`timescale 1ns / 1ps
`include "registers.svh"

module round_counter
  import ascon_pack::*;
(
    input  logic clk_i,
    input  logic rst_n_i,
    input  logic en_i,
    input  logic load_i,
    input  logic sel_p12_init_i,
    output rnd_t round_o,
    output logic n_last_rnd_o
);
  localparam rnd_t InitRndP12 = 0;
  localparam rnd_t InitRndP6 = 6;
  localparam rnd_t BeforeLastRound = 10;
  localparam rnd_t MaxRndValue = 11;

  rnd_t rnd_q, rnd_d;
  logic last_rnd_s;

  assign last_rnd_s = (rnd_q == MaxRndValue);

  // round counter logic
  always_comb begin
    rnd_d = rnd_q;
    if (load_i) begin
      if (sel_p12_init_i) begin
        rnd_d = InitRndP12;
      end else begin
        rnd_d = InitRndP6;
      end
    end else if (!last_rnd_s) begin
      rnd_d = rnd_q + 1'b1;
    end
  end
  assign round_o = rnd_q;
  assign n_last_rnd_o = (rnd_q == BeforeLastRound);

  `FFL(rnd_q, rnd_d, en_i, 0, clk_i, rst_n_i)

endmodule
