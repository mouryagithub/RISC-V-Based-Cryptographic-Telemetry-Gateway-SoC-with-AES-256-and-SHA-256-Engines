# AES RTL ↔ LOCKED REGISTER SPECIFICATION COMPLIANCE AUDIT
## Project: RISC-V Based Cryptographic Telemetry Gateway SoC
## Audit Date: 2026-08-29
## Status: READ-ONLY AUDIT — NO RTL MODIFICATIONS MADE

---

## 1. RTL Top-Level Interface

### Module: `aes_core_top`

| Property | Value |
|---|---|
| Module name | `aes_core_top` |
| Clock input | `aclk` (1-bit) |
| Reset input | `aresetn` (1-bit) |
| Reset polarity | Active-LOW |
| Reset synchronization | Synchronous — all always blocks use `posedge aclk` only; no `negedge aresetn` in sensitivity list |
| Bus interface | AXI4-Lite slave |
| Data width | 32-bit |
| Address width | `AXI_ADDR_WIDTH` parameter, default 8 bits |
| Interrupt output | `irq` (1-bit, wire, level-driven) |

### AXI4-Lite Ports (all on `aes_core_top`)

| Direction | Signal | Width |
|---|---|---|
| input | `s_axi_awaddr` | `AXI_ADDR_WIDTH` |
| input | `s_axi_awprot` | 3 |
| input | `s_axi_awvalid` | 1 |
| output | `s_axi_awready` | 1 |
| input | `s_axi_wdata` | 32 |
| input | `s_axi_wstrb` | 4 |
| input | `s_axi_wvalid` | 1 |
| output | `s_axi_wready` | 1 |
| output | `s_axi_bresp` | 2 |
| output | `s_axi_bvalid` | 1 |
| input | `s_axi_bready` | 1 |
| input | `s_axi_araddr` | `AXI_ADDR_WIDTH` |
| input | `s_axi_arprot` | 3 |
| input | `s_axi_arvalid` | 1 |
| output | `s_axi_arready` | 1 |
| output | `s_axi_rdata` | 32 |
| output | `s_axi_rresp` | 2 |
| output | `s_axi_rvalid` | 1 |
| input | `s_axi_rready` | 1 |

### Internal Signals Between `aes_regfile` and `aes_core_top` FSM

| Signal | Direction | Width | Purpose |
|---|---|---|---|
| `ctrl_start` | regfile → FSM | 1 | Start pulse |
| `ctrl_irq_en` | regfile → FSM | 1 | IRQ enable |
| `ctrl_decrypt` | regfile → FSM | 1 | Encrypt/decrypt select |
| `ctrl_key_size` | regfile → FSM | 2 | Key size select |
| `ctrl_mode_cbc` | regfile → FSM | 1 | CBC mode |
| `ctrl_mode_ctr` | regfile → FSM | 1 | CTR mode |
| `ctrl_soft_rst` | regfile → FSM | 1 | Software reset |
| `key_data` | regfile → FSM | 256 | Full AES-256 key |
| `iv_data` | regfile → FSM | 128 | Initialization vector |
| `din_data` | regfile → FSM | 128 | Input plaintext/ciphertext |
| `core_busy_r` | FSM → regfile | 1 | Busy status |
| `core_done_r` | FSM → regfile | 1 | Done pulse |
| `core_key_ready_r` | FSM → regfile | 1 | Key ready pulse |
| `core_err_r` | FSM → regfile | 1 | Error pulse (never driven high) |
| `done_blocks` | FSM → regfile | 16 | Block counter |
| `dout_data` | FSM → regfile | 128 | Output data |

### AES Core Signals (to/from IP Instances)

| Signal | Core | Width | Direction |
|---|---|---|---|
| `enc_ld` | `u_cipher` | 1 | FSM → core |
| `enc_done` | `u_cipher` | 1 | core → FSM |
| `enc_text_out` | `u_cipher` | 128 | core → FSM |
| `dec_kld` | `u_inv_cipher` | 1 | FSM → core |
| `dec_kdone` | `u_inv_cipher` | 1 | core → FSM |
| `dec_ld` | `u_inv_cipher` | 1 | FSM → core |
| `dec_done` | `u_inv_cipher` | 1 | core → FSM |
| `dec_text_out` | `u_inv_cipher` | 128 | core → FSM |
| `core_key_mux` | both | 128 | FSM → both cores (shared bus) |
| `text_in_mux` | both | 128 | FSM → both cores (shared bus) |

### Absent Interfaces (Not Present in RTL)

- No FIFO interface of any kind
- No AXI streaming (AXI-S) interface
- No DMA interface
- No APB interface
- No 64-bit beat assembly logic
- No backpressure mechanism
- No streaming data-path

---

## 2. Register Map Compliance

| Offset | Spec Register | Spec Access | RTL Register | RTL Access | Reset Value | Result | Evidence |
|---|---|---|---|---|---|---|---|
| 0x00 | AES_CTRL | R/W | `ctrl_*` fields in `aes_regfile` | R/W (START & SOFT_RST WO/SC) | 0x00000014 (KEY_SIZE=2'b10) | PARTIAL MATCH | Reset sets `ctrl_key_size<=2'b10`. Read returns fields. START reads as 0. |
| 0x04 | AES_STATUS | RO/W1C | `status_done`, `status_key_ready`, `status_err`, `core_busy` | RO/W1C | 0x00000000 | MATCH | BUSY from `core_busy` wire; DONE/KEY_READY/ERR sticky set/W1C |
| 0x08 | AES_BLK_CNT | R/W lower / RO upper | `total_blocks` [15:0], `core_done_blocks` [31:16] | Correct split | 0x00000000 | PARTIAL MATCH | `total_blocks` stored but never read by FSM. See Section 5. |
| 0x0C | AES_IRQ_CLR | W1C | clears `status_done`, `status_err` | W1C, reads 0 | 0x00000000 | PARTIAL MATCH | CLR_DONE clears `status_done`; CLR_ERR clears `status_err`. No CLR_KEY_READY bit. |
| 0x10 | AES_KEY0 | WO | `key_data[31:0]` | WO (reads 0) | 0x00000000 | MATCH | Case `6'h04`; read returns 32'b0 |
| 0x14 | AES_KEY1 | WO | `key_data[63:32]` | WO | 0x00000000 | MATCH | Case `6'h05` |
| 0x18 | AES_KEY2 | WO | `key_data[95:64]` | WO | 0x00000000 | MATCH | Case `6'h06` |
| 0x1C | AES_KEY3 | WO | `key_data[127:96]` | WO | 0x00000000 | MATCH | Case `6'h07` |
| 0x20 | AES_KEY4 | WO | `key_data[159:128]` | WO | 0x00000000 | MATCH | Case `6'h08` |
| 0x24 | AES_KEY5 | WO | `key_data[191:160]` | WO | 0x00000000 | MATCH | Case `6'h09` |
| 0x28 | AES_KEY6 | WO | `key_data[223:192]` | WO | 0x00000000 | MATCH | Case `6'h0A` |
| 0x2C | AES_KEY7 | WO | `key_data[255:224]` | WO | 0x00000000 | MATCH | Case `6'h0B` |
| 0x30 | AES_IV0 | R/W | `iv_data[31:0]` | R/W | 0x00000000 | MATCH | Case `6'h0C`; read returns `iv_data[31:0]` |
| 0x34 | AES_IV1 | R/W | `iv_data[63:32]` | R/W | 0x00000000 | MATCH | Case `6'h0D` |
| 0x38 | AES_IV2 | R/W | `iv_data[95:64]` | R/W | 0x00000000 | MATCH | Case `6'h0E` |
| 0x3C | AES_IV3 | R/W | `iv_data[127:96]` | R/W | 0x00000000 | MATCH | Case `6'h0F` |
| 0x40 | AES_DIN0 | WO | `din_data[31:0]` | WO (reads 0) | 0x00000000 | MATCH | Case `6'h10` |
| 0x44 | AES_DIN1 | WO | `din_data[63:32]` | WO | 0x00000000 | MATCH | Case `6'h11` |
| 0x48 | AES_DIN2 | WO | `din_data[95:64]` | WO | 0x00000000 | MATCH | Case `6'h12` |
| 0x4C | AES_DIN3 | WO | `din_data[127:96]` | WO | 0x00000000 | MATCH | Case `6'h13` |
| 0x50 | AES_DOUT0 | RO | `dout_data[31:0]` (combinational) | RO | 0x00000000 | MATCH | Case `6'h14` returns `dout_data[31:0]` |
| 0x54 | AES_DOUT1 | RO | `dout_data[63:32]` | RO | 0x00000000 | MATCH | Case `6'h15` |
| 0x58 | AES_DOUT2 | RO | `dout_data[95:64]` | RO | 0x00000000 | MATCH | Case `6'h16` |
| 0x5C | AES_DOUT3 | RO | `dout_data[127:96]` | RO | 0x00000000 | MATCH | Case `6'h17` |

---

## 3. AES_CTRL Field Compliance

### [0] START

| Property | Detail |
|---|---|
| RTL location | `ctrl_start` register in `aes_regfile`, output port to FSM |
| Reset value | 0 |
| Write behavior | Written via `wr_data[0]` when `wr_strb[0]` asserted and `wr_addr[7:2]==6'h00` |
| Self-clearing | `ctrl_start <= 1'b0` executes every clock at top of `else` block; write sets for one cycle only |
| Pulse width | Exactly one clock cycle as seen by FSM |
| Write-while-BUSY | Register can be written but FSM ignores `ctrl_start` unless in `ST_IDLE` |
| Relationship to `ld` | Indirect: START → FSM → `enc_ld` in ST_KEY_LOAD1 and ST_DATA_LOAD |
| **Result** | **MATCH** |

### [1] IRQ_EN

| Property | Detail |
|---|---|
| RTL location | `ctrl_irq_en` in `aes_regfile` |
| Reset value | 0 |
| Write/read | Stored R/W, returned at bit [1] of read |
| Hardware use | `assign irq = ctrl_irq_en & (status_done \| status_err)` |
| **Result** | **MATCH** |

### [2] DECRYPT

| Property | Detail |
|---|---|
| RTL location | `ctrl_decrypt` in `aes_regfile`, wire to FSM |
| Reset value | 0 |
| Hardware use | Selects `enc_ld`/`dec_ld`/`dec_kld` paths; muxes `raw_text_out`; controls `dout_internal` |
| **Result** | **MATCH** |

### [4:3] KEY_SIZE

| Property | Detail |
|---|---|
| RTL location | `ctrl_key_size[1:0]` in `aes_regfile` |
| Reset value | 2'b10 (256-bit) |
| Write/read | Stored R/W, returned at bits [4:3] |
| Hardware use | `wire use_256 = (ctrl_key_size == 2'b10)`, `wire use_192 = (ctrl_key_size == 2'b01)` |
| AES-128 path | `use_256=0`, `use_192=0` → single key load, skip ST_KEY_LOAD2 |
| AES-256 path | `use_256=1` → second key half `key_data[255:128]` loaded |
| AES-192 MISMATCH | Second key half uses `key_data[191:64]` — incorrect slice. Should be `key_data[191:128]` (zero-padded to 128 bits) |
| **Result** | **PARTIAL MATCH** — 128/256 correct; AES-192 slice incorrect |

### [5] MODE_CBC

| Property | Detail |
|---|---|
| RTL location | `ctrl_mode_cbc` in `aes_regfile` |
| Reset value | 0 |
| Hardware use | ST_DATA_LOAD: `text_in_mux <= din_data ^ feedback_reg`; ST_DATA_WAIT: `feedback_reg <= raw_text_out` (enc) or `din_data` (dec) |
| MISMATCH | `feedback_reg` never seeded from `iv_data`; CBC first block uses IV=0 not programmed IV |
| **Result** | **PARTIAL MATCH** — CBC arithmetic present; IV not seeded |

### [6] MODE_CTR

| Property | Detail |
|---|---|
| RTL location | `ctrl_mode_ctr` in `aes_regfile` |
| Reset value | 0 |
| Hardware use | ST_DATA_LOAD: counter block fed to core; ST_DATA_WAIT: `feedback_reg <= feedback_reg + 128'b1`; dout XOR with `din_data` |
| MISMATCH | `feedback_reg` not loaded from `iv_data` at START; CTR counter starts from 0 not programmed IV |
| **Result** | **PARTIAL MATCH** — CTR arithmetic present; IV not seeded |

### [7] SOFT_RST

| Property | Detail |
|---|---|
| RTL location | `ctrl_soft_rst` in `aes_regfile`, wire to FSM |
| Reset value | 0 |
| Self-clearing | Same mechanism as START — one cycle pulse |
| FSM reset | `if (rst \|\| ctrl_soft_rst)` resets all FSM registers, `feedback_reg`, `done_blocks` |
| Key registers | `key_data`, `iv_data`, `din_data` NOT cleared — only reset by `aresetn` |
| IP core reset | `rst_n = aresetn` only; `ctrl_soft_rst` NOT wired to IP core reset input |
| **Result** | **PARTIAL MATCH** — FSM resets; key material and IP cores not reset |

### [31:8] Reserved

| Property | Detail |
|---|---|
| Write | No storage; bits[31:8] of AES_CTRL write word ignored |
| Read | Returns `{24'b0, ctrl_soft_rst, ctrl_mode_ctr, ctrl_mode_cbc, ctrl_key_size, ctrl_decrypt, ctrl_irq_en, 1'b0}` — upper 24 bits are zero |
| **Result** | **MATCH** |

---

## 4. AES_STATUS Field Compliance

### [0] BUSY

| Property | Detail |
|---|---|
| What sets it | FSM `ST_IDLE` when `ctrl_start` seen: `core_busy_r <= 1'b1` |
| What clears it | FSM `ST_DONE`: `core_busy_r <= 1'b0`; also cleared by `rst \|\| ctrl_soft_rst` |
| Write behavior | Writes to STATUS[0] ignored |
| **Result** | **MATCH** |

### [1] DONE

| Property | Detail |
|---|---|
| What sets it | `status_done <= 1'b1` on `core_done` (= `core_done_r`) pulse |
| What clears it | W1C: STATUS write `wr_data[1]=1`; IRQ_CLR write `wr_data[0]=1`; `aresetn` |
| Sticky | Yes — flip-flop, not cleared by new START |
| DONE semantics | Means: AES core `done` output received AND `dout_internal` has been updated. Does NOT mean FIFO drained or DMA complete (neither exists). |
| **Result** | **MATCH** |

### [2] KEY_READY

| Property | Detail |
|---|---|
| What sets it | `core_key_ready_r` pulse from FSM after `enc_done`/`dec_kdone` on key load pass |
| What clears it | W1C via STATUS[2] write only. AES_IRQ_CLR has NO bit to clear KEY_READY. |
| MISMATCH | IRQ_CLR[0] only clears DONE; no IRQ_CLR path for KEY_READY |
| NOT VERIFIABLE | Whether `done`/`kdone` from the IP truly signals key expansion completion (IP source not present) |
| **Result** | **PARTIAL MATCH** |

### [3] ERR

| Property | Detail |
|---|---|
| What sets it | Nothing — `core_err_r` is always 0 in FSM. Never set to 1'b1 anywhere. |
| What clears it | W1C via STATUS[3] write or IRQ_CLR[1] — but it can never be set |
| MISMATCH | ERR bit is architecturally dead; `status_err` can only be cleared, never set by hardware |
| **Result** | **MISMATCH** |

### [31:4] Reserved

| Property | Detail |
|---|---|
| Read | Returns 28'b0 concatenated |
| **Result** | **MATCH** |

---

## 5. AES_BLK_CNT Compliance

### [15:0] TOTAL_BLOCKS

| Property | Detail |
|---|---|
| Storage | `total_blocks[15:0]` in `aes_regfile`, R/W, reset 0 |
| CRITICAL MISMATCH | `blk_remaining` in FSM is loaded as: `({\|{16'b0, 1'b0}} ? 16'b0 : ({16{1'b1}} & 16'd1))` — evaluates to constant **16'h0001**. `total_blocks` is NEVER read by the FSM. |
| `blk_remaining` usage | Declared and assigned in FSM but never decremented and never used in any condition |
| **Result** | **MISMATCH** — register stored, never consumed; multi-block operation not implemented |

### [31:16] DONE_BLOCKS

| Property | Detail |
|---|---|
| Storage | `done_blocks[15:0]` in FSM, connected to `core_done_blocks` input of regfile |
| Increment | `done_blocks <= done_blocks + 16'b1` in `ST_DONE` |
| Reset on SOFT_RST | Yes — cleared by `rst \|\| ctrl_soft_rst` |
| Reset on START | No — accumulates across multiple START operations |
| Spec says | Reset on SOFT_RST or new START — RTL only resets on SOFT_RST |
| **Result** | **PARTIAL MATCH** — increments correctly; not reset on START; TOTAL_BLOCKS not consumed |

---

## 6. Key Register Compliance

### Address-to-Slice Mapping (Traced from RTL)

| Register | Offset | Case | RTL Slice |
|---|---|---|---|
| AES_KEY0 | 0x10 | `6'h04` | `key_data[31:0]` |
| AES_KEY1 | 0x14 | `6'h05` | `key_data[63:32]` |
| AES_KEY2 | 0x18 | `6'h06` | `key_data[95:64]` |
| AES_KEY3 | 0x1C | `6'h07` | `key_data[127:96]` |
| AES_KEY4 | 0x20 | `6'h08` | `key_data[159:128]` |
| AES_KEY5 | 0x24 | `6'h09` | `key_data[191:160]` |
| AES_KEY6 | 0x28 | `6'h0A` | `key_data[223:192]` |
| AES_KEY7 | 0x2C | `6'h0B` | `key_data[255:224]` |

### Key Assembly (Traced)

Full key: `{KEY7, KEY6, KEY5, KEY4, KEY3, KEY2, KEY1, KEY0}` → **matches specification.**

First half sent to core: `key_data[127:0]` = `{KEY3, KEY2, KEY1, KEY0}`
Second half sent to core: `key_data[255:128]` = `{KEY7, KEY6, KEY5, KEY4}`

### Write-Only Behavior

All KEY reads return `32'b0` via read cases `6'h04`–`6'h0B`. **Correct.**

### DATA_LOAD Key Mismatch

In `ST_DATA_LOAD`: `core_key_mux <= key_data[127:0]` — only lower 128 bits re-presented during data processing. For AES-256 the full 256-bit schedule is needed; the IP core will re-expand from first half only.

| Item | Result |
|---|---|
| Address mapping | MATCH |
| Slice assignment | MATCH |
| WO behavior (reads zero) | MATCH |
| Reset | MATCH |
| AES-192 second key slice | MISMATCH — `key_data[191:64]` used, should be `key_data[191:128]` |
| DATA_LOAD key presentation | MISMATCH — only `key_data[127:0]` used, not full 256-bit key |

---

## 7. IV Register Compliance

### Address-to-Slice Mapping (Traced from RTL)

| Register | Offset | Case | RTL Slice |
|---|---|---|---|
| AES_IV0 | 0x30 | `6'h0C` | `iv_data[31:0]` |
| AES_IV1 | 0x34 | `6'h0D` | `iv_data[63:32]` |
| AES_IV2 | 0x38 | `6'h0E` | `iv_data[95:64]` |
| AES_IV3 | 0x3C | `6'h0F` | `iv_data[127:96]` |

IV assembly: `{IV3, IV2, IV1, IV0}` = `iv_data[127:0]` → **matches specification.**

### CRITICAL MISMATCH — iv_data Not Connected to Datapath

`iv_data` is declared as `wire [127:0]` in `aes_core_top` and connected from `aes_regfile`. However `iv_data` is **never read anywhere in `aes_core_top`**. It is not assigned to `feedback_reg`, not XOR'd with any signal, not used in any FSM state. The `feedback_reg` resets to `128'b0` and is never seeded from `iv_data`.

**The IV registers are fully implemented in the register file but architecturally disconnected from the AES datapath.**

| Item | Result |
|---|---|
| Register existence | MATCH |
| Read/write behavior | MATCH |
| Reset | MATCH |
| Bit mapping | MATCH |
| Concatenation | MATCH |
| Connection to CBC datapath | MISMATCH — `iv_data` not consumed |
| Connection to CTR datapath | MISMATCH — `iv_data` not consumed |

---

## 8. DIN / DOUT Compliance

### DIN

| Property | Detail |
|---|---|
| Storage | `din_data[127:0]` in `aes_regfile`, 4 × 32-bit WO registers |
| Connection | `din_data` wire used in FSM `ST_DATA_LOAD` for `text_in_mux` (ECB/CBC) and `dout_internal` (CTR XOR) |
| Valid timing | Valid when written; FSM reads `din_data` on cycle it enters `ST_DATA_LOAD` |
| **Result** | **MATCH** |

### DOUT

| Property | Detail |
|---|---|
| Storage | No flip-flop storage in regfile. `dout_data` is a combinational wire from `dout_internal` always@(*) block |
| Stability | NOT stable — combinational output changes whenever `raw_text_out`, `din_data`, or `feedback_reg` change |
| Spec expectation | Stable and valid after DONE assertion |
| DOUT meaning | ECB/CBC-E: `enc_text_out`; CBC-D: `dec_text_out ^ feedback_reg` (subject to timing issue); CTR: `din_data ^ enc_text_out` |
| CBC-D timing hazard | `dout_internal = raw_text_out ^ feedback_reg`. By the time DONE is asserted, `feedback_reg` has been updated to `din_data` (current ciphertext) in `ST_DATA_WAIT`. So output is `AES^-1(Ck) ^ Ck` (wrong), not `AES^-1(Ck) ^ C(k-1)` (correct). |
| **Result** | **PARTIAL MATCH** — connected to correct output path; not registered; CBC-D has timing hazard |

---

## 9. AXI / Data-Path Architecture Compliance

Expected architecture from locked spec:
```
DMA → AXI4 → 64-bit beat assembly → 128-bit block → CBC → AES-256 core
    → 128-bit result → 64-bit beat splitting → AXI4 → DMA
```

| Architectural Element | Spec | RTL | Result |
|---|---|---|---|
| AXI4 streaming ingress | Required | Not present | NOT IMPLEMENTED |
| AXI4 streaming egress | Required | Not present | NOT IMPLEMENTED |
| DMA interface | Required | Not present | NOT IMPLEMENTED |
| 64-bit beat assembly | Required | Not present | NOT IMPLEMENTED |
| Beat 0 → block[63:0] | Required | Not present | NOT IMPLEMENTED |
| Beat 1 → block[127:64] | Required | Not present | NOT IMPLEMENTED |
| 128-bit block register | Implied | `din_data[127:0]` (SW-written) | PARTIAL MATCH — SW-written, not HW-assembled |
| 64-bit beat splitting output | Required | Not present | NOT IMPLEMENTED |
| Backpressure handling | Required | Not present | NOT IMPLEMENTED |
| FIFO buffering | Required | Not present | NOT IMPLEMENTED |
| APB control plane | Mentioned in locked arch spec | Not present — AXI4-Lite used | MISMATCH |

The entire data-plane architecture described in the locked spec does not exist in the RTL. The RTL implements a CPU-written register interface only.

---

## 10. CBC Datapath Compliance

### Expected Equations

**Encrypt:** C₀ = IV; Xₖ = Pₖ XOR C(k-1); Cₖ = AES_K(Xₖ)

**Decrypt:** Xₖ = AES⁻¹_K(Cₖ); Pₖ = Xₖ XOR C(k-1); chain value = Cₖ

### RTL Trace

**Encrypt path (ST_DATA_LOAD, ctrl_mode_cbc=1, ctrl_decrypt=0):**
```verilog
text_in_mux <= din_data ^ feedback_reg;
enc_ld      <= 1'b1;
```
After first block: `feedback_reg <= raw_text_out` (= `enc_text_out`) in ST_DATA_WAIT.

**Decrypt path:**
```verilog
text_in_mux <= din_data;   // ciphertext fed directly to inverse cipher
dec_ld      <= 1'b1;
```
In ST_DATA_WAIT: `feedback_reg <= din_data` (current ciphertext).

In dout_internal (combinational, evaluated after ST_DATA_WAIT updates feedback_reg):
```verilog
dout_internal = raw_text_out ^ feedback_reg;
// feedback_reg has already been updated to din_data (current Ck)
// Result: AES^-1(Ck) XOR Ck   ← INCORRECT
// Should be: AES^-1(Ck) XOR C(k-1)
```

| CBC Element | Spec | RTL | Result |
|---|---|---|---|
| IV seeding | `feedback_reg = IV` at start | `feedback_reg` reset to 0, never loaded from `iv_data` | MISMATCH |
| Encrypt XOR pre-AES | `Pₖ XOR C(k-1)` | `din_data ^ feedback_reg` — correct equation, wrong initial value | PARTIAL MATCH |
| Encrypt chain update | `feedback_reg = Cₖ` | `feedback_reg <= raw_text_out` | MATCH |
| Decrypt chain update | `feedback_reg = Cₖ` | `feedback_reg <= din_data` | MATCH |
| Decrypt XOR post-AES | `AES⁻¹(Cₖ) XOR C(k-1)` | `raw_text_out ^ feedback_reg` where feedback already updated to Cₖ | MISMATCH |

---

## 11. AES-256 Key Expansion Compliance

The ASICS.ws IP (`aes_cipher_top`, `aes_inv_cipher_top`) implements **AES-128 only** (128-bit key, 10 rounds). The spec document states: *"This implementation is with a 128 bit key expansion module only. Implementations with different key sizes (192 & 256 bits) are commercially available."*

| Requirement | Spec | RTL | Result |
|---|---|---|---|
| 256-bit key input | Required | Two-phase 128-bit loading via FSM | PARTIAL MATCH — architectural workaround |
| 14 rounds (AES-256) | Required | IP core runs 10 rounds only (AES-128 IP) | MISMATCH |
| AES-256 key schedule | Required | IP generates 128-bit key schedule only; two ld pulses do not constitute 256-bit schedule | MISMATCH |
| KEY_READY timing | Documented | Pulsed after enc_done/dec_kdone on key load pass | NOT VERIFIABLE |
| Inverse key schedule | Required for decrypt | `aes_inv_cipher_top` handles internally | NOT VERIFIABLE |

**CRITICAL FINDING:** The ASICS.ws IP is an AES-128 core. Feeding two sequential 128-bit halves via two `ld` pulses does **not** implement AES-256. AES-256 requires a 256-bit key schedule producing 15 round keys (one initial + 14 rounds). This cannot be achieved by running AES-128 twice. **The RTL does not implement AES-256 encryption/decryption.**

---

## 12. AES Core Signal Binding

| Signal | Spec Meaning | RTL Driver | RTL Destination | Timing | Result |
|---|---|---|---|---|---|
| `ld` (encrypt) | Load key+text, start encrypt | `enc_ld` reg in FSM | `u_cipher.ld` | Pulsed in ST_KEY_LOAD1 and ST_DATA_LOAD | MATCH |
| `kld` (decrypt key) | Load key for inverse cipher | `dec_kld` reg in FSM | `u_inv_cipher.kld` | Pulsed in ST_KEY_LOAD1/ST_KEY_LOAD2 (decrypt path) | MATCH |
| `ld` (decrypt text) | Load text for inverse cipher | `dec_ld` reg in FSM | `u_inv_cipher.ld` | Pulsed in ST_DATA_LOAD (decrypt path) | MATCH |
| `done` (encrypt) | Encryption complete | `enc_done` wire | FSM conditions in ST_KEY_WAIT1, ST_KEY_WAIT2, ST_DATA_WAIT | One-cycle pulse from IP | MATCH |
| `kdone` (decrypt) | Key expansion complete | `dec_kdone` wire | FSM conditions in ST_KEY_WAIT1, ST_KEY_WAIT2 | One-cycle pulse from IP | MATCH |
| `done` (decrypt) | Decryption complete | `dec_done` wire | FSM condition in ST_DATA_WAIT | One-cycle pulse from IP | MATCH |
| `key[127:0]` | 128-bit key | `core_key_mux` reg | Both `u_cipher.key` and `u_inv_cipher.key` (shared bus) | Set before ld/kld pulse | PARTIAL MATCH — shared; both cores receive simultaneously |
| `text_in[127:0]` | 128-bit input text | `text_in_mux` reg | Both `u_cipher.text_in` and `u_inv_cipher.text_in` (shared bus) | Set in ST_KEY_LOAD* and ST_DATA_LOAD | PARTIAL MATCH — shared bus |
| `text_out[127:0]` (enc) | 128-bit output | `enc_text_out` | `raw_text_out` mux, `dout_internal` | Combinational IP output | MATCH |
| `text_out[127:0]` (dec) | 128-bit output | `dec_text_out` | `raw_text_out` mux, `dout_internal` | Combinational IP output | MATCH |

**Note:** Both cipher and inverse cipher cores receive the same `text_in_mux` and `core_key_mux` at all times. The unselected core processes every operation spuriously. Its output is muxed away but it consumes power and its internal state is indeterminate.

---

## 13. Interrupt Compliance

**RTL interrupt path:**
```verilog
assign irq = ctrl_irq_en & (status_done | status_err);
```

| Requirement | Spec | RTL | Result |
|---|---|---|---|
| IRQ_EN gates IRQ | Yes | `ctrl_irq_en &` | MATCH |
| DONE generates IRQ | Yes | `status_done` in equation | MATCH |
| ERR generates IRQ | Yes | `status_err` in equation (but ERR is never set — see Section 4) | MATCH (path exists; dead in practice) |
| KEY_READY generates IRQ | Not documented | Not in IRQ equation | MATCH by omission |
| AES_IRQ_CLR clears IRQ | Yes | Clears `status_done`/`status_err` → IRQ deasserts | MATCH |
| IRQ level or pulse | Not specified in spec | Level-sensitive (combinational assign) | NOT VERIFIABLE |
| IRQ polarity | Not specified | Active-HIGH | NOT VERIFIABLE |

---

## 14. Reset Compliance

| Element | Spec States | RTL Behavior | Result |
|---|---|---|---|
| Reset polarity | Active-LOW synchronous | `aresetn` active-LOW; all always blocks on `posedge aclk` only | MATCH |
| `ctrl_*` registers | Reset | All reset to 0 except `ctrl_key_size` = 2'b10 | MATCH |
| `key_data` | Reset | Reset to 256'b0 in write dispatch always block | MATCH |
| `iv_data` | Reset | Reset to 128'b0 | MATCH |
| `din_data` | Reset | Reset to 128'b0 | MATCH |
| `status_done/key_ready/err` | Reset | Separate always block resets all to 0 | MATCH |
| `total_blocks` | Reset | Reset to 16'h0000 | MATCH |
| `feedback_reg` | Reset | Reset to 128'b0 in FSM | MATCH |
| `done_blocks` | Reset | Reset to 16'b0 in FSM | MATCH |
| IP core reset | Active-LOW | `rst_n = aresetn` fed to both IP instances | MATCH |
| SOFT_RST resets key registers | Spec implies | `ctrl_soft_rst` does NOT reset `key_data`, `iv_data`, `din_data` | MISMATCH |
| SOFT_RST resets IP cores | Implied | `rst_n` is only `aresetn`; SOFT_RST not wired to IP reset | MISMATCH |
| `s_axi_awready` at reset | — | Reset to 1'b0; requires one cycle after reset to become ready | FACT (not an error) |

---

## 15. Security Observations

| Observation | Evidence | Severity |
|---|---|---|
| Key registers read as zero | Read cases `6'h04`–`6'h0B` return `32'b0` | Implemented correctly |
| `key_data` not cleared by SOFT_RST | SOFT_RST only triggers FSM reset; `key_data` only resets on `aresetn` | Key material persists after soft reset |
| `key_data` not cleared on new START | No logic clears key on START | Acceptable but documented |
| No KEY_SIZE validation | `KEY_SIZE=2'b11` accepted silently; silently degrades to AES-128 path | Invalid encoding has no error indication |
| Encryption can start with all-zero key | No check that key registers have been written before START | Zero-key operation possible |
| `blk_remaining` hardwired to 1 | Even with `TOTAL_BLOCKS=0`, one block will always be processed | No zero-block guard |
| Both IP cores active simultaneously | `core_key_mux` and `text_in_mux` shared; unselected core processes every operation | Side-channel / power leakage risk |
| `dout_data` is combinational | Output changes immediately if `feedback_reg` changes — before DONE in some scenarios | Risk of reading transitional output |

---

## 16. Specification Conflicts

| Area | Architectural Spec | Register Spec | RTL | Final Status |
|---|---|---|---|---|
| Bus interface | APB control plane | AXI4-Lite | AXI4-Lite | Arch spec vs Register spec conflict; RTL follows Register spec |
| Data ingress | AXI4 streaming / DMA | CPU-written DIN registers | CPU-written DIN registers | RTL matches Register spec; conflicts with Arch spec |
| Data egress | AXI4 streaming / DMA | CPU-read DOUT registers | CPU-read DOUT (combinational) | RTL matches Register spec; conflicts with Arch spec |
| Key size | AES-256 only (locked) | Selectable 128/192/256 | Selectable 128/192/256 | Register spec conflicts with locked AES-256 arch spec |
| Block cipher mode | CBC-only (locked) | ECB/CBC/CTR selectable | ECB/CBC/CTR selectable | Register spec conflicts with locked CBC arch spec |
| 64-bit beat assembly | Required | Not mentioned | Not present | Arch spec requirement absent in both Register spec and RTL |
| Multi-block autonomous | Block-counter controlled | TOTAL_BLOCKS documented | TOTAL_BLOCKS unused | Register spec documents it; RTL does not implement it |
| AES-256 implementation | True 256-bit | Two-phase 128-bit loading | Two-phase 128-bit loading of AES-128 IP | Neither Register spec nor RTL implements true AES-256 |

---

## 17. Critical Mismatches

| # | Area | Description |
|---|---|---|
| 1 | AES-256 not implemented | ASICS.ws IP is AES-128 only. Two sequential `ld` pulses with two 128-bit key halves do not constitute AES-256. RTL produces non-standard, cryptographically incorrect output when `KEY_SIZE=2'b10`. |
| 2 | IV not connected to datapath | `iv_data` wire present but never read in `aes_core_top`. `feedback_reg` always initializes to zero, not IV. All CBC/CTR operations use an effective IV of zero. |
| 3 | CBC-Decrypt XOR wrong ciphertext | `feedback_reg` updated to `din_data` in `ST_DATA_WAIT` before `dout_internal` combinational evaluation. Result is `AES⁻¹(Ck) XOR Ck` instead of `AES⁻¹(Ck) XOR C(k-1)`. Incorrect for all blocks after block 0. |
| 4 | TOTAL_BLOCKS never consumed | `blk_remaining` hardwired to constant 1 (expression evaluates to `16'h0001`). Never decremented. Multi-block operation unsupported. |
| 5 | ERR bit never asserted | `core_err_r` is always 0 in FSM. `status_err` can only be cleared, never set by hardware. |
| 6 | SOFT_RST incomplete | Key registers (`key_data`, `iv_data`, `din_data`) not cleared. IP cores not reset by SOFT_RST. |
| 7 | AES-192 key slice incorrect | Second key half for AES-192 uses `key_data[191:64]`; should be `key_data[191:128]`. |
| 8 | DOUT combinational, not registered | `dout_data` can change at any time; no stable hold at DONE assertion. |
| 9 | DONE_BLOCKS not reset on START | Counter accumulates across START operations; spec requires reset on START. |
| 10 | APB vs AXI4-Lite | Locked architectural spec mentions APB; RTL implements AXI4-Lite. |

---

## 18. Missing Implementations

| # | Feature | Specified In |
|---|---|---|
| 1 | True AES-256 key schedule (14 rounds) | Arch spec |
| 2 | AXI4 streaming ingress | Arch spec |
| 3 | AXI4 streaming egress | Arch spec |
| 4 | DMA interface | Arch spec |
| 5 | 64-bit beat assembly (Beat0→[63:0], Beat1→[127:64]) | Arch spec |
| 6 | 64-bit output beat splitting | Arch spec |
| 7 | FIFO buffering | Arch spec |
| 8 | Backpressure handling | Arch spec |
| 9 | IV seeding of `feedback_reg` from `iv_data` | Register spec, Arch spec |
| 10 | Multi-block autonomous operation | Register spec |
| 11 | ERR detection and generation | Register spec |
| 12 | SOFT_RST clearing key material | Register spec (implied) |
| 13 | SOFT_RST resetting IP cores | Implied |
| 14 | KEY_READY IRQ clear via AES_IRQ_CLR | Implied by IRQ_CLR design |
| 15 | DONE_BLOCKS reset on START | Register spec |

---

## 19. Items That Cannot Be Verified

| # | Item | Reason |
|---|---|---|
| 1 | Whether AES-128 IP `done` signals key expansion vs encryption completion | IP source files (`aes_cipher_top.v`, `aes_inv_cipher_top.v`) not read |
| 2 | Actual round count of `aes_cipher_top` / `aes_inv_cipher_top` | IP source files not available in RTL directory |
| 3 | Whether `aes_inv_cipher_top` receives correct key ordering for decryption | Depends on IP internal key reversal buffer behavior |
| 4 | IRQ polarity expected by SoC interrupt controller | Not specified in any document |
| 5 | Whether `enc_done` / `dec_done` are truly one-cycle pulses | Depends on IP internal FSM |
| 6 | Side effects of both IP cores running simultaneously | Requires simulation or formal analysis |
| 7 | Timing closure between `feedback_reg` update and `dout_internal` combinational read in same clock cycle | Requires gate-level or STA analysis |
| 8 | AXI write FSM behavior when AW and W arrive in the same cycle | Requires simulation of simultaneous valid signals |

---

## 20. Final Compliance Matrix

### A. MATCHES (17)

1. AES_CTRL reset value (0x00000014, KEY_SIZE=2'b10)
2. AES_CTRL[1] IRQ_EN — R/W, gating, read behavior
3. AES_CTRL[2] DECRYPT — R/W, mux select
4. AES_CTRL[0] START — self-clearing, one-cycle pulse, BUSY guard via FSM
5. AES_STATUS[0] BUSY — RO, set/cleared by FSM correctly
6. AES_STATUS[1] DONE — sticky, W1C, reset behavior
7. AES_IRQ_CLR — W1C, reads as zero
8. All 8 KEY registers — address mapping, slice assignment, WO (reads zero), reset
9. All 4 IV registers — address mapping, R/W, reset, slice assignment
10. All 4 DIN registers — address mapping, WO, reset
11. All 4 DOUT register read paths — mapped to `dout_data` slices
12. AES_STATUS[31:4] — read as zero
13. AES_CTRL[31:8] — read as zero, WI
14. Reset polarity and synchronization — active-LOW synchronous
15. Interrupt gating by IRQ_EN
16. DONE and ERR clear via AES_IRQ_CLR
17. `ld`/`kld`/`done`/`kdone` signal binding (names, widths, pulse behavior)

### B. PARTIAL MATCHES (8)

1. AES_CTRL[4:3] KEY_SIZE — 128/256 correct; AES-192 slice wrong
2. AES_CTRL[5] MODE_CBC — logic present; IV not seeded; CBC-D XOR timing incorrect
3. AES_CTRL[6] MODE_CTR — logic present; `feedback_reg` not seeded from IV
4. AES_CTRL[7] SOFT_RST — FSM reset correct; key registers and IP cores not reset
5. AES_STATUS[2] KEY_READY — sticky/W1C correct; IRQ_CLR cannot clear it
6. AES_BLK_CNT[31:16] DONE_BLOCKS — increments correctly; not reset on START
7. Key assembly and DATA_LOAD — full 256-bit key assembled correctly; DATA_LOAD re-uses only lower 128 bits
8. DOUT connection — correct signal path; not registered; CBC-D timing hazard

### C. MISMATCHES (10)

1. AES-256 key expansion — AES-128 IP used; true AES-256 not implemented
2. IV not connected — `iv_data` unread; `feedback_reg` = 0, not IV
3. CBC-D XOR — uses current ciphertext; should use previous
4. TOTAL_BLOCKS — stored but never consumed; `blk_remaining` hardwired to 1
5. ERR bit — never asserted by hardware
6. AES-192 key slice — `key_data[191:64]` incorrect; should be `key_data[191:128]`
7. SOFT_RST — does not clear key material or reset IP cores
8. DOUT not registered — combinational; no stable hold at DONE
9. DONE_BLOCKS not reset on START
10. APB vs AXI4-Lite

### D. NOT IMPLEMENTED (15)

1. True AES-256 key schedule (14 rounds, 15 round keys)
2. AXI4 streaming ingress
3. AXI4 streaming egress
4. DMA interface
5. 64-bit beat assembly
6. 64-bit output beat splitting
7. FIFO buffering
8. Backpressure handling
9. IV seeding of `feedback_reg`
10. Multi-block autonomous operation
11. ERR detection and generation
12. SOFT_RST clearing key material
13. SOFT_RST resetting IP cores
14. KEY_READY clearing via IRQ_CLR
15. DONE_BLOCKS reset on START

### E. NOT VERIFIABLE (8)

1. Whether IP `done` signals key expansion vs encryption completion
2. Actual round count of IP cores
3. Correct key ordering in `aes_inv_cipher_top`
4. IRQ polarity expected by SoC
5. Whether `enc_done`/`dec_done` are one-cycle pulses
6. Side effects of both IP cores running simultaneously
7. `feedback_reg`/`dout_internal` combinational timing at gate level
8. AXI write FSM simultaneous AW+W arrival behavior

### F. Questions That Must Be Resolved Before Verification

| # | Question |
|---|---|
| 1 | Is the locked specification AES-256 only, or is 128/192/256 selectable? RTL supports selection but does not actually implement 256. |
| 2 | Is the data plane CPU-register-based (DIN/DOUT) or AXI-streaming/DMA? The two specifications directly contradict each other. |
| 3 | Is the control bus APB or AXI4-Lite? RTL uses AXI4-Lite; locked arch spec mentions APB. |
| 4 | Is CBC the only mode, or are ECB and CTR required? Locked spec says CBC-only; Register spec adds ECB and CTR. |
| 5 | Must IV be user-programmable per-operation or fixed? IV is writable but never consumed. |
| 6 | What does ERR signify? No hardware condition currently generates it. |
| 7 | Are `aes_cipher_top` and `aes_inv_cipher_top` source files available? Required to verify round count, `done` timing, and key schedule correctness. |
| 8 | What is the expected IRQ polarity and level/edge behavior at the RISC-V interrupt controller? |
| 9 | Is multi-block autonomous operation (TOTAL_BLOCKS-driven) required? Currently non-functional. |
| 10 | Is DOUT required to be registered (stable) or can it be combinational? |

---

## Summary Statistics

| Category | Count |
|---|---|
| MATCHES | 17 |
| PARTIAL MATCHES | 8 |
| MISMATCHES | 10 |
| NOT IMPLEMENTED | 15 |
| NOT VERIFIABLE | 8 |
| **Total Items Audited** | **58** |

---

*This document is a READ-ONLY compliance audit. No RTL was modified during this audit.*
*RTL files audited: `rtl/aes_regfile.v`, `rtl/aes_core_top.v`*
*Reference documents: `doc/aes_regset.md`, ASICS.ws AES Rijndael IP Core Rev 1.1 (aes.pdf)*
