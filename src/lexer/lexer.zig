const std = @import("std");
const EToken = @import("./tokens.zig").EToken;
const TToken = @import("./tokens.zig").TToken;

pub fn lexer(input: []const u8, allocator: *const std.mem.Allocator) !std.ArrayList(TToken) {
    var tokens = std.ArrayList(TToken).init(allocator.*);
    var i: usize = 0;

    std.debug.print("Starting lexer. Input length: {d}\n", .{input.len});

    while (i < input.len) : (i += 1) {
        const c = input[i];
        std.debug.print("Processing character at index {d}: '{c}'\n", .{ i, c });

        switch (c) {
            '{' => try appendToken(&tokens, .LBrace, "{"),
            '}' => try appendToken(&tokens, .RBrace, "}"),
            ':' => try appendToken(&tokens, .Colon, ":"),
            '&' => try appendToken(&tokens, .Ampersand, "&"),
            '@' => {
                std.debug.print("Encountered @. Remaining input: {s}\n", .{input[i..]});
                const commands = [_]struct { name: []const u8, token: EToken }{
                    .{ .name = "@socket_create", .token = .CmdSocketCreate },
                    .{ .name = "@socket_bind", .token = .CmdSocketBind },
                    .{ .name = "@socket_listen", .token = .CmdSocketListen },
                    .{ .name = "@socket_accept", .token = .CmdSocketAccept },
                    .{ .name = "@socket_read", .token = .CmdSocketRead },
                    .{ .name = "@socket_write", .token = .CmdSocketWrite },
                    .{ .name = "@socket_close", .token = .CmdSocketClose },
                    .{ .name = "@print_int", .token = .CmdPrintInt },
                    .{ .name = "@print_char", .token = .CmdPrintChar },
                    .{ .name = "@print_buf", .token = .CmdPrintBuf },
                };

                var matched = false;
                for (commands) |cmd| {
                    if (input.len >= i + cmd.name.len and std.mem.eql(u8, input[i .. i + cmd.name.len], cmd.name)) {
                        try appendToken(&tokens, cmd.token, cmd.name);
                        i += cmd.name.len - 1;
                        matched = true;
                        break;
                    }
                }

                if (!matched) {
                    std.debug.print("Invalid @ command at index {d}. Partial command: ", .{i});
                    var j: usize = i;
                    while (j < input.len and input[j] != ' ' and input[j] != '\n') : (j += 1) {
                        std.debug.print("{c}", .{input[j]});
                    }
                    std.debug.print("\n", .{});
                    return error.InvalidCharacter;
                }
            },
            '0'...'9' => {
                const start = i;
                while (i < input.len and std.ascii.isDigit(input[i])) : (i += 1) {}
                try appendToken(&tokens, .Integer, input[start..i]);
                i -= 1;
                std.debug.print("Parsed integer: {s}\n", .{input[start .. i + 1]});
            },
            'a'...'z', 'A'...'Z', '_' => {
                const start = i;
                while (i < input.len and (std.ascii.isAlphanumeric(input[i]) or input[i] == '_')) : (i += 1) {}
                const identifier = input[start..i];
                std.debug.print("Parsed identifier: {s}\n", .{identifier});
                if (std.mem.eql(u8, identifier, "say")) {
                    try appendToken(&tokens, .VariableDeclaration, identifier);
                } else if (std.mem.eql(u8, identifier, "if")) {
                    try appendToken(&tokens, .If, identifier);
                } else if (std.mem.eql(u8, identifier, "while")) {
                    try appendToken(&tokens, .While, identifier);
                } else if (std.mem.eql(u8, identifier, "u64") or std.mem.eql(u8, identifier, "u8")) {
                    try appendToken(&tokens, .TypeDeclaration, identifier);
                } else {
                    try appendToken(&tokens, .SayIdentifier, identifier);
                }
                i -= 1;
            },
            '+' => try appendToken(&tokens, .Add, "+"),
            '*' => try appendToken(&tokens, .Mul, "*"),
            '-' => try appendToken(&tokens, .Sub, "-"),
            '/' => try appendToken(&tokens, .Div, "/"),
            '%' => try appendToken(&tokens, .Modulo, "%"),
            '=' => {
                if (i + 1 < input.len and input[i + 1] == '=') {
                    try appendToken(&tokens, .Equal, "==");
                    i += 1;
                } else {
                    try appendToken(&tokens, .Assignment, "=");
                }
            },
            '<' => try appendToken(&tokens, .Less, "<"),
            '>' => try appendToken(&tokens, .Greater, ">"),
            '!' => {
                if (i + 1 < input.len and input[i + 1] == '=') {
                    try appendToken(&tokens, .NotEqual, "!=");
                    i += 1;
                } else {
                    std.debug.print("Invalid '!' usage at index {d}\n", .{i});
                    return error.InvalidCharacter;
                }
            },
            '.' => {
                if (i + 1 < input.len and input[i + 1] == '*') {
                    try appendToken(&tokens, .Dereference, ".*");
                    i += 1;
                } else {
                    std.debug.print("Unexpected '.' at index {d}\n", .{i});
                    return error.UnexpectedDot;
                }
            },
            '(' => try appendToken(&tokens, .LParen, "("),
            ')' => try appendToken(&tokens, .RParen, ")"),
            '[' => try appendToken(&tokens, .LSquareBracket, "["),
            ']' => try appendToken(&tokens, .RSquareBracket, "]"),
            ',' => try appendToken(&tokens, .Comma, ","),
            '\n' => try appendToken(&tokens, .EOS, "\\n"),
            ' ', '\t' => {
                std.debug.print("Skipping whitespace at index {d}\n", .{i});
            },
            else => {
                std.debug.print("Invalid character at index {d}: '{c}'\n", .{ i, c });
                return error.InvalidCharacter;
            },
        }
    }

    try appendToken(&tokens, .EOF, "");
    std.debug.print("Lexer completed. Total tokens: {d}\n", .{tokens.items.len});
    return tokens;
}

fn appendToken(tokens: *std.ArrayList(TToken), token_type: EToken, value: []const u8) !void {
    try tokens.append(.{ .type = token_type, .value = value });
    std.debug.print("Appended token: {s} with value: {s}\n", .{ @tagName(token_type), value });
}
