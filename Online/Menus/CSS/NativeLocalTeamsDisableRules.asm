# Address: 0x802616C0 # VS rules / melee-teams toggle hit testing.
.include "Common/Common.s"
.include "Online/Online.s"
getMinorMajor r12
cmpwi r12, SCENE_ONLINE_CSS
bne EXIT
loadwz r12, CSSDT_BUF_ADDR
lbz r12, CSSDT_LOCAL_TEAMS_STATUS + LTS_NATIVE(r12)
cmpwi r12, 0
beq EXIT
branch r12, 0x80261944 # preserve costume and door controls; skip offline rules
EXIT:
lwz r3, -0x49F0(r13) # original instruction
