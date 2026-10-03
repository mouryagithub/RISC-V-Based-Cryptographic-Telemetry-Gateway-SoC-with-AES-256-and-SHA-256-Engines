// =============================================================================
// File        : axi_timer_top.v
// Module      : axi_timer_top
// Project     : RISC-V Cryptographic Telemetry Gateway SoC
// Description : AXI4-Lite slave wrapper for OpenTitan-compliant 64-bit Real-Time
//               System Timer (rv_timer).
//
// Register Map (Base: 0x4000_2000, 4 KB Window):
//   Offset   Register Name      Type  Reset Value   Description
//   0x000    ALERT_TEST         WO    0x0000_0000   Alert test register
//   0x004    CTRL               RW    0x0000_0000   Bit [0]: active enable
//   0x100    INTR_ENABLE0       RW    0x0000_0000   Bit [0]: Hart 0 timer IRQ enable
//   0x104    INTR_STATE0        RW1C  0x0000_0000   Bit [0]: Hart 0 timer IRQ state
//   0x108    INTR_TEST0         WO    0x0000_0000   Bit [0]: Software IRQ test
//   0x10C    CFG0               RW    0x0000_0000   [11:0] prescale, [23:16] step
//   0x110    TIMER_V_LOWER0     RW    0x0000_0000   mtime lower 32 bits [31:0]
//   0x114    TIMER_V_UPPER0     RW    0x0000_0000   mtime upper 32 bits [63:32]
//   0x118    COMPARE_LOWER0_0   RW    0xFFFF_FFFF   mtimecmp lower 32 bits [31:0]
//   0x11C    COMPARE_UPPER0_0   RW    0xFFFF_FFFF   mtimecmp upper 32 bits [63:32]
// =============================================================================

`timescale 1ns/1ps
`default_nettype none

module axi_timer_top #(
    parameter AXI_ADDR_WIDTH = 12,
    parameter AXI_DATA_WIDTH = 32
)(
    // Clock & Reset
    input  wire                       aclk,
    input  wire                       aresetn,

    // AXI4-Lite Write Address Channel
    input  wire [AXI_ADDR_WIDTH-1:0]  s_axi_awaddr,
    input  wire [2:0]                 s_axi_awprot,
    input  wire                       s_axi_awvalid,
    output reg                        s_axi_awready,

    // AXI4-Lite Write Data Channel
    input  wire [AXI_DATA_WIDTH-1:0]  s_axi_wdata,
    input  wire [3:0]                 s_axi_wstrb,
    input  wire                       s_axi_wvalid,
    output reg                        s_axi_wready,

    // AXI4-Lite Write Response Channel
    output reg  [1:0]                 s_axi_bresp,
    output reg                        s_axi_bvalid,
    input  wire                       s_axi_bready,

    // AXI4-Lite Read Address Channel
    input  wire [AXI_ADDR_WIDTH-1:0]  s_axi_araddr,
    input  wire [2:0]                 s_axi_arprot,
    input  wire                       s_axi_arvalid,
    output reg                        s_axi_arready,

    // AXI4-Lite Read Data Channel
    output reg  [AXI_DATA_WIDTH-1:0]  s_axi_rdata,
    output reg  [1:0]                 s_axi_rresp,
    output reg                        s_axi_rvalid,
    input  wire                       s_axi_rready,

    // Interrupt output to SoC PIC
    output wire                       timer_irq
);

    // Internal Registers
    reg        reg_active;
    reg [11:0] reg_prescale;
    reg [7:0]  reg_step;
    reg        reg_intr_en;
    reg        reg_intr_state;
    reg [63:0] reg_mtime;
    reg [63:0] reg_mtimecmp;

    // Timer core signals
    wire        core_tick;
    wire [63:0] core_mtime_d;
    wire [0:0]  core_intr;

    // Connect OpenTitan timer_core
    timer_core #(.N(1)) u_timer_core (
        .clk_i       (aclk),
        .rst_ni      (aresetn),
        .active      (reg_active),
        .prescaler   (reg_prescale),
        .step        (reg_step),
        .tick        (core_tick),
        .mtime_d     (core_mtime_d),
        .mtime       (reg_mtime),
        .mtimecmp    ('{reg_mtimecmp}),
        .intr        (core_intr)
    );

    // Timer Counter Increment and IRQ Latch Logic
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            reg_mtime      <= 64'd0;
            reg_intr_state <= 1'b0;
        end else begin
            // Increment counter on tick
            if (reg_active && core_tick) begin
                reg_mtime <= core_mtime_d;
            end

            // Latch comparator interrupt
            if (core_intr[0]) begin
                reg_intr_state <= 1'b1;
            end
        end
    end

    // AXI-Lite Write Channels
    reg [1:0] wr_state;
    localparam WR_IDLE = 2'd0;
    localparam WR_RESP = 2'd1;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_awready  <= 1'b0;
            s_axi_wready   <= 1'b0;
            s_axi_bvalid   <= 1'b0;
            s_axi_bresp    <= 2'b00;
            wr_state       <= WR_IDLE;
            reg_active     <= 1'b0;
            reg_prescale   <= 12'd0;
            reg_step       <= 8'd1;
            reg_intr_en    <= 1'b0;
            reg_mtimecmp   <= 64'hFFFF_FFFF_FFFF_FFFF;
        end else begin
            case (wr_state)
                WR_IDLE: begin
                    if (s_axi_awvalid && s_axi_wvalid) begin
                        s_axi_awready <= 1'b1;
                        s_axi_wready  <= 1'b1;
                        s_axi_bvalid  <= 1'b1;
                        s_axi_bresp   <= 2'b00;
                        wr_state      <= WR_RESP;

                        // Decode register writes
                        case (s_axi_awaddr[11:0])
                            12'h004: reg_active               <= s_axi_wdata[0];
                            12'h100: reg_intr_en              <= s_axi_wdata[0];
                            12'h104: if (s_axi_wdata[0]) reg_intr_state <= 1'b0; // RW1C
                            12'h108: if (s_axi_wdata[0]) reg_intr_state <= 1'b1; // Test IRQ
                            12'h10C: begin
                                reg_prescale <= s_axi_wdata[11:0];
                                reg_step     <= s_axi_wdata[23:16];
                            end
                            12'h110: reg_mtime[31:0]          <= s_axi_wdata;
                            12'h114: reg_mtime[63:32]         <= s_axi_wdata;
                            12'h118: reg_mtimecmp[31:0]       <= s_axi_wdata;
                            12'h11C: reg_mtimecmp[63:32]      <= s_axi_wdata;
                            default: ;
                        endcase
                    end else begin
                        s_axi_awready <= 1'b0;
                        s_axi_wready  <= 1'b0;
                    end
                end

                WR_RESP: begin
                    s_axi_awready <= 1'b0;
                    s_axi_wready  <= 1'b0;
                    if (s_axi_bready) begin
                        s_axi_bvalid <= 1'b0;
                        wr_state     <= WR_IDLE;
                    end
                end
            endcase
        end
    end

    // AXI-Lite Read Channels
    reg [1:0] rd_state;
    localparam RD_IDLE = 2'd0;
    localparam RD_DATA = 2'd1;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rresp   <= 2'b00;
            s_axi_rdata   <= 32'h0;
            rd_state      <= RD_IDLE;
        end else begin
            case (rd_state)
                RD_IDLE: begin
                    if (s_axi_arvalid) begin
                        s_axi_arready <= 1'b1;
                        s_axi_rvalid  <= 1'b1;
                        s_axi_rresp   <= 2'b00;
                        rd_state      <= RD_DATA;

                        case (s_axi_araddr[11:0])
                            12'h000: s_axi_rdata <= 32'h0;
                            12'h004: s_axi_rdata <= {31'h0, reg_active};
                            12'h100: s_axi_rdata <= {31'h0, reg_intr_en};
                            12'h104: s_axi_rdata <= {31'h0, reg_intr_state};
                            12'h108: s_axi_rdata <= 32'h0;
                            12'h10C: s_axi_rdata <= {8'h0, reg_step, 4'h0, reg_prescale};
                            12'h110: s_axi_rdata <= reg_mtime[31:0];
                            12'h114: s_axi_rdata <= reg_mtime[63:32];
                            12'h118: s_axi_rdata <= reg_mtimecmp[31:0];
                            12'h11C: s_axi_rdata <= reg_mtimecmp[63:32];
                            default: s_axi_rdata <= 32'h0;
                        endcase
                    end else begin
                        s_axi_arready <= 1'b0;
                    end
                end

                RD_DATA: begin
                    s_axi_arready <= 1'b0;
                    if (s_axi_rready) begin
                        s_axi_rvalid <= 1'b0;
                        rd_state     <= RD_IDLE;
                    end
                end
            endcase
        end
    end

    // Interrupt Generation
    assign timer_irq = reg_intr_en & reg_intr_state;

endmodule

`default_nettype wire
