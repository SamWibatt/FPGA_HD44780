/*
	hd44780 controller

    a bit different from my previous projects' controllers; this is just the LCD driver.
    top and syscon handle the top-level stuff.

*/
`default_nettype	none



/*
MAY NEED TO REDO a bit bc there are only a few timings
and ... do we really need all these flipflops just to
delay? Bc the delay values are:
100 ms <=== only once and gobbles up like 5 more ffs
4.1 ms ... than this
3 ms   ... and this = 30 * 100us? = 18 ffs
100 us ... 13 ffs @ 48Hz
53 us - at 48MHz, divide down by 2523? = 12 ffs
...so like 23 FFs
Indeed, (1/10) / (1/48000000) =~ 4_800_000
which takes 23 bits - huh
Well, deal
*/

//System clock frequency, Hz. Might want to define somewhere more globally like a configs include.
//RECALL that up5k builtin 48MHz is not very accurate, might want to fudge the speed down by 10%
//or so to avoid flakiness
//and let's only do this if G_SYSFREQ is not declared elsewhere, like on a command line
`ifndef G_SYSFREQ
`ifdef SIM_STEP
//10240 got 10 bits, same 10241 - integer / 10 - sure - let's try 10250 - 11 bits!
//now it's 10240 gets 11, 1023 gets 10 - because 1024 needs 10 bits when you think about it
//let's do sim at 10K, which is the low freq osc on the chip!
`define G_SYSFREQ 10_240
`else
`define G_SYSFREQ 48_000_000
`endif
`endif

//then values we load into the delay thing, why not
//MAKE SURE THESE ARE AT LEAST 1 (likely not a problem with real clock freqs)
`define DELAY_100MS ($ceil($itor(`G_SYSFREQ) / $itor(10)))
//I think this works - gets correct 2544 out of 48MHz
//gets 1 out of 100Hz
//6 out of 100KHz - yup, ceil(5.3) - looks like it oughta work!
`define DELAY_53US ($ceil(($itor(`G_SYSFREQ) * $itor(53)) / $itor(1_000_000)))
//4.1 ms - call it 41/10_000
`define DELAY_4P1MS ($ceil(($itor(`G_SYSFREQ) * $itor(41)) / $itor(10_000)))
//3 ms
`define DELAY_3MS ($ceil(($itor(`G_SYSFREQ) * $itor(3)) / $itor(1_000)))
//100 us
`define DELAY_100US ($ceil(($itor(`G_SYSFREQ) * $itor(100)) / $itor(1_000_000)))

//parameter STATE_TIMER_BITS = 7;     //will derive counts from clock freq at some point
//per https://stackoverflow.com/questions/5602167/logarithm-in-verilog,
// If it is a logarithm base 2 you are trying to do, you can use the built-in function $clog2()
// is this right?
//MAKE SURE THIS IS RIGHT on some edge cases - yay, 10240 got 10 bits and 10250 got 11 bits.
//but maybe 1023 should get 10, 1024 11 - try x+1 where x was
//no, wait, (x/10)+1, not (x+1)/10
//and now it is right.
`define BITS_TO_HOLD_100MS(x) ($ceil($clog2(($itor(x)/$itor(10))+1) ))
`define G_STATE_TIMER_BITS (`BITS_TO_HOLD_100MS(`G_SYSFREQ))

//*************************************************************************************
//aha, it's the backtick before referring to a define that makes them work like numbers
//*************************************************************************************

module state_timer #(parameter SYSFREQ = `G_SYSFREQ, parameter STATE_TIMER_BITS = `BITS_TO_HOLD_100MS(SYSFREQ)) (
    input wire RST_I,
    input wire CLK_I,
	input wire [STATE_TIMER_BITS-1:0] DAT_I,	//[STATE_TIMER_BITS-1:0] DAT_I,
    input wire start_strobe,            // causes timer to load
    output wire end_strobe              // nudges caller to advance state
    );

    // DEBUG ===============================================================================
    // can I print out defines like this? yarp! Shouldn't synthesize anything
    initial begin
        $display("DELAY_100MS is %d",`DELAY_100MS);
        $display("DELAY_4P1MS is %d",`DELAY_4P1MS);
        $display("DELAY_3MS is %d",`DELAY_3MS);
        $display("DELAY_100US is %d",`DELAY_100US);
        $display("DELAY_53US is %d",`DELAY_53US);
        $display("G_STATE_TIMER_BITS is %d",`G_STATE_TIMER_BITS);
    end
    // END DEBUG ===========================================================================

    reg [STATE_TIMER_BITS-1:0] st_count = 0;
    reg end_strobe_reg = 0;

	always @(posedge CLK_I) begin
		if(RST_I == 1) begin
			st_count <= 0;
			end_strobe_reg <= 0;
		end else if(start_strobe == 1) begin
			end_strobe_reg <= 0;
			st_count <= DAT_I;
		end else if(|st_count) begin
			//count is not 0 - raise strobe in the last tick before it goes 0
			if(st_count == 1) begin
				end_strobe_reg <= 1;
			end
			st_count <= st_count-1;
		end else begin
			//counter is 0
			end_strobe_reg <= 0;
		end
	end

    // hey why not just do
    //	assign end_strobe = (st_count == 1);
	//might screw up if load a 1
    assign end_strobe = end_strobe_reg;

endmodule


//***********************************************************************************************************
//***********************************************************************************************************
//***********************************************************************************************************
// HEREAFTER UNCHANGED **************************************************************************************
//***********************************************************************************************************
//***********************************************************************************************************
//***********************************************************************************************************


// MAIN ********************************************************************************************************************************************
module hd44780_controller(
    input RST_I,                //wishbone reset, also on falling edge of reset we want to do the whole big LCD init.
    input CLK_I,
    input STB_I,                //to let this module know rs and lcd_data are ready and to do its thing.
    input rs,                   //register select - command or data, will go to LCD RS pin
    input wire[7:0] lcd_data,   // byte to send to LCD, one nybble at a time
    output busy,
	output alive_led,			//this is THE LED, the green one that shows the controller is alive
);


	// Super simple "I'm Alive" blinky on one of the external LEDs.
	parameter GREENBLINKBITS = 25;			// at 12 MHz 23 is ok - it's kind of hyper at 48. KEY THIS TO GLOBAL SYSTEM CLOCK FREQ DEFINE
											// and hey why not define that in top or tb instead of in the controller or even on command line - ok
											// now the define above is wrapped in `ifndef G_SYSFREQ so there you go
	reg[GREENBLINKBITS-1:0] greenblinkct = 0;
	always @(posedge i_clk) begin
		greenblinkct <= greenblinkct + 1;
	end

	assign alive_led = ~greenblinkct[GREENBLINKBITS-1];	   //controller_alive, always block just above this

    //moving syscon stuff to top....??? tb will need it too


	//HERE INSTANTIATE A STATE TIMER MODULE SO I CAN SEE HOW IT LOOKS IN GTKWAVE
	//annoying that parameterizing needs a separate calculation on bits to hold tenth, but we'll figure it out
	reg[`G_STATE_TIMER_BITS-1:0] timer_value = 0;
	reg timer_start = 0;
	wire timer_done;

	//should just be state_timer timey
	//state_timer #(.SYSFREQ(slow_freq)) timey 			//should figure out bits by itself - but this is gross, need to do the bits calc here and in the module :P but ok
	state_timer timey
	(
		.RST_I(RST_O),
		.CLK_I(CLK_O),
		.DAT_I(timer_value),			//can I use regs here?
		.start_strobe(timer_start),		//and here?
		.end_strobe(timer_done)
	);

    reg in_reset_n = 0;                 //0 means in reset so post-reset can spot
    always @(posedge CLK_I) begin
        if(RST_I) begin
            //glue stuff down
            //maybe set some register so we know we've been in reset, let's say
            //in_reset_n = 0 when we're in reset
            in_reset_n <= 0;
        end else begin
            //need a bit in here somewhere about how if reset is freshly released
            //the in_reset register
            if(~in_reset_n) begin
                //send busy and reset LCD 
                in_reset_n <= 1;            //dismiss just-reset active low flag
            end else if (STB_I) begin
                //aha, raise the
            end else begin
                //state-machiney stuff
            end
        end
    end


endmodule
