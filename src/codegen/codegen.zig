const std = @import("std");
const Program = @import("../ast/program.zig").Program;
const Node = @import("../ast/node.zig").Node;

const VarInfo = struct {
    offset: usize,
    type: *VarType,
};

pub const VarType = struct {
    type_enum: enum { U8, U64, Pointer, Array },
    inner: ?*VarType,
    array_size: ?usize,

    fn fromString(allocator: std.mem.Allocator, str: []const u8) !*VarType {
        const result = try allocator.create(VarType);
        errdefer allocator.destroy(result);

        if (std.mem.startsWith(u8, str, "[")) {
            const closing_bracket = std.mem.indexOf(u8, str, "]") orelse return error.InvalidArrayType;
            const arr_size = try std.fmt.parseInt(usize, str[1..closing_bracket], 10);
            const inner_type = try VarType.fromString(allocator, str[closing_bracket + 1 ..]);
            result.* = .{ .type_enum = .Array, .inner = inner_type, .array_size = arr_size };
        } else if (std.mem.eql(u8, str, "u8")) {
            result.* = .{ .type_enum = .U8, .inner = null, .array_size = null };
        } else if (std.mem.eql(u8, str, "u64")) {
            result.* = .{ .type_enum = .U64, .inner = null, .array_size = null };
        } else if (std.mem.startsWith(u8, str, "*")) {
            const inner_type = try VarType.fromString(allocator, str[1..]);
            result.* = .{ .type_enum = .Pointer, .inner = inner_type, .array_size = null };
        } else {
            allocator.destroy(result);
            return error.UnsupportedType;
        }
        return result;
    }

    pub fn size(self: VarType) usize {
        return switch (self.type_enum) {
            .U8 => 1,
            .U64, .Pointer => 8,
            .Array => self.array_size.? * self.inner.?.size(),
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
    current_offset: usize,
    allocator: std.mem.Allocator,
    label_counter: usize,

    fn init(allocator: std.mem.Allocator) SymbolTable {
        return .{
            .variables = std.StringHashMap(VarInfo).init(allocator),
            .current_offset = 32, // Start after saved fp and lr
            .allocator = allocator,
            .label_counter = 0,
        };
    }

    fn addVariable(self: *@This(), name: []const u8, var_type: []const u8) !void {
        const type_enum = try VarType.fromString(self.allocator, var_type);
        const size = type_enum.size();

        // Align the offset for larger types
        if (size > 1) {
            self.current_offset = (self.current_offset + 7) & ~@as(usize, 7);
        }

        const start_offset = self.current_offset;
        self.current_offset += size;

        try self.variables.put(name, .{ .offset = start_offset, .type = type_enum });
    }

    fn getVariableOffset(self: *@This(), name: []const u8) ?usize {
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
    std.debug.print("Starting codegen_init\n", .{});
    var symbol_table = SymbolTable.init(program.statements.allocator);
    defer symbol_table.deinit();

    std.debug.print("Writing base assembly code\n", .{});
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
        \\
    );

    try writer.writeAll("    stp x29, x30, [sp, #-16]!\n");
    try writer.writeAll("    mov x29, sp\n");

    // First pass: count variables
    std.debug.print("First pass: counting variables\n", .{});
    for (program.statements.items) |stmt| {
        std.debug.print("Processing statement {s}\n", .{@tagName(stmt.type)});
        if (stmt.type == .SayDeclaration) {
            if (stmt.value.variable_decl.name.len > 0) {
                std.debug.print("Adding variable: {s}\n", .{stmt.value.variable_decl.name});
                try symbol_table.addVariable(stmt.value.variable_decl.name, stmt.value.variable_decl.type);
            } else {
                std.debug.print("SayDeclaration with empty name\n", .{});
            }
        } else {
            std.debug.print("Non-variable declaration statement encountered\n", .{});
        }
    }

    // Align stack size to 16 bytes
    const stack_size = (symbol_table.current_offset + 15) & ~@as(usize, 15);
    std.debug.print("Stack size: {}\n", .{stack_size});
    if (stack_size > 16) {
        try writer.print("    sub sp, sp, #{}\n", .{stack_size});
    }

    // Second pass: generate code
    std.debug.print("Second pass: generating code\n", .{});
    for (program.statements.items) |stmt| {
        std.debug.print("Generating code for statement: {any}\n", .{stmt});
        try codegen(stmt, writer, &symbol_table, null);
    }

    // Epilogue
    std.debug.print("Writing epilogue\n", .{});
    if (stack_size > 16) {
        try writer.print("    add sp, sp, #{d}\n", .{stack_size - 16});
    }
    try writer.writeAll("    ldp x29, x30, [sp], #16\n");

    std.debug.print("Writing termination code\n", .{});
    try writer.writeAll(
        \\
        \\_terminate:
        \\    mov x0, #0  // Exit syscall number
        \\    mov x16, #1 // Terminate syscall
        \\    svc 0       // Trigger syscall
        \\
    );
    std.debug.print("Finished codegen_init\n", .{});
}

fn codegen(node: *Node, writer: anytype, symbol_table: *SymbolTable, parent_var_name: ?[]const u8) !void {
    std.debug.print("codegen: Processing node of type: {s}\n", .{@tagName(node.type)});
    switch (node.type) {
        .IntegerLiteral => {
            std.debug.print("codegen: IntegerLiteral value: {}\n", .{node.value.integer});
            if (node.value.integer > 255) {
                try writer.print("    mov x0, #{}\n", .{node.value.integer});
            } else {
                try writer.print("    mov w0, #{}\n", .{node.value.integer});
            }
        },
        .NodeAdd, .NodeSub, .NodeMul, .NodeDiv, .NodeModulo => {
            std.debug.print("codegen: Binary operation\n", .{});
            if (node.left) |left| try codegen(left, writer, symbol_table, null);

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
            if (node.right) |right| try codegen(right, writer, symbol_table, null);
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
            if (node.left) |left| try codegen(left, writer, symbol_table, null);

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
            if (node.right) |right| try codegen(right, writer, symbol_table, null);

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
            try writer.writeAll(
                \\
                \\    ; Say variable declaration
                \\
            );
            const var_name = node.value.variable_decl.name;
            const var_type = node.value.variable_decl.type;
            const type_enum = try VarType.fromString(symbol_table.allocator, var_type);
            defer {
                type_enum.deinit(symbol_table.allocator);
                symbol_table.allocator.destroy(type_enum);
            }
            const offset = if (symbol_table.getVariableOffset(var_name)) |off| off else blk: {
                try symbol_table.addVariable(var_name, var_type);
                break :blk symbol_table.getVariableOffset(var_name).?;
            };

            if (type_enum.type_enum == .Array) {
                if (node.left) |left| {
                    if (left.type == .ArrayInitialization or left.type == .StringLiteral) {
                        try codegen(left, writer, symbol_table, var_name);
                    }
                }
            } else if (node.left) |left| {
                try codegen(left, writer, symbol_table, null);
                switch (type_enum.type_enum) {
                    .U8 => try writer.print("    strb w0, [x29, #-{}]\n", .{offset}),
                    .U64, .Pointer => try writer.print("    str x0, [x29, #-{}]\n", .{offset}),
                    .Array => unreachable, // Handled above
                }
            }
        },
        .Variable => {
            const var_name = node.value.str;
            const offset = symbol_table.getVariableOffset(var_name) orelse return error.UndefinedVariable;
            const var_type = symbol_table.getVariableType(var_name) orelse return error.UndefinedVariable;

            std.debug.print("\nVAR NAME: {s}\n", .{var_name});
            std.debug.print("VAR OFFSET: {}\n", .{offset});

            switch (var_type.type_enum) {
                .U8 => try writer.print("    ldrb w0, [x29, #-{}]\n", .{offset}),
                .U64 => try writer.print("    ldr x0, [x29, #-{}]\n", .{offset}),
                .Pointer => try writer.print("    ldr x0, [x29, #-{}]\n", .{offset}),
                .Array => {
                    const arr_length = var_type.array_size.?;
                    std.debug.print("ARR LENGTH: {?}\n", .{arr_length});

                    // For arrays, load the address of the first element
                    try writer.print("    add x0, x29, #-{}\n", .{offset + arr_length - 1});
                },
            }
        },
        .CmdPrintInt => {
            if (node.left) |left| try codegen(left, writer, symbol_table, null);
            try writer.writeAll("    bl _printInt\n");
        },
        .CmdPrintChar => {
            if (node.left) |left| try codegen(left, writer, symbol_table, null);
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
        .CmdPrintBuf => {
            // Get array information
            const var_name = node.left.?.value.str;
            const var_type = symbol_table.getVariableType(var_name) orelse return error.UndefinedVariable;
            const array_size = var_type.array_size orelse return error.MissingArraySize;
            const element_size = var_type.inner.?.size();
            const total_size = array_size * element_size;
            const offset = symbol_table.getVariableOffset(var_name) orelse return error.UndefinedVariable;

            // Calculate the correct base address
            try writer.print("    add x0, x29, #-{}\n", .{offset + total_size - element_size});
            try writer.writeAll("    mov x1, x0\n"); // Move pointer to x1

            // Generate code for the count argument
            try codegen(node.right.?, writer, symbol_table, null);
            try writer.writeAll("    mov x2, x0\n"); // Move count to x2

            // Ensure we don't print more than the array size
            try writer.print("    mov x3, #{}\n", .{array_size});
            try writer.writeAll("    cmp x2, x3\n");
            try writer.writeAll("    csel x2, x2, x3, ls\n"); // x2 = min(x2, x3)

            // System call to write
            try writer.writeAll(
                \\    mov x0, #1     ; stdout file descriptor
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

            try codegen(condition, writer, symbol_table, null);

            // Branch based on condition result
            try writer.writeAll("    cbz w0, ");
            try writer.print("{s}\n", .{end_label});

            try codegen(block, writer, symbol_table, null);

            try writer.print("{s}:\n", .{end_label});
        },
        .BlockStatement => {
            for (node.value.nodes) |stmt| {
                try codegen(stmt, writer, symbol_table, null);
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
            try codegen(condition, writer, symbol_table, null);
            try writer.writeAll("    cmp x0, #0\n");
            try writer.print("    beq {s}\n", .{end_label});

            // Generate code for the loop body
            try codegen(block, writer, symbol_table, null);

            // Generate code for the loop operation (if present)
            if (loop_operation) |operation| {
                std.debug.print("LOOP OPER:\n", .{});
                operation.print(0, "OPERATION");
                try codegen(operation, writer, symbol_table, null);
            }

            try writer.print("    b {s}\n", .{loop_label});
            try writer.print("{s}:\n", .{end_label});
        },
        .Assignment => {
            if (node.left.?.type == .Dereference) {
                // Generate code to put the address into x1
                try codegen(node.left.?.left.?, writer, symbol_table, null);
                try writer.writeAll("    mov x1, x0\n");

                // Generate code to put the value into x0
                try codegen(node.right.?, writer, symbol_table, null);

                try writer.writeAll("    strb w0, [x1]\n");
            } else if (node.left.?.type == .ArrayIndex) {
                const array_node = node.left.?.left.?;
                const index_node = node.left.?.right.?;

                const array_name = array_node.value.str;
                const var_type = symbol_table.getVariableType(array_name) orelse return error.UndefinedVariable;
                const offset = symbol_table.getVariableOffset(array_name) orelse return error.UndefinedVariable;
                const array_size = var_type.array_size orelse return error.MissingArraySize;
                const element_size = var_type.inner.?.size();

                // Calculate base address
                try writer.print("    add x1, x29, #-{}\n", .{offset + array_size - element_size});

                // Generate code for index
                try codegen(index_node, writer, symbol_table, null);
                try writer.writeAll("    add x1, x1, x0\n"); // Subtract index from base address

                // Generate code for the right-hand side of the assignment
                try codegen(node.right.?, writer, symbol_table, null);

                // Store the result in the array element
                try writer.writeAll("    strb w0, [x1]\n");
            } else {
                const varName = node.left.?.value.str;
                const offset = symbol_table.getVariableOffset(varName) orelse return error.UndefinedVariable;
                const var_type = symbol_table.getVariableType(varName) orelse return error.UndefinedVariable;

                // Generate code for the right-hand side of the assignment
                if (node.right) |right| {
                    try codegen(right, writer, symbol_table, null);
                }

                // Store the result in the variable
                switch (var_type.type_enum) {
                    .U8 => try writer.print("    strb w0, [x29, #-{}]\n", .{offset}),
                    .U64, .Pointer => try writer.print("    str x0, [x29, #-{}]\n", .{offset}),
                    .Array => return error.UnexpectedVar,
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
            if (node.left) |left| try codegen(left, writer, symbol_table, null);
            try writer.writeAll("    ldrb w0, [x0]\n");
        },
        .ArrayIndex => {
            // Generate code for the array base
            if (node.left) |left| try codegen(left, writer, symbol_table, null);
            try writer.writeAll("    mov x1, x0\n");

            // Generate code for the index
            if (node.right) |right| try codegen(right, writer, symbol_table, null);

            // Calculate the address of the element
            try writer.writeAll("    sub x0, x1, x0\n");

            // Load the value from the calculated address
            try writer.writeAll("    ldrb w0, [x0]\n");
        },
        .ArrayInitialization => {
            const var_name = parent_var_name orelse return error.MissingParentVariableName;
            const offset = symbol_table.getVariableOffset(var_name) orelse return error.UndefinedVariable;
            const var_type = symbol_table.getVariableType(var_name) orelse return error.UndefinedVariable;

            if (var_type.type_enum != .Array) return error.ExpectedArrayType;
            const element_type = var_type.inner.?;
            const element_size = element_type.size();
            const declared_size = var_type.array_size orelse return error.MissingArraySize;
            const actual_size = @min(declared_size, node.value.nodes.len);

            // Initialize elements in natural order
            for (node.value.nodes[0..actual_size], 0..) |element, i| {
                try codegen(element, writer, symbol_table, null);
                const adjusted_offset = offset + (actual_size - 1 - i) * element_size;
                switch (element_type.type_enum) {
                    .U8 => try writer.print("    strb w0, [x29, #-{}]\n", .{adjusted_offset}),
                    .U64 => try writer.print("    str x0, [x29, #-{}]\n", .{adjusted_offset}),
                    else => return error.UnsupportedArrayElementType,
                }
            }
        },
        .SocketCreate => {
            try writer.writeAll(
                \\    mov x0, #2          // AF_INET
                \\    mov x1, #1          // SOCK_STREAM
                \\    mov x2, #0          // protocol (0 = default)
                \\    mov x16, #97        // socket syscall
                \\    svc #0x80
                \\    cmp x0, #0
                \\    b.lt socket_create_error
                \\    mov x19, x0         // save socket descriptor to x19
                \\
                \\    ; Set socket to blocking mode
                \\    mov x0, x19         // socket fd
                \\    mov x1, #3          // F_GETFL
                \\    mov x16, #92        // fcntl syscall
                \\    svc #0x80
                \\    bic x1, x0, #0x800  // Set O_NONBLOCK flag
                \\    mov x0, x19         // socket fd
                \\    mov x2, x1          // New flags
                \\    mov x1, #4          // F_SETFL
                \\    mov x16, #92        // fcntl syscall
                \\    svc #0x80
                \\    cmp x0, #0
                \\    b.lt socket_create_error
                \\    mov x0, x19         // return the socket descriptor
                \\    b socket_create_end
                \\socket_create_error:
                \\    mov x1, x0          // save error code to x1
                \\    mov x0, #1          // prepare for exit syscall
                \\    mov x16, #1         // exit syscall
                \\    svc #0x80
                \\socket_create_end:
            );
        },
        .SocketBind => {
            try writer.writeAll(
                \\
                \\    ; Socket bind
                \\
            );

            if (node.left) |socket_fd| try codegen(socket_fd, writer, symbol_table, null);
            try writer.writeAll("    mov x9, x0          // save socket fd to x9\n");

            // Generate code for port number argument
            if (node.right) |port| try codegen(port, writer, symbol_table, null);
            try writer.writeAll("    mov x10, x0         // save port to x10\n");

            // Create sockaddr_in structure on stack
            // TODO: Fix the rev w10, w10
            // Right now it just uses the port 8888, but it should use the developer-provided port
            try writer.writeAll(
                \\    sub sp, sp, #16     // allocate 16 bytes on stack for sockaddr_in
                \\    mov x1, #2          // AF_INET
                \\    strh w1, [sp]       // store sin_family
                \\    rev16 w10, w10        // convert port to network byte order
                \\
                \\    strh w10, [sp, #2]  // store sin_port
                \\    mov x11, #0         // INADDR_ANY
                \\    str x11, [sp, #4]   // store sin_addr
                \\
                \\    mov x0, x9          // socket fd
                \\    mov x1, sp          // pointer to sockaddr_in
                \\    mov x2, #16         // length of sockaddr_in
                \\    mov x16, #104       // bind syscall
                \\    svc #0x80
                \\
                \\    add sp, sp, #16     // deallocate stack space
                \\    mov x1, x0          // save result to x1
            );
        },
        .SocketListen => {
            try writer.writeAll(
                \\
                \\    ; Socket listen
                \\
            );
            if (node.left) |socket_fd| try codegen(socket_fd, writer, symbol_table, null);
            try writer.writeAll("    mov x9, x0          // save socket fd to x9\n");

            // Generate code for backlog argument
            if (node.right) |backlog| try codegen(backlog, writer, symbol_table, null);
            try writer.writeAll("    mov x1, x0          // move backlog to x1\n");

            try writer.writeAll(
                \\    mov x0, x9          // socket fd
                \\    mov x16, #106       // listen syscall
                \\    svc #0x80
            );
            try writer.writeAll("\n    mov x1, x0          // save result to x1\n");
        },
        .SocketAccept => {
            try writer.writeAll(
                \\
                \\    ; Socket accept
                \\
            );
            if (node.left) |socket_fd| try codegen(socket_fd, writer, symbol_table, null);
            try writer.writeAll("    mov x9, x0          // save socket fd to x9\n");

            try writer.writeAll(
                \\    mov x0, x9          // socket fd
                \\    mov x1, #0          // NULL for client address
                \\    mov x2, #0          // NULL for address length
                \\    mov x16, #30        // accept syscall
                \\    svc #0x80
            );
            try writer.writeAll("\n    mov x1, x0          // save client socket fd to x1\n");
        },
        .SocketWrite => {
            try writer.writeAll(
                \\
                \\    ; Socket write
                \\
            );
            if (node.left) |socket_fd| try codegen(socket_fd, writer, symbol_table, null);
            try writer.writeAll("    mov x9, x0          // save socket fd to x9\n");

            // Generate code for buffer argument
            if (node.right) |buffer| try codegen(buffer, writer, symbol_table, null);
            try writer.writeAll("    mov x10, x0         // save buffer address to x10\n");

            // Generate code for length argument
            if (node.extra) |length| try codegen(length, writer, symbol_table, null);
            try writer.writeAll("    mov x11, x0         // save length to x11\n");

            try writer.writeAll(
                \\    mov x0, x9          // socket fd
                \\    mov x1, x10         // buffer address
                \\    mov x2, x11         // length
                \\    mov x16, #4         // write syscall
                \\    svc #0x80
            );
            try writer.writeAll("\n    mov x1, x0          // save number of bytes written to x1\n");
        },
        .SocketClose => {
            try writer.writeAll(
                \\
                \\    ; Socket close
                \\
            );
            // Generate code for socket file descriptor argument
            if (node.left) |socket_fd| try codegen(socket_fd, writer, symbol_table, null);
            try writer.writeAll("    mov x9, x0          // save socket fd to x9\n");

            try writer.writeAll(
                \\    mov x0, x9          // socket fd
                \\    mov x16, #6         // close syscall
                \\    svc #0x80
            );
            try writer.writeAll("\n    mov x1, x0          // save result to x1\n");
        },
        .StringLiteral => {
            std.debug.print("codegen: StringLiteral\n", .{});
            const str_value = node.value.str;
            const var_name = parent_var_name orelse {
                std.debug.print("codegen: Error - Missing parent variable name for StringLiteral\n", .{});
                return error.MissingParentVariableName;
            };
            std.debug.print("codegen: StringLiteral parent variable: {s}\n", .{var_name});
            const offset = symbol_table.getVariableOffset(var_name) orelse return error.UndefinedVariable;
            const var_type = symbol_table.getVariableType(var_name) orelse return error.UndefinedVariable;

            if (var_type.type_enum != .Array) return error.ExpectedArrayType;
            const element_type = var_type.inner.?;
            if (element_type.type_enum != .U8) return error.ExpectedU8ArrayForString;
            const declared_size = var_type.array_size orelse str_value.len;
            const actual_size = @min(declared_size, str_value.len);

            for (str_value[0..actual_size], 0..) |char, i| {
                const adjusted_offset = offset + (declared_size - 1 - i);
                try writer.print("    mov w0, #{}\n", .{char});
                try writer.print("    strb w0, [x29, #-{}]\n", .{adjusted_offset});
            }

            // Null-terminate if there's space
            if (actual_size < declared_size) {
                const null_terminator_offset = offset + (declared_size - actual_size - 1);
                try writer.print("    mov w0, #0\n", .{});
                try writer.print("    strb w0, [x29, #-{}]\n", .{null_terminator_offset});
            }
        },
        else => {
            std.debug.print("codegen: Unsupported node type: {s}\n", .{@tagName(node.type)});
            return error.UnsupportedNodeType;
        },
    }
    std.debug.print("codegen: Finished processing node of type: {s}\n", .{@tagName(node.type)});
}
