; AP68040: a table walk that updates a descriptor whose line is dirty in
; the data cache.  The page tables sit in a copyback page; the program
; remaps pages $20 and $21 (to physical $23000 and $24000, U clear) through
; the cache, so the descriptors' line is dirty, then touches the pages: the
; walk must push the line before it reads and updates a descriptor
; (E_TW_UPD) -- without the push it reads the old mapping -- and the
; descriptor ends with U set (and M for the write).  A third page's
; descriptor is in the line pushed already.
; assembled with vasmm68k_mot -Fbin -m68040
;   1-2  page $20: the data, then the descriptor's U
;   3-4  page $21 written: the data, then U and M; 6 the physical page
;   5    page $22, its descriptor in the line pushed already

FAILREG	equ	$F100
DONEREG	equ	$F102

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
	; page table: 64 identity pages, the table page ($4000) copyback
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
	move.l	#$00004023,($4410).l	; page 4: CM = copyback
	move.l	#$00004203,($4000).l
	move.l	#$00004403,($4200).l
	move.l	#$20202020,($20000).l
	move.l	#$21212121,($21000).l
	move.l	#$22222222,($22000).l
	move.l	#$23232323,($23000).l
	move.l	#$24242424,($24000).l
	move.l	#$4000,d0
	movec	d0,urp
	movec	d0,srp
	move.l	#$80008000,d0
	movec	d0,cacr
	cpusha	bc
	move.l	#$8000,d0		; E, 4K pages
	movec	d0,tc
	pflusha

	; the descriptors of pages $20-$22 rewritten through the cache (U, M
	; clear): their line ($4480) is dirty
	move.l	#$00023003,($4480).l	; page $20 -> $23000
	move.l	#$00024003,($4484).l	; page $21 -> $24000
	move.l	#$00022003,($4488).l
	pflusha
	; 1-2: a load from page $20: the walk sets U in a dirty line
	move.l	($20000).l,d0
	chkl	d0,$23232323,1
	move.l	($4480).l,d0
	and.l	#$18,d0
	chkl	d0,$08,2		; U, not M
	; 3-4: a store to page $21: U and M
	move.l	#$21215555,($21000).l
	move.l	($21000).l,d0
	chkl	d0,$21215555,3
	moveq	#0,d0
	movec	d0,tc
	pflusha
	move.l	($24000).l,d0		; (physical: the store landed there)
	chkl	d0,$21215555,6
	move.l	#$8000,d0
	movec	d0,tc
	pflusha
	move.l	($4484).l,d0
	and.l	#$18,d0
	chkl	d0,$18,4
	; 5: page $22 by a load
	move.l	($22000).l,d0
	chkl	d0,$22222222,5

	moveq	#0,d0
	movec	d0,tc
	pflusha
	move.w	#$600D,(DONEREG).l
	bra.s	*

fail_all:
	move.w	d7,(FAILREG).l
	move.w	#$BAD0,(DONEREG).l
	bra.s	*

unexp:
	failt	99
