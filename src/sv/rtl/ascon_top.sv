`timescale 1ns / 1ps

module ascon_top
  import ascon_pack::*;
#(
    parameter int BLK_AD_AW = 10,
    parameter int BLK_PT_AW = 10
) (
    input logic clk_i,
    input logic rst_n_i,
    input logic [63:0] data_i,
    input logic [127:0] key_i,
    input logic [127:0] nonce_i,
    input logic [BLK_AD_AW-1:0] ad_size_i,
    input logic [BLK_PT_AW-1:0] pt_size_i,
    input logic start_i,
    input logic data_valid_i,
    output logic data_req_o,
    output logic ready_o,
    output logic done_o,
    output logic ct_valid_o,
    output logic [63:0] ct_o,
    output logic tag_valid_o,
    output logic [127:0] tag_o
);

  // Input data register
  logic load_data_s;
  logic [63:0] data_s;

  // State register
  logic load_state_s;
  type_state state_s, n_state_s;

  // AD block counter
  logic en_ad_cnt_s;
  logic load_ad_cnt_s;
  logic [BLK_AD_AW-1:0] ad_cnt_s;
  logic last_ad_blk_s;

  // PT block counter
  logic en_pt_cnt_s;
  logic load_pt_cnt_s;
  logic [BLK_PT_AW-1:0] pt_cnt_s;
  logic last_pt_blk_s;

  // Round counter
  logic en_rnd_cnt_s;
  logic load_rnd_cnt_s;
  logic sel_p12_init_s;
  logic [3:0] round_s;
  logic n_last_rnd_o;

  // Permutation round
  logic sel_state_init_s;
  logic sel_xor_init_s;
  logic sel_xor_ext_s;
  logic sel_xor_dom_sep_s;
  logic sel_xor_fin_s;
  logic sel_xor_tag_s;
  logic ct_valid_s;
  logic tag_valid_s;

  `FF(data_s, data_i, 0, clk_i, rst_n_i)
  `FFL(state_s, n_state_s, load_state_s, 0, clk_i, rst_n_i)

  block_counter #(
      .WIDTH(BLK_AD_AW)
  ) u_block_counter_ad (
      .clk_i     (clk_i),
      .rst_n_i   (rst_n_i),
      .en_i      (en_ad_cnt_s),
      .load_i    (load_ad_cnt_s),
      .blk_no_i  (ad_size_i),
      .blk_cnt_i (0),
      .blk_cnt_o (ad_cnt_s),
      .last_blk_o(last_ad_blk_s)
  );

  block_counter #(
      .WIDTH(BLK_PT_AW)
  ) u_block_counter_pt (
      .clk_i     (clk_i),
      .rst_n_i   (rst_n_i),
      .en_i      (en_pt_cnt_s),
      .load_i    (load_pt_cnt_s),
      .blk_no_i  (pt_size_i),
      .blk_cnt_i (0),
      .blk_cnt_o (pt_cnt_s),
      .last_blk_o(last_pt_blk_s)
  );

  round_counter #(
      .WIDTH(4)
  ) u_round_counter (
      .clk_i         (clk_i),
      .rst_n_i       (rst_n_i),
      .en_i          (en_rnd_cnt_s),
      .load_i        (load_rnd_cnt_s),
      .sel_p12_init_i(sel_p12_init_s),
      .round_o       (round_s),
      .n_last_rnd_o  (n_last_rnd_o)
  );

  permutation u_permutation (
      .round_i          (round_s),
      .sel_state_init_i (sel_state_init_s),
      .sel_xor_init_i   (sel_xor_init_s),
      .sel_xor_ext_i    (sel_xor_ext_s),
      .sel_xor_dom_sep_i(sel_xor_dom_sep_s),
      .sel_xor_fin_i    (sel_xor_fin_s),
      .sel_xor_tag_i    (sel_xor_tag_s),
      .ct_valid_i       (ct_valid_s),
      .tag_valid_i      (tag_valid_s),
      .key_i            (key_i),
      .nonce_i          (nonce_i),
      .data_i           (data_s),
      .state_i          (state_s),
      .state_o          (n_state_s),
      .ciphertext_o     (ct_o),
      .tag_o            (tag_o)
  );

  assign ct_valid_o  = ct_valid_s;
  assign tag_valid_o = tag_valid_s;

  ascon_fsm u_ascon_fsm (
      // Clock
      .clk_i            (clk_i),
      // Reset
      .rst_n_i          (rst_n_i),
      // FSM
      .start_i          (start_i),
      .data_valid_i     (data_valid_i),
      .data_req_o       (data_req_o),
      .ready_o          (ready_o),
      .done_o           (done_o),
      // State register
      .load_state_o     (load_state_s),
      // AD block counter
      .last_ad_blk_i    (last_ad_blk_s),
      .en_ad_cnt_o      (en_ad_cnt_s),
      .load_ad_cnt_o    (load_ad_cnt_s),
      // PT block counter
      .pt_cnt_end_i     (last_pt_blk_s),
      .en_pt_cnt_o      (en_pt_cnt_s),
      .load_pt_cnt_o    (load_pt_cnt_s),
      // Round counter
      .n_last_rnd_i     (n_last_rnd_o),
      .en_rnd_cnt_o     (en_rnd_cnt_s),
      .load_rnd_cnt_o   (load_rnd_cnt_s),
      .sel_p12_init_o   (sel_p12_init_s),
      // Permutation round
      .sel_state_init_o (sel_state_init_s),
      .sel_xor_init_o   (sel_xor_init_s),
      .sel_xor_ext_o    (sel_xor_ext_s),
      .sel_xor_dom_sep_o(sel_xor_dom_sep_s),
      .sel_xor_fin_o    (sel_xor_fin_s),
      .sel_xor_tag_o    (sel_xor_tag_s),
      .ct_valid_o       (ct_valid_s),
      .tag_valid_o      (tag_valid_s)
  );

endmodule
