//===================================================================================================
// Project : FPGA Projects
// Module  : 4-Tap Pipelined FIR Filter
//
// Description:
//   Parameterized signed 4-tap FIR filter.
//
//   y[n] = H0*x[n]
//        + H1*x[n-1]
//        + H2*x[n-2]
//        + H3*x[n-3]
//
// Pipeline Stages:
//   Stage 0 - Sample delay line
//   Stage 1 - Parallel multipliers
//   Stage 2 - Pairwise adders
//   Stage 3 - Final adder / output register
//
//===================================================================================================

module fir_filter #(
    parameter integer WIDTH       = 8,
    parameter integer COEFF_WIDTH = 8,

    parameter signed [COEFF_WIDTH-1:0] H0 =  1,
    parameter signed [COEFF_WIDTH-1:0] H1 = -2,
    parameter signed [COEFF_WIDTH-1:0] H2 =  3,
    parameter signed [COEFF_WIDTH-1:0] H3 = -1
)(
    input  logic clk,
    input  logic rst_n,
    input  logic in_valid,

    input  logic signed [WIDTH-1:0] sample_in,

    output logic signed [(WIDTH + COEFF_WIDTH + 2)-1:0] sample_out,
    output logic out_valid
);


//--------------------------------------------------
// Local Parameters
//--------------------------------------------------

localparam integer PRODUCT_WIDTH = WIDTH + COEFF_WIDTH;
localparam integer SUM_WIDTH     = PRODUCT_WIDTH + 1;


//--------------------------------------------------
// Stage 0 - Sample Delay Line
//--------------------------------------------------

logic signed [WIDTH-1:0] x0;
logic signed [WIDTH-1:0] x1;
logic signed [WIDTH-1:0] x2;
logic signed [WIDTH-1:0] x3;

logic s0_valid;


//--------------------------------------------------
// Stage 1 - Products
//--------------------------------------------------

logic signed [PRODUCT_WIDTH-1:0] product0;
logic signed [PRODUCT_WIDTH-1:0] product1;
logic signed [PRODUCT_WIDTH-1:0] product2;
logic signed [PRODUCT_WIDTH-1:0] product3;

logic s1_valid;


//--------------------------------------------------
// Stage 2 - Pairwise Sums
//--------------------------------------------------

logic signed [SUM_WIDTH-1:0] sum0;
logic signed [SUM_WIDTH-1:0] sum1;

logic s2_valid;


//--------------------------------------------------
// Stage 0 - Sample Delay Line
//--------------------------------------------------

always_ff @(posedge clk) begin
    if (!rst_n) begin
        x0       <= '0;
        x1       <= '0;
        x2       <= '0;
        x3       <= '0;
        s0_valid <= 1'b0;
    end
    else begin
        s0_valid <= in_valid;

        if (in_valid) begin
            x3 <= x2;
            x2 <= x1;
            x1 <= x0;
            x0 <= sample_in;
        end
    end
end


//--------------------------------------------------
// Stage 1 - Parallel Multipliers
//--------------------------------------------------

always_ff @(posedge clk) begin
    if (!rst_n) begin
        product0 <= '0;
        product1 <= '0;
        product2 <= '0;
        product3 <= '0;
        s1_valid <= 1'b0;
    end
    else begin
        s1_valid <= s0_valid;

        if (s0_valid) begin
            product0 <= x0 * H0;
            product1 <= x1 * H1;
            product2 <= x2 * H2;
            product3 <= x3 * H3;
        end
    end
end


//--------------------------------------------------
// Stage 2 - Pairwise Adders
//--------------------------------------------------

always_ff @(posedge clk) begin
    if (!rst_n) begin
        sum0     <= '0;
        sum1     <= '0;
        s2_valid <= 1'b0;
    end
    else begin
        s2_valid <= s1_valid;

        if (s1_valid) begin
            sum0 <= $signed({product0[PRODUCT_WIDTH-1], product0})
                  + $signed({product1[PRODUCT_WIDTH-1], product1});

            sum1 <= $signed({product2[PRODUCT_WIDTH-1], product2})
                  + $signed({product3[PRODUCT_WIDTH-1], product3});
        end
    end
end


//--------------------------------------------------
// Stage 3 - Final Adder
//--------------------------------------------------

always_ff @(posedge clk) begin
    if (!rst_n) begin
        sample_out <= '0;
        out_valid  <= 1'b0;
    end
    else begin
        out_valid <= s2_valid;

        if (s2_valid) begin
            sample_out <= $signed({sum0[SUM_WIDTH-1], sum0})
                        + $signed({sum1[SUM_WIDTH-1], sum1});
        end
    end
end


endmodule
