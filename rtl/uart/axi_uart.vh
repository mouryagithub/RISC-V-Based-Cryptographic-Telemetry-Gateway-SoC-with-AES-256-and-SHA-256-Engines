// =============================================================================
// File    : axi_uart.vh
// Description : UART custom register map and configuration bit definitions
//               for axi_uart_top.  Registers are word-addressed; the address
//               field used in the FSM is axi_araddr[ADDR_WIDTH-1:LSB_WIDTH]
//               i.e. bits [7:2] for a 32-bit / 8-bit-address configuration.
// =============================================================================

`ifndef AXI_UART_VH
`define AXI_UART_VH

// ---------------------------------------------------------------------------
// Register map  (6-bit word address = byte_addr[7:2])
// ---------------------------------------------------------------------------
`define _UART_RBR_          6'h00   // Receive Buffer Register    (DLAB=0, read)
`define _UART_THR_          6'h00   // Transmit Holding Register  (DLAB=0, write)
`define _UART_IER_          6'h01   // Interrupt Enable Register  (DLAB=0)
`define _UART_BAUD_DIVISOR_ 6'h02   // Baud Rate Divisor          (DLAB=1)
`define _UART_LCR_          6'h03   // Line Control Register
`define _UART_LSR_          6'h05   // Line Status Register       (read-only)

// ---------------------------------------------------------------------------
// LCR bit positions (within the 32-bit AXI data word)
// ---------------------------------------------------------------------------
`define _UART_CONFIG_DLAB_          7   // Divisor Latch Access Bit
`define _UART_CONFIG_STOP_BITS_     2   // 0 = 1 stop bit,  1 = 2 stop bits
`define _UART_CONFIG_PARITY_EN_     3   // 1 = parity enabled
`define _UART_CONFIG_PARITY_MODE_   4   // 0 = odd parity,  1 = even parity

// ---------------------------------------------------------------------------
// LSR bit positions
// ---------------------------------------------------------------------------
`define _UART_LSR_DATA_READY_   0   // RX data available in FIFO
`define _UART_LSR_THRE_         5   // Transmit Holding Register Empty
`define _UART_LSR_TEMT_         6   // Transmitter Empty (shift reg & FIFO empty)

// ---------------------------------------------------------------------------
// UART data width and default baud-rate divisor
//   Default: 115200 baud @ 50 MHz  ->  50_000_000 / 115200 ≈ 434
// ---------------------------------------------------------------------------
`define _DATA_WIDTH_UART_           8
`define _UART_BAUDRATE_DIV_INIT_    16'd434

`endif // AXI_UART_VH
