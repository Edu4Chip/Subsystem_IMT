`timescale 1ns / 1ps

module ascon_round_function
  import ascon_pack::*;
#(
  parameter int unsigned BLOCK_AW
) (

  input ascon_op_e                   op_i,
  input logic                        decrypt_i,
  input logic      [     PAD_AW-1:0] di_pad_idx_i,
  input logic      [   BLOCK_AW-1:0] di_blk_no_i,
  input logic      [  KEY_WIDTH-1:0] key_i,
  input logic      [NONCE_WIDTH-1:0] nonce_i,
  input logic      [ROUND_WIDTH-1:0] round_i,
  input logic      [BLOCK_WIDTH-1:0] data_i,
  input logic      [STATE_WIDTH-1:0] state_i,

  output logic [STATE_WIDTH-1:0] state_o,
  output logic [BLOCK_WIDTH-1:0] data_o,
  output logic [  TAG_WIDTH-1:0] tag_o

);
  localparam int unsigned EXT_WIDTH = BLOCK_WIDTH;
  localparam int unsigned INT_WIDTH = STATE_WIDTH - BLOCK_WIDTH;
  localparam logic [INT_WIDTH-1:0] DOM_SEP_CONST = {1'b1, {(INT_WIDTH - 1) {1'b0}}};

  typedef struct packed {
    logic [INT_WIDTH-1:0] internal;
    logic [EXT_WIDTH-1:0] external;
  } ascon_state_t;

  logic [STATE_WIDTH-1:0] ascon_iv_s;
  logic [  INT_WIDTH-1:0] init_key_pad_s;
  logic [  INT_WIDTH-1:0] fin_key_pad_s;

  ascon_state_t state_reg_input_s, state_reg_output_s;
  ascon_state_t perm_state_input_s, perm_state_output_s;

  assign ascon_iv_s = {nonce_i, key_i, ASCON_AEAD128_IV};
  assign init_key_pad_s = {key_i, {(INT_WIDTH - KEY_WIDTH) {1'b0}}};
  assign fin_key_pad_s = {{(INT_WIDTH - KEY_WIDTH) {1'b0}}, key_i};

  assign state_reg_output_s = state_i;
  assign state_o = state_reg_input_s;

  always_comb begin : permutation_logic
    perm_state_input_s = state_reg_output_s;
    state_reg_input_s  = perm_state_output_s;
    tag_o = TAG_WIDTH'(0);
    data_o = BLOCK_WIDTH'(0);

    case (op_i)

      AsconOp0: begin
        // Others
      end

      AsconOp1: begin
        // initialize the state
        perm_state_input_s = ascon_iv_s;
      end

      AsconOp2: begin
        // xoring the secret key into the last 128 bits of the state
        state_reg_input_s.internal = perm_state_output_s.internal ^ init_key_pad_s;
      end

      AsconOp3: begin
        // xoring the secret key into the last 128 bits of the state and adding the sep. constant
        state_reg_input_s.internal = perm_state_output_s.internal ^ init_key_pad_s ^ DOM_SEP_CONST;
      end

      AsconOp4: begin
        perm_state_input_s.external = state_reg_output_s.external ^ data_i;
      end

      AsconOp5: begin
        // adding the sep. constant after processing AD
        state_reg_input_s.internal = perm_state_output_s.internal ^ DOM_SEP_CONST;
      end

      AsconOp6: begin
        data_o = state_reg_output_s.external ^ data_i;
        if (!decrypt_i) begin
          perm_state_input_s.external = data_o;
        end else begin
          perm_state_input_s.external = data_i;
        end
      end

      AsconOp7: begin
        data_o = state_reg_output_s.external ^ data_i;
        if (!decrypt_i) begin
          perm_state_input_s.external = data_o;
        end else begin
          perm_state_input_s.external = data_i;
        end
        perm_state_input_s.internal = state_reg_output_s.internal ^ fin_key_pad_s;
      end

      AsconOp8: begin
        tag_o = perm_state_output_s.internal[INT_WIDTH-1-:TAG_WIDTH] ^ key_i;
      end

      default: begin
      end

    endcase
  end

  ascon_permutation u_ascon_permutation (
    .round_i(round_i),
    .state_i(perm_state_input_s),
    .state_o(perm_state_output_s)
  );

endmodule
