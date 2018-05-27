;Part B – Array Addition (2 Marks)
;Load the two arrays (1, 2, 3, 4, 5) and (5, 4, 3, 2, 1) into 10 registers, and then add them together,
;storing the result as an third array in data memory. Each integer should take up one byte.
;Data memory should be allocated using the assembler directives instead of hard-coding the address.
;You do not need to use loops or load data from program memory for this task.

.include "m2560def.inc"

.def counter = r16
.def target = r17
.def current = r18
.def true_flag = r19

.macro do_request_lvl
    ldi target, @0
    call request_lvl
.endmacro

.cseg
    ;ldi ZL, low(string<<1)  ; Load immediate into register Z, the low byte of ; the address of "h
    ;ldi ZH, high(string<<1) ; Load immediate into register Z, the high byte of ; the address of "h" 
    ;what does <<2 do? it left shifts 2, but the result doesn't change?

    ;ldi YH, high(Cap_string) 
    ;ldi YL, low(Cap_string)    ;makes Y max byte 20? not sure...

start:
    ldi true_flag, 1
    ldi counter, 0 ;counter
    ldi target, 1
    ldi current, 0

    do_request_lvl 0

    do_request_lvl 1

    do_request_lvl 3
    
    do_request_lvl 5

    rjmp halt

request_lvl:
    push YL
    push YH
    ldi YL, 0 ; reset Y
    ldi YH, 0
    ldi counter, 0
request_lvl_iterate:
    cp counter, target
    breq request_lvl_return
    ld current, Y+
    inc counter
    rjmp request_lvl_iterate
request_lvl_return:
    st Y, true_flag
    pop YH
    pop YL
    ret

halt:
    rjmp halt