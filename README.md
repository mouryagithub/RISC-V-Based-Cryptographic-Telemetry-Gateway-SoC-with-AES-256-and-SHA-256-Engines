# RISC-V Based Cryptographic Telemetry Gateway SoC
### with AES-256 and SHA-256 Engines

> **Honours Project — RTL Design & Verification**  
> Simulation environment: Synopsys VCS U-2023.03 / Verdi · Language: Verilog / SystemVerilog

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Problem Statement & Motivation](#2-problem-statement--motivation)
3. [Objectives](#3-objectives)
4. [Project Specification (Intended Architecture)](#4-project-specification-intended-architecture)
5. [Current Implementation Status](#5-current-implementation-status)
6. [System Architecture (Current Repository)](#6-system-architecture-current-repository)
7. [Repository Structure](#7-repository-structure)
8. [Module Descriptions](#8-module-descriptions)
9. [Address Map](#9-address-map)
10. [Verification & Testing](#10-verification--testing)
11. [Simulation Instructions](#11-simulation-instructions)
12. [Current Limitations & Known Issues](#12-current-limitations--known-issues)
13. [Future Work / Planned Features](#13-future-work--planned-features)
14. [Technologies & Tools](#14-technologies--tools)
15. [References](#15-references)

---

## 1. Project Overview

This repository is an Honours-level digital design project implementing the RTL for a **RISC-V based Cryptographic Telemetry Gateway System-on-Chip (SoC)**. The goal is to build a hardware platform capable of securely receiving raw telemetry data over a serial interface, processing it through on-chip AES-256 and SHA-256 cryptographic accelerators, and transmitting the secured payload back to an external host — all with minimal CPU involvement through autonomous DMA-driven data movement across an AXI4 interconnect fabric.

The project is implemented in **Verilog / SystemVerilog** and targets functional simulation using **Synopsys VCS** and **Verdi**. No physical FPGA or ASIC target has been pursued at this stage.

---

## 2. Problem Statement & Motivation

Telemetry systems in safety-critical and aerospace applications must transmit sensor data securely. Implementing cryptography in software on a general-purpose processor introduces unacceptable latency and CPU load for real-time applications. Dedicated hardware accelerators offload cryptographic operations, but integrating them correctly into a coherent SoC bus fabric — with proper memory-mapped register access, interrupt handling, and DMA data movement — is a non-trivial hardware engineering challenge.

This project addresses that challenge by designing and verifying the RTL components of such a gateway: a unified AXI4 interconnect fabric, AXI-to-Lite protocol bridging, AES block cipher logic, and a UART serial interface, within a single unified SoC.

---

## 3. Objectives

The project targets the following objectives:

- Design a parameterised AXI4 crossbar interconnect fabric connecting CPU, DMA, and peripherals.
- Implement an AES-256 CBC hardware accelerator with memory-mapped register control over AXI4-Lite.
- Implement a SHA-256 hardware accelerator for message integrity verification.
- Implement a UART serial interface with AXI4-Lite control and internal FIFOs.
- Integrate all components into a `soc_top` module with a defined address map.
- Develop self-checking SystemVerilog testbenches for each subsystem.
- Verify functional correctness via RTL simulation in VCS/Verdi.

---

## 4. Project Specification (Intended Architecture)

> The following describes the **intended** architecture from `doc/Project_spec.odt`. It represents the full design target. See [Section 5](#5-current-implementation-status) for what has actually been implemented.

### 4.1 SoC Block Diagram (Intended)

The control path defines how the VeeR EL2 core orchestrates system operations across the unified AXI4/AXI4-Lite interconnect architecture.

```
RISC-V Based Cryptographic Telemetry Gateway SoC

                ┌──────────────────────┐
                │      VeeR EL2        │
                │   32-bit RISC-V      │
                │      RV32IMC         │
                └──────────┬───────────┘
                           │
                     AXI4 Master
                           │
                           ▼
        ┌──────────────────────────────────────┐
        │      64-bit AMBA AXI4 Interconnect   │
        │                                      │
        │ CPU LSU ───────► System SRAM         │
        │ DMA Master ────► System SRAM         │
        │ DMA Master ────► AES-256 Data Plane  │
        │ DMA Master ────► SHA-256 Data Plane  │
        └──────────────┬───────────────────────┘
                       │
                AXI4-Lite Control
                       │
       ┌───────────────┼────────────────────────┐
       │               │                        │
       ▼               ▼                        ▼
    ┌──────┐       ┌────────┐              ┌────────┐
    │ UART │       │ Timer  │              │  GPIO  │
    └──────┘       └────────┘              └────────┘
       │
       ├───────────────┐
       ▼               ▼
   ┌────────┐      ┌────────┐
   │  DMA   │      │  PIC   │
   │ Control│      │/Events │
   └────────┘      └────────┘

                       │
                 AXI4-Lite Control
                       │
              ┌────────┴────────┐
              ▼                 ▼
        ┌──────────┐      ┌──────────┐
        │ SHA-256  │      │ AES-256  │
        │ Control  │      │  Control │
        └──────────┘      └──────────┘
```

### 4.2 Specified Components

| Component | Specification |
|---|---|
| **CPU Core** | Western Digital VeeR EL2 (RISC-V RV32IMC) |
| **System Interconnect** | 64-bit AMBA AXI4 crossbar interconnect |
| **Control / Peripheral Bus** | AXI4-Lite subordinate ports derived directly from AXI4 interconnect |
| **Memory** | System SRAM (telemetry staging + result buffer) |
| **DMA Controller** | AXI4 master, autonomous block transfers, completion/error IRQ, AXI4-Lite control |
| **AES-256 Engine** | CBC mode only, 256-bit key, 128-bit IV, DMA-driven 64-bit beat data plane, AXI4-Lite control plane |
| **SHA-256 Engine** | 256-bit digest, DMA-driven data input, AXI4-Lite control plane |
| **UART** | Serial ingress/egress, configurable baud rate and frame format, AXI4-Lite control |
| **GPIO** | General-purpose I/O peripheral, AXI4-Lite control |
| **System Timer** | Interval timer peripheral, AXI4-Lite control |
| **Interrupt Controller** | Programmable Interrupt Controller (PIC) → VeeR EL2 `extintsrc_req` |

### 4.3 Specified Operational Data Flow

```
[Ingress]
  External Host → Serial Line → UART → AXI4-Lite → VeeR EL2 → AXI4 → System SRAM

[Processing]
  System SRAM → AXI4 → DMA → SHA-256 → 256-bit digest → AXI4-Lite / CPU readback
  System SRAM → AXI4 → DMA → AES-256 CBC → Ciphertext → System SRAM

[Egress]
  System SRAM → VeeR EL2 (LSU) → AXI4-Lite → UART → Serial Line → External Host
```

### 4.4 Specified AES-256 Interface

| Interface | Specification |
|---|---|
| Control plane | AXI4-Lite registers: `AES_CTRL` (0x00), `AES_STATUS` (0x04), `AES_BLK_CNT` (0x08), `AES_KEY0–7` (0x10–0x2C), `AES_IV0–3` (0x30–0x3C) |
| Data input | AXI4 full slave S3 at `0x9000_0010`, 64-bit beats (2 beats per 128-bit block) |
| Data output | AXI4 full slave S4 at `0x9000_0020`, 64-bit beats |
| Algorithm | AES-256, CBC mode, 14 rounds, 256-bit key schedule |
| Block count | Controlled by `AES_BLK_CNT` register |
| Interrupt | `aes_done_irq` to PIC on completion |

---

## 5. Current Implementation Status

> **Important:** The specification describes the intended design. The table below describes what is **actually present in the repository today**. These are two different things. Features are categorised as Implemented, Partially Implemented, or Not Implemented.

### 5.1 Summary Table

| Feature | Status | Notes |
|---|---|---|
| AXI4 parameterised crossbar interconnect (2×10) | ✅ **Implemented** | Alex Forencich open-source core, parameterised |
| AXI4-to-AXI4-Lite combinational bridge | ✅ **Implemented** | Zero-latency, strips burst fields, truncates ID |
| `soc_top` integration module | ✅ **Implemented** | UART only; AES removed from current integration |
| UART peripheral (AXI4-Lite control, 16-byte FIFOs) | ✅ **Implemented** | TX/RX FIFO, baud divisor, parity, interrupts |
| UART testbench (12 test cases) | ✅ **Implemented** | 10 testbench bugs identified and fixed |
| AES register file (22 registers, AXI4-Lite) | ✅ **Implemented** | Correct register offsets and field behavior |
| AES Rijndael IP (cipher + inverse cipher) | ✅ **Implemented** | **AES-128 only** — ASICS.ws IP (10 rounds) |
| AES control FSM (9 states, ECB/CBC/CTR framework) | ✅ **Implemented** | FSM structurally present; several functional gaps (see below) |
| AES testbench (`tb_aes_axi_slave.sv`) | ✅ **Implemented** | No simulation log in repository to confirm pass/fail |
| AXI interconnect testbench | ✅ **Implemented** | File present |
| SoC-level testbench (`tb_soc_top.sv`) | ✅ **Implemented** | Elaboration fails — `aes_core_top` not in compile list |
| Interconnect wrapper generator (Python) | ✅ **Implemented** | `scripts/axi_interconnect_wrap.py` |
| VCS simulation file-lists | ✅ **Implemented** | `run/run.f`, `run/run_integrated_soc.f` |
| **AES-256 (true 14-round, 256-bit key schedule)** | ❌ **Not Implemented** | IP is AES-128; two-phase key load ≠ AES-256 |
| **AES IV connected to CBC datapath** | ❌ **Not Implemented** | `iv_data` wire unread; `feedback_reg` always starts at 0 |
| **AES multi-block autonomous operation** | ❌ **Not Implemented** | `blk_remaining` hardwired to 1; `TOTAL_BLOCKS` unused |
| **AES DMA-driven data plane (AXI4 S3/S4)** | ❌ **Not Implemented** | No AXI4 full data-plane slaves; no FIFOs; no beat assembly |
| **AES CBC decrypt XOR correctness** | ❌ **Not Implemented** | Timing bug: uses current ciphertext instead of previous |
| **AES integrated in SoC top** | ❌ **Not Implemented** | Removed from current `soc_top.v` (m00 tied off) |
| **VeeR EL2 RISC-V CPU core** | ❌ **Not Implemented** | No CPU RTL in repository |
| **SHA-256 hardware accelerator** | ❌ **Not Implemented** | No SHA-256 RTL in repository |
| **DMA Controller** | ❌ **Not Implemented** | No DMA RTL in repository |
| **GPIO peripheral** | ❌ **Not Implemented** | No GPIO RTL in repository |
| **System Timer** | ❌ **Not Implemented** | No timer RTL in repository |
| **Programmable Interrupt Controller (PIC)** | ❌ **Not Implemented** | No PIC RTL in repository |
| **System SRAM** | ❌ **Not Implemented** | No SRAM model in repository |

### 5.2 AES Compliance Detail

The AES subsystem has been subject to an internal audit documented in [`doc/aes_compliance_matrix.md`](doc/aes_compliance_matrix.md) and [`doc/aes_rtl_audit.md`](doc/aes_rtl_audit.md).

> **Architectural Alignment Note:** Earlier audit documents evaluated the RTL against a legacy baseline that previously assumed an APB control plane. The updated specification establishes AXI4-Lite as the unified control interface for the AES core and all peripherals, which aligns directly with the AXI4-Lite slave interface already present in `rtl/interconnect/aes_regfile.v`. However, the critical algorithmic and data-plane gaps identified in the audit remain active issues to be addressed.

**Critical mismatches identified:**

1. **Wrong cipher algorithm:** The ASICS.ws IP (`aes_cipher_top`, `aes_inv_cipher_top`) implements AES-128 (10 rounds). AES-256 requires 14 rounds and a different key schedule. The current RTL is **not cryptographically equivalent to AES-256** regardless of how the key registers are programmed.
2. **IV disconnected:** The IV registers (`AES_IV0–3`) are fully implemented in the register file, but the `iv_data` wire in `aes_core_top` is never read. The CBC feedback register always starts at `128'b0`, not the programmed IV.
3. **CBC decryption XOR timing error:** For blocks k ≥ 1, the decrypted output is XOR'd with the **current** ciphertext block instead of the **previous** one, producing incorrect plaintext.
4. **Multi-block non-functional:** `blk_remaining` is hardwired to the constant `1` via the expression `({16{1'b1}} & 16'd1)`. The `TOTAL_BLOCKS` register is stored but never consumed by the FSM.
5. **No DMA data plane:** The AXI4 S3/S4 slaves, 64-bit beat assembly/splitting, and input/output FIFOs specified in the architecture are entirely absent.

---

## 6. System Architecture (Current Repository)

The current top-level module (`rtl/interconnect/soc_top.v`) implements a partial SoC with **UART only**:

```
                  ┌─────────────────────────────────────────┐
   AXI Master 0 ──┤ s00    axi_interconnect_wrap_2x10        ├─ m00 ──► (tied off)
   AXI Master 1 ──┤ s01    (Alex Forencich, parameterised    ├─ m01 ──► [bridge] ──► axi_uart_top
                  │         2 slave × 10 master crossbar)   ├─ m02 ──► (tied off, SLVERR)
                  │                                          │  ...
                  └─────────────────────────────────────────┘  m09 ──► (tied off, SLVERR)
```

> **Note:** An earlier iteration of `soc_top.v` (as described in `doc/description.md`) connected m00 to `aes_core_top` via the AXI4-to-AXI4-Lite bridge. The most recent commit (2026-09-19) replaced this with a UART-only configuration for isolated UART verification. The AES module port m00 is currently tied off.

### Full Module Hierarchy (Current `soc_top`)

```
soc_top
├── axi_interconnect_wrap_2x10    (u_interconnect)
│   └── axi_interconnect          (axi_interconnect_inst) — parameterised NxM AXI4 crossbar
│       ├── arbiter               (×20, one per master×channel)
│       └── priority_encoder      (×10)
├── axi_to_axilite_bridge         (u_bridge_uart) — m01 → UART
└── axi_uart_top                  (u_uart)
    ├── uart_controller
    │   ├── uart_transmitter
    │   │   └── uart_parity_bit_compute
    │   └── uart_receiver
    ├── axi_internal_fifo         (TX FIFO, 16 entries)
    └── axi_internal_fifo         (RX FIFO, 16 entries)
```

### AXI4-to-AXI4-Lite Bridge

The `axi_to_axilite_bridge.v` is a purely combinational (zero-latency) adapter that:

- **Strips** AXI4 burst fields (`awlen`, `awsize`, `awburst`, `wlast`, `rlast`) — single-beat transactions only.
- **Passes through** address (lower address bits), data, byte strobes, protection, and all handshake signals unchanged.
- **Truncates** transaction ID from 8 bits to 4 bits (lower nibble retained).
- **Drives `rlast = 1`** always on the return path (every AXI4-Lite read is a single beat).

### Reset and Clock

| Signal | Description |
|---|---|
| `clk` | Primary AXI bus clock (50 MHz in simulation) |
| `uart_clk` | Fixed reference clock for UART baud engine (50 MHz in simulation) |
| `aresetn` | Active-LOW synchronous reset (AXI convention) |
| `rst` | Active-HIGH reset derived as `~aresetn` for the interconnect |

---

## 7. Repository Structure

```
RISC-V-Crypto-SoC/
│
├── rtl/
│   ├── aes/
│   │   ├── aes_cipher_top.v           # ASICS.ws AES-128 encryption IP
│   │   ├── aes_inv_cipher_top.v       # ASICS.ws AES-128 decryption IP
│   │   ├── aes_sbox.v                 # AES substitution box (encrypt)
│   │   ├── aes_inv_sbox.v             # AES substitution box (decrypt)
│   │   ├── aes_key_expand_128.v       # AES-128 key expansion
│   │   ├── aes_rcon.v                 # AES round constant ROM
│   │   └── timescale.v                # Timescale directive
│   │
│   ├── interconnect/
│   │   ├── axi_interconnect.v         # Parameterised AXI4 NxM crossbar (Alex Forencich)
│   │   ├── axi_interconnect_wrap_2x10.v # 2-slave × 10-master wrapper
│   │   ├── arbiter.v                  # Round-robin arbiter (per-channel)
│   │   ├── priority_encoder.v         # Priority encoder for arbiter
│   │   ├── axi_to_axilite_bridge.v    # Combinational AXI4 → AXI4-Lite bridge
│   │   ├── aes_core_top.v             # AES accelerator top (FSM + regfile interface)
│   │   ├── aes_regfile.v              # AES AXI4-Lite register file (22 registers)
│   │   └── soc_top.v                  # SoC top-level (current: UART only)
│   │
│   └── uart/
│       ├── axi_uart_top.v             # UART top with AXI4-Lite slave
│       ├── uart_controller.v          # UART control logic (TX/RX coordination)
│       ├── uart_transmitter.v         # UART TX FSM and serialiser
│       ├── uart_receiver.v            # UART RX FSM and deserialiser
│       ├── uart_parity_bit_compute.v  # Parity computation (even/odd/none)
│       ├── axi_internal_fifo.v        # 16-entry synchronous FIFO (TX and RX)
│       ├── axi_uart_defines.vh        # UART constants and field definitions
│       ├── axi_uart.vh                # UART register map header
│       └── timescale.v                # Timescale directive
│
├── tb/
│   ├── tb_aes_axi_slave.sv            # AES AXI4-Lite slave testbench (SystemVerilog)
│   ├── tb_aes_axi_slave.v             # AES AXI4-Lite slave testbench (Verilog)
│   ├── tb_axi_interconnect.sv         # Interconnect testbench
│   ├── tb_axi_uart_top.sv             # UART top testbench (self-checking, 12 tests)
│   ├── tb_soc_top.sv                  # SoC-level testbench
│   └── test_bench_top.v               # AES IP basic testbench (Verilog)
│
├── scripts/
│   └── axi_interconnect_wrap.py       # Python generator for AXI interconnect wrappers
│
├── run/
│   ├── run.f                          # VCS file-list: AES IP only
│   ├── run_integrated_soc.f           # VCS file-list: full SoC (UART + interconnect)
│   ├── run1.f / run2.f                # Additional file-lists
│   └── simv.daidir/                   # VCS/Verdi simulation artifacts (generated)
│
├── doc/
│   ├── Project_spec.odt               # Project specification (source of truth)
│   ├── description.md                 # SoC integration description and address map
│   ├── aes_regset.md                  # AES register set specification
│   ├── aes_rtl_audit.md               # Detailed AES RTL-to-spec compliance audit
│   ├── aes_compliance_matrix.md       # AES requirement compliance matrix (48 items)
│   ├── aes_cbc_audit_verification_plan.md  # AES CBC verification plan
│   ├── uart_errors.md                 # UART testbench bug report (B1–B10) and fixes
│   ├── simlog.md                      # Simulation output log
│   └── aes.pdf                        # ASICS.ws AES Rijndael IP Core Rev 1.1 datasheet
│
├── .gitignore
└── README.md
```

---

## 8. Module Descriptions

### 8.1 `soc_top` — SoC Top-Level

**File:** [`rtl/interconnect/soc_top.v`](rtl/interconnect/soc_top.v)

The SoC top-level module. Exposes two full AXI4 slave ports (`s00`, `s01`) for external masters (e.g. CPU LSU and DMA). Instantiates the 2×10 crossbar, the AXI4-to-AXI4-Lite bridge, and `axi_uart_top`. Master ports m02–m09 are tied off with `bresp/rresp = 2'b10` (SLVERR) and all ready signals deasserted.

### 8.2 `axi_interconnect_wrap_2x10` / `axi_interconnect` — AXI4 Crossbar

**Files:** [`rtl/interconnect/axi_interconnect_wrap_2x10.v`](rtl/interconnect/axi_interconnect_wrap_2x10.v), [`rtl/interconnect/axi_interconnect.v`](rtl/interconnect/axi_interconnect.v)

A parameterised AXI4 crossbar (Alex Forencich open-source). The 2×10 wrapper fixes `S_COUNT=2`, `M_COUNT=10` and flattens the port interface. Address decoding is performed by base address and decode-width parameters set per master port. Internal round-robin arbiters handle concurrent access from both slave ports.

### 8.3 `axi_to_axilite_bridge` — Protocol Bridge

**File:** [`rtl/interconnect/axi_to_axilite_bridge.v`](rtl/interconnect/axi_to_axilite_bridge.v)

Purely combinational. Bridges the interconnect's full AXI4 master ports to the AXI4-Lite slave interfaces of the UART (and formerly AES) peripherals. No additional pipeline stages. See [Section 6](#6-system-architecture-current-repository) for bridge details.

### 8.4 `axi_uart_top` — UART Peripheral

**File:** [`rtl/uart/axi_uart_top.v`](rtl/uart/axi_uart_top.v)

AXI4-Lite slave UART peripheral. Two clock inputs: `axi_aclk_i` (AXI bus clock) and `fixed_clk_i` (UART baud reference clock). Internally instantiates `uart_controller`, a TX FIFO, and an RX FIFO (each 16 entries deep via `axi_internal_fifo`).

**UART Register Map** (base `0x4000_1000`):

| Offset | Register | Access | Description |
|---|---|---|---|
| 0x00 | THR / RBR | W / R | Transmit Holding / Receive Buffer (DLAB=0) |
| 0x04 | IER | R/W | Interrupt Enable Register |
| 0x08 | BAUD_DIV | R/W | Baud Rate Divisor (DLAB=1) |
| 0x0C | LCR | R/W | Line Control Register |
| 0x14 | LSR | R | Line Status Register |

> **Known RTL limitation:** LSR bits [6:5] (THRE / TEMT) are always `0` due to a threshold constant truncation bug in `axi_internal_fifo.v` (`FIFO_THRESHOLD=90` is bit-truncated to 26 which always exceeds the FIFO depth of 16). This is a documented RTL defect; the testbench has been updated to reflect this known behavior.

### 8.5 `aes_core_top` — AES Accelerator Top

**File:** [`rtl/interconnect/aes_core_top.v`](rtl/interconnect/aes_core_top.v)

Top-level AES accelerator. Instantiates `aes_regfile` (AXI4-Lite register file) and the two ASICS.ws IP cores (`u_cipher` for encryption, `u_inv_cipher` for decryption), and contains the AES control FSM. Both cores share the same `core_key_mux` and `text_in_mux` buses.

> **Important:** This module is **not instantiated in the current `soc_top.v`**. It exists in the repository and has its own testbench but is not part of the integrated SoC simulation as of the latest commit.

**AES FSM States:**

| State | Encoding | Description |
|---|---|---|
| `ST_IDLE` | 4'd0 | Waits for `ctrl_start` |
| `ST_KEY_LOAD1` | 4'd1 | Loads first 128-bit key half |
| `ST_KEY_WAIT1` | 4'd2 | Waits for IP `done`/`kdone` on first key |
| `ST_KEY_LOAD2` | 4'd3 | Loads second 128-bit key half (AES-256/192) |
| `ST_KEY_WAIT2` | 4'd4 | Waits for IP `done`/`kdone` on second key |
| `ST_DATA_LOAD` | 4'd5 | Applies CBC XOR and pulses IP load |
| `ST_DATA_WAIT` | 4'd6 | Waits for IP encrypt/decrypt `done` |
| `ST_DONE` | 4'd7 | Pulses `core_done_r`, clears BUSY, returns to IDLE |
| `ST_SOFT_RST` | 4'd8 | Defined but **never entered** (dead state) |

### 8.6 `aes_regfile` — AES Register File

**File:** [`rtl/interconnect/aes_regfile.v`](rtl/interconnect/aes_regfile.v)

AXI4-Lite slave register file for the AES accelerator. Implements 22 registers across a 96-byte address space. Full register specification is in [`doc/aes_regset.md`](doc/aes_regset.md).

**AES Register Map** (base `0x4000_0000`, offsets relative to base):

| Offset | Register | Access | Description |
|---|---|---|---|
| 0x00 | `AES_CTRL` | R/W | Control: START[0], IRQ_EN[1], DECRYPT[2], KEY_SIZE[4:3], MODE_CBC[5], MODE_CTR[6], SOFT_RST[7] |
| 0x04 | `AES_STATUS` | RO/W1C | Status: BUSY[0], DONE[1], KEY_READY[2], ERR[3] |
| 0x08 | `AES_BLK_CNT` | R/W | Block count: TOTAL_BLOCKS[15:0] (WR), DONE_BLOCKS[31:16] (RO) |
| 0x0C | `AES_IRQ_CLR` | W1C | Interrupt clear |
| 0x10–0x2C | `AES_KEY0–7` | WO | 256-bit key (8 × 32-bit, reads return 0) |
| 0x30–0x3C | `AES_IV0–3` | R/W | 128-bit Initialization Vector |
| 0x40–0x4C | `AES_DIN0–3` | WO | 128-bit data input (4 × 32-bit) |
| 0x50–0x5C | `AES_DOUT0–3` | RO | 128-bit data output (4 × 32-bit, combinational) |

---

## 9. Address Map

### 9.1 Current SoC Address Map (`soc_top.v`)

| Port | Peripheral | Base Address | Decode Width | Effective Range |
|---|---|---|---|---|
| m00 | (tied off) | `0x0000_0000` | 0 bits | unreachable |
| m01 | `axi_uart_top` | `0x4000_1000` | 8 bits | `0x4000_1000 – 0x4000_10FF` |
| m02–m09 | (reserved) | `0x0000_0000` | 0 bits | unreachable |

### 9.2 Planned SoC Address Map (from `doc/description.md`)

| Port | Peripheral | Base Address | Decode Width | Effective Range |
|---|---|---|---|---|
| m00 | `aes_core_top` | `0x4000_0000` | 24 bits | `0x4000_0000 – 0x40FF_FFFF` |
| m01 | `axi_uart_top` | `0x4000_1000` | 8 bits | `0x4000_1000 – 0x4000_10FF` |
| m02–m09 | (reserved) | `0x0000_0000` | 0 bits | unreachable |

> The UART decode at `0x4000_1000` (8-bit) takes priority over the overlapping AES 24-bit window via longest-prefix matching in the interconnect.

---

## 10. Verification & Testing

### 10.1 Testbench Overview

| Testbench | File | DUT | Self-Checking | Status |
|---|---|---|---|---|
| AES IP basic | `tb/test_bench_top.v` | `aes_cipher_top`, `aes_inv_cipher_top` | No | Unknown — no sim log |
| AES AXI4-Lite slave | `tb/tb_aes_axi_slave.sv` | `aes_core_top` | Yes | Unknown — no sim log |
| AES AXI4-Lite slave | `tb/tb_aes_axi_slave.v` | `aes_core_top` | No | Unknown |
| AXI interconnect | `tb/tb_axi_interconnect.sv` | `axi_interconnect_wrap_2x10` | Yes | Unknown — no sim log |
| UART top | `tb/tb_axi_uart_top.sv` | `axi_uart_top` | Yes (12 tests) | **PASS=7, FAIL=3** (before final fixes); expected PASS=12 after B1–B10 |
| SoC top | `tb/tb_soc_top.sv` | `soc_top` | Yes | **Elaboration error** — `aes_core_top` not in compile list |

### 10.2 UART Testbench Results

Simulation was run with Synopsys VCS U-2023.03 on Rocky Linux 8.10. Three rounds of testbench debugging were performed, identifying and fixing 10 bugs (B1–B10) documented in [`doc/uart_errors.md`](doc/uart_errors.md).

**Final simulation result (before B9/B10 applied):** `PASS=7, FAIL=3`

**Expected result after all 10 fixes applied:**

| Test | Description | Expected |
|---|---|---|
| 1 | LCR DLAB=1 write | PASS |
| 2 | Baud divisor write | PASS |
| 3 | LCR 8N1 write | PASS |
| 4 | IER enable write | PASS |
| 5 | LSR read (THRE=0, TEMT=0 — RTL threshold bug) | PASS |
| 6 | TX 0x55 loopback | PASS |
| 7 | TX 0xAA loopback | PASS |
| 8 | RX 0x37 inject → RBR | PASS |
| 9 | RX 0xC3 inject → RBR | PASS |
| 10 | RX interrupt assertion | PASS |
| 11 | Back-to-back TX 0x01, 0x02, 0x03 | PASS |
| 12 | LSR drain check | PASS |

> A re-run confirming all 12 tests pass has not been committed to the repository. The expected results above are from the analysis in `doc/uart_errors.md`.

### 10.3 UART Testbench Bugs Fixed

| Bug ID | Severity | Root Cause | Fix Summary |
|---|---|---|---|
| B1 | Critical | `axi_write`: valids deasserted before BVALID — caused infinite deadlock | Keep `awvalid`/`wvalid` asserted until `bvalid` seen |
| B2 | Critical | `axi_read`: `arvalid` deasserted before RVALID — deadlock on every read | Keep `arvalid` asserted until `rvalid` seen |
| B3 | Critical | Tests 8/9: only 50-cycle RX settle wait (needed ≥440 for receiver pipeline) | Increased to 600 cycles |
| B4 | Critical | Test 10: same 50-cycle wait for interrupt check | Increased to 600 cycles |
| B5 | Minor | `recv_uart_byte`: combinational wire sample fragile at clock edge | Added clarifying comment |
| B6 | Critical | Test 5: THRE/TEMT expected 1 but RTL always drives 0 (threshold bug) | Corrected expected values to 0 |
| B7 | Critical | Test 7: fork race — `@(negedge uart_tx)` latches wrong edge for 0xAA | Added 10-cycle write-thread head start |
| B8 | Critical | Test 11: same fork race for back-to-back TX | Added 10-cycle head start |
| B9 | Critical | `recv_uart_byte`: async negedge triggers on data-bit transitions | Replaced with synchronous clock-edge polling |
| B10 | Minor | Tests 6/7/11: `repeat(10)` head-starts now harmful after B9 fix | Removed head-start delays |

### 10.4 AES Verification Status

The AES subsystem has been audited against 48 requirements. Key verification findings from [`doc/aes_cbc_audit_verification_plan.md`](doc/aes_cbc_audit_verification_plan.md):

| Test Category | Feasible in RTL | Will Fail |
|---|---|---|
| Single-block AES-128 ECB encrypt | Yes | — |
| Single-block AES-128 ECB decrypt | Yes | — |
| Single-block AES-256 ECB encrypt | — | Yes (AES-128 IP) |
| Multi-block encryption (N>1) | — | Yes (`blk_remaining` hardwired) |
| NIST AES-256-CBC vector | — | Yes (AES-128 IP + IV disconnected) |
| CBC-D correctness | — | Yes (XOR timing bug) |
| Beat-based DMA I/O (S3/S4) | — | Not testable (not implemented) |

---

## 11. Simulation Instructions

### Prerequisites

- Synopsys VCS (tested: U-2023.03\_Full64)
- Synopsys Verdi (for waveform viewing)
- Linux environment (tested: Rocky Linux 8.10 x86\_64)

All commands must be run from the `run/` directory.

### 11.1 UART Standalone Simulation

```bash
cd run/

# Compile and simulate (text output only)
vcs -full64 -sverilog -f run_integrated_soc.f -o simv_uart && ./simv_uart

# Compile and simulate with Verdi waveform capture
vcs -full64 -sverilog -kdb -lca -debug_access+all \
    -f run_integrated_soc.f -o simv_uart && ./simv_uart -verdi

# Open captured waveform
verdi -ssf dump.fsdb &
```

> **Note:** The integrated SoC simulation currently produces an elaboration error (`aes_core_top` module not found) because the AES module was removed from `run_integrated_soc.f`. The UART sub-hierarchy compiles cleanly. If only UART is required, remove the `soc_top.v` instantiation reference or use the UART-only file-list.

### 11.2 AES IP Standalone Simulation

```bash
cd run/

# Compile AES IP and basic testbench
vcs -full64 -sverilog -f run.f -o simv_aes && ./simv_aes
```

### 11.3 Waveform Viewer

```bash
verdi -ssf dump.fsdb &
# or
verdi -ssf dump_soc.fsdb &
```

---

## 12. Current Limitations & Known Issues

### 12.1 AES Accelerator

| # | Issue | Severity |
|---|---|---|
| 1 | AES-128 IP used instead of AES-256. Encrypted output is not FIPS-197 AES-256. | Critical |
| 2 | IV register (`AES_IV0–3`) never connected to CBC feedback path. CBC always uses IV=0. | Critical |
| 3 | CBC decryption XOR uses current ciphertext block instead of previous (timing bug). | Critical |
| 4 | `TOTAL_BLOCKS` register stored but `blk_remaining` hardwired to 1. Multi-block non-functional. | Critical |
| 5 | AXI4 data-plane (S3/S4 slaves), 64-bit beat assembly, FIFOs, and backpressure entirely absent. | Critical |
| 6 | `SOFT_RST` does not clear `key_data`, `iv_data`, or `din_data` registers. | High |
| 7 | `SOFT_RST` does not reset the AES IP cores (`rst_n = aresetn` only). | High |
| 8 | No busy-state write protection — configuration registers can be modified mid-operation. | High |
| 9 | `AES_STATUS.ERR` bit is never set by hardware (dead bit). | Medium |
| 10 | `AES_DOUT` output is combinational, not registered — unstable hold at DONE assertion. | Medium |
| 11 | `ST_SOFT_RST` state (4'd8) defined but never entered — dead code. | Low |
| 12 | `AES_STATUS.DONE_BLOCKS` counter not reset on new `START`. | Low |
| 13 | Both cipher and inverse cipher cores run simultaneously (unselected core spuriously active). | Medium |
| 14 | `aes_core_top` not in the integrated SoC (`soc_top.v`) or compile list (`run_integrated_soc.f`). | — |

### 12.2 UART

| # | Issue | Severity |
|---|---|---|
| 1 | LSR bits THRE[5] and TEMT[6] always read 0. Root cause: `FIFO_THRESHOLD=90` is bit-truncated to 26 in `axi_internal_fifo.v`, which always exceeds the FIFO depth of 16. | Medium |
| 2 | `axi_bvalid_o` gated by `awvalid & wvalid` — master must hold valid signals until `bvalid` is seen (non-standard but documented behaviour). | Low |
| 3 | `axi_rvalid_o` gated by `arvalid` — master must hold `arvalid` until `rvalid` is seen. | Low |

### 12.3 SoC Integration

| # | Issue | Severity |
|---|---|---|
| 1 | `run_integrated_soc.f` references `soc_top.v` which instantiates `aes_core_top`, but `aes_core_top.v` is absent from the compile list — elaboration fails with `URMI` error. | High |
| 2 | `tb_soc_top.sv` connects fewer ports than `soc_top` module definition — `TFIPC` warning. | Low |

---

## 13. Future Work / Planned Features

The following components are required to complete the intended architecture described in `doc/Project_spec.odt`:

| Priority | Item |
|---|---|
| 🔴 High | Re-integrate `aes_core_top` into `soc_top.v` and `run_integrated_soc.f` |
| 🔴 High | Replace ASICS.ws AES-128 IP with a true AES-256 core (14 rounds, 256-bit key schedule) |
| 🔴 High | Fix `iv_data` → `feedback_reg` connection in `aes_core_top` |
| 🔴 High | Fix CBC-D XOR timing (add `prev_ciphertext` register) |
| 🔴 High | Fix `blk_remaining` to load from `total_blocks`; add FSM decrement and multi-block loop |
| 🔴 High | Implement AXI4 data-plane slaves (S3 input, S4 output) with 64-bit beats, beat assembly/splitting, and input/output FIFOs |
| 🟠 Medium | Add SHA-256 hardware accelerator RTL (with AXI4-Lite control interface) |
| 🟠 Medium | Add DMA controller RTL (AXI4 master, AXI4-Lite control interface) |
| 🟠 Medium | Add Timer, GPIO, and PIC peripherals with AXI4-Lite interfaces |
| 🟠 Medium | Integrate VeeR EL2 RISC-V CPU core |
| 🟠 Medium | Add System SRAM model |
| 🟡 Low | Fix UART FIFO threshold calculation in `axi_internal_fifo.v` |
| 🟡 Low | Add busy-state write protection to AES register file |
| 🟡 Low | Connect `SOFT_RST` to key register clearing and IP core reset |
| 🟡 Low | Register `AES_DOUT` output for stable hold at DONE |
| 🟡 Low | Run and commit final confirmed UART simulation log (all 12 PASS) |

---

## 14. Technologies & Tools

| Category | Tool / Technology |
|---|---|
| **HDL** | Verilog (IEEE 1364-2001), SystemVerilog (IEEE 1800-2012) |
| **Simulation** | Synopsys VCS U-2023.03\_Full64 |
| **Waveform Viewer** | Synopsys Verdi (FSDB format) |
| **OS** | Rocky Linux 8.10 (x86\_64) |
| **AES IP** | ASICS.ws AES Rijndael IP Core Rev 1.1 (AES-128) |
| **AXI Interconnect** | Alex Forencich parameterised AXI4 crossbar (open-source) |
| **Version Control** | Git / GitHub |
| **Documentation** | Markdown, LibreOffice Writer (.odt) |
| **Scripting** | Python 3 (Jinja2 template engine for RTL generation) |

---

## 15. References

1. **Project Specification:** `doc/Project_spec.odt` — *RISC-V Based Cryptographic Telemetry Gateway SoC*, Honours Project Brief.
2. **AES IP Datasheet:** `doc/aes.pdf` — *ASICS.ws AES Rijndael IP Core Rev 1.1*.
3. **AES Standard:** NIST FIPS 197 — *Advanced Encryption Standard (AES)*, November 2001.
4. **SHA-256 Standard:** NIST FIPS 180-4 — *Secure Hash Standard (SHS)*, August 2015.
5. **AXI Protocol:** ARM IHI0022E — *AMBA AXI and ACE Protocol Specification*, 2013.
6. **AXI Interconnect:** Alex Forencich — *verilog-axi*, GitHub: `alexforencich/verilog-axi`.
7. **VeeR EL2 Core:** Western Digital — *VeeR EL2 Programmer's Reference Manual*, 2021.
8. **Internal Audit Documents:** `doc/aes_rtl_audit.md`, `doc/aes_compliance_matrix.md`, `doc/aes_cbc_audit_verification_plan.md`, `doc/uart_errors.md`.

---

*This README was generated from a complete analysis of the repository source code, git history, simulation logs, and project specification. All technical claims are sourced directly from the repository contents. Features are described as implemented in the repository at the time of this writing and are not assumed from the specification alone.*
