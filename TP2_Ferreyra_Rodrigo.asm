;
; AssemblerApplication3.asm
;
; Created: 12/11/2020 00:08:38
; Author : Rodrigo
;
; Replace with your application code

.include "m328Pdef.inc"

.def temp = r25

.dseg
.org SRAM_START
sensor_1_state_change: .byte  1
sensor_2_state_change: .byte  1
reg16: .byte 1

.dseg
.org SRAM_START

.cseg
.org 0x0000
	rjmp	inicio
.org INT0addr
	rjmp	Handler_Int_Ext0
.org INT1addr
	rjmp	Handler_Int_Ext1
.org INT_VECTORS_SIZE

inicio:
	ldi  r16, low(RAMEND)
	out  SPL, r16
	ldi  r16, high(RAMEND)
	out  SPH, r16
	rcall   configure_ports
	rcall configure_int0
	rcall configure_int1
	rcall enable_int0
	rcall enable_int1
	rcall init_variables
	sei
	

main_loop:
	ldi r17,0x01
izquierda:
	rcall check_sensor_state
	OUT portc,R17
	rcall retardo_200ms
	;rcall retardo_500ms
	lsl r17
	mov r18,r17
	subi r18,32
	breq derecha
	rjmp izquierda
derecha:
	rcall check_sensor_state
	OUT portc,R17
	rcall retardo_200ms
	;rcall retardo_500ms
	lsr r17
	mov r18,r17
	subi r18,0x01
	breq izquierda
	rjmp derecha
	rjmp main_loop


init_variables:
	clr   temp
	sts   sensor_1_state_change, temp
	sts   sensor_2_state_change, temp
	ldi r16,0x00
	sts reg16,r16
    ret

configure_ports:
	ldi     temp,0xFF      
    out     DDRC,temp	;habilito todas como salida
	ldi		temp,0x00 
	out		DDRD,temp	;habilito como entrada puerto donde estan los pulsadores
	out		PORTC,temp
	out		PORTD,temp
ret

/*interrupciones por flanco bajo*/
configure_int0:
   lds  temp, EICRA
   ori  temp, (1 << ISC00) | (1 << ISC01)
   sts  EICRA, temp 
   ret

configure_int1:
   lds  temp, EICRA
   ori  temp, (1 << ISC10) | (1 << ISC11)
   sts  EICRA, temp 
   ret

/*habilitar int0 e int1 */
enable_int0:
   in temp, EIMSK
   ori temp, (1<<INT0)
   out EIMSK, temp
   ret
enable_int1:
   in temp, EIMSK
   ori temp, (1<<INT1)
   out EIMSK, temp
   ret

/*retardos*/
retardo_1:							
	ldi r19,200						;1CM
loop_retardo_1:						
	dec r19							;1CM
	brne loop_retardo_1				;2CM
ret									;4CM            CM = 3*200+4+1-1= 604 CM , t= 37.75us

retardo_5ms:
    ldi r20,131						;1 CM
loop_retardo_5ms:
    rcall   retardo_1               ;4 CM del rcall
    dec r20							;1CM
	brne loop_retardo_5ms			;2CM
ret									;4 CM				CM= 1+x*(604+7)-1+4= 80000    X=131   t=5.0028ms

retardo_500ms:
 ldi r21,100					;1 CM
loop_retardo_500ms:
    rcall   retardo_5ms             ;4 CM del rcall
    dec r21							;1CM
	brne loop_retardo_500ms			;2CM
ret									;4 CM				CM= 1+100*(80045+7)-1+4= 8005204   t=500,3ms

retardo_200ms:
 ldi r26,40					;1 CM
loop_retardo_200ms:
    rcall   retardo_5ms             ;4 CM del rcall
    dec r26							;1CM
	brne loop_retardo_200ms		;2CM
ret	

debounce_time:
	push	R24
    eor     R24, R24
loop_retardo_debounce:
    rcall   retardo_5ms
    inc     r24
    cpi     r24,10
    brne    loop_retardo_debounce
	pop		R24
    ret

; Se chequea si hubo un cambio en un sensor y se ejecuta el codigo correspondiente
check_sensor_state:
   push  temp
   lds   temp, sensor_1_state_change	;cargo en temp(r16) el contenido de sensor_1_...
   ror   temp							;rotacion a la derecha, el bit menos significativo va al carry
   brcc  check_sensor_2					;si el carry esta vacio salto a check....
   rcall sensor_1_state_changed			;si el carry estaba en 1 salto a sensor_1_state....
check_sensor_2:
   lds   temp, sensor_2_state_change
   ror   temp
   brcc  end_check_sensor_state
   rcall sensor_2_state_changed
end_check_sensor_state:
   pop   temp
   ret

sensor_1_state_changed:
    push  temp
    clr   temp
    sts   sensor_1_state_change, temp
;Codigo a realizar cuando el sensor 1 cambia
	rcall	debounce_time
	sbis	PIND, 2 
	rjmp    fin1   ;no tengo flanco alto
	ldi r22,15
	loop:
	ldi	r23,0x21
	out PORTC,r23
	;rcall retardo_500ms
	rcall retardo_200ms
	clr r23
	out PORTC,r23
	;rcall retardo_500ms
	rcall retardo_200ms
	dec r22
	brne loop
fin1:
	pop  temp
	ret

sensor_2_state_changed:
	push  temp
	clr   temp
	sts   sensor_2_state_change, temp
;Codigo a realizar cuando el sensor 2 cambia
	rcall	debounce_time
	sbis	PIND, 3 
	rjmp    fin2   ;no tengo flanco alto
	lds r16,reg16
	out PORTC,r16
	rcall retardo_500ms
	rcall retardo_500ms
	rcall retardo_500ms
	inc r16
	cpi r16,64       ;cuando llego a 64 reinicio r16
	brne sigo
	rjmp borrar
borrar:
	clr r16
sigo:
	sts reg16,r16
fin2:
	pop  temp
	ret

Handler_Int_Ext0:
	push  temp
	in	 temp, SREG  ;Guardo el SREG en el stack
	push  temp
	ser   temp       ;setea todos los bits en 1
	sts   sensor_1_state_change, temp
	pop   temp
	out	 SREG, temp  ;Recupero el SREG
	pop   temp
	reti

Handler_Int_Ext1:
	push  temp
	in	 temp, SREG  ; Guardo el SREG en el stack
	push  temp
	ser   temp
	sts   sensor_2_state_change, temp
	pop   temp
	out	 SREG, temp  ;Recupero el SREG
	pop   temp
	reti
