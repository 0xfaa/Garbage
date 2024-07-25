const std = @import("std");
const EToken = @import("./tokens.zig").EToken;
const TToken = @import("./tokens.zig").TToken;

pub fn lexer(input: []const u8, allocator: *const std.mem.Allocator) !std.ArrayList(TToken) {
    var tokens = std.ArrayList(TToken).init(allocator.*);
    var i: usize = 0;

    while (i < input.len) : (i += 1) {
        const c = input[i];
        switch (c) {
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
            '=' => try tokens.append(.{ .type = EToken.Assignment, .value = "=" }),
            // @printInt
            '@' => {
                if (input.len >= i + 9 and std.mem.eql(u8, input[i .. i + 9], "@printInt")) {
                    try tokens.append(.{ .type = EToken.CmdPrintInt, .value = "@printInt" });
                    i += 9;
                }
            },
            '\n' => try tokens.append(.{ .type = EToken.EOS, .value = "\\n" }),
            ' ', '\t' => {},
            else => return error.InvalidCharacter,
        }
    }

    try tokens.append(.{ .type = EToken.EOF, .value = "" });
    return tokens;
}
