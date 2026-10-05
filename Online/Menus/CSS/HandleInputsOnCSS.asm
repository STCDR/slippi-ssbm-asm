################################################################################
# Address: 0x80263258 # CSS_LoadButtonInputs runs once per frame
################################################################################

.include "Common/Common.s"
.include "Online/Online.s"

.set REG_ZERO, 28
.set REG_INPUTS, 27
.set REG_MSRB_ADDR, 26
.set REG_TXB_ADDR, 25
.set REG_CSSDT_ADDR, 24

.set DISCONNECT_HOLD_DELAY, 0x30 # stock: disconnect when held >48 frames

# Deal with replaced codeline
beq+ START
# The VS input branch differs from the single-player branch. Native local CSS
# always runs our aggregate readiness gate, even when stock Start was masked.
backup
getMinorMajor r3
cmpwi r3, SCENE_ONLINE_CSS
bne NATIVE_START_NOT_ACTIVE
loadwz r3, CSSDT_BUF_ADDR
lbz r3, CSSDT_LOCAL_TEAMS_STATUS + LTS_NATIVE(r3)
cmpwi r3, 0
beq NATIVE_START_NOT_ACTIVE
restore
b START
NATIVE_START_NOT_ACTIVE:
restore
branch r12, 0x80263334

START:
backup

# Ensure that this is an online CSS
getMinorMajor r3
cmpwi r3, SCENE_ONLINE_CSS
bne EXIT # If not online CSS, continue as normal

################################################################################
# Init
################################################################################
mr REG_INPUTS, r7
loadwz REG_CSSDT_ADDR, CSSDT_BUF_ADDR
lwz REG_MSRB_ADDR, CSSDT_MSRB_ADDR(REG_CSSDT_ADDR) # Load where buf is stored
li REG_ZERO, 0 # set to zero just in case :)

################################################################################
# Play sound on lock-in state 1 -> 0 transition
################################################################################
lbz r3, CSSDT_PREV_LOCK_IN_STATE(REG_CSSDT_ADDR)
lbz r4, MSRB_IS_LOCAL_PLAYER_READY(REG_MSRB_ADDR)
stb r4, CSSDT_PREV_LOCK_IN_STATE(REG_CSSDT_ADDR) # Change previous value
cmpwi r3, 1
bne LOCK_IN_RESET_CHECK_END
cmpwi r4, 0
bne LOCK_IN_RESET_CHECK_END

# If we get here, we transitioned from locked-in to not locked-in, play the sound
b PLAY_BACK_SOUND_ON_RESET
LOCK_IN_RESET_CHECK_END:

################################################################################
# Handle connection state sounds
################################################################################
lbz r3, CSSDT_PREV_CONNECTED_STATE(REG_CSSDT_ADDR)
lbz r4, MSRB_CONNECTION_STATE(REG_MSRB_ADDR)
stb r4, CSSDT_PREV_CONNECTED_STATE(REG_CSSDT_ADDR) # Change previous value

################################################################################
# Play "error" sound on connection state transition ANY -> ERROR
################################################################################
cmpwi r3, MM_STATE_ERROR_ENCOUNTERED
beq ERR_STATE_CHECK_END
cmpwi r4, MM_STATE_ERROR_ENCOUNTERED
bne ERR_STATE_CHECK_END

b PLAY_ERROR_SOUND_ON_ERROR
ERR_STATE_CHECK_END:

################################################################################
# Play "back" sound on connection state transition CONNECTED -> ANY
################################################################################
# Check to see if connection was cleared
cmpwi r3, MM_STATE_CONNECTION_SUCCESS
bne CONN_RESET_CHECK_END
cmpwi r4, MM_STATE_CONNECTION_SUCCESS
beq CONN_RESET_CHECK_END # If still success, no sound

b PLAY_BACK_SOUND_ON_RESET
CONN_RESET_CHECK_END:
b SOUND_PLAY_END

PLAY_BACK_SOUND_ON_RESET:
# Play "back" sound
li	r3, 0
b PLAY_SOUND

PLAY_ERROR_SOUND_ON_ERROR:
# Play "error" sound
li	r3, 3

PLAY_SOUND:
branchl r12, SFX_Menu_CommonSound

SOUND_PLAY_END:

lbz r3, CSSDT_LOCAL_TEAMS_STATUS + LTS_NATIVE(REG_CSSDT_ADDR)
cmpwi r3, 0
bne NATIVE_TEAMS_HANDLE

# Local teams owns Start/search/ready when enabled. The picker remains P1.
lbz r3, CSSDT_LOCAL_TEAMS_STATUS(REG_CSSDT_ADDR)
cmpwi r3, 0
beq LOCAL_TEAMS_STOCK_CSS
rlwinm. r0, REG_INPUTS, 0, 0x10
beq LOCAL_TEAMS_NO_CANCEL
bl FN_RESET_CONNECTIONS
b SKIP_START_MATCH
LOCAL_TEAMS_NO_CANCEL:
lbz r3, CSSDT_LOCAL_TEAMS_STATUS + 5(REG_CSSDT_ADDR)
cmpwi r3, 0 # selecting
beq LOCAL_TEAMS_SELECT
cmpwi r3, 5 # waiting for the native room-code entry callback
beq LOCAL_TEAMS_ENTER_CODE
b CHECK_SHOULD_START_MATCH
LOCAL_TEAMS_SELECT:
lbz r3, CSSDT_LOCAL_TEAMS_STATUS + 6(REG_CSSDT_ADDR)
cmpwi r3, 0
beq SKIP_START_MATCH
rlwinm. r0, REG_INPUTS, 0, 19, 19
beq SKIP_START_MATCH
loadGlobalFrame r3
cmpwi r3, 0
beq SKIP_START_MATCH
lbz r3, -0x49A9(r13)
cmpwi r3, 0
beq SKIP_START_MATCH
# Local teams proposes its stage directly, including on rematches. Preserve the
# stock first-match scene routing; an uninitialized zero means "previous loser"
# and sends us to SSS without having installed its stage-selection callback.
li r3, ISWINNER_NULL
stb r3, OFST_R13_ISWINNER(r13)
stb REG_ZERO, OFST_R13_CHOSESTAGE(r13)
li r3, 0x1F # fixed Battlefield proposal
bl FN_TX_LOCK_IN
# Only the last local confirmation opens normal Slippi code entry. Rematches
# keep the existing room. The explicit localhost fixture starts without a code.
lbz r3, CSSDT_LOCAL_TEAMS_STATUS + 2(REG_CSSDT_ADDR)
addi r3, r3, 1
lbz r4, CSSDT_LOCAL_TEAMS_STATUS + 1(REG_CSSDT_ADDR)
cmpw r3, r4
bne SKIP_START_MATCH
lbz r3, CSSDT_LOCAL_TEAMS_STATUS + 8(REG_CSSDT_ADDR)
cmpwi r3, 0
bne SKIP_START_MATCH
lbz r3, MSRB_CONNECTION_STATE(REG_MSRB_ADDR)
cmpwi r3, MM_STATE_CONNECTION_SUCCESS
beq SKIP_START_MATCH
bl FN_LOAD_CODE_ENTRY
b SKIP_START_MATCH
LOCAL_TEAMS_ENTER_CODE:
# A cancelled code-entry screen leaves all saved choices intact. A fresh Start
# reopens it; Z still cancels the whole local group.
lbz r3, CSSDT_LOCAL_TEAMS_STATUS + 6(REG_CSSDT_ADDR)
cmpwi r3, 0
beq SKIP_START_MATCH
rlwinm. r0, REG_INPUTS, 0, 19, 19
beq SKIP_START_MATCH
bl FN_LOAD_CODE_ENTRY
b SKIP_START_MATCH
NATIVE_TEAMS_HANDLE:
lbz r3, -0x49aa(r13)
cmpwi r3, 0
bne SKIP_START_MATCH # native keyboard is operating
# Stock: Z press cancels a search/error; connected lobbies require >48 held
# frames. Separate timers prevent one local inheriting another's partial hold.
lbz r3, MSRB_CONNECTION_STATE(REG_MSRB_ADDR)
cmpwi r3, MM_STATE_CONNECTION_SUCCESS
beq NATIVE_TEAMS_HOLD_DISCONNECT
li r3, 0
stw r3, CSSDT_NATIVE_Z_TIMERS(REG_CSSDT_ADDR)
rlwinm. r0, REG_INPUTS, 0, 0x10
beq NATIVE_TEAMS_NO_CANCEL
bl FN_RESET_CONNECTIONS
b SKIP_START_MATCH
NATIVE_TEAMS_HOLD_DISCONNECT:
li r20, 0
NATIVE_TEAMS_Z_PLAYER:
mr r3, r20 # HSD pads are already mapped to logical local ports
branchl r12, Inputs_GetPlayerHeldInputs
addi r21, REG_CSSDT_ADDR, CSSDT_NATIVE_Z_TIMERS
rlwinm. r0, r4, 0, 0x10
beq NATIVE_TEAMS_Z_RELEASED
lbzx r3, r21, r20
addi r3, r3, 1
stbx r3, r21, r20
cmpwi r3, DISCONNECT_HOLD_DELAY
ble NATIVE_TEAMS_Z_NEXT
li r3, 0
stw r3, CSSDT_NATIVE_Z_TIMERS(REG_CSSDT_ADDR)
bl FN_RESET_CONNECTIONS
b SKIP_START_MATCH
NATIVE_TEAMS_Z_RELEASED:
li r3, 0
stbx r3, r21, r20
NATIVE_TEAMS_Z_NEXT:
addi r20, r20, 1
lbz r3, CSSDT_LOCAL_TEAMS_STATUS + 1(REG_CSSDT_ADDR)
cmpw r20, r3
blt NATIVE_TEAMS_Z_PLAYER
NATIVE_TEAMS_NO_CANCEL:
lbz r3, CSSDT_LOCAL_TEAMS_STATUS + 5(REG_CSSDT_ADDR)
cmpwi r3, 5
beq NATIVE_TEAMS_REOPEN_CODE
cmpwi r3, 0
bne CHECK_SHOULD_START_MATCH
loadGlobalFrame r3
cmpwi r3, 0
beq SKIP_START_MATCH
li r20, 0
NATIVE_TEAMS_READY_PLAYER:
li r21, 1
slw r21, r21, r20
lbz r3, CSSDT_LOCAL_TEAMS_STATUS + 4(REG_CSSDT_ADDR)
and. r3, r3, r21
bne NATIVE_TEAMS_READY_NEXT
lbz r3, CSSDT_LOCAL_TEAMS_STATUS + LTS_ARMED(REG_CSSDT_ADDR)
lbz r4, CSSDT_LOCAL_TEAMS_STATUS + LTS_START_HELD(REG_CSSDT_ADDR)
and r3, r3, r4
and. r3, r3, r21
beq NATIVE_TEAMS_READY_NEXT
# The player's own token must be placed, with a valid character.
load r3, 0x804A0BD0
slwi r4, r20, 2
lwzx r3, r3, r4
cmpwi r3, 0
beq NATIVE_TEAMS_READY_NEXT
lbz r3, 5(r3)
cmpwi r3, 0
bne NATIVE_TEAMS_READY_NEXT
lwz r3, -0x49f0(r13)
mulli r4, r20, 0x24
add r3, r3, r4
lbz r3, 0x70(r3)
cmplwi r3, 26
bge NATIVE_TEAMS_READY_NEXT
mr r3, r20
bl FN_TX_NATIVE_PICK
lbz r3, CSSDT_LOCAL_TEAMS_STATUS + 4(REG_CSSDT_ADDR)
or r3, r3, r21
stb r3, CSSDT_LOCAL_TEAMS_STATUS + 4(REG_CSSDT_ADDR)
li r3, ISWINNER_NULL
stb r3, OFST_R13_ISWINNER(r13)
li r3, 0
stb r3, OFST_R13_CHOSESTAGE(r13)
NATIVE_TEAMS_READY_NEXT:
addi r20, r20, 1
lbz r3, CSSDT_LOCAL_TEAMS_STATUS + 1(REG_CSSDT_ADDR)
cmpw r20, r3
blt NATIVE_TEAMS_READY_PLAYER
li r4, 1
slw r4, r4, r3
subi r4, r4, 1
lbz r3, CSSDT_LOCAL_TEAMS_STATUS + 4(REG_CSSDT_ADDR)
cmpw r3, r4
bne SKIP_START_MATCH
lbz r3, MSRB_CONNECTION_STATE(REG_MSRB_ADDR)
cmpwi r3, MM_STATE_CONNECTION_SUCCESS
beq CHECK_SHOULD_START_MATCH
li r3, 5
stb r3, CSSDT_LOCAL_TEAMS_STATUS + 5(REG_CSSDT_ADDR)
bl FN_LOAD_CODE_ENTRY
b SKIP_START_MATCH
NATIVE_TEAMS_REOPEN_CODE:
lbz r3, CSSDT_LOCAL_TEAMS_STATUS + LTS_ARMED(REG_CSSDT_ADDR)
lbz r4, CSSDT_LOCAL_TEAMS_STATUS + LTS_START_HELD(REG_CSSDT_ADDR)
and r3, r3, r4
andi. r3, r3, 1 # only the primary operates room entry
beq SKIP_START_MATCH
bl FN_LOAD_CODE_ENTRY
b SKIP_START_MATCH
LOCAL_TEAMS_STOCK_CSS:
################################################################################
# Fork logic based on current connection state
################################################################################
lbz r3, MSRB_CONNECTION_STATE(REG_MSRB_ADDR)
cmpwi r3, MM_STATE_IDLE
ble HANDLE_IDLE
cmpwi r3, MM_STATE_OPPONENT_CONNECTING
ble HANDLE_FINDING
cmpwi r3, MM_STATE_CONNECTION_SUCCESS
beq HANDLE_CONNECTED
cmpwi r3, MM_STATE_ERROR_ENCOUNTERED
beq HANDLE_ERROR

b SKIP_START_MATCH

################################################################################
# Case 1: Handle idle case
################################################################################
HANDLE_IDLE:

# Prevent CSS Actions if chat window is opened
lbz r3, CSSDT_CHAT_WINDOW_OPENED(REG_CSSDT_ADDR)
cmpwi r3, 0
bne SKIP_START_MATCH # skip input if chat window is opened

# When idle, pressing start will start finding match
# Check if start was pressed
rlwinm.	r0, REG_INPUTS, 0, 19, 19
beq SKIP_START_MATCH # Exit if start was not pressed

# Sometimes when returning to the CSS, previously held buttons will stay held,
# including start. This prevents the start input from locking people in
# immediately... Doesn't feel like this should be necessary, and if it is,
# this doesn't feel like the right place for this logic
loadGlobalFrame r3
cmpwi r3, 0
beq SKIP_START_MATCH # Don't search on very first frame

# Initialize ISWINNER (first match)
li  r3, ISWINNER_NULL
stb r3, OFST_R13_ISWINNER (r13)
# Init CHOSESTAGE bool
li r3,  0
stb r3, OFST_R13_CHOSESTAGE (r13)

# Check if character has been selected, if not, do nothing
lbz r3, -0x49A9(r13)
cmpwi r3, 0
beq SKIP_START_MATCH

# Check which mode we are playing. direct mode should launch text entry
lbz r3, OFST_R13_ONLINE_MODE(r13)
cmpwi r3, ONLINE_MODE_RANKED
beq HANDLE_IDLE_UNRANKED
cmpwi r3, ONLINE_MODE_UNRANKED
beq HANDLE_IDLE_UNRANKED
cmpwi r3, ONLINE_MODE_PARTY
beq HANDLE_IDLE_UNRANKED
cmpwi r3, ONLINE_MODE_DIRECT
beq HANDLE_IDLE_DIRECT
cmpwi r3, ONLINE_MODE_TEAMS
beq HANDLE_IDLE_DIRECT
b 0x0

HANDLE_IDLE_UNRANKED:
li  r3, SB_RAND     # stages in unranked are always random
bl FN_LOCK_IN_AND_SEARCH # lock in and trigger matchmaking
b SKIP_START_MATCH

HANDLE_IDLE_DIRECT:
bl FN_LOAD_CODE_ENTRY # load text code entry
b SKIP_START_MATCH

################################################################################
# Case 2: Handle case where search is underway
################################################################################
HANDLE_FINDING:

# Handle cancel
rlwinm.	r0, REG_INPUTS, 0, 0x10
bnel FN_RESET_CONNECTIONS

b SKIP_START_MATCH

################################################################################
# Case 3: Handle case where we have an opponent
################################################################################
HANDLE_CONNECTED:

# Handle disconnect when input is hold for X seconds
lbz r3, -0x49B0(r13) # player index in control of CSS
branchl r12, Inputs_GetPlayerHeldInputs
rlwinm. r0, r4, 0, 0x10
beq RESET_HOLD_TIMER # if button is no longer pressed, reset hold timer

# increase time holding Z
lbz r3, CSSDT_Z_BUTTON_HOLD_TIMER(REG_CSSDT_ADDR)
addi r3, r3, 1
stb r3, CSSDT_Z_BUTTON_HOLD_TIMER(REG_CSSDT_ADDR)

# skip disconnect if hold time is less than delay
cmpwi r3, DISCONNECT_HOLD_DELAY
ble SKIP_DISCONNECT

# reset disconnect hold timer when disconnecting
stb REG_ZERO, CSSDT_Z_BUTTON_HOLD_TIMER(REG_CSSDT_ADDR)
bl FN_RESET_CONNECTIONS
b SKIP_START_MATCH
RESET_HOLD_TIMER:
stb REG_ZERO, CSSDT_Z_BUTTON_HOLD_TIMER(REG_CSSDT_ADDR)
SKIP_DISCONNECT:

# Handle case where we are not yet locked-in
lbz r3, MSRB_IS_LOCAL_PLAYER_READY(REG_MSRB_ADDR)
cmpwi r3, 0
bne CHECK_SHOULD_START_MATCH

# Check if start is pressed to see whether we should lock in
rlwinm.	r0, REG_INPUTS, 0, 19, 19
bne HANDLE_CONNECTED_ADVANCE

# Check if direct mode && loser && already chose stage
lbz r3, OFST_R13_ONLINE_MODE(r13)
cmpwi r3, ONLINE_MODE_DIRECT
beq HANDLE_CONNECTED_CHECK_LOSER_FOR_STAGE
cmpwi r3, ONLINE_MODE_TEAMS
bne CHECK_SHOULD_START_MATCH
HANDLE_CONNECTED_CHECK_LOSER_FOR_STAGE:
lbz r3, OFST_R13_ISWINNER (r13)
cmpwi r3,ISWINNER_LOST              # Check if this is the loser
bne CHECK_SHOULD_START_MATCH
lbz r3, OFST_R13_CHOSESTAGE (r13)
cmpwi r3,1                          # Check if loser picked stage already
bne CHECK_SHOULD_START_MATCH
b HANDLE_CONNECTED_ADVANCE

HANDLE_CONNECTED_ADVANCE:
# Check if character has been selected, if not, do nothing
lbz r3, -0x49A9(r13)
cmpwi r3, 0
beq CHECK_SHOULD_START_MATCH

# Sometimes when returning to the CSS, previously held buttons will stay held,
# including start. This prevents the start input from locking people in
# immediately... Doesn't feel like this should be necessary, and if it is,
# this doesn't feel like the right place for this logic
loadGlobalFrame r3
cmpwi r3, 0
beq CHECK_SHOULD_START_MATCH # Don't lock-in on the very first frame

# Check which mode we are playing.
lbz r3, OFST_R13_ONLINE_MODE(r13)
cmpwi r3, ONLINE_MODE_UNRANKED
beq HANDLE_CONNECTED_UNRANKED
cmpwi r3, ONLINE_MODE_PARTY
beq HANDLE_CONNECTED_UNRANKED
cmpwi r3, ONLINE_MODE_DIRECT
beq HANDLE_CONNECTED_DIRECT
cmpwi r3, ONLINE_MODE_TEAMS
beq HANDLE_CONNECTED_DIRECT
b 0x0                           # stall if neither

# Branch to this mode's behavior
HANDLE_CONNECTED_UNRANKED:
li  r3, SB_RAND       # stages always random for unranked
bl FN_TX_LOCK_IN
b CHECK_SHOULD_START_MATCH
HANDLE_CONNECTED_DIRECT:
# Loser picks the stage
lbz r3, OFST_R13_ISWINNER (r13)
cmpwi r3,ISWINNER_LOST
beq HANDLE_CONNECTED_DIRECT_ISLOSER
# Winner is unselected
cmpwi r3,ISWINNER_WON
beq HANDLE_CONNECTED_DIRECT_ISWINNER
b 0x0

HANDLE_CONNECTED_DIRECT_ISWINNER:
li  r3, SB_NOTSEL       # lock in, use opponents stage
bl FN_TX_LOCK_IN
b CHECK_SHOULD_START_MATCH

HANDLE_CONNECTED_DIRECT_ISLOSER:
# Check if loser picked stage already
lbz r3, OFST_R13_CHOSESTAGE (r13)
cmpwi r3,0
beq HANDLE_CONNECTED_DIRECT_LOADSSS
HANDLE_CONNECTED_DIRECT_SENDSTAGE:
# Send selected stage
lwz	r3, -0x77C0 (r13)
addi	r3, r3, 1424 + 0x8   # adding 0x8 to skip past some scene state stuff
lhz r3, 0x1E (r3)
bl FN_TX_LOCK_IN
b CHECK_SHOULD_START_MATCH
HANDLE_CONNECTED_DIRECT_LOADSSS:
# Set teams on/off bit. This is required by the "disable fod during doubles" gecko code
lbz r4, OFST_R13_ONLINE_MODE(r13)
cmpwi r4, ONLINE_MODE_TEAMS
li r3, 0
bne SET_TEAMS_BOOL
li r3, 1
SET_TEAMS_BOOL:
lwz	r4, -0x49F0(r13)
stb r3, 0x18(r4)
# Request scene change
li  r3,1
stb	r3, -0x49AA (r13)
# Set lock in callback function
bl FN_TX_LOCK_IN_BLRL
mflr r3
stw r3, OFST_R13_CALLBACK(r13)
b SKIP_START_MATCH

# Check to see if both players are ready and start match if they are
CHECK_SHOULD_START_MATCH:

lbz r3, MSRB_IS_LOCAL_PLAYER_READY(REG_MSRB_ADDR)
lbz r4, MSRB_IS_REMOTE_PLAYER_READY(REG_MSRB_ADDR)
and. r3, r3, r4
beq SKIP_START_MATCH # If not both players are ready, skip

# Native local Teams is ready according to Slippi, not offline VS's team count.
# The stock continuation at 0x80263264 rejects same-team local selections and
# plays the error sound every frame instead of requesting the scene change.
lbz r3, CSSDT_LOCAL_TEAMS_STATUS + LTS_NATIVE(REG_CSSDT_ADDR)
cmpwi r3, 0
beq START_MATCH_STOCK
restore
branch r12, 0x80263270

START_MATCH_STOCK:
restore
branch r12, 0x80263264

################################################################################
# Case 4: Handle case where we have not locked-in
################################################################################
HANDLE_ERROR:

# Handle cancel
rlwinm.	r0, REG_INPUTS, 0, 0x10
bnel FN_RESET_CONNECTIONS

b SKIP_START_MATCH

################################################################################
# Function: Start find match
################################################################################
FN_TX_FIND_MATCH_BLRL:
blrl
FN_TX_FIND_MATCH:
backup

# Prevent a cached EnteringCode status / held keyboard Start from reopening it.
loadwz r3, CSSDT_BUF_ADDR
lbz r4, CSSDT_LOCAL_TEAMS_STATUS(r3)
cmpwi r4, 0
beq FN_TX_FIND_MATCH_STATUS_READY
li r4, 1 # Searching; the next poll replaces this with the backend result
stb r4, CSSDT_LOCAL_TEAMS_STATUS + 5(r3)
li r4, 0
stb r4, CSSDT_LOCAL_TEAMS_STATUS + 6(r3)
stb r4, CSSDT_LOCAL_TEAMS_STATUS + LTS_ARMED(r3)
stb r4, CSSDT_LOCAL_TEAMS_STATUS + LTS_START_HELD(r3)
FN_TX_FIND_MATCH_STATUS_READY:

# When the player starts looking for a match is a good time to reset the game index
loadwz r3, 0x803dad40 # Load minor scene data array ptr
lwz r12, 0x88(r3) # Load game prep minor scene data
li r3, 0
sth r3, GPDO_CUR_GAME(r12)
stb r3, GPDO_TIEBREAK_GAME_NUM(r12)

# Prepare buffer for EXI transfer
li r3, FMTB_SIZE
branchl r12, HSD_MemAlloc
mr REG_TXB_ADDR, r3

# Write tx data
li r3, CONST_SlippiCmdFindOpponent
stb r3, FMTB_CMD(REG_TXB_ADDR)

# Write online mode
lbz r3, OFST_R13_ONLINE_MODE(r13)
stb r3, FMTB_ONLINE_MODE(REG_TXB_ADDR)

# Write opp connect code, only matters for direct mode
addi r7, REG_TXB_ADDR, FMTB_OPP_CONNECT_CODE
load r6, 0x804a0740
li r4, 0
li r5, 0

WRITE_OPP_CODE_LOOP_START:
lhzx r3, r6, r4
sthx r3, r7, r5
addi r4, r4, 3
addi r5, r5, 2
cmpwi r5, 18
blt WRITE_OPP_CODE_LOOP_START

# Start finding opponent
mr r3, REG_TXB_ADDR
li r4, FMTB_SIZE
li r5, CONST_ExiWrite
branchl r12, FN_EXITransferBuffer

mr r3, REG_TXB_ADDR
branchl r12, HSD_Free

restore
blr

################################################################################
# Function: Lock in character selection
# r3 = stage behavior.
#     -2 = random stage
#     -1 = unselected (use opponents stage)
#      0+ = specify stage ID.
################################################################################
FN_TX_NATIVE_PICK:
backup
mr r31, r3 # logical local player, independent of the menu-entering controller
li r3, PSTB_SIZE
branchl r12, HSD_MemAlloc
mr r30, r3
li r4, PSTB_SIZE
branchl r12, Zero_AreaLength
li r3, CONST_LocalTeamsConfirm
stb r3, PSTB_CMD(r30)
lwz r29, -0x49f0(r13)
mulli r3, r31, 0x24
add r29, r29, r3
lbz r3, 0x70(r29)
stb r3, PSTB_CHAR_ID(r30)
lbz r3, 0x73(r29)
stb r3, PSTB_CHAR_COLOR(r30)
lbz r3, 0x79(r29)
stb r3, PSTB_TEAM_ID(r30)
li r3, 1
stb r3, PSTB_CHAR_OPT(r30)
stb r3, PSTB_STAGE_OPT(r30)
li r3, 0x1f
sth r3, PSTB_STAGE_ID(r30)
ori r3, r31, 0x80 # private C6 discriminant, stock Slippi wire format unchanged
stb r3, PSTB_ONLINE_MODE(r30)
computeBranchTargetAddress r3, INJ_FREEZE_STADIUM
lbz r3, 8(r3)
stb r3, PSTB_ALT_STAGE_MODE(r30)
mr r3, r30
li r4, PSTB_SIZE
li r5, CONST_ExiWrite
branchl r12, FN_EXITransferBuffer
mr r3, r30
branchl r12, HSD_Free
restore
blr

FN_TX_LOCK_IN_BLRL:
blrl
FN_TX_LOCK_IN:
.set  REG_SB, 31    # stage behavior
backup

# Backup stage behavior
mr  REG_SB,r3

# Prepare buffer for EXI transfer
li r3, PSTB_SIZE
branchl r12, HSD_MemAlloc
mr REG_TXB_ADDR, r3

# Write tx data
li r3, CONST_SlippiCmdSetMatchSelections
loadwz r4, CSSDT_BUF_ADDR
lbz r4, CSSDT_LOCAL_TEAMS_STATUS(r4)
cmpwi r4, 0
beq LOCAL_TEAMS_SET_SELECTION_CMD
li r3, CONST_LocalTeamsConfirm
LOCAL_TEAMS_SET_SELECTION_CMD:
stb r3, PSTB_CMD(REG_TXB_ADDR)

# Fetch selected character information
lwz r4, -0x49f0(r13) # base address where css selections are stored
lbz r3, -0x5108(r13) # player index
mulli r3, r3, 0x24
add r4, r4, r3

lbz r3, 0x70(r4) # load char id
stb r3, PSTB_CHAR_ID(REG_TXB_ADDR)
lbz r3, 0x73(r4) # load char color
stb r3, PSTB_CHAR_COLOR(REG_TXB_ADDR)
li r3, 1 # merge character
stb r3, PSTB_CHAR_OPT(REG_TXB_ADDR)

# Send a blank team ID if this isn't teams mode.
lbz r3, OFST_R13_ONLINE_MODE(r13)
cmpwi r3, ONLINE_MODE_TEAMS
beq SEND_TEAM_ID
li r3, 0
stb r3, PSTB_TEAM_ID(REG_TXB_ADDR)
b SKIP_SEND_TEAM_ID

SEND_TEAM_ID:
# Calc/Set Team ID
loadwz r3, CSSDT_BUF_ADDR
lbz r3, CSSDT_TEAM_IDX(r3)
subi r3, r3, 1
stb r3, PSTB_TEAM_ID(REG_TXB_ADDR)

SKIP_SEND_TEAM_ID:
# Handle stage
cmpwi REG_SB, -2
beq FN_TX_LOCK_IN_STAGE_RAND
cmpwi REG_SB, -1
beq FN_TX_LOCK_IN_STAGE_UNSET
cmpwi REG_SB, 0
bge FN_TX_LOCK_IN_STAGE_PICK

FN_TX_LOCK_IN_STAGE_RAND:
li  r3,0
li  r4,3
b FN_TX_LOCK_IN_STAGE_SEND

FN_TX_LOCK_IN_STAGE_UNSET:
li  r3,0
li  r4,0
b FN_TX_LOCK_IN_STAGE_SEND

FN_TX_LOCK_IN_STAGE_PICK:
mr  r3,REG_SB
li  r4,1
b FN_TX_LOCK_IN_STAGE_SEND

FN_TX_LOCK_IN_STAGE_SEND:
sth r3, PSTB_STAGE_ID(REG_TXB_ADDR)
stb r4, PSTB_STAGE_OPT(REG_TXB_ADDR)

# Write the alt stage mode
computeBranchTargetAddress r3, INJ_FREEZE_STADIUM
addi r3, r3, 0x8
lbz r3, 0(r3)
stb r3, PSTB_ALT_STAGE_MODE(REG_TXB_ADDR)
# mr r5, r3
# logf LOG_LEVEL_WARN, "TXB: Alt Stage Mode: %x"

# Write the online mode we are in
lbz r3, OFST_R13_ONLINE_MODE(r13)
stb r3, PSTB_ONLINE_MODE(REG_TXB_ADDR)

# Indicate to Dolphin we want to lock-in
mr r3, REG_TXB_ADDR
li r4, PSTB_SIZE
li r5, CONST_ExiWrite
branchl r12, FN_EXITransferBuffer

mr r3, REG_TXB_ADDR
branchl r12, HSD_Free

restore
blr

################################################################################
# Function: Simple function to lock in and search
# r3 = stage behavior.
#     -2 = random stage
#     -1 = unselected (use opponents stage)
#      0+ = specify stage ID.
################################################################################
FN_LOCK_IN_AND_SEARCH_BLRL:
blrl
FN_LOCK_IN_AND_SEARCH:
backup

lbz r20, CSSDT_TEAM_IDX(REG_CSSDT_ADDR)
# logf LOG_LEVEL_NOTICE, "TEAM INDEX AFTER %d", "mr r5, 20"

bl FN_TX_LOCK_IN # Lock in character selection
bl FN_TX_FIND_MATCH # Trigger matchmaking

restore
blr

################################################################################
# Function: Load code entry
################################################################################
FN_LOAD_CODE_ENTRY:
backup

li r3, 0
stb r3, CSSDT_LOCAL_TEAMS_STATUS + 6(REG_CSSDT_ADDR)
stb r3, CSSDT_LOCAL_TEAMS_STATUS + LTS_ARMED(REG_CSSDT_ADDR)
stb r3, CSSDT_LOCAL_TEAMS_STATUS + LTS_START_HELD(REG_CSSDT_ADDR)

# Indicate we want name entry to operate in connect code mode
li r3, 1
stb r3, OFST_R13_NAME_ENTRY_MODE(r13)

# Prepare callback address on successful name entry
lbz r3, CSSDT_LOCAL_TEAMS_STATUS(REG_CSSDT_ADDR)
cmpwi r3, 0
beq FN_LOAD_CODE_ENTRY_STOCK_CALLBACK
bl FN_TX_FIND_MATCH_BLRL
b FN_LOAD_CODE_ENTRY_SET_CALLBACK
FN_LOAD_CODE_ENTRY_STOCK_CALLBACK:
bl FN_LOCK_IN_AND_SEARCH_BLRL
FN_LOAD_CODE_ENTRY_SET_CALLBACK:
mflr r3
stw r3, OFST_R13_CALLBACK(r13)

# Set the player index controlling name entry
lbz r0, -0x49b0(r13)
stb r0, -0x49a7(r13)

# Start process to load name entry
li r0, 4
stb r0, -0x49aa(r13)

restore
blr

################################################################################
# Function: Reset connections and clear lock-in state
################################################################################
FN_RESET_CONNECTIONS:
backup

# Prepare buffer for EXI transfer
li r3, 1
branchl r12, HSD_MemAlloc
mr REG_TXB_ADDR, r3

# Write tx data
li r3, CONST_SlippiCmdCleanupConnections
stb r3, 0(REG_TXB_ADDR)

# Reset connections
mr r3, REG_TXB_ADDR
li r4, 1
li r5, CONST_ExiWrite
branchl r12, FN_EXITransferBuffer

mr r3, REG_TXB_ADDR
branchl r12, HSD_Free

restore
blr


################################################################################
# Skip starting match
################################################################################
SKIP_START_MATCH:
restore
branch r12, 0x80263334

EXIT:
restore
