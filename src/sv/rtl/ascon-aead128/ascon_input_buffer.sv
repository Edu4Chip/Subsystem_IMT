`timescale 1ns / 1ps

module ascon_input_buffer
  import ascon_pack::*;
(
  input  logic                   clk,
  input  logic                   rst_n,
  input  logic                   en_i,
  input  logic [BLOCK_WIDTH-1:0] data_i,
  output logic [BLOCK_WIDTH-1:0] data_o
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      data_o <= BLOCK_WIDTH'(0);
    end else begin
      if (en_i) begin
        data_o <= data_i;
      end
    end
  end

endmodule

