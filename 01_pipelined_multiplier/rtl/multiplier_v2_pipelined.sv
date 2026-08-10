//====================================================================================================
// Project : FPGA Projects
// Module  : Pipelined Unsigned Multiplier - V2
//
// Description:
//   Parameterized unsigned multiplier that splits each operand into upper and lower halves.
//   Four partial products are calculated, registered, shifted and added to produce the final product.
//
// Pipeline Stages:
//   Stage 0 - Input registers
//   Stage 1 - Partial product registers
//   Stage 2 - Output register
//
// Note:
//   WIDTH should be an even number.
//
//====================================================================================================

module multiplier_v2_pipelined #(
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
// Local Parameters
//--------------------------------------------------

localparam HALF = WIDTH / 2;

//--------------------------------------------------
// Input Registers
//--------------------------------------------------

logic [WIDTH-1:0] op1_reg;
logic [WIDTH-1:0] op2_reg;

logic valid_input_reg;

//--------------------------------------------------
// Operand Split
//--------------------------------------------------

logic [HALF-1:0] op1_hi;
logic [HALF-1:0] op1_lo;

logic [HALF-1:0] op2_hi;
logic [HALF-1:0] op2_lo;

//--------------------------------------------------
// Partial Products
//--------------------------------------------------

logic [(2*HALF)-1:0] p0;
logic [(2*HALF)-1:0] p1;
logic [(2*HALF)-1:0] p2;
logic [(2*HALF)-1:0] p3;

//--------------------------------------------------
// Registered Partial Products
//--------------------------------------------------

logic [(2*HALF)-1:0] p0_reg;
logic [(2*HALF)-1:0] p1_reg;
logic [(2*HALF)-1:0] p2_reg;
logic [(2*HALF)-1:0] p3_reg;

logic valid_partial_reg;

//--------------------------------------------------
// Extended Partial Products
//--------------------------------------------------

logic [(2*WIDTH)-1:0] p0_ext;
logic [(2*WIDTH)-1:0] p1_ext;
logic [(2*WIDTH)-1:0] p2_ext;
logic [(2*WIDTH)-1:0] p3_ext;

//--------------------------------------------------
// Register Inputs
//--------------------------------------------------

always_ff @(posedge clk) begin
    if (!rst_n) begin
        op1_reg         <= '0;
        op2_reg         <= '0;
        valid_input_reg <= 1'b0;
    end
    else begin
        op1_reg         <= op1;
        op2_reg         <= op2;
        valid_input_reg <= in_valid;
    end
end

//--------------------------------------------------
// Split Operands
//--------------------------------------------------

assign op1_lo = op1_reg[HALF-1:0];
assign op1_hi = op1_reg[WIDTH-1:HALF];

assign op2_lo = op2_reg[HALF-1:0];
assign op2_hi = op2_reg[WIDTH-1:HALF];

//--------------------------------------------------
// Calculate Partial Products
//--------------------------------------------------

always_comb begin
    p0 = op1_lo * op2_lo;
    p1 = op1_hi * op2_lo;
    p2 = op1_lo * op2_hi;
    p3 = op1_hi * op2_hi;
end


//--------------------------------------------------
// Register Partial Products
//--------------------------------------------------

always_ff @(posedge clk) begin
    if (!rst_n) begin
        p0_reg            <= '0;
        p1_reg            <= '0;
        p2_reg            <= '0;
        p3_reg            <= '0;
        valid_partial_reg <= 1'b0;
    end
    else begin
        p0_reg            <= p0;
        p1_reg            <= p1;
        p2_reg            <= p2;
        p3_reg            <= p3;
        valid_partial_reg <= valid_input_reg;
    end
end

//--------------------------------------------------
// Extend Partial Products
//
// Extension is done before shifting so that bits
// are not lost during the shift operations.
//--------------------------------------------------

always_comb begin
    p0_ext = '0;
    p1_ext = '0;
    p2_ext = '0;
    p3_ext = '0;

    p0_ext[(2*HALF)-1:0] = p0_reg;
    p1_ext[(2*HALF)-1:0] = p1_reg;
    p2_ext[(2*HALF)-1:0] = p2_reg;
    p3_ext[(2*HALF)-1:0] = p3_reg;
end

//--------------------------------------------------
// Shift and Add Partial Products
//--------------------------------------------------

always_ff @(posedge clk) begin
    if (!rst_n) begin
        product   <= '0;
        out_valid <= 1'b0;
    end
    else begin
        product <= p0_ext
                 + (p1_ext << HALF)
                 + (p2_ext << HALF)
                 + (p3_ext << (2 * HALF));

        out_valid <= valid_partial_reg;
    end
end

endmodule
