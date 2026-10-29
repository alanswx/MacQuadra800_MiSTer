; AP68040: an address register AG updates -- (An)+, -(An), a memory-to-
; memory MOVE's second update, a second slot's address-register form --
; whose older writer is still in DC1 or DC2 (AG waits for every older
; writer of a register it writes: pw_q, registered a clock ahead, and EX's
; at once).  Every case checks the memory written and the register.
; assembled with vasmm68k_mot -Fbin -m68040
;   1    MOVEA.L Dn,A1 then MOVE.L D1,(A1)+
;   2    the same, -(A1)
;   3    MOVEA.L (A3),A1 (a load) then MOVE.L D1,(A1)+
;   4    MOVEA.L D0,A0 then MOVE.L (A0)+,(A1)+ (A0's is the second update)
;   5    MOVEA.L D0,A1, then MOVEQ and ADDQ.L #4,A1 (a pair's second slot)
;   6    MOVEA.L D0,A1, then LEA (4,A1),A1 and MOVE.L D1,(A1)+
;   7    a loop: A1 from D4, a store through (A1)+, D4 from A1

FAILREG	equ	$F100
DONEREG	equ	$F102
BUF	equ	$8000
PTR	equ	$8800
SRC	equ	$8900

failt	macro
	move.w	#\1,d7
	bra	fail_all
	endm

chkl	macro
	cmp.l	#\2,\1
	beq.s	.ok\@
	failt	\3
.ok\@:
	endm

	org	0
	dc.l	$3400
	dc.l	start
	rept	254
	dc.l	unexp
	endr

	org	$400
start:
	move.l	#$80008000,d0
	movec	d0,cacr
	move.l	#BUF+$40,(PTR).l
	move.l	#$CAFEF00D,(SRC).l
	lea	(PTR).l,a3

	; 1: (A1)+ behind MOVEA.L D0,A1
	move.l	#BUF,d0
	move.l	#$11111111,d1
	movea.l	d0,a1
	move.l	d1,(a1)+
	move.l	a1,d2
	chkl	d2,BUF+4,1
	move.l	(BUF).l,d2
	chkl	d2,$11111111,2

	; 2: -(A1)
	move.l	#BUF+$10,d0
	move.l	#$22222222,d1
	movea.l	d0,a1
	move.l	d1,-(a1)
	move.l	a1,d2
	chkl	d2,BUF+$0C,3
	move.l	(BUF+$0C).l,d2
	chkl	d2,$22222222,4

	; 3: (A1)+ behind a load of A1
	move.l	#$33333333,d1
	movea.l	(a3),a1
	move.l	d1,(a1)+
	move.l	a1,d2
	chkl	d2,BUF+$44,5
	move.l	(BUF+$40).l,d2
	chkl	d2,$33333333,6

	; 4: the source's (A0)+, the second update, behind MOVEA.L D0,A0
	move.l	#SRC,d0
	lea	(BUF+$20).l,a1
	movea.l	d0,a0
	move.l	(a0)+,(a1)+
	move.l	a0,d2
	chkl	d2,SRC+4,7
	move.l	a1,d2
	chkl	d2,BUF+$24,8
	move.l	(BUF+$20).l,d2
	chkl	d2,$CAFEF00D,9

	; 5: ADDQ.L #4,A1 beside a MOVEQ, behind MOVEA.L D0,A1
	move.l	#BUF+$80,d0
	movea.l	d0,a1
	moveq	#5,d3
	addq.l	#4,a1
	move.l	a1,d2
	chkl	d2,BUF+$84,10
	chkl	d3,5,11
	movea.l	d0,a1
	addq.l	#4,a1
	moveq	#6,d3
	addq.l	#4,a1
	move.l	a1,d2
	chkl	d2,BUF+$88,12

	; 6: LEA (4,A1),A1 then (A1)+
	move.l	#BUF+$90,d0
	move.l	#$66666666,d1
	movea.l	d0,a1
	lea	(4,a1),a1
	move.l	d1,(a1)+
	move.l	a1,d2
	chkl	d2,BUF+$98,13
	move.l	(BUF+$94).l,d2
	chkl	d2,$66666666,14

	; 7: a loop: BUF+$100 .. +$13C get 0..15
	move.l	#BUF+$100,d4
	moveq	#0,d5
	moveq	#15,d6
.lp:	movea.l	d4,a1
	move.l	d5,(a1)+
	move.l	a1,d4
	addq.l	#1,d5
	dbf	d6,.lp
	chkl	d4,BUF+$140,15
	lea	(BUF+$100).l,a2
	moveq	#0,d5
	moveq	#0,d6
.sum:	add.l	(a2)+,d5
	addq.l	#1,d6
	cmp.l	#16,d6
	bne.s	.sum
	chkl	d5,120,16

	move.w	#$600D,(DONEREG).l
	bra.s	*

fail_all:
	move.w	d7,(FAILREG).l
	move.w	#$BAD0,(DONEREG).l
	bra.s	*

unexp:
	failt	99
