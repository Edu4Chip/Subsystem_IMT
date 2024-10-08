`timescale 1ns / 1ps
`include "registers.svh"


module ascon_fsm (
    // Clock
    input logic clk_i,

    // Reset
    input logic rst_n_i,

    // FSM
    input  logic start_i,
    input  logic data_valid_i,
    output logic data_req_o,
    output logic ready_o,
    output logic done_o,

    // State register
    output logic load_state_o,

    // AD block counter
    input  logic last_ad_blk_i,
    output logic en_ad_cnt_o,
    output logic load_ad_cnt_o,

    // PT block counter
    input  logic pt_cnt_end_i,
    output logic en_pt_cnt_o,
    output logic load_pt_cnt_o,

    // Round counter
    input  logic n_last_rnd_i,
    output logic en_rnd_cnt_o,
    output logic load_rnd_cnt_o,
    output logic sel_p12_init_o,

    // Permutation round
    output logic sel_state_init_o,
    output logic sel_xor_init_o,
    output logic sel_xor_ext_o,
    output logic sel_xor_dom_sep_o,
    output logic sel_xor_fin_o,
    output logic sel_xor_tag_o,
    output logic ct_valid_o,
    output logic tag_valid_o
);
  typedef enum logic [4:0] {
    idle,
    start,
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

  always_comb begin

    data_req_o = 0;
    ready_o = 0;
    done_o = 0;

    load_state_o = 0;

    en_ad_cnt_o = 0;
    load_ad_cnt_o = 0;
    en_pt_cnt_o = 0;
    load_pt_cnt_o = 0;
    en_rnd_cnt_o = 0;
    load_rnd_cnt_o = 0;
    sel_p12_init_o = 0;

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
        if (start_i) begin
          n_state_s = start;
        end else begin
          n_state_s = idle;
        end
      end
      start: begin
        // initialize the PT block counter
        en_pt_cnt_o = 1;
        load_pt_cnt_o = 1;
        // initialize the AD block counter
        en_ad_cnt_o = 1;
        load_ad_cnt_o = 1;
        // initialize the round counter
        en_rnd_cnt_o = 1;
        load_rnd_cnt_o = 1;
        sel_p12_init_o = 1;
        n_state_s = ini_sta;
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
        if (n_last_rnd_i) begin
          if (last_ad_blk_i) begin
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
        // request a new data block for the next state
        data_req_o = 1;
        if (pt_cnt_end_i) begin
          n_state_s = wait_last_pt;
        end else begin
          n_state_s = wait_pt;
        end
      end
      ini_end: begin
        load_state_o = 1;
        sel_xor_init_o = 1;
        // request a new data block for the next state
        data_req_o = 1;
        n_state_s = wait_ad;
      end
      wait_ad: begin
        // reinitialize the round counter
        en_rnd_cnt_o   = 1;
        load_rnd_cnt_o = 1;
        if (data_valid_i) begin
          n_state_s = ad_sta;
        end else begin
          n_state_s = wait_ad;
        end
      end
      ad_sta: begin
        load_state_o  = 1;
        en_rnd_cnt_o  = 1;
        // consume the input data block
        en_ad_cnt_o   = 1;
        sel_xor_ext_o = 1;
        n_state_s = ad_mid;
      end
      ad_mid: begin
        load_state_o = 1;
        en_rnd_cnt_o = 1;
        if (n_last_rnd_i) begin
          if (last_ad_blk_i) begin
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
        // request a new data block for the next state
        data_req_o   = 1;
        n_state_s = wait_ad;
      end
      end_ad: begin
        load_state_o = 1;
        // add the domain separation constant before processing the plaintext
        sel_xor_dom_sep_o = 1;
        // request a new data block for the next state
        data_req_o = 1;
        if (pt_cnt_end_i) begin
          n_state_s = wait_last_pt;
        end else begin
          n_state_s = wait_pt;
        end
      end
      wait_pt: begin
        // reinitialize the round counter
        en_rnd_cnt_o   = 1;
        load_rnd_cnt_o = 1;
        if (data_valid_i) begin
          n_state_s = pt_sta;
        end else begin
          n_state_s = wait_pt;
        end
      end
      pt_sta: begin
        load_state_o = 1;
        en_rnd_cnt_o = 1;
        // consume the input data block and produce a ciphertext block
        en_pt_cnt_o = 1;
        sel_xor_ext_o = 1;
        ct_valid_o = 1;
        n_state_s = pt_mid;
      end
      pt_mid: begin
        load_state_o = 1;
        en_rnd_cnt_o = 1;
        if (n_last_rnd_i) begin
          n_state_s = pt_end;
        end else begin
          n_state_s = pt_mid;
        end
      end
      pt_end: begin
        load_state_o = 1;
        // request a new data block for the next state
        data_req_o   = 1;
        if (pt_cnt_end_i) begin
          n_state_s = wait_last_pt;
        end else begin
          n_state_s = wait_pt;
        end
      end
      wait_last_pt: begin
        // reinitialize the round counter
        en_rnd_cnt_o   = 1;
        load_rnd_cnt_o = 1;
        sel_p12_init_o = 1;
        if (data_valid_i) begin
          n_state_s = fin_sta;
        end else begin
          n_state_s = wait_last_pt;
        end
      end
      fin_sta: begin
        load_state_o = 1;
        en_rnd_cnt_o = 1;
        // consume the last input data block and produce a ciphertext block
        sel_xor_ext_o = 1;
        sel_xor_fin_o = 1;
        ct_valid_o = 1;
        n_state_s = fin_mid;
      end
      fin_mid: begin
        load_state_o = 1;
        en_rnd_cnt_o = 1;
        if (n_last_rnd_i) begin
          n_state_s = fin_end;
        end else begin
          n_state_s = fin_mid;
        end
      end
      fin_end: begin
        load_state_o  = 1;
        // produce the tag
        sel_xor_tag_o = 1;
        tag_valid_o   = 1;
        n_state_s = done;
      end
      done: begin
        // wait for a new computation
        ready_o = 1;
        done_o  = 1;
        if (start_i) begin
          n_state_s = start;
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
