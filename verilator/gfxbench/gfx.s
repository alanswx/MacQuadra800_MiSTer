; gfx.s -- QuickDraw-shaped microbench for tb_gfx.
;
; Each kernel touches a 16 KB window RPT+1 times.  The uncached VRAM window is
; at $F9010000; the cached RAM window at $00020000 (copyback).  A tag is
; written to the timestamp port between kernels; cost/op is a subtraction of
; the printed cycle counts.  Kernels mirror QuickDraw inner loops:
;   K1 sequential long fill      (PaintRect / blit fill)
;   K2 unaligned spanning stores (pattern fill at an odd offset)
;   K3 read-modify-write         (CopyBits with a transfer mode)
;   K4 / K5 the same to cached RAM, as a baseline.

RPT	equ	4-1		; outer passes - 1 (dbf)
NLONG	equ	4096-1		; longs per pass - 1 (dbf); 16 KB window
VBASE	equ	$F9010000
RBASE	equ	$00020000

TS	macro
	move.l	#\1,$50000010
	endm

	org	0
	dc.l	$00008000	; SSP
	dc.l	start
	dcb.l	254,fault

start:
	move.l	#$0000C020,d0	; TTR: $00xxxxxx, enabled, copyback (CM=01)
	movec	d0,dtt0
	movec	d0,itt0
	moveq	#0,d0		; the other TTRs disabled
	movec	d0,dtt1
	movec	d0,itt1
	cinva	bc
	move.l	#$80008000,d0	; D-cache and I-cache enable
	movec	d0,cacr

	;---- K1: sequential VRAM long fill (uncached store stream) ----
	TS	$100
	move.l	#RPT,d2
.k1o	lea	VBASE,a0
	move.w	#NLONG,d1
	move.l	#$FFFFFFFF,d0
.k1	move.l	d0,(a0)+
	dbf	d1,.k1
	dbf	d2,.k1o
	TS	$101

	;---- K2: unaligned spanning VRAM long stores ----
	TS	$200
	move.l	#RPT,d2
.k2o	lea	VBASE+1,a0	; odd base: every long spans two bus words
	move.w	#NLONG,d1
	move.l	#$A5A5A5A5,d0
.k2	move.l	d0,(a0)
	addq.l	#4,a0
	dbf	d1,.k2
	dbf	d2,.k2o
	TS	$201

	;---- K3: VRAM read-modify-write (CopyBits with a mode) ----
	TS	$300
	move.l	#RPT,d2
.k3o	lea	VBASE,a0
	move.w	#NLONG,d1
	move.l	#$0F0F0F0F,d3
.k3	move.l	(a0),d0
	or.l	d3,d0
	move.l	d0,(a0)+
	dbf	d1,.k3
	dbf	d2,.k3o
	TS	$301

	;---- K4: RAM cached sequential long fill (baseline for K1) ----
	TS	$400
	move.l	#RPT,d2
.k4o	lea	RBASE,a0
	move.w	#NLONG,d1
	move.l	#$FFFFFFFF,d0
.k4	move.l	d0,(a0)+
	dbf	d1,.k4
	dbf	d2,.k4o
	TS	$401

	;---- K5: RAM cached read-modify-write (baseline for K3) ----
	TS	$500
	move.l	#RPT,d2
.k5o	lea	RBASE,a0
	move.w	#NLONG,d1
	move.l	#$0F0F0F0F,d3
.k5	move.l	(a0),d0
	or.l	d3,d0
	move.l	d0,(a0)+
	dbf	d1,.k5
	dbf	d2,.k5o
	TS	$501

	;---- K6: VRAM read with arithmetic between reads (CopyBits-shaped:
	;     fetch source, compute mask/pattern, fetch next) ----
	TS	$600
	move.l	#RPT,d2
.k6o	lea	VBASE,a0
	move.w	#NLONG,d1
	move.l	#$00010001,d3
.k6	move.l	(a0)+,d0
	mulu.l	d3,d0		; ~10 clocks of older, non-store work before the next read
	add.l	d0,d4
	dbf	d1,.k6
	dbf	d2,.k6o
	TS	$601

	move.l	#$A5A5A5A5,$50000000
	cpusha	dc
.h	bra	.h

fault:	move.l	#$EE,$50000000
	cpusha	dc
.hf	bra	.hf
