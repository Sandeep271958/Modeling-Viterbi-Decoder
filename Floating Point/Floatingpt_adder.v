/*
 * Module: FPtAdder_IEEE754
 * Description: A single-cycle, combinatorial 32-bit floating point adder.
 *              Implements IEEE-754 standard, including:
 *              - Special cases (NaN, Inf, Zero)
 *              - Subnormal (denormalized) number support
 *              - Round-to-Nearest, Ties-to-Even rounding
 *              - Overflow and Underflow exception handling
 */
module FPtAdder_IEEE754(
    input [31:0] A, 
    input [31:0] B,
    output reg [31:0] sum,
    output reg overflow,
    output reg underflow,
    output reg inexact
);

    //================================================================
    // STAGE 1: UNPACK AND SPECIAL CASE DETECTION
    //================================================================
    
    // Deconstruct inputs
    wire sign_a = A;
    wire [7:0] exp_a = A[30:23];
    wire [22:0] mant_a = A[22:0];

    wire sign_b = B;
    wire [7:0] exp_b = B[30:23];
    wire [22:0] mant_b = B[22:0];

    // Internal registers for the datapath
    reg [7:0] exp_a_internal, exp_b_internal;
    reg [26:0] mant_a_internal, mant_b_internal; // 1 (implicit) + 23 (mant) + 3 (GRS)

    // Special case detection
    wire is_exp_a_zero = (exp_a == 8'h00);
    wire is_exp_a_ff = (exp_a == 8'hFF);
    wire is_mant_a_zero = (mant_a == 23'h0);
    
    wire is_exp_b_zero = (exp_b == 8'h00);
    wire is_exp_b_ff = (exp_b == 8'hFF);
    wire is_mant_b_zero = (mant_b == 23'h0);

    wire is_a_zero = is_exp_a_zero && is_mant_a_zero;
    wire is_b_zero = is_exp_b_zero && is_mant_b_zero;
    
    wire is_a_subnormal = is_exp_a_zero &&!is_mant_a_zero;
    wire is_b_subnormal = is_exp_b_zero &&!is_mant_b_zero;

    wire is_a_inf = is_exp_a_ff && is_mant_a_zero;
    wire is_b_inf = is_exp_b_ff && is_mant_b_zero;

    wire is_a_nan = is_exp_a_ff &&!is_mant_a_zero;
    wire is_b_nan = is_exp_b_ff &&!is_mant_b_zero;
    
    wire is_nan_result = is_a_nan |

| is_b_nan |
| (is_a_inf && is_b_inf && (sign_a!= sign_b));
    wire is_inf_result = is_a_inf |

| is_b_inf;
    wire is_special_result = is_nan_result |

| is_inf_result |
| is_a_zero |
| is_b_zero;

    // Output for "Quiet NaN"
    localparam [31:0] QNAN = 32'h7FC00000; // Sign=0, Exp=FF, Mant=100...0

    // Internal signals for alignment
    reg [7:0] exp_diff;
    reg [7:0] exp_larger;
    reg [26:0] mant_larger, mant_smaller;
    reg sign_larger, sign_smaller, sign_result;
    reg effective_op; // 0 for ADD, 1 for SUB
    
    // Internal signals for addition
    reg [27:0] mant_smaller_shifted; // 1-bit wider for sticky-bit OR-reduction
    reg [27:0] sum_mant_unnorm; // 27 bits + 1 overflow bit

    // Internal signals for normalization
    wire [26:0] sum_mant_abs;
    wire [4:0] lzc_out; // Leading Zero Counter output (max 27 zeros)
    reg [7:0] exp_normalized;
    reg [26:0] mant_normalized;
    reg [27:0] mant_to_normalize;

    // Internal signals for rounding
    wire lsb, guard, round, sticky;
    wire round_up;
    reg [23:0] mant_rounded; // 1 (implicit) + 23 (explicit)
    reg [7:0] exp_rounded;
    reg overflow_from_round;

    // Internal signals for final packing
    reg [7:0] exp_final;
    reg [22:0] mant_final;
    reg is_result_zero;
    
    // Instantiate Leading Zero Counter (for 27-bit mantissa)
    LeadingZeroCounter lzc_inst (
       .in(sum_mant_abs),
       .out(lzc_out)
    );

    always @(*) begin
        // Default exception flags
        overflow = 1'b0;
        underflow = 1'b0;
        inexact = 1'b0;
        is_result_zero = 1'b0;

        //============================================================
        // STAGE 1.A: SPECIAL CASE "BYPASS" DATAPATH
        //============================================================
        if (is_special_result) begin
            if (is_nan_result) begin
                sum = QNAN;
            end 
            else if (is_inf_result) begin
                // Inf + Inf = Inf
                // A + Inf = Inf
                // Inf - A = Inf
                sum = {sign_a & ~is_b_inf | sign_b & ~is_a_inf, 8'hFF, 23'h0};
            end
            else if (is_a_zero && is_b_zero) begin
                // 0 + 0 = 0
                // 0 - 0 = 0
                // -0 + -0 = -0
                sum = {(sign_a & sign_b), 8'h00, 23'h0};
            end
            else if (is_a_zero) begin
                // 0 + B = B
                sum = B;
            end
            else if (is_b_zero) begin
                // A + 0 = A
                sum = A;
            end
            else begin
                // Should be unreachable
                sum = QNAN;
            end
        end 
        else begin
            //========================================================
            // STAGE 1.B: OPERAND UNPACKING (for Normal/Subnormal)
            //========================================================

            // Unpack A
            if (is_a_subnormal) begin
                exp_a_internal = 8'd1;
                mant_a_internal = {1'b0, mant_a, 3'b0}; // Implicit '0'
            end else begin
                exp_a_internal = exp_a;
                mant_a_internal = {1'b1, mant_a, 3'b0}; // Implicit '1'
            end

            // Unpack B
            if (is_b_subnormal) begin
                exp_b_internal = 8'd1;
                mant_b_internal = {1'b0, mant_b, 3'b0}; // Implicit '0'
            end else begin
                exp_b_internal = exp_b;
                mant_b_internal = {1'b1, mant_b, 3'b0}; // Implicit '1'
            end

            //========================================================
            // STAGE 2: ALIGNMENT AND GRS BIT GENERATION
            //========================================================

            if (exp_a_internal > exp_b_internal) begin
                exp_diff = exp_a_internal - exp_b_internal;
                exp_larger = exp_a_internal;
                mant_larger = mant_a_internal;
                mant_smaller = mant_b_internal;
                sign_larger = sign_a;
                sign_smaller = sign_b;
            end else begin
                exp_diff = exp_b_internal - exp_a_internal;
                exp_larger = exp_b_internal;
                mant_larger = mant_b_internal;
                mant_smaller = mant_a_internal;
                sign_larger = sign_b;
                sign_smaller = sign_a;
            end
            
            sign_result = sign_larger; // Preliminary sign
            effective_op = sign_a ^ sign_b; // 0=ADD, 1=SUB

            // Perform alignment shift with GRS bit generation
            // This is complex. We need to catch all shifted-out bits.
            // A shift > 27 will result in 0 + sticky bit.
            if (exp_diff == 8'd0) begin
                mant_smaller_shifted = {mant_smaller, 1'b0}; // 28-bits
            end
            else if (exp_diff > 27) begin
                // Shift is so large, only sticky bit might remain
                wire sticky_bit = (mant_smaller!= 27'b0);
                mant_smaller_shifted = {27'b0, sticky_bit};
            end 
            else begin
                // Use a dynamic shifter and OR-reduction for sticky
                // This is often a bottleneck and is implemented as a barrel shifter in ASICs
                // `mant_smaller` is 27 bits [26:0]
                // `sticky_mask` will be 1s for all bits below the Round bit
                // Example: exp_diff = 4. G=, R=, S=|[1:0]
                reg [26:0] shifted_out_bits;
                reg [26:0] sticky_mask;
                
                shifted_out_bits = (mant_smaller << (27 - exp_diff));
                sticky_mask = (27'hFFFFFFF >> (exp_diff - 1'b1));
                
                wire guard_bit = shifted_out_bits;
                wire round_bit = (exp_diff == 1)? 1'b0 : shifted_out_bits;
                wire sticky_bit = (exp_diff < 3)? 1'b0 : |(shifted_out_bits[24:0]);

                mant_smaller_shifted = { (mant_smaller >> exp_diff), guard_bit, round_bit, sticky_bit };
            end
            
            //========================================================
            // STAGE 3: WIDE MANTISSA ADD/SUBTRACT
            //========================================================
            
            // Use 28-bit adder (27 mant+GRS + 1 overflow)
            // Add an extra 0 at the MSB for alignment
            reg [27:0] mant_larger_ext;
            reg [27:0] mant_smaller_eff;
            
            mant_larger_ext = {1'b0, mant_larger};

            if (effective_op == 1'b1) begin // SUBTRACTION
                // Perform 2's complement subtraction
                mant_smaller_eff = ~(mant_smaller_shifted) + 1'b1;
            end else begin // ADDITION
                mant_smaller_eff = mant_smaller_shifted;
            end

            sum_mant_unnorm = mant_larger_ext + mant_smaller_eff;

            // Handle subtraction result (sign-magnitude conversion)
            if (effective_op == 1'b1 && sum_mant_unnorm == 1'b0) begin
                // Result was negative (A-B where B>A), and sum is in 2's complement
                // We must negate it to get the sign-magnitude result
                mant_to_normalize = ~(sum_mant_unnorm) + 1'b1;
                sign_result = ~sign_larger; // Flip the sign
            end else begin
                mant_to_normalize = sum_mant_unnorm;
                // sign_result remains sign_larger
            end

            //========================================================
            // STAGE 4: POST-COMPUTATION NORMALIZATION
            //========================================================
            
            // Check for zero result
            if (mant_to_normalize[26:0] == 27'b0) begin
                is_result_zero = 1'b1;
                exp_normalized = 8'h00;
                mant_normalized = 27'h0;
            end
            
            // Path A: Overflow (from addition)
            else if (mant_to_normalize) begin 
                // e.g., 1.xxx + 1.xxx = 10.xxx
                // Shift right by 1, increment exponent
                mant_normalized = mant_to_normalize[27:1]; // 1-bit right shift
                exp_normalized = exp_larger + 1;
            end
            
            // Path B: Already Normalized
            else if (mant_to_normalize) begin
                // e.g., 1.xxx - 0.1xx = 1.xxx
                // No shift needed
                mant_normalized = mant_to_normalize[26:0];
                exp_normalized = exp_larger;
            end
            
            // Path C: Cancellation (from subtraction)
            else begin
                // e.g., 1.001 - 1.000 = 0.001
                // Find LZC and shift left
                sum_mant_abs = mant_to_normalize[26:0];
                
                // lzc_out is from the instantiated module
                if (exp_larger > lzc_out) begin
                    // Normal left shift
                    mant_normalized = mant_to_normalize[26:0] << lzc_out;
                    exp_normalized = exp_larger - lzc_out;
                end else begin
                    // Shift would cause underflow. Clamp to subnormal.
                    // This is part of the underflow handling
                    mant_normalized = mant_to_normalize[26:0] << (exp_larger - 1);
                    exp_normalized = 8'd0; // Will be handled as subnormal
                    underflow = 1'b1;
                end
            end

            //========================================================
            // STAGE 5: IEEE-754 ROUNDING
            //========================================================
            
            // Extract L, G, R, S bits from the normalized 27-bit mantissa
            //  = Implicit bit, [25:3] = 23-bit Mantissa
            //  = Guard (G),  = Round (R),  = Sticky (S)
            lsb = mant_normalized;    // LSB of the final 23-bit mantissa
            guard = mant_normalized;  // Guard bit
            round = mant_normalized;  // Round bit
            sticky = mant_normalized; // Sticky bit

            inexact = guard | round | sticky;

            // Round to Nearest, Ties to Even
            // round_up = G & (R | S | L)
            round_up = guard & (round | sticky | lsb);

            // Add the rounding bit. This can overflow!
            {overflow_from_round, mant_rounded} = mant_normalized[26:3] + round_up;
            exp_rounded = exp_normalized;

            //========================================================
            // STAGE 6: FINALIZATION AND EXCEPTION HANDLING
            //========================================================
            
            // Handle post-rounding overflow (e.g., 1.11...1 + 1 = 10.00...0)
            if (overflow_from_round) begin
                exp_final = exp_rounded + 1;
                mant_final = 23'h000000;
            end else begin
                exp_final = exp_rounded;
                mant_final = mant_rounded[22:0]; // Discard the implicit bit
            end

            // Final check for Overflow (to Inf)
            if (exp_final >= 8'hFF) begin
                overflow = 1'b1;
                inexact = 1'b1; // Overflow is an inexact result
                sum = {sign_result, 8'hFF, 23'h0}; // Set to Infinity
            end
            
            // Final check for Underflow (to Subnormal or Zero)
            else if (exp_final < 8'd1) begin
                underflow = 1'b1;
                inexact = 1'b1;
                // Result must be represented as a subnormal number or zero
                // We must right-shift the *normalized* mantissa to denormalize it
                // shift_amount = 1 - exp_final
                reg [4:0] subnormal_shift;
                subnormal_shift = 1 - exp_final;
                
                // Re-create the 24-bit normalized mantissa
                reg [23:0] mant_to_denorm;
                mant_to_denorm = mant_rounded; // This is {1'b1, mant_final}
                
                // Re-calculate GRS bits for this *new* shift
                reg [23:0] shifted_out_bits_sub;
                shifted_out_bits_sub = (mant_to_denorm << (24 - subnormal_shift));
                
                wire guard_s = shifted_out_bits_sub;
                wire round_s = (subnormal_shift == 1)? 1'b0 : shifted_out_bits_sub;
                wire sticky_s = (subnormal_shift < 3)? 1'b0 : |(shifted_out_bits_sub[21:0]);
                
                // Re-round the subnormal mantissa
                reg [23:0] mant_subnormal_shifted;
                mant_subnormal_shifted = (mant_to_denorm >> subnormal_shift);
                
                wire lsb_s = mant_subnormal_shifted; // LSB is now bit 0
                wire round_up_s = guard_s & (round_s | sticky_s | lsb_s);
                
                mant_final = (mant_subnormal_shifted + round_up_s)[22:0];
                
                sum = {sign_result, 8'h00, mant_final};
            end
            
            // Final check for Zero
            else if (is_result_zero) begin
                sum = {sign_result, 8'h00, 23'h0};
            end
            
            // Normal case: Assemble the final normalized number
            else begin
                sum = {sign_result, exp_final, mant_final};
            end
        end
    end

endmodule
