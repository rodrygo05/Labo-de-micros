.include "m328Pdef.inc"

.equ	F_CPU	= 16000000					;Freq of the CM
.equ	Pree	= 64						;preescaler
.equ	Frec	= 400						;frecuencia
.equ	ICR		= ((F_CPU/Frec/Pree) - 1)	;baud prescale
.equ	NIVELES	= 128

.def temp = r16

.dseg
.org SRAM_START
tecla_0: .byte  1
tecla_1: .byte  1

.cseg
.org 0x0000
	rjmp	inicio
.org INT0addr
	rjmp	Int_Ext0
.org INT1addr
	rjmp	Int_Ext1
.org INT_VECTORS_SIZE

inicio:
	; Inicializar Stack
	ldi			temp, low(RAMEND)
	out			SPL, temp
	ldi			temp, high(RAMEND)
	out			SPH, temp

	rcall		configure_ports
	rcall		configure_int
	rcall		init_PWM
	rcall		init_var
	sei
main_loop:
	rcall		verificar_pulsadores
	rjmp		main_loop


init_PWM: 
	lds		temp, TCCR1A			//habilito modo FAST PWM 14
	andi	temp,~(1 << WGM10)  ;0
	ori		temp,(1 << WGM11)   ;1
	sts		TCCR1A, temp 

	lds		temp, TCCR1B
	ori		temp,(1 << WGM12)   ;1
	ori		temp,(1 << WGM13)   ;1
	sts		TCCR1B, temp
	rcall	timer_pre_64
	;seteo periodo se;al
	LDI		temp, high(ICR)
	sts		ICR1H,temp
	LDI		temp, low(ICR)
	sts		ICR1L,temp
	//activo salida pb1 clear
	lds		temp, TCCR1A     
	andi	temp,~(1<<COM1A0)  ;0
	ori		temp,(1<<COM1A1)   ;1
	sts		TCCR1A, temp 
	ret

timer_pre_64:
	lds		temp, TCCR1B
	ori		temp,(1<<CS10)   ;1
	ori		temp,(1<<CS11)   ;1
	andi	temp,~(1<<CS12)	 ;0
	sts		TCCR1B, temp
	ret

//config Interrupciones externas
configure_int:
	lds  temp, EICRA						;int0 e int1 flanco alto
	ori  temp, (1 << ISC01) | (1 << ISC00)
	sts  EICRA, temp 

	lds  temp, EICRA
	ori  temp, (1 << ISC10) | (1 << ISC11)
	sts  EICRA, temp

	in temp, EIMSK							;habilito int0 e int1
	ori temp, (1<<INT0) | (1<<INT1)
	out EIMSK, temp
	ret

;Configurar los pines de interrupcion externa como entradas
configure_ports:
	ldi		temp,0x00		; PD2/PD3 int
	out		DDRD,temp
	sbi		DDRB,DDB1		;led en Pb1
	ret

// Interrupciones externas
// Cuando se presiona una tecla setea el flag correspondiente 'tecla_0' o 'tecla_1'
//
Int_Ext0:	
	ser		temp
	sts		tecla_0, temp
	reti

Int_Ext1:
	ser		temp
	sts		tecla_1, temp
	reti

//Rutina en la que se verifica si alguna tecla fue presionada, verificando los flag 
verificar_pulsadores:
   push  temp
   lds   temp, tecla_0			
   ror   temp					//rotacion a la derecha y dejo en el carry bit que se cae
   brcc  verificar_tecla_1		//si C=1 entonces tecla_0 estaba seteada
   rcall subir_brillo
verificar_tecla_1:
   lds   temp, tecla_1			
   ror   temp					//rotacion a la derecha y dejo en el carry bit que se cae
   brcc  end_verificar			//si C=1 entonces tecla_1 estaba seteada
   rcall bajar_brillo
end_verificar:
   pop   temp
   ret

//inicializa variables usadas en las rutina subir brillo y bajar_brillo
init_var:
	ldi		r21,ICR/NIVELES	 // numero de cuentas en un nivel 
	ldi		r20,0x00		 //contador de control
	ret


bajar_brillo:
	ldi		temp,0x00
	sts		tecla_1,temp		//borro flag de 'tecla_1'
	rcall	retardo_50ms
tecla_1_presionada:
	sbis	pind,3				//si tecla 1 esta apretada salteo
	rjmp	end2
	cpi		r20,0				//mientras r20 sea distinto de cero continuo decrementado brillo
	breq	end2
	dec		r20
	muls	r20,r21				//multiplico cantidad de cuentas de un nivel por r20 	
	mov		temp,r1
	sts		OCR1AH,temp
	mov		temp,r0
	sts		OCR1AL,temp
	rcall	delay_10ms			//espero un tiempo para que no baje tan rapido el brillo
	rjmp	tecla_1_presionada  //vuelvo a verificar si esta presionada la tecla
end2:
	ret

subir_brillo:
	ldi		temp,0x00
	sts		tecla_0,temp		//borro flag de 'tecla_0'
	rcall	retardo_50ms
tecla_0_presionada:
	sbis	pind,2				//si tecla 0 esta apretada salteo
	rjmp	end1
	cpi		r20,NIVELES			//mientras r20 sea distinto de niveles continuo incrementando brillo
	breq	end1
	inc		r20
	muls	r20,r21				//multiplico cantidad de cuentas de un nivel por r20 
	mov		temp,r1
	sts		OCR1AH,temp
	mov		temp,r0
	sts		OCR1AL,temp
	rcall	delay_10ms			//espero un tiempo para que no suba tan rapido el brillo 
	rjmp	tecla_0_presionada	//vuelvo a verificar si esta presionada la tecla
end1:
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

//config timer 0, para delay debounce
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