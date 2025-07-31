`timescale 1ns / 1ps

module ascon_ctrl
  import ascon_pack::*;
#(
  parameter int unsigned SIZE_WIDTH,
  parameter int unsigned BLOCK_AW
) (

  input logic clk,
  input logic rst_n,

  input logic start_i,

  input logic [SIZE_WIDTH-1:0] ad_size_i,
  input logic [SIZE_WIDTH-1:0] di_size_i,
  input logic [  BLOCK_AW-1:0] ad_pad_idx_i,
  input logic [  BLOCK_AW-1:0] di_pad_idx_i,
  input logic [  BLOCK_AW-1:0] ad_blk_no_i,
  input logic [  BLOCK_AW-1:0] di_blk_no_i,

  input logic data_valid_i,
  input logic ad_last_i,
  input logic di_last_i,
  input logic rnd_last_i,
  input logic timeout_i,

  output logic idle_o,
  output logic sync_o,
  output logic done_o,

  output logic      en_state_o,
  output ascon_op_e op_o,
  output logic      sel_ad_o,
  output logic      en_padding_o,
  output logic      en_trunc_o,
  output logic      en_buf_in_o,
  output logic      data_ready_o,
  output logic      en_buf_out_o,
  output logic      en_tag_o,
  output logic      en_ad_cnt_o,
  output logic      load_ad_cnt_o,
  output logic      en_di_cnt_o,
  output logic      load_di_cnt_o,
  output logic      en_rnd_o,
  output logic      load_rnd_a_o,
  output logic      load_rnd_b_o,
  output logic      en_timer_o,
  output logic      load_timer_o

);

  typedef enum logic [4:0] {
    Idle,
    Start,
    Delay,
    InitStart,
    InitMid,
    InitEnd,
    InitEndSep,
    ADWait,
    ADStart,
    ADMid,
    ADEnd,
    ADLastWait,
    ADLastNoWait,
    ADLastStart,
    ADLastMid,
    ADLastEnd,
    DIWait,
    DIStart,
    DIMid,
    DIEnd,
    FinalWait,
    FinalNoWait,
    FinalStart,
    FinalStartEmpty,
    FinalMid,
    FinalEnd,
    Done
  } phase_e;

  phase_e phase_q, phase_d;

  logic ad_empty_s, di_empty_s;
  logic ad_single_block_s, di_single_block_s;
  logic ad_empty_last_block_s, di_empty_last_block_s;

  assign ad_empty_s = ad_size_i == '0;
  assign ad_single_block_s = ad_blk_no_i == '0;
  assign ad_empty_last_block_s = ad_pad_idx_i == '0;

  assign di_empty_s = di_size_i == '0;
  assign di_single_block_s = di_blk_no_i == '0;
  assign di_empty_last_block_s = di_pad_idx_i == '0;

  always_comb begin : fsm_state_logic

    case (phase_q)

      Idle: begin
        if (!start_i) begin
          phase_d = Idle;
        end else begin
          phase_d = Start;
        end
      end

      Start: begin
        phase_d = Delay;
      end

      Delay: begin
        if (!start_i) begin
          phase_d = Idle;
        end else begin
          if (!timeout_i) begin
            phase_d = Delay;
          end else begin
            phase_d = InitStart;
          end
        end
      end

      InitStart: begin
        phase_d = InitMid;
      end

      InitMid: begin
        if (!rnd_last_i) begin
          phase_d = InitMid;
        end else begin
          if (!ad_empty_s) begin
            phase_d = InitEnd;
          end else begin
            phase_d = InitEndSep;
          end
        end
      end

      InitEnd: begin
        if (!ad_single_block_s) begin
          phase_d = ADWait;
        end else begin
          phase_d = ADLastWait;
        end
      end

      InitEndSep: begin
        if (!di_single_block_s) begin
          phase_d = DIWait;
        end else if (!di_empty_last_block_s) begin
          phase_d = FinalWait;
        end else begin
          phase_d = FinalNoWait;
        end
      end

      ADWait: begin
        if (!start_i) begin
          phase_d = Idle;
        end else begin
          if (!data_valid_i) begin
            phase_d = ADWait;
          end else begin
            phase_d = ADStart;
          end
        end
      end

      ADStart: begin
        phase_d = ADMid;
      end

      ADMid: begin
        if (!rnd_last_i) begin
          phase_d = ADMid;
        end else begin
          phase_d = ADEnd;
        end
      end

      ADEnd: begin
        if (!ad_last_i) begin
          phase_d = ADWait;
        end else if (!ad_empty_last_block_s) begin
          phase_d = ADLastWait;
        end else begin
          phase_d = ADLastNoWait;
        end
      end

      ADLastWait: begin
        if (!start_i) begin
          phase_d = Idle;
        end else begin
          if (!data_valid_i) begin
            phase_d = ADLastWait;
          end else begin
            phase_d = ADLastStart;
          end
        end
      end

      ADLastNoWait: begin
        phase_d = ADLastStart;
      end

      ADLastStart: begin
        phase_d = ADLastMid;
      end

      ADLastMid: begin
        if (!rnd_last_i) begin
          phase_d = ADLastMid;
        end else begin
          phase_d = ADLastEnd;
        end
      end

      ADLastEnd: begin
        if (!di_single_block_s) begin
          phase_d = DIWait;
        end else if (!di_empty_last_block_s) begin
          phase_d = FinalWait;
        end else begin
          phase_d = FinalNoWait;
        end
      end

      DIWait: begin
        if (!start_i) begin
          phase_d = Idle;
        end else begin
          if (!data_valid_i) begin
            phase_d = DIWait;
          end else begin
            phase_d = DIStart;
          end
        end
      end

      DIStart: begin
        phase_d = DIMid;
      end

      DIMid: begin
        if (!rnd_last_i) begin
          phase_d = DIMid;
        end else begin
          phase_d = DIEnd;
        end
      end

      DIEnd: begin
        if (!di_last_i) begin
          phase_d = DIWait;
        end else if (!di_empty_last_block_s) begin
          phase_d = FinalWait;
        end else begin
          phase_d = FinalNoWait;
        end
      end

      FinalWait: begin
        if (!start_i) begin
          phase_d = Idle;
        end else begin
          if (!data_valid_i) begin
            phase_d = FinalWait;
          end else begin
            phase_d = FinalStart;
          end
        end
      end

      FinalNoWait: begin
        phase_d = FinalStartEmpty;
      end

      FinalStart: begin
        phase_d = FinalMid;
      end

      FinalStartEmpty: begin
        phase_d = FinalMid;
      end

      FinalMid: begin
        if (!rnd_last_i) begin
          phase_d = FinalMid;
        end else begin
          phase_d = FinalEnd;
        end
      end

      FinalEnd: begin
        phase_d = Done;
      end

      Done: begin
        if (!start_i) begin
          phase_d = Idle;
        end else begin
          phase_d = Done;
        end
      end

      default: begin
        phase_d = Idle;
      end

    endcase

  end

  always_comb begin : fsm_round_function_logic
    op_o = AsconOp0;

    case (phase_q)

      InitStart: begin
        op_o = AsconOp1;
      end

      InitEnd: begin
        op_o = AsconOp2;
      end

      InitEndSep: begin
        op_o = AsconOp3;
      end

      ADStart, ADLastStart: begin
        op_o = AsconOp4;
      end

      ADLastEnd: begin
        op_o = AsconOp5;
      end

      DIStart: begin
        op_o = AsconOp6;
      end

      FinalStart, FinalStartEmpty: begin
        op_o = AsconOp7;
      end

      FinalEnd: begin
        op_o = AsconOp8;
      end

      default: begin
      end

    endcase
  end

  always_comb begin : fsm_status_logic
    idle_o = 1'b0;
    sync_o = 1'b0;
    done_o = 1'b0;

    case (phase_q)

      Idle: begin
        idle_o = 1'b1;
      end

      InitStart, ADStart, ADLastStart, DIStart, FinalStart, FinalStartEmpty: begin
        sync_o = 1'b1;
      end

      Done: begin
        done_o = 1'b1;
      end

      default: begin
      end

    endcase

  end

  always_comb begin : fsm_ctrl_logic
    en_timer_o = 1'b0;
    load_timer_o = 1'b0;
    en_state_o = 1'b0;
    en_rnd_o = 1'b0;
    load_rnd_a_o = 1'b0;
    load_rnd_b_o = 1'b0;
    en_di_cnt_o = 1'b0;
    load_di_cnt_o = 1'b0;
    en_ad_cnt_o = 1'b0;
    load_ad_cnt_o = 1'b0;
    sel_ad_o = 1'b0;
    en_padding_o = 1'b0;
    en_trunc_o = 1'b0;
    en_buf_in_o = 1'b0;
    data_ready_o = 1'b0;
    en_buf_out_o = 1'b0;
    en_tag_o = 1'b0;

    case (phase_q)

      Idle: begin
      end

      Start: begin
        load_timer_o = 1'b1;
        load_rnd_a_o = 1'b1;
        load_ad_cnt_o = 1'b1;
        load_di_cnt_o = 1'b1;
      end

      Delay: begin
        en_timer_o = 1'b1;
      end

      InitStart: begin
        en_state_o = 1'b1;
        en_rnd_o = 1'b1;
      end

      InitMid: begin
        en_state_o = 1'b1;
        en_rnd_o = 1'b1;
      end

      InitEnd: begin
        en_state_o = 1'b1;
      end

      InitEndSep: begin
        en_state_o = 1'b1;
      end

      ADWait: begin
        en_buf_in_o = 1'b1;
        load_rnd_b_o = 1'b1;
        data_ready_o = 1'b1;
      end

      ADStart: begin
        sel_ad_o = 1'b1;
        en_state_o = 1'b1;
        en_rnd_o = 1'b1;
        en_ad_cnt_o = 1'b1;
      end

      ADMid: begin
        en_state_o = 1'b1;
        en_rnd_o = 1'b1;
      end

      ADEnd: begin
        en_state_o = 1'b1;
      end

      ADLastWait: begin
        en_buf_in_o = 1'b1;
        load_rnd_b_o = 1'b1;
        data_ready_o = 1'b1;
      end

      ADLastNoWait: begin
        load_rnd_b_o = 1'b1;
      end

      ADLastStart: begin
        sel_ad_o = 1'b1;
        en_padding_o = 1'b1;
        en_state_o = 1'b1;
        en_rnd_o = 1'b1;
      end

      ADLastMid: begin
        en_state_o = 1'b1;
        en_rnd_o = 1'b1;
      end

      ADLastEnd: begin
        en_state_o = 1'b1;
      end

      DIWait: begin
        en_buf_in_o = 1'b1;
        load_rnd_b_o = 1'b1;
        data_ready_o = 1'b1;
      end

      DIStart: begin
        en_buf_out_o = 1'b1;
        en_state_o = 1'b1;
        en_rnd_o = 1'b1;
        en_di_cnt_o = 1'b1;
      end

      DIMid: begin
        en_state_o = 1'b1;
        en_rnd_o = 1'b1;
      end

      DIEnd: begin
        en_state_o = 1'b1;
      end

      FinalWait: begin
        en_buf_in_o = 1'b1;
        load_rnd_a_o = 1'b1;
        data_ready_o = 1'b1;
      end

      FinalNoWait: begin
        load_rnd_a_o = 1'b1;
      end

      FinalStart: begin
        en_buf_out_o = 1'b1;
        en_trunc_o = 1'b1;
        en_padding_o = 1'b1;
        en_state_o = 1'b1;
        en_rnd_o = 1'b1;
      end

      FinalStartEmpty: begin
        en_padding_o = 1'b1;
        en_state_o = 1'b1;
        en_rnd_o = 1'b1;
      end

      FinalMid: begin
        en_state_o = 1'b1;
        en_rnd_o = 1'b1;
      end

      FinalEnd: begin
        en_tag_o = 1'b1;
      end

      default: begin
      end

    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin : fsm_state_reg
    if (!rst_n) begin
      phase_q <= Idle;
    end else begin
      phase_q <= phase_d;
    end
  end

endmodule
