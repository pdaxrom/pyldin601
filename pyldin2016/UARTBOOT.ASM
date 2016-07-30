REG_RMCR    equ $10     ;RATE AND MODE CONTROL REGISTER
REG_TRCSR   equ $11     ;TXD/RXD CONTROL AND STATUS REG.
REG_RDR     equ $12     ;RECEIVE DATA REGISTER
REG_TDR     equ $13     ;TRANSMIT DATA REGISTER

VTRAP	equ	$f0
VSCI	equ	$f2
VTOF	equ	$f4
VOCF	equ	$f6
VICF	equ	$f8
VIRQ	equ	$fa
VSWI	equ	$fc
VNMI	equ	$fe

	org	$e000

	ds	$f000-*, $ff

reset	jmp	start
	jmp	uartin
	jmp	uartout
	jmp	puts
	jmp	puthex

start
	sei

	lds	#$ef

	ldx	#vstub_trap
	stx	VTRAP
	ldx	#vstub_sci
	stx	VSCI
	ldx	#vstub_tof
	stx	VTOF
	ldx	#vstub_ocf
	stx	VOCF
	ldx	#vstub_icf
	stx	VICF
	ldx	#vstub_irq
	stx	VIRQ
	ldx	#vstub_swi
	stx	VSWI
	ldx	#vstub_nmi
	stx	VNMI

	ldaa	#$ff
	staa	$0
	ldaa	#$f0
	staa	$2

	bsr	uartinit

	ldx	#text
	jsr	puts

loop
;;	ldaa	#'#'
;;	jsr	uartout
	jsr	uartin
	cmpa	#'W'
	beq	memwrite
	cmpa	#'R'
	beq	memread
	cmpa	#'G'
	beq	memgo
	cmpa	#'S'
	beq	cmdgo
	ldaa	#'E'
	bsr	uartout
	bra	loop
stop
	bra	stop

memwrite
	bsr	getmem
	ldx	$80
memw1	bsr	uartin
	staa	0,x
	inx
	cpx	$82
	bne	memw1
	ldaa	#'O'
	bsr	uartout
	bra	loop

memread
	bsr	getmem
	ldx	$80
memr1	ldaa	0,x
	bsr	uartout
	inx
	cpx	$82
	bne	memr1
	ldaa	#'O'
	bsr	uartout
	bra	loop

memgo
	bsr	uartin
	staa	$80
	bsr	uartin
	staa	$81
	ldaa	#'O'
	bsr	uartout

	ldx	#taddr1
	bsr	puts

	ldaa	$80
	bsr	puthex
	ldaa	$81
	bsr	puthex


	ldx	$80
	jmp	0,x

cmdgo
	ldaa	#'O'
	bsr	uartout
	jmp	$100

getmem
	bsr	uartin
	staa	$80
	bsr	uartin
	staa	$81
	bsr	uartin
	staa	$82
	bsr	uartin
	staa	$83
	rts

;-------
uartinit	proc
        ldaa  #$04		;ENABLE INTERNAL UART, INTERNAL CLOCK, 115200 BAUD
	staa  REG_RMCR
	ldaa  #$0A		;ENABLE RECIEVE AND TRANSMITT DATA
	staa  REG_TRCSR
	ldaa  REG_RDR		;FLUSH BUFFER AND CLEAR ERROR FLAGS
	rts
	endp

uartout	proc
	pshb
uartou1	ldab	REG_TRCSR	;Get Status Reg 
	aslb			;TDRE->C
	aslb
	aslb
	bcc	uartou1		;READY FOR NEXT CHARACTER
	staa	REG_TDR
	pulb
        rts
	endp

uartin	proc
	ldaa	REG_TRCSR
	anda	#$C0		;FILTER OUT RDRF AND ORFE
	cmpa	#$00
	beq	uartin		;WAIT FOR CHARACTER
	cmpa	#$40
	beq	uartin1		;CHECK FOR FRAMING ERROR
	ldaa	REG_RDR         ;READ RECIEVED CHARACTER
	rts
uartin1	ldaa	REG_RDR		;ON ERROR, FLUSH BUFFER AND CLEAR ERROR FLAG
	bra	uartin
	endp

puts	proc
	psha
puts1	ldaa	0,x
	cmpa	#0
	beq	puts2
	bsr	uartout
	inx
	bra	puts1
puts2	pula
	rts
	endp

;---

;;************************************************************************
;; OUTHEX
;; Output A as 2 HEX digits
;;************************************************************************
puthex  proc
        pshb            ;Save B
        tab             ;Save A in B 
        bsr   OUTNIBH   ;Print High 4 bits
        tba             ;Get A from B 
        bsr   OUTNIBL   ;Print Low 4 Bits
        pulb            ;Restore B
        rts
OUTNIBH lsra          ;OUT HEX LEFT HEX DIGIT
        lsra
        lsra
        lsra
OUTNIBL anda  #$0F     ;OUT HEX RIGHT HEX DIGIT
        oraa  #$30
        cmpa  #$39
        bls   OUTNIBX
        adda  #$7
OUTNIBX bsr   uartout
        rts
	endp

;----

vstub_trap proc
	ldx	#vectextTRAP
	bsr	puts
	rti
	endp

vstub_sci proc
	ldx	#vectextSCI
	bsr	puts
	rti
	endp

vstub_tof proc
	ldx	#vectextTOF
	bsr	puts
	rti
	endp

vstub_ocf proc
	ldx	#vectextOCF
	bsr	puts
	rti
	endp

vstub_icf proc
	ldx	#vectextICF
	bsr	puts
	rti
	endp

vstub_irq proc
	ldx	#vectextIRQ
	bsr	puts
	rti
	endp

vstub_swi proc
	ldx	#vectextSWI
	bsr	puts
	rti
	endp

vstub_nmi proc
	ldx	#vectextNMI
	bsr	puts
	rti
	endp

;----
vec_trap proc
	ldx	VTRAP
	jmp	0,x
	endp

vec_sci proc
	ldx	VSCI
	jmp	0,x
	endp

vec_tof	proc
	ldx	VTOF
	jmp	0,x
	endp

vec_ocf	proc
	ldx	VOCF
	jmp	0,x
	endp

vec_icf	proc
	ldx	VICF
	jmp	0,x
	endp

vec_irq	proc
	ldx	VIRQ
	jmp	0,x
	endp

vec_swi	proc
	ldx	VSWI
	jmp	0,x
	endp

vec_nmi	proc
	ldx	VNMI
	jmp	0,x
	endp

text
	db	'PYLDIN 2016 (HD63B03) UART BOOTLOADER', $0a, $0d
	db	'(c) Alexander Chukov <sashz@pdaXrom.org>, 2016', $0a, $0d
	db	'http://pyldin.info', $0a, $0d, 0

vectextTRAP	db	$a,$d,'TRAP',$a,$d,0
vectextSCI	db	$a,$d,'SCI',$a,$d,0
vectextTOF	db	$a,$d,'TOF',$a,$d,0
vectextOCF	db	$a,$d,'OCF',$a,$d,0
vectextICF	db	$a,$d,'ICF',$a,$d,0
vectextIRQ	db	$a,$d,'IRQ',$a,$d,0
vectextSWI	db	$a,$d,'SWI',$a,$d,0
vectextNMI	db	$a,$d,'NMI',$a,$d,0

taddr1	db	$0a, $0d, 'START: ',0
taddr2	db	$0a, $0d, 'END:   ',0

	ds	$ffee-*, $ff
	dw	vec_trap
	dw	vec_sci
	dw	vec_tof
	dw	vec_ocf
	dw	vec_icf
	dw	vec_irq
	dw	vec_swi
	dw	vec_nmi
	dw	reset
