// =============================================================================
// File        : soc_top.v
// Project     : RISC-V Cryptographic Telemetry Gateway SoC
// Description : SoC top-level integrating the 2x10 AXI interconnect with:
//                 m00 → tied off (AES removed for UART-only verification)
//                 m01 → axi_uart_top  (AXI4-Lite UART with 16-byte FIFOs)
//                 m02–m09 → tied off (placeholder for future peripherals)
//
// Address Map
// -----------
//   Slave  Module          Base Address   Size   Decode Width
//   m01    UART            0x4000_1000    256 B   8 bits
//   m00,m02-09 (reserved)  (tied off)
//
// =============================================================================

`timescale 1ns/1ps
`default_nettype none

module soc_top (
    // -------------------------------------------------------------------------
    // Clocks & Reset
    // -------------------------------------------------------------------------
    input  wire         clk,         // Primary AXI clock  (50 MHz)
    input  wire         uart_clk,    // Fixed clock for UART baud engine (50 MHz)
    input  wire         aresetn,     // Active-LOW synchronous reset

    // -------------------------------------------------------------------------
    // AXI4 Slave Port 0  (CPU / DMA master 0)
    // -------------------------------------------------------------------------
    input  wire [7:0]   s00_axi_awid,
    input  wire [31:0]  s00_axi_awaddr,
    input  wire [7:0]   s00_axi_awlen,
    input  wire [2:0]   s00_axi_awsize,
    input  wire [1:0]   s00_axi_awburst,
    input  wire         s00_axi_awlock,
    input  wire [3:0]   s00_axi_awcache,
    input  wire [2:0]   s00_axi_awprot,
    input  wire [3:0]   s00_axi_awqos,
    input  wire         s00_axi_awvalid,
    output wire         s00_axi_awready,
    input  wire [31:0]  s00_axi_wdata,
    input  wire [3:0]   s00_axi_wstrb,
    input  wire         s00_axi_wlast,
    input  wire         s00_axi_wvalid,
    output wire         s00_axi_wready,
    output wire [7:0]   s00_axi_bid,
    output wire [1:0]   s00_axi_bresp,
    output wire         s00_axi_bvalid,
    input  wire         s00_axi_bready,
    input  wire [7:0]   s00_axi_arid,
    input  wire [31:0]  s00_axi_araddr,
    input  wire [7:0]   s00_axi_arlen,
    input  wire [2:0]   s00_axi_arsize,
    input  wire [1:0]   s00_axi_arburst,
    input  wire         s00_axi_arlock,
    input  wire [3:0]   s00_axi_arcache,
    input  wire [2:0]   s00_axi_arprot,
    input  wire [3:0]   s00_axi_arqos,
    input  wire         s00_axi_arvalid,
    output wire         s00_axi_arready,
    output wire [7:0]   s00_axi_rid,
    output wire [31:0]  s00_axi_rdata,
    output wire [1:0]   s00_axi_rresp,
    output wire         s00_axi_rlast,
    output wire         s00_axi_rvalid,
    input  wire         s00_axi_rready,

    // -------------------------------------------------------------------------
    // AXI4 Slave Port 1  (CPU / DMA master 1)
    // -------------------------------------------------------------------------
    input  wire [7:0]   s01_axi_awid,
    input  wire [31:0]  s01_axi_awaddr,
    input  wire [7:0]   s01_axi_awlen,
    input  wire [2:0]   s01_axi_awsize,
    input  wire [1:0]   s01_axi_awburst,
    input  wire         s01_axi_awlock,
    input  wire [3:0]   s01_axi_awcache,
    input  wire [2:0]   s01_axi_awprot,
    input  wire [3:0]   s01_axi_awqos,
    input  wire         s01_axi_awvalid,
    output wire         s01_axi_awready,
    input  wire [31:0]  s01_axi_wdata,
    input  wire [3:0]   s01_axi_wstrb,
    input  wire         s01_axi_wlast,
    input  wire         s01_axi_wvalid,
    output wire         s01_axi_wready,
    output wire [7:0]   s01_axi_bid,
    output wire [1:0]   s01_axi_bresp,
    output wire         s01_axi_bvalid,
    input  wire         s01_axi_bready,
    input  wire [7:0]   s01_axi_arid,
    input  wire [31:0]  s01_axi_araddr,
    input  wire [7:0]   s01_axi_arlen,
    input  wire [2:0]   s01_axi_arsize,
    input  wire [1:0]   s01_axi_arburst,
    input  wire         s01_axi_arlock,
    input  wire [3:0]   s01_axi_arcache,
    input  wire [2:0]   s01_axi_arprot,
    input  wire [3:0]   s01_axi_arqos,
    input  wire         s01_axi_arvalid,
    output wire         s01_axi_arready,
    output wire [7:0]   s01_axi_rid,
    output wire [31:0]  s01_axi_rdata,
    output wire [1:0]   s01_axi_rresp,
    output wire         s01_axi_rlast,
    output wire         s01_axi_rvalid,
    input  wire         s01_axi_rready,

    // -------------------------------------------------------------------------
    // UART serial interface (pass-through from axi_uart_top)
    // -------------------------------------------------------------------------
    input  wire         uart_rx,
    output wire         uart_tx,
    output wire         uart_irq     // RX data-available interrupt
);

    // =========================================================================
    // Local parameters
    // =========================================================================
    localparam DATA_W    = 32;
    localparam ADDR_W    = 32;
    localparam ID_W      = 8;
    localparam STRB_W    = DATA_W / 8;

    // UART address region: base 0x40001000, decode width 8 (256 B window)
    localparam UART_BASE = 32'h4000_1000;
    localparam UART_DECO = 8;

    // =========================================================================
    // Reset adaptation: interconnect uses active-HIGH rst
    // =========================================================================
    wire rst = ~aresetn;

    // =========================================================================
    // Internal wires — interconnect master ports
    // =========================================================================

    // --- m01 (UART) ---
    wire [ID_W-1:0]  m01_awid;    wire [ADDR_W-1:0] m01_awaddr;
    wire [7:0]       m01_awlen;   wire [2:0]        m01_awsize;
    wire [1:0]       m01_awburst; wire              m01_awlock;
    wire [3:0]       m01_awcache; wire [2:0]        m01_awprot;
    wire [3:0]       m01_awqos;   wire [3:0]        m01_awregion;
    wire             m01_awvalid; wire              m01_awready;
    wire [DATA_W-1:0] m01_wdata;  wire [STRB_W-1:0] m01_wstrb;
    wire             m01_wlast;   wire              m01_wvalid;
    wire             m01_wready;
    wire [ID_W-1:0]  m01_bid;     wire [1:0]        m01_bresp;
    wire             m01_bvalid;  wire              m01_bready;
    wire [ID_W-1:0]  m01_arid;    wire [ADDR_W-1:0] m01_araddr;
    wire [7:0]       m01_arlen;   wire [2:0]        m01_arsize;
    wire [1:0]       m01_arburst; wire              m01_arlock;
    wire [3:0]       m01_arcache; wire [2:0]        m01_arprot;
    wire [3:0]       m01_arqos;   wire [3:0]        m01_arregion;
    wire             m01_arvalid; wire              m01_arready;
    wire [ID_W-1:0]  m01_rid;     wire [DATA_W-1:0] m01_rdata;
    wire [1:0]       m01_rresp;   wire              m01_rlast;
    wire             m01_rvalid;  wire              m01_rready;

    // =========================================================================
    // AXI4 2x10 Interconnect instantiation
    // =========================================================================
    axi_interconnect_wrap_2x10 #(
        .DATA_WIDTH         (DATA_W),
        .ADDR_WIDTH         (ADDR_W),
        .ID_WIDTH           (ID_W),
        // ---- m00: disabled (AES removed) ----
        .M00_BASE_ADDR      (32'h0),
        .M00_ADDR_WIDTH     ({1{32'd0}}),
        .M00_CONNECT_READ   (2'b00),
        .M00_CONNECT_WRITE  (2'b00),
        // ---- m01: UART ----
        .M01_BASE_ADDR      (UART_BASE),
        .M01_ADDR_WIDTH     ({1{32'd12}}),    // 4KB decode
        .M01_CONNECT_READ   (2'b11),         // both masters can reach m01
        .M01_CONNECT_WRITE  (2'b11),
        // ---- m02-m09: disabled ----
        .M02_BASE_ADDR      (32'h0),
        .M02_ADDR_WIDTH     ({1{32'd0}}),
        .M03_BASE_ADDR      (32'h0),
        .M03_ADDR_WIDTH     ({1{32'd0}}),
        .M04_BASE_ADDR      (32'h0),
        .M04_ADDR_WIDTH     ({1{32'd0}}),
        .M05_BASE_ADDR      (32'h0),
        .M05_ADDR_WIDTH     ({1{32'd0}}),
        .M06_BASE_ADDR      (32'h0),
        .M06_ADDR_WIDTH     ({1{32'd0}}),
        .M07_BASE_ADDR      (32'h0),
        .M07_ADDR_WIDTH     ({1{32'd0}}),
        .M08_BASE_ADDR      (32'h0),
        .M08_ADDR_WIDTH     ({1{32'd0}}),
        .M09_BASE_ADDR      (32'h0),
        .M09_ADDR_WIDTH     ({1{32'd0}})
    ) u_interconnect (
        .clk                (clk),
        .rst                (rst),

        // --- Slave port 0 ---
        .s00_axi_awid       (s00_axi_awid),
        .s00_axi_awaddr     (s00_axi_awaddr),
        .s00_axi_awlen      (s00_axi_awlen),
        .s00_axi_awsize     (s00_axi_awsize),
        .s00_axi_awburst    (s00_axi_awburst),
        .s00_axi_awlock     (s00_axi_awlock),
        .s00_axi_awcache    (s00_axi_awcache),
        .s00_axi_awprot     (s00_axi_awprot),
        .s00_axi_awqos      (s00_axi_awqos),
        .s00_axi_awuser     (1'b0),
        .s00_axi_awvalid    (s00_axi_awvalid),
        .s00_axi_awready    (s00_axi_awready),
        .s00_axi_wdata      (s00_axi_wdata),
        .s00_axi_wstrb      (s00_axi_wstrb),
        .s00_axi_wlast      (s00_axi_wlast),
        .s00_axi_wuser      (1'b0),
        .s00_axi_wvalid     (s00_axi_wvalid),
        .s00_axi_wready     (s00_axi_wready),
        .s00_axi_bid        (s00_axi_bid),
        .s00_axi_bresp      (s00_axi_bresp),
        .s00_axi_buser      (),
        .s00_axi_bvalid     (s00_axi_bvalid),
        .s00_axi_bready     (s00_axi_bready),
        .s00_axi_arid       (s00_axi_arid),
        .s00_axi_araddr     (s00_axi_araddr),
        .s00_axi_arlen      (s00_axi_arlen),
        .s00_axi_arsize     (s00_axi_arsize),
        .s00_axi_arburst    (s00_axi_arburst),
        .s00_axi_arlock     (s00_axi_arlock),
        .s00_axi_arcache    (s00_axi_arcache),
        .s00_axi_arprot     (s00_axi_arprot),
        .s00_axi_arqos      (s00_axi_arqos),
        .s00_axi_aruser     (1'b0),
        .s00_axi_arvalid    (s00_axi_arvalid),
        .s00_axi_arready    (s00_axi_arready),
        .s00_axi_rid        (s00_axi_rid),
        .s00_axi_rdata      (s00_axi_rdata),
        .s00_axi_rresp      (s00_axi_rresp),
        .s00_axi_rlast      (s00_axi_rlast),
        .s00_axi_ruser      (),
        .s00_axi_rvalid     (s00_axi_rvalid),
        .s00_axi_rready     (s00_axi_rready),

        // --- Slave port 1 ---
        .s01_axi_awid       (s01_axi_awid),
        .s01_axi_awaddr     (s01_axi_awaddr),
        .s01_axi_awlen      (s01_axi_awlen),
        .s01_axi_awsize     (s01_axi_awsize),
        .s01_axi_awburst    (s01_axi_awburst),
        .s01_axi_awlock     (s01_axi_awlock),
        .s01_axi_awcache    (s01_axi_awcache),
        .s01_axi_awprot     (s01_axi_awprot),
        .s01_axi_awqos      (s01_axi_awqos),
        .s01_axi_awuser     (1'b0),
        .s01_axi_awvalid    (s01_axi_awvalid),
        .s01_axi_awready    (s01_axi_awready),
        .s01_axi_wdata      (s01_axi_wdata),
        .s01_axi_wstrb      (s01_axi_wstrb),
        .s01_axi_wlast      (s01_axi_wlast),
        .s01_axi_wuser      (1'b0),
        .s01_axi_wvalid     (s01_axi_wvalid),
        .s01_axi_wready     (s01_axi_wready),
        .s01_axi_bid        (s01_axi_bid),
        .s01_axi_bresp      (s01_axi_bresp),
        .s01_axi_buser      (),
        .s01_axi_bvalid     (s01_axi_bvalid),
        .s01_axi_bready     (s01_axi_bready),
        .s01_axi_arid       (s01_axi_arid),
        .s01_axi_araddr     (s01_axi_araddr),
        .s01_axi_arlen      (s01_axi_arlen),
        .s01_axi_arsize     (s01_axi_arsize),
        .s01_axi_arburst    (s01_axi_arburst),
        .s01_axi_arlock     (s01_axi_arlock),
        .s01_axi_arcache    (s01_axi_arcache),
        .s01_axi_arprot     (s01_axi_arprot),
        .s01_axi_arqos      (s01_axi_arqos),
        .s01_axi_aruser     (1'b0),
        .s01_axi_arvalid    (s01_axi_arvalid),
        .s01_axi_arready    (s01_axi_arready),
        .s01_axi_rid        (s01_axi_rid),
        .s01_axi_rdata      (s01_axi_rdata),
        .s01_axi_rresp      (s01_axi_rresp),
        .s01_axi_rlast      (s01_axi_rlast),
        .s01_axi_ruser      (),
        .s01_axi_rvalid     (s01_axi_rvalid),
        .s01_axi_rready     (s01_axi_rready),

        // --- Master port 0: tied off (AES removed) ---
        .m00_axi_awvalid    (),  .m00_axi_awready    (1'b0),
        .m00_axi_awid       (),  .m00_axi_awaddr     (),
        .m00_axi_awlen      (),  .m00_axi_awsize     (),
        .m00_axi_awburst    (),  .m00_axi_awlock     (),
        .m00_axi_awcache    (),  .m00_axi_awprot     (),
        .m00_axi_awqos      (),  .m00_axi_awregion   (), .m00_axi_awuser    (),
        .m00_axi_wvalid     (),  .m00_axi_wready     (1'b0),
        .m00_axi_wdata      (),  .m00_axi_wstrb      (),
        .m00_axi_wlast      (),  .m00_axi_wuser      (),
        .m00_axi_bvalid     (1'b0), .m00_axi_bready  (),
        .m00_axi_bid        ({ID_W{1'b0}}), .m00_axi_bresp (2'b10), .m00_axi_buser (1'b0),
        .m00_axi_arvalid    (),  .m00_axi_arready    (1'b0),
        .m00_axi_arid       (),  .m00_axi_araddr     (),
        .m00_axi_arlen      (),  .m00_axi_arsize     (),
        .m00_axi_arburst    (),  .m00_axi_arlock     (),
        .m00_axi_arcache    (),  .m00_axi_arprot     (),
        .m00_axi_arqos      (),  .m00_axi_arregion   (), .m00_axi_aruser    (),
        .m00_axi_rvalid     (1'b0), .m00_axi_rready  (),
        .m00_axi_rid        ({ID_W{1'b0}}), .m00_axi_rdata ({DATA_W{1'b0}}),
        .m00_axi_rresp      (2'b10), .m00_axi_rlast  (1'b0), .m00_axi_ruser (1'b0),

        // --- Master port 1 (UART) ---
        .m01_axi_awid       (m01_awid),
        .m01_axi_awaddr     (m01_awaddr),
        .m01_axi_awlen      (m01_awlen),
        .m01_axi_awsize     (m01_awsize),
        .m01_axi_awburst    (m01_awburst),
        .m01_axi_awlock     (m01_awlock),
        .m01_axi_awcache    (m01_awcache),
        .m01_axi_awprot     (m01_awprot),
        .m01_axi_awqos      (m01_awqos),
        .m01_axi_awregion   (m01_awregion),
        .m01_axi_awuser     (),
        .m01_axi_awvalid    (m01_awvalid),
        .m01_axi_awready    (m01_awready),
        .m01_axi_wdata      (m01_wdata),
        .m01_axi_wstrb      (m01_wstrb),
        .m01_axi_wlast      (m01_wlast),
        .m01_axi_wuser      (),
        .m01_axi_wvalid     (m01_wvalid),
        .m01_axi_wready     (m01_wready),
        .m01_axi_bid        (m01_bid),
        .m01_axi_bresp      (m01_bresp),
        .m01_axi_buser      (1'b0),
        .m01_axi_bvalid     (m01_bvalid),
        .m01_axi_bready     (m01_bready),
        .m01_axi_arid       (m01_arid),
        .m01_axi_araddr     (m01_araddr),
        .m01_axi_arlen      (m01_arlen),
        .m01_axi_arsize     (m01_arsize),
        .m01_axi_arburst    (m01_arburst),
        .m01_axi_arlock     (m01_arlock),
        .m01_axi_arcache    (m01_arcache),
        .m01_axi_arprot     (m01_arprot),
        .m01_axi_arqos      (m01_arqos),
        .m01_axi_arregion   (m01_arregion),
        .m01_axi_aruser     (),
        .m01_axi_arvalid    (m01_arvalid),
        .m01_axi_arready    (m01_arready),
        .m01_axi_rid        (m01_rid),
        .m01_axi_rdata      (m01_rdata),
        .m01_axi_rresp      (m01_rresp),
        .m01_axi_rlast      (m01_rlast),
        .m01_axi_ruser      (1'b0),
        .m01_axi_rvalid     (m01_rvalid),
        .m01_axi_rready     (m01_rready),

        // --- Master ports 02–09 (tied off) ---
        .m02_axi_awvalid    (),  .m02_axi_awready    (1'b0),
        .m02_axi_awid       (),  .m02_axi_awaddr     (),
        .m02_axi_awlen      (),  .m02_axi_awsize     (),
        .m02_axi_awburst    (),  .m02_axi_awlock     (),
        .m02_axi_awcache    (),  .m02_axi_awprot     (),
        .m02_axi_awqos      (),  .m02_axi_awregion   (), .m02_axi_awuser    (),
        .m02_axi_wvalid     (),  .m02_axi_wready     (1'b0),
        .m02_axi_wdata      (),  .m02_axi_wstrb      (),
        .m02_axi_wlast      (),  .m02_axi_wuser      (),
        .m02_axi_bvalid     (1'b0), .m02_axi_bready  (),
        .m02_axi_bid        ({ID_W{1'b0}}), .m02_axi_bresp (2'b10), .m02_axi_buser (1'b0),
        .m02_axi_arvalid    (),  .m02_axi_arready    (1'b0),
        .m02_axi_arid       (),  .m02_axi_araddr     (),
        .m02_axi_arlen      (),  .m02_axi_arsize     (),
        .m02_axi_arburst    (),  .m02_axi_arlock     (),
        .m02_axi_arcache    (),  .m02_axi_arprot     (),
        .m02_axi_arqos      (),  .m02_axi_arregion   (), .m02_axi_aruser    (),
        .m02_axi_rvalid     (1'b0), .m02_axi_rready  (),
        .m02_axi_rid        ({ID_W{1'b0}}), .m02_axi_rdata ({DATA_W{1'b0}}),
        .m02_axi_rresp      (2'b10), .m02_axi_rlast  (1'b0), .m02_axi_ruser (1'b0),

        .m03_axi_awvalid    (),  .m03_axi_awready    (1'b0),
        .m03_axi_awid       (),  .m03_axi_awaddr     (),
        .m03_axi_awlen      (),  .m03_axi_awsize     (),
        .m03_axi_awburst    (),  .m03_axi_awlock     (),
        .m03_axi_awcache    (),  .m03_axi_awprot     (),
        .m03_axi_awqos      (),  .m03_axi_awregion   (), .m03_axi_awuser    (),
        .m03_axi_wvalid     (),  .m03_axi_wready     (1'b0),
        .m03_axi_wdata      (),  .m03_axi_wstrb      (),
        .m03_axi_wlast      (),  .m03_axi_wuser      (),
        .m03_axi_bvalid     (1'b0), .m03_axi_bready  (),
        .m03_axi_bid        ({ID_W{1'b0}}), .m03_axi_bresp (2'b10), .m03_axi_buser (1'b0),
        .m03_axi_arvalid    (),  .m03_axi_arready    (1'b0),
        .m03_axi_arid       (),  .m03_axi_araddr     (),
        .m03_axi_arlen      (),  .m03_axi_arsize     (),
        .m03_axi_arburst    (),  .m03_axi_arlock     (),
        .m03_axi_arcache    (),  .m03_axi_arprot     (),
        .m03_axi_arqos      (),  .m03_axi_arregion   (), .m03_axi_aruser    (),
        .m03_axi_rvalid     (1'b0), .m03_axi_rready  (),
        .m03_axi_rid        ({ID_W{1'b0}}), .m03_axi_rdata ({DATA_W{1'b0}}),
        .m03_axi_rresp      (2'b10), .m03_axi_rlast  (1'b0), .m03_axi_ruser (1'b0),

        .m04_axi_awvalid    (),  .m04_axi_awready    (1'b0),
        .m04_axi_awid       (),  .m04_axi_awaddr     (),
        .m04_axi_awlen      (),  .m04_axi_awsize     (),
        .m04_axi_awburst    (),  .m04_axi_awlock     (),
        .m04_axi_awcache    (),  .m04_axi_awprot     (),
        .m04_axi_awqos      (),  .m04_axi_awregion   (), .m04_axi_awuser    (),
        .m04_axi_wvalid     (),  .m04_axi_wready     (1'b0),
        .m04_axi_wdata      (),  .m04_axi_wstrb      (),
        .m04_axi_wlast      (),  .m04_axi_wuser      (),
        .m04_axi_bvalid     (1'b0), .m04_axi_bready  (),
        .m04_axi_bid        ({ID_W{1'b0}}), .m04_axi_bresp (2'b10), .m04_axi_buser (1'b0),
        .m04_axi_arvalid    (),  .m04_axi_arready    (1'b0),
        .m04_axi_arid       (),  .m04_axi_araddr     (),
        .m04_axi_arlen      (),  .m04_axi_arsize     (),
        .m04_axi_arburst    (),  .m04_axi_arlock     (),
        .m04_axi_arcache    (),  .m04_axi_arprot     (),
        .m04_axi_arqos      (),  .m04_axi_arregion   (), .m04_axi_aruser    (),
        .m04_axi_rvalid     (1'b0), .m04_axi_rready  (),
        .m04_axi_rid        ({ID_W{1'b0}}), .m04_axi_rdata ({DATA_W{1'b0}}),
        .m04_axi_rresp      (2'b10), .m04_axi_rlast  (1'b0), .m04_axi_ruser (1'b0),

        .m05_axi_awvalid    (),  .m05_axi_awready    (1'b0),
        .m05_axi_awid       (),  .m05_axi_awaddr     (),
        .m05_axi_awlen      (),  .m05_axi_awsize     (),
        .m05_axi_awburst    (),  .m05_axi_awlock     (),
        .m05_axi_awcache    (),  .m05_axi_awprot     (),
        .m05_axi_awqos      (),  .m05_axi_awregion   (), .m05_axi_awuser    (),
        .m05_axi_wvalid     (),  .m05_axi_wready     (1'b0),
        .m05_axi_wdata      (),  .m05_axi_wstrb      (),
        .m05_axi_wlast      (),  .m05_axi_wuser      (),
        .m05_axi_bvalid     (1'b0), .m05_axi_bready  (),
        .m05_axi_bid        ({ID_W{1'b0}}), .m05_axi_bresp (2'b10), .m05_axi_buser (1'b0),
        .m05_axi_arvalid    (),  .m05_axi_arready    (1'b0),
        .m05_axi_arid       (),  .m05_axi_araddr     (),
        .m05_axi_arlen      (),  .m05_axi_arsize     (),
        .m05_axi_arburst    (),  .m05_axi_arlock     (),
        .m05_axi_arcache    (),  .m05_axi_arprot     (),
        .m05_axi_arqos      (),  .m05_axi_arregion   (), .m05_axi_aruser    (),
        .m05_axi_rvalid     (1'b0), .m05_axi_rready  (),
        .m05_axi_rid        ({ID_W{1'b0}}), .m05_axi_rdata ({DATA_W{1'b0}}),
        .m05_axi_rresp      (2'b10), .m05_axi_rlast  (1'b0), .m05_axi_ruser (1'b0),

        .m06_axi_awvalid    (),  .m06_axi_awready    (1'b0),
        .m06_axi_awid       (),  .m06_axi_awaddr     (),
        .m06_axi_awlen      (),  .m06_axi_awsize     (),
        .m06_axi_awburst    (),  .m06_axi_awlock     (),
        .m06_axi_awcache    (),  .m06_axi_awprot     (),
        .m06_axi_awqos      (),  .m06_axi_awregion   (), .m06_axi_awuser    (),
        .m06_axi_wvalid     (),  .m06_axi_wready     (1'b0),
        .m06_axi_wdata      (),  .m06_axi_wstrb      (),
        .m06_axi_wlast      (),  .m06_axi_wuser      (),
        .m06_axi_bvalid     (1'b0), .m06_axi_bready  (),
        .m06_axi_bid        ({ID_W{1'b0}}), .m06_axi_bresp (2'b10), .m06_axi_buser (1'b0),
        .m06_axi_arvalid    (),  .m06_axi_arready    (1'b0),
        .m06_axi_arid       (),  .m06_axi_araddr     (),
        .m06_axi_arlen      (),  .m06_axi_arsize     (),
        .m06_axi_arburst    (),  .m06_axi_arlock     (),
        .m06_axi_arcache    (),  .m06_axi_arprot     (),
        .m06_axi_arqos      (),  .m06_axi_arregion   (), .m06_axi_aruser    (),
        .m06_axi_rvalid     (1'b0), .m06_axi_rready  (),
        .m06_axi_rid        ({ID_W{1'b0}}), .m06_axi_rdata ({DATA_W{1'b0}}),
        .m06_axi_rresp      (2'b10), .m06_axi_rlast  (1'b0), .m06_axi_ruser (1'b0),

        .m07_axi_awvalid    (),  .m07_axi_awready    (1'b0),
        .m07_axi_awid       (),  .m07_axi_awaddr     (),
        .m07_axi_awlen      (),  .m07_axi_awsize     (),
        .m07_axi_awburst    (),  .m07_axi_awlock     (),
        .m07_axi_awcache    (),  .m07_axi_awprot     (),
        .m07_axi_awqos      (),  .m07_axi_awregion   (), .m07_axi_awuser    (),
        .m07_axi_wvalid     (),  .m07_axi_wready     (1'b0),
        .m07_axi_wdata      (),  .m07_axi_wstrb      (),
        .m07_axi_wlast      (),  .m07_axi_wuser      (),
        .m07_axi_bvalid     (1'b0), .m07_axi_bready  (),
        .m07_axi_bid        ({ID_W{1'b0}}), .m07_axi_bresp (2'b10), .m07_axi_buser (1'b0),
        .m07_axi_arvalid    (),  .m07_axi_arready    (1'b0),
        .m07_axi_arid       (),  .m07_axi_araddr     (),
        .m07_axi_arlen      (),  .m07_axi_arsize     (),
        .m07_axi_arburst    (),  .m07_axi_arlock     (),
        .m07_axi_arcache    (),  .m07_axi_arprot     (),
        .m07_axi_arqos      (),  .m07_axi_arregion   (), .m07_axi_aruser    (),
        .m07_axi_rvalid     (1'b0), .m07_axi_rready  (),
        .m07_axi_rid        ({ID_W{1'b0}}), .m07_axi_rdata ({DATA_W{1'b0}}),
        .m07_axi_rresp      (2'b10), .m07_axi_rlast  (1'b0), .m07_axi_ruser (1'b0),

        .m08_axi_awvalid    (),  .m08_axi_awready    (1'b0),
        .m08_axi_awid       (),  .m08_axi_awaddr     (),
        .m08_axi_awlen      (),  .m08_axi_awsize     (),
        .m08_axi_awburst    (),  .m08_axi_awlock     (),
        .m08_axi_awcache    (),  .m08_axi_awprot     (),
        .m08_axi_awqos      (),  .m08_axi_awregion   (), .m08_axi_awuser    (),
        .m08_axi_wvalid     (),  .m08_axi_wready     (1'b0),
        .m08_axi_wdata      (),  .m08_axi_wstrb      (),
        .m08_axi_wlast      (),  .m08_axi_wuser      (),
        .m08_axi_bvalid     (1'b0), .m08_axi_bready  (),
        .m08_axi_bid        ({ID_W{1'b0}}), .m08_axi_bresp (2'b10), .m08_axi_buser (1'b0),
        .m08_axi_arvalid    (),  .m08_axi_arready    (1'b0),
        .m08_axi_arid       (),  .m08_axi_araddr     (),
        .m08_axi_arlen      (),  .m08_axi_arsize     (),
        .m08_axi_arburst    (),  .m08_axi_arlock     (),
        .m08_axi_arcache    (),  .m08_axi_arprot     (),
        .m08_axi_arqos      (),  .m08_axi_arregion   (), .m08_axi_aruser    (),
        .m08_axi_rvalid     (1'b0), .m08_axi_rready  (),
        .m08_axi_rid        ({ID_W{1'b0}}), .m08_axi_rdata ({DATA_W{1'b0}}),
        .m08_axi_rresp      (2'b10), .m08_axi_rlast  (1'b0), .m08_axi_ruser (1'b0),

        .m09_axi_awvalid    (),  .m09_axi_awready    (1'b0),
        .m09_axi_awid       (),  .m09_axi_awaddr     (),
        .m09_axi_awlen      (),  .m09_axi_awsize     (),
        .m09_axi_awburst    (),  .m09_axi_awlock     (),
        .m09_axi_awcache    (),  .m09_axi_awprot     (),
        .m09_axi_awqos      (),  .m09_axi_awregion   (), .m09_axi_awuser    (),
        .m09_axi_wvalid     (),  .m09_axi_wready     (1'b0),
        .m09_axi_wdata      (),  .m09_axi_wstrb      (),
        .m09_axi_wlast      (),  .m09_axi_wuser      (),
        .m09_axi_bvalid     (1'b0), .m09_axi_bready  (),
        .m09_axi_bid        ({ID_W{1'b0}}), .m09_axi_bresp (2'b10), .m09_axi_buser (1'b0),
        .m09_axi_arvalid    (),  .m09_axi_arready    (1'b0),
        .m09_axi_arid       (),  .m09_axi_araddr     (),
        .m09_axi_arlen      (),  .m09_axi_arsize     (),
        .m09_axi_arburst    (),  .m09_axi_arlock     (),
        .m09_axi_arcache    (),  .m09_axi_arprot     (),
        .m09_axi_arqos      (),  .m09_axi_arregion   (), .m09_axi_aruser    (),
        .m09_axi_rvalid     (1'b0), .m09_axi_rready  (),
        .m09_axi_rid        ({ID_W{1'b0}}), .m09_axi_rdata ({DATA_W{1'b0}}),
        .m09_axi_rresp      (2'b10), .m09_axi_rlast  (1'b0), .m09_axi_ruser (1'b0)
    );

    // =========================================================================
    // AXI4 → AXI4-Lite bridge for m01 (UART)
    // =========================================================================
    wire [3:0]  uart_awid;   wire [7:0]  uart_awaddr;
    wire        uart_awvalid; wire       uart_awready;
    wire [31:0] uart_wdata;  wire [3:0]  uart_wstrb;
    wire        uart_wvalid; wire        uart_wready;
    wire [3:0]  uart_bid;    wire [1:0]  uart_bresp;
    wire        uart_bvalid; wire        uart_bready;
    wire [3:0]  uart_arid;   wire [7:0]  uart_araddr;
    wire        uart_arvalid; wire       uart_arready;
    wire [3:0]  uart_rid;    wire [31:0] uart_rdata;
    wire [1:0]  uart_rresp;  wire        uart_rvalid;  wire uart_rready;

    axi_to_axilite_bridge #(
        .DATA_WIDTH   (32),
        .M_ADDR_WIDTH (32),
        .S_ADDR_WIDTH (8),
        .M_ID_WIDTH   (8),
        .S_ID_WIDTH   (4)
    ) u_bridge_uart (
        .aclk           (clk),
        .aresetn        (aresetn),
        // Full-AXI side (from interconnect m01)
        .s_axi_awid     (m01_awid),    .s_axi_awaddr  (m01_awaddr),
        .s_axi_awlen    (m01_awlen),   .s_axi_awsize  (m01_awsize),
        .s_axi_awburst  (m01_awburst), .s_axi_awlock  (m01_awlock),
        .s_axi_awcache  (m01_awcache), .s_axi_awprot  (m01_awprot),
        .s_axi_awqos    (m01_awqos),   .s_axi_awregion(m01_awregion),
        .s_axi_awvalid  (m01_awvalid), .s_axi_awready (m01_awready),
        .s_axi_wdata    (m01_wdata),   .s_axi_wstrb   (m01_wstrb),
        .s_axi_wlast    (m01_wlast),   .s_axi_wvalid  (m01_wvalid),
        .s_axi_wready   (m01_wready),
        .s_axi_bid      (m01_bid),     .s_axi_bresp   (m01_bresp),
        .s_axi_bvalid   (m01_bvalid),  .s_axi_bready  (m01_bready),
        .s_axi_arid     (m01_arid),    .s_axi_araddr  (m01_araddr),
        .s_axi_arlen    (m01_arlen),   .s_axi_arsize  (m01_arsize),
        .s_axi_arburst  (m01_arburst), .s_axi_arlock  (m01_arlock),
        .s_axi_arcache  (m01_arcache), .s_axi_arprot  (m01_arprot),
        .s_axi_arqos    (m01_arqos),   .s_axi_arregion(m01_arregion),
        .s_axi_arvalid  (m01_arvalid), .s_axi_arready (m01_arready),
        .s_axi_rid      (m01_rid),     .s_axi_rdata   (m01_rdata),
        .s_axi_rresp    (m01_rresp),   .s_axi_rlast   (m01_rlast),
        .s_axi_rvalid   (m01_rvalid),  .s_axi_rready  (m01_rready),
        // AXI-Lite side (to UART)
        .m_axi_awid     (uart_awid),   .m_axi_awaddr  (uart_awaddr),
        .m_axi_awvalid  (uart_awvalid),.m_axi_awready (uart_awready),
        .m_axi_wdata    (uart_wdata),  .m_axi_wstrb   (uart_wstrb),
        .m_axi_wvalid   (uart_wvalid), .m_axi_wready  (uart_wready),
        .m_axi_bid      (uart_bid),    .m_axi_bresp   (uart_bresp),
        .m_axi_bvalid   (uart_bvalid), .m_axi_bready  (uart_bready),
        .m_axi_arid     (uart_arid),   .m_axi_araddr  (uart_araddr),
        .m_axi_arvalid  (uart_arvalid),.m_axi_arready (uart_arready),
        .m_axi_rid      (uart_rid),    .m_axi_rdata   (uart_rdata),
        .m_axi_rresp    (uart_rresp),  .m_axi_rvalid  (uart_rvalid),
        .m_axi_rready   (uart_rready)
    );

    // =========================================================================
    // UART top (m01)
    // =========================================================================
    axi_uart_top u_uart (
        .fixed_clk_i      (uart_clk),
        .axi_aclk_i       (clk),
        .axi_aresetn_i    (aresetn),

        .axi_awid_i       (uart_awid),
        .axi_awaddr_i     (uart_awaddr),
        .axi_awvalid_i    (uart_awvalid),
        .axi_awready_o    (uart_awready),

        .axi_wdata_i      (uart_wdata),
        .axi_wstrb_i      (uart_wstrb),
        .axi_wvalid_i     (uart_wvalid),
        .axi_wready_o     (uart_wready),

        .axi_bid_o        (uart_bid),
        .axi_bresp_o      (uart_bresp),
        .axi_bvalid_o     (uart_bvalid),
        .axi_bready_i     (uart_bready),

        .axi_arid_i       (uart_arid),
        .axi_araddr_i     (uart_araddr),
        .axi_arvalid_i    (uart_arvalid),
        .axi_arready_o    (uart_arready),

        .axi_rid_o        (uart_rid),
        .axi_rdata_o      (uart_rdata),
        .axi_rresp_o      (uart_rresp),
        .axi_rvalid_o     (uart_rvalid),
        .axi_rready_i     (uart_rready),

        .uart_rx_i        (uart_rx),
        .uart_tx_o        (uart_tx),
        .read_interrupt_o (uart_irq)
    );

endmodule

`default_nettype wire
