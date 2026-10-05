# Address: 0x80266830 # End of native CSS initialization, before restoring registers.
.include "Common/Common.s"
.include "Online/Online.s"
b CODE_START
DATA:
blrl
# Original HMN/team hitboxes; restore on every CSS, including ordinary VS.
.float -35.6,-28.6,-26.8,-21.0
.float -19.4,-13.4,-11.4,-6.0
.float -4.2,2.2,3.5,9.4
.float 11.0,17.0,19.0,24.6
# N=1/2/3/4 horizontal offsets. The last panel in N=2/3/4 ends at P1+18.
.float 0,0,0,0
.float 0,2.6,5.2,7.8
.float 0,-6.4,-12.8,-19.2
.float 0,-9.4,-18.8,-28.2
.float 0.5,-3.4 # team-marker midpoint / cursor height
.set NATIVE_DIGIT_GLYPHS, 0x88
# 1-P: replace only the eight-pixel digit, retain the stock hyphen/P/ring.
.long 0x00005dd0,0x0009fff0,0x02dffff0,0x08fffff0,0x048ffff0,0x000ffff0,0x000ffff0,0x000ffff0,0x000ffff0,0x000ffff0,0x000ffff0,0x000ffff0,0x000ffff0
# 2-P: replace only the eight-pixel digit, retain the stock hyphen/P/ring.
.long 0x00dfffd0,0x0dfffffd,0x0dfffffd,0x00000dfd,0x00000dfd,0x0000dfd0,0x000dfd00,0x00dfd000,0x0dfd0000,0x0dfd0000,0x0dfffffd,0x0dfffffd,0x0dfffffd
# 3-P: replace only the eight-pixel digit, retain the stock hyphen/P/ring.
.long 0x00dfffd0,0x0dfffffd,0x0dfffffd,0x00000dfd,0x00000dfd,0x000dffd0,0x000dffd0,0x00000dfd,0x00000dfd,0x00000dfd,0x0dfffffd,0x0dfffffd,0x00dfffd0
# 4-P: replace only the eight-pixel digit, retain the stock hyphen/P/ring.
.long 0x0000dfd0,0x000dffd0,0x00dfffd0,0x00dfffd0,0x0dfd0dd0,0x0dfd0dd0,0x0dfd0dd0,0x0dfffffd,0x0dfffffd,0x0000dfd0,0x0000dfd0,0x0000dfd0,0x0000dfd0
CODE_START:
backup BKP_DEFAULT_FREE_SPACE_SIZE, 2
bl DATA
mflr r31
li r30, 0
load r29, 0x803F0DFC
RESET_BOUNDS:
mulli r3, r30, 16
add r3, r31, r3
lwz r4, 0(r3)
stw r4, 0x14(r29)
lwz r4, 4(r3)
stw r4, 0x18(r29)
lwz r4, 8(r3)
stw r4, 0x1c(r29)
lwz r4, 12(r3)
stw r4, 0x20(r29)
addi r29, r29, 36
addi r30, r30, 1
cmpwi r30, 4
blt RESET_BOUNDS
getMinorMajor r3
cmpwi r3, SCENE_ONLINE_CSS
bne DONE
loadwz r28, CSSDT_BUF_ADDR
lbz r3, CSSDT_LOCAL_TEAMS_STATUS + LTS_NATIVE(r28)
cmpwi r3, 0
beq DONE
# The multiplayer menu has different frame/title meshes. Slippi's title
# animation expects SingleMenu UVs, so transplant those two unskinned DObj lists.
lwz r3, -0x49c8(r13)
lwz r3, 0x60(r3)
branchl r12, 0x80370e44 # HSD_JObjLoadJoint
mr r26, r3
li r25, 0
NATIVE_RESTORE_HEADER:
li r5, 1 # outer Teams frame
cmpwi r25, 0
beq NATIVE_HEADER_LOOKUP
li r5, 36 # mode title; Slippi still animates this live joint
NATIVE_HEADER_LOOKUP:
mr r24, r5
mr r3, r26
addi r4, sp, 0x30
li r6, -1
branchl r12, JObj_GetJObjChild
lwz r23, 0x30(sp)
lwz r3, -0x49e0(r13)
addi r4, sp, 0x30
mr r5, r24
li r6, -1
branchl r12, JObj_GetJObjChild
lwz r22, 0x30(sp)
lwz r3, 0x18(r22)
branchl r12, 0x8035e24c # HSD_DObjRemoveAll
lwz r3, 0x18(r23)
stw r3, 0x18(r22)
li r3, 0
stw r3, 0x18(r23) # transferred ownership, do not free with temporary root
addi r25, r25, 1
cmpwi r25, 2
blt NATIVE_RESTORE_HEADER
mr r3, r26
branchl r12, 0x80371590 # HSD_JObjRemoveAll
# The first SingleMenu title DObj is the stock "10-Man Melee" texture.
# Slippi animates the second title DObj; hide only that stray stock heading.
lwz r3, 0x18(r22)
lwz r4, 0x14(r3)
ori r4, r4, 1 # DOBJ_HIDDEN
stw r4, 0x14(r3)
# Keep the original bold "-P" lettering and circle. Patch only the digit
# before its first upload; the same narrow I4 block is used at every count.
lwz r3, -0x49e0(r13)
addi r4, sp, 0x30
li r5, 1
li r6, -1
branchl r12, JObj_GetJObjChild
lwz r3, 0x30(sp)
lwz r3, 0x18(r3) # DObj
lwz r3, 8(r3) # MObj
lwz r3, 8(r3) # TObj
lwz r3, 0x58(r3) # ImageDesc
lwz r4, 4(r3)
load r5, 0x00680048 # original 104x72 frame
cmpw r4, r5
bne NATIVE_FRAME_CLEAR_DONE
lwz r4, 8(r3)
cmpwi r4, 0 # GX_TF_I4
bne NATIVE_FRAME_CLEAR_DONE
lwz r26, 0(r3)
lbz r3, CSSDT_LOCAL_TEAMS_STATUS + 1(r28)
addi r3, r3, -1
mulli r3, r3, 52 # thirteen packed eight-pixel rows per digit
addi r24, r31, NATIVE_DIGIT_GLYPHS
add r24, r24, r3
li r25, 17
NATIVE_FRAME_DIGIT_ROW:
srwi r3, r25, 3
mulli r3, r3, 416 # 13 eight-pixel blocks per row, 32 bytes/block
addi r3, r3, 64 # digit spans x16..23, third eight-pixel block
andi. r4, r25, 7
slwi r4, r4, 2
add r3, r3, r4
lwz r4, 0(r24)
stwx r4, r26, r3
addi r24, r24, 4
addi r25, r25, 1
cmpwi r25, 30
blt NATIVE_FRAME_DIGIT_ROW
NATIVE_FRAME_CLEAR_DONE:
li r30, 0
NATIVE_INIT_PORT:
load r3, 0x804A0BC0
slwi r4, r30, 2
lwzx r3, r3, r4
lbz r4, CSSDT_LOCAL_TEAMS_STATUS + 1(r28)
cmpw r30, r4
blt NATIVE_VISIBLE_PORT
lwz r3, 0(r3) # cursor GObj -> JObj
lwz r3, 0x28(r3)
li r4, 0x10
branchl r12, JObj_SetFlagsAll
load r3, 0x804A0BD0
slwi r4, r30, 2
lwzx r3, r3, r4
lwz r3, 0(r3)
lwz r3, 0x28(r3)
li r4, 0x10
branchl r12, JObj_SetFlagsAll
b NATIVE_INIT_NEXT
NATIVE_VISIBLE_PORT:
# Preserve normal native doors/portraits. Disable CPU/HMN switching.
load r29, 0x803F0DFC
mulli r3, r30, 36
add r29, r29, r3
li r3, 0
stb r3, 0x0b(r29)
load r3, 0x447a0000 # out-of-range hitbox, 1000f
stw r3, 0x14(r29)
stw r3, 0x18(r29)
lbz r3, CSSDT_LOCAL_TEAMS_STATUS + 1(r28)
subi r3, r3, 1
slwi r3, r3, 4
addi r3, r3, 64
slwi r4, r30, 2
add r3, r3, r4
lfsx f31, r31, r3
lfs f30, 0x1c(r29)
fadds f30, f30, f31
stfs f30, 0x1c(r29)
lfs f30, 0x20(r29)
fadds f30, f30, f31
stfs f30, 0x20(r29)
# Spawn every local hand on its own moved team marker, including P1.
lfs f30, 0x1c(r29)
lfs f31, 0x20(r29)
fadds f30, f30, f31
lfs f31, 128(r31)
fmuls f30, f30, f31
load r3, 0x804A0BC0
slwi r4, r30, 2
lwzx r3, r3, r4
stfs f30, 0x0c(r3)
lfs f31, 132(r31)
stfs f31, 0x10(r3)
# Cache three native leaf joints and their original X coordinates per port.
li r27, 0
NATIVE_CACHE_JOINT:
li r5, 41 # background / character name
cmpwi r27, 0
beq NATIVE_CACHE_LOOKUP
li r5, 51 # character portrait
cmpwi r27, 1
beq NATIVE_CACHE_LOOKUP
li r5, 56 # team marker
NATIVE_CACHE_LOOKUP:
add r5, r5, r30
lwz r3, -0x49e0(r13)
addi r4, sp, 0x30
li r6, -1
branchl r12, JObj_GetJObjChild
lwz r3, 0x30(sp)
mulli r4, r30, 12
slwi r5, r27, 2
add r4, r4, r5
addi r5, r28, CSSDT_NATIVE_JOINTS
stwx r3, r5, r4
lwz r3, 0x38(r3)
addi r5, r28, CSSDT_NATIVE_ORIGINAL_X
stwx r3, r5, r4
addi r27, r27, 1
cmpwi r27, 3
blt NATIVE_CACHE_JOINT
NATIVE_INIT_NEXT:
addi r30, r30, 1
cmpwi r30, 4
blt NATIVE_INIT_PORT
li r3, 1
stb r3, CSSDT_NATIVE_INITIALIZED(r28)
lbz r3, CSSDT_LOCAL_TEAMS_STATUS + 1(r28)
stb r3, CSSDT_NATIVE_VISIBLE_COUNT(r28) # commit layout with the newly spawned fields/cursors
DONE:
restore BKP_DEFAULT_FREE_SPACE_SIZE, 2
lmw r17, 0x11c(sp) # original instruction
