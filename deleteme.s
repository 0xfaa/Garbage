; CODE GENERATED BY CLAUDE
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
    sub sp, sp, #64

    ; Socket create
    mov x0, #2          // AF_INET
    mov x1, #1          // SOCK_STREAM
    mov x2, #0          // protocol (0 = default)
    mov x16, #97        // socket syscall
    svc #0x80
    cmp x0, #0
    b.ge socket_create_ok
    mov x1, x0          // save error code
    mov x0, #1          // exit syscall
    mov x16, #1
    svc #0x80
socket_create_ok:
    mov x19, x0         // save socket descriptor to x19
    str x0, [x29, #-32]
    mov x0, x19
    bl _printInt

    ; Set socket to blocking mode (clear O_NONBLOCK flag)
    mov x0, x19         // socket fd
    mov x1, #3          // F_GETFL
    mov x16, #92        // fcntl syscall
    svc #0x80
    bic x1, x0, #0x800  // Clear O_NONBLOCK flag
    mov x0, x19         // socket fd
    mov x2, x1          // New flags
    mov x1, #4          // F_SETFL
    mov x16, #92        // fcntl syscall
    svc #0x80

    ; Prepare sockaddr_in structure
    sub sp, sp, #16
    mov w1, #2          // AF_INET
    strh w1, [sp]
    mov w1, #0xb822     // Port 8888 in network byte order
    strh w1, [sp, #2]
    mov x1, #0          // INADDR_ANY
    str x1, [sp, #4]

    ; Socket bind
    mov x0, x19         // socket fd
    mov x1, sp          // pointer to sockaddr_in
    mov x2, #16         // length of sockaddr_in
    mov x16, #104       // bind syscall
    svc #0x80
    add sp, sp, #16     // deallocate stack space
    cmp x0, #0
    b.ge socket_bind_ok
    mov x1, x0          // save error code
    mov x0, #1          // exit syscall
    mov x16, #1
    svc #0x80
socket_bind_ok:

    ; Socket listen
    mov x0, x19         // socket fd
    mov x1, #5          // backlog
    mov x16, #106       // listen syscall
    svc #0x80
    cmp x0, #0
    b.ge socket_listen_ok
    mov x1, x0          // save error code
    mov x0, #1          // exit syscall
    mov x16, #1
    svc #0x80
socket_listen_ok:

    ; Infinite loop for accepting connections
.accept_loop:
    ; Socket accept
    mov x0, x19         // socket fd
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
    mov x20, x0         // save client socket fd to x20
    mov x0, x20
    bl _printInt

    ; Prepare HTTP response
    adrp x1, http_response@PAGE
    add x1, x1, http_response@PAGEOFF
    mov x2, #http_response_len

    ; Socket write
    mov x0, x20         // client socket fd
    mov x16, #4         // write syscall
    svc #0x80
    cmp x0, #0
    b.ge socket_write_ok
    mov x1, x0          // save error code
    mov x0, #1          // exit syscall
    mov x16, #1
    svc #0x80
socket_write_ok:

    ; Socket close (client)
    mov x0, x20         // client socket fd
    mov x16, #6         // close syscall
    svc #0x80
    cmp x0, #0
    b.ge socket_close_ok
    mov x1, x0          // save error code
    mov x0, #1          // exit syscall
    mov x16, #1
    svc #0x80
socket_close_ok:

    b .accept_loop

    ; We never reach here in this example
    mov w0, #0
    bl _printInt
    add sp, sp, #48
    ldp x29, x30, [sp], #16

_terminate:
    mov x0, #0  // Exit syscall number
    mov x16, #1 // Terminate syscall
    svc 0       // Trigger syscall

.data
http_response:
    .ascii "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 1\r\n\r\nA"
http_response_len = . - http_response