# ADB joystick support — plan

Status: plan only, nothing implemented (2026-09-30).

Goal: let a MiSTer controller (gamepad, flight stick) drive 68k Mac games on
the Quadra 800 core **while the normal mouse and keyboard keep working** —
mouse to drive the Finder, joystick in the game, both plugged in at once,
the way a real Mac user ran an Apple mouse and a Gravis stick on the same
ADB chain.

## Background

- The Quadra 800 has no game port. Every period Mac joystick is an ADB
  device, so joystick support means adding an ADB device to `rtl/adb.sv`.
- Apple's InputSprocket (Game Sprockets) is PowerPC-only, so on a 68040
  games talk to joysticks through the vendor's driver (Gravis control
  panel, ThrustMaster, CH ...) or through keyboard/mouse emulation.
- Neither MAME (`src/mame/apple/macadb.cpp`, `src/devices/bus/adb/`: keyboard
  and mouse only) nor Basilisk II (`BasiliskII/src/adb.cpp`: keyboard and a
  handler 1/2/4 mouse; cebix/macemu issue #142 is the open joystick request)
  emulates an ADB joystick. Basilisk users map the controller to keys and
  mouse on the host with JoyToKey / AntiMicroX.
- The protocol source is lampmerchant's **tashnotes**
  (`macintosh/adb/protocols/*.md`, `macintosh/adb/device_list.md`), captured
  from real devices. Summary of the game controllers:

| device | default addr | handler (plug-in -> driver) | Talk 0 | Talk 1 |
|---|---|---|---|---|
| Gravis Mac GamePad | 2 | 0x02 (acts as Extended Keyboard: D-pad = arrows) -> **0x34** | 2 bytes: 4 buttons, D-pad, mode switch, active-low | `03 00` |
| Gravis MouseStick II | 3 | 0x01 (plain mouse) -> **0x23** | 7 bytes: mouse word, X s16, Y s16 (about ±600), buttons byte | `03 00` (7-byte format) / `04 00` (3-byte) |
| Gravis Blackhawk | 3 | 0x01 -> **0x4E** (also answers 0x23) | 8 bytes: X, Y, throttle 0x00-0xFF, 4 buttons | `0A 06 01` |
| Gravis Firebird | 3 | 0x01 -> **0x4E** (also answers 0x23) | 8 bytes: X, Y, throttle, trim, rudder(?) 0x00-0xFF, hat, 13 buttons | `0A 01 30` |
| MS SideWinder 3D Pro | 3 (mouse) + 4 | 0x5D at addr 4 | 7 bytes: 10-bit X/Y/throttle, 9-bit twist, 8-way hat, 8 buttons | — |
| MacAlly JoyStick | 5 | 0x03 fixed | 5 bytes: 10-bit X/Y, 2 buttons | mode reg: `55 55` mouse / `AA AA` joystick |

All buttons are active-low (0 = pressed). "Handler -> driver" means the
driver issues Listen 3 with the new handler ID; a device that does not
support an ID ignores it, so the driver can probe by writing and reading back
with Talk 3.

## Stage 0 — no RTL: Main's controller mapping

MiSTer Main already does what JoyToKey does for Basilisk II:
`mouse_emu` in `Main_MiSTer/input.cpp` (a mapped button turns the stick into
the mouse) and the per-core joystick-to-keyboard map
(`MacQuadra800_input_<id>_jk.map`). Try this on hardware first and write down
what it does not do (it is rate control, needs a mode toggle, no dead-zone
or sensitivity). That list is the justification for stages 1-3.

## Design decision: a second ADB device, not a replacement mouse

Earlier notes suggested turning our address-3 mouse into a MouseStick II
(its 7-byte report even carries a mouse-delta word). **Don't.** The user
wants the real mouse for the Finder and the stick in the game, and a merged
device has two problems:

- Before the Gravis driver loads, a MouseStick at handler 0x01 *is* the mouse,
  so the merge is invisible — but once the driver switches it to 0x23 the
  control panel owns the whole report. What it does with the mouse word
  under a per-game "joystick" setting is undocumented; it may suppress or
  remap it, and the real mouse would stop working in exactly the games we
  care about.
- It cannot extend to the GamePad (address 2) or a second stick.

So the joystick is its **own ADB device**, exactly as on real hardware. The
Apple mouse stays at address 3 / handler 1 (later handler 4, stage 1b); the
emulated Gravis stick also powers up at address 3 / handler 1. That makes the
one piece of real ADB behaviour our model skips mandatory: **address
collision resolution**.

### How the Mac separates two devices on one address

At ADBReInit the ADB Manager, for each address:

1. Talk 3 to address A. Every device at A answers at once; on the wire they
   collide, one wins, the losers *notice the collision* and set a flag.
2. Listen 3 to A with handler byte 0xFE and a free address B ("move only if
   you did not detect a collision"). The winner moves to B; losers clear
   their flag and stay.
3. Repeat Talk 3 to A until nobody answers; the last device moved is moved
   back to A.

After this every device has a unique address and the Manager's table
remembers each one's *original* address (3), so the stock mouse driver
('ADBS' for address 3) drives both. That matters for stage 1: **in handler
0x01 mode the emulated stick must stay quiet** (no Talk 0 data unless the
OSD option asks for it), or the Mac would see two mice fighting.

The Gravis control panel then walks the ADB table, finds devices whose
original address is 3, tries Listen 3 handler 0x23 on each and keeps the one
that accepts (Talk 3 reads back 0x23). The Apple mouse ignores 0x23 because
it only accepts 0x01 (0x04 after stage 1b), so the probe picks out the stick.

## Changes to `rtl/adb.sv`

1. **Device table.** Today the keyboard and mouse are two hand-written
   branches (`cmd_addr == kbd_addr`, `cmd_addr == mouse_addr`). Add a third
   (and later a fourth) with per-device `addr`, `handler`, `collided`,
   `srq_en`, `has_data`, and route commands to *all* devices that match
   `cmd_addr`, not the first.
2. **Collision emulation** on Talk 3 / Listen 3 0xFE (pseudocode below).
   Winner rule: lowest index (keyboard, mouse, joystick, gamepad). The
   loser's `collided` flag is cleared by the next Listen 3 or Talk 3 it sees.
3. **Handler switching.** Listen 3 per the ADB spec: 0xFE = move if not
   collided, 0x00 = move / set SRQ-enable, other values = switch handler if
   the device supports it, else ignore. Today the mouse and keyboard only
   honour 0xFE; they should keep rejecting other IDs (the keyboard must not
   accept 0x34, the mouse must not accept 0x23 / 0x4E).
4. **Talk 1** per handler (table above).
5. **Longer Talk 0 replies.** `response[0:7]` and `resp_pending` already
   exist, but nothing on this core has ever returned more than 2 bytes. Prove
   7- and 8-byte replies through the VIA1 SR shim in `iosb.sv` in sim before
   anything else.
6. **SRQ policy.** The joystick raises SRQ (`has_data`) when the report it
   would send differs from the last one it sent; positions are absolute, so
   an unchanged stick does not need re-sending. `any_srq` becomes the OR of
   all devices. Whether the Gravis driver relies on SRQ or polls with its own
   `ADBOp` Talk 0 is unknown — the sim trace will say.
7. **Reset** (command type 00) returns every device to its default address
   and handler 0x01 / 0x02.

### Input plumbing

- `MacQuadra800.sv`: take `joystick_0` (D-pad in [3:0], buttons above),
  `joystick_l_analog_0` (X [7:0], Y [15:8], signed -127..+127) and
  `joystick_r_analog_0` (throttle for the Firebird format) from `hps_io`,
  and pass them through `quadra800` -> `iosb` -> `adb`.
- These are level buses from the HPS with no strobe, unlike `ps2_mouse`.
  Two-flop synchronise every bit (same `preserve` /
  `SYNCHRONIZER_IDENTIFICATION` attributes as the mouse sync in `adb.sv`) and
  only accept a new sample when two consecutive synchronised samples match,
  so a half-updated X byte is never reported.
- CONF_STR: a `J1,...` line naming the buttons (Trigger, Thumb, Top L,
  Top R, Base) plus `jn`/`jp` defaults, and an option on a free status bit
  (`O[44]` and up are unused today):
  `O[45:44],ADB joystick (on reset),Off,MouseStick II,Firebird;`
  Off must build a core that behaves exactly like today (device absent, no
  answer on any address).
- A digital-only pad (analog reads 0) synthesises full deflection from the
  D-pad.

## Pseudocode

Illustrative, not RTL: the real version stays in `adb.sv`'s style (one FSM,
`process_command` task, `response[]` / `resp_len`).

```text
# ---- per-device state -------------------------------------------------
struct Dev { addr, def_addr, handler, def_handler, collided, has_data,
             accepts: set of handler IDs, present }
KBD  = Dev(def_addr=2, def_handler=0x02, accepts={0x02})          # 0x03 later
MOU  = Dev(def_addr=3, def_handler=0x01, accepts={0x01})          # +0x04 in 1b
JOY  = Dev(def_addr=3, def_handler=0x01,
           accepts = {0x01, 0x23}            if mode == MouseStickII
                     {0x01, 0x23, 0x4E}      if mode == Firebird,
           present = (mode != Off))
DEVS = [KBD, MOU, JOY]                       # index order = collision winner

# ---- command dispatch ---------------------------------------------------
on command(cmd):
  a, type, reg = cmd.addr, cmd.type, cmd.reg
  if type == RESET:
      for d in DEVS: d.addr = d.def_addr; d.handler = d.def_handler
                     d.collided = 0; d.has_data = 0
      return
  hits = [d for d in DEVS if d.present and d.addr == a]
  if hits empty: reply nothing; return            # INT tells ROM "timeout"

  if type == TALK and reg == 3:
      winner = hits[0]
      for d in hits[1:]: d.collided = 1           # they lost on the wire
      reply { 0 exc srq_en 0 winner.addr , winner.handler }
      return

  if type == LISTEN and reg == 3:                 # data = {byte0, byte1}
      new_addr = byte0[3:0]; h = byte1
      for d in hits:
          if h == 0xFE:
              if not d.collided: d.addr = new_addr
          elif h == 0x00:
              d.addr = new_addr; d.srq_en = byte0[5]
          elif h in (0xFD, 0xFF):
              pass                                # activator / self-test
          elif h in d.accepts:
              d.handler = h
          d.collided = 0
      return

  d = hits[0]                                     # unique after ADBReInit
  if type == TALK:  reply talk(d, reg)
  if type == LISTEN: d.listen(reg, data)          # kbd LEDs etc., as today

# ---- the joystick's registers --------------------------------------------
talk(JOY, 0):
  if not JOY.has_data: reply nothing; return
  s = joy_state                                   # synchronised snapshot
  case JOY.handler:
    0x01:                                         # no driver loaded
      if osd_stick_moves_pointer:                 # optional, default off
          reply mouse_word(btn=s.trigger, dx=s.x>>3, dy=s.y>>3)
      else: reply nothing                         # stay out of the mouse's way
    0x23:                                         # MouseStick II, 7-byte format
      X = s.x * 75 / 16                           # -127..127 -> about ±600
      Y = s.y * 75 / 16
      reply [ 0x80, 0x80,                         # mouse word: btn up, dx=dy=0
              X[15:8], X[7:0], Y[15:8], Y[7:0],
              {3'b111, ~{topR, topL, trigger, bottom, top}} ]
    0x4E:                                         # Firebird 8-byte format
      reply [ 0xFE | ~base[8],  ~base[7:0],
              ~{hatL, handleUp, handleMid, hatD, hatU, trigger, handleLow, hatR},
              s.x ^ 0x80, s.y ^ 0x80,             # signed -> 0x00..0xFF
              s.throttle ^ 0x80, 0x80 /*trim*/, 0x80 /*rudder*/ ]
  JOY.last_sent = s; JOY.has_data = 0

talk(JOY, 1):
  case JOY.handler: 0x23 -> reply [0x03, 0x00]
                    0x4E -> reply [0x0A, 0x01, 0x30]
                    else -> reply nothing         # unknown: check in sim

every adb clock:
  s = sync_and_debounce(joystick_0, joystick_l_analog_0, joystick_r_analog_0)
  if s.analog == 0: s.x, s.y = dpad_to_full_deflection(s.dpad)
  if JOY.handler != 0x01 and s != JOY.last_sent: JOY.has_data = 1
  any_srq = OR(d.has_data and d.srq_en for d in DEVS)
```

Bit positions in the Firebird row follow tashnotes' table, packed MSB-first
into bytes 7..0; check them against the doc, and the sign of Y, before
writing RTL.

## Stages

| stage | what | RTL | risk |
|---|---|---|---|
| 0 | Main `mouse_emu` + `_jk.map` on hardware | none | none |
| 1a | device table + collision emulation, with the joystick present but still handler 0x01 and silent | `adb.sv` | ROM boot path: ADBReInit must still come up with a working mouse and keyboard |
| 1b | Extended Mouse (handler 0x04, 3 buttons) on the real mouse; tashnotes `mouse_handler_0x04_devices.md` | `adb.sv` | small; independent of the joystick |
| 2 | MouseStick II handler 0x23: 7-byte Talk 0, Talk 1, input plumbing, CONF_STR `J1` and the OSD option | `adb.sv`, `iosb.sv`, `quadra800.sv`, `MacQuadra800.sv` | the >2-byte reply path; unknown SRQ/poll expectations of the driver |
| 3 | Firebird/Blackhawk handler 0x4E (throttle, many buttons) | `adb.sv` | small once 2 works |
| 4 | Gravis GamePad on address 2 / 0x34 | `adb.sv` | the same collision code, now at the keyboard's address; its 0x02 mode must stay silent too |

Area: a few hundred ALMs in total. The chip is at 94 % so each stage costs
the usual 2-4 seed walk.

## Verification

1. **Directed bench** `verilator/tb_adb.sv` (none exists today): drive command
   bytes through the `st` / `adb_din` interface the way the ROM does and
   check: mouse alone at 3 (today's behaviour, bit-exact); mouse + stick at 3
   -> Talk 3 winner, Listen 3 0xFE moves only the winner, second Talk 3 finds
   the other; reset restores both; the mouse rejects 0x23; 7- and 8-byte Talk
   0 replies come out complete.
2. **Full-machine sim** (`scripts/sim_wsl.sh`) with an ADB command log (address,
   type, register, bytes) behind a `define. Boot 8.1 and confirm ADBReInit
   separates the two devices and the mouse still moves. Then install the
   Gravis control panel (Macintosh Garden / Macintosh Repository) on the sim
   disk: the log shows its probe sequence, which handler it sets, whether it
   reads Talk 1, and whether it polls or waits for SRQ. That fills the gaps
   tashnotes leaves, with no real stick needed.
3. **Hardware**: mouse and stick together in the Finder (only the mouse moves
   the pointer), the Gravis control panel sees the stick and its test view
   tracks it, then one game with Gravis support. The regression gate in
   `CLAUDE.md` still applies (8.1 and A/UX boot, shut down, CD audio).

## Open questions

- SRQ vs polling in the Gravis driver (sim trace).
- Talk 1 / Talk 2 content in handler 0x01 mode (tashnotes only gives the
  driver-mode values).
- Whether the control panel identifies the stick by Talk 1 (`03 00` vs
  `0A 01 30`) and so needs the exact model string; if so the OSD option
  picks which model we claim to be.
- Which 68k games read the Gravis driver directly, and which only use its
  keystroke mapping — the latter works as soon as the control panel works.
- The ROM's own collision handling on the Mac II-style transceiver path:
  the transceiver is dumb, so the ROM's ADB Manager does resolution as above;
  confirm in the sim log that the Quadra ROM follows the Inside Macintosh
  sequence.

## Sources

- tashnotes ADB protocols:
  <https://github.com/lampmerchant/tashnotes/tree/main/macintosh/adb/protocols>
  and device list:
  <https://github.com/lampmerchant/tashnotes/blob/main/macintosh/adb/device_list.md>
- Basilisk II ADB: <https://github.com/kanjitalk755/macemu/blob/master/BasiliskII/src/adb.cpp>;
  joystick request: <https://github.com/cebix/macemu/issues/142>
- MAME: `src/mame/apple/macadb.cpp`, `src/devices/bus/adb/` (local tree in `~/mame`)
- Game Sprockets PowerPC-only: <https://en.wikipedia.org/wiki/Game_Sprockets>
