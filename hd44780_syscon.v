//hd44780 syscon

module hd44780_syscon(
    input i_clk,
    output RST_O,
    output CLK_O
);

// SYSCON ============================================================================================================================
// Wishbone-like syscon responsible for clock and reset.

//after https://electronics.stackexchange.com/questions/405363/is-it-possible-to-generate-internal-RST_O-pulse-in-verilog-with-machxo3lf-fpga
//tis worky, drops RST_O to 0 at 15 clocks. ADJUST THIS IF IT'S INSUFFICIENT. may want to differ with frequency, but it's an on-chip thing so many not need to
//so long as the speed check passes
reg [3:0] rst_cnt = 0;
wire RST_O = ~rst_cnt[3];       // My RST_O is active high, original was active low; I think that's why it was called rst_n
wire CLK_O;                     // avoid default_nettype error
always @(posedge CLK_O)         // see if I can use the output that way
    if( RST_O )                 // active high RST_O
        rst_cnt <= rst_cnt + 1;

assign CLK_O = i_clk;
// END SYSCON ========================================================================================================================

endmodule
