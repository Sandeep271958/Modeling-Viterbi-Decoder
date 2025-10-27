# Floating Point Adder and Subtractor (IEEE 754 - Single Precision)

## Overview
This project implements a **32-bit IEEE-754 compliant single-precision Floating Point Adder and Subtractor**.  
The design follows the IEEE-754 standard for floating-point arithmetic and includes complete handling for **special cases**, **alignment**, **normalization**, **rounding**, and **overflow/underflow** conditions.

All datapath stages are implemented within a **single-cycle combinational block**

---

## Module Details
**Module Name:** `fpt_adder.v`  
**Purpose:** Perform addition of two 32-bit IEEE 754 single-precision floating-point numbers.

### IEEE 754 Format
| Field | Bits | Description |
|:------|:----:|:-------------|
| Sign | 1 | Represents the sign of the number (0 → positive, 1 → negative) |
| Exponent | 8 | Stores the biased exponent |
| Mantissa | 23 | Fractional part (with an implicit leading 1) |

---

## Operation Breakdown
1. **Exponent Alignment:**  
   The exponent of the smaller operand is adjusted to match the larger one by right-shifting its mantissa.  
2. **Mantissa Addition/Subtraction:**  
   Depending on the signs, mantissas are added or subtracted to get the intermediate sum.  
3. **Normalization:**  
   The result is shifted and the exponent adjusted to ensure it fits within normalized IEEE 754 form.  
4. **Rounding:**  
   The output is rounded to preserve precision as per IEEE 754 rounding rules.  
5. **Result Construction:**  
   The final **Sign**, **Exponent**, and **Mantissa** are combined to produce the 32-bit output.  


`(F₁ × 2ᴱ¹) + (F₂ × 2ᴱ²) = F × 2ᴱ`

---
##  Datapath Stages
The full single-cycle datapath includes **six distinct stages**, described below.

### **Stage 1: Special Case & Unpack**
- Detects **NaN**, **Infinity**, and **Zero**.  
- Unpacks valid operands into a **27-bit internal format**:  
  `1-bit implicit + 23-bit mantissa + 3-bit GRS`.  
- Handles **subnormals** and provides a **fast bypass path** to skip main datapath when special cases are detected.

### **Stage 2: Alignment**
- Compares exponents to determine the larger operand.  
- Right-shifts the smaller mantissa to align both exponents.  
- Generates **Guard (G)**, **Round (R)**, and **Sticky (S)** bits to track precision loss during shifting.

### **Stage 3: Add/Subtract**
- Performs **28-bit mantissa arithmetic** (27-bit + overflow).  
- Handles effective subtraction via **2’s complement negation** when operand signs differ.

### **Stage 4: Normalization**
- Implements a **dual-path normalizer**:
  - **Path A (Overflow):** For addition results like `10.xxxx`, performs 1-bit right shift and increments exponent.
  - **Path B (Cancellation):** For subtraction results like `00.01xxx`, uses a **Leading Zero Counter (LZC)** and **barrel shifter** to perform variable left shift and exponent adjustment.

### **Stage 5: Rounding**
- Applies **Round to Nearest, Ties to Even** logic.  
- Uses L, G, R, and S bits to decide if mantissa should round up.  
- Rounding decision equation:
  ```verilog
  round_up = G & (R | S | L);
'''

### **Stage 6: Finalization & Pack**
- Handles post-rounding overflow, underflow (subnormal conversion), and final packing into IEEE-754 32-bit format.

---
## Special Case Handling

IEEE-754 defines explicit behavior for exceptional operands:

| Case |	Condition |	Result |
|------|-----------|--------|
| NaN |	Exponent = 8'hFF, Mantissa ≠ 0 |	Any operation involving NaN → NaN |
| Infinity |	Exponent = 8'hFF, Mantissa = 0 |	A + Inf = Inf, A - Inf = -Inf, Inf - Inf = NaN |
| Zero |	Exponent = 8'h00, Mantissa = 0 |	A + 0 = A, A - 0 = A |

To minimize power, the fast bypass path directly outputs pre-determined special-case results without activating the full datapath.

### Guard, Round, and Sticky Bits

The G, R, and S bits preserve information lost during mantissa alignment.
They are essential for correct IEEE-754 rounding.

| exp_diff (Shift Amount) |	Bits Shifted Out |	Guard (G) |	Round (R) |	Sticky (S) |
|-------------------------|--------------------|-------------|-----------|------------|
| 0 |	None |	0 |	0 | 	0 |
| 1 |	mant[0] |	Bit 0 |	0 |	0 |
| 2 |	mant[1:0] |	Bit 1 |	Bit 0 |	0 |
| 3 |	mant[2:0] |	Bit 2	| Bit 1 |	OR of Bit[0] |
| ≥4 |	mant[exp_diff-1:0] |	mant[exp_diff-1] |	mant[exp_diff-2] |	OR of remaining bits

 - The Sticky bit = OR of all bits shifted out after the R bit.
This prevents bias during tie-breaking.

### Rounding Decision Table (Round to Nearest, Ties to Even)
| LSB (L) |	G |	R |	S |	Description	Decision |
|---------|---|-----|-----|------------------------|
|X | 0 |	X |	X |	< 0.5 from LSB	Round Down |
|X	| 1 |	0 |	1 |	> 0.5 from LSB	Round Up |
|X	| 1 |	1 |	X |	> 0.5 from LSB	Round Up |
|0	| 1 |	0 |	0 |	Exact 0.5 tie, even LSB	Round Down |
|1	| 1 |	0 |	0 |	Exact 0.5 tie, odd LSB	Round Up |

### Exception Handling (Overflow / Underflow)
| Condition |	Description	| Action |
|-----------|--------------|--------|
| Overflow |	Exponent ≥ 255 (8'hFF) |	Result → Infinity ({sign, 8'hFF, 23'h000000}) |
| Post-Rounding Overflow |	Mantissa overflows to 10.000...000 |	Right shift by 1 and increment exponent |
| Underflow	Exponent < 1 | (unbiased E < -126)	Convert to Subnormal number | (exp=0, mantissa right-shifted) |
| Re-Rounding (Subnormal) |	Generated G, R, S bits from shift |	Perform re-rounding before packing |

## Core Hardware Blocks

- Leading Zero Counter (LZC) — Determines number of leading zeros for normalization.

- Variable Barrel Shifter — Performs left/right shifts for mantissa normalization.

- Rounding Logic — Implements IEEE-754 “Round to Nearest, Ties to Even.”

- Fast Bypass Path — Handles NaN, Inf, and Zero without full datapath activation.
---

## Key Features
- **IEEE 754 Compliance**  
  Follows single-precision floating-point addition rules precisely.  
- **Exponent Alignment & Normalization**  
  Maintains proper scaling between operands.  
- **High Precision Rounding**  
  Ensures accuracy in fractional arithmetic.  
- **Hardware-Friendly Design**  
  Suitable for FPGA or ASIC implementation.

---

## Advantages
- **High Precision:** Accurate for scientific and engineering computations.  
- **Wide Dynamic Range:** Handles very large and very small numbers efficiently.  
- **Reusable Design:** Can serve as a module in larger floating-point arithmetic units.

---

## Limitations
- **Design Complexity:** Floating-point operations require careful handling of exponents and rounding.  
- **Resource Utilization:** More hardware resources compared to integer arithmetic.

---

## Files Included
- `floatingpt_adder.v` — Verilog implementation  
- `tb_floatingpt_adder.v` — Testbench for simulation  

---

## Simulation
You can simulate the design using tools like **ModelSim**, **Vivado**, or **Icarus Verilog**.





