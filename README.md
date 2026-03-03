# 🔐 ASCON APB Accelerator  
### Authenticated Encryption Hardware IP (Verilog RTL)

<p align="center">
  <img src="docs/block_diagram.png" width="850"/>
</p>

---

## 📌 Overview

This project implements a **hardware accelerator for the ASCON authenticated encryption algorithm (AEAD)** with an **APB (Advanced Peripheral Bus) slave interface**.

The design supports:

- ✅ Encryption
- ✅ Decryption
- ✅ Authentication Tag Generation
- ✅ Tag Verification
- ✅ 64-bit data path
- ✅ 128-bit Key
- ✅ 128-bit Nonce
- ✅ FSM-based control logic
- ✅ APB register interface for SoC integration

This IP core is suitable for:

- Secure SoC integration  
- Embedded systems  
- FPGA prototyping  
- Cryptographic accelerator research  

---

# 🧱 Architecture

The design is divided into three major blocks:

### 1️⃣ APB Interface
Handles:
- Register reads and writes
- Control register decoding
- Status reporting
- Data input/output

### 2️⃣ FSM Controller
Controls:
- Initialization phase
- Permutation rounds
- Mode selection (Encrypt / Decrypt)
- Tag generation and verification

### 3️⃣ ASCON Round Core
Implements:
- pC (constant addition)
- pS (substitution layer)
- pL (diffusion layer)
- Configurable round selection (12 / 6 rounds)

---

# 🔄 Functional Flow

---

## 🔐 Encryption Flow

1. Load Key
2. Load Nonce
3. Load Plaintext
4. Write CONTROL = 0x1
5. Initialization (12 rounds)
6. Plaintext Absorption (6 rounds)
7. Finalization (12 rounds)
8. Tag Generation
9. DONE = 1

Outputs:
- Ciphertext
- Authentication Tag

---

## 🔓 Decryption Flow

1. Load Key
2. Load Nonce
3. Load Ciphertext
4. Load Received Tag
5. Write CONTROL = 0x3
6. Initialization
7. Ciphertext Absorption
8. Tag Regeneration
9. Tag Comparison
10. DONE = 1

Outputs:
- Recovered Plaintext
- TAG_VALID flag

---

# 🗺 APB Register Map

| Offset | Register | Access | Description |
|--------|----------|--------|------------|
| 0x00 | CONTROL | R/W | Start + Mode |
| 0x04 | STATUS | R | Done / Busy / Tag Valid |
| 0x08 | DATA_IN_LOW | W | Input data [31:0] |
| 0x0C | DATA_IN_HIGH | W | Input data [63:32] |
| 0x10 | DATA_OUT_LOW | R | Output data [31:0] |
| 0x14 | DATA_OUT_HIGH | R | Output data [63:32] |
| 0x18 | KEY0 | W | Key [31:0] |
| 0x1C | KEY1 | W | Key [63:32] |
| 0x20 | KEY2 | W | Key [95:64] |
| 0x24 | KEY3 | W | Key [127:96] |
| 0x28 | NONCE0 | W | Nonce [31:0] |
| 0x2C | NONCE1 | W | Nonce [63:32] |
| 0x30 | NONCE2 | W | Nonce [95:64] |
| 0x34 | NONCE3 | W | Nonce [127:96] |
| 0x38 | TAG0 | R | Tag [31:0] |
| 0x3C | TAG1 | R | Tag [63:32] |
| 0x40 | TAG2 | R | Tag [95:64] |
| 0x44 | TAG3 | R | Tag [127:96] |
| 0x48 | TAG_IN0 | W | Input Tag [31:0] |
| 0x4C | TAG_IN1 | W | Input Tag [63:32] |
| 0x50 | TAG_IN2 | W | Input Tag [95:64] |
| 0x54 | TAG_IN3 | W | Input Tag [127:96] |

---

## 🔧 CONTROL Register (0x00)

| Bit | Name | Description |
|-----|------|------------|
| 0 | START | Start operation |
| 1 | DECRYPT | 0 = Encrypt mode, 1 = Decrypt mode |
| 31:2 | Reserved | Write 0 |

### Usage

Encryption:
```c
CONTROL = 0x1;

---
👨‍💻 Author

Mohd Irfan
