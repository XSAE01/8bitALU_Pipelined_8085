# Pipelined 8085 ALU — FPGA timing and utilization

The pipeline with accumulator forwarding met a **25 MHz** clock constraint on a Lattice iCE40 HX8K in the CT256 package. At that clock, a continuous stream of valid requests produces **25 million results per second** after the initial fill cycle. The clock rate comes from static timing analysis of a routed design. Functional simulation checked the one-result-per-clock behavior separately.

## Timing

| Post-route metric | Result |
| --- | ---: |
| Target period | 40.00 ns |
| Longest register-to-register path | 12.75 ns |
| Setup slack at 25 MHz | +27.25 ns |
| Estimated maximum internal clock frequency | 78.41 MHz |

The critical path starts at `use_acc_reg`, passes through operand selection and the ALU, and ends at the sign flag register (`flags_out[4]`). nextpnr attributes 5.05 ns to logic and 7.71 ns to routing, rounded separately.

The device, 25 MHz target and placement seed 1 are reference choices. nextpnr assigned the package pins automatically. The estimate covers the internal clock domain for this placement. Board-level timing requires the board pinout and external I/O timing constraints.

## Resources

| Resource | Used | Available |
| --- | ---: | ---: |
| Packed logic cells | 181 (2.36%) | 7,680 |
| Package I/Os | 47 | 206 |
| Global buffers | 1 | 8 |
| Block RAMs | 0 | 32 |
| PLLs | 0 | 2 |

Before packing, Yosys reported 146 four-input LUTs, 37 flip-flops and 7 carry primitives. Logic cells can contain several primitives, so the packed count is the relevant device utilization figure.

## Reproduce the measurement

From the repository root, use the YoWASP builds of Yosys 0.71 (`yowasp-yosys==0.71.0.0.post1285`) and nextpnr 0.11.1 (`yowasp-nextpnr-ice40==0.11.1.0.post826`). The commands below synthesize the streaming top module and write the netlist, placement, timing and utilization reports into `build/ice40`.

```sh
mkdir -p build/ice40
yowasp-yosys -Q -l build/ice40/synthesis.log \
  -p 'read_verilog rtl/*.v; synth_ice40 -top alu_8085_pipeline -json build/ice40/pipeline.json; stat'
yowasp-nextpnr-ice40 --hx8k --package ct256 --freq 25 --seed 1 \
  --pcf-allow-unconstrained --json build/ice40/pipeline.json \
  --asc build/ice40/pipeline.asc --report build/ice40/timing.json \
  --log build/ice40/route.log
```

Use the final clock frequency in `route.log` or the `fmax` field in `timing.json`. The log also includes an intermediate placement estimate before routing finishes.
