`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////
// top
//
// Basys 3 sample / "hello world" project, extended with a UART test
// harness.
//
//   - sw[15:0]  -> led[15:0]   direct pass-through, confirms switches & LEDs
//   - btnC                     synchronous reset for the seconds counter
//   - free-running 1 Hz tick increments a 16-bit counter, shown in hex on
//     the 4-digit 7-segment display
//   - RsRx/RsTx                onboard USB-UART bridge (no external wiring):
//                               a host PC script can read sw[]/the counter
//                               and trigger a reset over the same USB cable
//                               used to program the board. See
//                               src/uart_test_harness.v for the protocol.
//
// Board:  Digilent Basys 3 (Xilinx Artix-7 XC7A35T-1CPG236C)
// Clock:  100 MHz onboard oscillator, pin W5 (see constraints/Basys3_Master.xdc)
//////////////////////////////////////////////////////////////////////////////
module top (
    input  wire        clk,        // 100 MHz onboard clock, pin W5
    input  wire        btnC,       // center button - synchronous reset
    input  wire [15:0] sw,         // 16 slide switches
    output wire [15:0] led,        // 16 LEDs
    output wire [6:0]  seg,        // 7-segment cathodes
    output wire        dp,         // 7-segment decimal point
    output wire [3:0]  an,         // 7-segment digit anodes
    input  wire        RsRx,       // UART in, from host TX (pin B18)
    output wire        RsTx        // UART out, to host RX  (pin A18)
);

    // ---------------------------------------------------------------
    // Reset synchronizer (2-FF) for the active-high btnC input
    // ---------------------------------------------------------------
    reg rst_ff1 = 1'b0, rst = 1'b0;
    always @(posedge clk) begin
        rst_ff1 <= btnC;
        rst     <= rst_ff1;
    end

    // ---------------------------------------------------------------
    // Switches drive the LEDs directly
    // ---------------------------------------------------------------
    assign led = sw;

    // ---------------------------------------------------------------
    // Timing generation
    // ---------------------------------------------------------------
    wire refresh_tick;
    wire seconds_tick;

    clock_divider #(
        .CLK_FREQ_HZ (100_000_000),
        .REFRESH_HZ  (1_000),
        .SECOND_HZ   (1)
    ) u_clock_divider (
        .clk          (clk),
        .rst          (rst),
        .refresh_tick (refresh_tick),
        .seconds_tick (seconds_tick)
    );

    // ---------------------------------------------------------------
    // 16-bit free-running seconds counter
    // (soft_reset comes from the UART harness's 'R' command, and only
    //  clears the counter - it does not touch the rest of the system, so
    //  it can't stomp on an in-flight UART transaction)
    // ---------------------------------------------------------------
    wire       soft_reset;
    reg [15:0] seconds_count = 16'h0000;
    always @(posedge clk) begin
        if (rst || soft_reset)
            seconds_count <= 16'h0000;
        else if (seconds_tick)
            seconds_count <= seconds_count + 1'b1;
    end

    // ---------------------------------------------------------------
    // 7-segment display driver
    // ---------------------------------------------------------------
    seven_seg_hex u_seven_seg_hex (
        .clk          (clk),
        .rst          (rst),
        .refresh_tick (refresh_tick),
        .digits       (seconds_count),
        .seg          (seg),
        .dp           (dp),
        .an           (an)
    );

    // ---------------------------------------------------------------
    // UART test harness (115200 8N1 over the onboard USB-UART bridge)
    // ---------------------------------------------------------------
    wire       rx_dv;
    wire [7:0] rx_byte;
    wire       tx_dv;
    wire [7:0] tx_byte;
    wire       tx_active;
    wire       tx_done;

    uart_rx #(
        .CLK_FREQ_HZ (100_000_000),
        .BAUD_RATE   (115_200)
    ) u_uart_rx (
        .clk     (clk),
        .rst     (rst),
        .rx      (RsRx),
        .rx_dv   (rx_dv),
        .rx_byte (rx_byte)
    );

    uart_tx #(
        .CLK_FREQ_HZ (100_000_000),
        .BAUD_RATE   (115_200)
    ) u_uart_tx (
        .clk       (clk),
        .rst       (rst),
        .tx_dv     (tx_dv),
        .tx_byte   (tx_byte),
        .tx        (RsTx),
        .tx_active (tx_active),
        .tx_done   (tx_done)
    );

    uart_test_harness u_uart_test_harness (
        .clk           (clk),
        .rst           (rst),
        .rx_dv         (rx_dv),
        .rx_byte       (rx_byte),
        .tx_dv         (tx_dv),
        .tx_byte       (tx_byte),
        .tx_active     (tx_active),
        .tx_done       (tx_done),
        .sw            (sw),
        .seconds_count (seconds_count),
        .soft_reset    (soft_reset)
    );

endmodule
