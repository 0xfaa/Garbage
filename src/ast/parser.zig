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
