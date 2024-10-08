`timescale 1ns / 1ps
`include "ascon.svh"

module permutation
  import ascon_pack::*;
(
    input logic [3:0] round_i,

    input logic sel_state_init_i,
    input logic sel_xor_init_i,
    input logic sel_xor_ext_i,
    input logic sel_xor_dom_sep_i,
    input logic sel_xor_fin_i,
    input logic sel_xor_tag_i,

    input logic ct_valid_i,
    input logic tag_valid_i,

    input logic [127:0] key_i,
    input logic [127:0] nonce_i,
    input logic [ 63:0] data_i,

    input type_state state_i,
    output type_state state_o,
    output logic [63:0] ciphertext_o,
    output logic [127:0] tag_o
);
  type_state state1_mux_s;
  type_state state2_in_s;
  type_state state3_add_s;
  type_state state4_sbox_s;
  type_state state5_diff_s;
  type_state state6_xor_key_s;
  type_state state7_out_s;

  logic [7:0] round_constant_s;
  logic sel_xor_key_s;

  // load the initial state
  assign state1_mux_s = sel_state_init_i ? {FixedIV, key_i, nonce_i} : state_i;

  // XOR the external state with a data bloc
  assign state2_in_s[0] = sel_xor_ext_i ? state1_mux_s[0] ^ data_i : state1_mux_s[0];
  // XOR part of the internal state with the secret key
  // at the beginning of the finalization
  assign state2_in_s[1] = sel_xor_fin_i ? state1_mux_s[1] ^ key_i[127:64] : state1_mux_s[1];
  assign state2_in_s[2] = sel_xor_fin_i ? state1_mux_s[2] ^ key_i[63:0] : state1_mux_s[2];
  assign state2_in_s[3] = state1_mux_s[3];
  assign state2_in_s[4] = state1_mux_s[4];

  // generate the ciphertext
  assign ciphertext_o = ct_valid_i ? state2_in_s[0] : 0;

  // addition layer
  assign round_constant_s = RoundConstant[round_i];
  assign state3_add_s[0] = state2_in_s[0];
  assign state3_add_s[1] = state2_in_s[1];
  assign state3_add_s[2] = state2_in_s[2] ^ {56'd0, round_constant_s};
  assign state3_add_s[3] = state2_in_s[3];
  assign state3_add_s[4] = state2_in_s[4];

  // substitution layer
  for (genvar i = 0; i < 64; i++) begin : gen_sbox
    `SBOX5(state4_sbox_s, state3_add_s, Sbox, i)
  end

  // diffusion layer
  `DIFF64(state5_diff_s[0], state4_sbox_s[0], 19, 28)
  `DIFF64(state5_diff_s[1], state4_sbox_s[1], 61, 39)
  `DIFF64(state5_diff_s[2], state4_sbox_s[2], 1, 6)
  `DIFF64(state5_diff_s[3], state4_sbox_s[3], 10, 17)
  `DIFF64(state5_diff_s[4], state4_sbox_s[4], 7, 41)

  // XOR part of the internal state with the secret key
  // either at the end of the initialization
  // or at the end of the finalization to generate the tag
  assign sel_xor_key_s = sel_xor_init_i | sel_xor_tag_i;

  assign state6_xor_key_s[0] = state5_diff_s[0];
  assign state6_xor_key_s[1] = state5_diff_s[1];
  assign state6_xor_key_s[2] = state5_diff_s[2];
  assign state6_xor_key_s[3] = sel_xor_key_s ? state5_diff_s[3] ^ key_i[127:64] : state5_diff_s[3];
  assign state6_xor_key_s[4] = sel_xor_key_s ? state5_diff_s[4] ^ key_i[63:0] : state5_diff_s[4];

  // XOR part of the internal state with the domain separation constant
  // at the end of the processing of the associated data
  // or at the end of the initialization if the associated data is missing
  assign state7_out_s[0] = state6_xor_key_s[0];
  assign state7_out_s[1] = state6_xor_key_s[1];
  assign state7_out_s[2] = state6_xor_key_s[2];
  assign state7_out_s[3] = state6_xor_key_s[3];
  assign state7_out_s[4] = sel_xor_dom_sep_i ? state6_xor_key_s[4] ^ 64'd1 : state6_xor_key_s[4];

  // generate the tag
  assign tag_o = tag_valid_i ? {state7_out_s[3], state7_out_s[4]} : 0;

  // output the state of the permutation
  assign state_o = state7_out_s;

endmodule

