/*
	hd44780 controller

    a bit different from my previous projects' controllers; this is just the LCD driver.
    top and syscon handle the top-level stuff.

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

// tick defines moved to hd44780_config.py, qv

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

// MAIN ********************************************************************************************************************************************
module hd44780_controller(
    input wire RST_I,                    //wishbone reset, also on falling edge of reset we want to do the whole big LCD init.
    input wire CLK_I,
    input wire STB_I,                    //to let this module know rs and lcd_data are ready and to do its thing.
    input wire i_rs,                     //register select - command or data, will go to LCD RS pin
    //input wire[7:0] i_lcd_addr    //is there an address we have to send? looks like not, it's cursor-based.
    input wire[7:0] i_lcd_data,     // byte to send to LCD, one nybble at a time
    output wire busy,
	output wire alive_led,			//this is THE LED, the green one that shows the controller is alive
    output wire o_rs,
    output wire [3:0] o_lcd_data,   //can you do this? the data bits we send really are 7:4 - I guess others NC? tied low?
                                    //see above in nybble sender
    output wire o_e                 //LCD enable pin
);

	// Super simple "I'm Alive" blinky on one of the external LEDs.
	parameter GREENBLINKBITS = 25;			// at 12 MHz 23 is ok - it's kind of hyper at 48. KEY THIS TO GLOBAL SYSTEM CLOCK FREQ DEFINE
											// and hey why not define that in top or tb instead of in the controller or even on command line - ok
											// now the define above is wrapped in `ifndef G_SYSFREQ so there you go
	reg[GREENBLINKBITS-1:0] greenblinkct = 0;
	always @(posedge CLK_I) begin
		greenblinkct <= greenblinkct + 1;
	end

	assign alive_led = ~greenblinkct[GREENBLINKBITS-1];	   //controller_alive, always block just above this


    // DEBUG ===============================================================================
    // can I print out defines like this? yarp! Shouldn't synthesize anything
    //yosys doesn't like these defines so only do them in iverilog
    `ifdef SIM_STEP
    initial begin
        $display("H4_DELAY_100MS is %d",`H4_DELAY_100MS);
        $display("H4_DELAY_4P1MS is %d",`H4_DELAY_4P1MS);
		$display("H4_DELAY_3MS is   %d",`H4_DELAY_3MS);
        $display("H4_DELAY_100US is %d",`H4_DELAY_100US);
		$display("H4_DELAY_53US is  %d",`H4_DELAY_53US);
		$display("H4_TIMER_BITS is  %d",`H4_TIMER_BITS);
		$display("---");
		$display("H4NS_TICKS_TAS is   %d",`H4NS_TICKS_TAS);
		$display("H4NS_TICKS_PWEH is  %d",`H4NS_TICKS_PWEH);
        $display("H4NS_TICKS_TAH is   %d",`H4NS_TICKS_TAH);
        $display("H4NS_TICKS_E_PAD is %d",`H4NS_TICKS_E_PAD);
        $display("H4NS_COUNT_TOP is   %d",`H4NS_COUNT_TOP);
		$display("H4NS_COUNT_BITS is  %d",`H4NS_COUNT_BITS);
	end
    `endif
    // END DEBUG ===========================================================================

    /*
    **************************************************************************************
    **************************************************************************************
    **************************************************************************************
    so ok now for what it really does
    Version 1, and possibly all, with a different module that does initialization seq,
    or something
    ANYWAY what it does is cue up one nybble of i_lcd_data, then call the nybble sender,
    then cue up the other one, and send that.
    that is what the first testbench should do.

    **************************************************************************************
    **************************************************************************************
    **************************************************************************************
    */

    //so, need a var for the outgoing strobe to the nybble sender.
    //the STB_I one is the strobe for the controller itself, which triggers two nybble sends.
    //but first, just put in a nybble sender.
    reg ns_ststrobe = 0;                       //start strobe for nybble sender
    wire ns_busy;                           //nybble sender's busy, which is not the same as controller's
    reg [3:0] ns_nybbin = 4'b0000;          //nybble we wish to send
	reg cont_rs_reg = 0;

    hd44780_nybble_sender nybsen(
        .RST_I(RST_I),
        .CLK_I(CLK_I),
        .STB_I(ns_ststrobe),
		.i_rs(cont_rs_reg),		//was (i_rs), but that passes through async changes in rs line which is bad
        .i_nybble(ns_nybbin),
        .o_busy(ns_busy),
        .o_lcd_data(o_lcd_data),
        .o_rs(o_rs),
        .o_e(o_e)
    );

    //so little state machine
    //************************************************************************************************************
    //************************************************************************************************************
    //************************************************************************************************************
    // FIGURE THIS OUT
    // state succession is pretty easy, bc nybble sender does its own e-cycle timing, and you just
    // wait for not busy first!
    // load nybble, pulse strobe, wait for not busy (and can load next nybble in the meantime!)
    // pulse strobe and wait done.
    // note that the thing is still running, but since we wait for not busy at first, this
    // lets us zoom off and do other stuff and if there are further bytes to send, no problem.
    // if not, or if like in initialization we're doing pauses in between, it'll just be immediately not-busy
    // by the time the second invocation happens.
    // WRITE IT!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    //************************************************************************************************************
    //************************************************************************************************************
    //************************************************************************************************************

    reg [2:0] cont_state = 0;
    reg cont_busy_reg = 0;
    reg [7:0] i_lcd_data_shadow = 0;    // save off a copy of i_lcd data so spurious changes on the input lines don't trash nybbles

    //state defines
    localparam st_c_idle = 3'b000;
    localparam st_c_waitstb = 3'b001;
    localparam st_c_nyb1 = 3'b010;
    localparam st_c_stb1 = 3'b011;
    localparam st_c_dstb1 = 3'b100;
    localparam st_c_nyb2 = 3'b101;
    localparam st_c_stb2 = 3'b110;
    localparam st_c_dstb2 = 3'b111;

    always @(posedge CLK_I) begin
        if(RST_I) begin
            //reset!
            ns_ststrobe <= 0;
            ns_nybbin <= 0;
            cont_state <= 0;
            cont_busy_reg <= 0;
			cont_rs_reg <= 0;
		end else if (STB_I & ~busy)	begin	//Can I do this? was & ~cont_busy_reg & ~ns_busy) begin			//busy output is cont busy reg | ns_busy... this is clumsy
            //strobe came along while we're not busy and nybble sender isn't either! let's get rolling
            cont_busy_reg <= 1;
			cont_rs_reg <= i_rs;		//synchronize RS line
            cont_state <= 3'b001; //bump out of idle
        end else begin
            // load nybble, pulse strobe, wait for not busy (and can load next nybble in the meantime!)
            // or maybe not, depending on how the nybble is handled.
            // pulse strobe and wait done.

            //state 0 is idle.
            case(cont_state)
                st_c_idle: begin
                    cont_busy_reg <= 0;
                end

                st_c_waitstb: begin
                    //wait for strobe to drop
                    if(~STB_I) begin
                        i_lcd_data_shadow <= i_lcd_data;    //save off input byte so changes on the input lines don't mess up nybbles asynchronously
                        cont_state <= cont_state + 1;
                    end
                end

                //state 1, cue up first nybble
                st_c_nyb1: begin
                    //do we send lower nybble first? if so, do this, otherwise swap with the other one
                    //nope, we send upper nyb first.
                    ns_nybbin <= {i_lcd_data_shadow[7],i_lcd_data_shadow[6],i_lcd_data_shadow[5],i_lcd_data_shadow[4]};
                    cont_state <= cont_state + 1;
                end

                st_c_stb1: begin
                    //raise strobe - may not need all these states but can tighten up yes?
                    ns_ststrobe <= 1;
                    cont_state <= cont_state + 1;
                end

                st_c_dstb1: begin
                    //drop strobe - may not need all these states but can tighten up yes?
                    ns_ststrobe <= 0;
                    cont_state <= cont_state + 1;
                end

                st_c_nyb2: begin
                    //wait for busy to drop - MAY NEED A WAIT STATE ? nope seems to work
                    if(~ns_busy) begin
                        cont_state <= cont_state +1;
                        //do we send upper nybble last? if so, do this, otherwise swap with the other one
                        //nope, it's last, so moved low nybble here
                        ns_nybbin <= {i_lcd_data_shadow[3],i_lcd_data_shadow[2],i_lcd_data_shadow[1],i_lcd_data_shadow[0]};
                    end
                end

                st_c_stb2: begin
                    //raise strobe - may not need all these states but can tighten up yes?
                    ns_ststrobe <= 1;
                    cont_state <= cont_state + 1;
                end

                st_c_dstb2: begin
                    //drop strobe - may not need all these states but can tighten up yes?
                    ns_ststrobe <= 0;
                    cont_state <= 0;           //go back to idle. subsequent calls will wait for busy.
                end
            endcase
        end
    end

	assign busy = cont_busy_reg | ns_busy;		//adding ns_busy bc controller is busy if ns is.

    /*
    //moving syscon stuff to top....??? tb will need it too
    reg busy_reg = 0;               //for synching busy flag
    reg active = 0;                 //0 means in reset so post-reset can spot
    reg [3:0] nybble = 0;           //nybble to send to LCD
	reg already_did_reset = 0;		//if 1, means that the LCD has gone through the power-on reset and should get a different "warm boot" reset,
									//assuming that it's already in nybble mode. If the caller has put it into some crazy state, feh. Will try to protect against.
									//SO THIS IS OUTSIDE THE INFLUENCE OF RST_I. it's the LCD's initialized bit, not the controller's... this is probably awful style but ???
    */

    /*
	//HERE INSTANTIATE A STATE TIMER MODULE SO I CAN SEE HOW IT LOOKS IN GTKWAVE
	//annoying that parameterizing needs a separate calculation on bits to hold tenth, but we'll figure it out
	reg[`H4_TIMER_BITS-1:0] timer_value = 0;
	reg timer_start = 0;
	wire timer_done;

	//should just be state_timer timey
	//hd44780_state_timer #(.SYSFREQ(slow_freq)) timey 			//should figure out bits by itself - but this is gross, need to do the bits calc here and in the module :P but ok
	hd44780_state_timer timey
	(
		.RST_I(RST_I),
		.CLK_I(CLK_I),
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
    */
    /* Here is the initialization sequence given in http://web.alfredstate.edu/faculty/weimandn/lcd/lcd_initialization/lcd_initialization_index.html
    Copyright © 2009, 2010, 2012 Donald Weiman
    (weimandn@alfredstate.edu)

	*****************************************************************************************************************************************************************
	*****************************************************************************************************************************************************************
	*****************************************************************************************************************************************************************
	*****************************************************************************************************************************************************************
	*****************************************************************************************************************************************************************
	*****************************************************************************************************************************************************************
	*****************************************************************************************************************************************************************
	IMPORTANT: TEST TO SEE WHAT HAPPENS IF WE'VE BEEN USING THE LCD FOR A WHILE AND THEN SEND A RESET. DOES IT WAKE BACK UP PROPERLY?
	Per https://mil.ufl.edu/3744/docs/lcdmanual/commands.html#Fs,
	"This command should be issued only after automatic power-on initialization has occurred, or as part of the module initialization sequence."
	Let's see if we can't find something a little more definite
	- datasheet says:
	Note: Perform the function at the head of the program before executing any instructions (except for the
	read busy flag and address instruction). From this point, the function set instruction cannot be
	executed unless the interface data length is changed.
	- so, may have to do some thing, like a "did power on reset" where if the LCD is known / believed to be powered up and assume it's in nybble mode?
	- OR, I guess we could send 8-bit mode then 4-bit mode? First try the register. Maybe both! Let's do both.
	- OR, maybe always do set to 8 bit then set to 4 bit? then see if it works on power-up?
	*****************************************************************************************************************************************************************
	*****************************************************************************************************************************************************************
	*****************************************************************************************************************************************************************
	*****************************************************************************************************************************************************************
	*****************************************************************************************************************************************************************
	*****************************************************************************************************************************************************************
	*****************************************************************************************************************************************************************

	----- if doing the 8-bit then 4-bit:
	Step -n: wait 100ms... do we need to, if we assume power is on? I guess if you have a single init for cold or warm, do this. Adds 1/10 sec to startup but wev

	Step -n-1 .. 0: contains multitudes. Do we have to do 3 4-bit sends of 0011, like steps 2, 3, 4 below, THEN ANOTHER 0011 instead of steps 5 and 6? LCD pins tied low mean it
	will assume N and F are 0, so 1 line and 5x8 font, acceptable. Also prolly send a display off ... only if it's in 8-bit, I can't bc that needs bit 3 to be 1 and it's tied low

	BUT FIRST DON'T WORRY RE THAT, get the power-on case working

	----- original
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

    /*
    // **********************************************
    // SO HERE IS THE LIST OF STATES WE'LL BE DEALING WITH IN THIS MODULE -
    // THIS WILL AMOUNT TO A BUNCH OF USES OF THE TIMER MODULE AND THE NYBBLE SENDER MODULE
	// ********************** INCOMPLETE! FIX!
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
            // SHOULD THERE BE A PIECE IN HERE ABOUT HOW IF WE ARE NEWLY RESET, SHUT THE LCD OFF?
            // i.e. if active == 1, ... hm.
			//
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
				if(already_did_reset) begin
					//do "warm boot" reset; possibly for safety's sake, do function set to 8 bit mode then set to 4 bit?
					//datasheet sez -------
					//Note: Perform the function at the head of the program before executing any instructions (except for the
					//read busy flag and address instruction). From this point, the function set instruction cannot be
					//executed unless the interface data length is changed.
					//end datasheet sez ---
					//8-bit-then-4-bit may be a way around the don't-do-function-set-after-init thing from the datasheet
				end else begin
					//do power-on reset

					//and after that, mark that the power-on reset has been done.
					already_did_reset <= 1;

				end
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
    */

endmodule
