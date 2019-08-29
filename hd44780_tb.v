//testbench is very much like top but we drive all the signals with assignments instead of THE REAL WORLD.
//so let's start by copying top
`default_nettype	none

//?
`timescale 100ns/100ns


// Main module -----------------------------------------------------------------------------------------

module hd44780_tb;
    // (
    // //lcd output pins
    // output wire lcd_rs,                 //R/S pin - R/~W is tied low
    // output wire lcd_e,                  //enable!
    // output wire [3:0] lcd_data,         //data
    // output wire alive_led,              //alive-blinky, use rgb green ... from controller
    // output wire led_b,                  //blue led bc rgb driver needs it
    // output wire led_r                   //red led
    // );

    //and then the clock, simulation style
    reg clk = 1;            //try this to see if it makes aligning clock delays below work right - they were off by half a cycle
    always #1 clk = (clk === 1'b0);

    wire led_b, led_r;
    //looks like the pwm parameters like registers - not quite sure how they work, but let's
    //just create some registers and treat them as active-high ... Well, we'll see what we get.
    reg led_r_reg = 0;
    reg led_g_reg = 0;
    reg led_b_reg = 0;

    //LED driver setup for 5k, rip out
    // SB_RGBA_DRV rgb (
    //   .RGBLEDEN (1'b1),         // enable LED
    //   .RGB0PWM  (led_g_reg),    //these appear to be single-bit parameters. ordering determined by experimentation and may be wrong
    //   .RGB1PWM  (led_b_reg),    //driven from registers within counter arrays in every example I've seen
    //   .RGB2PWM  (led_r_reg),    //so I will do similar
    //   .CURREN   (1'b1),         // supply current; 0 shuts off the driver (verify)
    //   .RGB0     (alive_led),    //Actual Hardware connection - output wires. looks like it goes 0=green
    //   .RGB1     (led_b),        //1 = blue
    //   .RGB2     (led_r)         //2 = red - but verify
    // );
    // defparam rgb.CURRENT_MODE = "0b1";          //half current mode
    // defparam rgb.RGB0_CURRENT = "0b000001";     //4mA for Full Mode; 2mA for Half Mode
    // defparam rgb.RGB1_CURRENT = "0b000001";     //see SiliconBlue ICE Technology doc
    // defparam rgb.RGB2_CURRENT = "0b000001";

    wire led_outwire;       //************ NEED TO DRIVE THIS WITH SOME BLINKINESS or what?
    //assign led_outwire =

    //up5k LED setup brightness (effectively)
    // //alive blinky
    // parameter PWMbits = 3;              // for dimming test, try having LED on only 1/2^PWMbits of the time
    // reg[PWMbits-1:0] pwmctr = 0;
    // always @(posedge clk) begin
    //     //assign output of main blinky to the driver module
    //     //ok, even this is a little too bright.
    //     //led_g_reg <= led_outwire;              //output from blinky is active high now , used to have ~led_outwire
    //     led_g_reg <= (&pwmctr) & led_outwire;    //when counter is all ones, turn on (if we're in a blink)
    //     pwmctr <= pwmctr + 1;
    // end

    //we DO also want a wishbone syscon and a controller!
    wire wb_reset;
    wire wb_clk;
    hd44780_syscon syscon(
        .i_clk(clk),
        .RST_O(wb_reset),
        .CLK_O(wb_clk)
        );


    //whatever we're testing, we need to dump gtkwave-viewable trace
    initial begin
        $dumpfile("hd44780_tb.vcd");
        $dumpvars(0, hd44780_tb);
    end


    //we're not quite ready to try the whole controller. Let's do little modules first - timer and nybble sender.
    // hd44780_controller controller(
    //
    //     );

    // ------------------------8<--------------------------------8<-----------------------------------
    // module hd44780_state_timer  #(parameter SYSFREQ = `H4_SYSFREQ, parameter STATE_TIMER_BITS = `H4_TIMER_BITS)
    // (
    //     input wire RST_I,
    //     input wire CLK_I,
    // 	input wire [STATE_TIMER_BITS-1:0] DAT_I,	//[STATE_TIMER_BITS-1:0] DAT_I,
    //     input wire start_strobe,            // causes timer to load
    //     output wire end_strobe             // nudges caller to advance state
    //     );

    reg[`H4_TIMER_BITS-1:0] time_len = 0;
    reg ststrobe = 0;                       //start strobe
    //wire ststrobe_wire = ststrobe;        //try this assign to see if start strobe will work with it
    wire endstrobe;
    hd44780_state_timer stimey(
        .RST_I(wb_reset),
        .CLK_I(clk),
        .DAT_I(time_len),
        .start_strobe(ststrobe), //(ststrobe_wire),       //this was ststrobe, and we weren't seeing the strobe in controller
        .end_strobe(endstrobe)
        );

    //ok so here is our little benchie for the state timer!
    //put in a number, raise and lower strobe, roll a while and see about that end strobe!
    //cases: load while running (should trample old and do new)
    //1 cycle wait, 0 cycle wait?

    initial begin
        //***********************************************************************************************
        //***********************************************************************************************
        //***********************************************************************************************
        //OK, HERE IS A THING, if you raise a strobe on an odd # in this tb, and lower it in #1,
        //that's not enough of a signal to trigger a strobe! the clock is 2 tb-ticks wide, yes?
        //***********************************************************************************************
        //***********************************************************************************************
        //***********************************************************************************************
        #18 time_len = `H4_DELAY_100US;
        #2 ststrobe = 1;
        //is this too short?
        //#1 ststrobe = 0; //it appears to be! Let's see if it works on an even tick (orig first was #17)
        //if first is #17
        //we should do #2 anyway bc clock tick is 2 sim ticks? Yes.
        #20 ststrobe = 0;       //ok so what this shews is that the timer raises its out strobe n ticks
                                //after instrobe is raised - if it's 1 tick wide. Better to look at it as
                                //n-1 ticks after strobe drops, and we want n ticks after strobe drops.
                                //now fixed


        //let's try a real degenerate case - but one that's going to come up at slow clock speeds - 1 tick
        #50 time_len = 1;   //`H4_DELAY_100US;
        #2 ststrobe = 1;
        #8 ststrobe = 0; //it appears to be! Let's see if it works on an even tick (orig first was #17)

        //let's try a real degenerate case - one that should never come up, but I should trap for it.
        //expected behavior is that end strobe comes high the cycle after startstrobe drops.
        #50 time_len = 0;
        #2 ststrobe = 1;
        #2 ststrobe = 0; //it appears to be! Let's see if it works on an even tick (orig first was #17)

        #1000 $finish;
    end
    // ------------------------8<--------------------------------8<-----------------------------------


endmodule


/* Original TB
`default_nettype	none

// not very realistic for 48MHz ... see if it works. Nope, 20 isn't a good one
`timescale 10ns/10ns
//***********************************************************************************************************
//***********************************************************************************************************
//***********************************************************************************************************
// HEREAFTER UNCHANGED **************************************************************************************
//***********************************************************************************************************
//***********************************************************************************************************
//***********************************************************************************************************


// Main module -----------------------------------------------------------------------------------------

module hd44780_tb;
    reg clk = 0;
    always #1 clk = (clk === 1'b0);

    wire reset;
    wire sysclk;
    wire strobe;
    wire[7:0] data;
    wire led;                       //active high LED
    reg buttonreg = 0;              // simulated button input
    wire buttonhi = ~buttonreg;     //assign! need active high for controller
    wire led0, led1, led2, led3;    //other lights on the icestick
    reg mnt_stb=0;       //STB_I,   //then here is the student that takes direction from testbench
    reg[7:0] mnt_data=8'b00000000;  //DAT_I
    reg[7:0] dipswitch_reg=8'b1111_1111; //initial value to avoid X values at start; active low so all off.
    wire[7:0] dipswitch_wires = dipswitch_reg;



    //module hd44780_controller(
    //    input i_clk,
    //    output RST_O
    //    output CLK_O
    //           );

    // was this for small simulation clocks hd44780_controller #(.NEWMASK_CLK_BITS(9)) controller(
    // now let's try with real clock values, or as close as I can get - REAL ones take too long, but let's move it out more,
    // like have... 16 bits? default is 26, which is 1000 times longer.
    // one problem with this organization is that I can't get at the blinky's parameter - can I? Can I add a param to controller that
    // passes it along? Let us try. We want a blinky mask clock to be about 3 full cycles of 8... let's say 32x as fast as newmask clk so 5 fewer bits?
    // let's try 6 - ok, that proportion looks not bad!
    // but in practice I did 7 - so let's do that here
    parameter CTRL_MASK_CLK_BITS=16; //20;    //26 is "real?";  FROM CALCS IN THE LOOP BELOW I THINK 25 WILL BE IT     //works at 16 and 20
    hd44780_controller
        //#(.NEWMASK_CLK_BITS(CTRL_MASK_CLK_BITS),.BLINKY_MASK_CLK_BITS(CTRL_MASK_CLK_BITS-7))
        controller(
        .i_clk(clk),
        .button_internal(buttonhi),
        .dip_switch(dipswitch_wires),
        .the_led(led),
        .o_led0(led0),
        .o_led1(led1),
        .o_led2(led2),
        .o_led3(led3)
    );

    //bit for creating gtkwave output
    initial begin
        //uncomment the next two for gtkwave?
        $dumpfile("hd44780_tb.vcd");
        $dumpvars(0, hd44780_tb);
    end

    initial begin
        #0 buttonreg = 1;           //active low
        #1 dipswitch_reg = 8'b01011111;         //user-swicthed mask. ACTIVE LOW. classic blink-blink
        //drive button! Now we can do that
        #7 buttonreg = 0;
        #100 buttonreg = 1;

        //try one before release interval done?
        #30023 buttonreg = 0;
        #19 buttonreg = 1;

        //then set up some new data
        #1 dipswitch_reg = 8'b00110011;         //user-swicthed mask ACTIVE LOW. slower steady flash

        // then one that does take, in order to toggle the LED
        #137 buttonreg = 0;
        #75 buttonreg = 1;

        #100000 $finish;           //longer sim, mask clock is now 16 bits. 5 sec run on vm, 30M vcd.
    end

endmodule
*/
