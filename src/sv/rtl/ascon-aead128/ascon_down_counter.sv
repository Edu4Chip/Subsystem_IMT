`timescale 1ns / 1ps

module ascon_down_counter #(
  parameter int unsigned WIDTH
) (
  input  logic             clk,
  input  logic             rst_n,
  input  logic             en_i,
  input  logic             load_i,
  input  logic [WIDTH-1:0] count_i,
  output logic [WIDTH-1:0] count_o,
  output logic             zero_o
);
  logic [WIDTH-1:0] count_q, count_d;

  assign zero_o = (count_q == '0);
  assign count_o = count_q;

  always_comb begin
    count_d = count_q;

    if (load_i) begin
      count_d = count_i;
    end else if (!zero_o) begin
      count_d = count_q - 1'b1;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      count_q <= WIDTH'(0);
    end else begin
      if (en_i) begin
        count_q <= count_d;
      end
    end
  end

endmodule
