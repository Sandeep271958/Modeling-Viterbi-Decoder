# Floating Point Adder (IEEE 754 - Single Precision)

## Overview
This Section implements a **32-bit single-precision Floating Point Adder** following the **IEEE 754** standard.  
It performs accurate addition of two floating-point numbers while handling exponent alignment, normalization, and rounding — just like hardware floating-point units (FPUs) in modern processors.

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




