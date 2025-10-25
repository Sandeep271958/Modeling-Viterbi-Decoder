module FPtAdder(
    input [31:0] A, B,
    output [31:0] sum);

    //A floating point field split as per IEEE754
    wire sign_a = A[31];
    wire [7:0] exp_a = A[30:23];
    wire [22:0] mant_a = A[22:0];

    //B floating point field split as per IEEE754
    wire sign_b = B[31];
    wire [7:0] exp_b = B[30:23];
    wire [22:0] mant_b = B[22:0];
    
    //internal registers
    reg [24:0] mant_a_full;
    reg [24:0] mant_b_full;

    reg [24:0] mant_a_full_c;
    reg [24:0] mant_b_full_c;

    reg [24:0] shifted_mant_a;
    reg [24:0] shifted_mant_b;
    reg [25:0] sum_mant;

    reg [7:0] exp_diff;

    reg sign_c;
    reg [7:0] exp_c;
    reg [22:0] mant_c;
    //C floating point - to store the results of exp and final mant
    always@(*) 
        begin

            // Add the implicit '1' for normalized numbers. Using 25 bits for guard/overflow.
            mant_a_full = {1'b1, mant_a, 1'b0};
            mant_b_full = {1'b1, mant_b, 1'b0};

            
            if(exp_a > exp_b)
                begin
                    exp_c = exp_a;
                    exp_diff = exp_a - exp_b;
                    shifted_mant_b = mant_b_full >> exp_diff;
                    //sum_mant = mant_a_full + shifted_mant_b;
                    mant_a_full_c = mant_a_full;
                    mant_b_full_c = shifted_mant_b;
                    

                end

            else if(exp_b > exp_a)
                begin
                    exp_c = exp_b;
                    exp_diff = exp_b - exp_a;
                    shifted_mant_a = mant_a_full >> exp_diff;
                    //sum_mant = mant_b_full + shifted_mant_a;
                    mant_a_full_c = shifted_mant_a;
                    mant_b_full_c = mant_b_full;

                end

            else
                begin
                    exp_c = exp_a;
                    sign_c = sign_a;
                    exp_diff = 8'b0;
                    mant_a_full_c = mant_a_full;
                    mant_b_full_c = mant_b_full;

                end

            //mant_a_full_c = (exp_b > exp_a) ? shifted_mant_a : mant_a_full ;
            //mant_b_full_c = (exp_a >= exp_b) ? shifted_mant_b : mant_b_full ;


            if (sign_a == sign_b)
                //Addition (same sign)
                begin
                    sum_mant = mant_a_full_c + mant_b_full_c;
                    sign_c = sign_a;
                end
            else
                //Subtraction (opp sign)
                begin

                    if(mant_a_full_c >= mant_b_full_c)
                        begin
                            sum_mant = mant_a_full_c - mant_b_full_c;
                            sign_c = sign_a;
                        end

                    else
                        begin
                            sum_mant = mant_b_full_c - mant_a_full_c;
                            sign_c = sign_b;
                        end

                end



            //if in case over flow occured, shift the mant right and increment the exp by 1
            if (sum_mant[25]) 
                begin 
                    // Case 1: Overflow (from addition)
                    // We check the 26th bit.
                    exp_c = exp_c + 1;
                    mant_c = sum_mant[23:1]; // Shift right, take top 23 bits
                end 
            else if (sum_mant[24]) 
                begin 
                    // Case 2: Standard result (no overflow)
                    // The hidden bit is in position 24.
                    mant_c = sum_mant[22:0];
                end 
            else 
                begin
                    // !! CRITICAL FLAW !!
                    // Case 3: Result has leading zeros (from subtraction)
                    // You are missing the logic for left-shift normalization here.
                    // If sum_mant is 26'b0000_0101_... you must shift it left
                    // until the '1' is in position 24 and decrement exp_c
                    // for each shift.
                    //
                    // Without this, all your subtractions will be WRONG.
                    mant_c = sum_mant[22:0]; // This line is INCORRECT for this case
                end
    
        end

    assign sum = {sign_c, exp_c, mant_c};


endmodule