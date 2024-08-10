const std = @import("std");
const EToken = @import("./tokens.zig").EToken;
const TToken = @import("./tokens.zig").TToken;

pub const LexerError = error{
    InvalidCharacter,
    UnterminatedString,
    InvalidEscapeSequence,
    InvalidAtCommand,
    UnexpectedDot,
    OutOfMemory,
};

pub const LexerResult = struct {
    tokens: []TToken,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *LexerResult) void {
        for (self.tokens) |token| {
            self.allocator.free(token.value);
        }
        self.allocator.free(self.tokens);
    }
};

pub fn lexer(input: []const u8, allocator: std.mem.Allocator) LexerError!LexerResult {
    var tokens = std.ArrayList(TToken).init(allocator);
    errdefer {
        for (tokens.items) |token| {
            allocator.free(token.value);
        }
        tokens.deinit();
    }

    var i: usize = 0;
    while (i < input.len) : (i += 1) {
        const c = input[i];
        switch (c) {
            '{', '}', ':', '&', '+', '-', '*', '/', '%', '<', '>', '(', ')', '[', ']', ',' => try handleSingleCharToken(&tokens, c),
            '@' => i = try handleAtCommand(&tokens, input, i),
            '0'...'9' => i = try handleNumber(&tokens, input, i),
            'a'...'z', 'A'...'Z', '_' => i = try handleIdentifier(&tokens, input, i),
            '=' => i = try handleEquals(&tokens, input, i),
            '!' => i = try handleNot(&tokens, input, i),
            '.' => i = try handleDot(&tokens, input, i),
            '\n' => try appendToken(&tokens, .EOS, "\\n"),
            ' ', '\t' => {},
            '"' => i = try handleString(&tokens, input, i, allocator),
            else => return error.InvalidCharacter,
        }
    }

    try appendToken(&tokens, .EOF, "");
    return LexerResult{ .tokens = try tokens.toOwnedSlice(), .allocator = allocator };
}

fn handleSingleCharToken(tokens: *std.ArrayList(TToken), c: u8) !void {
    const token_type: EToken = switch (c) {
        '{' => .LBrace,
        '}' => .RBrace,
        ':' => .Colon,
        '&' => .Ampersand,
        '+' => .Add,
        '-' => .Sub,
        '*' => .Mul,
        '/' => .Div,
        '%' => .Modulo,
        '<' => .Less,
        '>' => .Greater,
        '(' => .LParen,
        ')' => .RParen,
        '[' => .LSquareBracket,
        ']' => .RSquareBracket,
        ',' => .Comma,
        else => unreachable,
    };
    try appendToken(tokens, token_type, &[_]u8{c});
}

fn handleAtCommand(tokens: *std.ArrayList(TToken), input: []const u8, i: usize) !usize {
    if (i + 1 >= input.len or !std.ascii.isAlphabetic(input[i + 1])) {
        // Standalone '@'
        try appendToken(tokens, .AtSign, "@");
        return i;
    }

    const commands = [_]struct { name: []const u8, token: EToken }{
        .{ .name = "@socket_create", .token = .CmdSocketCreate },
        .{ .name = "@socket_bind", .token = .CmdSocketBind },
        .{ .name = "@socket_listen", .token = .CmdSocketListen },
        .{ .name = "@socket_accept", .token = .CmdSocketAccept },
        .{ .name = "@socket_read", .token = .CmdSocketRead },
        .{ .name = "@socket_write", .token = .CmdSocketWrite },
        .{ .name = "@socket_close", .token = .CmdSocketClose },
        .{ .name = "@print_buf", .token = .CmdPrintBuf },
        .{ .name = "@print_int", .token = .CmdPrintInt },
    };

    for (commands) |cmd| {
        if (std.mem.startsWith(u8, input[i..], cmd.name)) {
            try appendToken(tokens, cmd.token, cmd.name);
            return i + cmd.name.len - 1;
        }
    }

    // Unknown '@' command
    var end = i + 1;
    while (end < input.len and (std.ascii.isAlphanumeric(input[end]) or input[end] == '_')) : (end += 1) {}
    try appendToken(tokens, .UnknownAtCommand, input[i..end]);
    return end - 1;
}

fn handleNumber(tokens: *std.ArrayList(TToken), input: []const u8, start: usize) !usize {
    var i = start;
    while (i < input.len and std.ascii.isDigit(input[i])) : (i += 1) {}
    try appendToken(tokens, .Integer, input[start..i]);
    return i - 1;
}

fn handleIdentifier(tokens: *std.ArrayList(TToken), input: []const u8, start: usize) !usize {
    var i = start;
    while (i < input.len and (std.ascii.isAlphanumeric(input[i]) or input[i] == '_')) : (i += 1) {}
    const identifier = input[start..i];
    const token_type: EToken = if (std.mem.eql(u8, identifier, "say"))
        .VariableDeclaration
    else if (std.mem.eql(u8, identifier, "if"))
        .If
    else if (std.mem.eql(u8, identifier, "while"))
        .While
    else if (std.mem.eql(u8, identifier, "u64") or std.mem.eql(u8, identifier, "u8"))
        .TypeDeclaration
    else
        .SayIdentifier;
    try appendToken(tokens, token_type, identifier);
    return i - 1;
}

fn handleEquals(tokens: *std.ArrayList(TToken), input: []const u8, i: usize) !usize {
    if (i + 1 < input.len and input[i + 1] == '=') {
        try appendToken(tokens, .Equal, "==");
        return i + 1;
    } else {
        try appendToken(tokens, .Assignment, "=");
        return i;
    }
}

fn handleNot(tokens: *std.ArrayList(TToken), input: []const u8, i: usize) !usize {
    if (i + 1 < input.len and input[i + 1] == '=') {
        try appendToken(tokens, .NotEqual, "!=");
        return i + 1;
    } else {
        try appendToken(tokens, .Not, "!");
        return i;
    }
}

fn handleDot(tokens: *std.ArrayList(TToken), input: []const u8, i: usize) !usize {
    if (i + 1 < input.len and input[i + 1] == '*') {
        try appendToken(tokens, .Dereference, ".*");
        return i + 1;
    } else {
        return error.UnexpectedDot;
    }
}

fn handleString(tokens: *std.ArrayList(TToken), input: []const u8, start: usize, allocator: std.mem.Allocator) !usize {
    var result = std.ArrayList(u8).init(allocator);
    defer result.deinit();

    var i = start + 1;
    while (i < input.len and input[i] != '"') : (i += 1) {
        if (input[i] == '\\' and i + 1 < input.len) {
            i += 1;
            const escaped_char = try processEscapeSequence(input[i]);
            try result.append(escaped_char);
        } else {
            try result.append(input[i]);
        }
    }

    if (i >= input.len) return error.UnterminatedString;

    const string_literal = try result.toOwnedSlice();
    try appendToken(tokens, .StringLiteral, string_literal);
    return i;
}

fn processEscapeSequence(c: u8) !u8 {
    return switch (c) {
        'n' => '\n',
        'r' => '\r',
        't' => '\t',
        '\\' => '\\',
        '"' => '"',
        '0' => 0,
        else => error.InvalidEscapeSequence,
    };
}

fn appendToken(tokens: *std.ArrayList(TToken), token_type: EToken, value: []const u8) !void {
    const duped_value = if (token_type == .StringLiteral)
        value
    else
        try tokens.allocator.dupe(u8, value);

    errdefer {
        if (token_type != .StringLiteral) {
            tokens.allocator.free(duped_value);
        }
    }

    try tokens.append(.{ .type = token_type, .value = duped_value });
}
