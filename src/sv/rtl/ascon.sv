`timescale 1ns / 1ps

module ascon
  import ascon_pack::*;
#(
    parameter int unsigned DATA_AW = 7,
    parameter int unsigned DELAY_WIDTH = 16
) (
    // Clk
    input logic clk,

    // Reset
    input logic rst_n,

    // Control
    input u128_t key_i,
    input u128_t nonce_i,
    input logic [DATA_AW-1:0] ad_size_i,
    input logic [DATA_AW-1:0] pt_size_i,
    input logic [DELAY_WIDTH-1:0] delay_i,

    // Status and tag
    input  logic  start_i,
    output logic  ready_o,
    output logic  wait_ad_o,
    output logic  wait_pt_o,
    output logic  tag_valid_o,
    output u128_t tag_o,
    output logic  first_round_o,

    // AD FIFO
    output logic ad_flush_o,
    output logic ad_pop_o,
    input  u64_t ad_i,
    input  logic ad_empty_i,

    // PT FIFO
    output logic pt_flush_o,
    output logic pt_pop_o,
    input  u64_t pt_i,
    input  logic pt_empty_i,

    // CT FIFO
    output logic ct_flush_o,
    output logic ct_push_o,
    output u64_t ct_o,
    input  logic ct_full_i

);
  parameter int unsigned BLOCK_AW = DATA_AW - 2;

  // AD block counter
  logic en_ad_cnt_s;
  logic load_ad_cnt_s;
  logic [BLOCK_AW-1:0] ad_cnt_s;
  logic ad_cnt_of_s;

  // PT block counter
  logic en_pt_cnt_s;
  logic load_pt_cnt_s;
  logic [BLOCK_AW-1:0] pt_cnt_s;
  logic pt_cnt_of_s;

  // Round counter
  logic en_rnd_cnt_s;
  logic load_rnd_cnt_s;
  logic [ROUND_WIDTH-1:0] init_rnd_s;
  logic [ROUND_WIDTH-1:0] rnd_s;
  logic rnd_of_s;

  // Timer
  logic en_timer_s;
  logic load_timer_s;
  logic [DELAY_WIDTH-1:0] timer_s;
  logic timer_of_s;

  // AD block padding
  logic en_ad_pad_s;
  logic [2:0] ad_idx_s;
  u64_t ad_s;

  // PT block padding
  logic en_pt_pad_s;
  logic [2:0] pt_idx_s;
  u64_t pt_s;

  // CT block truncation
  logic en_ct_trunc_s;
  logic [2:0] ct_idx_s;
  u64_t ct_s;

  // Permutation round
  logic en_state_s;
  logic sel_ad_s;
  logic sel_state_init_s;
  logic sel_xor_init_s;
  logic sel_xor_ext_s;
  logic sel_xor_dom_sep_s;
  logic sel_xor_fin_s;
  logic sel_xor_tag_s;
  logic ct_valid_s;

  counter #(
      .WIDTH(BLOCK_AW)
  ) u_ad_block_counter (
      .clk       (clk),
      .rst_n     (rst_n),
      .en_i      (en_ad_cnt_s),
      .load_i    (load_ad_cnt_s),
      .cnt_i     ('0),
      .cnt_o     (ad_cnt_s),
      .overflow_o(ad_cnt_of_s)
  );

  counter #(
      .WIDTH(BLOCK_AW)
  ) u_pt_block_counter (
      .clk       (clk),
      .rst_n     (rst_n),
      .en_i      (en_pt_cnt_s),
      .load_i    (load_pt_cnt_s),
      .cnt_i     ('0),
      .cnt_o     (pt_cnt_s),
      .overflow_o(pt_cnt_of_s)
  );

  counter #(
      .WIDTH(ROUND_WIDTH)
  ) u_round_counter (
      .clk       (clk),
      .rst_n     (rst_n),
      .en_i      (en_rnd_cnt_s),
      .load_i    (load_rnd_cnt_s),
      .cnt_i     (init_rnd_s),
      .cnt_o     (rnd_s),
      .overflow_o(rnd_of_s)
  );

  counter #(
      .WIDTH(DELAY_WIDTH)
  ) u_timer (
      .clk       (clk),
      .rst_n     (rst_n),
      .en_i      (en_timer_s),
      .load_i    (load_timer_s),
      .cnt_i     ('0),
      .cnt_o     (timer_s),
      .overflow_o(timer_of_s)
  );

  block_padding u_ad_block_padding (
      .en_i  (en_ad_pad_s),
      .idx_i (ad_idx_s),
      .data_i(ad_i),
      .data_o(ad_s)
  );

  block_padding u_pt_block_padding (
      .en_i  (en_pt_pad_s),
      .idx_i (pt_idx_s),
      .data_i(pt_i),
      .data_o(pt_s)
  );

  block_trunc u_block_trunc (
      .en_i  (en_ct_trunc_s),
      .idx_i (ct_idx_s),
      .data_i(ct_s),
      .data_o(ct_o)
  );

  permutation u_permutation (
      // Clk
      .clk              (clk),
      // Reset
      .rst_n            (rst_n),
      // Control
      .en_state_i       (en_state_s),
      .sel_ad_i         (sel_ad_s),
      .sel_state_init_i (sel_state_init_s),
      .sel_xor_init_i   (sel_xor_init_s),
      .sel_xor_ext_i    (sel_xor_ext_s),
      .sel_xor_dom_sep_i(sel_xor_dom_sep_s),
      .sel_xor_fin_i    (sel_xor_fin_s),
      .sel_xor_tag_i    (sel_xor_tag_s),
      .ct_valid_i       (ct_valid_s),
      .tag_valid_i      (tag_valid_o),
      // Round counter
      .rnd_i            (rnd_s),
      // Ascon
      .key_i            (key_i),
      .nonce_i          (nonce_i),
      .ad_i             (ad_s),
      .pt_i             (pt_s),
      .ct_o             (ct_s),
      .tag_o            (tag_o)
  );

  ascon_fsm #(
      .DATA_AW    (DATA_AW),
      .BLOCK_AW   (BLOCK_AW),
      .DELAY_WIDTH(DELAY_WIDTH)
  ) u_ascon_fsm (
      // Clock
      .clk              (clk),
      // Reset
      .rst_n            (rst_n),
      // Control
      .ad_size_i        (ad_size_i),
      .pt_size_i        (pt_size_i),
      // Status
      .start_i          (start_i),
      .ready_o          (ready_o),
      .wait_ad_o        (wait_ad_o),
      .wait_pt_o        (wait_pt_o),
      .first_round_o    (first_round_o),
      // AD FIFO
      .ad_empty_i       (ad_empty_i),
      .ad_pop_o         (ad_pop_o),
      .ad_flush_o       (ad_flush_o),
      // PT FIFO
      .pt_empty_i       (pt_empty_i),
      .pt_pop_o         (pt_pop_o),
      .pt_flush_o       (pt_flush_o),
      // CT FIFO
      .ct_full_i        (ct_full_i),
      .ct_push_o        (ct_push_o),
      .ct_flush_o       (ct_flush_o),
      // AD block counter
      .ad_cnt_i         (ad_cnt_s),
      .en_ad_cnt_o      (en_ad_cnt_s),
      .load_ad_cnt_o    (load_ad_cnt_s),
      // PT block counter
      .pt_cnt_i         (pt_cnt_s),
      .en_pt_cnt_o      (en_pt_cnt_s),
      .load_pt_cnt_o    (load_pt_cnt_s),
      // Round counter
      .rnd_i            (rnd_s),
      .en_rnd_cnt_o     (en_rnd_cnt_s),
      .load_rnd_cnt_o   (load_rnd_cnt_s),
      .init_rnd_o       (init_rnd_s),
      // Delay counter
      .delay_i          (delay_i),
      .timer_i          (timer_s),
      .en_timer_o       (en_timer_s),
      .load_timer_o     (load_timer_s),
      // AD padding
      .en_ad_pad_o      (en_ad_pad_s),
      .ad_idx_o         (ad_idx_s),
      // PT padding
      .en_pt_pad_o      (en_pt_pad_s),
      .pt_idx_o         (pt_idx_s),
      // CT truncation
      .en_ct_trunc_o    (en_ct_trunc_s),
      .ct_idx_o         (ct_idx_s),
      // Permutation round
      .en_state_o       (en_state_s),
      .sel_ad_o         (sel_ad_s),
      .sel_state_init_o (sel_state_init_s),
      .sel_xor_init_o   (sel_xor_init_s),
      .sel_xor_ext_o    (sel_xor_ext_s),
      .sel_xor_dom_sep_o(sel_xor_dom_sep_s),
      .sel_xor_fin_o    (sel_xor_fin_s),
      .sel_xor_tag_o    (sel_xor_tag_s),
      .ct_valid_o       (ct_valid_s),
      .tag_valid_o      (tag_valid_o)
  );

endmodule
