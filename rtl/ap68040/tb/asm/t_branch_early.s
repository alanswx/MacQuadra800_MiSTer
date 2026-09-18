; AP040 early-redirect self test (2026-09-18)
;
; The unconditional transfers whose target the fetch queue already holds --
; BRA.W/.L, BSR.W/.L, JSR and JMP abs.W, abs.L and d16(PC) -- dispatch from
; the retire that pops them straight into their branch state and, when the
; port is free, put the target fetch out in that same cycle
; (ap040_core.v, dispatch_branch).  This program checks that the transfer,
; the return address, the stack pointer, the trace frames, the odd-target
; address error, an interrupt landing anywhere inside the redirect window,
; a rewritten displacement and a target that is already resident all
; behave exactly as the S_DECODE path did.  It passes on the pre-change
; core as well, which is the point: the change must be invisible.
;
; protocol with the testbench (as t_integer.s):
;   word write to $F100 = failing test number
;   word write to $F102 = $BAD0 on failure, $600D when all tests passed
;   word write to $F110 = request interrupt level (0 releases)
;   word write to $F148 = raise level 2 N cycles from now
;
; assembled with vasmm68k_mot -Fbin -m68040 -no-opt

FAILREG	equ	$F100
DONEREG	equ	$F102
IPLREG	equ	$F110
IPLDLY	equ	$F148

cnt_addr	equ	$3600	; address errors seen
cnt_trace	equ	$3602	; trace frames seen
cnt_int2	equ	$3604	; level-2 interrupts seen
addr_pc		equ	$3610	; last address error: stacked PC
addr_fa		equ	$3614	;   its address field
addr_sp		equ	$3618	;   A7 at handler entry
resume		equ	$361C	;   where the handler continues
int2_pc		equ	$3620	; last interrupt: stacked PC
store_word	equ	$3624
trace_log	equ	$3700	; 8 bytes per trace frame: PC, address field

; fail with test number \1
failt	macro
	move.w	#\1,d7
	bra	fail_all
	endm

; compare register \1 (long) against \2, fail with number \3
chkl	macro
	cmp.l	#\2,\1
	beq.s	ok\@
	failt	\3
ok\@:
	endm

; compare the word counter at \1 against \2, fail with number \3
chkcnt	macro
	move.w	(\1).l,d6
	cmp.w	#\2,d6
	beq.s	ok\@
	failt	\3
ok\@:
	endm

; compare trace_log entry \1 against PC label \2 and address label \3,
; fail with number \4
chktrace	macro
	move.l	(trace_log+8*\1).l,d6
	lea	\2(pc),a6
	cmpa.l	d6,a6
	beq.s	okp\@
	failt	\4
okp\@:
	move.l	(trace_log+8*\1+4).l,d6
	lea	\3(pc),a6
	cmpa.l	d6,a6
	beq.s	oka\@
	failt	\4
oka\@:
	endm

	org	0
	dc.l	$3400		; ISP
	dc.l	start
	dc.l	unexp		; 2 bus error
	dc.l	h_addr		; 3 address error
	dc.l	unexp		; 4
	dc.l	unexp		; 5
	dc.l	unexp		; 6
	dc.l	unexp		; 7
	dc.l	unexp		; 8
	dc.l	h_trace		; 9 trace
	rept	16
	dc.l	unexp		; 10-25
	endr
	dc.l	h_int2		; 26 level 2 autovector
	rept	229
	dc.l	unexp		; 27-255
	endr

	org	$400
start:
	move.l	#$80008000,d0
	movec	d0,cacr
	clr.w	(cnt_addr).l
	clr.w	(cnt_trace).l
	clr.w	(cnt_int2).l

;----------------------------------------------- A: BRA.W / BRA.L targets
	moveq	#1,d0
	bra.w	la1		; after a register producer
	failt	1
la1:	chkl	d0,1,2
	lea	(store_word).l,a0
	move.l	#$11223344,(a0)	; after a store retire
	bra.w	la2
	failt	3
la2:	move.l	(a0),d1		; after a load retire
	bra.w	la3
	failt	4
la3:	chkl	d1,$11223344,5
	lea	la4(pc),a1	; after LEA
	bra.w	la4
	failt	6
la4:	bra.w	la5		; a target that is itself a branch
	failt	7
la5:	nop			; after NOP (retires from S_DECODE)
	bra.l	la6
	failt	8
	dc.l	0
la6:	moveq	#2,d0
	bra.l	la7
	failt	9
la7:	chkl	d0,2,10
	moveq	#3,d2
la8:	subq.l	#1,d2		; a backward BRA.W after a producer
	beq.s	la9
	moveq	#0,d3
	bra.w	la8
	failt	11
la9:	chkl	d2,0,12
	moveq	#6,d0
	bra.w	la10		; zero displacement: the target is resident
la10:	chkl	d0,6,13

;----------------------------------------------- B: BSR.W / BSR.L
	move.l	sp,a4
	lea	b1(pc),a5
	moveq	#0,d3
	bsr.w	sub_ret
b1:	chkl	d3,$C0FFEE,14
	cmpa.l	sp,a4
	bne	sp_fail
	lea	b2(pc),a5
	moveq	#0,d3
	bsr.l	sub_ret
b2:	chkl	d3,$C0FFEE,15
	cmpa.l	sp,a4
	bne	sp_fail
	lea	b3(pc),a5
	move.l	d3,(a0)		; after a store retire
	bsr.w	sub_ret
b3:	chkl	d3,$C0FFEE,16
	lea	b4(pc),a5
	move.l	(a0),d3		; after a load retire
	bsr.w	sub_ret
b4:	chkl	d3,$C0FFEE,17
	cmpa.l	sp,a4
	bne	sp_fail

;----------------------------------------------- C: JSR / JMP
	lea	c1(pc),a5
	moveq	#0,d3
	jsr	(sub_ret).l
c1:	chkl	d3,$C0FFEE,18
	lea	c2(pc),a5
	moveq	#0,d3
	jsr	(sub_ret).w
c2:	chkl	d3,$C0FFEE,19
	lea	c3(pc),a5
	moveq	#0,d3
	jsr	sub_ret(pc)
c3:	chkl	d3,$C0FFEE,20
	lea	c3b(pc),a5
	move.l	d3,(a0)		; after a store retire
	jsr	(sub_ret).l
c3b:	chkl	d3,$C0FFEE,21
	cmpa.l	sp,a4
	bne	sp_fail
	moveq	#7,d0
	jmp	(c4).l
	failt	22
c4:	chkl	d0,7,23
	moveq	#8,d0
	jmp	(c5).w
	failt	24
c5:	chkl	d0,8,25
	moveq	#9,d0
	jmp	c6(pc)
	failt	26
c6:	chkl	d0,9,27
	moveq	#10,d0
	jmp	(c7).l		; the target is the next word: resident
c7:	chkl	d0,10,28

;----------------------------------------------- K: an A7 write landing
	lea	k1(pc),a5
	moveq	#0,d3
	subq.l	#4,sp		; A7 written on the edge that pops the BSR
	bsr.w	sub_ret
k1:	addq.l	#4,sp
	chkl	d3,$C0FFEE,29
	cmpa.l	sp,a4
	bne	sp_fail
	lea	k2(pc),a5
	moveq	#0,d3
	subq.l	#4,sp
	jsr	(sub_ret).l
k2:	addq.l	#4,sp
	chkl	d3,$C0FFEE,30
	cmpa.l	sp,a4
	bne	sp_fail
	lea	k3(pc),a5
	moveq	#0,d3
	movea.l	a4,sp		; MOVEA to A7 (a register producer)
	bsr.w	sub_ret
k3:	chkl	d3,$C0FFEE,31
	cmpa.l	sp,a4
	bne	sp_fail

;----------------------------------------------- D: traces
	; T1 traces every instruction: the MOVEQ (frame PC = the BSR, address
	; = the MOVEQ), the BSR (frame PC = the target, address = the BSR), the
	; four instructions of sub_ret, and the MOVE to SR that ends it.
	lea	ld1(pc),a5
	moveq	#0,d3
	move.w	#$A000,sr
	moveq	#0,d3
d_bsr:	bsr.w	sub_ret
ld1:	move.w	#$2000,sr
	chkcnt	cnt_trace,7,32
	chktrace	0,d_bsr,ld1m,33
	chktrace	1,sub_ret,d_bsr,34
	chktrace	5,ld1,sub_ret_rts,35
	chkl	d3,$C0FFEE,36
	; T0 traces changes of flow only: the BSR (at its target), the RTS
	; and the MOVE to SR.
	clr.w	(cnt_trace).l
	lea	ld2(pc),a5
	move.w	#$6000,sr
	moveq	#0,d3
d_bsr2:	bsr.w	sub_ret
ld2:	move.w	#$2000,sr
	chkcnt	cnt_trace,3,37
	chktrace	0,sub_ret,d_bsr2,38
	chktrace	1,ld2,sub_ret_rts,39
	chkl	d3,$C0FFEE,40
	; T0 over BRA.W, JSR abs.L and JMP abs.L
	clr.w	(cnt_trace).l
	move.w	#$6000,sr
	moveq	#0,d0
d_bra:	bra.w	d3l
	failt	41
d3l:	move.w	#$2000,sr
	chkcnt	cnt_trace,2,42
	chktrace	0,d3l,d_bra,43
	clr.w	(cnt_trace).l
	lea	ld4(pc),a5
	move.w	#$6000,sr
	moveq	#0,d3
d_jsr:	jsr	(sub_ret).l
ld4:	move.w	#$2000,sr
	chkcnt	cnt_trace,3,44
	chktrace	0,sub_ret,d_jsr,45
	chktrace	1,ld4,sub_ret_rts,46
	clr.w	(cnt_trace).l
	move.w	#$6000,sr
	moveq	#0,d0
d_jmp:	jmp	(ld5).l
	failt	47
ld5:	move.w	#$2000,sr
	chkcnt	cnt_trace,2,48
	chktrace	0,ld5,d_jmp,49

;----------------------------------------------- E: odd targets
	move.l	sp,d5
	move.l	#e1,(resume).l
e_bsr:	dc.w	$6100,$0003	; bsr.w to an odd target: no push
e1:	chkcnt	cnt_addr,1,50
	move.l	(addr_pc).l,d0
	lea	e_bsr(pc),a0
	cmpa.l	d0,a0
	bne	e_fail
	move.l	(addr_fa).l,d0
	lea	e_bsr+4(pc),a0	; target e_bsr+5 with A0 cleared
	cmpa.l	d0,a0
	bne	e_fail
	move.l	(addr_sp).l,d0
	add.l	#12,d0		; the format-$2 frame
	cmp.l	d5,d0
	bne	e_fail
	move.l	#e2,(resume).l
e_bra:	dc.w	$6000,$0003	; bra.w to an odd target
e2:	chkcnt	cnt_addr,2,51
	move.l	(addr_pc).l,d0
	lea	e_bra(pc),a0
	cmpa.l	d0,a0
	bne	e_fail
	move.l	#e3,(resume).l
e_jsr:	dc.w	$4EB9		; jsr abs.l to an odd target: the frame names the target
	dc.l	e_odd+1
e3:	chkcnt	cnt_addr,3,52
	move.l	(addr_pc).l,d0
	lea	e_odd+1(pc),a0
	cmpa.l	d0,a0
	bne	e_fail
	move.l	(addr_fa).l,d0
	lea	e_odd(pc),a0
	cmpa.l	d0,a0
	bne	e_fail
	move.l	(addr_sp).l,d0
	add.l	#12,d0
	cmp.l	d5,d0
	bne	e_fail
	move.l	#e4,(resume).l
e_jmp:	dc.w	$4EF9		; jmp abs.l to an odd target: the frame PC is the JMP + 2
	dc.l	e_odd+1
e4:	chkcnt	cnt_addr,4,53
	move.l	(addr_pc).l,d0
	lea	e_jmp+2(pc),a0
	cmpa.l	d0,a0
	bne	e_fail
	bra.s	e_ok
e_fail:
	failt	54
e_odd:	nop
e_ok:

;----------------------------------------------- F: an interrupt in the window
	; Level 2 is raised d6 cycles after the write, for every d6 from 1
	; to 24, so the request lands on every cycle between the MOVEQ's
	; retire and the subroutine's return: at the boundary before the BSR,
	; inside the BSR's redirect, or in the subroutine.  Each iteration
	; must see exactly one interrupt, a correct return address and A7.
	move.w	#$2000,sr
	moveq	#1,d6
f_loop:
	lea	f_ret(pc),a5
	move.w	(cnt_int2).l,d4
	move.w	d6,(IPLDLY).l
	moveq	#0,d3
	bsr.w	sub_ret2
f_ret:	cmpa.l	sp,a4
	bne	sp_fail
	chkl	d3,$C0FFEE,55
	move.w	#400,d1
f_settle:
	dbra	d1,f_settle	; let a late request land
	move.w	(cnt_int2).l,d5
	sub.w	d4,d5
	cmp.w	#1,d5
	bne	f_fail
	addq.w	#1,d6
	cmp.w	#25,d6
	bne	f_loop
	; the same window around JSR abs.L
	moveq	#1,d6
f_loop2:
	lea	f_ret2(pc),a5
	move.w	(cnt_int2).l,d4
	move.w	d6,(IPLDLY).l
	moveq	#0,d3
	jsr	(sub_ret2).l
f_ret2:	cmpa.l	sp,a4
	bne	sp_fail
	chkl	d3,$C0FFEE,56
	move.w	#400,d1
f_settle2:
	dbra	d1,f_settle2
	move.w	(cnt_int2).l,d5
	sub.w	d4,d5
	cmp.w	#1,d5
	bne	f_fail
	addq.w	#1,d6
	cmp.w	#25,d6
	bne	f_loop2
	bra.s	f_ok
f_fail:
	failt	57
f_ok:

;----------------------------------------------- G: rewritten displacements
	; the instruction cache is not snooped by CPU writes (as on the real
	; 68040): the patch is followed by CINV, and the queue's own flush on
	; a store into its window plus the refetch must then see the new word
	lea	g_bra(pc),a0
	move.w	#g_new-g_bra-2,2(a0)	; the store lands in the fetch window
	cinva	ic
	moveq	#5,d0
g_bra:	bra.w	g_old
g_old:	failt	58
g_new:	chkl	d0,5,59
	lea	g_jsr(pc),a0
	move.l	#sub_ret,2(a0)
	cinva	ic
	lea	g1(pc),a5
	moveq	#0,d3
g_jsr:	jsr	(g_dummy).l
g1:	chkl	d3,$C0FFEE,60
	cmpa.l	sp,a4
	bne	sp_fail

;----------------------------------------------- done
	move.w	#$600D,(DONEREG).l
	stop	#$2700

sp_fail:
	failt	61

g_dummy:
	failt	62

;----------------------------------------------- subroutines
; the pushed return address must be the label the caller put in a5
sub_ret:
	cmpa.l	(sp),a5
	bne	ret_fail
	move.l	#$C0FFEE,d3
sub_ret_rts:
	rts
ret_fail:
	failt	63

sub_ret2:
	cmpa.l	(sp),a5
	bne	ret_fail2
	nop
	nop
	move.l	#$C0FFEE,d3
	rts
ret_fail2:
	failt	64

ld1m	equ	d_bsr-2	; the MOVEQ before the traced BSR

;----------------------------------------------- handlers
; trace: log the frame's PC and address field, keep T as it was
h_trace:
	move.l	a0,-(sp)
	move.l	d0,-(sp)
	move.w	(cnt_trace).l,d0
	lsl.w	#3,d0
	lea	(trace_log).l,a0
	adda.w	d0,a0
	move.l	10(sp),(a0)+	; stacked PC
	move.l	16(sp),(a0)	; format-$2 address field
	addq.w	#1,(cnt_trace).l
	move.l	(sp)+,d0
	move.l	(sp)+,a0
	rte

; address error: record the frame, continue at (resume)
h_addr:
	move.l	sp,(addr_sp).l
	move.l	2(sp),(addr_pc).l
	move.l	8(sp),(addr_fa).l
	move.l	(resume).l,2(sp)
	addq.w	#1,(cnt_addr).l
	rte

; level 2: record the frame PC, release the request
h_int2:
	move.l	2(sp),(int2_pc).l
	move.w	#0,(IPLREG).l
	addq.w	#1,(cnt_int2).l
	rte

fail_all:
	move.w	d7,(FAILREG).l
	move.w	#$BAD0,(DONEREG).l
halt1:
	bra.s	halt1

unexp:
	move.w	#$0099,(FAILREG).l
	move.w	#$BAD0,(DONEREG).l
halt2:
	bra.s	halt2
