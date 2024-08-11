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
    sub sp, sp, #1184

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
    mov x0, #6969
    mov x10, x0         // save port to x10
    sub sp, sp, #16     // allocate 16 bytes on stack for sockaddr_in
    mov x1, #2          // AF_INET
    strh w1, [sp]       // store sin_family
    rev16 w10, w10        // convert port to network byte order

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
    mov x1, x0          // save result to x1

    ; Say variable declaration

    ; Say variable declaration
    mov w0, #72
    strb w0, [x29, #-1169]
    mov w0, #84
    strb w0, [x29, #-1168]
    mov w0, #84
    strb w0, [x29, #-1167]
    mov w0, #80
    strb w0, [x29, #-1166]
    mov w0, #47
    strb w0, [x29, #-1165]
    mov w0, #49
    strb w0, [x29, #-1164]
    mov w0, #46
    strb w0, [x29, #-1163]
    mov w0, #49
    strb w0, [x29, #-1162]
    mov w0, #32
    strb w0, [x29, #-1161]
    mov w0, #50
    strb w0, [x29, #-1160]
    mov w0, #48
    strb w0, [x29, #-1159]
    mov w0, #48
    strb w0, [x29, #-1158]
    mov w0, #10
    strb w0, [x29, #-1157]
    mov w0, #67
    strb w0, [x29, #-1156]
    mov w0, #111
    strb w0, [x29, #-1155]
    mov w0, #110
    strb w0, [x29, #-1154]
    mov w0, #116
    strb w0, [x29, #-1153]
    mov w0, #101
    strb w0, [x29, #-1152]
    mov w0, #110
    strb w0, [x29, #-1151]
    mov w0, #116
    strb w0, [x29, #-1150]
    mov w0, #45
    strb w0, [x29, #-1149]
    mov w0, #84
    strb w0, [x29, #-1148]
    mov w0, #121
    strb w0, [x29, #-1147]
    mov w0, #112
    strb w0, [x29, #-1146]
    mov w0, #101
    strb w0, [x29, #-1145]
    mov w0, #58
    strb w0, [x29, #-1144]
    mov w0, #32
    strb w0, [x29, #-1143]
    mov w0, #116
    strb w0, [x29, #-1142]
    mov w0, #101
    strb w0, [x29, #-1141]
    mov w0, #120
    strb w0, [x29, #-1140]
    mov w0, #116
    strb w0, [x29, #-1139]
    mov w0, #47
    strb w0, [x29, #-1138]
    mov w0, #104
    strb w0, [x29, #-1137]
    mov w0, #116
    strb w0, [x29, #-1136]
    mov w0, #109
    strb w0, [x29, #-1135]
    mov w0, #108
    strb w0, [x29, #-1134]
    mov w0, #10
    strb w0, [x29, #-1133]
    mov w0, #67
    strb w0, [x29, #-1132]
    mov w0, #111
    strb w0, [x29, #-1131]
    mov w0, #110
    strb w0, [x29, #-1130]
    mov w0, #116
    strb w0, [x29, #-1129]
    mov w0, #101
    strb w0, [x29, #-1128]
    mov w0, #110
    strb w0, [x29, #-1127]
    mov w0, #116
    strb w0, [x29, #-1126]
    mov w0, #45
    strb w0, [x29, #-1125]
    mov w0, #76
    strb w0, [x29, #-1124]
    mov w0, #101
    strb w0, [x29, #-1123]
    mov w0, #110
    strb w0, [x29, #-1122]
    mov w0, #103
    strb w0, [x29, #-1121]
    mov w0, #116
    strb w0, [x29, #-1120]
    mov w0, #104
    strb w0, [x29, #-1119]
    mov w0, #58
    strb w0, [x29, #-1118]
    mov w0, #32
    strb w0, [x29, #-1117]
    mov w0, #52
    strb w0, [x29, #-1116]
    mov w0, #57
    strb w0, [x29, #-1115]
    mov w0, #10
    strb w0, [x29, #-1114]
    mov w0, #10
    strb w0, [x29, #-1113]
    mov w0, #60
    strb w0, [x29, #-1112]
    mov w0, #116
    strb w0, [x29, #-1111]
    mov w0, #105
    strb w0, [x29, #-1110]
    mov w0, #116
    strb w0, [x29, #-1109]
    mov w0, #108
    strb w0, [x29, #-1108]
    mov w0, #101
    strb w0, [x29, #-1107]
    mov w0, #62
    strb w0, [x29, #-1106]
    mov w0, #71
    strb w0, [x29, #-1105]
    mov w0, #97
    strb w0, [x29, #-1104]
    mov w0, #114
    strb w0, [x29, #-1103]
    mov w0, #98
    strb w0, [x29, #-1102]
    mov w0, #97
    strb w0, [x29, #-1101]
    mov w0, #103
    strb w0, [x29, #-1100]
    mov w0, #101
    strb w0, [x29, #-1099]
    mov w0, #60
    strb w0, [x29, #-1098]
    mov w0, #47
    strb w0, [x29, #-1097]
    mov w0, #116
    strb w0, [x29, #-1096]
    mov w0, #105
    strb w0, [x29, #-1095]
    mov w0, #116
    strb w0, [x29, #-1094]
    mov w0, #108
    strb w0, [x29, #-1093]
    mov w0, #101
    strb w0, [x29, #-1092]
    mov w0, #62
    strb w0, [x29, #-1091]
    mov w0, #60
    strb w0, [x29, #-1090]
    mov w0, #98
    strb w0, [x29, #-1089]
    mov w0, #111
    strb w0, [x29, #-1088]
    mov w0, #100
    strb w0, [x29, #-1087]
    mov w0, #121
    strb w0, [x29, #-1086]
    mov w0, #62
    strb w0, [x29, #-1085]
    mov w0, #60
    strb w0, [x29, #-1084]
    mov w0, #98
    strb w0, [x29, #-1083]
    mov w0, #62
    strb w0, [x29, #-1082]
    mov w0, #119
    strb w0, [x29, #-1081]
    mov w0, #101
    strb w0, [x29, #-1080]
    mov w0, #32
    strb w0, [x29, #-1079]
    mov w0, #98
    strb w0, [x29, #-1078]
    mov w0, #97
    strb w0, [x29, #-1077]
    mov w0, #108
    strb w0, [x29, #-1076]
    mov w0, #108
    strb w0, [x29, #-1075]
    mov w0, #60
    strb w0, [x29, #-1074]
    mov w0, #47
    strb w0, [x29, #-1073]
    mov w0, #98
    strb w0, [x29, #-1072]
    mov w0, #62
    strb w0, [x29, #-1071]
    mov w0, #60
    strb w0, [x29, #-1070]
    mov w0, #47
    strb w0, [x29, #-1069]
    mov w0, #98
    strb w0, [x29, #-1068]
    mov w0, #111
    strb w0, [x29, #-1067]
    mov w0, #100
    strb w0, [x29, #-1066]
    mov w0, #121
    strb w0, [x29, #-1065]
    mov w0, #62
    strb w0, [x29, #-1064]
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
    mov x1, x0          // save client socket fd to x1
    str x0, [x29, #-1176]

    ; Socket read
    ldr x0, [x29, #-1176]
    mov x9, x0          // save socket fd to x9
    add x0, x29, #-1063
    mov x10, x0         // save buffer address to x10
    mov x0, #1024
    mov x11, x0         // save length to x11
    mov x0, x9          // socket fd
    mov x1, x10         // buffer address
    mov x2, x11         // length
    mov x16, #3         // read syscall
    svc #0x80
    cmp x0, #0
    b.lt socket_read_error
    mov x1, x0          // save number of bytes read to x1
    b socket_read_end
socket_read_error:
    mov x1, #-1         // set error indicator
socket_read_end:    add x0, x29, #-1063
    mov x1, x0
    mov x0, #1024
    mov x2, x0
    mov x3, #1024
    cmp x2, x3
    csel x2, x2, x3, ls
    mov x0, #1     ; stdout file descriptor
    mov x16, #4    ; write syscall number
    svc 0

    ; Socket write
    ldr x0, [x29, #-1176]
    mov x9, x0          // save socket fd to x9
    add x0, x29, #-1169
    mov x10, x0         // save buffer address to x10
    mov w0, #106
    mov x11, x0         // save length to x11
    mov x0, x9          // socket fd
    mov x1, x10         // buffer address
    mov x2, x11         // length
    mov x16, #4         // write syscall
    svc #0x80
    mov x1, x0          // save number of bytes written to x1

    ; Socket close
    ldr x0, [x29, #-1176]
    mov x9, x0          // save socket fd to x9
    mov x0, x9          // socket fd
    mov x16, #6         // close syscall
    svc #0x80
    mov x1, x0          // save result to x1
    b .L0_loop
.L0_end:

    ; Socket close
    ldr x0, [x29, #-32]
    mov x9, x0          // save socket fd to x9
    mov x0, x9          // socket fd
    mov x16, #6         // close syscall
    svc #0x80
    mov x1, x0          // save result to x1
    mov w0, #0
    bl _printInt
    add sp, sp, #1168
    ldp x29, x30, [sp], #16

_terminate:
    mov x0, #0  // Exit syscall number
    mov x16, #1 // Terminate syscall
    svc 0       // Trigger syscall
