// =============================================================================
// aes_axi_slave.v
//
// AXI4-Lite Slave — AES Cipher + Inverse Cipher Register Set
//
// Implements two independent register sets as defined in aes_regset.md:
//
//   AES Cipher Core (aes_cipher_top)      base 0x00 – 0x40
//   AES Inverse Cipher Core (aes_inv_cipher_top) base 0x44 – 0x84
//
// Each set contains:
//   CSR          : 1 × 32-bit   (upper16=CTRL, lower16=STATUS)
//   KEY0–KEY7    : 8 × 32-bit   (WO, 256-bit key)
//   TEXT_IN0–3   : 4 × 32-bit   (WO, 128-bit input text)
//   TEXT_OUT0–3  : 4 × 32-bit   (RO, 128-bit output text from core)
//
// CSR bit assignments:
//   Cipher CSR  : bit[16]=ld(SC WO), bit[0]=done(RO)
//   Inv CSR     : bit[17]=kld(SC WO), bit[16]=ld(SC WO),
//                 bit[1]=kdone(RO),   bit[0]=done(RO)
//
// AXI4-Lite interface:
//   Data width  : 32-bit
//   Address width: AXI_ADDR_WIDTH (default 8, covers 0x00–0x84)
//   Reset       : active-LOW synchronous (aresetn)
//
// Reference: ASICS.ws AES Rijndael IP Core Rev 1.1 (aes.pdf)
// =============================================================================

`timescale 1ns/1ps
`default_nettype none

module aes_axi_slave #(
    parameter AXI_ADDR_WIDTH = 8    // must cover up to 0x84 → 8 bits sufficient
)(
    // -------------------------------------------------------------------------
    // AXI4-Lite Clock & Reset
    // -------------------------------------------------------------------------
    input  wire                       aclk,
    input  wire                       aresetn,    // active-LOW synchronous reset

    // -------------------------------------------------------------------------
    // AXI4-Lite Slave — Write Address Channel
    // -------------------------------------------------------------------------
    input  wire [AXI_ADDR_WIDTH-1:0]  s_axi_awaddr,
    input  wire [2:0]                 s_axi_awprot,
    input  wire                       s_axi_awvalid,
    output reg                        s_axi_awready,

    // -------------------------------------------------------------------------
    // AXI4-Lite Slave — Write Data Channel
    // -------------------------------------------------------------------------
    input  wire [31:0]                s_axi_wdata,
    input  wire [3:0]                 s_axi_wstrb,
    input  wire                       s_axi_wvalid,
    output reg                        s_axi_wready,

    // -------------------------------------------------------------------------
    // AXI4-Lite Slave — Write Response Channel
    // -------------------------------------------------------------------------
    output reg  [1:0]                 s_axi_bresp,
    output reg                        s_axi_bvalid,
    input  wire                       s_axi_bready,

    // -------------------------------------------------------------------------
    // AXI4-Lite Slave — Read Address Channel
    // -------------------------------------------------------------------------
    input  wire [AXI_ADDR_WIDTH-1:0]  s_axi_araddr,
    input  wire [2:0]                 s_axi_arprot,
    input  wire                       s_axi_arvalid,
    output reg                        s_axi_arready,

    // -------------------------------------------------------------------------
    // AXI4-Lite Slave — Read Data Channel
    // -------------------------------------------------------------------------
    output reg  [31:0]                s_axi_rdata,
    output reg  [1:0]                 s_axi_rresp,
    output reg                        s_axi_rvalid,
    input  wire                       s_axi_rready,

    // -------------------------------------------------------------------------
    // AES Cipher Core Ports  (aes_cipher_top)
    // -------------------------------------------------------------------------
    output reg                        cipher_ld,          // → ld  (self-clearing)
    input  wire                       cipher_done,        // ← done
    output wire [127:0]               cipher_key,         // → key[127:0]
    output wire [127:0]               cipher_text_in,     // → text_in[127:0]
    input  wire [127:0]               cipher_text_out,    // ← text_out[127:0]

    // -------------------------------------------------------------------------
    // AES Inverse Cipher Core Ports  (aes_inv_cipher_top)
    // -------------------------------------------------------------------------
    output reg                        inv_kld,            // → kld (self-clearing)
    input  wire                       inv_kdone,          // ← kdone
    output reg                        inv_ld,             // → ld  (self-clearing)
    input  wire                       inv_done,           // ← done
    output wire [127:0]               inv_key,            // → key[127:0]
    output wire [127:0]               inv_text_in,        // → text_in[127:0]
    input  wire [127:0]               inv_text_out        // ← text_out[127:0]
);

    // =========================================================================
    // Internal reset (active-HIGH)
    // =========================================================================
    wire rst = ~aresetn;

    // =========================================================================
    // Register Storage
    // =========================================================================

    // --- Cipher key (256-bit held in two 128-bit halves) ---------------------
    reg [127:0] cipher_key_lo;   // KEY0–3  key[127:0]
    reg [127:0] cipher_key_hi;   // KEY4–7  key[255:128]

    // --- Cipher text_in (128-bit) --------------------------------------------
    reg [127:0] cipher_tin;

    // --- Inv cipher key (256-bit) --------------------------------------------
    reg [127:0] inv_key_lo;
    reg [127:0] inv_key_hi;

    // --- Inv cipher text_in (128-bit) ----------------------------------------
    reg [127:0] inv_tin;

    // =========================================================================
    // AXI4-Lite Write Path
    // — Latch AW and W independently, dispatch when both are valid
    // =========================================================================
    reg [AXI_ADDR_WIDTH-1:0] wr_addr;
    reg [31:0]               wr_data;
    reg [3:0]                wr_strb;
    reg                      wr_addr_vld;
    reg                      wr_data_vld;

    // Byte-strobe helper
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

    // --- AW channel -----------------------------------------------------------
    always @(posedge aclk) begin
        if (rst) begin
            s_axi_awready <= 1'b0;
            wr_addr       <= {AXI_ADDR_WIDTH{1'b0}};
            wr_addr_vld   <= 1'b0;
        end else begin
            if (s_axi_awvalid && s_axi_awready) begin
                wr_addr       <= s_axi_awaddr;
                wr_addr_vld   <= 1'b1;
                s_axi_awready <= 1'b0;
            end else if (!wr_addr_vld) begin
                s_axi_awready <= 1'b1;
            end
            // Clear once dispatched
            if (wr_addr_vld && wr_data_vld) begin
                wr_addr_vld   <= 1'b0;
                s_axi_awready <= 1'b1;
            end
        end
    end

    // --- W channel ------------------------------------------------------------
    always @(posedge aclk) begin
        if (rst) begin
            s_axi_wready <= 1'b0;
            wr_data      <= 32'b0;
            wr_strb      <= 4'b0;
            wr_data_vld  <= 1'b0;
        end else begin
            if (s_axi_wvalid && s_axi_wready) begin
                wr_data      <= s_axi_wdata;
                wr_strb      <= s_axi_wstrb;
                wr_data_vld  <= 1'b1;
                s_axi_wready <= 1'b0;
            end else if (!wr_data_vld) begin
                s_axi_wready <= 1'b1;
            end
            if (wr_addr_vld && wr_data_vld) begin
                wr_data_vld  <= 1'b0;
                s_axi_wready <= 1'b1;
            end
        end
    end

    // =========================================================================
    // Write Dispatch + B Response
    // =========================================================================
    always @(posedge aclk) begin
        if (rst) begin
            s_axi_bvalid  <= 1'b0;
            s_axi_bresp   <= 2'b00;
            // Self-clearing outputs default to 0
            cipher_ld     <= 1'b0;
            inv_kld       <= 1'b0;
            inv_ld        <= 1'b0;
            // Register storage
            cipher_key_lo <= 128'b0;
            cipher_key_hi <= 128'b0;
            cipher_tin    <= 128'b0;
            inv_key_lo    <= 128'b0;
            inv_key_hi    <= 128'b0;
            inv_tin       <= 128'b0;
        end else begin
            // Default: deassert self-clearing control pulses every cycle
            cipher_ld <= 1'b0;
            inv_kld   <= 1'b0;
            inv_ld    <= 1'b0;

            // Dispatch when both AW and W have been captured
            if (wr_addr_vld && wr_data_vld) begin
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00; // OKAY

                case (wr_addr[7:2])  // word address (bits[7:2])
                    // ============================================================
                    // CIPHER register set  (base 0x00)
                    // ============================================================

                    // 0x00 CIPHER_CSR — only bit[16] LD is writable
                    7'h00: begin
                        if (wr_strb[2]) begin
                            // byte 2 = bits[23:16]; bit[16]=LD
                            cipher_ld <= wr_data[16];
                        end
                        // bits[15:0] (STATUS) are RO — writes ignored
                    end

                    // 0x04–0x20  CIPHER_KEY0–KEY7  (WO)
                    7'h01: cipher_key_lo[31:0]    <= apply_strb(cipher_key_lo[31:0],   wr_data, wr_strb);
                    7'h02: cipher_key_lo[63:32]   <= apply_strb(cipher_key_lo[63:32],  wr_data, wr_strb);
                    7'h03: cipher_key_lo[95:64]   <= apply_strb(cipher_key_lo[95:64],  wr_data, wr_strb);
                    7'h04: cipher_key_lo[127:96]  <= apply_strb(cipher_key_lo[127:96], wr_data, wr_strb);
                    7'h05: cipher_key_hi[31:0]    <= apply_strb(cipher_key_hi[31:0],   wr_data, wr_strb);
                    7'h06: cipher_key_hi[63:32]   <= apply_strb(cipher_key_hi[63:32],  wr_data, wr_strb);
                    7'h07: cipher_key_hi[95:64]   <= apply_strb(cipher_key_hi[95:64],  wr_data, wr_strb);
                    7'h08: cipher_key_hi[127:96]  <= apply_strb(cipher_key_hi[127:96], wr_data, wr_strb);

                    // 0x24–0x30  CIPHER_TEXT_IN0–3  (WO)
                    7'h09: cipher_tin[31:0]    <= apply_strb(cipher_tin[31:0],   wr_data, wr_strb);
                    7'h0A: cipher_tin[63:32]   <= apply_strb(cipher_tin[63:32],  wr_data, wr_strb);
                    7'h0B: cipher_tin[95:64]   <= apply_strb(cipher_tin[95:64],  wr_data, wr_strb);
                    7'h0C: cipher_tin[127:96]  <= apply_strb(cipher_tin[127:96], wr_data, wr_strb);

                    // 0x34–0x40  CIPHER_TEXT_OUT0–3  RO — writes ignored
                    7'h0D, 7'h0E, 7'h0F, 7'h10: ; // silently ignore

                    // ============================================================
                    // INV CIPHER register set  (base 0x44)
                    // ============================================================

                    // 0x44 INV_CSR — bits[17]=KLD, bits[16]=LD writable
                    7'h11: begin
                        if (wr_strb[2]) begin
                            inv_kld <= wr_data[17];
                            inv_ld  <= wr_data[16];
                        end
                        // bits[15:0] (STATUS) are RO
                    end

                    // 0x48–0x64  INV_KEY0–KEY7  (WO)
                    7'h12: inv_key_lo[31:0]    <= apply_strb(inv_key_lo[31:0],   wr_data, wr_strb);
                    7'h13: inv_key_lo[63:32]   <= apply_strb(inv_key_lo[63:32],  wr_data, wr_strb);
                    7'h14: inv_key_lo[95:64]   <= apply_strb(inv_key_lo[95:64],  wr_data, wr_strb);
                    7'h15: inv_key_lo[127:96]  <= apply_strb(inv_key_lo[127:96], wr_data, wr_strb);
                    7'h16: inv_key_hi[31:0]    <= apply_strb(inv_key_hi[31:0],   wr_data, wr_strb);
                    7'h17: inv_key_hi[63:32]   <= apply_strb(inv_key_hi[63:32],  wr_data, wr_strb);
                    7'h18: inv_key_hi[95:64]   <= apply_strb(inv_key_hi[95:64],  wr_data, wr_strb);
                    7'h19: inv_key_hi[127:96]  <= apply_strb(inv_key_hi[127:96], wr_data, wr_strb);

                    // 0x68–0x74  INV_TEXT_IN0–3  (WO)
                    7'h1A: inv_tin[31:0]    <= apply_strb(inv_tin[31:0],   wr_data, wr_strb);
                    7'h1B: inv_tin[63:32]   <= apply_strb(inv_tin[63:32],  wr_data, wr_strb);
                    7'h1C: inv_tin[95:64]   <= apply_strb(inv_tin[95:64],  wr_data, wr_strb);
                    7'h1D: inv_tin[127:96]  <= apply_strb(inv_tin[127:96], wr_data, wr_strb);

                    // 0x78–0x84  INV_TEXT_OUT0–3  RO — writes ignored
                    7'h1E, 7'h1F, 7'h20, 7'h21: ; // silently ignore

                    default: s_axi_bresp <= 2'b00; // OKAY for unknown addr
                endcase
            end

            // B-channel handshake clear
            if (s_axi_bvalid && s_axi_bready)
                s_axi_bvalid <= 1'b0;
        end
    end

    // =========================================================================
    // Drive IP Core ports from register storage via continuous assign
    // The IP core always sees the currently loaded key / text_in.
    // For the 256-bit two-pulse scheme: firmware loads KEY0-3, pulses LD,
    // then loads KEY4-7 into cipher_key_lo and pulses LD again.
    // =========================================================================
    assign cipher_key     = cipher_key_lo;   // key[127:0] → cipher core
    assign cipher_text_in = cipher_tin;      // text_in[127:0] → cipher core
    assign inv_key        = inv_key_lo;      // key[127:0] → inv_cipher core
    assign inv_text_in    = inv_tin;         // text_in[127:0] → inv_cipher core

    // =========================================================================
    // AXI4-Lite Read Path
    // =========================================================================
    always @(posedge aclk) begin
        if (rst) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rdata   <= 32'b0;
            s_axi_rresp   <= 2'b00;
        end else begin
            s_axi_arready <= 1'b1;  // always ready for AR

            if (s_axi_arvalid && s_axi_arready) begin
                s_axi_arready <= 1'b0;
                s_axi_rvalid  <= 1'b1;
                s_axi_rresp   <= 2'b00;

                case (s_axi_araddr[7:2])
                    // ----------------------------------------------------------
                    // CIPHER register set reads
                    // ----------------------------------------------------------

                    // 0x00 CIPHER_CSR
                    // [31:17]=0, [16]=0 (LD reads as 0, WO/SC),
                    // [15:1]=0,  [0]=done (live from core)
                    7'h00: s_axi_rdata <= {15'b0, 1'b0,   // ctrl: LD reads 0
                                           15'b0, cipher_done}; // status

                    // 0x04–0x20 CIPHER_KEY0–KEY7: WO, reads return 0
                    7'h01, 7'h02, 7'h03, 7'h04,
                    7'h05, 7'h06, 7'h07, 7'h08: s_axi_rdata <= 32'b0;

                    // 0x24–0x30 CIPHER_TEXT_IN0–3: WO, reads return 0
                    7'h09, 7'h0A, 7'h0B, 7'h0C: s_axi_rdata <= 32'b0;

                    // 0x34–0x40 CIPHER_TEXT_OUT0–3: RO, live from core
                    7'h0D: s_axi_rdata <= cipher_text_out[31:0];
                    7'h0E: s_axi_rdata <= cipher_text_out[63:32];
                    7'h0F: s_axi_rdata <= cipher_text_out[95:64];
                    7'h10: s_axi_rdata <= cipher_text_out[127:96];

                    // ----------------------------------------------------------
                    // INV CIPHER register set reads
                    // ----------------------------------------------------------

                    // 0x44 INV_CSR
                    // [31:18]=0, [17]=0(KLD WO), [16]=0(LD WO),
                    // [15:2]=0,  [1]=kdone, [0]=done
                    7'h11: s_axi_rdata <= {14'b0, 2'b00,       // ctrl: KLD/LD read 0
                                           14'b0, inv_kdone, inv_done}; // status

                    // 0x48–0x64 INV_KEY0–KEY7: WO, reads return 0
                    7'h12, 7'h13, 7'h14, 7'h15,
                    7'h16, 7'h17, 7'h18, 7'h19: s_axi_rdata <= 32'b0;

                    // 0x68–0x74 INV_TEXT_IN0–3: WO, reads return 0
                    7'h1A, 7'h1B, 7'h1C, 7'h1D: s_axi_rdata <= 32'b0;

                    // 0x78–0x84 INV_TEXT_OUT0–3: RO, live from core
                    7'h1E: s_axi_rdata <= inv_text_out[31:0];
                    7'h1F: s_axi_rdata <= inv_text_out[63:32];
                    7'h20: s_axi_rdata <= inv_text_out[95:64];
                    7'h21: s_axi_rdata <= inv_text_out[127:96];

                    default: begin
                        s_axi_rdata <= 32'b0;
                        s_axi_rresp <= 2'b00;
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
