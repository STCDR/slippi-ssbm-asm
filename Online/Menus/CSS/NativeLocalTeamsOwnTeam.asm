# Address: 0x80261B8C # VS cursor's team-button hit test.
.include "Common/Common.s"
.include "Online/Online.s"
getMinorMajor r12
cmpwi r12, SCENE_ONLINE_CSS
bne EXIT
loadwz r12, CSSDT_BUF_ADDR
lbz r12, CSSDT_LOCAL_TEAMS_STATUS + LTS_NATIVE(r12)
cmpwi r12, 0
beq EXIT
lbz r12, 4(r31) # this native cursor's logical index
mulli r12, r12, 36
load r11, 0x803F0DFC
add r12, r12, r11
cmpw r12, r25 # this cursor can only change its own team
beq EXIT
branch r12, 0x80261BFC
EXIT:
lfs f0, 0x1c(r25) # original instruction
