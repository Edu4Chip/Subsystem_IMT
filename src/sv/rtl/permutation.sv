`timescale 1ns / 1ps
`include "registers.svh"

// helper macros
`define _RROT64(__d, __n) {__d[__n-1:0], __d[63:__n]}
`define _DIFF64(__d, __n1, __n2) __d ^ `_RROT64(__d, __n1) ^ `_RROT64(__d, __n2)
`define _COL5(__d, __i) {__d[0][__i], __d[1][__i], __d[2][__i], __d[3][__i], __d[4][__i]}

module permutation
  import ascon_pack::*;
(
    // Clk
    input logic clk,

    // Reset
    input logic rst_n,

    // Control
    input logic en_state_i,
    input logic sel_ad_i,
    input logic sel_state_init_i,
    input logic sel_xor_init_i,
    input logic sel_xor_ext_i,
    input logic sel_xor_dom_sep_i,
    input logic sel_xor_fin_i,
    input logic sel_xor_tag_i,
    input logic ct_valid_i,
    input logic tag_valid_i,

    // Round counter
    input logic [ROUND_WIDTH-1:0] rnd_i,

    // Ascon
    input u128_t key_i,
    input u128_t nonce_i,
    input u64_t ad_i,
    input u64_t pt_i,
    output u64_t ct_o,
    output u128_t tag_o
);
  typedef u64_t state_t[5];

  state_t state_q, state_d;
  state_t state1_mux_s;
  state_t state2_in_s;
  state_t state3_add_s;
  state_t state4_sbox_s;
  state_t state5_diff_s;
  state_t state6_xor_key_s;

  u64_t l_key_s, r_key_s;
  u64_t l_nonce_s, r_nonce_s;
  u64_t data_s;
  u8_t  round_constant_s;
  logic sel_xor_key_s;

  // split the key into two data blocks
  assign {l_key_s, r_key_s} = key_i;
  assign {l_nonce_s, r_nonce_s} = nonce_i;

  // load the initial state
  assign state1_mux_s[0] = sel_state_init_i ? ASCON128_IV : state_q[0];
  assign state1_mux_s[1] = sel_state_init_i ? l_key_s : state_q[1];
  assign state1_mux_s[2] = sel_state_init_i ? r_key_s : state_q[2];
  assign state1_mux_s[3] = sel_state_init_i ? l_nonce_s : state_q[3];
  assign state1_mux_s[4] = sel_state_init_i ? r_nonce_s : state_q[4];

  // output the tag when it is valid
  assign tag_o = tag_valid_i ? {state_q[3], state_q[4]} : 128'd0;

  // XOR the external state with a data bloc
  assign data_s = sel_ad_i ? ad_i : pt_i;
  assign state2_in_s[0] = sel_xor_ext_i ? state1_mux_s[0] ^ data_s : state1_mux_s[0];
  // output the ciphertext when it is valid
  assign ct_o = ct_valid_i ? state2_in_s[0] : 64'd0;
  // XOR part of the internal state with the secret key
  // at the beginning of the finalization
  assign state2_in_s[1] = sel_xor_fin_i ? state1_mux_s[1] ^ l_key_s : state1_mux_s[1];
  assign state2_in_s[2] = sel_xor_fin_i ? state1_mux_s[2] ^ r_key_s : state1_mux_s[2];
  assign state2_in_s[3] = state1_mux_s[3];
  assign state2_in_s[4] = state1_mux_s[4];

  // addition layer
  assign round_constant_s = (rnd_i < ROUND_NO) ? RndConst[rnd_i] : 8'h00;
  assign state3_add_s[0] = state2_in_s[0];
  assign state3_add_s[1] = state2_in_s[1];
  assign state3_add_s[2] = state2_in_s[2] ^ {56'd0, round_constant_s};
  assign state3_add_s[3] = state2_in_s[3];
  assign state3_add_s[4] = state2_in_s[4];

  // substitution layer
  for (genvar i = 0; i < 64; i++) begin : gen_sbox
    assign `_COL5(state4_sbox_s, i) = Sbox[`_COL5(state3_add_s, i)];
  end

  // diffusion layer
  assign state5_diff_s[0] = `_DIFF64(state4_sbox_s[0], 19, 28);
  assign state5_diff_s[1] = `_DIFF64(state4_sbox_s[1], 61, 39);
  assign state5_diff_s[2] = `_DIFF64(state4_sbox_s[2], 1, 6);
  assign state5_diff_s[3] = `_DIFF64(state4_sbox_s[3], 10, 17);
  assign state5_diff_s[4] = `_DIFF64(state4_sbox_s[4], 7, 41);

  // XOR part of the internal state with the secret key
  // either at the end of the initialization
  // or at the end of the finalization to generate the tag
  assign sel_xor_key_s = sel_xor_init_i || sel_xor_tag_i;
  assign state6_xor_key_s[0] = state5_diff_s[0];
  assign state6_xor_key_s[1] = state5_diff_s[1];
  assign state6_xor_key_s[2] = state5_diff_s[2];
  assign state6_xor_key_s[3] = sel_xor_key_s ? state5_diff_s[3] ^ l_key_s : state5_diff_s[3];
  assign state6_xor_key_s[4] = sel_xor_key_s ? state5_diff_s[4] ^ r_key_s : state5_diff_s[4];

  // XOR part of the internal state with the domain separation constant
  // at the end of the processing of the associated data
  // or at the end of the initialization if the associated data is missing
  assign state_d[0] = state6_xor_key_s[0];
  assign state_d[1] = state6_xor_key_s[1];
  assign state_d[2] = state6_xor_key_s[2];
  assign state_d[3] = state6_xor_key_s[3];
  assign state_d[4] = sel_xor_dom_sep_i ? state6_xor_key_s[4] ^ DOM_SEP_CONST : state6_xor_key_s[4];

  // state register
  for (genvar i = 0; i < 5; i++) begin : gen_state
    `FFL(state_q[i], state_d[i], en_state_i, 64'd0, clk, rst_n)
  end

endmodule

// cleanup macros
`undef _RROT64
`undef _DIFF64
`undef _COL5
