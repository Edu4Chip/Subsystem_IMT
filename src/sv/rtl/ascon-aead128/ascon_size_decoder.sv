`timescale 1ns / 1ps

module ascon_size_decoder
  import ascon_pack::*;
#(
  parameter int unsigned SIZE_WIDTH,
  parameter int unsigned BLOCK_AW
) (

  input logic [SIZE_WIDTH-1:0] ad_size_i,
  input logic [SIZE_WIDTH-1:0] di_size_i,

  output logic [  PAD_AW-1:0] ad_pad_idx_o,
  output logic [  PAD_AW-1:0] di_pad_idx_o,
  output logic [BLOCK_AW-1:0] ad_blk_no_o,
  output logic [BLOCK_AW-1:0] di_blk_no_o

);

  assign ad_pad_idx_o = ad_size_i[PAD_AW-1:0];
  assign di_pad_idx_o = di_size_i[PAD_AW-1:0];
  // the last block is not counted in as it is handled differently
  assign ad_blk_no_o = ad_size_i[PAD_AW+:BLOCK_AW];
  assign di_blk_no_o = di_size_i[PAD_AW+:BLOCK_AW];

endmodule
