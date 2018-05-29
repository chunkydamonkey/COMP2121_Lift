
; The program gets input from keypad and displays its ascii value on the
; LED bar
.include "m2560def.inc"

.def temp_counter = r15

.def temp1=r16
.def temp2=r17
.def current_lvl = r18
.def target_lvl = r19
.def direction = r20

.def row = r21 ; current row number
.def col = r22 ; current column number
.def rmask = r23 ; mask for current row during scan
.def cmask = r24 ; mask for current column during scan

.equ PORTLDIR = 0xF0 ; PD7-4: output, PD3-0, input
.equ INITCOLMASK = 0xEF ; scan from the rightmost column,
.equ INITROWMASK = 0x01 ; scan from the top row
.equ ROWMASK = 0x0F ; for obtaining input from Port D

.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4

.equ MAX_LVLS = 10
.equ MIN_LVLS = 0

.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4
; 4 cycles per iteration - setup/call-return overhead

.macro do_lcd_command
	push temp1
	ldi temp1, @0
	rcall lcd_command
	rcall lcd_wait
	pop temp1
.endmacro
.macro do_lcd_data
	push temp1
	ldi temp1, @0
	rcall lcd_data
	rcall lcd_wait
	pop temp1
.endmacro
.macro do_lcd_data_r
	push temp1
	mov temp1, @0
	rcall lcd_data
	rcall lcd_wait
	pop temp1
.endmacro
.macro do_lcd_number
	push temp1
	mov temp1, @0
	rcall lcd_number
	rcall lcd_wait
	pop temp1
.endmacro
.macro do_divide
	push temp1
	push temp2
	mov temp1, @0
	mov temp2, @1
	rcall divide
	mov @0, temp1 ;store result in first register argument
	mov @1, temp2 ;store remainder in second register argument
	pop temp2
	pop temp1
.endmacro
.macro do_to_ascii_number
	push temp1
	mov temp1, @0
	rcall to_ascii_number
	mov @0, temp1
	pop temp1
.endmacro
.macro lcd_set
	sbi PORTA, @0
.endmacro
.macro lcd_clr
	cbi PORTA, @0
.endmacro
.macro do_request_lvl
	push temp1
	push temp2
    ldi temp1, @0 ;temp2 is the target_lvl
	ldi temp2, 1 ;temp2 is the requested_flag
    call flag_lvl
	pop temp2
	pop temp1
.endmacro
.macro do_request_lvl_r
	push temp1
	push temp2
    mov temp1, @0 ;temp2 is the target_lvl
	ldi temp2, 1 ;temp2 is the requested_flag
    call flag_lvl
	pop temp2
	pop temp1
.endmacro
.macro do_unrequest_lvl
	push temp1
	push temp2
    ldi temp1, @0 ;temp1 is the target_lvl
	ldi temp2, 0 ;temp2 is the requested_flag
    call flag_lvl
	pop temp2
	pop temp1
.endmacro
.macro do_display_lift_lcd
    call display_lift_lcd
.endmacro
.macro do_update_target_lvl
	call update_target_lvl
.endmacro
.macro clear
	push YL
	push YH
	push temp1
	ldi YL, low(@0) ; load the memory address to Y
	ldi YH, high(@0)
	clr temp1
	st Y+, temp1 ; clear the two bytes at @0 in SRAM
	st Y, temp1
	pop temp1
	pop YH
	pop YL
.endmacro

.dseg
.org 0x0200
SecondCounter:
	.byte 2 ; Two-byte counter for counting seconds.
TempCounter:
	.byte 2 ; Temporary counter. Used to determine

; if one second has passed
.cseg
.org 0x0000

jmp RESET
jmp DEFAULT ; No handling for IRQ0.
jmp DEFAULT ; No handling for IRQ1.

.org OVF0addr
jmp Timer0OVF ; Jump to the interrupt handler for
; Timer0 overflow.
jmp DEFAULT ; default service for all other interrupts.

DEFAULT: 
	reti ; no service

RESET:
	ldi temp1, low(RAMEND) ; initialize the stack
	out SPL, temp1
	ldi temp1, high(RAMEND)
	out SPH, temp1
	ldi temp1, PORTLDIR ; PA7:4/PA3:0, out/in
	sts DDRL, temp1 ;DDRA out

	;set pins as output
	ser temp1 
	out DDRA, temp1
	out DDRC, temp1
	out DDRF, temp1

	out PORTC, temp1

	rcall reset_lift

	;Lift testing
	do_request_lvl 0

    do_request_lvl 1

    do_request_lvl 3
	do_unrequest_lvl 3
	;put break point on next line, use emulator to test should show 1100010000

	ldi current_lvl, 8
	ldi target_lvl, 8
	;rcall update_target_lvl

	do_display_lift_lcd

	;LCD testing

	;do_lcd_command 0b00000001 ; clear display
	ldi r21, 23
	ldi r22, 4

	/*
	do_divide r21, r22
	do_lcd_number r21
	do_lcd_data '|'
	do_lcd_number r22
	do_lcd_data '|'
	do_lcd_number r21
	do_lcd_data '|'
	do_lcd_number r22
	do_lcd_data '|'
	*/

	/* THERE's a BUG HERE
	clear TempCounter ; Initialize the temporary counter to 0
	clear SecondCounter ; Initialize the second counter to 0
	ldi temp1, 0b00000000
	out TCCR0A, temp1
	ldi temp1, 0b00000010
	out TCCR0B, temp1 ; Prescaling value=8
	ldi temp1, 1<<TOIE0 ; = 128 microseconds
	sts TIMSK0, temp1 ; T/C0 interrupt enable
	sei ; Enable global interrupt

	TODO: use a button to iterate the lift move <--------------------------------------------------------------------------
	*/

	out PORTC, r22
	rjmp main

Timer0OVF: ; interrupt subroutine to Timer0
	push temp1
	in temp1, SREG
	push temp1 ; Prologue starts.
	push temp2
	push YH ; Save all conflict registers in the prologue.
	push YL
	push r25
	push r24 ; Prologue ends.
	; Load the value of the temporary counter.
	lds r24, TempCounter
	lds r25, TempCounter+1
	adiw r25:r24, 1 ; Increase the temporary counter by one.
	cpi r24, low(7812) ; Check if (r25:r24) = 7812
	ldi temp1, high(7812) ; 7812 = 106/128
	cpc r25, temp1
	brne NotSecond ;if the interval does not coincide with a second interval, then increment and return
	;com leds ;one's compliment

	;move lift
	;rcall move_lift

	out PORTC, target_lvl
	clear TempCounter ; Reset the temporary counter.
	; Load the value of the second counter.
	lds r24, SecondCounter
	lds r25, SecondCounter+1
	adiw r25:r24, 1 ; Increase the second counter by one.
	sts SecondCounter, r24
	sts SecondCounter+1, r25
	rjmp EndIF

NotSecond:
	; Store the new value of the temporary counter.
	sts TempCounter, r24
	sts TempCounter+1, r25

EndIF:
	pop r24 ; Epilogue starts;
	pop r25 ; Restore all conflict registers from the stack.
	pop YL
	pop YH
	pop temp2
	pop temp1
	out SREG, temp1
	pop temp1
	reti ; Return from the interrupt.

main:
	ldi cmask, INITCOLMASK ; initial column mask
	clr col ; initial column

colloop:
	cpi col, 4
	breq main ; If all keys are scanned, repeat.
	sts PORTL, cmask ; Otherwise, scan a column. out
	ldi temp1, 0xFF ; Slow down the scan operation.

delay: 
	dec temp1
	brne delay
	lds temp1, PINL ; Read PORTL in
	andi temp1, ROWMASK ; Get the keypad output value
	cpi temp1, 0xF ; Check if any row is low
	breq nextcol
	; If yes, find which row is low
	ldi rmask, INITROWMASK ; Initialize for row check
	clr row ;
	
rowloop:
	cpi row, 4
	breq nextcol ; the row scan is over.
	mov temp2, temp1
	and temp2, rmask ; check unmasked bit
	breq convert
	inc row
	lsl rmask
	ori rmask, 0xF0
	jmp rowloop

nextcol: ; if row scan is over
	lsl cmask
	ori cmask, 0x0F
	inc col	; incresae column value
	jmp colloop ; go to the next column
	
convert:
	cpi col, 3 ; If the pressed key in in col.3
	breq letters ; we have a letter
	; If the key is not in col.3
	cpi row, 3 ; If the key is in row3,
	breq symbols
	mov temp1, row 
	; Otherwise we have a number in 1-9
	lsl temp1
	add temp1, row
	add temp1, col ; temp1 = row*3 + col
	inc temp1
	;subi temp1, -'1' ; Add the value of character ‘1’
	jmp convert_end

letters:
	ldi temp1, 'A'
	add temp1, row ; Get the ASCII value for the key
	jmp convert_end

symbols:
	cpi col, 0 ; Check if we have a star
	breq star
	cpi col, 1 ; or if we have zero
	breq zero
	ldi temp1, '#' ; if not we have hash
	jmp convert_end

star:
	ldi temp1, '*' ; Set to star
	jmp convert_end

zero:
	clr temp1 ; Set to zero

convert_end:
	out PORTC, temp1 ; Write value to PORTC
	do_request_lvl_r temp1
	do_update_target_lvl
	do_display_lift_lcd
	jmp main ; Restart main loop

lcd_command:
	out PORTF, temp1
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	ret

lcd_data:
	out PORTF, temp1
	lcd_set LCD_RS
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	lcd_clr LCD_RS
	ret

lcd_wait:
	push temp1
	clr temp1
	out DDRF, temp1
	out PORTF, temp1
	lcd_set LCD_RW

lcd_wait_loop:
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	in temp1, PINF
	lcd_clr LCD_E
	sbrc temp1, 7
	rjmp lcd_wait_loop
	lcd_clr LCD_RW
	ser temp1
	out DDRF, temp1
	pop temp1
	ret

sleep_1ms:
	push r24
	push r25
	ldi r25, high(DELAY_1MS)
	ldi r24, low(DELAY_1MS)
delayloop_1ms:
	sbiw r25:r24, 1
	brne delayloop_1ms
	pop r25
	pop r24
	ret

divide:
	push temp_counter
	clr temp_counter
divide_iterate:
	cp temp1, temp2
	brlo divide_return
	sub temp1, temp2 ;number,divisor, temp1 will contain the remainder.
	inc temp_counter ;keep track of division count, this is the result.
	rjmp divide_iterate
divide_return:
	mov temp2, temp1 ;store the remainder into temp2
	mov temp1, temp_counter ; store the result into temp1
	pop temp_counter
	ret

lcd_number:
	push temp_counter
	push temp2
	push temp1
	clr temp_counter
lcd_number_iterate:
	inc temp_counter
	ldi temp2, 10
	do_divide temp1, temp2
	push temp2 ;push the remainer 
	cpi temp1, 0
	brne lcd_number_iterate
lcd_number_print_digit:
	tst temp_counter
	breq lcd_number_return
	dec temp_counter
	pop temp2 ;pop remainder results and print
	do_to_ascii_number temp2
	do_lcd_data_r temp2
	rjmp lcd_number_print_digit
lcd_number_return:
	pop temp1
	pop temp2
	pop temp_counter
	ret

to_ascii_number:
	push temp2
	ldi temp2, 48
	add temp1, temp2
	pop temp2
	ret

flag_lvl:
    push YL
    push YH
	push temp_counter
	push temp2
    ldi YL, 0 ; make Y point to the first address of the requested_lift registers
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

display_lift_lcd:
	do_lcd_command 0b00000001
	push YL
    push YH
	push temp_counter
	push temp1
	push temp2
	ldi temp1, MAX_LVLS ;10 is the number of lvls
	clr temp_counter
	ldi YL, 0 ; make Y point to the first address of the requested_lift registers
    ldi YH, 0
display_lift_lcd_iterate:
	;loop through and print lcd display
    cp temp_counter, temp1 ;temp1 is MAX_LVLS = 10
    brge display_current_lvl
    ld temp2, Y+ ;temp2 stores the current requested status of the level
    
	;if target_lvl = tempcounter
	cp target_lvl, temp_counter
	breq display_lift_lcd_flag_target

	;mov temp2, temp_counter
display_lift_lcd_one_char:
	inc temp_counter
	do_to_ascii_number temp2
	do_lcd_data_r temp2
    rjmp display_lift_lcd_iterate

display_current_lvl:
	do_lcd_data 'E'
	do_lcd_command 0b11000000; shift to bottom lcd, can't find this in documentation?
	clr temp_counter
	
display_current_lvl_iterate:
	cp temp_counter, current_lvl
	brge display_lift_lcd_return
	do_lcd_data ' '
	inc temp_counter
	rjmp display_current_lvl_iterate

display_lift_lcd_return:
	do_lcd_data 'C'
	pop temp2
	pop temp1
	pop temp_counter
	pop YH
    pop YL
	ret

display_lift_lcd_flag_target:
	ldi temp2, 2
	rjmp display_lift_lcd_one_char

reset_lift:
	push YL
    push YH
	push temp_counter
	push temp1
	push temp2
	ldi temp1, MAX_LVLS ;10 is the number of lvls
	clr temp2
	clr temp_counter
	ldi YL, 0 ; make Y point to the first address of the requested_lift registers
    ldi YH, 0

reset_lift_iterate:
	cp temp_counter, temp1 ;temp1 is MAX_LVLS = 10
	brge reset_lift_return
	st Y+, temp2 ;set the register to 0
	rjmp reset_lift_iterate

reset_lift_return:
	pop temp2
	pop temp1
	pop temp_counter
	pop YH
    pop YL
	ret

;TODO: no_requests situation
;TODO: unrequest current_lvl if target_lvl = current_lvl
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

move_lift:
	push temp1
move_lift_iterate:
	clr temp1
	cpse direction, temp1
	inc current_lvl
	dec temp1
	cpse direction, temp1
	dec current_lvl
	do_display_lift_lcd
move_lift_return:
	pop temp1
	ret
