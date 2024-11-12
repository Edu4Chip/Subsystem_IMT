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

module top_ascon #(
    parameter int unsigned APB_AW    = 10,
    parameter int unsigned APB_DW    = 32,
    parameter int unsigned FifoDepth = 4,
    parameter int unsigned DataAddrWidth = 7,
    parameter int unsigned DelayWidth = 16
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
  import ascon_pack::*;

  u128_t key_s;
  u128_t nonce_s;
  logic [DataAddrWidth-1:0] ad_size_s;
  logic [DataAddrWidth-1:0] pt_size_s;
  logic [DelayWidth-1:0] delay_s;
  logic start_s;
  logic ready_s;
  logic tag_valid_s;
  u128_t tag_s;
  logic ad_push_s;
  u64_t ad_s;
  logic ad_full_s;
  logic ad_empty_s;
  logic pt_push_s;
  u64_t pt_s;
  logic pt_full_s;
  logic pt_empty_s;
  logic ct_pop_s;
  u64_t ct_s;
  logic ct_full_s;
  logic ct_empty_s;

  apb_registers #(
      .APB_AW       (APB_AW),
      .APB_DW       (APB_DW),
      .DataAddrWidth(DataAddrWidth),
      .DelayWidth   (DelayWidth)
  ) u_apb_registers (
      // Interface: APB
      .PADDR      (PADDR),
      .PENABLE    (PENABLE),
      .PSEL       (PSEL),
      .PWDATA     (PWDATA),
      .PWRITE     (PWRITE),
      .PRDATA     (PRDATA),
      .PREADY     (PREADY),
      .PSLVERR    (PSLVERR),
      // Interface: Clock
      .clk        (clk_in),
      // Interface: Reset
      .rst_n      (reset_int),
      // Interface: Ascon wrapper
      .key_o      (key_s),
      .nonce_o    (nonce_s),
      .ad_size_o  (ad_size_s),
      .pt_size_o  (pt_size_s),
      .delay_o    (delay_s),
      .start_o    (start_s),
      .ready_i    (ready_s),
      .tag_valid_i(tag_valid_s),
      .tag_i      (tag_s),
      .ad_push_o  (ad_push_s),
      .ad_o       (ad_s),
      .ad_full_i  (ad_full_s),
      .ad_empty_i (ad_empty_s),
      .pt_push_o  (pt_push_s),
      .pt_o       (pt_s),
      .pt_full_i  (pt_full_s),
      .pt_empty_i (pt_empty_s),
      .ct_pop_o   (ct_pop_s),
      .ct_i       (ct_s),
      .ct_full_i  (ct_full_s),
      .ct_empty_i (ct_empty_s)
  );

  ascon_wrapper #(
      .FifoDepth    (FifoDepth),
      .DataAddrWidth(DataAddrWidth),
      .DelayWidth   (DelayWidth)
  ) u_ascon_wrapper (
      .clk      (clk_in),
      .rst_n    (reset_int),
      .key_i      (key_s),
      .nonce_i    (nonce_s),
      .ad_size_i  (ad_size_s),
      .pt_size_i  (pt_size_s),
      .delay_i    (delay_s),
      .start_i    (start_s),
      .ready_o    (ready_s),
      .tag_valid_o(tag_valid_s),
      .tag_o      (tag_s),
      .ad_push_i  (ad_push_s),
      .ad_i       (ad_s),
      .ad_full_o  (ad_full_s),
      .ad_empty_o (ad_empty_s),
      .pt_push_i  (pt_push_s),
      .pt_i       (pt_s),
      .pt_full_o  (pt_full_s),
      .pt_empty_o (pt_empty_s),
      .ct_pop_i   (ct_pop_s),
      .ct_o       (ct_s),
      .ct_full_o  (ct_full_s),
      .ct_empty_o (ct_empty_s)
  );

endmodule
