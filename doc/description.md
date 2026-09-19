# SoC Integration Description

**Project:** RISC-V Cryptographic Telemetry Gateway SoC  
**Date:** 2026-09-19  
**Files created:**
- `rtl/interconnect/axi_to_axilite_bridge.v`
- `rtl/interconnect/soc_top.v`

---

## What was done

The UART IP core (`axi_uart_top`) was integrated into the SoC as a memory-mapped
peripheral reachable by both AXI masters through the existing 2x10 AXI
interconnect.  Three new artefacts were created:

1. **`axi_to_axilite_bridge.v`** — a protocol-adaptation bridge between the
   interconnect's full AXI4 master ports and the AXI4-Lite slave interfaces of
   the peripherals.

2. **`soc_top.v`** — the SoC top-level module that wires the interconnect, the
   bridges, the AES core (m00), and the UART (m01) together and ties off the
   eight unused master ports (m02–m09).

3. **`doc/description.md`** — this file.

---

## System architecture

```
                 ┌──────────────────────────────────────┐
  AXI Master 0  ─┤  s00          axi_interconnect        ├─ m00 ─► [bridge] ─► aes_core_top
  AXI Master 1  ─┤  s01          _wrap_2x10              ├─ m01 ─► [bridge] ─► axi_uart_top
                 │                                       ├─ m02 ─► (tied off)
                 │                                       │  ...
                 └───────────────────────────────────────┘  m09 ─► (tied off)
```

Both AXI masters (e.g. a CPU and a DMA engine) can reach any peripheral. The
interconnect's internal arbiter handles concurrent access. Address decoding is
performed by the interconnect using the base address and decode-width parameters
supplied at instantiation.

---

## Address map

| Master port | Peripheral     | Base address  | Decode width | Address range           |
|-------------|----------------|---------------|--------------|-------------------------|
| m00         | AES-256 core   | `0x4000_0000` | 24 bits      | `0x4000_0000–0x40FF_FFFF` |
| m01         | UART           | `0x4000_1000` | 8 bits       | `0x4000_1000–0x4000_10FF` |
| m02–m09     | (reserved)     | `0x0000_0000` | 0 bits       | unreachable              |

### Why these addresses

- `0x4000_0000` is a standard peripheral base in the 1 GB "device" window
  (`0x4000_0000–0x7FFF_FFFF`) common in RISC-V SoC designs. It avoids the
  lower DRAM region and sits well above any boot-ROM or SRAM.
- The AES decode width of 24 bits (16 MB) is generous; the AES register file
  only uses ~256 bytes, but a 16 MB window matches the pre-existing parameter
  set in `axi_interconnect_wrap_2x10`.
- The UART is placed at `0x4000_1000` — a 4 KB offset above the AES base —
  which keeps it inside the AES 16 MB window from the interconnect's perspective.
  The interconnect matches the **longest prefix** first (smallest decode width
  wins for overlapping regions), so the 8-bit UART decode at `0x4000_1000`
  takes priority over the 24-bit AES decode for that address, ensuring no
  ambiguity. The UART register file occupies only 21 bytes (`0x00`–`0x14`); an
  8-bit (256-byte) decode window is the minimum practical power-of-two granularity
  and gives room for future register additions.

### UART register map (byte offsets from base `0x4000_1000`)

| Offset | Register | Access | Description                    |
|--------|----------|--------|--------------------------------|
| 0x00   | THR/RBR  | W/R    | Transmit Holding / Receive Buffer (DLAB=0) |
| 0x04   | IER      | R/W    | Interrupt Enable Register       |
| 0x08   | BAUD_DIV | R/W    | Baud Rate Divisor (DLAB=1)      |
| 0x0C   | LCR      | R/W    | Line Control Register           |
| 0x14   | LSR      | R      | Line Status Register            |

---

## Why a bridge is needed

The interconnect (`axi_interconnect_wrap_2x10` / `axi_interconnect.v`) implements
full **AXI4** on all master ports. Full AXI4 includes burst fields (`awlen`,
`awsize`, `awburst`, `wlast`, `rlast`, `arlen`, etc.) and an 8-bit transaction
ID. The two peripherals implement **AXI4-Lite**, which:

- Has no burst capability (every transaction is exactly one beat).
- Has no `wlast`/`rlast` signals.
- Typically uses a narrower ID field (4 bits in both `aes_core_top` and
  `axi_uart_top`).

Rather than modifying the verified peripheral IPs or the third-party interconnect,
a thin **combinational bridge** (`axi_to_axilite_bridge.v`) was inserted between
each interconnect master port and its peripheral. The bridge:

- **Strips** all burst-only fields and lets them float (the interconnect will
  only issue single-beat transactions to properly-decoded peripheral addresses,
  so `awlen=0` is guaranteed in practice).
- **Passes through** address (lower `S_ADDR_WIDTH` bits), data, strobe, prot,
  and all handshake signals unchanged.
- **Truncates** the ID from 8 bits to 4 bits by keeping only the lower nibble.
  The interconnect appends routing prefix bits to the MSBs of the ID; the lower
  bits preserve the original master ID and are sufficient for response routing.
- **Drives `rlast=1` always** on the full-AXI return path, since every AXI-Lite
  read response is inherently the last (and only) beat.

The bridge is purely combinational — zero additional latency cycles are introduced.

---

## Why `axi_uart_top` has two clocks and how they are handled

`axi_uart_top` has two separate clock inputs:

- `fixed_clk_i` — a stable reference used by the UART baud-rate generator
  and the serial transmitter/receiver FSMs. It must not be gated.
- `axi_aclk_i` — the AXI bus clock used by the AXI FSM and the
  `axi_sync_wren`/`axi_sync_rden` cross-domain synchronisers.

In `soc_top`, both are connected to separate top-level input ports (`uart_clk`
and `clk`). This keeps the two clocks structurally independent even though in
the current 50 MHz implementation they are driven from the same source. If the
system is later partitioned into different clock domains (e.g. AXI bus at 100 MHz
and UART fixed clock at 50 MHz), only the top-level connection changes — no RTL
inside `soc_top` or the peripherals needs to be modified.

---

## Why m02–m09 are tied off the way they are

Unused master ports of the interconnect must still present a valid AXI slave
interface, otherwise the interconnect's internal arbiter may stall waiting for
a response that never comes (protocol deadlock). The tie-off strategy:

- `awready = 0`, `wready = 0`, `arready = 0` — the interconnect arbiter will
  never see its request accepted, so it will not issue any transaction to these
  ports. Any address that falls in a zero-width decode region is already
  unroutable by the interconnect, so these ports should never receive traffic
  regardless.
- `bvalid = 0`, `rvalid = 0` — no spurious response will ever be injected.
- `bresp = 2'b10` (SLVERR), `rresp = 2'b10` (SLVERR) — if a transaction ever
  does reach a tied-off port through a misconfiguration, the response signals
  visible to the master will indicate a slave error rather than silently
  returning garbage data.

---

## Reset polarity

The interconnect uses **active-HIGH** reset (`rst`). Both peripheral IPs use
**active-LOW** reset (`aresetn`). `soc_top` receives `aresetn` as its external
reset input and derives `rst = ~aresetn` for the interconnect. This keeps the
external interface consistent (active-LOW is the AXI convention) while satisfying
each internal module's requirement.

---

## Files and module hierarchy

```
soc_top
├── axi_interconnect_wrap_2x10  (u_interconnect)
│   └── axi_interconnect        (axi_interconnect_inst)
│       ├── arbiter             (×20, one per master×channel)
│       └── priority_encoder    (×10)
├── axi_to_axilite_bridge       (u_bridge_aes)   — m00 → AES
├── aes_core_top                (u_aes)
│   ├── aes_regfile
│   ├── aes_cipher_top
│   └── aes_inv_cipher_top
├── axi_to_axilite_bridge       (u_bridge_uart)  — m01 → UART
└── axi_uart_top                (u_uart)
    ├── uart_controller
    │   ├── uart_transmitter
    │   │   └── uart_parity_bit_compute
    │   └── uart_receiver
    ├── axi_internal_fifo       (TX FIFO)
    └── axi_internal_fifo       (RX FIFO)
```
