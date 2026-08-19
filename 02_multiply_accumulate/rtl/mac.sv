//===================================================================================================
// Project : FPGA Projects
// Module  : Parameterized Multiply-Accumulate (MAC) Unit
//
// Description:
//   Unsigned multiply-accumulate unit that reuses the registered multiplier from the
//   pipelined multiplier project. Valid multiplication results are added to a running
//   accumulator. The accumulator holds its value when no valid product is available.
//
// Operation:
//   acc = acc + (a * b)
//
// Architecture:
//   Stage 0 - Multiplier input registers
//   Stage 1 - Multiplier product register
//   Stage 2 - Accumulator register
//
//===================================================================================================

module mac #(
    parameter WIDTH     = 8,
    parameter ACC_WIDTH = 4 * WIDTH
)(
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic                     in_valid,

    input  logic [WIDTH-1:0]         a,
    input  logic [WIDTH-1:0]         b,

    output logic [ACC_WIDTH-1:0]     acc,
    output logic                     out_valid
);


//--------------------------------------------------
// Internal Signals
//--------------------------------------------------

logic [(2*WIDTH)-1:0] product;
logic                 product_valid;

logic [ACC_WIDTH-1:0] product_ext;


//----------------------------------------------------------------------------------------------------
// Registered Multiplier
//
// Reuses the registered unsigned multiplier from Project 01. 
// The multiplier registers the input operands and then registers the resulting product.
//----------------------------------------------------------------------------------------------------

multiplier_v1_registered #(
    .WIDTH(WIDTH)
) prodMul (
    .clk       (clk),
    .rst_n     (rst_n),
    .in_valid  (in_valid),
    .op1       (a),
    .op2       (b),
    .product   (product),
    .out_valid (product_valid)
);


//----------------------------------------------------------------------------------------------------
// Product Width Extension
//
// The multiplier produces a 2*WIDTH-bit result.
// Zero-extend the unsigned product to ACC_WIDTH before adding it to the accumulator.
//----------------------------------------------------------------------------------------------------

always_comb begin
    product_ext = '0;
    product_ext[(2*WIDTH)-1:0] = product;
end


//----------------------------------------------------------------------------------------------------
// Accumulator
//
// A valid product is added to the previous accumulator value.
//
// product_valid = 1 : accumulate product
// product_valid = 0 : hold accumulator
//
// out_valid is registered alongside the accumulator update so that it indicates when a 
// new accumulated result is available.
//----------------------------------------------------------------------------------------------------

always_ff @(posedge clk) begin

    if (!rst_n) begin
        acc       <= '0;
        out_valid <= 1'b0;
    end
    else begin

        if (product_valid) begin
            acc <= acc + product_ext;
        end

        out_valid <= product_valid;

    end

end

endmodule
