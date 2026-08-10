# Pipelined Unsigned Multiplier

## Overview

I implemented two versions of an unsigned multiplier in SystemVerilog and compared their FPGA resource usage and timing in Vivado.
The first version is a baseline registered multiplier that uses the '*' operator directly.
The second version splits each operand into upper and lower halves, calculates four partial products, registers them, and then shifts and adds the partial products to calculate the final result.
The goal of the project was to understand how pipelining affects latency, throughput, FPGA resource usage, and timing.

## Target

- FPGA: Xilinx Artix-7
- Device: 'xc7a35tcpg236-1'
- Board: Basys 3
- Tool: Vivado
- RTL: SystemVerilog
- Clock constraint: 100 MHz

## Project Structure

01_pipelined_multiplier
├── rtl
│   ├── multiplier_v1_registered.sv
│   └── multiplier_v2_pipelined.sv
├── tb
│   ├── tb_multiplier_v1_registered.sv
│   └── tb_multiplier_v2_pipelined.sv
├── constraints
│   └── timing.xdc
├── reports
└── README.md

## Version 1

V1 registers the input operands and then performs the full multiplication before registering the output.

op1, op2
   |
   v
Input Registers
   |
   v
WIDTH x WIDTH Multiply
   |
   v
Output Register
   |
   v
product

### Pipeline

- Stage 0: Input registers
- Stage 1: Output register

The design can accept a new input every clock cycle after the pipeline starts.

## Version 2

V2 splits each operand into two halves.

For an 8-bit input:

op1 = op1_hi | op1_lo
op2 = op2_hi | op2_lo

Four partial products are calculated:

p0 = op1_lo * op2_lo
p1 = op1_hi * op2_lo
p2 = op1_lo * op2_hi
p3 = op1_hi * op2_hi

The final product is calculated using:

p0
+ (p1 << HALF)
+ (p2 << HALF)
+ (p3 << (2 * HALF))

### Pipeline

op1, op2
   |
   v
Input Registers
   |
   v
Split Operands
   |
   v
Partial Product Generation
   |
   v
Partial Product Registers
   |
   v
Shift and Add
   |
   v
Output Register
   |
   v
product

- Stage 0: Input registers
- Stage 1: Partial product registers
- Stage 2: Output register

## Valid Signal

The valid signal moves through the pipeline with the data.

For V2:

in_valid
   |
   v
valid_input_reg
   |
   v
valid_partial_reg
   |
   v
out_valid

This also allows bubbles to move through the pipeline correctly.

## Verification

Both versions use self-checking SystemVerilog testbenches.

The testbenches include:

- directed test cases
- maximum input values
- pipeline bubble testing
- valid signal checking
- random test cases
- automatic PASS/FAIL checking

The expected multiplication result is pipelined inside the testbench so that it stays aligned with the DUT output.

## FPGA Results

Both versions were implemented using the same 100 MHz clock constraint.

| Resource      |     V1    |     V2    | 
|---------------|----------:|----------:|
| LUTs          |     71    |     78    |
| Flip-Flops    |     34    |     67    | 
| DSPs          |     0     |     0     | 
| BRAM          |     0     |     0     |
| WNS @ 100 MHz | +3.193 ns | +5.811 ns |

## What I Observed

V2 uses more flip-flops because of the additional pipeline stage.

At 'WIDTH = 8', I expected the V2 flip-flop count to be:

Input registers:
8 + 8 + 1 valid = 17

Partial product registers:
4 * 8 + 1 valid = 33

Output registers:
16 + 1 valid = 17

Total:
17 + 33 + 17 = 67 flip-flops

Vivado reported exactly 67 flip-flops.

The pipelined version also had better timing margin at 100 MHz.

V1 WNS = +3.193 ns
V2 WNS = +5.811 ns

This showed me the main trade-off of pipelining:

More registers and slightly more logic
                vs
Shorter critical path and better timing

Both versions can accept a new multiplication every clock cycle once the pipeline is running.

## What I Learned

This project helped me understand:

- combinational and sequential RTL
- 'always_comb' and 'always_ff'
- parameterized SystemVerilog
- partial-product multiplication
- pipeline stages
- latency vs throughput
- pipeline bubbles
- valid signal propagation
- self-checking testbenches
- FPGA resource utilization
- timing constraints
- timing slack
- area vs timing trade-offs

## Future Improvements

Possible improvements include:

- signed multiplication
- DSP48-based implementation
- testing wider operand sizes
- Booth multiplication
- Wallace-tree partial-product reduction
