const std = @import("std");
const EToken = @import("./tokens.zig").EToken;
const TToken = @import("./tokens.zig").TToken;

pub fn lexer(input: []const u8, allocator: *const std.mem.Allocator) !std.ArrayList(TToken) {
    var tokens = std.ArrayList(TToken).init(allocator.*);
    var i: usize = 0;

    while (i < input.len) : (i += 1) {
        const c = input[i];
        switch (c) {
            '{' => try tokens.append(.{ .type = EToken.LBrace, .value = "{" }),
            '}' => try tokens.append(.{ .type = EToken.RBrace, .value = "}" }),
            ':' => try tokens.append(.{ .type = EToken.Colon, .value = ":" }),
            '&' => try tokens.append(.{ .type = EToken.Ampersand, .value = "&" }),
            '@' => {
                if (input.len >= i + 9 and std.mem.eql(u8, input[i .. i + 9], "@printInt")) {
                    try tokens.append(.{ .type = EToken.CmdPrintInt, .value = "@printInt" });
                    i += 8;
                } else if (input.len >= i + 10 and std.mem.eql(u8, input[i .. i + 10], "@printChar")) {
                    try tokens.append(.{ .type = EToken.CmdPrintChar, .value = "@printChar" });
                    i += 9;
                } else {
                    return error.InvalidCharacter;
                }
            },
            '0'...'9' => {
                const start = i;
                while (i < input.len and std.ascii.isDigit(input[i])) : (i += 1) {}
                try tokens.append(.{ .type = EToken.Integer, .value = input[start..i] });
                i -= 1;
            },
            'a'...'z', 'A'...'Z', '_' => {
                const start = i;
                while (i < input.len and (std.ascii.isAlphanumeric(input[i]) or input[i] == '_')) : (i += 1) {}
                const identifier = input[start..i];
                if (std.mem.eql(u8, identifier, "say")) {
                    try tokens.append(.{ .type = EToken.VariableDeclaration, .value = identifier });
                } else if (std.mem.eql(u8, identifier, "if")) {
                    try tokens.append(.{ .type = EToken.If, .value = identifier });
                } else if (std.mem.eql(u8, identifier, "while")) {
                    try tokens.append(.{ .type = EToken.While, .value = identifier });
                } else if (std.mem.eql(u8, identifier, "u64") or std.mem.eql(u8, identifier, "u8")) {
                    try tokens.append(.{ .type = EToken.TypeDeclaration, .value = identifier });
                } else {
                    try tokens.append(.{ .type = EToken.SayIdentifier, .value = identifier });
                }
                i -= 1;
            },
            '+' => try tokens.append(.{ .type = EToken.Add, .value = "+" }),
            '*' => try tokens.append(.{ .type = EToken.Mul, .value = "*" }),
            '-' => try tokens.append(.{ .type = EToken.Sub, .value = "-" }),
            '/' => try tokens.append(.{ .type = EToken.Div, .value = "/" }),
            '%' => try tokens.append(.{ .type = EToken.Modulo, .value = "%" }),
            '=' => {
                if (i + 1 < input.len and input[i + 1] == '=') {
                    try tokens.append(.{ .type = EToken.Equal, .value = "==" });
                    i += 1;
                } else {
                    try tokens.append(.{ .type = EToken.Assignment, .value = "=" });
                }
            },
            '<' => try tokens.append(.{ .type = EToken.Less, .value = "<" }),
            '>' => try tokens.append(.{ .type = EToken.Greater, .value = ">" }),
            '!' => {
                if (i + 1 < input.len and input[i + 1] == '=') {
                    try tokens.append(.{ .type = EToken.NotEqual, .value = "!=" });
                    i += 1;
                } else {
                    return error.InvalidCharacter;
                }
            },
            '.' => {
                if (i + 1 < input.len and input[i + 1] == '*') {
                    try tokens.append(.{ .type = .Dereference, .value = ".*" });
                    i += 1;
                } else {
                    return error.UnexpectedDot;
                }
            },
            '(' => try tokens.append(.{ .type = EToken.LParen, .value = "(" }),
            ')' => try tokens.append(.{ .type = EToken.RParen, .value = ")" }),
            '\n' => try tokens.append(.{ .type = EToken.EOS, .value = "\\n" }),
            ' ', '\t' => {},
            else => return error.InvalidCharacter,
        }
    }

    try tokens.append(.{ .type = EToken.EOF, .value = "" });
    return tokens;
}
