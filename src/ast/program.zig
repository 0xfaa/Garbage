const std = @import("std");
const Node = @import("./node.zig").Node;

pub const Program = struct {
    statements: std.ArrayList(*Node),

    pub fn create(allocator: *const std.mem.Allocator) !*Program {
        var prog = try allocator.create(Program);
        prog.statements = std.ArrayList(*Node).init(allocator.*);
        return prog;
    }

    pub fn deinit(self: *Program, allocator: *const std.mem.Allocator) void {
        for (self.statements.items) |stmt| {
            stmt.deinit(allocator);
        }
        self.statements.deinit();
        allocator.destroy(self);
    }

    pub fn print(self: *@This(), pad: i64, modif: []const u8) !void {
        std.debug.print("[{d} stmts] Program:\n", .{self.statements.items.len});
        for (self.statements.items) |stmt| {
            try stmt.print(pad, modif);
        }
    }
};
