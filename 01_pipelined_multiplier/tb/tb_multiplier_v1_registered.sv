//==================================================
// Project : FPGA Projects
// Module  : Testbench for Multiplier V1
//
// Description:
//   Self-checking testbench for the registered
//   unsigned multiplier.
//
//==================================================

module tb_multiplier_v1_registered;

localparam WIDTH = 8;

//--------------------------------------------------
// Testbench Signals
//--------------------------------------------------

logic clk;
logic rst_n;
logic in_valid;

logic [WIDTH-1:0] op1;
logic [WIDTH-1:0] op2;

logic [(2*WIDTH)-1:0] product;
logic out_valid;

//--------------------------------------------------
// Expected Output Pipeline
//--------------------------------------------------

logic [(2*WIDTH)-1:0] expected_stage1;
logic [(2*WIDTH)-1:0] expected_stage2;

logic expected_valid_stage1;
logic expected_valid_stage2;

integer check_count;
integer error_count;

//--------------------------------------------------
// DUT
//--------------------------------------------------

multiplier_v1_registered #(
    .WIDTH(WIDTH)
) dut (
    .clk(clk),
    .rst_n(rst_n),
    .in_valid(in_valid),
    .op1(op1),
    .op2(op2),
    .product(product),
    .out_valid(out_valid)
);

//--------------------------------------------------
// Clock Generation
//--------------------------------------------------

initial begin
    clk = 1'b0;

    forever #5 clk = ~clk;
end

//--------------------------------------------------
// Apply Input
//--------------------------------------------------

task automatic apply_input(
    input logic [WIDTH-1:0] a,
    input logic [WIDTH-1:0] b
);
begin
    @(negedge clk);

    op1      = a;
    op2      = b;
    in_valid = 1'b1;
end
endtask

//--------------------------------------------------
// Insert Bubble
//--------------------------------------------------

task automatic apply_bubble;
begin
    @(negedge clk);

    op1      = '0;
    op2      = '0;
    in_valid = 1'b0;
end
endtask

//--------------------------------------------------
// Reference Model
//--------------------------------------------------

always_ff @(posedge clk) begin
    if (!rst_n) begin
        expected_stage1       <= '0;
        expected_stage2       <= '0;

        expected_valid_stage1 <= 1'b0;
        expected_valid_stage2 <= 1'b0;
    end
    else begin
        expected_stage1 <= op1 * op2;
        expected_stage2 <= expected_stage1;

        expected_valid_stage1 <= in_valid;
        expected_valid_stage2 <= expected_valid_stage1;
    end
end

//--------------------------------------------------
// Scoreboard
//--------------------------------------------------

always @(negedge clk) begin
    if (rst_n) begin

        check_count = check_count + 1;

        if (out_valid !== expected_valid_stage2) begin
            error_count = error_count + 1;

            $display(
                "FAIL VALID @ %0t : actual=%0b expected=%0b",
                $time,
                out_valid,
                expected_valid_stage2
            );
        end

        if (expected_valid_stage2) begin

            check_count = check_count + 1;

            if (product !== expected_stage2) begin
                error_count = error_count + 1;

                $display(
                    "FAIL DATA @ %0t : actual=%0d expected=%0d",
                    $time,
                    product,
                    expected_stage2
                );
            end
            else begin
                $display(
                    "PASS V1 @ %0t : product=%0d",
                    $time,
                    product
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

    rst_n    = 1'b0;
    in_valid = 1'b0;
    op1      = '0;
    op2      = '0;

    // Hold reset for two clock cycles
    repeat (2) @(negedge clk);

    rst_n = 1'b1;

    // Directed tests
    apply_input(8'd0,   8'd0);
    apply_input(8'd1,   8'd1);
    apply_input(8'd3,   8'd5);
    apply_input(8'd7,   8'd9);
    apply_input(8'd15,  8'd15);
    apply_input(8'd255, 8'd255);

    // Bubble test
    apply_input(8'd12, 8'd7);

    apply_bubble();

    apply_input(8'd25, 8'd4);

    // Random tests
    repeat (50) begin
        @(negedge clk);

        op1 = $urandom_range(
            0,
            (1 << WIDTH) - 1
        );

        op2 = $urandom_range(
            0,
            (1 << WIDTH) - 1
        );

        in_valid = 1'b1;
    end

    // Stop sending data
    apply_bubble();

    // Flush pipeline
    repeat (4) @(negedge clk);

    //--------------------------------------------------
    // Test Summary
    //--------------------------------------------------

    $display("");
    $display("======================================");

    if (error_count == 0) begin
        $display(
            "V1 TEST PASSED : %0d checks, 0 errors",
            check_count
        );
    end
    else begin
        $display(
            "V1 TEST FAILED : %0d checks, %0d errors",
            check_count,
            error_count
        );
    end

    $display("======================================");
    $display("");

    $finish;
end

endmodule
