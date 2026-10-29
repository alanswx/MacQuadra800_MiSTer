; AP68040: the bit operations' Z flag, every bit number.  The ALU picks
; the tested bit by the number's two widths (mod 32 for a data register,
; mod 8 for a memory byte), the size choosing last.  Both passes: caches
; off, then on.
; assembled with vasmm68k_mot -Fbin -m68040
;   1   BTST Dn,Dm: bit n of a one-hot word, n = 0..31, set and clear
;   2   BTST Dn,Dm: number n+32 (taken mod 32) on the same word
;   3   BTST #n,Dm for the high half (16..31), unrolled
;   4   BCHG/BCLR/BSET Dn,Dm: Z from the old bit, the result
;   5   BTST Dn,(a0): bit n of a byte, n = 0..15 (taken mod 8)
;   6   BSET Dn,(a0) with n = 8..15: the byte's bit n-8

FAILREG	equ	$F100
DONEREG	equ	$F102
BUF	equ	$10000

failt	macro
	move.w	#\1,d7
	bra	fail_all
	endm

; Z set (beq) or clear (bne) as expected, else fail \1
zset	macro
	beq.s	.ok\@
	failt	\1
.ok\@:
	endm
zclr	macro
	bne.s	.ok\@
	failt	\1
.ok\@:
	endm

	org	0
	dc.l	$3400
	dc.l	start
	rept	62
	dc.l	unexp
	endr

	org	$400
start:
	moveq	#0,d6			; pass: 0 caches off, 1 on
pass:
	; 1-2: d2 = 1 << n; bit n set, bit n+1 (mod 32) clear; n+32 the same
	moveq	#0,d1
.l1:	moveq	#1,d2
	lsl.l	d1,d2
	btst	d1,d2
	zclr	1
	move.l	d1,d3
	addq.l	#1,d3
	btst	d3,d2
	zset	1
	not.l	d2
	btst	d1,d2
	zset	1
	not.l	d2
	move.l	d1,d3
	add.l	#32,d3
	btst	d3,d2
	zclr	2
	addq.l	#1,d1
	cmp.l	#32,d1
	bne.s	.l1
	; 3: immediates, the high half
	move.l	#$00010000,d2
	btst	#16,d2
	zclr	3
	btst	#0,d2
	zset	3
	move.l	#$00800000,d2
	btst	#23,d2
	zclr	3
	btst	#7,d2
	zset	3
	move.l	#$80000000,d2
	btst	#31,d2
	zclr	3
	btst	#15,d2
	zset	3
	move.l	#$7FFFFFFF,d2
	btst	#31,d2
	zset	3
	btst	#30,d2
	zclr	3
	; 4: BCHG/BCLR/BSET on bit 20 and bit 29
	moveq	#20,d1
	moveq	#0,d2
	bchg	d1,d2
	zset	4
	cmp.l	#$00100000,d2
	beq.s	.c1
	failt	4
.c1:	bchg	d1,d2
	zclr	4
	tst.l	d2
	beq.s	.c2
	failt	4
.c2:	moveq	#29,d1
	bset	d1,d2
	zset	4
	bset	d1,d2
	zclr	4
	cmp.l	#$20000000,d2
	beq.s	.c3
	failt	4
.c3:	bclr	d1,d2
	zclr	4
	bclr	d1,d2
	zset	4
	tst.l	d2
	beq.s	.c4
	failt	4
.c4:
	; 5: a byte in memory, number n = 0..15 tests bit n mod 8
	lea	(BUF).l,a0
	moveq	#0,d1
.l5:	move.l	d1,d3
	and.l	#7,d3
	moveq	#1,d2
	lsl.l	d3,d2
	move.b	d2,(a0)
	btst	d1,(a0)
	zclr	5
	not.b	(a0)
	btst	d1,(a0)
	zset	5
	addq.l	#1,d1
	cmp.l	#16,d1
	bne.s	.l5
	; 6: BSET with n = 8..15 sets bit n-8 of the byte
	moveq	#8,d1
.l6:	clr.b	(a0)
	bset	d1,(a0)
	zset	6
	move.l	d1,d3
	subq.l	#8,d3
	moveq	#1,d2
	lsl.l	d3,d2
	cmp.b	(a0),d2
	beq.s	.c6
	failt	6
.c6:	addq.l	#1,d1
	cmp.l	#16,d1
	bne.s	.l6

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

unexp:
	failt	99
