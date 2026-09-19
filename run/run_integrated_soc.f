// =============================================================================
// run_integrated_soc.f  —  VCS compile/elaborate/simulate file-list
//                          for the integrated SoC (soc_top) testbench.
//
// This file list compiles the UART RTL hierarchy only:
//   - UART sub-modules (leaf → top)
//   - Interconnect primitives and wrappers
//   - AXI4 → AXI4-Lite bridge
//   - SoC top-level (soc_top)
//   - SoC-level testbench (tb_soc_top.sv)
//
// Usage (run from the project_dir/run/ directory):
// ----------------------------------------------------------------------------
//   Compile + simulate (text output only):
//     vcs -full64 -sverilog -f run_integrated_soc.f \
//         -o simv_soc && ./simv_soc
//
//   Compile + simulate with Verdi/FSDB waveform capture:
//     vcs -full64 -sverilog -kdb -lca -debug_access+all \
//         -f run_integrated_soc.f -o simv_soc \
//     && ./simv_soc -verdi
//
//   Open waveform after simulation:
//     verdi -ssf dump_soc.fsdb &
// =============================================================================

// ---------------------------------------------------------------------------
// Include search paths
// ---------------------------------------------------------------------------
+incdir+../rtl
+incdir+../rtl/uart
+incdir+../rtl/interconnect
+incdir+../tb

// ---------------------------------------------------------------------------
// Timescale unit  (must be first source file compiled)
// ---------------------------------------------------------------------------
../rtl/uart/timescale.v

// ===========================================================================
// UART sub-modules  (leaf → top)
// ===========================================================================

// Parity bit computation (leaf, no sub-instances)
../rtl/uart/uart_parity_bit_compute.v

// RX/TX FIFOs (leaf)
../rtl/uart/axi_internal_fifo.v

// UART receiver FSM
../rtl/uart/uart_receiver.v

// UART transmitter FSM (instantiates uart_parity_bit_compute)
../rtl/uart/uart_transmitter.v

// UART controller (instantiates receiver + transmitter)
../rtl/uart/uart_controller.v

// AXI-UART top (instantiates controller + two FIFOs)
../rtl/uart/axi_uart_top.v

// ===========================================================================
// Interconnect primitives and wrappers
// ===========================================================================

// Priority encoder (instantiated inside axi_interconnect)
../rtl/interconnect/priority_encoder.v

// Round-robin arbiter (instantiated inside axi_interconnect)
../rtl/interconnect/arbiter.v

// AXI4 interconnect core (Alex Forencich, parameterised NxM crossbar)
../rtl/interconnect/axi_interconnect.v

// 2x10 wrapper (sets S_COUNT=2, M_COUNT=10, exposes flat port list)
../rtl/interconnect/axi_interconnect_wrap_2x10.v

// ===========================================================================
// Protocol bridge
// ===========================================================================

// AXI4-full → AXI4-Lite combinational bridge (used for UART)
../rtl/interconnect/axi_to_axilite_bridge.v

// ===========================================================================
// SoC top-level
// ===========================================================================
../rtl/interconnect/soc_top.v

// ===========================================================================
// Testbench
// ===========================================================================
../tb/tb_soc_top.sv
