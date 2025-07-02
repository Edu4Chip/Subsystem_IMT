/*
  Contributors:
    * Matti Käyrä (matti.kayra@tuni.fi)
  Description:
    * integration layer
*/

module imt_ss(
    // Interface: APB
    input  logic [31:0] PADDR,
    input  logic        PENABLE,
    input  logic        PSEL,
    input  logic [31:0] PWDATA,
    input  logic        PWRITE,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    output logic        PSLVERR,

    // Interface: Clock
    input  logic        clk_in,

    // Interface: high_speed_clock
    input  logic        high_speed_clk,

    // Interface: IRQ
    output logic        irq_1,

    // Interface: Reset
    input  logic        reset_int,

    // Interface: SS_Ctrl
    input  logic        irq_en_1,
    input  logic [7:0]  ss_ctrl_1,
    
    //Interface: GPIO pmod 
    input  logic [15:0]  pmod_gpi,
    output logic [15:0]  pmod_gpo,
    output logic [15:0]  pmod_gpio_oe
  );

  top_ascon i_top_ascon(
    // Interface: APB
    .PADDR(PADDR),
    .PENABLE(PENABLE),
    .PSEL(PSEL),
    .PWDATA(PWDATA),
    .PWRITE(PWRITE),
    .PRDATA(PRDATA),
    .PREADY(PREADY),
    .PSLVERR(PSLVERR),

    // Interface: Clock
    .clk_in(clk_in),

    // Interface: IRQ
    .irq_1(irq_1),

    // Interface: Reset
    .reset_int(reset_int),

    // Interface: pmod_gpio_0
    .pmod_0_gpi(pmod_0_gpi),
    .pmod_0_gpio_oe(pmod_0_gpio_oe),
    .pmod_0_gpo(pmod_0_gpo),

    // Interface: pmod_gpio_1
    .pmod_1_gpi(pmod_1_gpi),
    .pmod_1_gpio_oe(pmod_1_gpio_oe),
    .pmod_1_gpo(pmod_1_gpo),

    // Interface: ss_ctrl
    .irq_en_1(irq_en_1),
    .ss_ctrl_1(ss_ctrl_1)
  );

endmodule