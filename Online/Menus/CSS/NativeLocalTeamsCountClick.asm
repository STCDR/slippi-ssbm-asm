# Address: 0x802608D8 # After movement, before held/free token paths split.
.include "Common/Common.s"
.include "Online/Online.s"
getMinorMajor r12
cmpwi r12, SCENE_ONLINE_CSS
bne EXIT
loadwz r12, CSSDT_BUF_ADDR
lbz r12, CSSDT_LOCAL_TEAMS_STATUS + LTS_NATIVE(r12)
cmpwi r12, 0
beq EXIT
backup BKP_DEFAULT_FREE_SPACE_SIZE, 2
mr r30, r31 # stock cursor data
loadwz r31, CSSDT_BUF_ADDR
# Local Teams routes the native 31-frame B hold: main exits, teammates leave.
li r3, 0
sth r3, 0x0a(r30)
# P1 owns the count selector; r28 contains retail pressed-button edges.
lbz r3, 4(r30)
cmpwi r3, 0
bne NATIVE_PASS
andi. r3, r28, 0x100
beq NATIVE_PASS
bl COUNT_BOUNDS
mflr r29
lfs f30, 0x0c(r30)
lfs f31, 0(r29)
fcmpo cr0, f30, f31
blt NATIVE_PASS
lfs f31, 4(r29)
fcmpo cr0, f30, f31
bgt NATIVE_PASS
lfs f30, 0x10(r30)
lfs f31, 8(r29)
fcmpo cr0, f30, f31
blt NATIVE_PASS
lfs f31, 12(r29)
fcmpo cr0, f30, f31
bgt NATIVE_PASS
lbz r3, CSSDT_LOCAL_TEAMS_STATUS + 5(r31)
cmpwi r3, 0
bne NATIVE_CONSUME_CLICK
lbz r25, CSSDT_LOCAL_TEAMS_STATUS + 1(r31)
addi r26, r25, 1
cmpwi r26, 4
ble NATIVE_COUNT_READY
li r26, 1
NATIVE_COUNT_READY:
# EXIDma discards the address's low five bits. HSD buffers are 32-byte aligned;
# the cursor's stack frame is not. Reuse one aligned buffer for command/status.
li r3, LOCAL_TEAMS_STATUS_SIZE
branchl r12, HSD_MemAlloc
mr r24, r3
cmpwi r24, 0
beq NATIVE_CONSUME_CLICK
li r3, CONST_LocalTeamsCount
stb r3, 0(r24)
stb r26, 1(r24)
li r27, 0
NATIVE_SAVE_PICK:
lwz r3, -0x49f0(r13)
mulli r4, r27, 36
add r3, r3, r4
slwi r4, r27, 2
addi r5, r24, 2
add r5, r5, r4
lbz r6, 0x70(r3)
stb r6, 0(r5)
lbz r6, 0x73(r3)
stb r6, 1(r5)
lbz r6, 0x79(r3)
stb r6, 2(r5)
li r6, 0
load r3, 0x804a0bd0
lwzx r3, r3, r4
cmpwi r3, 0
beq NATIVE_SAVE_PLACED
lbz r3, 5(r3)
cmpwi r3, 0
bne NATIVE_SAVE_PLACED
li r6, 1
NATIVE_SAVE_PLACED:
stb r6, 3(r5)
addi r27, r27, 1
cmpwi r27, 4
blt NATIVE_SAVE_PICK
mr r3, r24
li r4, 18
li r5, CONST_ExiWrite
branchl r12, FN_EXITransferBuffer
mr r3, r24
li r4, LOCAL_TEAMS_STATUS_SIZE
li r5, CONST_ExiRead
branchl r12, FN_EXITransferBuffer
lbz r3, 0(r24)
cmpwi r3, 1
bne NATIVE_FREE_BUFFER
lbz r3, LTS_NATIVE(r24)
cmpwi r3, 1
bne NATIVE_FREE_BUFFER
lbz r3, 1(r24)
cmpw r3, r26 # reload only when the backend reports the exact requested count
bne NATIVE_FREE_BUFFER
li r3, 1
stb r3, CSSDT_NATIVE_RELOAD(r31)
li r3, 2 # unconditional exit; retail rejects flag 1 with empty tokens
stb r3, -0x49aa(r13)
li r3, 2
branchl r12, SFX_Menu_CommonSound
NATIVE_FREE_BUFFER:
mr r3, r24
branchl r12, HSD_Free
NATIVE_CONSUME_CLICK:
restore BKP_DEFAULT_FREE_SPACE_SIZE, 2
branch r12, 0x802622a8 # consume A, update hand display
NATIVE_PASS:
restore BKP_DEFAULT_FREE_SPACE_SIZE, 2
b EXIT
COUNT_BOUNDS:
blrl
.float -35.0,-14.5,20.5,25.0 # entire reachable grey corner
EXIT:
lbz r4, 4(r31) # original instruction
