const std = @import("std");
const Program = @import("../ast/program.zig").Program;
const Node = @import("../ast/node.zig").Node;

const SymbolTable = struct {
    variables: std.StringHashMap(i64),
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator) SymbolTable {
        return .{
            .variables = std.StringHashMap(i64).init(allocator),
            .allocator = allocator,
        };
    }

    fn addVariable(self: *@This(), name: []const u8, offset: i64) !void {
        try self.variables.put(name, offset);
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
        \\
    );

    try writer.writeAll("    stp x29, x30, [sp, #-16]!\n");
    try writer.writeAll("    mov x29, sp\n");

    // First pass: count variables
    var stack_size: i64 = 0;
    for (program.statements.items) |stmt| {
        if (stmt.type == .SayDeclaration) {
            try symbol_table.addVariable(stmt.value.str, stack_size);
            stack_size += 8;
        }
    }

    // Align stack size to 16 bytes
    stack_size = (stack_size + 15) & -16;

    // Allocate stack space
    if (stack_size > 0) {
        try writer.print("    sub sp, sp, #{}\n", .{stack_size});
    }

    // Second pass: generate code
    for (program.statements.items) |stmt| {
        try codegen(stmt, writer, &symbol_table);
    }

    // Epilogue
    if (stack_size > 0) {
        try writer.print("    add sp, sp, #{}\n", .{stack_size});
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
        .NodeAdd => {
            if (node.left) |left| try codegen(left, writer, symbol_table);
            try writer.writeAll("    mov x1, x0\n");
            if (node.right) |right| try codegen(right, writer, symbol_table);
            try writer.writeAll("    add x0, x1, x0\n");
        },
        .NodeSub => {
            if (node.left) |left| try codegen(left, writer, symbol_table);
            try writer.writeAll("    mov x1, x0\n");
            if (node.right) |right| try codegen(right, writer, symbol_table);
            try writer.writeAll("    sub x0, x1, x0\n");
        },
        .NodeMul => {
            if (node.left) |left| try codegen(left, writer, symbol_table);
            try writer.writeAll("    mov x1, x0\n");
            if (node.right) |right| try codegen(right, writer, symbol_table);
            try writer.writeAll("    mul x0, x1, x0\n");
        },
        .NodeDiv => {
            if (node.left) |left| try codegen(left, writer, symbol_table);
            try writer.writeAll("    mov x1, x0\n");
            if (node.right) |right| try codegen(right, writer, symbol_table);
            try writer.writeAll("    sdiv x0, x1, x0\n");
        },
        .NodeModulo => {
            // step 1: parse left number
            // mov x0 #{left}
            // mov x2, x0
            //
            // step 2: parse right number
            // mov x0, #{right}
            //
            // step 3: save the previous calc results
            // mov x3, x1
            //
            // step 4: prepare and divide
            // | udiv (quotient) = divident / divisor
            // | x4 = x2 / x0
            // udiv x4, x2, x0
            //
            // step 5: multiply the result by the divisor
            // | mul x4, x4, x0
            // | x4 = x4 * x0
            //
            // step 6: subtract the multiplication result from the divident
            // | sub x2, x2, x4
            // | x2 = x2 - x4
            //
            // step 7: move the result to x0, and return the previous calc to x1
            // mov x0, x2
            // mov x1, x3
            if (node.left) |left| try codegen(left, writer, symbol_table);
            try writer.writeAll("    mov x1, x0\n");
            if (node.right) |right| try codegen(right, writer, symbol_table);
            try writer.writeAll("    sdiv x2, x1, x0\n");
            try writer.writeAll("    mul x2, x2, x0\n");
            try writer.writeAll("    sub x0, x1, x2\n");
        },
        .SayDeclaration => {
            const var_name = node.value.str;
            const offset = symbol_table.getVariableOffset(var_name) orelse return error.UndefinedVariable;

            if (node.left) |left| try codegen(left, writer, symbol_table);
            try writer.print("    str x0, [x29, #-{}]\n", .{offset + 16});
        },
        .Assignment => {
            const var_name = node.value.str;
            const offset = symbol_table.getVariableOffset(var_name) orelse return error.UndefinedVariable;

            if (node.left) |left| try codegen(left, writer, symbol_table);
            try writer.print("    str x0, [x29, #-{}]\n", .{offset + 16});
        },
        .Variable => {
            const var_name = node.value.str;
            const offset = symbol_table.getVariableOffset(var_name) orelse return error.UndefinedVariable;
            try writer.print("    ldr x0, [x29, #-{}]\n", .{offset + 16});
        },
        .CmdPrintInt => {
            if (node.left) |left| try codegen(left, writer, symbol_table);
            try writer.writeAll("    bl _printInt\n");
        },
        else => return error.UnsupportedNodeType,
    }
}
