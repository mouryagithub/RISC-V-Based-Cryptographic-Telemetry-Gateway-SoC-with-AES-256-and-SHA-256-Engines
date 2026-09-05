// =============================================================================
// run_uart.f  —  VCS compile/elaborate/simulate file-list for AXI-UART TB
//
// Usage (from the run/ directory):
//   vcs -full64 -sverilog -f run_uart.f -o simv_uart && ./simv_uart
//
// Or with Verdi/FSDB support:
//   vcs -full64 -sverilog -kdb -lca -debug_access+all \
//       -f run_uart.f -o simv_uart && ./simv_uart -verdi
// =============================================================================

// ---------------------------------------------------------------------------
// Include search paths
// ---------------------------------------------------------------------------
+incdir+../rtl
+incdir+../rtl/uart
+incdir+../tb

// ---------------------------------------------------------------------------
// UART RTL source files  (compile sub-modules before the top)
// ---------------------------------------------------------------------------
// Timescale must come first so all subsequent modules inherit it
../rtl/uart/timescale.v

// Parity bit computation (leaf module, no sub-instances)
../rtl/uart/uart_parity_bit_compute.v

// FIFO (leaf module, instantiated by axi_uart_top)
../rtl/uart/axi_internal_fifo.v

// UART receiver (instantiated by uart_controller)
../rtl/uart/uart_receiver.v

// UART transmitter (instantiates uart_parity_bit_compute)
../rtl/uart/uart_transmitter.v

// UART controller (instantiates uart_receiver + uart_transmitter)
../rtl/uart/uart_controller.v

// AXI-UART top (instantiates uart_controller + two axi_internal_fifo)
../rtl/uart/axi_uart_top.v

// ---------------------------------------------------------------------------
// Testbench
// ---------------------------------------------------------------------------
../tb/tb_axi_uart_top.sv
