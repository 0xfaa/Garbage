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
            } else if (self.tokens[self.i.*].type == .LParen) {
                self.i.* += 1;
                const expression = try self.parseExpression();
                if (self.tokens[self.i.*].type != .RParen) {
                    return error.ExpectedRightParen;
                }
                self.i.* += 1;
                return expression;
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

        fn parseExpression(self: *@This()) anyerror!*Node {
            if (self.i.* >= self.tokens.len) {
                return error.UnexpectedEndOfFile;
            }

            if (self.tokens[self.i.*].type == .CmdPrintInt) {
                const printIntNode = try self.parseCmdPrintInt();
                return printIntNode orelse return error.UnexpectedToken;
            }

            return self.parseAdditiveExpression() catch |err| switch (err) {
                error.UnexpectedToken => return self.parsePrimary(),
                else => return err,
            };
        }

        fn parseCmdPrintInt(self: *@This()) anyerror!?*Node {
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
            errdefer self.allocator.destroy(expression);

            const varDeclNode = try Node.create(self.allocator, .SayDeclaration, expression, null, varName);
            return varDeclNode;
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

        fn parseIfStatement(self: *@This()) anyerror!*Node {
            if (self.tokens[self.i.*].type != .If) {
                return error.ExpectedIfKeyword;
            }
            self.i.* += 1;

            const condition = try self.parseExpression();
            errdefer self.allocator.destroy(condition);

            if (self.tokens[self.i.*].type != .LBrace) {
                return error.ExpectedLeftBrace;
            }
            self.i.* += 1;

            const block = try self.parseBlockStatement();
            errdefer self.allocator.destroy(block);

            const ifNode = try Node.create(self.allocator, .IfStatement, condition, block, null);
            return ifNode;
        }

        fn parseBlockStatement(self: *@This()) anyerror!*Node {
            var statements = std.ArrayList(*Node).init(self.allocator.*);
            defer {
                for (statements.items) |node| {
                    self.allocator.destroy(node);
                }
                statements.deinit();
            }

            while (self.tokens[self.i.*].type == .EOS) {
                self.i.* += 1;
            }

            while (self.tokens[self.i.*].type != .RBrace) {
                const stmt = try self.parseStatement();
                errdefer self.allocator.destroy(stmt);
                try statements.append(stmt);

                while (self.tokens[self.i.*].type == .EOS) {
                    self.i.* += 1;
                }
            }

            self.i.* += 1;

            const nodes = try statements.toOwnedSlice();
            const blockNode = try Node.create(self.allocator, .BlockStatement, null, null, nodes);
            return blockNode;
        }

        fn parseStatement(self: *@This()) !*Node {
            var stmt: *Node = undefined;
            switch (self.tokens[self.i.*].type) {
                .VariableDeclaration => stmt = try self.parseVariableDeclaration(),
                .CmdPrintInt => stmt = try self.parseCmdPrintInt() orelse return error.UnexpectedToken,
                .If => stmt = try self.parseIfStatement(),
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
            errdefer program.deinit(self.allocator);

            while (self.i.* < self.tokens.len and self.tokens[self.i.*].type != .EOF) {
                // Skip over empty lines
                while (self.i.* < self.tokens.len and self.tokens[self.i.*].type == .EOS) {
                    self.i.* += 1;
                }

                // Check if we've reached the end of the file
                if (self.i.* >= self.tokens.len or self.tokens[self.i.*].type == .EOF) {
                    break;
                }

                const stmt = try self.parseStatement();
                errdefer self.allocator.destroy(stmt);
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
