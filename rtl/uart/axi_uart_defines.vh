// =============================================================================
// File    : axi_uart_defines.vh
// Description : AXI4-Lite interface parameter definitions for axi_uart_top
// =============================================================================

`ifndef AXI_UART_DEFINES_VH
`define AXI_UART_DEFINES_VH

`define _AXI_UART_DATA_WIDTH_   32   // AXI data bus width (bits)
`define _AXI_UART_ADDR_WIDTH_   8    // AXI address bus width (bits)
`define _AXI_UART_DIV_WIDTH_    16   // Baud-rate divisor register width
`define _AXI_UART_ID_WIDTH_     4    // AXI transaction ID width
`define _AXI_UART_RESP_WIDTH_   2    // AXI response field width
`define _AXI_UART_FIFO_DEPTH_   16   // RX / TX FIFO depth (entries)
`define _AXI_UART_DEADLOCK_     256  // Deadlock counter limit

`endif // AXI_UART_DEFINES_VH
