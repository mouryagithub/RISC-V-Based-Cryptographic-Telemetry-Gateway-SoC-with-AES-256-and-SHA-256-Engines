// =============================================================================
// File        : axi_sha256_top.v
// Module      : axi_sha256_top
// Project     : RISC-V Cryptographic Telemetry Gateway SoC
// Description : AXI4-Lite slave wrapper for Secworks SHA-256 accelerator core.
//
// Address Mapping (Base: 0x4000_4000, 4 KB Window):
//   Offset   Word Addr   Register Name
//   0x00     0x00        NAME0    ("sha2")
//   0x04     0x01        NAME1    ("-256")
//   0x08     0x02        VERSION  ("0.80")
//   0x20     0x08        CTRL     (bit 0=INIT, bit 1=NEXT, bit 2=MODE)
//   0x24     0x09        STATUS   (bit 0=READY, bit 1=DIGEST_VALID)
//   0x40-7C  0x10-0x1F   BLOCK_0 to BLOCK_15 (512-bit message buffer)
//   0x80-9C  0x20-0x27   DIGEST_0 to DIGEST_7 (256-bit computed hash digest)
// =============================================================================

`timescale 1ns/1ps
`default_nettype none

module axi_sha256_top #(
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
    output wire                       sha_irq
);

    // Internal signals to sha256 core
    reg         core_cs;
    reg         core_we;
    reg  [7:0]  core_addr;
    reg  [31:0] core_wdata;
    wire [31:0] core_rdata;
    wire        core_error;

    // Instantiate Secworks SHA-256 core
    sha256 u_sha256 (
        .clk        (aclk),
        .reset_n    (aresetn),
        .cs         (core_cs),
        .we         (core_we),
        .address    (core_addr),
        .write_data (core_wdata),
        .read_data  (core_rdata),
        .error      (core_error)
    );

    // Write state machine
    reg [1:0] wr_state;
    localparam WR_IDLE = 2'd0;
    localparam WR_RESP = 2'd1;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_bvalid  <= 1'b0;
            s_axi_bresp   <= 2'b00;
            wr_state      <= WR_IDLE;
        end else begin
            case (wr_state)
                WR_IDLE: begin
                    if (s_axi_awvalid && s_axi_wvalid) begin
                        s_axi_awready <= 1'b1;
                        s_axi_wready  <= 1'b1;
                        s_axi_bvalid  <= 1'b1;
                        s_axi_bresp   <= 2'b00;
                        wr_state      <= WR_RESP;
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

    // Read state machine
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
                        s_axi_rdata   <= core_rdata;
                        rd_state      <= RD_DATA;
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

    // Core bus interface multiplexing
    always @(*) begin
        if (wr_state == WR_IDLE && s_axi_awvalid && s_axi_wvalid) begin
            core_cs    = 1'b1;
            core_we    = 1'b1;
            core_addr  = {2'b00, s_axi_awaddr[7:2]};
            core_wdata = s_axi_wdata;
        end else if (s_axi_arvalid) begin
            core_cs    = 1'b1;
            core_we    = 1'b0;
            core_addr  = {2'b00, s_axi_araddr[7:2]};
            core_wdata = 32'h0;
        end else begin
            core_cs    = 1'b0;
            core_we    = 1'b0;
            core_addr  = 8'h0;
            core_wdata = 32'h0;
        end
    end

    // Digest valid status flag latching for interrupt
    reg digest_valid_reg;
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            digest_valid_reg <= 1'b0;
        end else if (core_addr == 8'h09 && core_cs && !core_we) begin
            digest_valid_reg <= core_rdata[1];
        end else if (core_addr == 8'h08 && core_cs && core_we && core_wdata[0]) begin
            // Clear on INIT
            digest_valid_reg <= 1'b0;
        end
    end

    assign sha_irq = digest_valid_reg;

endmodule

`default_nettype wire
