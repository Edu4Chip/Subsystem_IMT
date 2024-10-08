//-----------------------------------------------------------------------------
// File          : apb_ascon.v
// Creation date : 13.10.2024
// Creation time : 16:24:24
// Description   : Cryptographic accelerator for the Ascon128 AEAD authenticated encryption scheme.
// Created by    : Alexandre Menu
// Tool : Kactus2 3.13.2 64-bit
// Plugin : Verilog generator 2.4
// This file was generated based on IP-XACT component emse.fr:ip:apb_ascon:0.1
// whose XML file is /home/menu/work/subsystem_imt/ipxact/emse.fr/ip/apb_ascon/0.1/apb_ascon.0.1.xml
//-----------------------------------------------------------------------------
`include "registers.svh"

module apb_ascon #(
    parameter APB_AW    = 10,
    parameter APB_DW    = 32,
    parameter BLK_AD_AW = 3,
    parameter BLK_PT_AW = 3,
    parameter BUF_DEPTH = 4
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
    input logic clk_in,

    // Interface: IRQ
    output logic irq_1,

    // Interface: Reset
    input logic reset_int,

    // Interface: pmod_gpio_0
    input  logic [3:0] pmod_0_gpi,
    output logic [3:0] pmod_0_gpio_oe,
    output logic [3:0] pmod_0_gpo,

    // Interface: pmod_gpio_1
    input  logic [3:0] pmod_1_gpi,
    output logic [3:0] pmod_1_gpio_oe,
    output logic [3:0] pmod_1_gpo,

    // Interface: ss_ctrl
    input logic       irq_en_1,
    input logic [7:0] ss_ctrl_1
);

  // WARNING: EVERYTHING ON AND ABOVE THIS LINE MAY BE OVERWRITTEN BY KACTUS2!!!

  parameter int REG128_REG_NO = 128 / APB_DW;
  parameter int DATA_REG_NO = BUF_DEPTH * (64 / APB_DW);
  parameter int APB_REG_NO = 2 + 3 * REG128_REG_NO + 2 * DATA_REG_NO;
  parameter int REG_AW = APB_REG_NO > 1 ? $clog2(APB_REG_NO) : 1;

  // address of APB registers
  parameter logic [REG_AW-1:0] CTRL = 0, STATUS = 1, KEY = 2,
   NONCE = 6, TAG = 10, DATAIN = 14, DATAOUT = 22;
  // offset of fields in CTRL register
  parameter int AD_BLK_NO = 16, PT_BLK_NO = 24;

  parameter logic [APB_REG_NO-1:0] READONLY_REG = {
    {DATA_REG_NO{1'b1}},
    {DATA_REG_NO{1'b0}},
    {REG128_REG_NO{1'b1}},
    {REG128_REG_NO{1'b0}},
    {REG128_REG_NO{1'b0}},
    1'b1,
    1'b0
  };

  typedef union packed {logic [BUF_DEPTH-1:0][63:0] blocks;} buffer_t;
  typedef union packed {logic [APB_REG_NO-1:0][APB_DW-1:0] regs;} reg_t;

  reg_t reg_s, n_reg_s, ro_reg_s;
  logic [APB_REG_NO-1:0] load_reg_s;
  logic [REG_AW-1:0] addr_s;

  logic start_s;
  logic data_valid_s;
  logic ct_read_ack_s;
  logic [BLK_AD_AW-1:0] ad_size_s;
  logic [BLK_PT_AW-1:0] pt_size_s;
  logic [127:0] key_s;
  logic [127:0] nonce_s;
  buffer_t data_s;
  buffer_t ct_s;
  logic [127:0] tag_s;
  logic ready_s;
  logic done_s;
  logic ct_ready_s;
  logic data_req_s;

  assign addr_s = PADDR[2+:REG_AW];

  always_comb begin
    ct_read_ack_s = 0;
    data_valid_s = 0;
    start_s = 0;
    n_reg_s = 0;
    load_reg_s = 0;
    PREADY = PSEL & PENABLE;
    PSLVERR = 0;
    PRDATA = 0;

    if (PSEL) begin
      if (|PADDR[1:0]) begin
        PSLVERR = 1;
      end else begin
        if (PWRITE & PENABLE) begin
          if (addr_s == CTRL) begin
            {n_reg_s.regs[addr_s][APB_DW-1:3], ct_read_ack_s, data_valid_s, start_s} = PWDATA;
            load_reg_s[addr_s] = 1;
          end else begin
            if (!READONLY_REG[addr_s]) begin
              n_reg_s.regs[addr_s] = PWDATA;
              load_reg_s[addr_s]   = 1;
            end else begin
              // attempt to write a read-only register
              PSLVERR = 1;
            end
          end
        end else if (!PWRITE) begin
          if (!READONLY_REG[addr_s]) begin
            PRDATA = reg_s.regs[addr_s];
          end else begin
            PRDATA = ro_reg_s.regs[addr_s];
          end
        end
      end
    end
  end

  for (genvar i = 0; i < APB_REG_NO; ++i) begin : gen_apb_reg
    `FFL(reg_s.regs[i], n_reg_s.regs[i], load_reg_s[i], 0, clk_in, reset_int)
  end

  assign ad_size_s = reg_s.regs[CTRL][AD_BLK_NO+:BLK_AD_AW];
  assign pt_size_s = reg_s.regs[CTRL][PT_BLK_NO+:BLK_PT_AW];
  assign key_s = {<<APB_DW{reg_s[KEY*APB_DW+:128]}};
  assign nonce_s = {<<APB_DW{reg_s[NONCE*APB_DW+:128]}};
  for (genvar i = 0; i < BUF_DEPTH; i++) begin : gen_data
    assign data_s.blocks[i] = {<<APB_DW{reg_s[DATAIN*APB_DW+i*64+:64]}};
  end

  assign ro_reg_s.regs[CTRL] = 0;
  assign ro_reg_s.regs[STATUS][APB_DW-1:4] = 0;
  assign ro_reg_s.regs[STATUS][3:0] = {data_req_s, ct_ready_s, done_s, ready_s};
  assign ro_reg_s[KEY*APB_DW+:128] = 0;
  assign ro_reg_s[NONCE*APB_DW+:128] = 0;
  assign ro_reg_s[TAG*APB_DW+:128] = {<<APB_DW{tag_s}};
  assign ro_reg_s[DATAIN*APB_DW+:DATA_REG_NO*APB_DW] = 0;
  for (genvar i = 0; i < BUF_DEPTH; i++) begin : gen_ct
    assign ro_reg_s[DATAOUT*APB_DW+i*64+:64] = {<<APB_DW{ct_s.blocks[i]}};
  end

  ascon_wrapper #(
      .BUF_DEPTH(BUF_DEPTH),
      .BLK_AD_AW(BLK_AD_AW),
      .BLK_PT_AW(BLK_PT_AW)
  ) u_ascon_wrapper (
      .clk_i        (clk_in),
      .rst_n_i      (reset_int),
      .data_i       (data_s.blocks),
      .key_i        (key_s),
      .nonce_i      (nonce_s),
      .ad_size_i    (ad_size_s),
      .pt_size_i    (pt_size_s),
      .start_i      (start_s),
      .data_valid_i (data_valid_s),
      .ct_read_ack_i(ct_read_ack_s),
      .data_req_o   (data_req_s),
      .ct_ready_o   (ct_ready_s),
      .ready_o      (ready_s),
      .done_o       (done_s),
      .ct_o         (ct_s.blocks),
      .tag_o        (tag_s)
  );

endmodule
