#Code developed by Mario Alberto Segura Oliva
#Registros de los periféricos de entrada/salida
	.data 0xFFFF0000
KEYBOARD_CONTROL:	.space 4 
KEYBOARD_DATA: 		.space 4
SCREEN_CONTROL: 	.space 4
SCREEN_DATA:		.space 4


#Mensajes por pantalla, valores del reloj, mensajes de error
	.data 0x10000000
STRING: 			.asciiz "En un lugar de la mancha de cuyo nombre no quiero acordarme\n"
strMessagePart0:	.asciiz " [Pulsacion("
COUNTER: 			.word 0 
strMessagePart2: 	.asciiz ")= "
KEY_PRESSED:		.word 0
strMessagePart3:	.asciiz "] "
TIMER_MESSAGE:	 	.asciiz "\n\t\t\tHora Actual-> "
TIME_SEPARATOR:		.asciiz ":"
FIRST_DIGIT_HOUR:	.word 0
SECOND_DIGIT_HOUR:	.word 0
FIRST_DIGIT_MIN:	.word 0
SECOND_DIGIT_MIN:	.word 0
FIRST_DIGIT_SEC:	.word 0
SECOND_DIGIT_SEC:	.word 0
N:					.asciiz "\n"
CTRL_R:				.word 0x12
ENTER_HOURS:		.asciiz "\nIntroduzca las horas(HH):\n"
ENTER_MINS:			.asciiz "\nIntroduzca los minutos(mm):\n"
ENTER_SECONDS:		.asciiz "\nIntroduzca los segundos(ss):\n"
ERROR_INPUT_HOUR:	.asciiz "\nHora invalida, por favor\n"
SUCCEED_INPUT_HOUR:	.asciiz "\nSe ha modificado la hora con exito\n"	
USER_INPUT_HOUR:	.word 4
USER_INPUT_MIN:		.word 4
USER_INPUT_SEC:		.word 4


#Dirección que almacena la dirección de retorno al fichero exceptions
	.align 2
ADDRESS:			.space 4

	.text 0x00400000
	.globl main
main:
	mfc0 $t0, $12
	ori $t0, $t0, 1 			#Interrupciones habilitadas Registro Status
	mtc0 $t0, $12
	jal KeyboardInterruptEnable #Interrupciones de teclado habilitadas
	jal TimerInterruptEnable 	#Interrupciones de timer habilitadas
	
LoadString:
	la $s3, STRING				#Puntero a cadena
	
MainLoop:
	lb $a0, 0($s3)				#Cargar n-byte
	beqz $a0, LoadString		#comprobar fin cadena
	jal PrintCharacter			#imprimir carácter
	jal Delay					#bucle de espera
	addi $s3, $s3, 1			#avanzar el puntero
	j MainLoop					#repetir proceso
	
PrintCharacter:
	la $t0, SCREEN_CONTROL		#cargar dirección registro pantalla	control
	lw $t0, 0($t0)				#cargar registro
	andi $t0, $t0, 1			#enmáscarar bit ready
	beqz $t0, PrintCharacter	#comprobar pantalla lista
	sb $a0, SCREEN_DATA			#mostrar carácter
	jr $31						#retornar a la dirección posterior a la que ejecutó jal PrintCharacter
	
Delay:
	li $t1, 10000				#tiempo de espera
	add $t2, $0, $0				#contador de espera
	
DelayLoop:
	addi $t2, $t2, 1			#incrementar contador
	beq $t2, $t1, EndOfDelay	#comprobar fin de contador
	j DelayLoop					#repetir proceso
	
EndOfDelay:
	jr $31						#retornar a la dirección posterior a la que ejecutó jal Delay
	
KeyboardInterruptEnable:
	lw $t0, KEYBOARD_CONTROL		
	ori $t0, $t0, 2				#Escribir el bit 1 (no el 0) del registro de control del teclado a 1=>Interrupciones habilitadas
	sw $t0, KEYBOARD_CONTROL
	
	mfc0 $t0, $12
	ori $t0,$t0, 0x800			#Enmascarar status, tratar interrupciones de teclado
	mtc0 $t0, $12
	
	jr $31						#retornar llamada+4
	
TimerInterruptEnable:
	mfc0 $t0 $12
	ori $t0, $t0, 0x8000		#Enmascarar status, tratar interrupciones de timer
	mtc0 $t0 $12
	
	li $t0, 1000					#Compare a 1000
	mtc0 $t0 $11
	
	mtc0 $0 $9					#Count a 0, count se va incrementado por sí solo y pasa al compare, necesario
	jr $31						#ponerlo a 0 de nuevo para no esperar muchísimo tiempo
	
CaseInterrupt:
	sw $31, ADDRESS				#se almacena el jalr que vino del exceptions
	li $t0, 0x800				#$31 lo guardo éxitosamente posteriormente para evitar saltos incorrectos
	beq $t0, $k0, KbdInterrupt
	li $t0, 0x8000
	beq $t0, $k0, TimerInterrupt
								#Se comprueban el registro Cause con los códigos que atendemos ($k0)
EndOfInterrupt:
	lw $31, ADDRESS				#Retornamos al exceptions	
	jalr $31
	
##############################################
KbdInterrupt:
	lw $s4, CTRL_R
	lw $s3, KEYBOARD_DATA
	beq $s3, $s4, ADJUST_TIME		#Se lee la tecla pulsada, si es CTRL_R se ajusta el reloj
	
	sw $s3, KEY_PRESSED				#guardamos la tecla pulsada
	
	la $s3, strMessagePart0			#[Pulsación(
	jal PrintString

	lw $a0, COUNTER					#Se imprime el contador con el valor actual
	li $v0, 1 
	syscall
	
	addi $a0, $a0, 1				#Se incrementa y se re-escribe
	sw $a0, COUNTER

	la $s3, strMessagePart2			#)=
	jal PrintString
	
	lb $a0, KEY_PRESSED				#imprime "tecla pulsada"
	jal PrintCharacter
	
	la $s3, strMessagePart3			#]
	jal PrintString
		
	j EndOfInterrupt				#interrupción tratada con éxito!
	
PrintString:
	lb $a0, 0($s3)
	beqz $a0, EndOfPrintString		#similar al main, pero sin delay
	add $t3, $31, $0
	jal PrintCharacter
	add $31, $t3, $0
	addi $s3, $s3, 1
	j PrintString
	
EndOfPrintString:
	jr $31
	
	
###################################
TimerInterrupt:	
	la $a0, TIMER_MESSAGE			#imprime la hora actual
	li $v0, 4
	syscall
	jal FixSeconds					#se incrementan los segundos en 1 y se actualizan los registros
	jal WriteHours					#que representan la hora
	jal WriteSeparator
	jal WriteMin
	jal WriteSeparator
	jal WriteSec
	mtc0 $0 $9						#count vuelve a 0 para futuras interrupciones
	j EndOfInterrupt				#interrupción atendida con éxito
	
WriteHours:
	lw $a0, FIRST_DIGIT_HOUR		#separator son ':' y simplemente se imprimen los valores de los registros...
	li $v0, 1
	syscall
	lw $a0, SECOND_DIGIT_HOUR
	li $v0, 1
	syscall
	jr $31
	
WriteMin:
	lw $a0, FIRST_DIGIT_MIN
	li $v0, 1
	syscall
	lw $a0, SECOND_DIGIT_MIN
	li $v0, 1
	syscall
	jr $31

WriteSec:
	lw $a0, FIRST_DIGIT_SEC
	li $v0, 1
	syscall
	lw $a0, SECOND_DIGIT_SEC
	li $v0, 1
	syscall
	la $a0, N
	li $v0, 4
	syscall
	jr $31
	
WriteSeparator:
	la $a0, TIME_SEPARATOR
	li $v0, 4
	syscall
	jr $31

FixSeconds:
	lw $t0, FIRST_DIGIT_SEC					#Rutina que comprueba segundos válidos
	lw $t1, SECOND_DIGIT_SEC
	li $t2, 10
	mult $t0, $t2
	mflo $t0
	add $t0, $t0, $t1
	addi $t0, $t0, 1
	li $t3, 59
	bgt $t0, $t3, FixMinutes
	div $t0 $t2
	mflo $t0
	mfhi $t1
	sw $t0 FIRST_DIGIT_SEC
	sw $t1 SECOND_DIGIT_SEC
	jr $31
	
FixMinutes:
	sw $0 FIRST_DIGIT_SEC					#Rutina que comprueba minutos válidos
	sw $0 SECOND_DIGIT_SEC
	lw $t0, FIRST_DIGIT_MIN
	lw $t1, SECOND_DIGIT_MIN
	mult $t0, $t2
	mflo $t0
	add $t0, $t0, $t1
	addi $t0, $t0, 1
	bgt $t0, $t3, FixHours
	div $t0 $t2
	mflo $t0
	mfhi $t1
	sw $t0, FIRST_DIGIT_MIN
	sw $t1, SECOND_DIGIT_MIN
	jr $31
	
FixHours:
	sw $0 FIRST_DIGIT_MIN					#Rutina que comprueba horas válidas
	sw $0 SECOND_DIGIT_MIN
	lw $t0 FIRST_DIGIT_HOUR
	lw $t1 SECOND_DIGIT_HOUR
	mult $t0, $t2
	mflo $t0
	add $t0, $t0, $t1
	addi $t0, $t0, 1
	li $t3, 23
	bgt $t0, $t3, ResetHours
	div $t0 $t2
	mflo $t0
	mfhi $t1
	sw $t0, FIRST_DIGIT_HOUR
	sw $t1, SECOND_DIGIT_HOUR
	jr $31
	
ResetHours:
	sw $0 FIRST_DIGIT_HOUR				#En caso de 23:59:59+1 se viene aquí y se resetean las horas
	sw $0 SECOND_DIGIT_HOUR
	jr $31
	
ADJUST_TIME:
	la $a0 ENTER_HOURS				 #CTRL_R viene aquí, se imprime información al usuario
	li $v0 4						 #e introduce los datos, en caso de fallo se imprime un mensaje de error
	syscall
	
	li $v0, 5
	syscall
	
	sw $v0 USER_INPUT_HOUR
	li $t1, 23
	bgt $v0, $t1, AGAIN
	
	la $a0 ENTER_MINS
	li $v0 4
	syscall
	
	li $v0 5
	syscall
	
	sw $v0 USER_INPUT_MIN
	li $t1, 59
	bgt $v0, $t1, AGAIN
	
	la $a0 ENTER_SECONDS
	li $v0 4
	syscall

	li $v0, 5
	syscall
	sw $v0 USER_INPUT_SEC
	bgt $v0, $t1, AGAIN
	
	lw $t0, USER_INPUT_HOUR
	li $t1, 10
	div $t0, $t1
	mflo $t0
	mfhi $t1
	sw $t0 FIRST_DIGIT_HOUR
	sw $t1 SECOND_DIGIT_HOUR
	
	lw $t0, USER_INPUT_MIN
	li $t1, 10
	div $t0, $t1
	mflo $t0 
	mfhi $t1
	sw $t0, FIRST_DIGIT_MIN
	sw $t1 SECOND_DIGIT_MIN
	
	lw $t0 USER_INPUT_SEC
	li $t1, 10
	div $t0, $t1
	mflo $t0
	mfhi $t1
	sw $t0 FIRST_DIGIT_SEC
	sw $t1 SECOND_DIGIT_SEC
	
	j EndOfInterrupt
	
AGAIN:
	la $a0 ERROR_INPUT_HOUR			#Cualquier fallo reinicia la rutina de introducir hora
	li $v0 4
	syscall
	
	j ADJUST_TIME
