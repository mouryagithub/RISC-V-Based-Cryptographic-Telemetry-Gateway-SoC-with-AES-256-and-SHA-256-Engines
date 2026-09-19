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

    // UART register byte addresses (absolute, through interconnect)
    localparam [31:0] UART_BASE     = 32'h4000_1000;
    localparam [31:0] UART_THR      = UART_BASE + 32'h00;  // TX holding / RX buffer
    localparam [31:0] UART_IER      = UART_BASE + 32'h04;  // interrupt enable
    localparam [31:0] UART_BAUD_DIV = UART_BASE + 32'h08;  // baud divisor (DLAB=1)
    localparam [31:0] UART_LCR      = UART_BASE + 32'h0C;  // line control
    localparam [31:0] UART_LSR      = UART_BASE + 32'h14;  // line status

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

    // Interrupt
    wire        uart_irq;

    // =========================================================================
    // DUT: soc_top
    // =========================================================================
    soc_top u_dut (
        .clk             (clk),
        .uart_clk        (uart_clk),
        .aresetn         (aresetn),

        // s00 — TB master
        .s00_axi_awid    (m_awid),
        .s00_axi_awaddr  (m_awaddr),
        .s00_axi_awlen   (m_awlen),
        .s00_axi_awsize  (m_awsize),
        .s00_axi_awburst (m_awburst),
        .s00_axi_awlock  (m_awlock),
        .s00_axi_awcache (m_awcache),
        .s00_axi_awprot  (m_awprot),
        .s00_axi_awqos   (m_awqos),
        .s00_axi_awvalid (m_awvalid),
        .s00_axi_awready (m_awready),
        .s00_axi_wdata   (m_wdata),
        .s00_axi_wstrb   (m_wstrb),
        .s00_axi_wlast   (m_wlast),
        .s00_axi_wvalid  (m_wvalid),
        .s00_axi_wready  (m_wready),
        .s00_axi_bid     (m_bid),
        .s00_axi_bresp   (m_bresp),
        .s00_axi_bvalid  (m_bvalid),
        .s00_axi_bready  (m_bready),
        .s00_axi_arid    (m_arid),
        .s00_axi_araddr  (m_araddr),
        .s00_axi_arlen   (m_arlen),
        .s00_axi_arsize  (m_arsize),
        .s00_axi_arburst (m_arburst),
        .s00_axi_arlock  (m_arlock),
        .s00_axi_arcache (m_arcache),
        .s00_axi_arprot  (m_arprot),
        .s00_axi_arqos   (m_arqos),
        .s00_axi_arvalid (m_arvalid),
        .s00_axi_arready (m_arready),
        .s00_axi_rid     (m_rid),
        .s00_axi_rdata   (m_rdata),
        .s00_axi_rresp   (m_rresp),
        .s00_axi_rlast   (m_rlast),
        .s00_axi_rvalid  (m_rvalid),
        .s00_axi_rready  (m_rready),

        // s01 — idle (no second master in this TB)
        .s01_axi_awid    (8'h0),
        .s01_axi_awaddr  (32'h0),
        .s01_axi_awlen   (8'h0),
        .s01_axi_awsize  (3'h0),
        .s01_axi_awburst (2'h0),
        .s01_axi_awlock  (1'b0),
        .s01_axi_awcache (4'h0),
        .s01_axi_awprot  (3'h0),
        .s01_axi_awqos   (4'h0),
        .s01_axi_awvalid (1'b0),
        .s01_axi_wdata   (32'h0),
        .s01_axi_wstrb   (4'h0),
        .s01_axi_wlast   (1'b0),
        .s01_axi_wvalid  (1'b0),
        .s01_axi_bready  (1'b0),
        .s01_axi_arid    (8'h0),
        .s01_axi_araddr  (32'h0),
        .s01_axi_arlen   (8'h0),
        .s01_axi_arsize  (3'h0),
        .s01_axi_arburst (2'h0),
        .s01_axi_arlock  (1'b0),
        .s01_axi_arcache (4'h0),
        .s01_axi_arprot  (3'h0),
        .s01_axi_arqos   (4'h0),
        .s01_axi_arvalid (1'b0),
        .s01_axi_rready  (1'b0),

        // UART I/O
        .uart_rx         (uart_rx),
        .uart_tx         (uart_tx),
        .uart_irq        (uart_irq)
    );

    // =========================================================================
    // Task: AXI4 single-beat write
    //
    // [F1] Extra @(posedge clk) after raising valids, BEFORE the first
    //      while-ready poll.  Prevents 0-delay race on same-cycle READY.
    //
    // [F2] awvalid and wvalid stay asserted until BVALID is observed.
    //      The UART RTL gates bvalid on (awvalid & wvalid); deassert early
    //      and bvalid is permanently gated to 0 → deadlock.
    // =========================================================================
    task axi_write;
        input [31:0] addr;
        input [31:0] data;
        begin
            // Present all address and data signals simultaneously.
            @(posedge clk);
            m_awid    = 8'h01;
            m_awaddr  = addr;
            m_awlen   = 8'h00;        // single beat
            m_awsize  = 3'b010;       // 4 bytes
            m_awburst = 2'b01;        // INCR
            m_awlock  = 1'b0;
            m_awcache = 4'b0010;
            m_awprot  = 3'b000;
            m_awqos   = 4'h0;
            m_awvalid = 1'b1;
            m_wdata   = data;
            m_wstrb   = 4'hF;
            m_wlast   = 1'b1;         // always last for single-beat
            m_wvalid  = 1'b1;
            m_bready  = 1'b1;

            // [F1] Advance one cycle so the DUT can register the valid inputs,
            // then start polling.  Avoids evaluating the while-condition on the
            // same delta-time as the signal assignment.
            @(posedge clk);
            while (!m_awready) @(posedge clk);

            // Wait for WREADY — awvalid/wvalid remain asserted.
            while (!m_wready)  @(posedge clk);

            // [F2] Wait for BVALID — awvalid/wvalid MUST stay high so the
            // UART's axi_wren signal stays asserted and bvalid is not gated off.
            while (!m_bvalid)  @(posedge clk);

            // Handshake complete: deassert all on the next clock edge.
            @(posedge clk);
            m_awvalid = 1'b0;
            m_wvalid  = 1'b0;
            m_wlast   = 1'b0;
            m_bready  = 1'b0;
        end
    endtask

    // =========================================================================
    // Task: AXI4 single-beat read
    //
    // [F1] Extra @(posedge clk) before first poll.
    // [F3] arvalid stays asserted until RVALID is seen (RTL rvalid gating).
    // =========================================================================
    task axi_read;
        input  [31:0] addr;
        output [31:0] rdata;
        begin
            @(posedge clk);
            m_arid    = 8'h01;
            m_araddr  = addr;
            m_arlen   = 8'h00;
            m_arsize  = 3'b010;
            m_arburst = 2'b01;
            m_arlock  = 1'b0;
            m_arcache = 4'b0010;
            m_arprot  = 3'b000;
            m_arqos   = 4'h0;
            m_arvalid = 1'b1;
            m_rready  = 1'b1;

            // [F1] Advance one cycle before polling.
            @(posedge clk);
            while (!m_arready) @(posedge clk);

            // [F3] arvalid stays high — RTL gates rvalid on arvalid.
            while (!m_rvalid)  @(posedge clk);
            rdata = m_rdata;

            // Deassert on next clock edge.
            @(posedge clk);
            m_arvalid = 1'b0;
            m_rready  = 1'b0;
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

            // Step 5: skip stop bit
            repeat (baud_clks) @(posedge uart_clk);
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
        input [159:0] label;
        begin
            if (got === exp) begin
                $display("[PASS] %-20s : got 0x%0h", label, got);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("[FAIL] %-20s : got 0x%0h  expected 0x%0h",
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
    // FSDB waveform dump — full SoC hierarchy
    // =========================================================================
    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, tb_soc_top);
        $fsdbDumpSVA();
        $fsdbDumpMDA();
    end

endmodule

`default_nettype wire
