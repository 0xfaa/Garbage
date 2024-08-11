const std = @import("std");
const lexer = @import("./lexer/lexer.zig").lexer;
const parse = @import("./ast/parser.zig").parse;
const codegen_init = @import("./codegen/codegen.zig").codegen_init;

pub fn compile(code: []const u8, allocator: std.mem.Allocator) ![]u8 {
    std.debug.print("Starting compilation\n", .{});

    std.debug.print("Lexing...\n", .{});
    var lexer_result = lexer(code, allocator) catch |err| {
        std.debug.print("Lexer error: {}\n", .{err});
        return err;
    };
    defer lexer_result.deinit();

    for (lexer_result.tokens) |t| {
        std.debug.print("token: type = {} | value = {s}\n", .{ t.type, t.value });
    }

    std.debug.print("Parsing...\n", .{});
    var program = parse(lexer_result.tokens, allocator) catch |err| {
        std.debug.print("Parser error: {}\n", .{err});
        return err;
    };
    defer program.deinit();

    std.debug.print("Printing AST...\n", .{});
    program.print(1, "root");

    std.debug.print("Generating assembly...\n", .{});
    var asm_code = std.ArrayList(u8).init(allocator);
    defer asm_code.deinit();

    codegen_init(program, asm_code.writer()) catch |err| {
        std.debug.print("Codegen error: {}\n", .{err});
        return err;
    };

    std.debug.print("Compilation complete\n", .{});
    return try allocator.dupe(u8, asm_code.items);
}
