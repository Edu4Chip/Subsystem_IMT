`timescale 1ns / 1ps

module block_counter #(
    parameter int WIDTH = 8
) (
    input logic clk_i,
    input logic rst_n_i,
    input logic en_i,
    input logic load_i,
    input logic [WIDTH-1:0] blk_no_i,
    input logic [WIDTH-1:0] blk_cnt_i,
    output logic [WIDTH-1:0] blk_cnt_o,
    output logic last_blk_o
);
  logic [WIDTH-1:0] blk_cnt_s, n_blk_cnt_s;
  logic last_blk_s;

  assign last_blk_s = (blk_cnt_s == blk_no_i);

  always_comb begin
    n_blk_cnt_s = blk_cnt_s;
    if (load_i) begin
      n_blk_cnt_s = blk_cnt_i;
    end else begin
      if (last_blk_s) begin
        n_blk_cnt_s = blk_cnt_i;
      end else begin
        n_blk_cnt_s = blk_cnt_s + 1;
      end
    end
  end

  assign blk_cnt_o  = blk_cnt_s;
  assign last_blk_o = last_blk_s;

  `FFL(blk_cnt_s, n_blk_cnt_s, en_i, 0, clk_i, rst_n_i)

endmodule
