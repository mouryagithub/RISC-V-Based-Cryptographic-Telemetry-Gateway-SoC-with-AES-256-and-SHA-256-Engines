/////////////////////////////////////////////////////////////////////
////                                                             ////
////  AES Key Expand Block (for 256 bit keys)                    ////
////                                                             ////
/////////////////////////////////////////////////////////////////////

`include "timescale.v"

module aes_key_expand_256(clk, kld, key, wo_0, wo_1, wo_2, wo_3);
input		clk;
input		kld;
input	[255:0]	key;
output	[31:0]	wo_0, wo_1, wo_2, wo_3;

reg	[31:0]	w[7:0];
reg		rot;
wire	[31:0]	tmp_w;
wire	[31:0]	subword;
wire	[31:0]	rcon;
wire	[31:0]	k_in;
wire	[31:0]	w4_next, w5_next, w6_next, w7_next;
wire	[7:0]	sbox_in0, sbox_in1, sbox_in2, sbox_in3;

assign wo_0 = w[0];
assign wo_1 = w[1];
assign wo_2 = w[2];
assign wo_3 = w[3];

assign tmp_w = w[7];

// In AES-256 (FIPS-197):
// When rot == 1 (even rounds 2, 4, 6...): SubWord(RotWord(tmp_w)) ^ rcon
//   RotWord: byte3=tmp_w[23:16], byte2=tmp_w[15:8], byte1=tmp_w[7:0], byte0=tmp_w[31:24]
// When rot == 0 (odd rounds 3, 5, 7...): SubWord(tmp_w) directly (no RotWord, no rcon)
//   tmp_w:   byte3=tmp_w[31:24], byte2=tmp_w[23:16], byte1=tmp_w[15:8], byte0=tmp_w[7:0]
assign sbox_in3 = rot ? tmp_w[23:16] : tmp_w[31:24];
assign sbox_in2 = rot ? tmp_w[15:08] : tmp_w[23:16];
assign sbox_in1 = rot ? tmp_w[07:00] : tmp_w[15:08];
assign sbox_in0 = rot ? tmp_w[31:24] : tmp_w[07:00];

aes_sbox u0(	.a(sbox_in3), .d(subword[31:24]));
aes_sbox u1(	.a(sbox_in2), .d(subword[23:16]));
aes_sbox u2(	.a(sbox_in1), .d(subword[15:08]));
aes_sbox u3(	.a(sbox_in0), .d(subword[07:00]));

aes_rcon r0(	.clk(clk), .kld(kld), .en(rot), .out(rcon));

assign k_in = rot ? (subword ^ rcon) : subword;

assign w4_next = w[0] ^ k_in;
assign w5_next = w[1] ^ w4_next;
assign w6_next = w[2] ^ w5_next;
assign w7_next = w[3] ^ w6_next;

always @(posedge clk) begin
    if (kld) begin
        w[0] <= #1 key[255:224];
        w[1] <= #1 key[223:192];
        w[2] <= #1 key[191:160];
        w[3] <= #1 key[159:128];
        w[4] <= #1 key[127:096];
        w[5] <= #1 key[095:064];
        w[6] <= #1 key[063:032];
        w[7] <= #1 key[031:000];
        rot  <= #1 1'b1;
    end else begin
        w[0] <= #1 w[4];
        w[1] <= #1 w[5];
        w[2] <= #1 w[6];
        w[3] <= #1 w[7];
        w[4] <= #1 w4_next;
        w[5] <= #1 w5_next;
        w[6] <= #1 w6_next;
        w[7] <= #1 w7_next;
        rot  <= #1 ~rot;
    end
end

endmodule
