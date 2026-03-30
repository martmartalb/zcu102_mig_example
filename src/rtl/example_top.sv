/******************************************************************************
// (c) Copyright 2013 - 2014 Xilinx, Inc. All rights reserved.
//
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
******************************************************************************/
//   ____  ____
//  /   /\/   /
// /___/  \  /    Vendor             : Xilinx
// \   \   \/     Version            : 1.0
//  \   \         Application        : MIG
//  /   /         Filename           : example_top.sv
// /___/   /\     Date Last Modified : $Date: 2014/09/03 $
// \   \  /  \    Date Created       : Thu Apr 18 2013
//  \___\/\___\
//
// Device           : UltraScale
// Design Name      : DDR4_SDRAM
// Purpose          :
//                    Top-level  module. This module serves both as an example,
//                    and allows the user to synthesize a self-contained
//                    design, which they can be used to test their hardware.
//                    In addition to the memory controller,
//                    the module instantiates:
//                      1. Synthesizable testbench - used to model
//                      user's backend logic and generate different
//                      traffic patterns
//
// Reference        :
// Revision History :
//*****************************************************************************

`timescale 1ps/1ps
module example_top #
  (
    parameter nCK_PER_CLK           = 4,
    parameter APP_DATA_WIDTH        = 128,
    parameter APP_MASK_WIDTH        = 16,
    parameter SIMULATION            = "FALSE"
  )
  (
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

  localparam APP_ADDR_WIDTH    = 28;
  localparam MEM_ADDR_ORDER    = "ROW_COLUMN_BANK";
  localparam DBG_WR_STS_WIDTH  = 32;
  localparam DBG_RD_STS_WIDTH  = 32;
  localparam ECC               = "OFF";

  // Application interface wires
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
  wire                        c0_ddr4_clk;
  wire                        c0_ddr4_rst;
  wire                        dbg_clk;
  wire                        c0_wr_rd_complete;

  // Traffic generator control signals
  wire                        traffic_start;
  wire                        traffic_rst;
  wire                        traffic_err_chk_en;
  wire [3:0]                  traffic_instr_addr_mode;
  wire [4:0]                  traffic_instr_data_mode;
  wire [3:0]                  traffic_instr_rw_mode;
  wire [1:0]                  traffic_instr_rw_submode;
  wire [31:0]                 traffic_instr_num_of_iter;
  wire [5:0]                  traffic_instr_nxt_instr;
  wire [APP_DATA_WIDTH-1:0]   traffic_error_tg;
  wire [APP_DATA_WIDTH-1:0]   traffic_error;

  // tg_reset not used without MARGIN_CHECK
  wire                        tg_reset_x1;
  assign tg_reset_x1 = 1'b0;

  // Debug ports
  wire [63:0]                 dbg_rd_data_cmp;
  wire [63:0]                 dbg_expected_data;
  wire [2:0]                  dbg_cal_seq;
  wire [31:0]                 dbg_cal_seq_cnt;
  wire [7:0]                  dbg_cal_seq_rd_cnt;
  wire                        dbg_rd_valid;
  wire [5:0]                  dbg_cmp_byte;
  wire [63:0]                 dbg_rd_data;
  wire [15:0]                 dbg_cplx_config;
  wire [1:0]                  dbg_cplx_status;
  wire [27:0]                 dbg_io_address;
  wire                        dbg_pllGate;
  wire [19:0]                 dbg_phy2clb_fixdly_rdy_low;
  wire [19:0]                 dbg_phy2clb_fixdly_rdy_upp;
  wire [19:0]                 dbg_phy2clb_phy_rdy_low;
  wire [19:0]                 dbg_phy2clb_phy_rdy_upp;
  wire [127:0]                cal_r0_status;
  wire [8:0]                  cal_post_status;

  // HW TG status signals
  wire [3:0]                  vio_tg_status_state;
  wire                        vio_tg_status_err_bit_valid;
  wire [APP_DATA_WIDTH-1:0]   vio_tg_status_err_bit;
  wire [31:0]                 vio_tg_status_err_cnt;
  wire [APP_ADDR_WIDTH-1:0]   vio_tg_status_err_addr;
  wire                        vio_tg_status_exp_bit_valid;
  wire [APP_DATA_WIDTH-1:0]   vio_tg_status_exp_bit;
  wire                        vio_tg_status_read_bit_valid;
  wire [APP_DATA_WIDTH-1:0]   vio_tg_status_read_bit;
  wire                        vio_tg_status_first_err_bit_valid;
  wire [APP_DATA_WIDTH-1:0]   vio_tg_status_first_err_bit;
  wire [APP_ADDR_WIDTH-1:0]   vio_tg_status_first_err_addr;
  wire                        vio_tg_status_first_exp_bit_valid;
  wire [APP_DATA_WIDTH-1:0]   vio_tg_status_first_exp_bit;
  wire                        vio_tg_status_first_read_bit_valid;
  wire [APP_DATA_WIDTH-1:0]   vio_tg_status_first_read_bit;
  wire                        vio_tg_status_err_bit_sticky_valid;
  wire [APP_DATA_WIDTH-1:0]   vio_tg_status_err_bit_sticky;
  wire [31:0]                 vio_tg_status_err_cnt_sticky;
  wire                        vio_tg_status_err_type_valid;
  wire                        vio_tg_status_err_type;
  wire                        vio_tg_status_wr_done;
  wire                        vio_tg_status_done;
  wire                        vio_tg_status_watch_dog_hang;
  wire                        tg_ila_debug;

  // Debug Bus
  wire [511:0]                dbg_bus;

  // Calibration and error status (active in hardware mode)
  wire                        c0_init_calib_complete;
  wire                        c0_data_compare_error;

  // Debug wires with mark_debug attribute
  (* mark_debug = "TRUE" *) wire dbg_init_calib_complete;
  (* mark_debug = "TRUE" *) wire dbg_data_compare_error;

  wire c0_ddr4_reset_n_int;
  assign c0_ddr4_reset_n = c0_ddr4_reset_n_int;

  //***************************************************************************
  // DDR4 Memory Controller
  //***************************************************************************

  ddr4_0 u_ddr4_0
  (
    .sys_rst                       (system_reset),

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

    .traffic_wr_done               (vio_tg_status_wr_done),
    .traffic_status_err_bit_valid  (vio_tg_status_err_bit_valid),
    .traffic_status_err_type_valid (vio_tg_status_err_type_valid),
    .traffic_status_err_type       (vio_tg_status_err_type),
    .traffic_status_done           (vio_tg_status_done),
    .traffic_status_watch_dog_hang (vio_tg_status_watch_dog_hang),
    .traffic_error                 (vio_tg_status_err_bit_sticky),

    // MARGIN_CHECK disabled - tie off signals
    .win_start                     (4'b0),
    .traffic_clr_error             (),
    .win_status                    (),

    // VIO_ATG_EN disabled - connect traffic signals
    .traffic_start                 (traffic_start),
    .traffic_rst                   (traffic_rst),
    .traffic_err_chk_en            (traffic_err_chk_en),
    .traffic_instr_addr_mode       (traffic_instr_addr_mode),
    .traffic_instr_data_mode       (traffic_instr_data_mode),
    .traffic_instr_rw_mode         (traffic_instr_rw_mode),
    .traffic_instr_rw_submode      (traffic_instr_rw_submode),
    .traffic_instr_num_of_iter     (traffic_instr_num_of_iter),
    .traffic_instr_nxt_instr       (traffic_instr_nxt_instr),

    .c0_ddr4_dm_dbi_n              (c0_ddr4_dm_dbi_n),
    .c0_ddr4_dq                    (c0_ddr4_dq),
    .c0_ddr4_dqs_c                 (c0_ddr4_dqs_c),
    .c0_ddr4_dqs_t                 (c0_ddr4_dqs_t),

    .c0_ddr4_ui_clk                (c0_ddr4_clk),
    .c0_ddr4_ui_clk_sync_rst       (c0_ddr4_rst),
    .addn_ui_clkout1               (),
    .dbg_clk                       (dbg_clk),
    .dbg_rd_data_cmp               (dbg_rd_data_cmp),
    .dbg_expected_data             (dbg_expected_data),
    .dbg_cal_seq                   (dbg_cal_seq),
    .dbg_cal_seq_cnt               (dbg_cal_seq_cnt),
    .dbg_cal_seq_rd_cnt            (dbg_cal_seq_rd_cnt),
    .dbg_rd_valid                  (dbg_rd_valid),
    .dbg_cmp_byte                  (dbg_cmp_byte),
    .dbg_rd_data                   (dbg_rd_data),
    .dbg_cplx_config               (dbg_cplx_config),
    .dbg_cplx_status               (dbg_cplx_status),
    .dbg_io_address                (dbg_io_address),
    .dbg_pllGate                   (dbg_pllGate),
    .dbg_phy2clb_fixdly_rdy_low    (dbg_phy2clb_fixdly_rdy_low),
    .dbg_phy2clb_fixdly_rdy_upp    (dbg_phy2clb_fixdly_rdy_upp),
    .dbg_phy2clb_phy_rdy_low       (dbg_phy2clb_phy_rdy_low),
    .dbg_phy2clb_phy_rdy_upp       (dbg_phy2clb_phy_rdy_upp),
    .cal_r0_status                 (cal_r0_status),
    .cal_post_status               (cal_post_status),

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

    .dbg_bus                       (dbg_bus)
  );

  //***************************************************************************
  // Hardware Traffic Generator (HW_TG_EN active)
  //***************************************************************************

  ddr4_v2_2_28_hw_tg #
  (
    .SIMULATION      (SIMULATION),
    .MEM_TYPE        ("DDR4"),
    .APP_DATA_WIDTH  (APP_DATA_WIDTH),
    .APP_ADDR_WIDTH  (APP_ADDR_WIDTH),
    .NUM_DQ_PINS     (16),
    .ECC             (ECC),
    .DEFAULT_MODE    ("2015_3")
  )
  u_hw_tg
  (
    .clk                                (c0_ddr4_clk),
    .rst                                (c0_ddr4_rst),
    .init_calib_complete                (c0_init_calib_complete),
    .app_rdy                            (c0_ddr4_app_rdy),
    .app_wdf_rdy                        (c0_ddr4_app_wdf_rdy),
    .app_rd_data_valid                  (c0_ddr4_app_rd_data_valid),
    .app_rd_data                        (c0_ddr4_app_rd_data),
    .app_cmd                            (c0_ddr4_app_cmd),
    .app_addr                           (c0_ddr4_app_addr),
    .app_en                             (c0_ddr4_app_en),
    .app_wdf_mask                       (c0_ddr4_app_wdf_mask),
    .app_wdf_data                       (c0_ddr4_app_wdf_data),
    .app_wdf_end                        (c0_ddr4_app_wdf_end),
    .app_wdf_wren                       (c0_ddr4_app_wdf_wren),
    .app_wdf_en                         (),
    .app_wdf_addr                       (),
    .app_wdf_cmd                        (),
    .compare_error                      (c0_data_compare_error),

    // VIO_ATG_EN disabled - use fixed/traffic-controlled values
    .vio_tg_rst                         (traffic_rst | tg_reset_x1),
    .vio_tg_start                       (traffic_start),
    .vio_tg_err_chk_en                  (traffic_err_chk_en),
    .vio_tg_err_clear                   (1'b0),
    .vio_tg_instr_addr_mode             (traffic_instr_addr_mode),
    .vio_tg_instr_data_mode             (traffic_instr_data_mode),
    .vio_tg_instr_rw_mode               (traffic_instr_rw_mode),
    .vio_tg_instr_rw_submode            (traffic_instr_rw_submode),
    .vio_tg_instr_num_of_iter           (traffic_instr_num_of_iter),
    .vio_tg_instr_nxt_instr             (traffic_instr_nxt_instr),
    .vio_tg_status_first_err_bit        (traffic_error_tg),
    .vio_tg_restart                     (1'b0),
    .vio_tg_pause                       (1'b0),
    .vio_tg_err_clear_all               (1'b0),
    .vio_tg_err_continue                (1'b0),
    .vio_tg_instr_program_en            (1'b0),
    .vio_tg_direct_instr_en             (1'b0),
    .vio_tg_instr_num                   (5'b00000),
    .vio_tg_instr_victim_mode           (3'b000),
    .vio_tg_instr_victim_aggr_delay     (5'b00000),
    .vio_tg_instr_victim_select         (3'b000),
    .vio_tg_instr_m_nops_btw_n_burst_m  (10'd0),
    .vio_tg_instr_m_nops_btw_n_burst_n  (32'd0),
    .vio_tg_seed_program_en             (1'b0),
    .vio_tg_seed_num                    (8'h00),
    .vio_tg_seed                        (23'd0),
    .vio_tg_glb_victim_bit              (8'h00),
    .vio_tg_glb_start_addr              ({APP_ADDR_WIDTH{1'b0}}),
    .vio_tg_glb_qdriv_rw_submode        (2'b00),

    // Status outputs
    .vio_tg_status_state                (vio_tg_status_state),
    .vio_tg_status_err_bit_valid        (vio_tg_status_err_bit_valid),
    .vio_tg_status_err_bit              (vio_tg_status_err_bit),
    .vio_tg_status_err_cnt              (vio_tg_status_err_cnt),
    .vio_tg_status_err_addr             (vio_tg_status_err_addr),
    .vio_tg_status_exp_bit_valid        (vio_tg_status_exp_bit_valid),
    .vio_tg_status_exp_bit              (vio_tg_status_exp_bit),
    .vio_tg_status_read_bit_valid       (vio_tg_status_read_bit_valid),
    .vio_tg_status_read_bit             (vio_tg_status_read_bit),
    .vio_tg_status_first_err_bit_valid  (vio_tg_status_first_err_bit_valid),
    .vio_tg_status_first_err_addr       (vio_tg_status_first_err_addr),
    .vio_tg_status_first_exp_bit_valid  (vio_tg_status_first_exp_bit_valid),
    .vio_tg_status_first_exp_bit        (vio_tg_status_first_exp_bit),
    .vio_tg_status_first_read_bit_valid (vio_tg_status_first_read_bit_valid),
    .vio_tg_status_first_read_bit       (vio_tg_status_first_read_bit),
    .vio_tg_status_err_bit_sticky_valid (vio_tg_status_err_bit_sticky_valid),
    .vio_tg_status_err_bit_sticky       (vio_tg_status_err_bit_sticky),
    .vio_tg_status_err_cnt_sticky       (vio_tg_status_err_cnt_sticky),
    .vio_tg_status_err_type_valid       (vio_tg_status_err_type_valid),
    .vio_tg_status_err_type             (vio_tg_status_err_type),
    .vio_tg_status_wr_done              (vio_tg_status_wr_done),
    .vio_tg_status_done                 (vio_tg_status_done),
    .vio_tg_status_watch_dog_hang       (vio_tg_status_watch_dog_hang),
    .tg_ila_debug                       (tg_ila_debug),
    .tg_qdriv_submode11_app_rd          (1'b0)
  );

  assign traffic_error = traffic_error_tg;

  //***************************************************************************
  // Debug Core - ILA (SIMULATION disabled, so ILA is active)
  //***************************************************************************

  assign dbg_init_calib_complete = c0_init_calib_complete;
  assign dbg_data_compare_error  = c0_data_compare_error;

  ila_ddrx u_ila_ddrx
  (
    .clk     (c0_ddr4_clk),
    .probe0  (dbg_init_calib_complete),
    .probe1  (dbg_data_compare_error),
    .probe2  (dbg_expected_data),
    .probe3  (dbg_rd_data_cmp),
    .probe4  (dbg_cal_seq),
    .probe5  (dbg_cal_seq_cnt),
    .probe6  (dbg_cal_seq_rd_cnt),
    .probe7  (dbg_rd_valid),
    .probe8  (dbg_cmp_byte),
    .probe9  (dbg_rd_data),
    .probe10 (dbg_cplx_config),
    .probe11 (dbg_cplx_status),
    .probe12 (dbg_io_address),
    .probe13 (dbg_pllGate),
    .probe14 (dbg_phy2clb_fixdly_rdy_low),
    .probe15 (dbg_phy2clb_fixdly_rdy_upp),
    .probe16 (dbg_phy2clb_phy_rdy_low),
    .probe17 (dbg_phy2clb_phy_rdy_upp),
    .probe18 (cal_r0_status),
    .probe19 (cal_post_status)
  );

  //***************************************************************************
  // LED Display Driver
  //***************************************************************************

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
    .system_reset   (system_reset),
    .led            (led[3:0])
  );

endmodule