;Projeto Final - Microcontroladores
;Aluno: Albert Kirchner 				RA: 2263580
;Aluno: Guilherme Vinicius Medeiros 	RA: 2159961
;PERIFÉRICOS USADOS:
;AD -> variação duty cycle do PWM
;EEPROM -> salva em qual frequencia estava rodando o programa
;INTERRUPÇÃO -> reset através do botão RB0
;LCD -> printa o menu e o duty cycle
;MODULO CCP -> geração do PWM
;TECLADO MATRICIAL -> seleciona qual frequência do PWM (1,2,3) e volta para o menu (0) 

	__config _XT_OSC & _WDT_OFF & _LVP_OFF & _DEBUG_OFF

	include P16F877A.inc

;---- Paginacao de Memoria de Dados --------------------

bank0 macro		;Seleciona Banco 0 da Memoria
				BCF STATUS, RP0
				BCF STATUS, RP1
		endm

bank1 macro		;Seleciona Banco 1 da Memoria
				BSF STATUS, RP0
				BCF STATUS, RP1
		endm

bank2 macro		;Seleciona Banco 2 da Memoria
				BCF STATUS, RP0
				BSF STATUS, RP1
		endm

bank3 macro		;Seleciona Banco 3 da Memoria
				BSF STATUS, RP0
				BSF STATUS, RP1
		endm

;========================================================================================

MOV32L macro Address,imm32
		BANKSEL Address ;Address specifies the LSB start
	 	movlw Address 	;Use FSR and INDF for indirect
	 	movwf FSR

    	movlw imm32 >>D'00' & H'FF'
		movwf INDF 
    
    	incf FSR,F ;Point to next byte
    	movlw imm32 >>D'08' & H'FF'
 		movwf INDF
    
		incf FSR,F ;Point to next byte
    	movlw imm32 >>D'16' & H'FF'
 		movwf INDF

    	incf FSR,F ;Point to next byte
    	movlw imm32 >>D'24' & H'FF'
 		movwf INDF
    
	endm
	
;----------	Definicao de Saidas e entradas ------------------
#define	RS			PORTE,0
#define EN 			PORTE,1
#define	DADOS		PORTD
;#define BOTAO1		PORTB,0
;#define BOTAO2		PORTB,1
;---------- entradas para leitura das linhas do teclado ----------

#define 	LINHA0 PORTB, RB1 ;linha 0 do teclado
#define 	LINHA1 PORTB, RB2 ;linha 1 do teclado
#define 	LINHA2 PORTB, RB3 ;linha 2 do teclado
#define 	LINHA3 PORTB, RB4 ;linha 3 do teclado

;---------- saidas para as colunas do teclado ----------

#define 	COLUNA0 PORTC, RC4 ;coluna 0 do teclado
#define 	COLUNA1 PORTC, RC5 ;coluna 1 do teclado
#define 	COLUNA2 PORTC, RC6 ;coluna 2 do teclado
#define 	COLUNA3 PORTC, RC7 ;coluna 3 do teclado
	
;========================================================================================
; --- Registradores de Uso Geral ---
	cblock		H'20'						;Início da memória disponível para o usuário
	
	ANVAL									;valor analógico da entrada AN0
	CNT0									;contadores auxiliares para a conversão A/D
	CNT1
	DADO
	DELAY0
	DELAY1
	DELAY2
	DELAY3
	ADVAL

	;variaveis EEPROM
	RESULTADO_LEITURA
	ADDRESS
	VALUE


	REG1H									;byte alto registrador 1 de 16 bits utilizado na rotina de divisão
	REG1L									;byte baixo registrador 1 de 16 bits utilizado na rotina de divisão
	REG2H									;byte alto registrador 2 de 16 bits utilizado na rotina de divisão
	REG2L									;byte baixo registrador 2 de 16 bits utilizado na rotina de divisão
	REG3H									;byte alto registrador 3 de 16 bits utilizado na rotina de divisão
	REG3L									;byte baixo registrador 3 de 16 bits utilizado na rotina de divisão
	REG4H									;byte alto registrador 4 de 16 bits utilizado na rotina de divisão
	REG4L									;byte baixo registrador 4 de 16 bits utilizado na rotina de divisão
	AUX_H									;byte baixo de registrador de 16 bits para retornar valor da div
	AUX_L									;byte baixo de registrador de 16 bits para retornar valor da div
	AUX_TEMP								;contador temporário usado na rotina de divisão
	REG_MULT1								;registrador 1 para multiplicação
	REG_MULT2								;registrador 2 para multiplicação
	UNIDADE									;armazena unidade
	DEZ_A									;armazena unidade da dezena
	DEZ_B									;armazena dezena
	UNI										;Armazena unidade
	DEZ										;Armazena dezena
	CEN										;Armazena centena
	REG_AUX									;Registrador auxiliar para uso na conversão bin/dec
	cmd										;Registrador para comandos do LCD
	DISP									;Registrador a ser exibido no display

	;variáveis para recuperação de contexto para interrupção
	STATUS_TEMP
	W_TEMP

	RESET_									;variavel para saber se é pra resetar, ela é setada na interrupção

	endc									;Final da memória do usuário

;========================================================================================
; --- Vetor de RESET ---
	org			H'0000'						;Origem no endereço 00h de memória
	goto		inicio						;Desvia para a label início
	
;========================================================================================
; --- Vetor de Interrupção ---
	org			H'0004'						;As interrupções deste processador apontam para este endereço
	movwf		W_TEMP
	swapf		STATUS,W
	clrf		STATUS
	movwf		STATUS_TEMP

	btfss		INTCON,INTF
	goto		RECUPERA_CONTEXTO
	bcf			INTCON,INTF			;Limpa flag para a proxima interrupção

RECUPERA_CONTEXTO:
	swapf		STATUS_TEMP,W
	movf		STATUS,W		
	swapf		W_TEMP,F
	swapf		W_TEMP,W

	bsf			RESET_,0
	retfie

;========================================================================================	
; --- Principal ---
inicio:
	
	bank1									;seleciona o banco 1 de memória
	movlw		H'00'						;move literal 00h para Work
	movwf		TRISD						;configura todo PORTD como saída (barramento de dados LCD)
	movlw		H'00'						;move literal 00h para Work
	movwf		TRISC


	bsf			PORTA,RA3					;configura RA3 como entrada (entrada A/D)
	
	bsf			PORTB,RB0					;configura RB0 como entrada (LINHAS TECLADO)
	bsf			PORTB,RB1					;configura RB1 como entrada (LINHAS TECLADO)
	bsf			PORTB,RB2					;configura RB2 como entrada (LINHAS TECLADO)
	bsf			PORTB,RB3					;configura RB3 como entrada (LINHAS TECLADO)
	
	bcf			PORTE,RE0					;configura RE0 como saída (pino RS LCD)
	bcf			PORTE,RE1					;configura RE1 como saída (pino EN LCD)
	
	bank0
	call		ADC_INIT					;sub rotina de inicialização do conversor A/D
	call		LCD_INIT					;sub rotina de inicialização da tela LCD

	bsf			INTCON,PEIE					;Habilita interrupções de perifericos
	bsf			INTCON,GIE					;Habilita interrupções globais
	bsf			INTCON,INTE					;Habilita interrupções pelo RB0

MANUAL_RESET:								;reset causado pela interrupção (botao RB0)
	bcf			RESET_,0
	movlw		0x10
	movwf		ADDRESS


	call 		CLEAR

	call 		LEITURA_EEPROM				;reseta e retorna para a mesma frequencia que estava sendo usada

	btfsc		RESULTADO_LEITURA, 0
	goto 		F5LOOP

	btfsc		RESULTADO_LEITURA, 1
	goto 		F10LOOP
	
 	btfsc		RESULTADO_LEITURA, 2
	goto 		F20LOOP
	
	
	
;========================================================================================	
MENU:					;modo1 é a seleção da frequencia do PWM
	bcf			T2CON, 2					;desliga a geração do sinal PWM
	bcf 		COLUNA0
	bcf 		COLUNA1
	bcf 		COLUNA2
	bcf 		COLUNA3
	
	

	call		CLEAR

	bsf 		COLUNA1		
	btfsc 		LINHA0  	;verifica se o botao da 1 esta nivel logico 1
    goto 		F5KHZ		;se estiver = 1, vai para a rotina F5KHZ

	bsf 		COLUNA2		
	btfsc 		LINHA0  	;verifica se o botao da 1 esta nivel logico 2
    goto 		F10KHZ		;se estiver = 1, vai para a rotina F10KHZ					

	bsf 		COLUNA3		
	btfsc 		LINHA0  	;verifica se o botao da 1 esta nivel logico 3
    goto 		F20KHZ		;se estiver = 1, vai para a rotina F20KHZ

	call		TEXTOMENU
	
	btfsc		RESET_,0
	goto		MANUAL_RESET

	goto 		MENU

TEXTOMENU:
	movlw	'F'
	movwf	DADO
	call	LCD_ESCRITA
	movlw	'R'
	movwf	DADO
	call	LCD_ESCRITA
	movlw	'E'
	movwf	DADO
	call	LCD_ESCRITA
	movlw	'Q'
	movwf	DADO
	call	LCD_ESCRITA
	movlw	'U'
	movwf	DADO
	call	LCD_ESCRITA
	movlw	'E'
	movwf	DADO
	call	LCD_ESCRITA
	movlw	'N'
	movwf	DADO
	call	LCD_ESCRITA
	movlw	'C'
	movwf	DADO
	call	LCD_ESCRITA
	movlw	'I'
	movwf	DADO
	call	LCD_ESCRITA
	movlw	'A'
	movwf	DADO
	call	LCD_ESCRITA
	movlw	' '
	movwf	DADO
	call	LCD_ESCRITA
	movlw	'('
	movwf	DADO
	call	LCD_ESCRITA
	movlw	'H'
	movwf	DADO
	call	LCD_ESCRITA
	movlw	'z'
	movwf	DADO
	call	LCD_ESCRITA
	movlw	')'
	movwf	DADO
	call	LCD_ESCRITA

	movlw	0xC0		;comando para pular para a segunda linha
	movwf	DADO
	call	LCD_CMD		;Escreve comando configurar a escrita

	movlw	'1'
	movwf	DADO
	call	LCD_ESCRITA
	movlw	'-'
	movwf	DADO
	call	LCD_ESCRITA
	movlw	'5'
	movwf	DADO
	call	LCD_ESCRITA
	movlw	'k'
	movwf	DADO
	call	LCD_ESCRITA
	movlw	' '
	movwf	DADO
	call	LCD_ESCRITA	

	
	movlw	'2'
	movwf	DADO
	call	LCD_ESCRITA
	movlw	'-'
	movwf	DADO
	call	LCD_ESCRITA
	movlw	'1'
	movwf	DADO
	call	LCD_ESCRITA
	movlw	'0'
	movwf	DADO
	call	LCD_ESCRITA
	movlw	'k'
	movwf	DADO
	call	LCD_ESCRITA
	movlw	' '
	movwf	DADO
	call	LCD_ESCRITA	
	
	movlw	'3'
	movwf	DADO
	call	LCD_ESCRITA
	movlw	'-'
	movwf	DADO
	call	LCD_ESCRITA
	movlw	'2'
	movwf	DADO
	call	LCD_ESCRITA
	movlw	'0'
	movwf	DADO
	call	LCD_ESCRITA
	movlw	'k'
	movwf	DADO
	call	LCD_ESCRITA

	MOV32L  DELAY0, 2800 ;Delay 1,53ms
	call	Delay
	return
; --- Sub Rotinas do PWM ---
; para definir o valor de PR2 no PWM:
;PR2 = f_osc/(f_pwm*4*TMR2PRE) - 1
;f_osc = 20MHz		f_pwm será 5KHz, 10KHz ou 20KHz
;TMR2PRE = prescaler 1:1
F20KHZ:
	movlw		0x04
	movwf		VALUE
	call 		ESCRITA_EEPROM
	
F20LOOP:
	call		ADC_READ					;chama sub rotina para ler ADC

	bank1
	movlw		D'249'						;seta para variar o duty cycle de 0 a 1023 e assim,
	movwf		PR2							;controla o periodo do PWM
	bank0
	movf		ADRESH,w
	movwf		ADVAL

	bsf			CCP1CON,2					;b0000 11xx seleciona modo PWM
	bsf			CCP1CON,3

	bsf 		CCP1CON,5					;2 bits menos significativos do duty cycle do PWM
	bsf 		CCP1CON,4

	movf		ADVAL,w						;passa os bits 8 bits mais significativos para
	movwf		CCPR1L						;os 8 bits mais significativos do duty cycle do PWM

	bsf			T2CON, 2					;inicia o timer para geracao do PWM

	call 		CLEAR
	call 		TELA						;printa no LCD o valor da leitura
	;CCPR1L e CCP1CON<5:4> ficarão, para duty cycle máximo quando:
	;1111 1111 11
	;ou seja, usa os 8 bits do CCPR1H e os bits 5 e 4
	;do CCP1CON para fechar os 10 bits do PWM

	bsf 		COLUNA0		
	btfsc 		LINHA0  	;verifica se o botao da 1 esta nivel logico 0
    goto 		MENU		;se estiver = 1, para de gerar o PWM
	
	btfsc		RESET_,0
	goto		MANUAL_RESET

	goto 		F20LOOP

F10KHZ:
	movlw		0x02
	movwf		VALUE
	call 		ESCRITA_EEPROM
	
F10LOOP:
	call		ADC_READ					;chama sub rotina para ler ADC
	
	bank1
	movlw		D'449'						;seta para variar o duty cycle de 0 a 1023 e assim,
	movwf		PR2							;controla o periodo do PWM
	bank0
	movf		ADRESH,w
	movwf		ADVAL

	bsf			CCP1CON,2					;b0000 11xx seleciona modo PWM
	bsf			CCP1CON,3

	bsf 		CCP1CON,5					;2 bits menos significativos do duty cycle do PWM
	bsf 		CCP1CON,4

	movf		ADVAL,w						;passa os bits 8 bits mais significativos para
	movwf		CCPR1L						;os 8 bits mais significativos do duty cycle do PWM

	bsf			T2CON, 2					;inicia o timer para geracao do PWM

	call 		CLEAR
	call 		TELA						;printa no LCD o valor da leitura
	;CCPR1L e CCP1CON<5:4> ficarão, para duty cycle máximo quando:
	;1111 1111 11
	;ou seja, usa os 8 bits do CCPR1H e os bits 5 e 4
	;do CCP1CON para fechar os 10 bits do PWM

	bsf 		COLUNA0		
	btfsc 		LINHA0  	;verifica se o botao da 1 esta nivel logico 0
    goto 		MENU		;se estiver = 1, para de gerar o PWM

	btfsc		RESET_,0
	goto		MANUAL_RESET

	goto 	F10LOOP

F5KHZ:
	movlw		0x01
	movwf		VALUE
	call 		ESCRITA_EEPROM
	
F5LOOP:
	call		ADC_READ					;chama sub rotina para ler ADC
	
	bank1
	movlw		D'999'						;seta para variar o duty cycle de 0 a 1023 e assim,
	movwf		PR2							;controla o periodo do PWM
	bank0
	movf		ADRESH,w
	movwf		ADVAL

	bsf			CCP1CON,2					;b0000 11xx seleciona modo PWM
	bsf			CCP1CON,3

	bsf 		CCP1CON,5					;2 bits menos significativos do duty cycle do PWM
	bsf 		CCP1CON,4

	movf		ADVAL,w						;passa os bits 8 bits mais significativos para
	movwf		CCPR1L						;os 8 bits mais significativos do duty cycle do PWM

	bsf			T2CON, 2					;inicia o timer para geracao do PWM

	call 		CLEAR
	call 		TELA						;printa no LCD o valor da leitura
	;CCPR1L e CCP1CON<5:4> ficarão, para duty cycle máximo quando:
	;1111 1111 11
	;ou seja, usa os 8 bits do CCPR1H e os bits 5 e 4
	;do CCP1CON para fechar os 10 bits do PWM

	bsf 	COLUNA0		
	btfsc 	LINHA0  	;verifica se o botao da 1 esta nivel logico 0
    goto 	MENU		;se estiver = 1, para de gerar o PWM

	btfsc		RESET_,0
	goto		MANUAL_RESET

	goto F5LOOP

;========================================================================================
; --- EEPROM ---
ESCRITA_EEPROM:

	bank3
	BTFSC	EECON1, WR		;espera finalizar a escrita
	GOTO	$-1

	bank0
	MOVF	ADDRESS,	W	;endereço da escrita

	bank2
	MOVWF	EEADR

	bank0
	MOVF	VALUE,	W		;dado para a escrita
	
	bank2
	MOVWF	EEDATA

	bank3

	BCF		EECON1, EEPGD	;acesso à memoria de dados
	BSF		EECON1, WREN	;habilita a escrita
	
	BCF		INTCON, GIE		;desabilita interrupções

	
	MOVLW	0x55			;Escrita 55h na EECON2
	MOVWF	EECON2
	MOVLW	0xAA			;Escrita AAh na EECON2
	MOVWF	EECON2
	BSF		EECON1,	WR		;Começa a operação de escrita

	BSF		INTCON, GIE		;Habilita as interrupções
							;Se foram desabilitadas
	BCF		EECON1,	WREN	;Desabilita a escrita
	BCF		EECON1, WR

	bank0
	return

LEITURA_EEPROM:
	bank0
	MOVF	ADDRESS,	W	; Escreve o Endereco
	bank2
	MOVWF	EEADR			; Para fazer a leitura
	bank3
	BCF		EECON1,	EEPGD	; Aponta para memória de dados
	BSF		EECON1,	RD		; Começa a fazer a leitura
	bank2
	MOVF	EEDATA, W		; W = EEDATA
	;DICA:	Lembrar de retornar ao banco 0;
	
	bank3
	BCF		EECON1, RD		; Desabilita a leitura
	
	bank0
	MOVWF	RESULTADO_LEITURA
	return

;========================================================================================
; --- Sub Rotinas do ADC ---
ADC_INIT
	bank1									;seleciona o banco1 de memória
	movlw		H'00'						;move literal 00h para Work 0000 0000b
	movwf		ADCON1						;Resultado A/D justificado à esquerda, AN-AN7 entradas analógicas

	bank0									;seleciona o banco0 de memória
	movlw		H'D9'						;move literal D9h para Work 1101 1001b
	movwf		ADCON0						;FRC, CH03 (RA3/AN3), A/D converter ON

	movlw		H'00'						;seta o prescaler 1:1
	movwf		T2CON

	return

ADC_READ:

	bsf			ADCON0,2 					;conversão A/D em progresso
	
wait:										;aguarda até a leitura terminar: bit 2 de ADCON0 = 0
	btfsc		ADCON0,2
	goto		wait

	movf		ADRESH,W					;Sim. Move conteúdo de ADRESH em Work
	movwf		REG_MULT1					;move conteúdo de Work para REG_MULT1
	movlw		D'100'						;move literal 250 para Work
	movwf		REG_MULT2					;carrega 250 em REG_MULT2
	call		multip						;chama sub rotina para multiplicação
	movf		AUX_H,W						;move conteúdo de AUX_H para Work
	movwf		REG2H						;armazena resultado da multiplicação
	movf		AUX_L,W						;move conteúdo de AUX_L para Work
	movwf		REG2L						;armazena resultado da multiplicação
	clrf		REG1H						;limpa REG1H
	movlw		D'255'						;move 255 para WOrk
	movwf		REG1L						;armazena 255 em REG1L
	call		divid						;chama sub rotina para divisão
	movf		REG2L,W						;move conteúdo de REG2L para Work
	
	call		conv_binToDec				;chama sub rotina para ajuste decimal
	movlw		H'88' 						;posiciona cursor na linha 2, coluna 6
	call		LCD_CMD						;envia comando para LCD
	movf		CEN,W						;move conteúdo de CEN para work
	addlw		H'30'						;soma com 30h (ASCII)
	movf		DEZ,W						;move conteúdo de DEZ para work
	addlw		H'30'						;soma com 30h (ASCII)
	movf		UNI,W						;move conteúdo de UNI para work
	addlw		H'30'						;soma com 30h (ASCII)

	return

conv_binToDec:

	movwf		REG_AUX						;salva valor a converter em REG_AUX
	clrf		UNIDADE						;limpa unidade
	clrf		DEZ							;limpa dezena
	clrf		CEN							;limpa centena

	movf		REG_AUX,F					;REG_AUX = REG_AUX
	btfsc		STATUS,Z					;valor a converter resultou em zero?
	return	

start_adj:
						
	incf		UNIDADE,F						;Não. Incrementa UNI
	movf		UNIDADE,W						;move o conteúdo de UNI para Work
	xorlw		H'0A'						;W = UNI XOR 10d
	btfss		STATUS,Z					;Resultou em 10d?
	goto		end_adj						;Não. Desvia para end_adj
						 
	clrf		UNIDADE						;Sim. Limpa registrador UNI
	movf		DEZ,W						;Move o conteúdo de DEZ para Work
	xorlw		H'09'						;W = DEZ_A XOR 9d
	btfss		STATUS,Z					;Resultou em 9d?
	goto		incDezA						;Não, valor menor que 9. Incrementa DEZ_A
	clrf		DEZ							;Sim. Limpa registrador DEZ
	incf		CEN,F						;Incrementa registrador CEN
	goto		end_adj						;Desvia para end_adj
	
incDezA:
	incf		DEZ,F						;Incrementa DEZ
	
end_adj:
	decfsz		REG_AUX,F					;Decrementa REG_AUX. Fim da conversão ?
	goto		start_adj					;Não. Continua
	return									;Sim. Retorna
mult    MACRO   bit							;Inicio da macro de multiplicação

	btfsc		REG_MULT1,bit				;bit atual de REG_MULT1 limpo?
	addwf		AUX_H,F						;Não. Acumula soma de AUX_H
	rrf			AUX_H,F						;rotaciona AUX_H para direita e armazena o resultado nele próprio
	rrf			AUX_L,F						;rotaciona AUX_L para direita e armazena o resultado nele próprio

	endm									;fim da macro


multip:

	clrf		AUX_H						;limpa AUX_H
	clrf		AUX_L						;limpa AUX_L
	movf		REG_MULT2,W					;move o conteúdo de REG_MULT2 para Work
	bcf			STATUS,C					;limpa o bit de carry

	mult    	0							;chama macro para cada um dos 7 bits
	mult    	1							;de REG_MULT1
	mult    	2							;
	mult    	3							;
	mult    	4							;
	mult    	5							;
	mult    	6							;
	mult    	7							;

	return									;retorna
divid:

	movlw		H'10'						;move 16d para Work
	movwf		AUX_TEMP					;carrega contador para divisão

	movf		REG2H,W						;move conteúdo de REG2H para Work
	movwf		REG4H						;armazena em REG4H
	movf		REG2L,W						;move conteúdo de REG2L para Work
	movwf		REG4L						;armazena em REG4L
	clrf		REG2H						;limpa REG2H
	clrf		REG2L						;limpa REG2L
	clrf		REG3H						;limpa REG3H
	clrf		REG3L						;limpa REG3L

DIV
	bcf			STATUS,C					;limpa bit de carry
	rlf			REG4L,F						;rotaciona REG4L para esquerda e armazena nele próprio
	rlf			REG4H,F						;rotaciona REG4H para esquerda e armazena nele próprio
	rlf			REG3L,F						;rotaciona REG3L para esquerda e armazena nele próprio 
	rlf			REG3H,F						;rotaciona REG3H para esquerda e armazena nele próprio 
	movf		REG1H,W						;move conteúdo de REG1H para Work
	subwf		REG3H,W						;Work = REG3H - REG1H
	btfss		STATUS,Z					;Resultado igual a zero?
	goto		NOCHK						;Não. Desvia para NOCHK
	movf		REG1L,W						;Sim. Move conteúdo de REG1L para Work
	subwf		REG3L,W						;Work = REG3L - REG1L
	 
NOCHK
	btfss		STATUS,C					;Carry setado?
	goto		NOGO						;Não. Desvia para NOGO
	movf		REG1L,W						;Sim. Move conteúdo de REG1L para Work
	subwf		REG3L,F						;Work = REG3L - REG1L
	btfss		STATUS,C					;Carry setado?
	decf		REG3H,F						;decrementa REG3H 
	movf		REG1H,W						;move conteúdo de REG1H para Work
	subwf		REG3H,F						;Work = REG3H - REG1H
	bsf			STATUS,C					;seta carry
	 
NOGO
	rlf			REG2L,F						;rotaciona REG2L para esquerda e salva nele próprio
	rlf			REG2H,F						;rotaciona REG2H para esquerda e salva nele próprio
	decfsz		AUX_TEMP,F					;decrementa AUX_TEMP. Chegou em zero?
	goto		DIV							;Não. Continua processo de divisão
	return									;Sim. Retorna

BUSY_CHECK:
	bank1				    				;Seleciona banco 1 de memória
    movlw   	H'FF'            			;move literal FFh para work
    movwf   	TRISD						;configura todo PORTB como entrada
    bank0				    				;Seleciona banco 0 de memória
    bcf     	RS    						;LCD em modo comando
    bsf     	EN    						;habilita LCD
    movf    	DADOS,W     				;le o busy flag, endereco DDram 
    bcf     	EN    						;desabilita LCD
    andlw   	H'80'						;Limpa bits não utilizados
	btfss   	STATUS, Z					;chegou em zero?
    goto    	BUSY_CHECK					;não, continua teste
    
lcdnobusy:									;sim
    ;bcf     	RW  						;LCD em modo leitura     
    bank1				    				;Seleciona banco 1 de memória
    movlw   	H'00'						;move literal 00h para work
    movwf   	TRISD						;configura todo PORTB como saída
    bank0				    				;Seleciona banco 0 de memória
    retlw   	H'00'						;retorna limpando work


;========================================================================================
; --- Sub Rotinas da tela LCD ---
TELA										;subrotina para escrita das informacoes
	bank0
	movlw	'D'
	movwf	DADO
	call	LCD_ESCRITA
	movlw	'u'
	movwf	DADO
	call	LCD_ESCRITA
	movlw	't'
	movwf	DADO
	call	LCD_ESCRITA
	movlw	'y'
	movwf	DADO
	call	LCD_ESCRITA
	movlw	' '
	movwf	DADO
	call	LCD_ESCRITA
	movlw	'c'
	movwf	DADO
	call	LCD_ESCRITA
	movlw	'y'
	movwf	DADO
	call	LCD_ESCRITA
	movlw	'c'
	movwf	DADO
	call	LCD_ESCRITA
	movlw	'l'
	movwf	DADO
	call	LCD_ESCRITA
	movlw	'e'
	movwf	DADO
	call	LCD_ESCRITA
	movlw	':'
	movwf	DADO
	call	LCD_ESCRITA

	movf	CEN,W
	addlw	H'30'
	movwf	DADO
	call	LCD_ESCRITA

	movf	DEZ,W
	addlw	H'30'
	movwf	DADO
	call	LCD_ESCRITA

	movf	UNI,W
	addlw	H'30'
	movwf	DADO
	call	LCD_ESCRITA
	
	movlw	'%'
	movwf	DADO
	call	LCD_ESCRITA

	movlw	0x0C
	movwf	DADO
	call	LCD_CMD


	MOV32L  DELAY0, 2800 ;Delay 1,53ms
	call	Delay

	return

LCD_INIT

	MOV32L  DELAY0,2800 					;Delay 1,53ms
	call	Delay

	;Function SET	Modo 8 Bits 2 Linhas 5x10 
	movlw	0x38							;0b00111000 
	movwf	DADO
	call	LCD_CMD							;Escreve comando fuction set

	;Display On/OFF Control Liga Display S/ Cursor S/ Piscar

	movlw	0x0C							;0b0000 1100
	movwf	DADO
	call	LCD_CMD							;Escreve comando Display On/Off
	
	;Display Clear

	movlw	0x01
	movwf	DADO
	call	LCD_CMD							;Escreve comando p/ limpar o display

	MOV32L  DELAY0, 250						;Delay 1,53ms
	call	Delay

	;Entry Set Mode	escreve da direita p/ esquerda deslocando o cursor

	movlw	0x06							;0b0000 0110
	movwf	DADO
	call	LCD_CMD							;Escreve comando configurar a escrita

	return


LCD_ESCRITA
		bsf 	RS							;Indica a escrita de um Dado
		movf	DADO,0						;Move da variavel dado para o WREG
		movwf	DADOS						;Seta o PORTD a partir do WREG
		call	ENABLE						;Pulso de enable
		MOV32L  DELAY0, 7
		call	Delay
	return
LCD_CMD
		bcf 	RS							;Indica a escrita de uma instrução
		movf	DADO,0						;Move da variavel dado para o WREG
		movwf	DADOS						;Seta o PORTD a partir do WREG
		call	ENABLE						;Pulso de enable
		MOV32L  DELAY0, 7
		call	Delay
	return
ENABLE
		bsf	EN								;Pulso no pino de Enable
		bcf	EN
	return

CLEAR
	movlw	0x01							;comando pra dar clear 0b00000001 
	movwf	DADO
	call	LCD_CMD							;Escreve comando fuction set
	return

;========================================================================================
; --- Delay ---
Delay
    	banksel	DELAY0
		incf 	DELAY0
		incf 	DELAY1
		incf 	DELAY2
		incf 	DELAY3
	
DelayLoop

		decfsz DELAY0
		goto DelayLoop
		
		decfsz DELAY1
		goto DelayLoop
		
		decfsz DELAY2
		goto DelayLoop
		
		decfsz DELAY3
		goto DelayLoop
    
	return

	end