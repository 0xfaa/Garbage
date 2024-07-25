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
    defer tokens.deinit();
    for (tokens.items) |t| std.debug.print("token: type = {} | value = {s}\n", .{ t.type, t.value });

    var program = try parse(tokens.items, &allocator);
    defer program.deinit(&allocator);
    try program.print(1, "root");

    var asm_code = std.ArrayList(u8).init(allocator);
    defer asm_code.deinit();

    try asm_code.appendSlice(
        \\.global _main
        \\.align 2
        \\_itoa:
        \\mov x2, x0      ; Copy the input num to x2 for division
        \\mov x3, #0      ; set the ascii reg to #0
        \\mov x4, #10     ; set the divider to #10
        \\mov x5, #0      ; init quotient to #0
        \\mov x6, #0      ; digit counter for buffer offset #0
        \\mov x7, #0  
        \\.itoa_loop:
        \\udiv x5, x2, x4
        \\msub x3, x5, x4, x2
        \\mov x2, x5
        \\add x3, x3, #48
        \\sub x7, x1, x6
        \\sub x7, x7, #1
        \\strb w3, [x7]
        \\add x6, x6, #1
        \\cmp x2, #0
        \\bne .itoa_loop
        \\mov x2, x6
        \\sub x1, x1, x6
        \\ret
        \\ _printInt:
        \\ stp x30, x29, [sp, #-16]!
        \\ mov x29, sp
        \\ sub sp, sp, #21
        \\ mov x1, sp
        \\ bl _itoa
        \\ mov w0, #10
        \\ strb w0, [x1, x2]
        \\ add x2, x2, #1
        \\ mov x0, #0        ; stdout file descriptor (0)
        \\ mov x16, #4       ; write call (4)
        \\ svc 0
        \\ add sp, sp, #21
        \\ ldp x30, x29, [sp], #16
        \\ ret
        \\
        \\_main:
        \\
    );
    try codegen_init(program, asm_code.writer());
    try asm_code.appendSlice(
        \\
        \\_terminate:
        \\    mov x0, #0  // Exit syscall number
        \\    mov x16, #1 // Terminate syscall
        \\    svc 0       // Trigger syscall
        \\
    );

    return try allocator.dupe(u8, asm_code.items);
}
