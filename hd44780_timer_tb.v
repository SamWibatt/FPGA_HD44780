//*********************************************************************************************************0
//*********************************************************************************************************0
//*********************************************************************************************************0
//For Goal 1 - State Timer
// THIS IS THE ORIGINAL TEST BENCH FOR THE STATE TIMER as of 8/31/19.
// THE TIMER MAY CHANGE AFTER THAT, THIS IS JUST FOR THE RECORD.
// use sim_timer.sh to run this in isolation.
// uses the values for delay defines in hd44780_sim_config.inc unless you change sim_timer.sh not
// to use the SIM_STEP define, in which case it will use hd44780_build_config.inc
//
// Set up so that every 10 simulation ticks = 1 system tick, ignore the units (microseconds, for no real reason.)
// that is,
// #10 x = 1
// the #10 covers one system clock. Useful for this so I can show that a 1200-tick call to the
// state timer has 12,000 simulation ticks between the drop of the input strobe and the raise of the output one.
//
//*********************************************************************************************************0
//*********************************************************************************************************0
//*********************************************************************************************************0

//testbench is very much like top but we drive all the signals with assignments instead of THE REAL WORLD.
//so let's start by copying top
`default_nettype	none

//Timescale seems to be pretty useless on its own for emulating a real system tick, since it SHRIEKS if I try
//to start either of the values with a digit other than "1" and sometimes you want an 83.333 ns tick.
//and the documentation around it is infinity repostings of the same missing-the-point advice,
//like misheard and typo-riddled song lyrics potatostamped all over the web by unthinking spiders.
//so, you could set the fractional part to 1ps and do delays like #83.333
//...which would likely generate a hojillion-byte vcd before its conversion to fst.
//...which are wrong for any other clock speed.
//so let's just use a value that's easy to count.
//One problem is that the "clock", the way I simulate it, takes two simulation ticks for one clock tick.
//what if... I use always #5 for the clock and make all the events a multiple of 10?
`timescale 1ns/1ns


// Main module -----------------------------------------------------------------------------------------

module hd44780_timer_tb;
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
    //was always #1 clk = (clk === 1'b0);
    //test: see if we can make easier-to-count values by having a system tick be 10 clk ticks
    always #5 clk = (clk === 1'b0);

    //we DO also want a wishbone syscon and a controller!
    wire wb_reset;
    wire wb_clk;
    hd44780_syscon syscon(
        .i_clk(clk),
        .RST_O(wb_reset),
        .CLK_O(wb_clk)
        );

    reg[`H4_TIMER_BITS-1:0] time_len = 0;
    reg ststrobe = 0;                       //start strobe
    //wire ststrobe_wire = ststrobe;        //try this assign to see if start strobe will work with it
    wire tmr_busy;
    hd44780_state_timer stimey(
        .RST_I(wb_reset),
        .CLK_I(wb_clk),
        .DAT_I(time_len),
        .start_strobe(ststrobe), //(ststrobe_wire),       //this was ststrobe, and we weren't seeing the strobe in controller
        .busy(tmr_busy)
        );


    //whatever we're testing, we need to dump gtkwave-viewable trace
    initial begin
        $dumpfile("hd44780_timer_tb.vcd");
        $dumpvars(0, hd44780_timer_tb);
    end

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
        //THIS HAS BEEN UPDATED FOR THE 5-tick clock, 10-tick sysclk version, if that ends up being useful
        //***********************************************************************************************
        //***********************************************************************************************
        //***********************************************************************************************
        #90 time_len = `H4_DELAY_100US;
        #10 ststrobe = 1;
        //notes from original discovery when using 2 ticks = system tick, now 10 ticks = system tick
        //is this too short?
        //#1 ststrobe = 0; //it appears to be! Let's see if it works on an even tick (orig first was #17)
        //if first is #17
        //we should do #2 anyway bc clock tick is 2 sim ticks? Yes.
        #50 ststrobe = 0;       //ok so what this shews is that the timer raises its out strobe n ticks
                                //after instrobe is raised - if it's 1 tick wide. Better to look at it as
                                //n-1 ticks after strobe drops, and we want n ticks after strobe drops.
                                //***** now fixed


        //let's try a real degenerate case - but one that's going to come up at slow clock speeds - 1 tick
        //was
        //#250 time_len = 1;
        //but the problem was if the config had h4_delay_100us as < 250 sim ticks = 25 system ticks, we'd
        //trample this - WHICH WAS A NICE INFORMAL TEST OF BEHAVIOR WHEN THE CLOCK WAS INTERRUPTED, and
        //looked like it behaved correctly, but that's not the point of this test - so, let's use
        //a variable delay. Need to multiply the delay ticks by 10 to convert to simulation ticks.
        #((`H4_DELAY_100US * 10) + 250) time_len = 1;   //`H4_DELAY_100US;
        #10 ststrobe = 1;
        #20 ststrobe = 0; //it appears to be! Let's see if it works on an even tick (orig first was #17)

        //let's try a real degenerate case - one that should never come up, but I should trap for it.
        //expected behavior is that end strobe comes high the cycle after startstrobe drops.
        #250 time_len = 0;
        #10 ststrobe = 1;
        #10 ststrobe = 0; //it appears to be! Let's see if it works on an even tick (orig first was #17)

        //then an official test to see what happens if we interrupt a timer. Load up the 100ms again but
        //interrupt it after a short while with a little county-count.
        #100 time_len = `H4_DELAY_100US;
        #10 ststrobe = 1;
        #10 ststrobe = 0;

        //so halfway through its count, start a littlie
        #((`H4_DELAY_100US / 2) * 10) time_len = 7;
        #10 ststrobe = 1;
        //long strobe, show exactly how the timer is derailed - and, it appears, correctly.
        #100 ststrobe = 0;


        #1000 $finish;
    end
    // ------------------------8<--------------------------------8<-----------------------------------

endmodule
