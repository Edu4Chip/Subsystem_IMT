`timescale 1ns / 1ps

module ascon_wrapper
  import ascon_pack::*;
#(
    parameter int FifoDepth = 4,
    parameter int DATA_AW = 7,
    parameter int DELAY_WIDTH = 16
) (
    // Interface: Clock
    input logic clk,

    // Interface: Reset
    input logic rst_n,

    // Interface: Ascon
    input u128_t key_i,
    input u128_t nonce_i,
    input logic [DATA_AW-1:0] ad_size_i,
    input logic [DATA_AW-1:0] pt_size_i,
    input logic [DELAY_WIDTH-1:0] delay_i,

    input  logic  start_i,
    output logic  ready_o,
    output logic  tag_valid_o,
    output u128_t tag_o,
    output logic  first_round_o,

    input  logic ad_push_i,
    input  u64_t ad_i,
    output logic ad_full_o,
    output logic ad_empty_o,

    input  logic pt_push_i,
    input  u64_t pt_i,
    output logic pt_full_o,
    output logic pt_empty_o,

    input  logic ct_pop_i,
    output u64_t ct_o,
    output logic ct_full_o,
    output logic ct_empty_o
);
  logic ad_flush_s;
  logic ad_pop_s;
  u64_t ad_s;

  logic pt_flush_s;
  logic pt_pop_s;
  u64_t pt_s;

  logic ct_flush_s;
  logic ct_push_s;
  u64_t ct_s;

  fifo #(
      .DATA_WIDTH(BLOCK_WIDTH),
      .DEPTH     (FifoDepth)
  ) u_fifo_ad (
      .clk    (clk),
      .rst_n  (rst_n),
      .flush_i(ad_flush_s),
      .push_i (ad_push_i),
      .data_i (ad_i),
      .pop_i  (ad_pop_s),
      .data_o (ad_s),
      .full_o (ad_full_o),
      .empty_o(ad_empty_o)
  );

  fifo #(
      .DATA_WIDTH(BLOCK_WIDTH),
      .DEPTH     (FifoDepth)
  ) u_fifo_pt (
      .clk    (clk),
      .rst_n  (rst_n),
      .flush_i(pt_flush_s),
      .push_i (pt_push_i),
      .data_i (pt_i),
      .pop_i  (pt_pop_s),
      .data_o (pt_s),
      .full_o (pt_full_o),
      .empty_o(pt_empty_o)
  );

  fifo #(
      .DATA_WIDTH(BLOCK_WIDTH),
      .DEPTH     (FifoDepth)
  ) u_fifo_ct (
      .clk    (clk),
      .rst_n  (rst_n),
      .flush_i(ct_flush_s),
      .push_i (ct_push_s),
      .data_i (ct_s),
      .pop_i  (ct_pop_i),
      .data_o (ct_o),
      .full_o (ct_full_o),
      .empty_o(ct_empty_o)
  );

  ascon #(
      .DATA_AW    (DATA_AW),
      .DELAY_WIDTH(DELAY_WIDTH)
  ) u_ascon (
      // Clk
      .clk          (clk),
      // Reset
      .rst_n        (rst_n),
      // Control
      .key_i        (key_i),
      .nonce_i      (nonce_i),
      .ad_size_i    (ad_size_i),
      .pt_size_i    (pt_size_i),
      .delay_i      (delay_i),
      // Status and tag
      .start_i      (start_i),
      .ready_o      (ready_o),
      .tag_valid_o  (tag_valid_o),
      .tag_o        (tag_o),
      .first_round_o(first_round_o),
      // AD FIFO
      .ad_flush_o   (ad_flush_s),
      .ad_pop_o     (ad_pop_s),
      .ad_i         (ad_s),
      .ad_empty_i   (ad_empty_o),
      // PT FIFO
      .pt_flush_o   (pt_flush_s),
      .pt_pop_o     (pt_pop_s),
      .pt_i         (pt_s),
      .pt_empty_i   (pt_empty_o),
      // CT FIFO
      .ct_flush_o   (ct_flush_s),
      .ct_push_o    (ct_push_s),
      .ct_o         (ct_s),
      .ct_full_i    (ct_full_o)
  );

endmodule
