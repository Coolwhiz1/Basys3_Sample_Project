`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////
// uart_test_harness_tb
//
// Self-checking simulation testbench for the UART command/response
// protocol. Bit-bangs UART frames onto the top-level DUT's RsRx pin (as if
// it were the host PC's serial TX) and decodes frames coming back out of
// RsTx, checking each response against what src/uart_test_harness.v is
// supposed to send. Not synthesized - simulation only.
//
// NOTE: this only exercises the UART protocol itself (bytes in -> bytes
// out), not the real-time 1 Hz seconds counter, which would take a full
// second of simulated time to observe ticking. sim/top_tb.v and the
// python/basys3_test_harness.py hardware test cover that instead.
//////////////////////////////////////////////////////////////////////////////
module uart_test_harness_tb;

    localparam integer CLKS_PER_BIT = 868;             // matches DUT: 100e6 / 115200
    localparam integer BIT_PERIOD   = CLKS_PER_BIT * 10; // ns, DUT clk period is 10ns

    reg         clk = 1'b0;
    reg         btnC = 1'b0;
    reg  [15:0] sw = 16'h0000;
    reg         dut_rx = 1'b1; // idle high
    wire        dut_tx;
    wire [15:0] led;
    wire [6:0]  seg;
    wire        dp;
    wire [3:0]  an;

    always #5 clk = ~clk; // 100 MHz

    top dut (
        .clk  (clk),
        .btnC (btnC),
        .sw   (sw),
        .led  (led),
        .seg  (seg),
        .dp   (dp),
        .an   (an),
        .RsRx (dut_rx),
        .RsTx (dut_tx)
    );

    integer errors = 0;

    // Drive one UART frame (start + 8 data bits LSB-first + stop) onto dut_rx
    task send_byte(input [7:0] data);
        integer i;
        begin
            dut_rx = 1'b0;              // start bit
            #(BIT_PERIOD);
            for (i = 0; i < 8; i = i + 1) begin
                dut_rx = data[i];
                #(BIT_PERIOD);
            end
            dut_rx = 1'b1;               // stop bit
            #(BIT_PERIOD);
        end
    endtask

    // Wait for and decode one UART frame from dut_tx
    task recv_byte(output [7:0] data);
        integer i;
        begin
            @(negedge dut_tx);           // start bit edge
            #(BIT_PERIOD / 2);           // move to mid start-bit
            for (i = 0; i < 8; i = i + 1) begin
                #(BIT_PERIOD);
                data[i] = dut_tx;
            end
            #(BIT_PERIOD);               // stop bit
        end
    endtask

    task check_byte(input [7:0] got, input [7:0] expected, input [127:0] label);
        begin
            if (got !== expected) begin
                errors = errors + 1;
                $display("[%0t] FAIL %0s: got=%02h expected=%02h", $time, label, got, expected);
            end else begin
                $display("[%0t] PASS %0s: %02h", $time, label, got);
            end
        end
    endtask

    reg [7:0] resp0, resp1;

    initial begin
        // hold reset for a few clocks
        btnC = 1'b1;
        repeat (5) @(posedge clk);
        btnC = 1'b0;
        repeat (5) @(posedge clk);

        // 'S' -> switch readback, MSB then LSB
        sw = 16'hBEEF;
        send_byte("S");
        recv_byte(resp0); check_byte(resp0, 8'hBE, "S resp[0] (sw MSB)");
        recv_byte(resp1); check_byte(resp1, 8'hEF, "S resp[1] (sw LSB)");

        // 'C' -> counter readback; still 0x0000 this early in sim time
        send_byte("C");
        recv_byte(resp0); check_byte(resp0, 8'h00, "C resp[0] (count MSB)");
        recv_byte(resp1); check_byte(resp1, 8'h00, "C resp[1] (count LSB)");

        // 'R' -> soft reset, replies "OK"
        send_byte("R");
        recv_byte(resp0); check_byte(resp0, "O", "R resp[0]");
        recv_byte(resp1); check_byte(resp1, "K", "R resp[1]");

        // 'T' -> self-test / BIST placeholder, single byte 0x01
        send_byte("T");
        recv_byte(resp0); check_byte(resp0, 8'h01, "T resp[0]");

        // unknown command -> '?'
        send_byte("Z");
        recv_byte(resp0); check_byte(resp0, "?", "unknown cmd resp[0]");

        // change switches and re-check 'S' still tracks them live
        sw = 16'h1234;
        send_byte("S");
        recv_byte(resp0); check_byte(resp0, 8'h12, "S resp[0] after sw change");
        recv_byte(resp1); check_byte(resp1, 8'h34, "S resp[1] after sw change");

        if (errors == 0)
            $display("*** ALL TESTS PASSED ***");
        else
            $display("*** %0d TEST(S) FAILED ***", errors);

        $finish;
    end

endmodule
