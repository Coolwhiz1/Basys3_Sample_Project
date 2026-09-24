`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////
// uart_test_harness
//
// Tiny command/response protocol over the Basys 3's onboard USB-UART bridge
// (RsRx/RsTx, pins B18/A18 - no external wiring needed, it's the same USB
// cable used to program the board). Meant as a stand-in for a host-driven
// automated test setup: a PC script sends single-byte ASCII commands and
// checks the response against what it expects, the same way a bench ATE
// script talks to a unit under test.
//
// Commands (host -> FPGA, 1 byte each):
//   'S' (0x53) -> FPGA replies 2 bytes: {sw[15:8], sw[7:0]}
//   'C' (0x43) -> FPGA replies 2 bytes: {seconds_count[15:8], seconds_count[7:0]}
//   'R' (0x52) -> pulses soft_reset (clears the seconds counter), replies "OK"
//   'T' (0x54) -> replies 1 byte 0x01 (a placeholder self-test/BIST pass code)
//   anything else -> replies 1 byte '?' (0x3F)
//////////////////////////////////////////////////////////////////////////////
module uart_test_harness (
    input  wire        clk,
    input  wire        rst,

    // from uart_rx
    input  wire        rx_dv,
    input  wire [7:0]  rx_byte,

    // to/from uart_tx
    output reg          tx_dv,
    output reg  [7:0]   tx_byte,
    input  wire         tx_active,
    input  wire         tx_done,

    // design under test hooks
    input  wire [15:0] sw,
    input  wire [15:0] seconds_count,
    output reg          soft_reset
);

    localparam [7:0]
        CMD_SW       = 8'h53, // 'S'
        CMD_COUNT    = 8'h43, // 'C'
        CMD_RESET    = 8'h52, // 'R'
        CMD_SELFTEST = 8'h54; // 'T'

    localparam [1:0]
        S_WAIT       = 2'd0,
        S_SEND_START = 2'd1,
        S_SEND_WAIT  = 2'd2;

    reg [1:0] state = S_WAIT;
    reg [7:0] resp_data [0:1];
    reg [1:0] resp_len  = 2'd0;
    reg [1:0] resp_idx  = 2'd0;

    always @(posedge clk) begin
        if (rst) begin
            state      <= S_WAIT;
            tx_dv      <= 1'b0;
            tx_byte    <= 8'h00;
            soft_reset <= 1'b0;
            resp_len   <= 2'd0;
            resp_idx   <= 2'd0;
        end else begin
            tx_dv      <= 1'b0; // default: single-cycle pulse only
            soft_reset <= 1'b0; // default: single-cycle pulse only

            case (state)
                S_WAIT: begin
                    if (rx_dv) begin
                        resp_idx <= 2'd0;
                        case (rx_byte)
                            CMD_SW: begin
                                resp_data[0] <= sw[15:8];
                                resp_data[1] <= sw[7:0];
                                resp_len     <= 2'd2;
                            end
                            CMD_COUNT: begin
                                resp_data[0] <= seconds_count[15:8];
                                resp_data[1] <= seconds_count[7:0];
                                resp_len     <= 2'd2;
                            end
                            CMD_RESET: begin
                                soft_reset   <= 1'b1;
                                resp_data[0] <= "O";
                                resp_data[1] <= "K";
                                resp_len     <= 2'd2;
                            end
                            CMD_SELFTEST: begin
                                resp_data[0] <= 8'h01;
                                resp_len     <= 2'd1;
                            end
                            default: begin
                                resp_data[0] <= "?";
                                resp_len     <= 2'd1;
                            end
                        endcase
                        state <= S_SEND_START;
                    end
                end

                S_SEND_START: begin
                    if (!tx_active) begin
                        tx_byte <= resp_data[resp_idx];
                        tx_dv   <= 1'b1;
                        state   <= S_SEND_WAIT;
                    end
                end

                S_SEND_WAIT: begin
                    if (tx_done) begin
                        if (resp_idx + 1'b1 < resp_len) begin
                            resp_idx <= resp_idx + 1'b1;
                            state    <= S_SEND_START;
                        end else begin
                            state <= S_WAIT;
                        end
                    end
                end

                default: state <= S_WAIT;
            endcase
        end
    end

endmodule
