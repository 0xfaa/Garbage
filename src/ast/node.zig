const std = @import("std");
const VarType = @import("../codegen/codegen.zig").VarType;

pub const ENode = enum {
    IntegerLiteral,
    NodeAdd,
    NodeMul,
    NodeSub,
    NodeDiv,
    NodeModulo,
    Statement,

    // commands
    CmdPrintInt,
    CmdPrintChar,
    CmdPrintBuf,

    // Variable stuff
    Variable,
    SayDeclaration,
    Assignment,

    // Types // Pointers
    Type,
    PointerType,
    ArrayType,
    AddressOf,
    Dereference,

    // If statment
    IfStatement,
    BlockStatement,

    // Conditionals
    NodeEqual,
    NodeLess,
    NodeGreater,
    NodeNotEqual,

    // While statement
    WhileStatement,

    // Array
    ArrayIndex,
    ArrayInitialization,

    // Networking
    SocketCreate,
    SocketBind,
    SocketListen,
    SocketAccept,
    SocketRead,
    SocketWrite,
    SocketClose,
};

pub const NodeValue = union(enum) {
    integer: i64,
    str: []const u8,
    nodes: []const *Node,
    variable_decl: struct {
        name: []const u8,
        type: []const u8,
    },
};

pub const Node = struct {
    type: ENode,
    left: ?*Node,
    right: ?*Node,
    extra: ?*Node, // Field for loop operation
    value: NodeValue,

    pub fn create(allocator: *const std.mem.Allocator, node_type: ENode, left: ?*Node, right: ?*Node, extra: ?*Node, value: anytype) !*Node {
        const node = try allocator.create(Node);
        node.* = .{
            .type = node_type,
            .left = left,
            .right = right,
            .extra = extra,
            .value = switch (@TypeOf(value)) {
                i64 => .{ .integer = value },
                []const u8 => .{ .str = value },
                []*Node => .{ .nodes = value },
                @TypeOf(null) => .{ .str = "null" },
                else => @compileError("Unsupported value type: " ++ @typeName(@TypeOf(value))),
            },
        };
        return node;
    }

    pub fn createVariableDecl(allocator: *const std.mem.Allocator, node_type: ENode, left: ?*Node, right: ?*Node, extra: ?*Node, name: []const u8, var_type: []const u8) !*Node {
        const node = try allocator.create(Node);
        const name_copy = try allocator.dupe(u8, name);
        const type_copy = try allocator.dupe(u8, var_type);
        node.* = .{
            .type = node_type,
            .left = left,
            .right = right,
            .extra = extra,
            .value = .{ .variable_decl = .{ .name = name_copy, .type = type_copy } },
        };
        return node;
    }

    pub fn deinit(self: *Node, allocator: *const std.mem.Allocator) void {
        if (self.left) |left| left.deinit(allocator);
        if (self.right) |right| right.deinit(allocator);
        if (self.extra) |extra| extra.deinit(allocator);
        switch (self.value) {
            .nodes => |nodes| {
                for (nodes) |node| {
                    node.deinit(allocator);
                }
                allocator.free(nodes);
            },
            .variable_decl => |var_decl| {
                allocator.free(var_decl.name);
                allocator.free(var_decl.type);
            },
            else => {},
        }
        allocator.destroy(self);
    }

    pub fn print(self: *@This(), pad: i64, modif: []const u8) !void {
        var i: i64 = 0;
        while (i < pad) : (i += 1) {
            std.debug.print(" ", .{});
        }

        std.debug.print("{s} [{s}]", .{ modif, @tagName(self.type) });

        switch (self.value) {
            .integer => |int| std.debug.print(" = {d}\n", .{int}),
            .str => |str| std.debug.print(" = {s}\n", .{str}),
            .nodes => |n| for (n) |node| {
                std.debug.print("\n", .{});
                try node.print(pad + 1, modif);
            },
            .variable_decl => |decl| std.debug.print(" = {s}: {s}\n", .{ decl.name, decl.type }),
        }

        if (self.left) |left| {
            try left.print(pad + 1, "l");
        }
        if (self.right) |right| {
            try right.print(pad + 1, "r");
        }
        if (self.extra) |extra| {
            try extra.print(pad + 1, "e");
        }
    }
};
