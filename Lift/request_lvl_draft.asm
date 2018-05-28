;Part B – Array Addition (2 Marks)
;Load the two arrays (1, 2, 3, 4, 5) and (5, 4, 3, 2, 1) into 10 registers, and then add them together,
;storing the result as an third array in data memory. Each integer should take up one byte.
;Data memory should be allocated using the assembler directives instead of hard-coding the address.
;You do not need to use loops or load data from program memory for this task.

.include "m2560def.inc"

.def temp_counter = r15
.def temp1 = r16
.def temp2 = r17

.macro do_request_lvl
    ldi temp1, @0 ;temp2 is the target_lvl
	ldi temp2, 1 ;temp2 is the requested_flag
    call flag_lvl
.endmacro

.macro do_unrequest_lvl
    ldi temp1, @0 ;temp1 is the target_lvl
	ldi temp2, 0 ;temp2 is the requested_flag
    call flag_lvl
.endmacro

.cseg
    ;ldi ZL, low(string<<1)  ; Load immediate into register Z, the low byte of ; the address of "h
    ;ldi ZH, high(string<<1) ; Load immediate into register Z, the high byte of ; the address of "h" 
    ;what does <<2 do? it left shifts 2, but the result doesn't change?

    ;ldi YH, high(Cap_string) 
    ;ldi YL, low(Cap_string)    ;makes Y max byte 20? not sure...

start:
    do_request_lvl 0

    do_request_lvl 1

    do_request_lvl 3
	do_unrequest_lvl 3
    
    do_request_lvl 5

    rjmp halt

flag_lvl:
    push YL
    push YH
	push temp_counter
	push temp2
    ldi YL, 0 ; reset Y
    ldi YH, 0
    clr temp_counter
flag_lvl_iterate:
    cp temp_counter, temp1 ;temp1 is the target_lvl
    breq flag_lvl_return
    ld temp2, Y+ ;temp2 stores the current requested status of the level
    inc temp_counter
    rjmp flag_lvl_iterate
flag_lvl_return: 
	pop temp2 ;pop off the requested_flag value
    st Y, temp2 ; flag the register as "requested"
	pop temp_counter
    pop YH
    pop YL
    ret

halt:
    rjmp halt