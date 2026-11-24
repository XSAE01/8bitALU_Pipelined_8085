# 8-bit ALU of the 8085 — Phase 1 report

Phase 1 implements the arithmetic and logic unit (ALU) as a Verilog subsystem. For each operation, an external circuit supplies two 8-bit operands and a 5-bit operation code. The subsystem captures these inputs, computes the result and status flags, and signals when the outputs can be read. Its interface begins with a decoded ALU operation, so instruction fetch and memory access sit outside this phase.

## Project workflow

| Stage | Design work | How to check it |
| --- | --- | --- |
| 1. Build the arithmetic cell | Implement a one-bit full adder that produces a sum and a carry. | Check the sum and carry for all eight combinations of A, B and carry-in. |
| 2. Assemble a four-bit slice | Add AND, OR and XOR to each cell. Connect four cells in a carry chain with a shared operation selector. | Sweep the 2,048 combinations of selector, operands and carry-in. |
| 3. Complete the eight-bit datapath | Connect two four-bit slices, decode the operation, select the result and generate the flags. | Compare the combinational ALU against a behavioral reference model across all 32 operation codes, both operand bytes and both carry inputs (4,194,304 cases). |
| 4. Integrate the clocked subsystem | Add the accumulator, temporary operand register, opcode register, flag register and six-state controller. | Drive 2,097,152 operation-code and operand combinations through the controller. Check register write-back, completion and operations that depend on flags from a previous transaction. |

## Datapath design

![Phase 1 subsystem showing the registers, controller and ALU](../docs/alu_8085_top.svg)

The arithmetic path uses eight copies of the same one-bit cell. Each cell selects the full-adder sum or one of three logic results. Carry ripples from the least significant bit to the most significant bit. The carry leaving bit 3 has two uses: it feeds the upper slice and supplies the auxiliary carry (AC) for arithmetic. The carry leaving bit 7 supplies the carry flag (CY) for addition. [Bit-slice diagram](../docs/alu_4bit_slice.svg)

| Operation group | Implementation |
| --- | --- |
| ADD, ADC, SUB, SBB, CMP | All use the adder. SUB and CMP compute `A + ~B + 1`. SBB uses the inverse of the incoming CY as its carry-in. For these subtract operations, the inverse of the final carry indicates a borrow. CMP writes only the flags. |
| ANA, ORA, XRA, CMA | The slice selects AND, OR or XOR. CMA complements A by XORing it with `0xFF` and preserves every flag. |
| INR, DCR | The adder increments or decrements A and preserves the incoming CY. |
| RLC, RRC, RAL, RAR, STC, CMC | A separate rotate unit moves the outgoing bit into CY. Circular rotates also wrap that bit into A, while through-carry rotates insert the previous CY. STC sets CY and CMC complements it. |
| DAA | After packed-decimal addition, the adder applies a correction. The low correction is `0x06` if the low nibble exceeds nine or AC is set. The high correction is `0x60` if A exceeds `0x99` or CY is set. Both corrections can apply together. |
| DADL, DADH | A 16-bit addition uses two transactions. The caller saves the low-byte sum from DADL and supplies the high bytes for DADH. The flag register carries CY between them. Only CY changes in either pass. |

The flag register exposes sign (S), zero (Z), auxiliary carry (AC), even parity (P) and carry (CY). Each operation selects which flags to update. For example, ANA sets AC and clears CY, while ORA and XRA clear both. The 12 reserved operation codes pass through A and the incoming flags. [Operation encodings and flag effects](../README.md#supported-operations)

## One operation through the controller

The controller samples inputs on rising clock edges. An active-high synchronous reset returns it to idle with A at `0x00`, Z and P set, and the other flags clear.

| Current state | What happens |
| --- | --- |
| S0 · Idle | A rising edge with `start` high accepts the request. |
| S1 · Load A | The next rising edge loads `data_in_a` into the accumulator. |
| S2 · Load B | The next rising edge loads `data_in_b` into the temporary register. |
| S3 · Load operation | The next rising edge captures `alu_op_in`. The combinational ALU now has all three registered inputs. |
| S4 · Execute | On the edge into S5, the flag register captures the selected flags and the accumulator captures the result. CMP suppresses the accumulator write. |
| S5 · Done | `done` is high for one cycle. The caller can read `acc_out` and `flags_out` before the controller returns to idle. |

For example, with A = `0x0F`, B = `0x01` and ADD selected, the low slice computes `0xF + 0x1` and passes a carry to the high slice. At `done`, the accumulator holds `0x10`. AC is set because the sum crossed the nibble boundary. CY is clear because it fits in eight bits. S, Z and P are all clear, giving `flags_out = 5'b00100` in the order `{S, Z, AC, P, CY}`.

## Running the simulation

The testbenches follow the same order as the design workflow. The eight-bit and top-level benches use a shared reference model that calculates expected results with Verilog arithmetic. The top-level bench also chains ADD with DAA for all 10,000 pairs of two-digit packed-decimal values and checks 20,005 two-pass DAD additions. [Reference model](../tb/alu_ref_model.vh) · [Integration testbench](../tb/tb_alu_8085_top.v)

With Icarus Verilog installed, run the integration bench from the project root. The include path makes the reference model available during compilation.

```sh
iverilog -I tb -s tb_alu_8085_top -o tb_alu_8085_top.vvp rtl/*.v tb/tb_alu_8085_top.v
vvp tb_alu_8085_top.vvp
```

Read the final testbench summary for the pass or fail result. The project README gives the commands for running each lower-level bench independently. [Simulation instructions](../README.md#how-to-simulate)
