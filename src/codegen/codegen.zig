const std = @import("std");
const Program = @import("../ast/program.zig").Program;
const Node = @import("../ast/node.zig").Node;

pub fn codegen_init(program: *Program, writer: anytype) !void {
    for (program.statements.items) |stmt| {
        try codegen(stmt, writer);
    }
}

fn codegen(node: *Node, writer: anytype) !void {
    switch (node.type) {
        .IntegerLiteral => try writer.print("    mov x0, #{}\n", .{node.value.integer}),
        .NodeAdd => {
            if (node.left) |left| try codegen(left, writer);
            try writer.writeAll("    mov x1, x0\n");
            if (node.right) |right| try codegen(right, writer);
            try writer.writeAll("    add x0, x1, x0\n");
        },
        .NodeSub => {
            if (node.left) |left| try codegen(left, writer);
            try writer.writeAll("    mov x1, x0\n");
            if (node.right) |right| try codegen(right, writer);
            try writer.writeAll("    sub x0, x1, x0\n");
        },
        .NodeMul => {
            if (node.left) |left| try codegen(left, writer);
            try writer.writeAll("    mov x1, x0\n");
            if (node.right) |right| try codegen(right, writer);
            try writer.writeAll("    mul x0, x1, x0\n");
        },
        .NodeDiv => {
            if (node.left) |left| try codegen(left, writer);
            try writer.writeAll("    mov x2, x0\n"); // Save dividend in x2
            if (node.right) |right| try codegen(right, writer);
            try writer.writeAll("    mov x3, x1\n"); // Move saved value from x1 to x3
            try writer.writeAll("    mov x1, x0\n"); // Move divisor to x1
            try writer.writeAll("    mov x0, x2\n"); // Move dividend to x0
            try writer.writeAll("    sdiv x0, x0, x1\n"); // Signed divide: x0 = x0 / x1
            try writer.writeAll("    mov x1, x3\n"); // Move saved value back to x1
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

            if (node.left) |left| try codegen(left, writer);
            try writer.writeAll("    mov x2, x0\n");
            if (node.right) |right| try codegen(right, writer);
            try writer.writeAll("    mov x3, x1\n");

            try writer.writeAll("    udiv x4, x2, x0\n");
            try writer.writeAll("    mul x4, x4, x0\n");
            try writer.writeAll("    sub x2, x2, x4\n");

            try writer.writeAll("    mov x0, x2\n");
            try writer.writeAll("    mov x1, x3\n");
        },
        .Statement => {
            // the expression
            if (node.left) |left| try codegen(left, writer);

            // the statement
            if (node.right) |right| try codegen(right, writer);
        },
        .CmdPrintInt => {
            try writer.writeAll("    bl _printInt\n");
        },
        .SayDeclaration => {},
        .Assignment => {},
        .Variable => {},
    }
}
