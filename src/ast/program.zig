const std = @import("std");
const Node = @import("./node.zig").Node;

pub const Program = struct {
    statements: std.ArrayList(*Node),
    arena: std.heap.ArenaAllocator,

    pub fn create(allocator: std.mem.Allocator) !*Program {
        var prog = try allocator.create(Program);
        prog.statements = std.ArrayList(*Node).init(allocator);
        return prog;
    }

    pub fn deinit(self: *Program) void {
        self.arena.deinit();
    }

    pub fn print(self: *const @This(), pad: i64, modif: []const u8) void {
        std.debug.print("[{d} stmts] Program:\n", .{self.statements.items.len});
        for (self.statements.items) |stmt| {
            stmt.print(pad, modif);
        }
    }
};
