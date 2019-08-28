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


/*

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
//...drat, these don't work in yosys


//`define BITS_TO_HOLD_100MS(x) ($rtoi($ceil($clog2(($itor(x)/$itor(10))+1) )))
//`define G_STATE_TIMER_BITS (`BITS_TO_HOLD_100MS(`G_SYSFREQ))
//ok, needed integer arg to clog2
`define G_STATE_TIMER_BITS ($ceil($clog2( $rtoi($itor(`G_SYSFREQ)/$itor(10)) +1) ))
*/

//new way with include

`ifndef SIM_STEP
`include hd44780_build_config.inc
`else
`include hd44780_sim_config.inc
`endif

//*************************************************************************************
//aha, it's the backtick before referring to a define that makes them work like numbers
//*************************************************************************************

module hd44780_state_timer  #(parameter SYSFREQ = `G_SYSFREQ, parameter STATE_TIMER_BITS = `G_STATE_TIMER_BITS)
(
    input wire RST_I,
    input wire CLK_I,
	input wire [STATE_TIMER_BITS-1:0] DAT_I,	//[STATE_TIMER_BITS-1:0] DAT_I,
    input wire start_strobe,            // causes timer to load
    output wire end_strobe             // nudges caller to advance state
    );

    // DEBUG ===============================================================================
    // can I print out defines like this? yarp! Shouldn't synthesize anything
    //yosys doesn't like these defines so only do them in iverilog
    `ifdef SIM_STEP
    initial begin
        localparam d100ms = `DELAY_100MS;
        $display("DELAY_100MS is %d",d100ms);       //this didn't work either
        $display("DELAY_4P1MS is %d",`DELAY_4P1MS);
        $display("DELAY_3MS is %d",`DELAY_3MS);
        $display("DELAY_100US is %d",`DELAY_100US);
        $display("DELAY_53US is %d",`DELAY_53US);
        $display("G_STATE_TIMER_BITS is %d",`G_STATE_TIMER_BITS);
    end
    `endif
    // END DEBUG ===========================================================================

    //drat, yosys hates all my clever bit calculations
    //*********************** FIGURE OUT HOW TO DEAL WITH THAT
    reg [`G_STATE_TIMER_BITS-1:0] st_count = 0;
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

// tick defines moved to hd44780_config.py, qv

module hd44780_nybble_sender(
    input RST_I,                    //wishbone reset, also on falling edge of reset we want to do the whole big LCD init.
    input CLK_I,
    input STB_I,                    //to let this module know rs and lcd_data are ready and to do its thing.
    input i_rs,                     //register select - command or data, will go to LCD RS pin
    input wire[3:0] i_nybble,       //nybble we're sending
    output wire o_busy,             //whether this module is busy
    output wire [3:0] o_lcd_data,   //the data bits we send really are 7:4 - I guess others NC? tied low?
    output wire o_rs,
    output wire o_e                 //LCD enable pin
    );

    reg[`NSEND_TIMER_BITS-1:0] STDC = 0;
    reg e_reg = 0;
    reg busy_reg = 0;

    always @(posedge CLK_I) begin
        if(RST_I) begin
            //reset!
            e_reg <= 0;
            STDC <= 0;
            busy_reg <= 0;
        end else if (STB_I & ~busy_reg) begin
            //strobe came along while we're not busy! let's get rolling
            e_reg <= 0;
            STDC <= `TCYCE_TICKS + `TAS_TICKS;      //this should be how long the counter runs
            busy_reg <= 1;
        end else if (|STDC) begin
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
            if(STDC == `TCYCE_TICKS) begin      //i.e., TAS_TICKS after start
                e_reg <= 1;          //raise e
            end else if(STDC == `TCYCE_TICKS - `PWEH_TICKS) begin      //i.e., PWEH_TICKS after raise e
                e_reg <= 0;          //lower e
            end
        end else begin
            // counter is 0 - we're done! or continue not to be busy
            busy_reg <= 0;
        end
    end

    assign o_lcd_data = i_nybble; //asyncy, but does it matter?
    assign o_rs = i_rs; // similar, none of this matters until e
    assign o_e = e_reg;
    assign o_busy = busy_reg;

endmodule

// MAIN ********************************************************************************************************************************************
module hd44780_controller(
    input RST_I,                    //wishbone reset, also on falling edge of reset we want to do the whole big LCD init.
    input CLK_I,
    input STB_I,                    //to let this module know rs and lcd_data are ready and to do its thing.
    input i_rs,                     //register select - command or data, will go to LCD RS pin
    input wire[7:0] i_lcd_data,     // byte to send to LCD, one nybble at a time
    output wire busy,
	output wire alive_led,			//this is THE LED, the green one that shows the controller is alive
    output wire o_rs,
    output wire [3:0] o_lcd_data,   //can you do this? the data bits we send really are 7:4 - I guess others NC? tied low?
    output wire o_e                 //LCD enable pin
);

    reg busy_reg = 0;               //for synching busy flag
    reg active = 0;                 //0 means in reset so post-reset can spot
    reg [3:0] nybble = 0;           //nybble to send to LCD

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
	//hd44780_state_timer #(.SYSFREQ(slow_freq)) timey 			//should figure out bits by itself - but this is gross, need to do the bits calc here and in the module :P but ok
	hd44780_state_timer timey
	(
		.RST_I(RST_O),
		.CLK_I(CLK_O),
		.DAT_I(timer_value),			//can I use regs here?
		.start_strobe(timer_start),		//and here?
		.end_strobe(timer_done)
	);

    //state-machiney stuff
    //let's not bother with my old-fashioned single-bit transitions...?
    //remember a state machine can just increment through states or have defines or whatever
    //it's also possible to have unrelated bits of state machine - think of it like BASIC line numbers,
    //there could be a set of states reset_lcd_0, reset_lcd_1, ... reset_lcd_n s.t. those are the
    //states that walk through the LCD reset and then release busy and "hang" in a main state that
    //does nothing - STB_I strobe or another reset will jolt it into the new state it needs to be in.
    //Then there's another set of states like send_char_or_cmd_0, ... send_char_or_cmd_n, that does the
    //stuff where it presents i_lcd_data on the output pins one nybble at a time, waits for
    //whatever time, sets rs, raises e, etc. etc. This is where clever muxing or something could
    //be nice for the presentation of a nybble on the output.
    //here's how UW https://courses.cs.washington.edu/courses/cse370 does it
    //localparam IDLE=0, WAITFORB=1, DONE=2, ERROR=3;
    /* Here is the initialization sequence given in http://web.alfredstate.edu/faculty/weimandn/lcd/lcd_initialization/lcd_initialization_index.html
    Copyright © 2009, 2010, 2012 Donald Weiman
    (weimandn@alfredstate.edu)

    Step 1. Power on, then delay > 100 ms
    There are two different values (with two different references) specified on the datasheet flowchart for this initial delay but neither
    reference is from when the power was first applied. The delay required from power-up must obviously be more than 40 mS and I
    have arbitrarily chosen to use 100 mS. Since this delay only occurs once it doesen't make sense to try to speed up program
    execution time by skimping on this delay.

    Step 2. Instruction 0011b (3h), then delay > 4.1 ms
    This is a special case of the Function Set instruction where the lower four bits are irrelevant. These four bits are not shown on
    the flowcharts because the host microcontroller does not usually implement them at all (as opposed to the 8-bit mode wher they
    are implemented as '0's).
    This first instruction, for some unexplained reason, takes significantly longer to complete than the ones
    that come later.

    Step 3. Instruction 0011b (3h), then delay > 100 us
    This is a second instance of the special case of the Function Set instruction. The controller does not normally expect to receive
    more than one 'Function Set' instruction so this may account for the longer than normal execution time.

    Step 4. Instruction 0011b (3h), then delay > 100 us
    This is a third instance of the special case of the Function Set instruction.
    By now the LCD controller realizes that what is really
    intended is a 'reset', and it is now ready for the real Function Set instruction followed by the rest of the initialization instructions.
    The flowcharts do not specify what time delay belongs here.
    I have chosen 100 us to agree with the previous instruction.
    It may be possible to check the busy flag here.

    Step 5. Instruction 0010b (2h), then delay > 100 us
    Here is where the LCD controller is expecting the 'real' Function Set instruction which, in the 8-bit mode, would start with 0011.
    Instead, it gets a Function Set instruction starting with 0010. This is it's signal to again ignore the lower four bits, switch to the
    four-bit mode, and expect another 'real' Function Set instruction. Once again the required time delay is speculation.
    The LCD controller is now in the 4-bit mode. This means that the LCD controller reads only the four high order data pins each
    time the Enable pin is pulsed . To accomodate this, the host microcontroller must put the four high bits on the data lines and
    pulse the enable pin, it must then put the four low bits on the data lines and again pulse the enable pin. There is no need for a
    delay between these two sequences because the LCD controller isn't processing the instruction yet. After the second group of
    data bits is received the LCD controller reconstructs and executes the instruction and this is when the delay is required.

    Step 6. Instruction 0010b (2h), then 1000b (8h), then delay > 53 us or check BF
    This is the real Function Set instruction. This is where the interface, the number of lines, and the font are specified. Since we
    are implementing the 4-bit interface we make D = 0. The number of lines being specified here is the number of 'logical' lines as
    perceived by the LCD controller, it is NOT the number of 'physical' lines (or rows) that appear on the actual display. This should
    almost always be two lines so we set N=1 (go figure). There are very few displays capable of displaying a 5x10 font so the 5x7
    choice is almost always correct and we set F=0.

    Step 7. Instruction 0000b (0h), then 1000b (8h) then delay > 53 us or check BF
    This is the Display on/off Control instruction. This instruction is used to control several aspects of the display but now is NOT
    the time to set the display up the way we want it. The flow chart shows the instruction as 00001000, not 00001DCB which
    indicates that the Display (D), the Cursor (C), and the Blinking (B) should all be turned off by making the corresponding bits = 0.

    Step 8. Instruction 0000b (0h), then 0001b (1h) then delay > 3 ms or check BF
    This is the Clear Display instruction which, since it has to write information to all 80 DDRAM addresses, takes more time to
    execute than most of the other instructions. On some flow charts the comment is incorrectly labeled as 'Display on' but the
    instruction itself is correct.

    Step 9. Instruction 0000b (0h), then 0110b (6h), then delay > 53 us or check BF
    This is the Entry Mode Set instruction. This instruction determines which way the cursor and/or the display moves when we
    enter a string of characters. We normally want the cursor to increment (move from left to right) and the display to not shift so
    we set I/D=1 and S=0. If your application requires a different configuration you could change this instruction, but my
    recommendation is to leave this instruction alone and just add another Entry Mode Set instruction where appropriate in your
    program.

    Step 10. Initialization ends
    This is the end of the actual intitalization sequence, but note that step 6 has left the display off.

    Step 11. Instruction 0000b (0h), then 1100b (0Ch), then delay > 53 us or check BF
    This is another Display on/off Control instruction where the display is turned on and where the cursor can be made visible
    and/or the cursor location can be made to blink. This example shows the the display on and the other two options off, D=1, C=0,
    and B=0.

    ... This COULD maybe be done as a little table of nybble, delay - but let's do a state machine
    */

    // **********************************************
    // SO HERE IS THE LIST OF STATES WE'LL BE DEALING WITH IN THIS MODULE -
    // THIS WILL AMOUNT TO A BUNCH OF USES OF THE TIMER MODULE AND THE NYBBLE SENDER MODULE
    localparam IDLE=0,              // state where we end up after init or char/cmd send
        RESET_LCD_START = 1,        // Step 1. Power on, then delay > 100 ms
        RESET_LCD_FNSET1 = 2,       // Step 2. Instruction 0011b (3h), then delay > 4.1 ms
        RESET_LCD_FNSET2 = 3,       // Step 3. Instruction 0011b (3h), then delay > 100 us
        RESET_LCD_FNSET3 = 4,       // Step 4. Instruction 0011b (3h), then delay > 100 us
        RESET_LCD_4BIT = 5,         // Step 5. Instruction 0010b (2h), then delay > 100 us
        RESET_LCD_FS4LNFNT = 6,     // Step 6. Instruction 0010b (2h), then 1000b (8h), then delay > 53 us or check BF
        RESET_LCD_DISPOFF = 7,      // Step 7. Instruction 0000b (0h), then 1000b (8h) then delay > 53 us or check BF
        RESET_LCD_CLRDISP = 8,      // Step 8. Instruction 0000b (0h), then 0001b (1h) then delay > 3 ms or check BF
        RESET_LCD_EMSET = 9,        // Step 9. Instruction 0000b (0h), then 0110b (6h), then delay > 53 us or check BF
                                    // Step 10. Initialization ends
        RESET_LCD_DISPON = 10,      // Step 11. Instruction 0000b (0h), then 1100b (0Ch), then delay > 53 us or check BF
        // states related to sending a command or character byte one nybble at a time
        SENDCHAR_START = 11
        ;


    always @(posedge CLK_I) begin
        if(RST_I) begin
            //**************************************************************************************
            //**************************************************************************************
            //**************************************************************************************
            //* SHOULD THERE BE A PIECE IN HERE ABOUT HOW IF WE ARE NEWLY RESET, SHUT THE LCD OFF?
            // i.e. if active == 1, ... hm.
            //**************************************************************************************
            //**************************************************************************************
            //**************************************************************************************

            //in reset, zero everything out
            greenblinkct <= 0;
            busy_reg <= 0;
            timer_start <= 0;
            timer_value <= 0;
            active <= 0;            // positive edge in "active" shows reset is newly done so init LCD


        end else begin
            if(~active) begin
                //aha, we've just exited reset. send busy and reset LCD
                busy_reg <= 1;
                active <= 1;            //dismiss just-reset condition: now active
                //************ GO OFF AND DO RESET - HOW? Big state machine below?
            end else if (STB_I & ~busy) begin
                //Strobe doesn't do anything if we're already busy
                //aha, raise the busy flag and do whatever it is
                busy_reg <= 1;
                // ***************** MORE STUFF
            end else begin
                //state machine!
            end
        end
    end
    assign busy = busy_reg;

endmodule
