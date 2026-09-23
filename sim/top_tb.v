`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////
// top_tb
//
// Simple simulation testbench for the Basys3 sample project's top module.
// Drives a 100 MHz clock, pulses reset, wiggles the switches, and checks
// that led[] tracks sw[] combinationally. Run in the Vivado simulator
// (or any Verilog simulator) - this is not synthesized.
//////////////////////////////////////////////////////////////////////////////
module top_tb;

    reg         clk = 1'b0;
    reg         btnC = 1'b0;
    reg  [15:0] sw = 16'h0000;
    wire [15:0] led;
    wire [6:0]  seg;
    wire        dp;
    wire [3:0]  an;

    // 100 MHz clock -> 10 ns period
    always #5 clk = ~clk;

    top dut (
        .clk  (clk),
        .btnC (btnC),
        .sw   (sw),
        .led  (led),
        .seg  (seg),
        .dp   (dp),
        .an   (an)
    );

    integer errors = 0;

    task check_led_matches_sw;
        begin
            #1; // let combinational assign settle
            if (led !== sw) begin
                errors = errors + 1;
                $display("[%0t] FAIL: led=%h expected=%h", $time, led, sw);
            end else begin
                $display("[%0t] PASS: led=%h", $time, led);
            end
        end
    endtask

    initial begin
        // hold reset for a few clocks
        btnC = 1'b1;
        repeat (5) @(posedge clk);
        btnC = 1'b0;

        // sw -> led pass-through checks
        sw = 16'h0000; @(posedge clk); check_led_matches_sw;
        sw = 16'hFFFF; @(posedge clk); check_led_matches_sw;
        sw = 16'hA5A5; @(posedge clk); check_led_matches_sw;
        sw = 16'h1234; @(posedge clk); check_led_matches_sw;

        // let the design run long enough to see the 7-seg mux and at least
        // the start of the seconds counter behavior in waveforms
        #100000;

        if (errors == 0)
            $display("*** ALL TESTS PASSED ***");
        else
            $display("*** %0d TEST(S) FAILED ***", errors);

        $finish;
    end

endmodule
