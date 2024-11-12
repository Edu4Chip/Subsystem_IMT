`timescale 1ns / 1ps
`include "registers.svh"


module ascon_fsm #(
    parameter int unsigned ROUND_WIDTH = 4,
    parameter int unsigned DataAddrWidth = 7,
    parameter int unsigned DelayWidth = 16
) (
    // Clock
    input logic clk_i,

    // Reset
    input logic rst_n_i,

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
    input logic [DataAddrWidth-1:0] ad_size_i,
    input logic [DataAddrWidth-1:0] ad_cnt_i,
    output logic en_ad_cnt_o,
    output logic load_ad_cnt_o,

    // PT block counter
    input logic [DataAddrWidth-1:0] pt_size_i,
    input logic [DataAddrWidth-1:0] pt_cnt_i,
    output logic en_pt_cnt_o,
    output logic load_pt_cnt_o,

    // Round counter
    input logic [ROUND_WIDTH-1:0] rnd_i,
    output logic en_rnd_cnt_o,
    output logic load_rnd_cnt_o,
    output logic [ROUND_WIDTH-1:0] init_rnd_o,

    // Delay counter
    input  logic [DelayWidth-1:0] delay_i,
    input  logic [DelayWidth-1:0] timer_i,
    output logic en_timer_o,
    output logic load_timer_o,

    // Permutation round
    output logic load_state_o,
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
    idle,
    start,
    wait_delay,
    ini_sta,
    ini_mid,
    ini_end,
    ini_end_no_ad,
    wait_ad,
    ad_sta,
    ad_mid,
    end_ad_blk,
    end_ad,
    wait_pt,
    pt_sta,
    pt_mid,
    pt_end,
    wait_last_pt,
    fin_sta,
    fin_mid,
    fin_end,
    done
  } state_t;

  state_t state_s, n_state_s;

  logic last_ad_s;
  logic before_last_pt_s;
  logic before_last_rnd_s;
    logic sel_p12_init_o;

  assign last_ad_s = (ad_cnt_i == ad_size_i);
  assign before_last_pt_s = (pt_cnt_i == pt_size_i);
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
    load_state_o = 0;
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

    case (state_s)
      idle: begin
        ready_o = 1;
        // flush the buffers
        ad_flush_o = 1;
        pt_flush_o = 1;
        ct_flush_o = 1;
        if (start_i) begin
          n_state_s = start;
        end else begin
          n_state_s = idle;
        end
      end
      start: begin
        // initialize the PT block counter
        load_pt_cnt_o = 1;
        // initialize the AD block counter
        load_ad_cnt_o = 1;
        // initialize the round counter
        load_rnd_cnt_o = 1;
        init_rnd_o = InitRndP12;
        // reload the timer
        load_timer_o = 1;
        n_state_s = wait_delay;
      end
      wait_delay: begin
        en_timer_o = 1;
        if (timer_i == delay_i) begin
          n_state_s = ini_sta;
        end else begin
          n_state_s = wait_delay;
        end
      end
      ini_sta: begin
        load_state_o = 1;
        en_rnd_cnt_o = 1;
        // remove the last PT block from the PT block count
        en_pt_cnt_o = 1;
        // initialize the permutation state
        sel_state_init_o = 1;
        n_state_s = ini_mid;
      end
      ini_mid: begin
        load_state_o = 1;
        en_rnd_cnt_o = 1;
        if (before_last_rnd_s) begin
          if (last_ad_s) begin
            n_state_s = ini_end_no_ad;
          end else begin
            n_state_s = ini_end;
          end
        end else begin
          n_state_s = ini_mid;
        end
      end
      ini_end_no_ad: begin
        load_state_o = 1;
        sel_xor_init_o = 1;
        // add the domain separation constant before processing the plaintext
        sel_xor_dom_sep_o = 1;
        if (before_last_pt_s) begin
          n_state_s = wait_last_pt;
        end else begin
          n_state_s = wait_pt;
        end
      end
      ini_end: begin
        load_state_o = 1;
        sel_xor_init_o = 1;
        n_state_s = wait_ad;
      end
      wait_ad: begin
        // reinitialize the round counter
        load_rnd_cnt_o = 1;
        if (!ad_empty_i) begin
          n_state_s = ad_sta;
        end else begin
          n_state_s = wait_ad;
        end
      end
      ad_sta: begin
        load_state_o = 1;
        en_rnd_cnt_o = 1;
        // consume the input data block
        sel_ad_o = 1;
        ad_pop_o = 1;
        en_ad_cnt_o = 1;
        sel_xor_ext_o = 1;
        n_state_s = ad_mid;
      end
      ad_mid: begin
        load_state_o = 1;
        en_rnd_cnt_o = 1;
        if (before_last_rnd_s) begin
          if (last_ad_s) begin
            n_state_s = end_ad;
          end else begin
            n_state_s = end_ad_blk;
          end
        end else begin
          n_state_s = ad_mid;
        end
      end
      end_ad_blk: begin
        load_state_o = 1;
        n_state_s = wait_ad;
      end
      end_ad: begin
        load_state_o = 1;
        // add the domain separation constant before processing the plaintext
        sel_xor_dom_sep_o = 1;
        if (before_last_pt_s) begin
          n_state_s = wait_last_pt;
        end else begin
          n_state_s = wait_pt;
        end
      end
      wait_pt: begin
        // reinitialize the round counter
        load_rnd_cnt_o = 1;
        if (!pt_empty_i && !ct_full_i) begin
          n_state_s = pt_sta;
        end else begin
          n_state_s = wait_pt;
        end
      end
      pt_sta: begin
        load_state_o = 1;
        en_rnd_cnt_o = 1;
        // consume the input data block and produce a ciphertext block
        pt_pop_o = 1;
        ct_push_o = 1;
        en_pt_cnt_o = 1;
        sel_xor_ext_o = 1;
        ct_valid_o = 1;
        n_state_s = pt_mid;
      end
      pt_mid: begin
        load_state_o = 1;
        en_rnd_cnt_o = 1;
        if (before_last_rnd_s) begin
          n_state_s = pt_end;
        end else begin
          n_state_s = pt_mid;
        end
      end
      pt_end: begin
        load_state_o = 1;
        if (before_last_pt_s) begin
          n_state_s = wait_last_pt;
        end else begin
          n_state_s = wait_pt;
        end
      end
      wait_last_pt: begin
        // reinitialize the round counter
        load_rnd_cnt_o = 1;
        init_rnd_o = InitRndP12;
        if (!pt_empty_i && !ct_full_i) begin
          n_state_s = fin_sta;
        end else begin
          n_state_s = wait_last_pt;
        end
      end
      fin_sta: begin
        load_state_o = 1;
        en_rnd_cnt_o = 1;
        // consume the last input data block and produce a ciphertext block
        pt_pop_o = 1;
        ct_push_o = 1;
        sel_xor_ext_o = 1;
        sel_xor_fin_o = 1;
        ct_valid_o = 1;
        n_state_s = fin_mid;
      end
      fin_mid: begin
        load_state_o = 1;
        en_rnd_cnt_o = 1;
        if (before_last_rnd_s) begin
          n_state_s = fin_end;
        end else begin
          n_state_s = fin_mid;
        end
      end
      fin_end: begin
        load_state_o = 1;
        // produce the tag
        sel_xor_tag_o = 1;
        n_state_s = done;
      end
      done: begin
        tag_valid_o = 1;
        if (!start_i) begin
          n_state_s = idle;
        end else begin
          n_state_s = done;
        end
      end
      default: begin
        n_state_s = idle;
      end
    endcase
  end

  `FF(state_s, n_state_s, idle, clk_i, rst_n_i)

endmodule
