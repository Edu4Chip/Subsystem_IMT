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
    output logic first_round_o,

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
    InitEndNoADFinalize,
    ADWait,
    ADStart,
    ADMid,
    ADEnd,
    ADPaddingStart,
    ADLastWait,
    ADLastStart,
    ADLastMid,
    ADLastEnd,
    ADLastEndFinalize,
    PTWait,
    PTStart,
    FinalPaddingStart,
    PTMid,
    PTEnd,
    PTEndFinalize,
    FinalWait,
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
  logic ad_full_blk_padding_s;
  logic ad_ready_s;

  logic [2:0] pt_idx_s;
  logic [BLOCK_AW-1:0] pt_max_cnt_s;
  logic last_pt_s;
  logic pt_full_blk_padding_s;
  logic pt_ready_s;

  logic last_rnd_next_s;
  logic abort_s;

  assign abort_s = !start_i;

  assign ad_idx_s = ad_size_i[2:0];
  assign ad_max_cnt_s = BLOCK_AW'(ad_size_i[DATA_AW-1:3]);
  assign skip_ad_s = ad_size_i == '0;
  assign last_ad_s = ad_cnt_i == ad_max_cnt_s;
  assign ad_full_blk_padding_s = ad_idx_s == '0;
  assign ad_ready_s = !ad_empty_i;

  assign pt_idx_s = pt_size_i[2:0];
  assign pt_max_cnt_s = BLOCK_AW'(pt_size_i[DATA_AW-1:3]);
  assign pt_idx_o = pt_idx_s;
  assign last_pt_s = pt_cnt_i == pt_max_cnt_s;
  assign pt_full_blk_padding_s = pt_idx_s == '0;
  assign pt_ready_s = !pt_empty_i && !ct_full_i;

  assign last_rnd_next_s = (rnd_i == BeforeLastRnd);

  assign ad_idx_o = ad_idx_s;
  assign ct_idx_o = pt_idx_s;

  always_comb begin
    ready_o = 0;
    first_round_o = 0;
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
        // flush the buffers and wait for the start signal to go high
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
        if (abort_s) begin
          state_d = Idle;
        end else if (timer_i == delay_i) begin
          state_d = InitStart;
        end else begin
          state_d = Delay;
        end
      end
      InitStart: begin
        // initialize the permutation state
        // compute the first round of the initialization
        first_round_o = 1;
        en_state_o = 1;
        en_rnd_cnt_o = 1;
        sel_state_init_o = 1;
        state_d = InitMid;
      end
      InitMid: begin
        // compute the intermediate rounds of the initialization
        en_state_o   = 1;
        en_rnd_cnt_o = 1;
        // depending on input data choose to either:
        // 1) add the domain separation constant and jump to the finalization
        // 2) add the domain separation constant and process the first PT block
        // 3) do not add the domain separation constant and process the first AD block
        if (last_rnd_next_s) begin
          if (skip_ad_s && last_pt_s) begin
            state_d = InitEndNoADFinalize;
          end else if (skip_ad_s) begin
            state_d = InitEndNoAD;
          end else begin
            state_d = InitEnd;
          end
        end else begin
          state_d = InitMid;
        end
      end
      InitEndNoADFinalize: begin
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
        if (pt_full_blk_padding_s) begin
          state_d = FinalPaddingStart;
        end else begin
          if (pt_ready_s) begin
            state_d = FinalStart;
          end else begin
            state_d = FinalWait;
          end
        end
      end
      InitEndNoAD: begin
        // add the key and the domain separation constant
        // compute the last round of the initialization
        // initialize the round counter before processing the first PT block
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
        // initialize the round counter before processing an AD block
        en_state_o = 1;
        load_rnd_cnt_o = 1;
        sel_xor_init_o = 1;
        // do not wait if either:
        // 1) a 64-bit padding block is processed next or
        // 2) an AD block is already available
        if (last_ad_s && ad_full_blk_padding_s) begin
          state_d = ADPaddingStart;
        end else if (last_ad_s) begin
          if (ad_ready_s) begin
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
        if (abort_s) begin
          state_d = Idle;
        end else if (ad_ready_s) begin
          state_d = ADStart;
        end else begin
          state_d = ADWait;
        end
      end
      ADStart: begin
        // pop an AD block
        // compute the first round of the AD block permutation
        first_round_o = 1;
        en_state_o = 1;
        en_rnd_cnt_o = 1;
        sel_ad_o = 1;
        ad_pop_o = 1;
        en_ad_cnt_o = 1;
        sel_xor_ext_o = 1;
        state_d = ADMid;
      end
      ADMid: begin
        // compute an intermediate round of the AD block permutation
        en_state_o   = 1;
        en_rnd_cnt_o = 1;
        if (last_rnd_next_s) begin
          state_d = ADEnd;
        end else begin
          state_d = ADMid;
        end
      end
      ADEnd: begin
        // compute the last round of the AD block permutation
        // initialize the round counter before processing the next AD block
        en_state_o = 1;
        load_rnd_cnt_o = 1;
        // see InitEnd
        if (last_ad_s && ad_full_blk_padding_s) begin
          state_d = ADPaddingStart;
        end else if (last_ad_s) begin
          if (ad_ready_s) begin
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
      ADPaddingStart: begin
        // use a 64-bit block padding as the last AD block
        // compute the first round of the AD block permutation
        first_round_o = 1;
        en_state_o = 1;
        en_rnd_cnt_o = 1;
        sel_ad_o = 1;
        en_ad_cnt_o = 1;
        sel_xor_ext_o = 1;
        en_ad_pad_o = 1;
        state_d = ADLastMid;
      end
      ADLastWait: begin
        // wait for the last AD block
        if (abort_s) begin
          state_d = Idle;
        end else if (ad_ready_s) begin
          state_d = ADLastStart;
        end else begin
          state_d = ADLastWait;
        end
      end
      ADLastStart: begin
        // pop the last AD block and enable the block padding
        // compute the first round of the AD block permutation
        first_round_o = 1;
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
        // compute an intermediate round of the last AD block permutation
        en_state_o   = 1;
        en_rnd_cnt_o = 1;
        if (last_rnd_next_s) begin
          if (last_pt_s) begin
            state_d = ADLastEndFinalize;
          end else begin
            state_d = ADLastEnd;
          end
        end else begin
          state_d = ADLastMid;
        end
      end
      ADLastEnd: begin
        // compute the last round of the last AD block permutation
        // add the domain separation constant
        // initialize the round counter before processing the next PT block
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
      ADLastEndFinalize: begin
        // compute the last round of the last AD block permutation
        // add the domain separation constant
        // initialize the round counter before the finalization
        en_state_o = 1;
        load_rnd_cnt_o = 1;
        init_rnd_o = InitRndP12;
        sel_xor_dom_sep_o = 1;
        // see InitEndNoADFinalize
        if (pt_full_blk_padding_s) begin
          state_d = FinalPaddingStart;
        end else begin
          if (pt_ready_s) begin
            state_d = FinalStart;
          end else begin
            state_d = FinalWait;
          end
        end
      end
      PTWait: begin
        // wait for a PT block
        if (abort_s) begin
          state_d = Idle;
        end else if (pt_ready_s) begin
          state_d = PTStart;
        end else begin
          state_d = PTWait;
        end
      end
      PTStart: begin
        // pop a PT block
        // compute the first round of the PT block permutation
        // push a CT block
        first_round_o = 1;
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
        // compute an intermediate round of the PT block permutation
        en_state_o   = 1;
        en_rnd_cnt_o = 1;
        if (last_rnd_next_s) begin
          if (last_pt_s) begin
            state_d = PTEndFinalize;
          end else begin
            state_d = PTEnd;
          end
        end else begin
          state_d = PTMid;
        end
      end
      PTEnd: begin
        // compute the last round of the PT block permutation
        // initialize the round counter before processing the next PT block
        en_state_o = 1;
        load_rnd_cnt_o = 1;
        if (pt_ready_s) begin
          state_d = PTStart;
        end else begin
          state_d = PTWait;
        end
      end
      PTEndFinalize: begin
        // compute the last round of the before last PT block permutation
        // initialize the round counter before the finalization
        en_state_o = 1;
        load_rnd_cnt_o = 1;
        init_rnd_o = InitRndP12;
        // See InitEndNoADFinalize
        if (pt_full_blk_padding_s) begin
          state_d = FinalPaddingStart;
        end else begin
          if (pt_ready_s) begin
            state_d = FinalStart;
          end else begin
            state_d = FinalWait;
          end
        end
      end
      FinalPaddingStart: begin
        // use a 64-bit block padding as the last PT block
        // compute the first round of the finalization
        // do not produce a CT block (it will be truncated anyway)
        first_round_o = 1;
        en_state_o = 1;
        en_rnd_cnt_o = 1;
        sel_xor_ext_o = 1;
        sel_xor_fin_o = 1;
        en_pt_pad_o = 1;
        state_d = FinalMid;
      end
      FinalWait: begin
        // wait for the last PT block
        if (abort_s) begin
          state_d = Idle;
        end else if (pt_ready_s) begin
          state_d = FinalStart;
        end else begin
          state_d = FinalWait;
        end
      end
      FinalStart: begin
        // pop the last PT block and enable the block padding
        // compute the first round of the finalization
        // push a CT block with the truncated block part set to zero.
        first_round_o = 1;
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
        // compute the intermediate rounds of the finalization
        en_state_o   = 1;
        en_rnd_cnt_o = 1;
        if (last_rnd_next_s) begin
          state_d = FinalEnd;
        end else begin
          state_d = FinalMid;
        end
      end
      FinalEnd: begin
        // compute the last round of the finalization and the tag
        en_state_o = 1;
        sel_xor_tag_o = 1;
        state_d = Done;
      end
      Done: begin
        // wait for the start signal to go low
        // the remaining CT blocks and the tag are valid until then
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

  // FSM state register
  `FF(state_q, state_d, Idle, clk, rst_n)

endmodule
