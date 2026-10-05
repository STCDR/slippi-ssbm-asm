# Address: 0x80266470 # Standalone offline Ready to Fight banner's GX callback.
.include "Common/Common.s"
.include "Online/Online.s"
getMinorMajor r12
cmpwi r12, SCENE_ONLINE_CSS
bne STOCK_CALLBACK
loadwz r12, CSSDT_BUF_ADDR
lbz r12, CSSDT_LOCAL_TEAMS_STATUS + LTS_NATIVE(r12)
cmpwi r12, 0
beq STOCK_CALLBACK
# Keep the banner object's stock think callback; Slippi owns visible readiness.
bl NO_DRAW
mflr r4
b EXIT
STOCK_CALLBACK:
addi r4, r3, 0x1070 # original callback: HSD_GObj_JObjCallback
b EXIT
NO_DRAW:
blrl
blr
EXIT:
