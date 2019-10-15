/*
	hd44780 state timer

*/
`default_nettype	none

//new way with include

`ifndef SIM_STEP
`include "./hd44780_build_config.inc"
`else
`include "./hd44780_sim_config.inc"
`endif

//e.g.
// "long" delays needed for LCD initialization, in clock ticks
// `define H4_SYSFREQ       (48000000)
// `define H4_DELAY_53US    (2544)
// `define H4_DELAY_100MS   (4800000)
// `define H4_DELAY_4P1MS   (196800)
// `define H4_DELAY_3MS     (144000)
// `define H4_DELAY_100US   (4800)
// `define H4_TIMER_BITS    (23)
//
// //short delays for hd44780 nybble sender, in clock ticks
// `define H4NS_TICKS_TAS   (3)
// `define H4NS_TICKS_TCYCE (48)
// `define H4NS_TICKS_PWEH  (22)
// `define H4NS_COUNT_BITS  (6)


//*************************************************************************************
//aha, it's the backtick before referring to a define that makes them work like numbers
//*************************************************************************************

module hd44780_state_timer  #(parameter SYSFREQ = `H4_SYSFREQ, parameter STATE_TIMER_BITS = `H4_TIMER_BITS)
(
    input wire RST_I,
    input wire CLK_I,
	input wire [STATE_TIMER_BITS-1:0] DAT_I,	//[STATE_TIMER_BITS-1:0] DAT_I,
    input wire start_strobe,            // causes timer to load
    output wire busy             // nudges caller to advance state
    );

    reg [`H4_TIMER_BITS-1:0] st_count = 0;
    reg busy_reg = 0;

	always @(posedge CLK_I) begin
		if(RST_I == 1) begin
			st_count <= 0;
			busy_reg <= 0;
            //strobe_dropped <= 0;
		end else begin
            if(start_strobe) begin
                st_count <= DAT_I;
    			busy_reg <= 1;
            end else if(|st_count) begin
    			st_count <= st_count-1;
		    end else begin
    			//counter is 0
                busy_reg <= 0;
	        end
        end
	end

    assign busy = busy_reg;

endmodule
