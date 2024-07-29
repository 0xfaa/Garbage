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

        fn parseBasicPrimary(self: *@This()) !*Node {
            switch (self.tokens[self.i.*].type) {
                .Integer => {
                    const value = try std.fmt.parseInt(i64, self.tokens[self.i.*].value, 10);
                    self.i.* += 1;
                    return Node.create(self.allocator, .IntegerLiteral, null, null, null, value);
                },
                .SayIdentifier => {
                    const value = self.tokens[self.i.*].value;
                    self.i.* += 1;
                    return Node.create(self.allocator, .Variable, null, null, null, value);
                },
                .LParen => {
                    self.i.* += 1;
                    const expression = try self.parseExpression();
                    if (self.tokens[self.i.*].type != .RParen) {
                        return error.ExpectedRightParen;
                    }
                    self.i.* += 1;
                    return expression;
                },
                .Ampersand => {
                    self.i.* += 1;
                    const expr = try self.parseBasicPrimary();
                    return Node.create(self.allocator, .AddressOf, expr, null, null, @as(i64, 0));
                },
                .LBrace => {
                    return try self.parseArrayInitialization();
                },
                else => {
                    std.debug.print("Unexpected token: {s}\n", .{@tagName(self.tokens[self.i.*].type)});
                    return error.UnexpectedToken;
                },
            }
        }

        fn parsePostfixOperations(self: *@This(), expr: *Node) !*Node {
            var result = expr;
            while (self.i.* < self.tokens.len) {
                switch (self.tokens[self.i.*].type) {
                    .Dereference => {
                        self.i.* += 1;
                        result = try Node.create(self.allocator, .Dereference, result, null, null, @as(i64, 0));
                    },
                    .LSquareBracket => {
                        self.i.* += 1;
                        const index = try self.parseExpression();
                        if (self.tokens[self.i.*].type != .RSquareBracket) {
                            return error.ExpectedRightSquareBracket;
                        }
                        self.i.* += 1;
                        result = try Node.create(self.allocator, .ArrayIndex, result, index, null, @as(i64, 0));
                    },
                    else => break,
                }
            }
            return result;
        }

        fn parsePrimary(self: *@This()) !*Node {
            const expr = try self.parseBasicPrimary();
            return try self.parsePostfixOperations(expr);
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

                left = try Node.create(self.allocator, nodeType, left, right, null, nodeTokenValue);
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
                }, left, right, null, nodeTokenValue);
            }

            return left;
        }

        fn parseComparisonExpression(self: *@This()) !*Node {
            var left = try self.parseAdditiveExpression();

            while (self.i.* < self.tokens.len) {
                const tokenType = self.tokens[self.i.*].type;
                if (tokenType != .Equal and tokenType != .Less and tokenType != .Greater and tokenType != .NotEqual) break;

                const nodeTokenValue = self.tokens[self.i.*].value;

                self.i.* += 1;
                const right = try self.parseAdditiveExpression();
                const nodeType = switch (tokenType) {
                    .Equal => ENode.NodeEqual,
                    .Less => ENode.NodeLess,
                    .Greater => ENode.NodeGreater,
                    .NotEqual => ENode.NodeNotEqual,
                    else => unreachable,
                };

                left = try Node.create(self.allocator, nodeType, left, right, null, nodeTokenValue);
            }

            return left;
        }

        fn parseArrayInitialization(self: *@This()) !*Node {
            std.debug.print("Parsing array initialization\n", .{});
            self.i.* += 1; // Skip the opening brace
            var elements = std.ArrayList(*Node).init(self.allocator.*);
            errdefer {
                for (elements.items) |elem| elem.deinit(self.allocator);
                elements.deinit();
            }

            while (self.i.* < self.tokens.len and self.tokens[self.i.*].type != .RBrace) {
                const element = try self.parseExpression();
                try elements.append(element);

                if (self.tokens[self.i.*].type == .Comma) {
                    self.i.* += 1;
                } else if (self.tokens[self.i.*].type != .RBrace) {
                    return error.ExpectedCommaOrRBrace;
                }
            }

            if (self.i.* >= self.tokens.len or self.tokens[self.i.*].type != .RBrace) {
                return error.ExpectedRBrace;
            }
            self.i.* += 1; // Skip the closing brace

            return Node.create(self.allocator, .ArrayInitialization, null, null, null, try elements.toOwnedSlice());
        }

        fn parseExpression(self: *@This()) anyerror!*Node {
            std.debug.print("Parsing expression\n", .{});
            if (self.i.* >= self.tokens.len) {
                return error.UnexpectedEndOfFile;
            }

            if (self.tokens[self.i.*].type == .CmdPrintInt) {
                return try self.parseCmdPrintInt() orelse return error.UnexpectedToken;
            }

            if (self.tokens[self.i.*].type == .LBrace) {
                return try self.parseArrayInitialization();
            }

            var expr = try self.parseComparisonExpression();
            expr = try self.parsePostfixOperations(expr);

            if (self.i.* < self.tokens.len and self.tokens[self.i.*].type == .Assignment) {
                self.i.* += 1;
                const right = try self.parseExpression();
                expr = try Node.create(self.allocator, .Assignment, expr, right, null, @as(i64, 0));
            }

            return expr;
        }

        fn parseCmdPrintChar(self: *@This()) anyerror!?*Node {
            if (self.tokens[self.i.*].type == .CmdPrintChar) {
                self.i.* += 1;
                const expression = try self.parseExpression();
                return Node.create(self.allocator, .CmdPrintChar, expression, null, null, self.tokens[self.i.* - 1].value);
            }
            return null;
        }

        fn parseCmdPrintInt(self: *@This()) anyerror!?*Node {
            if (self.tokens[self.i.*].type == .CmdPrintInt) {
                self.i.* += 1;
                const expression = try self.parseExpression();
                return Node.create(self.allocator, .CmdPrintInt, expression, null, null, self.tokens[self.i.* - 1].value);
            }
            return null;
        }

        fn parseCmdPrintBuf(self: *@This()) anyerror!?*Node {
            if (self.tokens[self.i.*].type == .CmdPrintBuf) {
                self.i.* += 1;

                // Parse the first argument (pointer)
                const pointer_expr = try self.parseExpression();

                // Expect a comma
                if (self.tokens[self.i.*].type != .Comma) return error.ExpectedComma;
                self.i.* += 1;

                // Parse the second argument (number of chars)
                const count_expr = try self.parseExpression();

                // Create a new node for CmdPrintBuf
                return Node.create(self.allocator, .CmdPrintBuf, pointer_expr, count_expr, null, self.tokens[self.i.* - 1].value);
            }
            return null;
        }

        fn parseType(self: *@This()) !*Node {
            if (self.tokens[self.i.*].type == .LSquareBracket) {
                self.i.* += 1; // Skip '['
                const size_node = try self.parseExpression();
                if (self.tokens[self.i.*].type != .RSquareBracket) {
                    return error.ExpectedRightSquareBracket;
                }
                self.i.* += 1; // Skip ']'
                const element_type = try self.parseType();
                return Node.create(self.allocator, .ArrayType, size_node, element_type, null, @as(i64, 0)); // Use a dummy integer value
            } else if (self.tokens[self.i.*].type == .Mul) {
                self.i.* += 1;
                const baseType = try self.parseType();
                return Node.create(self.allocator, .PointerType, baseType, null, null, @as([]const u8, ""));
            } else if (self.tokens[self.i.*].type == .TypeDeclaration) {
                const typeValue = self.tokens[self.i.*].value;
                self.i.* += 1;
                return Node.create(self.allocator, .Type, null, null, null, typeValue);
            }
            return error.ExpectedType;
        }

        fn typeNodeToString(self: *@This(), typeNode: *Node) ![]const u8 {
            var builder = std.ArrayList(u8).init(self.allocator.*);
            errdefer builder.deinit();

            switch (typeNode.type) {
                .Type => {
                    try builder.appendSlice(typeNode.value.str);
                },
                .PointerType => {
                    try builder.appendSlice("*");
                    if (typeNode.left) |node| {
                        const inner_type = try self.typeNodeToString(node);
                        defer self.allocator.free(inner_type);
                        try builder.appendSlice(inner_type);
                    } else {
                        return error.InvalidTypeNode;
                    }
                },
                .ArrayType => {
                    try builder.appendSlice("[");
                    if (typeNode.left) |size_node| {
                        if (size_node.type == .IntegerLiteral) {
                            const size_str = try std.fmt.allocPrint(self.allocator.*, "{d}", .{size_node.value.integer});
                            defer self.allocator.free(size_str);
                            try builder.appendSlice(size_str);
                        } else {
                            return error.InvalidArraySize;
                        }
                    } else {
                        return error.InvalidTypeNode;
                    }
                    try builder.appendSlice("]");
                    if (typeNode.right) |element_type| {
                        const inner_type = try self.typeNodeToString(element_type);
                        defer self.allocator.free(inner_type);
                        try builder.appendSlice(inner_type);
                    } else {
                        return error.InvalidTypeNode;
                    }
                },
                else => return error.InvalidTypeNode,
            }
            return builder.toOwnedSlice();
        }

        fn parseVariableDeclaration(self: *@This()) !*Node {
            std.debug.print("Parsing variable declaration\n", .{});
            if (self.tokens[self.i.*].type != .VariableDeclaration) {
                return error.ExpectedVarDeclaration;
            }
            self.i.* += 1;

            if (self.tokens[self.i.*].type != .SayIdentifier) {
                return error.ExpectedIdentifier;
            }

            const varName = self.tokens[self.i.*].value;
            self.i.* += 1;

            if (self.tokens[self.i.*].type != .Colon) {
                return error.ExpectedColon;
            }
            self.i.* += 1;

            const typeNode = try self.parseType();
            defer typeNode.deinit(self.allocator);

            const typeStr = try self.typeNodeToString(typeNode);
            defer self.allocator.free(typeStr);

            if (self.tokens[self.i.*].type != .Assignment) {
                return error.ExpectedAssignment;
            }
            self.i.* += 1;

            const expression = try self.parseExpression();
            std.debug.print("Parsed expression for variable declaration\n", .{});

            return Node.createVariableDecl(self.allocator, .SayDeclaration, expression, null, null, varName, typeStr);
        }

        fn parseAssignment(self: *@This()) !*Node {
            const varNode = try Node.create(self.allocator, .Variable, null, null, null, self.tokens[self.i.*].value);
            self.i.* += 1;

            if (self.tokens[self.i.*].type != .Assignment) {
                return error.UnexpectedAssignment;
            }
            self.i.* += 1;

            const expression = try self.parseExpression();
            return Node.create(self.allocator, .Assignment, varNode, expression, null, null);
        }

        fn parseIfStatement(self: *@This()) anyerror!*Node {
            if (self.tokens[self.i.*].type != .If) {
                return error.ExpectedIfKeyword;
            }
            self.i.* += 1;

            const condition = try self.parseExpression();
            errdefer self.allocator.destroy(condition);

            if (self.i.* >= self.tokens.len or self.tokens[self.i.*].type != .LBrace) {
                return error.ExpectedLeftBrace;
            }
            self.i.* += 1;

            const block = try self.parseBlockStatement();
            errdefer self.allocator.destroy(block);

            return try Node.create(self.allocator, .IfStatement, condition, block, null, null);
        }

        fn parseBlockStatement(self: *@This()) anyerror!*Node {
            var statements = std.ArrayList(*Node).init(self.allocator.*);
            errdefer {
                for (statements.items) |stmt| stmt.deinit(self.allocator);
                statements.deinit();
            }

            while (self.i.* < self.tokens.len and self.tokens[self.i.*].type != .RBrace) {
                if (self.tokens[self.i.*].type == .EOS) {
                    self.i.* += 1;
                    continue;
                }

                const stmt = try self.parseStatement();
                try statements.append(stmt);

                if (self.i.* < self.tokens.len and self.tokens[self.i.*].type == .EOS) {
                    self.i.* += 1;
                }
            }

            if (self.i.* >= self.tokens.len or self.tokens[self.i.*].type != .RBrace) {
                return error.ExpectedRightBrace;
            }
            self.i.* += 1;

            const nodes = try statements.toOwnedSlice();
            const blockNode = try Node.create(self.allocator, .BlockStatement, null, null, null, nodes);
            return blockNode;
        }

        fn parseWhileStatement(self: *@This()) anyerror!*Node {
            if (self.tokens[self.i.*].type != .While) {
                return error.ExpectedWhileKeyword;
            }
            self.i.* += 1;

            const condition = try self.parseExpression();
            errdefer self.allocator.destroy(condition);

            var loop_operation: ?*Node = null;
            if (self.tokens[self.i.*].type == .Colon) {
                self.i.* += 1;
                loop_operation = try self.parseExpression();
            }

            if (self.tokens[self.i.*].type != .LBrace) {
                return error.ExpectedLeftBrace;
            }
            self.i.* += 1;

            if (self.tokens[self.i.*].type == .EOS) {
                self.i.* += 1;
            }

            const block = try self.parseBlockStatement();
            errdefer self.allocator.destroy(block);

            return Node.create(self.allocator, .WhileStatement, condition, block, loop_operation, null);
        }

        fn parseStatement(self: *@This()) !*Node {
            switch (self.tokens[self.i.*].type) {
                .VariableDeclaration => return try self.parseVariableDeclaration(),
                .CmdPrintInt => return (try self.parseCmdPrintInt()) orelse return error.UnexpectedToken,
                .CmdPrintChar => return (try self.parseCmdPrintChar()) orelse return error.UnexpectedToken,
                .CmdPrintBuf => return (try self.parseCmdPrintBuf()) orelse return error.UnexpectedToken,
                .If => return try self.parseIfStatement(),
                .While => return try self.parseWhileStatement(),
                else => return try self.parseExpression(),
            }
        }

        fn parseProgram(self: *@This()) !*Program {
            const program = try Program.create(self.allocator);
            errdefer program.deinit(self.allocator);

            while (self.i.* < self.tokens.len and self.tokens[self.i.*].type != .EOF) {
                std.debug.print("Parsing statement at index {}: {s}\n", .{ self.i.*, @tagName(self.tokens[self.i.*].type) });
                // Skip over empty lines
                while (self.i.* < self.tokens.len and self.tokens[self.i.*].type == .EOS) {
                    self.i.* += 1;
                }

                // Check if we've reached the end of the file
                if (self.i.* >= self.tokens.len or self.tokens[self.i.*].type == .EOF) {
                    break;
                }

                const stmt = try self.parseStatement();
                std.debug.print("Parsed statement: {s}\n", .{@tagName(stmt.type)});
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
