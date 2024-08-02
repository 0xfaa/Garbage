.global _main
.align 2

.data
http_response:
    .ascii "HTTP/1.1 200 OK\r\n"
    .ascii "Content-Type: text/html\r\n"
    .ascii "Content-Length: 95\r\n"
    .ascii "\r\n"
    .ascii "<html><head><title>Hello, World!</title></head>"
    .ascii "<body>Hello World</body></html>\n"
http_response_len = . - http_response

.text
_main:
    // Create socket
    mov x0, #2  // AF_INET
    mov x1, #1  // SOCK_STREAM
    mov x2, #0  // protocol
    mov x16, #97  // socket syscall
    svc #0x80
    mov x19, x0  // Save socket fd

    // Set SO_REUSEADDR
    sub sp, sp, #16
    mov w1, #1  // SOL_SOCKET
    mov w2, #2  // SO_REUSEADDR
    mov w3, #1
    str w3, [sp]
    mov x3, sp
    mov x4, #4
    mov x0, x19  // socket fd
    mov x16, #105  // setsockopt syscall
    svc #0x80
    add sp, sp, #16

    // Prepare sockaddr_in structure
    sub sp, sp, #16
    mov w1, #2  // AF_INET
    strh w1, [sp]
    mov w1, #0xb822  // Port 8888 in network byte order
    strh w1, [sp, #2]
    str xzr, [sp, #4]  // INADDR_ANY

    // Bind
    mov x0, x19  // socket fd
    mov x1, sp  // sockaddr_in structure
    mov x2, #16  // length
    mov x16, #104  // bind syscall
    svc #0x80

    // Listen
    mov x0, x19  // socket fd
    mov x1, #5  // backlog
    mov x16, #106  // listen syscall
    svc #0x80

accept_loop:
    // Accept
    mov x0, x19  // socket fd
    mov x1, #0  // NULL
    mov x2, #0  // NULL
    mov x16, #30  // accept syscall
    svc #0x80
    mov x20, x0  // Save client fd



    // Write HTTP response to client
    mov x0, x20  // client fd
    adrp x1, http_response@PAGE
    add x1, x1, http_response@PAGEOFF
    mov x2, #http_response_len
    mov x16, #4  // write syscall
    svc #0x80

    // Close client socket
    mov x0, x20
    mov x16, #6  // close syscall
    svc #0x80

    b accept_loop  // Loop back to accept more connections

    // Exit (we never reach here in this example)
    mov x0, #0
    mov x16, #1  // exit syscall
    svc #0x80