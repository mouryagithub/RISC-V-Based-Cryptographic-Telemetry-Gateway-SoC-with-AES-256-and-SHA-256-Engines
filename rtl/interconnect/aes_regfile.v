// =============================================================================
// aes_regfile.v
//
// AES-256 Register File  –  AXI4-Lite Slave
//
// Register Map (32-bit word-addressed, byte offset):
//
//  0x00  AES_CTRL    R/W   [0]     START      – self-clearing, write 1 to start
//                          [1]     IRQ_EN     – interrupt enable
//                          [2]     DECRYPT    – 0=encrypt, 1=decrypt
//                          [4:3]   KEY_SIZE   – 00=128b, 01=192b, 10=256b
//                          [5]     MODE_CBC   – 0=ECB, 1=CBC
//                          [6]     MODE_CTR   – 0=ECB/CBC, 1=CTR
//                          [7]     SOFT_RST   – self-clearing software reset
//                          [31:8]  RAZ/WI
//  0x04  AES_STATUS  RO/W1C[0]     BUSY       – RO: core busy
//                          [1]     DONE       – W1C: operation complete
//                          [2]     KEY_READY  – W1C: key expansion done
//                          [3]     ERR        – W1C: error flag
//                          [31:4]  RAZ
//  0x08  AES_BLK_CNT R/W   [15:0]  TOTAL_BLOCKS – total blocks to process
//                          [31:16] DONE_BLOCKS  – blocks processed (RO, HW)
//  0x0C  AES_IRQ_CLR W1C   [0]     CLR_DONE   – write 1 to clear DONE IRQ
//                          [1]     CLR_ERR    – write 1 to clear ERR IRQ
//                          [31:2]  RAZ/WI
//  0x10  AES_KEY0    WO    [31:0]  key[31:0]
//  0x14  AES_KEY1    WO    [31:0]  key[63:32]
//  0x18  AES_KEY2    WO    [31:0]  key[95:64]
//  0x1C  AES_KEY3    WO    [31:0]  key[127:96]
//  0x20  AES_KEY4    WO    [31:0]  key[159:128]
//  0x24  AES_KEY5    WO    [31:0]  key[191:160]
//  0x28  AES_KEY6    WO    [31:0]  key[223:192]
//  0x2C  AES_KEY7    WO    [31:0]  key[255:224]
//  0x30  AES_IV0     R/W   [31:0]  iv[31:0]
//  0x34  AES_IV1     R/W   [31:0]  iv[63:32]
//  0x38  AES_IV2     R/W   [31:0]  iv[95:64]
//  0x3C  AES_IV3     R/W   [31:0]  iv[127:96]
//  0x40  AES_DIN0    WO    [31:0]  plaintext/ciphertext in [31:0]
//  0x44  AES_DIN1    WO    [31:0]  input block [63:32]
//  0x48  AES_DIN2    WO    [31:0]  input block [95:64]
//  0x4C  AES_DIN3    WO    [31:0]  input block [127:96]
//  0x50  AES_DOUT0   RO    [31:0]  ciphertext/plaintext out [31:0]
//  0x54  AES_DOUT1   RO    [31:0]  output block [63:32]
//  0x58  AES_DOUT2   RO    [31:0]  output block [95:64]
//  0x5C  AES_DOUT3   RO    [31:0]  output block [127:96]
//
// AXI4-Lite slave interface: 32-bit data, 8-bit byte-enables
// Active-HIGH synchronous reset (axi_aresetn is active-LOW, inverted internally)
//
// =============================================================================

`timescale 1ns/1ps
`default_nettype none

module aes_regfile #(
    parameter ADDR_WIDTH = 8   // covers 0x00–0x5C (7 bits minimum; 8 used for margin)
)(
    // -------------------------------------------------------------------------
    // AXI4-Lite Slave Interface
    // -------------------------------------------------------------------------
    input  wire                  aclk,
    input  wire                  aresetn,     // active-LOW reset

    // Write address channel
    input  wire [ADDR_WIDTH-1:0] s_axi_awaddr,
    input  wire [2:0]            s_axi_awprot,
    input  wire                  s_axi_awvalid,
    output reg                   s_axi_awready,

    // Write data channel
    input  wire [31:0]           s_axi_wdata,
    input  wire [3:0]            s_axi_wstrb,
    input  wire                  s_axi_wvalid,
    output reg                   s_axi_wready,

    // Write response channel
    output reg  [1:0]            s_axi_bresp,
    output reg                   s_axi_bvalid,
    input  wire                  s_axi_bready,

    // Read address channel
    input  wire [ADDR_WIDTH-1:0] s_axi_araddr,
    input  wire [2:0]            s_axi_arprot,
    input  wire                  s_axi_arvalid,
    output reg                   s_axi_arready,

    // Read data channel
    output reg  [31:0]           s_axi_rdata,
    output reg  [1:0]            s_axi_rresp,
    output reg                   s_axi_rvalid,
    input  wire                  s_axi_rready,

    // -------------------------------------------------------------------------
    // Register outputs to AES core
    // -------------------------------------------------------------------------
    output reg                   ctrl_start,       // self-clearing start
    output reg                   ctrl_irq_en,
    output reg                   ctrl_decrypt,
    output reg  [1:0]            ctrl_key_size,    // 00=128, 01=192, 10=256
    output reg                   ctrl_mode_cbc,
    output reg                   ctrl_mode_ctr,
    output reg                   ctrl_soft_rst,    // self-clearing

    output reg  [255:0]          key_data,         // KEY7..KEY0 concatenated
    output reg  [127:0]          iv_data,          // IV3..IV0 concatenated
    output reg  [127:0]          din_data,         // DIN3..DIN0 concatenated

    // -------------------------------------------------------------------------
    // Register inputs from AES core
    // -------------------------------------------------------------------------
    input  wire                  core_busy,
    input  wire                  core_done,        // pulse: operation complete
    input  wire                  core_key_ready,   // pulse: key expansion done
    input  wire                  core_err,         // pulse: error
    input  wire [15:0]           core_done_blocks, // running block counter
    input  wire [127:0]          dout_data,        // core output text

    // -------------------------------------------------------------------------
    // Interrupt output
    // -------------------------------------------------------------------------
    output wire                  irq
);

    // -------------------------------------------------------------------------
    // Internal reset (active-high)
    // -------------------------------------------------------------------------
    wire rst = ~aresetn;

    // -------------------------------------------------------------------------
    // Register storage
    // -------------------------------------------------------------------------
    // AES_CTRL  (0x00)
    // ctrl_start, ctrl_irq_en, ctrl_decrypt, ctrl_key_size, ctrl_mode_cbc,
    // ctrl_mode_ctr, ctrl_soft_rst declared in output ports above

    // AES_STATUS (0x04) – BUSY is live, DONE/KEY_READY/ERR are sticky W1C
    reg  status_done;
    reg  status_key_ready;
    reg  status_err;

    // AES_BLK_CNT (0x08)
    reg  [15:0] total_blocks;

    // KEY registers (write-only; stored internally, exposed as output)
    // key_data[255:0] declared in outputs

    // IV registers  (R/W)
    // iv_data[127:0] declared in outputs

    // DIN registers (write-only)
    // din_data[127:0] declared in outputs

    // DOUT registers: live from core, no storage needed here

    // -------------------------------------------------------------------------
    // AXI4-Lite write state machine
    // -------------------------------------------------------------------------
    // Latch AW and W independently, issue B after both captured
    reg  [ADDR_WIDTH-1:0] wr_addr;
    reg  [31:0]           wr_data;
    reg  [3:0]            wr_strb;
    reg                   wr_addr_valid;
    reg                   wr_data_valid;

    // Helper: apply byte strobes
    // Returns new_val with strb-selected bytes replaced by data
    function [31:0] apply_strb;
        input [31:0] old_val;
        input [31:0] new_data;
        input [3:0]  strb;
        integer i;
        begin
            apply_strb = old_val;
            for (i = 0; i < 4; i = i + 1)
                if (strb[i]) apply_strb[i*8 +: 8] = new_data[i*8 +: 8];
        end
    endfunction

    // AW channel
    always @(posedge aclk) begin
        if (rst) begin
            s_axi_awready  <= 1'b0;
            wr_addr        <= {ADDR_WIDTH{1'b0}};
            wr_addr_valid  <= 1'b0;
        end else begin
            if (s_axi_awvalid && s_axi_awready) begin
                wr_addr       <= s_axi_awaddr;
                wr_addr_valid <= 1'b1;
                s_axi_awready <= 1'b0;
            end else if (!wr_addr_valid) begin
                s_axi_awready <= 1'b1;
            end
            // Clear once write is dispatched
            if (wr_addr_valid && wr_data_valid) begin
                wr_addr_valid <= 1'b0;
                s_axi_awready <= 1'b1;
            end
        end
    end

    // W channel
    always @(posedge aclk) begin
        if (rst) begin
            s_axi_wready  <= 1'b0;
            wr_data       <= 32'b0;
            wr_strb       <= 4'b0;
            wr_data_valid <= 1'b0;
        end else begin
            if (s_axi_wvalid && s_axi_wready) begin
                wr_data       <= s_axi_wdata;
                wr_strb       <= s_axi_wstrb;
                wr_data_valid <= 1'b1;
                s_axi_wready  <= 1'b0;
            end else if (!wr_data_valid) begin
                s_axi_wready <= 1'b1;
            end
            if (wr_addr_valid && wr_data_valid) begin
                wr_data_valid <= 1'b0;
                s_axi_wready  <= 1'b1;
            end
        end
    end

    // Write dispatch + B response
    always @(posedge aclk) begin
        if (rst) begin
            s_axi_bvalid   <= 1'b0;
            s_axi_bresp    <= 2'b00;
            ctrl_start     <= 1'b0;
            ctrl_irq_en    <= 1'b0;
            ctrl_decrypt   <= 1'b0;
            ctrl_key_size  <= 2'b10;   // default = 256-bit
            ctrl_mode_cbc  <= 1'b0;
            ctrl_mode_ctr  <= 1'b0;
            ctrl_soft_rst  <= 1'b0;
            total_blocks   <= 16'h0000;
            key_data       <= 256'b0;
            iv_data        <= 128'b0;
            din_data       <= 128'b0;
        end else begin
            // Self-clearing pulses
            ctrl_start    <= 1'b0;
            ctrl_soft_rst <= 1'b0;

            // Dispatch write when both AW and W have been captured
            if (wr_addr_valid && wr_data_valid) begin
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00; // OKAY

                case (wr_addr[7:2])   // word-address index (bits[7:2])
                    6'h00: begin // 0x00 AES_CTRL
                        if (wr_strb[0]) begin
                            ctrl_start    <= wr_data[0];   // self-clearing
                            ctrl_irq_en   <= wr_data[1];
                            ctrl_decrypt  <= wr_data[2];
                            ctrl_key_size <= wr_data[4:3];
                            ctrl_mode_cbc <= wr_data[5];
                            ctrl_mode_ctr <= wr_data[6];
                            ctrl_soft_rst <= wr_data[7];   // self-clearing
                        end
                    end
                    6'h01: begin // 0x04 AES_STATUS – W1C bits (DONE, KEY_READY, ERR)
                        // BUSY bit[0] is RO – ignore writes
                        if (wr_strb[0]) begin
                            if (wr_data[1]) status_done      <= 1'b0;
                            if (wr_data[2]) status_key_ready <= 1'b0;
                            if (wr_data[3]) status_err       <= 1'b0;
                        end
                    end
                    6'h02: begin // 0x08 AES_BLK_CNT – only TOTAL_BLOCKS[15:0] writable
                        if (wr_strb[0]) total_blocks[7:0]  <= wr_data[7:0];
                        if (wr_strb[1]) total_blocks[15:8] <= wr_data[15:8];
                        // bits[31:16] (DONE_BLOCKS) are RO
                    end
                    6'h03: begin // 0x0C AES_IRQ_CLR – W1C, mirrors STATUS clear
                        if (wr_strb[0]) begin
                            if (wr_data[0]) status_done <= 1'b0;
                            if (wr_data[1]) status_err  <= 1'b0;
                        end
                    end
                    // KEY registers  0x10–0x2C  (WO)
                    6'h04: key_data[31:0]    <= apply_strb(key_data[31:0],    wr_data, wr_strb);
                    6'h05: key_data[63:32]   <= apply_strb(key_data[63:32],   wr_data, wr_strb);
                    6'h06: key_data[95:64]   <= apply_strb(key_data[95:64],   wr_data, wr_strb);
                    6'h07: key_data[127:96]  <= apply_strb(key_data[127:96],  wr_data, wr_strb);
                    6'h08: key_data[159:128] <= apply_strb(key_data[159:128], wr_data, wr_strb);
                    6'h09: key_data[191:160] <= apply_strb(key_data[191:160], wr_data, wr_strb);
                    6'h0A: key_data[223:192] <= apply_strb(key_data[223:192], wr_data, wr_strb);
                    6'h0B: key_data[255:224] <= apply_strb(key_data[255:224], wr_data, wr_strb);
                    // IV registers   0x30–0x3C  (R/W)
                    6'h0C: iv_data[31:0]     <= apply_strb(iv_data[31:0],     wr_data, wr_strb);
                    6'h0D: iv_data[63:32]    <= apply_strb(iv_data[63:32],    wr_data, wr_strb);
                    6'h0E: iv_data[95:64]    <= apply_strb(iv_data[95:64],    wr_data, wr_strb);
                    6'h0F: iv_data[127:96]   <= apply_strb(iv_data[127:96],   wr_data, wr_strb);
                    // DIN registers  0x40–0x4C  (WO)
                    6'h10: din_data[31:0]    <= apply_strb(din_data[31:0],    wr_data, wr_strb);
                    6'h11: din_data[63:32]   <= apply_strb(din_data[63:32],   wr_data, wr_strb);
                    6'h12: din_data[95:64]   <= apply_strb(din_data[95:64],   wr_data, wr_strb);
                    6'h13: din_data[127:96]  <= apply_strb(din_data[127:96],  wr_data, wr_strb);
                    // DOUT 0x50–0x5C is RO: writes ignored (SLVERR not raised,
                    // hardware may optionally return SLVERR by changing bresp)
                    default: s_axi_bresp <= 2'b00; // silently ignore unknown addr
                endcase
            end

            // B handshake clear
            if (s_axi_bvalid && s_axi_bready)
                s_axi_bvalid <= 1'b0;
        end
    end

    // -------------------------------------------------------------------------
    // Hardware status updates from core
    // -------------------------------------------------------------------------
    always @(posedge aclk) begin
        if (rst) begin
            status_done      <= 1'b0;
            status_key_ready <= 1'b0;
            status_err       <= 1'b0;
        end else begin
            if (core_done)      status_done      <= 1'b1;
            if (core_key_ready) status_key_ready <= 1'b1;
            if (core_err)       status_err       <= 1'b1;
        end
    end

    // -------------------------------------------------------------------------
    // Interrupt output
    // -------------------------------------------------------------------------
    assign irq = ctrl_irq_en & (status_done | status_err);

    // -------------------------------------------------------------------------
    // AXI4-Lite read state machine
    // -------------------------------------------------------------------------
    reg  [ADDR_WIDTH-1:0] rd_addr;

    always @(posedge aclk) begin
        if (rst) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rdata   <= 32'b0;
            s_axi_rresp   <= 2'b00;
            rd_addr       <= {ADDR_WIDTH{1'b0}};
        end else begin
            s_axi_arready <= 1'b1; // always ready to accept AR

            if (s_axi_arvalid && s_axi_arready) begin
                rd_addr       <= s_axi_araddr;
                s_axi_rvalid  <= 1'b1;
                s_axi_rresp   <= 2'b00;
                s_axi_arready <= 1'b0;

                case (s_axi_araddr[7:2])
                    6'h00: s_axi_rdata <= {24'b0,
                                           ctrl_soft_rst,
                                           ctrl_mode_ctr,
                                           ctrl_mode_cbc,
                                           ctrl_key_size,
                                           ctrl_decrypt,
                                           ctrl_irq_en,
                                           1'b0};           // START reads as 0

                    6'h01: s_axi_rdata <= {28'b0,
                                           status_err,
                                           status_key_ready,
                                           status_done,
                                           core_busy};

                    6'h02: s_axi_rdata <= {core_done_blocks, total_blocks};

                    6'h03: s_axi_rdata <= 32'b0; // IRQ_CLR is WO

                    // KEY registers are WO – return 0 on read (security)
                    6'h04, 6'h05, 6'h06, 6'h07,
                    6'h08, 6'h09, 6'h0A, 6'h0B: s_axi_rdata <= 32'b0;

                    // IV registers are R/W
                    6'h0C: s_axi_rdata <= iv_data[31:0];
                    6'h0D: s_axi_rdata <= iv_data[63:32];
                    6'h0E: s_axi_rdata <= iv_data[95:64];
                    6'h0F: s_axi_rdata <= iv_data[127:96];

                    // DIN registers are WO – return 0 on read
                    6'h10, 6'h11, 6'h12, 6'h13: s_axi_rdata <= 32'b0;

                    // DOUT registers are RO – return live core output
                    6'h14: s_axi_rdata <= dout_data[31:0];
                    6'h15: s_axi_rdata <= dout_data[63:32];
                    6'h16: s_axi_rdata <= dout_data[95:64];
                    6'h17: s_axi_rdata <= dout_data[127:96];

                    default: begin
                        s_axi_rdata <= 32'b0;
                        s_axi_rresp <= 2'b00; // OKAY for unknown (harmless)
                    end
                endcase
            end

            if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid  <= 1'b0;
                s_axi_arready <= 1'b1;
            end
        end
    end

endmodule

`default_nettype wire
