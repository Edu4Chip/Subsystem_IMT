`timescale 1ns / 1ps

module ascon_wrapper #(
    parameter int BUF_DEPTH = 4,
    parameter int BLK_AD_AW = 3,
    parameter int BLK_PT_AW = 3
) (
    input logic clk_i,
    input logic rst_n_i,
    input logic [BUF_DEPTH-1:0][63:0] data_i,
    input logic [127:0] key_i,
    input logic [127:0] nonce_i,
    input logic [BLK_AD_AW-1:0] ad_size_i,
    input logic [BLK_PT_AW-1:0] pt_size_i,
    input logic start_i,
    input logic data_valid_i,
    input logic ct_read_ack_i,
    output logic data_req_o,
    output logic ct_ready_o,
    output logic ready_o,
    output logic done_o,
    output logic [BUF_DEPTH-1:0][63:0] ct_o,
    output logic [127:0] tag_o
);
  parameter int IDX_WIDTH = BUF_DEPTH > 1 ? $clog2(BUF_DEPTH) : 1;
  localparam logic [IDX_WIDTH-1:0] LastIdx = BUF_DEPTH[IDX_WIDTH-1:0] - 1;

  typedef enum logic [3:0] {
    idle,
    start,
    wait_req_after_start,
    wait_req,
    wait_buf_valid,
    pop,
    valid_data,
    check,
    push,
    wait_req_then_ack,
    wait_ack
  } state_t;

  logic rst_buf_sync_s;

  logic [IDX_WIDTH-1:0] rd_idx_s, n_rd_idx_s;
  logic en_rd_idx_s;
  logic rd_overflow_s;
  logic pop_s;
  logic [63:0] data_s;

  logic [IDX_WIDTH-1:0] wr_idx_s, n_wr_idx_s;
  logic en_wr_idx_s;
  logic wr_overflow_s;
  logic push_s;
  logic [BUF_DEPTH-1:0][63:0] buf_s, n_buf_s;
  logic [BUF_DEPTH-1:0] en_buf_s;

  logic [63:0] ct_s, n_ct_s;
  logic [127:0] tag_s, n_tag_s;
  logic load_tag_s;

  state_t state_s, n_state_s;

  logic ready_s;
  logic done_s;
  logic data_valid_s;
  logic req_data_s;
  logic ct_valid_s;

  assign rd_overflow_s = rd_idx_s == LastIdx;

  always_comb begin
    data_s = data_i[rd_idx_s];
    n_rd_idx_s = rd_idx_s;
    en_rd_idx_s = 0;
    if (rst_buf_sync_s) begin
      n_rd_idx_s  = LastIdx;
      en_rd_idx_s = 1;
    end else if (pop_s) begin
      en_rd_idx_s = 1;
      if (rd_overflow_s) begin
        n_rd_idx_s = 0;
      end else begin
        n_rd_idx_s = rd_idx_s + 1;
      end
    end
  end

  assign wr_overflow_s = wr_idx_s == LastIdx;

  always_comb begin
    n_buf_s = buf_s;
    n_wr_idx_s = wr_idx_s;
    en_buf_s = 0;
    en_wr_idx_s = 0;
    if (rst_buf_sync_s) begin
      n_buf_s = 0;
      n_wr_idx_s = 0;
      en_buf_s = {BUF_DEPTH{1'b1}};
      en_wr_idx_s = 1;
    end else if (push_s) begin
      n_buf_s[wr_idx_s] = ct_s;
      en_wr_idx_s = 1;
      if (wr_idx_s == 0) begin
        n_wr_idx_s = wr_idx_s + 1;
        en_buf_s   = {BUF_DEPTH{1'b1}};
      end else begin
        en_buf_s[wr_idx_s] = 1;
        if (wr_overflow_s) begin
          n_wr_idx_s = 0;
        end else begin
          n_wr_idx_s = wr_idx_s + 1;
        end
      end
    end
  end

  assign ct_o = buf_s;

  always_comb begin
    n_state_s = idle;
    rst_buf_sync_s = 0;
    pop_s = 0;
    push_s = 0;
    data_valid_s = 0;
    data_req_o = 0;
    ct_ready_o = 0;

    case (state_s)
      idle: begin
        if (start_i) begin
          n_state_s = start;
        end else begin
          n_state_s = idle;
        end
      end
      start: begin
        rst_buf_sync_s = 1;
        n_state_s = wait_req_after_start;
      end
      wait_req_after_start: begin
        // Ascon128 AEAD requires at least one block of plaintext.
        // Thus, we assume that the input buffer has been filled before the start of the encryption.
        if (req_data_s) begin
          n_state_s = pop;
        end else begin
          n_state_s = wait_req_after_start;
        end
      end
      wait_req: begin
        // wait for a request from the Ascon module
        if (done_s) begin
          n_state_s = idle;
        end else if (req_data_s) begin
          if (!rd_overflow_s) begin
            n_state_s = pop;
          end else begin
            n_state_s = wait_buf_valid;
          end
        end else begin
          n_state_s = wait_req;
        end
      end
      wait_buf_valid: begin
        // wait for the input buffer to be refilled
        data_req_o = 1;
        if (data_valid_i) begin
          n_state_s = pop;
        end else begin
          n_state_s = wait_buf_valid;
        end
      end
      pop: begin
        // pop a new data block from the input buffer
        pop_s = 1;
        n_state_s = valid_data;
      end
      valid_data: begin
        // feed the data block to the Ascon module
        data_valid_s = 1;
        n_state_s = check;
      end
      check: begin
        // check if a ciphertext was produced
        if (ct_valid_s) begin
          n_state_s = push;
        end else begin
          n_state_s = wait_req;
        end
      end
      push: begin
        // push a ciphertext block in the output buffer
        push_s = 1;
        if (wr_overflow_s) begin
          // Pushing the current element fills the buffer.
          // Thus, the buffer needs to be read in the next state.
          n_state_s = wait_req_then_ack;
        end else begin
          n_state_s = wait_req;
        end
      end
      wait_req_then_ack: begin
        // wait until the Ascon module emit a request and wait for an answer
        // before signaling that the output buffer is full.
        if (done_s) begin
          n_state_s = idle;
        end else if (req_data_s) begin
          n_state_s = wait_ack;
        end else begin
          n_state_s = wait_req_then_ack;
        end
      end
      wait_ack: begin
        // signal that the output buffer is full and resume the completion of the request
        // when an read acknowledgment is received.
        ct_ready_o = 1;
        if (ct_read_ack_i) begin
          if (rd_overflow_s) begin
            n_state_s = wait_buf_valid;
          end else begin
            n_state_s = pop;
          end
        end else begin
          n_state_s = wait_ack;
        end
      end
      default: begin
      end
    endcase
  end

  `FFL(rd_idx_s, n_rd_idx_s, en_rd_idx_s, 0, clk_i, rst_n_i)
  `FFL(wr_idx_s, n_wr_idx_s, en_wr_idx_s, 0, clk_i, rst_n_i)

  for (genvar i = 0; i < BUF_DEPTH; i++) begin : gen_buf
    `FFL(buf_s[i], n_buf_s[i], en_buf_s[i], 0, clk_i, rst_n_i)
  end

  `FF(state_s, n_state_s, idle, clk_i, rst_n_i)
  `FF(ct_s, n_ct_s, 0, clk_i, rst_n_i)
  `FFL(tag_s, n_tag_s, load_tag_s, 0, clk_i, rst_n_i)

  assign tag_o = tag_s;

  ascon_top #(
      .BLK_AD_AW(BLK_AD_AW),
      .BLK_PT_AW(BLK_PT_AW)
  ) u_ascon_top (
      .clk_i       (clk_i),
      .rst_n_i     (rst_n_i),
      .data_i      (data_s),
      .key_i       (key_i),
      .nonce_i     (nonce_i),
      .ad_size_i   (ad_size_i),
      .pt_size_i   (pt_size_i),
      .start_i     (start_i),
      .data_valid_i(data_valid_s),
      .data_req_o  (req_data_s),
      .ready_o     (ready_s),
      .done_o      (done_s),
      .ct_valid_o  (ct_valid_s),
      .ct_o        (n_ct_s),
      .tag_valid_o (load_tag_s),
      .tag_o       (n_tag_s)
  );

  assign ready_o = ready_s;
  assign done_o  = done_s;

endmodule
