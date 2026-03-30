//*****************************************************************************
// (c) Copyright 2009 Xilinx, Inc. All rights reserved.
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
//
//*****************************************************************************
//   ____  ____
//  /   /\/   /
// /___/  \  /    Vendor: Xilinx
// \   \   \/     Version: %version
//  \   \         Application: MIG
//  /   /         Filename: led_display_driver.v
// /___/   /\     Date Last Modified: $Date: 2011/03/14 21:31:46 $
// \   \  /  \    Date Created: Aug 03 2009
//  \___\/\___\
//
//Device: Virtex-6
//Design Name: DDR3 SDRAM
//Purpose: Drives discrete LEDs and 7-segment LED on ML660 board to indicate
//         current status of core. Discrete LEDs used to indicate status of
//         calibration, whether an error detected. 7-segment LED does the
//         same, but also increments based on number of data word checks
//         successfully executed (you'll need to fine tune this based on your
//         own application to get a reasonable, and observable, increment
//         rate). Assumes the following LED configuration:
//          1. One 7-segment LED available (7 segments + dec pt) (active low)
//          2. 4 discrete LEDs available (active high)
//Reference:
//Revision History:
//*****************************************************************************

`timescale 1ps / 1ps


`define SEVEN_SEG_0     7'b1000000
`define SEVEN_SEG_1     7'b1111001
`define SEVEN_SEG_2     7'b0100100
`define SEVEN_SEG_3     7'b0110000
`define SEVEN_SEG_4     7'b0011001
`define SEVEN_SEG_5     7'b0010010
`define SEVEN_SEG_6     7'b0000010
`define SEVEN_SEG_7     7'b1111000
`define SEVEN_SEG_8     7'b0000000
`define SEVEN_SEG_9     7'b0011000
`define SEVEN_SEG_A     7'b0001000  // "A"
`define SEVEN_SEG_B     7'b0000011  // "b"
`define SEVEN_SEG_C     7'b0100111  // "c"
`define SEVEN_SEG_D     7'b0100001  // "d"
`define SEVEN_SEG_E     7'b0000110  // "E"
`define SEVEN_SEG_F     7'b0001110  // "F"
`define SEVEN_SEG_CAL   7'b1000110  // "C"
`define SEVEN_SEG_ERROR 7'b0111111  // "-"

module led_display_driver #
  (
   parameter TCQ = 100
  )
  (
   rst,         // global (system) reset
   clk,         // connected to c0_ddr4_clk; 3.333 period, 300 MHz.
   dbg_clk,     // connected to dbg_clk; 13.333 period, 75 MHz.
   init_done_i, // initialization done
   error_i,     // data check fail
   valid_i,     // data read valid
   seven_seg_n,
   seven_seg_dp_n,
   system_reset,
   led
   );

  input        rst;
  input        clk;
  input        dbg_clk;
  input        init_done_i;
  input        error_i;
  input        valid_i;
  output [6:0] seven_seg_n;
  output       seven_seg_dp_n;
  output [3:0] led;
  output       system_reset;
  
  localparam   SEVEN_SEG_0    = 7'b1000000;
  localparam   SEVEN_SEG_1    = 7'b1111001;
  localparam   SEVEN_SEG_2    = 7'b0100100;
  localparam   SEVEN_SEG_3    = 7'b0110000;
  localparam   SEVEN_SEG_4    = 7'b0011001;
  localparam   SEVEN_SEG_5    = 7'b0010010;
  localparam   SEVEN_SEG_6    = 7'b0000010;
  localparam   SEVEN_SEG_7    = 7'b1111000;
  localparam   SEVEN_SEG_8    = 7'b0000000;
  localparam   SEVEN_SEG_9    = 7'b0011000;
  localparam   SEVEN_SEG_A    = 7'b0001000;    // "A"
  localparam   SEVEN_SEG_B    = 7'b0000011;    // "b"
  localparam   SEVEN_SEG_C    = 7'b0100111;    // "c"
  localparam   SEVEN_SEG_D    = 7'b0100001;    // "d"
  localparam   SEVEN_SEG_E    = 7'b0000110;    // "E"
  localparam   SEVEN_SEG_F    = 7'b0001110;    // "F"
  localparam   SEVEN_SEG_CAL  = 7'b1000110;    // "C"
  localparam   SEVEN_SEG_ERROR = 7'b0111111;   // "-"

  localparam   CLK_DIV_CNT_WIDTH = 27;
  localparam   READ_DIV_CNT_WIDTH = 27;

  reg [6:0]    seven_seg_n;
  reg          error_reg;
  reg          memtest_start;
  reg          init_done_r;
  reg [3:0]    led;
  //reg          error_i_reg;
  //reg          valid_i_reg;
  //reg          init_done_i_reg;

  // Synchronizer FFs
  (* ASYNC_REG = "TRUE" *) reg        system_reset_out0;
  (* ASYNC_REG = "TRUE" *) reg        system_reset_out1;
  (* ASYNC_REG = "TRUE" *) reg        system_reset_out2;
  (* ASYNC_REG = "TRUE" *) reg        system_reset_out3;

  (* ASYNC_REG = "TRUE" *) reg        error_i_reg0;
  (* ASYNC_REG = "TRUE" *) reg        error_i_reg1;
  (* ASYNC_REG = "TRUE" *) reg        error_i_reg2;
  (* ASYNC_REG = "TRUE" *) reg        error_i_reg3;

  (* ASYNC_REG = "TRUE" *) reg        valid_i_reg0;
  (* ASYNC_REG = "TRUE" *) reg        valid_i_reg1;
  (* ASYNC_REG = "TRUE" *) reg        valid_i_reg2;
  (* ASYNC_REG = "TRUE" *) reg        valid_i_reg3;

  (* ASYNC_REG = "TRUE" *) reg        init_done_i_reg0;
  (* ASYNC_REG = "TRUE" *) reg        init_done_i_reg1;
  (* ASYNC_REG = "TRUE" *) reg        init_done_i_reg2;
  (* ASYNC_REG = "TRUE" *) reg        init_done_i_reg3;
  
  (* ASYNC_REG = "TRUE" *) reg        reset_in_reg0;
  (* ASYNC_REG = "TRUE" *) reg        reset_in_reg1;
  (* ASYNC_REG = "TRUE" *) reg        reset_in_reg2;
  (* ASYNC_REG = "TRUE" *) reg        reset_in_reg3;

  (* ASYNC_REG = "TRUE" *) reg        cpu_reset_reg0;
  (* ASYNC_REG = "TRUE" *) reg        cpu_reset_reg1;
  (* ASYNC_REG = "TRUE" *) reg        cpu_reset_reg2;
  (* ASYNC_REG = "TRUE" *) reg        cpu_reset_reg3;



  // These counters might be too large for the higher (300MHz+)
  // memory interfaces. If so, then need to generate divided down
  // local clock to use here
  reg [CLK_DIV_CNT_WIDTH-1:0]  clk_div_cnt = 'b0;
  reg [READ_DIV_CNT_WIDTH-1:0] read_div_cnt;
  wire [3:0]                   seven_seg_sel;
  //wire                         clkdiv;
  reg                          valid_div;
  reg                          valid_pulse;
  reg                          valid_pulse_r;
  reg                          valid_toggle;
  reg                          valid_toggle_r;

///////////////////////////////////////////////////////////////////////////////

  /////////////////////////////////////////////////////////////////////////////
  // Discrete LEDs:
  //  led(0) = data check pass
  //  led(1) = divided down system clock
  //  led(2) = data check fail
  //  led(3) = initialization (calibration) done
  /////////////////////////////////////////////////////////////////////////////

  // Use the UltraScale Clock divider in a BUFGCE_DIV. Divide by two.
  //BUFGCE_DIV #(
  //   .BUFGCE_DIVIDE(4),      // 1-8 Set to match dbg_clk; 3.333 x 4 = 13.333
  //   // Programmable Inversion Attributes: Specifies built-in programmable inversion on specific pins
  //   .IS_CE_INVERTED(1'b0),  // Optional inversion for CE
  //   .IS_CLR_INVERTED(1'b0), // Optional inversion for CLR
  //   .IS_I_INVERTED(1'b0)    // Optional inversion for I
  //)
  //BUFGCE_DIV_inst (
  //   .O(clkdiv),     // 1-bit output: Buffer
  //   .CE(1'b1),   // 1-bit input: Buffer enable
  //   .CLR(1'b0), // 1-bit input: Asynchronous clear
  //   .I(clk)      // 1-bit input: Buffer
  //);

  assign system_reset = ( system_reset_out3 );
 
  always @(posedge CFGMCLK) begin
      system_reset_out0 <= (cpu_reset | rst);
      system_reset_out1 <= system_reset_out0;
      system_reset_out2 <= system_reset_out1;
      system_reset_out3 <= system_reset_out2;
  end


  // Divide down fast clock to generate slower clock for display heartbeat
  always @(posedge clk)
    clk_div_cnt <= clk_div_cnt + 1;

  // error flag from memory controller stays high as long as phy initialization
  // is in progress. Once phy init complete, then can toggle high and low as
  // bits are compared. We want LED to stay lit once a single error is
  // encountered

  // CDC Synchronizer logic per UG906 Single-Bit Synchronizer
  // Clock Domain Crossing clk to clk
  // Initial Synchronizer FF 
  always @(posedge clk) begin
      error_i_reg0 <= error_i;
      valid_i_reg0 <= valid_i;
      init_done_i_reg0 <= init_done_i;
  end
  
  // Second Synchronizer FF 
  always @(posedge dbg_clk) begin
      error_i_reg1 <= error_i_reg0;
      valid_i_reg1 <= valid_i_reg0;
      init_done_i_reg1 <= init_done_i_reg0;
  end
  
  // Third Synchronizer FF 
  always @(posedge dbg_clk) begin
      error_i_reg2 <= error_i_reg1;
      valid_i_reg2 <= valid_i_reg1;
      init_done_i_reg2 <= init_done_i_reg1;
  end
  // Fourth Synchronizer FF 
  always @(posedge dbg_clk) begin
      error_i_reg3 <= error_i_reg2;
      valid_i_reg3 <= valid_i_reg2;
      init_done_i_reg3 <= init_done_i_reg2;
  end

  //always @(posedge clk) begin
  //    error_i_reg <= error_i;
  //    valid_i_reg <= valid_i;
  //    init_done_i_reg <= init_done_i;
  //end

  always @(posedge dbg_clk or posedge rst)
    if (rst)
      memtest_start <= 1'b0;
    else if (!memtest_start)
      // wait for ERROR = 0 to tell we've started the memory test (can't
      // look at INIT_DONE_I, it comes slightly earlier than when memory
      // test starts)
      memtest_start <= ~error_i_reg3;

  always @(posedge dbg_clk or posedge rst)
    if (rst)
      error_reg <= 1'b0;
    else if (memtest_start)
      if (!error_reg && error_i_reg3)
        error_reg <= 1'b1;

  always @(posedge dbg_clk)
    init_done_r <= init_done_i_reg3;

  always @(posedge dbg_clk) begin
      led[0] <= memtest_start & (~error_reg);
      led[1] <= clk_div_cnt[CLK_DIV_CNT_WIDTH-1];
      led[2] <= error_reg;
      led[3] <= init_done_r;
  end

  /////////////////////////////////////////////////////////////////////////////
  // 7-segment LEDs:
  //  0-F: Used to indicate progress of data checking
  //  U:   Indicates still in initialization/calibration
  //  -:   Indicates error found
  /////////////////////////////////////////////////////////////////////////////

  always @(posedge dbg_clk or posedge rst) begin
    if (rst) begin
      valid_toggle <= 1'b0;
    end else if (valid_i_reg3)
      valid_toggle <= ~valid_toggle;
  end

  always @(posedge dbg_clk or posedge rst) begin
    if (rst) begin
      valid_toggle_r <= 1'b0;
    end else if (valid_i_reg3)
      valid_toggle_r <= valid_toggle;
  end

  always @(posedge dbg_clk or posedge rst) begin
    if (rst)
      valid_pulse <= 1'b0;
    else
      valid_pulse <= valid_toggle & ~valid_toggle_r;
  end

  always @(posedge dbg_clk or posedge rst) begin
    if (rst)
      valid_pulse_r <= 1'b0;
    else
      valid_pulse_r <= valid_pulse;
  end

  always @(posedge dbg_clk or posedge rst) begin
    if (rst)
      valid_div <= 1'b0;
    else
      valid_div <= valid_pulse | valid_pulse_r;
  end

  // Divide down read
  always @(posedge dbg_clk or posedge rst) begin
    if (rst)
      read_div_cnt <= 0;
    else
      if (valid_div)
        read_div_cnt <= read_div_cnt + 1;
  end

  assign seven_seg_sel = read_div_cnt[READ_DIV_CNT_WIDTH-1:
                                      READ_DIV_CNT_WIDTH-4];

  // Generate 7-segment LED outputs
  always @(error_i_reg3 or init_done_i_reg3 or seven_seg_sel) begin
    if (~init_done_i_reg3)
      seven_seg_n <= SEVEN_SEG_CAL;
    else if (error_i_reg3)
      seven_seg_n <= SEVEN_SEG_ERROR;
    else
      case (seven_seg_sel)
        4'h0: seven_seg_n <= SEVEN_SEG_0;
        4'h1: seven_seg_n <= SEVEN_SEG_1;
        4'h2: seven_seg_n <= SEVEN_SEG_2;
        4'h3: seven_seg_n <= SEVEN_SEG_3;
        4'h4: seven_seg_n <= SEVEN_SEG_4;
        4'h5: seven_seg_n <= SEVEN_SEG_5;
        4'h6: seven_seg_n <= SEVEN_SEG_6;
        4'h7: seven_seg_n <= SEVEN_SEG_7;
        4'h8: seven_seg_n <= SEVEN_SEG_8;
        4'h9: seven_seg_n <= SEVEN_SEG_9;
        4'hA: seven_seg_n <= SEVEN_SEG_A;
        4'hB: seven_seg_n <= SEVEN_SEG_B;
        4'hC: seven_seg_n <= SEVEN_SEG_C;
        4'hD: seven_seg_n <= SEVEN_SEG_D;
        4'hE: seven_seg_n <= SEVEN_SEG_E;
        4'hF: seven_seg_n <= SEVEN_SEG_F;
      endcase
  end

  // Keep decimal point inactive for now
  assign seven_seg_dp_n = 1'b1;

  // VIO Reset; CCLK from startup block continues to run while the VIO core is in reset 
  // and allows this to come out of reset.
  wire reset_in;
  reg cpu_reset;
  reg [3:0] counter;
  wire CFGMCLK;

  vio_leds VIO_inst(
    .clk       (  dbg_clk  ),
    .probe_in0 (  led[3:0]  ),
    .probe_out0(  reset_in  ) //assumes a positive going reset, initialized to 0!!
  );

  // CDC Synchronizer logic per UG906 Single-Bit Synchronizer
  // Clock Domain Crossing dbg_clk to CFGMCLK
  // Initial Synchronizer FF 
  always @(posedge dbg_clk) begin
      reset_in_reg0 <= reset_in;
  end
  // Second Synchronizer FF 
  always @(posedge CFGMCLK) begin
      reset_in_reg1 <= reset_in_reg0;
  end
  // Third Synchronizer FF 
  always @(posedge CFGMCLK) begin
      reset_in_reg2 <= reset_in_reg1;
  end
  // Fourth Synchronizer FF 
  always @(posedge CFGMCLK) begin
      reset_in_reg3 <= reset_in_reg2;
  end

  always @(posedge CFGMCLK)begin :ONESHOT
     if (reset_in_reg3 & counter > 0)	begin
       cpu_reset <= 1;
       counter   <= counter - 1;
    end
    else if (reset_in_reg3 & counter == 0) begin
       cpu_reset <= 0;
       counter   <= 0;
    end
    else begin
       cpu_reset <= 0;
       counter   <= 7;
    end
  end
  	     
  //// CDC Synchronizer logic per UG906 Single-Bit Synchronizer
  //// Clock Domain Crossing CFGMCLK to dbg_clk
  //// Initial Synchronizer FF 
  //always @(posedge CFGMCLK) begin
  //    cpu_reset_reg0 <= cpu_reset;
  //end
  //// Second Synchronizer FF 
  //always @(posedge dbg_clk) begin
  //    cpu_reset_reg1 <= cpu_reset_reg0;
  //end
  //// Third Synchronizer FF 
  //always @(posedge dbg_clk) begin
  //    cpu_reset_reg2 <= cpu_reset_reg1;
  //end
  //// Fourth Synchronizer FF 
  //always @(posedge dbg_clk) begin
  //    cpu_reset_reg3 <= cpu_reset_reg2;
  //end

   // STARTUPE3: UltraScale STARTUP Block
  STARTUPE3 #(
     .PROG_USR("FALSE"),    // Activate program event security feature. Requires encrypted bitstreams.
     .SIM_CCLK_FREQ(0.0)    // Set the Configuration Clock Frequency(ns) for simulation
  )
  STARTUPE3_inst (
     .CFGCLK(),             // 1-bit output: Configuration main clock output
     .CFGMCLK(CFGMCLK),     // 1-bit output: Configuration internal oscillator clock output
     .DI(),                 // 4-bit output: Allow receiving on the D input pin
     .EOS(),                // 1-bit output: Active-High output signal indicating the End Of Startup
     .PREQ(),               // 1-bit output: PROGRAM request to fabric output
     .DO(),                 // 4-bit input: Allows control of the D pin output
     .DTS(),                // 4-bit input: Allows tristate of the D pin
     .FCSBO(),              // 1-bit input: Contols the FCS_B pin for flash access
     .FCSBTS(),             // 1-bit input: Tristate the FCS_B pin
     .GSR(),                // 1-bit input: Global Set/Reset input (GSR cannot be used for the port)
     .GTS(),                // 1-bit input: Global 3-state input (GTS cannot be used for the port name)
     .KEYCLEARB(),          // 1-bit input: Clear AES Decrypter Key input from Battery-Backed RAM (BBRAM)
     .PACK(),               // 1-bit input: PROGRAM acknowledge input
     .USRCCLKO(),           // 1-bit input: User CCLK input
     .USRCCLKTS(),          // 1-bit input: User CCLK 3-state enable input
     .USRDONEO(),           // 1-bit input: User DONE pin output control
     .USRDONETS()           // 1-bit input: User DONE 3-state enable output
  );


  // End of STARTUPE3_inst instantiation
              


endmodule
