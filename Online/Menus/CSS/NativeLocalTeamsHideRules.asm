# Address: 0x802662C8 # VS-only rules banner and KO text initialization.
.include "Common/Common.s"
.include "Online/Online.s"
li r0, 0 # original instruction
getMinorMajor r12
cmpwi r12, SCENE_ONLINE_CSS
bne EXIT
loadwz r12, CSSDT_BUF_ADDR
lbz r12, CSSDT_LOCAL_TEAMS_STATUS + LTS_NATIVE(r12)
cmpwi r12, 0
beq EXIT
stb r0, 0x483(r28) # scroll_flag, normally the following stock instruction
branch r12, 0x80266438 # shared Press Start / door initialization after VS text
EXIT:
