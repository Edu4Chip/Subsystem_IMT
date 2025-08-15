`timescale 1ns / 1ps

module ascon_round_counter
  import ascon_pack::*;
(
  input  logic                   clk,
  input  logic                   rst_n,
  input  logic                   en_i,
  input  logic                   load_a_i,
  input  logic                   load_b_i,
  output logic [ROUND_WIDTH-1:0] round_o,
  output logic                   round_last_o
);

  localparam int unsigned ROUND_LAST = MAX_ROUND_NO - 2;
  localparam int unsigned ROUND_A_START = MAX_ROUND_NO - ROUND_A;
  localparam int unsigned ROUND_B_START = MAX_ROUND_NO - ROUND_B;

  logic [ROUND_WIDTH-1:0] round_q, round_d;

  assign round_last_o = (round_q == ROUND_LAST[ROUND_WIDTH-1:0]);
  assign round_o = round_q;

  assign round_d = round_q + 1'b1;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      round_q <= '0;
    end else begin
      if (load_a_i) begin
        round_q <= ROUND_A_START[ROUND_WIDTH-1:0];
      end else if (load_b_i) begin
        round_q <= ROUND_B_START[ROUND_WIDTH-1:0];
      end else if (en_i) begin
        round_q <= round_d;
      end
    end
  end

endmodule
