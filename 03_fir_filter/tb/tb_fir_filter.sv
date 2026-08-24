`timescale 1ns / 1ps

//===================================================================================================
// Project : FPGA Projects
// Module  : Testbench for 4-Tap FIR Filter
//
// Description:
//   Self-checking testbench for the signed 4-tap FIR filter.
//   The testbench maintains an independent reference sample history,
//   calculates the expected FIR output, pipelines the expected result,
//   and compares it with the DUT output.
//
// Verification Includes:
//   - Directed test cases
//   - Positive and negative samples
//   - Pipeline bubbles
//   - Consecutive bubbles
//   - Randomized signed samples
//   - Valid signal alignment
//   - Automatic PASS/FAIL checking
//
//===================================================================================================

module tb_fir_filter;


//--------------------------------------------------
// Parameters
//--------------------------------------------------

parameter WIDTH       = 8;
parameter COEFF_WIDTH = 8;

parameter logic signed [COEFF_WIDTH-1:0] H0 =  1;
parameter logic signed [COEFF_WIDTH-1:0] H1 = -2;
parameter logic signed [COEFF_WIDTH-1:0] H2 =  3;
parameter logic signed [COEFF_WIDTH-1:0] H3 = -1;

localparam OUT_WIDTH = WIDTH + COEFF_WIDTH + 2;


//--------------------------------------------------
// DUT Signals
//--------------------------------------------------

logic clk;
logic rst_n;
logic in_valid;

logic signed [WIDTH-1:0] sample_in;

logic signed [OUT_WIDTH-1:0] sample_out;
logic out_valid;


//--------------------------------------------------
// Reference Sample History
//--------------------------------------------------

logic signed [WIDTH-1:0] ref_x0;
logic signed [WIDTH-1:0] ref_x1;
logic signed [WIDTH-1:0] ref_x2;


//--------------------------------------------------
// Expected Output Pipeline
//--------------------------------------------------

logic signed [OUT_WIDTH-1:0] expected0;
logic signed [OUT_WIDTH-1:0] expected1;
logic signed [OUT_WIDTH-1:0] expected2;
logic signed [OUT_WIDTH-1:0] expected_out;

logic expected_valid0;
logic expected_valid1;
logic expected_valid2;
logic expected_out_valid;


//--------------------------------------------------
// Test Statistics
//--------------------------------------------------

integer check_count;
integer error_count;


//--------------------------------------------------
// DUT
//--------------------------------------------------

fir_filter #(
    .WIDTH       (WIDTH),
    .COEFF_WIDTH (COEFF_WIDTH),
    .H0          (H0),
    .H1          (H1),
    .H2          (H2),
    .H3          (H3)
) dut (
    .clk        (clk),
    .rst_n      (rst_n),
    .in_valid   (in_valid),
    .sample_in  (sample_in),
    .sample_out (sample_out),
    .out_valid  (out_valid)
);


//--------------------------------------------------
// Clock Generation
//
// 10 ns period = 100 MHz
//--------------------------------------------------

initial begin
    clk = 1'b0;

    forever #5 clk = ~clk;
end


//--------------------------------------------------
// Send Valid Sample
//--------------------------------------------------

task automatic send_sample(
    input logic signed [WIDTH-1:0] sample
);
begin
    @(negedge clk);

    sample_in = sample;
    in_valid  = 1'b1;
end
endtask


//--------------------------------------------------
// Send Pipeline Bubble
//--------------------------------------------------

task automatic send_bubble;
begin
    @(negedge clk);

    sample_in = '0;
    in_valid  = 1'b0;
end
endtask


//----------------------------------------------------------------------------------------------------
// Reference FIR Model
//
// Expected FIR equation:
//
// y[n] = H0*x[n]
//      + H1*x[n-1]
//      + H2*x[n-2]
//      + H3*x[n-3]
//
// The reference model does not reproduce the DUT adder-tree architecture. It directly calculates
// the expected mathematical result.
//----------------------------------------------------------------------------------------------------

always_ff @(posedge clk) begin

    if (!rst_n) begin

        ref_x0 <= '0;
        ref_x1 <= '0;
        ref_x2 <= '0;

        expected0   <= '0;
        expected1   <= '0;
        expected2   <= '0;
        expected_out <= '0;

        expected_valid0   <= 1'b0;
        expected_valid1   <= 1'b0;
        expected_valid2   <= 1'b0;
        expected_out_valid <= 1'b0;

    end
    else begin

        //--------------------------------------------------
        // Expected result pipeline
        //--------------------------------------------------

        expected1   <= expected0;
        expected2   <= expected1;
        expected_out <= expected2;

        expected_valid0    <= in_valid;
        expected_valid1    <= expected_valid0;
        expected_valid2    <= expected_valid1;
        expected_out_valid <= expected_valid2;


        //--------------------------------------------------
        // Calculate FIR result for new valid sample
        //--------------------------------------------------

        if (in_valid) begin

            expected0 <=
                  (sample_in * H0)
                + (ref_x0    * H1)
                + (ref_x1    * H2)
                + (ref_x2    * H3);


            //--------------------------------------------------
            // Update reference delay line
            //--------------------------------------------------

            ref_x2 <= ref_x1;
            ref_x1 <= ref_x0;
            ref_x0 <= sample_in;

        end

    end

end


//--------------------------------------------------------------------------------------------
// Output Checker
//
// Comparison is performed on the negative edge so DUT and reference registers have settled
// after the previous positive edge.
//--------------------------------------------------------------------------------------------

always @(negedge clk) begin

    if (rst_n) begin

        //--------------------------------------------------
        // Check valid alignment
        //--------------------------------------------------

        check_count = check_count + 1;

        if (out_valid !== expected_out_valid) begin

            error_count = error_count + 1;

            $display(
                "FAIL VALID @ %0t : actual=%0b expected=%0b",
                $time,
                out_valid,
                expected_out_valid
            );

        end


        //--------------------------------------------------
        // Check FIR output
        //--------------------------------------------------

        if (expected_out_valid) begin

            check_count = check_count + 1;

            if (sample_out !== expected_out) begin

                error_count = error_count + 1;

                $display(
                    "FAIL DATA @ %0t : actual=%0d expected=%0d",
                    $time,
                    sample_out,
                    expected_out
                );

            end
            else begin

                $display(
                    "PASS @ %0t : sample_out=%0d",
                    $time,
                    sample_out
                );

            end

        end

    end

end


//--------------------------------------------------
// Test Sequence
//--------------------------------------------------

initial begin

    check_count = 0;
    error_count = 0;

    rst_n     = 1'b0;
    in_valid  = 1'b0;
    sample_in = '0;


    //--------------------------------------------------
    // Reset
    //--------------------------------------------------

    repeat (3) @(negedge clk);

    rst_n = 1'b1;


    //--------------------------------------------------
    // Directed Tests
    //
    // Coefficients:
    //
    // H0 =  1
    // H1 = -2
    // H2 =  3
    // H3 = -1
    //
    // First expected outputs:
    //
    // input 2  ->  2
    // input 5  ->  1
    // input 8  ->  4
    // input 10 ->  7
    //--------------------------------------------------

    send_sample( 8'sd2);
    send_sample( 8'sd5);
    send_sample( 8'sd8);
    send_sample( 8'sd10);


    //--------------------------------------------------
    // Bubble
    //--------------------------------------------------

    send_bubble();


    //--------------------------------------------------
    // Negative and Positive Samples
    //--------------------------------------------------

    send_sample(-8'sd4);
    send_sample( 8'sd7);


    //--------------------------------------------------
    // Multiple Bubbles
    //--------------------------------------------------

    send_bubble();
    send_bubble();


    //--------------------------------------------------
    // Resume Valid Samples
    //--------------------------------------------------

    send_sample(-8'sd3);
    send_sample( 8'sd12);
    send_sample(-8'sd20);
    send_sample( 8'sd25);


    //--------------------------------------------------
    // Boundary Values
    //--------------------------------------------------

    send_sample( 8'sd127);
    send_sample(-8'sd128);


    //--------------------------------------------------
    // Random Signed Tests
    //--------------------------------------------------

    repeat (50) begin

        @(negedge clk);

        sample_in = $urandom_range(0, 255);
        in_valid  = 1'b1;

    end


    //--------------------------------------------------
    // Final Bubble
    //--------------------------------------------------

    send_bubble();


    //--------------------------------------------------
    // Flush Pipeline
    //--------------------------------------------------

    repeat (6) @(negedge clk);


    //--------------------------------------------------
    // Test Summary
    //--------------------------------------------------

    $display("");
    $display("==============================================");

    if (error_count == 0) begin

        $display(
            "FIR TEST PASSED : %0d checks, 0 errors",
            check_count
        );

    end
    else begin

        $display(
            "FIR TEST FAILED : %0d checks, %0d errors",
            check_count,
            error_count
        );

    end

    $display("==============================================");
    $display("");

    $finish;

end


endmodule
