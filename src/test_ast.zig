const std = @import("std");
const testing = std.testing;
const parse = @import("ast/parser.zig").parse;
const lexer = @import("lexer/lexer.zig").lexer;
const Node = @import("ast/node.zig").Node;
const Program = @import("ast/program.zig").Program;
const ENode = @import("ast/node.zig").ENode;

fn testParse(input: []const u8, expected: []const ENode) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var lexer_result = try lexer(input, allocator);
    defer lexer_result.deinit();

    var program = try parse(lexer_result.tokens, allocator);
    defer program.deinit();

    try testing.expectEqual(expected.len, program.statements.items.len);

    for (program.statements.items, 0..) |stmt, i| {
        try testing.expectEqual(expected[i], stmt.type);
    }
}

fn compareNodes(expected: *Node, actual: *Node) !void {
    try testing.expectEqual(expected.type, actual.type);

    switch (expected.type) {
        .IntegerLiteral => try testing.expectEqual(expected.value.integer, actual.value.integer),
        .Variable => try testing.expectEqualStrings(expected.value.str, actual.value.str),
        // Add more cases for other node types as needed
        else => {},
    }

    if (expected.left) |left| {
        try testing.expect(actual.left != null);
        try compareNodes(left, actual.left.?);
    } else {
        try testing.expect(actual.left == null);
    }

    if (expected.right) |right| {
        try testing.expect(actual.right != null);
        try compareNodes(right, actual.right.?);
    } else {
        try testing.expect(actual.right == null);
    }
}

test "Parse integer literal" {
    try testParse("42", &[_]ENode{.IntegerLiteral});
}

test "Parse simple addition" {
    try testParse("1 + 2", &[_]ENode{.NodeAdd});
}

test "Parse variable declaration" {
    try testParse("say x: u64 = 10", &[_]ENode{.SayDeclaration});
}

test "Parse if statement" {
    try testParse(
        \\if x < 10 {
        \\    @print_int(x)
        \\}
    , &[_]ENode{.IfStatement});
}

test "Parse while loop" {
    try testParse(
        \\while x < 10 {
        \\    x = x + 1
        \\}
    , &[_]ENode{.WhileStatement});
}

test "Parse array initialization" {
    try testParse("say arr: [5]u8 = {1, 2, 3, 4, 5}", &[_]ENode{.SayDeclaration});
}

test "Parse array string initialization" {
    try testParse("say arr: [5]u8 = \"hello\"", &[_]ENode{.SayDeclaration});
}

test "Parse socket operations" {
    try testParse(
        \\say socket: u64 = @socket_create
        \\@socket_bind socket, 8080
        \\@socket_listen socket, 5
        \\say client: u64 = @socket_accept socket
    , &[_]ENode{
        .SayDeclaration,
        .SocketBind,
        .SocketListen,
        .SayDeclaration,
    });
}

test "Parse complex expression" {
    try testParse("(1 + 2) * (3 - 4) / 5 % 6", &[_]ENode{.NodeModulo});
}

test "Parse string literal" {
    try testParse("say msg: [5]u8 = \"Hello\"", &[_]ENode{.SayDeclaration});
}
