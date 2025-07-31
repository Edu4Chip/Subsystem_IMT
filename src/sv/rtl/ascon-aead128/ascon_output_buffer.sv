`timescale 1ns / 1ps

module ascon_output_buffer #(
  parameter int unsigned WIDTH
) (
  input  logic             clk,
  input  logic             rst_n,
  input  logic             en_i,
  input  logic [WIDTH-1:0] data_i,
  output logic [WIDTH-1:0] data_o,
  output logic             valid_pulse_o
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      data_o <= WIDTH'(0);
      valid_pulse_o <= 1'b0;
    end else begin
      if (en_i) begin
        data_o <= data_i;
        valid_pulse_o <= 1'b1;
      end else begin
        valid_pulse_o <= 1'b0;
      end
    end
  end

endmodule
