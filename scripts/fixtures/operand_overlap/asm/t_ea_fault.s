; Extension-only demand faults at 4K page boundaries. Check original PC,
; fault address, no early writes, and restart after a format-7 RTE.
FAILREG equ $F100
DONEREG equ $F102
FBERRCTL equ $F154
check macro
 cmp.l #\2,\1
 beq.s ok\@
 move.w #\3,d7
 bra fail
ok\@:
 endm
arm macro
 move.l #\1,a4
 move.l #\2,a5
 move.w a5,(FBERRCTL).l
 jmp (a4)
 endm
 org 0
 dc.l $7800,start,h_bus
 rept 253
 dc.l unexpected
 endr
 org $400
start:
 move.w #$2700,sr
 moveq #0,d0
 movec d0,cacr
 move.l #$10203040,($6000).l
 movea.l #$5FF0,a0
 moveq #0,d6
 move.l #$55AA55AA,d2
 arm test_d16,$1000
done_d16:
 check d2,$10203040,1
 check d6,1,2
 move.l #$55AA55AA,d2
 arm test_abs,$2000
done_abs:
 check d2,$10203040,3
 check d6,2,4
 move.l #$55AA55AA,d2
 arm test_imm,$3000
done_imm:
 move.l ($6000).l,d0
 check d0,$11223344,5
 check d6,3,6
 move.l #$10203040,($6000).l
 moveq #$10,d1
 arm test_index,$4000
done_index:
 check d2,$10203040,7
 check d6,4,8
 move.l #$55AA55AA,d2
 arm test_pc,$5000
done_pc:
 check d2,$DEADBEEF,9
 check d6,5,10
 move.w #$600D,(DONEREG).l
 stop #$2700
fail:
 move.w d7,(FAILREG).l
 move.w #$BAD0,(DONEREG).l
 bra.s fail
unexpected:
 move.w #255,d7
 bra fail
 org $800
h_bus:
 move.w #101,d7
 cmpi.w #$7008,6(sp)
 bne fail
 move.l 2(sp),d0
 cmp.l a4,d0
 bne fail
 move.l $14(sp),d0
 cmp.l a5,d0
 bne fail
 move.w $0C(sp),d0
 andi.w #$0407,d0
 cmpi.w #6,d0
 bne fail
 check d2,$55AA55AA,102
 move.l ($6000).l,d0
 check d0,$10203040,103
 addq.l #1,d6
 rte
 org $FFE
test_d16:
 move.l ($10,a0),d2
 jmp done_d16
 org $1FFC
test_abs:
 move.l ($6000).l,d2
 jmp done_abs
 org $2FFA
test_imm:
 addi.l #$01020304,($10,a0)
 jmp done_imm
 org $3FFE
test_index:
 move.l (0,a0,d1.l),d2
 jmp done_index
 org $4FFE
test_pc:
 move.l (pc_data,pc),d2
 jmp done_pc
 org $5100
pc_data:
 dc.l $DEADBEEF
