// all top does is contain / handle platform-dependent stuff.
// it supplies a clock to a controller.
`default_nettype	none


// Main module -----------------------------------------------------------------------------------------

module hd44780_top(
    //lcd output pins
    output wire lcd_rs,                 //R/S pin - R/~W is tied low
    output wire lcd_e,                  //enable!
    output wire [3:0] lcd_data,         //data
    output wire alive_led,              //alive-blinky, use rgb green ... from controller
    output wire led_b,                  //blue led bc rgb driver needs it
    output wire led_r                   //red led
    );

    //and then the clock, up5k style
    // enable the high frequency oscillator,
	// which generates a 48 MHz clock
	wire clk;
	SB_HFOSC u_hfosc (
		.CLKHFPU(1'b1),
		.CLKHFEN(1'b1),
		.CLKHF(clk)
	);

    wire led_b, led_r;
    //looks like the pwm parameters like registers - not quite sure how they work, but let's
    //just create some registers and treat them as active-high ... Well, we'll see what we get.
    reg led_r_reg = 0;
    reg led_g_reg = 0;
    reg led_b_reg = 0;
    SB_RGBA_DRV rgb (
      .RGBLEDEN (1'b1),         // enable LED
      .RGB0PWM  (led_g_reg),    //these appear to be single-bit parameters. ordering determined by experimentation and may be wrong
      .RGB1PWM  (led_b_reg),    //driven from registers within counter arrays in every example I've seen
      .RGB2PWM  (led_r_reg),    //so I will do similar
      .CURREN   (1'b1),         // supply current; 0 shuts off the driver (verify)
      .RGB0     (alive_led),    //Actual Hardware connection - output wires. looks like it goes 0=green
      .RGB1     (led_b),        //1 = blue
      .RGB2     (led_r)         //2 = red - but verify
    );
    defparam rgb.CURRENT_MODE = "0b1";          //half current mode
    defparam rgb.RGB0_CURRENT = "0b000001";     //4mA for Full Mode; 2mA for Half Mode
    defparam rgb.RGB1_CURRENT = "0b000001";     //see SiliconBlue ICE Technology doc
    defparam rgb.RGB2_CURRENT = "0b000001";

    wire led_outwire;       //************ NEED TO DRIVE THIS WITH SOME BLINKINESS or what?
    //assign led_outwire =

    //alive blinky
    parameter PWMbits = 3;              // for dimming test, try having LED on only 1/2^PWMbits of the time
    reg[PWMbits-1:0] pwmctr = 0;
    always @(posedge clk) begin
        //assign output of main blinky to the driver module
        //ok, even this is a little too bright.
        //led_g_reg <= led_outwire;              //output from blinky is active high now , used to have ~led_outwire
        led_g_reg <= (&pwmctr) & led_outwire;    //when counter is all ones, turn on (if we're in a blink)
        pwmctr <= pwmctr + 1;
    end

    //we DO also want a wishbone syscon and a controller!
    wire wb_reset;
    wire wb_clk;
    hd44780_syscon syscon(
        .i_clk(clk),
        .RST_O(wb_reset),
        .CLK_O(wb_clk)
        );

    hd44780_controller controller(
            //GOING TO GO WRITE THIS IN TB AND BRING IT BACK HERE 
        );

endmodule
