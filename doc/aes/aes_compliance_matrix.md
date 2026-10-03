# AES-256 CBC RTL-to-Specification Compliance Matrix
## Project: RISC-V Based Cryptographic Telemetry Gateway SoC
## Date: 2026-08-29
## Audit Type: READ-ONLY — No RTL modified
## RTL Files Audited: rtl/aes_core_top.v, rtl/aes_regfile.v

---

## Locked Architectural Baseline (Reference Contract)

| Property | Locked Value |
|---|---|
| Algorithm | AES-256, CBC mode only |
| Key | 256-bit |
| IV | 128-bit |
| Block | 128-bit |
| Data bus | AXI4, 64-bit beats |
| Beats/block | 2 (Beat0=block[63:0], Beat1=block[127:64]) |
| Block count | AES_BLK_CNT |
| Control plane | APB |
| Data-plane input | AXI4 Slave S3 @ 0x9000_0010 |
| Data-plane output | AXI4 Slave S4 @ 0x9000_0020 |
| AES_CTRL | APB offset 0x00 |
| AES_STATUS | APB offset 0x04 |
| AES_BLK_CNT | APB offset 0x08 |
| AES_KEY0–7 | APB offsets 0x10–0x2C |
| AES_IV0–3 | APB offsets 0x30–0x3C |

---

## Complete RTL-to-Specification Compliance Matrix

### Section A — AES Algorithm Requirements

| Req ID | Architectural Requirement | Expected Interface/Signal | Expected Behavior | RTL Implementation | RTL Signal/Module/File | Status | Severity | Exact Discrepancy | Required Architectural Resolution |
|---|---|---|---|---|---|---|---|---|---|
| A-01 | AES-256 key width = 256 bits | `key[255:0]` to AES core | 256-bit key accepted and used | `key_data[255:0]` assembled in `aes_regfile`; however only `key_data[127:0]` (first 128 bits) is presented to `core_key_mux` during data processing in ST_DATA_LOAD | `key_data`, `core_key_mux`, `aes_regfile.v` line: `6'h04`–`6'h0B`; `aes_core_top.v`: `core_key_mux <= key_data[127:0]` in ST_DATA_LOAD | PARTIALLY COMPLIANT | CRITICAL | 256-bit key is stored in registers but only the lower 128 bits (`key_data[127:0]`) are fed to the IP core during encryption/decryption. Upper 128 bits (`key_data[255:128]`) are never used by the AES core during data processing. | AES core must accept and use all 256 bits simultaneously, or a true AES-256 key schedule must generate 15 round keys from the full 256-bit key before data processing begins. |
| A-02 | AES-256 requires 14 rounds | 14-round cipher execution | Every 128-bit block encrypted in exactly 14 rounds | ASICS.ws `aes_cipher_top` and `aes_inv_cipher_top` are AES-128 IP cores implementing 10 rounds | `u_cipher`, `u_inv_cipher` in `aes_core_top.v`; IP spec: "10 cycles for the 10 rounds" | MISSING | CRITICAL | RTL instantiates an AES-128 IP (10 rounds). AES-256 requires 14 rounds. The IP core is architecturally incapable of AES-256 regardless of how many key halves are fed to it. | Replace `aes_cipher_top`/`aes_inv_cipher_top` with a true AES-256 IP core that implements 14 rounds and accepts a 256-bit key. |
| A-03 | AES-256 key expansion | 256-bit key → 15 round keys (Nk=8, Nr=14) | Round keys correctly derived before first block processed | RTL uses two sequential `ld` pulses with two 128-bit key halves to the AES-128 IP. This performs two independent AES-128 key expansions, not an AES-256 key schedule. | ST_KEY_LOAD1, ST_KEY_LOAD2, ST_KEY_WAIT1, ST_KEY_WAIT2 in `aes_core_top.v` | MISSING | CRITICAL | AES-256 key schedule (FIPS 197 §5.2) requires a single 256-bit input to derive 15 round keys. The RTL performs two AES-128 key expansions, producing different round keys than AES-256 specifies. | Implement or instantiate an AES-256 key expansion module that takes `key_data[255:0]` and produces 15 correct 128-bit round keys. |
| A-04 | AES-256 encryption path | `enc_ld`, `key[255:0]`, `text_in[127:0]` → `text_out[127:0]` | 14-round AES-256 encryption | `u_cipher` (AES-128 10-round encrypt). Input: `text_in_mux[127:0]` with `core_key_mux[127:0]` (only lower 128 bits of 256-bit key) | `aes_cipher_top u_cipher` in `aes_core_top.v` | MISSING | CRITICAL | Encryption produces AES-128 output (10 rounds, 128-bit key), not AES-256 output (14 rounds, 256-bit key). Output is cryptographically incorrect for AES-256. | Replace with AES-256 compliant encrypt core. |
| A-05 | AES-256 decryption path | `dec_kld`, `dec_ld`, `key[255:0]`, `text_in[127:0]` → `text_out[127:0]` | 14-round AES-256 decryption | `u_inv_cipher` (AES-128 10-round decrypt) | `aes_inv_cipher_top u_inv_cipher` in `aes_core_top.v` | MISSING | CRITICAL | Decryption produces AES-128 inverse cipher output, not AES-256. | Replace with AES-256 compliant decrypt core. |
| A-06 | CBC encryption: Xk = Pk XOR C(k-1) | Pre-AES XOR with previous ciphertext | `text_in = plaintext XOR C(k-1)` before each AES block | `text_in_mux <= din_data ^ feedback_reg` in ST_DATA_LOAD (encrypt CBC path) | `aes_core_top.v` ST_DATA_LOAD: `text_in_mux <= (ctrl_mode_cbc) ? (din_data ^ feedback_reg) : ...` | PARTIALLY COMPLIANT | CRITICAL | Equation is structurally correct. However `feedback_reg` initializes to `128'b0` (not IV) because `iv_data` is never loaded into `feedback_reg`. For block 0, XOR is with 0 instead of IV. Functionally wrong for all correctly-configured CBC sequences. | Load `iv_data` into `feedback_reg` at the start of each transaction (on `ctrl_start`). |
| A-07 | CBC encryption: C0 = IV (first block uses configured IV) | `feedback_reg` = IV at transaction start | `text_in[0] = P0 XOR IV` | `feedback_reg` resets to `128'b0`; `iv_data` wire declared in `aes_core_top` but never assigned to `feedback_reg` | `aes_core_top.v`: `feedback_reg <= 128'b0` in reset; `iv_data` wire connected from regfile but unread in FSM | MISSING | CRITICAL | `iv_data` is architecturally disconnected. The wire carrying IV register values from `aes_regfile` to `aes_core_top` is never read. First block CBC XOR uses 0, not the programmed IV. | Add `if (ctrl_start) feedback_reg <= iv_data;` to the ST_IDLE transition (pending RTL change approval). |
| A-08 | CBC encryption: CBC_state update = Ck after each block | `feedback_reg <= ciphertext_output` | After each encrypt block, feedback = new ciphertext | `feedback_reg <= raw_text_out` in ST_DATA_WAIT (encrypt CBC path). `raw_text_out = enc_text_out` when `ctrl_decrypt=0` | `aes_core_top.v` ST_DATA_WAIT: `if (!ctrl_decrypt && ctrl_mode_cbc) feedback_reg <= raw_text_out` | COMPLIANT | LOW | Chaining update equation is correct assuming the core output were genuine AES-256. | None for this specific equation (subject to AES-256 core fix). |
| A-09 | CBC decryption: Xk = AES^-1_K(Ck) | Inverse cipher applied to ciphertext | `dec_ld` triggers inverse cipher on raw ciphertext | `text_in_mux <= din_data` then `dec_ld <= 1'b1` in ST_DATA_LOAD (decrypt path) | `aes_core_top.v` ST_DATA_LOAD decrypt branch | COMPLIANT | LOW | Ciphertext is correctly routed to inverse cipher without pre-XOR. Equation structurally correct (subject to AES-256 core fix). | None for this specific path. |
| A-10 | CBC decryption: Pk = Xk XOR C(k-1) (post-AES XOR with previous ciphertext) | `dout = dec_output XOR C(k-1)` | Final XOR uses the ciphertext from the previous block | `dout_internal = raw_text_out ^ feedback_reg` in combinational `always@(*)`. BUT by the time this evaluates after ST_DATA_WAIT, `feedback_reg` has already been updated to `din_data` (current Ck) in the same ST_DATA_WAIT cycle | `aes_core_top.v`: `dout_internal = raw_text_out ^ feedback_reg` (comb); ST_DATA_WAIT: `feedback_reg <= din_data` (registered, same trigger cycle) | CONTRADICTORY | CRITICAL | For block k≥1: `feedback_reg` holds Ck (current) when `dout_internal` evaluates, producing `AES^-1(Ck) XOR Ck` instead of `AES^-1(Ck) XOR C(k-1)`. All CBC-D blocks after block 0 produce incorrect plaintext. Block 0 is also wrong because IV is not loaded. | Store C(k-1) in a separate register before updating `feedback_reg`. XOR `dec_text_out` with the saved C(k-1), not the updated feedback. |
| A-11 | CBC-D: Next_CBC_state = Ck (raw ciphertext in, not plaintext) | `feedback_reg` updated to raw `din_data` after decrypt | Next block XOR uses the ciphertext that was just decrypted | `feedback_reg <= din_data` in ST_DATA_WAIT (decrypt CBC path). `din_data` is the ciphertext fed in (correct value) | `aes_core_top.v` ST_DATA_WAIT: `else if (ctrl_decrypt && ctrl_mode_cbc) feedback_reg <= din_data` | COMPLIANT | LOW | The chaining source value is correct — `din_data` is the ciphertext input. The timing issue (see A-10) is the problem, not the source assignment. | No change needed for source value selection. Timing of XOR application must be fixed. |
| A-12 | Raw Ck retained during CBC-D before final XOR | C(k-1) saved before overwrite | `C(k-1)` must remain accessible when computing `Pk = Xk XOR C(k-1)` | No separate previous-ciphertext register exists. `feedback_reg` is updated to `din_data` (current Ck) in the same always block that feeds `dout_internal` with `feedback_reg` | `aes_core_top.v`: no `prev_ciphertext` register defined | MISSING | CRITICAL | Architecture requires C(k-1) to be held until after post-AES XOR. RTL has no such register. Once `feedback_reg <= din_data` executes in ST_DATA_WAIT, C(k-1) is lost. | Add `reg [127:0] prev_feedback` that captures `feedback_reg` before it is updated, and use `prev_feedback` in the CBC-D XOR. |

---

### Section B — APB Control Plane Requirements

| Req ID | Architectural Requirement | Expected Interface/Signal | Expected Behavior | RTL Implementation | RTL Signal/Module/File | Status | Severity | Exact Discrepancy | Required Architectural Resolution |
|---|---|---|---|---|---|---|---|---|---|
| B-01 | APB is the control/configuration plane | PCLK, PRESETn, PSEL, PENABLE, PWRITE, PADDR[7:0], PWDATA[31:0], PRDATA[31:0], PREADY, PSLVERR | Standard APB2/APB3 slave interface | No APB signals present anywhere in RTL. Module port list contains only AXI4-Lite signals: `aclk`, `aresetn`, `s_axi_aw*`, `s_axi_w*`, `s_axi_b*`, `s_axi_ar*`, `s_axi_r*` | `aes_core_top.v` module port list; `aes_regfile.v` module port list | MISSING | CRITICAL | APB slave interface is completely absent. RTL implements AXI4-Lite instead. These protocols are incompatible at pin level, timing level, and bus-fabric level. | Replace AXI4-Lite register slave with APB slave, or provide an AXI4-Lite-to-APB bridge if architectural exception is approved. |
| B-02 | AES_CTRL at APB offset 0x00 | `PADDR=0x00`, `PWRITE=1` → write CTRL | APB write phase 2 stores to CTRL register | AXI4-Lite write to `s_axi_awaddr=0x00` stores to `ctrl_*` fields via case `6'h00` | `aes_regfile.v` write dispatch case `6'h00` | PARTIALLY COMPLIANT | HIGH | Register offset 0x00 is correct. Bus protocol is AXI4-Lite, not APB. Register content is functionally writable and readable at the correct offset. | Bus protocol change required (B-01). Offset and content can remain. |
| B-03 | AES_STATUS at APB offset 0x04 | `PADDR=0x04` | APB read returns BUSY, DONE | AXI4-Lite read at address 0x04, case `6'h01` returns `{28'b0, status_err, status_key_ready, status_done, core_busy}` | `aes_regfile.v` read case `6'h01` | PARTIALLY COMPLIANT | HIGH | Offset correct. Protocol wrong. Extra fields KEY_READY[2] and ERR[3] not in locked spec. | Bus protocol change required. Extra fields must be reviewed against locked spec. |
| B-04 | AES_BLK_CNT at APB offset 0x08 | `PADDR=0x08` | Read/write block count | AXI4-Lite at 0x08, case `6'h02`. `total_blocks[15:0]` writable; `core_done_blocks[15:0]` readable in [31:16] | `aes_regfile.v` write case `6'h02`; read case `6'h02` | PARTIALLY COMPLIANT | CRITICAL | Offset correct. Protocol wrong. `total_blocks` stored but never consumed by FSM. Multi-block operation non-functional. | Fix FSM to use `total_blocks`. Fix bus protocol. |
| B-05 | AES_KEY0–7 at APB offsets 0x10–0x2C | `PADDR=0x10..0x2C` | Write-only key registers | AXI4-Lite at 0x10–0x2C, cases `6'h04`–`6'h0B`. Writes stored. Reads return 0. | `aes_regfile.v` cases `6'h04`–`6'h0B` | PARTIALLY COMPLIANT | HIGH | Offsets correct. Assembly order `{KEY7..KEY0}` correct. Protocol wrong (AXI4-Lite not APB). | Bus protocol change required. |
| B-06 | AES_IV0–3 at APB offsets 0x30–0x3C | `PADDR=0x30..0x3C` | R/W IV registers, IV used in CBC | AXI4-Lite at 0x30–0x3C, cases `6'h0C`–`6'h0F`. Writes stored. Reads return stored value. `iv_data[127:0]` assembly: `{IV3,IV2,IV1,IV0}` correct. But `iv_data` never reaches CBC datapath. | `aes_regfile.v` cases `6'h0C`–`6'h0F`; `aes_core_top.v`: `wire [127:0] iv_data` declared but unread in FSM | PARTIALLY COMPLIANT | CRITICAL | Offsets and assembly correct. Protocol wrong. IV architecturally disconnected from CBC feedback register. | Connect `iv_data` to `feedback_reg` on START. Fix bus protocol. |
| B-07 | AES_CTRL.START: self-clearing write-one-to-start | `PWDATA[0]=1` pulses start | Write 1 triggers one operation cycle, bit reads back as 0 | `ctrl_start` register: default assignment `ctrl_start <= 1'b0` every cycle; write sets for one cycle. FSM checks in ST_IDLE. | `aes_regfile.v`: `ctrl_start <= 1'b0` in else block; `ctrl_start <= wr_data[0]` in write dispatch | COMPLIANT | LOW | Functionally correct self-clearing behavior on correct bus. | Bus protocol change required (B-01). Functional behavior is correct. |
| B-08 | AES_STATUS.BUSY: asserts when operation in progress, deasserts on completion | `PRDATA[0]=1` while processing | Hardware-set, software-read-only | `core_busy_r` set in ST_IDLE on ctrl_start, cleared in ST_DONE. RO via `core_busy` input to regfile. | `aes_core_top.v`: `core_busy_r <= 1'b1` in ST_IDLE; `core_busy_r <= 1'b0` in ST_DONE | COMPLIANT | LOW | Functionally correct. Subject to bus protocol fix. | Bus protocol change required (B-01). |
| B-09 | AES_STATUS.DONE: W1C, asserts after block completion | `PRDATA[1]=1` after done; write 1 clears | Sticky set by HW, cleared by SW write-1 | `status_done`: set by `core_done_r` pulse; cleared by writing `STATUS[1]=1` or `IRQ_CLR[0]=1` | `aes_regfile.v`: `status_done <= 1'b1` on `core_done`; `if (wr_data[1]) status_done <= 1'b0` in 6'h01 handler | COMPLIANT | LOW | Functionally correct. Subject to bus protocol fix and DONE timing issue (DONE should assert only after output accepted, not immediately on core completion). | Fix DONE timing. Fix bus protocol. |
| B-10 | AES_CTRL.IRQ_EN: enables interrupt when set | `PWDATA[1]` | Gates IRQ output | `ctrl_irq_en` stored, used in `assign irq = ctrl_irq_en & (status_done \| status_err)` | `aes_regfile.v`: `ctrl_irq_en <= wr_data[1]`; `assign irq = ctrl_irq_en & (status_done \| status_err)` | COMPLIANT | LOW | Functionally correct. Subject to bus protocol fix. | Bus protocol change required. |
| B-11 | AES_CTRL.MODE: selects encrypt or decrypt | `PWDATA[2]` = 0 (enc) or 1 (dec) | Controls cipher direction | `ctrl_decrypt` bit [2]. Locked spec uses term "MODE" for encrypt/decrypt. RTL uses bit [2] = DECRYPT. Functionally equivalent encoding. | `aes_regfile.v` case `6'h00`: `ctrl_decrypt <= wr_data[2]` | COMPLIANT | LOW | Field name differs (MODE vs DECRYPT) but encoding and behavior match: 0=encrypt, 1=decrypt. | Bus protocol change required. Field naming is a documentation issue. |
| B-12 | Configuration registers not writable while BUSY | When `STATUS.BUSY=1`, writes to KEY, IV, CTRL should be rejected or ignored | BUSY-state write protection | No BUSY guard in write dispatch. `key_data`, `iv_data`, `ctrl_decrypt`, `ctrl_mode_cbc` all writable while `core_busy_r=1` | `aes_regfile.v` write dispatch: no `core_busy` check before any case | MISSING | HIGH | Any configuration register can be modified mid-operation, potentially corrupting an in-progress AES computation. | Add BUSY check in write dispatch: reject writes to configuration registers (KEY, IV, CTRL.MODE, CTRL.KEY_SIZE) when `core_busy=1`. |
| B-13 | IRQ behavior: irq asserts when DONE=1 and IRQ_EN=1 | `irq` output | Level-sensitive IRQ tied to DONE | `assign irq = ctrl_irq_en & (status_done \| status_err)` | `aes_regfile.v` final assign | COMPLIANT | LOW | Functionally correct. | None. |
| B-14 | Reset values: all control registers = 0 at reset | All fields = 0 after active reset | `ctrl_*` = 0, `key_data` = 0, `iv_data` = 0 | Reset block sets: `ctrl_start=0`, `ctrl_irq_en=0`, `ctrl_decrypt=0`, `ctrl_key_size=2'b10` (NOT 0), `ctrl_mode_cbc=0`, `ctrl_mode_ctr=0`, `ctrl_soft_rst=0`, `total_blocks=0`, `key_data=0`, `iv_data=0`, `din_data=0` | `aes_regfile.v` write dispatch reset: `ctrl_key_size <= 2'b10` | PARTIALLY COMPLIANT | MEDIUM | `ctrl_key_size` resets to 2'b10 (256-bit selection) instead of 0. Locked spec does not specify the reset value for this field, but a non-zero reset is a deviation. | Clarify whether KEY_SIZE reset value of 2'b10 is acceptable. Document explicitly. |

---

### Section C — Data Plane Requirements

| Req ID | Architectural Requirement | Expected Interface/Signal | Expected Behavior | RTL Implementation | RTL Signal/Module/File | Status | Severity | Exact Discrepancy | Required Architectural Resolution |
|---|---|---|---|---|---|---|---|---|---|
| C-01 | AXI4 Slave S3 at 0x9000_0010 (data input) | Full AXI4 slave: AWVALID/AWREADY, WVALID/WREADY, WDATA[63:0], WLAST, BVALID/BREADY | Accepts 64-bit write beats of AES input data | No AXI4 data-plane slave exists in any RTL file. No S3 endpoint. No 64-bit data port. | Not present in `aes_core_top.v` or `aes_regfile.v`. RTL directory contains no additional AES files. | MISSING | CRITICAL | Entire AXI4 input data-plane interface absent. The accelerator has no mechanism to receive data from DMA via the SoC bus. | Implement AXI4 slave for data input at S3 address space with 64-bit WDATA. |
| C-02 | AXI4 Slave S4 at 0x9000_0020 (data output) | Full AXI4 slave: ARVALID/ARREADY, RDATA[63:0], RLAST, RVALID/RREADY | Provides 64-bit read beats of AES output data | Not present. Only a 32-bit AXI4-Lite interface exists, used for register access only. | Not present in any RTL file | MISSING | CRITICAL | Entire AXI4 output data-plane interface absent. DMA cannot read output data via bus fabric. | Implement AXI4 slave for data output at S4 address space with 64-bit RDATA. |
| C-03 | 64-bit input beats | `WDATA[63:0]` per beat | Two 64-bit beats deliver one 128-bit AES block | Not present. `s_axi_wdata` is 32-bit in `aes_regfile`. | `aes_regfile.v`: `input wire [31:0] s_axi_wdata` | MISSING | CRITICAL | Data bus width is 32 bits (AXI4-Lite), not 64 bits (AXI4 full). Incompatible with locked 64-bit beat architecture. | Data-plane AXI4 interface must have 64-bit WDATA. |
| C-04 | Beat 0 = block[63:0] | Beat 0 data maps to lower 64 bits of 128-bit AES block | First 64-bit beat stored as block[63:0] | No beat concept. 128-bit input block written as 4 separate 32-bit register writes to DIN0–DIN3 by CPU. | `aes_regfile.v` cases `6'h10`–`6'h13` | MISSING | CRITICAL | No hardware beat assembly. Block is assembled by CPU software, not by AXI4 slave hardware. | Implement hardware beat assembler that captures Beat0 into block[63:0] on first WVALID. |
| C-05 | Beat 1 = block[127:64] | Beat 1 data maps to upper 64 bits of 128-bit AES block | Second 64-bit beat stored as block[127:64] | Not present | Not present | MISSING | CRITICAL | No Beat 1 capture register. | Implement hardware beat assembler capturing Beat1 into block[127:64]. |
| C-06 | block[127:0] = {Beat1, Beat0} | Two beats assembled into one 128-bit block | Assembly order: upper=Beat1, lower=Beat0 | Not present | Not present | MISSING | CRITICAL | No beat assembly logic. | Implement assembly: `block = {beat1_reg, beat0_reg}`. |
| C-07 | 128-bit output splitting — Beat 0 = out[63:0] | First read beat returns lower 64 bits of output | `RDATA[63:0] = ciphertext[63:0]` | Not present. Output read as 4×32-bit via DOUT0–DOUT3 registers. | `aes_regfile.v` cases `6'h14`–`6'h17` | MISSING | CRITICAL | No hardware output beat splitter. Output fragmented into 4×32-bit, not 2×64-bit. | Implement 128-to-64 bit splitter outputting Beat0=out[63:0] and Beat1=out[127:64]. |
| C-08 | 128-bit output splitting — Beat 1 = out[127:64] | Second read beat returns upper 64 bits | `RDATA[63:0] = ciphertext[127:64]` | Not present | Not present | MISSING | CRITICAL | No Beat 1 output path. | Same as C-07 resolution. |
| C-09 | Input FIFO | Buffers incoming AXI4 write data | Decouples DMA write rate from AES processing rate; holds partial blocks | Not present. No FIFO of any kind in RTL. | Not present in any RTL file | MISSING | HIGH | Without an input FIFO, the DMA cannot write data unless the AES core is ready to accept it immediately. No buffering. | Implement input FIFO between AXI4 S3 slave and beat assembler. |
| C-10 | Output FIFO | Buffers AES output data | Decouples AES output rate from DMA read rate | Not present | Not present in any RTL file | MISSING | HIGH | Without an output FIFO, AES output is lost if DMA does not immediately read. | Implement output FIFO between 128-bit splitter and AXI4 S4 slave. |
| C-11 | Input FIFO backpressure | AES FSM waits when input FIFO empty | Engine does not consume invalid data | Not present. FSM reads `din_data` directly; no empty/valid check. | `aes_core_top.v` ST_DATA_LOAD: `text_in_mux <= din_data` without valid check | MISSING | HIGH | FSM will process whatever is in `din_data` regardless of whether valid data has been written. No mechanism to hold FSM for missing input. | Input FIFO with empty flag; FSM transitions to data states only when FIFO has ≥2 beats (one full block). |
| C-12 | Output FIFO full backpressure | AES FSM stalls when output FIFO full | Engine does not overwrite output data | Not present. No FIFO, no full flag, no stall logic. | Not present | MISSING | HIGH | No backpressure on output. If DMA stalls, output is overwritten. | Output FIFO with full flag; FSM holds in ST_DONE until FIFO has space. |
| C-13 | AXI4 WVALID/WREADY handshaking on data plane | `WVALID` asserted by master; `WREADY` by slave | Standard AXI4 handshake for each beat | Not present. `s_axi_wvalid`/`s_axi_wready` exist only on AXI4-Lite register interface, not on a data-plane slave. | `aes_regfile.v` register-plane only | MISSING | HIGH | No data-plane AXI4 handshake exists. | Implement full AXI4 valid/ready handshake on S3 slave. |
| C-14 | AXI4 RVALID/RREADY handshaking on output | `RVALID` by slave; `RREADY` by master | Standard AXI4 handshake for each read beat | Not present on data plane | Not present | MISSING | HIGH | No data-plane read handshake. | Implement full AXI4 read valid/ready on S4 slave. |
| C-15 | WLAST on final beat of each AXI4 write transaction | `WLAST=1` on Beat 1 | Marks end of 2-beat burst per block | Not present. AXI4-Lite has no WLAST signal. `aes_regfile` has no WLAST port. | Not present | MISSING | MEDIUM | No burst framing. AXI4 full requires WLAST to terminate write bursts. | AXI4 S3 slave must process WLAST to detect end of 2-beat write transaction. |
| C-16 | RLAST on final beat of each AXI4 read transaction | `RLAST=1` on Beat 1 | Marks end of 2-beat burst per block read | Not present | Not present | MISSING | MEDIUM | No RLAST generation. | AXI4 S4 slave must assert RLAST on second beat of each output read. |

---

### Section D — Transaction Control Requirements

| Req ID | Architectural Requirement | Expected Interface/Signal | Expected Behavior | RTL Implementation | RTL Signal/Module/File | Status | Severity | Exact Discrepancy | Required Architectural Resolution |
|---|---|---|---|---|---|---|---|---|---|
| D-01 | AES_BLK_CNT controls number of 128-bit blocks processed | `total_blocks[15:0]` consumed by FSM | For N blocks: FSM loops N times; remaining_count decrements each block | `total_blocks` stored in `aes_regfile`. FSM `blk_remaining` loaded in ST_IDLE as `({16{1'b1}} & 16'd1)` = constant 1. `total_blocks` is never read by FSM. | `aes_core_top.v` ST_IDLE: `blk_remaining <= ({16{1'b1}} & 16'd1)` — constant expression evaluates to 16'h0001 | MISSING | CRITICAL | `blk_remaining` is hardwired to 1 at every START. `total_blocks` register has no connection to FSM operation. Multi-block DMA transfers are impossible. | FSM must load `blk_remaining <= total_blocks` at START and decrement after each block, returning to GET_BEAT0/DATA_LOAD if `blk_remaining > 0`. |
| D-02 | Zero-block rejection: N=0 must not start execution | N=0 check before processing | `START` with `TOTAL_BLOCKS=0` is a no-op | No check. When `ctrl_start=1`, FSM transitions to ST_KEY_LOAD1 regardless of `total_blocks` value. | `aes_core_top.v` ST_IDLE: `if (ctrl_start)` with no block count check | MISSING | HIGH | Writing `TOTAL_BLOCKS=0` and asserting START causes the FSM to process one block (since `blk_remaining=1` hardwired). | Add guard: `if (ctrl_start && (total_blocks != 0))` before starting. |
| D-03 | Block counter decrement per block | `blk_remaining = blk_remaining - 1` after each block output | Counter decrements by exactly 1 after each block completes | `blk_remaining` is never decremented anywhere in FSM. | `aes_core_top.v`: no `blk_remaining <= blk_remaining - 1` anywhere | MISSING | CRITICAL | Block counter decrement absent. FSM cannot implement multi-block loops without it. | Add `blk_remaining <= blk_remaining - 1` in ST_DONE or CHECK_DONE equivalent state. |
| D-04 | End-of-transaction: DONE asserted only after final output beat accepted by DMA | DONE pulse after last output beat consumed | DONE must not assert until the DMA acknowledges the last output | `core_done_r` pulsed in ST_DONE, which is entered immediately after AES core `enc_done`/`dec_done`. No check for output FIFO drain or DMA acknowledgment. | `aes_core_top.v` ST_DONE: `core_done_r <= 1'b1` immediately | MISSING | HIGH | DONE asserts before output is consumed. Software could read DONE and attempt to start a new operation while output data from the previous operation is still pending. | DONE must be deferred until output FIFO is drained or final output beat RREADY handshake completes. |
| D-05 | BUSY deasserts only after final output beat | BUSY follows DONE | BUSY=0 must not occur until output is safely delivered | `core_busy_r <= 1'b0` in ST_DONE, same cycle as `core_done_r` pulse. No output delivery check. | `aes_core_top.v` ST_DONE: `core_busy_r <= 1'b0` | MISSING | HIGH | BUSY deasserts before output delivery. Allows re-triggering while previous output is pending. | Same resolution as D-04 — tie BUSY deassertion to output acceptance. |
| D-06 | IRQ asserts after final block output is complete | `irq` level | IRQ triggers software to read output or start next DMA | `irq = ctrl_irq_en & (status_done \| status_err)`. `status_done` set by `core_done_r` pulse (same timing issue as D-04). | `aes_regfile.v`: `assign irq = ctrl_irq_en & (status_done \| status_err)` | PARTIALLY COMPLIANT | HIGH | IRQ path structurally correct. Timing incorrect — asserts before output fully delivered. | Fix DONE timing (D-04); IRQ will automatically inherit correct timing. |

---

### Section E — CBC State Handling Requirements

| Req ID | Architectural Requirement | Expected Interface/Signal | Expected Behavior | RTL Implementation | RTL Signal/Module/File | Status | Severity | Exact Discrepancy | Required Architectural Resolution |
|---|---|---|---|---|---|---|---|---|---|
| E-01 | IV loaded into feedback register at START | `feedback_reg <= iv_data` on `ctrl_start` | First block CBC XOR uses programmed IV | `feedback_reg` initialized to `128'b0` in reset. `iv_data` wire present in `aes_core_top` (connected from regfile) but never assigned to `feedback_reg` anywhere. | `aes_core_top.v`: `feedback_reg <= 128'b0` in reset; `wire [127:0] iv_data` declared but not used in FSM body | MISSING | CRITICAL | IV register values are stored in `aes_regfile` and wired to `aes_core_top` but the wire terminates without being read. `feedback_reg` is always 0 at transaction start. | Add to ST_IDLE on ctrl_start: `feedback_reg <= iv_data`. |
| E-02 | CBC-E: feedback = Ck after each encrypt block | `feedback_reg <= enc_text_out` | Each subsequent block XOR uses previous ciphertext | `feedback_reg <= raw_text_out` in ST_DATA_WAIT CBC-E path. `raw_text_out = enc_text_out` when `ctrl_decrypt=0`. | `aes_core_top.v` ST_DATA_WAIT: `if (!ctrl_decrypt && ctrl_mode_cbc) feedback_reg <= raw_text_out` | COMPLIANT | LOW | Structurally correct assuming AES-256 core. | None for this path. |
| E-03 | CBC-D: feedback = Ck (raw ciphertext input, not decrypted output) | `feedback_reg <= din_data` | Next decrypt block XOR uses the ciphertext that was just decrypted, not the plaintext output | `feedback_reg <= din_data` in ST_DATA_WAIT CBC-D path. `din_data` is the raw ciphertext. Correct source value. | `aes_core_top.v` ST_DATA_WAIT: `else if (ctrl_decrypt && ctrl_mode_cbc) feedback_reg <= din_data` | COMPLIANT | LOW | Source value is correct. Timing of XOR application is still wrong (see E-04). | None for source selection. |
| E-04 | CBC-D: C(k-1) used for final XOR (not Ck) | `dout = dec_output XOR C(k-1)` | XOR applied with ciphertext from block k-1, not block k | `dout_internal = raw_text_out ^ feedback_reg` in `always@(*)`. At time of evaluation, `feedback_reg` has already been updated to `din_data` (block k's ciphertext). For k≥1, `feedback_reg` holds Ck, not C(k-1). | `aes_core_top.v`: combinational `always@(*)` block and ST_DATA_WAIT registered update share same `feedback_reg` with no intermediate capture | CONTRADICTORY | CRITICAL | Registered update `feedback_reg <= din_data` in ST_DATA_WAIT resolves combinationally before `dout_internal`. Next clock sees `feedback_reg = Ck`. For block 0: IV=0 (wrong). For block k≥1: feedback=Ck (current), should be C(k-1). All outputs wrong. | Capture C(k-1) before update: `prev_ciphertext <= feedback_reg` before `feedback_reg <= din_data`. Use `prev_ciphertext` in XOR. |
| E-05 | CBC state continuous across all N blocks in one transaction | `feedback_reg` persists across blocks within one START session | Blocks 0,1,...,N-1 use correct chained ciphertext | Not testable — multi-block not implemented (`blk_remaining` hardwired to 1). `feedback_reg` is retained in FSM between states, so it would persist if multi-block were implemented. | `aes_core_top.v`: `feedback_reg` is a persistent register (not cleared between blocks) | PARTIALLY COMPLIANT | HIGH | Persistence is structurally correct but multi-block loop is absent. Cannot verify chaining across blocks. | Fix multi-block FSM (D-01 through D-03); CBC chaining register will then function correctly structurally. |

---

### Section F — SoC Integration Requirements

| Req ID | Architectural Requirement | Expected Interface/Signal | Expected Behavior | RTL Implementation | RTL Signal/Module/File | Status | Severity | Exact Discrepancy | Required Architectural Resolution |
|---|---|---|---|---|---|---|---|---|---|
| F-01 | APB control bus connects to SoC APB fabric | APB slave signals matching SoC pin list | PSEL, PENABLE, PWRITE, PADDR, PWDATA, PRDATA, PREADY all connect to SoC APB bus matrix | RTL exports AXI4-Lite signals: `s_axi_aw*`, `s_axi_w*`, `s_axi_b*`, `s_axi_ar*`, `s_axi_r*`. Cannot connect directly to APB fabric. | `aes_core_top.v` module port list | MISSING | CRITICAL | No APB pins exist. RTL is incompatible with APB fabric at the signal level. An APB master cannot drive AXI4-Lite signals. | Implement APB slave in RTL, or insert an APB-to-AXI4-Lite bridge and update the SoC integration netlist. |
| F-02 | AXI4 S3 input slave connects to SoC AXI4 interconnect | AXI4 slave signals at S3 port | DMA write transactions reach AES input FIFO via SoC crossbar | No S3 slave exists in RTL | Not present | MISSING | CRITICAL | No S3 AXI4 slave. Cannot connect to SoC interconnect for data input. | Implement AXI4 slave S3 with 64-bit WDATA. |
| F-03 | AXI4 S4 output slave connects to SoC AXI4 interconnect | AXI4 slave signals at S4 port | DMA read transactions retrieve AES output via SoC crossbar | No S4 slave exists in RTL | Not present | MISSING | CRITICAL | No S4 AXI4 slave. Cannot connect to SoC interconnect for data output. | Implement AXI4 slave S4 with 64-bit RDATA. |
| F-04 | Clock interface: single clock domain | `PCLK` (APB) or `aclk` (AXI) | All RTL clocked by SoC peripheral clock | RTL uses `aclk` (AXI4 clock convention). Locked spec requires `PCLK` for APB. Functionally the same if clock frequencies match; signal name differs. | `aes_core_top.v` port: `input wire aclk` | PARTIALLY COMPLIANT | MEDIUM | Clock signal name `aclk` vs `PCLK`. If same net in SoC, connection is trivial. If separate clock domains, CDC handling required. | Confirm SoC clock topology. Rename or remap in integration wrapper if needed. |
| F-05 | Reset interface: active-LOW synchronous reset | `PRESETn` (APB) or `aresetn` (AXI) | Synchronous active-LOW reset from SoC reset controller | RTL uses `aresetn` (AXI4-Lite convention). APB uses `PRESETn`. Functionally identical if same reset net. | `aes_core_top.v` port: `input wire aresetn` | PARTIALLY COMPLIANT | MEDIUM | Signal name `aresetn` vs `PRESETn`. Polarity (active-LOW) matches. | Rename in wrapper or confirm same reset net assignment. |
| F-06 | Register address map must be compatible with SoC memory map | AES_CTRL=0x00, AES_STATUS=0x04, AES_BLK_CNT=0x08, KEY0-7=0x10-0x2C, IV0-3=0x30-0x3C | Offsets match locked SoC peripheral register map | All 5 locked register offsets implemented at correct addresses in RTL. Extra registers at 0x0C, 0x40-0x5C not in locked spec. | `aes_regfile.v` case statements | PARTIALLY COMPLIANT | MEDIUM | The 5 locked registers are at correct offsets. RTL adds 9 extra registers outside the locked spec (IRQ_CLR, DIN0-3, DOUT0-3). These may conflict with SoC address decode. | Confirm whether extra registers are acceptable or remove them from the locked map. |
| F-07 | Data-plane address 0x9000_0010 (input) decoded by SoC interconnect and routed to AES S3 slave | SoC interconnect routes this address to AES S3 port | Writes to 0x9000_0010 reach AES input | No S3 slave exists; address cannot be mapped to AES input | Not present | MISSING | CRITICAL | Without S3 slave, address decode at SoC level will fail or produce no connection. | Implement S3 slave. Update SoC address decode accordingly. |
| F-08 | Data-plane address 0x9000_0020 (output) decoded and routed to AES S4 | SoC interconnect routes to AES S4 | Reads from 0x9000_0020 return AES output | No S4 slave exists | Not present | MISSING | CRITICAL | Same as F-07 for output path. | Implement S4 slave. Update SoC address decode. |
| F-09 | `irq` output connects to RISC-V interrupt controller | `irq` wire to interrupt controller | Level-sensitive IRQ input to RISC-V PLIC | `irq` output present in `aes_core_top`. Level-sensitive (combinational assign). Active-HIGH. | `aes_core_top.v`: `output wire irq` | COMPLIANT | LOW | IRQ output present and level-driven. Polarity (active-HIGH) must be confirmed against RISC-V PLIC input polarity expectations. | Confirm PLIC input polarity. |

---

## 1. Compliance Summary

| Status | Count | Req IDs |
|---|---|---|
| **COMPLIANT** | 9 | A-08, A-09, A-11, B-07, B-08, B-09, B-10, B-11, B-13, E-02, E-03, F-09 |
| **PARTIALLY COMPLIANT** | 9 | A-01, A-06, B-02, B-03, B-04, B-05, B-06, B-14, D-06, E-05, F-04, F-05, F-06 |
| **MISSING** | 26 | A-02, A-03, A-04, A-05, A-07, A-12, B-01, B-12, C-01 through C-16 (all 16), D-01, D-02, D-03, D-04, D-05, E-01, F-01, F-02, F-03, F-07, F-08 |
| **CONTRADICTORY** | 2 | A-10, E-04 |
| **Total Requirements** | **48** | — |

---

## 2. Critical Mismatch List (Ranked by Architectural Impact)

| Rank | Req ID | Mismatch | Impact |
|---|---|---|---|
| 1 | A-02, A-03, A-04, A-05 | AES-128 IP used instead of AES-256. 10 rounds instead of 14. Incorrect key expansion. | ALL encrypted/decrypted data is cryptographically wrong. Device provides no AES-256 security. |
| 2 | C-01, C-02, C-03 | AXI4 data-plane slaves S3/S4 absent. No 64-bit data interface. | Accelerator cannot receive or transmit data through SoC bus fabric. Non-functional as an accelerator. |
| 3 | B-01, F-01 | APB control plane absent. AXI4-Lite used instead. | RTL cannot connect to SoC APB fabric without a bridge. Direct integration impossible. |
| 4 | A-07, E-01 | `iv_data` wire architecturally disconnected. `feedback_reg` always starts at 0. | CBC IV is always 0 regardless of IV register values. CBC security property (IV randomness) completely defeated. |
| 5 | A-10, E-04 | CBC-D XOR uses current ciphertext (Ck) instead of previous (C(k-1)). Timing error in combinational/registered interaction. | All CBC decryption outputs are wrong for block k≥1. Decryption is not the inverse of encryption. |
| 6 | D-01, D-03 | `total_blocks` register unused. `blk_remaining` hardwired to constant 1. Multi-block loop absent. | Only single-block operation possible. AES_BLK_CNT has no effect. DMA streaming transfers impossible. |
| 7 | A-12 | No previous-ciphertext register. C(k-1) overwritten before XOR. | CBC-D XOR permanently broken; cannot be fixed without a new register. |
| 8 | C-04 through C-08 | No beat assembly (64→128 bit) or beat splitting (128→64 bit). | Beat-based DMA data transfer architecture is completely absent. |
| 9 | C-09, C-10, C-11, C-12 | No input/output FIFOs, no backpressure. | Flow control between DMA and AES core absent. Data loss or starvation will occur in streaming use. |
| 10 | B-12 | No BUSY-state write protection on configuration registers. | Key or IV can be modified mid-operation, producing corrupted or insecure output. |

---

## 3. Register Compatibility Verdict

**The locked APB register specification CANNOT remain unchanged despite the current RTL.**

Evidence:

1. The locked specification defines 5 registers (AES_CTRL, AES_STATUS, AES_BLK_CNT, AES_KEY0–7, AES_IV0–3) on an APB bus. The RTL implements these same 5 registers at the same offsets but on an AXI4-Lite bus. The register offsets and field definitions are compatible at the logical level, but the bus interface protocol is incompatible.

2. The RTL adds 9 registers not in the locked spec: AES_IRQ_CLR (0x0C), AES_DIN0–3 (0x40–0x4C), AES_DOUT0–3 (0x50–0x5C). These occupy address space that may conflict with other SoC peripherals in the locked memory map.

3. The locked spec has no DIN/DOUT registers because data is supposed to flow through the AXI4 data plane. The RTL's DIN/DOUT registers represent an architectural deviation in the data delivery model.

4. AES_BLK_CNT is in the locked spec and in the RTL at the same offset, but its function is not implemented in the RTL FSM.

**Verdict: The register logical map is compatible at offset level only. The bus interface, the extra registers, and the non-functional BLK_CNT must be resolved before the locked register spec can be declared satisfied.**

---

## 4. Interface Compatibility Verdict

**The existing RTL CANNOT connect to the locked SoC architecture without an adapter/wrapper.**

Evidence:

| Interface | Locked Spec | RTL Provides | Compatible? |
|---|---|---|---|
| Control plane bus | APB (PSEL/PENABLE/PWRITE/PADDR/PWDATA/PRDATA/PREADY) | AXI4-Lite (s_axi_aw*/w*/b*/ar*/r*) | NO |
| Data-plane input | AXI4 full slave S3, 64-bit WDATA, at 0x9000_0010 | Not present | NO |
| Data-plane output | AXI4 full slave S4, 64-bit RDATA, at 0x9000_0020 | Not present | NO |
| Clock | PCLK (APB) | aclk (AXI) | Name mismatch — same net may be acceptable |
| Reset | PRESETn (APB) | aresetn (AXI), active-LOW | Name mismatch — functionally compatible if same net |
| IRQ | irq to PLIC | irq output present | YES (polarity TBD) |

**Minimum requirement for connection:** An APB-to-AXI4-Lite bridge for the control plane, and a complete AXI4 data-plane slave implementation for S3/S4. Neither exists in the current RTL.

---

## 5. Algorithmic Correctness Verdict

**The existing RTL does NOT implement AES-256 CBC.**

Evidence per algorithm component:

| Component | Correct? | Evidence |
|---|---|---|
| AES-256 key (256 bits) | NO | `core_key_mux` is 128 bits; only `key_data[127:0]` fed to IP during data processing |
| AES-256 key expansion | NO | IP is ASICS.ws AES-128; generates 11 round keys (10 rounds), not 15 (14 rounds) |
| 14 AES rounds | NO | IP spec: "10 cycles for the 10 rounds" — 10 rounds only |
| CBC IV seeding | NO | `iv_data` wire unread; `feedback_reg` = 128'b0 at start |
| CBC-E equation Xk=Pk XOR C(k-1) | PARTIALLY | Equation present; initial C0 wrong (0 not IV) |
| CBC-E chain update Ck = AES(Xk) | NO | AES-128 output, not AES-256 |
| CBC-D equation Pk=AES^-1(Ck) XOR C(k-1) | NO | XOR uses current Ck instead of C(k-1) due to feedback_reg timing error |
| CBC-D chain: feedback = Ck | YES (source value) | `feedback_reg <= din_data` is correct source |
| Multi-block chaining | NO | Single block only; `blk_remaining` hardwired to 1 |

**The RTL implements a partial, single-block, AES-128, register-polled accelerator with a structurally correct but incorrectly timed CBC framework. It does not implement AES-256 CBC as defined by FIPS 197 and the locked architectural specification.**

---

## 6. Final Decision

**C. RTL fundamentally contradicts the locked architecture and requires architectural/implementation changes.**

The following contradictions are fundamental and cannot be resolved by an adapter or wrapper alone:

1. **The AES algorithm is wrong.** The ASICS.ws AES-128 IP core is not capable of AES-256 regardless of wrapping. 10 rounds ≠ 14 rounds. A different AES core is required.

2. **The data-plane architecture is absent.** The locked spec requires AXI4 S3/S4 slaves, 64-bit beats, FIFOs, and beat assembly/splitting. None of these exist. A wrapper cannot add a full streaming data plane without effectively rewriting the data path.

3. **The IV is not used.** The CBC IV register is populated but the wire from the register to the CBC feedback register is disconnected. This is a logic implementation gap, not a bus mismatch.

4. **CBC decryption produces wrong output.** The timing error in the feedback XOR (using Ck instead of C(k-1)) requires a structural RTL fix — a new register and corrected combinational path.

5. **Multi-block operation is non-functional.** The block counter is stored but hardwired out. Restoring multi-block operation requires FSM changes.

An APB-to-AXI4-Lite bridge can resolve the bus protocol mismatch for the control plane and should be noted as a required integration component. However it does not resolve the algorithm, data-plane, CBC correctness, or multi-block issues above.

### Items Requiring RTL Change (Proposed, Pending Approval)

| Item | Change Required |
|---|---|
| AES-256 core | Replace `aes_cipher_top`/`aes_inv_cipher_top` with AES-256 compliant cores |
| IV seeding | Add `if (ctrl_start) feedback_reg <= iv_data` in ST_IDLE |
| CBC-D XOR | Add `prev_feedback` register; use it for post-decrypt XOR |
| Multi-block FSM | Load `blk_remaining <= total_blocks`; decrement after each block; loop until 0 |
| AXI4 data plane | Implement S3/S4 slaves with 64-bit beats, FIFO, beat assembly/splitting |
| Bus protocol | Replace AXI4-Lite with APB, or provide APB-to-AXI4-Lite bridge at SoC level |
| BUSY guard | Block configuration writes when `core_busy=1` |
| DONE timing | Assert DONE only after output FIFO drain/final beat accepted |

---

*No RTL was modified during this audit.*
*RTL source: rtl/aes_core_top.v, rtl/aes_regfile.v*
*All findings based on direct RTL inspection. No behavior inferred.*
