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

_main:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    sub sp, sp, #96

    ; Say variable declaration

    ; Socket create
    mov x0, #2          // AF_INET
    mov x1, #1          // SOCK_STREAM
    mov x2, #0          // protocol (0 = default)
    mov x16, #97        // socket syscall
    svc #0x80
    mov x1, x0          // save socket descriptor to x1    str x0, [x29, #-32]
    ldr x0, [x29, #-32]
    bl _printInt

    ; Say variable declaration
    mov x0, #8888
    str x0, [x29, #-40]

    ; Socket bind
    ldr x0, [x29, #-32]
    mov x9, x0          // save socket fd to x9
    ldr x0, [x29, #-40]
    mov x10, x0         // save port to x10
    sub sp, sp, #16     // allocate 16 bytes on stack for sockaddr_in
    mov x1, #2          // AF_INET
    strh w1, [sp]       // store sin_family
    rev w10, w10        // convert port to network byte order
    strh w10, [sp, #2]  // store sin_port
    mov x11, #0         // INADDR_ANY
    str x11, [sp, #4]   // store sin_addr

    mov x0, x9          // socket fd
    mov x1, sp          // pointer to sockaddr_in
    mov x2, #16         // length of sockaddr_in
    mov x16, #104       // bind syscall
    svc #0x80

    add sp, sp, #16     // deallocate stack space
    mov x1, x0          // save result to x1
    ; Say variable declaration
    mov w0, #5
    str x0, [x29, #-48]

    ; Socket listen
    ldr x0, [x29, #-32]
    mov x9, x0          // save socket fd to x9
    ldr x0, [x29, #-48]
    mov x1, x0          // move backlog to x1
    mov x0, x9          // socket fd
    mov x16, #106       // listen syscall
    svc #0x80
    mov x1, x0          // save result to x1

    ; Say variable declaration

    ; Socket accept
    ldr x0, [x29, #-32]
    mov x9, x0          // save socket fd to x9
    mov x0, x9          // socket fd
    mov x1, #0          // NULL for client address
    mov x2, #0          // NULL for address length
    mov x16, #30        // accept syscall
    svc #0x80
    mov x1, x0          // save client socket fd to x1
    str x0, [x29, #-56]
    ldr x0, [x29, #-56]
    bl _printInt

    ; Say variable declaration
    mov w0, #72
    strb w0, [x29, #-80]
    mov w0, #84
    strb w0, [x29, #-79]
    mov w0, #84
    strb w0, [x29, #-78]
    mov w0, #80
    strb w0, [x29, #-77]
    mov w0, #47
    strb w0, [x29, #-76]
    mov w0, #49
    strb w0, [x29, #-75]
    mov w0, #46
    strb w0, [x29, #-74]
    mov w0, #49
    strb w0, [x29, #-73]
    mov w0, #32
    strb w0, [x29, #-72]
    mov w0, #50
    strb w0, [x29, #-71]
    mov w0, #48
    strb w0, [x29, #-70]
    mov w0, #48
    strb w0, [x29, #-69]
    mov w0, #32
    strb w0, [x29, #-68]
    mov w0, #79
    strb w0, [x29, #-67]
    mov w0, #75
    strb w0, [x29, #-66]
    mov w0, #13
    strb w0, [x29, #-65]
    mov w0, #10
    strb w0, [x29, #-64]

    ; Socket write
    ldr x0, [x29, #-56]
    mov x9, x0          // save socket fd to x9
    add x0, x29, #-64
    mov x1, x0
    mov w0, #0
    sub x0, x1, x0
    ldrb w0, [x0]
    mov x10, x0         // save buffer address to x10
    mov w0, #17
    mov x11, x0         // save length to x11
    mov x0, x9          // socket fd
    mov x1, x10         // buffer address
    mov x2, x11         // length
    mov x16, #4         // write syscall
    svc #0x80
    mov x1, x0          // save number of bytes written to x1

    ; Socket close
    ldr x0, [x29, #-56]
    mov x9, x0          // save socket fd to x9
    mov x0, x9          // socket fd
    mov x16, #6         // close syscall
    svc #0x80
    mov x1, x0          // save result to x1

    ; Socket close
    ldr x0, [x29, #-32]
    mov x9, x0          // save socket fd to x9
    mov x0, x9          // socket fd
    mov x16, #6         // close syscall
    svc #0x80
    mov x1, x0          // save result to x1
    mov w0, #0
    bl _printInt
    add sp, sp, #80
    ldp x29, x30, [sp], #16

_terminate:
    mov x0, #0  // Exit syscall number
    mov x16, #1 // Terminate syscall
    svc 0       // Trigger syscall
