const std = @import("std");
const VarType = @import("../codegen/codegen.zig").VarType;

pub const ENode = enum(u32) {
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

    // Strings
    StringLiteral,
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

    pub fn create(allocator: std.mem.Allocator, node_type: ENode, left: ?*Node, right: ?*Node, extra: ?*Node, value: anytype) !*Node {
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

    pub fn createVariableDecl(allocator: std.mem.Allocator, node_type: ENode, left: ?*Node, right: ?*Node, extra: ?*Node, name: []const u8, var_type: []const u8) !*Node {
        const node = try allocator.create(Node);
        node.* = .{
            .type = node_type,
            .left = left,
            .right = right,
            .extra = extra,
            .value = .{
                .variable_decl = .{
                    .name = try allocator.dupe(u8, name),
                    .type = try allocator.dupe(u8, var_type),
                },
            },
        };
        return node;
    }

    pub fn deinit(self: *Node, allocator: std.mem.Allocator) void {
        if (self.left) |left| {
            left.deinit(allocator);
            allocator.destroy(left);
        }
        if (self.right) |right| {
            right.deinit(allocator);
            allocator.destroy(right);
        }
        if (self.extra) |extra| {
            extra.deinit(allocator);
            allocator.destroy(extra);
        }
        switch (self.value) {
            .str => |s| allocator.free(s),
            .nodes => |nodes| {
                for (nodes) |node| {
                    node.deinit(allocator);
                    allocator.destroy(node);
                }
                allocator.free(nodes);
            },
            .variable_decl => |decl| {
                allocator.free(decl.name);
                allocator.free(decl.type);
            },
            else => {},
        }
    }

    pub fn print(self: *const @This(), pad: i64, modif: []const u8) void {
        var i: i64 = 0;
        while (i < pad) : (i += 1) {
            std.debug.print(" ", .{});
        }

        std.debug.print("{s} [{s}]", .{ modif, @tagName(self.type) });

        switch (self.value) {
            .integer => |int| std.debug.print(" = {d}\n", .{int}),
            .str => |str| std.debug.print(" = {s}\n", .{str}),
            .nodes => |n| {
                std.debug.print("\n", .{});
                for (n) |node| {
                    node.print(pad + 1, modif);
                }
            },
            .variable_decl => {
                std.debug.print(" = name: type\n", .{});
            },
        }

        if (self.left) |left| {
            left.print(pad + 1, "l");
        }
        if (self.right) |right| {
            right.print(pad + 1, "r");
        }
        if (self.extra) |extra| {
            extra.print(pad + 1, "e");
        }
    }
};
