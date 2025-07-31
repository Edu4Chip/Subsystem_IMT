`timescale 1ns / 1ps

module ascon_apb_wrapper
  import ascon_pack::*;
#(
  parameter  int unsigned APB_AW,
  parameter  int unsigned APB_DW,
  localparam int unsigned SIZE_WIDTH  = 8,
  localparam int unsigned DELAY_WIDTH = 16
) (

  input  logic [APB_AW-1:0] PADDR,
  input  logic              PENABLE,
  input  logic              PSEL,
  input  logic [APB_DW-1:0] PWDATA,
  input  logic              PWRITE,
  output logic [APB_DW-1:0] PRDATA,
  output logic              PREADY,
  output logic              PSLVERR,

  input logic clk,
  input logic rst_n,

  output logic sync_o

);
  typedef logic [APB_AW-1:0] addr_t;
  typedef logic [APB_DW-1:0] data_t;

  localparam addr_t STATUS_REG_ADDR = APB_AW'(0);
  localparam addr_t CTRL_REG_ADDR = APB_AW'(4);
  localparam addr_t SET_REG_ADDR = APB_AW'(8);
  localparam addr_t CONFIG_REG_ADDR = APB_AW'(12);
  localparam addr_t KEY_REG_ADDR = APB_AW'(16);
  localparam addr_t NONCE_REG_ADDR = APB_AW'(32);
  localparam addr_t TAG_REG_ADDR = APB_AW'(48);
  localparam addr_t DI_REG_ADDR = APB_AW'(64);
  localparam addr_t DO_REG_ADDR = APB_AW'(80);
  localparam addr_t MAX_REG_ADDR = APB_AW'(96);

  // Control register
  localparam int unsigned START_BIT = 0;
  localparam int unsigned DECRYPT_BIT = 1;

  // Set register
  localparam int unsigned DI_VALID_BIT = 0;
  localparam int unsigned DO_READY_BIT = 1;

  // Config register
  localparam int unsigned AD_SIZE_OFFSET = 0;
  localparam int unsigned DI_SIZE_OFFSET = 8;
  localparam int unsigned DELAY_OFFSET = 16;

  logic idle_s;
  logic done_s;
  logic di_ready_s;
  logic do_valid_s;
  logic tag_valid_s;
  logic di_valid_s;

  logic [ SIZE_WIDTH-1:0] ad_size_s;
  logic [ SIZE_WIDTH-1:0] di_size_s;
  logic [DELAY_WIDTH-1:0] delay_s;

  logic PREADY_q, PREADY_d;
  logic PSLVERR_q, PSLVERR_d;
  data_t PRDATA_q, PRDATA_d;

  data_t status_s;
  data_t ctrl_s;

  logic start_q, start_d;
  logic decrypt_q, decrypt_d;
  data_t config_q, config_d;
  logic di_valid_pulse_q, di_valid_pulse_d;
  logic do_ready_pulse_q, do_ready_pulse_d;
  data_t [3:0] key_q, key_d;
  data_t [3:0] nonce_q, nonce_d;
  data_t [3:0] di_q, di_d;
  data_t [3:0] do_s;
  data_t [3:0] tag_s;

  logic di_valid_state_q;
  logic do_valid_state_q;

  assign status_s = {{(APB_DW - 5) {1'b0}}, tag_valid_s, do_valid_state_q, di_ready_s, done_s, ~idle_s};
  assign ctrl_s =  {{(APB_DW - 2) {1'b0}}, decrypt_q, start_q};

  assign ad_size_s = config_q[AD_SIZE_OFFSET+:SIZE_WIDTH];
  assign di_size_s = config_q[DI_SIZE_OFFSET+:SIZE_WIDTH];
  assign delay_s = config_q[DELAY_OFFSET+:DELAY_WIDTH];
  assign di_valid_s = di_valid_state_q && !do_valid_state_q;

  always_comb begin : apb_logic
    PREADY_d = 1'b0;
    PSLVERR_d = 1'b0;
    PRDATA_d = data_t'(0);

    di_valid_pulse_d = 1'b0;
    do_ready_pulse_d = 1'b0;

    start_d = start_q;
    decrypt_d = decrypt_q;
    config_d = config_q;
    key_d = key_q;
    nonce_d = nonce_q;
    di_d = di_q;

    if (PSEL) begin
      if (PREADY_q == 1'b1) begin
        PREADY_d = 1'b0;
      end else if (PWRITE) begin
        PREADY_d = 1'b1;
        case (PADDR)
          CTRL_REG_ADDR: begin
            start_d = PWDATA[START_BIT];
            decrypt_d = PWDATA[DECRYPT_BIT];
          end
          SET_REG_ADDR: begin
            di_valid_pulse_d = PWDATA[DI_VALID_BIT];
            do_ready_pulse_d = PWDATA[DO_READY_BIT];
          end
          CONFIG_REG_ADDR: begin
            config_d = PWDATA;
          end
          KEY_REG_ADDR + 0: begin
            key_d[0] = PWDATA;
          end
          KEY_REG_ADDR + 4: begin
            key_d[1] = PWDATA;
          end
          KEY_REG_ADDR + 8: begin
            key_d[2] = PWDATA;
          end
          KEY_REG_ADDR + 12: begin
            key_d[3] = PWDATA;
          end
          NONCE_REG_ADDR + 0: begin
            nonce_d[0] = PWDATA;
          end
          NONCE_REG_ADDR + 4: begin
            nonce_d[1] = PWDATA;
          end
          NONCE_REG_ADDR + 8: begin
            nonce_d[2] = PWDATA;
          end
          NONCE_REG_ADDR + 12: begin
            nonce_d[3] = PWDATA;
          end
          DI_REG_ADDR + 0: begin
            di_d[0] = PWDATA;
          end
          DI_REG_ADDR + 4: begin
            di_d[1] = PWDATA;
          end
          DI_REG_ADDR + 8: begin
            di_d[2] = PWDATA;
          end
          DI_REG_ADDR + 12: begin
            di_d[3] = PWDATA;
          end
          default: begin
            PSLVERR_d = 1'b1;
          end
        endcase
      end else begin
        PREADY_d = 1'b1;
        case (PADDR)
          STATUS_REG_ADDR: begin
            PRDATA_d = status_s;
          end
          CTRL_REG_ADDR: begin
            PRDATA_d = ctrl_s;
          end
          CONFIG_REG_ADDR: begin
            PRDATA_d = config_q;
          end
          KEY_REG_ADDR + 0: begin
            PRDATA_d = key_q[0];
          end
          KEY_REG_ADDR + 4: begin
            PRDATA_d = key_q[1];
          end
          KEY_REG_ADDR + 8: begin
            PRDATA_d = key_q[2];
          end
          KEY_REG_ADDR + 12: begin
            PRDATA_d = key_q[3];
          end
          NONCE_REG_ADDR + 0: begin
            PRDATA_d = nonce_q[0];
          end
          NONCE_REG_ADDR + 4: begin
            PRDATA_d = nonce_q[1];
          end
          NONCE_REG_ADDR + 8: begin
            PRDATA_d = nonce_q[2];
          end
          NONCE_REG_ADDR + 12: begin
            PRDATA_d = nonce_q[3];
          end
          TAG_REG_ADDR + 0: begin
            PRDATA_d = tag_s[0];
          end
          TAG_REG_ADDR + 4: begin
            PRDATA_d = tag_s[1];
          end
          TAG_REG_ADDR + 8: begin
            PRDATA_d = tag_s[2];
          end
          TAG_REG_ADDR + 12: begin
            PRDATA_d = tag_s[3];
          end
          DI_REG_ADDR + 0: begin
            PRDATA_d = di_q[0];
          end
          DI_REG_ADDR + 4: begin
            PRDATA_d = di_q[1];
          end
          DI_REG_ADDR + 8: begin
            PRDATA_d = di_q[2];
          end
          DI_REG_ADDR + 12: begin
            PRDATA_d = di_q[3];
          end
          DO_REG_ADDR + 0: begin
            PRDATA_d = do_s[0];
          end
          DO_REG_ADDR + 4: begin
            PRDATA_d = do_s[1];
          end
          DO_REG_ADDR + 8: begin
            PRDATA_d = do_s[2];
          end
          DO_REG_ADDR + 12: begin
            PRDATA_d = do_s[3];
          end
          default: begin
            PSLVERR_d = 1'b1;
          end
        endcase
      end
    end

  end

  always_ff @(posedge clk or negedge rst_n) begin : apb_regs
    if (!rst_n) begin
      PREADY_q <= '0;
      PSLVERR_q <= '0;
      PRDATA_q <= '0;
      start_q <= '0;
      decrypt_q <= '0;
      config_q <= '0;
      di_valid_pulse_q <= '0;
      do_ready_pulse_q <= '0;
      key_q <= '0;
      nonce_q <= '0;
      di_q <= '0;
    end else begin
      PREADY_q <= PREADY_d;
      PSLVERR_q <= PSLVERR_d;
      PRDATA_q <= PRDATA_d;
      start_q <= start_d;
      decrypt_q <= decrypt_d;
      config_q <= config_d;
      di_valid_pulse_q <= di_valid_pulse_d;
      do_ready_pulse_q <= do_ready_pulse_d;
      key_q <= key_d;
      nonce_q <= nonce_d;
      di_q <= di_d;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin : di_valid_fsm
    if (!rst_n) begin
      di_valid_state_q <= 1'b0;
    end else begin
      if (di_valid_state_q && di_ready_s) begin
        di_valid_state_q <= 1'b0;
      end else if (!di_valid_state_q && di_valid_pulse_q) begin
        di_valid_state_q <= 1'b1;
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin : do_valid_fsm
    if (!rst_n) begin
      do_valid_state_q <= 1'b0;
    end else begin
      if (do_valid_state_q && do_ready_pulse_q) begin
        do_valid_state_q <= 1'b0;
      end else if (!do_valid_state_q && do_valid_s) begin
        do_valid_state_q <= 1'b1;
      end
    end
  end

  ascon_core #(
    .SIZE_WIDTH (SIZE_WIDTH),
    .DELAY_WIDTH(DELAY_WIDTH)
  ) u_ascon_core (
    .clk         (clk),
    .rst_n       (rst_n),
    .start_i     (start_q),
    .decrypt_i   (decrypt_q),
    .ad_size_i   (ad_size_s),
    .di_size_i   (di_size_s),
    .delay_i     (delay_s),
    .key_i       (key_q),
    .nonce_i     (nonce_q),
    .data_i      (di_q),
    .data_valid_i(di_valid_s),
    .idle_o      (idle_s),
    .sync_o      (sync_o),
    .done_o      (done_s),
    .data_ready_o(di_ready_s),
    .data_o      (do_s),
    .data_valid_o(do_valid_s),
    .tag_o       (tag_s),
    .tag_valid_o (tag_valid_s)
  );

endmodule
