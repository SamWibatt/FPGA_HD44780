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

module hd44780_controller_tb;
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

    wire wb_reset;
    wire wb_clk;
    hd44780_syscon syscon(
        .i_clk(clk),
        .RST_O(wb_reset),
        .CLK_O(wb_clk)
        );


    reg cont_ststart = 0;
    wire cont_busy;
    wire led_outwire;

    reg [7:0] start_addr = 0;

    hd44780_controller #(.ram_dwidth(16),.ram_awidth(8)) cont(
        .RST_I(wb_reset), //input wire RST_I,                    //wishbone reset, also on falling edge of reset we want to do the whole big LCD init.
        .CLK_I(wb_clk), //input wire CLK_I,
        .STB_I(cont_ststart), //input wire STB_I,                    //to let this module know rs and lcd_data are ready and to do its thing.
        /*
        .i_rs(lcd_rs), //input wire i_rs,                     //register select - command or data, will go to LCD RS pin
        .i_lcd_data(lcd_byte), //input wire[7:0] i_lcd_data,     // byte to send to LCD, one nybble at a time
        */
        .i_start_addr(start_addr),          //address from which to start reading control words in the given ram.
        .busy(cont_busy), //output wire busy,
    	.alive_led(led_outwire)  //, //output wire alive_led,			//this is THE LED, the green one that shows the controller is alive
        /*
        .o_rs(o_rs), //output wire o_rs,
        .o_lcd_data(o_lcd_nybble), //output wire [3:0] o_lcd_data,   //can you do this? the data bits we send really are 7:4 - I guess others NC? tied low?
                                        //see above in nybble sender
        .o_e(o_lcd_e) //output wire o_e                 //LCD enable pin
        */
        );

    //we need this module to actually do SOMETHING
    always @(posedge clk) begin
        start_addr = start_addr + 1;
    end


    //whatever we're testing, we need to dump gtkwave-viewable trace
    initial begin
        $dumpfile("hd44780_controller_tb.vcd");
        $dumpvars(0, hd44780_controller_tb);
    end

    initial begin
        //#5 tick, 10 ticks/syclc

        #90 start_addr = 8'b0110_1101;            //distinctive nybbles
        #10 cont_ststart = 1;                   //strobe lcd controller
        #10 cont_ststart = 0;

        #2500 $finish;
    end

endmodule
