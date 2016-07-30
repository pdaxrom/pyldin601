MON	equ	$f000
GETCHAR	equ	$f003
PUTCHAR	equ	$f006
PUTS	equ	$f009
PUTH	equ	$f00c

	org $100

	ldx	#hello
	jsr	PUTS

	ldaa	#4
	ldab	#13
	mul
	std	$80
	ldaa	$80
	jsr	PUTH
	ldaa	$81
	jsr	PUTH

	jmp	MON

hello	db	$0a, $0d, 'Hello World!!!', $0a, $0d, 0

