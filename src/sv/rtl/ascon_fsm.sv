`timescale 1ns / 1ps
`include "registers.svh"


module ascon_fsm
  import ascon_pack::*;
#(
    parameter int unsigned BLOCK_AW = 7,
    parameter int unsigned DELAY_WIDTH = 16
) (
    // Clock
    input logic clk,

    // Reset
    input logic rst_n,

    // FSM
    input  logic start_i,
    output logic ready_o,
    output logic sel_ad_o,

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
    input logic [BLOCK_AW-1:0] ad_blk_no_i,
    input logic [BLOCK_AW-1:0] ad_cnt_i,
    output logic en_ad_cnt_o,
    output logic load_ad_cnt_o,

    // PT block counter
    input logic [BLOCK_AW:0] pt_blk_no_i,
    input logic [BLOCK_AW:0] pt_cnt_i,
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

    // Permutation round
    output logic en_state_o,
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

  typedef enum logic [4:0] {
    Idle,
    Start,
    Delay,
    InitStart,
    InitMid,
    InitEndWithAD,
    InitEndNoAD,
    ADPrepare,
    ADStart,
    ADMid,
    ADEndBlk,
    ADEnd,
    PTPrepare,
    PTStart,
    PTMid,
    PTEnd,
    FinalPrepare,
    FinalStart,
    FinalMid,
    FinalEnd,
    Done
  } state_e;

  state_e state_q, state_d;

  logic last_ad_s;
  logic before_last_pt_s;
  logic before_last_rnd_s;

  assign last_ad_s = (ad_cnt_i == ad_blk_no_i);
  assign before_last_pt_s = (pt_cnt_i == pt_blk_no_i);
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
        ready_o = 1;
        // flush the buffers
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
        // initialize the round counter
        load_rnd_cnt_o = 1;
        init_rnd_o = InitRndP12;
        // reload the timer
        load_timer_o = 1;
        state_d = Delay;
      end
      Delay: begin
        en_timer_o = 1;
        if (timer_i == delay_i) begin
          state_d = InitStart;
        end else begin
          state_d = Delay;
        end
      end
      InitStart: begin
        en_state_o = 1;
        en_rnd_cnt_o = 1;
        // remove the last PT block from the PT block count
        en_pt_cnt_o = 1;
        // initialize the permutation state
        sel_state_init_o = 1;
        state_d = InitMid;
      end
      InitMid: begin
        en_state_o   = 1;
        en_rnd_cnt_o = 1;
        if (before_last_rnd_s) begin
          if (last_ad_s) begin
            state_d = InitEndNoAD;
          end else begin
            state_d = InitEndWithAD;
          end
        end else begin
          state_d = InitMid;
        end
      end
      InitEndNoAD: begin
        en_state_o = 1;
        sel_xor_init_o = 1;
        // add the domain separation constant before processing the plaintext
        sel_xor_dom_sep_o = 1;
        if (before_last_pt_s) begin
          state_d = FinalPrepare;
        end else begin
          state_d = PTPrepare;
        end
      end
      InitEndWithAD: begin
        en_state_o = 1;
        sel_xor_init_o = 1;
        state_d = ADPrepare;
      end
      ADPrepare: begin
        // reinitialize the round counter
        load_rnd_cnt_o = 1;
        if (!ad_empty_i) begin
          state_d = ADStart;
        end else begin
          state_d = ADPrepare;
        end
      end
      ADStart: begin
        en_state_o = 1;
        en_rnd_cnt_o = 1;
        // consume the input data block
        sel_ad_o = 1;
        ad_pop_o = 1;
        en_ad_cnt_o = 1;
        sel_xor_ext_o = 1;
        state_d = ADMid;
      end
      ADMid: begin
        en_state_o   = 1;
        en_rnd_cnt_o = 1;
        if (before_last_rnd_s) begin
          if (last_ad_s) begin
            state_d = ADEnd;
          end else begin
            state_d = ADEndBlk;
          end
        end else begin
          state_d = ADMid;
        end
      end
      ADEndBlk: begin
        en_state_o = 1;
        state_d = ADPrepare;
      end
      ADEnd: begin
        en_state_o = 1;
        // add the domain separation constant before processing the plaintext
        sel_xor_dom_sep_o = 1;
        if (before_last_pt_s) begin
          state_d = FinalPrepare;
        end else begin
          state_d = PTPrepare;
        end
      end
      PTPrepare: begin
        // reinitialize the round counter
        load_rnd_cnt_o = 1;
        if (!pt_empty_i && !ct_full_i) begin
          state_d = PTStart;
        end else begin
          state_d = PTPrepare;
        end
      end
      PTStart: begin
        en_state_o = 1;
        en_rnd_cnt_o = 1;
        // consume the input data block and produce a ciphertext block
        pt_pop_o = 1;
        ct_push_o = 1;
        en_pt_cnt_o = 1;
        sel_xor_ext_o = 1;
        ct_valid_o = 1;
        state_d = PTMid;
      end
      PTMid: begin
        en_state_o   = 1;
        en_rnd_cnt_o = 1;
        if (before_last_rnd_s) begin
          state_d = PTEnd;
        end else begin
          state_d = PTMid;
        end
      end
      PTEnd: begin
        en_state_o = 1;
        if (before_last_pt_s) begin
          state_d = FinalPrepare;
        end else begin
          state_d = PTPrepare;
        end
      end
      FinalPrepare: begin
        // reinitialize the round counter
        load_rnd_cnt_o = 1;
        init_rnd_o = InitRndP12;
        if (!pt_empty_i && !ct_full_i) begin
          state_d = FinalStart;
        end else begin
          state_d = FinalPrepare;
        end
      end
      FinalStart: begin
        en_state_o = 1;
        en_rnd_cnt_o = 1;
        // consume the last input data block and produce a ciphertext block
        pt_pop_o = 1;
        ct_push_o = 1;
        sel_xor_ext_o = 1;
        sel_xor_fin_o = 1;
        ct_valid_o = 1;
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
