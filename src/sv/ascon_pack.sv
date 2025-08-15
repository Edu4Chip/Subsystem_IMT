package ascon_pack;

  // constants
  parameter int unsigned STATE_WIDTH = 320;
  parameter int unsigned MAX_ROUND_NO = 16;
  parameter int unsigned ROUND_WIDTH = MAX_ROUND_NO > 1 ? $clog2(MAX_ROUND_NO) : 1;

  parameter int unsigned RATE = 16;
  parameter int unsigned TAG_WIDTH = 128;
  parameter int unsigned ROUND_B = 8;
  parameter int unsigned ROUND_A = 12;
  parameter int unsigned BLOCK_WIDTH = RATE * 8;

  parameter int unsigned PAD_NO = BLOCK_WIDTH / 8;
  parameter int unsigned PAD_AW = PAD_NO > 1 ? $clog2(PAD_NO) : 1;

  parameter int unsigned KEY_WIDTH = 128;
  parameter int unsigned NONCE_WIDTH = 128;

  // parameter logic [63:0] ASCON_AEAD128_IV = 64'h00001000808C0001;
  parameter logic [63:0] ASCON_AEAD128_IV = {
    RATE[23:0], TAG_WIDTH[15:0], ROUND_B[3:0], ROUND_A[3:0], 16'd1
  };

  parameter logic [7:0] RoundConst[MAX_ROUND_NO] = {
    8'h3c,
    8'h2d,
    8'h1e,
    8'h0f,
    8'hf0,
    8'he1,
    8'hd2,
    8'hc3,
    8'hb4,
    8'ha5,
    8'h96,
    8'h87,
    8'h78,
    8'h69,
    8'h5a,
    8'h4b
  };

  parameter logic [4:0] Sbox[32] = {
    5'h04,
    5'h0B,
    5'h1F,
    5'h14,
    5'h1A,
    5'h15,
    5'h09,
    5'h02,
    5'h1B,
    5'h05,
    5'h08,
    5'h12,
    5'h1D,
    5'h03,
    5'h06,
    5'h1C,
    5'h1E,
    5'h13,
    5'h07,
    5'h0E,
    5'h00,
    5'h0D,
    5'h11,
    5'h18,
    5'h10,
    5'h0C,
    5'h01,
    5'h19,
    5'h16,
    5'h0A,
    5'h0F,
    5'h17
  };

  typedef enum logic [3:0] {
    AsconOp0,
    AsconOp1,
    AsconOp2,
    AsconOp3,
    AsconOp4,
    AsconOp5,
    AsconOp6,
    AsconOp7,
    AsconOp8
  } ascon_op_e;


endpackage
