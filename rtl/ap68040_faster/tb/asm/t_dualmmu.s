; AP68040: dual issue with translation on.  On the Minimig a floppy that
; leaves the MMU alone booted the dual-issue core and the hard disk (SetPatch
; and 68040.library: translation, the ROM remapped) did not.  Each case maps
; a page somewhere else, so an access that skips translation reads other
; data (or runs other code) and fails.
; assembled with vasmm68k_mot -Fbin -m68040
;
;   page  $B ($B000) -> physical $C000 (data)
;   page  $7 ($7000) -> physical $6000 (code: physical $7000 is ILLEGALs)
;
;   1    companion loads (MOVE.L (Ay),Dx beside an ADDQ to a data register)
;        from the remapped page, 20 passes of 64: the physical $C000 data
;   2    the same loop run from the remapped code page
;   3    the companion load's first touch of a page (an ATC miss under the
;        pair): PFLUSHA before every pass
;   4    MOVEA and ADDQ #q,An companions (second-slot address arithmetic)
;        walking the remapped page
;   5    four lines in one data-cache set and their pages in one ATC set
;        ($06800, $16800, $26800, $36800): four cache ways hit through
;        four ATC ways, each line read back twice
;   6    a long across two such lines in each page: the second part's
;        lookup by the engine through that page's ATC way

FAILREG	equ	$F100
DONEREG	equ	$F102

failt	macro
	move.w	#\1,d7
	bra	fail_all
	endm

	org	0
	dc.l	$3400
	dc.l	start
	rept	62
	dc.l	unexp
	endr

	org	$400
start:
	; page table: 64 identity pages, two remapped
	lea	($4400).l,a0
	moveq	#0,d0
	moveq	#63,d1
.t:	move.l	d0,d2
	lsl.l	#8,d2
	lsl.l	#4,d2
	addq.l	#3,d2
	move.l	d2,(a0)+
	addq.l	#1,d0
	dbra	d1,.t
	move.l	#$0000C003,($442C).l	; page $B -> $C000
	move.l	#$00006003,($441C).l	; page $7 -> $6000
	move.l	#$00004203,($4000).l
	move.l	#$00004403,($4200).l
	; the data: $C0000000 + i at physical $C000, $B0000000 + i at $B000
	lea	($C000).l,a0
	lea	($B000).l,a1
	moveq	#0,d0
	moveq	#63,d1
.d:	move.l	d0,d2
	add.l	#$C0000000,d2
	move.l	d2,(a0)+
	move.l	d0,d2
	add.l	#$B0000000,d2
	move.l	d2,(a1)+
	addq.l	#1,d0
	dbra	d1,.d
	; the code page: the routine at physical $6000, ILLEGALs at $7000
	lea	rout(pc),a0
	lea	($6000).l,a1
	move.w	#(route-rout)/2-1,d1
.c:	move.w	(a0)+,(a1)+
	dbra	d1,.c
	lea	($7000).l,a1
	move.w	#255,d1
.i:	move.w	#$4AFC,(a1)+
	dbra	d1,.i
	move.l	#$4000,d0
	movec	d0,urp
	movec	d0,srp
	move.l	#$80008000,d0
	movec	d0,cacr
	cpusha	bc
	move.l	#$8000,d0		; E, 4K pages
	movec	d0,tc
	pflusha

;------------------------------------------------ 1 companion loads
	moveq	#19,d5
.p1:	bsr	body
	tst.l	d7
	beq.s	.k1
	failt	1
.k1:	dbra	d5,.p1

;------------------------------------------------ 2 from the remapped code page
	moveq	#19,d5
.p2:	jsr	($7000).l
	tst.l	d7
	beq.s	.k2
	failt	2
.k2:	dbra	d5,.p2

;------------------------------------------------ 3 an ATC miss under the pair
	moveq	#19,d5
.p3:	pflusha
	bsr	body
	tst.l	d7
	beq.s	.k3
	failt	3
.k3:	dbra	d5,.p3

;------------------------------------------------ 4 address arithmetic
	moveq	#19,d5
.p4:	lea	($B000).l,a0
	moveq	#62,d4
	moveq	#0,d6
.l4:	movea.l	a0,a1			; companion: MOVEA Ay,Ax
	addq.l	#1,d6
	addq.l	#4,a0			; companion: ADDQ #4,An
	move.l	(a1),d3
	move.l	d6,d2
	subq.l	#1,d2
	add.l	#$C0000000,d2
	cmp.l	d2,d3
	beq.s	.n4
	failt	4
.n4:	dbra	d4,.l4
	dbra	d5,.p4

;------------------------------------------------ 5 four ways through four ATC ways
	move.l	#$D0D0D001,($06800).l
	move.l	#$D0D0D002,($16800).l
	move.l	#$D0D0D003,($26800).l
	move.l	#$D0D0D004,($36800).l
	moveq	#1,d5
.p5:	cmp.l	#$D0D0D001,($06800).l
	bne.s	.f5
	cmp.l	#$D0D0D002,($16800).l
	bne.s	.f5
	cmp.l	#$D0D0D003,($26800).l
	bne.s	.f5
	cmp.l	#$D0D0D004,($36800).l
	bne.s	.f5
	dbra	d5,.p5
	bra.s	.k5
.f5:	failt	5
.k5:
	; a long across the two lines of each page: its second part is the
	; engine's lookup (E_SP_2) through that page's ATC way
	move.l	#$11223345,($0680C).l
	move.l	#$55667788,($06810).l
	move.l	#$11223346,($1680C).l
	move.l	#$55667789,($16810).l
	move.l	#$11223347,($2680C).l
	move.l	#$5566778A,($26810).l
	move.l	#$11223348,($3680C).l
	move.l	#$5566778B,($36810).l
	move.l	($0680C).l,d0
	move.l	($06810).l,d0
	move.l	($1680C).l,d0
	move.l	($16810).l,d0
	move.l	($2680C).l,d0
	move.l	($26810).l,d0
	move.l	($3680C).l,d0
	move.l	($36810).l,d0
	cmp.l	#$33455566,($0680E).l
	bne.s	.f6
	cmp.l	#$33465566,($1680E).l
	bne.s	.f6
	cmp.l	#$33475566,($2680E).l
	bne.s	.f6
	cmp.l	#$33485566,($3680E).l
	bne.s	.f6
	bra.s	.k6
.f6:	failt	6
.k6:

	move.w	#$600D,(DONEREG).l
	bra.s	*

fail_all:
	move.w	d7,(FAILREG).l
	move.w	#$BAD0,(DONEREG).l
	bra.s	*

unexp:
	failt	99

; 64 companion loads from logical $B000: D7 = 0 when every one read the
; physical $C000 data
body:	lea	($B000).l,a1
	moveq	#63,d4
	moveq	#0,d6
	moveq	#0,d7
.l:	addq.l	#1,d6			; first slot: no memory access
	move.l	(a1),d3			; companion: load from (Ay)
	move.l	d6,d2
	subq.l	#1,d2
	add.l	#$C0000000,d2
	cmp.l	d2,d3
	beq.s	.n
	moveq	#1,d7
.n:	addq.l	#4,a1
	dbra	d4,.l
	rts

; the same, position independent, copied to physical $6000 (run at $7000)
rout:	lea	($B000).l,a1
	moveq	#63,d4
	moveq	#0,d6
	moveq	#0,d7
.l:	addq.l	#1,d6
	move.l	(a1),d3
	move.l	d6,d2
	subq.l	#1,d2
	add.l	#$C0000000,d2
	cmp.l	d2,d3
	beq.s	.n
	moveq	#1,d7
.n:	addq.l	#4,a1
	dbra	d4,.l
	rts
route:
