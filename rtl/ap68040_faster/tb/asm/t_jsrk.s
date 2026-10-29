; AP68040: JSR to a target the decoder knows (UA_JSR_K), and words that
; look like one.  The decoder changes a fast-decoded JSR (d16,PC), (xxx).W
; or (xxx).L into a single push with a redirect; the change is keyed on the
; operation word and the EA kind, from the idle phase only.  A slow-path
; instruction (a memory-indirect source: full-format extension) whose
; destination displacement reads as a JSR's operation word ($4EB8, $4EB9,
; $4EBA) must stay what it is.  Both passes: caches off, then on.
; assembled with vasmm68k_mot -Fbin -m68040
;   1-3   JSR (d16,PC), (xxx).W, (xxx).L: the routine ran, came back
;   4     a JSR in a loop, four passes
;   5-7   MOVE.L ([a0]),(d16,a1) with d16 = $4EB8 / $4EB9 / $4EBA
;   8     the return addresses on the stack were the next instructions'

FAILREG	equ	$F100
DONEREG	equ	$F102
BUF	equ	$10000

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
	rept	62
	dc.l	unexp
	endr

	org	$400
start:
	moveq	#0,d6			; pass: 0 caches off, 1 on
pass:
	; 1-3
	moveq	#0,d0
	jsr	sub1(pc)
r1:
	chkl	d0,$11,1
	moveq	#0,d0
	jsr	(sub2).w
r2:
	chkl	d0,$22,2
	moveq	#0,d0
	jsr	(sub3).l
r3:
	chkl	d0,$33,3
	; 4
	moveq	#0,d0
	moveq	#3,d1
.lp:	jsr	(sub4).l
	dbra	d1,.lp
	chkl	d0,$44*4,4
	; 5-7: the source through a pointer, the destination BUF + d16
	lea	(ptr).l,a0
	lea	(BUF).l,a1
	move.l	#$55555555,(val).l
	move.l	([a0]),($4EB8,a1)
	move.l	(BUF+$4EB8).l,d0
	chkl	d0,$55555555,5
	move.l	#$66666666,(val).l
	move.l	([a0]),($4EB9,a1)
	move.l	(BUF+$4EB9).l,d0
	chkl	d0,$66666666,6
	move.l	#$77777777,(val).l
	move.l	([a0]),($4EBA,a1)
	move.l	(BUF+$4EBA).l,d0
	chkl	d0,$77777777,7
	; 8: each routine kept the return address it got
	lea	(rets).l,a2
	move.l	(a2)+,d0
	chkl	d0,r1,8
	move.l	(a2)+,d0
	chkl	d0,r2,8
	move.l	(a2)+,d0
	chkl	d0,r3,8

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

; (the return address each of the first three saw)
sub1:	move.l	(sp),(rets).l
	moveq	#$11,d0
	rts
sub2:	move.l	(sp),(rets+4).l
	moveq	#$22,d0
	rts
sub3:	move.l	(sp),(rets+8).l
	moveq	#$33,d0
	rts
sub4:	add.l	#$44,d0
	rts

	cnop	0,4
ptr:	dc.l	val
val:	dc.l	0
rets:	dc.l	0,0,0
