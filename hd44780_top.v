// all top does is contain / handle platform-dependent stuff.
// it supplies a clock to a controller.
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
`ifndef SIM_STEP
    //if we're not doing a simulation, we need these pcf pins
    //lcd output pins
    output wire lcd_rs,                 //R/S pin - R/~W is tied low
    output wire lcd_e,                  //enable!
    output wire [3:0] lcd_data,         //data
    input wire the_button,              //button
    output wire alive_led,              //alive-blinky, use rgb green ... from controller
    output wire led_b,                  //blue led bc rgb driver needs it
    output wire led_r,                   //red led
    output wire o_led0,     //set_io o_led0 36
    output wire o_led1,     //set_io o_led1 42
    output wire o_led2,     //set_io o_led2 38
    output wire o_led3      //set_io o_led3 28
`endif
    );

    //VARS FOR EITHER SIM OR BUILD
    

`ifdef SIM_STEP
    //testbench equivalents to the module ports up there
    wire lcd_rs;                 //R/S pin - R/~W is tied low
    wire lcd_e;                  //enable!
    wire [3:0] lcd_data;         //data
    wire the_button;
    wire alive_led;              //alive-blinky, use rgb green ... from controller
    wire led_b;                  //blue led bc rgb driver needs it
    wire led_r;                   //red led
    wire o_led0;     //set_io o_led0 36
    wire o_led1;     //set_io o_led1 42
    wire o_led2;     //set_io o_led2 38
    wire o_led3;     //set_io o_led3 28

    //***************** HERE HAVE TB-STYLE CLOCK
    //and then the clock, simulation style, 10 cycles per posedge on sys clk
    reg clk = 1;            //try this to see if it makes aligning clock delays below work right - they were off by half a cycle
    always #5 clk = (clk === 1'b0);
    
    wire button_acthi = ~the_button;            //not sure about this! Test in tb

`else
    //not sim-step;
    //and then the clock, up5k style
    // enable the high frequency oscillator,
	// which generates a 48 MHz clock
	wire clk;
	SB_HFOSC u_hfosc (
		.CLKHFPU(1'b1),
		.CLKHFEN(1'b1),
		.CLKHF(clk)
	);
    
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
    reg led_r_pwm_reg = 0;
    reg led_g_pwm_reg = 0;
    reg led_b_pwm_reg = 0;
    
    SB_RGBA_DRV rgb (
      .RGBLEDEN (1'b1),         // enable LED
      .RGB0PWM  (led_g_pwm_reg),    //these appear to be single-bit parameters. ordering determined by experimentation and may be wrong
      .RGB1PWM  (led_b_pwm_reg),    //driven from registers within counter arrays in every example I've seen
      .RGB2PWM  (led_r_pwm_reg),    //so I will do similar
      .CURREN   (1'b1),         // supply current; 0 shuts off the driver (verify)
      .RGB0     (alive_led),    //Actual Hardware connection - output wires. looks like it goes 0=green
      .RGB1     (led_b),        //1 = blue
      .RGB2     (led_r)         //2 = red - but verify
    );
    defparam rgb.CURRENT_MODE = "0b1";          //half current mode
    defparam rgb.RGB0_CURRENT = "0b000001";     //4mA for Full Mode; 2mA for Half Mode
    defparam rgb.RGB1_CURRENT = "0b000001";     //see SiliconBlue ICE Technology doc
    defparam rgb.RGB2_CURRENT = "0b000001";
    
    
    parameter PWMbits = 3;              // for dimming test, try having LED on only 1/2^PWMbits of the time
    reg[PWMbits-1:0] pwmctr = 0;
    always @(posedge clk) begin
        //assign output of main blinky to the driver module
        //ok, even this is a little too bright.
        //led_g_reg <= led_outwire;              //output from blinky is active high now , used to have ~led_outwire
        led_g_pwm_reg <= (&pwmctr) & led_outwire;    //when counter is all ones, turn on (if we're in a blink)
        pwmctr <= pwmctr + 1;
    end

    
`endif

    //copied verbatim from controller.
	// Super simple "I'm Alive" blinky on one of the external LEDs. Copied from controller
	parameter GREENBLINKBITS = `H4_TIMER_BITS + 4;		//see if can adjust to sim or build clock speed			//25;			// at 12 MHz 23 is ok - it's kind of hyper at 48. KEY THIS TO GLOBAL SYSTEM CLOCK FREQ DEFINE
											// and hey why not define that in top or tb instead of in the controller or even on command line - ok
											// now the define above is wrapped in `ifndef G_SYSFREQ so there you go
	reg[GREENBLINKBITS-1:0] greenblinkct = 0;
    always @(posedge clk) begin
		greenblinkct <= greenblinkct + 1;
	end

	wire led_outwire = ~greenblinkct[GREENBLINKBITS-1];	   //controller_alive, always block just above this - this line causes multiple driver problem

    //STUFF THAT SHUTS UP THE WARNINGS ABOUT UNUSUED PORTS - 
    reg reg_led0 = 0;
    reg reg_led1 = 0;
    reg reg_led2 = 0;
    reg reg_led3 = 0;
    
    always @(posedge clk) begin
        //for top pure blinky, set all active low other-blinkies to off
        reg_led0 <= 1;
        reg_led1 <= 1;
        reg_led2 <= 1;
        reg_led3 <= 1;
    end

    //place holder registers for red and blue LEDs of RGB. green taken up by 
    reg led_b_reg = 0;
    reg led_r_reg = 0;

    always @(posedge clk) begin
        //for top pure blinky, set red and blue RGBs off
        led_b_reg <= 1;
        led_r_reg <= 1;
    end


    
    //wire lcd_rs;                 //R/S pin - R/~W is tied low
    assign lcd_rs = 0;
    //wire lcd_e;                  //enable!
    assign lcd_e = 0;
    //wire [3:0] lcd_data;         //data
    assign lcd_data = 4'b1010;     //distinctive thing 
    //wire alive_led;              //alive-blinky, handled above
    //wire led_b;                  //blue led bc rgb driver needs it
    /* all this stuff looks necessary but ends up generating multiple-driver errors.
    assign led_b = led_b_reg; //assuming act high       - THESE WILL BE SET BY STUFF LIKE THE ALIVE BLINKY ABOVE>..
    //wire led_r;                   //red led
    assign led_r = led_r_reg; //assuming act high
    //wire o_led0;     //set_io o_led0 36
    assign o_led0 = reg_led0;     //act low
    //wire o_led1;     //set_io o_led1 42
    assign o_led1 = reg_led1;     //act low
    //wire o_led2;     //set_io o_led2 38
    assign o_led2 = reg_led2;     //act low
    //wire o_led3;     //set_io o_led3 28
    assign o_led3 = reg_led3;     //act low
    */
    

    
    
	/* LATER when we know the blinky works
    //we DO also want a wishbone syscon and a controller!
    wire wb_reset;
    wire wb_clk;
    hd44780_syscon syscon(
        .i_clk(clk),
        .RST_O(wb_reset),
        .CLK_O(wb_clk)
        );

    hd44780_state_timer timey(
        .RST_I(wb_reset),
        .CLK_I(wb_clk),
    	input wire [STATE_TIMER_BITS-1:0] DAT_I,	//[STATE_TIMER_BITS-1:0] DAT_I,
        input wire start_strobe,            // causes timer to load
        output wire end_strobe             // nudges caller to advance state
        );

    //THEN OTHER STUFF
	end LATER when we know the blinky works */

endmodule
