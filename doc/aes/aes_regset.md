# AES Rijndael IP Core — Register Set Specification
## Reference: ASICS.ws AES Rijndael IP Core Rev 1.1 (aes.pdf)
## Interface: AXI4-Lite, 32-bit registers, 8-bit byte addressing

---

## 1. Overview

Every register is **32 bits wide**.

There are **two independent register sets** — one for the AES Cipher core
(encryption) and one for the AES Inverse Cipher core (decryption), each
following an identical structure:

| Group        | Registers     | Total bits |
|--------------|---------------|------------|
| CSR          | 1 × 32-bit    | 32 bit     |
| KEY0–KEY7    | 8 × 32-bit    | 256-bit key|
| TEXT_IN0–3   | 4 × 32-bit    | 128-bit    |
| TEXT_OUT0–3  | 4 × 32-bit    | 128-bit RO |

Each set occupies **0x44 bytes** (17 registers × 4 bytes).

| Block             | Base Offset | End Offset |
|-------------------|-------------|------------|
| AES Cipher        | 0x00        | 0x40       |
| AES Inverse Cipher| 0x44        | 0x84       |

---

## 2. CSR — Control/Status Register (32-bit)

**One CSR per core. Upper 16 bits = CONTROL. Lower 16 bits = STATUS.**

```
 31      16 15       0
 ┌─────────┬─────────┐
 │ CONTROL │ STATUS  │
 └─────────┴─────────┘
```

### 2.1 AES Cipher CSR

| Bits  | Field  | Access | Reset | Description                                             |
|-------|--------|--------|-------|---------------------------------------------------------|
| 31:17 | —      | RAZ/WI | 0     | Reserved                                                |
| 16    | LD     | WO/SC  | 0     | Write 1 to assert `ld` for one clock cycle. Self-clears. Loads `key` + `text_in` and starts encryption. Reads as 0. |
| 15:1  | —      | RAZ    | 0     | Reserved                                                |
| 0     | DONE   | RO     | 0     | Reflects `done` output from `aes_cipher_top`. Set for one clock cycle when encryption completes. |

> From aes.pdf §3.1: The cipher core starts when `ld` is asserted high.
> It completes in 12 clock cycles and asserts `done` for one clock cycle.

### 2.2 AES Inverse Cipher CSR

| Bits  | Field  | Access | Reset | Description                                              |
|-------|--------|--------|-------|----------------------------------------------------------|
| 31:18 | —      | RAZ/WI | 0     | Reserved                                                 |
| 17    | KLD    | WO/SC  | 0     | Write 1 to assert `kld` for one clock cycle. Self-clears. Triggers key expansion; wait for KDONE before asserting LD. |
| 16    | LD     | WO/SC  | 0     | Write 1 to assert `ld` for one clock cycle. Self-clears. Starts decryption sequence. Key must be pre-loaded (KDONE=1). |
| 15:2  | —      | RAZ    | 0     | Reserved                                                 |
| 1     | KDONE  | RO     | 0     | Reflects `kdone` output. Set for one clock cycle when key expansion is complete. Decryption may now be started. |
| 0     | DONE   | RO     | 0     | Reflects `done` output. Set for one clock cycle when decryption completes. |

> From aes.pdf §3.2: `kld` must be asserted first; wait for `kdone` before
> asserting `ld`. Key and decrypt sequences cannot run in parallel.

---

## 3. KEY Registers (256-bit, 8 × 32-bit)

**Identical layout for both cipher and inv_cipher.**

Each register is **Write-Only**. Reads return 0x00000000.
All 8 registers must be written to provide a complete 256-bit key.

The 128-bit `key[127:0]` port on each IP core is driven by
`{KEY3, KEY2, KEY1, KEY0}` (lower 128 bits of the 256-bit key).

> Note: The ASICS.ws IP natively accepts a 128-bit key. Driving the full
> 256-bit key requires two sequential `ld`/`kld` pulses — first with
> KEY0–3 (`key[127:0]`), then with KEY4–7 (`key[255:128]`).

| Register | Offset from block base | Access | Key Slice       |
|----------|------------------------|--------|-----------------|
| KEY0     | +0x04                  | WO     | key[31:0]       |
| KEY1     | +0x08                  | WO     | key[63:32]      |
| KEY2     | +0x0C                  | WO     | key[95:64]      |
| KEY3     | +0x10                  | WO     | key[127:96]     |
| KEY4     | +0x14                  | WO     | key[159:128]    |
| KEY5     | +0x18                  | WO     | key[191:160]    |
| KEY6     | +0x1C                  | WO     | key[223:192]    |
| KEY7     | +0x20                  | WO     | key[255:224]    |

Key assembly: `key[255:0] = {KEY7, KEY6, KEY5, KEY4, KEY3, KEY2, KEY1, KEY0}`

First `ld`/`kld` pulse uses: `key[127:0]  = {KEY3, KEY2, KEY1, KEY0}`
Second `ld`/`kld` pulse uses: `key[255:128] = {KEY7, KEY6, KEY5, KEY4}`

---

## 4. TEXT_IN Registers (128-bit, 4 × 32-bit)

**Identical layout for both cipher and inv_cipher.**

Write-Only. Reads return 0x00000000.
These map to the `text_in[127:0]` port of the respective IP core.

| Register  | Offset from block base | Access | text_in Slice      |
|-----------|------------------------|--------|--------------------|
| TEXT_IN0  | +0x24                  | WO     | text_in[31:0]      |
| TEXT_IN1  | +0x28                  | WO     | text_in[63:32]     |
| TEXT_IN2  | +0x2C                  | WO     | text_in[95:64]     |
| TEXT_IN3  | +0x30                  | WO     | text_in[127:96]    |

Assembly: `text_in[127:0] = {TEXT_IN3, TEXT_IN2, TEXT_IN1, TEXT_IN0}`

> For the cipher core: write plaintext here before asserting CSR.LD.
> For the inv_cipher core: write ciphertext here before asserting CSR.LD.
> All four registers must be written before asserting LD.

---

## 5. TEXT_OUT Registers (128-bit, 4 × 32-bit)

**Identical layout for both cipher and inv_cipher.**

Read-Only. Driven directly by `text_out[127:0]` of the respective IP core.
Valid to read after the core asserts `done` (CSR.DONE = 1).

| Register   | Offset from block base | Access | text_out Slice      |
|------------|------------------------|--------|---------------------|
| TEXT_OUT0  | +0x34                  | RO     | text_out[31:0]      |
| TEXT_OUT1  | +0x38                  | RO     | text_out[63:32]     |
| TEXT_OUT2  | +0x3C                  | RO     | text_out[95:64]     |
| TEXT_OUT3  | +0x40                  | RO     | text_out[127:96]    |

Assembly: `text_out[127:0] = {TEXT_OUT3, TEXT_OUT2, TEXT_OUT1, TEXT_OUT0}`

> For the cipher core: read ciphertext after CSR.DONE = 1.
> For the inv_cipher core: read plaintext after CSR.DONE = 1.

---

## 6. Full Register Address Map

### 6.1 AES Cipher Core (Base 0x00)

```
Offset  Register         Access   Reset       IP Signal
------  ---------------  -------  ----------  --------------------------
0x00    CIPHER_CSR       R/W      0x00000000  [16]=ld(SC), [0]=done(RO)
0x04    CIPHER_KEY0      WO       0x00000000  key[31:0]
0x08    CIPHER_KEY1      WO       0x00000000  key[63:32]
0x0C    CIPHER_KEY2      WO       0x00000000  key[95:64]
0x10    CIPHER_KEY3      WO       0x00000000  key[127:96]
0x14    CIPHER_KEY4      WO       0x00000000  key[159:128]
0x18    CIPHER_KEY5      WO       0x00000000  key[191:160]
0x1C    CIPHER_KEY6      WO       0x00000000  key[223:192]
0x20    CIPHER_KEY7      WO       0x00000000  key[255:224]
0x24    CIPHER_TEXT_IN0  WO       0x00000000  text_in[31:0]
0x28    CIPHER_TEXT_IN1  WO       0x00000000  text_in[63:32]
0x2C    CIPHER_TEXT_IN2  WO       0x00000000  text_in[95:64]
0x30    CIPHER_TEXT_IN3  WO       0x00000000  text_in[127:96]
0x34    CIPHER_TEXT_OUT0 RO       0x00000000  text_out[31:0]
0x38    CIPHER_TEXT_OUT1 RO       0x00000000  text_out[63:32]
0x3C    CIPHER_TEXT_OUT2 RO       0x00000000  text_out[95:64]
0x40    CIPHER_TEXT_OUT3 RO       0x00000000  text_out[127:96]
```

### 6.2 AES Inverse Cipher Core (Base 0x44)

```
Offset  Register           Access   Reset       IP Signal
------  -----------------  -------  ----------  ------------------------------------
0x44    INV_CSR            R/W      0x00000000  [17]=kld(SC),[16]=ld(SC),[1]=kdone(RO),[0]=done(RO)
0x48    INV_KEY0           WO       0x00000000  key[31:0]
0x4C    INV_KEY1           WO       0x00000000  key[63:32]
0x50    INV_KEY2           WO       0x00000000  key[95:64]
0x54    INV_KEY3           WO       0x00000000  key[127:96]
0x58    INV_KEY4           WO       0x00000000  key[159:128]
0x5C    INV_KEY5           WO       0x00000000  key[191:160]
0x60    INV_KEY6           WO       0x00000000  key[223:192]
0x64    INV_KEY7           WO       0x00000000  key[255:224]
0x68    INV_TEXT_IN0       WO       0x00000000  text_in[31:0]
0x6C    INV_TEXT_IN1       WO       0x00000000  text_in[63:32]
0x70    INV_TEXT_IN2       WO       0x00000000  text_in[95:64]
0x74    INV_TEXT_IN3       WO       0x00000000  text_in[127:96]
0x78    INV_TEXT_OUT0      RO       0x00000000  text_out[31:0]
0x7C    INV_TEXT_OUT1      RO       0x00000000  text_out[63:32]
0x80    INV_TEXT_OUT2      RO       0x00000000  text_out[95:64]
0x84    INV_TEXT_OUT3      RO       0x00000000  text_out[127:96]
```

---

## 7. Programming Sequences

### 7.1 Encryption (aes_cipher_top)

```
// 1. Load 256-bit key (lower half first)
Write CIPHER_KEY0 = key[31:0]
Write CIPHER_KEY1 = key[63:32]
Write CIPHER_KEY2 = key[95:64]
Write CIPHER_KEY3 = key[127:96]
// 2. Load plaintext
Write CIPHER_TEXT_IN0 = plain[31:0]
Write CIPHER_TEXT_IN1 = plain[63:32]
Write CIPHER_TEXT_IN2 = plain[95:64]
Write CIPHER_TEXT_IN3 = plain[127:96]
// 3. Start encryption
Write CIPHER_CSR = 0x00010000   // LD=1 (bit 16), self-clears
// 4. Wait ~12 cycles, poll DONE
Poll CIPHER_CSR[0] == 1         // DONE asserted for one cycle
// 5. Read ciphertext
Read CIPHER_TEXT_OUT0..3
```

### 7.2 Decryption (aes_inv_cipher_top)

```
// 1. Load 256-bit key
Write INV_KEY0..INV_KEY7        // same as encryption
// 2. Trigger key expansion
Write INV_CSR = 0x00020000      // KLD=1 (bit 17), self-clears
// 3. Wait for key expansion (~12 cycles)
Poll INV_CSR[1] == 1            // KDONE asserted
// 4. Load ciphertext
Write INV_TEXT_IN0 = cipher[31:0]
Write INV_TEXT_IN1 = cipher[63:32]
Write INV_TEXT_IN2 = cipher[95:64]
Write INV_TEXT_IN3 = cipher[127:96]
// 5. Start decryption
Write INV_CSR = 0x00010000      // LD=1 (bit 16), self-clears
// 6. Wait ~12 cycles, poll DONE
Poll INV_CSR[0] == 1            // DONE asserted
// 7. Read plaintext
Read INV_TEXT_OUT0..3
```

---

## 8. Signal Connection Summary

| Register Field         | Direction      | IP Core Signal (Cipher)    | IP Core Signal (Inv Cipher)  |
|------------------------|----------------|----------------------------|------------------------------|
| CIPHER_CSR[16] LD      | Regfile → Core | `ld` (1-cycle pulse)       | —                            |
| CIPHER_CSR[0]  DONE    | Core → Regfile | `done` (1-cycle pulse)     | —                            |
| INV_CSR[17]    KLD     | Regfile → Core | —                          | `kld` (1-cycle pulse)        |
| INV_CSR[16]    LD      | Regfile → Core | —                          | `ld` (1-cycle pulse)         |
| INV_CSR[1]     KDONE   | Core → Regfile | —                          | `kdone` (1-cycle pulse)      |
| INV_CSR[0]     DONE    | Core → Regfile | —                          | `done` (1-cycle pulse)       |
| KEY0–KEY7              | Regfile → Core | `key[127:0]` (lower half)  | `key[127:0]` (lower half)    |
| TEXT_IN0–3             | Regfile → Core | `text_in[127:0]`           | `text_in[127:0]`             |
| TEXT_OUT0–3            | Core → Regfile | `text_out[127:0]`          | `text_out[127:0]`            |

---

*Based on: ASICS.ws AES Rijndael IP Core Rev 1.1 (aes.pdf), Table 1 — Core Interfaces.*
*RTL: rtl/aes/aes_cipher_top.v, rtl/aes/aes_inv_cipher_top.v*
