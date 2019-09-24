// all top does is contain / handle platform-dependent stuff.
// it supplies a clock to a controller.
// and whatever else I feel like. For this project, it's like the main for the chosen build.
//WIRING IS THE SAME FOR ALL THE SUBPROJECTS! on the up5k, Well, see the pcf. and the top module ports.
//the only tricky one is the_button, up5k gpio 4, which should be an input, active low, pulled up.
//everything else is LCD signals r_s/e/nybble, a bunch of alive LEDs (some active high, the up5k's rgb module,)
// some active low (external alive-LEDs, which go +V -> current limiting resistor -> anode, cathode -> pin)
// Divided clock down to run at 6MHz so can pick stuff up better with logic analysizer,
//


`default_nettype	none

//project wide timing data
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

// Main module -----------------------------------------------------------------------------------------

module hd44780_top(
    //lcd output pins
    output wire lcd_rs,                 //R/S pin - R/~W is tied low
    output wire lcd_e,                  //enable!
    output wire [3:0] lcd_data,         //data
    input wire the_button,              //button
    output wire led_g,              //alive-blinky, use rgb green ... from controller
    output wire led_b,                  //blue led bc rgb driver needs it
    output wire led_r,                   //red led
    output wire o_led0,     //set_io o_led0 36
    output wire o_led1,     //set_io o_led1 42
    output wire o_led2,     //set_io o_led2 38
    output wire o_led3,      //set_io o_led3 28
    output wire logan_strobe    // strobe out pin to ping the logic analyzer to start
    );

    // PLATFORM-SPECIFIC STUFF ==================================================================================
    //not sim-step;
    //and then the clock, up5k style
    // enable the high frequency oscillator,
	// which generates a 48 MHz clock - later, divided down to 6 MHz.
    /* Ice40 osc user guide page 8 has this div thing -
    SB_HFOSC OSCInst0 (
    .CLKHFEN(ENCLKHF),
    .CLKHFPU(CLKHF_POWERUP),
    .CLKHF(CLKHF)
    ) / * synthesis ROUTE_THROUGH_FABRIC= [0|1] * /;
    Defparam OSCInst0.CLKHF_DIV = 2’b00;
    */
	wire clk;
    /* original
	SB_HFOSC u_hfosc (
		.CLKHFPU(1'b1),
		.CLKHFEN(1'b1),
		.CLKHF(clk)
	);
    */
    //ok, this way of setting the divider worked, and 0b10 should be /4 = 12MHz. Let's rerun
    //the config for build setup for ... let's do 6MHz, /8, for better logic analysizer read.
    SB_HFOSC #(.CLKHF_DIV("0b11")) u_hfosc (
		.CLKHFPU(1'b1),
		.CLKHFEN(1'b1),
		.CLKHF(clk)
	);
    //The SB_HFOSC primitive contains the following parameter and their default values:
    //Parameter CLKHF_DIV = 2’b00 : 00 = div1, 01 = div2, 10 = div4, 11 = div8 ; Default = “00”
    //Defparam u_hfosc.CLKHF_DIV = 2’b10;     //test div 4

    // INPUT BUTTON - after https://discourse.tinyfpga.com/t/internal-pullup-in-bx/800
    wire button_internal;
    wire button_acthi;
    SB_IO #(
        .PIN_TYPE(6'b 0000_01),     // PIN_NO_OUTPUT | PIN_INPUT (not latched or registered)
        .PULLUP(1'b 1)              // enable pullup and there's our active low
    ) button_input(
        .PACKAGE_PIN(the_button),   //has to be a pin in bank 0,1,2
        .D_IN_0(button_internal)
    );
    assign button_acthi = ~button_internal;


    //looks like the pwm parameters like registers - not quite sure how they work, but let's
    //just create some registers and treat them as active-high ... Well, we'll see what we get.
    //these work basically like an "on" bit, just write a 1 to turn LED on. PWM comes from you
    //switching it on and off and stuff.
    reg led_r_pwm_reg = 0;
    reg led_g_pwm_reg = 0;
    reg led_b_pwm_reg = 0;

    SB_RGBA_DRV rgb (
      .RGBLEDEN (1'b1),         // enable LED
      .RGB0PWM  (led_g_pwm_reg),    //these appear to be single-bit parameters. ordering determined by experimentation and may be wrong
      .RGB1PWM  (led_b_pwm_reg),    //driven from registers within counter arrays in every example I've seen
      .RGB2PWM  (led_r_pwm_reg),    //so I will do similar
      .CURREN   (1'b1),         // supply current; 0 shuts off the driver (verify)
      .RGB0     (led_g),    //Actual Hardware connection - output wires. looks like it goes 0=green
      .RGB1     (led_b),        //1 = blue
      .RGB2     (led_r)         //2 = red - but verify
    );
    defparam rgb.CURRENT_MODE = "0b1";          //half current mode
    defparam rgb.RGB0_CURRENT = "0b000001";     //4mA for Full Mode; 2mA for Half Mode
    defparam rgb.RGB1_CURRENT = "0b000001";     //see SiliconBlue ICE Technology doc
    defparam rgb.RGB2_CURRENT = "0b000001";

    //stuff that is not particular to
    wire led_g_outwire;       //************ NEED TO DRIVE THIS WITH SOME BLINKINESS or what?
    //assign led_g_outwire =

    //alive blinky
    parameter PWMbits = 3;              // for dimming test, try having LED on only 1/2^PWMbits of the time
    reg[PWMbits-1:0] pwmctr = 0;
    always @(posedge clk) begin
        //assign output of main blinky to the driver module
        //ok, even this is a little too bright.
        //led_g_reg <= led_g_outwire;              //output from blinky is active high now , used to have ~led_g_outwire
        led_g_pwm_reg <= (&pwmctr) & led_g_outwire;    //when counter is all ones, turn on (if we're in a blink)
        led_b_pwm_reg <= (&pwmctr) & led_b_outwire;
        led_r_pwm_reg <= (&pwmctr) & led_r_outwire;
        pwmctr <= pwmctr + 1;
    end
    // END PLATFORM-SPECIFIC STUFF ==============================================================================

    // MULTI-USEFUL STUFF =======================================================================================

    //syscon!
    //we DO also want a wishbone syscon and a controller!
    wire wb_reset;
    wire syscon_reset;
    wire wb_clk;
    hd44780_syscon syscon(
        .i_clk(clk),
        .RST_O(syscon_reset),
        .CLK_O(wb_clk)
        );


    // HERE IS THE BUTTON THING - single register that just remembers if button has EVER been pressed,
    // which doesn't have to be very accurate (and I'm curious to see how it looks) for the logic analyzer.
    // So now this circuit will have the RGB LEDs only blinking along, external LEDs dark, until you push the
    // button, and then the alives fire up.
    reg button_has_been_pressed = 0;
    reg logan_strobe_reg = 0;           //sync signal for when the logic analyzer strobe pin goes high

    always @(posedge clk) begin
        if(~button_has_been_pressed) begin
            if(button_acthi) begin
                //try a completely undebounced button press - this is what the logic analyzer will watch for too
                //looks pretty harmless.
                button_has_been_pressed <= 1;
                logan_strobe_reg <= 1;      // yay, fling logic analyzer strobe to a pin tt
            end
        end
    end

    //extend the reset to wait for the button to be pressed.
    //that way, the wishbone-like stuff won't trigger until we're ready to
    //capture it.
    assign wb_reset = syscon_reset | ~button_has_been_pressed;
    //logic analyzer waits for pos edge of this
    assign logan_strobe = logan_strobe_reg;


    // alive-blinky wires:
    wire led_g_outwire; // = ~greenblinkct[GREENBLINKBITS-1];	   //controller_alive, always block just above this - this line causes multiple driver problem
    wire led_b_outwire; // = greenblinkct[GREENBLINKBITS-1];
    wire led_r_outwire; // = ~greenblinkct[GREENBLINKBITS-2];


    // end MULTI-USEFUL STUFF ===================================================================================

`ifdef LCD_TARGET_TIMER
`include "top_timer_test_inc.v"             //breaking these out into inc files bc this will be a mess otherwise; see how that goes
`elsif LCD_TARGET_NYBSEN
    //this doesn't work here $display("doing target timer top!");
    //*****************************************************************************************
    //NOW STUFF FOR TESTING THE LCD PINS!
    //WHICH IS THE ENTIRE POINT OF ALL OF THIS!
    //reg lcd_rs_reg = 0;
    reg lcd_e_reg = 0;
    reg [3:0] lcd_data_reg = 4'b0000;
    //*****************************************************************************************

    reg nybsen_strobe = 0;

    //PUT ACTUAL NYBBLE SENDER AND TEST OF IT HERE
    //PUT ACTUAL NYBBLE SENDER AND TEST OF IT HERE
    //PUT ACTUAL NYBBLE SENDER AND TEST OF IT HERE
    //PUT ACTUAL NYBBLE SENDER AND TEST OF IT HERE
    module hd44780_nybble_sender(
        .RST_I(wb_reset),                    //wishbone reset, also on falling edge of reset we want to do the whole big LCD init.
        .CLK_I(wb_clk),
        .STB_I(nybsen_strobe),                    //to let this module know rs and lcd_data are ready and to do its thing.
        .i_rs(lcd_rs),                     //register select - command or data, will go to LCD RS pin
        .i_nybble(),       //nybble we're sending
        .o_busy(),             //whether this module is busy
        .o_lcd_data(),   //the data bits we send really are 7:4 - I guess others NC? tied low?
                                        //check vpok. also I saw a way to do 7:4 -> 3:0 but - well, later
        .o_rs(),
        .o_e()                 //LCD enable pin
        );

    //wire lcd_rs;                 //R/S pin - R/~W is tied low
    //assign lcd_rs = lcd_rs_reg; // was st_start_stb;   //mirror start strobe with rs for LA visibility - was lcd_rs_reg;
    //wire lcd_e;                  //enable!
    assign lcd_e = st_end_stb | st_start_stb;  //mirror START AND end strobe with e for LA visitbility - was lcd_e_reg;
    //wire [3:0] lcd_data;         //data
    assign lcd_data = lcd_data_reg;     //What's something interesting to do with lcd_data_reg? currently counting

    // TESTER OF ALL LEDs =======================================================================================
	// Super simple "I'm Alive" blinky on one of the external LEDs. Copied from controller
	parameter GREENBLINKBITS = `H4_TIMER_BITS + 2;		//see if can adjust to sim or build clock speed			//25;			// at 12 MHz 23 is ok - it's kind of hyper at 48. KEY THIS TO GLOBAL SYSTEM CLOCK FREQ DEFINE
											// and hey why not define that in top or tb instead of in the controller or even on command line - ok
											// now the define above is wrapped in `ifndef G_SYSFREQ so there you go
	reg[GREENBLINKBITS-1:0] greenblinkct = 0;
    always @(posedge clk) begin
		greenblinkct <= greenblinkct + 1;
	end

	assign led_g_outwire = ~greenblinkct[GREENBLINKBITS-1];	   //controller_alive, always block just above this - this line causes multiple driver problem
    assign led_b_outwire = greenblinkct[GREENBLINKBITS-1];
    assign led_r_outwire = ~greenblinkct[GREENBLINKBITS-2];

    //STUFF THAT SHUTS UP THE WARNINGS ABOUT UNUSUED PORTS -
    reg reg_led0 = 0;
    reg reg_led1 = 0;
    reg reg_led2 = 0;
    reg reg_led3 = 0;

    //mad alive blinkies

    always @(posedge clk) begin
        if(button_has_been_pressed) begin
            //for top pure blinky, set all active low other-blinkies to off
            //this was failing with the assigns below when I had <= 1 here; bad driver sort of sitch?
            reg_led0 <= greenblinkct[GREENBLINKBITS-2];
            reg_led1 <= ~greenblinkct[GREENBLINKBITS-3];
            reg_led2 <= greenblinkct[GREENBLINKBITS-3];
            reg_led3 <= ~greenblinkct[GREENBLINKBITS-4];
        end else begin
            // glue LEDs off
            reg_led0 <= 1;
            reg_led1 <= 1;
            reg_led2 <= 1;
            reg_led3 <= 1;
        end
    end

    //wire o_led0;     //set_io o_led0 36
    assign o_led0 = reg_led0;     //act low
    //wire o_led1;     //set_io o_led1 42
    assign o_led1 = reg_led1;     //act low
    //wire o_led2;     //set_io o_led2 38
    assign o_led2 = reg_led2;     //act low
    //wire o_led3;     //set_io o_led3 28
    assign o_led3 = reg_led3;     //act low

    // END TESTER OF ALL LEDs ===================================================================================
`endif //LCD_TARGET_NYBSEN - work out what else can be extracted






	/* LATER when we know the blinky works
    //we DO also want a wishbone syscon and a controller!
    wire wb_reset;
    wire wb_clk;
    hd44780_syscon syscon(
        .i_clk(clk),
        .RST_O(wb_reset),
        .CLK_O(wb_clk)
        );

    reg [`H4_TIMER_BITS-1:0] st_dat = 0;
    reg st_start_stb = 0;
    wire st_end_stb;
    hd44780_state_timer timey(
        .RST_I(wb_reset),
        .CLK_I(wb_clk),
    	.DAT_I(st_dat),
        .start_strobe(st_start_stb),            // causes timer to load
        .end_strobe(st_end_stb)             // nudges caller to advance state
        );

    //THEN OTHER STUFF
    //super first test: just turn on green LED
    //FIGURE THIS OUT and write the alive-blinkies in the timer and nybsen and all
    assign led_g_outwire = 1;
    assign led_g = 1;       //dunt work.
    */
endmodule
