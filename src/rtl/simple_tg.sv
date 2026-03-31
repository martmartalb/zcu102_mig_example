`timescale 1ps/1ps

module simple_tg #(
  parameter APP_ADDR_WIDTH = 28,
  parameter APP_DATA_WIDTH = 128,
  parameter APP_MASK_WIDTH = 16,
  parameter NUM_TRANSACTIONS = 8
)(
  input  wire                        clk,
  input  wire                        rst,
  input  wire                        init_calib_complete,

  // MIG app interface
  input  wire                        app_rdy,
  input  wire                        app_wdf_rdy,
  input  wire [APP_DATA_WIDTH-1:0]   app_rd_data,
  input  wire                        app_rd_data_valid,
  input  wire                        app_rd_data_end,

  output reg  [APP_ADDR_WIDTH-1:0]   app_addr,
  output reg  [2:0]                  app_cmd,
  output reg                         app_en,
  output reg  [APP_DATA_WIDTH-1:0]   app_wdf_data,
  output reg                         app_wdf_end,
  output reg  [APP_MASK_WIDTH-1:0]   app_wdf_mask,
  output reg                         app_wdf_wren,

  // Status
  output wire                        done,
  output wire                        error
);

  localparam CMD_WRITE = 3'b000;
  localparam CMD_READ  = 3'b001;

  // Address step: 8 bytes per BL8 beat x (APP_DATA_WIDTH/8) bytes per UI word = 16 bytes
  // MIG address is byte-aligned, step by 0x10 (16) for 128-bit data width
  localparam [APP_ADDR_WIDTH-1:0] ADDR_STEP = 'd16;

  // FSM states
  localparam S_IDLE       = 3'd0;
  localparam S_WRITE      = 3'd1;
  localparam S_WRITE_WAIT = 3'd2;
  localparam S_READ       = 3'd3;
  localparam S_READ_WAIT  = 3'd4;
  localparam S_DONE       = 3'd5;

  reg [2:0]  state;
  reg [$clog2(NUM_TRANSACTIONS)-1:0] wr_cnt;
  reg [$clog2(NUM_TRANSACTIONS)-1:0] rd_cmd_cnt;
  reg [$clog2(NUM_TRANSACTIONS)-1:0] rd_data_cnt;
  reg        error_reg;
  reg        done_reg;

  // Hardcoded test data: each entry is a 128-bit pattern
  function [APP_DATA_WIDTH-1:0] test_data(input [$clog2(NUM_TRANSACTIONS)-1:0] idx);
    case (idx)
      0: test_data = 128'hDEAD_BEEF_CAFE_BABE_0123_4567_89AB_CDEF;
      1: test_data = 128'hA5A5_A5A5_5A5A_5A5A_1234_5678_9ABC_DEF0;
      2: test_data = 128'hFFFF_FFFF_0000_0000_FFFF_FFFF_0000_0000;
      3: test_data = 128'h0000_0000_FFFF_FFFF_0000_0000_FFFF_FFFF;
      4: test_data = 128'h0123_4567_89AB_CDEF_FEDC_BA98_7654_3210;
      5: test_data = 128'hAAAA_AAAA_5555_5555_AAAA_AAAA_5555_5555;
      6: test_data = 128'h1111_2222_3333_4444_5555_6666_7777_8888;
      7: test_data = 128'hFEDC_BA98_7654_3210_0123_4567_89AB_CDEF;
      default: test_data = {APP_DATA_WIDTH{1'b0}};
    endcase
  endfunction

  assign done  = done_reg;
  assign error = error_reg;

  always @(posedge clk) begin
    if (rst) begin
      state       <= S_IDLE;
      app_addr    <= {APP_ADDR_WIDTH{1'b0}};
      app_cmd     <= CMD_WRITE;
      app_en      <= 1'b0;
      app_wdf_data <= {APP_DATA_WIDTH{1'b0}};
      app_wdf_end <= 1'b0;
      app_wdf_mask <= {APP_MASK_WIDTH{1'b0}};
      app_wdf_wren <= 1'b0;
      wr_cnt      <= 0;
      rd_cmd_cnt  <= 0;
      rd_data_cnt <= 0;
      error_reg   <= 1'b0;
      done_reg    <= 1'b0;
    end else begin
      case (state)

        // ---------------------------------------------------------------
        S_IDLE: begin
          if (init_calib_complete) begin
            state       <= S_WRITE;
            wr_cnt      <= 0;
            app_addr    <= {APP_ADDR_WIDTH{1'b0}};
            app_cmd     <= CMD_WRITE;
            app_en      <= 1'b1;
            app_wdf_data <= test_data(0);
            app_wdf_mask <= {APP_MASK_WIDTH{1'b0}};  // write all bytes
            app_wdf_wren <= 1'b1;
            app_wdf_end  <= 1'b1;
          end
        end

        // ---------------------------------------------------------------
        // Issue write command + data in the same cycle.
        // Only advance when both app_rdy and app_wdf_rdy accept.
        S_WRITE: begin
          if (app_rdy && app_wdf_rdy) begin
            if (wr_cnt == NUM_TRANSACTIONS - 1) begin
              // All writes issued, move to read phase
              app_en       <= 1'b0;
              app_wdf_wren <= 1'b0;
              app_wdf_end  <= 1'b0;
              state        <= S_WRITE_WAIT;
            end else begin
              wr_cnt       <= wr_cnt + 1;
              app_addr     <= app_addr + ADDR_STEP;
              app_wdf_data <= test_data(wr_cnt + 1);
            end
          end
        end

        // ---------------------------------------------------------------
        // Small gap between writes and reads
        S_WRITE_WAIT: begin
          state      <= S_READ;
          rd_cmd_cnt <= 0;
          rd_data_cnt <= 0;
          app_addr   <= {APP_ADDR_WIDTH{1'b0}};
          app_cmd    <= CMD_READ;
          app_en     <= 1'b1;
        end

        // ---------------------------------------------------------------
        // Issue read commands
        S_READ: begin
          if (app_rdy) begin
            if (rd_cmd_cnt == NUM_TRANSACTIONS - 1) begin
              app_en <= 1'b0;
              state  <= S_READ_WAIT;
            end else begin
              rd_cmd_cnt <= rd_cmd_cnt + 1;
              app_addr   <= app_addr + ADDR_STEP;
            end
          end

          // Check returning read data (can arrive while we still issue commands)
          if (app_rd_data_valid) begin
            if (app_rd_data != test_data(rd_data_cnt))
              error_reg <= 1'b1;
            rd_data_cnt <= rd_data_cnt + 1;
          end
        end

        // ---------------------------------------------------------------
        // Wait for remaining read data to return
        S_READ_WAIT: begin
          if (app_rd_data_valid) begin
            if (app_rd_data != test_data(rd_data_cnt))
              error_reg <= 1'b1;
            rd_data_cnt <= rd_data_cnt + 1;
            if (rd_data_cnt == NUM_TRANSACTIONS - 1)
              state <= S_DONE;
          end
        end

        // ---------------------------------------------------------------
        S_DONE: begin
          done_reg <= 1'b1;
        end

        default: state <= S_IDLE;

      endcase
    end
  end

endmodule
