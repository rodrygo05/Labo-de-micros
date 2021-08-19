/*
 * Trabajo Practico Integrador
 *
 *
 * 
 * Programa que genera un senial PWM de frecuencia 60Hz, verifica su frecuencia 
 * utilizando el timer1 en modo input capture disparado por la int0, y mide la 
 * tension sobre el capacitor de un circuito RC utilizando el ADC. Los valores de 
 * tension y la frecuencia medidas se trasmiten por puerto serie con una secuencia
 * de 100 valores de tension, 1 de frecuencia. 
 *
 *
 *  Autores: Rodrigo Ferreyra - Martin Anus
 *	Fecha: 01/03/2021
 *  Version: 01
 */


 ;Incluyo las dependencias del Micro ATMega 328P
.include "m328pdef.inc"

 
 ;Defino Constantes .EQU
.equ	ADC_PORT		= PORTC
.equ	ADC_PORT_DIR	= DDRC
.equ	ADC_PORT_IN		= PINC
.equ	ADC_PIN_0		= 0
.equ	bps		= 25 ;Baud PreScaler para baud rate 38400 con fosc 16MHz

; Alias de los registros
.def	dif_L = r1
.def	dif_H = r2  
.def	start_adc = r3
.def	temp	= r16
.def	temp_h	= r17
.def	char	= r18
.def	Vc_count	= r19
.def	freq_byte = r20
.def	Is_First_Captured = r21
.def	IC_Value1L=r22
.def	IC_Value1H=r23
.def	IC_Value2L=r24
.def	IC_Value2H=r25



; Definicion de una macro de nombre load_lh_regs
; Macro que carga un valor de dos bytes en dos registros
; LOW y HIGH son sentencias para el pre-ensamblador
.macro load_lh_regs
	ldi		@0, LOW(@2)			;@0 primer argumento de la llamada
	ldi		@1, HIGH(@2)		;@1 segundo argumento de la llamada
.endmacro						;@2 tercer argumento de la llamada



.cseg
.org 0x0000
; Segmento de datos en memoria de codigo
	rjmp	main

; Defino Vectores de interrupcion
.org	INT0addr
	rjmp	Handler_Int_Ext0
.org	ICP1addr
	rjmp	Handler_Int_timer1_IC
.org UTXCaddr
	rjmp UTXC_HANDLER

.org ADCCaddr
	rjmp ADC_COMPLETE_HANDLER

; Arranco el programa despues de los vectores de interrupcion
.org INT_VECTORS_SIZE
main:

	;Inicializo el stack
	ldi temp, high(RAMEND)
	out sph, temp
	ldi temp, low(RAMEND)
	out spl, temp


	rcall config_ports

	rcall USART_initialize

	rcall config_adc

	rcall		configure_int0
	rcall		enable_int0

	rcall		init_variables

	rcall		init_timer_0
	rcall		init_timer_1
	
	sei

	ldi temp, 0xCF
	mov start_adc, temp ; Activo conversion seteando ADSC
	sts ADCSRA, start_adc  ; Inicia la primera conversion.

end:
	rjmp end
    


init_variables:
   ldi	Is_First_Captured,0x00
   ldi	Vc_count, 100
   ldi freq_byte, 0x00
   ret

ADC_COMPLETE_HANDLER: 
	; Leo valor de salida del ADC 
	lds char, ADCH
	; Trasmito el valor por USART
	sts UDR0, char
	reti

; Tx Usart Completada
UTXC_HANDLER:
	cpi Vc_count, 0x00
	brne enable_adc
	rcall freq_tx			; Trasmito el valor de frecuencia
	rjmp end_UTXC_HANDLER
enable_adc:
	dec Vc_count
	; Habilito el ADC para nueva comparacion
	sts ADCSRA, start_adc
	
end_UTXC_HANDLER:
	reti



freq_tx:
	cpi freq_byte, 0x00
	brne not_sync_byte

sync_byte:
	ldi temp, 0x00	;Trasmito un '0' para avisar que vienen valores de freq
	sts UDR0, temp
	inc freq_byte
	rjmp end_freq_tx
not_sync_byte:
	cpi freq_byte, 0x01		; Envio parte baja de la freq medida
	brne tx_freqH
tx_freqL:
	sts UDR0, dif_L 
	inc freq_byte
	rjmp end_freq_tx
tx_freqH:
	sts UDR0, dif_H		; Envio parte alta de la freq medida
	ldi freq_byte, 0x00
	ldi Vc_count, 100	; Seteo contador para trasmitir 100 valores mas de Vc
end_freq_tx:
	ret


Handler_Int_Ext0:
	ldi		temp ,0x01			; Hago saltar la interrupcion de ICP1
	out		pinb,temp			;toogle 2 veces icp1
	out		pinb,temp 	
	reti


Handler_Int_timer1_IC:
	cpi		Is_First_Captured, 0xff
	breq capture_2
capture_1:
	lds		IC_Value1L,ICR1L		; Guardo valores de captura1
	lds		IC_Value1H,ICR1H
	ldi		Is_First_Captured, 0xff
	rjmp	end_Handler_Int_timer1_IC
capture_2:
	lds		IC_Value2L,ICR1L		; Guardo valores de captura2 
	lds		IC_Value2H,ICR1H
	rcall	calcular_diferencia										 
	ldi		Is_First_Captured, 0x00			
end_Handler_Int_timer1_IC:
	reti


calcular_diferencia:
	cp		IC_Value1H,IC_Value2H
	breq	iguales
	brcs	val2_mayor
	brcc	val1_mayor
iguales:	
	cp		IC_Value1L,IC_Value2L
	brcs	val2_mayor
	brcc	val1_mayor
	rjmp	end_diff
val1_mayor:
	ldi		temp, 0xff	;Difference = (0xffff-IC_Value1) + IC_Value2 + 1;
	ldi		temp_h, 0xff
	sub		temp, IC_Value1L
	sbc		temp_h , IC_Value1H
	
	add		temp ,IC_Value2L
	adc		temp_h ,IC_Value2H
	
	ldi		r30, 0x01
	add		temp,r30
	ldi		r30, 0x00
	adc		temp_h,r30

	mov		dif_L,	temp	; Valores de salida de frecuencia calculada
	mov		dif_H,	temp_h

	rjmp	end_diff
val2_mayor:
	sub		IC_Value2L,IC_Value1L	;Difference = IC_Value2-IC_Value1;
	sbc		IC_Value2H,IC_Value1H			
	mov		dif_L,	IC_Value2L
	mov		dif_H,	IC_Value2H		; Valores de salida de frecuencia calculada
end_diff:
	ret

	
config_ports:
	config_icp1_port:
		ldi temp, 0x01				; seteo PB0/ICP1 como salida
		out DDRB, temp				; para poder activar interrupcion x software
	config_adc_port:
		ldi temp, 0x00
		out ADC_PORT_DIR, temp		; Seteo PortC como entrada
		out ADC_PORT, temp			; sin pull-up
	config_pwm_int0_port:
		ldi		temp,0x40			;PD2 entrada int0 
		out		DDRD,temp			;PD6 como salida  OC0A para PWM
	ret



USART_initialize:	
	;Configuro el prescaler
	load_lh_regs temp, temp_h, bps		
	sts UBRR0L, temp
	sts UBRR0H, temp_h

	;Configuro en modo asincronico 8N1
				;async		 | No paridad | 1bit stop | 8bits-1 
	ldi temp, (0<<UMSEL00) | (0<<UPM00) | (0<<USBS0) | (0b11<<UCSZ00)  
	sts UCSR0C, temp

	;Habilito	  int Tx	|	Tx		 | termino de configurar 8bits de datos
	ldi temp,   (1<<TXCIE0) | (1<<TXEN0) | (0<<UCSZ02)  
	sts UCSR0B, temp

	ret


config_adc:
				; Avcc ref | Left adjust | channel 0 (1110 =1.1v / 1111 0V) 
	ldi temp, (0b01<<REFS0) | (1<<ADLAR) | (0b0000<<MUX0)
	sts ADMUX, temp

	; ADC enable, auto-trigger disable, interrupt enable, Prescaler 128 = 125kHz
	ldi temp, (1<<ADEN) | (0<<ADATE) | (1<<ADIE) | (0b111<<ADPS0)
	sts ADCSRA, temp

	; Disable all pins except pin0
	ldi temp, 0xFE
	sts DIDR0, temp

	ret


configure_int0:   
	lds		temp, EICRA
	ori		temp, (1 << ISC01)		; Configuro int0 por flanco ascendente
	ori		temp, (1 << ISC00)	
	sts		EICRA, temp 
	ret

enable_int0:
   in		temp, EIMSK
   ori		temp, (1<<INT0)
   out		EIMSK, temp
   ret

//pwm de 61Hz
init_timer_0: 
	in		temp, TCCR0A		 // fast pwm
	ori		temp,(1 << WGM00)  ;1
	ori		temp,(1 << WGM01)  ;1
	out		TCCR0A, temp 

	in		temp, TCCR0B
	ori		temp, (1 << WGM02) ;1
	out		TCCR0B , temp

	in		temp, TCCR0A		 // toogle OC0A
	andi	temp,~(1 << COM0A1)  ;0
	ori		temp,(1 << COM0A0)  ;1
	out		TCCR0A , temp

	in		temp, TCCR0B     //timer preescaler 1024
	ori		temp,(1<<CS00)	 ;1
	andi	temp,~(1<<CS01)  ;0
	ori		temp,(1<<CS02)	 ;1
	out		TCCR0B, temp

	LDI		temp, 128		//duty cicle 50%
	out		OCR0A,temp
	ret

/*
T_max=((2^16)*presscaler)/F_cpu
con preescaler=8
T_max=32ms => sirve
f_min=31Hz

*/
init_timer_1:
	ldi		temp,0x00
	sts		TCCR1A,temp ;timer mode = normal 
	ldi		temp ,0x42
	sts		TCCR1B,temp ;flanco ascendente, CON prees de 8, sin cancelador de ruido

	lds		temp, TIMSK1    //habilito interrupcion por input capture
	ori		temp,(1<<ICIE1) 
	sts		TIMSK1, temp
	ret
