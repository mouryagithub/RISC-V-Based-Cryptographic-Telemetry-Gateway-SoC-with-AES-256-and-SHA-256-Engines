// =============================================================================
// File        : soc_top.v
// Project     : RISC-V Cryptographic Telemetry Gateway SoC
// Description : Master SoC Top-Level integrating the 2x5 AXI4 Crossbar Interconnect
//               (axi_interconnect_wrap_2x5) with:
//
//   TWO AXI4 MASTERS:
//     s00 -> Western Digital VeeR EL2 RISC-V Core (RV32IMC) LSU Master
//     s01 -> 64-bit AXI DMA Controller Master (dma_axi_top)
//
//   FIVE SLAVE IPS (connected via AXI4-to-AXI4-Lite Protocol Bridges):
//     m00 -> AES-256 / AES-128 Cryptographic Accelerator (aes_core_top)
//     m01 -> UART Serial Controller 16550 with 16-byte FIFOs (axi_uart_top)
//     m02 -> 64-bit Real-Time System Timer (axi_timer_top)
//     m03 -> 64-pin General-Purpose I/O Controller (axi_gpio_top)
//     m04 -> SHA-256 Cryptographic Hash Accelerator (axi_sha256_top)
//
// Address Map (4 KB per slave window, 12-bit decode width):
// -----------------------------------------------------------------------------
//   Port   Peripheral IP              Base Address   End Address    Size
//   m00    AES-256 Accelerator        0x4000_0000    0x4000_0FFF    4 KB
//   m01    UART Controller            0x4000_1000    0x4000_1FFF    4 KB
//   m02    System Timer (rv_timer)    0x4000_2000    0x4000_2FFF    4 KB
//   m03    GPIO Controller (64-pin)   0x4000_3000    0x4000_3FFF    4 KB
//   m04    SHA-256 Hash Accelerator   0x4000_4000    0x4000_4FFF    4 KB
//
// Interrupt Routing to VeeR-EL2 PIC Gateway (extintsrc_req):
//   extintsrc_req[1] = UART RX/TX/Line Error IRQ
//   extintsrc_req[2] = System Timer Expiration IRQ
//   extintsrc_req[3] = AES Operation Complete IRQ
//   extintsrc_req[4] = SHA Digest Valid IRQ
//   extintsrc_req[5] = DMA Transfer Done IRQ
//   extintsrc_req[6] = DMA AXI Bus Error IRQ
//   extintsrc_req[7] = GPIO Bank 0 Interrupt (pins 31:0)
//   extintsrc_req[8] = GPIO Bank 1 Interrupt (pins 63:32)
// =============================================================================

`timescale 1ns/1ps
`default_nettype none

module soc_top #(
    parameter USE_INTERNAL_CPU = 1,     // 1: Instantiate VeeR2 core; 0: External TB master port
    parameter AXI_DATA_WIDTH   = 32,
    parameter AXI_ADDR_WIDTH   = 32,
    parameter AXI_ID_WIDTH     = 8
)(
    // -------------------------------------------------------------------------
    // Clocks & Resets
    // -------------------------------------------------------------------------
    input  wire         clk,             // Primary system AXI clock (50/100 MHz)
    input  wire         uart_clk,        // Fixed clock for UART baud generator
    input  wire         aresetn,         // Active-LOW synchronous system reset

    // -------------------------------------------------------------------------
    // External AXI4 Master 0 Port (Active when USE_INTERNAL_CPU == 0 for TB)
    // -------------------------------------------------------------------------
    input  wire [AXI_ID_WIDTH-1:0]      ext_s00_axi_awid,
    input  wire [AXI_ADDR_WIDTH-1:0]    ext_s00_axi_awaddr,
    input  wire [7:0]                   ext_s00_axi_awlen,
    input  wire [2:0]                   ext_s00_axi_awsize,
    input  wire [1:0]                   ext_s00_axi_awburst,
    input  wire                         ext_s00_axi_awlock,
    input  wire [3:0]                   ext_s00_axi_awcache,
    input  wire [2:0]                   ext_s00_axi_awprot,
    input  wire [3:0]                   ext_s00_axi_awqos,
    input  wire                         ext_s00_axi_awvalid,
    output wire                         ext_s00_axi_awready,
    input  wire [AXI_DATA_WIDTH-1:0]    ext_s00_axi_wdata,
    input  wire [AXI_DATA_WIDTH/8-1:0]  ext_s00_axi_wstrb,
    input  wire                         ext_s00_axi_wlast,
    input  wire                         ext_s00_axi_wvalid,
    output wire                         ext_s00_axi_wready,
    output wire [AXI_ID_WIDTH-1:0]      ext_s00_axi_bid,
    output wire [1:0]                   ext_s00_axi_bresp,
    output wire                         ext_s00_axi_bvalid,
    input  wire                         ext_s00_axi_bready,
    input  wire [AXI_ID_WIDTH-1:0]      ext_s00_axi_arid,
    input  wire [AXI_ADDR_WIDTH-1:0]    ext_s00_axi_araddr,
    input  wire [7:0]                   ext_s00_axi_arlen,
    input  wire [2:0]                   ext_s00_axi_arsize,
    input  wire [1:0]                   ext_s00_axi_arburst,
    input  wire                         ext_s00_axi_arlock,
    input  wire [3:0]                   ext_s00_axi_arcache,
    input  wire [2:0]                   ext_s00_axi_arprot,
    input  wire [3:0]                   ext_s00_axi_arqos,
    input  wire                         ext_s00_axi_arvalid,
    output wire                         ext_s00_axi_arready,
    output wire [AXI_ID_WIDTH-1:0]      ext_s00_axi_rid,
    output wire [AXI_DATA_WIDTH-1:0]    ext_s00_axi_rdata,
    output wire [1:0]                   ext_s00_axi_rresp,
    output wire                         ext_s00_axi_rlast,
    output wire                         ext_s00_axi_rvalid,
    input  wire                         ext_s00_axi_rready,

    // -------------------------------------------------------------------------
    // External DMA CSR Configuration Port (for CPU / testbench to program DMA)
    // -------------------------------------------------------------------------
    input  wire [31:0]  dma_csr_awaddr,
    input  wire [2:0]   dma_csr_awprot,
    input  wire         dma_csr_awvalid,
    output wire         dma_csr_awready,
    input  wire [31:0]  dma_csr_wdata,
    input  wire [3:0]   dma_csr_wstrb,
    input  wire         dma_csr_wvalid,
    output wire         dma_csr_wready,
    output wire [1:0]   dma_csr_bresp,
    output wire         dma_csr_bvalid,
    input  wire         dma_csr_bready,
    input  wire [31:0]  dma_csr_araddr,
    input  wire [2:0]   dma_csr_arprot,
    input  wire         dma_csr_arvalid,
    output wire         dma_csr_arready,
    output wire [31:0]  dma_csr_rdata,
    output wire [1:0]   dma_csr_rresp,
    output wire         dma_csr_rvalid,
    input  wire         dma_csr_rready,

    // -------------------------------------------------------------------------
    // Peripheral External Interfaces
    // -------------------------------------------------------------------------
    // UART Serial Port
    input  wire         uart_rx,
    output wire         uart_tx,

    // 64-Pin GPIO External Pins
    input  wire [63:0]  gpio_i,
    output wire [63:0]  gpio_o,
    output wire [63:0]  gpio_dir_o,

    // External Interrupt Observation Outputs
    output wire         uart_irq_o,
    output wire         timer_irq_o,
    output wire         aes_irq_o,
    output wire         sha_irq_o,
    output wire         dma_done_o,
    output wire         dma_error_o,
    output wire [1:0]   gpio_intr_o,

    // VeeR-EL2 CPU Debug / Status Interface
    output wire         cpu_halt_status_o
);

    // Active-HIGH reset for interconnect
    wire rst = ~aresetn;

    // -------------------------------------------------------------------------
    // Interconnect S00 / S01 Signals
    // -------------------------------------------------------------------------
    wire [AXI_ID_WIDTH-1:0]      s00_awid;
    wire [AXI_ADDR_WIDTH-1:0]    s00_awaddr;
    wire [7:0]                   s00_awlen;
    wire [2:0]                   s00_awsize;
    wire [1:0]                   s00_awburst;
    wire                         s00_awlock;
    wire [3:0]                   s00_awcache;
    wire [2:0]                   s00_awprot;
    wire [3:0]                   s00_awqos;
    wire                         s00_awvalid;
    wire                         s00_awready;
    wire [AXI_DATA_WIDTH-1:0]    s00_wdata;
    wire [AXI_DATA_WIDTH/8-1:0]  s00_wstrb;
    wire                         s00_wlast;
    wire                         s00_wvalid;
    wire                         s00_wready;
    wire [AXI_ID_WIDTH-1:0]      s00_bid;
    wire [1:0]                   s00_bresp;
    wire                         s00_bvalid;
    wire                         s00_bready;
    wire [AXI_ID_WIDTH-1:0]      s00_arid;
    wire [AXI_ADDR_WIDTH-1:0]    s00_araddr;
    wire [7:0]                   s00_arlen;
    wire [2:0]                   s00_arsize;
    wire [1:0]                   s00_arburst;
    wire                         s00_arlock;
    wire [3:0]                   s00_arcache;
    wire [2:0]                   s00_arprot;
    wire [3:0]                   s00_arqos;
    wire                         s00_arvalid;
    wire                         s00_arready;
    wire [AXI_ID_WIDTH-1:0]      s00_rid;
    wire [AXI_DATA_WIDTH-1:0]    s00_rdata;
    wire [1:0]                   s00_rresp;
    wire                         s00_rlast;
    wire                         s00_rvalid;
    wire                         s00_rready;

    wire [AXI_ID_WIDTH-1:0]      s01_awid;
    wire [AXI_ADDR_WIDTH-1:0]    s01_awaddr;
    wire [7:0]                   s01_awlen;
    wire [2:0]                   s01_awsize;
    wire [1:0]                   s01_awburst;
    wire                         s01_awlock;
    wire [3:0]                   s01_awcache;
    wire [2:0]                   s01_awprot;
    wire [3:0]                   s01_awqos;
    wire [3:0]                   s01_awregion;
    wire                         s01_awvalid;
    wire                         s01_awready;
    wire [AXI_DATA_WIDTH-1:0]    s01_wdata;
    wire [AXI_DATA_WIDTH/8-1:0]  s01_wstrb;
    wire                         s01_wlast;
    wire                         s01_wvalid;
    wire                         s01_wready;
    wire [AXI_ID_WIDTH-1:0]      s01_bid;
    wire [1:0]                   s01_bresp;
    wire                         s01_bvalid;
    wire                         s01_bready;
    wire [AXI_ID_WIDTH-1:0]      s01_arid;
    wire [AXI_ADDR_WIDTH-1:0]    s01_araddr;
    wire [7:0]                   s01_arlen;
    wire [2:0]                   s01_arsize;
    wire [1:0]                   s01_arburst;
    wire                         s01_arlock;
    wire [3:0]                   s01_arcache;
    wire [2:0]                   s01_arprot;
    wire [3:0]                   s01_arqos;
    wire [3:0]                   s01_arregion;
    wire                         s01_arvalid;
    wire                         s01_arready;
    wire [AXI_ID_WIDTH-1:0]      s01_rid;
    wire [AXI_DATA_WIDTH-1:0]    s01_rdata;
    wire [1:0]                   s01_rresp;
    wire                         s01_rlast;
    wire                         s01_rvalid;
    wire                         s01_rready;

    // -------------------------------------------------------------------------
    // Internal Master 0: VeeR-EL2 CPU Core (when USE_INTERNAL_CPU = 1)
    // -------------------------------------------------------------------------
    wire [63:0] cpu_lsu_wdata;
    wire [7:0]  cpu_lsu_wstrb;
    wire [63:0] cpu_lsu_rdata;
    wire [31:0] cpu_lsu_awaddr, cpu_lsu_araddr;
    wire [3:0]  cpu_lsu_awid, cpu_lsu_arid;
    wire        cpu_lsu_awvalid, cpu_lsu_awready;
    wire        cpu_lsu_wvalid, cpu_lsu_wready, cpu_lsu_wlast;
    wire        cpu_lsu_bvalid, cpu_lsu_bready;
    wire [1:0]  cpu_lsu_bresp;
    wire [3:0]  cpu_lsu_bid;
    wire        cpu_lsu_arvalid, cpu_lsu_arready;
    wire        cpu_lsu_rvalid, cpu_lsu_rready, cpu_lsu_rlast;
    wire [1:0]  cpu_lsu_rresp;
    wire [3:0]  cpu_lsu_rid;

    // Interrupt signals
    wire        uart_irq;
    wire        timer_irq;
    wire        aes_irq;
    wire        sha_irq;
    wire        dma_done;
    wire        dma_error;
    wire [1:0]  gpio_intr;

    // Drive external outputs
    assign uart_irq_o   = uart_irq;
    assign timer_irq_o  = timer_irq;
    assign aes_irq_o    = aes_irq;
    assign sha_irq_o    = sha_irq;
    assign dma_done_o   = dma_done;
    assign dma_error_o  = dma_error;
    assign gpio_intr_o  = gpio_intr;

    // 32-entry PIC external interrupt vector bus
    wire [31:1] pic_ext_irqs;
    assign pic_ext_irqs[1]     = uart_irq;
    assign pic_ext_irqs[2]     = timer_irq;
    assign pic_ext_irqs[3]     = aes_irq;
    assign pic_ext_irqs[4]     = sha_irq;
    assign pic_ext_irqs[5]     = dma_done;
    assign pic_ext_irqs[6]     = dma_error;
    assign pic_ext_irqs[7]     = gpio_intr[0];
    assign pic_ext_irqs[8]     = gpio_intr[1];
    assign pic_ext_irqs[31:9]  = 23'h0;

    generate
        if (USE_INTERNAL_CPU) begin : gen_veer_cpu
            // 64-bit to 32-bit LSU bus steering
            assign s00_awid    = {4'b0, cpu_lsu_awid};
            assign s00_awaddr  = cpu_lsu_awaddr;
            assign s00_awlen   = 8'd0;
            assign s00_awsize  = 3'd2; // 32-bit word
            assign s00_awburst = 2'b01;
            assign s00_awlock  = 1'b0;
            assign s00_awcache = 4'h0;
            assign s00_awprot  = 3'h0;
            assign s00_awqos   = 4'h0;
            assign s00_awvalid = cpu_lsu_awvalid;
            assign cpu_lsu_awready = s00_awready;

            assign s00_wdata   = cpu_lsu_awaddr[2] ? cpu_lsu_wdata[63:32] : cpu_lsu_wdata[31:0];
            assign s00_wstrb   = cpu_lsu_awaddr[2] ? cpu_lsu_wstrb[7:4]   : cpu_lsu_wstrb[3:0];
            assign s00_wlast   = cpu_lsu_wlast;
            assign s00_wvalid  = cpu_lsu_wvalid;
            assign cpu_lsu_wready = s00_wready;

            assign cpu_lsu_bvalid = s00_bvalid;
            assign cpu_lsu_bresp  = s00_bresp;
            assign cpu_lsu_bid    = s00_bid[3:0];
            assign s00_bready     = cpu_lsu_bready;

            assign s00_arid    = {4'b0, cpu_lsu_arid};
            assign s00_araddr  = cpu_lsu_araddr;
            assign s00_arlen   = 8'd0;
            assign s00_arsize  = 3'd2;
            assign s00_arburst = 2'b01;
            assign s00_arlock  = 1'b0;
            assign s00_arcache = 4'h0;
            assign s00_arprot  = 3'h0;
            assign s00_arqos   = 4'h0;
            assign s00_arvalid = cpu_lsu_arvalid;
            assign cpu_lsu_arready = s00_arready;

            assign cpu_lsu_rdata  = {s00_rdata, s00_rdata}; // duplicate to both halves
            assign cpu_lsu_rvalid = s00_rvalid;
            assign cpu_lsu_rresp  = s00_rresp;
            assign cpu_lsu_rid    = s00_rid[3:0];
            assign cpu_lsu_rlast  = s00_rlast;
            assign s00_rready     = cpu_lsu_rready;

            // Tie off external port
            assign ext_s00_axi_awready = 1'b0;
            assign ext_s00_axi_wready  = 1'b0;
            assign ext_s00_axi_bvalid  = 1'b0;
            assign ext_s00_axi_bresp   = 2'b10;
            assign ext_s00_axi_bid     = '0;
            assign ext_s00_axi_arready = 1'b0;
            assign ext_s00_axi_rvalid  = 1'b0;
            assign ext_s00_axi_rdata   = '0;
            assign ext_s00_axi_rresp   = 2'b10;
            assign ext_s00_axi_rid     = '0;
            assign ext_s00_axi_rlast   = 1'b0;

            assign cpu_halt_status_o = 1'b0;
        end else begin : gen_ext_master
            // Pass external testbench master directly into s00
            assign s00_awid     = ext_s00_axi_awid;
            assign s00_awaddr   = ext_s00_axi_awaddr;
            assign s00_awlen    = ext_s00_axi_awlen;
            assign s00_awsize   = ext_s00_axi_awsize;
            assign s00_awburst  = ext_s00_axi_awburst;
            assign s00_awlock   = ext_s00_axi_awlock;
            assign s00_awcache  = ext_s00_axi_awcache;
            assign s00_awprot   = ext_s00_axi_awprot;
            assign s00_awqos    = ext_s00_axi_awqos;
            assign s00_awvalid  = ext_s00_axi_awvalid;
            assign ext_s00_axi_awready = s00_awready;

            assign s00_wdata    = ext_s00_axi_wdata;
            assign s00_wstrb    = ext_s00_axi_wstrb;
            assign s00_wlast    = ext_s00_axi_wlast;
            assign s00_wvalid   = ext_s00_axi_wvalid;
            assign ext_s00_axi_wready = s00_wready;

            assign ext_s00_axi_bid    = s00_bid;
            assign ext_s00_axi_bresp  = s00_bresp;
            assign ext_s00_axi_bvalid = s00_bvalid;
            assign s00_bready   = ext_s00_axi_bready;

            assign s00_arid     = ext_s00_axi_arid;
            assign s00_araddr   = ext_s00_axi_araddr;
            assign s00_arlen    = ext_s00_axi_arlen;
            assign s00_arsize   = ext_s00_axi_arsize;
            assign s00_arburst  = ext_s00_axi_arburst;
            assign s00_arlock   = ext_s00_axi_arlock;
            assign s00_arcache  = ext_s00_axi_arcache;
            assign s00_arprot   = ext_s00_axi_arprot;
            assign s00_arqos    = ext_s00_axi_arqos;
            assign s00_arvalid  = ext_s00_axi_arvalid;
            assign ext_s00_axi_arready = s00_arready;

            assign ext_s00_axi_rid    = s00_rid;
            assign ext_s00_axi_rdata  = s00_rdata;
            assign ext_s00_axi_rresp  = s00_rresp;
            assign ext_s00_axi_rlast  = s00_rlast;
            assign ext_s00_axi_rvalid = s00_rvalid;
            assign s00_rready   = ext_s00_axi_rready;

            assign cpu_halt_status_o = 1'b0;
        end
    endgenerate

    // -------------------------------------------------------------------------
    // Internal Master 1: 64-bit AXI DMA Controller (dma_axi_top)
    // -------------------------------------------------------------------------
    dma_axi_top #(
        .DMA_ID_VAL     (0)
    ) u_dma_controller (
        .clk            (clk),
        .rst            (rst),

        .dma_done_o     (dma_done),
        .dma_error_o    (dma_error),

        // CSR slave interface (programmed by CPU or external host)
        .dma_s_awaddr   (dma_csr_awaddr),
        .dma_s_awprot   (dma_csr_awprot),
        .dma_s_awvalid  (dma_csr_awvalid),
        .dma_s_awready  (dma_csr_awready),
        .dma_s_wdata    (dma_csr_wdata),
        .dma_s_wstrb    (dma_csr_wstrb),
        .dma_s_wvalid   (dma_csr_wvalid),
        .dma_s_wready   (dma_csr_wready),
        .dma_s_bresp    (dma_csr_bresp),
        .dma_s_bvalid   (dma_csr_bvalid),
        .dma_s_bready   (dma_csr_bready),
        .dma_s_araddr   (dma_csr_araddr),
        .dma_s_arprot   (dma_csr_arprot),
        .dma_s_arvalid  (dma_csr_arvalid),
        .dma_s_arready  (dma_csr_arready),
        .dma_s_rdata    (dma_csr_rdata),
        .dma_s_rresp    (dma_csr_rresp),
        .dma_s_rvalid   (dma_csr_rvalid),
        .dma_s_rready   (dma_csr_rready),

        // AXI4 Master port -> connected to S01 of Interconnect
        .dma_m_awid     (s01_awid),
        .dma_m_awaddr   (s01_awaddr),
        .dma_m_awlen    (s01_awlen),
        .dma_m_awsize   (s01_awsize),
        .dma_m_awburst  (s01_awburst),
        .dma_m_awlock   (s01_awlock),
        .dma_m_awcache  (s01_awcache),
        .dma_m_awprot   (s01_awprot),
        .dma_m_awqos    (s01_awqos),
        .dma_m_awregion (s01_awregion),
        .dma_m_awvalid  (s01_awvalid),
        .dma_m_awready  (s01_awready),
        .dma_m_wdata    (s01_wdata),
        .dma_m_wstrb    (s01_wstrb),
        .dma_m_wlast    (s01_wlast),
        .dma_m_wvalid   (s01_wvalid),
        .dma_m_wready   (s01_wready),
        .dma_m_bid      (s01_bid),
        .dma_m_bresp    (s01_bresp),
        .dma_m_bvalid   (s01_bvalid),
        .dma_m_bready   (s01_bready),
        .dma_m_arid     (s01_arid),
        .dma_m_araddr   (s01_araddr),
        .dma_m_arlen    (s01_arlen),
        .dma_m_arsize   (s01_arsize),
        .dma_m_arburst  (s01_arburst),
        .dma_m_arlock   (s01_arlock),
        .dma_m_arcache  (s01_arcache),
        .dma_m_arprot   (s01_arprot),
        .dma_m_arqos    (s01_arqos),
        .dma_m_arregion (s01_arregion),
        .dma_m_arvalid  (s01_arvalid),
        .dma_m_arready  (s01_arready),
        .dma_m_rid      (s01_rid),
        .dma_m_rdata    (s01_rdata),
        .dma_m_rresp    (s01_rresp),
        .dma_m_rlast    (s01_rlast),
        .dma_m_rvalid   (s01_rvalid),
        .dma_m_rready   (s01_rready)
    );

    // -------------------------------------------------------------------------
    // Interconnect Master Ports (m00 to m04) Wires
    // -------------------------------------------------------------------------
    // m00 (AES)
    wire [AXI_ID_WIDTH-1:0]   m00_awid;    wire [AXI_ADDR_WIDTH-1:0] m00_awaddr;
    wire [7:0]                m00_awlen;   wire [2:0]                m00_awsize;
    wire [1:0]                m00_awburst; wire                      m00_awlock;
    wire [3:0]                m00_awcache; wire [2:0]                m00_awprot;
    wire [3:0]                m00_awqos;   wire [3:0]                m00_awregion;
    wire                      m00_awvalid; wire                      m00_awready;
    wire [AXI_DATA_WIDTH-1:0] m00_wdata;   wire [AXI_DATA_WIDTH/8-1:0] m00_wstrb;
    wire                      m00_wlast;   wire                      m00_wvalid;
    wire                      m00_wready;
    wire [AXI_ID_WIDTH-1:0]   m00_bid;     wire [1:0]                m00_bresp;
    wire                      m00_bvalid;  wire                      m00_bready;
    wire [AXI_ID_WIDTH-1:0]   m00_arid;    wire [AXI_ADDR_WIDTH-1:0] m00_araddr;
    wire [7:0]                m00_arlen;   wire [2:0]                m00_arsize;
    wire [1:0]                m00_arburst; wire                      m00_arlock;
    wire [3:0]                m00_arcache; wire [2:0]                m00_arprot;
    wire [3:0]                m00_arqos;   wire [3:0]                m00_arregion;
    wire                      m00_arvalid; wire                      m00_arready;
    wire [AXI_ID_WIDTH-1:0]   m00_rid;     wire [AXI_DATA_WIDTH-1:0] m00_rdata;
    wire [1:0]                m00_rresp;   wire                      m00_rlast;
    wire                      m00_rvalid;  wire                      m00_rready;

    // m01 (UART)
    wire [AXI_ID_WIDTH-1:0]   m01_awid;    wire [AXI_ADDR_WIDTH-1:0] m01_awaddr;
    wire [7:0]                m01_awlen;   wire [2:0]                m01_awsize;
    wire [1:0]                m01_awburst; wire                      m01_awlock;
    wire [3:0]                m01_awcache; wire [2:0]                m01_awprot;
    wire [3:0]                m01_awqos;   wire [3:0]                m01_awregion;
    wire                      m01_awvalid; wire                      m01_awready;
    wire [AXI_DATA_WIDTH-1:0] m01_wdata;   wire [AXI_DATA_WIDTH/8-1:0] m01_wstrb;
    wire                      m01_wlast;   wire                      m01_wvalid;
    wire                      m01_wready;
    wire [AXI_ID_WIDTH-1:0]   m01_bid;     wire [1:0]                m01_bresp;
    wire                      m01_bvalid;  wire                      m01_bready;
    wire [AXI_ID_WIDTH-1:0]   m01_arid;    wire [AXI_ADDR_WIDTH-1:0] m01_araddr;
    wire [7:0]                m01_arlen;   wire [2:0]                m01_arsize;
    wire [1:0]                m01_arburst; wire                      m01_arlock;
    wire [3:0]                m01_arcache; wire [2:0]                m01_arprot;
    wire [3:0]                m01_arqos;   wire [3:0]                m01_arregion;
    wire                      m01_arvalid; wire                      m01_arready;
    wire [AXI_ID_WIDTH-1:0]   m01_rid;     wire [AXI_DATA_WIDTH-1:0] m01_rdata;
    wire [1:0]                m01_rresp;   wire                      m01_rlast;
    wire                      m01_rvalid;  wire                      m01_rready;

    // m02 (Timer)
    wire [AXI_ID_WIDTH-1:0]   m02_awid;    wire [AXI_ADDR_WIDTH-1:0] m02_awaddr;
    wire [7:0]                m02_awlen;   wire [2:0]                m02_awsize;
    wire [1:0]                m02_awburst; wire                      m02_awlock;
    wire [3:0]                m02_awcache; wire [2:0]                m02_awprot;
    wire [3:0]                m02_awqos;   wire [3:0]                m02_awregion;
    wire                      m02_awvalid; wire                      m02_awready;
    wire [AXI_DATA_WIDTH-1:0] m02_wdata;   wire [AXI_DATA_WIDTH/8-1:0] m02_wstrb;
    wire                      m02_wlast;   wire                      m02_wvalid;
    wire                      m02_wready;
    wire [AXI_ID_WIDTH-1:0]   m02_bid;     wire [1:0]                m02_bresp;
    wire                      m02_bvalid;  wire                      m02_bready;
    wire [AXI_ID_WIDTH-1:0]   m02_arid;    wire [AXI_ADDR_WIDTH-1:0] m02_araddr;
    wire [7:0]                m02_arlen;   wire [2:0]                m02_arsize;
    wire [1:0]                m02_arburst; wire                      m02_arlock;
    wire [3:0]                m02_arcache; wire [2:0]                m02_arprot;
    wire [3:0]                m02_arqos;   wire [3:0]                m02_arregion;
    wire                      m02_arvalid; wire                      m02_arready;
    wire [AXI_ID_WIDTH-1:0]   m02_rid;     wire [AXI_DATA_WIDTH-1:0] m02_rdata;
    wire [1:0]                m02_rresp;   wire                      m02_rlast;
    wire                      m02_rvalid;  wire                      m02_rready;

    // m03 (GPIO)
    wire [AXI_ID_WIDTH-1:0]   m03_awid;    wire [AXI_ADDR_WIDTH-1:0] m03_awaddr;
    wire [7:0]                m03_awlen;   wire [2:0]                m03_awsize;
    wire [1:0]                m03_awburst; wire                      m03_awlock;
    wire [3:0]                m03_awcache; wire [2:0]                m03_awprot;
    wire [3:0]                m03_awqos;   wire [3:0]                m03_awregion;
    wire                      m03_awvalid; wire                      m03_awready;
    wire [AXI_DATA_WIDTH-1:0] m03_wdata;   wire [AXI_DATA_WIDTH/8-1:0] m03_wstrb;
    wire                      m03_wlast;   wire                      m03_wvalid;
    wire                      m03_wready;
    wire [AXI_ID_WIDTH-1:0]   m03_bid;     wire [1:0]                m03_bresp;
    wire                      m03_bvalid;  wire                      m03_bready;
    wire [AXI_ID_WIDTH-1:0]   m03_arid;    wire [AXI_ADDR_WIDTH-1:0] m03_araddr;
    wire [7:0]                m03_arlen;   wire [2:0]                m03_arsize;
    wire [1:0]                m03_arburst; wire                      m03_arlock;
    wire [3:0]                m03_arcache; wire [2:0]                m03_arprot;
    wire [3:0]                m03_arqos;   wire [3:0]                m03_arregion;
    wire                      m03_arvalid; wire                      m03_arready;
    wire [AXI_ID_WIDTH-1:0]   m03_rid;     wire [AXI_DATA_WIDTH-1:0] m03_rdata;
    wire [1:0]                m03_rresp;   wire                      m03_rlast;
    wire                      m03_rvalid;  wire                      m03_rready;

    // m04 (SHA)
    wire [AXI_ID_WIDTH-1:0]   m04_awid;    wire [AXI_ADDR_WIDTH-1:0] m04_awaddr;
    wire [7:0]                m04_awlen;   wire [2:0]                m04_awsize;
    wire [1:0]                m04_awburst; wire                      m04_awlock;
    wire [3:0]                m04_awcache; wire [2:0]                m04_awprot;
    wire [3:0]                m04_awqos;   wire [3:0]                m04_awregion;
    wire                      m04_awvalid; wire                      m04_awready;
    wire [AXI_DATA_WIDTH-1:0] m04_wdata;   wire [AXI_DATA_WIDTH/8-1:0] m04_wstrb;
    wire                      m04_wlast;   wire                      m04_wvalid;
    wire                      m04_wready;
    wire [AXI_ID_WIDTH-1:0]   m04_bid;     wire [1:0]                m04_bresp;
    wire                      m04_bvalid;  wire                      m04_bready;
    wire [AXI_ID_WIDTH-1:0]   m04_arid;    wire [AXI_ADDR_WIDTH-1:0] m04_araddr;
    wire [7:0]                m04_arlen;   wire [2:0]                m04_arsize;
    wire [1:0]                m04_arburst; wire                      m04_arlock;
    wire [3:0]                m04_arcache; wire [2:0]                m04_arprot;
    wire [3:0]                m04_arqos;   wire [3:0]                m04_arregion;
    wire                      m04_arvalid; wire                      m04_arready;
    wire [AXI_ID_WIDTH-1:0]   m04_rid;     wire [AXI_DATA_WIDTH-1:0] m04_rdata;
    wire [1:0]                m04_rresp;   wire                      m04_rlast;
    wire                      m04_rvalid;  wire                      m04_rready;

    // =========================================================================
    // AXI4 2x5 Crossbar Interconnect Instantiation
    // =========================================================================
    axi_interconnect_wrap_2x5 #(
        .DATA_WIDTH         (AXI_DATA_WIDTH),
        .ADDR_WIDTH         (AXI_ADDR_WIDTH),
        .ID_WIDTH           (AXI_ID_WIDTH),
        .M_REGIONS          (1),

        // m00: AES Accelerator (0x4000_0000, 4 KB)
        .M00_BASE_ADDR      (32'h4000_0000),
        .M00_ADDR_WIDTH     ({1{32'd12}}),
        .M00_CONNECT_READ   (2'b11),
        .M00_CONNECT_WRITE  (2'b11),

        // m01: UART Controller (0x4000_1000, 4 KB)
        .M01_BASE_ADDR      (32'h4000_1000),
        .M01_ADDR_WIDTH     ({1{32'd12}}),
        .M01_CONNECT_READ   (2'b11),
        .M01_CONNECT_WRITE  (2'b11),

        // m02: System Timer (0x4000_2000, 4 KB)
        .M02_BASE_ADDR      (32'h4000_2000),
        .M02_ADDR_WIDTH     ({1{32'd12}}),
        .M02_CONNECT_READ   (2'b11),
        .M02_CONNECT_WRITE  (2'b11),

        // m03: GPIO Controller (0x4000_3000, 4 KB)
        .M03_BASE_ADDR      (32'h4000_3000),
        .M03_ADDR_WIDTH     ({1{32'd12}}),
        .M03_CONNECT_READ   (2'b11),
        .M03_CONNECT_WRITE  (2'b11),

        // m04: SHA-256 Accelerator (0x4000_4000, 4 KB)
        .M04_BASE_ADDR      (32'h4000_4000),
        .M04_ADDR_WIDTH     ({1{32'd12}}),
        .M04_CONNECT_READ   (2'b11),
        .M04_CONNECT_WRITE  (2'b11)
    ) u_interconnect_2x5 (
        .clk                (clk),
        .rst                (rst),

        // --- Slave Port 0: VeeR2 CPU LSU Master ---
        .s00_axi_awid       (s00_awid),
        .s00_axi_awaddr     (s00_awaddr),
        .s00_axi_awlen      (s00_awlen),
        .s00_axi_awsize     (s00_awsize),
        .s00_axi_awburst    (s00_awburst),
        .s00_axi_awlock     (s00_awlock),
        .s00_axi_awcache    (s00_awcache),
        .s00_axi_awprot     (s00_awprot),
        .s00_axi_awqos      (s00_awqos),
        .s00_axi_awuser     (1'b0),
        .s00_axi_awvalid    (s00_awvalid),
        .s00_axi_awready    (s00_awready),
        .s00_axi_wdata      (s00_wdata),
        .s00_axi_wstrb      (s00_wstrb),
        .s00_axi_wlast      (s00_wlast),
        .s00_axi_wuser      (1'b0),
        .s00_axi_wvalid     (s00_wvalid),
        .s00_axi_wready     (s00_wready),
        .s00_axi_bid        (s00_bid),
        .s00_axi_bresp      (s00_bresp),
        .s00_axi_buser      (),
        .s00_axi_bvalid     (s00_bvalid),
        .s00_axi_bready     (s00_bready),
        .s00_axi_arid       (s00_arid),
        .s00_axi_araddr     (s00_araddr),
        .s00_axi_arlen      (s00_arlen),
        .s00_axi_arsize     (s00_arsize),
        .s00_axi_arburst    (s00_arburst),
        .s00_axi_arlock     (s00_arlock),
        .s00_axi_arcache    (s00_arcache),
        .s00_axi_arprot     (s00_arprot),
        .s00_axi_arqos      (s00_arqos),
        .s00_axi_aruser     (1'b0),
        .s00_axi_arvalid    (s00_arvalid),
        .s00_axi_arready    (s00_arready),
        .s00_axi_rid        (s00_rid),
        .s00_axi_rdata      (s00_rdata),
        .s00_axi_rresp      (s00_rresp),
        .s00_axi_rlast      (s00_rlast),
        .s00_axi_ruser      (),
        .s00_axi_rvalid     (s00_rvalid),
        .s00_axi_rready     (s00_rready),

        // --- Slave Port 1: AXI DMA Controller Master ---
        .s01_axi_awid       (s01_awid),
        .s01_axi_awaddr     (s01_awaddr),
        .s01_axi_awlen      (s01_awlen),
        .s01_axi_awsize     (s01_awsize),
        .s01_axi_awburst    (s01_awburst),
        .s01_axi_awlock     (s01_awlock),
        .s01_axi_awcache    (s01_awcache),
        .s01_axi_awprot     (s01_awprot),
        .s01_axi_awqos      (s01_awqos),
        .s01_axi_awuser     (1'b0),
        .s01_axi_awvalid    (s01_awvalid),
        .s01_axi_awready    (s01_awready),
        .s01_axi_wdata      (s01_wdata),
        .s01_axi_wstrb      (s01_wstrb),
        .s01_axi_wlast      (s01_wlast),
        .s01_axi_wuser      (1'b0),
        .s01_axi_wvalid     (s01_wvalid),
        .s01_axi_wready     (s01_wready),
        .s01_axi_bid        (s01_bid),
        .s01_axi_bresp      (s01_bresp),
        .s01_axi_buser      (),
        .s01_axi_bvalid     (s01_bvalid),
        .s01_axi_bready     (s01_bready),
        .s01_axi_arid       (s01_arid),
        .s01_axi_araddr     (s01_araddr),
        .s01_axi_arlen      (s01_arlen),
        .s01_axi_arsize     (s01_arsize),
        .s01_axi_arburst    (s01_arburst),
        .s01_axi_arlock     (s01_arlock),
        .s01_axi_arcache    (s01_arcache),
        .s01_axi_arprot     (s01_arprot),
        .s01_axi_arqos      (s01_arqos),
        .s01_axi_aruser     (1'b0),
        .s01_axi_arvalid    (s01_arvalid),
        .s01_axi_arready    (s01_arready),
        .s01_axi_rid        (s01_rid),
        .s01_axi_rdata      (s01_rdata),
        .s01_axi_rresp      (s01_rresp),
        .s01_axi_rlast      (s01_rlast),
        .s01_axi_ruser      (),
        .s01_axi_rvalid     (s01_rvalid),
        .s01_axi_rready     (s01_rready),

        // --- Master Port 0: m00 (AES) ---
        .m00_axi_awid       (m00_awid),
        .m00_axi_awaddr     (m00_awaddr),
        .m00_axi_awlen      (m00_awlen),
        .m00_axi_awsize     (m00_awsize),
        .m00_axi_awburst    (m00_awburst),
        .m00_axi_awlock     (m00_awlock),
        .m00_axi_awcache    (m00_awcache),
        .m00_axi_awprot     (m00_awprot),
        .m00_axi_awqos      (m00_awqos),
        .m00_axi_awregion   (m00_awregion),
        .m00_axi_awuser     (),
        .m00_axi_awvalid    (m00_awvalid),
        .m00_axi_awready    (m00_awready),
        .m00_axi_wdata      (m00_wdata),
        .m00_axi_wstrb      (m00_wstrb),
        .m00_axi_wlast      (m00_wlast),
        .m00_axi_wuser      (),
        .m00_axi_wvalid     (m00_wvalid),
        .m00_axi_wready     (m00_wready),
        .m00_axi_bid        (m00_bid),
        .m00_axi_bresp      (m00_bresp),
        .m00_axi_buser      (1'b0),
        .m00_axi_bvalid     (m00_bvalid),
        .m00_axi_bready     (m00_bready),
        .m00_axi_arid       (m00_arid),
        .m00_axi_araddr     (m00_araddr),
        .m00_axi_arlen      (m00_arlen),
        .m00_axi_arsize     (m00_arsize),
        .m00_axi_arburst    (m00_arburst),
        .m00_axi_arlock     (m00_arlock),
        .m00_axi_arcache    (m00_arcache),
        .m00_axi_arprot     (m00_arprot),
        .m00_axi_arqos      (m00_arqos),
        .m00_axi_arregion   (m00_arregion),
        .m00_axi_aruser     (),
        .m00_axi_arvalid    (m00_arvalid),
        .m00_axi_arready    (m00_arready),
        .m00_axi_rid        (m00_rid),
        .m00_axi_rdata      (m00_rdata),
        .m00_axi_rresp      (m00_rresp),
        .m00_axi_rlast      (m00_rlast),
        .m00_axi_ruser      (1'b0),
        .m00_axi_rvalid     (m00_rvalid),
        .m00_axi_rready     (m00_rready),

        // --- Master Port 1: m01 (UART) ---
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

        // --- Master Port 2: m02 (Timer) ---
        .m02_axi_awid       (m02_awid),
        .m02_axi_awaddr     (m02_awaddr),
        .m02_axi_awlen      (m02_awlen),
        .m02_axi_awsize     (m02_awsize),
        .m02_axi_awburst    (m02_awburst),
        .m02_axi_awlock     (m02_awlock),
        .m02_axi_awcache    (m02_awcache),
        .m02_axi_awprot     (m02_awprot),
        .m02_axi_awqos      (m02_awqos),
        .m02_axi_awregion   (m02_awregion),
        .m02_axi_awuser     (),
        .m02_axi_awvalid    (m02_awvalid),
        .m02_axi_awready    (m02_awready),
        .m02_axi_wdata      (m02_wdata),
        .m02_axi_wstrb      (m02_wstrb),
        .m02_axi_wlast      (m02_wlast),
        .m02_axi_wuser      (),
        .m02_axi_wvalid     (m02_wvalid),
        .m02_axi_wready     (m02_wready),
        .m02_axi_bid        (m02_bid),
        .m02_axi_bresp      (m02_bresp),
        .m02_axi_buser      (1'b0),
        .m02_axi_bvalid     (m02_bvalid),
        .m02_axi_bready     (m02_bready),
        .m02_axi_arid       (m02_arid),
        .m02_axi_araddr     (m02_araddr),
        .m02_axi_arlen      (m02_arlen),
        .m02_axi_arsize     (m02_arsize),
        .m02_axi_arburst    (m02_arburst),
        .m02_axi_arlock     (m02_arlock),
        .m02_axi_arcache    (m02_arcache),
        .m02_axi_arprot     (m02_arprot),
        .m02_axi_arqos      (m02_arqos),
        .m02_axi_arregion   (m02_arregion),
        .m02_axi_aruser     (),
        .m02_axi_arvalid    (m02_arvalid),
        .m02_axi_arready    (m02_arready),
        .m02_axi_rid        (m02_rid),
        .m02_axi_rdata      (m02_rdata),
        .m02_axi_rresp      (m02_rresp),
        .m02_axi_rlast      (m02_rlast),
        .m02_axi_ruser      (1'b0),
        .m02_axi_rvalid     (m02_rvalid),
        .m02_axi_rready     (m02_rready),

        // --- Master Port 3: m03 (GPIO) ---
        .m03_axi_awid       (m03_awid),
        .m03_axi_awaddr     (m03_awaddr),
        .m03_axi_awlen      (m03_awlen),
        .m03_axi_awsize     (m03_awsize),
        .m03_axi_awburst    (m03_awburst),
        .m03_axi_awlock     (m03_awlock),
        .m03_axi_awcache    (m03_awcache),
        .m03_axi_awprot     (m03_awprot),
        .m03_axi_awqos      (m03_awqos),
        .m03_axi_awregion   (m03_awregion),
        .m03_axi_awuser     (),
        .m03_axi_awvalid    (m03_awvalid),
        .m03_axi_awready    (m03_awready),
        .m03_axi_wdata      (m03_wdata),
        .m03_axi_wstrb      (m03_wstrb),
        .m03_axi_wlast      (m03_wlast),
        .m03_axi_wuser      (),
        .m03_axi_wvalid     (m03_wvalid),
        .m03_axi_wready     (m03_wready),
        .m03_axi_bid        (m03_bid),
        .m03_axi_bresp      (m03_bresp),
        .m03_axi_buser      (1'b0),
        .m03_axi_bvalid     (m03_bvalid),
        .m03_axi_bready     (m03_bready),
        .m03_axi_arid       (m03_arid),
        .m03_axi_araddr     (m03_araddr),
        .m03_axi_arlen      (m03_arlen),
        .m03_axi_arsize     (m03_arsize),
        .m03_axi_arburst    (m03_arburst),
        .m03_axi_arlock     (m03_arlock),
        .m03_axi_arcache    (m03_arcache),
        .m03_axi_arprot     (m03_arprot),
        .m03_axi_arqos      (m03_arqos),
        .m03_axi_arregion   (m03_arregion),
        .m03_axi_aruser     (),
        .m03_axi_arvalid    (m03_arvalid),
        .m03_axi_arready    (m03_arready),
        .m03_axi_rid        (m03_rid),
        .m03_axi_rdata      (m03_rdata),
        .m03_axi_rresp      (m03_rresp),
        .m03_axi_rlast      (m03_rlast),
        .m03_axi_ruser      (1'b0),
        .m03_axi_rvalid     (m03_rvalid),
        .m03_axi_rready     (m03_rready),

        // --- Master Port 4: m04 (SHA) ---
        .m04_axi_awid       (m04_awid),
        .m04_axi_awaddr     (m04_awaddr),
        .m04_axi_awlen      (m04_awlen),
        .m04_axi_awsize     (m04_awsize),
        .m04_axi_awburst    (m04_awburst),
        .m04_axi_awlock     (m04_awlock),
        .m04_axi_awcache    (m04_awcache),
        .m04_axi_awprot     (m04_awprot),
        .m04_axi_awqos      (m04_awqos),
        .m04_axi_awregion   (m04_awregion),
        .m04_axi_awuser     (),
        .m04_axi_awvalid    (m04_awvalid),
        .m04_axi_awready    (m04_awready),
        .m04_axi_wdata      (m04_wdata),
        .m04_axi_wstrb      (m04_wstrb),
        .m04_axi_wlast      (m04_wlast),
        .m04_axi_wuser      (),
        .m04_axi_wvalid     (m04_wvalid),
        .m04_axi_wready     (m04_wready),
        .m04_axi_bid        (m04_bid),
        .m04_axi_bresp      (m04_bresp),
        .m04_axi_buser      (1'b0),
        .m04_axi_bvalid     (m04_bvalid),
        .m04_axi_bready     (m04_bready),
        .m04_axi_arid       (m04_arid),
        .m04_axi_araddr     (m04_araddr),
        .m04_axi_arlen      (m04_arlen),
        .m04_axi_arsize     (m04_arsize),
        .m04_axi_arburst    (m04_arburst),
        .m04_axi_arlock     (m04_arlock),
        .m04_axi_arcache    (m04_arcache),
        .m04_axi_arprot     (m04_arprot),
        .m04_axi_arqos      (m04_arqos),
        .m04_axi_arregion   (m04_arregion),
        .m04_axi_aruser     (),
        .m04_axi_arvalid    (m04_arvalid),
        .m04_axi_arready    (m04_arready),
        .m04_axi_rid        (m04_rid),
        .m04_axi_rdata      (m04_rdata),
        .m04_axi_rresp      (m04_rresp),
        .m04_axi_rlast      (m04_rlast),
        .m04_axi_ruser      (1'b0),
        .m04_axi_rvalid     (m04_rvalid),
        .m04_axi_rready     (m04_rready)
    );

    // =========================================================================
    // Protocol Bridges (AXI4-Full to AXI4-Lite) for m00..m04
    // =========================================================================

    // --- m00 -> Bridge -> AES-256 ---
    wire [7:0]  aes_awaddr, aes_araddr;
    wire [31:0] aes_wdata,  aes_rdata;
    wire [3:0]  aes_wstrb;
    wire [2:0]  aes_awprot, aes_arprot;
    wire        aes_awvalid, aes_awready;
    wire        aes_wvalid,  aes_wready;
    wire [1:0]  aes_bresp,   aes_rresp;
    wire        aes_bvalid,  aes_bready;
    wire        aes_arvalid, aes_arready;
    wire        aes_rvalid,  aes_rready;

    axi_to_axilite_bridge #(
        .DATA_WIDTH   (32),
        .M_ADDR_WIDTH (32),
        .S_ADDR_WIDTH (8),
        .M_ID_WIDTH   (AXI_ID_WIDTH),
        .S_ID_WIDTH   (4)
    ) u_bridge_aes (
        .aclk         (clk),
        .aresetn      (aresetn),
        .s_axi_awid   (m00_awid),    .s_axi_awaddr  (m00_awaddr),
        .s_axi_awlen  (m00_awlen),   .s_axi_awsize  (m00_awsize),
        .s_axi_awburst(m00_awburst), .s_axi_awlock  (m00_awlock),
        .s_axi_awcache(m00_awcache), .s_axi_awprot  (m00_awprot),
        .s_axi_awqos  (m00_awqos),   .s_axi_awregion(m00_awregion),
        .s_axi_awvalid(m00_awvalid), .s_axi_awready (m00_awready),
        .s_axi_wdata  (m00_wdata),   .s_axi_wstrb   (m00_wstrb),
        .s_axi_wlast  (m00_wlast),   .s_axi_wvalid  (m00_wvalid),
        .s_axi_wready (m00_wready),  .s_axi_bid     (m00_bid),
        .s_axi_bresp  (m00_bresp),   .s_axi_bvalid  (m00_bvalid),
        .s_axi_bready (m00_bready),  .s_axi_arid    (m00_arid),
        .s_axi_araddr (m00_araddr),  .s_axi_arlen   (m00_arlen),
        .s_axi_arsize (m00_arsize),  .s_axi_arburst (m00_arburst),
        .s_axi_arlock (m00_arlock),  .s_axi_arcache (m00_arcache),
        .s_axi_arprot (m00_arprot),  .s_axi_arqos   (m00_arqos),
        .s_axi_arregion(m00_arregion),.s_axi_arvalid(m00_arvalid),
        .s_axi_arready(m00_arready), .s_axi_rid     (m00_rid),
        .s_axi_rdata  (m00_rdata),   .s_axi_rresp   (m00_rresp),
        .s_axi_rlast  (m00_rlast),   .s_axi_rvalid  (m00_rvalid),
        .s_axi_rready (m00_rready),
        // Lite side
        .m_axi_awid   (),            .m_axi_awaddr  (aes_awaddr),
        .m_axi_awvalid(aes_awvalid), .m_axi_awready (aes_awready),
        .m_axi_wdata  (aes_wdata),   .m_axi_wstrb   (aes_wstrb),
        .m_axi_wvalid (aes_wvalid),  .m_axi_wready  (aes_wready),
        .m_axi_bid    (4'h0),        .m_axi_bresp   (aes_bresp),
        .m_axi_bvalid (aes_bvalid),  .m_axi_bready  (aes_bready),
        .m_axi_arid   (),            .m_axi_araddr  (aes_araddr),
        .m_axi_arvalid(aes_arvalid), .m_axi_arready (aes_arready),
        .m_axi_rid    (4'h0),        .m_axi_rdata   (aes_rdata),
        .m_axi_rresp  (aes_rresp),   .m_axi_rvalid  (aes_rvalid),
        .m_axi_rready (aes_rready)
    );

    // --- Slave 0: AES-256 Accelerator Top ---
    aes_core_top #(
        .AXI_ADDR_WIDTH (8)
    ) u_aes (
        .aclk           (clk),
        .aresetn        (aresetn),
        .s_axi_awaddr   (aes_awaddr),
        .s_axi_awprot   (3'h0),
        .s_axi_awvalid  (aes_awvalid),
        .s_axi_awready  (aes_awready),
        .s_axi_wdata    (aes_wdata),
        .s_axi_wstrb    (aes_wstrb),
        .s_axi_wvalid   (aes_wvalid),
        .s_axi_wready   (aes_wready),
        .s_axi_bresp    (aes_bresp),
        .s_axi_bvalid   (aes_bvalid),
        .s_axi_bready   (aes_bready),
        .s_axi_araddr   (aes_araddr),
        .s_axi_arprot   (3'h0),
        .s_axi_arvalid  (aes_arvalid),
        .s_axi_arready  (aes_arready),
        .s_axi_rdata    (aes_rdata),
        .s_axi_rresp    (aes_rresp),
        .s_axi_rvalid   (aes_rvalid),
        .s_axi_rready   (aes_rready),
        .irq            (aes_irq)
    );

    // --- m01 -> Bridge -> UART ---
    wire [3:0]  uart_awid,   uart_arid, uart_bid, uart_rid;
    wire [7:0]  uart_awaddr, uart_araddr;
    wire [31:0] uart_wdata,  uart_rdata;
    wire [3:0]  uart_wstrb;
    wire        uart_awvalid, uart_awready;
    wire        uart_wvalid,  uart_wready;
    wire [1:0]  uart_bresp,   uart_rresp;
    wire        uart_bvalid,  uart_bready;
    wire        uart_arvalid, uart_arready;
    wire        uart_rvalid,  uart_rready;

    axi_to_axilite_bridge #(
        .DATA_WIDTH   (32),
        .M_ADDR_WIDTH (32),
        .S_ADDR_WIDTH (8),
        .M_ID_WIDTH   (AXI_ID_WIDTH),
        .S_ID_WIDTH   (4)
    ) u_bridge_uart (
        .aclk         (clk),
        .aresetn      (aresetn),
        .s_axi_awid   (m01_awid),    .s_axi_awaddr  (m01_awaddr),
        .s_axi_awlen  (m01_awlen),   .s_axi_awsize  (m01_awsize),
        .s_axi_awburst(m01_awburst), .s_axi_awlock  (m01_awlock),
        .s_axi_awcache(m01_awcache), .s_axi_awprot  (m01_awprot),
        .s_axi_awqos  (m01_awqos),   .s_axi_awregion(m01_awregion),
        .s_axi_awvalid(m01_awvalid), .s_axi_awready (m01_awready),
        .s_axi_wdata  (m01_wdata),   .s_axi_wstrb   (m01_wstrb),
        .s_axi_wlast  (m01_wlast),   .s_axi_wvalid  (m01_wvalid),
        .s_axi_wready (m01_wready),  .s_axi_bid     (m01_bid),
        .s_axi_bresp  (m01_bresp),   .s_axi_bvalid  (m01_bvalid),
        .s_axi_bready (m01_bready),  .s_axi_arid    (m01_arid),
        .s_axi_araddr (m01_araddr),  .s_axi_arlen   (m01_arlen),
        .s_axi_arsize (m01_arsize),  .s_axi_arburst (m01_arburst),
        .s_axi_arlock (m01_arlock),  .s_axi_arcache (m01_arcache),
        .s_axi_arprot (m01_arprot),  .s_axi_arqos   (m01_arqos),
        .s_axi_arregion(m01_arregion),.s_axi_arvalid(m01_arvalid),
        .s_axi_arready(m01_arready), .s_axi_rid     (m01_rid),
        .s_axi_rdata  (m01_rdata),   .s_axi_rresp   (m01_rresp),
        .s_axi_rlast  (m01_rlast),   .s_axi_rvalid  (m01_rvalid),
        .s_axi_rready (m01_rready),
        // Lite side
        .m_axi_awid   (uart_awid),   .m_axi_awaddr  (uart_awaddr),
        .m_axi_awvalid(uart_awvalid),.m_axi_awready (uart_awready),
        .m_axi_wdata  (uart_wdata),  .m_axi_wstrb   (uart_wstrb),
        .m_axi_wvalid (uart_wvalid), .m_axi_wready  (uart_wready),
        .m_axi_bid    (uart_bid),    .m_axi_bresp   (uart_bresp),
        .m_axi_bvalid (uart_bvalid), .m_axi_bready  (uart_bready),
        .m_axi_arid   (uart_arid),   .m_axi_araddr  (uart_araddr),
        .m_axi_arvalid(uart_arvalid),.m_axi_arready (uart_arready),
        .m_axi_rid    (uart_rid),    .m_axi_rdata   (uart_rdata),
        .m_axi_rresp  (uart_rresp),  .m_axi_rvalid  (uart_rvalid),
        .m_axi_rready (uart_rready)
    );

    // --- Slave 1: UART Controller Top ---
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

    // --- m02 -> Bridge -> System Timer ---
    wire [11:0] timer_awaddr, timer_araddr;
    wire [31:0] timer_wdata,  timer_rdata;
    wire [3:0]  timer_wstrb;
    wire        timer_awvalid, timer_awready;
    wire        timer_wvalid,  timer_wready;
    wire [1:0]  timer_bresp,   timer_rresp;
    wire        timer_bvalid,  timer_bready;
    wire        timer_arvalid, timer_arready;
    wire        timer_rvalid,  timer_rready;

    axi_to_axilite_bridge #(
        .DATA_WIDTH   (32),
        .M_ADDR_WIDTH (32),
        .S_ADDR_WIDTH (12),
        .M_ID_WIDTH   (AXI_ID_WIDTH),
        .S_ID_WIDTH   (4)
    ) u_bridge_timer (
        .aclk         (clk),
        .aresetn      (aresetn),
        .s_axi_awid   (m02_awid),    .s_axi_awaddr  (m02_awaddr),
        .s_axi_awlen  (m02_awlen),   .s_axi_awsize  (m02_awsize),
        .s_axi_awburst(m02_awburst), .s_axi_awlock  (m02_awlock),
        .s_axi_awcache(m02_awcache), .s_axi_awprot  (m02_awprot),
        .s_axi_awqos  (m02_awqos),   .s_axi_awregion(m02_awregion),
        .s_axi_awvalid(m02_awvalid), .s_axi_awready (m02_awready),
        .s_axi_wdata  (m02_wdata),   .s_axi_wstrb   (m02_wstrb),
        .s_axi_wlast  (m02_wlast),   .s_axi_wvalid  (m02_wvalid),
        .s_axi_wready (m02_wready),  .s_axi_bid     (m02_bid),
        .s_axi_bresp  (m02_bresp),   .s_axi_bvalid  (m02_bvalid),
        .s_axi_bready (m02_bready),  .s_axi_arid    (m02_arid),
        .s_axi_araddr (m02_araddr),  .s_axi_arlen   (m02_arlen),
        .s_axi_arsize (m02_arsize),  .s_axi_arburst (m02_arburst),
        .s_axi_arlock (m02_arlock),  .s_axi_arcache (m02_arcache),
        .s_axi_arprot (m02_arprot),  .s_axi_arqos   (m02_arqos),
        .s_axi_arregion(m02_arregion),.s_axi_arvalid(m02_arvalid),
        .s_axi_arready(m02_arready), .s_axi_rid     (m02_rid),
        .s_axi_rdata  (m02_rdata),   .s_axi_rresp   (m02_rresp),
        .s_axi_rlast  (m02_rlast),   .s_axi_rvalid  (m02_rvalid),
        .s_axi_rready (m02_rready),
        // Lite side
        .m_axi_awid   (),            .m_axi_awaddr  (timer_awaddr),
        .m_axi_awvalid(timer_awvalid),.m_axi_awready(timer_awready),
        .m_axi_wdata  (timer_wdata),  .m_axi_wstrb  (timer_wstrb),
        .m_axi_wvalid (timer_wvalid), .m_axi_wready (timer_wready),
        .m_axi_bid    (4'h0),        .m_axi_bresp   (timer_bresp),
        .m_axi_bvalid (timer_bvalid), .m_axi_bready (timer_bready),
        .m_axi_arid   (),            .m_axi_araddr  (timer_araddr),
        .m_axi_arvalid(timer_arvalid),.m_axi_arready(timer_arready),
        .m_axi_rid    (4'h0),        .m_axi_rdata   (timer_rdata),
        .m_axi_rresp  (timer_rresp),  .m_axi_rvalid  (timer_rvalid),
        .m_axi_rready (timer_rready)
    );

    // --- Slave 2: System Timer Top ---
    axi_timer_top #(
        .AXI_ADDR_WIDTH (12),
        .AXI_DATA_WIDTH (32)
    ) u_timer (
        .aclk           (clk),
        .aresetn        (aresetn),
        .s_axi_awaddr   (timer_awaddr),
        .s_axi_awprot   (3'h0),
        .s_axi_awvalid  (timer_awvalid),
        .s_axi_awready  (timer_awready),
        .s_axi_wdata    (timer_wdata),
        .s_axi_wstrb    (timer_wstrb),
        .s_axi_wvalid   (timer_wvalid),
        .s_axi_wready   (timer_wready),
        .s_axi_bresp    (timer_bresp),
        .s_axi_bvalid   (timer_bvalid),
        .s_axi_bready   (timer_bready),
        .s_axi_araddr   (timer_araddr),
        .s_axi_arprot   (3'h0),
        .s_axi_arvalid  (timer_arvalid),
        .s_axi_arready  (timer_arready),
        .s_axi_rdata    (timer_rdata),
        .s_axi_rresp    (timer_rresp),
        .s_axi_rvalid   (timer_rvalid),
        .s_axi_rready   (timer_rready),
        .timer_irq      (timer_irq)
    );

    // --- m03 -> Bridge -> GPIO ---
    wire [11:0] gpio_awaddr, gpio_araddr;
    wire [31:0] gpio_wdata,  gpio_rdata;
    wire [3:0]  gpio_wstrb;
    wire        gpio_awvalid, gpio_awready;
    wire        gpio_wvalid,  gpio_wready;
    wire [1:0]  gpio_bresp,   gpio_rresp;
    wire        gpio_bvalid,  gpio_bready;
    wire        gpio_arvalid, gpio_arready;
    wire        gpio_rvalid,  gpio_rready;

    axi_to_axilite_bridge #(
        .DATA_WIDTH   (32),
        .M_ADDR_WIDTH (32),
        .S_ADDR_WIDTH (12),
        .M_ID_WIDTH   (AXI_ID_WIDTH),
        .S_ID_WIDTH   (4)
    ) u_bridge_gpio (
        .aclk         (clk),
        .aresetn      (aresetn),
        .s_axi_awid   (m03_awid),    .s_axi_awaddr  (m03_awaddr),
        .s_axi_awlen  (m03_awlen),   .s_axi_awsize  (m03_awsize),
        .s_axi_awburst(m03_awburst), .s_axi_awlock  (m03_awlock),
        .s_axi_awcache(m03_awcache), .s_axi_awprot  (m03_awprot),
        .s_axi_awqos  (m03_awqos),   .s_axi_awregion(m03_awregion),
        .s_axi_awvalid(m03_awvalid), .s_axi_awready (m03_awready),
        .s_axi_wdata  (m03_wdata),   .s_axi_wstrb   (m03_wstrb),
        .s_axi_wlast  (m03_wlast),   .s_axi_wvalid  (m03_wvalid),
        .s_axi_wready (m03_wready),  .s_axi_bid     (m03_bid),
        .s_axi_bresp  (m03_bresp),   .s_axi_bvalid  (m03_bvalid),
        .s_axi_bready (m03_bready),  .s_axi_arid    (m03_arid),
        .s_axi_araddr (m03_araddr),  .s_axi_arlen   (m03_arlen),
        .s_axi_arsize (m03_arsize),  .s_axi_arburst (m03_arburst),
        .s_axi_arlock (m03_arlock),  .s_axi_arcache (m03_arcache),
        .s_axi_arprot (m03_arprot),  .s_axi_arqos   (m03_arqos),
        .s_axi_arregion(m03_arregion),.s_axi_arvalid(m03_arvalid),
        .s_axi_arready(m03_arready), .s_axi_rid     (m03_rid),
        .s_axi_rdata  (m03_rdata),   .s_axi_rresp   (m03_rresp),
        .s_axi_rlast  (m03_rlast),   .s_axi_rvalid  (m03_rvalid),
        .s_axi_rready (m03_rready),
        // Lite side
        .m_axi_awid   (),            .m_axi_awaddr  (gpio_awaddr),
        .m_axi_awvalid(gpio_awvalid),.m_axi_awready (gpio_awready),
        .m_axi_wdata  (gpio_wdata),  .m_axi_wstrb   (gpio_wstrb),
        .m_axi_wvalid (gpio_wvalid), .m_axi_wready  (gpio_wready),
        .m_axi_bid    (4'h0),        .m_axi_bresp   (gpio_bresp),
        .m_axi_bvalid (gpio_bvalid), .m_axi_bready  (gpio_bready),
        .m_axi_arid   (),            .m_axi_araddr  (gpio_araddr),
        .m_axi_arvalid(gpio_arvalid),.m_axi_arready (gpio_arready),
        .m_axi_rid    (4'h0),        .m_axi_rdata   (gpio_rdata),
        .m_axi_rresp  (gpio_rresp),  .m_axi_rvalid  (gpio_rvalid),
        .m_axi_rready (gpio_rready)
    );

    // --- Slave 3: GPIO Controller Top ---
    axi_gpio_top #(
        .AXI_ADDR_WIDTH (12),
        .AXI_DATA_WIDTH (32)
    ) u_gpio (
        .aclk           (clk),
        .aresetn        (aresetn),
        .s_axi_awaddr   (gpio_awaddr),
        .s_axi_awprot   (3'h0),
        .s_axi_awvalid  (gpio_awvalid),
        .s_axi_awready  (gpio_awready),
        .s_axi_wdata    (gpio_wdata),
        .s_axi_wstrb    (gpio_wstrb),
        .s_axi_wvalid   (gpio_wvalid),
        .s_axi_wready   (gpio_wready),
        .s_axi_bresp    (gpio_bresp),
        .s_axi_bvalid   (gpio_bvalid),
        .s_axi_bready   (gpio_bready),
        .s_axi_araddr   (gpio_araddr),
        .s_axi_arprot   (3'h0),
        .s_axi_arvalid  (gpio_arvalid),
        .s_axi_arready  (gpio_arready),
        .s_axi_rdata    (gpio_rdata),
        .s_axi_rresp    (gpio_rresp),
        .s_axi_rvalid   (gpio_rvalid),
        .s_axi_rready   (gpio_rready),
        .gpio_i         (gpio_i),
        .gpio_o         (gpio_o),
        .gpio_dir_o     (gpio_dir_o),
        .gpio_intr_o    (gpio_intr)
    );

    // --- m04 -> Bridge -> SHA-256 ---
    wire [11:0] sha_awaddr, sha_araddr;
    wire [31:0] sha_wdata,  sha_rdata;
    wire [3:0]  sha_wstrb;
    wire        sha_awvalid, sha_awready;
    wire        sha_wvalid,  sha_wready;
    wire [1:0]  sha_bresp,   sha_rresp;
    wire        sha_bvalid,  sha_bready;
    wire        sha_arvalid, sha_arready;
    wire        sha_rvalid,  sha_rready;

    axi_to_axilite_bridge #(
        .DATA_WIDTH   (32),
        .M_ADDR_WIDTH (32),
        .S_ADDR_WIDTH (12),
        .M_ID_WIDTH   (AXI_ID_WIDTH),
        .S_ID_WIDTH   (4)
    ) u_bridge_sha (
        .aclk         (clk),
        .aresetn      (aresetn),
        .s_axi_awid   (m04_awid),    .s_axi_awaddr  (m04_awaddr),
        .s_axi_awlen  (m04_awlen),   .s_axi_awsize  (m04_awsize),
        .s_axi_awburst(m04_awburst), .s_axi_awlock  (m04_awlock),
        .s_axi_awcache(m04_awcache), .s_axi_awprot  (m04_awprot),
        .s_axi_awqos  (m04_awqos),   .s_axi_awregion(m04_awregion),
        .s_axi_awvalid(m04_awvalid), .s_axi_awready (m04_awready),
        .s_axi_wdata  (m04_wdata),   .s_axi_wstrb   (m04_wstrb),
        .s_axi_wlast  (m04_wlast),   .s_axi_wvalid  (m04_wvalid),
        .s_axi_wready (m04_wready),  .s_axi_bid     (m04_bid),
        .s_axi_bresp  (m04_bresp),   .s_axi_bvalid  (m04_bvalid),
        .s_axi_bready (m04_bready),  .s_axi_arid    (m04_arid),
        .s_axi_araddr (m04_araddr),  .s_axi_arlen   (m04_arlen),
        .s_axi_arsize (m04_arsize),  .s_axi_arburst (m04_arburst),
        .s_axi_arlock (m04_arlock),  .s_axi_arcache (m04_arcache),
        .s_axi_arprot (m04_arprot),  .s_axi_arqos   (m04_arqos),
        .s_axi_arregion(m04_arregion),.s_axi_arvalid(m04_arvalid),
        .s_axi_arready(m04_arready), .s_axi_rid     (m04_rid),
        .s_axi_rdata  (m04_rdata),   .s_axi_rresp   (m04_rresp),
        .s_axi_rlast  (m04_rlast),   .s_axi_rvalid  (m04_rvalid),
        .s_axi_rready (m04_rready),
        // Lite side
        .m_axi_awid   (),            .m_axi_awaddr  (sha_awaddr),
        .m_axi_awvalid(sha_awvalid), .m_axi_awready (sha_awready),
        .m_axi_wdata  (sha_wdata),   .m_axi_wstrb   (sha_wstrb),
        .m_axi_wvalid (sha_wvalid),  .m_axi_wready  (sha_wready),
        .m_axi_bid    (4'h0),        .m_axi_bresp   (sha_bresp),
        .m_axi_bvalid (sha_bvalid),  .m_axi_bready  (sha_bready),
        .m_axi_arid   (),            .m_axi_araddr  (sha_araddr),
        .m_axi_arvalid(sha_arvalid), .m_axi_arready (sha_arready),
        .m_axi_rid    (4'h0),        .m_axi_rdata   (sha_rdata),
        .m_axi_rresp  (sha_rresp),   .m_axi_rvalid  (sha_rvalid),
        .m_axi_rready (sha_rready)
    );

    // --- Slave 4: SHA-256 Accelerator Top ---
    axi_sha256_top #(
        .AXI_ADDR_WIDTH (12),
        .AXI_DATA_WIDTH (32)
    ) u_sha (
        .aclk           (clk),
        .aresetn        (aresetn),
        .s_axi_awaddr   (sha_awaddr),
        .s_axi_awprot   (3'h0),
        .s_axi_awvalid  (sha_awvalid),
        .s_axi_awready  (sha_awready),
        .s_axi_wdata    (sha_wdata),
        .s_axi_wstrb    (sha_wstrb),
        .s_axi_wvalid   (sha_wvalid),
        .s_axi_wready   (sha_wready),
        .s_axi_bresp    (sha_bresp),
        .s_axi_bvalid   (sha_bvalid),
        .s_axi_bready   (sha_bready),
        .s_axi_araddr   (sha_araddr),
        .s_axi_arprot   (3'h0),
        .s_axi_arvalid  (sha_arvalid),
        .s_axi_arready  (sha_arready),
        .s_axi_rdata    (sha_rdata),
        .s_axi_rresp    (sha_rresp),
        .s_axi_rvalid   (sha_rvalid),
        .s_axi_rready   (sha_rready),
        .sha_irq        (sha_irq)
    );

endmodule

`default_nettype wire
