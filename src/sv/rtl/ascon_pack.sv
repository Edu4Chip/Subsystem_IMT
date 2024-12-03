package ascon_pack;
  // types
  typedef logic [127:0] u128_t;
  typedef logic [63:0] u64_t;
  typedef logic [31:0] u32_t;
  typedef logic [7:0] u8_t;
  typedef logic [3:0] rnd_t;

  // constants
  parameter int unsigned BLOCK_WIDTH = 64;
  parameter int unsigned BLOCK_BYTE_AW = 3;
  parameter int unsigned ROUND_WIDTH = 4;
  parameter int unsigned ROUND_NO = 12;
  parameter u64_t ASCON128_IV = 64'h80400c0600000000;
  parameter u64_t DOM_SEP_CONST = 64'd1;

  parameter u8_t RndConst[ROUND_NO] = {
    8'hF0,
    8'hE1,
    8'hD2,
    8'hC3,
    8'hB4,
    8'hA5,
    8'h96,
    8'h87,
    8'h78,
    8'h69,
    8'h5A,
    8'h4B
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

endpackage
