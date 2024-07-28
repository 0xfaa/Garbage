const std = @import("std");
const Program = @import("../ast/program.zig").Program;
const Node = @import("../ast/node.zig").Node;

const VarInfo = struct {
    offset: i64,
    type: *VarType,
};

pub const VarType = struct {
    type_enum: enum { U8, U64, Pointer },
    inner: ?*VarType,

    fn fromString(allocator: std.mem.Allocator, str: []const u8) !*VarType {
        const result = try allocator.create(VarType);
        errdefer allocator.destroy(result);

        if (std.mem.eql(u8, str, "u8")) {
            result.* = .{ .type_enum = .U8, .inner = null };
        } else if (std.mem.eql(u8, str, "u64")) {
            result.* = .{ .type_enum = .U64, .inner = null };
        } else if (std.mem.startsWith(u8, str, "*")) {
            const inner_type = try VarType.fromString(allocator, str[1..]);
            result.* = .{ .type_enum = .Pointer, .inner = inner_type };
        } else {
            allocator.destroy(result);
            return error.UnsupportedType;
        }
        return result;
    }

    pub fn size(self: VarType) u8 {
        return switch (self.type_enum) {
            .U8 => 1,
            .U64, .Pointer => 8,
        };
    }

    pub fn deinit(self: *VarType, allocator: std.mem.Allocator) void {
        if (self.inner) |inner| {
            inner.deinit(allocator);
            allocator.destroy(inner);
        }
    }
};

const SymbolTable = struct {
    variables: std.StringHashMap(VarInfo),
    current_offset: i64,
    allocator: std.mem.Allocator,
    label_counter: usize,

    fn init(allocator: std.mem.Allocator) SymbolTable {
        return .{
            .variables = std.StringHashMap(VarInfo).init(allocator),
            .current_offset = 16, // Start after saved fp and lr
            .allocator = allocator,
            .label_counter = 0,
        };
    }

    fn addVariable(self: *@This(), name: []const u8, var_type: []const u8) !void {
        const type_enum = try VarType.fromString(self.allocator, var_type);
        const size = type_enum.size();

        // Align the offset for larger types
        if (size > 1) {
            self.current_offset = (self.current_offset + 7) & ~@as(i64, 7);
        }

        std.debug.print("Adding a variable: {s} with size: {}\n", .{ name, size });

        try self.variables.put(name, .{ .offset = self.current_offset, .type = type_enum });
        std.debug.print("Saved variable with offset: {}\n", .{self.current_offset});

        self.current_offset += size;
        std.debug.print("New offset: {}\n", .{self.current_offset});
    }

    fn getVariableOffset(self: *@This(), name: []const u8) ?i64 {
        return if (self.variables.get(name)) |entry| entry.offset else null;
    }

    fn getVariableType(self: *@This(), name: []const u8) ?*VarType {
        return if (self.variables.get(name)) |entry| entry.type else null;
    }

    fn deinit(self: *@This()) void {
        var it = self.variables.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.type.deinit(self.allocator);
            self.allocator.destroy(entry.value_ptr.type);
        }
        self.variables.deinit();
    }
};

pub fn codegen_init(program: *Program, writer: anytype) !void {
    var symbol_table = SymbolTable.init(program.statements.allocator);
    defer symbol_table.deinit();

    // Write the base assembly code
    try writer.writeAll(
        \\.global _main
        \\.align 2
        \\_itoa:
        \\mov x2, x0      ; Copy the input num to x2 for division
        \\mov x3, #0      ; set the ascii reg to #0
        \\mov x4, #10     ; set the divider to #10
        \\mov x5, #0      ; init quotient to #0
        \\mov x6, #0      ; digit counter for buffer offset #0
        \\mov x7, #0  
        \\.itoa_loop:
        \\udiv x5, x2, x4
        \\msub x3, x5, x4, x2
        \\mov x2, x5
        \\add x3, x3, #48
        \\sub x7, x1, x6
        \\sub x7, x7, #1
        \\strb w3, [x7]
        \\add x6, x6, #1
        \\cmp x2, #0
        \\bne .itoa_loop
        \\mov x2, x6
        \\sub x1, x1, x6
        \\ret
        \\_printInt:
        \\stp x30, x29, [sp, #-16]!
        \\mov x29, sp
        \\sub sp, sp, #21
        \\mov x1, sp
        \\bl _itoa
        \\mov w0, #10
        \\strb w0, [x1, x2]
        \\add x2, x2, #1
        \\mov x0, #0        ; stdout file descriptor (0)
        \\mov x16, #4       ; write call (4)
        \\svc 0
        \\add sp, sp, #21
        \\ldp x30, x29, [sp], #16
        \\ret
        \\
        \\_main:
    );

    try writer.writeAll("    stp x29, x30, [sp, #-16]!\n");
    try writer.writeAll("    mov x29, sp\n");

    // First pass: count variables
    for (program.statements.items) |stmt| {
        if (stmt.type == .SayDeclaration) {
            try symbol_table.addVariable(stmt.value.variable_decl.name, stmt.value.variable_decl.type);
        }
    }

    // Align stack size to 16 bytes
    const stack_size = (symbol_table.current_offset + 15) & -16;
    if (stack_size > 16) {
        try writer.print("    sub sp, sp, #{d}\n", .{stack_size});
    }

    // Second pass: generate code
    for (program.statements.items) |stmt| {
        try codegen(stmt, writer, &symbol_table);
    }

    // Epilogue
    if (stack_size > 16) {
        try writer.print("    add sp, sp, #{d}\n", .{stack_size - 16});
    }
    try writer.writeAll("    ldp x29, x30, [sp], #16\n");

    // Write the termination code
    try writer.writeAll(
        \\
        \\_terminate:
        \\    mov x0, #0  // Exit syscall number
        \\    mov x16, #1 // Terminate syscall
        \\    svc 0       // Trigger syscall
        \\
    );
}

fn codegen(node: *Node, writer: anytype, symbol_table: *SymbolTable) !void {
    switch (node.type) {
        .IntegerLiteral => {
            if (node.value.integer > 255) {
                try writer.print("    mov x0, #{}\n", .{node.value.integer});
            } else {
                try writer.print("    mov w0, #{}\n", .{node.value.integer});
            }
        },
        .NodeAdd, .NodeSub, .NodeMul, .NodeDiv, .NodeModulo => {
            if (node.left) |left| try codegen(left, writer, symbol_table);

            if (node.left.?.type == .Variable) {
                const var_type = symbol_table.getVariableType(node.left.?.value.str) orelse return error.UndefinedVariable;
                if (var_type.type_enum == .U8) {
                    try writer.writeAll("    uxtb w1, w0\n");
                    try writer.writeAll("    mov x1, x1\n");
                } else {
                    try writer.writeAll("    mov x1, x0\n");
                }
            } else {
                try writer.writeAll("    mov x1, x0\n");
            }
            try writer.writeAll("    str x1, [sp, #-16]!\n"); // Push left operand onto stack
            if (node.right) |right| try codegen(right, writer, symbol_table);
            // Now right operand is in x0
            try writer.writeAll("    mov x2, x0\n"); // Move right operand to x2
            try writer.writeAll("    ldr x1, [sp], #16\n"); // Pop left operand into x1

            if (node.type == .NodeAdd or node.type == .NodeSub) {
                if (node.left.?.type == .Variable) {
                    const var_type = symbol_table.getVariableType(node.left.?.value.str) orelse return error.UndefinedVariable;
                    if (var_type.type_enum == .Pointer) {
                        // Always increment by 1 byte, regardless of pointed-to type
                        // No need for multiplication
                        if (node.type == .NodeAdd) {
                            try writer.writeAll("    add x0, x1, x2\n");
                        } else { // .NodeSub
                            try writer.writeAll("    sub x0, x1, x2\n");
                        }
                        return; // Skip the default arithmetic handling
                    }
                }
            }

            switch (node.type) {
                .NodeAdd => try writer.writeAll("    add x0, x1, x2\n"),
                .NodeSub => try writer.writeAll("    sub x0, x1, x2\n"),
                .NodeMul => try writer.writeAll("    mul x0, x1, x2\n"),
                .NodeDiv => try writer.writeAll("    sdiv x0, x1, x2\n"),
                .NodeModulo => {
                    try writer.writeAll("    sdiv x3, x1, x2\n");
                    try writer.writeAll("    msub x0, x3, x2, x1\n");
                },
                else => unreachable,
            }
        },
        .NodeEqual, .NodeLess, .NodeGreater, .NodeNotEqual => {
            const left_type = if (node.left.?.type == .Variable)
                symbol_table.getVariableType(node.left.?.value.str) orelse return error.UndefinedVariable
            else
                null;

            // Generate code for left operand
            if (node.left) |left| try codegen(left, writer, symbol_table);

            // If left operand is u8, keep it in w register
            if (left_type) |lt| {
                if (lt.type_enum == .U8) {
                    try writer.writeAll("    mov w1, w0\n");
                } else {
                    try writer.writeAll("    mov x1, x0\n");
                }
            } else {
                try writer.writeAll("    mov x1, x0\n");
            }

            // Generate code for right operand
            if (node.right) |right| try codegen(right, writer, symbol_table);

            // Perform comparison based on type
            if (left_type) |lt| {
                if (lt.type_enum == .U8) {
                    try writer.writeAll("    cmp w1, w0\n");
                } else {
                    try writer.writeAll("    cmp x1, x0\n");
                }
            } else {
                try writer.writeAll("    cmp x1, x0\n");
            }

            // Set result based on comparison type
            switch (node.type) {
                .NodeEqual => try writer.writeAll("    cset w0, eq\n"),
                .NodeLess => try writer.writeAll("    cset w0, lt\n"),
                .NodeGreater => try writer.writeAll("    cset w0, gt\n"),
                .NodeNotEqual => try writer.writeAll("    cset w0, ne\n"),
                else => unreachable,
            }
        },
        .SayDeclaration => {
            const var_name = node.value.variable_decl.name;
            const var_type = node.value.variable_decl.type;

            if (node.left) |left| try codegen(left, writer, symbol_table);
            const type_enum = try VarType.fromString(symbol_table.allocator, var_type);

            defer {
                type_enum.deinit(symbol_table.allocator);
                symbol_table.allocator.destroy(type_enum);
            }
            const offset = if (symbol_table.getVariableOffset(var_name)) |off| off else blk: {
                try symbol_table.addVariable(var_name, var_type);
                break :blk symbol_table.getVariableOffset(var_name).?;
            };

            std.debug.print("Var name: {s}: {s} | \n{}\nOffset: {}\n\n", .{ var_name, var_type, type_enum, offset });

            switch (type_enum.type_enum) {
                .U8 => try writer.print("    strb w0, [x29, #-{}]\n", .{offset}),
                .U64, .Pointer => try writer.print("    str x0, [x29, #-{}]\n", .{offset}),
            }
        },
        .Variable => {
            const var_name = node.value.str;
            const offset = symbol_table.getVariableOffset(var_name) orelse return error.UndefinedVariable;
            const var_type = symbol_table.getVariableType(var_name) orelse return error.UndefinedVariable;
            switch (var_type.type_enum) {
                .U8 => try writer.print("    ldrb w0, [x29, #-{}]\n", .{offset}),
                .U64 => try writer.print("    ldr x0, [x29, #-{}]\n", .{offset}),
                .Pointer => try writer.print("    ldr x0, [x29, #-{}]\n", .{offset}),
            }
        },
        .CmdPrintInt => {
            if (node.left) |left| try codegen(left, writer, symbol_table);
            try writer.writeAll("    bl _printInt\n");
        },
        .CmdPrintChar => {
            if (node.left) |left| try codegen(left, writer, symbol_table);
            try writer.writeAll(
                \\    mov x1, sp
                \\    strb w0, [x1]
                \\    mov x0, #1     ; stdout file descriptor
                \\    mov x2, #1     ; length of 1 character
                \\    mov x16, #4    ; write syscall number
                \\    svc 0
                \\
            );
        },
        .IfStatement => {
            const condition = node.left orelse return error.MissingCondition;
            const block = node.right orelse return error.MissingBlock;

            const end_label = try std.fmt.allocPrint(symbol_table.allocator, ".F{d}", .{symbol_table.label_counter});
            defer symbol_table.allocator.free(end_label);
            symbol_table.label_counter += 1;

            try codegen(condition, writer, symbol_table);

            // Branch based on condition result
            try writer.writeAll("    cbz w0, ");
            try writer.print("{s}\n", .{end_label});

            try codegen(block, writer, symbol_table);

            try writer.print("{s}:\n", .{end_label});
        },
        .BlockStatement => {
            for (node.value.nodes) |stmt| {
                try codegen(stmt, writer, symbol_table);
            }
        },
        .WhileStatement => {
            const condition = node.left orelse return error.MissingCondition;
            const block = node.right orelse return error.MissingBlock;
            const loop_operation = node.extra;

            const loop_label = try std.fmt.allocPrint(symbol_table.allocator, ".L{d}_loop", .{symbol_table.label_counter});
            defer symbol_table.allocator.free(loop_label);
            const end_label = try std.fmt.allocPrint(symbol_table.allocator, ".L{d}_end", .{symbol_table.label_counter});
            defer symbol_table.allocator.free(end_label);
            symbol_table.label_counter += 1;

            try writer.print("{s}:\n", .{loop_label});

            // Generate code for the condition
            try codegen(condition, writer, symbol_table);
            try writer.writeAll("    cmp x0, #0\n");
            try writer.print("    beq {s}\n", .{end_label});

            // Generate code for the loop body
            try codegen(block, writer, symbol_table);

            // Generate code for the loop operation (if present)
            if (loop_operation) |operation| {
                std.debug.print("LOOP OPER:\n", .{});
                try operation.print(0, "OPERATION");
                try codegen(operation, writer, symbol_table);
            }

            try writer.print("    b {s}\n", .{loop_label});
            try writer.print("{s}:\n", .{end_label});
        },
        .Assignment => {
            if (node.left.?.type == .Dereference) {
                // Generate code to put the address into x1
                try codegen(node.left.?.left.?, writer, symbol_table);
                try writer.writeAll("    mov x1, x0\n");

                // Generate code to put the value into x0
                try codegen(node.right.?, writer, symbol_table);

                try writer.writeAll("    strb w0, [x1]\n");
            } else {
                const varName = node.left.?.value.str;
                const offset = symbol_table.getVariableOffset(varName) orelse return error.UndefinedVariable;
                const var_type = symbol_table.getVariableType(varName) orelse return error.UndefinedVariable;

                // Generate code for the right-hand side of the assignment
                if (node.right) |right| {
                    try codegen(right, writer, symbol_table);
                }

                // Store the result in the variable
                switch (var_type.type_enum) {
                    .U8 => try writer.print("    strb w0, [x29, #-{}]\n", .{offset}),
                    .U64, .Pointer => try writer.print("    str x0, [x29, #-{}]\n", .{offset}),
                }
            }
        },
        .AddressOf => {
            if (node.left) |left| {
                if (left.type != .Variable) return error.InvalidAddressOf;
                const var_name = left.value.str;
                const offset = symbol_table.getVariableOffset(var_name) orelse return error.UndefinedVariable;
                try writer.print("    add x0, x29, #-{}\n", .{offset});
            } else {
                return error.InvalidAddressOf;
            }
        },
        .Dereference => {
            if (node.left) |left| try codegen(left, writer, symbol_table);
            try writer.writeAll("    ldrb w0, [x0]\n");
        },
        else => return error.UnsupportedNodeType,
    }
}
