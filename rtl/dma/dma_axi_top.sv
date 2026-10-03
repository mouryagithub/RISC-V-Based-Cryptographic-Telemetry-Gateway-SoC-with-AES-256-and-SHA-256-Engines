/**
 * File              : dma_axi_top.sv
 * Module            : dma_axi_top
 * Project           : RISC-V Cryptographic Telemetry Gateway SoC
 * Description       : AXI discrete pin-level wrapper for DMA Controller.
 *                     Presents standard AXI4 Master port (to Interconnect S01)
 *                     and standard AXI4-Lite Slave port (CSR configuration).
 */

`timescale 1ns/1ps

module dma_axi_top
  import amba_axi_pkg::*;
  import dma_utils_pkg::*;
#(
  parameter int DMA_ID_VAL = 0
)(
  input  wire                     clk,
  input  wire                     rst,

  // Interrupt Triggers to PIC
  output wire                     dma_done_o,
  output wire                     dma_error_o,

  // AXI4-Lite Slave CSR Interface
  input  wire [31:0]              dma_s_awaddr,
  input  wire [2:0]               dma_s_awprot,
  input  wire                     dma_s_awvalid,
  output wire                     dma_s_awready,

  input  wire [31:0]              dma_s_wdata,
  input  wire [3:0]               dma_s_wstrb,
  input  wire                     dma_s_wvalid,
  output wire                     dma_s_wready,

  output wire [1:0]               dma_s_bresp,
  output wire                     dma_s_bvalid,
  input  wire                     dma_s_bready,

  input  wire [31:0]              dma_s_araddr,
  input  wire [2:0]               dma_s_arprot,
  input  wire                     dma_s_arvalid,
  output wire                     dma_s_arready,

  output wire [31:0]              dma_s_rdata,
  output wire [1:0]               dma_s_rresp,
  output wire                     dma_s_rvalid,
  input  wire                     dma_s_rready,

  // AXI4 Master Interface (to Interconnect S01)
  output wire [7:0]               dma_m_awid,
  output wire [31:0]              dma_m_awaddr,
  output wire [7:0]               dma_m_awlen,
  output wire [2:0]               dma_m_awsize,
  output wire [1:0]               dma_m_awburst,
  output wire                     dma_m_awlock,
  output wire [3:0]               dma_m_awcache,
  output wire [2:0]               dma_m_awprot,
  output wire [3:0]               dma_m_awqos,
  output wire [3:0]               dma_m_awregion,
  output wire                     dma_m_awvalid,
  input  wire                     dma_m_awready,

  output wire [31:0]              dma_m_wdata,
  output wire [3:0]               dma_m_wstrb,
  output wire                     dma_m_wlast,
  output wire                     dma_m_wvalid,
  input  wire                     dma_m_wready,

  input  wire [7:0]               dma_m_bid,
  input  wire [1:0]               dma_m_bresp,
  input  wire                     dma_m_bvalid,
  output wire                     dma_m_bready,

  output wire [7:0]               dma_m_arid,
  output wire [31:0]              dma_m_araddr,
  output wire [7:0]               dma_m_arlen,
  output wire [2:0]               dma_m_arsize,
  output wire [1:0]               dma_m_arburst,
  output wire                     dma_m_arlock,
  output wire [3:0]               dma_m_arcache,
  output wire [2:0]               dma_m_arprot,
  output wire [3:0]               dma_m_arqos,
  output wire [3:0]               dma_m_arregion,
  output wire                     dma_m_arvalid,
  input  wire                     dma_m_arready,

  input  wire [7:0]               dma_m_rid,
  input  wire [31:0]              dma_m_rdata,
  input  wire [1:0]               dma_m_rresp,
  input  wire                     dma_m_rlast,
  input  wire                     dma_m_rvalid,
  output wire                     dma_m_rready
);

  s_axil_mosi_t dma_s_mosi;
  s_axil_miso_t dma_s_miso;

  s_axi_mosi_t  dma_m_mosi;
  s_axi_miso_t  dma_m_miso;

  // Unpack discrete AXI-Lite wires to s_axil_mosi_t struct
  always_comb begin
    dma_s_mosi.awid    = '0;
    dma_s_mosi.awaddr  = dma_s_awaddr;
    dma_s_mosi.awprot  = dma_s_awprot;
    dma_s_mosi.awvalid = dma_s_awvalid;
    dma_s_mosi.wdata   = dma_s_wdata;
    dma_s_mosi.wstrb   = dma_s_wstrb;
    dma_s_mosi.wvalid  = dma_s_wvalid;
    dma_s_mosi.bready  = dma_s_bready;
    dma_s_mosi.arid    = '0;
    dma_s_mosi.araddr  = dma_s_araddr;
    dma_s_mosi.arprot  = dma_s_arprot;
    dma_s_mosi.arvalid = dma_s_arvalid;
    dma_s_mosi.rready  = dma_s_rready;

    dma_m_miso.awready = dma_m_awready;
    dma_m_miso.wready  = dma_m_wready;
    dma_m_miso.bid     = dma_m_bid;
    dma_m_miso.bresp   = dma_m_bresp;
    dma_m_miso.buser   = '0;
    dma_m_miso.bvalid  = dma_m_bvalid;
    dma_m_miso.arready = dma_m_arready;
    dma_m_miso.rid     = dma_m_rid;
    dma_m_miso.rdata   = dma_m_rdata;
    dma_m_miso.rresp   = dma_m_rresp;
    dma_m_miso.rlast   = dma_m_rlast;
    dma_m_miso.ruser   = '0;
    dma_m_miso.rvalid  = dma_m_rvalid;
  end

  // Pack s_axil_miso_t struct to discrete AXI-Lite wires
  assign dma_s_awready = dma_s_miso.awready;
  assign dma_s_wready  = dma_s_miso.wready;
  assign dma_s_bresp   = dma_s_miso.bresp;
  assign dma_s_bvalid  = dma_s_miso.bvalid;
  assign dma_s_arready = dma_s_miso.arready;
  assign dma_s_rdata   = dma_s_miso.rdata[31:0];
  assign dma_s_rresp   = dma_s_miso.rresp;
  assign dma_s_rvalid  = dma_s_miso.rvalid;

  // Pack s_axi_mosi_t struct to discrete AXI4 Master wires
  assign dma_m_awid     = dma_m_mosi.awid;
  assign dma_m_awaddr   = dma_m_mosi.awaddr;
  assign dma_m_awlen    = dma_m_mosi.awlen;
  assign dma_m_awsize   = dma_m_mosi.awsize;
  assign dma_m_awburst  = dma_m_mosi.awburst;
  assign dma_m_awlock   = dma_m_mosi.awlock;
  assign dma_m_awcache  = dma_m_mosi.awcache;
  assign dma_m_awprot   = dma_m_mosi.awprot;
  assign dma_m_awqos    = dma_m_mosi.awqos;
  assign dma_m_awregion = dma_m_mosi.awregion;
  assign dma_m_awvalid  = dma_m_mosi.awvalid;

  assign dma_m_wdata    = dma_m_mosi.wdata[31:0];
  assign dma_m_wstrb    = dma_m_mosi.wstrb[3:0];
  assign dma_m_wlast    = dma_m_mosi.wlast;
  assign dma_m_wvalid   = dma_m_mosi.wvalid;
  assign dma_m_bready   = dma_m_mosi.bready;

  assign dma_m_arid     = dma_m_mosi.arid;
  assign dma_m_araddr   = dma_m_mosi.araddr;
  assign dma_m_arlen    = dma_m_mosi.arlen;
  assign dma_m_arsize   = dma_m_mosi.arsize;
  assign dma_m_arburst  = dma_m_mosi.arburst;
  assign dma_m_arlock   = dma_m_mosi.arlock;
  assign dma_m_arcache  = dma_m_mosi.arcache;
  assign dma_m_arprot   = dma_m_mosi.arprot;
  assign dma_m_arqos    = dma_m_mosi.arqos;
  assign dma_m_arregion = dma_m_mosi.arregion;
  assign dma_m_arvalid  = dma_m_mosi.arvalid;
  assign dma_m_rready   = dma_m_mosi.rready;

  // Instantiate core DMA AXI wrapper
  dma_axi_wrapper #(
    .DMA_ID_VAL (DMA_ID_VAL)
  ) u_dma_axi_wrapper (
    .clk            (clk),
    .rst            (rst),
    .dma_csr_mosi_i (dma_s_mosi),
    .dma_csr_miso_o (dma_s_miso),
    .dma_m_mosi_o   (dma_m_mosi),
    .dma_m_miso_i   (dma_m_miso),
    .dma_done_o     (dma_done_o),
    .dma_error_o    (dma_error_o)
  );

endmodule
