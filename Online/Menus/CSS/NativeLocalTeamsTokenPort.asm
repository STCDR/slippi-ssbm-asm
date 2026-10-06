# Address: 0x80262844 # Native token's port-number animation, before scaling by 4.
.include "Common/Common.s"
.include "Online/Online.s"
lbz r4, 4(r29) # card index; preserve its selection ownership
getMinorMajor r12
cmpwi r12, SCENE_ONLINE_CSS
bne EXIT
loadwz r12, CSSDT_BUF_ADDR
lbz r11, CSSDT_LOCAL_TEAMS_STATUS + LTS_NATIVE(r12)
cmpwi r11, 0
beq EXIT
addi r12, r12, CSSDT_LOCAL_TEAMS_STATUS + LTS_PORTS
lbzx r11, r12, r4
cmpwi r11, 4
bge EXIT
mr r4, r11
EXIT:
