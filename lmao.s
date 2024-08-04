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
    sub sp, sp, #48

    ; Say variable declaration
    mov x0, #2          // AF_INET
    mov x1, #1          // SOCK_STREAM
    mov x2, #0          // protocol (0 = default)
    mov x16, #97        // socket syscall
    svc #0x80
    cmp x0, #0
    b.lt socket_create_error
    mov x19, x0         // save socket descriptor to x19

    ; Set socket to blocking mode
    mov x0, x19         // socket fd
    mov x1, #3          // F_GETFL
    mov x16, #92        // fcntl syscall
    svc #0x80
    bic x1, x0, #0x800  // Set O_NONBLOCK flag
    mov x0, x19         // socket fd
    mov x2, x1          // New flags
    mov x1, #4          // F_SETFL
    mov x16, #92        // fcntl syscall
    svc #0x80
    cmp x0, #0
    b.lt socket_create_error
    mov x0, x19         // return the socket descriptor
    b socket_create_end
socket_create_error:
    mov x1, x0          // save error code to x1
    mov x0, #1          // prepare for exit syscall
    mov x16, #1         // exit syscall
    svc #0x80
socket_create_end:    str x0, [x29, #-32]

    ; Socket bind
    ldr x0, [x29, #-32]
    mov x9, x0          // save socket fd to x9
    mov x0, #8888
    mov x10, x0         // save port to x10
    sub sp, sp, #16     // allocate 16 bytes on stack for sockaddr_in
    mov x1, #2          // AF_INET
    strh w1, [sp]       // store sin_family
    ; rev w10, w10        // convert port to network byte order
    mov w10, #0xb822

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
    ; Socket listen
    ldr x0, [x29, #-32]
    mov x9, x0          // save socket fd to x9
    mov w0, #5
    mov x1, x0          // move backlog to x1
    mov x0, x9          // socket fd
    mov x16, #106       // listen syscall
    svc #0x80
    cmp x0, #0
    b.ge socket_listen_ok
    mov x1, x0          // save error code
    mov x0, #1          // exit syscall
    mov x16, #1
    svc #0x80
socket_listen_ok:
    mov x1, x0          // save result to x1
.L0_loop:
    mov w0, #1
    mov x1, x0
    mov w0, #0
    cmp x1, x0
    cset w0, gt
    cmp x0, #0
    beq .L0_end

    ; Say variable declaration

    ; Socket accept
    ldr x0, [x29, #-32]
    mov x9, x0          // save socket fd to x9
    mov x0, x9          // socket fd
    mov x1, #0          // NULL for client address
    mov x2, #0          // NULL for address length
    mov x16, #30        // accept syscall
    svc #0x80
    cmp x0, #0
    b.ge socket_accept_ok
    mov x1, x0          // save error code
    mov x0, #1          // exit syscall
    mov x16, #1
    svc #0x80
socket_accept_ok:
    mov x1, x0          // save client socket fd to x1
    str x0, [x29, #-40]

    ; Say variable declaration
    mov w0, #72
    strb w0, [x29, #-93]
    mov w0, #84
    strb w0, [x29, #-92]
    mov w0, #84
    strb w0, [x29, #-91]
    mov w0, #80
    strb w0, [x29, #-90]
    mov w0, #47
    strb w0, [x29, #-89]
    mov w0, #49
    strb w0, [x29, #-88]
    mov w0, #46
    strb w0, [x29, #-87]
    mov w0, #49
    strb w0, [x29, #-86]
    mov w0, #32
    strb w0, [x29, #-85]
    mov w0, #50
    strb w0, [x29, #-84]
    mov w0, #48
    strb w0, [x29, #-83]
    mov w0, #48
    strb w0, [x29, #-82]
    mov w0, #32
    strb w0, [x29, #-81]
    mov w0, #79
    strb w0, [x29, #-80]
    mov w0, #75
    strb w0, [x29, #-79]
    mov w0, #13
    strb w0, [x29, #-78]
    mov w0, #10
    strb w0, [x29, #-77]
    mov w0, #67
    strb w0, [x29, #-76]
    mov w0, #111
    strb w0, [x29, #-75]
    mov w0, #110
    strb w0, [x29, #-74]
    mov w0, #116
    strb w0, [x29, #-73]
    mov w0, #101
    strb w0, [x29, #-72]
    mov w0, #110
    strb w0, [x29, #-71]
    mov w0, #116
    strb w0, [x29, #-70]
    mov w0, #45
    strb w0, [x29, #-69]
    mov w0, #84
    strb w0, [x29, #-68]
    mov w0, #121
    strb w0, [x29, #-67]
    mov w0, #112
    strb w0, [x29, #-66]
    mov w0, #101
    strb w0, [x29, #-65]
    mov w0, #58
    strb w0, [x29, #-64]
    mov w0, #32
    strb w0, [x29, #-63]
    mov w0, #116
    strb w0, [x29, #-62]
    mov w0, #101
    strb w0, [x29, #-61]
    mov w0, #120
    strb w0, [x29, #-60]
    mov w0, #116
    strb w0, [x29, #-59]
    mov w0, #47
    strb w0, [x29, #-58]
    mov w0, #112
    strb w0, [x29, #-57]
    mov w0, #108
    strb w0, [x29, #-56]
    mov w0, #97
    strb w0, [x29, #-55]
    mov w0, #105
    strb w0, [x29, #-54]
    mov w0, #110
    strb w0, [x29, #-53]
    mov w0, #13
    strb w0, [x29, #-52]
    mov w0, #10
    strb w0, [x29, #-51]
    mov w0, #67
    strb w0, [x29, #-50]
    mov w0, #111
    strb w0, [x29, #-49]
    mov w0, #110
    strb w0, [x29, #-48]

    ; Socket write
    ldr x0, [x29, #-40]
    mov x9, x0          // save socket fd to x9
    add x0, x29, #-93
    mov x10, x0         // save buffer address to x10
    mov w0, #46
    mov x11, x0         // save length to x11
    mov x0, x9          // socket fd
    mov x1, x10         // buffer address
    mov x2, x11         // length
    mov x16, #4         // write syscall
    svc #0x80
    cmp x0, #0
    b.ge socket_write_ok
    mov x1, x0          // save error code
    mov x0, #1          // exit syscall
    mov x16, #1
    svc #0x80
socket_write_ok:
    mov x1, x0          // save number of bytes written to x1

    ; Socket close
    ldr x0, [x29, #-40]
    mov x9, x0          // save socket fd to x9
    mov x0, x9          // socket fd
    mov x16, #6         // close syscall
    svc #0x80
    cmp x0, #0
    b.ge socket_close_ok
    mov x1, x0          // save error code
    mov x0, #1          // exit syscall
    mov x16, #1
    svc #0x80
socket_close_ok:
    mov x1, x0          // save result to x1
    b .L0_loop
.L0_end:
    mov w0, #0
    bl _printInt
    add sp, sp, #32
    ldp x29, x30, [sp], #16

_terminate:
    mov x0, #0  // Exit syscall number
    mov x16, #1 // Terminate syscall
    svc 0       // Trigger syscall
