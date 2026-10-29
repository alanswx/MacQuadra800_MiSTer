; AP040 FPU: integer stores (FMOVE.B/W/L FPn,Dn) whose rounding carries
; the value across the format's range.  F_PACKI range checks both
; rounding candidates and the rounding mode chooses last: these rows
; round out of range (OPERR, the sign's extreme stored) and back in
; (INEX2, the rounded value), under each FPCR mode.  The expected results
; were generated with a model of the rounding (nearest-even, zero, minus,
; plus) and the range check.  Both passes: caches off, then on.
; assembled with vasmm68k_mot -Fbin -m68040
;   row: double, FPCR, size (0 b, 1 w, 2 l), result (sign extended),
;   FPSR exception byte (OPERR $2000, INEX2 $0200)
;   failure code: row * 4 + 1 (result) or + 2 (exception byte)

FAILREG	equ	$F100
DONEREG	equ	$F102

	org	0
	dc.l	$3400
	dc.l	start
	rept	254
	dc.l	unexp
	endr

	org	$400
start:
	moveq	#0,d6			; pass: 0 caches off, 1 on
pass:
	lea	rows(pc),a0
	moveq	#0,d5			; row
.lp:	fmove.d	(a0)+,fp0
	move.l	(a0)+,d1		; FPCR
	move.l	(a0)+,d2		; size
	fmove.l	d1,fpcr
	fmove.l	#0,fpsr
	moveq	#0,d0
	cmp.l	#1,d2
	beq.s	.w
	bhi.s	.l
	fmove.b	fp0,d0
	extb.l	d0
	bra.s	.st
.w:	fmove.w	fp0,d0
	ext.l	d0
	bra.s	.st
.l:	fmove.l	fp0,d0
.st:	fmove.l	fpsr,d3
	fmove.l	#0,fpcr
	and.l	#$FF00,d3
	move.l	d5,d7
	lsl.l	#2,d7
	cmp.l	(a0)+,d0
	beq.s	.r
	addq.l	#1,d7
	bra.s	fail_all
.r:	cmp.l	(a0)+,d3
	beq.s	.e
	addq.l	#2,d7
	bra.s	fail_all
.e:	addq.l	#1,d5
	cmp.l	#NROW,d5
	bne.s	.lp

	tst.l	d6
	bne.s	done
	move.l	#$80008000,d0
	movec	d0,cacr
	cpusha	bc
	moveq	#1,d6
	bra	pass
done:
	moveq	#0,d0
	movec	d0,cacr
	move.w	#$600D,(DONEREG).l
	bra.s	*

fail_all:
	move.w	d7,(FAILREG).l
	move.w	#$BAD0,(DONEREG).l
	bra.s	*

unexp:	move.w	#$FFFF,(FAILREG).l
	move.w	#$BAD0,(DONEREG).l
	bra.s	*

NROW	equ	32
	cnop	0,4
rows:
	dc.l	$405FE000,$00000000,$0,0,$0000007F,$2000	; 127.5 RN b
	dc.l	$405FA000,$00000000,$0,0,$0000007E,$200	; 126.5 RN b
	dc.l	$C0601000,$00000000,$0,0,$FFFFFF80,$200	; -128.5 RN b
	dc.l	$C0601051,$EB851EB8,$0,0,$FFFFFF80,$2000	; -128.51 RN b
	dc.l	$405FDF5C,$28F5C28F,$0,0,$0000007F,$200	; 127.49 RN b
	dc.l	$405FC000,$00000000,$0,0,$0000007F,$0	; 127.0 RN b
	dc.l	$C0600000,$00000000,$0,0,$FFFFFF80,$0	; -128.0 RN b
	dc.l	$405FF999,$9999999A,$10,0,$0000007F,$200	; 127.9 RZ b
	dc.l	$C0601CCC,$CCCCCCCD,$10,0,$FFFFFF80,$200	; -128.9 RZ b
	dc.l	$40600000,$00000000,$10,0,$0000007F,$2000	; 128.0 RZ b
	dc.l	$C0600333,$33333333,$20,0,$FFFFFF80,$2000	; -128.1 RM b
	dc.l	$405FF999,$9999999A,$20,0,$0000007F,$200	; 127.9 RM b
	dc.l	$405FC000,$00000000,$20,0,$0000007F,$0	; 127.0 RM b
	dc.l	$405FC666,$66666666,$30,0,$0000007F,$2000	; 127.1 RP b
	dc.l	$C0601CCC,$CCCCCCCD,$30,0,$FFFFFF80,$200	; -128.9 RP b
	dc.l	$405FA000,$00000000,$30,0,$0000007F,$200	; 126.5 RP b
	dc.l	$40DFFFE0,$00000000,$0,1,$00007FFF,$2000	; 32767.5 RN w
	dc.l	$C0E00010,$00000000,$0,1,$FFFF8000,$200	; -32768.5 RN w
	dc.l	$C0E00030,$00000000,$0,1,$FFFF8000,$2000	; -32769.5 RN w
	dc.l	$40DFFFC0,$A3D70A3D,$30,1,$00007FFF,$2000	; 32767.01 RP w
	dc.l	$C0E00000,$51EB851F,$20,1,$FFFF8000,$2000	; -32768.01 RM w
	dc.l	$40DFFFFF,$5C28F5C3,$10,1,$00007FFF,$200	; 32767.99 RZ w
	dc.l	$C0E0001F,$AE147AE1,$10,1,$FFFF8000,$200	; -32768.99 RZ w
	dc.l	$40DFFFA0,$00000000,$0,1,$00007FFE,$200	; 32766.5 RN w
	dc.l	$41DFFFFF,$FFE00000,$0,2,$7FFFFFFF,$2000	; 2147483647.5 RN l
	dc.l	$C1E00000,$00100000,$0,2,$80000000,$200	; -2147483648.5 RN l
	dc.l	$41DFFFFF,$FFFF5C29,$10,2,$7FFFFFFF,$200	; 2147483647.99 RZ l
	dc.l	$41DFFFFF,$FFC0A3D7,$30,2,$7FFFFFFF,$2000	; 2147483647.01 RP l
	dc.l	$C1E00000,$000051EC,$20,2,$80000000,$2000	; -2147483648.01 RM l
	dc.l	$C1DFFFFF,$FFE00000,$0,2,$80000000,$200	; -2147483647.5 RN l
	dc.l	$41DFFFFF,$FFA00000,$0,2,$7FFFFFFE,$200	; 2147483646.5 RN l
	dc.l	$C1E00000,$001FAE14,$30,2,$80000000,$200	; -2147483648.99 RP l
