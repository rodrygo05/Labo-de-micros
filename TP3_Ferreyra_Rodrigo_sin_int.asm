
.equ	F_CPU = 16000000			;Freq of the CM
.equ	baud	= 9600			; baudrate
.equ	bps	= ((F_CPU/16/baud) - 1)	; baud prescale

.equ    MAX_REC_SIZE = 100

;We will use the carriage return as end of string
.equ	EOS = 0x0D

.equ	UNO = 0X31	
.equ	DOS =0X32
.equ	TRES =0X33
.equ	CUATRO =0X34

.dseg
.org SRAM_START
tabla_ram:	.byte	MAX_REC_SIZE


.cseg
;Inicio del codigo
.org	0x0000
	rjmp inicio;

;Direccion siguiente a la ultima interrupcion. Es dependiente del micro utilizado por eso se utiliza esta macro
.org INT_VECTORS_SIZE


inicio:

; Se inicializa el Stack Pointer al final de la RAM utilizando la definicion global
; RAMEND
	ldi		r16, HIGH(RAMEND)
	out		sph, r16
	ldi		r16, LOW(RAMEND)
	out		spl, r16.

	rcall	Config_Serial
	rcall	configure_ports
	ldi		zl, LOW(tabla_rom<<1)
	ldi		zh, HIGH(tabla_rom<<1)
	rcall	puts

main:
	rcall getc
comparar_con_uno:
	cpi		r16,UNO
	brne	comparar_con_dos
	ldi		r20,1
	out		pinc,r20
	rjmp	main

comparar_con_dos:
	cpi		r16,DOS
	brne	comparar_con_tres
	ldi		r20,2
	out		pinc,r20
	rjmp	main

comparar_con_tres:
	cpi		r16,TRES
	brne	comparar_con_cuatro
	ldi		r20,4
	out		pinc,r20
	rjmp	main

comparar_con_cuatro:
	cpi		r16,CUATRO
	brne	main
	ldi		r20,8
	out		pinc,r20
	rjmp	main
;**************************************************************
;* subroutine: initUART
;*
;* inputs: r17:r16 - baud rate prescale
;*
;* enables UART transmission with 8 data, 1 parity, no stop bit
;* at input baudrate
;*
;* registers modified: r16
;**************************************************************
Config_Serial:
	ldi		r16, LOW(bps)			; load baud prescale
	ldi		r17, HIGH(bps)			; into r17:r16
	rcall	initUART	
	ret

initUART:
	sts		UBRR0L, r16			; load baud prescale
	sts		UBRR0H, r17			; to UBRR0

	; Frame-Format: 8 Bit
	ldi		r16, (0<<UMSEL00) | (0<<UPM00) | (0<<USBS0) | (3<<UCSZ00) ;8bits, no parity, 1stop bit, async usart
	sts		UCSR0C, r16

	ldi		r16, (1<<RXEN0) | (1<<TXEN0) | (0<<UCSZ02)	; habilito transmision y recepcion, 8bits
	sts		UCSR0B, r16

	ret

configure_ports:
	ldi     r16,0xFF      
    out     DDRC,r16	;habilito todas como salida
ret


;**************************************************************
;* subroutine: puts
;*
;* inputs: ZH:ZL - Program Memory address of string to transmit
;*
;* transmits null terminated string via UART
;*
;* registers modified: r16,r17,r30,r31
;**************************************************************
puts:	
	lpm		r16, Z+				; load character from pmem
	cpi		r16, 0x00			; check if null
	breq	puts_end			; branch if null

puts_wait:
	lds		r17, UCSR0A			; load UCSR0A into r17 **** UCSR0A - USART Control and Status Register A
	sbrs	r17, UDRE0			; esperando buffer de transmision de datos vacio? **** UDRE0 = 5	; USART Data Register Empty
	rjmp	puts_wait			; repeat loop

	sts		UDR0, r16			; transmit character
	rjmp	puts				; repeat loop

puts_end:
	ret
;**************************************************************
;* subroutine: getc
;*
;* inputs: none
;*
;* outputs:	r16 - character received
;*
;* receives single ASCII character via UART.
;* 
;* THIS ROUTINE BLOCKS THE CPU UNTIL A CHARACTER
;* IS RECEIVED
;*
;
;* registers modified: r16, r17
;**************************************************************
getc:	
	lds		r17, UCSR0A			; load UCSR0A into r17
	sbrs	r17, RXC0			; wait for empty transmit buffer
	rjmp	getc				; repeat loop
	lds		r16, UDR0			; get received character
	ret	


tabla_rom: .db "***Hola Labo de micro***" ,0x0D,  "Escriba 1, 2, 3 o 4 para controlar los LEDs",0x0D,0x00


