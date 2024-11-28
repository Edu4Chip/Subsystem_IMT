module block_trunc
  import ascon_pack::*;
(
    input logic en_i,
    input logic [2:0] idx_i,
    input u64_t data_i,
    output u64_t data_o
);
  u64_t trunc_s[8];

  assign trunc_s[0] = '0;
  for (genvar i = 1; i < 8; i++) begin : gen_padding
    assign trunc_s[i] = {data_i[BLOCK_WIDTH-1-:i*8], {(BLOCK_WIDTH - i * 8) {1'b0}}};
  end

  assign data_o = en_i ? trunc_s[idx_i] : data_i;

endmodule

