// ============================================================================
// tb_axi_interconnect.sv
//
// Testbench for axi_interconnect_wrap_2x10
//   - 2 AXI4 Masters  (s00 / s01 ports of the wrapper)
//   - 10 AXI4 Slaves  (m00 – m09 ports of the wrapper)
//   - DATA_WIDTH = 64, ADDR_WIDTH = 32
//
// Tests:
//   1. Single-beat 64-bit AXI4 Write  : Master 0  ->  Slave 0  (m00)
//   2. Single-beat 64-bit AXI4 Read   : Master 0  ->  Slave 0  (m00)
//   3. Read-data == Write-data check   : PASS / FAIL
//
// Address map (M_REGIONS=1, M00_ADDR_WIDTH=24 => 16 MB window):
//   Slave 0  (m00): base = 32'h0000_0000, size = 2^24 = 16 MB
//   Slaves 1-9: non-overlapping 16 MB windows starting at 32'h0100_0000
//
// The wrapper convention (from the RTL):
//   s00/s01  = slave-side AXI ports  (driven by the Masters in this TB)
//   m00-m09  = master-side AXI ports (driven by the Slaves  in this TB)
// ============================================================================

`timescale 1ns/1ps

module tb_axi_interconnect;

    // -------------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------------
    localparam DATA_WIDTH  = 64;
    localparam ADDR_WIDTH  = 32;
    localparam STRB_WIDTH  = DATA_WIDTH / 8;   // 8
    localparam ID_WIDTH    = 8;
    localparam AWUSER_WIDTH = 1;
    localparam WUSER_WIDTH  = 1;
    localparam BUSER_WIDTH  = 1;
    localparam ARUSER_WIDTH = 1;
    localparam RUSER_WIDTH  = 1;

    // Slave 0 base address (m00) – must lie within M00_BASE_ADDR window
    localparam [ADDR_WIDTH-1:0] SLAVE0_BASE = 32'h0000_0000;
    localparam [ADDR_WIDTH-1:0] TEST_ADDR   = SLAVE0_BASE + 32'h0000_0100;
    localparam [DATA_WIDTH-1:0] TEST_DATA   = 64'hDEAD_BEEF_CAFE_1234;

    // Watchdog timeout in clock cycles
    localparam WATCHDOG_LIMIT = 10_000;

    // -------------------------------------------------------------------------
    // Clock & Reset
    // -------------------------------------------------------------------------
    logic clk;
    logic rst;

    initial clk = 0;
    always #5 clk = ~clk;   // 100 MHz

    // -------------------------------------------------------------------------
    // Master 0 AXI signals  (s00_axi_* in the DUT)
    // -------------------------------------------------------------------------
    // Write address channel
    logic [ID_WIDTH-1:0]     m0_awid;
    logic [ADDR_WIDTH-1:0]   m0_awaddr;
    logic [7:0]              m0_awlen;
    logic [2:0]              m0_awsize;
    logic [1:0]              m0_awburst;
    logic                    m0_awlock;
    logic [3:0]              m0_awcache;
    logic [2:0]              m0_awprot;
    logic [3:0]              m0_awqos;
    logic [AWUSER_WIDTH-1:0] m0_awuser;
    logic                    m0_awvalid;
    wire                     m0_awready;
    // Write data channel
    logic [DATA_WIDTH-1:0]   m0_wdata;
    logic [STRB_WIDTH-1:0]   m0_wstrb;
    logic                    m0_wlast;
    logic [WUSER_WIDTH-1:0]  m0_wuser;
    logic                    m0_wvalid;
    wire                     m0_wready;
    // Write response channel
    wire  [ID_WIDTH-1:0]     m0_bid;
    wire  [1:0]              m0_bresp;
    wire  [BUSER_WIDTH-1:0]  m0_buser;
    wire                     m0_bvalid;
    logic                    m0_bready;
    // Read address channel
    logic [ID_WIDTH-1:0]     m0_arid;
    logic [ADDR_WIDTH-1:0]   m0_araddr;
    logic [7:0]              m0_arlen;
    logic [2:0]              m0_arsize;
    logic [1:0]              m0_arburst;
    logic                    m0_arlock;
    logic [3:0]              m0_arcache;
    logic [2:0]              m0_arprot;
    logic [3:0]              m0_arqos;
    logic [ARUSER_WIDTH-1:0] m0_aruser;
    logic                    m0_arvalid;
    wire                     m0_arready;
    // Read data channel
    wire  [ID_WIDTH-1:0]     m0_rid;
    wire  [DATA_WIDTH-1:0]   m0_rdata;
    wire  [1:0]              m0_rresp;
    wire                     m0_rlast;
    wire  [RUSER_WIDTH-1:0]  m0_ruser;
    wire                     m0_rvalid;
    logic                    m0_rready;

    // -------------------------------------------------------------------------
    // Master 1 AXI signals  (s01_axi_* in the DUT) – all tied off / idle
    // -------------------------------------------------------------------------
    logic [ID_WIDTH-1:0]     m1_awid;
    logic [ADDR_WIDTH-1:0]   m1_awaddr;
    logic [7:0]              m1_awlen;
    logic [2:0]              m1_awsize;
    logic [1:0]              m1_awburst;
    logic                    m1_awlock;
    logic [3:0]              m1_awcache;
    logic [2:0]              m1_awprot;
    logic [3:0]              m1_awqos;
    logic [AWUSER_WIDTH-1:0] m1_awuser;
    logic                    m1_awvalid;
    wire                     m1_awready;
    logic [DATA_WIDTH-1:0]   m1_wdata;
    logic [STRB_WIDTH-1:0]   m1_wstrb;
    logic                    m1_wlast;
    logic [WUSER_WIDTH-1:0]  m1_wuser;
    logic                    m1_wvalid;
    wire                     m1_wready;
    wire  [ID_WIDTH-1:0]     m1_bid;
    wire  [1:0]              m1_bresp;
    wire  [BUSER_WIDTH-1:0]  m1_buser;
    wire                     m1_bvalid;
    logic                    m1_bready;
    logic [ID_WIDTH-1:0]     m1_arid;
    logic [ADDR_WIDTH-1:0]   m1_araddr;
    logic [7:0]              m1_arlen;
    logic [2:0]              m1_arsize;
    logic [1:0]              m1_arburst;
    logic                    m1_arlock;
    logic [3:0]              m1_arcache;
    logic [2:0]              m1_arprot;
    logic [3:0]              m1_arqos;
    logic [ARUSER_WIDTH-1:0] m1_aruser;
    logic                    m1_arvalid;
    wire                     m1_arready;
    wire  [ID_WIDTH-1:0]     m1_rid;
    wire  [DATA_WIDTH-1:0]   m1_rdata;
    wire  [1:0]              m1_rresp;
    wire                     m1_rlast;
    wire  [RUSER_WIDTH-1:0]  m1_ruser;
    wire                     m1_rvalid;
    logic                    m1_rready;

    // -------------------------------------------------------------------------
    // Slave 0 (m00_axi_*) – active responder with an internal memory register
    // -------------------------------------------------------------------------
    // Write address channel (from interconnect to slave)
    wire  [ID_WIDTH-1:0]     s0_awid;
    wire  [ADDR_WIDTH-1:0]   s0_awaddr;
    wire  [7:0]              s0_awlen;
    wire  [2:0]              s0_awsize;
    wire  [1:0]              s0_awburst;
    wire                     s0_awlock;
    wire  [3:0]              s0_awcache;
    wire  [2:0]              s0_awprot;
    wire  [3:0]              s0_awqos;
    wire  [3:0]              s0_awregion;
    wire  [AWUSER_WIDTH-1:0] s0_awuser;
    wire                     s0_awvalid;
    logic                    s0_awready;
    // Write data channel
    wire  [DATA_WIDTH-1:0]   s0_wdata;
    wire  [STRB_WIDTH-1:0]   s0_wstrb;
    wire                     s0_wlast;
    wire  [WUSER_WIDTH-1:0]  s0_wuser;
    wire                     s0_wvalid;
    logic                    s0_wready;
    // Write response channel (slave -> interconnect)
    logic [ID_WIDTH-1:0]     s0_bid;
    logic [1:0]              s0_bresp;
    logic [BUSER_WIDTH-1:0]  s0_buser;
    logic                    s0_bvalid;
    wire                     s0_bready;
    // Read address channel
    wire  [ID_WIDTH-1:0]     s0_arid;
    wire  [ADDR_WIDTH-1:0]   s0_araddr;
    wire  [7:0]              s0_arlen;
    wire  [2:0]              s0_arsize;
    wire  [1:0]              s0_arburst;
    wire                     s0_arlock;
    wire  [3:0]              s0_arcache;
    wire  [2:0]              s0_arprot;
    wire  [3:0]              s0_arqos;
    wire  [3:0]              s0_arregion;
    wire  [ARUSER_WIDTH-1:0] s0_aruser;
    wire                     s0_arvalid;
    logic                    s0_arready;
    // Read data channel (slave -> interconnect)
    logic [ID_WIDTH-1:0]     s0_rid;
    logic [DATA_WIDTH-1:0]   s0_rdata;
    logic [1:0]              s0_rresp;
    logic                    s0_rlast;
    logic [RUSER_WIDTH-1:0]  s0_ruser;
    logic                    s0_rvalid;
    wire                     s0_rready;

    // -------------------------------------------------------------------------
    // Dummy Slave 1-9 (m01-m09) signals – tied to constant ready values
    // -------------------------------------------------------------------------
    // Each slave: awready=1, wready=1, bvalid (registered), arready=1, rvalid (registered)
    // We use generate-friendly arrays for slaves 1..9
    wire  [ID_WIDTH-1:0]     ds_awid    [1:9];
    wire  [ADDR_WIDTH-1:0]   ds_awaddr  [1:9];
    wire  [7:0]              ds_awlen   [1:9];
    wire  [2:0]              ds_awsize  [1:9];
    wire  [1:0]              ds_awburst [1:9];
    wire                     ds_awlock  [1:9];
    wire  [3:0]              ds_awcache [1:9];
    wire  [2:0]              ds_awprot  [1:9];
    wire  [3:0]              ds_awqos   [1:9];
    wire  [3:0]              ds_awregion[1:9];
    wire  [AWUSER_WIDTH-1:0] ds_awuser  [1:9];
    wire                     ds_awvalid [1:9];
    logic                    ds_awready [1:9];

    wire  [DATA_WIDTH-1:0]   ds_wdata   [1:9];
    wire  [STRB_WIDTH-1:0]   ds_wstrb   [1:9];
    wire                     ds_wlast   [1:9];
    wire  [WUSER_WIDTH-1:0]  ds_wuser   [1:9];
    wire                     ds_wvalid  [1:9];
    logic                    ds_wready  [1:9];

    logic [ID_WIDTH-1:0]     ds_bid     [1:9];
    logic [1:0]              ds_bresp   [1:9];
    logic [BUSER_WIDTH-1:0]  ds_buser   [1:9];
    logic                    ds_bvalid  [1:9];
    wire                     ds_bready  [1:9];

    wire  [ID_WIDTH-1:0]     ds_arid    [1:9];
    wire  [ADDR_WIDTH-1:0]   ds_araddr  [1:9];
    wire  [7:0]              ds_arlen   [1:9];
    wire  [2:0]              ds_arsize  [1:9];
    wire  [1:0]              ds_arburst [1:9];
    wire                     ds_arlock  [1:9];
    wire  [3:0]              ds_arcache [1:9];
    wire  [2:0]              ds_arprot  [1:9];
    wire  [3:0]              ds_arqos   [1:9];
    wire  [3:0]              ds_arregion[1:9];
    wire  [ARUSER_WIDTH-1:0] ds_aruser  [1:9];
    wire                     ds_arvalid [1:9];
    logic                    ds_arready [1:9];

    logic [ID_WIDTH-1:0]     ds_rid     [1:9];
    logic [DATA_WIDTH-1:0]   ds_rdata   [1:9];
    logic [1:0]              ds_rresp   [1:9];
    logic                    ds_rlast   [1:9];
    logic [RUSER_WIDTH-1:0]  ds_ruser   [1:9];
    logic                    ds_rvalid  [1:9];
    wire                     ds_rready  [1:9];

    // =========================================================================
    // DUT Instantiation
    // =========================================================================
    axi_interconnect_wrap_2x10 #(
        .DATA_WIDTH   (DATA_WIDTH),
        .ADDR_WIDTH   (ADDR_WIDTH),
        .STRB_WIDTH   (STRB_WIDTH),
        .ID_WIDTH     (ID_WIDTH),
        // User signals disabled
        .AWUSER_ENABLE(0), .AWUSER_WIDTH(AWUSER_WIDTH),
        .WUSER_ENABLE (0), .WUSER_WIDTH (WUSER_WIDTH),
        .BUSER_ENABLE (0), .BUSER_WIDTH (BUSER_WIDTH),
        .ARUSER_ENABLE(0), .ARUSER_WIDTH(ARUSER_WIDTH),
        .RUSER_ENABLE (0), .RUSER_WIDTH (RUSER_WIDTH),
        .FORWARD_ID   (0),
        .M_REGIONS    (1),
        // Slave 0 (m00): 0x0000_0000 – 0x00FF_FFFF  (24-bit = 16 MB)
        .M00_BASE_ADDR (32'h0000_0000), .M00_ADDR_WIDTH({1{32'd24}}),
        .M00_CONNECT_READ(2'b11), .M00_CONNECT_WRITE(2'b11), .M00_SECURE(1'b0),
        // Slave 1 (m01): 0x0100_0000
        .M01_BASE_ADDR (32'h0100_0000), .M01_ADDR_WIDTH({1{32'd24}}),
        .M01_CONNECT_READ(2'b11), .M01_CONNECT_WRITE(2'b11), .M01_SECURE(1'b0),
        // Slave 2 (m02): 0x0200_0000
        .M02_BASE_ADDR (32'h0200_0000), .M02_ADDR_WIDTH({1{32'd24}}),
        .M02_CONNECT_READ(2'b11), .M02_CONNECT_WRITE(2'b11), .M02_SECURE(1'b0),
        // Slave 3 (m03): 0x0300_0000
        .M03_BASE_ADDR (32'h0300_0000), .M03_ADDR_WIDTH({1{32'd24}}),
        .M03_CONNECT_READ(2'b11), .M03_CONNECT_WRITE(2'b11), .M03_SECURE(1'b0),
        // Slave 4 (m04): 0x0400_0000
        .M04_BASE_ADDR (32'h0400_0000), .M04_ADDR_WIDTH({1{32'd24}}),
        .M04_CONNECT_READ(2'b11), .M04_CONNECT_WRITE(2'b11), .M04_SECURE(1'b0),
        // Slave 5 (m05): 0x0500_0000
        .M05_BASE_ADDR (32'h0500_0000), .M05_ADDR_WIDTH({1{32'd24}}),
        .M05_CONNECT_READ(2'b11), .M05_CONNECT_WRITE(2'b11), .M05_SECURE(1'b0),
        // Slave 6 (m06): 0x0600_0000
        .M06_BASE_ADDR (32'h0600_0000), .M06_ADDR_WIDTH({1{32'd24}}),
        .M06_CONNECT_READ(2'b11), .M06_CONNECT_WRITE(2'b11), .M06_SECURE(1'b0),
        // Slave 7 (m07): 0x0700_0000
        .M07_BASE_ADDR (32'h0700_0000), .M07_ADDR_WIDTH({1{32'd24}}),
        .M07_CONNECT_READ(2'b11), .M07_CONNECT_WRITE(2'b11), .M07_SECURE(1'b0),
        // Slave 8 (m08): 0x0800_0000
        .M08_BASE_ADDR (32'h0800_0000), .M08_ADDR_WIDTH({1{32'd24}}),
        .M08_CONNECT_READ(2'b11), .M08_CONNECT_WRITE(2'b11), .M08_SECURE(1'b0),
        // Slave 9 (m09): 0x0900_0000
        .M09_BASE_ADDR (32'h0900_0000), .M09_ADDR_WIDTH({1{32'd24}}),
        .M09_CONNECT_READ(2'b11), .M09_CONNECT_WRITE(2'b11), .M09_SECURE(1'b0)
    ) dut (
        .clk (clk),
        .rst (rst),

        // ---- Master 0 (AXI slave port s00) ----
        .s00_axi_awid    (m0_awid),
        .s00_axi_awaddr  (m0_awaddr),
        .s00_axi_awlen   (m0_awlen),
        .s00_axi_awsize  (m0_awsize),
        .s00_axi_awburst (m0_awburst),
        .s00_axi_awlock  (m0_awlock),
        .s00_axi_awcache (m0_awcache),
        .s00_axi_awprot  (m0_awprot),
        .s00_axi_awqos   (m0_awqos),
        .s00_axi_awuser  (m0_awuser),
        .s00_axi_awvalid (m0_awvalid),
        .s00_axi_awready (m0_awready),
        .s00_axi_wdata   (m0_wdata),
        .s00_axi_wstrb   (m0_wstrb),
        .s00_axi_wlast   (m0_wlast),
        .s00_axi_wuser   (m0_wuser),
        .s00_axi_wvalid  (m0_wvalid),
        .s00_axi_wready  (m0_wready),
        .s00_axi_bid     (m0_bid),
        .s00_axi_bresp   (m0_bresp),
        .s00_axi_buser   (m0_buser),
        .s00_axi_bvalid  (m0_bvalid),
        .s00_axi_bready  (m0_bready),
        .s00_axi_arid    (m0_arid),
        .s00_axi_araddr  (m0_araddr),
        .s00_axi_arlen   (m0_arlen),
        .s00_axi_arsize  (m0_arsize),
        .s00_axi_arburst (m0_arburst),
        .s00_axi_arlock  (m0_arlock),
        .s00_axi_arcache (m0_arcache),
        .s00_axi_arprot  (m0_arprot),
        .s00_axi_arqos   (m0_arqos),
        .s00_axi_aruser  (m0_aruser),
        .s00_axi_arvalid (m0_arvalid),
        .s00_axi_arready (m0_arready),
        .s00_axi_rid     (m0_rid),
        .s00_axi_rdata   (m0_rdata),
        .s00_axi_rresp   (m0_rresp),
        .s00_axi_rlast   (m0_rlast),
        .s00_axi_ruser   (m0_ruser),
        .s00_axi_rvalid  (m0_rvalid),
        .s00_axi_rready  (m0_rready),

        // ---- Master 1 (AXI slave port s01) – idle ----
        .s01_axi_awid    (m1_awid),
        .s01_axi_awaddr  (m1_awaddr),
        .s01_axi_awlen   (m1_awlen),
        .s01_axi_awsize  (m1_awsize),
        .s01_axi_awburst (m1_awburst),
        .s01_axi_awlock  (m1_awlock),
        .s01_axi_awcache (m1_awcache),
        .s01_axi_awprot  (m1_awprot),
        .s01_axi_awqos   (m1_awqos),
        .s01_axi_awuser  (m1_awuser),
        .s01_axi_awvalid (m1_awvalid),
        .s01_axi_awready (m1_awready),
        .s01_axi_wdata   (m1_wdata),
        .s01_axi_wstrb   (m1_wstrb),
        .s01_axi_wlast   (m1_wlast),
        .s01_axi_wuser   (m1_wuser),
        .s01_axi_wvalid  (m1_wvalid),
        .s01_axi_wready  (m1_wready),
        .s01_axi_bid     (m1_bid),
        .s01_axi_bresp   (m1_bresp),
        .s01_axi_buser   (m1_buser),
        .s01_axi_bvalid  (m1_bvalid),
        .s01_axi_bready  (m1_bready),
        .s01_axi_arid    (m1_arid),
        .s01_axi_araddr  (m1_araddr),
        .s01_axi_arlen   (m1_arlen),
        .s01_axi_arsize  (m1_arsize),
        .s01_axi_arburst (m1_arburst),
        .s01_axi_arlock  (m1_arlock),
        .s01_axi_arcache (m1_arcache),
        .s01_axi_arprot  (m1_arprot),
        .s01_axi_arqos   (m1_arqos),
        .s01_axi_aruser  (m1_aruser),
        .s01_axi_arvalid (m1_arvalid),
        .s01_axi_arready (m1_arready),
        .s01_axi_rid     (m1_rid),
        .s01_axi_rdata   (m1_rdata),
        .s01_axi_rresp   (m1_rresp),
        .s01_axi_rlast   (m1_rlast),
        .s01_axi_ruser   (m1_ruser),
        .s01_axi_rvalid  (m1_rvalid),
        .s01_axi_rready  (m1_rready),

        // ---- Slave 0 (AXI master port m00) – active responder ----
        .m00_axi_awid     (s0_awid),
        .m00_axi_awaddr   (s0_awaddr),
        .m00_axi_awlen    (s0_awlen),
        .m00_axi_awsize   (s0_awsize),
        .m00_axi_awburst  (s0_awburst),
        .m00_axi_awlock   (s0_awlock),
        .m00_axi_awcache  (s0_awcache),
        .m00_axi_awprot   (s0_awprot),
        .m00_axi_awqos    (s0_awqos),
        .m00_axi_awregion (s0_awregion),
        .m00_axi_awuser   (s0_awuser),
        .m00_axi_awvalid  (s0_awvalid),
        .m00_axi_awready  (s0_awready),
        .m00_axi_wdata    (s0_wdata),
        .m00_axi_wstrb    (s0_wstrb),
        .m00_axi_wlast    (s0_wlast),
        .m00_axi_wuser    (s0_wuser),
        .m00_axi_wvalid   (s0_wvalid),
        .m00_axi_wready   (s0_wready),
        .m00_axi_bid      (s0_bid),
        .m00_axi_bresp    (s0_bresp),
        .m00_axi_buser    (s0_buser),
        .m00_axi_bvalid   (s0_bvalid),
        .m00_axi_bready   (s0_bready),
        .m00_axi_arid     (s0_arid),
        .m00_axi_araddr   (s0_araddr),
        .m00_axi_arlen    (s0_arlen),
        .m00_axi_arsize   (s0_arsize),
        .m00_axi_arburst  (s0_arburst),
        .m00_axi_arlock   (s0_arlock),
        .m00_axi_arcache  (s0_arcache),
        .m00_axi_arprot   (s0_arprot),
        .m00_axi_arqos    (s0_arqos),
        .m00_axi_arregion (s0_arregion),
        .m00_axi_aruser   (s0_aruser),
        .m00_axi_arvalid  (s0_arvalid),
        .m00_axi_arready  (s0_arready),
        .m00_axi_rid      (s0_rid),
        .m00_axi_rdata    (s0_rdata),
        .m00_axi_rresp    (s0_rresp),
        .m00_axi_rlast    (s0_rlast),
        .m00_axi_ruser    (s0_ruser),
        .m00_axi_rvalid   (s0_rvalid),
        .m00_axi_rready   (s0_rready),

        // ---- Slaves 1–9 (AXI master ports m01–m09) – dummy responders ----
        .m01_axi_awid     (ds_awid[1]),    .m01_axi_awaddr(ds_awaddr[1]),
        .m01_axi_awlen    (ds_awlen[1]),   .m01_axi_awsize(ds_awsize[1]),
        .m01_axi_awburst  (ds_awburst[1]), .m01_axi_awlock(ds_awlock[1]),
        .m01_axi_awcache  (ds_awcache[1]), .m01_axi_awprot(ds_awprot[1]),
        .m01_axi_awqos    (ds_awqos[1]),   .m01_axi_awregion(ds_awregion[1]),
        .m01_axi_awuser   (ds_awuser[1]),  .m01_axi_awvalid(ds_awvalid[1]),
        .m01_axi_awready  (ds_awready[1]),
        .m01_axi_wdata    (ds_wdata[1]),   .m01_axi_wstrb(ds_wstrb[1]),
        .m01_axi_wlast    (ds_wlast[1]),   .m01_axi_wuser(ds_wuser[1]),
        .m01_axi_wvalid   (ds_wvalid[1]),  .m01_axi_wready(ds_wready[1]),
        .m01_axi_bid      (ds_bid[1]),     .m01_axi_bresp(ds_bresp[1]),
        .m01_axi_buser    (ds_buser[1]),   .m01_axi_bvalid(ds_bvalid[1]),
        .m01_axi_bready   (ds_bready[1]),
        .m01_axi_arid     (ds_arid[1]),    .m01_axi_araddr(ds_araddr[1]),
        .m01_axi_arlen    (ds_arlen[1]),   .m01_axi_arsize(ds_arsize[1]),
        .m01_axi_arburst  (ds_arburst[1]), .m01_axi_arlock(ds_arlock[1]),
        .m01_axi_arcache  (ds_arcache[1]), .m01_axi_arprot(ds_arprot[1]),
        .m01_axi_arqos    (ds_arqos[1]),   .m01_axi_arregion(ds_arregion[1]),
        .m01_axi_aruser   (ds_aruser[1]),  .m01_axi_arvalid(ds_arvalid[1]),
        .m01_axi_arready  (ds_arready[1]),
        .m01_axi_rid      (ds_rid[1]),     .m01_axi_rdata(ds_rdata[1]),
        .m01_axi_rresp    (ds_rresp[1]),   .m01_axi_rlast(ds_rlast[1]),
        .m01_axi_ruser    (ds_ruser[1]),   .m01_axi_rvalid(ds_rvalid[1]),
        .m01_axi_rready   (ds_rready[1]),

        .m02_axi_awid     (ds_awid[2]),    .m02_axi_awaddr(ds_awaddr[2]),
        .m02_axi_awlen    (ds_awlen[2]),   .m02_axi_awsize(ds_awsize[2]),
        .m02_axi_awburst  (ds_awburst[2]), .m02_axi_awlock(ds_awlock[2]),
        .m02_axi_awcache  (ds_awcache[2]), .m02_axi_awprot(ds_awprot[2]),
        .m02_axi_awqos    (ds_awqos[2]),   .m02_axi_awregion(ds_awregion[2]),
        .m02_axi_awuser   (ds_awuser[2]),  .m02_axi_awvalid(ds_awvalid[2]),
        .m02_axi_awready  (ds_awready[2]),
        .m02_axi_wdata    (ds_wdata[2]),   .m02_axi_wstrb(ds_wstrb[2]),
        .m02_axi_wlast    (ds_wlast[2]),   .m02_axi_wuser(ds_wuser[2]),
        .m02_axi_wvalid   (ds_wvalid[2]),  .m02_axi_wready(ds_wready[2]),
        .m02_axi_bid      (ds_bid[2]),     .m02_axi_bresp(ds_bresp[2]),
        .m02_axi_buser    (ds_buser[2]),   .m02_axi_bvalid(ds_bvalid[2]),
        .m02_axi_bready   (ds_bready[2]),
        .m02_axi_arid     (ds_arid[2]),    .m02_axi_araddr(ds_araddr[2]),
        .m02_axi_arlen    (ds_arlen[2]),   .m02_axi_arsize(ds_arsize[2]),
        .m02_axi_arburst  (ds_arburst[2]), .m02_axi_arlock(ds_arlock[2]),
        .m02_axi_arcache  (ds_arcache[2]), .m02_axi_arprot(ds_arprot[2]),
        .m02_axi_arqos    (ds_arqos[2]),   .m02_axi_arregion(ds_arregion[2]),
        .m02_axi_aruser   (ds_aruser[2]),  .m02_axi_arvalid(ds_arvalid[2]),
        .m02_axi_arready  (ds_arready[2]),
        .m02_axi_rid      (ds_rid[2]),     .m02_axi_rdata(ds_rdata[2]),
        .m02_axi_rresp    (ds_rresp[2]),   .m02_axi_rlast(ds_rlast[2]),
        .m02_axi_ruser    (ds_ruser[2]),   .m02_axi_rvalid(ds_rvalid[2]),
        .m02_axi_rready   (ds_rready[2]),

        .m03_axi_awid     (ds_awid[3]),    .m03_axi_awaddr(ds_awaddr[3]),
        .m03_axi_awlen    (ds_awlen[3]),   .m03_axi_awsize(ds_awsize[3]),
        .m03_axi_awburst  (ds_awburst[3]), .m03_axi_awlock(ds_awlock[3]),
        .m03_axi_awcache  (ds_awcache[3]), .m03_axi_awprot(ds_awprot[3]),
        .m03_axi_awqos    (ds_awqos[3]),   .m03_axi_awregion(ds_awregion[3]),
        .m03_axi_awuser   (ds_awuser[3]),  .m03_axi_awvalid(ds_awvalid[3]),
        .m03_axi_awready  (ds_awready[3]),
        .m03_axi_wdata    (ds_wdata[3]),   .m03_axi_wstrb(ds_wstrb[3]),
        .m03_axi_wlast    (ds_wlast[3]),   .m03_axi_wuser(ds_wuser[3]),
        .m03_axi_wvalid   (ds_wvalid[3]),  .m03_axi_wready(ds_wready[3]),
        .m03_axi_bid      (ds_bid[3]),     .m03_axi_bresp(ds_bresp[3]),
        .m03_axi_buser    (ds_buser[3]),   .m03_axi_bvalid(ds_bvalid[3]),
        .m03_axi_bready   (ds_bready[3]),
        .m03_axi_arid     (ds_arid[3]),    .m03_axi_araddr(ds_araddr[3]),
        .m03_axi_arlen    (ds_arlen[3]),   .m03_axi_arsize(ds_arsize[3]),
        .m03_axi_arburst  (ds_arburst[3]), .m03_axi_arlock(ds_arlock[3]),
        .m03_axi_arcache  (ds_arcache[3]), .m03_axi_arprot(ds_arprot[3]),
        .m03_axi_arqos    (ds_arqos[3]),   .m03_axi_arregion(ds_arregion[3]),
        .m03_axi_aruser   (ds_aruser[3]),  .m03_axi_arvalid(ds_arvalid[3]),
        .m03_axi_arready  (ds_arready[3]),
        .m03_axi_rid      (ds_rid[3]),     .m03_axi_rdata(ds_rdata[3]),
        .m03_axi_rresp    (ds_rresp[3]),   .m03_axi_rlast(ds_rlast[3]),
        .m03_axi_ruser    (ds_ruser[3]),   .m03_axi_rvalid(ds_rvalid[3]),
        .m03_axi_rready   (ds_rready[3]),

        .m04_axi_awid     (ds_awid[4]),    .m04_axi_awaddr(ds_awaddr[4]),
        .m04_axi_awlen    (ds_awlen[4]),   .m04_axi_awsize(ds_awsize[4]),
        .m04_axi_awburst  (ds_awburst[4]), .m04_axi_awlock(ds_awlock[4]),
        .m04_axi_awcache  (ds_awcache[4]), .m04_axi_awprot(ds_awprot[4]),
        .m04_axi_awqos    (ds_awqos[4]),   .m04_axi_awregion(ds_awregion[4]),
        .m04_axi_awuser   (ds_awuser[4]),  .m04_axi_awvalid(ds_awvalid[4]),
        .m04_axi_awready  (ds_awready[4]),
        .m04_axi_wdata    (ds_wdata[4]),   .m04_axi_wstrb(ds_wstrb[4]),
        .m04_axi_wlast    (ds_wlast[4]),   .m04_axi_wuser(ds_wuser[4]),
        .m04_axi_wvalid   (ds_wvalid[4]),  .m04_axi_wready(ds_wready[4]),
        .m04_axi_bid      (ds_bid[4]),     .m04_axi_bresp(ds_bresp[4]),
        .m04_axi_buser    (ds_buser[4]),   .m04_axi_bvalid(ds_bvalid[4]),
        .m04_axi_bready   (ds_bready[4]),
        .m04_axi_arid     (ds_arid[4]),    .m04_axi_araddr(ds_araddr[4]),
        .m04_axi_arlen    (ds_arlen[4]),   .m04_axi_arsize(ds_arsize[4]),
        .m04_axi_arburst  (ds_arburst[4]), .m04_axi_arlock(ds_arlock[4]),
        .m04_axi_arcache  (ds_arcache[4]), .m04_axi_arprot(ds_arprot[4]),
        .m04_axi_arqos    (ds_arqos[4]),   .m04_axi_arregion(ds_arregion[4]),
        .m04_axi_aruser   (ds_aruser[4]),  .m04_axi_arvalid(ds_arvalid[4]),
        .m04_axi_arready  (ds_arready[4]),
        .m04_axi_rid      (ds_rid[4]),     .m04_axi_rdata(ds_rdata[4]),
        .m04_axi_rresp    (ds_rresp[4]),   .m04_axi_rlast(ds_rlast[4]),
        .m04_axi_ruser    (ds_ruser[4]),   .m04_axi_rvalid(ds_rvalid[4]),
        .m04_axi_rready   (ds_rready[4]),

        .m05_axi_awid     (ds_awid[5]),    .m05_axi_awaddr(ds_awaddr[5]),
        .m05_axi_awlen    (ds_awlen[5]),   .m05_axi_awsize(ds_awsize[5]),
        .m05_axi_awburst  (ds_awburst[5]), .m05_axi_awlock(ds_awlock[5]),
        .m05_axi_awcache  (ds_awcache[5]), .m05_axi_awprot(ds_awprot[5]),
        .m05_axi_awqos    (ds_awqos[5]),   .m05_axi_awregion(ds_awregion[5]),
        .m05_axi_awuser   (ds_awuser[5]),  .m05_axi_awvalid(ds_awvalid[5]),
        .m05_axi_awready  (ds_awready[5]),
        .m05_axi_wdata    (ds_wdata[5]),   .m05_axi_wstrb(ds_wstrb[5]),
        .m05_axi_wlast    (ds_wlast[5]),   .m05_axi_wuser(ds_wuser[5]),
        .m05_axi_wvalid   (ds_wvalid[5]),  .m05_axi_wready(ds_wready[5]),
        .m05_axi_bid      (ds_bid[5]),     .m05_axi_bresp(ds_bresp[5]),
        .m05_axi_buser    (ds_buser[5]),   .m05_axi_bvalid(ds_bvalid[5]),
        .m05_axi_bready   (ds_bready[5]),
        .m05_axi_arid     (ds_arid[5]),    .m05_axi_araddr(ds_araddr[5]),
        .m05_axi_arlen    (ds_arlen[5]),   .m05_axi_arsize(ds_arsize[5]),
        .m05_axi_arburst  (ds_arburst[5]), .m05_axi_arlock(ds_arlock[5]),
        .m05_axi_arcache  (ds_arcache[5]), .m05_axi_arprot(ds_arprot[5]),
        .m05_axi_arqos    (ds_arqos[5]),   .m05_axi_arregion(ds_arregion[5]),
        .m05_axi_aruser   (ds_aruser[5]),  .m05_axi_arvalid(ds_arvalid[5]),
        .m05_axi_arready  (ds_arready[5]),
        .m05_axi_rid      (ds_rid[5]),     .m05_axi_rdata(ds_rdata[5]),
        .m05_axi_rresp    (ds_rresp[5]),   .m05_axi_rlast(ds_rlast[5]),
        .m05_axi_ruser    (ds_ruser[5]),   .m05_axi_rvalid(ds_rvalid[5]),
        .m05_axi_rready   (ds_rready[5]),

        .m06_axi_awid     (ds_awid[6]),    .m06_axi_awaddr(ds_awaddr[6]),
        .m06_axi_awlen    (ds_awlen[6]),   .m06_axi_awsize(ds_awsize[6]),
        .m06_axi_awburst  (ds_awburst[6]), .m06_axi_awlock(ds_awlock[6]),
        .m06_axi_awcache  (ds_awcache[6]), .m06_axi_awprot(ds_awprot[6]),
        .m06_axi_awqos    (ds_awqos[6]),   .m06_axi_awregion(ds_awregion[6]),
        .m06_axi_awuser   (ds_awuser[6]),  .m06_axi_awvalid(ds_awvalid[6]),
        .m06_axi_awready  (ds_awready[6]),
        .m06_axi_wdata    (ds_wdata[6]),   .m06_axi_wstrb(ds_wstrb[6]),
        .m06_axi_wlast    (ds_wlast[6]),   .m06_axi_wuser(ds_wuser[6]),
        .m06_axi_wvalid   (ds_wvalid[6]),  .m06_axi_wready(ds_wready[6]),
        .m06_axi_bid      (ds_bid[6]),     .m06_axi_bresp(ds_bresp[6]),
        .m06_axi_buser    (ds_buser[6]),   .m06_axi_bvalid(ds_bvalid[6]),
        .m06_axi_bready   (ds_bready[6]),
        .m06_axi_arid     (ds_arid[6]),    .m06_axi_araddr(ds_araddr[6]),
        .m06_axi_arlen    (ds_arlen[6]),   .m06_axi_arsize(ds_arsize[6]),
        .m06_axi_arburst  (ds_arburst[6]), .m06_axi_arlock(ds_arlock[6]),
        .m06_axi_arcache  (ds_arcache[6]), .m06_axi_arprot(ds_arprot[6]),
        .m06_axi_arqos    (ds_arqos[6]),   .m06_axi_arregion(ds_arregion[6]),
        .m06_axi_aruser   (ds_aruser[6]),  .m06_axi_arvalid(ds_arvalid[6]),
        .m06_axi_arready  (ds_arready[6]),
        .m06_axi_rid      (ds_rid[6]),     .m06_axi_rdata(ds_rdata[6]),
        .m06_axi_rresp    (ds_rresp[6]),   .m06_axi_rlast(ds_rlast[6]),
        .m06_axi_ruser    (ds_ruser[6]),   .m06_axi_rvalid(ds_rvalid[6]),
        .m06_axi_rready   (ds_rready[6]),

        .m07_axi_awid     (ds_awid[7]),    .m07_axi_awaddr(ds_awaddr[7]),
        .m07_axi_awlen    (ds_awlen[7]),   .m07_axi_awsize(ds_awsize[7]),
        .m07_axi_awburst  (ds_awburst[7]), .m07_axi_awlock(ds_awlock[7]),
        .m07_axi_awcache  (ds_awcache[7]), .m07_axi_awprot(ds_awprot[7]),
        .m07_axi_awqos    (ds_awqos[7]),   .m07_axi_awregion(ds_awregion[7]),
        .m07_axi_awuser   (ds_awuser[7]),  .m07_axi_awvalid(ds_awvalid[7]),
        .m07_axi_awready  (ds_awready[7]),
        .m07_axi_wdata    (ds_wdata[7]),   .m07_axi_wstrb(ds_wstrb[7]),
        .m07_axi_wlast    (ds_wlast[7]),   .m07_axi_wuser(ds_wuser[7]),
        .m07_axi_wvalid   (ds_wvalid[7]),  .m07_axi_wready(ds_wready[7]),
        .m07_axi_bid      (ds_bid[7]),     .m07_axi_bresp(ds_bresp[7]),
        .m07_axi_buser    (ds_buser[7]),   .m07_axi_bvalid(ds_bvalid[7]),
        .m07_axi_bready   (ds_bready[7]),
        .m07_axi_arid     (ds_arid[7]),    .m07_axi_araddr(ds_araddr[7]),
        .m07_axi_arlen    (ds_arlen[7]),   .m07_axi_arsize(ds_arsize[7]),
        .m07_axi_arburst  (ds_arburst[7]), .m07_axi_arlock(ds_arlock[7]),
        .m07_axi_arcache  (ds_arcache[7]), .m07_axi_arprot(ds_arprot[7]),
        .m07_axi_arqos    (ds_arqos[7]),   .m07_axi_arregion(ds_arregion[7]),
        .m07_axi_aruser   (ds_aruser[7]),  .m07_axi_arvalid(ds_arvalid[7]),
        .m07_axi_arready  (ds_arready[7]),
        .m07_axi_rid      (ds_rid[7]),     .m07_axi_rdata(ds_rdata[7]),
        .m07_axi_rresp    (ds_rresp[7]),   .m07_axi_rlast(ds_rlast[7]),
        .m07_axi_ruser    (ds_ruser[7]),   .m07_axi_rvalid(ds_rvalid[7]),
        .m07_axi_rready   (ds_rready[7]),

        .m08_axi_awid     (ds_awid[8]),    .m08_axi_awaddr(ds_awaddr[8]),
        .m08_axi_awlen    (ds_awlen[8]),   .m08_axi_awsize(ds_awsize[8]),
        .m08_axi_awburst  (ds_awburst[8]), .m08_axi_awlock(ds_awlock[8]),
        .m08_axi_awcache  (ds_awcache[8]), .m08_axi_awprot(ds_awprot[8]),
        .m08_axi_awqos    (ds_awqos[8]),   .m08_axi_awregion(ds_awregion[8]),
        .m08_axi_awuser   (ds_awuser[8]),  .m08_axi_awvalid(ds_awvalid[8]),
        .m08_axi_awready  (ds_awready[8]),
        .m08_axi_wdata    (ds_wdata[8]),   .m08_axi_wstrb(ds_wstrb[8]),
        .m08_axi_wlast    (ds_wlast[8]),   .m08_axi_wuser(ds_wuser[8]),
        .m08_axi_wvalid   (ds_wvalid[8]),  .m08_axi_wready(ds_wready[8]),
        .m08_axi_bid      (ds_bid[8]),     .m08_axi_bresp(ds_bresp[8]),
        .m08_axi_buser    (ds_buser[8]),   .m08_axi_bvalid(ds_bvalid[8]),
        .m08_axi_bready   (ds_bready[8]),
        .m08_axi_arid     (ds_arid[8]),    .m08_axi_araddr(ds_araddr[8]),
        .m08_axi_arlen    (ds_arlen[8]),   .m08_axi_arsize(ds_arsize[8]),
        .m08_axi_arburst  (ds_arburst[8]), .m08_axi_arlock(ds_arlock[8]),
        .m08_axi_arcache  (ds_arcache[8]), .m08_axi_arprot(ds_arprot[8]),
        .m08_axi_arqos    (ds_arqos[8]),   .m08_axi_arregion(ds_arregion[8]),
        .m08_axi_aruser   (ds_aruser[8]),  .m08_axi_arvalid(ds_arvalid[8]),
        .m08_axi_arready  (ds_arready[8]),
        .m08_axi_rid      (ds_rid[8]),     .m08_axi_rdata(ds_rdata[8]),
        .m08_axi_rresp    (ds_rresp[8]),   .m08_axi_rlast(ds_rlast[8]),
        .m08_axi_ruser    (ds_ruser[8]),   .m08_axi_rvalid(ds_rvalid[8]),
        .m08_axi_rready   (ds_rready[8]),

        .m09_axi_awid     (ds_awid[9]),    .m09_axi_awaddr(ds_awaddr[9]),
        .m09_axi_awlen    (ds_awlen[9]),   .m09_axi_awsize(ds_awsize[9]),
        .m09_axi_awburst  (ds_awburst[9]), .m09_axi_awlock(ds_awlock[9]),
        .m09_axi_awcache  (ds_awcache[9]), .m09_axi_awprot(ds_awprot[9]),
        .m09_axi_awqos    (ds_awqos[9]),   .m09_axi_awregion(ds_awregion[9]),
        .m09_axi_awuser   (ds_awuser[9]),  .m09_axi_awvalid(ds_awvalid[9]),
        .m09_axi_awready  (ds_awready[9]),
        .m09_axi_wdata    (ds_wdata[9]),   .m09_axi_wstrb(ds_wstrb[9]),
        .m09_axi_wlast    (ds_wlast[9]),   .m09_axi_wuser(ds_wuser[9]),
        .m09_axi_wvalid   (ds_wvalid[9]),  .m09_axi_wready(ds_wready[9]),
        .m09_axi_bid      (ds_bid[9]),     .m09_axi_bresp(ds_bresp[9]),
        .m09_axi_buser    (ds_buser[9]),   .m09_axi_bvalid(ds_bvalid[9]),
        .m09_axi_bready   (ds_bready[9]),
        .m09_axi_arid     (ds_arid[9]),    .m09_axi_araddr(ds_araddr[9]),
        .m09_axi_arlen    (ds_arlen[9]),   .m09_axi_arsize(ds_arsize[9]),
        .m09_axi_arburst  (ds_arburst[9]), .m09_axi_arlock(ds_arlock[9]),
        .m09_axi_arcache  (ds_arcache[9]), .m09_axi_arprot(ds_arprot[9]),
        .m09_axi_arqos    (ds_arqos[9]),   .m09_axi_arregion(ds_arregion[9]),
        .m09_axi_aruser   (ds_aruser[9]),  .m09_axi_arvalid(ds_arvalid[9]),
        .m09_axi_arready  (ds_arready[9]),
        .m09_axi_rid      (ds_rid[9]),     .m09_axi_rdata(ds_rdata[9]),
        .m09_axi_rresp    (ds_rresp[9]),   .m09_axi_rlast(ds_rlast[9]),
        .m09_axi_ruser    (ds_ruser[9]),   .m09_axi_rvalid(ds_rvalid[9]),
        .m09_axi_rready   (ds_rready[9])
    );

    // =========================================================================
    // Dummy Master 1 – permanently idle (all valid signals = 0)
    // =========================================================================
    assign m1_awid    = '0;
    assign m1_awaddr  = '0;
    assign m1_awlen   = '0;
    assign m1_awsize  = '0;
    assign m1_awburst = 2'b01;
    assign m1_awlock  = 1'b0;
    assign m1_awcache = '0;
    assign m1_awprot  = '0;
    assign m1_awqos   = '0;
    assign m1_awuser  = '0;
    assign m1_awvalid = 1'b0;
    assign m1_wdata   = '0;
    assign m1_wstrb   = '0;
    assign m1_wlast   = 1'b0;
    assign m1_wuser   = '0;
    assign m1_wvalid  = 1'b0;
    assign m1_bready  = 1'b1;
    assign m1_arid    = '0;
    assign m1_araddr  = '0;
    assign m1_arlen   = '0;
    assign m1_arsize  = '0;
    assign m1_arburst = 2'b01;
    assign m1_arlock  = 1'b0;
    assign m1_arcache = '0;
    assign m1_arprot  = '0;
    assign m1_arqos   = '0;
    assign m1_aruser  = '0;
    assign m1_arvalid = 1'b0;
    assign m1_rready  = 1'b1;

    // =========================================================================
    // Dummy Slaves 1–9 – always-ready responders
    // =========================================================================
    // State registers for W/R response generation per dummy slave
    logic [ID_WIDTH-1:0] ds_pending_bid  [1:9];
    logic [ID_WIDTH-1:0] ds_pending_rid  [1:9];
    logic                ds_aw_captured  [1:9];
    logic                ds_w_captured   [1:9];
    logic                ds_ar_captured  [1:9];

    genvar gi;
    generate
        for (gi = 1; gi <= 9; gi++) begin : g_dummy_slave
            // AW/W channels: always ready
            always_comb begin
                ds_awready[gi] = 1'b1;
                ds_wready[gi]  = 1'b1;
                ds_arready[gi] = 1'b1;
            end

            // B channel: respond one cycle after AW+W accepted
            always_ff @(posedge clk or posedge rst) begin
                if (rst) begin
                    ds_bvalid[gi]      <= 1'b0;
                    ds_bid[gi]         <= '0;
                    ds_bresp[gi]       <= 2'b00;
                    ds_buser[gi]       <= '0;
                    ds_aw_captured[gi] <= 1'b0;
                    ds_w_captured[gi]  <= 1'b0;
                    ds_pending_bid[gi] <= '0;
                end else begin
                    // Capture AW
                    if (ds_awvalid[gi] && ds_awready[gi]) begin
                        ds_pending_bid[gi] <= ds_awid[gi];
                        ds_aw_captured[gi] <= 1'b1;
                    end
                    // Capture W last beat
                    if (ds_wvalid[gi] && ds_wready[gi] && ds_wlast[gi]) begin
                        ds_w_captured[gi] <= 1'b1;
                    end
                    // Issue B response once both AW and W are captured
                    if (ds_aw_captured[gi] && ds_w_captured[gi] && !ds_bvalid[gi]) begin
                        ds_bvalid[gi]      <= 1'b1;
                        ds_bid[gi]         <= ds_pending_bid[gi];
                        ds_bresp[gi]       <= 2'b00; // OKAY
                        ds_buser[gi]       <= '0;
                        ds_aw_captured[gi] <= 1'b0;
                        ds_w_captured[gi]  <= 1'b0;
                    end
                    // Clear B when accepted
                    if (ds_bvalid[gi] && ds_bready[gi]) begin
                        ds_bvalid[gi] <= 1'b0;
                    end
                end
            end

            // R channel: respond one cycle after AR accepted
            always_ff @(posedge clk or posedge rst) begin
                if (rst) begin
                    ds_rvalid[gi]      <= 1'b0;
                    ds_rid[gi]         <= '0;
                    ds_rdata[gi]       <= '0;
                    ds_rresp[gi]       <= 2'b00;
                    ds_rlast[gi]       <= 1'b0;
                    ds_ruser[gi]       <= '0;
                    ds_ar_captured[gi] <= 1'b0;
                    ds_pending_rid[gi] <= '0;
                end else begin
                    if (ds_arvalid[gi] && ds_arready[gi]) begin
                        ds_pending_rid[gi] <= ds_arid[gi];
                        ds_ar_captured[gi] <= 1'b1;
                    end
                    if (ds_ar_captured[gi] && !ds_rvalid[gi]) begin
                        ds_rvalid[gi]      <= 1'b1;
                        ds_rid[gi]         <= ds_pending_rid[gi];
                        ds_rdata[gi]       <= '0;   // return zero for dummy slaves
                        ds_rresp[gi]       <= 2'b00;
                        ds_rlast[gi]       <= 1'b1;
                        ds_ruser[gi]       <= '0;
                        ds_ar_captured[gi] <= 1'b0;
                    end
                    if (ds_rvalid[gi] && ds_rready[gi]) begin
                        ds_rvalid[gi] <= 1'b0;
                        ds_rlast[gi]  <= 1'b0;
                    end
                end
            end
        end
    endgenerate

    // =========================================================================
    // Active Slave 0 (m00) – single-register memory model
    // =========================================================================
    logic [DATA_WIDTH-1:0] slave0_mem;  // the one storage element

    // Write-side state machine
    typedef enum logic [1:0] {
        S0_WR_IDLE,
        S0_WR_DATA,
        S0_WR_RESP
    } s0_wr_state_t;

    s0_wr_state_t s0_wr_state;
    logic [ID_WIDTH-1:0] s0_pending_bid_reg;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            s0_wr_state        <= S0_WR_IDLE;
            s0_awready         <= 1'b1;
            s0_wready          <= 1'b0;
            s0_bvalid          <= 1'b0;
            s0_bid             <= '0;
            s0_bresp           <= 2'b00;
            s0_buser           <= '0;
            slave0_mem         <= '0;
            s0_pending_bid_reg <= '0;
        end else begin
            case (s0_wr_state)
                S0_WR_IDLE: begin
                    s0_bvalid <= 1'b0;
                    if (s0_awvalid && s0_awready) begin
                        s0_pending_bid_reg <= s0_awid;
                        s0_awready         <= 1'b0;
                        s0_wready          <= 1'b1;
                        s0_wr_state        <= S0_WR_DATA;
                    end
                end
                S0_WR_DATA: begin
                    if (s0_wvalid && s0_wready) begin
                        // Byte-enable-aware write
                        for (int b = 0; b < STRB_WIDTH; b++) begin
                            if (s0_wstrb[b])
                                slave0_mem[b*8 +: 8] <= s0_wdata[b*8 +: 8];
                        end
                        s0_wready   <= 1'b0;
                        s0_bvalid   <= 1'b1;
                        s0_bid      <= s0_pending_bid_reg;
                        s0_bresp    <= 2'b00;
                        s0_buser    <= '0;
                        s0_wr_state <= S0_WR_RESP;
                    end
                end
                S0_WR_RESP: begin
                    if (s0_bvalid && s0_bready) begin
                        s0_bvalid   <= 1'b0;
                        s0_awready  <= 1'b1;
                        s0_wr_state <= S0_WR_IDLE;
                    end
                end
                default: s0_wr_state <= S0_WR_IDLE;
            endcase
        end
    end

    // Read-side state machine
    typedef enum logic [1:0] {
        S0_RD_IDLE,
        S0_RD_DATA,
        S0_RD_WAIT
    } s0_rd_state_t;

    s0_rd_state_t s0_rd_state;
    logic [ID_WIDTH-1:0] s0_pending_rid_reg;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            s0_rd_state        <= S0_RD_IDLE;
            s0_arready         <= 1'b1;
            s0_rvalid          <= 1'b0;
            s0_rid             <= '0;
            s0_rdata           <= '0;
            s0_rresp           <= 2'b00;
            s0_rlast           <= 1'b0;
            s0_ruser           <= '0;
            s0_pending_rid_reg <= '0;
        end else begin
            case (s0_rd_state)
                S0_RD_IDLE: begin
                    s0_rvalid <= 1'b0;
                    if (s0_arvalid && s0_arready) begin
                        s0_pending_rid_reg <= s0_arid;
                        s0_arready         <= 1'b0;
                        s0_rvalid          <= 1'b1;
                        s0_rid             <= s0_arid;
                        s0_rdata           <= slave0_mem;
                        s0_rresp           <= 2'b00;
                        s0_rlast           <= 1'b1;
                        s0_ruser           <= '0;
                        s0_rd_state        <= S0_RD_DATA;
                    end
                end
                S0_RD_DATA: begin
                    if (s0_rvalid && s0_rready) begin
                        s0_rvalid   <= 1'b0;
                        s0_rlast    <= 1'b0;
                        s0_arready  <= 1'b1;
                        s0_rd_state <= S0_RD_IDLE;
                    end
                end
                default: s0_rd_state <= S0_RD_IDLE;
            endcase
        end
    end

    // =========================================================================
    // Watchdog Timer
    // =========================================================================
    int unsigned watchdog_cnt;
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            watchdog_cnt <= 0;
        end else begin
            watchdog_cnt <= watchdog_cnt + 1;
            if (watchdog_cnt >= WATCHDOG_LIMIT) begin
                $display("WATCHDOG TIMEOUT at cycle %0d – simulation aborted.", watchdog_cnt);
                $finish;
            end
        end
    end

    // =========================================================================
    // Main Test Stimulus – Master 0
    // =========================================================================
    logic [DATA_WIDTH-1:0] read_data_capture;

    // Default all Master 0 outputs to idle values
    task automatic m0_idle();
        m0_awid    = '0;
        m0_awaddr  = '0;
        m0_awlen   = 8'h00;
        m0_awsize  = 3'b011; // 8 bytes for 64-bit
        m0_awburst = 2'b01;  // INCR
        m0_awlock  = 1'b0;
        m0_awcache = 4'b0000;
        m0_awprot  = 3'b000;
        m0_awqos   = 4'b0000;
        m0_awuser  = '0;
        m0_awvalid = 1'b0;
        m0_wdata   = '0;
        m0_wstrb   = '0;
        m0_wlast   = 1'b0;
        m0_wuser   = '0;
        m0_wvalid  = 1'b0;
        m0_bready  = 1'b1;
        m0_arid    = '0;
        m0_araddr  = '0;
        m0_arlen   = 8'h00;
        m0_arsize  = 3'b011;
        m0_arburst = 2'b01;
        m0_arlock  = 1'b0;
        m0_arcache = 4'b0000;
        m0_arprot  = 3'b000;
        m0_arqos   = 4'b0000;
        m0_aruser  = '0;
        m0_arvalid = 1'b0;
        m0_rready  = 1'b1;
    endtask

    // AXI4 single-beat write task
    // Drives AW and W simultaneously (both valid asserted at the same time),
    // then waits for B response.
    task automatic axi4_write(
        input  [ADDR_WIDTH-1:0] addr,
        input  [DATA_WIDTH-1:0] data,
        input  [STRB_WIDTH-1:0] strb
    );
        // Assert AW and W simultaneously
        @(posedge clk);
        #1;
        m0_awid    = 8'h01;
        m0_awaddr  = addr;
        m0_awlen   = 8'h00;      // single beat
        m0_awsize  = 3'b011;     // 8 bytes
        m0_awburst = 2'b01;      // INCR
        m0_awlock  = 1'b0;
        m0_awcache = 4'b0000;
        m0_awprot  = 3'b000;
        m0_awqos   = 4'b0000;
        m0_awuser  = '0;
        m0_awvalid = 1'b1;
        m0_wdata   = data;
        m0_wstrb   = strb;
        m0_wlast   = 1'b1;
        m0_wuser   = '0;
        m0_wvalid  = 1'b1;
        m0_bready  = 1'b1;

        // Wait for AW handshake
        do @(posedge clk); while (!m0_awready);
        #1;
        m0_awvalid = 1'b0;

        // Wait for W handshake
        do @(posedge clk); while (!m0_wready);
        #1;
        m0_wvalid = 1'b0;
        m0_wlast  = 1'b0;

        // Wait for B response
        do @(posedge clk); while (!m0_bvalid);
        $display("[WRITE] addr=0x%08h data=0x%016h bresp=%0b", addr, data, m0_bresp);
        #1;
        m0_bready = 1'b0;
        @(posedge clk);
        #1;
        m0_bready = 1'b1;
    endtask

    // AXI4 single-beat read task
    task automatic axi4_read(
        input  [ADDR_WIDTH-1:0] addr,
        output [DATA_WIDTH-1:0] rdata
    );
        @(posedge clk);
        #1;
        m0_arid    = 8'h01;
        m0_araddr  = addr;
        m0_arlen   = 8'h00;   // single beat
        m0_arsize  = 3'b011;  // 8 bytes
        m0_arburst = 2'b01;   // INCR
        m0_arlock  = 1'b0;
        m0_arcache = 4'b0000;
        m0_arprot  = 3'b000;
        m0_arqos   = 4'b0000;
        m0_aruser  = '0;
        m0_arvalid = 1'b1;
        m0_rready  = 1'b1;

        // Wait for AR handshake
        do @(posedge clk); while (!m0_arready);
        #1;
        m0_arvalid = 1'b0;

        // Wait for R beat
        do @(posedge clk); while (!m0_rvalid);
        rdata = m0_rdata;
        $display("[READ]  addr=0x%08h data=0x%016h rresp=%0b rlast=%0b",
                 addr, m0_rdata, m0_rresp, m0_rlast);
        @(posedge clk);
        #1;
        m0_rready = 1'b0;
        @(posedge clk);
        #1;
        m0_rready = 1'b1;
    endtask

    // =========================================================================
    // Test Sequence
    // =========================================================================
    initial begin
        // ----- Initialise all Master 0 outputs -----
        m0_idle();

        // ----- Reset -----
        rst = 1'b1;
        repeat (10) @(posedge clk);
        #1;
        rst = 1'b0;
        repeat (5) @(posedge clk);

        $display("====================================================");
        $display(" AXI4 Interconnect Testbench  (2 Masters, 10 Slaves)");
        $display("====================================================");

        // ----- Test 1: Single-beat 64-bit Write (Master 0 -> Slave 0) -----
        $display("[INFO] Starting AXI4 Write transaction ...");
        axi4_write(TEST_ADDR, TEST_DATA, {STRB_WIDTH{1'b1}});

        // ----- Test 2: Single-beat 64-bit Read  (Master 0 -> Slave 0) -----
        $display("[INFO] Starting AXI4 Read transaction ...");
        axi4_read(TEST_ADDR, read_data_capture);

        // ----- Test 3: Verification -----
        $display("====================================================");
        if (read_data_capture === TEST_DATA) begin
            $display(" RESULT : PASS");
            $display(" Written : 0x%016h", TEST_DATA);
            $display(" Read    : 0x%016h", read_data_capture);
        end else begin
            $display(" RESULT : FAIL");
            $display(" Expected : 0x%016h", TEST_DATA);
            $display(" Got      : 0x%016h", read_data_capture);
        end
        $display("====================================================");

        repeat (10) @(posedge clk);
        $finish;
    end
endmodule
