const std = @import("std");
const testing = std.testing;
const lexer = @import("./lexer/lexer.zig");
const parser = @import("./ast/parser.zig");

fn testParse(input: []const u8) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var tokens = try lexer.lexer(input, &allocator);
    defer tokens.deinit();

    var program = try parser.parse(tokens.items, &allocator);
    defer program.deinit(&allocator);

    // If we got here without any errors, the parse was successful
}

test "basic variable declaration" {
    try testParse("say x = 5");
}

test "simple arithmetic" {
    try testParse("say x = 5 + 3 * 2");
}

test "while loop" {
    try testParse(
        \\while x < 10 : x = x + 1 {
        \\    @printInt x
        \\}
    );
}

test "if statement" {
    try testParse(
        \\if x < 5 {
        \\    @printInt x
        \\}
    );
}

test "complex expression" {
    try testParse("say result = (5 + 3) * 2 - (10 / 2)");
}

test "multiple statements" {
    try testParse(
        \\say x = 5
        \\say y = 10
        \\@printInt x + y
    );
}

test "nested structures" {
    try testParse(
        \\while x < 10 : x = x + 1 {
        \\    if x % 2 == 0 {
        \\        @printInt x
        \\    }
        \\}
    );
}
