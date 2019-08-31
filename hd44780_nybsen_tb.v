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

module hd44780_nybsen_tb;
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


    //whatever we're testing, we need to dump gtkwave-viewable trace
    initial begin
        $dumpfile("hd44780_nybsen_tb.vcd");
        $dumpvars(0, hd44780_nybsen_tb);
    end

    /* TB FOR NYBBLE SENDER */
    // ------------------------8<--------------------------------8<-----------------------------------
    //now here is a tb for a nybble sender! DO THIS ONE WITH A HIGH ENOUGH CLOCK SPEED THAT THE COUNTER IN NYBSEN IS MEANINGFUL - trying 12000000
    //module hd44780_nybble_sender(
    //    input RST_I,                    //wishbone reset, also on falling edge of reset we want to do the whole big LCD init.
    //    input CLK_I,
    //    input STB_I,                    //to let this module know rs and lcd_data are ready and to do its thing.
    //    input i_rs,                     //register select - command or data, will go to LCD RS pin
    //    input wire[3:0] i_nybble,       //nybble we're sending
    //    output wire o_busy,             //whether this module is busy
    //    output wire [3:0] o_lcd_data,   //the data bits we send really are 7:4 - I guess others NC? tied low?
    //    output wire o_rs,
    //    output wire o_e                 //LCD enable pin
    //    );

    reg ststrobe = 0;                       //start strobe
    wire busy;
    reg rs_reg = 0;
    reg [3:0] nybbin = 4'b0000;

    //in real hardware these are package pins
    wire pin_busy;
    wire [3:0] pins_data;
    wire pin_rs;
    wire pin_e;

    hd44780_nybble_sender nybsen(
        .RST_I(wb_reset),
        .CLK_I(wb_clk),
        .STB_I(ststrobe),
        .i_rs(rs_reg),
        .i_nybble(nybbin),
        .o_busy(pin_busy),
        .o_lcd_data(pins_data),
        .o_rs(pin_rs),
        .o_e(pin_e)
    );

    initial begin
        //set up and send some stuff, osberve behavior of nybble sender
        /* for the #1 clk, 2-tick system clock
        #18 nybbin = 4'b1011;           //pick a distinctive nybble
        rs_reg = 1;                       //and send rs high just 'cause
        #2 ststrobe = 1;
        #2 ststrobe = 0;
        #1000 $finish;
        */
        //#5 tick, 10 ticks/syclck, swh
        #90 nybbin = 4'b1011;           //pick a distinctive nybble
        rs_reg = 1;                       //and send rs high just 'cause
        #10 ststrobe = 1;
        #10 ststrobe = 0;

        //what if we do a really long strobe? currently it doesn't work.
        //lemme go look at that
        //********************* HEY ADJUST THE DELAY HERE USING FREQ DEFINES
        //OR wait for the LCD busy to happen ?
        #700 nybbin = 4'b0100;           //pick a distinctive nybble
        rs_reg = 0;                       //and send rs low just 'cause
        #10 ststrobe = 1;
        #500 ststrobe = 0;

        //***********************************************************************
        //OK SO WRITE SOME ANOMALIES - like when the second test there was #90
        //at first instread of #1000, with 12MHz, the second test stomped on the first
        //

        #2500 $finish;

    end
    // ------------------------8<--------------------------------8<-----------------------------------
    /* END TB FOR NYBBLE SENDER */

endmodule
