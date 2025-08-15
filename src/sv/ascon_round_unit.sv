module ascon_round_unit
  import ascon_pack::*;
#(
  parameter int unsigned BLOCK_AW
) (

  input logic clk,
  input logic rst_n,
  input logic en_i,

  input ascon_op_e                   op_i,
  input logic                        decrypt_i,
  input logic      [     PAD_AW-1:0] di_pad_idx_i,
  input logic      [   BLOCK_AW-1:0] di_blk_no_i,
  input logic      [  KEY_WIDTH-1:0] key_i,
  input logic      [NONCE_WIDTH-1:0] nonce_i,
  input logic      [ROUND_WIDTH-1:0] round_i,
  input logic      [BLOCK_WIDTH-1:0] data_i,

  output logic [BLOCK_WIDTH-1:0] data_o,
  output logic [  TAG_WIDTH-1:0] tag_o

);

  logic [STATE_WIDTH-1:0] state_q, state_d;

  ascon_reg #(
    .WIDTH(STATE_WIDTH)
  ) u_ascon_reg (
    .clk   (clk),
    .rst_n (rst_n),
    .en_i  (en_i),
    .data_i(state_d),
    .data_o(state_q)
  );

  ascon_round_function #(
    .BLOCK_AW(BLOCK_AW)
  ) u_ascon_round_function (
    .op_i        (op_i),
    .decrypt_i   (decrypt_i),
    .di_pad_idx_i(di_pad_idx_i),
    .di_blk_no_i (di_blk_no_i),
    .key_i       (key_i),
    .nonce_i     (nonce_i),
    .round_i     (round_i),
    .data_i      (data_i),
    .state_i     (state_q),
    .state_o     (state_d),
    .data_o      (data_o),
    .tag_o       (tag_o)
  );

endmodule
