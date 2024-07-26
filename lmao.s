.global _main
.align 2
_itoa:
mov x2, x0      ; Copy the input num to x2 for division
mov x3, #0      ; set the ascii reg to #0
mov x4, #10     ; set the divider to #10
mov x5, #0      ; init quotient to #0
mov x6, #0      ; digit counter for buffer offset #0
mov x7, #0  
.itoa_loop:
udiv x5, x2, x4
msub x3, x5, x4, x2
mov x2, x5
add x3, x3, #48
sub x7, x1, x6
sub x7, x7, #1
strb w3, [x7]
add x6, x6, #1
cmp x2, #0
bne .itoa_loop
mov x2, x6
sub x1, x1, x6
ret
_printInt:
stp x30, x29, [sp, #-16]!
mov x29, sp
sub sp, sp, #21
mov x1, sp
bl _itoa
mov w0, #10
strb w0, [x1, x2]
add x2, x2, #1
mov x0, #0        ; stdout file descriptor (0)
mov x16, #4       ; write call (4)
svc 0
add sp, sp, #21
ldp x30, x29, [sp], #16
ret

_main:    stp x29, x30, [sp, #-16]!
    mov x29, sp
    sub sp, sp, #32
    mov x0, #0
    str x0, [x29, #-16]
.L0_loop:
    ldr x0, [x29, #-16]
    str x0, [sp, #-16]!
    mov x0, #5
    mov x1, x0
    ldr x0, [sp], #16
    cmp x0, x1
    cset x0, lt
    cmp x0, #0
    beq .L0_end
    ldr x0, [x29, #-16]
    str x0, [sp, #-16]!
    mov x0, #2
    mov x1, x0
    ldr x0, [sp], #16
    sdiv x2, x0, x1
    msub x0, x2, x1, x0
    str x0, [sp, #-16]!
    mov x0, #0
    mov x1, x0
    ldr x0, [sp], #16
    cmp x0, x1
    cset x0, eq
    cmp x0, #0
    beq .L1
    mov x0, #69
    bl _printInt
.L1:
    ldr x0, [x29, #-16]
    str x0, [sp, #-16]!
    mov x0, #3
    mov x1, x0
    ldr x0, [sp], #16
    sdiv x2, x0, x1
    msub x0, x2, x1, x0
    str x0, [sp, #-16]!
    mov x0, #0
    mov x1, x0
    ldr x0, [sp], #16
    cmp x0, x1
    cset x0, eq
    cmp x0, #0
    beq .L2
    mov x0, #420
    bl _printInt
.L2:
    ldr x0, [x29, #-16]
    str x0, [sp, #-16]!
    mov x0, #2
    mov x1, x0
    ldr x0, [sp], #16
    sdiv x2, x0, x1
    msub x0, x2, x1, x0
    str x0, [sp, #-16]!
    mov x0, #0
    mov x1, x0
    ldr x0, [sp], #16
    cmp x0, x1
    cset x0, ne
    cmp x0, #0
    beq .L3
    ldr x0, [x29, #-16]
    str x0, [sp, #-16]!
    mov x0, #3
    mov x1, x0
    ldr x0, [sp], #16
    sdiv x2, x0, x1
    msub x0, x2, x1, x0
    str x0, [sp, #-16]!
    mov x0, #0
    mov x1, x0
    ldr x0, [sp], #16
    cmp x0, x1
    cset x0, ne
    cmp x0, #0
    beq .L4
    ldr x0, [x29, #-16]
    bl _printInt
.L4:
.L3:
    ldr x0, [x29, #-16]
    str x0, [sp, #-16]!
    mov x0, #1
    mov x1, x0
    ldr x0, [sp], #16
    add x0, x0, x1
    str x0, [x29, #-16]
    b .L0_loop
.L0_end:
    add sp, sp, #16
    ldp x29, x30, [sp], #16

_terminate:
    mov x0, #0  // Exit syscall number
    mov x16, #1 // Terminate syscall
    svc 0       // Trigger syscall
