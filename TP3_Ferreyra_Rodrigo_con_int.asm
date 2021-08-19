
.equ	F_CPU = 16000000			;Freq of the CM
.equ	baud	= 9600			; baudrate
.equ	bps	= ((F_CPU/16/baud) - 1)	; baud prescale

.equ	UNO = 0X31	
.equ	DOS =0X32
.equ	TRES =0X33
.equ	CUATRO =0X34

.dseg
.org SRAM_START

;Inicio del codigo
.cseg
.org 0x0000
	rjmp	inicio
.org URXCaddr
	rjmp	Int_rx
.org UTXCaddr
	rjmp	Int_tx

;Direccion siguiente a la ultima interrupcion. Es dependiente del micro utilizado por eso se utiliza esta macro
.org INT_VECTORS_SIZE


inicio:
	ldi		r16, HIGH(RAMEND)
	out		sph, r16
	ldi		r16, LOW(RAMEND)
	out		spl, r16
	sei
	rcall	Config_Serial
	rcall	configure_ports

	ldi		zl, LOW(tabla_rom<<1)
	ldi		zh, HIGH(tabla_rom<<1)
	
	lpm		r16, Z+				; load character from pmem
	cpi		r16, 0x00			; check if null
	breq	main				; branch if null
	sts		UDR0, r16			; transmit character

	ldi		r17,0xff

main:
	cpi		r17,0xff
	breq	main

procesar_mensaje:
	mov		r22,r17
	ldi		r17,0xff

comparar_con_uno:
	cpi		r22,UNO
	brne	comparar_con_dos
	ldi		r20,1
	out		pinc,r20
	rjmp	main

comparar_con_dos:
	cpi		r22,DOS
	brne	comparar_con_tres
	ldi		r20,2
	out		pinc,r20
	rjmp	main

comparar_con_tres:
	cpi		r22,TRES
	brne	comparar_con_cuatro
	ldi		r20,4
	out		pinc,r20
	rjmp	main

comparar_con_cuatro:
	cpi		r22,CUATRO
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

	ldi		r16, (1<<RXEN0) | (1<<TXEN0) | (0<<UCSZ02)  | (1<<TXCIE0) | (1<<RXCIE0)	; habilito transmision y recepcion, 8bits, interrupciones
	sts		UCSR0B, r16

	ret

configure_ports:
	ldi     r16,0xFF      
    out     DDRC,r16			;habilito todas como salida
ret

Int_tx:	
	lpm		r16, Z+	
	cpi		r16, 0x00			; verifico fin de cadena
	breq	fin_cadena		
	sts		UDR0, r16
	rjmp	end
fin_cadena:
	lds		r16,UCSR0B		
	cbr		r16,(1<<TXCIE0)
	sts		UCSR0B, R16
end:
	reti
	
Int_rx:	
	lds		r17, UDR0			; guardo en r17 caracter del buffer
	reti

tabla_rom: .db "***Hola Labo de micro***" ,0x0D,  "Escriba 1, 2, 3 o 4 para controlar los LEDs",0x0D,0x00
