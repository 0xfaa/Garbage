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
    mov x0, #1024
    mov x8, #-1064
    str x0, [x29, x8]

    ; Say variable declaration
    mov w0, #72
    mov x8, #-1173
    strb w0, [x29, x8]
    mov w0, #84
    mov x8, #-1172
    strb w0, [x29, x8]
    mov w0, #84
    mov x8, #-1171
    strb w0, [x29, x8]
    mov w0, #80
    mov x8, #-1170
    strb w0, [x29, x8]
    mov w0, #47
    mov x8, #-1169
    strb w0, [x29, x8]
    mov w0, #49
    mov x8, #-1168
    strb w0, [x29, x8]
    mov w0, #46
    mov x8, #-1167
    strb w0, [x29, x8]
    mov w0, #49
    mov x8, #-1166
    strb w0, [x29, x8]
    mov w0, #32
    mov x8, #-1165
    strb w0, [x29, x8]
    mov w0, #50
    mov x8, #-1164
    strb w0, [x29, x8]
    mov w0, #48
    mov x8, #-1163
    strb w0, [x29, x8]
    mov w0, #48
    mov x8, #-1162
    strb w0, [x29, x8]
    mov w0, #10
    mov x8, #-1161
    strb w0, [x29, x8]
    mov w0, #67
    mov x8, #-1160
    strb w0, [x29, x8]
    mov w0, #111
    mov x8, #-1159
    strb w0, [x29, x8]
    mov w0, #110
    mov x8, #-1158
    strb w0, [x29, x8]
    mov w0, #116
    mov x8, #-1157
    strb w0, [x29, x8]
    mov w0, #101
    mov x8, #-1156
    strb w0, [x29, x8]
    mov w0, #110
    mov x8, #-1155
    strb w0, [x29, x8]
    mov w0, #116
    mov x8, #-1154
    strb w0, [x29, x8]
    mov w0, #45
    mov x8, #-1153
    strb w0, [x29, x8]
    mov w0, #84
    mov x8, #-1152
    strb w0, [x29, x8]
    mov w0, #121
    mov x8, #-1151
    strb w0, [x29, x8]
    mov w0, #112
    mov x8, #-1150
    strb w0, [x29, x8]
    mov w0, #101
    mov x8, #-1149
    strb w0, [x29, x8]
    mov w0, #58
    mov x8, #-1148
    strb w0, [x29, x8]
    mov w0, #32
    mov x8, #-1147
    strb w0, [x29, x8]
    mov w0, #116
    mov x8, #-1146
    strb w0, [x29, x8]
    mov w0, #101
    mov x8, #-1145
    strb w0, [x29, x8]
    mov w0, #120
    mov x8, #-1144
    strb w0, [x29, x8]
    mov w0, #116
    mov x8, #-1143
    strb w0, [x29, x8]
    mov w0, #47
    mov x8, #-1142
    strb w0, [x29, x8]
    mov w0, #104
    mov x8, #-1141
    strb w0, [x29, x8]
    mov w0, #116
    mov x8, #-1140
    strb w0, [x29, x8]
    mov w0, #109
    mov x8, #-1139
    strb w0, [x29, x8]
    mov w0, #108
    mov x8, #-1138
    strb w0, [x29, x8]
    mov w0, #10
    mov x8, #-1137
    strb w0, [x29, x8]
    mov w0, #67
    mov x8, #-1136
    strb w0, [x29, x8]
    mov w0, #111
    mov x8, #-1135
    strb w0, [x29, x8]
    mov w0, #110
    mov x8, #-1134
    strb w0, [x29, x8]
    mov w0, #116
    mov x8, #-1133
    strb w0, [x29, x8]
    mov w0, #101
    mov x8, #-1132
    strb w0, [x29, x8]
    mov w0, #110
    mov x8, #-1131
    strb w0, [x29, x8]
    mov w0, #116
    mov x8, #-1130
    strb w0, [x29, x8]
    mov w0, #45
    mov x8, #-1129
    strb w0, [x29, x8]
    mov w0, #76
    mov x8, #-1128
    strb w0, [x29, x8]
    mov w0, #101
    mov x8, #-1127
    strb w0, [x29, x8]
    mov w0, #110
    mov x8, #-1126
    strb w0, [x29, x8]
    mov w0, #103
    mov x8, #-1125
    strb w0, [x29, x8]
    mov w0, #116
    mov x8, #-1124
    strb w0, [x29, x8]
    mov w0, #104
    mov x8, #-1123
    strb w0, [x29, x8]
    mov w0, #58
    mov x8, #-1122
    strb w0, [x29, x8]
    mov w0, #32
    mov x8, #-1121
    strb w0, [x29, x8]
    mov w0, #52
    mov x8, #-1120
    strb w0, [x29, x8]
    mov w0, #53
    mov x8, #-1119
    strb w0, [x29, x8]
    mov w0, #10
    mov x8, #-1118
    strb w0, [x29, x8]
    mov w0, #10
    mov x8, #-1117
    strb w0, [x29, x8]
    mov w0, #60
    mov x8, #-1116
    strb w0, [x29, x8]
    mov w0, #116
    mov x8, #-1115
    strb w0, [x29, x8]
    mov w0, #105
    mov x8, #-1114
    strb w0, [x29, x8]
    mov w0, #116
    mov x8, #-1113
    strb w0, [x29, x8]
    mov w0, #108
    mov x8, #-1112
    strb w0, [x29, x8]
    mov w0, #101
    mov x8, #-1111
    strb w0, [x29, x8]
    mov w0, #62
    mov x8, #-1110
    strb w0, [x29, x8]
    mov w0, #71
    mov x8, #-1109
    strb w0, [x29, x8]
    mov w0, #97
    mov x8, #-1108
    strb w0, [x29, x8]
    mov w0, #114
    mov x8, #-1107
    strb w0, [x29, x8]
    mov w0, #98
    mov x8, #-1106
    strb w0, [x29, x8]
    mov w0, #97
    mov x8, #-1105
    strb w0, [x29, x8]
    mov w0, #103
    mov x8, #-1104
    strb w0, [x29, x8]
    mov w0, #101
    mov x8, #-1103
    strb w0, [x29, x8]
    mov w0, #60
    mov x8, #-1102
    strb w0, [x29, x8]
    mov w0, #47
    mov x8, #-1101
    strb w0, [x29, x8]
    mov w0, #116
    mov x8, #-1100
    strb w0, [x29, x8]
    mov w0, #105
    mov x8, #-1099
    strb w0, [x29, x8]
    mov w0, #116
    mov x8, #-1098
    strb w0, [x29, x8]
    mov w0, #108
    mov x8, #-1097
    strb w0, [x29, x8]
    mov w0, #101
    mov x8, #-1096
    strb w0, [x29, x8]
    mov w0, #62
    mov x8, #-1095
    strb w0, [x29, x8]
    mov w0, #60
    mov x8, #-1094
    strb w0, [x29, x8]
    mov w0, #98
    mov x8, #-1093
    strb w0, [x29, x8]
    mov w0, #111
    mov x8, #-1092
    strb w0, [x29, x8]
    mov w0, #100
    mov x8, #-1091
    strb w0, [x29, x8]
    mov w0, #121
    mov x8, #-1090
    strb w0, [x29, x8]
    mov w0, #62
    mov x8, #-1089
    strb w0, [x29, x8]
    mov w0, #60
    mov x8, #-1088
    strb w0, [x29, x8]
    mov w0, #98
    mov x8, #-1087
    strb w0, [x29, x8]
    mov w0, #62
    mov x8, #-1086
    strb w0, [x29, x8]
    mov w0, #52
    mov x8, #-1085
    strb w0, [x29, x8]
    mov w0, #48
    mov x8, #-1084
    strb w0, [x29, x8]
    mov w0, #52
    mov x8, #-1083
    strb w0, [x29, x8]
    mov w0, #60
    mov x8, #-1082
    strb w0, [x29, x8]
    mov w0, #47
    mov x8, #-1081
    strb w0, [x29, x8]
    mov w0, #98
    mov x8, #-1080
    strb w0, [x29, x8]
    mov w0, #62
    mov x8, #-1079
    strb w0, [x29, x8]
    mov w0, #60
    mov x8, #-1078
    strb w0, [x29, x8]
    mov w0, #47
    mov x8, #-1077
    strb w0, [x29, x8]
    mov w0, #98
    mov x8, #-1076
    strb w0, [x29, x8]
    mov w0, #111
    mov x8, #-1075
    strb w0, [x29, x8]
    mov w0, #100
    mov x8, #-1074
    strb w0, [x29, x8]
    mov w0, #121
    mov x8, #-1073
    strb w0, [x29, x8]
    mov w0, #62
    mov x8, #-1072
    strb w0, [x29, x8]

    ; Say variable declaration
    mov w0, #0
    mov x8, #-1176
    str x0, [x29, x8]
.L0_loop:
    mov w0, #1
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
    mov x8, #-1184
    str x0, [x29, x8]

    ; Say variable declaration
    mov w0, #72
    mov x8, #-1297
    strb w0, [x29, x8]
    mov w0, #84
    mov x8, #-1296
    strb w0, [x29, x8]
    mov w0, #84
    mov x8, #-1295
    strb w0, [x29, x8]
    mov w0, #80
    mov x8, #-1294
    strb w0, [x29, x8]
    mov w0, #47
    mov x8, #-1293
    strb w0, [x29, x8]
    mov w0, #49
    mov x8, #-1292
    strb w0, [x29, x8]
    mov w0, #46
    mov x8, #-1291
    strb w0, [x29, x8]
    mov w0, #49
    mov x8, #-1290
    strb w0, [x29, x8]
    mov w0, #32
    mov x8, #-1289
    strb w0, [x29, x8]
    mov w0, #50
    mov x8, #-1288
    strb w0, [x29, x8]
    mov w0, #48
    mov x8, #-1287
    strb w0, [x29, x8]
    mov w0, #48
    mov x8, #-1286
    strb w0, [x29, x8]
    mov w0, #10
    mov x8, #-1285
    strb w0, [x29, x8]
    mov w0, #67
    mov x8, #-1284
    strb w0, [x29, x8]
    mov w0, #111
    mov x8, #-1283
    strb w0, [x29, x8]
    mov w0, #110
    mov x8, #-1282
    strb w0, [x29, x8]
    mov w0, #116
    mov x8, #-1281
    strb w0, [x29, x8]
    mov w0, #101
    mov x8, #-1280
    strb w0, [x29, x8]
    mov w0, #110
    mov x8, #-1279
    strb w0, [x29, x8]
    mov w0, #116
    mov x8, #-1278
    strb w0, [x29, x8]
    mov w0, #45
    mov x8, #-1277
    strb w0, [x29, x8]
    mov w0, #84
    mov x8, #-1276
    strb w0, [x29, x8]
    mov w0, #121
    mov x8, #-1275
    strb w0, [x29, x8]
    mov w0, #112
    mov x8, #-1274
    strb w0, [x29, x8]
    mov w0, #101
    mov x8, #-1273
    strb w0, [x29, x8]
    mov w0, #58
    mov x8, #-1272
    strb w0, [x29, x8]
    mov w0, #32
    mov x8, #-1271
    strb w0, [x29, x8]
    mov w0, #116
    mov x8, #-1270
    strb w0, [x29, x8]
    mov w0, #101
    mov x8, #-1269
    strb w0, [x29, x8]
    mov w0, #120
    mov x8, #-1268
    strb w0, [x29, x8]
    mov w0, #116
    mov x8, #-1267
    strb w0, [x29, x8]
    mov w0, #47
    mov x8, #-1266
    strb w0, [x29, x8]
    mov w0, #104
    mov x8, #-1265
    strb w0, [x29, x8]
    mov w0, #116
    mov x8, #-1264
    strb w0, [x29, x8]
    mov w0, #109
    mov x8, #-1263
    strb w0, [x29, x8]
    mov w0, #108
    mov x8, #-1262
    strb w0, [x29, x8]
    mov w0, #10
    mov x8, #-1261
    strb w0, [x29, x8]
    mov w0, #67
    mov x8, #-1260
    strb w0, [x29, x8]
    mov w0, #111
    mov x8, #-1259
    strb w0, [x29, x8]
    mov w0, #110
    mov x8, #-1258
    strb w0, [x29, x8]
    mov w0, #116
    mov x8, #-1257
    strb w0, [x29, x8]
    mov w0, #101
    mov x8, #-1256
    strb w0, [x29, x8]
    mov w0, #110
    mov x8, #-1255
    strb w0, [x29, x8]
    mov w0, #116
    mov x8, #-1254
    strb w0, [x29, x8]
    mov w0, #45
    mov x8, #-1253
    strb w0, [x29, x8]
    mov w0, #76
    mov x8, #-1252
    strb w0, [x29, x8]
    mov w0, #101
    mov x8, #-1251
    strb w0, [x29, x8]
    mov w0, #110
    mov x8, #-1250
    strb w0, [x29, x8]
    mov w0, #103
    mov x8, #-1249
    strb w0, [x29, x8]
    mov w0, #116
    mov x8, #-1248
    strb w0, [x29, x8]
    mov w0, #104
    mov x8, #-1247
    strb w0, [x29, x8]
    mov w0, #58
    mov x8, #-1246
    strb w0, [x29, x8]
    mov w0, #32
    mov x8, #-1245
    strb w0, [x29, x8]
    mov w0, #52
    mov x8, #-1244
    strb w0, [x29, x8]
    mov w0, #57
    mov x8, #-1243
    strb w0, [x29, x8]
    mov w0, #10
    mov x8, #-1242
    strb w0, [x29, x8]
    mov w0, #10
    mov x8, #-1241
    strb w0, [x29, x8]
    mov w0, #60
    mov x8, #-1240
    strb w0, [x29, x8]
    mov w0, #116
    mov x8, #-1239
    strb w0, [x29, x8]
    mov w0, #105
    mov x8, #-1238
    strb w0, [x29, x8]
    mov w0, #116
    mov x8, #-1237
    strb w0, [x29, x8]
    mov w0, #108
    mov x8, #-1236
    strb w0, [x29, x8]
    mov w0, #101
    mov x8, #-1235
    strb w0, [x29, x8]
    mov w0, #62
    mov x8, #-1234
    strb w0, [x29, x8]
    mov w0, #71
    mov x8, #-1233
    strb w0, [x29, x8]
    mov w0, #97
    mov x8, #-1232
    strb w0, [x29, x8]
    mov w0, #114
    mov x8, #-1231
    strb w0, [x29, x8]
    mov w0, #98
    mov x8, #-1230
    strb w0, [x29, x8]
    mov w0, #97
    mov x8, #-1229
    strb w0, [x29, x8]
    mov w0, #103
    mov x8, #-1228
    strb w0, [x29, x8]
    mov w0, #101
    mov x8, #-1227
    strb w0, [x29, x8]
    mov w0, #60
    mov x8, #-1226
    strb w0, [x29, x8]
    mov w0, #47
    mov x8, #-1225
    strb w0, [x29, x8]
    mov w0, #116
    mov x8, #-1224
    strb w0, [x29, x8]
    mov w0, #105
    mov x8, #-1223
    strb w0, [x29, x8]
    mov w0, #116
    mov x8, #-1222
    strb w0, [x29, x8]
    mov w0, #108
    mov x8, #-1221
    strb w0, [x29, x8]
    mov w0, #101
    mov x8, #-1220
    strb w0, [x29, x8]
    mov w0, #62
    mov x8, #-1219
    strb w0, [x29, x8]
    mov w0, #60
    mov x8, #-1218
    strb w0, [x29, x8]
    mov w0, #98
    mov x8, #-1217
    strb w0, [x29, x8]
    mov w0, #111
    mov x8, #-1216
    strb w0, [x29, x8]
    mov w0, #100
    mov x8, #-1215
    strb w0, [x29, x8]
    mov w0, #121
    mov x8, #-1214
    strb w0, [x29, x8]
    mov w0, #62
    mov x8, #-1213
    strb w0, [x29, x8]
    mov w0, #60
    mov x8, #-1212
    strb w0, [x29, x8]
    mov w0, #98
    mov x8, #-1211
    strb w0, [x29, x8]
    mov w0, #62
    mov x8, #-1210
    strb w0, [x29, x8]
    mov w0, #119
    mov x8, #-1209
    strb w0, [x29, x8]
    mov w0, #101
    mov x8, #-1208
    strb w0, [x29, x8]
    mov w0, #32
    mov x8, #-1207
    strb w0, [x29, x8]
    mov w0, #98
    mov x8, #-1206
    strb w0, [x29, x8]
    mov w0, #97
    mov x8, #-1205
    strb w0, [x29, x8]
    mov w0, #108
    mov x8, #-1204
    strb w0, [x29, x8]
    mov w0, #108
    mov x8, #-1203
    strb w0, [x29, x8]
    mov w0, #60
    mov x8, #-1202
    strb w0, [x29, x8]
    mov w0, #47
    mov x8, #-1201
    strb w0, [x29, x8]
    mov w0, #98
    mov x8, #-1200
    strb w0, [x29, x8]
    mov w0, #62
    mov x8, #-1199
    strb w0, [x29, x8]
    mov w0, #60
    mov x8, #-1198
    strb w0, [x29, x8]
    mov w0, #47
    mov x8, #-1197
    strb w0, [x29, x8]
    mov w0, #98
    mov x8, #-1196
    strb w0, [x29, x8]
    mov w0, #111
    mov x8, #-1195
    strb w0, [x29, x8]
    mov w0, #100
    mov x8, #-1194
    strb w0, [x29, x8]
    mov w0, #121
    mov x8, #-1193
    strb w0, [x29, x8]
    mov w0, #62
    mov x8, #-1192
    strb w0, [x29, x8]

    ; Socket write
    mov x8, #-1184
    ldr x0, [x29, x8]
    mov x9, x0          // save socket fd to x9
    add x0, x29, #-1297
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
    mov x8, #-1184
    ldr x0, [x29, x8]
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
