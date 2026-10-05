# Address: 0x80264590 # Select CSS menu's GX callback.
.include "Common/Common.s"
.include "Online/Online.s"
getMinorMajor r12
cmpwi r12, SCENE_ONLINE_CSS
bne STOCK_CALLBACK
loadwz r12, CSSDT_BUF_ADDR
lbz r12, CSSDT_LOCAL_TEAMS_STATUS + LTS_NATIVE(r12)
cmpwi r12, 0
beq STOCK_CALLBACK
bl DRAW_CALLBACK
mflr r4
b EXIT
STOCK_CALLBACK:
addi r4, r4, 0x1070 # original callback: HSD_GObj_JObjCallback
b EXIT
DRAW_CALLBACK:
blrl
backup BKP_DEFAULT_FREE_SPACE_SIZE, 2
mr r31, r3 # GObj
mr r30, r4 # render pass
loadwz r29, CSSDT_BUF_ADDR
lbz r3, CSSDT_NATIVE_INITIALIZED(r29)
cmpwi r3, 0
beq DRAW_DONE
bl DATA
mflr r28
# Character-name SIS objects are separate from the panel joints. Hide only them.
li r27, 0
HIDE_CHARACTER_NAME:
load r3, 0x803F0E8C
mulli r4, r27, 12
lwzx r3, r3, r4
cmpwi r3, 0
beq HIDE_CHARACTER_NAME_NEXT
lwz r3, 0(r3)
cmpwi r3, 0
beq HIDE_CHARACTER_NAME_NEXT
li r4, 1
stb r4, 0x4d(r3) # HSD_Text.hidden
HIDE_CHARACTER_NAME_NEXT:
addi r27, r27, 1
cmpwi r27, 4
blt HIDE_CHARACTER_NAME
# Hide the VS rules banner and original lower panels. Slippi draws its own text.
li r27, 0
HIDE_GROUP:
lwz r3, 0x28(r31)
addi r4, sp, 0x30
lbzx r5, r28, r27
li r6, -1
branchl r12, JObj_GetJObjChild
lwz r3, 0x30(sp)
li r4, 0x10
branchl r12, JObj_SetFlagsAll
addi r27, r27, 1
cmpwi r27, 14
blt HIDE_GROUP
mr r3, r31
mr r4, r30
branchl r12, 0x80391070
# Higher local numbers draw first, leaving P1 above P2 above P3 above P4.
mr r3, r30
branchl r12, 0x80390eb8
mr r26, r3
# Polling can already report the requested roster while this CSS is leaving.
# Keep its initialized fields/spacing until the replacement CSS is ready.
lbz r27, CSSDT_NATIVE_VISIBLE_COUNT(r29)
subi r27, r27, 1
DRAW_PORT:
lbz r3, CSSDT_NATIVE_VISIBLE_COUNT(r29)
subi r3, r3, 1
slwi r3, r3, 4
addi r3, r3, 16
slwi r4, r27, 2
add r3, r3, r4
lfsx f31, r28, r3
li r25, 0
DRAW_COMPONENT:
# Empty doors retain a fallback portrait mesh. Follow the retail icon state
# so blank panels stay blank while hovered and selected characters still show.
cmpwi r25, 1
bne DRAW_VISIBLE_COMPONENT
load r3, 0x803f0dfc
mulli r4, r27, 36
add r3, r3, r4
lbz r3, 0x0e(r3)
cmplwi r3, 25
bge DRAW_COMPONENT_NEXT
DRAW_VISIBLE_COMPONENT:
mulli r24, r27, 12
slwi r3, r25, 2
add r24, r24, r3
addi r3, r29, CSSDT_NATIVE_JOINTS
lwzx r23, r3, r24
addi r3, r29, CSSDT_NATIVE_ORIGINAL_X
lfsx f30, r3, r24
fadds f30, f30, f31
stfs f30, 0x38(r23)
mr r3, r23
li r4, 0x40 # mark translated matrix dirty
branchl r12, JObj_SetFlags
mr r3, r23
li r4, 0x10
branchl r12, JObj_ClearFlags
mr r3, r23
li r4, 0
mr r5, r26
li r6, 0
branchl r12, 0x803709dc # HSD_JObjDispAll draws this leaf, not its siblings
DRAW_COMPONENT_NEXT:
addi r25, r25, 1
cmpwi r25, 3
blt DRAW_COMPONENT
subi r27, r27, 1
cmpwi r27, 0
bge DRAW_PORT
DRAW_DONE:
restore BKP_DEFAULT_FREE_SPACE_SIZE, 2
blr
DATA:
blrl
.byte 37,38,40,45,50,55,60,86,111,132,140,148,156,164,0,0 # align floats; keep restored frame visible
.float 0,0,0,0
.float 0,2.6,5.2,7.8
.float 0,-6.4,-12.8,-19.2
.float 0,-9.4,-18.8,-28.2
EXIT:
