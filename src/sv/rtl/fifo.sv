module fifo #(
    parameter int unsigned DATA_WIDTH = 64,
    parameter int unsigned DEPTH = 4,
    parameter type data_t = logic [DATA_WIDTH-1:0]
) (
    input logic clk,
    input logic rst_n,
    input logic flush_i,
    input logic push_i,
    input data_t data_i,
    input logic pop_i,
    output data_t data_o,
    output logic full_o,
    output logic empty_o
);
  localparam int unsigned IdxWidth = (DEPTH > 1) ? $clog2(DEPTH) : 1;

  // index to the read and write sections of the queue
  logic [IdxWidth-1:0] rd_idx_q, rd_idx_d;
  logic [IdxWidth-1:0] wr_idx_q, wr_idx_d;

  // keep track of the number of items in the buffer
  logic [IdxWidth:0] status_cnt_q, status_cnt_d;

  // buffer registers
  data_t [DEPTH-1:0] buf_d, buf_q;

  // status
  assign full_o  = (status_cnt_q == DEPTH[IdxWidth:0]);
  assign empty_o = (status_cnt_q == 0);

  // read and write logic
  always_comb begin : comb_fifo
    rd_idx_d     = rd_idx_q;
    wr_idx_d     = wr_idx_q;
    status_cnt_d = status_cnt_q;
    buf_d        = buf_q;
    data_o       = empty_o ? '0 : buf_q[rd_idx_q];

    // push a new element to the queue and increment the write index
    // as long as the queue is not full we can push new data
    if (push_i && !full_o) begin
      buf_d[wr_idx_q] = data_i;
      if (wr_idx_q == DEPTH[IdxWidth-1:0] - 1) begin
        wr_idx_d = '0;
      end else begin
        wr_idx_d = wr_idx_q + 1'b1;
      end
      status_cnt_d = status_cnt_q + 1'b1;
    end

    // read from the queue and increment the read index
    // as long as the queue is not empty we can pop new elements
    if (pop_i && !empty_o) begin
      if (rd_idx_d == DEPTH[IdxWidth-1:0] - 1) begin
        rd_idx_d = '0;
      end else begin
        rd_idx_d = rd_idx_q + 1'b1;
      end
      status_cnt_d = status_cnt_q - 1'b1;
    end

    // the number of items in the buffer is stable if we push and pop at the same time
    if ((push_i && !full_o) && (pop_i && !empty_o)) begin
      status_cnt_d = status_cnt_q;
    end

  end

  `FFARNC(rd_idx_q, rd_idx_d, flush_i, '0, clk, rst_n)
  `FFARNC(wr_idx_q, wr_idx_d, flush_i, '0, clk, rst_n)
  `FFARNC(status_cnt_q, status_cnt_d, flush_i, '0, clk, rst_n)
  `FF(buf_q, buf_d, '0, clk, rst_n)

endmodule
