`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////
// uart_rx
//
// Simple 8-N-1 UART receiver. Samples the middle of the start bit to sync,
// then samples each of 8 data bits (LSB first) one bit period apart, and
// checks for a valid stop bit. rx_dv pulses for one clk cycle when a byte
// has been received; rx_byte holds it until the next byte arrives.
//
// UART line idles high; a start bit is a falling edge to 0.
//////////////////////////////////////////////////////////////////////////////
module uart_rx #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE   = 115_200
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       rx,        // serial line in (from host TX, board pin B18)
    output reg        rx_dv,     // 1-cycle pulse: rx_byte is valid
    output reg [7:0]  rx_byte
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
    reg [7:0]  rx_shift  = 0;

    // 2-FF synchronizer for the async serial input
    reg rx_meta = 1'b1, rx_sync = 1'b1;
    always @(posedge clk) begin
        rx_meta <= rx;
        rx_sync <= rx_meta;
    end

    always @(posedge clk) begin
        if (rst) begin
            state     <= S_IDLE;
            clk_count <= 0;
            bit_index <= 0;
            rx_dv     <= 1'b0;
            rx_byte   <= 8'h00;
        end else begin
            case (state)
                S_IDLE: begin
                    rx_dv     <= 1'b0;
                    clk_count <= 0;
                    bit_index <= 0;
                    if (rx_sync == 1'b0)
                        state <= S_START_BIT;
                end

                // wait half a bit period, then confirm the line is still low
                S_START_BIT: begin
                    if (clk_count == (CLKS_PER_BIT - 1) / 2) begin
                        if (rx_sync == 1'b0) begin
                            clk_count <= 0;
                            state     <= S_DATA_BITS;
                        end else begin
                            state <= S_IDLE; // false start (glitch)
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                S_DATA_BITS: begin
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count             <= 0;
                        rx_shift[bit_index]   <= rx_sync;
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1'b1;
                        end else begin
                            bit_index <= 0;
                            state     <= S_STOP_BIT;
                        end
                    end
                end

                S_STOP_BIT: begin
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 0;
                        rx_byte   <= rx_shift;
                        rx_dv     <= 1'b1;
                        state     <= S_CLEANUP;
                    end
                end

                S_CLEANUP: begin
                    rx_dv <= 1'b0;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
