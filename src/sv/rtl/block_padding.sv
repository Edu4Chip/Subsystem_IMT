module block_padding
  import ascon_pack::*;
#(
    parameter int unsigned DATA_AW  = 7,
    parameter int unsigned BLOCK_AW = DATA_AW - 3
) (
    input logic [DATA_AW-1:0] ad_size_i,
    input logic [BLOCK_AW-1:0] ad_blk_cnt_i,
    input u64_t ad_i,
    output logic [BLOCK_AW-1:0] ad_blk_no_o,
    output u64_t ad_o,

    input logic [DATA_AW-1:0] pt_size_i,
    input logic [BLOCK_AW:0] pt_blk_cnt_i,
    input u64_t pt_i,
    output logic [BLOCK_AW:0] pt_blk_no_o,
    output u64_t pt_o,

    input  u64_t ct_i,
    output u64_t ct_o

);
  logic [2:0] ad_pad_size_s;
  logic [2:0] pt_pad_size_s;
  logic [BLOCK_AW-1:0] ad_blk_no_s;
  logic [BLOCK_AW:0] pt_blk_no_s;
  u64_t ad_w_pad_s[8];
  u64_t pt_w_pad_s[8];
  u64_t ct_wo_pad_s[8];

  assign ad_pad_size_s = ad_size_i[2:0];
  assign ad_blk_no_s   = ad_size_i[2+:BLOCK_AW];
  assign pt_pad_size_s = pt_size_i[2:0];

  always_comb begin
    if (pt_pad_size_s == '0) begin
      pt_blk_no_s = pt_size_i[2+:BLOCK_AW] + 1'b1;
    end else begin
      pt_blk_no_s = {1'b0, pt_size_i[2+:BLOCK_AW]};
    end
  end

  assign ad_w_pad_s[0] = ad_i;
  for (genvar i = 1; i < 8; i++) begin : gen_ad_padding
    assign ad_w_pad_s[i] = {ad_i[BLOCK_WIDTH-1-:i*8], 1'b1, {(BLOCK_WIDTH - i * 8 - 1) {1'b0}}};
  end

  assign pt_w_pad_s[0] = {1'b1, {(BLOCK_WIDTH-1){1'b0}}};
  assign ct_wo_pad_s[0] = '0;
  for (genvar i = 1; i < 8; i++) begin : gen_pt_padding
    assign pt_w_pad_s[i] = {pt_i[BLOCK_WIDTH-1-:i*8], 1'b1, {(BLOCK_WIDTH - i * 8 - 1) {1'b0}}};
    assign ct_wo_pad_s[i] = {ct_i[BLOCK_WIDTH-1-:i*8], {(BLOCK_WIDTH - i * 8) {1'b0}}};
  end

  always_comb begin: comb_padding
    ad_o = ad_i;
    pt_o = pt_i;
    ct_o = ct_i;

    if (ad_blk_cnt_i == ad_blk_no_s) begin
      ad_o = ad_w_pad_s[ad_pad_size_s];
    end

    if (pt_blk_cnt_i == pt_blk_no_s) begin
      pt_o = pt_w_pad_s[pt_pad_size_s];
      ct_o = ct_wo_pad_s[pt_pad_size_s];
    end
  end

  assign ad_blk_no_o = ad_blk_no_s;
  assign pt_blk_no_o = pt_blk_no_s;

endmodule
