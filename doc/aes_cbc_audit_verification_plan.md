# AES-256 CBC Accelerator Subsystem
# RTL-to-Architecture Audit & Verification Plan
## Project: RISC-V Based Cryptographic Telemetry Gateway SoC
## Date: 2026-08-29
## Status: READ-ONLY AUDIT — RTL NOT MODIFIED

---

## Locked Architectural Baseline

| Property | Locked Value |
|---|---|
| Algorithm | AES-256 |
| Mode | CBC only |
| Key width | 256 bits |
| IV width | 128 bits |
| Block size | 128 bits |
| Data-plane bus | AXI4, 64-bit beats |
| Beats per block | 2 |
| Beat 0 | block[63:0] |
| Beat 1 | block[127:64] |
| Block count control | AES_BLK_CNT |
| Control plane bus | APB |
| AES input endpoint | AXI4 Slave S3 @ 0x9000_0010 |
| AES output endpoint | AXI4 Slave S4 @ 0x9000_0020 |
| AES_CTRL | 0x00 |
| AES_STATUS | 0x04 |
| AES_BLK_CNT | 0x08 |
| AES_KEY0–KEY7 | 0x10–0x2C |
| AES_IV0–IV3 | 0x30–0x3C |

---

## A. RTL Hierarchy

```
aes_core_top  [rtl/aes_core_top.v]
│
├── aes_regfile  [rtl/aes_regfile.v]
│   ├── AXI4-Lite slave write FSM  (AW + W channel latching, B response)
│   ├── AXI4-Lite read FSM         (AR → R one-cycle response)
│   ├── Register storage           (ctrl_*, key_data, iv_data, din_data,
│   │                               total_blocks, status_done/key_ready/err)
│   └── IRQ combinational output   (assign irq = ctrl_irq_en & (status_done | status_err))
│
├── aes_cipher_top  [u_cipher — ASICS.ws AES-128 encrypt IP — SOURCE NOT IN REPO]
│   └── Ports: clk, rst(active-LOW), ld, done, key[127:0], text_in[127:0], text_out[127:0]
│
├── aes_inv_cipher_top  [u_inv_cipher — ASICS.ws AES-128 decrypt IP — SOURCE NOT IN REPO]
│   └── Ports: clk, rst(active-LOW), kld, kdone, ld, done, key[127:0],
│              text_in[127:0], text_out[127:0]
│
└── Control FSM  [inline in aes_core_top.v]
    States: ST_IDLE, ST_KEY_LOAD1, ST_KEY_WAIT1, ST_KEY_LOAD2,
            ST_KEY_WAIT2, ST_DATA_LOAD, ST_DATA_WAIT, ST_DONE, ST_SOFT_RST
```

### Modules NOT Present in RTL (searched entire rtl/ directory)

| Required Module | Status |
|---|---|
| APB register slave | ABSENT — AXI4-Lite used instead |
| Input FIFO | ABSENT |
| Output FIFO | ABSENT |
| 64-bit beat assembler | ABSENT |
| 128-bit beat splitter | ABSENT |
| AXI4 data-plane slave (S3) | ABSENT |
| AXI4 data-plane slave (S4) | ABSENT |
| AES-256 dedicated key expansion | ABSENT — AES-128 IP used |
| Block counter decrementer | ABSENT |
| Backpressure logic | ABSENT |

---

## B. Register Audit

### Architectural Register Addresses vs RTL

| Arch Offset | Arch Register | RTL Offset | RTL Register | Bus Arch | Bus RTL | Match? |
|---|---|---|---|---|---|---|
| 0x00 | AES_CTRL | 0x00 | AES_CTRL (ctrl_* fields) | APB | AXI4-Lite | ADDR MATCH / BUS MISMATCH |
| 0x04 | AES_STATUS | 0x04 | AES_STATUS | APB | AXI4-Lite | ADDR MATCH / BUS MISMATCH |
| 0x08 | AES_BLK_CNT | 0x08 | AES_BLK_CNT | APB | AXI4-Lite | ADDR MATCH / BUS MISMATCH |
| 0x0C | (not in arch spec) | 0x0C | AES_IRQ_CLR | — | AXI4-Lite | EXTRA REGISTER (not in locked spec) |
| 0x10–0x2C | AES_KEY0–7 | 0x10–0x2C | AES_KEY0–7 | APB | AXI4-Lite | ADDR MATCH / BUS MISMATCH |
| 0x30–0x3C | AES_IV0–3 | 0x30–0x3C | AES_IV0–3 | APB | AXI4-Lite | ADDR MATCH / BUS MISMATCH |
| — | (not in locked spec) | 0x40–0x4C | AES_DIN0–3 | — | AXI4-Lite | EXTRA REGISTERS |
| — | (not in locked spec) | 0x50–0x5C | AES_DOUT0–3 | — | AXI4-Lite | EXTRA REGISTERS |

### Per-Register Detail

#### 0x00 — AES_CTRL

| Property | Spec | RTL | Status |
|---|---|---|---|
| Address | 0x00 | 0x00 (`wr_addr[7:2]==6'h00`) | MATCH |
| Bus | APB | AXI4-Lite | MISMATCH |
| Width | 32-bit | 32-bit | MATCH |
| Reset | Not specified | 0x00000014 (`ctrl_key_size=2'b10`) | AMBIGUOUS |
| START [0] | Self-clearing | `ctrl_start <= 1'b0` every cycle; write sets for 1 cycle | MATCH |
| IRQ_EN [1] | Enable IRQ | `ctrl_irq_en`, R/W, gated in irq equation | MATCH |
| MODE [2] | Encrypt/Decrypt | `ctrl_decrypt`, 0=enc, 1=dec | MATCH (renamed) |
| KEY_SIZE [4:3] | Not in locked spec | `ctrl_key_size[1:0]` 00=128,01=192,10=256 | DEVIATION (arch is AES-256 only) |
| MODE_CBC [5] | Not in locked spec | `ctrl_mode_cbc` | DEVIATION (arch is CBC only) |
| MODE_CTR [6] | Not in locked spec | `ctrl_mode_ctr` | DEVIATION (arch is CBC only) |
| SOFT_RST [7] | Not in locked spec | `ctrl_soft_rst`, self-clearing | DEVIATION |
| [31:8] | Reserved | RAZ/WI | MATCH |
| BUSY guard on writes | Not specified | No guard — config writable while BUSY | AMBIGUOUS |

#### 0x04 — AES_STATUS

| Property | Spec | RTL | Status |
|---|---|---|---|
| Address | 0x04 | 0x04 (`wr_addr[7:2]==6'h01`) | MATCH |
| BUSY [0] | Required | `core_busy` from FSM, RO | MATCH |
| DONE [1] | W1C | `status_done`, set by `core_done_r` pulse, W1C | MATCH |
| KEY_READY [2] | Not in locked spec | `status_key_ready` | DEVIATION |
| ERR [3] | Not in locked spec | `status_err` — NEVER SET by hardware | DEVIATION + DEAD BIT |
| [31:4] | Reserved | RAZ | MATCH |

#### 0x08 — AES_BLK_CNT

| Property | Spec | RTL | Status |
|---|---|---|---|
| Address | 0x08 | 0x08 (`wr_addr[7:2]==6'h02`) | MATCH |
| TOTAL_BLOCKS [15:0] | Controls block count | Stored in `total_blocks[15:0]` | MATCH (stored) |
| TOTAL_BLOCKS consumed | FSM decrements and uses it | NEVER READ by FSM — `blk_remaining` hardwired to 1 | FAIL |
| DONE_BLOCKS [31:16] | Not in locked spec | `core_done_blocks` from `done_blocks` counter | DEVIATION |

#### 0x10–0x2C — AES_KEY0–KEY7

| Property | Spec | RTL | Status |
|---|---|---|---|
| Addresses | 0x10,0x14,0x18,0x1C,0x20,0x24,0x28,0x2C | Same (`6'h04`–`6'h0B`) | MATCH |
| Write-only | Yes | Reads return 32'b0 | MATCH |
| key[31:0]←KEY0 | Required | `key_data[31:0]` | MATCH |
| key[63:32]←KEY1 | Required | `key_data[63:32]` | MATCH |
| key[95:64]←KEY2 | Required | `key_data[95:64]` | MATCH |
| key[127:96]←KEY3 | Required | `key_data[127:96]` | MATCH |
| key[159:128]←KEY4 | Required | `key_data[159:128]` | MATCH |
| key[191:160]←KEY5 | Required | `key_data[191:160]` | MATCH |
| key[223:192]←KEY6 | Required | `key_data[223:192]` | MATCH |
| key[255:224]←KEY7 | Required | `key_data[255:224]` | MATCH |
| Reset to zero | Yes | Reset to 256'b0 | MATCH |

#### 0x30–0x3C — AES_IV0–IV3

| Property | Spec | RTL | Status |
|---|---|---|---|
| Addresses | 0x30,0x34,0x38,0x3C | Same (`6'h0C`–`6'h0F`) | MATCH |
| iv[31:0]←IV0 | Required | `iv_data[31:0]` | MATCH |
| iv[63:32]←IV1 | Required | `iv_data[63:32]` | MATCH |
| iv[95:64]←IV2 | Required | `iv_data[95:64]` | MATCH |
| iv[127:96]←IV3 | Required | `iv_data[127:96]` | MATCH |
| Connected to CBC | Required | `iv_data` NEVER READ in `aes_core_top` | FAIL |
| Reset to zero | Yes | Reset to 128'b0 | MATCH |

---

## C. Signal Audit

### APB Signals (Locked Spec Requirement)

| Signal | Required | Present in RTL | Notes |
|---|---|---|---|
| PCLK | Yes | ABSENT | AXI `aclk` used instead |
| PRESETn | Yes | ABSENT | AXI `aresetn` used instead |
| PSEL | Yes | ABSENT | No APB decode logic |
| PENABLE | Yes | ABSENT | No APB phase logic |
| PWRITE | Yes | ABSENT | No APB write signal |
| PADDR | Yes | ABSENT | AXI `s_axi_awaddr`/`s_axi_araddr` used |
| PWDATA | Yes | ABSENT | AXI `s_axi_wdata` used |
| PRDATA | Yes | ABSENT | AXI `s_axi_rdata` used |
| PREADY | Yes | ABSENT | AXI `s_axi_rvalid`/`s_axi_bvalid` used |
| PSLVERR | Optional | ABSENT | Not implemented |

### AXI4 Data-Plane Signals (Locked Spec Requirement)

| Signal | Required | Present in RTL | Notes |
|---|---|---|---|
| S3 slave (input @ 0x9000_0010) | Yes | ABSENT | No dedicated data-plane AXI slave |
| S4 slave (output @ 0x9000_0020) | Yes | ABSENT | No dedicated data-plane AXI slave |
| 64-bit WDATA | Yes | ABSENT | RTL uses 32-bit AXI4-Lite only |
| WLAST | Yes | ABSENT | AXI4-Lite has no WLAST |
| RLAST | Yes | ABSENT | AXI4-Lite has no RLAST |

### AXI4-Lite Signals (Present in RTL — Control plane only)

| Signal | Width | Direction | Function |
|---|---|---|---|
| `aclk` | 1 | in | Clock |
| `aresetn` | 1 | in | Active-LOW sync reset |
| `s_axi_awaddr` | AXI_ADDR_WIDTH (8) | in | Write address |
| `s_axi_awprot` | 3 | in | Protection type (unused) |
| `s_axi_awvalid` | 1 | in | Write address valid |
| `s_axi_awready` | 1 | out | Write address ready |
| `s_axi_wdata` | 32 | in | Write data |
| `s_axi_wstrb` | 4 | in | Byte strobes |
| `s_axi_wvalid` | 1 | in | Write data valid |
| `s_axi_wready` | 1 | out | Write data ready |
| `s_axi_bresp` | 2 | out | Write response (always OKAY) |
| `s_axi_bvalid` | 1 | out | Write response valid |
| `s_axi_bready` | 1 | in | Write response ready |
| `s_axi_araddr` | AXI_ADDR_WIDTH (8) | in | Read address |
| `s_axi_arprot` | 3 | in | Protection type (unused) |
| `s_axi_arvalid` | 1 | in | Read address valid |
| `s_axi_arready` | 1 | out | Read address ready |
| `s_axi_rdata` | 32 | out | Read data |
| `s_axi_rresp` | 2 | out | Read response (always OKAY) |
| `s_axi_rvalid` | 1 | out | Read data valid |
| `s_axi_rready` | 1 | in | Read data ready |

### FSM Signals

| Signal | Width | Type | Function |
|---|---|---|---|
| `state` | 4 | reg | Current FSM state |
| `enc_ld` | 1 | reg | Cipher core load pulse |
| `dec_ld` | 1 | reg | Inverse cipher text load pulse |
| `dec_kld` | 1 | reg | Inverse cipher key load pulse |
| `core_key_mux` | 128 | reg | Key half presented to both IP cores |
| `text_in_mux` | 128 | reg | Input text to both IP cores |
| `feedback_reg` | 128 | reg | CBC/CTR chaining register (never seeded from iv_data) |
| `blk_remaining` | 16 | reg | Block counter — hardwired to constant 1, never decremented |
| `done_blocks` | 16 | reg | Completed block counter |
| `core_busy_r` | 1 | reg | BUSY status to regfile |
| `core_done_r` | 1 | reg | DONE pulse to regfile |
| `core_key_ready_r` | 1 | reg | KEY_READY pulse to regfile |
| `core_err_r` | 1 | reg | ERR pulse — NEVER ASSERTED |

### CBC Signals

| Signal | Present | Correct | Notes |
|---|---|---|---|
| `feedback_reg` | YES | PARTIAL | Never loaded from `iv_data` |
| IV seed path | NO | FAIL | `iv_data` wire exists but is unread |
| CBC-E XOR | YES | PARTIAL | `din_data ^ feedback_reg` correct equation; wrong initial value |
| CBC-D XOR | YES | FAIL | Uses updated `feedback_reg` (current Ck), not previous C(k-1) |
| Chaining update (enc) | YES | MATCH | `feedback_reg <= raw_text_out` |
| Chaining update (dec) | YES | MATCH | `feedback_reg <= din_data` |

### AES Core Signals

| Signal | Core | Width | Direction | Notes |
|---|---|---|---|---|
| `enc_ld` | u_cipher | 1 | FSM→core | Load pulse |
| `enc_done` | u_cipher | 1 | core→FSM | Completion (behavior NOT VERIFIABLE without IP source) |
| `enc_text_out` | u_cipher | 128 | core→FSM | Output cipher text |
| `dec_kld` | u_inv_cipher | 1 | FSM→core | Key load pulse |
| `dec_kdone` | u_inv_cipher | 1 | core→FSM | Key expansion done |
| `dec_ld` | u_inv_cipher | 1 | FSM→core | Text load pulse |
| `dec_done` | u_inv_cipher | 1 | core→FSM | Decryption done |
| `dec_text_out` | u_inv_cipher | 128 | core→FSM | Output plain text |

### Missing Signals (Required by Spec, Absent in RTL)

| Signal | Required By | Status |
|---|---|---|
| Input FIFO write/read ports | Arch spec | ABSENT |
| Output FIFO write/read ports | Arch spec | ABSENT |
| beat0_reg, beat1_reg | Arch spec | ABSENT |
| block_assembled[127:0] | Arch spec | ABSENT |
| out_beat0, out_beat1 | Arch spec | ABSENT |
| AXI S3 slave ports | Arch spec | ABSENT |
| AXI S4 slave ports | Arch spec | ABSENT |
| APB ports (PSEL, PENABLE, etc.) | Arch spec | ABSENT |

---

## D. RTL-to-Spec Compliance Matrix

| # | Specification Item | Required Behavior | RTL Implementation | RTL Signal/Module | Status | Issue |
|---|---|---|---|---|---|---|
| 1 | APB control plane | APB register interface | AXI4-Lite interface | `aes_regfile` | FAIL | Wrong bus protocol — APB absent, AXI4-Lite used |
| 2 | AXI4 64-bit data plane | AXI4 S3/S4, 64-bit WDATA | Not present | None | FAIL | Entire data-plane AXI4 slave absent |
| 3 | AXI4 input slave S3 @ 0x9000_0010 | AXI4 slave for data input | Not present | None | FAIL | No S3 slave |
| 4 | AXI4 output slave S4 @ 0x9000_0020 | AXI4 slave for data output | Not present | None | FAIL | No S4 slave |
| 5 | AES_CTRL address 0x00 | APB addr 0x00 | AXI4-Lite addr 0x00 | `wr_addr[7:2]==6'h00` | DEVIATION | Address correct, bus wrong |
| 6 | AES_STATUS address 0x04 | APB addr 0x04 | AXI4-Lite addr 0x04 | `wr_addr[7:2]==6'h01` | DEVIATION | Address correct, bus wrong |
| 7 | AES_BLK_CNT address 0x08 | APB addr 0x08 | AXI4-Lite addr 0x08 | `wr_addr[7:2]==6'h02` | DEVIATION | Address correct, bus wrong |
| 8 | AES_KEY0–7 addresses 0x10–0x2C | APB addrs | AXI4-Lite addrs | `6'h04`–`6'h0B` | DEVIATION | Addresses correct, bus wrong |
| 9 | AES_IV0–3 addresses 0x30–0x3C | APB addrs | AXI4-Lite addrs | `6'h0C`–`6'h0F` | DEVIATION | Addresses correct, bus wrong |
| 10 | AES_CTRL.START self-clearing | Write 1 starts, auto-clears | `ctrl_start <= 1'b0` each cycle | `ctrl_start` | PASS | One-cycle pulse confirmed |
| 11 | AES_CTRL.IRQ_EN | Enable interrupt | `ctrl_irq_en`, gating in irq equation | `ctrl_irq_en` | PASS | Correct |
| 12 | AES_CTRL.MODE | Encrypt/Decrypt | `ctrl_decrypt` bit [2] | `ctrl_decrypt` | PASS | Functional, renamed |
| 13 | AES_STATUS.BUSY | Core busy flag | `core_busy_r` from FSM | `core_busy_r` | PASS | Set on START, cleared on DONE |
| 14 | AES_STATUS.DONE | W1C done flag | `status_done` W1C | `status_done` | PASS | Sticky, W1C correct |
| 15 | AES_BLK_CNT TOTAL_BLOCKS stored | Store block count | `total_blocks[15:0]` | `total_blocks` | PASS | Register stores value |
| 16 | AES_BLK_CNT controls operation | FSM uses count | `blk_remaining` hardwired to 1, never decremented, `total_blocks` never read | `blk_remaining` | FAIL | Multi-block not functional |
| 17 | Key packing {KEY7..KEY0} | key[255:0]={KEY7..KEY0} | `key_data[255:224]=KEY7` ... `key_data[31:0]=KEY0` | `key_data` | PASS | Correct assembly |
| 18 | IV packing {IV3..IV0} | iv[127:0]={IV3..IV0} | `iv_data[127:96]=IV3` ... `iv_data[31:0]=IV0` | `iv_data` | PASS | Correct assembly |
| 19 | IV connected to CBC datapath | `feedback_reg` seeded from IV | `iv_data` NEVER READ in `aes_core_top` | None | FAIL | iv_data architecturally disconnected |
| 20 | AES-256 key expansion (14 rounds) | 256-bit key, 14 rounds | ASICS.ws AES-128 IP (10 rounds), two 128-bit ld pulses | `u_cipher`, `u_inv_cipher` | FAIL | AES-128 IP, not AES-256 |
| 21 | AES-256 encryption path | AES-256 encryption | AES-128 cipher with two-phase key (non-standard) | `u_cipher` | FAIL | Not AES-256 |
| 22 | AES-256 decryption path | AES-256 decryption | AES-128 inv cipher with two-phase key (non-standard) | `u_inv_cipher` | FAIL | Not AES-256 |
| 23 | CBC XOR: Xk = Pk XOR C(k-1) | Pre-AES XOR with prior ciphertext | `din_data ^ feedback_reg` (encrypt path) | `text_in_mux` | DEVIATION | Equation correct; initial value wrong (0 not IV) |
| 24 | CBC chaining: CBC_state = Ck after encrypt | Update chain after encrypt | `feedback_reg <= raw_text_out` in ST_DATA_WAIT | `feedback_reg` | PASS | Correct update |
| 25 | CBC decrypt: Pk = AES^-1(Ck) XOR C(k-1) | Post-AES XOR with previous ciphertext | `raw_text_out ^ feedback_reg` but feedback already updated to current Ck | `dout_internal` | FAIL | Wrong ciphertext used in XOR |
| 26 | CBC-D: Next_CBC_state = Ck (current ciphertext in) | Save current ciphertext | `feedback_reg <= din_data` in ST_DATA_WAIT | `feedback_reg` | PASS | Correct save (but too early for dout XOR) |
| 27 | C0 = IV (first block uses IV) | First block CBC XOR uses IV | `feedback_reg` initialized to 0, not IV | `feedback_reg` | FAIL | IV register never seeds feedback |
| 28 | 64-bit beat assembly | Two 64-bit beats form 128-bit block | Not present — 128-bit DIN written directly via 4×32-bit registers | None | FAIL | No beat assembly |
| 29 | Beat0 = block[63:0] | First 64-bit beat maps to lower half | Not present | None | FAIL | No beat concept in RTL |
| 30 | Beat1 = block[127:64] | Second 64-bit beat maps to upper half | Not present | None | FAIL | No beat concept in RTL |
| 31 | block[127:0] = {Beat1, Beat0} | Correct assembly order | Not present | None | FAIL | No beat assembly |
| 32 | 128-bit output splitting | Output split into two 64-bit beats | Not present — 128-bit DOUT read via 4×32-bit registers | None | FAIL | No beat splitting |
| 33 | Input FIFO | Buffers incoming AXI data | Not present | None | FAIL | No FIFO |
| 34 | Output FIFO | Buffers outgoing AXI data | Not present | None | FAIL | No FIFO |
| 35 | Input FIFO backpressure | FSM waits when FIFO empty | Not present | None | FAIL | No backpressure |
| 36 | Output FIFO backpressure | FSM stalls when FIFO full | Not present | None | FAIL | No backpressure |
| 37 | AXI4 valid/ready handshaking (data plane) | AXI4 valid/ready | Not present for data plane | None | FAIL | Data-plane AXI4 absent |
| 38 | Block counter decrement per block | `remaining -= 1` per block | `blk_remaining` never decremented | `blk_remaining` | FAIL | Counter not functional |
| 39 | N=0 does not start | TOTAL_BLOCKS=0 rejected | No guard; one block always processed | None | FAIL | Zero-block guard absent |
| 40 | DONE after final output accepted | DONE after last output beat | `core_done_r` pulsed in ST_DONE immediately after core completes, not after AXI output accepted | `ST_DONE` | FAIL | DONE semantics incorrect |
| 41 | Interrupt generation | irq = IRQ_EN AND DONE | `assign irq = ctrl_irq_en & (status_done \| status_err)` | `irq` | PASS | Correct |
| 42 | Reset behavior — FSM | Reset to IDLE | `if (rst)` resets all FSM regs | `aes_core_top` | PASS | Correct |
| 43 | Reset behavior — key registers | Key cleared | Reset to 256'b0 | `key_data` | PASS | Correct |
| 44 | Reset behavior — IV registers | IV cleared | Reset to 128'b0 | `iv_data` | PASS | Correct |
| 45 | Reset behavior — status | Status cleared | Separate always block resets to 0 | `status_done` etc. | PASS | Correct |
| 46 | SOFT_RST clears key material | Key zeroized on soft reset | `key_data` only reset by `aresetn`, not `ctrl_soft_rst` | `key_data` | FAIL | Key material persists after SOFT_RST |
| 47 | SOFT_RST resets IP cores | IP cores reset | `rst_n = aresetn` only; SOFT_RST not connected to IP reset | `rst_n` | FAIL | IP cores not reset by SOFT_RST |
| 48 | Busy-state register protection | Config locked while BUSY | No guard on any register write | None | FAIL | All registers writable while BUSY |

---

## E. FSM Comparison

### Architectural FSM (Locked Spec)

```
IDLE → KEY_EXPAND → GET_BEAT0 → GET_BEAT1 → CBC_INPUT →
CORE_EXEC → CBC_OUTPUT → PUT_BEAT0 → PUT_BEAT1 →
CHECK_DONE → (GET_BEAT0 | COMPLETE)
```

### Actual RTL FSM (Extracted from aes_core_top.v)

| State | Encoding | Entry Condition | Actions | Exit Condition | Next State |
|---|---|---|---|---|---|
| ST_IDLE | 4'd0 | Reset or after ST_DONE | `core_busy_r=0` | `ctrl_start=1` | ST_KEY_LOAD1 |
| ST_KEY_LOAD1 | 4'd1 | From ST_IDLE on start | Assert `enc_ld` (enc) or `dec_kld` (dec); load `key_data[127:0]` | Unconditional (1 cycle) | ST_KEY_WAIT1 |
| ST_KEY_WAIT1 | 4'd2 | From ST_KEY_LOAD1 | Wait | `enc_done` (enc) or `dec_kdone` (dec) | ST_KEY_LOAD2 (if 256/192) or ST_DATA_LOAD (if 128) |
| ST_KEY_LOAD2 | 4'd3 | From ST_KEY_WAIT1 | Assert `enc_ld` or `dec_kld`; load second key half | Unconditional (1 cycle) | ST_KEY_WAIT2 |
| ST_KEY_WAIT2 | 4'd4 | From ST_KEY_LOAD2 | Wait | `enc_done` or `dec_kdone` | ST_DATA_LOAD |
| ST_DATA_LOAD | 4'd5 | From ST_KEY_WAIT1/2 | XOR din_data with feedback_reg (CBC enc); assert `enc_ld` or `dec_ld` | Unconditional (1 cycle) | ST_DATA_WAIT |
| ST_DATA_WAIT | 4'd6 | From ST_DATA_LOAD | Wait; update feedback_reg when done | `enc_done` or `dec_done` | ST_DONE |
| ST_DONE | 4'd7 | From ST_DATA_WAIT | Pulse `core_done_r`; increment `done_blocks`; clear `core_busy_r` | Unconditional (1 cycle) | ST_IDLE |
| ST_SOFT_RST | 4'd8 | Never entered (dead state) | None — state defined but never assigned | N/A | N/A |

### FSM Gap Analysis

| Arch FSM State | RTL Equivalent | Present | Functionally Equivalent | Notes |
|---|---|---|---|---|
| IDLE | ST_IDLE | YES | YES | — |
| KEY_EXPAND | ST_KEY_LOAD1, ST_KEY_WAIT1, ST_KEY_LOAD2, ST_KEY_WAIT2 | YES | PARTIAL | Uses AES-128 IP not AES-256 |
| GET_BEAT0 | None | NO | NO | No beat concept |
| GET_BEAT1 | None | NO | NO | No beat concept |
| CBC_INPUT | ST_DATA_LOAD (partial) | PARTIAL | NO | IV not seeded; CBC-D wrong |
| CORE_EXEC | ST_DATA_WAIT | YES | PARTIAL | AES-128 rounds not AES-256 |
| CBC_OUTPUT | dout_internal combinational | PARTIAL | NO | CBC-D timing hazard |
| PUT_BEAT0 | None | NO | NO | No output beat splitting |
| PUT_BEAT1 | None | NO | NO | No output beat splitting |
| CHECK_DONE | ST_DONE → ST_IDLE | PARTIAL | NO | blk_remaining unused; always returns to IDLE after 1 block |
| GET_BEAT0 (loop) | None | NO | NO | Multi-block not implemented |
| COMPLETE | ST_DONE | PARTIAL | NO | Done signaled before output accepted |
| ST_SOFT_RST | ST_SOFT_RST (4'd8) | YES (defined) | NO | Dead state — never entered from any transition |

---

## F. Data-Path Verification

```
APB Configuration
      ↓ FAIL — APB absent; AXI4-Lite used
AXI4-Lite Write to aes_regfile
      ↓
Key Registers (key_data[255:0])      ← PASS: correct assembly {KEY7..KEY0}
      ↓
IV Registers (iv_data[127:0])        ← PASS: correct assembly {IV3..IV0}
      ↓ FAIL — iv_data never read in aes_core_top
feedback_reg                         ← FAIL: always starts at 128'b0, not IV
      ↓
DMA
      ↓ FAIL — No DMA interface
AXI4 Data Plane
      ↓ FAIL — No AXI4 data-plane slave (S3/S4)
Input FIFO
      ↓ FAIL — No FIFO
Beat 0 / Beat 1 Assembly
      ↓ FAIL — No 64-bit beat concept; 128-bit DIN written directly via 4×32b registers
128-bit Block (din_data[127:0])      ← PARTIAL: assembled by CPU writes, not HW
      ↓
CBC XOR: text_in_mux = din_data ^ feedback_reg
      ↓ FAIL: feedback_reg=0 on first block (should be IV)
      ↓ FAIL: CBC-D XOR uses updated feedback (current Ck, not C(k-1))
AES-256 Core                         ← FAIL: ASICS.ws AES-128 IP (10 rounds, not 14)
      ↓
raw_text_out = enc_text_out or dec_text_out
      ↓
dout_internal (combinational always@(*))
      ↓ FAIL: not registered; no stable hold at DONE; CBC-D timing hazard
DOUT registers                       ← PARTIAL: readable via 4×32b AXI4-Lite reads
      ↓
128-bit Output Split
      ↓ FAIL — No beat splitter
Output FIFO
      ↓ FAIL — No FIFO
AXI4 Output (S4 @ 0x9000_0020)
      ↓ FAIL — No AXI4 output slave
DMA
      ↓ FAIL — No DMA interface
```

**Summary:** Only the register-level configuration path (APB→AXI4-Lite) and the single-block AES core invocation path have any implementation. The complete DMA/FIFO/AXI4-data-plane/beat-assembly pipeline is absent.

---

## G. Critical Issues

### CRITICAL

| # | Issue | Evidence |
|---|---|---|
| C1 | AES-256 not implemented — ASICS.ws IP is AES-128 (10 rounds). Two ld pulses with two 128-bit key halves do not constitute AES-256 key expansion or 14-round operation. All encrypted/decrypted output is cryptographically incorrect for AES-256. | IP port `key[127:0]`; spec states 10 rounds for 128-bit keys |
| C2 | Entire AXI4 data-plane absent. No S3 slave, no S4 slave, no 64-bit beat interface, no FIFO. The accelerator cannot receive or transmit data via the SoC bus fabric as specified. | No AXI S3/S4 ports in any RTL file |
| C3 | IV never connected to CBC datapath. `iv_data` wire in `aes_core_top` is not read anywhere. `feedback_reg` starts at 0. Every CBC operation uses IV=0 regardless of IV register contents. | `iv_data` declared as wire, never assigned to `feedback_reg` |
| C4 | APB control plane absent. Architecture requires APB. RTL implements AXI4-Lite. These are incompatible bus protocols with different signal sets, timing, and address decode. Direct integration into an APB bus fabric will fail. | No PSEL/PENABLE/PWRITE/PADDR/PRDATA signals anywhere |
| C5 | CBC decrypt XOR uses current ciphertext instead of previous. `feedback_reg` updated to `din_data` in ST_DATA_WAIT before `dout_internal` combinational evaluation. First block is correct; all subsequent blocks produce wrong plaintext. | `feedback_reg <= din_data` then `dout_internal = raw_text_out ^ feedback_reg` in same cycle |

### HIGH

| # | Issue | Evidence |
|---|---|---|
| H1 | TOTAL_BLOCKS register is stored but never consumed. `blk_remaining` is hardwired to constant 1 via `({16{1'b1}} & 16'd1)`. Multi-block operations always process exactly one block regardless of AES_BLK_CNT value. | `blk_remaining <= ({16{1'b1}} & 16'd1)` in ST_IDLE; `total_blocks` never read in FSM |
| H2 | DONE asserted before output is architecturally safe. `core_done_r` pulses in ST_DONE immediately after AES core completion, before any output acceptance handshake. | ST_DONE: `core_done_r <= 1'b1` with no FIFO/AXI output check |
| H3 | DOUT output is combinational with no stable hold register. `dout_internal` is an `always@(*)` block; output can change mid-read if `feedback_reg` or `din_data` change. | `always @(*) begin ... dout_internal = ...` |
| H4 | SOFT_RST does not reset key material. `key_data[255:0]` only resets on `aresetn`. A soft reset after key programming leaves the key intact — security-sensitive data not zeroized. | Reset block in write dispatch: resets only on `rst` (`~aresetn`) |
| H5 | No protection against register writes while BUSY. Configuration (key, IV, mode, block count) can be changed while an AES operation is in progress, causing undefined behavior. | No `core_busy_r` check in write dispatch `always` block |

### MEDIUM

| # | Issue | Evidence |
|---|---|---|
| M1 | SOFT_RST does not reset IP cores. `rst_n = aresetn` only. IP core internal state (round counters, intermediate results) not cleared by software reset. | `rst_n = aresetn` assignment; `ctrl_soft_rst` not wired to any IP reset |
| M2 | ERR bit in AES_STATUS is architecturally dead. `core_err_r` is never set to 1'b1 anywhere in the FSM. `status_err` can only be cleared, never set. | No assignment `core_err_r <= 1'b1` anywhere in RTL |
| M3 | ST_SOFT_RST state defined but never entered. `localparam ST_SOFT_RST = 4'd8` declared; no transition leads to it. Dead code in FSM. | `ST_SOFT_RST = 4'd8` declared; no `state <= ST_SOFT_RST` anywhere |
| M4 | AES-192 key slice incorrect. For `use_192`, second key half uses `key_data[191:64]` instead of `key_data[191:128]`. | `key_data[191:64]` in ST_KEY_WAIT1 |
| M5 | DONE_BLOCKS not reset on START. `done_blocks` accumulates across multiple START operations. | No `done_blocks <= 0` on `ctrl_start` in ST_IDLE |
| M6 | Both AES IP cores run simultaneously. `core_key_mux` and `text_in_mux` shared; unselected core processes every operation spuriously, consuming power and producing indeterminate internal state. | Single `core_key_mux` and `text_in_mux` connected to both `u_cipher` and `u_inv_cipher` |

### LOW

| # | Issue | Evidence |
|---|---|---|
| L1 | N=0 block count guard absent. Writing TOTAL_BLOCKS=0 and asserting START will process one block (blk_remaining=1 hardwired). | No `if (total_blocks == 0)` check |
| L2 | `s_axi_awready` reset to 1'b0. First write after reset requires one cycle for awready to assert. | `s_axi_awready <= 1'b0` in AW reset block |
| L3 | IRQ_CLR has no KEY_READY clear path. Only direct W1C write to AES_STATUS[2] can clear KEY_READY. | IRQ_CLR[0] maps to `status_done`, IRQ_CLR[1] to `status_err` only |
| L4 | KEY_SIZE[4:3]=2'b11 silently accepted. Invalid encoding not detected; silently degrades to AES-128 path. | No check for `ctrl_key_size==2'b11` |
| L5 | AXI4-Lite data width is 32 bits. Locked spec requires 64-bit data beats on the AXI4 data plane. Even if the control bus were considered acceptable, DIN register writes require 4 separate 32-bit transactions per 128-bit block. | `s_axi_wdata` is 32-bit |

---

## H. Verification Test Matrix

### Basic Operation

| Test ID | Feature | Stimulus | Expected Result | RTL Feasibility |
|---|---|---|---|---|
| BAS-001 | One-block AES-128 ECB encrypt | Write key (128-bit), write DIN, assert START with KEY_SIZE=00, MODE_CBC=0 | BUSY asserts, DONE asserts, DOUT = AES-128-ECB(key, plaintext) | FEASIBLE (AES-128 only) |
| BAS-002 | One-block AES-128 ECB decrypt | Write key (128-bit), write DIN (ciphertext), DECRYPT=1, START | DONE asserts, DOUT = plaintext | FEASIBLE |
| BAS-003 | One-block AES-256 ECB encrypt | Write all 8 key registers, KEY_SIZE=10, write DIN, START | DONE asserts, DOUT = AES-256(key, plaintext) | WILL FAIL — AES-128 IP only |
| BAS-004 | Multiple-block encryption (N=3) | Write AES_BLK_CNT=3, write DIN, START; repeat for each block | 3 DONE pulses, correct output per block | WILL FAIL — blk_remaining hardwired to 1 |
| BAS-005 | Multiple-block decryption (N=3) | Same as BAS-004 but DECRYPT=1 | 3 correct decryptions | WILL FAIL |

### CBC Correctness

| Test ID | Feature | Stimulus | Expected Result | RTL Feasibility |
|---|---|---|---|---|
| CBC-001 | Known AES-256-CBC encrypt vector (NIST) | Write 256-bit key, 128-bit IV, 128-bit plaintext, MODE_CBC=1, START | DOUT matches NIST AES-256-CBC ciphertext | WILL FAIL — AES-128 IP; IV not seeded |
| CBC-002 | Known AES-256-CBC decrypt vector | Write key, IV, ciphertext, DECRYPT=1, MODE_CBC=1, START | DOUT matches NIST plaintext | WILL FAIL — CBC-D XOR bug; AES-128 IP |
| CBC-003 | AES-128 CBC encrypt, IV=0 (workaround for IV bug) | Write 128-bit key, IV=0, write plaintext, MODE_CBC=1, START | DOUT = AES-128-CBC(key, IV=0, P0) | FEASIBLE with IV=0 only |
| CBC-004 | CBC chaining — block 2 uses block 1 ciphertext | Two-block CBC encrypt | Block 2 plaintext XOR'd with block 1 ciphertext | WILL FAIL — multi-block not functional |
| CBC-005 | CBC-D chaining correctness | Two-block CBC decrypt, check P1 = AES^-1(C1) XOR C0 | Correct P1 | WILL FAIL — feedback timing bug |
| CBC-006 | Different IV produces different output | Same key/plaintext, different IV | Different ciphertext | WILL FAIL — IV not consumed |
| CBC-007 | Different key produces different output | Same IV/plaintext, different key | Different ciphertext | FEASIBLE |

### Beat Ordering

| Test ID | Feature | Stimulus | Expected Result | RTL Feasibility |
|---|---|---|---|---|
| BEAT-001 | Beat 0 = block[63:0] assembly | Send 64-bit Beat 0 then Beat 1 via AXI S3 | block[63:0] from Beat 0 | WILL FAIL — no AXI S3 slave, no beat concept |
| BEAT-002 | Beat 1 = block[127:64] assembly | Send Beat 1 after Beat 0 | block[127:64] from Beat 1 | WILL FAIL |
| BEAT-003 | Output beat 0 ordering | Read output via AXI S4 | First read = ciphertext[63:0] | WILL FAIL — no AXI S4 slave |
| BEAT-004 | Output beat 1 ordering | Second read = ciphertext[127:64] | Correct upper half | WILL FAIL |
| BEAT-005 | Deliberate byte-order reversal | Swap Beat 0/Beat 1 | Output differs from correct | NOT TESTABLE — no beat interface |

### Block Count

| Test ID | Feature | Stimulus | Expected Result | RTL Feasibility |
|---|---|---|---|---|
| BLK-001 | N=1 single block | AES_BLK_CNT=1, START | One encryption, DONE after 1 block | FEASIBLE (blk_remaining=1 hardwired) |
| BLK-002 | N=2 two blocks | AES_BLK_CNT=2, START | Two encryptions, DONE after 2 blocks | WILL FAIL — only 1 block processed |
| BLK-003 | N=8 multiple blocks | AES_BLK_CNT=8, START | Eight blocks, correct chaining | WILL FAIL |
| BLK-004 | N=0 rejection | AES_BLK_CNT=0, START | No operation initiated | WILL FAIL — 1 block always processed |
| BLK-005 | DONE_BLOCKS increment | Monitor DONE_BLOCKS after each block | Increments by 1 per block | FEASIBLE for N=1 |
| BLK-006 | DONE_BLOCKS reset on START | Assert START twice, read DONE_BLOCKS | Resets to 0 on second START | WILL FAIL — not reset on START |

### FIFO / Backpressure

| Test ID | Feature | Stimulus | Expected Result | RTL Feasibility |
|---|---|---|---|---|
| FIFO-001 | Input FIFO empty stall | Start with empty input FIFO | FSM waits at GET_BEAT0 | NOT TESTABLE — no FIFO |
| FIFO-002 | Only Beat 0 in input FIFO | Write one beat, hold second beat | FSM waits at GET_BEAT1 | NOT TESTABLE — no FIFO |
| FIFO-003 | Output FIFO full | Fill output FIFO before START | FSM stalls before PUT_BEAT0 | NOT TESTABLE — no FIFO |
| FIFO-004 | Output FIFO one free entry | One slot remaining | RTL safely completes or stalls | NOT TESTABLE — no FIFO |
| FIFO-005 | DMA output stall | Hold AXI RREADY low | Output data preserved until accepted | NOT TESTABLE — no AXI S4 |
| FIFO-006 | Intermittent AXI WVALID | Toggle WVALID during block write | Correct assembly maintained | NOT TESTABLE — no data-plane AXI |

### Control

| Test ID | Feature | Stimulus | Expected Result | RTL Feasibility |
|---|---|---|---|---|
| CTRL-001 | START while idle | Write START=1 to AES_CTRL | BUSY asserts, FSM moves to ST_KEY_LOAD1 | FEASIBLE |
| CTRL-002 | START while busy | Assert START again while BUSY=1 | START ignored; current operation continues | FEASIBLE — FSM only checks START in ST_IDLE |
| CTRL-003 | Key write while busy | Write AES_KEY0 while BUSY=1 | Key register updated mid-operation | WILL FAIL — no BUSY guard |
| CTRL-004 | IV write while busy | Write AES_IV0 while BUSY=1 | IV updated mid-operation | WILL FAIL — no BUSY guard |
| CTRL-005 | DONE clearing via STATUS | Write STATUS[1]=1 while DONE=1 | DONE clears; IRQ deasserts | FEASIBLE |
| CTRL-006 | DONE clearing via IRQ_CLR | Write IRQ_CLR[0]=1 | DONE clears | FEASIBLE |
| CTRL-007 | IRQ_EN=0, verify no interrupt | Set IRQ_EN=0, complete operation | irq stays deasserted | FEASIBLE |
| CTRL-008 | IRQ_EN=1, verify interrupt | Set IRQ_EN=1, complete operation | irq asserts after DONE | FEASIBLE |
| CTRL-009 | SOFT_RST during idle | Write SOFT_RST=1 | FSM resets, feedback_reg cleared; key NOT cleared | FEASIBLE |
| CTRL-010 | SOFT_RST during AES processing | Write SOFT_RST=1 mid-operation | FSM aborts, IP core NOT reset | FEASIBLE (partial) |

### Reset

| Test ID | Feature | Stimulus | Expected Result | RTL Feasibility |
|---|---|---|---|---|
| RST-001 | Hard reset while idle | Assert aresetn=0 | All registers to reset values | FEASIBLE |
| RST-002 | Hard reset during key expansion | Assert aresetn=0 during ST_KEY_WAIT1 | FSM returns to ST_IDLE, key cleared | FEASIBLE |
| RST-003 | Hard reset during AES processing | Assert aresetn=0 during ST_DATA_WAIT | FSM resets, in-progress operation aborted | FEASIBLE |
| RST-004 | Hard reset while output pending | Assert aresetn=0 with DONE=1 | Status cleared, DOUT returns to 0 | FEASIBLE (DOUT is combinational) |
| RST-005 | SOFT_RST key clear verification | Program key, assert SOFT_RST, read key | Key should read 0 (but won't — only hard reset clears key) | WILL FAIL — key not cleared by SOFT_RST |
| RST-006 | Verify IP core reset by SOFT_RST | Assert SOFT_RST during IP operation | IP core should reset | WILL FAIL — SOFT_RST not wired to IP reset |

---

## I. Final Verdict

### Evidence Summary

**PASS items (17):** Register addresses, START self-clearing, IRQ_EN gating, DECRYPT select, BUSY RO, DONE W1C, key assembly {KEY7..KEY0}, IV assembly {IV3..IV0}, IV register R/W, DIN WO, DOUT read path, key reset, IV reset, status reset, hard reset polarity, IRQ equation, AXI4-Lite handshake (control plane only).

**FAIL items (22):** APB absent, AXI4 data plane absent, S3/S4 slaves absent, AES-256 not implemented, IV not connected, CBC-D XOR wrong, TOTAL_BLOCKS unused, beat assembly absent, beat splitter absent, FIFO absent, backpressure absent, N=0 guard absent, DONE timing wrong, SOFT_RST incomplete, key protection absent, busy-guard absent, ERR dead, multi-block absent.

**DEVIATION items (7):** AXI4-Lite instead of APB (addresses match, bus wrong), extra registers (IRQ_CLR, DIN, DOUT, KEY_READY, DONE_BLOCKS), KEY_SIZE/MODE_CBC/MODE_CTR fields not in locked spec.

### Conclusion

# ARCHITECTURAL MISMATCHES FOUND

The existing AES RTL does not correctly implement the locked AES-256 CBC architectural specification.

The following architectural contracts are violated:

1. The IP core is AES-128, not AES-256. No amount of FSM wrapping produces AES-256 from an AES-128 cipher.
2. The control bus is AXI4-Lite. The locked spec requires APB. These are incompatible.
3. The entire AXI4 data plane (S3 input slave, S4 output slave, 64-bit beats, FIFOs, beat assembly, beat splitting) is absent.
4. The IV registers are populated but architecturally disconnected. No CBC operation uses the programmed IV.
5. The block count register is populated but the FSM hardwires operation to exactly one block regardless.
6. CBC decryption produces incorrect plaintext for all blocks after the first due to a feedback register timing error.

The RTL implements a partial, single-block, AES-128, CPU-polled, register-based accelerator. It does not implement the locked AES-256 CBC DMA-driven streaming accelerator with APB control and AXI4 data planes.

**These issues must be resolved before SoC integration.**

---

*Audit performed on: rtl/aes_core_top.v, rtl/aes_regfile.v*
*Referenced: doc/aes_regset.md, doc/aes_rtl_audit.md, ASICS.ws AES Rijndael IP Core Rev 1.1*
*No RTL was modified during this audit.*
