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
    ; Preserve link register
    stp x30, x29, [sp, #-16]!
    mov x29, sp
    
    ; allocate 21 bytes from stack
    sub sp, sp, #21
    mov x1, sp

    bl _itoa

    ; Add \n at the end
    mov w0, #10
    strb w0, [x1, x2]
    add x2, x2, #1

    ; Print
    mov x0, #0        ; stdout file descriptor (0)
    ; We don't need these two because the registers
    ; are already in the right positions.
    ; mov x1, x1      ; buffer start
    ; mov x2, x2      ; buffer length
    mov x16, #4       ; write call (4)
    svc 0

    add sp, sp, #21

    ; Restore link register
    ldp x30, x29, [sp], #16
    ret

_main:
    mov x0, #698
    bl _printInt

_terminate:
    mov x0,  #0  // Exit syscall number
    mov x16, #1  // Terminate syscall
    svc 0        // Trigger syscall
