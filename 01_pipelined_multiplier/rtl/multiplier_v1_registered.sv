//===================================================================================================
// Project : FPGA Projects
// Module  : Registered Unsigned Multiplier - V1
//
// Description:
//   Baseline unsigned multiplier. Inputs are registered first and the multiplication result
//   is captured in the output register.
//
// Pipeline Stages:
//   Stage 0 - Input registers
//   Stage 1 - Output register
//
//===================================================================================================

module multiplier_v1_registered #(
    parameter WIDTH = 8
)(
    input  logic clk,
    input  logic rst_n,
    input  logic in_valid,
    input  logic [WIDTH-1:0] op1,
    input  logic [WIDTH-1:0] op2,

    output logic [(2*WIDTH)-1:0] product,
    output logic out_valid
);


//--------------------------------------------------
// Input Registers
//--------------------------------------------------

logic [WIDTH-1:0] op1_reg;
logic [WIDTH-1:0] op2_reg;

logic valid_reg;


//--------------------------------------------------
// Register Inputs
//--------------------------------------------------

always_ff @(posedge clk) begin
    if (!rst_n) begin
        op1_reg   <= '0;
        op2_reg   <= '0;
        valid_reg <= 1'b0;
    end
    else begin
        op1_reg   <= op1;
        op2_reg   <= op2;
        valid_reg <= in_valid;
    end
end


//--------------------------------------------------
// Multiply Registered Inputs
//--------------------------------------------------

always_ff @(posedge clk) begin
    if (!rst_n) begin
        product   <= '0;
        out_valid <= 1'b0;
    end
    else begin
        product   <= op1_reg * op2_reg;
        out_valid <= valid_reg;
    end
end

endmodule
