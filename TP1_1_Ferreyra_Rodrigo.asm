;*************************************************************************************
;Hacer un programa que haga parpadear un LED conectado en el PIN 2
;
; Autor: Rodrigo Ferreyra
; Padron:102625
; Fecha: 29/10/2020
;
;*************************************************************************************	
.equ    LED_PORT_DIR =  DDRD
.equ    LED_PORT     =  PORTD
.equ    LED_PIN      =  0

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
	out		spl,r16.

	rcall	configure_ports
main_loop:
	;rcall   retardo_500ms
	rcall   retardo_5ms
    	sbi     LED_PORT,LED_PIN    
    	;rcall   retardo_500ms
	rcall   retardo_5ms
    	cbi     LED_PORT,LED_PIN    
	rjmp	main_loop

;*************************************************************************************;
; En este caso se configura el pin 0 del puerto D como salida , que corresponde al pin 2 del atmega328p
;Entrada: 					
;Salida: 					
;Registros utilizados: R20	
;*************************************************************************************
configure_ports:
	ldi     r20,0x01    ;0000-0001
    out     LED_PORT_DIR,r20  ;habilito el puerto dado como salida
	out     LED_PORT,r20
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
;
;
;Entrada: 					
;Salida: 					
;Registros utilizados: R21
;*************************************************************************************
retardo_1:							
	ldi r21,200					;1CM
loop_retardo_1:						
	dec r21						;1CM
	brne loop_retardo_1				;2CM
ret							;4CM            t = 3*200+4+1-1= 604 CM  = 37.75us
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
    dec r22					;1CM
	brne loop_retardo_5ms			;2CM
ret						;4 CM				t= 1+x*(604+7)-1+4= 80000    X=131   t=5.0028ms

;lo deje para probar porque con el de 5ms no se nota que parpadea
retardo_500ms:
 ldi r24,100					;1 CM
loop_retardo_500ms:
    rcall   retardo_5ms               ;4 CM del rcall
    dec r24					;1CM
	brne loop_retardo_500ms			;2CM
ret						;4 CM				t= 1+100*(80045+7)-1+4= 8005204   t=500,3ms


