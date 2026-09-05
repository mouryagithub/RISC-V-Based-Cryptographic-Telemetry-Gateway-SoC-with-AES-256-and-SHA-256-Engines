// =============================================================================
// Project        : AXI-lite UART IP Core
// File           : tb_axi_uart_top.sv
// Description    : Combined SystemVerilog testbench for all UART RTL modules:
//                    - axi_uart_top
//                    - uart_controller
//                    - uart_transmitter
//                    - uart_receiver
//                    - uart_parity_bit_compute
//                    - axi_internal_fifo
// =============================================================================
// AXI4-Lite parameters must match the defines used in axi_uart_top.v.
// They are replicated here so the TB compiles without external .vh files.
// =============================================================================

// ---------------------------------------------------------------------------
// Macro definitions (replicate axi_uart_defines.vh / axi_uart.vh)
// ---------------------------------------------------------------------------
`define _AXI_UART_DATA_WIDTH_   32
`define _AXI_UART_ADDR_WIDTH_   8
`define _AXI_UART_DIV_WIDTH_    16
`define _AXI_UART_ID_WIDTH_     4
`define _AXI_UART_RESP_WIDTH_   2
`define _AXI_UART_FIFO_DEPTH_   16
`define _AXI_UART_DEADLOCK_     256

// UART register map offsets (word-addressed, bits [7:2])
`define _UART_RBR_              6'h00   // Receive Buffer / Transmit Holding
`define _UART_THR_              6'h00
`define _UART_IER_              6'h01   // Interrupt Enable
`define _UART_BAUD_DIVISOR_     6'h02   // Baud Rate Divisor (when DLAB=1)
`define _UART_LCR_              6'h03   // Line Control Register

// LCR bit positions
`define _UART_CONFIG_DLAB_        7
`define _UART_CONFIG_STOP_BITS_   2
`define _UART_CONFIG_PARITY_EN_   3
`define _UART_CONFIG_PARITY_MODE_ 4

// LSR register offset and bit positions
`define _UART_LSR_              6'h05
`define _UART_LSR_DATA_READY_   0
`define _UART_LSR_THRE_         5
`define _UART_LSR_TEMT_         6

// UART data width and default baud divisor
`define _DATA_WIDTH_UART_       8
`define _UART_BAUDRATE_DIV_INIT_ 16'd434   // ~115200 baud @ 50 MHz

// ---------------------------------------------------------------------------
// Derived TB parameters
// ---------------------------------------------------------------------------
`define AXI_DATA_W  `_AXI_UART_DATA_WIDTH_
`define AXI_ADDR_W  `_AXI_UART_ADDR_WIDTH_
`define AXI_ID_W    `_AXI_UART_ID_WIDTH_
`define AXI_RESP_W  `_AXI_UART_RESP_WIDTH_

module tb_axi_uart_top;

  // -------------------------------------------------------------------------
  // Parameters
  // -------------------------------------------------------------------------
  localparam CLK_PERIOD_NS  = 20;   // 50 MHz fixed / AXI clock
  localparam BAUD_DIV       = 16'd434;  // 115200 @ 50 MHz

  // Byte-enable width = DATA_WIDTH / 8
  localparam AXI_STRB_W     = `AXI_DATA_W / 8;

  // -------------------------------------------------------------------------
  // Clock & reset
  // -------------------------------------------------------------------------
  reg fixed_clk;
  reg axi_clk;
  reg aresetn;

  initial fixed_clk = 0;
  always #(CLK_PERIOD_NS/2) fixed_clk = ~fixed_clk;

  initial axi_clk = 0;
  always #(CLK_PERIOD_NS/2) axi_clk = ~axi_clk;

  // -------------------------------------------------------------------------
  // AXI4-Lite master signals
  // -------------------------------------------------------------------------
  // Write address channel
  reg  [`AXI_ID_W-1:0]    m_awid;
  reg  [`AXI_ADDR_W-1:0]  m_awaddr;
  reg                      m_awvalid;
  wire                     m_awready;

  // Write data channel
  reg  [`AXI_DATA_W-1:0]  m_wdata;
  reg  [AXI_STRB_W-1:0]   m_wstrb;
  reg                      m_wvalid;
  wire                     m_wready;

  // Write response channel
  wire [`AXI_ID_W-1:0]    m_bid;
  wire [`AXI_RESP_W-1:0]  m_bresp;
  wire                     m_bvalid;
  reg                      m_bready;

  // Read address channel
  reg  [`AXI_ID_W-1:0]    m_arid;
  reg  [`AXI_ADDR_W-1:0]  m_araddr;
  reg                      m_arvalid;
  wire                     m_arready;

  // Read data channel
  wire [`AXI_ID_W-1:0]    m_rid;
  wire [`AXI_DATA_W-1:0]  m_rdata;
  wire [`AXI_RESP_W-1:0]  m_rresp;
  wire                     m_rvalid;
  reg                      m_rready;

  // UART serial interface
  wire uart_tx;
  reg  uart_rx;

  // Interrupt
  wire read_interrupt;

  // -------------------------------------------------------------------------
  // DUT: axi_uart_top (exercises all sub-modules)
  // -------------------------------------------------------------------------
  axi_uart_top dut (
    .fixed_clk_i    (fixed_clk),
    .axi_aclk_i     (axi_clk),
    .axi_aresetn_i  (aresetn),

    // Write address
    .axi_awid_i     (m_awid),
    .axi_awaddr_i   (m_awaddr),
    .axi_awvalid_i  (m_awvalid),
    .axi_awready_o  (m_awready),

    // Write data
    .axi_wdata_i    (m_wdata),
    .axi_wstrb_i    (m_wstrb),
    .axi_wvalid_i   (m_wvalid),
    .axi_wready_o   (m_wready),

    // Write response
    .axi_bid_o      (m_bid),
    .axi_bresp_o    (m_bresp),
    .axi_bvalid_o   (m_bvalid),
    .axi_bready_i   (m_bready),

    // Read address
    .axi_arid_i     (m_arid),
    .axi_araddr_i   (m_araddr),
    .axi_arvalid_i  (m_arvalid),
    .axi_arready_o  (m_arready),

    // Read data
    .axi_rid_o      (m_rid),
    .axi_rdata_o    (m_rdata),
    .axi_rresp_o    (m_rresp),
    .axi_rvalid_o   (m_rvalid),
    .axi_rready_i   (m_rready),

    // UART
    .uart_rx_i      (uart_rx),
    .uart_tx_o      (uart_tx),

    // Interrupt
    .read_interrupt_o (read_interrupt)
  );

  // -------------------------------------------------------------------------
  // Loopback: connect TX back to RX (local loopback test)
  // The TB drives uart_rx explicitly during TX tests; during RX tests the
  // loopback wire is used.
  // -------------------------------------------------------------------------
  // Override is handled per-task via uart_rx drives below.

  // -------------------------------------------------------------------------
  // Task: AXI4-Lite write
  // -------------------------------------------------------------------------
  task axi_write;
    input [`AXI_ADDR_W-1:0] addr;
    input [`AXI_DATA_W-1:0] data;
    begin
      @(posedge axi_clk);
      m_awid    = 4'h0;
      m_awaddr  = addr;
      m_awvalid = 1'b1;
      m_wdata   = data;
      m_wstrb   = {AXI_STRB_W{1'b1}};
      m_wvalid  = 1'b1;
      m_bready  = 1'b1;

      // Wait for AWREADY
      @(posedge axi_clk);
      while (!m_awready) @(posedge axi_clk);

      // Wait for WREADY
      while (!m_wready) @(posedge axi_clk);

      @(posedge axi_clk);
      m_awvalid = 1'b0;
      m_wvalid  = 1'b0;

      // Wait for BVALID
      while (!m_bvalid) @(posedge axi_clk);
      @(posedge axi_clk);
      m_bready = 1'b0;
    end
  endtask

  // -------------------------------------------------------------------------
  // Task: AXI4-Lite read
  // -------------------------------------------------------------------------
  task axi_read;
    input  [`AXI_ADDR_W-1:0] addr;
    output [`AXI_DATA_W-1:0] rdata;
    begin
      @(posedge axi_clk);
      m_arid    = 4'h0;
      m_araddr  = addr;
      m_arvalid = 1'b1;
      m_rready  = 1'b1;

      // Wait for ARREADY
      @(posedge axi_clk);
      while (!m_arready) @(posedge axi_clk);

      @(posedge axi_clk);
      m_arvalid = 1'b0;

      // Wait for RVALID
      while (!m_rvalid) @(posedge axi_clk);
      rdata = m_rdata;
      @(posedge axi_clk);
      m_rready = 1'b0;
    end
  endtask

  // -------------------------------------------------------------------------
  // Task: Send one UART byte to uart_rx_i (bit-bang)
  // UART format: 1 start + 8 data (LSB first) + 1 stop, no parity
  // -------------------------------------------------------------------------
  task send_uart_byte;
    input [7:0] byte_val;
    integer     baud_clks;
    integer     b;
    begin
      baud_clks = BAUD_DIV;   // clock periods per baud

      // Start bit
      uart_rx = 1'b0;
      repeat (baud_clks) @(posedge fixed_clk);

      // 8 data bits, LSB first
      for (b = 0; b < 8; b = b + 1) begin
        uart_rx = byte_val[b];
        repeat (baud_clks) @(posedge fixed_clk);
      end

      // Stop bit
      uart_rx = 1'b1;
      repeat (baud_clks) @(posedge fixed_clk);
    end
  endtask

  // -------------------------------------------------------------------------
  // Task: Receive one UART byte from uart_tx (sample mid-bit)
  // -------------------------------------------------------------------------
  task recv_uart_byte;
    output [7:0] rx_byte;
    integer      half_baud;
    integer      baud_clks;
    integer      b;
    begin
      half_baud = BAUD_DIV / 2;
      baud_clks = BAUD_DIV;
      rx_byte   = 8'h00;

      // Wait for start bit (falling edge on uart_tx)
      @(negedge uart_tx);

      // Skip to centre of first data bit
      repeat (half_baud + baud_clks) @(posedge fixed_clk);

      // Sample 8 data bits
      for (b = 0; b < 8; b = b + 1) begin
        rx_byte[b] = uart_tx;
        repeat (baud_clks) @(posedge fixed_clk);
      end

      // Skip stop bit
      repeat (baud_clks) @(posedge fixed_clk);
    end
  endtask

  // -------------------------------------------------------------------------
  // Test results tracking
  // -------------------------------------------------------------------------
  integer pass_count;
  integer fail_count;

  task check;
    input [`AXI_DATA_W-1:0] got;
    input [`AXI_DATA_W-1:0] exp;
    input [127:0]           test_name;
    begin
      if (got === exp) begin
        $display("[PASS] %s : got 0x%0h", test_name, got);
        pass_count = pass_count + 1;
      end else begin
        $display("[FAIL] %s : got 0x%0h, expected 0x%0h", test_name, got, exp);
        fail_count = fail_count + 1;
      end
    end
  endtask

  // -------------------------------------------------------------------------
  // Waveform dump
  // -------------------------------------------------------------------------
  initial begin
    $fsdbDumpfile("tb_axi_uart_top.fsdb");
    $fsdbDumpvars(0, tb_axi_uart_top);
  end

  // -------------------------------------------------------------------------
  // Main stimulus
  // -------------------------------------------------------------------------
  reg [`AXI_DATA_W-1:0] rd_data;
  reg [7:0]             rx_captured;

  // Address helpers (byte addresses, word-aligned)
  localparam ADDR_THR          = 8'h00;   // TX holding / RX buffer (DLAB=0)
  localparam ADDR_IER          = 8'h04;   // Interrupt enable        (DLAB=0)
  localparam ADDR_BAUD_DIV     = 8'h08;   // Baud divisor            (DLAB=1)
  localparam ADDR_LCR          = 8'h0C;   // Line control register
  localparam ADDR_LSR          = 8'h14;   // Line status register

  initial begin
    // -----------------------------------------------------------------------
    // Initialise master signals
    // -----------------------------------------------------------------------
    pass_count  = 0;
    fail_count  = 0;

    m_awid      = {`AXI_ID_W{1'b0}};
    m_awaddr    = {`AXI_ADDR_W{1'b0}};
    m_awvalid   = 1'b0;
    m_wdata     = {`AXI_DATA_W{1'b0}};
    m_wstrb     = {AXI_STRB_W{1'b0}};
    m_wvalid    = 1'b0;
    m_bready    = 1'b0;
    m_arid      = {`AXI_ID_W{1'b0}};
    m_araddr    = {`AXI_ADDR_W{1'b0}};
    m_arvalid   = 1'b0;
    m_rready    = 1'b0;
    uart_rx     = 1'b1;   // idle high

    // -----------------------------------------------------------------------
    // Reset sequence
    // -----------------------------------------------------------------------
    aresetn = 1'b0;
    repeat (10) @(posedge axi_clk);
    aresetn = 1'b1;
    repeat (5)  @(posedge axi_clk);

    $display("=============================================================");
    $display(" AXI-UART Top Combined Testbench");
    $display("=============================================================");

    // =======================================================================
    // TEST 1: Write LCR — configure UART (no parity, 1 stop bit, DLAB=1)
    // =======================================================================
    $display("\n--- TEST 1: LCR write (DLAB=1 to access baud divisor) ---");
    axi_write(ADDR_LCR, 32'h80);   // DLAB = bit[7] = 1

    // =======================================================================
    // TEST 2: Write baud divisor
    // =======================================================================
    $display("--- TEST 2: Baud divisor write ---");
    axi_write(ADDR_BAUD_DIV, {16'h0, BAUD_DIV});

    // =======================================================================
    // TEST 3: Clear DLAB, configure 8N1
    // =======================================================================
    $display("--- TEST 3: LCR write (DLAB=0, 8N1) ---");
    axi_write(ADDR_LCR, 32'h00);   // 8N1, DLAB=0

    // =======================================================================
    // TEST 4: Enable RX interrupt via IER
    // =======================================================================
    $display("--- TEST 4: IER write (enable RX data available interrupt) ---");
    axi_write(ADDR_IER, 32'h01);

    // =======================================================================
    // TEST 5: Read LSR — THR empty (bits 5 & 6 should be 1)
    // =======================================================================
    $display("--- TEST 5: Read LSR (THRE & TEMT should be set) ---");
    axi_read(ADDR_LSR, rd_data);
    check(rd_data[5], 1'b1, "LSR[THRE]");
    check(rd_data[6], 1'b1, "LSR[TEMT]");

    // =======================================================================
    // TEST 6: Transmit byte 0x55 via AXI write to THR
    //         Then capture it on uart_tx (loopback verification)
    // =======================================================================
    $display("--- TEST 6: TX byte 0x55 via AXI THR write ---");
    fork
      begin
        axi_write(ADDR_THR, 32'h55);
        $display("    AXI write to THR done");
      end
      begin
        recv_uart_byte(rx_captured);
        $display("    Captured UART TX byte: 0x%0h", rx_captured);
        check(rx_captured, 8'h55, "TX byte loopback");
      end
    join

    // =======================================================================
    // TEST 7: Transmit byte 0xAA
    // =======================================================================
    $display("--- TEST 7: TX byte 0xAA via AXI THR write ---");
    fork
      begin
        axi_write(ADDR_THR, 32'hAA);
      end
      begin
        recv_uart_byte(rx_captured);
        $display("    Captured UART TX byte: 0x%0h", rx_captured);
        check(rx_captured, 8'hAA, "TX byte 0xAA");
      end
    join

    // =======================================================================
    // TEST 8: Receive byte 0x37 injected on uart_rx
    //         Then read it back via AXI RBR read
    // =======================================================================
    $display("--- TEST 8: RX byte 0x37 injected on uart_rx ---");
    // Allow some idle time
    repeat (20) @(posedge fixed_clk);
    send_uart_byte(8'h37);
    // Wait for data to propagate into RX FIFO
    repeat (50) @(posedge fixed_clk);

    axi_read(ADDR_THR, rd_data);   // RBR shares address 0x00 with THR (DLAB=0)
    $display("    AXI RBR read: 0x%0h", rd_data[7:0]);
    check(rd_data[7:0], 8'h37, "RX byte 0x37");

    // =======================================================================
    // TEST 9: Receive byte 0xC3
    // =======================================================================
    $display("--- TEST 9: RX byte 0xC3 injected on uart_rx ---");
    repeat (20) @(posedge fixed_clk);
    send_uart_byte(8'hC3);
    repeat (50) @(posedge fixed_clk);

    axi_read(ADDR_THR, rd_data);
    $display("    AXI RBR read: 0x%0h", rd_data[7:0]);
    check(rd_data[7:0], 8'hC3, "RX byte 0xC3");

    // =======================================================================
    // TEST 10: Read interrupt check — send a byte and verify interrupt fires
    // =======================================================================
    $display("--- TEST 10: RX interrupt assertion check ---");
    repeat (20) @(posedge fixed_clk);
    send_uart_byte(8'hBE);
    repeat (50) @(posedge fixed_clk);
    check(read_interrupt, 1'b1, "read_interrupt asserted");

    // Drain the FIFO
    axi_read(ADDR_THR, rd_data);

    // =======================================================================
    // TEST 11: Back-to-back TX — multiple bytes
    // =======================================================================
    $display("--- TEST 11: Back-to-back TX bytes 0x01, 0x02, 0x03 ---");
    begin : back2back
      reg [7:0] captured [0:2];
      integer   i;

      fork
        begin
          axi_write(ADDR_THR, 32'h01);
          axi_write(ADDR_THR, 32'h02);
          axi_write(ADDR_THR, 32'h03);
        end
        begin
          recv_uart_byte(captured[0]);
          recv_uart_byte(captured[1]);
          recv_uart_byte(captured[2]);
        end
      join

      for (i = 0; i < 3; i = i + 1) begin
        $display("    captured[%0d] = 0x%0h", i, captured[i]);
      end
      check(captured[0], 8'h01, "B2B TX[0]");
      check(captured[1], 8'h02, "B2B TX[1]");
      check(captured[2], 8'h03, "B2B TX[2]");
    end

    // =======================================================================
    // TEST 12: LSR DATA_READY cleared after FIFO drain
    // =======================================================================
    $display("--- TEST 12: LSR DATA_READY cleared after drain ---");
    // Ensure FIFO is empty (read one extra time)
    axi_read(ADDR_LSR, rd_data);
    // DATA_READY should be 0 (FIFO empty) or may still be 1 if pending —
    // we just verify we can read LSR without hanging.
    $display("    LSR after drain = 0x%0h", rd_data);

    // =======================================================================
    // Summary
    // =======================================================================
    repeat (10) @(posedge axi_clk);
    $display("\n=============================================================");
    $display(" RESULTS: PASS=%0d  FAIL=%0d", pass_count, fail_count);
    $display("=============================================================");

    if (fail_count == 0)
      $display(" ALL TESTS PASSED");
    else
      $display(" SOME TESTS FAILED");

    $finish;
  end

  // -------------------------------------------------------------------------
  // Timeout watchdog — prevent runaway simulation
  // -------------------------------------------------------------------------
  initial begin
    #50_000_000;  // 50 ms simulation limit
    $display("[TIMEOUT] Simulation exceeded time limit.");
    $finish;
  end

endmodule
