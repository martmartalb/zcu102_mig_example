`timescale 1ps/1ps

module simple_top #(
  parameter APP_DATA_WIDTH = 128,
  parameter APP_MASK_WIDTH = 16,
  parameter SIMULATION     = "FALSE"
)(
  input                 sys_rst,

  output [3:0]          led,
  input                 c0_sys_clk_p,
  input                 c0_sys_clk_n,
  output                c0_ddr4_act_n,
  output [16:0]         c0_ddr4_adr,
  output [1:0]          c0_ddr4_ba,
  output [0:0]          c0_ddr4_bg,
  output [0:0]          c0_ddr4_cke,
  output [0:0]          c0_ddr4_odt,
  output [0:0]          c0_ddr4_cs_n,
  output [0:0]          c0_ddr4_ck_t,
  output [0:0]          c0_ddr4_ck_c,
  output                c0_ddr4_reset_n,
  inout  [1:0]          c0_ddr4_dm_dbi_n,
  inout  [15:0]         c0_ddr4_dq,
  inout  [1:0]          c0_ddr4_dqs_t,
  inout  [1:0]          c0_ddr4_dqs_c
);

  localparam APP_ADDR_WIDTH = 28;

  // -----------------------------------------------------------------------
  // Internal wires
  // -----------------------------------------------------------------------

  // MIG app interface
  wire [APP_ADDR_WIDTH-1:0]   c0_ddr4_app_addr;
  wire [2:0]                  c0_ddr4_app_cmd;
  wire                        c0_ddr4_app_en;
  wire [APP_DATA_WIDTH-1:0]   c0_ddr4_app_wdf_data;
  wire                        c0_ddr4_app_wdf_end;
  wire [APP_MASK_WIDTH-1:0]   c0_ddr4_app_wdf_mask;
  wire                        c0_ddr4_app_wdf_wren;
  wire [APP_DATA_WIDTH-1:0]   c0_ddr4_app_rd_data;
  wire                        c0_ddr4_app_rd_data_end;
  wire                        c0_ddr4_app_rd_data_valid;
  wire                        c0_ddr4_app_rdy;
  wire                        c0_ddr4_app_wdf_rdy;

  // Clocks and resets
  wire                        c0_ddr4_clk;
  wire                        c0_ddr4_rst;
  wire                        dbg_clk;

  // Status
  wire                        c0_init_calib_complete;
  wire                        c0_data_compare_error;
  wire                        tg_done;

  // Debug
  wire [511:0]                dbg_bus;

  wire c0_ddr4_reset_n_int;
  assign c0_ddr4_reset_n = c0_ddr4_reset_n_int;

  (* mark_debug = "TRUE" *) wire dbg_init_calib_complete;
  (* mark_debug = "TRUE" *) wire dbg_data_compare_error;

  assign dbg_init_calib_complete = c0_init_calib_complete;
  assign dbg_data_compare_error  = c0_data_compare_error;

  // *************************************************************************
  // DDR4 Memory Controller (Simple TG mode — no traffic generator ports)
  // *************************************************************************

  ddr4_0 u_ddr4_0
  (
    .sys_rst                       (sys_rst),

    .c0_sys_clk_p                  (c0_sys_clk_p),
    .c0_sys_clk_n                  (c0_sys_clk_n),
    .c0_init_calib_complete        (c0_init_calib_complete),
    .c0_ddr4_act_n                 (c0_ddr4_act_n),
    .c0_ddr4_adr                   (c0_ddr4_adr),
    .c0_ddr4_ba                    (c0_ddr4_ba),
    .c0_ddr4_bg                    (c0_ddr4_bg),
    .c0_ddr4_cke                   (c0_ddr4_cke),
    .c0_ddr4_odt                   (c0_ddr4_odt),
    .c0_ddr4_cs_n                  (c0_ddr4_cs_n),
    .c0_ddr4_ck_t                  (c0_ddr4_ck_t),
    .c0_ddr4_ck_c                  (c0_ddr4_ck_c),
    .c0_ddr4_reset_n               (c0_ddr4_reset_n_int),

    .c0_ddr4_dm_dbi_n              (c0_ddr4_dm_dbi_n),
    .c0_ddr4_dq                    (c0_ddr4_dq),
    .c0_ddr4_dqs_c                 (c0_ddr4_dqs_c),
    .c0_ddr4_dqs_t                 (c0_ddr4_dqs_t),

    .c0_ddr4_ui_clk                (c0_ddr4_clk),
    .c0_ddr4_ui_clk_sync_rst       (c0_ddr4_rst),
    .addn_ui_clkout1               (),
    .dbg_clk                       (dbg_clk),

    .c0_ddr4_app_addr              (c0_ddr4_app_addr),
    .c0_ddr4_app_cmd               (c0_ddr4_app_cmd),
    .c0_ddr4_app_en                (c0_ddr4_app_en),
    .c0_ddr4_app_hi_pri            (1'b0),
    .c0_ddr4_app_wdf_data          (c0_ddr4_app_wdf_data),
    .c0_ddr4_app_wdf_end           (c0_ddr4_app_wdf_end),
    .c0_ddr4_app_wdf_mask          (c0_ddr4_app_wdf_mask),
    .c0_ddr4_app_wdf_wren          (c0_ddr4_app_wdf_wren),
    .c0_ddr4_app_rd_data           (c0_ddr4_app_rd_data),
    .c0_ddr4_app_rd_data_end       (c0_ddr4_app_rd_data_end),
    .c0_ddr4_app_rd_data_valid     (c0_ddr4_app_rd_data_valid),
    .c0_ddr4_app_rdy               (c0_ddr4_app_rdy),
    .c0_ddr4_app_wdf_rdy           (c0_ddr4_app_wdf_rdy),

    // Debug Port
    .dbg_bus                       (dbg_bus)
  );

  // *************************************************************************
  // Simple Traffic Generator
  // *************************************************************************

  simple_tg #(
    .APP_ADDR_WIDTH (APP_ADDR_WIDTH),
    .APP_DATA_WIDTH (APP_DATA_WIDTH),
    .APP_MASK_WIDTH (APP_MASK_WIDTH),
    .NUM_TRANSACTIONS (8)
  )
  u_simple_tg
  (
    .clk                 (c0_ddr4_clk),
    .rst                 (c0_ddr4_rst),
    .init_calib_complete (c0_init_calib_complete),

    .app_rdy             (c0_ddr4_app_rdy),
    .app_wdf_rdy         (c0_ddr4_app_wdf_rdy),
    .app_rd_data         (c0_ddr4_app_rd_data),
    .app_rd_data_valid   (c0_ddr4_app_rd_data_valid),
    .app_rd_data_end     (c0_ddr4_app_rd_data_end),

    .app_addr            (c0_ddr4_app_addr),
    .app_cmd             (c0_ddr4_app_cmd),
    .app_en              (c0_ddr4_app_en),
    .app_wdf_data        (c0_ddr4_app_wdf_data),
    .app_wdf_end         (c0_ddr4_app_wdf_end),
    .app_wdf_mask        (c0_ddr4_app_wdf_mask),
    .app_wdf_wren        (c0_ddr4_app_wdf_wren),

    .done                (tg_done),
    .error               (c0_data_compare_error)
  );

  // *************************************************************************
  // Debug Core — ILA
  // *************************************************************************

  ila_ddrx u_ila_ddrx
  (
    .clk     (c0_ddr4_clk),
    .probe0  (dbg_init_calib_complete),
    .probe1  (dbg_data_compare_error),
    .probe2  (c0_ddr4_app_rd_data[63:0]),
    .probe3  (c0_ddr4_app_wdf_data[63:0]),
    .probe4  (c0_ddr4_app_cmd),
    .probe5  ({28'b0, c0_ddr4_app_en, c0_ddr4_app_rdy, c0_ddr4_app_wdf_rdy, tg_done}),
    .probe6  ({8{1'b0}}),
    .probe7  (c0_ddr4_app_rd_data_valid),
    .probe8  (6'b0),
    .probe9  (c0_ddr4_app_rd_data[63:0]),
    .probe10 (16'b0),
    .probe11 (2'b0),
    .probe12 (c0_ddr4_app_addr),
    .probe13 (1'b0),
    .probe14 (20'b0),
    .probe15 (20'b0),
    .probe16 (20'b0),
    .probe17 (20'b0),
    .probe18 (128'b0),
    .probe19 (9'b0)
  );

  // *************************************************************************
  // LED Display Driver
  // *************************************************************************

  led_display_driver u_led_display_driver
  (
    .rst            (sys_rst),
    .clk            (c0_ddr4_clk),
    .dbg_clk        (dbg_clk),
    .init_done_i    (c0_init_calib_complete),
    .error_i        (c0_data_compare_error),
    .valid_i        (c0_ddr4_app_rd_data_valid),
    .seven_seg_n    (),
    .seven_seg_dp_n (),
    .system_reset   (),
    .led            (led[3:0])
  );

endmodule
