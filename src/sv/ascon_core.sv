`timescale 1ns / 1ps

module ascon_core
  import ascon_pack::*;
#(
  parameter int unsigned SIZE_WIDTH  = 8,
  parameter int unsigned DELAY_WIDTH = 16
) (

  input logic clk,
  input logic rst_n,

  input logic                   start_i,
  input logic                   decrypt_i,
  input logic [ SIZE_WIDTH-1:0] ad_size_i,
  input logic [ SIZE_WIDTH-1:0] di_size_i,
  input logic [DELAY_WIDTH-1:0] delay_i,
  input logic [  KEY_WIDTH-1:0] key_i,
  input logic [NONCE_WIDTH-1:0] nonce_i,

  input logic [BLOCK_WIDTH-1:0] data_i,
  input logic                   data_valid_i,

  output logic idle_o,
  output logic sync_o,
  output logic done_o,

  output logic                   data_ready_o,
  output logic [BLOCK_WIDTH-1:0] data_o,
  output logic                   data_valid_o,
  output logic [  TAG_WIDTH-1:0] tag_o,
  output logic                   tag_valid_o

);

  localparam int unsigned BLOCK_AW = SIZE_WIDTH - PAD_AW;

  logic [PAD_AW-1:0] ad_pad_idx_s, di_pad_idx_s;
  logic [BLOCK_AW-1:0] ad_blk_no_s, di_blk_no_s;

  logic [BLOCK_WIDTH-1:0] buf_in_s, data_in_s;
  logic [BLOCK_WIDTH-1:0] buf_out_s, data_out_s;

  ascon_op_e op_s;

  logic [TAG_WIDTH-1:0] tag_s;
  logic [ROUND_WIDTH-1:0] round_s;

  logic [BLOCK_AW-1:0] ad_cnt_s, di_cnt_s;
  logic [DELAY_WIDTH-1:0] timer_s;

  // Data path

  ascon_size_decoder #(
    .SIZE_WIDTH(SIZE_WIDTH),
    .BLOCK_AW  (BLOCK_AW)
  ) u_ascon_size_decoder (
    .ad_size_i   (ad_size_i),
    .di_size_i   (di_size_i),
    .ad_pad_idx_o(ad_pad_idx_s),
    .di_pad_idx_o(di_pad_idx_s),
    .ad_blk_no_o (ad_blk_no_s),
    .di_blk_no_o (di_blk_no_s)
  );

  ascon_reg #(
    .WIDTH(BLOCK_WIDTH)
  ) u_ascon_input_buffer (
    .clk   (clk),
    .rst_n (rst_n),
    .en_i  (en_buf_in_s),
    .data_i(data_i),
    .data_o(buf_in_s)
  );

  ascon_input_padding u_ascon_input_padding (
    .en_i        (en_padding_s),
    .sel_ad_i    (sel_ad_s),
    .ad_pad_idx_i(ad_pad_idx_s),
    .di_pad_idx_i(di_pad_idx_s),
    .data_i      (buf_in_s),
    .data_o      (data_in_s)
  );

  ascon_round_unit #(
    .BLOCK_AW(BLOCK_AW)
  ) u_ascon_round_unit (
    .clk         (clk),
    .rst_n       (rst_n),
    .en_i        (en_state_s),
    .op_i        (op_s),
    .decrypt_i   (decrypt_i),
    .di_pad_idx_i(di_pad_idx_s),
    .di_blk_no_i (di_blk_no_s),
    .key_i       (key_i),
    .nonce_i     (nonce_i),
    .round_i     (round_s),
    .data_i      (data_in_s),
    .data_o      (data_out_s),
    .tag_o       (tag_s)
  );

  ascon_output_trunc u_ascon_output_trunc (
    .en_i        (en_trunc_s),
    .di_pad_idx_i(di_pad_idx_s),
    .data_i      (data_out_s),
    .data_o      (buf_out_s)
  );

  ascon_reg #(
    .WIDTH(BLOCK_WIDTH)
  ) u_ascon_output_buffer (
    .clk   (clk),
    .rst_n (rst_n),
    .en_i  (en_buf_out_s),
    .data_i(buf_out_s),
    .data_o(data_o)
  );

  ascon_reg #(
    .WIDTH(TAG_WIDTH)
  ) u_ascon_tag_buffer (
    .clk   (clk),
    .rst_n (rst_n),
    .en_i  (en_tag_s),
    .data_i(tag_s),
    .data_o(tag_o)
  );

  // Control path

  ascon_ctrl #(
    .SIZE_WIDTH(SIZE_WIDTH),
    .BLOCK_AW  (BLOCK_AW)
  ) u_ascon_ctrl (
    .clk          (clk),
    .rst_n        (rst_n),
    .start_i      (start_i),
    .ad_size_i    (ad_size_i),
    .di_size_i    (di_size_i),
    .ad_pad_idx_i (ad_pad_idx_s),
    .di_pad_idx_i (di_pad_idx_s),
    .ad_blk_no_i  (ad_blk_no_s),
    .di_blk_no_i  (di_blk_no_s),
    .data_valid_i (data_valid_i),
    .ad_last_i    (ad_last_s),
    .di_last_i    (di_last_s),
    .rnd_last_i   (rnd_last_s),
    .timeout_i    (timeout_s),
    .idle_o       (idle_o),
    .sync_o       (sync_o),
    .done_o       (done_o),
    .en_state_o   (en_state_s),
    .op_o         (op_s),
    .sel_ad_o     (sel_ad_s),
    .en_padding_o (en_padding_s),
    .en_trunc_o   (en_trunc_s),
    .en_buf_in_o  (en_buf_in_s),
    .data_ready_o (data_ready_o),
    .en_buf_out_o (en_buf_out_s),
    .data_valid_o (data_valid_o),
    .en_tag_o     (en_tag_s),
    .tag_valid_o  (tag_valid_o),
    .en_ad_cnt_o  (en_ad_cnt_s),
    .load_ad_cnt_o(load_ad_cnt_s),
    .en_di_cnt_o  (en_di_cnt_s),
    .load_di_cnt_o(load_di_cnt_s),
    .en_rnd_o     (en_rnd_s),
    .load_rnd_a_o (load_rnd_a_s),
    .load_rnd_b_o (load_rnd_b_s),
    .en_timer_o   (en_timer_s),
    .load_timer_o (load_timer_s)
  );

  ascon_down_counter #(
    .WIDTH(BLOCK_AW)
  ) u_ad_counter (
    .clk    (clk),
    .rst_n  (rst_n),
    .en_i   (en_ad_cnt_s),
    .load_i (load_ad_cnt_s),
    .count_i(ad_blk_no_s),
    .count_o(ad_cnt_s),
    .zero_o (ad_last_s)
  );

  ascon_down_counter #(
    .WIDTH(BLOCK_AW)
  ) u_di_counter (
    .clk    (clk),
    .rst_n  (rst_n),
    .en_i   (en_di_cnt_s),
    .load_i (load_di_cnt_s),
    .count_i(di_blk_no_s),
    .count_o(di_cnt_s),
    .zero_o (di_last_s)
  );

  ascon_down_counter #(
    .WIDTH(DELAY_WIDTH)
  ) u_timer (
    .clk    (clk),
    .rst_n  (rst_n),
    .en_i   (en_timer_s),
    .load_i (load_timer_s),
    .count_i(delay_i),
    .count_o(timer_s),
    .zero_o (timeout_s)
  );

  ascon_round_counter u_ascon_round_counter (
    .clk         (clk),
    .rst_n       (rst_n),
    .en_i        (en_rnd_s),
    .load_a_i    (load_rnd_a_s),
    .load_b_i    (load_rnd_b_s),
    .round_o     (round_s),
    .round_last_o(rnd_last_s)
  );

endmodule
