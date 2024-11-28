module block_padding
  import ascon_pack::*;
(
    input logic en_i,
    input logic [2:0] idx_i,
    input u64_t data_i,
    output u64_t data_o
);
  u64_t pad_s[8];

  assign pad_s[0] = {1'b1, {(BLOCK_WIDTH - 1) {1'b0}}};
  for (genvar i = 1; i < 8; i++) begin : gen_padding
    assign pad_s[i] = {data_i[BLOCK_WIDTH-1-:i*8], 1'b1, {(BLOCK_WIDTH - i * 8 - 1) {1'b0}}};
  end

  assign data_o = en_i ? pad_s[idx_i] : data_i;

endmodule
