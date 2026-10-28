import random, struct, math
random.seed(20261028)
def bits(x): return struct.unpack('>II', struct.pack('>d', x))
def rnd():
    m = random.uniform(1.0, 2.0)
    return random.choice([1,-1]) * m * 2.0**random.randint(-30,30)
cases=[]  # (op, a, b, expected)  op 0 div, 1 mul
for i in range(80):   # divisor a power of two
    a=rnd(); b=random.choice([1,-1])*2.0**random.randint(-25,25); cases.append((0,a,b,a/b))
for i in range(60):   # equal significands
    m=random.uniform(1.0,2.0); a=random.choice([1,-1])*m*2.0**random.randint(-25,25); b=random.choice([1,-1])*m*2.0**random.randint(-25,25)
    cases.append((0,a,b,a/b))
for i in range(80):   # multiplier a power of two (either operand)
    a=rnd(); p=random.choice([1,-1])*2.0**random.randint(-25,25)
    cases.append((1,a,p,a*p) if i%2 else (1,p,a,p*a))
for i in range(60):   # the normal paths
    a=rnd(); b=rnd(); cases.append((random.randint(0,1),a,b,(a/b) if 0 else None))
out=[]
for op,a,b,e in cases:
    if e is None:
        e = a/b if op==0 else a*b
    # (a/b, a*b in Python: IEEE double, round to nearest -- the FPU at double precision)
    out.append((op,a,b,e))
random.shuffle(out)
print("""; AP68040: FDIV and FMUL at double precision for %d pairs of doubles
; (generated with the expected results): divisors that are powers of two,
; equal significands, multipliers that are powers of two -- the shortcuts
; F_DIVL and F_MULT take in their first cycle from flags F_BIN registers --
; and pairs on the full paths.
; assembled with vasmm68k_mot -Fbin -m68040

FAILREG	equ	$F100
DONEREG	equ	$F102
NCASE	equ	%d

	org	0
	dc.l	$3400
	dc.l	start
	rept	254
	dc.l	unexp
	endr

	org	$400
start:
	fmove.l	#$00000080,fpcr		; round to nearest, double precision
	lea	cases(pc),a0
	move.l	#NCASE-1,d7
	moveq	#0,d6
.lp:	move.l	(a0)+,d0		; 0 FDIV, 1 FMUL
	fmove.d	(a0)+,fp0
	tst.l	d0
	bne.s	.mul
	fdiv.d	(a0)+,fp0
	bra.s	.chk
.mul:	fmul.d	(a0)+,fp0
.chk:	fmove.d	fp0,-(sp)
	move.l	(sp)+,d1
	move.l	(sp)+,d2
	cmp.l	(a0)+,d1
	bne.s	.bad
	cmp.l	(a0)+,d2
	bne.s	.bad
	addq.l	#1,d6
	dbf	d7,.lp
	move.w	#$600D,(DONEREG).l
	bra.s	*
.bad:	move.w	d6,(FAILREG).l
	move.w	#$BAD0,(DONEREG).l
	bra.s	*
unexp:	move.w	#$FFFF,(FAILREG).l
	move.w	#$BAD0,(DONEREG).l
	bra.s	*

	cnop	0,4
cases:""" % (len(out), len(out)))
for op,a,b,e in out:
    print("\tdc.l\t%d,$%08X,$%08X,$%08X,$%08X,$%08X,$%08X" % ((op,)+bits(a)+bits(b)+bits(e)))
