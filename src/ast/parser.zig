const std = @import("std");
const TToken = @import("../lexer/tokens.zig").TToken;
const EToken = @import("../lexer/tokens.zig").EToken;
const ENode = @import("./node.zig").ENode;
const Node = @import("./node.zig").Node;
const Program = @import("./program.zig").Program;

pub fn parse(tokens: []const TToken, allocator: *const std.mem.Allocator) !*Program {
    var i: usize = 0;

    const Parser = struct {
        tokens: []const TToken,
        i: *usize,
        allocator: *const std.mem.Allocator,

        fn parsePrimary(self: *@This()) !*Node {
            if (self.tokens[self.i.*].type == .Integer) {
                const value = try std.fmt.parseInt(i64, self.tokens[self.i.*].value, 10);
                self.i.* += 1;
                return Node.create(self.allocator, .IntegerLiteral, null, null, value);
            } else if (self.tokens[self.i.*].type == .SayIdentifier) {
                const value = self.tokens[self.i.*].value;
                self.i.* += 1;
                return Node.create(self.allocator, .Variable, null, null, value);
            }
            return error.UnexpectedToken;
        }

        fn parseAdditiveExpression(self: *@This()) !*Node {
            var left = try self.parseMultiplicativeExpression();

            while (self.i.* < self.tokens.len) {
                const tokenType = self.tokens[self.i.*].type;
                if (tokenType != .Add and tokenType != .Sub) break;

                const nodeTokenValue = self.tokens[self.i.*].value;

                self.i.* += 1;
                const right = try self.parseMultiplicativeExpression();
                const nodeType = switch (tokenType) {
                    .Add => ENode.NodeAdd,
                    .Sub => ENode.NodeSub,
                    else => unreachable,
                };

                left = try Node.create(self.allocator, nodeType, left, right, nodeTokenValue);
            }

            return left;
        }

        fn parseMultiplicativeExpression(self: *@This()) !*Node {
            var left = try self.parsePrimary();

            while (self.i.* < self.tokens.len) {
                const tokenType = self.tokens[self.i.*].type;
                if (tokenType != .Mul and tokenType != .Div and tokenType != .Modulo) break;

                const nodeTokenValue = self.tokens[self.i.*].value;

                self.i.* += 1;
                const right = try self.parsePrimary();
                left = try Node.create(self.allocator, switch (tokenType) {
                    .Mul => ENode.NodeMul,
                    .Div => ENode.NodeDiv,
                    else => ENode.NodeModulo,
                }, left, right, nodeTokenValue);
            }

            return left;
        }

        fn parseExpression(self: *@This()) !*Node {
            if (self.i.* >= self.tokens.len) {
                return error.UnexpectedEndOfFile;
            }
            return self.parseAdditiveExpression();
        }

        fn parseCmdPrintInt(self: *@This()) !?*Node {
            if (self.tokens[self.i.*].type == .CmdPrintInt) {
                self.i.* += 1;
                const expression = try self.parseExpression();
                return Node.create(self.allocator, .CmdPrintInt, expression, null, self.tokens[self.i.* - 1].value);
            }
            return null;
        }

        fn parseVariableDeclaration(self: *@This()) !*Node {
            if (self.tokens[self.i.*].type != .VariableDeclaration) {
                return error.ExpectedVarDeclaration;
            }
            self.i.* += 1;

            if (self.tokens[self.i.*].type != .SayIdentifier) {
                return error.ExpectedIdentifier;
            }

            const varName = self.tokens[self.i.*].value;
            self.i.* += 1;

            if (self.tokens[self.i.*].type != .Assignment) {
                return error.ExpectedAssignment;
            }
            self.i.* += 1;

            const expression = try self.parseExpression();
            return Node.create(self.allocator, .SayDeclaration, expression, null, varName);
        }

        fn parseAssignment(self: *@This()) !*Node {
            const varName = self.tokens[self.i.*].value;
            self.i.* += 1;

            if (self.tokens[self.i.*].type != .Assignment) {
                return error.UnexpectedAssignment;
            }
            self.i.* += 1;

            const expression = try self.parseExpression();
            return Node.create(self.allocator, .Assignment, expression, null, varName);
        }

        fn parseStatement(self: *@This()) !*Node {
            var stmt: *Node = undefined;
            switch (self.tokens[self.i.*].type) {
                .VariableDeclaration => stmt = try self.parseVariableDeclaration(),
                .CmdPrintInt => stmt = try self.parseCmdPrintInt() orelse return error.UnexpectedToken,
                .SayIdentifier => {
                    if (self.i.* + 1 < self.tokens.len and self.tokens[self.i.* + 1].type == .Assignment) {
                        stmt = try self.parseAssignment();
                    } else {
                        stmt = try self.parseExpression();
                    }
                },
                else => stmt = try self.parseExpression(),
            }

            return stmt;
        }

        fn parseProgram(self: *@This()) !*Program {
            const program = try Program.create(self.allocator);

            while (self.i.* < self.tokens.len and self.tokens[self.i.*].type != .EOF) {
                const stmt = try self.parseStatement();
                try program.statements.append(stmt);

                // Check for EOS
                if (self.i.* < self.tokens.len) {
                    if (self.tokens[self.i.*].type == .EOS) {
                        self.i.* += 1;
                    } else if (self.tokens[self.i.*].type != .EOF) {
                        return error.ExpectedEndOfStatement;
                    }
                }
            }

            return program;
        }
    };

    var parser = Parser{ .tokens = tokens, .i = &i, .allocator = allocator };

    return try parser.parseProgram();
}
