`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////
// seven_seg_hex
//
// Drives the Basys 3's 4-digit, common-anode 7-segment display. digits[]
// holds the four hex nibbles to show (digit 0 = rightmost). refresh_tick
// toggling steps a 2-bit scan counter that time-multiplexes which digit is
// active; persistence of vision makes all four appear lit at once.
//
// seg/an are active-low, matching the Basys 3 hardware.
//////////////////////////////////////////////////////////////////////////////
module seven_seg_hex (
    input  wire       clk,
    input  wire       rst,
    input  wire        refresh_tick,
    input  wire [15:0] digits,       // {digit3, digit2, digit1, digit0}
    output reg  [6:0]  seg,          // {seg[6:0]} = {CG,CF,CE,CD,CC,CB,CA} active-low
    output reg         dp,
    output reg  [3:0]  an            // active-low digit enables
);

    reg [1:0] scan = 2'b00;
    reg       refresh_prev = 1'b0;

    wire [3:0] nibble = (scan == 2'b00) ? digits[3:0]   :
                        (scan == 2'b01) ? digits[7:4]   :
                        (scan == 2'b10) ? digits[11:8]  :
                                          digits[15:12];

    always @(posedge clk) begin
        if (rst) begin
            scan         <= 2'b00;
            refresh_prev <= 1'b0;
        end else begin
            refresh_prev <= refresh_tick;
            if (refresh_tick != refresh_prev)
                scan <= scan + 1'b1;
        end
    end

    always @(*) begin
        case (scan)
            2'b00: an = 4'b1110; // AN0 active
            2'b01: an = 4'b1101; // AN1 active
            2'b10: an = 4'b1011; // AN2 active
            default: an = 4'b0111; // AN3 active
        endcase
    end

    always @(*) begin
        dp = 1'b1; // decimal points unused, keep off (active-low)
        case (nibble)
            4'h0: seg = 7'b1000000;
            4'h1: seg = 7'b1111001;
            4'h2: seg = 7'b0100100;
            4'h3: seg = 7'b0110000;
            4'h4: seg = 7'b0011001;
            4'h5: seg = 7'b0010010;
            4'h6: seg = 7'b0000010;
            4'h7: seg = 7'b1111000;
            4'h8: seg = 7'b0000000;
            4'h9: seg = 7'b0010000;
            4'hA: seg = 7'b0001000;
            4'hB: seg = 7'b0000011;
            4'hC: seg = 7'b1000110;
            4'hD: seg = 7'b0100001;
            4'hE: seg = 7'b0000110;
            default: seg = 7'b0001110; // F
        endcase
    end

endmodule
