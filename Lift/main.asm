.include "m2560def.inc"

.def temp1=r16
.def temp2=r17
.def temp3=r18
.def temp4=r19
.def temp5=r20

.def lift_buttons = r21

.macro do_lcd_command
	ldi temp1, @0
	rcall lcd_command
	rcall lcd_wait
.endmacro
.macro do_lcd_data
	ldi temp1, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro
.macro do_lcd_data_r
	mov temp1, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro
.macro do_lcd_number
	mov temp1, @0
	clr temp4
	rcall lcd_number
	rcall lcd_wait
.endmacro
.macro do_divide
	mov temp1, @0
	mov temp2, @1
	clr temp3
	rcall divide
	mov @0, temp3 ;store result in first register argument
	mov @1, temp1 ;store remainder in second register argument
.endmacro
.macro do_to_ascii_number
	mov temp1, @0
	clr temp2
	rcall to_ascii_number
	mov @0, temp1
.endmacro

.org 0
	jmp RESET
.org INT2addr
	jmp EXT_INT2

RESET:
	ldi temp1, low(RAMEND)
	out SPL, temp1
	ldi temp1, high(RAMEND)
	out SPH, temp1

	ser temp1
	out DDRF, temp1
	out DDRA, temp1
	out DDRC, temp1 ;LED panel


	;INITIALIZE PORT VALUES
	ldi temp1, 0b10101010 ; initial set of LED panel
	out PORTC, temp1

	clr temp1
	out PORTF, temp1
	out PORTA, temp1
	
	;ENABLE INT2 INTERRUPTS
	;set 0b00000100 into EIMSK to enable int2 interrupts
	in temp1, EIMSK
	ori temp1, 0b00000100
	out EIMSK, temp1

	lds temp1, EICRA
	ori temp1, 0b00110000
	sts EICRA, temp1
	;set 0b00110000 into EICRA to set int2 interrupts to trigger on rising edge
	
	sei

	do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_5ms
	do_lcd_command 0b00001000 ; display off?
	do_lcd_command 0b00000001 ; clear display
	do_lcd_command 0b00000110 ; increment, no display shift
	do_lcd_command 0b00001110 ; Cursor on, bar, no blink

	ldi r22, 130
	
	do_lcd_number r22

	rjmp halt

halt:
	rjmp halt

EXT_INT2:
	out PORTC, r22

	do_lcd_command 0b00000001
	do_lcd_number r22
	ret ;if this is set to reti, the interrupt is continiously detected

.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4

.macro lcd_set
	sbi PORTA, @0
.endmacro
.macro lcd_clr
	cbi PORTA, @0
.endmacro

;
; Send a command to the LCD (temp1)
;

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

.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4
; 4 cycles per iteration - setup/call-return overhead

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

sleep_5ms:
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	ret

divide:
	clr temp3
divide_iterate:
	cp temp1, temp2
	brlo divide_return
	sub temp1, temp2 ;number,divisor, temp1 will contain the remainder.
	inc temp3 ;keep track of division count, this is the result.
	rjmp divide_iterate
divide_return:
	ret

lcd_number:
	clr temp4
	ldi r23, 10
lcd_number_iterate:
	inc temp4
	ldi r23, 10
	do_divide r22, r23
	push r23 ;push the remainer 
	cpi r22, 0
	brne lcd_number_iterate
lcd_number_print_digit:
	cpi temp4, 0
	breq lcd_number_return
	dec temp4
	pop r23
	do_to_ascii_number r23
	do_lcd_data_r r23
	rjmp lcd_number_print_digit
lcd_number_return:
	ret

to_ascii_number:
	ldi temp2, 48
	add temp1, temp2
	ret