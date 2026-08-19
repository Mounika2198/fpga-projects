`timescale 1ns / 1ps

//===================================================================================================
// Project : FPGA Projects
// Module  : Testbench for Multiply-Accumulate Unit
//
// Description:
//   Self-checking testbench for the parameterized MAC.
//   Tests directed inputs, pipeline bubbles, accumulator hold behavior,
//   randomized inputs, reset behavior, and valid-signal alignment.
//
//===================================================================================================

module tb_mac;


//--------------------------------------------------
// Parameters
//--------------------------------------------------

parameter WIDTH     = 8;
parameter ACC_WIDTH = 4 * WIDTH;


//--------------------------------------------------
// DUT Signals
//--------------------------------------------------

logic clk;
logic rst_n;
logic in_valid;

logic [WIDTH-1:0] a;
logic [WIDTH-1:0] b;

logic [ACC_WIDTH-1:0] acc;
logic out_valid;


//--------------------------------------------------
// Reference Model Signals
//--------------------------------------------------

logic [(2*WIDTH)-1:0] expected_product_s0;
logic [(2*WIDTH)-1:0] expected_product_s1;

logic expected_valid_s0;
logic expected_valid_s1;

logic [ACC_WIDTH-1:0] expected_product_ext;
logic [ACC_WIDTH-1:0] expected_acc;

logic expected_out_valid;


//--------------------------------------------------
// Test Statistics
//--------------------------------------------------

integer check_count;
integer error_count;


//--------------------------------------------------
// DUT
//--------------------------------------------------

mac #(
    .WIDTH(WIDTH),
    .ACC_WIDTH(ACC_WIDTH)
) dut (
    .clk(clk),
    .rst_n(rst_n),
    .in_valid(in_valid),
    .a(a),
    .b(b),
    .acc(acc),
    .out_valid(out_valid)
);


//--------------------------------------------------
// Clock Generation
// 100 MHz clock -> 10 ns period
//--------------------------------------------------

initial begin
    clk = 1'b0;

    forever #5 clk = ~clk;
end


//--------------------------------------------------
// Apply Valid Input
//--------------------------------------------------

task automatic send_input(
    input logic [WIDTH-1:0] a_in,
    input logic [WIDTH-1:0] b_in
);
begin
    @(negedge clk);

    a        = a_in;
    b        = b_in;
    in_valid = 1'b1;
end
endtask


//--------------------------------------------------
// Insert Pipeline Bubble
//--------------------------------------------------

task automatic send_bubble;
begin
    @(negedge clk);

    a        = '0;
    b        = '0;
    in_valid = 1'b0;
end
endtask


//--------------------------------------------------
// Extend Expected Product
//
// The multiplier result is 2*WIDTH bits while the
// accumulator is ACC_WIDTH bits.
//--------------------------------------------------

always_comb begin
    expected_product_ext = '0;

    expected_product_ext[(2*WIDTH)-1:0]
        = expected_product_s1;
end


//--------------------------------------------------
// Reference Model
//
// This mirrors the actual DUT pipeline:
//
// Input
//   ↓
// expected_product_s0
//   ↓
// expected_product_s1
//   ↓
// expected_acc
//--------------------------------------------------

always_ff @(posedge clk) begin

    if (!rst_n) begin

        expected_product_s0 <= '0;
        expected_product_s1 <= '0;

        expected_valid_s0   <= 1'b0;
        expected_valid_s1   <= 1'b0;

        expected_acc        <= '0;
        expected_out_valid  <= 1'b0;

    end
    else begin

        // Mirror multiplier input stage
        expected_product_s0 <= a * b;
        expected_valid_s0   <= in_valid;


        // Mirror multiplier output stage
        expected_product_s1 <= expected_product_s0;
        expected_valid_s1   <= expected_valid_s0;


        // Mirror accumulator stage
        if (expected_valid_s1) begin
            expected_acc <=
                expected_acc + expected_product_ext;
        end


        // Valid signal corresponding to accumulator output
        expected_out_valid <= expected_valid_s1;

    end
end


//--------------------------------------------------
// Scoreboard
//
// Check on the negative edge so DUT and reference
// registers have settled after the positive edge.
//--------------------------------------------------

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
        // Check accumulator every cycle
        //
        // This also verifies that acc correctly holds
        // its value during pipeline bubbles.
        //--------------------------------------------------

        check_count = check_count + 1;

        if (acc !== expected_acc) begin

            error_count = error_count + 1;

            $display(
                "FAIL ACC @ %0t : actual=%0d expected=%0d",
                $time,
                acc,
                expected_acc
            );

        end
        else if (expected_out_valid) begin

            $display(
                "PASS @ %0t : acc=%0d",
                $time,
                acc
            );

        end

    end
end


//--------------------------------------------------
// Test Sequence
//--------------------------------------------------

initial begin

    check_count = 0;
    error_count = 0;

    rst_n    = 1'b0;
    in_valid = 1'b0;

    a = '0;
    b = '0;


    //--------------------------------------------------
    // Reset
    //--------------------------------------------------

    repeat (3) @(negedge clk);

    rst_n = 1'b1;


    //--------------------------------------------------
    // Directed Tests
    //
    // Expected accumulated values:
    //
    // 2*3  = 6       -> acc = 6
    // 4*5  = 20      -> acc = 26
    // bubble          -> acc = 26
    // 1*10 = 10      -> acc = 36
    //--------------------------------------------------

    send_input(8'd2, 8'd3);

    send_input(8'd4, 8'd5);

    send_bubble();

    send_input(8'd1, 8'd10);


    //--------------------------------------------------
    // More Directed Tests
    //--------------------------------------------------

    send_input(8'd0, 8'd100);     // adds 0

    send_input(8'd1, 8'd1);       // adds 1

    send_input(8'd15, 8'd15);     // adds 225

    send_input(8'd255, 8'd255);   // adds 65025


    //--------------------------------------------------
    // Multiple Bubbles
    //
    // Accumulator should hold its previous value.
    //--------------------------------------------------

    send_bubble();

    send_bubble();

    send_bubble();


    //--------------------------------------------------
    // Resume After Bubbles
    //--------------------------------------------------

    send_input(8'd10, 8'd10);

    send_input(8'd7, 8'd9);


    //--------------------------------------------------
    // Random Tests
    //--------------------------------------------------

    repeat (50) begin

        @(negedge clk);

        a = $urandom_range(
            0,
            (1 << WIDTH) - 1
        );

        b = $urandom_range(
            0,
            (1 << WIDTH) - 1
        );

        in_valid = 1'b1;

    end


    //--------------------------------------------------
    // Final Bubble
    //--------------------------------------------------

    send_bubble();


    //--------------------------------------------------
    // Flush Pipeline
    //
    // Allow the last operations already in flight
    // to reach the accumulator.
    //--------------------------------------------------

    repeat (5) @(negedge clk);


    //--------------------------------------------------
    // Test Summary
    //--------------------------------------------------

    $display("");
    $display("==============================================");

    if (error_count == 0) begin

        $display(
            "MAC TEST PASSED : %0d checks, 0 errors",
            check_count
        );

    end
    else begin

        $display(
            "MAC TEST FAILED : %0d checks, %0d errors",
            check_count,
            error_count
        );

    end

    $display("==============================================");
    $display("");

    $finish;

end


endmodule
