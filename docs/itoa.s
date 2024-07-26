.global _main
.align 2

_itoa:
    mov x2, x0      ; Copy the input number to x2 for division
    mov x3, #0      ; Initialize the remainder register to 0
    mov x4, #10     ; Set the divisor to 10 (for base 10 conversion)
    mov x5, #0      ; Initialize quotient to 0
    mov x6, #0      ; Initialize digit counter for buffer offset to 0
    mov x7, #0      ; Initialize temporary register for string reversal

.itoa_loop:
    ; Example using the number 69

    ; First iteration: x2 = 69, x4 = 10
    ; Second iteration: x2 = 6, x4 = 10
    udiv x5, x2, x4

    ; First iteration: x5 = 6, x3 = 9
    ; Second iteration: x5 = 0, x3 = 6
    msub x3, x5, x4, x2

    ; First iteration: x2 becomes 6
    ; Second iteration: x2 becomes 0
    mov x2, x5

    ; First iteration: x3 becomes 57 (ASCII '9')
    ; Second iteration: x3 becomes 54 (ASCII '6')
    add x3, x3, #48

    ; Calculate buffer position for storing the digit
    sub x7, x1, x6
    sub x7, x7, #1
    ; First iteration: Store '9' at the end of the buffer
    ; Second iteration: Store '6' one position before '9'
    strb w3, [x7]

    ; First iteration: x6 becomes 1
    ; Second iteration: x6 becomes 2
    add x6, x6, #1

    ; First iteration: x2 (6) != 0, so loop continues
    ; Second iteration: x2 (0) == 0, so loop ends
    cmp x2, #0
    bne .itoa_loop

    ; After loop: x6 = 2 (number of digits), x1 points to start of "69" in buffer
    mov x2, x6
    sub x1, x1, x6
    ret

_printInt:
    ; Save the link register (x30) and frame pointer (x29) to the stack
    ; This allows us to return to the caller and restore the stack frame
    stp x30, x29, [sp, #-16]!
    mov x29, sp
    
    ; Allocate 21 bytes on the stack for the string buffer
    ; This is enough space for a 64-bit integer (20 digits) plus a newline
    sub sp, sp, #21
    mov x1, sp        ; x1 now points to the start of our buffer

    ; Call _itoa to convert the integer to a string
    ; x0 already contains the integer to convert (passed from the caller)
    ; x1 contains the buffer address
    bl _itoa

    ; Add a newline character ('\n') at the end of the string
    mov w0, #10       ; ASCII code for newline
    strb w0, [x1, x2] ; Store newline at buffer[length]
    add x2, x2, #1    ; Increment length to include newline

    ; Print the string using a system call
    mov x0, #1        ; File descriptor 1 is stdout
    ; x1 already contains the buffer address
    ; x2 already contains the buffer length (including newline)
    mov x16, #4       ; System call number 4 is write
    svc 0             ; Make the system call

    ; Deallocate the 21 bytes we reserved on the stack
    add sp, sp, #21

    ; Restore the link register and frame pointer
    ldp x30, x29, [sp], #16
    ret               ; Return to caller

_main:
    mov x0, #698      ; Load the number 698 into x0 as an argument
    bl _printInt      ; Call _printInt to print the number
    ; _printInt will handle the conversion and printing
    ; When it returns, the number will have been printed