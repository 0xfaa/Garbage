const std = @import("std");
const compiler = @import("./compiler.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Read the input code
    const in = std.io.getStdIn();
    const input = try in.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(input);

    const asm_code = try compiler.compile(input, allocator);
    defer allocator.free(asm_code);

    // Write to stdout
    const out = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(out);
    var stdout = bw.writer();
    try stdout.print("{s}", .{asm_code});
    try bw.flush();
}
