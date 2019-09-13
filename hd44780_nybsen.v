/*
	hd44780 nybble sender 
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

module hd44780_nybble_sender(
    input RST_I,                    //wishbone reset, also on falling edge of reset we want to do the whole big LCD init.
    input CLK_I,
    input STB_I,                    //to let this module know rs and lcd_data are ready and to do its thing.
    input i_rs,                     //register select - command or data, will go to LCD RS pin
    input wire[3:0] i_nybble,       //nybble we're sending
    output wire o_busy,             //whether this module is busy
    output wire [3:0] o_lcd_data,   //the data bits we send really are 7:4 - I guess others NC? tied low?
                                    //check vpok. also I saw a way to do 7:4 -> 3:0 but - well, later
    output wire o_rs,
    output wire o_e                 //LCD enable pin
    );

    reg[`H4NS_COUNT_BITS-1:0] STDC = 0;
    reg e_reg = 0;
    reg busy_reg = 0;
    reg[3:0] o_lcd_reg = 0;

    reg rs_reg = 0;           //for saving off the rs so that async changes to input don't get propagated

    always @(posedge CLK_I) begin
        if(RST_I) begin
            //reset!
            e_reg <= 0;
            STDC <= 0;
            o_lcd_reg <= 0;
            busy_reg <= 0;
            rs_reg <= 0;
        end else if (STB_I & ~busy_reg) begin
            //strobe came along while we're not busy! let's get rolling
            e_reg <= 0;
            o_lcd_reg <= i_nybble;      //sync way
            rs_reg <= i_rs;              //sync rs too
            STDC <= `H4NS_COUNT_TOP; //`H4NS_TICKS_TCYCE + `H4NS_TICKS_TAS;      //this should be how long the counter runs
            busy_reg <= 1;
        //was end else if (|STDC) begin
        end else if (~STB_I & |STDC) begin
            STDC <= STDC - 1;           //decrement unless STDC is 0

            // our little state machine! All of the following with the appropriate delays
            // ************************* FIND OUT WHAT THE DELAYS ARE from hd44780 'sheet
            // put the nybble on the output lines
            // set r/s appropriately
            // - wait for TAS (address setup time), 60ns (pg 49 of 'sheet)
            // so it looks like a clock tick at 48 MHz is about 20.833 nanos.
            // is it even worth dealing with timer module for this?
            // if we did state machine as a counter and set the nybble to the output lines
    		// and set r/s at state i, then then raise e (below) at i+3...
    		// ok, but how to adjust for clock speed?
    		// not going to be a sitch where the # ffs is overwhelming
    		// bc that would mean a very high clock speed
    		// could try a define like with the longer delays, clog2 etc,
    		// and then a case where it's `TICK_SETRS: then a
    		// `TICK_SETRS + `DUR_60NS:
    		// advance state by counting up, or down as it may be better, until
    		// reach 0 and go idle.
    		// so count down, and calculate the meaningful states accordingly.
    		// move noodling to wiki
            // - here is where TCYCE starts
            // raise e
            // - wait for PWEH (pulse width enable high), 450 ns min
            // lower e
            // - wait for TAH (address hold time), 20 ns
            // - wait for rest of TCYCE (Enable cycle time) s.t. to here it's 1000 ns, so
            //     1000 - (TAS + TAH + PWEH) = 1000 - (60 + 450 + 20) = 1000 - 530 = 470 ?
            // - now we can leave, I reckon

            // load state downcounter (call it STDC) with TCYCE_TICKS + TAS_TICKS
            // while STDC > 0: //watch out for off-by-ones. Precision!
            // case(STDC)
            //     `TCYCE_TICKS + `TAS_TICKS: // maybe have a total_ticks define
            //         this would be where we set rs and o_lcd_data, if they were registers.
            //         currently I think they could just be assigned, see below.
            //     `TCYCE_TICKS: //I.e. TAS_TICKS later
            //         e_reg <= 1;
            //     `TCYCE_TICKS - `PWEH_TICKS:
            //         e_reg <= 0;
            //     etc. If there is anything else but waiting to 0
            // endcase
            // STDC <= STDC-1;
            // assign o_lcd_data = i_nybble; //asyncy, but does it matter?
            // assign o_rs = i_rs; // similar, none of this matters until e
            /*
            if(STDC == `H4NS_TICKS_TCYCE) begin      //i.e., TAS_TICKS after start
                e_reg <= 1;          //raise e
            end else if(STDC == `H4NS_TICKS_TCYCE - `H4NS_TICKS_PWEH) begin      //i.e., PWEH_TICKS after raise e
                e_reg <= 0;          //lower e
            end
            */
            /* ok, that didn't quite work. Correct enough in theory but in practice, at very low clock speeds,
            the fact that all the ns delays are 1 causes trouble.
            //short delays for hd44780 nybble sender, in clock ticks (32768 Hz)
            `define H4NS_TICKS_TAS   (1)
            `define H4NS_TICKS_PWEH  (1)
            `define H4NS_TICKS_TAH   (1)
            `define H4NS_TICKS_E_PAD (1)
            `define H4NS_COUNT_TOP   (4)
            `define H4NS_COUNT_BITS  (3)
            */
            if(STDC == `H4NS_COUNT_TOP - `H4NS_TICKS_TAS) begin      //i.e., TAS_TICKS after start
                e_reg <= 1;          //raise e
            end else if(STDC == `H4NS_COUNT_TOP - `H4NS_TICKS_TAS - `H4NS_TICKS_PWEH) begin      //i.e., PWEH_TICKS after raise e
                e_reg <= 0;          //lower e
            end

        //was end else begin
        end else if(~STB_I) begin
            // counter is 0 - we're done! or continue not to be busy
            busy_reg <= 0;
        end
        // ELSE COUNTER IS 0 AND STROBE IS OFF, and we care bc if we don't pay attention to strobe
        // and it persists for a long time, busy wiggles back and forth bc of previous block

    end

    assign o_lcd_data = o_lcd_reg;
    //was i_nybble; //asyncy, but does it matter? probably. controller tb hates it.
    assign o_rs = rs_reg; //i_rs; // similar, none of this matters until e - no, had to make it synch to avoid spurious input->output changes
    assign o_e = e_reg;
    assign o_busy = busy_reg;

endmodule
