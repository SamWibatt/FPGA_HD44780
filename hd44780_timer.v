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
    output wire end_strobe             // nudges caller to advance state
    );

    reg [`H4_TIMER_BITS-1:0] st_count = 0;
    reg end_strobe_reg = 0;
    reg dat_was_0 = 0;      //silly thing to keep the output strobe only last for 1 cycle
    reg strobe_dropped = 0; //this is a way to not start counting down until an additional tick after strobe drops.
                            //trying to make it so count of ticks is n *after strobe drops*, currently it's n-1 after drop
                            //ok now it works better

    //would it be better to redo this as a state machine?


	always @(posedge CLK_I) begin
		if(RST_I == 1) begin
			st_count <= 0;
			end_strobe_reg <= 0;
            strobe_dropped <= 0;
		end else begin
            if(start_strobe) begin
                st_count <= DAT_I;
    			end_strobe_reg <= 0;
                if(DAT_I) begin
                    strobe_dropped <= 0;
                end else begin
                    dat_was_0 <= 1;         //this
                    strobe_dropped <= 1;    //mechanism for sending a end strobe if we get a 0 in, which we shouldn't
                end
            end else if(|st_count) begin
                if(~strobe_dropped) begin
                    strobe_dropped <= 1;         //dumb wait state mechanism, makes it so we get DAT_I ticks after strobe drops
        		end else begin
        			//count is not 0 - raise strobe in the last tick before it goes 0
                    //do I need to do this? Yes.
        			if(st_count == 1) begin
        				end_strobe_reg <= 1;
        			end
        			st_count <= st_count-1;
                end
		    end else begin
    			//counter is 0
                if(dat_was_0 & strobe_dropped) begin
                    dat_was_0 <= 0;
                    end_strobe_reg = 1;         //the end strobe for a 0 loaded
                end else begin
                    end_strobe_reg <= 0;
                end
                strobe_dropped <= 0;
	        end
        end
	end

    // hey why not just do
    //	assign end_strobe = (st_count == 1);
	//might screw up if load a 1
    assign end_strobe = end_strobe_reg;

endmodule
