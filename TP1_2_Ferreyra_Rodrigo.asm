;*************************************************************************************
;Modificar programa para que prenda un LED cuando se presiona el pulsador 1 y quede
;parpadeando hasta que se apague cuando se presiona el botón 2.
;
; Autor: Ferreyra Rodrigo
; Padron:102625
; Fecha: 27/10/2020
;
;*************************************************************************************
.equ    PUL_PORT_DIR_1 =  DDRB
.equ    PUL_PORT_IN_1  =  PINB
.equ	PUL_PORT_1     =  PORTB
.equ    PUL_PIN_ON      =  0


.equ    PUL_PORT_DIR_2 =  DDRD
.equ    PUL_PORT_IN_2  =  PIND
.equ	PUL_PORT_2    =  PORTD
.equ    PUL_PIN_OFF    =  7

.equ    LED_PORT_DIR =  DDRD
.equ    LED_PORT     =  PORTD
.equ    LED_PIN      =  2

;Inicio del codigo
.org	0x0000
	rjmp inicio;

;Direccion siguiente a la ultima interrupcion. 
.org INT_VECTORS_SIZE

inicio:
; Se inicializa el Stack Pointer al final de la RAM utilizando la definicion global
; RAMEND
	ldi		r16,HIGH(RAMEND)
	out		sph,r16
	ldi		r16,LOW(RAMEND)
	out		spl,r16

	rcall   configure_ports
	;rcall configure_pull_up
main_loop:
;Espero un flanco ascendente
flanco_asc_ON:
	sbis	PUL_PORT_IN_1, PUL_PIN_ON
	rjmp	flanco_asc_ON
	rcall	debounce_time
	sbis	PUL_PORT_IN_1, PUL_PIN_ON  ;si tengo flanco alto salto a parpadear
	rjmp	flanco_asc_ON

	parpadear:
	;rcall   retardo_5ms
	rcall   retardo_500ms
    sbi     LED_PORT,LED_PIN    ;setea bit
    ;rcall   retardo_5ms
	rcall   retardo_500ms
    cbi     LED_PORT,LED_PIN    ;borra bit
flanco_asc_OFF:
	sbis	PUL_PORT_IN_2, PUL_PIN_OFF
	rjmp	parpadear
	rcall	debounce_time
	sbis	PUL_PORT_IN_2, PUL_PIN_OFF
	rjmp	parpadear
	cbi     LED_PORT,LED_PIN    ;borra bit
	rjmp main_loop
;*************************************************************************************
; Se configuran los puertos del microcontrolador como entrada/salida
;
; En este caso se configura el pin 2 del puerto D como salida , que corresponde al pin 4 del atmega328p
;se habilita como entrada todos los pines del puerto b y d, luego sobreescribo como salida el pin 4 que es donde va el led 
;
;Entrada: pulsador			
;Salida: leds					
;Registros utilizados: R20	
;*************************************************************************************
configure_ports:
	ldi     r20,0x00           ;habilito todas como entradas  
    out     PUL_PORT_DIR_1,r20

	ldi     r20,0x00            ;habilito todas como entradas   
    out     PUL_PORT_DIR_2,r20

	sbi     LED_PORT_DIR,2    ; habilito el pin 4 como salida
    cbi     LED_PORT,2   ;
ret

;*************************************************************************************
; Retardo de 50ms debounce (Calculado con un cristal de 16MHz) se reutilizo rutina de 5ms en un bucle x10
;Entrada: 					
;Salida: 					
;Registros utilizados: Ninguno en esta funcion, todos los registros son respetados.
;*************************************************************************************
debounce_time:
	push	R19
    eor     R19, R19
loop_retardo_debounce:
    rcall   retardo_5ms
    inc     r19
    cpi     r19,10
    brne    loop_retardo_debounce
	pop		R19
    ret
;*************************************************************************************
; Retardo de 37.75us BLOQUEANTE (Calculado con un cristal de 16MHz, para otro valor 
;   hay que recalcular todo)
;
; Calculo de tiempo en el loop: 
;   - El loop interno se debe ejecutar un numero X de veces para que el tiempo total sea de 
;     100useg
;   - Dentro del loop se tarda 3CM
; Se suma ademas del loop: 
;   - 1 CM del ldi inicial 
;   - 4 CM del ret 
; Se resta:
;   - 1 CM del brne cuando la comparación es cierta
;
;   Tiempo total  = 1 + 200 * 3 - 1 + 4 = 37.75useg  
;Entrada: 					
;Salida: 					
;Registros utilizados: R21
;*************************************************************************************
retardo_1:							
	ldi r21,200					;1CM
loop_retardo_1:						
	dec r21							;1CM
	brne loop_retardo_1				;2CM
ret									;4CM            CM = 3*200+4+1-1= 604 CM , t= 37.75us


;*************************************************************************************
; Retardo de 5ms BLOQUEANTE (Calculado con un cristal de 16MHz, para otro valor 
;   hay que recalcular todo)
;
; Calculo de tiempo: 
;   - El loop interno se debe ejecutar un numero X de veces para que el tiempo total sea de 
;     10mseg
;   - Cada ejecucion tarda 37.75useg o 604CM de la funcion a la que se llama
;   - 6useg en el calculo del loop
;   Tiempo total  = 1+ X * ( 604 + 7)+4-1 = 80000CM  --> X = 130.9263
;   Se elije X = 131 para asegurarse que se esta esperando el tiempo deseado.
;
;   Para calcular el tiempo total se debe incluir el eor inicial, el ciclo que se pierde en el bren y el ret final
;
;   ciclos totales = 1 + 131 * (604 + 7) - 1 + 4 = 80045  === Tiempo total=80045/(16.10^6)=5.00281ms
;
;   El metodo tiene 2.8125useg de error.
;
;Entrada: 					
;Salida: 					
;Registros utilizados: R22
;*************************************************************************************

retardo_5ms:
    ldi r22,131					;1 CM
loop_retardo_5ms:
    rcall   retardo_1               ;4 CM del rcall
    dec r22							;1CM
	brne loop_retardo_5ms			;2CM
ret									;4 CM				CM= 1+x*(604+7)-1+4= 80000    X=131   t=5.0028ms


retardo_500ms:
 ldi r24,100					;1 CM
loop_retardo_500ms:
    rcall   retardo_5ms               ;4 CM del rcall
    dec r24							;1CM
	brne loop_retardo_500ms			;2CM
ret									;4 CM				CM= 1+100*(80045+7)-1+4= 8005204   t=500,3ms
