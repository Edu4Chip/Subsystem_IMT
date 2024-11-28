`timescale 1ns / 1ps
`include "registers.svh"


module ascon_fsm
  import ascon_pack::*;
#(
    parameter int unsigned DATA_AW = 7,
    parameter int unsigned BLOCK_AW = 4,
    parameter int unsigned DELAY_WIDTH = 16
) (
    // Clock
    input logic clk,

    // Reset
    input logic rst_n,

    // Control
    input logic [DATA_AW-1:0] ad_size_i,
    input logic [DATA_AW-1:0] pt_size_i,

    // Status
    input  logic start_i,
    output logic ready_o,

    // AD FIFO
    input  logic ad_empty_i,
    output logic ad_pop_o,
    output logic ad_flush_o,

    // PT FIFO
    input  logic pt_empty_i,
    output logic pt_pop_o,
    output logic pt_flush_o,

    // CT FIFO
    input  logic ct_full_i,
    output logic ct_push_o,
    output logic ct_flush_o,

    // AD block counter
    input logic [BLOCK_AW-1:0] ad_cnt_i,
    output logic en_ad_cnt_o,
    output logic load_ad_cnt_o,

    // PT block counter
    input logic [BLOCK_AW-1:0] pt_cnt_i,
    output logic en_pt_cnt_o,
    output logic load_pt_cnt_o,

    // Round counter
    input logic [ROUND_WIDTH-1:0] rnd_i,
    output logic en_rnd_cnt_o,
    output logic load_rnd_cnt_o,
    output logic [ROUND_WIDTH-1:0] init_rnd_o,

    // Delay counter
    input logic [DELAY_WIDTH-1:0] delay_i,
    input logic [DELAY_WIDTH-1:0] timer_i,
    output logic en_timer_o,
    output logic load_timer_o,

    // AD padding
    output logic en_ad_pad_o,
    output logic [2:0] ad_idx_o,

    // PT padding
    output logic en_pt_pad_o,
    output logic [2:0] pt_idx_o,

    // CT truncation
    output logic en_ct_trunc_o,
    output logic [2:0] ct_idx_o,

    // Permutation round
    output logic en_state_o,
    output logic sel_ad_o,
    output logic sel_state_init_o,
    output logic sel_xor_init_o,
    output logic sel_xor_ext_o,
    output logic sel_xor_dom_sep_o,
    output logic sel_xor_fin_o,
    output logic sel_xor_tag_o,
    output logic ct_valid_o,
    output logic tag_valid_o
);
  localparam logic [ROUND_WIDTH-1:0] InitRndP12 = 0;
  localparam logic [ROUND_WIDTH-1:0] InitRndP6 = 6;
  localparam logic [ROUND_WIDTH-1:0] BeforeLastRnd = 10;
  localparam logic [ROUND_WIDTH-1:0] LastRnd = 11;

  typedef enum logic [4:0] {
    Idle,
    Start,
    Delay,
    InitStart,
    InitMid,
    InitEnd,
    InitEndNoAD,
    InitEndNoADLastPT,
    ADWait,
    ADStart,
    ADMid,
    ADEnd,
    ADLastWait,
    ADLastStart,
    ADLastMid,
    ADLastEnd,
    ADLastEndLastPT,
    PTWait,
    PTStart,
    PTMid,
    PTEnd,
    PTLastEnd,
    FinalPrepare,
    FinalStart,
    FinalMid,
    FinalEnd,
    Done
  } state_e;

  state_e state_q, state_d;

  logic [2:0] ad_idx_s;
  logic [BLOCK_AW-1:0] ad_max_cnt_s;
  logic skip_ad_s;
  logic last_ad_s;
  logic ad_ready_s;
  logic last_ad_ready_s;

  logic [2:0] pt_idx_s;
  logic [BLOCK_AW-1:0] pt_max_cnt_s;
  logic before_last_pt_s;
  logic pt_ready_s;
  logic before_last_pt_ready_s;

  logic before_last_rnd_s;

  assign ad_idx_s = ad_size_i[2:0];
  assign ad_max_cnt_s = BLOCK_AW'(ad_size_i[DATA_AW-1:3]);
  assign skip_ad_s = ad_size_i == '0;
  assign last_ad_s = ad_cnt_i == ad_max_cnt_s;
  assign ad_ready_s = !ad_empty_i;
  assign last_ad_ready_s = ad_ready_s || (ad_idx_s == '0);
  assign ad_idx_o = ad_idx_s;

  assign pt_idx_s = pt_size_i[2:0];
  assign pt_max_cnt_s = BLOCK_AW'(pt_size_i[DATA_AW-1:3]);
  assign pt_idx_o = pt_idx_s;
  assign before_last_pt_s = pt_cnt_i == pt_max_cnt_s;
  assign pt_ready_s = !pt_empty_i && !ct_full_i;
  assign before_last_pt_ready_s = pt_ready_s || (pt_idx_s == '0);
  assign ct_idx_o = pt_idx_s;

  assign before_last_rnd_s = (rnd_i == BeforeLastRnd);

  always_comb begin
    ready_o = 0;
    sel_ad_o = 0;
    ad_pop_o = 0;
    ad_flush_o = 0;
    pt_pop_o = 0;
    pt_flush_o = 0;
    ct_push_o = 0;
    ct_flush_o = 0;
    en_state_o = 0;
    en_ad_cnt_o = 0;
    load_ad_cnt_o = 0;
    en_pt_cnt_o = 0;
    load_pt_cnt_o = 0;
    init_rnd_o = InitRndP6;
    en_rnd_cnt_o = 0;
    load_rnd_cnt_o = 0;
    en_timer_o = 0;
    load_timer_o = 0;
    en_ad_pad_o = 0;
    en_pt_pad_o = 0;
    en_ct_trunc_o = 0;
    sel_state_init_o = 0;
    sel_xor_init_o = 0;
    sel_xor_ext_o = 0;
    sel_xor_dom_sep_o = 0;
    sel_xor_fin_o = 0;
    sel_xor_tag_o = 0;
    ct_valid_o = 0;
    tag_valid_o = 0;

    case (state_q)
      Idle: begin
        // flush the buffers and wait for the start signal
        ready_o = 1;
        ad_flush_o = 1;
        pt_flush_o = 1;
        ct_flush_o = 1;
        if (start_i) begin
          state_d = Start;
        end else begin
          state_d = Idle;
        end
      end
      Start: begin
        // initialize the PT block counter
        load_pt_cnt_o = 1;
        // initialize the AD block counter
        load_ad_cnt_o = 1;
        // initialize the round counter before the initilization
        load_rnd_cnt_o = 1;
        init_rnd_o = InitRndP12;
        // initialize the timer
        load_timer_o = 1;
        state_d = Delay;
      end
      Delay: begin
        // wait for a fixed amount of time
        en_timer_o = 1;
        if (timer_i == delay_i) begin
          state_d = InitStart;
        end else begin
          state_d = Delay;
        end
      end
      InitStart: begin
        // initialize the permutation state
        // compute the first round of the initialization
        en_state_o = 1;
        en_rnd_cnt_o = 1;
        sel_state_init_o = 1;
        state_d = InitMid;
      end
      InitMid: begin
        // compute the intermediate rounds of the initialization
        en_state_o   = 1;
        en_rnd_cnt_o = 1;
        if (before_last_rnd_s) begin
          if (skip_ad_s && before_last_pt_s) begin
            state_d = InitEndNoADLastPT;
          end else if (skip_ad_s) begin
            state_d = InitEndNoAD;
          end else begin
            state_d = InitEnd;
          end
        end else begin
          state_d = InitMid;
        end
      end
      InitEndNoADLastPT: begin
        // add the key and the domain separation constant
        // compute the last round of the initialization
        // initialize the round counter before the finalization
        en_state_o = 1;
        load_rnd_cnt_o = 1;
        init_rnd_o = InitRndP12;
        sel_xor_init_o = 1;
        sel_xor_dom_sep_o = 1;
        // do not wait if either:
        // 1) a 64-bit padding block is processed next or
        // 2) a PT block is already available and a CT block can be pushed in the output FIFO
        if (before_last_pt_ready_s) begin
          state_d = FinalStart;
        end else begin
          state_d = FinalPrepare;
        end
      end
      InitEndNoAD: begin
        // add the key and the domain separation constant
        // compute the last round of the initialization
        // initialize the round counter before processing the first block of plaintext
        en_state_o = 1;
        load_rnd_cnt_o = 1;
        sel_xor_init_o = 1;
        sel_xor_dom_sep_o = 1;
        // do not wait if a PT block is already available and a CT block can be pushed in the output FIFO
        if (pt_ready_s) begin
          state_d = PTStart;
        end else begin
          state_d = PTWait;
        end
      end
      InitEnd: begin
        // add the key
        // compute the last round of the initialization
        // initialize the round counter before processing a block of associated data
        en_state_o = 1;
        load_rnd_cnt_o = 1;
        sel_xor_init_o = 1;
        // do not wait if either:
        // 1) a 64-bit padding block is processed next or
        // 2) an AD block is already available
        if (last_ad_s) begin
          if (last_ad_ready_s) begin
            state_d = ADLastStart;
          end else begin
            state_d = ADLastWait;
          end
        end else begin
          if (ad_ready_s) begin
            state_d = ADStart;
          end else begin
            state_d = ADWait;
          end
        end
      end
      ADWait: begin
        // wait for an AD block
        if (ad_ready_s) begin
          state_d = ADStart;
        end else begin
          state_d = ADWait;
        end
      end
      ADStart: begin
        // pop an AD block
        // compute the first round of the block permutation
        en_state_o = 1;
        en_rnd_cnt_o = 1;
        sel_ad_o = 1;
        ad_pop_o = 1;
        en_ad_cnt_o = 1;
        sel_xor_ext_o = 1;
        state_d = ADMid;
      end
      ADMid: begin
        // compute an intermediate round of the block permutation
        en_state_o   = 1;
        en_rnd_cnt_o = 1;
        if (before_last_rnd_s) begin
          state_d = ADEnd;
        end else begin
          state_d = ADMid;
        end
      end
      ADEnd: begin
        // compute the last round of the block permutation
        // initialize the round counter before processing the next block of associated data
        en_state_o = 1;
        load_rnd_cnt_o = 1;
        // do not wait if either:
        // 1) a 64-bit padding block is processed next or
        // 2) an AD block is already available
        if (last_ad_s) begin
          if (last_ad_ready_s) begin
            state_d = ADLastStart;
          end else begin
            state_d = ADLastWait;
          end
        end else begin
          if (ad_ready_s) begin
            state_d = ADStart;
          end else begin
            state_d = ADWait;
          end
        end
      end
      ADLastWait: begin
        // wait for the last AD block
        if (last_ad_ready_s) begin
          state_d = ADLastStart;
        end else begin
          state_d = ADLastWait;
        end
      end
      ADLastStart: begin
        // pop the last AD block (if any) and set the padding
        // compute the first round of the block permutation
        en_state_o = 1;
        en_rnd_cnt_o = 1;
        sel_ad_o = 1;
        ad_pop_o = 1;
        en_ad_cnt_o = 1;
        sel_xor_ext_o = 1;
        en_ad_pad_o = 1;
        state_d = ADLastMid;
      end
      ADLastMid: begin
        // compute an intermediate round of the block permutation
        en_state_o   = 1;
        en_rnd_cnt_o = 1;
        if (before_last_rnd_s) begin
          if (before_last_pt_s) begin
            state_d = ADLastEndLastPT;
          end else begin
            state_d = ADLastEnd;
          end
        end else begin
          state_d = ADLastMid;
        end
      end
      ADLastEnd: begin
        // compute the last round of the block permutation
        // add the domain separation constant
        // initialize the round counter before processing the next block of plaintext
        en_state_o = 1;
        load_rnd_cnt_o = 1;
        sel_xor_dom_sep_o = 1;
        // do not wait if a PT block is already available and a CT block can be pushed in the output FIFO
        if (pt_ready_s) begin
          state_d = PTStart;
        end else begin
          state_d = PTWait;
        end
      end
      ADLastEndLastPT: begin
        // compute the last round of the block permutation
        // add the domain separation constant
        // initialize the round counter before the finalization
        en_state_o = 1;
        load_rnd_cnt_o = 1;
        init_rnd_o = InitRndP12;
        sel_xor_dom_sep_o = 1;
        // do not wait if either:
        // 1) a 64-bit padding block is processed next or
        // 2) a PT block is already available and a CT block can be pushed in the output FIFO
        if (before_last_pt_ready_s) begin
          state_d = FinalStart;
        end else begin
          state_d = FinalPrepare;
        end
      end
      PTWait: begin
        // wait for a PT block
        if (pt_ready_s) begin
          state_d = PTStart;
        end else begin
          state_d = PTWait;
        end
      end
      PTStart: begin
        // pop a PT block
        // compute the first round of the block permutation
        // push a CT block
        en_state_o = 1;
        en_rnd_cnt_o = 1;
        pt_pop_o = 1;
        ct_push_o = 1;
        en_pt_cnt_o = 1;
        sel_xor_ext_o = 1;
        ct_valid_o = 1;
        state_d = PTMid;
      end
      PTMid: begin
        // compute an intermediate round of the block permutation
        en_state_o   = 1;
        en_rnd_cnt_o = 1;
        if (before_last_rnd_s) begin
          if (before_last_pt_s) begin
            state_d = PTLastEnd;
          end else begin
            state_d = PTEnd;
          end
        end else begin
          state_d = PTMid;
        end
      end
      PTEnd: begin
        // compute the last round of the block permutation
        // initialize the round counter before processing the next block of plaintext
        en_state_o = 1;
        load_rnd_cnt_o = 1;
        if (pt_ready_s) begin
          state_d = PTStart;
        end else begin
          state_d = PTWait;
        end
      end
      PTLastEnd: begin
        // compute the last round of the block permutation
        // initialize the round counter before the finalization
        en_state_o = 1;
        load_rnd_cnt_o = 1;
        init_rnd_o = InitRndP12;
        // do not wait if either:
        // 1) a 64-bit padding block is processed next or
        // 2) a PT block is already available and a CT block can be pushed in the output FIFO
        if (before_last_pt_ready_s) begin
          state_d = FinalStart;
        end else begin
          state_d = FinalPrepare;
        end
      end
      FinalPrepare: begin
        if (before_last_pt_ready_s) begin
          state_d = FinalStart;
        end else begin
          state_d = FinalPrepare;
        end
      end
      FinalStart: begin
        // consume the last PT block and produce a CT block
        en_state_o = 1;
        en_rnd_cnt_o = 1;
        pt_pop_o = 1;
        ct_push_o = 1;
        sel_xor_ext_o = 1;
        sel_xor_fin_o = 1;
        ct_valid_o = 1;
        en_pt_pad_o = 1;
        en_ct_trunc_o = 1;
        state_d = FinalMid;
      end
      FinalMid: begin
        en_state_o   = 1;
        en_rnd_cnt_o = 1;
        if (before_last_rnd_s) begin
          state_d = FinalEnd;
        end else begin
          state_d = FinalMid;
        end
      end
      FinalEnd: begin
        en_state_o = 1;
        // produce the tag
        sel_xor_tag_o = 1;
        state_d = Done;
      end
      Done: begin
        tag_valid_o = 1;
        if (!start_i) begin
          state_d = Idle;
        end else begin
          state_d = Done;
        end
      end
      default: begin
        state_d = Idle;
      end
    endcase
  end

  `FF(state_q, state_d, Idle, clk, rst_n)

endmodule
