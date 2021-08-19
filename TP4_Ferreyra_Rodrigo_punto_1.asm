.include "m328Pdef.inc"

.def temp = r16

.dseg
.org SRAM_START
cambio_pd: .byte  1

.cseg
.org 0x0000
	rjmp	inicio
.org PCI2addr
	rjmp	rutina_pcint2
.org 0x001A
	rjmp	Timer1_OVF
.org INT_VECTORS_SIZE

inicio:

	; Inicializar Stack
	ldi  temp, low(RAMEND)
	out  SPL, temp
	ldi  temp, high(RAMEND)
	out  SPH, temp
	rcall configure_ports
	rcall config_pchange
	rcall init_timer_1
	sei

main_loop:
	rcall		verificar_pulsadores
	rjmp		main_loop



;Configurar los pines de interrupcion externa como entradas
configure_ports:
	ldi		temp,0x00
	out		DDRD,temp
	ldi		temp,0x01
	out		DDRB,temp
	sbi		portb,0
	ret

config_pchange:
;HABILITAR PUERTO
	ldi	temp, (1<<PCIE2)
	sts	PCICR, temp									;Pin Change Interrupt Control Register , habilito pin change 2
;HABILITAR PIN
	ldi temp, (1<<PCINT19)|(1<<PCINT18)				
	sts PCMSK2, temp
	ret

init_timer_1: 
	lds		temp, TCCR1A      //habilito modo ///CTC 
	andi	temp,~(1 << WGM10)  ;0
	andi	temp,~(1 << WGM11)  ;0
	sts		TCCR1A, temp 
	lds		temp, TCCR1B
	ori		temp,(1 << WGM12)   ;1
	andi	temp, ~(1 << WGM13) ;0
	sts		TCCR1B, temp

	lds		temp, TIMSK1    //habilito interrupcion por overflow
	ori		temp,(1<<TOIE1) 
	sts		TIMSK1, temp

	LDI R20,0xff
	sts OCR1AH,R20
	LDI R20,0xff
	sts OCR1AL,R20 
	ret

init_timer_0: 
	in		temp, TCCR0A		 //habilito modo normal
	andi	temp,~(1 << WGM00)  ;0
	andi	temp,~(1 << WGM01)  ;0
	out		TCCR0A, temp 
	in		temp, TCCR0B
	andi	temp, ~(1 << WGM02) ;0
	out		TCCR0B , temp

	in		temp, TCCR0B
	andi	temp,~(1<<CS00)  ;0
	andi	temp,~(1<<CS01)  ;0
	ori		temp,(1<<CS02)	 ;1
	out		TCCR0B, temp
	ret

off_timer_0:
	in		temp, TCCR0B
	andi	temp,~(1<<CS00)  ;0
	andi	temp,~(1<<CS01)  ;0
	andi	temp,~(1<<CS02)	 ;0
	out		TCCR0B, temp
	ret

timer_pre_64:
	lds		temp, TCCR1B
	ori		temp,(1<<CS10)   ;1
	ori		temp,(1<<CS11)   ;1
	andi	temp,~(1<<CS12)	 ;0
	sts		TCCR1B, temp
	ret

timer_pre_256:
	lds		temp, TCCR1B
	andi	temp,~(1<<CS10)  ;0
	andi	temp,~(1<<CS11)  ;0
	ori		temp,(1<<CS12)	 ;1
	sts		TCCR1B, temp
	ret

timer_pre_1024:
	lds		temp, TCCR1B
	ori		temp,(1<<CS10)   ;1
	andi	temp,~(1<<CS11)  ;0
	ori		temp,(1<<CS12)	 ;1
	sts		TCCR1B, temp
	ret

timer_off:
	lds		temp, TCCR1B
	andi	temp,~(1<<CS10)  ;0
	andi	temp,~(1<<CS11)  ;0
	andi	temp,~(1<<CS12)	 ;0
	sts		TCCR1B, temp
	ret

//interrupcion por overflow
Timer1_OVF:
	ldi		temp,0x01
	out		pinb,temp  //PB0
	reti
	
rutina_pcint2:
	ser		temp
	sts		cambio_pd, temp
	reti

procesar_tecla:
	ldi		temp,0x00
	sts		cambio_pd,temp
	rcall	retardo_50ms
	in		temp, PIND				//obtengo bit de preset y clear PD0 y  PD1
	andi	temp,0b00001100
	cpi		temp,0b00000000
	breq	set_Pre_1
	cpi		temp,0b00000100
	breq	set_Pre_2
	cpi		temp,0b00001000
	breq	set_Pre_3
	cpi		temp,0b00001100
	breq	set_Pre_4
	rjmp	end
set_Pre_1:
	rcall	timer_off
	sbi		portb,0
	rjmp	end
set_Pre_2:
	rcall	timer_pre_64
	rjmp	end
set_Pre_3:
	rcall	timer_pre_256
	rjmp	end	
set_Pre_4:
	rcall	timer_pre_1024
	rjmp	end	
end:
	ret

verificar_pulsadores:
   push  temp
   lds   temp, cambio_pd
   ror   temp
   brcc  end_verificar
   rcall procesar_tecla
end_verificar:
   pop   temp
   ret

//Retardos para debounce de pulsadores

delay_10ms:
	rcall	init_timer_0
	ldi		temp,0x64
	out		TCNT0,temp
again:
	in		temp,TIFR0
	sbrs	temp,0
	rjmp	again

	rcall off_timer_0
	ldi		temp,1<<TOV0
	out		TIFR0,temp
	ret

retardo_50ms:
    eor     R18, R18
loop_retardo_50ms:
    rcall   delay_10ms
    inc     r18
    cpi     r18,5
    brne    loop_retardo_50ms
    ret
