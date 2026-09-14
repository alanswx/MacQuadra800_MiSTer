 org 0
 dc.l $f000,start,access_error
 rept 253
 dc.l fail
 endr
 org $400
start:
 move.w #$2700,sr
 moveq #0,d6
 move.l #$80008000,d0
 movec d0,cacr
 lea ($4000).l,a0
 moveq #1,d7
 bsr reads
 moveq #2,d7
 move.l #$8000,d0
 movec d0,srp
 movec d0,urp
 movec d0,tc
 lea ($9000).l,a0
 bsr reads
 moveq #3,d7
 move.l #$0000c000,d0
 movec d0,dtt0
 lea ($4000).l,a0
 bsr reads
 moveq #4,d7
 move.l #$0000c040,d0
 movec d0,dtt0
 bsr reads
 moveq #5,d7
 move.l #$0000c000,d0
 movec d0,dtt0
 bsr reads
 moveq #6,d7
 move.l #$00008000,d0
 movec d0,cacr
 bsr reads
 moveq #7,d7
 move.l #$80008000,d0
 movec d0,cacr
 bsr reads
 moveq #8,d7
 bsr reads
 ; posted store hit-update: the core moves on (instruction hints) before
 ; the drain acknowledges; the merge must still land in the store's row
 lea ($4000).l,a0
 move.l (a0),d0
 move.l #$a5a55a5a,(a0)
 nop
 nop
 nop
 move.l (a0),d0
 cmp.l #$a5a55a5a,d0
 bne fail
 move.l #$12345678,(a0)
 nop
 nop
 move.l (a0),d0
 cmp.l #$12345678,d0
 bne fail
 ; spanning stores merge into both words of a resident line
 move.l #$11223344,2(a0)
 nop
 nop
 nop
 move.l 2(a0),d0
 cmp.l #$11223344,d0
 bne fail
 move.l (a0),d0
 cmp.l #$12341122,d0
 bne fail
 move.l 4(a0),d1
 move.w #$abcd,7(a0)
 nop
 nop
 move.l 4(a0),d0
 and.l #$ffffff00,d1
 or.l #$000000ab,d1
 cmp.l d1,d0
 bne fail
 move.l #$12345678,(a0)
 move.w #$9abc,6(a0)
 nop
 nop
 moveq #9,d7
 move.l #$0000c040,d0
 movec d0,dtt0
 move.l ($e000).l,d0
 cmp.l #$12345678,d0
 bne fail
 cmp.l #1,d6
 bne fail
 move.w #$600d,($f100).l
 stop #$2700
reads:
 move.l (a0),d0
 cmp.l #$12345678,d0
 bne fail
 move.l (a0),d0
 move.l (a0),d1
 move.l (4,a0),d2
 move.b (1,a0),d3
 and.l #$ff,d3
 cmp.l #$34,d3
 bne fail
 move.w (2,a0),d4
 cmp.w #$5678,d4
 bne fail
 move.l (a0),d5
 cmp.l #$12345678,d5
 bne fail
 rts
access_error:
 addq.l #1,d6
 rte
fail:
 move.w #$dead,($f100).l
 stop #$2700
 org $4000
 dc.l $12345678,$9abcdef0,$13579bdf,$2468ace0
 org $8000
 dc.l $0000820b
 org $8200
 dc.l $0000840b
 org $8400
 dc.l $0000001b,$0000101b,$0000201b,$0000301b
 dc.l $0000401b,$0000501b,$0000601b,$0000701b
 dc.l $0000801b,$0000401b,$0000a01b,$0000b01b
 dc.l $0000c01b,$0000d01b,$0000e01b,$0000f01b
 org $e000
 dc.l $12345678
