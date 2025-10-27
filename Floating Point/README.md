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
## 🧩 Datapath Stages
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




