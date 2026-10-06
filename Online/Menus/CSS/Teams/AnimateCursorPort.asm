################################################################################
# Address: 0x80262478 # CSS_BigFunc... Before animating the cursor
################################################################################

.include "Common/Common.s"
.include "Online/Online.s"

.set REG_TEAM_IDX, 31
.set REG_CSSDT_ADDR, REG_TEAM_IDX-1

backup
loadwz REG_CSSDT_ADDR, CSSDT_BUF_ADDR

# Ensure that this is an online CSS
getMinorMajor r3
cmpwi r3, SCENE_ONLINE_CSS
bne EXIT # If not online CSS, continue as normal

lbz r4, OFST_R13_ONLINE_MODE(r13)
cmpwi r4, ONLINE_MODE_TEAMS
bne EXIT # exit if not on TEAMS mode


# Native local CSS uses Melee's per-door teams and portraits.
lbz r3, CSSDT_LOCAL_TEAMS_STATUS + LTS_NATIVE(REG_CSSDT_ADDR)
cmpwi r3, 0
bne NATIVE_PORT_LABEL
lbz REG_TEAM_IDX, CSSDT_TEAM_IDX(REG_CSSDT_ADDR)

SKIP_PORT_CALC:

# if is green, leave as is, else substract 1
cmpwi REG_TEAM_IDX, 3
beq SKIP_COLOR_MAP

subi REG_TEAM_IDX, REG_TEAM_IDX, 1
SKIP_COLOR_MAP:

# Map to proper player port (4*PlayerPort)+Index
lbz r6, -0x49B0(r13) # player index
mulli r6, r6, 0x4
add REG_TEAM_IDX, REG_TEAM_IDX, r6

mr r3, REG_TEAM_IDX
#logf LOG_LEVEL_NOTICE, "CURSOR COLOR r3: %d", "mr r5, 3", "mr r6, 6"
branchl r12, FN_IntToFloat
b EXIT

NATIVE_PORT_LABEL:
# Retain the native cursor's team frame, replace only its displayed port.
lbz r6, 4(r31) # cursor's card index; selection ownership remains unchanged
addi r5, REG_CSSDT_ADDR, CSSDT_LOCAL_TEAMS_STATUS + LTS_PORTS
lbzx r5, r5, r6
cmpwi r5, 4
bge EXIT
fctiwz f0, f1
stfd f0, 0x30(sp)
lwz r3, 0x34(sp)
andi. r3, r3, 3
slwi r5, r5, 2
add r3, r3, r5
branchl r12, FN_IntToFloat

b EXIT

EXIT:
restore
# Restore original values to temp registers
lwz r3, 0x3C(sp)
li r4, 6
li r5, 1024
load r6, 0x8036410c
li r7, 1 # restore original line
