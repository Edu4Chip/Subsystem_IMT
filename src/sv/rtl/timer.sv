`timescale 1ns / 1ps
`include "registers.svh"

module timer #(
    parameter int WIDTH
) (
    input logic clk_i,
    input logic rst_n_i,
    input logic en_i,
    input logic load_i,
    input [WIDTH-1:0] count_i,
    output logic timeout_o
);
  logic [WIDTH-1:0] count_s, n_count_s;

  always_comb begin
    timeout_o = 0;
    if (load_i) begin
      n_count_s = ~count_i;
    end else begin
      {timeout_o, n_count_s} = count_s + 1;
    end
  end

  `FFL(count_s, n_count_s, en_i, 0, clk_i, rst_n_i)
endmodule
