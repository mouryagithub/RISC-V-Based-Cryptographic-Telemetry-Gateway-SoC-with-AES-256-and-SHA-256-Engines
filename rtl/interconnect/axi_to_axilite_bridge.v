// =============================================================================
// File        : axi_to_axilite_bridge.v
// Project     : RISC-V Cryptographic Telemetry Gateway SoC
// Description : AXI4-Full to AXI4-Lite protocol bridge.
//
// Purpose
// -------
// The axi_interconnect_wrap_2x10 presents full AXI4 master ports (with burst,
// size, lock, cache, QoS, user, wlast, rlast fields and an 8-bit ID).  The
// peripheral slaves in this SoC (aes_core_top, axi_uart_top) implement only
// AXI4-Lite — they accept single-beat transactions only, have no burst
// capability, and use narrower ID fields.
//
// This bridge performs the mapping:
//   - Accepts one AXI4 request at a time (no outstanding burst support).
//   - Strips all burst-only fields (awlen, awsize, awburst, awlock, awcache,
//     awqos, awregion, awuser, wlast, arlen, arsize, arburst, arlock, arcache,
//     arqos, arregion, aruser, rlast).  Since AXI4-Lite is always single-beat
//     the interconnect will only issue len=0 transfers to peripherals, so
//     ignoring burst fields is safe.
//   - Truncates the ID from M_ID_WIDTH bits to S_ID_WIDTH bits (MSBs dropped;
//     the interconnect appends routing bits to the top of the ID so the lower
//     bits are the original master ID).
//   - Passes address, data, strobe, prot, and all handshake signals through
//     directly.
//
// Parameters
// ----------
//   DATA_WIDTH    AXI data bus width (must match on both sides). Default 32.
//   M_ADDR_WIDTH  Address width of the full-AXI master port.     Default 32.
//   S_ADDR_WIDTH  Address width presented to the AXI-Lite slave. Default  8.
//   M_ID_WIDTH    ID width of the full-AXI master port.          Default  8.
//   S_ID_WIDTH    ID width used by the AXI-Lite slave.           Default  4.
//
// =============================================================================

`timescale 1ns/1ps
`default_nettype none

module axi_to_axilite_bridge #(
    parameter DATA_WIDTH   = 32,
    parameter M_ADDR_WIDTH = 32,
    parameter S_ADDR_WIDTH = 8,
    parameter M_ID_WIDTH   = 8,
    parameter S_ID_WIDTH   = 4
)(
    // -------------------------------------------------------------------------
    // Clock & Reset
    // -------------------------------------------------------------------------
    input  wire                      aclk,
    input  wire                      aresetn,

    // -------------------------------------------------------------------------
    // AXI4-Full slave port (connects to interconnect master mXX)
    // -------------------------------------------------------------------------
    // Write address
    input  wire [M_ID_WIDTH-1:0]     s_axi_awid,
    input  wire [M_ADDR_WIDTH-1:0]   s_axi_awaddr,
    input  wire [7:0]                s_axi_awlen,     // ignored (must be 0)
    input  wire [2:0]                s_axi_awsize,    // ignored
    input  wire [1:0]                s_axi_awburst,   // ignored
    input  wire                      s_axi_awlock,    // ignored
    input  wire [3:0]                s_axi_awcache,   // ignored
    input  wire [2:0]                s_axi_awprot,
    input  wire [3:0]                s_axi_awqos,     // ignored
    input  wire [3:0]                s_axi_awregion,  // ignored
    input  wire                      s_axi_awvalid,
    output wire                      s_axi_awready,
    // Write data
    input  wire [DATA_WIDTH-1:0]     s_axi_wdata,
    input  wire [DATA_WIDTH/8-1:0]   s_axi_wstrb,
    input  wire                      s_axi_wlast,     // ignored (always 1 for single-beat)
    input  wire                      s_axi_wvalid,
    output wire                      s_axi_wready,
    // Write response
    output wire [M_ID_WIDTH-1:0]     s_axi_bid,
    output wire [1:0]                s_axi_bresp,
    output wire                      s_axi_bvalid,
    input  wire                      s_axi_bready,
    // Read address
    input  wire [M_ID_WIDTH-1:0]     s_axi_arid,
    input  wire [M_ADDR_WIDTH-1:0]   s_axi_araddr,
    input  wire [7:0]                s_axi_arlen,     // ignored (must be 0)
    input  wire [2:0]                s_axi_arsize,    // ignored
    input  wire [1:0]                s_axi_arburst,   // ignored
    input  wire                      s_axi_arlock,    // ignored
    input  wire [3:0]                s_axi_arcache,   // ignored
    input  wire [2:0]                s_axi_arprot,
    input  wire [3:0]                s_axi_arqos,     // ignored
    input  wire [3:0]                s_axi_arregion,  // ignored
    input  wire                      s_axi_arvalid,
    output wire                      s_axi_arready,
    // Read data
    output wire [M_ID_WIDTH-1:0]     s_axi_rid,
    output wire [DATA_WIDTH-1:0]     s_axi_rdata,
    output wire [1:0]                s_axi_rresp,
    output wire                      s_axi_rlast,    // always driven 1
    output wire                      s_axi_rvalid,
    input  wire                      s_axi_rready,

    // -------------------------------------------------------------------------
    // AXI4-Lite master port (connects to peripheral slave)
    // -------------------------------------------------------------------------
    // Write address
    output wire [S_ID_WIDTH-1:0]     m_axi_awid,
    output wire [S_ADDR_WIDTH-1:0]   m_axi_awaddr,
    output wire                      m_axi_awvalid,
    input  wire                      m_axi_awready,
    // Write data
    output wire [DATA_WIDTH-1:0]     m_axi_wdata,
    output wire [DATA_WIDTH/8-1:0]   m_axi_wstrb,
    output wire                      m_axi_wvalid,
    input  wire                      m_axi_wready,
    // Write response
    input  wire [S_ID_WIDTH-1:0]     m_axi_bid,
    input  wire [1:0]                m_axi_bresp,
    input  wire                      m_axi_bvalid,
    output wire                      m_axi_bready,
    // Read address
    output wire [S_ID_WIDTH-1:0]     m_axi_arid,
    output wire [S_ADDR_WIDTH-1:0]   m_axi_araddr,
    output wire                      m_axi_arvalid,
    input  wire                      m_axi_arready,
    // Read data
    input  wire [S_ID_WIDTH-1:0]     m_axi_rid,
    input  wire [DATA_WIDTH-1:0]     m_axi_rdata,
    input  wire [1:0]                m_axi_rresp,
    input  wire                      m_axi_rvalid,
    output wire                      m_axi_rready
);

    // =========================================================================
    // Write address channel — pass-through (strip unused full-AXI fields)
    // =========================================================================
    assign m_axi_awid    = s_axi_awid[S_ID_WIDTH-1:0];
    assign m_axi_awaddr  = s_axi_awaddr[S_ADDR_WIDTH-1:0];
    assign m_axi_awvalid = s_axi_awvalid;
    assign s_axi_awready = m_axi_awready;

    // =========================================================================
    // Write data channel — pass-through
    // =========================================================================
    assign m_axi_wdata   = s_axi_wdata;
    assign m_axi_wstrb   = s_axi_wstrb;
    assign m_axi_wvalid  = s_axi_wvalid;
    assign s_axi_wready  = m_axi_wready;

    // =========================================================================
    // Write response channel — sign-extend ID back to full width
    // =========================================================================
    assign s_axi_bid     = {{(M_ID_WIDTH-S_ID_WIDTH){1'b0}}, m_axi_bid};
    assign s_axi_bresp   = m_axi_bresp;
    assign s_axi_bvalid  = m_axi_bvalid;
    assign m_axi_bready  = s_axi_bready;

    // =========================================================================
    // Read address channel — pass-through
    // =========================================================================
    assign m_axi_arid    = s_axi_arid[S_ID_WIDTH-1:0];
    assign m_axi_araddr  = s_axi_araddr[S_ADDR_WIDTH-1:0];
    assign m_axi_arvalid = s_axi_arvalid;
    assign s_axi_arready = m_axi_arready;

    // =========================================================================
    // Read data channel — rlast is always 1 (AXI-Lite is single-beat)
    // =========================================================================
    assign s_axi_rid     = {{(M_ID_WIDTH-S_ID_WIDTH){1'b0}}, m_axi_rid};
    assign s_axi_rdata   = m_axi_rdata;
    assign s_axi_rresp   = m_axi_rresp;
    assign s_axi_rlast   = 1'b1;
    assign s_axi_rvalid  = m_axi_rvalid;
    assign m_axi_rready  = s_axi_rready;

endmodule

`default_nettype wire
