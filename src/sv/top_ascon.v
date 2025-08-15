//-----------------------------------------------------------------------------
// File          : top_ascon.v
// Creation date : 12.11.2024
// Creation time : 22:59:57
// Description   : Cryptographic accelerator for the Ascon128 AEAD authenticated encryption scheme.
// Created by    : Alexandre Menu
// Tool : Kactus2 3.13.2 64-bit
// Plugin : Verilog generator 2.4
// This file was generated based on IP-XACT component emse.fr:ip:apb_ascon:0.2
// whose XML file is /home/menu/work/subsystem_imt/ipxact/emse.fr/ip/apb_ascon/0.2/apb_ascon.0.2.xml
//-----------------------------------------------------------------------------

module top_ascon #(
  parameter APB_AW = 10,
  parameter APB_DW = 32
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

  logic sync_s;

  ascon_apb_wrapper #(
    .APB_AW(APB_AW),
    .APB_DW(APB_DW)
  ) u_ascon_apb_wrapper (
    .PADDR  (PADDR),
    .PENABLE(PENABLE),
    .PSEL   (PSEL),
    .PWDATA (PWDATA),
    .PWRITE (PWRITE),
    .PRDATA (PRDATA),
    .PREADY (PREADY),
    .PSLVERR(PSLVERR),
    .clk    (clk_in),
    .rst_n  (reset_int),
    .sync_o (sync_s)
  );

  assign irq_1 = 1'b0;
  assign pmod_0_gpio_oe = 4'b0001;
  assign pmod_0_gpo = {3'b0, sync_s};
  assign pmod_1_gpio_oe = 4'b0000;
  assign pmod_1_gpo = 4'b0000;

endmodule
