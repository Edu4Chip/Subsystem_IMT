`timescale 1ns / 1ps

module ascon_input_padding
  import ascon_pack::*;
(
  input  logic                   en_i,
  input  logic                   sel_ad_i,
  input  logic [     PAD_AW-1:0] ad_pad_idx_i,
  input  logic [     PAD_AW-1:0] di_pad_idx_i,
  input  logic [BLOCK_WIDTH-1:0] data_i,
  output logic [BLOCK_WIDTH-1:0] data_o
);

  logic [BLOCK_WIDTH-1:0] pad_s[PAD_NO];
  logic [PAD_AW-1:0] pad_idx_s;

  assign pad_idx_s = sel_ad_i ? ad_pad_idx_i : di_pad_idx_i;
  assign data_o = en_i ? pad_s[pad_idx_s] : data_i;

  assign pad_s[0] = {{(BLOCK_WIDTH-1){1'b0}}, 1'b1};
  for (genvar i = 1; i < PAD_NO; i++) begin : gen_pad
    assign pad_s[i] = {{(BLOCK_WIDTH - 8 * i - 1) {1'b0}}, 1'b1, data_i[8*i-1:0]};
  end


endmodule
