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
