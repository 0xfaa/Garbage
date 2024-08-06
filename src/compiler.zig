const std = @import("std");

// TODO: Remove these
const lexer = @import("./lexer/lexer.zig").lexer;
const Token = @import("./lexer/tokens.zig").TToken;
const TokenType = @import("./lexer/tokens.zig").EToken;
const NodeType = @import("./ast/node.zig").ENode;
const Node = @import("./ast/node.zig").Node;
const Program = @import("./ast/program.zig").Program;
const parse = @import("./ast/parser.zig").parse;
const codegen_init = @import("./codegen/codegen.zig").codegen_init;

pub fn compile(code: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const tokens = try lexer(code, &allocator);
    defer {
        for (tokens.items) |token| {
            allocator.free(token.value);
        }
        tokens.deinit();
    }
    for (tokens.items) |t| std.debug.print("token: type = {} | value = {s}\n", .{ t.type, t.value });

    var program = try parse(tokens.items, &allocator);
    defer program.deinit(&allocator);
    try program.print(1, "root");

    var asm_code = std.ArrayList(u8).init(allocator);
    defer asm_code.deinit();

    try codegen_init(program, asm_code.writer());

    return try allocator.dupe(u8, asm_code.items);
}
