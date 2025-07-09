`timescale 1ns / 1ps
`include "imt_registers.svh"

module counter #(
    parameter int unsigned WIDTH = 4
) (
    input logic clk,
    input logic rst_n,
    input logic en_i,
    input logic load_i,
    input logic [WIDTH-1:0] cnt_i,
    output logic [WIDTH-1:0] cnt_o,
    output logic overflow_o
);
  logic [WIDTH:0] cnt_q, cnt_d;
  logic overflow_s;

  assign overflow_s = cnt_q[WIDTH];

  always_comb begin
    cnt_d = cnt_q;
    if (load_i) begin
      cnt_d = {1'b0, cnt_i};
    end else if (en_i && !overflow_s) begin
      cnt_d = cnt_q + 1'b1;
    end
  end

  `FF(cnt_q, cnt_d, '0, clk, rst_n)

  assign cnt_o = cnt_q[WIDTH-1:0];
  assign overflow_o = overflow_s;

endmodule
