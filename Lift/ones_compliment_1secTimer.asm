; This program implements a timer that counts one second using
; Timer0 interrupt
.include "m2560def.inc"
.equ PATTERN = 0b10101010
.def temp = r16
.def leds = r17
; The macro clears a word (2 bytes) in a memory
; the parameter @0 is the memory address for that word
.macro clear
	ldi YL, low(@0) ; load the memory address to Y
	ldi YH, high(@0)
	clr temp
	st Y+, temp ; clear the two bytes at @0 in SRAM
	st Y, temp
.endmacro

.dseg
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
	ldi temp, high(RAMEND) ; Initialize stack pointer
	out SPH, temp
	ldi temp, low(RAMEND)
	out SPL, temp
	ser temp ; set Port C as output
	out DDRC, temp
	rjmp main

Timer0OVF: ; interrupt subroutine to Timer0
	in temp, SREG
	push temp ; Prologue starts.
	push YH ; Save all conflict registers in the prologue.
	push YL
	push r25
	push r24 ; Prologue ends.
	; Load the value of the temporary counter.
	lds r24, TempCounter
	lds r25, TempCounter+1
	adiw r25:r24, 1 ; Increase the temporary counter by one.
	cpi r24, low(7812) ; Check if (r25:r24) = 7812
	ldi temp, high(7812) ; 7812 = 106/128
	cpc r25, temp
	brne NotSecond ;if the interval does not coincide with a second interval, then inrement and return
	com leds
	out PORTC, leds
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
	pop temp
	out SREG, temp
	reti ; Return from the interrupt.

main:
	ldi leds, 0xFF
	out PORTC, leds
	ldi leds, PATTERN
	clear TempCounter ; Initialize the temporary counter to 0
	clear SecondCounter ; Initialize the second counter to 0
	ldi temp, 0b00000000
	out TCCR0A, temp
	ldi temp, 0b00000010
	out TCCR0B, temp ; Prescaling value=8
	ldi temp, 1<<TOIE0 ; = 128 microseconds
	sts TIMSK0, temp ; T/C0 interrupt enable
	sei ; Enable global interrupt

loop: 
	rjmp loop ; loop forever