`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////
// clock_divider
//
// Free-running counter used to derive slower "tick" pulses from the
// Basys 3's 100 MHz onboard oscillator (pin W5). Two pulses are produced:
//   refresh_tick - toggles fast enough to multiplex the 4-digit 7-segment
//                  display without visible flicker (~1 kHz)
//   seconds_tick - a single-cycle pulse once per second, used to advance
//                  the demo counter shown on the display
//////////////////////////////////////////////////////////////////////////////
module clock_divider #(
    parameter integer CLK_FREQ_HZ   = 100_000_000,
    parameter integer REFRESH_HZ    = 1_000,
    parameter integer SECOND_HZ     = 1
) (
    input  wire clk,
    input  wire rst,
    output reg  refresh_tick,
    output reg  seconds_tick
);

    // refresh_tick is a toggling square wave (2 edges per period), so it
    // needs the /2 to hit REFRESH_HZ. seconds_tick is a single-cycle pulse
    // generated once every SECOND_DIV clocks, so no /2 there.
    localparam integer REFRESH_DIV = CLK_FREQ_HZ / (REFRESH_HZ * 2);
    localparam integer SECOND_DIV  = CLK_FREQ_HZ / SECOND_HZ;

    reg [$clog2(REFRESH_DIV)-1:0] refresh_cnt = 0;
    reg [$clog2(SECOND_DIV)-1:0]  second_cnt  = 0;

    always @(posedge clk) begin
        if (rst) begin
            refresh_cnt  <= 0;
            refresh_tick <= 1'b0;
        end else if (refresh_cnt == REFRESH_DIV - 1) begin
            refresh_cnt  <= 0;
            refresh_tick <= ~refresh_tick;
        end else begin
            refresh_cnt <= refresh_cnt + 1'b1;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            second_cnt   <= 0;
            seconds_tick <= 1'b0;
        end else if (second_cnt == SECOND_DIV - 1) begin
            second_cnt   <= 0;
            seconds_tick <= 1'b1;
        end else begin
            second_cnt   <= second_cnt + 1'b1;
            seconds_tick <= 1'b0;
        end
    end

endmodule
