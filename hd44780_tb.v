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
    //was always #1 clk = (clk === 1'b0);
    //test: see if we can make easier-to-count values by having a system tick be 10 clk ticks
    always #5 clk = (clk === 1'b0);


    wire led_b, led_r;
    //looks like the pwm parameters like registers - not quite sure how they work, but let's
    //just create some registers and treat them as active-high ... Well, we'll see what we get.
    //reg led_r_reg = 0;
    //reg led_g_reg = 0;
    //reg led_b_reg = 0;

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


    reg cont_ststart = 0;               // start strobe for controller, issued by this module
    reg lcd_rs = 0;                     // reg holding hd44780 register select bit
    reg [7:0] lcd_byte = 0;             // byte to send with controller
    wire cont_busy;
    wire o_rs;                          //output from FPGA to actual LCD, pkg pin. little weird we pass that through cont,
                                        //but it may want to reason over it or block it or something at some point
                                        //or sync it, or something like that
    wire [3:0] o_lcd_nybble;        //output from controller's nybble sender to LCD, package pins
    wire o_lcd_e;                       //package pin to LCD enable line e

    hd44780_controller cont(
        .RST_I(wb_reset), //input wire RST_I,                    //wishbone reset, also on falling edge of reset we want to do the whole big LCD init.
        .CLK_I(wb_clk), //input wire CLK_I,
        .STB_I(cont_ststart), //input wire STB_I,                    //to let this module know rs and lcd_data are ready and to do its thing.
        .i_rs(lcd_rs), //input wire i_rs,                     //register select - command or data, will go to LCD RS pin
        .i_lcd_data(lcd_byte), //input wire[7:0] i_lcd_data,     // byte to send to LCD, one nybble at a time
        .busy(cont_busy), //output wire busy,
    	.alive_led(led_outwire), //output wire alive_led,			//this is THE LED, the green one that shows the controller is alive
        .o_rs(o_rs), //output wire o_rs,
        .o_lcd_data(o_lcd_nybble), //output wire [3:0] o_lcd_data,   //can you do this? the data bits we send really are 7:4 - I guess others NC? tied low?
                                        //see above in nybble sender
        .o_e(o_lcd_e) //output wire o_e                 //LCD enable pin
        );


    //whatever we're testing, we need to dump gtkwave-viewable trace
    initial begin
        $dumpfile("hd44780_tb.vcd");
        $dumpvars(0, hd44780_tb);
    end

    initial begin
        //TIMINGS HERE ASSUME 12 MHZ. i.e. hd44780_sim_config.inc should look like:
        /*
          //automatically generated .inc file for FPGA_HD44780
          //Created by hd44780_config.py 12000000

          //system frequency 12000000.0Hz
          //1 system clock tick = 83.33333333333333 nanoseconds

          //"long" delays needed for LCD initialization, in clock ticks
          `define H4_SYSFREQ       (12_000_000)
          `define H4_DELAY_53US    (636)
          `define H4_DELAY_100MS   (1_200_000)
          `define H4_DELAY_4P1MS   (49_200)
          `define H4_DELAY_3MS     (36_000)
          `define H4_DELAY_100US   (1_200)
          `define H4_TIMER_BITS    (21)

          //short delays for hd44780 nybble sender, in clock ticks
          `define H4NS_TICKS_TAS   (1)
          `define H4NS_TICKS_PWEH  (6)
          `define H4NS_TICKS_TAH   (1)
          `define H4NS_TICKS_E_PAD (7)
          `define H4NS_COUNT_TOP   (15)
          `define H4NS_COUNT_BITS  (4)
        */
        //#5 tick, 10 ticks/syclck
        #90 lcd_byte = 8'b0110_1101;            //distinctive nybbles
        #10 cont_ststart = 1;                   //strobe lcd controller
        #10 cont_ststart = 0;

        //if we do another one right away, the controller should ignore it bc busy. Caller's responsibility to see to that
        #30 lcd_byte = 8'b1000_1110;            //distinctive nybbles
        #10 cont_ststart = 1;                   //strobe lcd controller
        #10 cont_ststart = 0;

        //another one after the controller itself is not busy but its nybble sender still is should also ignore
        //hm
        #200 lcd_byte = 8'b0101_1010;
        #10 cont_ststart = 1;                   //strobe lcd controller
        #10 cont_ststart = 0;

        //then this one SHOULD send a byte.
        #110 lcd_byte = 8'b1100_1011;
        #10 cont_ststart = 1;                   //strobe lcd controller
        #10 cont_ststart = 0;

        #2500 $finish;

        //************************ THIS IS FROM NYBBLE SENDER DEMO
        /*
        #90 nybbin = 4'b1011;           //pick a distinctive nybble
        rs_reg = 1;                       //and send rs high just 'cause
        #10 ststrobe = 1;
        #10 ststrobe = 0;
        #2500 $finish;
        */
    end




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
