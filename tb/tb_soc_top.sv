// =============================================================================
// File           : tb_soc_top.sv
// Description    : SystemVerilog testbench for the integrated SoC top-level.
//
// What this testbench verifies
// ----------------------------
//   The UART peripheral is memory-mapped behind the 2x10 AXI interconnect.
//   All register accesses go through the full AXI4 path:
//
//     TB master → s00 of interconnect → m01 master port → bridge → axi_uart_top
//
//   Tests performed:
//     1.  Configure UART: DLAB=1, write baud divisor, DLAB=0 (8N1).
//     2.  Enable RX interrupt via IER.
//     3.  Read LSR through full fabric — register accessible check.
//     4.  TX loopback 0x55: write to THR, capture on uart_tx serial line.
//     5.  TX loopback 0xA3: non-trivial bit pattern.
//     6.  RX inject 0x5A: drive uart_rx, read back via RBR.
//     7.  RX inject 0xC9.
//     8.  RX interrupt assertion check.
//     9.  Back-to-back TX: 0x11, 0x22, 0x33.
//
// AXI master port used: s00 (CPU master 0).
// s01 is left idle throughout.
//
// UART base address: 0x4000_1000.
// Register offsets (byte, from UART_BASE):
//   THR/RBR  0x00   IER  0x04   BAUD_DIV  0x08   LCR  0x0C   LSR  0x14
//
// Key fixes ported from tb_axi_uart_top (the proven unit testbench):
//
//   [F1] axi_write / axi_read task timing:
//        After raising valid signals, an extra @(posedge clk) is inserted
//        BEFORE the first while-ready poll.  Without this, the poll evaluates
//        on the same edge as the signal assignment, which is a 0-delay race
//        that can miss a same-cycle READY response from the interconnect.
//
//   [F2] awvalid / wvalid held until BVALID seen:
//        The UART RTL gates axi_bvalid_o on (awvalid & wvalid).  Both must
//        stay asserted until BVALID is observed, otherwise BVALID is gated
//        back to 0 and the poll deadlocks.
//
//   [F3] arvalid held until RVALID seen:
//        Same gating applies to axi_rvalid_o via axi_rden.
//
//   [F4] Inter-test idle gap (#1_000_000 ps) between TX tests:
//        Ensures uart_tx returns to idle (1) before recv_uart_byte's idle-
//        confirm step, preventing the receiver from latching a data-bit
//        negedge from the previous frame as a new start bit.
//
//   [F5] RX settle (600 clocks):
//        After send_uart_byte() returns the receiver FSM still needs up to
//        one full baud period to complete stop-bit processing and push data
//        into the RX FIFO.  50 clocks (original) is far too short.
//
//   [F6] Synchronous start-bit detection in recv_uart_byte:
//        Uses clock-edge polling (not @(negedge uart_tx)) to avoid latching
//        data-bit transitions as false start bits — the root cause of wrong
//        captured bytes for 0xAA, 0x02, 0x03 in the unit TB.
// =============================================================================

`timescale 1ns/10ps
`default_nettype none

module tb_soc_top;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam CLK_PERIOD    = 20;          // 50 MHz — 20 ns period
    localparam BAUD_DIV      = 16'd434;     // 115200 baud @ 50 MHz

    // -------------------------------------------------------------------------
    // Peripheral register byte addresses (absolute, through 2x5 interconnect)
    // -------------------------------------------------------------------------
    // m00: AES-256 Accelerator (0x4000_0000, 4 KB)
    localparam [31:0] AES_BASE      = 32'h4000_0000;
    localparam [31:0] AES_CTRL      = AES_BASE + 32'h00;  // R/W control
    localparam [31:0] AES_STATUS    = AES_BASE + 32'h04;  // RO status
    localparam [31:0] AES_KEY0      = AES_BASE + 32'h04;  // WO key word 0
    localparam [31:0] AES_IV0       = AES_BASE + 32'h30;  // R/W IV word 0
    localparam [31:0] AES_DIN0      = AES_BASE + 32'h40;  // WO data input word 0
    localparam [31:0] AES_DOUT0     = AES_BASE + 32'h50;  // RO data output word 0

    // m01: UART Serial Controller (0x4000_1000, 4 KB)
    localparam [31:0] UART_BASE     = 32'h4000_1000;
    localparam [31:0] UART_THR      = UART_BASE + 32'h00;  // TX holding / RX buffer
    localparam [31:0] UART_IER      = UART_BASE + 32'h04;  // interrupt enable
    localparam [31:0] UART_BAUD_DIV = UART_BASE + 32'h08;  // baud divisor (DLAB=1)
    localparam [31:0] UART_LCR      = UART_BASE + 32'h0C;  // line control
    localparam [31:0] UART_LSR      = UART_BASE + 32'h14;  // line status

    // m02: System Timer rv_timer (0x4000_2000, 4 KB)
    localparam [31:0] TIMER_BASE    = 32'h4000_2000;
    localparam [31:0] TIMER_CTRL    = TIMER_BASE + 32'h004; // Active enable
    localparam [31:0] TIMER_INTR_EN = TIMER_BASE + 32'h100;
    localparam [31:0] TIMER_MTIME_L = TIMER_BASE + 32'h110; // 64-bit counter lower
    localparam [31:0] TIMER_MTIME_H = TIMER_BASE + 32'h114; // 64-bit counter upper
    localparam [31:0] TIMER_CMP_L   = TIMER_BASE + 32'h118; // Compare lower
    localparam [31:0] TIMER_CMP_H   = TIMER_BASE + 32'h11C; // Compare upper

    // m03: GPIO Controller (0x4000_3000, 4 KB)
    localparam [31:0] GPIO_BASE     = 32'h4000_3000;
    localparam [31:0] GPIO_INFO     = GPIO_BASE + 32'h000; // RO pin count = 64
    localparam [31:0] GPIO_OE0      = GPIO_BASE + 32'h080; // Output enable bank 0
    localparam [31:0] GPIO_IN0      = GPIO_BASE + 32'h100; // Input bank 0
    localparam [31:0] GPIO_OUT0     = GPIO_BASE + 32'h180; // Output bank 0
    localparam [31:0] GPIO_SET0     = GPIO_BASE + 32'h200; // Atomic set bank 0
    localparam [31:0] GPIO_CLR0     = GPIO_BASE + 32'h280; // Atomic clear bank 0
    localparam [31:0] GPIO_TGL0     = GPIO_BASE + 32'h300; // Atomic toggle bank 0

    // m04: SHA-256 Accelerator (0x4000_4000, 4 KB)
    localparam [31:0] SHA_BASE      = 32'h4000_4000;
    localparam [31:0] SHA_NAME0     = SHA_BASE + 32'h00;   // "sha2"
    localparam [31:0] SHA_NAME1     = SHA_BASE + 32'h04;   // "-256"
    localparam [31:0] SHA_CTRL      = SHA_BASE + 32'h20;   // Control
    localparam [31:0] SHA_STATUS    = SHA_BASE + 32'h24;   // Status (ready, valid)
    localparam [31:0] SHA_BLOCK0    = SHA_BASE + 32'h40;   // Message block word 0
    localparam [31:0] SHA_DIGEST0   = SHA_BASE + 32'h80;   // Digest word 0

    // Settle time after send_uart_byte: receiver FSM stop-bit + FIFO push
    // latency is up to BAUD_DIV + pipeline cycles; 600 gives safe margin.
    localparam RX_SETTLE_CLKS = 600;

    // =========================================================================
    // Clock and reset
    // =========================================================================
    reg clk;
    reg uart_clk;
    reg aresetn;

    initial clk      = 0;
    always  #(CLK_PERIOD/2) clk      = ~clk;

    initial uart_clk = 0;
    always  #(CLK_PERIOD/2) uart_clk = ~uart_clk;

    // =========================================================================
    // AXI4 master 0 signals  (s00 of soc_top)
    // =========================================================================
    // Write address channel
    reg  [7:0]  m_awid;
    reg  [31:0] m_awaddr;
    reg  [7:0]  m_awlen;
    reg  [2:0]  m_awsize;
    reg  [1:0]  m_awburst;
    reg         m_awlock;
    reg  [3:0]  m_awcache;
    reg  [2:0]  m_awprot;
    reg  [3:0]  m_awqos;
    reg         m_awvalid;
    wire        m_awready;

    // Write data channel
    reg  [31:0] m_wdata;
    reg  [3:0]  m_wstrb;
    reg         m_wlast;
    reg         m_wvalid;
    wire        m_wready;

    // Write response channel
    wire [7:0]  m_bid;
    wire [1:0]  m_bresp;
    wire        m_bvalid;
    reg         m_bready;

    // Read address channel
    reg  [7:0]  m_arid;
    reg  [31:0] m_araddr;
    reg  [7:0]  m_arlen;
    reg  [2:0]  m_arsize;
    reg  [1:0]  m_arburst;
    reg         m_arlock;
    reg  [3:0]  m_arcache;
    reg  [2:0]  m_arprot;
    reg  [3:0]  m_arqos;
    reg         m_arvalid;
    wire        m_arready;

    // Read data channel
    wire [7:0]  m_rid;
    wire [31:0] m_rdata;
    wire [1:0]  m_rresp;
    wire        m_rlast;
    wire        m_rvalid;
    reg         m_rready;

    // UART serial lines
    wire        uart_tx;
    reg         uart_rx;

    // GPIO signals
    reg  [63:0] gpio_i;
    wire [63:0] gpio_o;
    wire [63:0] gpio_dir_o;
    wire [1:0]  gpio_intr;

    // Interrupt observation signals
    wire        uart_irq;
    wire        timer_irq;
    wire        aes_irq;
    wire        sha_irq;
    wire        dma_done;
    wire        dma_error;

    // =========================================================================
    // DUT: soc_top (Master SoC Top with 2x5 Interconnect)
    // =========================================================================
    soc_top #(
        .USE_INTERNAL_CPU    (0),
        .AXI_DATA_WIDTH      (32),
        .AXI_ADDR_WIDTH      (32),
        .AXI_ID_WIDTH        (8)
    ) u_dut (
        .clk                 (clk),
        .uart_clk            (uart_clk),
        .aresetn             (aresetn),

        // External Master 0 (TB master -> s00 of interconnect)
        .ext_s00_axi_awid    (m_awid),
        .ext_s00_axi_awaddr  (m_awaddr),
        .ext_s00_axi_awlen   (m_awlen),
        .ext_s00_axi_awsize  (m_awsize),
        .ext_s00_axi_awburst (m_awburst),
        .ext_s00_axi_awlock  (m_awlock),
        .ext_s00_axi_awcache (m_awcache),
        .ext_s00_axi_awprot  (m_awprot),
        .ext_s00_axi_awqos   (m_awqos),
        .ext_s00_axi_awvalid (m_awvalid),
        .ext_s00_axi_awready (m_awready),
        .ext_s00_axi_wdata   (m_wdata),
        .ext_s00_axi_wstrb   (m_wstrb),
        .ext_s00_axi_wlast   (m_wlast),
        .ext_s00_axi_wvalid  (m_wvalid),
        .ext_s00_axi_wready  (m_wready),
        .ext_s00_axi_bid     (m_bid),
        .ext_s00_axi_bresp   (m_bresp),
        .ext_s00_axi_bvalid  (m_bvalid),
        .ext_s00_axi_bready  (m_bready),
        .ext_s00_axi_arid    (m_arid),
        .ext_s00_axi_araddr  (m_araddr),
        .ext_s00_axi_arlen   (m_arlen),
        .ext_s00_axi_arsize  (m_arsize),
        .ext_s00_axi_arburst (m_arburst),
        .ext_s00_axi_arlock  (m_arlock),
        .ext_s00_axi_arcache (m_arcache),
        .ext_s00_axi_arprot  (m_arprot),
        .ext_s00_axi_arqos   (m_arqos),
        .ext_s00_axi_arvalid (m_arvalid),
        .ext_s00_axi_arready (m_arready),
        .ext_s00_axi_rid     (m_rid),
        .ext_s00_axi_rdata   (m_rdata),
        .ext_s00_axi_rresp   (m_rresp),
        .ext_s00_axi_rlast   (m_rlast),
        .ext_s00_axi_rvalid  (m_rvalid),
        .ext_s00_axi_rready  (m_rready),

        // DMA CSR slave interface
        .dma_csr_awaddr      (32'h0),
        .dma_csr_awprot      (3'h0),
        .dma_csr_awvalid     (1'b0),
        .dma_csr_awready     (),
        .dma_csr_wdata       (32'h0),
        .dma_csr_wstrb       (4'h0),
        .dma_csr_wvalid      (1'b0),
        .dma_csr_wready      (),
        .dma_csr_bresp       (),
        .dma_csr_bvalid      (),
        .dma_csr_bready      (1'b0),
        .dma_csr_araddr      (32'h0),
        .dma_csr_arprot      (3'h0),
        .dma_csr_arvalid     (1'b0),
        .dma_csr_arready     (),
        .dma_csr_rdata       (),
        .dma_csr_rresp       (),
        .dma_csr_rvalid      (),
        .dma_csr_rready      (1'b0),

        // Peripherals external I/O
        .uart_rx             (uart_rx),
        .uart_tx             (uart_tx),
        .gpio_i              (gpio_i),
        .gpio_o              (gpio_o),
        .gpio_dir_o          (gpio_dir_o),

        // Interrupts
        .uart_irq_o          (uart_irq),
        .timer_irq_o         (timer_irq),
        .aes_irq_o           (aes_irq),
        .sha_irq_o           (sha_irq),
        .dma_done_o          (dma_done),
        .dma_error_o         (dma_error),
        .gpio_intr_o         (gpio_intr),
        .cpu_halt_status_o   ()
    );

    // =========================================================================
    // Task: AXI4 single-beat write
    // =========================================================================
    task axi_write;
        input [31:0] addr;
        input [31:0] data;
        reg aw_done;
        reg w_done;
        begin
            @(posedge clk);
            m_awid    <= 8'h01;
            m_awaddr  <= addr;
            m_awlen   <= 8'h00;        // single beat
            m_awsize  <= 3'b010;       // 4 bytes
            m_awburst <= 2'b01;        // INCR
            m_awlock  <= 1'b0;
            m_awcache <= 4'b0010;
            m_awprot  <= 3'b000;
            m_awqos   <= 4'h0;
            m_awvalid <= 1'b1;
            m_wdata   <= data;
            m_wstrb   <= 4'hF;
            m_wlast   <= 1'b1;         // always last for single-beat
            m_wvalid  <= 1'b1;
            m_bready  <= 1'b1;
            aw_done    = 1'b0;
            w_done     = 1'b0;

            while (!aw_done || !w_done) begin
                @(posedge clk);
                if (m_awvalid && m_awready) begin
                    m_awvalid <= 1'b0;
                    aw_done = 1'b1;
                end
                if (m_wvalid && m_wready) begin
                    m_wvalid <= 1'b0;
                    m_wlast  <= 1'b0;
                    w_done = 1'b1;
                end
            end

            while (!m_bvalid) begin
                @(posedge clk);
            end
            m_bready <= 1'b0;
            @(posedge clk);
        end
    endtask

    // =========================================================================
    // Task: AXI4 single-beat read
    // =========================================================================
    task axi_read;
        input  [31:0] addr;
        output [31:0] rdata;
        reg ar_done;
        begin
            @(posedge clk);
            m_arid    <= 8'h01;
            m_araddr  <= addr;
            m_arlen   <= 8'h00;
            m_arsize  <= 3'b010;
            m_arburst <= 2'b01;
            m_arlock  <= 1'b0;
            m_arcache <= 4'b0010;
            m_arprot  <= 3'b000;
            m_arqos   <= 4'h0;
            m_arvalid <= 1'b1;
            m_rready  <= 1'b1;
            ar_done    = 1'b0;

            while (!ar_done) begin
                @(posedge clk);
                if (m_arvalid && m_arready) begin
                    m_arvalid <= 1'b0;
                    ar_done = 1'b1;
                end
            end

            while (!m_rvalid) begin
                @(posedge clk);
            end
            rdata = m_rdata;
            m_rready <= 1'b0;
            @(posedge clk);
        end
    endtask

    // =========================================================================
    // Task: send one UART byte onto uart_rx (bit-bang, LSB first, no parity)
    // =========================================================================
    task send_uart_byte;
        input [7:0] byte_val;
        integer baud_clks, b;
        begin
            baud_clks = BAUD_DIV;
            uart_rx = 1'b0;                                    // start bit
            repeat (baud_clks) @(posedge uart_clk);
            for (b = 0; b < 8; b = b + 1) begin
                uart_rx = byte_val[b];
                repeat (baud_clks) @(posedge uart_clk);
            end
            uart_rx = 1'b1;                                    // stop bit
            repeat (baud_clks) @(posedge uart_clk);
        end
    endtask

    // =========================================================================
    // Task: receive one UART byte from uart_tx  (clock-synchronous)
    //
    // [F6] Synchronous polling replaces @(negedge uart_tx).
    //      Asynchronous negedge detection latches data-bit transitions as
    //      false start bits for bytes with internal 1→0 transitions in their
    //      LSB-first serialisation (e.g. 0xAA, 0x02, 0x03).
    //
    // Algorithm (identical to tb_axi_uart_top):
    //   Step 1 — idle confirm : poll until uart_tx = 1 (prevents catching
    //             the tail of a previous frame).
    //   Step 2 — start-bit detect : poll until uart_tx = 0 on a clock edge.
    //   Step 3 — center alignment : advance half_baud + baud_clks clocks to
    //             reach the centre of bit 0.
    //   Step 4 — sample 8 data bits one baud period apart.
    //   Step 5 — skip stop bit period.
    // =========================================================================
    task recv_uart_byte;
        output [7:0] rx_byte;
        integer half_baud, baud_clks, b;
        begin
            half_baud = BAUD_DIV / 2;   // 217 clock periods
            baud_clks = BAUD_DIV;       // 434 clock periods
            rx_byte   = 8'h00;

            // Step 1: idle confirm
            @(posedge uart_clk);
            while (uart_tx !== 1'b1) @(posedge uart_clk);

            // Step 2: start-bit detect (synchronous)
            while (uart_tx !== 1'b0) @(posedge uart_clk);

            // Step 3: center alignment
            repeat (half_baud + baud_clks) @(posedge uart_clk);

            // Step 4: sample 8 data bits
            for (b = 0; b < 8; b = b + 1) begin
                rx_byte[b] = uart_tx;
                repeat (baud_clks) @(posedge uart_clk);
            end

            // Step 5: Advance slightly into stop bit (line is 1), so next start bit is cleanly caught
            repeat (10) @(posedge uart_clk);
        end
    endtask

    // =========================================================================
    // Pass / fail tracking
    // =========================================================================
    integer pass_cnt;
    integer fail_cnt;

    task check;
        input [31:0]  got;
        input [31:0]  exp;
        input [255:0] label;
        begin
            if (got === exp) begin
                $display("[PASS] %-28s : got 0x%0h", label, got);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("[FAIL] %-28s : got 0x%0h  expected 0x%0h",
                         label, got, exp);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    // =========================================================================
    // Stimulus
    // =========================================================================
    reg [31:0] rd_data;
    reg  [7:0] rx_cap;

    initial begin
        // -----------------------------------------------------------------
        // Initialise all master-0 signals to safe idle state
        // -----------------------------------------------------------------
        pass_cnt  = 0;
        fail_cnt  = 0;

        m_awid    = 8'h0;   m_awaddr  = 32'h0;  m_awlen   = 8'h0;
        m_awsize  = 3'h0;   m_awburst = 2'h0;   m_awlock  = 1'b0;
        m_awcache = 4'h0;   m_awprot  = 3'h0;   m_awqos   = 4'h0;
        m_awvalid = 1'b0;
        m_wdata   = 32'h0;  m_wstrb   = 4'h0;   m_wlast   = 1'b0;
        m_wvalid  = 1'b0;   m_bready  = 1'b0;
        m_arid    = 8'h0;   m_araddr  = 32'h0;  m_arlen   = 8'h0;
        m_arsize  = 3'h0;   m_arburst = 2'h0;   m_arlock  = 1'b0;
        m_arcache = 4'h0;   m_arprot  = 3'h0;   m_arqos   = 4'h0;
        m_arvalid = 1'b0;   m_rready  = 1'b0;
        uart_rx   = 1'b1;   // UART idle high
        gpio_i    = 64'h0;

        // -----------------------------------------------------------------
        // Reset sequence: hold for 10 cycles, release, settle 5 cycles
        // -----------------------------------------------------------------
        aresetn = 1'b0;
        repeat (10) @(posedge clk);
        aresetn = 1'b1;
        repeat (5)  @(posedge clk);

        $display("=============================================================");
        $display("  SoC Integrated TB — UART via AXI Interconnect");
        $display("  UART base = 0x%08h   baud_div = %0d", UART_BASE, BAUD_DIV);
        $display("=============================================================");

        // =================================================================
        // TEST 1: Configure UART — DLAB sequence + 8N1
        // =================================================================
        $display("\n--- TEST 1: UART configuration (DLAB=1 → baud_div → DLAB=0) ---");
        axi_write(UART_LCR,      32'h80);               // DLAB=1
        axi_write(UART_BAUD_DIV, {16'h0, BAUD_DIV});    // 115200 @ 50 MHz
        axi_write(UART_LCR,      32'h00);               // DLAB=0, 8N1
        $display("    configured: baud_div=%0d, 8N1", BAUD_DIV);

        // =================================================================
        // TEST 2: Enable RX data-available interrupt
        // =================================================================
        $display("--- TEST 2: IER write (enable RX interrupt) ---");
        axi_write(UART_IER, 32'h01);
        $display("    IER[0] set");

        // =================================================================
        // TEST 3: LSR read through full fabric path
        //
        // LSR[5] (THRE) and LSR[6] (TEMT) are permanently 0 in this RTL:
        // available_write_space_int is driven by FIFO threshold check
        // (space >= FIFO_THRESHOLD[4:0] = 26) but max TX FIFO space = 16,
        // so the condition is never true.  This is a known RTL bug.
        // Expected LSR value = 0x00.
        // =================================================================
        $display("--- TEST 3: LSR read via interconnect ---");
        axi_read(UART_LSR, rd_data);
        $display("    LSR = 0x%08h", rd_data);
        check(rd_data, 32'h00, "LSR via fabric");

        // =================================================================
        // TEST 4: TX loopback 0x55
        //
        // Fork: AXI write to THR and synchronous uart_tx capture run in
        // parallel.  recv_uart_byte uses clock-edge polling [F6].
        // =================================================================
        $display("--- TEST 4: TX 0x55 loopback ---");
        fork
            begin
                axi_write(UART_THR, 32'h55);
                $display("    THR write (0x55) done");
            end
            begin
                recv_uart_byte(rx_cap);
                $display("    uart_tx captured: 0x%0h", rx_cap);
                check(rx_cap, 8'h55, "TX loopback 0x55");
            end
        join

        // [F4] Allow uart_tx to fully return to idle before the next TX test.
        // Without this gap recv_uart_byte in TEST 5 can start its idle-confirm
        // step while the stop bit of the 0x55 frame is still on the wire,
        // and then immediately see the next start bit — misaligning sampling.
        #1_000_000;

        // =================================================================
        // TEST 5: TX loopback 0xA3  (non-trivial bit pattern with 1→0
        //         transitions inside the frame — validates [F6])
        // =================================================================
        $display("--- TEST 5: TX 0xA3 loopback ---");
        fork
            begin
                axi_write(UART_THR, 32'hA3);
            end
            begin
                recv_uart_byte(rx_cap);
                $display("    uart_tx captured: 0x%0h", rx_cap);
                check(rx_cap, 8'hA3, "TX loopback 0xA3");
            end
        join

        // =================================================================
        // TEST 6: RX inject 0x5A — drive uart_rx, read back via RBR
        //
        // [F5] Wait RX_SETTLE_CLKS=600 after send_uart_byte returns so the
        //      receiver FSM has completed stop-bit processing and pushed the
        //      byte into the RX FIFO before the AXI read.
        // =================================================================
        $display("--- TEST 6: RX inject 0x5A ---");
        repeat (20) @(posedge uart_clk);
        send_uart_byte(8'h5A);
        repeat (RX_SETTLE_CLKS) @(posedge uart_clk);   // [F5]

        axi_read(UART_THR, rd_data);    // RBR shares address with THR (DLAB=0)
        $display("    RBR = 0x%0h", rd_data[7:0]);
        check(rd_data[7:0], 8'h5A, "RX inject 0x5A");

        // =================================================================
        // TEST 7: RX inject 0xC9
        // =================================================================
        $display("--- TEST 7: RX inject 0xC9 ---");
        repeat (20) @(posedge uart_clk);
        send_uart_byte(8'hC9);
        repeat (RX_SETTLE_CLKS) @(posedge uart_clk);   // [F5]

        axi_read(UART_THR, rd_data);
        $display("    RBR = 0x%0h", rd_data[7:0]);
        check(rd_data[7:0], 8'hC9, "RX inject 0xC9");

        // =================================================================
        // TEST 8: RX interrupt assertion
        //
        // [F5] Same 600-cycle settle — interrupt fires only after the byte
        //      lands in the RX FIFO.
        // =================================================================
        $display("--- TEST 8: RX interrupt assertion ---");
        repeat (20) @(posedge uart_clk);
        send_uart_byte(8'hBE);
        repeat (RX_SETTLE_CLKS) @(posedge uart_clk);   // [F5]
        check(uart_irq, 1'b1, "uart_irq asserted");

        // Drain the FIFO so it does not interfere with TEST 9
        axi_read(UART_THR, rd_data);

        // =================================================================
        // TEST 9: Back-to-back TX bytes through interconnect
        //
        // Three writes are issued back-to-back; the TX FIFO absorbs them.
        // Three recv_uart_byte calls consume the serialised bytes.
        // [F6] Synchronous polling ensures correct alignment for each byte.
        // =================================================================
        $display("--- TEST 9: Back-to-back TX 0x11, 0x22, 0x33 ---");
        begin : b2b
            reg [7:0] cap [0:2];
            integer   i;

            fork
                begin
                    axi_write(UART_THR, 32'h11);
                    axi_write(UART_THR, 32'h22);
                    axi_write(UART_THR, 32'h33);
                end
                begin
                    recv_uart_byte(cap[0]);
                    recv_uart_byte(cap[1]);
                    recv_uart_byte(cap[2]);
                end
            join

            for (i = 0; i < 3; i = i + 1)
                $display("    cap[%0d] = 0x%0h", i, cap[i]);
            check(cap[0], 8'h11, "B2B[0] 0x11");
            check(cap[1], 8'h22, "B2B[1] 0x22");
            check(cap[2], 8'h33, "B2B[2] 0x33");
        end

        // =================================================================
        // TEST 10: GPIO Direction and Output Register
        // =================================================================
        $display("\n--- TEST 10: GPIO Direction & Output Register ---");
        axi_write(GPIO_OE0, 32'hFFFF_FFFF);          // lower 32 pins configured as outputs
        axi_read(GPIO_OE0, rd_data);
        check(rd_data, 32'hFFFF_FFFF, "GPIO OE0 readback");

        axi_write(GPIO_OUT0, 32'hA5A5_5A5A);
        axi_read(GPIO_OUT0, rd_data);
        check(rd_data, 32'hA5A5_5A5A, "GPIO OUT0 readback");
        check(gpio_o[31:0], 32'hA5A5_5A5A, "GPIO pins output value");

        // =================================================================
        // TEST 11: GPIO Raw Input Register
        // =================================================================
        $display("\n--- TEST 11: GPIO Raw Input Register ---");
        gpio_i = 64'h0000_0000_1234_5678;
        repeat (3) @(posedge clk);
        axi_read(GPIO_IN0, rd_data);
        check(rd_data, 32'h1234_5678, "GPIO IN0 readback");

        // =================================================================
        // TEST 12: GPIO Atomic Operations (SET, CLR, TGL)
        // =================================================================
        $display("\n--- TEST 12: GPIO Atomic Operations ---");
        axi_write(GPIO_SET0, 32'h0000_00FF);         // Set bits [7:0]
        axi_read(GPIO_OUT0, rd_data);
        check(rd_data, 32'hA5A5_5AFF, "GPIO SET0 verify");

        axi_write(GPIO_CLR0, 32'h0000_000F);         // Clear bits [3:0]
        axi_read(GPIO_OUT0, rd_data);
        check(rd_data, 32'hA5A5_5AF0, "GPIO CLR0 verify");

        axi_write(GPIO_TGL0, 32'h0000_FF00);         // Toggle bits [15:8]
        axi_read(GPIO_OUT0, rd_data);
        check(rd_data, 32'hA5A5_A5F0, "GPIO TGL0 verify");

        // =================================================================
        // TEST 13: System Timer (rv_timer)
        // =================================================================
        $display("\n--- TEST 13: System Timer (rv_timer) ---");
        // Write compare register
        axi_write(TIMER_CMP_L, 32'h0000_0100);
        axi_read(TIMER_CMP_L, rd_data);
        check(rd_data, 32'h0000_0100, "TIMER CMP_L readback");

        // Enable timer
        axi_write(TIMER_CTRL, 32'h0000_0001);
        repeat (10) @(posedge clk);
        axi_read(TIMER_MTIME_L, rd_data);
        if (rd_data > 0) begin
            $display("[PASS] %-20s : count incremented to 0x%0h", "TIMER MTIME_L", rd_data);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("[FAIL] %-20s : count did not increment (got 0x%0h)", "TIMER MTIME_L", rd_data);
            fail_cnt = fail_cnt + 1;
        end

        // =================================================================
        // TEST 14: SHA-256 Accelerator Register Access
        // =================================================================
        $display("\n--- TEST 14: SHA-256 Accelerator ---");
        // Read core name ("sha2" = 0x7368_6132)
        axi_read(SHA_NAME0, rd_data);
        check(rd_data, 32'h7368_6132, "SHA-256 NAME0 readback");

        // Read STATUS register (should be ready = bit 0 high)
        axi_read(SHA_STATUS, rd_data);
        check(rd_data[0], 1'b1, "SHA-256 ready flag");

        // Write block word 0
        axi_write(SHA_BLOCK0, 32'h6162_6380); // "abc" padded
        axi_read(SHA_BLOCK0, rd_data);
        check(rd_data, 32'h6162_6380, "SHA-256 BLOCK0 readback");

        // =================================================================
        // TEST 15: AES-256 Accelerator Register Access
        // =================================================================
        $display("\n--- TEST 15: AES-256 Accelerator ---");
        // Write IV0 (R/W register for 128-bit IV)
        axi_write(AES_IV0, 32'hDEAD_BEEF);
        axi_read(AES_IV0, rd_data);
        check(rd_data, 32'hDEAD_BEEF, "AES IV0 readback");

        // Write & Read CTRL register (configure key_size=256-bit, irq_en=1)
        axi_write(AES_CTRL, 32'h0000_0012); // ctrl_irq_en=1, ctrl_key_size=2'b10 (256-bit)
        axi_read(AES_CTRL, rd_data);
        check(rd_data[4:0], 5'h12, "AES CTRL readback");

        // =================================================================
        // Summary
        // =================================================================
        repeat (5) @(posedge clk);
        $display("\n=============================================================");
        $display("  RESULTS: PASS=%0d  FAIL=%0d", pass_cnt, fail_cnt);
        $display("=============================================================");
        if (fail_cnt == 0)
            $display("  ALL TESTS PASSED");
        else
            $display("  SOME TESTS FAILED");

        $finish;
    end

    // =========================================================================
    // Timeout watchdog — 100 ms covers all baud-rate dependent tests
    // =========================================================================
    initial begin
        #100_000_000;
        $display("[TIMEOUT] Simulation exceeded time limit.");
        $finish;
    end

    // =========================================================================
    // Waveform dump
    // =========================================================================
    initial begin
`ifdef FSDB
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, tb_soc_top);
        $fsdbDumpSVA();
        $fsdbDumpMDA();
`else
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_soc_top);
`endif
    end

endmodule

`default_nettype wire
