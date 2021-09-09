 ; Archivo:	  main.s  
 ; Dispositivo:	  PIC16F887
 ; Autor:	  Javier López
 ; Compilador:	  pic-as (v2.30), MPLAB V5.50
 ; 
 ; Programa:	  Contador binario de 8 bits con dos display de 7seg
 ; Harware:	  Push buttons en porte, leds en portb, displays en portc,
 ;		  transistores en puerto d
 ; 
 ; Creado: 23 agosto, 2021
 ; Última modificación: 24 agosto, 2021
  
 PROCESSOR 16F887
 #include <xc.inc>
 
 ;configuration word 1
 CONFIG FOSC=INTRC_NOCLKOUT	// Oscillador Interno sin salidas
 CONFIG WDTE=OFF    // WDT disabled (reinicio repetitivo del pic)
 CONFIG PWRTE=OFF    // PWRT enabled (espera de 72ms al iniciar)
 CONFIG MCLRE=OFF   // El pin de MCLR se utiliza como I/O
 CONFIG CP=OFF	    // Sin protección de código
 CONFIG CPD=OFF	    // Sin protección de datos
 
 CONFIG BOREN=OFF   // Sin reinicio cuando el voltaje de alimentación baja de 4V
 CONFIG IESO=OFF    // Reinicio sin cambio de reloj de interno a externo
 CONFIG FCMEN=OFF   // Cambio de reloj externo a interno en caso de fallo
 CONFIG LVP=OFF	    // programación en bajo voltaje permitida
 
 ;configuration word 2
 CONFIG WRT=OFF		// Protección de autoescritura por el programa desactivada
 CONFIG BOR4V=BOR40V	// Reinicio abajo de 4V, (BOR21V=2.1V)
 
 restart_tmr0 macro
    banksel PORTA
    movlw   131		; valor inicial para obtener saltos de 2ms
    movwf   TMR0	; almacenar valor inicial en TMR0
    bcf	    INTCON, 2	; limpiar bandera de overflow
    endm
 
 restart_tmr1 macro
    movlw   0x85	    ; ingresar valor de 1seg, (0x85EE) a TMR1
    movwf   TMR1H
    movlw   0xEE
    movwf   TMR1L  
    bcf	    TMR1IF	    ; limpiar bandera de overflow
    endm
 
 wdivl	macro	divisor, cociente, residuo, dividendo
    movwf   dividendo
    clrf    dividendo+1
    incf    dividendo+1
    movlw   divisor
    subwf   dividendo, F
    btfsc   STATUS,0
    goto    $-4
    decf    dividendo+1, w
    movwf   cociente
    movlw   divisor
    addwf   dividendo, w
    movwf   residuo	;division en 100
    endm

 PSECT udata_bank0 ; common memory
    dividendo:		DS  3	; 1 byte
    segundos:		DS  1	; 1 byte
    conteo:		DS  1	; 1 byte
    switch:		DS  1	; 1 byte
    cociente_d0:	DS  1	; 1 byte
    residuo_d1:		DS  1	; 1 byte
    mostrar_d0:		DS  1	; 1 byte
    mostrar_d1:		DS  1	; 1 byte
    
 PSECT udata_shr ; common memory
    W_TEMP:		DS  1	; 1 byte
    STATUS_TEMP:	DS  1	; 1 byte
    
 ;------------------Reset--------------------
 PSECT resVect, class=CODE, abs, delta=2
 ORG 00h	; posición 0000h para el reset
 resetVec:
     PAGESEL main
     goto main
     
 ;-------------Vector interrupcion--------------    
 PSECT intVect, class=CODE, abs, delta=2
 ORG 04h	; posición 0004h para interrupciones
 
 push:
    movwf	W_TEMP
    swapf	STATUS, W
    movwf	STATUS_TEMP
    
 isr:
    btfsc	TMR1IF		; chequear bandera de overflow
    call	int_t1
    btfsc	TMR2IF		; chequear bandera de overflow
    call	int_t2
    btfsc	TMR0IF		; chequear bandera de overflow
    call	int_t0
    
 pop:
    swapf	STATUS_TEMP, W
    movwf	STATUS
    swapf	W_TEMP, F
    swapf	W_TEMP, W
    retfie
    
 ;--------------------- subrutinas de interrupcion ---------------------
 int_t0:
    restart_tmr0		; reiniciar tmr0 y limpiar bandera
    clrf    PORTD		; limpiar ambas opciones de salida de display
    btfsc   switch, 0		
    goto    display_1
 display_0:			; display de decenas	
    movf    mostrar_d0, w	; mover el valor a mostrar a w
    movwf   PORTC		; mover w a puerto c
    bsf	    PORTD,0		; encender display 0
    goto    siguiente_display	; cambiar de display para actualizar el otro
 display_1:			; 
    movf    mostrar_d1, w	; mover el valor a mostrar a w
    movwf   PORTC		; mover w a puerto c
    bsf	    PORTD,1		; encender display 1
    goto    siguiente_display	; cambiar de display para actualizar el otro
 siguiente_display:		; invertir switch para cambiar de display
    movlw   1
    xorwf   switch, F		; cambiar valor del switch
    return
    
 int_t1:
    restart_tmr1
    incf	segundos	// incrementar variable auxiliar
    return
    
 int_t2:
    bcf		TMR2IF
    incf	conteo		// incrementar variable auxiliar
    return
 
 ;-------------------------------------------------------------------------
 PSECT code, delta=2, abs
 ORG 100h
 ;------------------------------ tabla ------------------------------------
 tabla:
    clrf    PCLATH
    bsf	    PCLATH, 0	; PCLATH = 01	PCL = 02
    andlw   0x0f
    addwf   PCL		; PC = PCLATH + PCL + w
    retlw   00111111B	; 0
    retlw   00000110B	; 1
    retlw   01011011B	; 2
    retlw   01001111B	; 3
    retlw   01100110B	; 4
    retlw   01101101B	; 5
    retlw   01111101B	; 6
    retlw   00000111B	; 7
    retlw   01111111B	; 8
    retlw   01101111B	; 9
    retlw   01110111B	; A
    retlw   01111100B	; B
    retlw   00111001B	; C
    retlw   01011110B	; D
    retlw   01111001B	; E
    retlw   01110001B	; F

 ;------------------------------- Codigo ----------------------------------   
 ;-------------configuración------------------
 main:
    call	config_io
    call	config_reloj
    call	config_tmr0
    call	config_tmr1
    call	config_tmr2
    call	config_int_enable
    banksel	PORTA
    
 ;-------------loop principal-----------------
 loop:
    movf	segundos, w	    // pasar variable incrementada a puerto b
    movwf	PORTB		    // para poder visualizar sus cambios
    
    movf	conteo, w	    // pasar variable incrementada a puerto a
    movwf	PORTA		    // para poder visualizar sus cambios
    
    movf	segundos, w
    movwf	dividendo
    wdivl	10, cociente_d0, residuo_d1, dividendo	// división
    call	prep_displays	    // convertir número a valores de display
    
    movlw	100
    subwf	segundos, w
    btfsc	STATUS,2	    // si el resultado anterior no es 0, saltar
    clrf	segundos
    clrw
    goto	loop
 
 ;-------------------------- configuraciones -----------------------------
 ;-------------------------- configurar io -------------------------------
 config_io:		    ; entradas y salidas
    banksel	ANSEL
    clrf	ANSEL
    clrf	ANSELH	    ; pines digitales
    banksel	TRISB
    bcf		TRISA,0	    ; puerto a como salida
    clrf	TRISB	    ; puerto b como salida
    clrf	TRISC	    ; puerto c como salida
    bcf		TRISD,0
    bcf		TRISD,1	    ; puerto d como salida
    banksel	PORTB
    bcf		PORTA,0	    ; limpiar puerto a
    clrf	PORTB	    ; limpiar puerto b
    clrf	PORTC	    ; limpiar puerto c
    bcf		PORTD,0
    bcf		PORTD,1	    ; limpiar puerto d
    return
 ;-------------------------- configurar reloj -------------------------------
 config_reloj:		    ; configurar velocidad de oscilador
    banksel	OSCCON
    bcf		OSCCON, 6
    bsf		OSCCON, 5
    bsf		OSCCON, 4   ; reloj a 500kHz
    bsf		OSCCON, 0   ; reloj interno
    return
 ;-------------------------- configurar tmr0 --------------------------------
 config_tmr0:		    ; configurar interrupcion de tmr0
    banksel OPTION_REG
    bcf		T0CS	    ; reloj interno
    bcf		PSA	    ; prescaler a tmr0
    bcf		PS2
    bcf		PS1
    bcf		PS0	    ; prescaler a 1:2
    restart_tmr0
    return
 ;-------------------------- configurar tmr1 --------------------------------
 config_tmr1:		    ; configurar interrupcion de tmr1
    banksel	T1CON
    bcf		TMR1GE	    ; timer1 siempre contando
    bsf		T1CKPS1
    bcf		T1CKPS0	    ; prescaler 1:4
    bcf		T1OSCEN	    ; oscilador LP apagado
    bcf		TMR1CS	    ; reloj interno
    bsf		TMR1ON	    ; reloj encendido
    restart_tmr1
    return
 ;-------------------------- configurar tmr2 --------------------------------
 config_tmr2:		    ; configurar interrupcion de tmr2
    banksel	PORTA
    bsf		TOUTPS3
    bsf		TOUTPS2
    bsf		TOUTPS1
    bsf		TOUTPS0	    ; postscaler 1:16
    bsf		TMR2ON	    ; activar timer 2
    bsf		T2CKPS1
    bsf		T2CKPS0	    ; prescaler 16
    
    banksel	TRISA
    movlw	244	    ; 196 para 0.050s
    movwf	PR2
    clrf	TMR2	    ; limpiar timer2
    bcf		TMR2IF	    ; limpiar bandera
    return
 ;------------------------ config interrupciones ---------------------------
 config_int_enable:	    ; habilitar interrupciones
    banksel	TRISA
    bsf		TMR1IE	    ; interrupcion timer1 activada
    bsf		TMR2IE	    ; interrupcion timer2 activada
    banksel	T1CON
    bsf		GIE	    ; interrupciones globales activadas
    bsf		PEIE	    ; interrupciones periféricas activadas
    bsf		T0IE	    ; interrupcion del tmr0 activada
    bcf		TMR1IF	    ; limpiar bandera de overflow de timer1
    bcf		TMR2IF	    ; limpiar bandera de overflow de timer2
    return
 ;------------------------ preparar displays ---------------------------
 prep_displays:
    movf	cociente_d0, w	    ; mover cociente a w
    call	tabla		    ; convertir valor con la tabla
    movwf	mostrar_d0	    ; pasar a registro que se usará en interrup
    
    movf	residuo_d1, w	    ; mover residuo a w
    call	tabla		    ; convertir valor con la tabla
    movwf	mostrar_d1	    ; pasar a registro que se usará en interrup
    return
 END