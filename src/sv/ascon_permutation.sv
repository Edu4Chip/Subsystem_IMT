`timescale 1ns / 1ps

// helper macros
`define _RROT64(__d, __n) {__d[__n-1:0], __d[63:__n]}
`define _DIFF64(__d, __n1, __n2) __d ^ `_RROT64(__d, __n1) ^ `_RROT64(__d, __n2)
`define _COL5(__d, __i) {__d[0][__i], __d[1][__i], __d[2][__i], __d[3][__i], __d[4][__i]}

module ascon_permutation
  import ascon_pack::*;
(
  input  logic [ROUND_WIDTH-1:0] round_i,
  input  logic [STATE_WIDTH-1:0] state_i,
  output logic [STATE_WIDTH-1:0] state_o
);

  localparam int unsigned STATE_DW = STATE_WIDTH / 5;
  typedef logic [4:0][STATE_DW-1:0] ascon_state_t;

  ascon_state_t round_const_s;
  ascon_state_t state_add_s;
  ascon_state_t state_sub_s;
  ascon_state_t state_diff_s;

  // addition layer
  assign round_const_s[0] = STATE_DW'(0);
  assign round_const_s[1] = STATE_DW'(0);
  assign round_const_s[2] = STATE_DW'(ascon_pack::RoundConst[round_i]);
  assign round_const_s[3] = STATE_DW'(0);
  assign round_const_s[4] = STATE_DW'(0);

  assign state_add_s = state_i ^ round_const_s;

  // substitution layer
  for (genvar i = 0; i < STATE_DW; i++) begin : gen_sbox
    assign `_COL5(state_sub_s, i) = Sbox[`_COL5(state_add_s, i)];
  end

  // diffusion layer
  assign state_diff_s[0] = `_DIFF64(state_sub_s[0], 19, 28);
  assign state_diff_s[1] = `_DIFF64(state_sub_s[1], 61, 39);
  assign state_diff_s[2] = `_DIFF64(state_sub_s[2], 1, 6);
  assign state_diff_s[3] = `_DIFF64(state_sub_s[3], 10, 17);
  assign state_diff_s[4] = `_DIFF64(state_sub_s[4], 7, 41);

  assign state_o = state_diff_s;

endmodule

// cleanup macros
`undef _RROT64
`undef _DIFF64
`undef _COL5
