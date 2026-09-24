`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////
// uart_tx
//
// Simple 8-N-1 UART transmitter. Pulse tx_dv for one clk cycle with
// tx_byte held valid to send a byte; tx_active stays high until the stop
// bit has been sent, tx_done pulses for one clk cycle when finished.
//////////////////////////////////////////////////////////////////////////////
module uart_tx #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE   = 115_200
) (
    input  wire       clk,
    input  wire       rst,
    input  wire        tx_dv,     // 1-cycle pulse: start sending tx_byte
    input  wire [7:0]  tx_byte,
    output reg          tx,        // serial line out (to host RX, board pin A18)
    output reg          tx_active,
    output reg          tx_done
);

    localparam integer CLKS_PER_BIT = CLK_FREQ_HZ / BAUD_RATE;

    localparam [2:0]
        S_IDLE      = 3'd0,
        S_START_BIT = 3'd1,
        S_DATA_BITS = 3'd2,
        S_STOP_BIT  = 3'd3,
        S_CLEANUP   = 3'd4;

    reg [2:0]  state = S_IDLE;
    reg [$clog2(CLKS_PER_BIT)-1:0] clk_count = 0;
    reg [2:0]  bit_index = 0;
    reg [7:0]  tx_shift  = 0;

    always @(posedge clk) begin
        if (rst) begin
            state     <= S_IDLE;
            clk_count <= 0;
            bit_index <= 0;
            tx        <= 1'b1; // idle high
            tx_active <= 1'b0;
            tx_done   <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    tx      <= 1'b1;
                    tx_done <= 1'b0;
                    clk_count <= 0;
                    bit_index <= 0;
                    if (tx_dv) begin
                        tx_shift  <= tx_byte;
                        tx_active <= 1'b1;
                        state     <= S_START_BIT;
                    end
                end

                S_START_BIT: begin
                    tx <= 1'b0;
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 0;
                        state     <= S_DATA_BITS;
                    end
                end

                S_DATA_BITS: begin
                    tx <= tx_shift[bit_index];
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 0;
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1'b1;
                        end else begin
                            bit_index <= 0;
                            state     <= S_STOP_BIT;
                        end
                    end
                end

                S_STOP_BIT: begin
                    tx <= 1'b1;
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 0;
                        tx_active <= 1'b0;
                        tx_done   <= 1'b1;
                        state     <= S_CLEANUP;
                    end
                end

                S_CLEANUP: begin
                    tx_done <= 1'b0;
                    state   <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
