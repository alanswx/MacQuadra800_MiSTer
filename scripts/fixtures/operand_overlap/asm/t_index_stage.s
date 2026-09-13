; Directed EA-stage overlap tests. Exact Sieve is a separate workload fixture.
FAILREG equ $F100
DONEREG equ $F102
check macro
 cmp.l #\2,\1
 beq.s ok\@
 move.w #\3,d7
 bra fail
ok\@:
 endm
 org 0
 dc.l $3400,start
 rept 254
 dc.l unexpected
 endr
 org $400
start:
 move.w #$2700,sr
 move.l #$80008000,d0
 movec d0,cacr
 lea ($3000).l,a0
 move.l #$12345678,($3000).l
 move.l #$89ABCDEF,($3020).l
 move.l #$0BADCAFE,($3040).l
 ; Brief Dn.W with negative index, nonzero scale and signed disp8.
 move.l #$1234FFF0,d1
 move.l ($40,a0,d1.w*2),d2
 check d2,$89ABCDEF,1
 ; Long index and negative displacement, immediate predecessor RAW.
 moveq #8,d1
 addq.l #8,d1
 move.l (-32,a0,d1.l*4),d2
 check d2,$89ABCDEF,2
 ; An index and identical base/index selection, no additional read port.
 movea.l #$10,a1
 move.l (0,a0,a1.l*2),d2
 check d2,$89ABCDEF,3
 movea.l #$1800,a1
 move.l (0,a1,a1.l),d2
 check d2,$12345678,4
 ; Source postincrement changes the base for the destination indexed EA.
 lea ($3000).l,a0
 moveq #$1c,d1
 move.l (a0)+,(0,a0,d1.w)
 move.l ($3020).l,d2
 check d2,$12345678,5
 ; Same operation through active ISP A7, then word/long A7 as index.
 movea.l a7,a5
 movea.l #$3000,a7
 moveq #$1c,d1
 move.l (a7)+,(0,a7,d1.w)
 move.l ($3020).l,d2
 check d2,$12345678,6
 lea ($20).w,a0
 move.l (-4,a0,a7.l),d2
 check d2,$12345678,7
 movea.l a5,a7
 ; PC-relative indexed extension uses extension-word PC, not later PC.
 moveq #4,d1
 move.l (pc_data,pc,d1.w),d2
 check d2,$CAFEBABE,8
 ; Full direct: word base displacement, long index, scale2.
 lea ($3000).l,a0
 moveq #8,d1
 dc.w $2430,$1B20,$0030
 check d2,$0BADCAFE,9
 ; Full direct: base/index suppressed, absolute long displacement.
 dc.w $2430,$01F0
 dc.l $3040
 check d2,$0BADCAFE,10
 ; Preindexed memory indirect and postindexed with outer displacement.
 move.l #$3050,($3048).l
 move.l #$DEAD0001,($3054).l
 move.l #$DEAD0002,($305C).l
 moveq #4,d1
 move.l ([$40,a0,d1.l*2],4),d2
 check d2,$DEAD0001,11
 move.l ([$48,a0],d1.l*2,4),d2
 check d2,$DEAD0002,12
 ; d16 operands and decode immediate survive extension setup.
 move.l #$10203040,($3060).l
 move.l ($60,a0),d2
 check d2,$10203040,15
 addi.l #$01020304,($60,a0)
 move.l ($60,a0),d2
 check d2,$11223344,16
 eori.w #$55AA,($62,a0)
 move.l ($60,a0),d2
 check d2,$112266EE,17
 ; Memory bit operations consume x_ext after EA setup clears imm.
 bset #19,($61,a0)
 move.l ($60,a0),d2
 check d2,$112A66EE,18
 move.l ($60,a0),($64,a0)
 move.l ($64,a0),d2
 check d2,$112A66EE,19
 ; Source postincrement visible at d16 destination base selection.
 lea ($3060).l,a1
 move.l (a1)+,($0C,a1)
 move.l ($3070).l,d2
 check d2,$112A66EE,20
 move.l a1,d2
 check d2,$3064,21
 move.l ($3070).w,($3074).w
 move.l ($3074).l,d2
 check d2,$112A66EE,22
 move.l (-4,a1),d2
 check d2,$112A66EE,23
 move.l (pc_data,pc),d2
 check d2,$11223344,24
 cmpi.l #$11223344,(pc_data,pc)
 beq.s pc_cmp_ok
 moveq #25,d7
 bra fail
pc_cmp_ok:
 ; Long absolute EA at both longword alignments.
 cnop 0,4
 move.l ($3074).l,d2
 check d2,$112A66EE,26
 cnop 2,4
 move.l ($3074).l,d2
 check d2,$112A66EE,27
 ; Master-stack bank as index after MOVEC/SR switch.
 move.l #$10,d0
 movec d0,msp
 move.w #$3700,sr
 move.l (0,a0,a7.l*4),d2
 check d2,$0BADCAFE,13
 move.w #$2700,sr
 ; User-stack bank used as index; regain supervisor via TRAP #0.
 move.l #$10,d0
 movec d0,usp
 move.l #from_user,($80).l
 move.w #$0000,sr
 move.l (0,a0,a7.l*4),d2
 trap #0
from_user:
 check d2,$0BADCAFE,14
 move.w #$600D,(DONEREG).l
 stop #$2700
fail:
 move.w d7,(FAILREG).l
 move.w #$BAD0,(DONEREG).l
 bra.s fail
unexpected:
 move.w #255,d7
 bra fail
 even
pc_data:
 dc.l $11223344,$CAFEBABE
