; AP68040: an index register that the instruction just before updated as
; its second address update (a memory-to-memory MOVE's source, upd2).
; AG takes such an index a clock after the update, from the updated value
; registered (the base keeps its direct bypass); every case reads through
; the updated register and checks the value.
; assembled with vasmm68k_mot -Fbin -m68040
;   1    MOVE.L (A0)+,(A1)+ (A0's update is the second) then (d8,A2,A0.L)
;   2    the same, index scaled *4
;   3    a word index, A0.W*2
;   4    a -(A0) source, then (d8,A2,A0.L)
;   5    A0 both base and index after the update
;   6    one and two instructions between the update and the use
;   7    a loop: 16 copies, each followed by an indexed read of the copy

FAILREG	equ	$F100
DONEREG	equ	$F102
SRC	equ	$8000
DST	equ	$8100
TBL	equ	$8800

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
	; TBL+i*4 holds $1000+i for i = 0..255
	lea	(TBL).l,a2
	moveq	#0,d1
.fill:	move.l	d1,d2
	add.l	#$1000,d2
	move.l	d2,(a2,d1.l*4)
	addq.l	#1,d1
	cmp.l	#256,d1
	bne.s	.fill
	move.l	#$11111111,(SRC).l
	move.l	#$22222222,(SRC+4).l
	move.l	#$80008000,d0
	movec	d0,cacr

	; 1: A0 = 4 after the copy (A0 was 0, a vector read): (0,A2,A0.L) =
	; TBL+4 -> $1001
	suba.l	a0,a0
	lea	(DST).l,a1
	move.l	(a0)+,(a1)+
	move.l	(0,a2,a0.l),d0
	chkl	d0,$00001001,1

	; 2: A0 = 4, *4: TBL+16 -> $1004
	suba.l	a0,a0
	lea	(DST).l,a1
	move.l	(a0)+,(a1)+
	move.l	(0,a2,a0.l*4),d0
	chkl	d0,$00001004,2

	; 3: A0 = 2 after a word copy, A0.W*2: TBL+4 -> $1001
	suba.l	a0,a0
	lea	(DST).l,a1
	move.w	(a0)+,(a1)+
	move.l	(0,a2,a0.w*2),d0
	chkl	d0,$00001001,3

	; 4: -(A0) source: A0 = 12 - 4 = 8: TBL+8 -> $1002
	move.l	#12,a0
	lea	(DST).l,a1
	move.l	-(a0),(a1)+
	move.l	(0,a2,a0.l),d0
	chkl	d0,$00001002,4

	; 5: A0 = SRC+4 as base and index: (A0,A0.L) = 2*(SRC+4)
	lea	(SRC).l,a0
	lea	(DST).l,a1
	move.l	#(SRC+4)*2,a4
	move.l	#$5A5A5A5A,(a4)
	move.l	(a0)+,(a1)+
	move.l	(0,a0,a0.l),d0
	chkl	d0,$5A5A5A5A,5

	; 6: one, then two instructions in between
	suba.l	a0,a0
	lea	(DST).l,a1
	move.l	(a0)+,(a1)+
	nop
	move.l	(0,a2,a0.l*2),d0
	chkl	d0,$00001002,6
	suba.l	a0,a0
	lea	(DST).l,a1
	move.l	(a0)+,(a1)+
	moveq	#0,d3
	moveq	#0,d4
	move.l	(0,a2,a0.l*2),d0
	chkl	d0,$00001002,7

	; 7: a copy loop, each copy followed by a read indexed by the source
	; pointer: A0 = 4, 8, ... 64 -> TBL+A0*4 = $1000+A0
	suba.l	a0,a0
	lea	(DST).l,a1
	moveq	#0,d5
	moveq	#15,d6
.lp:	move.l	(a0)+,(a1)+
	move.l	(0,a2,a0.l*4),d0
	add.l	d0,d5
	dbf	d6,.lp
	; sum of $1000+4k for k = 1..16 = 16*$1000 + 4*136 = $10220
	chkl	d5,$00010220,8

	move.w	#$600D,(DONEREG).l
	bra.s	*

fail_all:
	move.w	d7,(FAILREG).l
	move.w	#$BAD0,(DONEREG).l
	bra.s	*

unexp:
	failt	99
