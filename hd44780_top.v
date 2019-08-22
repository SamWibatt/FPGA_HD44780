// all top does is contain / handle platform-dependent stuff.
// it supplies a clock to a controller.
`default_nettype	none

// state delay module
/*
at posedge CLK_I:
    if reset:
        glue everything down
    else if strobe input:
        -- interrupt any ongoing countdown
        glue strobe output down
        load whatever is in the data input lines into current count
    else if current count is not 0:
        decrement current count
        if current count is 1:
            raise strobe
    else (current count IS 0):
        lower strobe
         glue strobe down
*/

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
parameter SYSFREQ = 48_000_000;


parameter STATE_TIMER_BITS = 7;     //will derive counts from clock freq at some point
module state_timer(
    input wire RST_I,
    input wire CLK_I,
    input wire [STATE_TIMER_BITS-1:0] DAT_I,
    input wire start_strobe,            // causes timer to load
    output wire end_strobe              // nudges caller to advance state
    );
    reg [STATE_TIMER_BITS-1:0] st_count = 0;
    reg end_strobe_reg = 0;

    if(RST_I == 1) begin
        end_strobe_reg <= 0;
    end else if(start_strobe == 1) begin
        end_strobe_reg <= 0;
        st_count <= DAT_I;
    end else if(|count) begin
        //count is not 0 - raise strobe in the last tick before it goes 0
        if(count == 1) begin
            end_strobe_reg <= 1;
        end
        st_count <= st_count-1;
    end else begin
        //counter is 0
        end_strobe_reg <= 0;
    end

    assign end_strobe = end_strobe_reg;

endmodule


// Main module -----------------------------------------------------------------------------------------

module hd44780_top(
    //lcd output pins
    output wire lcd_rs,                 //R/S pin - R/~W is tied low
    output wire lcd_e,                  //enable!
    output wire [3:0] lcd_data,         //data
    output wire alive_led,              //alive-blinky, use rgb green
    output wire led_b,                  //blue led bc rgb driver needs it
    output wire led_r                   //red led
    end
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
      .RGB2PWM  (ledX_r_reg),    //so I will do similar
      .CURREN   (1'b1),         // supply current; 0 shuts off the driver (verify)
      .RGB0     (alive_led),    //Actual Hardware connection - output wires. looks like it goes 0=green
      .RGB1     (led_b),        //1 = blue
      .RGB2     (led_r)         //2 = red - but verify
    );
    defparam rgb.CURRENT_MODE = "0b1";          //half current mode
    defparam rgb.RGB0_CURRENT = "0b000001";     //4mA for Full Mode; 2mA for Half Mode
    defparam rgb.RGB1_CURRENT = "0b000001";     //see SiliconBlue ICE Technology doc
    defparam rgb.RGB2_CURRENT = "0b000001";

    //***********************************************************************************************************
    //***********************************************************************************************************
    //***********************************************************************************************************
    // HEREAFTER UNCHANGED **************************************************************************************
    //***********************************************************************************************************
    //***********************************************************************************************************
    //***********************************************************************************************************

    /*
    // was this for small simulation clocks hd44780_controller #(.NEWMASK_CLK_BITS(9)) controller(
    // now let's try with real clock values, or as close as I can get - REAL ones take too long, but let's move it out more,
    // like have... 16 bits? default is 26, which is 1000 times longer.
    // one problem with this organization is that I can't get at the blinky's parameter - can I? Can I add a param to controller that
    // passes it along? Let us try. We want a blinky mask clock to be about 3 full cycles of 8... let's say 32x as fast as newmask clk so 5 fewer bits?
    // let's try 6 - ok, that proportion looks not bad!
    // but in practice I did 7 - so let's do that here
    parameter CTRL_MASK_CLK_BITS=30;      //is 28 default in controller, which was for 12MHz - so 30? try it. Good!
    wire led_outwire;
    hd44780_controller
        #(.NEWMASK_CLK_BITS(CTRL_MASK_CLK_BITS),.BLINKY_MASK_CLK_BITS(CTRL_MASK_CLK_BITS-7))
        controller(
        .i_clk(clk),
        .button_internal(button_acthi),          //will this work?
        .dip_switch(dip_swicth),
        .the_led(led_outwire),                   //was the_led), now the driver above is doing that
        .o_led0(o_led0),
        .o_led1(o_led1),
        .o_led2(o_led2),
        .o_led3(o_led3)
    );
    */

    wire led_outwire;

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

endmodule
