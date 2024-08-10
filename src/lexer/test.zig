const std = @import("std");
const testing = std.testing;
const lexer = @import("lexer.zig").lexer;
const EToken = @import("tokens.zig").EToken;
const TToken = @import("tokens.zig").TToken;
const LexerError = @import("lexer.zig").LexerError;
const LexerResult = @import("lexer.zig").LexerResult;

fn testLexer(input: []const u8, expected: []const EToken) !void {
    var result = try lexer(input, std.testing.allocator);
    defer result.deinit();

    try testing.expectEqual(expected.len, result.tokens.len);
    for (result.tokens, 0..) |token, i| {
        try testing.expectEqual(expected[i], token.type);
    }
}

test "Basic tokens" {
    const input = "{ } : & @ = < > + - * / % ( ) [ ] , \n";
    const expected = [_]EToken{
        .LBrace, .RBrace,  .Colon,  .Ampersand,      .AtSign,         .Assignment,
        .Less,   .Greater, .Add,    .Sub,            .Mul,            .Div,
        .Modulo, .LParen,  .RParen, .LSquareBracket, .RSquareBracket, .Comma,
        .EOS,    .EOF,
    };
    try testLexer(input, &expected);
}

test "Identifiers and keywords" {
    const input = "say hello u64 if while";
    const expected = [_]EToken{
        .VariableDeclaration, .SayIdentifier, .TypeDeclaration, .If, .While, .EOF,
    };
    try testLexer(input, &expected);
}

test "Integer literals" {
    const input = "123 456 0 789";
    const expected = [_]EToken{ .Integer, .Integer, .Integer, .Integer, .EOF };
    try testLexer(input, &expected);
}

test "String literals" {
    const input = "\"Hello, world!\" \"Escaped \\\"quotes\\\"\" \"\\n\\t\\r\"";
    const expected = [_]EToken{ .StringLiteral, .StringLiteral, .StringLiteral, .EOF };
    try testLexer(input, &expected);
}

test "Operators" {
    const input = "= == != < > + - * / % .* !";
    const expected = [_]EToken{
        .Assignment,  .Equal, .NotEqual, .Less, .Greater,
        .Add,         .Sub,   .Mul,      .Div,  .Modulo,
        .Dereference, .Not,   .EOF,
    };
    try testLexer(input, &expected);
}

test "Commands" {
    const input = "@socket_create @print_int";
    const expected = [_]EToken{ .CmdSocketCreate, .CmdPrintInt, .EOF };
    try testLexer(input, &expected);
}

test "Complex input" {
    const input =
        \\say hello u64 = 42
        \\if (x < 10) {
        \\    @print_int(x)
        \\}
        \\while (true) {
        \\    x = x + 1
        \\}
        \\@socket_create()
    ;
    const expected = [_]EToken{
        .VariableDeclaration, .SayIdentifier, .TypeDeclaration, .Assignment,    .Integer,       .EOS,
        .If,                  .LParen,        .SayIdentifier,   .Less,          .Integer,       .RParen,
        .LBrace,              .EOS,           .CmdPrintInt,     .LParen,        .SayIdentifier, .RParen,
        .EOS,                 .RBrace,        .EOS,             .While,         .LParen,        .SayIdentifier,
        .RParen,              .LBrace,        .EOS,             .SayIdentifier, .Assignment,    .SayIdentifier,
        .Add,                 .Integer,       .EOS,             .RBrace,        .EOS,           .CmdSocketCreate,
        .LParen,              .RParen,        .EOF,
    };
    try testLexer(input, &expected);
}

test "Error handling - Invalid character" {
    const input = "hello # world";
    try testing.expectError(error.InvalidCharacter, lexer(input, std.testing.allocator));
}

test "Error handling - Unterminated string" {
    const input = "\"Hello, world";
    try testing.expectError(error.UnterminatedString, lexer(input, std.testing.allocator));
}

test "Error handling - Invalid @ command" {
    const input = "@invalid_command";
    var result = try lexer(input, std.testing.allocator);
    defer result.deinit();
    try testing.expectEqual(@as(usize, 2), result.tokens.len);
    try testing.expectEqual(EToken.UnknownAtCommand, result.tokens[0].type);
    try testing.expectEqualStrings("@invalid_command", result.tokens[0].value);
    try testing.expectEqual(EToken.EOF, result.tokens[1].type);
}

test "Standalone @ character" {
    const input = "@ ";
    var result = try lexer(input, std.testing.allocator);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 2), result.tokens.len);
    try testing.expectEqual(EToken.AtSign, result.tokens[0].type);
    try testing.expectEqualStrings("@", result.tokens[0].value);
    try testing.expectEqual(EToken.EOF, result.tokens[1].type);
}

test "Networking commands" {
    const input = "@socket_create @socket_bind @socket_listen @socket_accept @socket_read @socket_write @socket_close";
    const expected = [_]EToken{
        .CmdSocketCreate,
        .CmdSocketBind,
        .CmdSocketListen,
        .CmdSocketAccept,
        .CmdSocketRead,
        .CmdSocketWrite,
        .CmdSocketClose,
        .EOF,
    };
    try testLexer(input, &expected);
}

test "Mixed commands" {
    const input = "@socket_create @print_int @socket_close";
    const expected = [_]EToken{
        .CmdSocketCreate,
        .CmdPrintInt,
        .CmdSocketClose,
        .EOF,
    };
    try testLexer(input, &expected);
}

test "Unknown and known commands" {
    const input = "@unknown_command @socket_bind @another_unknown";
    var result = try lexer(input, std.testing.allocator);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 4), result.tokens.len);
    try testing.expectEqual(EToken.UnknownAtCommand, result.tokens[0].type);
    try testing.expectEqualStrings("@unknown_command", result.tokens[0].value);
    try testing.expectEqual(EToken.CmdSocketBind, result.tokens[1].type);
    try testing.expectEqual(EToken.UnknownAtCommand, result.tokens[2].type);
    try testing.expectEqualStrings("@another_unknown", result.tokens[2].value);
    try testing.expectEqual(EToken.EOF, result.tokens[3].type);
}
