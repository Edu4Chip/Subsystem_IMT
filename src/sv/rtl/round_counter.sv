`timescale 1ns / 1ps
`include "registers.svh"

module round_counter #(
    parameter int WIDTH = 4
) (
    input logic clk_i,
    input logic rst_n_i,
    input logic en_i,
    input logic load_i,
    input logic sel_p12_init_i,
    output logic [WIDTH-1:0] round_o,
    output logic n_last_rnd_o
);
  localparam logic [WIDTH-1:0] RoundP12 = 0;
  localparam logic [WIDTH-1:0] RoundP6 = RoundP12 + 6;
  localparam logic [WIDTH-1:0] LastRound = 11;

  logic [WIDTH-1:0] round_s, n_round_s;

  // round counter logic
  always_comb begin
    n_round_s = 0;
    if (load_i) begin
      if (sel_p12_init_i) begin
        n_round_s = RoundP12;
      end else begin
        n_round_s = RoundP6;
      end
    end else begin
      n_round_s = round_s + 1;
    end
  end
  assign round_o = round_s;
  assign n_last_rnd_o = round_s == (LastRound - 1);

  `FFL(round_s, n_round_s, en_i, 0, clk_i, rst_n_i)

endmodule
