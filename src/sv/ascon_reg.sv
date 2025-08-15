module ascon_reg #(
    parameter int unsigned WIDTH
) (
    input  logic             clk,
    input  logic             rst_n,
    input  logic             en_i,
    input  logic [WIDTH-1:0] data_i,
    output logic [WIDTH-1:0] data_o
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      data_o <= WIDTH'(0);
    end else begin
      if (en_i) begin
        data_o <= data_i;
      end
    end
  end

endmodule

