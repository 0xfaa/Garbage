const std = @import("std");

const TokenType = enum { Integer, Add, Multiply, CmdPrintInt, EOF };
const Token = struct { type: TokenType, value: []const u8 };

const NodeType = enum {
    IntegerLiteral,
    Addition,
    Multiplication,
    CmdPrintInt,
    Statement,
};

const Node = struct {
    type: NodeType,
    left: ?*Node,
    right: ?*Node,
    value: union(enum) {
        integer: i64,
        str: []const u8,
    },

    fn create(allocator: *const std.mem.Allocator, node_type: NodeType, left: ?*Node, right: ?*Node, value: anytype) !*Node {
        const node = try allocator.create(Node);
        node.* = .{
            .type = node_type,
            .left = left,
            .right = right,
            .value = switch (@TypeOf(value)) {
                i64 => .{ .integer = value },
                []const u8 => .{ .str = value },
                else => @compileError("Unsupported value type: " ++ @typeName(@TypeOf(value))),
            },
        };
        return node;
    }

    // Recursively deinits the node & runs the same command on children.
    fn deinit(self: *Node, allocator: *const std.mem.Allocator) void {
        if (self.left) |left| {
            left.deinit(allocator);
        }
        if (self.right) |right| {
            right.deinit(allocator);
        }
        allocator.destroy(self);
    }

    fn print(self: *@This(), pad: i64, modif: []const u8) !void {
        var i: i64 = 0;
        while (i < pad) : (i += 1) {
            std.debug.print(" ", .{});
        }

        std.debug.print("{s} [{s}]", .{ modif, @tagName(self.type) });

        switch (self.value) {
            .integer => |int| std.debug.print(" = {d}\n", .{int}),
            .str => |str| std.debug.print(" = {s}\n", .{str}),
        }

        if (self.left) |left| {
            try left.print(pad + 1, "l");
        }
        if (self.right) |right| {
            try right.print(pad + 1, "r");
        }
    }
};

fn lexer(input: []const u8, allocator: *const std.mem.Allocator) !std.ArrayList(Token) {
    var tokens = std.ArrayList(Token).init(allocator.*);
    var i: usize = 0;
    while (i < input.len) : (i += 1) {
        const c = input[i];
        switch (c) {
            '0'...'9' => {
                const start = i;
                while (i < input.len and std.ascii.isDigit(input[i])) : (i += 1) {}
                try tokens.append(.{ .type = TokenType.Integer, .value = input[start..i] });
                i -= 1;
            },
            '+' => try tokens.append(.{ .type = TokenType.Add, .value = "+" }),
            '*' => try tokens.append(.{ .type = TokenType.Multiply, .value = "*" }),
            // @printInt
            '@' => {
                if (input.len >= i + 8 and std.mem.eql(u8, input[i .. i + 8], "@printInt")) {
                    std.debug.print("i+9: {s}\n", .{input[i .. i + 9]});
                }
                try tokens.append(.{ .type = TokenType.CmdPrintInt, .value = "" });
                i += 9;
            },
            ' ', '\t', '\n' => {},
            else => return error.InvalidCharacter,
        }
    }

    try tokens.append(.{ .type = TokenType.EOF, .value = "" });
    return tokens;
}

// Convert a string into an AST tree.
fn parse(tokens: []const Token, allocator: *const std.mem.Allocator) !*Node {
    var i: usize = 0;

    const Parser = struct {
        tokens: []const Token,
        i: *usize,
        allocator: *const std.mem.Allocator,

        fn parsePrimary(self: *@This()) !*Node {
            if (self.tokens[self.i.*].type == .Integer) {
                const value = try std.fmt.parseInt(i64, self.tokens[self.i.*].value, 10);
                self.i.* += 1;
                return Node.create(self.allocator, .IntegerLiteral, null, null, value);
            }
            return error.UnexpectedToken;
        }

        fn parseExpression(self: *@This()) !*Node {
            var left = try self.parsePrimary();

            while (self.i.* < self.tokens.len - 1) {
                const tokenType = self.tokens[self.i.*].type;

                const isArithmeticToken: bool = switch (tokenType) {
                    .Add => true,
                    .Multiply => true,
                    else => false,
                };

                std.debug.print("Token type: {}, Is arithmetic token: {}\n", .{ tokenType, isArithmeticToken });

                if (!isArithmeticToken) break;

                self.i.* += 1;
                const right = try self.parsePrimary();
                const value = self.tokens[self.i.* - 2].value;
                left = try Node.create(self.allocator, switch (tokenType) {
                    .Add => NodeType.Addition,
                    .Multiply => NodeType.Multiplication,
                    else => NodeType.Addition,
                }, left, right, value);
            }
            return left;
        }

        fn parseCmdPrintInt(self: *@This()) !?*Node {
            if (self.tokens[self.i.*].type == .CmdPrintInt) {
                self.i.* += 1;
                return Node.create(self.allocator, .CmdPrintInt, null, null, self.tokens[self.i.*].value);
            }
            return null;
        }

        fn parseStatement(self: *@This()) !*Node {
            const right = try self.parseCmdPrintInt();
            const left = try self.parseExpression();
            if (right != null) {
                return Node.create(self.allocator, .Statement, left, right, self.tokens[self.i.*].value);
            }
            return left;
        }
    };

    var parser = Parser{ .tokens = tokens, .i = &i, .allocator = allocator };

    return parser.parseStatement();
}

fn codegen(node: *Node, writer: anytype) !void {
    switch (node.type) {
        .IntegerLiteral => try writer.print("    mov x0, #{}\n", .{node.value.integer}),
        .Addition => {
            if (node.left) |left| try codegen(left, writer);
            try writer.writeAll("    mov x1, x0\n");
            if (node.right) |right| try codegen(right, writer);
            try writer.writeAll("    add x0, x1, x0\n");
        },
        .Multiplication => {
            if (node.left) |left| try codegen(left, writer);
            try writer.writeAll("    mov x1, x0\n");
            if (node.right) |right| try codegen(right, writer);
            try writer.writeAll("    mul x0, x1, x0\n");
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
    }
}

pub fn compile(code: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const tokens = try lexer(code, &allocator);
    defer tokens.deinit();
    for (tokens.items) |t| {
        std.debug.print("token: type = {} | value = {s}\n", .{ t.type, t.value });
    }

    const ast = try parse(tokens.items, &allocator);
    defer ast.deinit(&allocator);
    try ast.print(1, "root");

    var asm_code = std.ArrayList(u8).init(allocator);
    defer asm_code.deinit();

    try asm_code.appendSlice(
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
        \\ _printInt:
        \\ stp x30, x29, [sp, #-16]!
        \\ mov x29, sp
        \\ sub sp, sp, #21
        \\ mov x1, sp
        \\ bl _itoa
        \\ mov w0, #10
        \\ strb w0, [x1, x2]
        \\ add x2, x2, #1
        \\ mov x0, #0        ; stdout file descriptor (0)
        \\ mov x16, #4       ; write call (4)
        \\ svc 0
        \\ add sp, sp, #21
        \\ ldp x30, x29, [sp], #16
        \\ ret
        \\
        \\_main:
        \\
    );
    try codegen(ast, asm_code.writer());
    try asm_code.appendSlice(
        \\
        \\_terminate:
        \\    mov x0, #0  // Exit syscall number
        \\    mov x16, #1 // Terminate syscall
        \\    svc 0       // Trigger syscall
        \\
    );

    return try allocator.dupe(u8, asm_code.items);
}
