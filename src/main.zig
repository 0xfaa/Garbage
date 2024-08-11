const std = @import("std");
const compiler = @import("./compiler.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 3) {
        std.debug.print("Usage: {s} [--compile|--run] <input_file>\n", .{args[0]});
        return;
    }

    const mode = args[1];
    const input_file = args[2];

    if (!std.mem.eql(u8, mode, "--compile") and !std.mem.eql(u8, mode, "--run")) {
        std.debug.print("Invalid mode. Use --compile or --run\n", .{});
        return;
    }

    const cwd = std.fs.cwd();
    const abs_input_path = try cwd.realpathAlloc(allocator, input_file);
    defer allocator.free(abs_input_path);

    const input = try cwd.readFileAlloc(allocator, abs_input_path, std.math.maxInt(usize));
    defer allocator.free(input);

    const asm_code = try compiler.compile(input, allocator);
    defer allocator.free(asm_code);

    const abs_asm_path = try std.fmt.allocPrint(allocator, "{s}.asm", .{abs_input_path[0 .. abs_input_path.len - std.fs.path.extension(abs_input_path).len]});
    defer allocator.free(abs_asm_path);

    const file = try cwd.createFile(abs_asm_path, .{});
    defer file.close();
    try file.writeAll(asm_code);

    try assembleAndLink(allocator, abs_asm_path);

    if (std.mem.eql(u8, mode, "--run")) {
        const abs_executable_path = abs_asm_path[0 .. abs_asm_path.len - 4];
        std.debug.print("Attempting to run executable: {s}\n", .{abs_executable_path});

        // Check if the file exists before trying to run it
        cwd.access(abs_executable_path, .{}) catch |err| {
            std.debug.print("Error: Unable to access executable file '{s}': {}\n", .{ abs_executable_path, err });
            return;
        };

        try runExecutable(allocator, abs_executable_path);
    }
}

fn assembleAndLink(allocator: std.mem.Allocator, asm_file: []const u8) !void {
    const object_file = try std.fmt.allocPrint(allocator, "{s}.o", .{asm_file[0 .. asm_file.len - 4]});
    defer allocator.free(object_file);

    const executable_file = try allocator.dupe(u8, asm_file[0 .. asm_file.len - 4]);
    defer allocator.free(executable_file);

    // Assemble
    {
        const result = try std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{ "as", "-g", asm_file, "-o", object_file },
        });
        defer allocator.free(result.stderr);

        if (result.term.Exited != 0) {
            std.debug.print("Assembly failed: {s}\n", .{result.stderr});
            return error.AssemblyFailed;
        }
    }

    // Get SDK path
    const sdk_path = blk: {
        const result = try std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{ "xcrun", "--sdk", "macosx", "--show-sdk-path" },
        });
        defer allocator.free(result.stderr);
        defer allocator.free(result.stdout);

        if (result.term.Exited != 0) {
            std.debug.print("Failed to get SDK path: {s}\n", .{result.stderr});
            return error.SDKPathFailed;
        }

        const trimmed_path = std.mem.trim(u8, result.stdout, "\n");
        if (trimmed_path.len == 0) {
            std.debug.print("SDK path is empty\n", .{});
            return error.EmptySDKPath;
        }

        break :blk try allocator.dupe(u8, trimmed_path);
    };
    defer allocator.free(sdk_path);

    // Link
    {
        const lib_path = try std.fmt.allocPrint(allocator, "-L{s}/usr/lib", .{sdk_path});
        defer allocator.free(lib_path);

        const result = try std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{ "ld", object_file, "-o", executable_file, lib_path, "-syslibroot", sdk_path, "-lSystem", "-e", "_main", "-arch", "arm64" },
        });
        defer allocator.free(result.stderr);

        if (result.term.Exited != 0) {
            std.debug.print("Linking failed: {s}\n", .{result.stderr});
            return error.LinkingFailed;
        }
    }

    // Make executable
    {
        const file = try std.fs.cwd().openFile(executable_file, .{ .mode = .read_write });
        defer file.close();
        try file.chmod(0o755);
    }

    // Clean up object file
    std.fs.cwd().deleteFile(object_file) catch |err| {
        std.debug.print("Warning: Failed to delete object file: {s}. Error: {}\n", .{ object_file, err });
    };
}

fn runExecutable(allocator: std.mem.Allocator, executable_file: []const u8) !void {
    std.debug.print("Running executable: {s}\n", .{executable_file});

    var child = std.process.Child.init(&[_][]const u8{executable_file}, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();

    const stdout = child.stdout.?;
    const stderr = child.stderr.?;

    var stdout_thread = try std.Thread.spawn(.{}, readAndPrintOutput, .{ stdout, std.io.getStdOut().writer() });
    var stderr_thread = try std.Thread.spawn(.{}, readAndPrintOutput, .{ stderr, std.io.getStdErr().writer() });

    const term = try child.wait();

    stdout_thread.join();
    stderr_thread.join();
    switch (term) {
        .Exited => |code| {
            if (code != 0) {
                std.debug.print("Program exited with code: {}\n", .{code});
            }
        },
        .Signal => |sig| {
            std.debug.print("Program terminated by signal: {}\n", .{sig});
        },
        .Stopped => |sig| {
            std.debug.print("Program stopped by signal: {}\n", .{sig});
        },
        .Unknown => |code| {
            std.debug.print("Program terminated with unknown status: {}\n", .{code});
        },
    }
}

fn readAndPrintOutput(reader: anytype, writer: anytype) !void {
    var buf: [4096]u8 = undefined;
    while (true) {
        const bytes_read = try reader.read(&buf);
        if (bytes_read == 0) break;
        try writer.writeAll(buf[0..bytes_read]);
    }
}
