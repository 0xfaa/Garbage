const std = @import("std");
const Program = @import("../ast/program.zig").Program;
const Node = @import("../ast/node.zig").Node;

const SymbolTable = struct {
    variables: std.StringHashMap(i64),
    current_offset: i64,
    allocator: std.mem.Allocator,
    label_counter: usize,

    fn init(allocator: std.mem.Allocator) SymbolTable {
        return .{
            .variables = std.StringHashMap(i64).init(allocator),
            .current_offset = 16, // Start after saved fp and lr
            .allocator = allocator,
            .label_counter = 0,
        };
    }

    fn addVariable(self: *@This(), name: []const u8) !void {
        try self.variables.put(name, self.current_offset);
        self.current_offset += 8;
    }

    fn getVariableOffset(self: *@This(), name: []const u8) ?i64 {
        return self.variables.get(name);
    }

    fn deinit(self: *@This()) void {
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
            try symbol_table.addVariable(stmt.value.str);
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
        .IntegerLiteral => try writer.print("    mov x0, #{}\n", .{node.value.integer}),
        .NodeAdd, .NodeSub, .NodeMul, .NodeDiv, .NodeModulo, .NodeEqual, .NodeLess, .NodeGreater, .NodeNotEqual => {
            if (node.left) |left| try codegen(left, writer, symbol_table);
            try writer.writeAll("    str x0, [sp, #-16]!\n");
            if (node.right) |right| try codegen(right, writer, symbol_table);
            try writer.writeAll("    mov x1, x0\n");
            try writer.writeAll("    ldr x0, [sp], #16\n");
            switch (node.type) {
                .NodeAdd => try writer.writeAll("    add x0, x0, x1\n"),
                .NodeSub => try writer.writeAll("    sub x0, x0, x1\n"),
                .NodeMul => try writer.writeAll("    mul x0, x0, x1\n"),
                .NodeDiv => try writer.writeAll("    sdiv x0, x0, x1\n"),
                .NodeModulo => {
                    try writer.writeAll("    sdiv x2, x0, x1\n");
                    try writer.writeAll("    msub x0, x2, x1, x0\n");
                },
                .NodeEqual => {
                    try writer.writeAll("    cmp x0, x1\n");
                    try writer.writeAll("    cset x0, eq\n");
                },
                .NodeLess => {
                    try writer.writeAll("    cmp x0, x1\n");
                    try writer.writeAll("    cset x0, lt\n");
                },
                .NodeGreater => {
                    try writer.writeAll("    cmp x0, x1\n");
                    try writer.writeAll("    cset x0, gt\n");
                },
                .NodeNotEqual => {
                    try writer.writeAll("    cmp x0, x1\n");
                    try writer.writeAll("    cset x0, ne\n");
                },
                else => unreachable,
            }
        },
        .SayDeclaration => {
            const var_name = node.value.str;
            if (node.left) |left| try codegen(left, writer, symbol_table);
            const offset = if (symbol_table.getVariableOffset(var_name)) |off| off else blk: {
                try symbol_table.addVariable(var_name);
                break :blk symbol_table.getVariableOffset(var_name).?;
            };
            try writer.print("    str x0, [x29, #-{}]\n", .{offset});
        },
        .Variable => {
            const var_name = node.value.str;
            const offset = symbol_table.getVariableOffset(var_name) orelse return error.UndefinedVariable;
            try writer.print("    ldr x0, [x29, #-{}]\n", .{offset});
        },
        .CmdPrintInt => {
            if (node.left) |left| try codegen(left, writer, symbol_table);
            try writer.writeAll("    bl _printInt\n");
        },
        .IfStatement => {
            const condition = node.left orelse return error.MissingCondition;
            const block = node.right orelse return error.MissingBlock;

            const end_label = try std.fmt.allocPrint(symbol_table.allocator, ".L{d}", .{symbol_table.label_counter});
            defer symbol_table.allocator.free(end_label);
            symbol_table.label_counter += 1;

            try codegen(condition, writer, symbol_table);
            try writer.writeAll("    cmp x0, #0\n");
            try writer.print("    beq {s}\n", .{end_label});

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
            const varName = node.left.?.value.str;

            // Generate code for the right-hand side of the assignment
            if (node.right) |right| try codegen(right, writer, symbol_table);

            // Store the result in the variable
            const offset = symbol_table.getVariableOffset(varName) orelse return error.UndefinedVariable;
            try writer.print("    str x0, [x29, #-{}]\n", .{offset});
        },
        else => return error.UnsupportedNodeType,
    }
}
