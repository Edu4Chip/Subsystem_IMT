`timescale 1ns / 1ps
`include "registers.svh"

`define _SWAP(__q) {<<8{__q}}

module apb_registers
  import ascon_pack::*;
#(
  parameter int unsigned APB_AW      = 10,
  parameter int unsigned APB_DW      = 32,
  parameter int unsigned DATA_AW     = 7,
  parameter int unsigned DELAY_WIDTH = 16
) (
  // Interface: APB
  input  logic [APB_AW-1:0] PADDR,
  input  logic              PENABLE,
  input  logic              PSEL,
  input  logic [APB_DW-1:0] PWDATA,
  input  logic              PWRITE,
  output logic [APB_DW-1:0] PRDATA,
  output logic              PREADY,
  output logic              PSLVERR,

  // Interface: Clock
  input logic clk,

  // Interface: Reset
  input logic rst_n,

  // Interface: Ascon wrapper
  output u128_t                   key_o,
  output u128_t                   nonce_o,
  output logic  [    DATA_AW-1:0] ad_size_o,
  output logic  [    DATA_AW-1:0] pt_size_o,
  output logic  [DELAY_WIDTH-1:0] delay_o,

  output logic  start_o,
  input  logic  ready_i,
  input  logic  wait_ad_i,
  input  logic  wait_pt_i,
  input  logic  tag_valid_i,
  input  u128_t tag_i,

  output logic ad_push_o,
  output u64_t ad_o,
  input  logic ad_full_i,
  input  logic ad_empty_i,

  output logic pt_push_o,
  output u64_t pt_o,
  input  logic pt_full_i,
  input  logic pt_empty_i,

  output logic ct_pop_o,
  input  u64_t ct_i,
  input  logic ct_full_i,
  input  logic ct_empty_i
);
  localparam int unsigned APBRegNo = 20;
  localparam int unsigned IdxWidth = APBRegNo > 1 ? $clog2(APBRegNo) : 1;
  localparam int unsigned BlkRegNo = 64 / APB_DW;

  // address of registers
  localparam logic [APB_AW-1:0] CtrlAddr = APB_AW'('h00);
  localparam logic [APB_AW-1:0] StatusAddr = APB_AW'('h04);
  localparam logic [APB_AW-1:0] KeyAddr = APB_AW'('h08);
  localparam logic [APB_AW-1:0] NonceAddr = APB_AW'('h18);
  localparam logic [APB_AW-1:0] TagAddr = APB_AW'('h28);
  localparam logic [APB_AW-1:0] AdAddr = APB_AW'('h38);
  localparam logic [APB_AW-1:0] PtAddr = APB_AW'('h40);
  localparam logic [APB_AW-1:0] CtAddr = APB_AW'('h48);
  localparam logic [APB_AW-1:0] MaxAddr = APB_AW'('h50);

  // index of registers
  localparam int unsigned ADBaseIdx = int'(AdAddr[APB_AW-1:2]);
  localparam int unsigned PTBaseIdx = int'(PtAddr[APB_AW-1:2]);
  localparam int unsigned CTBaseIdx = int'(CtAddr[APB_AW-1:2]);

  // offset of fields in CTRL register
  localparam int unsigned StartBitOffset = 0;
  localparam int unsigned ADSizeOffset = 2;
  localparam int unsigned PTSizeOffset = 9;
  localparam int unsigned DelayOffset = 16;

  // offset of fields in STATUS register
  localparam int unsigned ReadyOffset = 0;
  localparam int unsigned WaitAdOffset = 1;
  localparam int unsigned WaitPtOffset = 2;
  localparam int unsigned TagValidOffset = 3;
  localparam int unsigned AdFullOffset = 4;
  localparam int unsigned PtFullOffset = 5;
  localparam int unsigned CtEmptyOffset = 6;
  localparam int unsigned CtFullOffset = 7;

  u64_t  ct_s;
  u128_t tag_s;
  u32_t  status_s;

  typedef logic [APB_DW-1:0] data_t;
  typedef struct packed {
    u64_t  ct;
    u64_t  pt;
    u64_t  ad;
    u128_t tag;
    u128_t nonce;
    u128_t key;
    u32_t  status;
    u32_t  ctrl;
  } apb_reg_map_t;

  // read-only register attribute (0: rw, 1: ro)
  localparam logic [APBRegNo-1:0] ReadOnly = {
    2'b11, 2'b00, 2'b00, 4'b1111, 4'b0000, 4'b0000, 1'b1, 1'b0
  };

  // APB registers
  data_t [APBRegNo-1:0] reg_q, reg_d, reg_ro_s;
  apb_reg_map_t reg_ro_map_s, reg_map_s;

  // one-hot signals encoding read and write transactions in APB registers
  logic [APBRegNo-1:0] wr_en_s;
  logic [APBRegNo-1:0] rd_en_s;

  // single-pulse detection of the end of a transaction
  logic apb_penable_q;
  logic apb_trans_end_s;

  // generation of push / pop signals after accessing
  // the lower half and the upper half of a 64-bit register
  logic [BlkRegNo-1:0] ad_wr_q, ad_wr_d;
  logic [BlkRegNo-1:0] pt_wr_q, pt_wr_d;
  logic [BlkRegNo-1:0] ct_rd_q, ct_rd_d;

  // address decoding logic
  logic [IdxWidth-1:0] idx_s;
  logic unaligned_addr_s;
  logic valid_addr_s;

  assign idx_s = PADDR[2+:IdxWidth];
  assign unaligned_addr_s = |PADDR[1:0];
  assign valid_addr_s = (PADDR < MaxAddr);

  // APB read and write transactions in registers with no wait state
  always_comb begin
    PREADY  = PSEL && PENABLE;
    PSLVERR = 1'b0;
    PRDATA  = '0;
    reg_d   = reg_q;
    wr_en_s = '0;
    rd_en_s = '0;
    if (PSEL) begin
      if (!valid_addr_s || unaligned_addr_s) begin
        // malformed address
        PSLVERR = 1;
      end else begin
        if (PWRITE && PENABLE) begin
          if (!ReadOnly[idx_s]) begin
            reg_d[idx_s]   = PWDATA;
            wr_en_s[idx_s] = 1;
          end else begin
            // attempt to write a read-only register
            PSLVERR = 1;
          end
        end else if (!PWRITE) begin
          rd_en_s[idx_s] = 1;
          if (!ReadOnly[idx_s]) begin
            PRDATA = reg_q[idx_s];
          end else begin
            PRDATA = reg_ro_s[idx_s];
          end
        end
      end
    end
  end

  // single-pulse detection of the end of a transaction
  assign apb_trans_end_s = apb_penable_q && !PENABLE;
  // generates a push / pop pulse at the end of a transaction
  // provided that all the registers in the block have been accessed
  assign ad_wr_d = ad_push_o ? '0 : ad_wr_q | wr_en_s[ADBaseIdx+:BlkRegNo];
  assign pt_wr_d = pt_push_o ? '0 : pt_wr_q | wr_en_s[PTBaseIdx+:BlkRegNo];
  assign ct_rd_d = ct_pop_o ? '0 : ct_rd_q | rd_en_s[CTBaseIdx+:BlkRegNo];
  assign ad_push_o = &ad_wr_q && apb_trans_end_s;
  assign pt_push_o = &pt_wr_q && apb_trans_end_s;
  assign ct_pop_o = &ct_rd_q && apb_trans_end_s;

  // map registers on output data
  assign reg_map_s = reg_q;
  assign start_o = reg_map_s.ctrl[StartBitOffset];
  assign ad_size_o = reg_map_s.ctrl[ADSizeOffset+:DATA_AW];
  assign pt_size_o = reg_map_s.ctrl[PTSizeOffset+:DATA_AW];
  assign delay_o = reg_map_s.ctrl[DelayOffset+:DELAY_WIDTH];
  assign key_o = `_SWAP(reg_map_s.key);
  assign nonce_o = `_SWAP(reg_map_s.nonce);
  assign ad_o = `_SWAP(reg_map_s.ad);
  assign pt_o = `_SWAP(reg_map_s.pt);

  // map input data on registers
  assign status_s[APB_DW-1:8] = '0;
  assign status_s[7:0] = {
    ct_full_i, ct_empty_i, pt_full_i, ad_full_i, tag_valid_i, wait_pt_i, wait_ad_i, ready_i
  };
  assign tag_s = `_SWAP(tag_i);
  assign ct_s = `_SWAP(ct_i);

  assign reg_ro_map_s = '{default: '0, status: status_s, tag: tag_s, ct: ct_s};
  assign reg_ro_s = reg_ro_map_s;

  // APB register file
  for (genvar i = 0; i < APBRegNo; i++) begin : gen_reg_file
    `FFL(reg_q[i], reg_d[i], wr_en_s[i], '0, clk, rst_n)
  end
  // PENABLE register
  `FF(apb_penable_q, PENABLE, 1'b0, clk, rst_n)
  // state registers capturing registers which have been read / written in AD, PT and CT blocks
  `FF(ad_wr_q, ad_wr_d, '0, clk, rst_n)
  `FF(pt_wr_q, pt_wr_d, '0, clk, rst_n)
  `FF(ct_rd_q, ct_rd_d, '0, clk, rst_n)

endmodule

`undef _SWAP
