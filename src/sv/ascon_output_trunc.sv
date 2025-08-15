module ascon_output_trunc
  import ascon_pack::*;
(
  input  logic                   en_i,
  input  logic [     PAD_AW-1:0] di_pad_idx_i,
  input  logic [BLOCK_WIDTH-1:0] data_i,
  output logic [BLOCK_WIDTH-1:0] data_o
);

  logic [BLOCK_WIDTH-1:0] trunc_s[PAD_NO];

  assign data_o = en_i ? trunc_s[di_pad_idx_i] : data_i;

  assign trunc_s[0] = BLOCK_WIDTH'(0);
  for (genvar i = 1; i < PAD_NO; i++) begin : gen_pad
    assign trunc_s[i] = {{(BLOCK_WIDTH - 8 * i) {1'b0}}, data_i[8*i-1:0]};
  end

endmodule
