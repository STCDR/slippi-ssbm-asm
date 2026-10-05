# Address: 0x802641CC # CSS setup: choose native four-cursor/menu path.
.include "Common/Common.s"
.include "Online/Online.s"
lbzu r0, 2(r3) # original instruction, advances CSS data pointer
getMinorMajor r12
cmpwi r12, SCENE_ONLINE_CSS
bne EXIT
loadwz r12, CSSDT_BUF_ADDR
lbz r12, CSSDT_LOCAL_TEAMS_STATUS + LTS_NATIVE(r12)
cmpwi r12, 0
beq EXIT
li r0, 0 # only the cursor/menu-path comparison, NOT the online scene/mode
EXIT:
