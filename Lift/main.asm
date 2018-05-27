
; The program gets input from keypad and displays its ascii value on the
; LED bar
.include "m2560def.inc"

.def temp_counter = r15

.def temp1=r16
.def temp2=r17
.def temp3=r18
.def temp4=r19
.def temp5=r20

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

.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4
; 4 cycles per iteration - setup/call-return overhead

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
	rcall lcd_number
	rcall lcd_wait
.endmacro
.macro do_divide
	mov temp1, @0
	mov temp2, @1
	rcall divide
	mov @0, temp1 ;store result in first register argument
	mov @1, temp2 ;store remainder in second register argument
.endmacro
.macro do_to_ascii_number
	mov temp1, @0
	clr temp2
	rcall to_ascii_number
	mov @0, temp1
.endmacro
.macro lcd_set
	sbi PORTA, @0
.endmacro
.macro lcd_clr
	cbi PORTA, @0
.endmacro


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

	do_lcd_command 0b00000001 ; clear display
	ldi r21, 23
	ldi r22, 4


	do_divide r21, r22
	do_lcd_number r21
	do_lcd_data '|'
	do_lcd_number r22
	do_lcd_data '|'
	do_lcd_number r21
	do_lcd_data '|'
	do_lcd_number r22
	do_lcd_data '|'

	out PORTC, r22

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
	ldi temp2, 48
	add temp1, temp2
	ret