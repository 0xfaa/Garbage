const std = @import("std");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: {} <assembly_file>\n", .{args[0]});
        std.process.exit(1);
    }

    const input_file = args[1];
    const file_stem = std.fs.path.stem(input_file);
    const object_file = try std.fmt.allocPrint(allocator, "{s}.o", .{file_stem});
    const executable_file = file_stem;

    // Assemble the file
    std.debug.print("Assembling {s}...\n", .{input_file});
    try runCommand(allocator, &.{ "as", "-g", input_file, "-o", object_file });

    // Get SDK path
    const sdk_path = try runCommandAndCapture(allocator, &.{ "xcrun", "--sdk", "macosx", "--show-sdk-path" });

    // Link the object file
    std.debug.print("Linking {s}...\n", .{object_file});
    try runCommand(allocator, &.{ "ld", object_file, "-o", executable_file, "-L", try std.fmt.allocPrint(allocator, "{s}/usr/lib", .{sdk_path}), "-lSystem", "-e", "_main", "-arch", "arm64" });

    // Clean up the object file
    std.fs.cwd().deleteFile(object_file) catch {};

    std.debug.print("Successfully created executable: {s}\n", .{executable_file});

    // Run the executable
    std.debug.print("Running {s}...\n", .{executable_file});
    const result = try std.ChildProcess.exec(.{
        .allocator = allocator,
        .argv = &.{try std.fmt.allocPrint(allocator, "./{s}", .{executable_file})},
    });
    std.debug.print("Output:\n{s}", .{result.stdout});
    if (result.stderr.len > 0) {
        std.debug.print("Errors:\n{s}", .{result.stderr});
    }
}

fn runCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const result = try std.ChildProcess.exec(.{ .allocator = allocator, .argv = args });
    if (result.term.Exited != 0) {
        std.debug.print("Error executing command: {s}\n", .{result.stderr});
        std.process.exit(1);
    }
}

fn runCommandAndCapture(allocator: std.mem.Allocator, args: []const []const u8) ![]const u8 {
    const result = try std.ChildProcess.exec(.{ .allocator = allocator, .argv = args });
    if (result.term.Exited != 0) {
        std.debug.print("Error executing command: {s}\n", .{result.stderr});
        std.process.exit(1);
    }
    return std.mem.trim(u8, result.stdout, &std.ascii.whitespace);
}
