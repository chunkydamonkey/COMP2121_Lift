;Part B – Array Addition (2 Marks)
;Load the two arrays (1, 2, 3, 4, 5) and (5, 4, 3, 2, 1) into 10 registers, and then add them together,
;storing the result as an third array in data memory. Each integer should take up one byte.
;Data memory should be allocated using the assembler directives instead of hard-coding the address.
;You do not need to use loops or load data from program memory for this task.

.include "m2560def.inc"

.def temp_counter = r15
.def temp1=r16
.def temp2=r17
.def current_lvl = r18
.def target_lvl = r19
.def direction = r20

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

.equ MAX_LVLS = 10
.equ MIN_LVLS = 0

.cseg
    ;ldi ZL, low(string<<1)  ; Load immediate into register Z, the low byte of ; the address of "h
    ;ldi ZH, high(string<<1) ; Load immediate into register Z, the high byte of ; the address of "h" 
    ;what does <<2 do? it left shifts 2, but the result doesn't change?

    ;ldi YH, high(Cap_string) 
    ;ldi YL, low(Cap_string)    ;makes Y max byte 20? not sure...

start:
    do_request_lvl 0

    do_request_lvl 2

    do_request_lvl 3
	do_unrequest_lvl 3
    ldi direction, 1
	ldi current_lvl, 4

	rcall update_target_lvl

    rjmp halt

halt:
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

update_target_lvl:
	push YL
    push YH
	push temp_counter
	push temp1

update_target_lvl_reset:
	mov temp_counter, current_lvl
	mov r28, current_lvl ; make Y point to the first address of the requested_lift registers, 
    clr r29	; WARNING IF WE CHOOSE ANOTHER STARTING ADDRESS FOR requested_lvls, we can't do this
	
	ldi temp1, 1
	cpse direction, temp1
	inc r28 ;if scanning down, increment Y first, since -Y decrements before loading value
	
	cpi direction, 0
	breq update_target_lvl_scandown

update_target_lvl_scanup: 
	ld temp1, Y+ ;get the requested_flag
	cpi temp1, 1 ;if 1, update target_lvl
	breq update_target_lvl_return
	inc temp_counter
	ldi temp1, MAX_LVLS
	cp temp_counter, temp1
	brge update_target_lvl_scanother
	rjmp update_target_lvl_scanup

update_target_lvl_scandown:
	ld temp1, -Y ;get the requested_flag
	cpi temp1, 1 ;if 1, update target_lvl
	breq update_target_lvl_return
	dec temp_counter
	ldi temp1, MIN_LVLS
	cp temp_counter, temp1
	brlt update_target_lvl_scanother
	rjmp update_target_lvl_scandown

update_target_lvl_scanother:
	clr temp_counter
	cpse direction, temp_counter
	ldi temp1, 0
	inc temp_counter
	cpse direction, temp_counter
	ldi temp1, 1
	mov direction, temp1
	rjmp update_target_lvl_reset

update_target_lvl_return:
	mov target_lvl, temp_counter
	pop temp1
	pop temp_counter
	pop YH
	pop YL
	ret

