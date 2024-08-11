const std = @import("std");
const TToken = @import("../lexer/tokens.zig").TToken;
const EToken = @import("../lexer/tokens.zig").EToken;
const ENode = @import("./node.zig").ENode;
const Node = @import("./node.zig").Node;
const Program = @import("./program.zig").Program;

const ParseError = error{
    UnexpectedToken,
    ExpectedExpression,
    ExpectedIdentifier,
    ExpectedType,
    ExpectedAssignment,
    ExpectedLeftBrace,
    ExpectedRightBrace,
    ExpectedEndOfStatement,
    ExpectedComma,
    ExpectedRightSquareBracket,
    InvalidArraySize,
    OutOfMemory,
    InvalidIntegerLiteral,
    IntegerOverflow,
    InvalidArgumentCount,
    UnexpectedEndOfInput,
    ExpectedCommaOrRParen,
};

pub fn parse(tokens: []const TToken, allocator: std.mem.Allocator) !*Program {
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();

    var parser = Parser.init(tokens, arena_allocator);
    var program = try parser.parseProgram();

    program.arena = arena;

    return program;
}

const Parser = struct {
    tokens: []const TToken,
    index: usize,
    allocator: std.mem.Allocator,

    fn init(tokens: []const TToken, allocator: std.mem.Allocator) Parser {
        return .{
            .tokens = tokens,
            .index = 0,
            .allocator = allocator,
        };
    }

    fn parseProgram(self: *Parser) ParseError!*Program {
        var program = try Program.create(self.allocator);
        errdefer program.deinit();

        while (self.peek()) |token| {
            switch (token.type) {
                .EOF => break,
                .EOS => self.advance(),
                else => {
                    const stmt = try self.parseStatement();
                    try program.statements.append(stmt);
                    if (self.peek()) |next_token| {
                        if (next_token.type == .EOS) {
                            self.advance();
                        }
                    }
                },
            }
        }

        return program;
    }

    fn parseStatement(self: *Parser) ParseError!*Node {
        const token = self.peek() orelse return ParseError.UnexpectedToken;
        std.debug.print("parseStatement: Current token is {s}\n", .{@tagName(token.type)});
        return switch (token.type) {
            .VariableDeclaration => self.parseVariableDeclaration(),
            .If => self.parseIfStatement(),
            .While => self.parseWhileStatement(),
            .CmdPrintInt, .CmdPrintChar, .CmdPrintBuf => self.parseCommand(),
            .CmdSocketCreate, .CmdSocketBind, .CmdSocketListen, .CmdSocketAccept, .CmdSocketRead, .CmdSocketWrite, .CmdSocketClose => self.parseSocketOperation(),
            .EOS => {
                self.advance();
                return self.parseStatement();
            },
            else => self.parseExpression(),
        };
    }

    fn parseExpression(self: *Parser) ParseError!*Node {
        var left = try self.parsePrimary();
        while (self.peek()) |token| {
            switch (token.type) {
                .Add, .Sub, .Mul, .Div, .Modulo, .Equal, .NotEqual, .Less, .Greater => {
                    self.advance();
                    const right = try self.parsePrimary();
                    left = try self.createBinaryOpNode(token.type, left, right);
                },
                .LSquareBracket => {
                    // Handle array indexing
                    self.advance();
                    const index = try self.parseExpression();
                    if (self.peek()) |next_token| {
                        if (next_token.type != .RSquareBracket) return ParseError.ExpectedRightSquareBracket;
                        self.advance();
                    } else {
                        return ParseError.ExpectedRightSquareBracket;
                    }
                    left = try Node.create(self.allocator, .ArrayIndex, left, index, null, @as(i64, 0));

                    // Check if this is an assignment
                    if (self.peek()) |next_token| {
                        if (next_token.type == .Assignment) {
                            self.advance();
                            const value = try self.parseExpression();
                            left = try Node.create(self.allocator, .Assignment, left, value, null, @as(i64, 0));
                        }
                    }
                },
                .Assignment => {
                    self.advance();
                    const right = try self.parseExpression();
                    return try Node.create(self.allocator, .Assignment, left, right, null, @as(i64, 0));
                },
                else => break,
            }
        }
        return left;
    }

    fn parsePrimary(self: *Parser) ParseError!*Node {
        const token = self.peek() orelse {
            std.debug.print("parsePrimary: Unexpected end of input\n", .{});
            return ParseError.ExpectedExpression;
        };
        std.debug.print("parsePrimary: Current token type is {s}\n", .{@tagName(token.type)});
        return switch (token.type) {
            .Integer => self.parseIntegerLiteral(),
            .SayIdentifier => self.parseVariable(),
            .LParen => self.parseGroupedExpression(),
            .Ampersand => self.parseAddressOf(),
            .LBrace => self.parseArrayInitialization(),
            .StringLiteral => self.parseStringLiteral(),
            .CmdSocketCreate, .CmdSocketBind, .CmdSocketListen, .CmdSocketAccept, .CmdSocketRead, .CmdSocketWrite, .CmdSocketClose => self.parseSocketOperation(),
            else => {
                std.debug.print("parsePrimary: Unexpected token type {s}\n", .{@tagName(token.type)});
                return ParseError.ExpectedExpression;
            },
        };
    }

    fn parseIntegerLiteral(self: *Parser) ParseError!*Node {
        const token = self.peek() orelse return ParseError.UnexpectedToken;
        self.advance();
        const value = std.fmt.parseInt(i64, token.value, 10) catch |err| switch (err) {
            error.InvalidCharacter => return ParseError.InvalidIntegerLiteral,
            error.Overflow => return ParseError.IntegerOverflow,
        };
        return try Node.create(self.allocator, .IntegerLiteral, null, null, null, value);
    }

    fn parseVariable(self: *Parser) ParseError!*Node {
        const token = self.peek() orelse return ParseError.UnexpectedToken;
        self.advance();
        return try Node.create(self.allocator, .Variable, null, null, null, token.value);
    }

    fn parseGroupedExpression(self: *Parser) ParseError!*Node {
        self.advance(); // Consume '('
        const expr = try self.parseExpression();
        if (self.peek()) |token| {
            if (token.type != .RParen) return ParseError.UnexpectedToken;
            self.advance(); // Consume ')'
        } else {
            return ParseError.UnexpectedToken;
        }
        return expr;
    }

    fn parseVariableDeclaration(self: *Parser) ParseError!*Node {
        self.advance(); // Consume 'say'
        const identifier = self.peek() orelse return ParseError.ExpectedIdentifier;
        if (identifier.type != .SayIdentifier) return ParseError.ExpectedIdentifier;
        self.advance();

        if (self.peek()) |token| {
            if (token.type != .Colon) return ParseError.UnexpectedToken;
            self.advance();
        } else {
            return ParseError.UnexpectedToken;
        }

        const type_node = try self.parseType();
        const type_str = try self.typeNodeToString(type_node);

        if (self.peek()) |token| {
            if (token.type != .Assignment) return ParseError.ExpectedAssignment;
            self.advance();
        } else {
            return ParseError.ExpectedAssignment;
        }

        const value = try self.parseExpression();

        return try Node.createVariableDecl(self.allocator, .SayDeclaration, value, null, null, identifier.value, type_str);
    }

    fn parseType(self: *Parser) ParseError!*Node {
        const token = self.peek() orelse return ParseError.ExpectedType;
        switch (token.type) {
            .TypeDeclaration => {
                self.advance();
                return try Node.create(self.allocator, .Type, null, null, null, token.value);
            },
            .LSquareBracket => {
                self.advance();
                const size_node = try self.parseExpression();
                if (self.peek()) |next_token| {
                    if (next_token.type != .RSquareBracket) return ParseError.UnexpectedToken;
                    self.advance();
                } else {
                    return ParseError.UnexpectedToken;
                }
                const element_type = try self.parseType();
                return try Node.create(self.allocator, .ArrayType, size_node, element_type, null, @as(i64, 0));
            },
            .Mul => {
                self.advance();
                const base_type = try self.parseType();
                return try Node.create(self.allocator, .PointerType, base_type, null, null, @as([]const u8, ""));
            },
            else => return ParseError.ExpectedType,
        }
    }

    fn typeNodeToString(self: *Parser, type_node: *Node) ParseError![]const u8 {
        var buffer = std.ArrayList(u8).init(self.allocator);
        errdefer buffer.deinit();

        switch (type_node.type) {
            .Type => try buffer.appendSlice(type_node.value.str),
            .PointerType => {
                try buffer.append('*');
                if (type_node.left) |inner_type| {
                    const inner_str = try self.typeNodeToString(inner_type);
                    defer self.allocator.free(inner_str);
                    try buffer.appendSlice(inner_str);
                }
            },
            .ArrayType => {
                try buffer.append('[');
                if (type_node.left) |size_node| {
                    if (size_node.type == .IntegerLiteral) {
                        const size_str = try std.fmt.allocPrint(self.allocator, "{d}", .{size_node.value.integer});
                        defer self.allocator.free(size_str);
                        try buffer.appendSlice(size_str);
                    } else {
                        return ParseError.InvalidArraySize;
                    }
                }
                try buffer.append(']');
                if (type_node.right) |element_type| {
                    const inner_str = try self.typeNodeToString(element_type);
                    defer self.allocator.free(inner_str);
                    try buffer.appendSlice(inner_str);
                }
            },
            else => return ParseError.ExpectedType,
        }

        return buffer.toOwnedSlice();
    }

    fn parseIfStatement(self: *Parser) ParseError!*Node {
        self.advance(); // Consume 'if'
        const condition = try self.parseExpression();
        const block = try self.parseBlockStatement();
        return try Node.create(self.allocator, .IfStatement, condition, block, null, @as(i64, 0));
    }

    fn parseWhileStatement(self: *Parser) ParseError!*Node {
        self.advance(); // Consume 'while'
        const condition = try self.parseExpression();
        const block = try self.parseBlockStatement();
        return try Node.create(self.allocator, .WhileStatement, condition, block, null, @as(i64, 0));
    }

    fn parseBlockStatement(self: *Parser) ParseError!*Node {
        std.debug.print("parseBlockStatement: Starting\n", .{});
        if (self.peek()) |token| {
            if (token.type != .LBrace) return ParseError.ExpectedLeftBrace;
            self.advance();
        } else {
            return ParseError.ExpectedLeftBrace;
        }

        var statements = std.ArrayList(*Node).init(self.allocator);
        errdefer {
            for (statements.items) |stmt| stmt.deinit(self.allocator);
            statements.deinit();
        }

        while (self.peek()) |token| {
            std.debug.print("parseBlockStatement: Current token is {s}\n", .{@tagName(token.type)});
            if (token.type == .RBrace) break;
            if (token.type == .EOS) {
                self.advance();
                continue;
            }
            const stmt = try self.parseStatement();
            try statements.append(stmt);
        }

        if (self.peek()) |token| {
            if (token.type != .RBrace) return ParseError.ExpectedRightBrace;
            self.advance();
        } else {
            return ParseError.ExpectedRightBrace;
        }

        std.debug.print("parseBlockStatement: Finished\n", .{});
        return try Node.create(self.allocator, .BlockStatement, null, null, null, try statements.toOwnedSlice());
    }

    fn parseCommand(self: *Parser) ParseError!*Node {
        const token = self.peek() orelse return ParseError.UnexpectedToken;
        self.advance();

        switch (token.type) {
            .CmdPrintInt, .CmdPrintChar, .CmdPrintBuf => {
                try self.expectToken(.LParen);
                const args = try self.parseArgumentList();
                try self.expectToken(.RParen);

                const node_type = switch (token.type) {
                    .CmdPrintInt => ENode.CmdPrintInt,
                    .CmdPrintChar => ENode.CmdPrintChar,
                    .CmdPrintBuf => ENode.CmdPrintBuf,
                    else => unreachable,
                };

                if (node_type == .CmdPrintBuf and args.len != 2) {
                    return ParseError.InvalidArgumentCount;
                } else if (node_type != .CmdPrintBuf and args.len != 1) {
                    return ParseError.InvalidArgumentCount;
                }

                if (node_type == .CmdPrintBuf) {
                    return try Node.create(self.allocator, node_type, args[0], args[1], null, token.value);
                } else {
                    return try Node.create(self.allocator, node_type, args[0], null, null, token.value);
                }
            },
            else => return ParseError.UnexpectedToken,
        }
    }

    fn parseSocketOperation(self: *Parser) ParseError!*Node {
        const token = self.peek() orelse return ParseError.UnexpectedToken;
        self.advance();
        std.debug.print("parseSocketOperation: Parsing {s}\n", .{@tagName(token.type)});

        const node_type = switch (token.type) {
            .CmdSocketCreate => ENode.SocketCreate,
            .CmdSocketBind => ENode.SocketBind,
            .CmdSocketListen => ENode.SocketListen,
            .CmdSocketAccept => ENode.SocketAccept,
            .CmdSocketRead => ENode.SocketRead,
            .CmdSocketWrite => ENode.SocketWrite,
            .CmdSocketClose => ENode.SocketClose,
            else => unreachable,
        };

        try self.expectToken(.LParen);
        const args = try self.parseArgumentList();
        try self.expectToken(.RParen);

        switch (node_type) {
            .SocketCreate => {
                if (args.len != 0) return ParseError.InvalidArgumentCount;
                return try Node.create(self.allocator, node_type, null, null, null, @as(i64, 0));
            },
            .SocketAccept, .SocketClose => {
                if (args.len != 1) return ParseError.InvalidArgumentCount;
                return try Node.create(self.allocator, node_type, args[0], null, null, @as(i64, 0));
            },
            .SocketBind, .SocketListen => {
                if (args.len != 2) return ParseError.InvalidArgumentCount;
                return try Node.create(self.allocator, node_type, args[0], args[1], null, @as(i64, 0));
            },
            .SocketRead, .SocketWrite => {
                if (args.len != 3) return ParseError.InvalidArgumentCount;
                return try Node.create(self.allocator, node_type, args[0], args[1], args[2], @as(i64, 0));
            },
            else => unreachable,
        }
    }

    fn parseArgumentList(self: *Parser) ParseError![]const *Node {
        var args = std.ArrayList(*Node).init(self.allocator);
        errdefer {
            for (args.items) |arg| arg.deinit(self.allocator);
            args.deinit();
        }

        while (true) {
            if (self.peek()) |token| {
                if (token.type == .RParen) break;
            } else {
                return ParseError.UnexpectedEndOfInput;
            }

            const arg = try self.parseExpression();
            try args.append(arg);

            if (self.peek()) |token| {
                if (token.type == .Comma) {
                    self.advance();
                } else if (token.type == .RParen) {
                    break;
                } else {
                    return ParseError.ExpectedCommaOrRParen;
                }
            } else {
                return ParseError.UnexpectedEndOfInput;
            }
        }

        return args.toOwnedSlice();
    }

    fn parseArrayInitialization(self: *Parser) ParseError!*Node {
        self.advance(); // Consume '{'
        var elements = std.ArrayList(*Node).init(self.allocator);
        errdefer {
            for (elements.items) |elem| elem.deinit(self.allocator);
            elements.deinit();
        }

        while (self.peek()) |token| {
            if (token.type == .RBrace) break;
            const element = try self.parseExpression();
            try elements.append(element);
            if (self.peek()) |next_token| {
                if (next_token.type == .Comma) {
                    self.advance();
                } else if (next_token.type != .RBrace) {
                    return ParseError.UnexpectedToken;
                }
            }
        }

        if (self.peek()) |token| {
            if (token.type != .RBrace) return ParseError.ExpectedRightBrace;
            self.advance();
        } else {
            return ParseError.ExpectedRightBrace;
        }

        return try Node.create(self.allocator, .ArrayInitialization, null, null, null, try elements.toOwnedSlice());
    }

    fn parseStringLiteral(self: *Parser) ParseError!*Node {
        const token = self.peek() orelse return ParseError.UnexpectedToken;
        self.advance();
        return try Node.create(self.allocator, .StringLiteral, null, null, null, token.value);
    }

    fn createBinaryOpNode(self: *Parser, op: EToken, left: *Node, right: *Node) ParseError!*Node {
        const node_type = switch (op) {
            .Add => ENode.NodeAdd,
            .Sub => ENode.NodeSub,
            .Mul => ENode.NodeMul,
            .Div => ENode.NodeDiv,
            .Modulo => ENode.NodeModulo,
            .Equal => ENode.NodeEqual,
            .NotEqual => ENode.NodeNotEqual,
            .Less => ENode.NodeLess,
            .Greater => ENode.NodeGreater,
            else => return ParseError.UnexpectedToken,
        };
        return try Node.create(self.allocator, node_type, left, right, null, @as(i64, 0));
    }

    fn parseAddressOf(self: *Parser) ParseError!*Node {
        self.advance(); // Consume '&'
        const expr = try self.parsePrimary();
        return try Node.create(self.allocator, .AddressOf, expr, null, null, @as(i64, 0));
    }

    fn parseDereference(self: *Parser) ParseError!*Node {
        self.advance(); // Consume '*'
        const expr = try self.parsePrimary();
        return try Node.create(self.allocator, .Dereference, expr, null, null, @as(i64, 0));
    }

    fn parseArrayIndex(self: *Parser, array: *Node) ParseError!*Node {
        self.advance(); // Consume '['
        const index = try self.parseExpression();
        if (self.peek()) |token| {
            if (token.type != .RSquareBracket) return ParseError.UnexpectedToken;
            self.advance();
        } else {
            return ParseError.UnexpectedToken;
        }
        return try Node.create(self.allocator, .ArrayIndex, array, index, null, @as(i64, 0));
    }

    fn advance(self: *Parser) void {
        if (self.index < self.tokens.len) {
            self.index += 1;
        }
    }

    fn peek(self: *Parser) ?TToken {
        return if (self.index < self.tokens.len) self.tokens[self.index] else null;
    }

    fn expectEndOfStatement(self: *Parser) ParseError!void {
        switch (self.peek() orelse return ParseError.ExpectedEndOfStatement) {
            .EOS => self.advance(),
            .EOF => {},
            else => return ParseError.ExpectedEndOfStatement,
        }
    }

    fn expectToken(self: *Parser, expected: EToken) ParseError!void {
        const token = self.peek() orelse return ParseError.UnexpectedEndOfInput;
        if (token.type != expected) {
            return ParseError.UnexpectedToken;
        }
        self.advance();
    }
};

// pub fn parse(tokens: []const TToken, allocator: *const std.mem.Allocator) !*Program {
//     var i: usize = 0;

//     const Parser = struct {
//         tokens: []const TToken,
//         i: *usize,
//         allocator: *const std.mem.Allocator,

//         fn parseBasicPrimary(self: *@This()) !*Node {
//             switch (self.tokens[self.i.*].type) {
//                 .Integer => {
//                     const value = try std.fmt.parseInt(i64, self.tokens[self.i.*].value, 10);
//                     self.i.* += 1;
//                     return Node.create(self.allocator, .IntegerLiteral, null, null, null, value);
//                 },
//                 .SayIdentifier => {
//                     const value = self.tokens[self.i.*].value;
//                     self.i.* += 1;
//                     return Node.create(self.allocator, .Variable, null, null, null, value);
//                 },
//                 .LParen => {
//                     self.i.* += 1;
//                     const expression = try self.parseExpression();
//                     if (self.tokens[self.i.*].type != .RParen) {
//                         return error.ExpectedRightParen;
//                     }
//                     self.i.* += 1;
//                     return expression;
//                 },
//                 .Ampersand => {
//                     self.i.* += 1;
//                     const expr = try self.parseBasicPrimary();
//                     return Node.create(self.allocator, .AddressOf, expr, null, null, @as(i64, 0));
//                 },
//                 .LBrace => {
//                     return try self.parseArrayInitialization();
//                 },
//                 else => {
//                     return error.UnexpectedToken;
//                 },
//             }
//         }

//         fn parsePostfixOperations(self: *@This(), expr: *Node) !*Node {
//             var result = expr;
//             while (self.i.* < self.tokens.len) {
//                 switch (self.tokens[self.i.*].type) {
//                     .Dereference => {
//                         self.i.* += 1;
//                         result = try Node.create(self.allocator, .Dereference, result, null, null, @as(i64, 0));
//                     },
//                     .LSquareBracket => {
//                         self.i.* += 1;
//                         const index = try self.parseExpression();
//                         if (self.tokens[self.i.*].type != .RSquareBracket) {
//                             return error.ExpectedRightSquareBracket;
//                         }
//                         self.i.* += 1;
//                         result = try Node.create(self.allocator, .ArrayIndex, result, index, null, @as(i64, 0));
//                     },
//                     else => break,
//                 }
//             }
//             return result;
//         }

//         fn parsePrimary(self: *@This()) !*Node {
//             const expr = try self.parseBasicPrimary();
//             return try self.parsePostfixOperations(expr);
//         }

//         fn parseAdditiveExpression(self: *@This()) !*Node {
//             var left = try self.parseMultiplicativeExpression();

//             while (self.i.* < self.tokens.len) {
//                 const tokenType = self.tokens[self.i.*].type;
//                 if (tokenType != .Add and tokenType != .Sub) break;

//                 const nodeTokenValue = self.tokens[self.i.*].value;

//                 self.i.* += 1;
//                 const right = try self.parseMultiplicativeExpression();
//                 const nodeType = switch (tokenType) {
//                     .Add => ENode.NodeAdd,
//                     .Sub => ENode.NodeSub,
//                     else => unreachable,
//                 };

//                 left = try Node.create(self.allocator, nodeType, left, right, null, nodeTokenValue);
//             }

//             return left;
//         }

//         fn parseMultiplicativeExpression(self: *@This()) !*Node {
//             var left = try self.parsePrimary();

//             while (self.i.* < self.tokens.len) {
//                 const tokenType = self.tokens[self.i.*].type;
//                 if (tokenType != .Mul and tokenType != .Div and tokenType != .Modulo) break;

//                 const nodeTokenValue = self.tokens[self.i.*].value;

//                 self.i.* += 1;
//                 const right = try self.parsePrimary();
//                 left = try Node.create(self.allocator, switch (tokenType) {
//                     .Mul => ENode.NodeMul,
//                     .Div => ENode.NodeDiv,
//                     else => ENode.NodeModulo,
//                 }, left, right, null, nodeTokenValue);
//             }

//             return left;
//         }

//         fn parseComparisonExpression(self: *@This()) !*Node {
//             var left = try self.parseAdditiveExpression();

//             while (self.i.* < self.tokens.len) {
//                 const tokenType = self.tokens[self.i.*].type;
//                 if (tokenType != .Equal and tokenType != .Less and tokenType != .Greater and tokenType != .NotEqual) break;

//                 const nodeTokenValue = self.tokens[self.i.*].value;

//                 self.i.* += 1;
//                 const right = try self.parseAdditiveExpression();
//                 const nodeType = switch (tokenType) {
//                     .Equal => ENode.NodeEqual,
//                     .Less => ENode.NodeLess,
//                     .Greater => ENode.NodeGreater,
//                     .NotEqual => ENode.NodeNotEqual,
//                     else => unreachable,
//                 };

//                 left = try Node.create(self.allocator, nodeType, left, right, null, nodeTokenValue);
//             }

//             return left;
//         }

//         fn parseArrayInitialization(self: *@This()) !*Node {
//             if (self.tokens[self.i.*].type == .StringLiteral) {
//                 const str_value = self.tokens[self.i.*].value;
//                 self.i.* += 1;
//                 return Node.create(self.allocator, .StringLiteral, null, null, null, str_value);
//             }

//             self.i.* += 1; // Skip the opening brace
//             var elements = std.ArrayList(*Node).init(self.allocator.*);
//             errdefer {
//                 for (elements.items) |elem| elem.deinit(self.allocator);
//                 elements.deinit();
//             }

//             while (self.i.* < self.tokens.len and self.tokens[self.i.*].type != .RBrace) {
//                 const element = try self.parseExpression();
//                 try elements.append(element);

//                 if (self.tokens[self.i.*].type == .Comma) {
//                     self.i.* += 1;
//                 } else if (self.tokens[self.i.*].type != .RBrace) {
//                     return error.ExpectedCommaOrRBrace;
//                 }
//             }

//             if (self.i.* >= self.tokens.len or self.tokens[self.i.*].type != .RBrace) {
//                 return error.ExpectedRBrace;
//             }
//             self.i.* += 1; // Skip the closing brace

//             return Node.create(self.allocator, .ArrayInitialization, null, null, null, try elements.toOwnedSlice());
//         }

//         fn parseExpression(self: *@This()) anyerror!*Node {
//             if (self.i.* >= self.tokens.len) {
//                 return error.UnexpectedEndOfFile;
//             }

//             if (self.tokens[self.i.*].type == .CmdPrintInt) {
//                 return try self.parseCmdPrintInt() orelse return error.UnexpectedToken;
//             }

//             if (self.tokens[self.i.*].type == .CmdSocketCreate) {
//                 return try self.parseSocketCreate();
//             }

//             if (self.tokens[self.i.*].type == .CmdSocketAccept) {
//                 return try self.parseSocketAccept();
//             }

//             if (self.tokens[self.i.*].type == .LBrace) {
//                 return try self.parseArrayInitialization();
//             }

//             var expr = try self.parseComparisonExpression();
//             expr = try self.parsePostfixOperations(expr);

//             if (self.i.* < self.tokens.len and self.tokens[self.i.*].type == .Assignment) {
//                 self.i.* += 1;
//                 const right = try self.parseExpression();

//                 // Check if the left side is an ArrayIndex node
//                 if (expr.type == .ArrayIndex) {
//                     // Create an Assignment node with the ArrayIndex as the left child
//                     return try Node.create(self.allocator, .Assignment, expr, right, null, @as(i64, 0));
//                 } else {
//                     // For regular assignments
//                     return try Node.create(self.allocator, .Assignment, expr, right, null, @as(i64, 0));
//                 }
//             }

//             return expr;
//         }

//         fn parseCmdPrintChar(self: *@This()) anyerror!?*Node {
//             if (self.tokens[self.i.*].type == .CmdPrintChar) {
//                 self.i.* += 1;
//                 const expression = try self.parseExpression();
//                 return Node.create(self.allocator, .CmdPrintChar, expression, null, null, self.tokens[self.i.* - 1].value);
//             }
//             return null;
//         }

//         fn parseCmdPrintInt(self: *@This()) anyerror!?*Node {
//             if (self.tokens[self.i.*].type == .CmdPrintInt) {
//                 self.i.* += 1;
//                 const expression = try self.parseExpression();
//                 return Node.create(self.allocator, .CmdPrintInt, expression, null, null, self.tokens[self.i.* - 1].value);
//             }
//             return null;
//         }

//         fn parseCmdPrintBuf(self: *@This()) anyerror!?*Node {
//             if (self.tokens[self.i.*].type == .CmdPrintBuf) {
//                 self.i.* += 1;

//                 // Parse the first argument (pointer)
//                 const pointer_expr = try self.parseExpression();

//                 // Expect a comma
//                 if (self.tokens[self.i.*].type != .Comma) return error.ExpectedComma;
//                 self.i.* += 1;

//                 // Parse the second argument (number of chars)
//                 const count_expr = try self.parseExpression();

//                 // Create a new node for CmdPrintBuf
//                 return Node.create(self.allocator, .CmdPrintBuf, pointer_expr, count_expr, null, self.tokens[self.i.* - 1].value);
//             }
//             return null;
//         }

//         fn parseType(self: *@This()) !*Node {
//             if (self.tokens[self.i.*].type == .LSquareBracket) {
//                 self.i.* += 1; // Skip '['
//                 var size_node: ?*Node = null;
//                 if (self.tokens[self.i.*].type != .RSquareBracket) {
//                     size_node = try self.parseExpression();
//                 }
//                 if (self.tokens[self.i.*].type != .RSquareBracket) {
//                     return error.ExpectedRightSquareBracket;
//                 }
//                 self.i.* += 1; // Skip ']'
//                 const element_type = try self.parseType();
//                 return Node.create(self.allocator, .ArrayType, size_node, element_type, null, @as(i64, 0)); // Use a dummy integer value
//             } else if (self.tokens[self.i.*].type == .Mul) {
//                 self.i.* += 1;
//                 const baseType = try self.parseType();
//                 return Node.create(self.allocator, .PointerType, baseType, null, null, @as([]const u8, ""));
//             } else if (self.tokens[self.i.*].type == .TypeDeclaration) {
//                 const typeValue = self.tokens[self.i.*].value;
//                 self.i.* += 1;
//                 return Node.create(self.allocator, .Type, null, null, null, typeValue);
//             }
//             return error.ExpectedType;
//         }

//         fn typeNodeToString(self: *@This(), typeNode: *Node) ![]const u8 {
//             var builder = std.ArrayList(u8).init(self.allocator.*);
//             errdefer builder.deinit();

//             switch (typeNode.type) {
//                 .Type => {
//                     try builder.appendSlice(typeNode.value.str);
//                 },
//                 .PointerType => {
//                     try builder.appendSlice("*");
//                     if (typeNode.left) |node| {
//                         const inner_type = try self.typeNodeToString(node);
//                         defer self.allocator.free(inner_type);
//                         try builder.appendSlice(inner_type);
//                     } else {
//                         return error.InvalidTypeNode;
//                     }
//                 },
//                 .ArrayType => {
//                     try builder.appendSlice("[");
//                     if (typeNode.left) |size_node| {
//                         if (size_node.type == .IntegerLiteral) {
//                             const size_str = try std.fmt.allocPrint(self.allocator.*, "{d}", .{size_node.value.integer});
//                             defer self.allocator.free(size_str);
//                             try builder.appendSlice(size_str);
//                         } else {
//                             return error.InvalidArraySize;
//                         }
//                     } else {
//                         return error.InvalidTypeNode;
//                     }
//                     try builder.appendSlice("]");
//                     if (typeNode.right) |element_type| {
//                         const inner_type = try self.typeNodeToString(element_type);
//                         defer self.allocator.free(inner_type);
//                         try builder.appendSlice(inner_type);
//                     } else {
//                         return error.InvalidTypeNode;
//                     }
//                 },
//                 else => return error.InvalidTypeNode,
//             }
//             return builder.toOwnedSlice();
//         }

//         fn parseVariableDeclaration(self: *@This()) !*Node {
//             if (self.tokens[self.i.*].type != .VariableDeclaration) {
//                 return error.ExpectedVarDeclaration;
//             }
//             self.i.* += 1;

//             if (self.tokens[self.i.*].type != .SayIdentifier) {
//                 return error.ExpectedIdentifier;
//             }

//             const varName = self.tokens[self.i.*].value;
//             self.i.* += 1;

//             if (self.tokens[self.i.*].type != .Colon) {
//                 return error.ExpectedColon;
//             }
//             self.i.* += 1;

//             const typeNode = try self.parseType();
//             defer typeNode.deinit(self.allocator);

//             const typeStr = try self.typeNodeToString(typeNode);
//             defer self.allocator.free(typeStr);

//             if (self.tokens[self.i.*].type != .Assignment) {
//                 return error.ExpectedAssignment;
//             }
//             self.i.* += 1;

//             const expression = if (self.tokens[self.i.*].type == .StringLiteral)
//                 try self.parseArrayInitialization()
//             else
//                 try self.parseExpression();

//             return Node.createVariableDecl(self.allocator, .SayDeclaration, expression, null, null, varName, typeStr);
//         }

//         fn parseAssignment(self: *@This()) !*Node {
//             const varNode = try Node.create(self.allocator, .Variable, null, null, null, self.tokens[self.i.*].value);
//             self.i.* += 1;

//             if (self.tokens[self.i.*].type != .Assignment) {
//                 return error.UnexpectedAssignment;
//             }
//             self.i.* += 1;

//             const expression = try self.parseExpression();
//             return Node.create(self.allocator, .Assignment, varNode, expression, null, null);
//         }

//         fn parseIfStatement(self: *@This()) anyerror!*Node {
//             if (self.tokens[self.i.*].type != .If) {
//                 return error.ExpectedIfKeyword;
//             }
//             self.i.* += 1;

//             const condition = try self.parseExpression();
//             errdefer self.allocator.destroy(condition);

//             if (self.i.* >= self.tokens.len or self.tokens[self.i.*].type != .LBrace) {
//                 return error.ExpectedLeftBrace;
//             }
//             self.i.* += 1;

//             const block = try self.parseBlockStatement();
//             errdefer self.allocator.destroy(block);

//             return try Node.create(self.allocator, .IfStatement, condition, block, null, null);
//         }

//         fn parseBlockStatement(self: *@This()) anyerror!*Node {
//             var statements = std.ArrayList(*Node).init(self.allocator.*);
//             errdefer {
//                 for (statements.items) |stmt| stmt.deinit(self.allocator);
//                 statements.deinit();
//             }

//             while (self.i.* < self.tokens.len and self.tokens[self.i.*].type != .RBrace) {
//                 if (self.tokens[self.i.*].type == .EOS) {
//                     self.i.* += 1;
//                     continue;
//                 }

//                 const stmt = try self.parseStatement();
//                 try statements.append(stmt);

//                 if (self.i.* < self.tokens.len and self.tokens[self.i.*].type == .EOS) {
//                     self.i.* += 1;
//                 }
//             }

//             if (self.i.* >= self.tokens.len or self.tokens[self.i.*].type != .RBrace) {
//                 return error.ExpectedRightBrace;
//             }
//             self.i.* += 1;

//             const nodes = try statements.toOwnedSlice();
//             const blockNode = try Node.create(self.allocator, .BlockStatement, null, null, null, nodes);
//             return blockNode;
//         }

//         fn parseWhileStatement(self: *@This()) anyerror!*Node {
//             if (self.tokens[self.i.*].type != .While) {
//                 return error.ExpectedWhileKeyword;
//             }
//             self.i.* += 1;

//             const condition = try self.parseExpression();
//             errdefer self.allocator.destroy(condition);

//             var loop_operation: ?*Node = null;
//             if (self.tokens[self.i.*].type == .Colon) {
//                 self.i.* += 1;
//                 loop_operation = try self.parseExpression();
//             }

//             if (self.tokens[self.i.*].type != .LBrace) {
//                 return error.ExpectedLeftBrace;
//             }
//             self.i.* += 1;

//             if (self.tokens[self.i.*].type == .EOS) {
//                 self.i.* += 1;
//             }

//             const block = try self.parseBlockStatement();
//             errdefer self.allocator.destroy(block);

//             return Node.create(self.allocator, .WhileStatement, condition, block, loop_operation, null);
//         }

//         fn parseSocketCreate(self: *@This()) !*Node {
//             self.i.* += 1; // Consume the @socket_create token
//             return Node.create(self.allocator, .SocketCreate, null, null, null, null);
//         }

//         fn parseSocketBind(self: *@This()) !*Node {
//             self.i.* += 1; // Consume the @socket_bind token
//             const socket = try self.parseExpression();
//             if (self.tokens[self.i.*].type != .Comma) return error.ExpectedComma;
//             self.i.* += 1;
//             const port = try self.parseExpression();
//             return Node.create(self.allocator, .SocketBind, socket, port, null, null);
//         }

//         fn parseSocketListen(self: *@This()) !*Node {
//             self.i.* += 1; // Consume the @socket_listen token
//             const socket = try self.parseExpression();
//             if (self.tokens[self.i.*].type != .Comma) return error.ExpectedComma;
//             self.i.* += 1;
//             const backlog = try self.parseExpression();
//             return Node.create(self.allocator, .SocketListen, socket, backlog, null, null);
//         }

//         fn parseSocketAccept(self: *@This()) !*Node {
//             self.i.* += 1; // Consume the @socket_accept token
//             const socket = try self.parseExpression();
//             return Node.create(self.allocator, .SocketAccept, socket, null, null, null);
//         }

//         fn parseSocketRead(self: *@This()) !*Node {
//             self.i.* += 1; // Consume the @socket_read token
//             const socket = try self.parseExpression();
//             if (self.tokens[self.i.*].type != .Comma) return error.ExpectedComma;
//             self.i.* += 1;
//             const buffer = try self.parseExpression();
//             if (self.tokens[self.i.*].type != .Comma) return error.ExpectedComma;
//             self.i.* += 1;
//             const length = try self.parseExpression();
//             return Node.create(self.allocator, .SocketRead, socket, buffer, length, null);
//         }

//         fn parseSocketWrite(self: *@This()) !*Node {
//             self.i.* += 1; // Consume the @socket_write token
//             const socket = try self.parseExpression();
//             if (self.tokens[self.i.*].type != .Comma) return error.ExpectedComma;
//             self.i.* += 1;
//             const buffer = try self.parseExpression();
//             if (self.tokens[self.i.*].type != .Comma) return error.ExpectedComma;
//             self.i.* += 1;
//             const length = try self.parseExpression();
//             return Node.create(self.allocator, .SocketWrite, socket, buffer, length, null);
//         }

//         fn parseSocketClose(self: *@This()) !*Node {
//             self.i.* += 1; // Consume the @socket_close token
//             const socket = try self.parseExpression();
//             return Node.create(self.allocator, .SocketClose, socket, null, null, null);
//         }

//         fn parseStatement(self: *@This()) !*Node {
//             switch (self.tokens[self.i.*].type) {
//                 .VariableDeclaration => return try self.parseVariableDeclaration(),
//                 .CmdPrintInt => return (try self.parseCmdPrintInt()) orelse return error.UnexpectedToken,
//                 .CmdPrintChar => return (try self.parseCmdPrintChar()) orelse return error.UnexpectedToken,
//                 .CmdPrintBuf => return (try self.parseCmdPrintBuf()) orelse return error.UnexpectedToken,

//                 // Networking
//                 .CmdSocketCreate => return try self.parseSocketCreate(),
//                 .CmdSocketBind => return try self.parseSocketBind(),
//                 .CmdSocketListen => return try self.parseSocketListen(),
//                 .CmdSocketAccept => return try self.parseSocketAccept(),
//                 .CmdSocketRead => return try self.parseSocketRead(),
//                 .CmdSocketWrite => return try self.parseSocketWrite(),
//                 .CmdSocketClose => return try self.parseSocketClose(),

//                 // Contoll Flow
//                 .If => return try self.parseIfStatement(),
//                 .While => return try self.parseWhileStatement(),
//                 else => return try self.parseExpression(),
//             }
//         }

//         fn parseProgram(self: *@This()) !*Program {
//             const program = try Program.create(self.allocator);
//             errdefer program.deinit(self.allocator);

//             while (self.i.* < self.tokens.len and self.tokens[self.i.*].type != .EOF) {
//                 // Skip over empty lines
//                 while (self.i.* < self.tokens.len and self.tokens[self.i.*].type == .EOS) {
//                     self.i.* += 1;
//                 }

//                 // Check if we've reached the end of the file
//                 if (self.i.* >= self.tokens.len or self.tokens[self.i.*].type == .EOF) {
//                     break;
//                 }

//                 const stmt = try self.parseStatement();
//                 errdefer self.allocator.destroy(stmt);
//                 try program.statements.append(stmt);

//                 // Check for EOS
//                 if (self.i.* < self.tokens.len) {
//                     if (self.tokens[self.i.*].type == .EOS) {
//                         self.i.* += 1;
//                     } else if (self.tokens[self.i.*].type != .EOF) {
//                         return error.ExpectedEndOfStatement;
//                     }
//                 }
//             }

//             return program;
//         }
//     };

//     var parser = Parser{ .tokens = tokens, .i = &i, .allocator = allocator };

//     return try parser.parseProgram();
// }
