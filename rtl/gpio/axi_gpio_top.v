// =============================================================================
// File        : axi_gpio_top.v
// Module      : axi_gpio_top
// Project     : RISC-V Cryptographic Telemetry Gateway SoC
// Description : AXI4-Lite slave wrapper for 64-pin General-Purpose I/O Controller
//               with atomic bit operations and edge/level interrupt generation.
//
// Register Map (Base: 0x4000_3000, 4 KB Window):
//   Offset   Register Name           Type   Description
//   0x000    GPIO_INFO               RO     Reads 64 (implemented pin count)
//   0x004    GPIO_CFG                RW     Global GPIO configuration
//   0x008    GPIO_MODE               RW     Pin multiplexer mode selection
//   0x080    GPIO_EN_0               RW     Output enable pins [31:0] (1=Out, 0=In)
//   0x084    GPIO_EN_1               RW     Output enable pins [63:32]
//   0x100    GPIO_IN_0               RO     Sampled raw inputs pins [31:0]
//   0x104    GPIO_IN_1               RO     Sampled raw inputs pins [63:32]
//   0x180    GPIO_OUT_0              RW     Output drive data pins [31:0]
//   0x184    GPIO_OUT_1              RW     Output drive data pins [63:32]
//   0x200    GPIO_SET_0              WO     Atomic bit set pins [31:0]
//   0x204    GPIO_SET_1              WO     Atomic bit set pins [63:32]
//   0x280    GPIO_CLEAR_0            WO     Atomic bit clear pins [31:0]
//   0x284    GPIO_CLEAR_1            WO     Atomic bit clear pins [63:32]
//   0x300    GPIO_TOGGLE_0           WO     Atomic bit toggle pins [31:0]
//   0x304    GPIO_TOGGLE_1           WO     Atomic bit toggle pins [63:32]
//   0x380    INTRPT_RISE_EN_0        RW     Rising-edge IRQ enable [31:0]
//   0x384    INTRPT_RISE_EN_1        RW     Rising-edge IRQ enable [63:32]
//   0x400    INTRPT_FALL_EN_0        RW     Falling-edge IRQ enable [31:0]
//   0x404    INTRPT_FALL_EN_1        RW     Falling-edge IRQ enable [63:32]
//   0x480    INTRPT_LVL_HIGH_EN_0    RW     Active-high IRQ enable [31:0]
//   0x484    INTRPT_LVL_HIGH_EN_1    RW     Active-high IRQ enable [63:32]
//   0x500    INTRPT_LVL_LOW_EN_0     RW     Active-low IRQ enable [31:0]
//   0x504    INTRPT_LVL_LOW_EN_1     RW     Active-low IRQ enable [63:32]
//   0x580    INTRPT_STATUS_0         RW1C   Cumulative IRQ status [31:0]
//   0x584    INTRPT_STATUS_1         RW1C   Cumulative IRQ status [63:32]
// =============================================================================

`timescale 1ns/1ps
`default_nettype none

module axi_gpio_top #(
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

    // External GPIO Pins
    input  wire [63:0]                gpio_i,
    output wire [63:0]                gpio_o,
    output wire [63:0]                gpio_dir_o,

    // Interrupts to SoC PIC (Bank 0 = IRQ 7, Bank 1 = IRQ 8)
    output wire [1:0]                 gpio_intr_o
);

    // Register Storage
    reg [31:0] reg_cfg;
    reg [31:0] reg_mode;
    reg [31:0] reg_en_0, reg_en_1;
    reg [31:0] reg_out_0, reg_out_1;
    reg [31:0] reg_rise_en_0, reg_rise_en_1;
    reg [31:0] reg_fall_en_0, reg_fall_en_1;
    reg [31:0] reg_high_en_0, reg_high_en_1;
    reg [31:0] reg_low_en_0,  reg_low_en_1;
    reg [31:0] reg_status_0,  reg_status_1;

    // Synchronize GPIO inputs to aclk
    reg [63:0] gpio_sync_0, gpio_sync_1, gpio_sync_2;
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            gpio_sync_0 <= 64'd0;
            gpio_sync_1 <= 64'd0;
            gpio_sync_2 <= 64'd0;
        end else begin
            gpio_sync_0 <= gpio_i;
            gpio_sync_1 <= gpio_sync_0;
            gpio_sync_2 <= gpio_sync_1;
        end
    end

    // Edge Detection
    wire [63:0] gpio_rise = gpio_sync_1 & ~gpio_sync_2;
    wire [63:0] gpio_fall = ~gpio_sync_1 & gpio_sync_2;
    wire [63:0] gpio_high = gpio_sync_1;
    wire [63:0] gpio_low  = ~gpio_sync_1;

    // Interrupt Evaluation
    wire [31:0] intr_trig_0 = (gpio_rise[31:0]  & reg_rise_en_0) |
                              (gpio_fall[31:0]  & reg_fall_en_0) |
                              (gpio_high[31:0]  & reg_high_en_0) |
                              (gpio_low[31:0]   & reg_low_en_0);

    wire [31:0] intr_trig_1 = (gpio_rise[63:32] & reg_rise_en_1) |
                              (gpio_fall[63:32] & reg_fall_en_1) |
                              (gpio_high[63:32] & reg_high_en_1) |
                              (gpio_low[63:32]  & reg_low_en_1);

    // AXI-Lite Write Channels
    reg [1:0] wr_state;
    localparam WR_IDLE = 2'd0;
    localparam WR_RESP = 2'd1;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_awready   <= 1'b0;
            s_axi_wready    <= 1'b0;
            s_axi_bvalid    <= 1'b0;
            s_axi_bresp     <= 2'b00;
            wr_state        <= WR_IDLE;
            reg_cfg         <= 32'h0;
            reg_mode        <= 32'h0;
            reg_en_0        <= 32'h0;
            reg_en_1        <= 32'h0;
            reg_out_0       <= 32'h0;
            reg_out_1       <= 32'h0;
            reg_rise_en_0   <= 32'h0;
            reg_rise_en_1   <= 32'h0;
            reg_fall_en_0   <= 32'h0;
            reg_fall_en_1   <= 32'h0;
            reg_high_en_0   <= 32'h0;
            reg_high_en_1   <= 32'h0;
            reg_low_en_0    <= 32'h0;
            reg_low_en_1    <= 32'h0;
            reg_status_0    <= 32'h0;
            reg_status_1    <= 32'h0;
        end else begin
            // Latch edge/level interrupt triggers
            reg_status_0 <= reg_status_0 | intr_trig_0;
            reg_status_1 <= reg_status_1 | intr_trig_1;

            case (wr_state)
                WR_IDLE: begin
                    if (s_axi_awvalid && s_axi_wvalid) begin
                        s_axi_awready <= 1'b1;
                        s_axi_wready  <= 1'b1;
                        s_axi_bvalid  <= 1'b1;
                        s_axi_bresp   <= 2'b00;
                        wr_state      <= WR_RESP;

                        case (s_axi_awaddr[11:0])
                            12'h004: reg_cfg       <= s_axi_wdata;
                            12'h008: reg_mode      <= s_axi_wdata;
                            12'h080: reg_en_0      <= s_axi_wdata;
                            12'h084: reg_en_1      <= s_axi_wdata;
                            12'h180: reg_out_0     <= s_axi_wdata;
                            12'h184: reg_out_1     <= s_axi_wdata;
                            12'h200: reg_out_0     <= reg_out_0 | s_axi_wdata;       // Set
                            12'h204: reg_out_1     <= reg_out_1 | s_axi_wdata;
                            12'h280: reg_out_0     <= reg_out_0 & ~s_axi_wdata;      // Clear
                            12'h284: reg_out_1     <= reg_out_1 & ~s_axi_wdata;
                            12'h300: reg_out_0     <= reg_out_0 ^ s_axi_wdata;       // Toggle
                            12'h304: reg_out_1     <= reg_out_1 ^ s_axi_wdata;
                            12'h380: reg_rise_en_0 <= s_axi_wdata;
                            12'h384: reg_rise_en_1 <= s_axi_wdata;
                            12'h400: reg_fall_en_0 <= s_axi_wdata;
                            12'h404: reg_fall_en_1 <= s_axi_wdata;
                            12'h480: reg_high_en_0 <= s_axi_wdata;
                            12'h484: reg_high_en_1 <= s_axi_wdata;
                            12'h500: reg_low_en_0  <= s_axi_wdata;
                            12'h504: reg_low_en_1  <= s_axi_wdata;
                            12'h580: reg_status_0  <= (reg_status_0 & ~s_axi_wdata) | intr_trig_0; // RW1C
                            12'h584: reg_status_1  <= (reg_status_1 & ~s_axi_wdata) | intr_trig_1;
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
                            12'h000: s_axi_rdata <= 32'd64;                     // GPIO_INFO = 64
                            12'h004: s_axi_rdata <= reg_cfg;
                            12'h008: s_axi_rdata <= reg_mode;
                            12'h080: s_axi_rdata <= reg_en_0;
                            12'h084: s_axi_rdata <= reg_en_1;
                            12'h100: s_axi_rdata <= gpio_sync_1[31:0];           // GPIO_IN_0
                            12'h104: s_axi_rdata <= gpio_sync_1[63:32];          // GPIO_IN_1
                            12'h180: s_axi_rdata <= reg_out_0;
                            12'h184: s_axi_rdata <= reg_out_1;
                            12'h380: s_axi_rdata <= reg_rise_en_0;
                            12'h384: s_axi_rdata <= reg_rise_en_1;
                            12'h400: s_axi_rdata <= reg_fall_en_0;
                            12'h404: s_axi_rdata <= reg_fall_en_1;
                            12'h480: s_axi_rdata <= reg_high_en_0;
                            12'h484: s_axi_rdata <= reg_high_en_1;
                            12'h500: s_axi_rdata <= reg_low_en_0;
                            12'h504: s_axi_rdata <= reg_low_en_1;
                            12'h580: s_axi_rdata <= reg_status_0;
                            12'h584: s_axi_rdata <= reg_status_1;
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

    // Pin Drive & Interrupt Assignments
    assign gpio_o       = {reg_out_1, reg_out_0};
    assign gpio_dir_o   = {reg_en_1, reg_en_0};
    assign gpio_intr_o  = {|reg_status_1, |reg_status_0};

endmodule

`default_nettype wire
