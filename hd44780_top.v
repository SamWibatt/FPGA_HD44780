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
    reg lcd_rs_reg = 0;
    reg [3:0] lcd_data_reg = 4'b0000;
    //*****************************************************************************************

    reg nybsen_strobe = 0;
    wire nybsen_busy;

    // our nybble sender
    hd44780_nybble_sender nybby(
        .RST_I(wb_reset),                    //wishbone reset, also on falling edge of reset we want to do the whole big LCD init.
        .CLK_I(wb_clk),
        .STB_I(nybsen_strobe),                    //to let this module know rs and lcd_data are ready and to do its thing.
        .i_rs(lcd_rs_reg),                     //register select - command or data, will go to LCD RS pin
        .i_nybble(lcd_data_reg),       //nybble we're sending
        .o_busy(nybsen_busy),             //whether this module is busy
        .o_lcd_data(lcd_data),   //the data bits we send really are 7:4 - I guess others NC? tied low?
                                        //check vpok. also I saw a way to do 7:4 -> 3:0 but - well, later
        .o_rs(lcd_rs),
        .o_e(lcd_e)                 //LCD enable pin
        );

    // TEST THE NYBBLE SENDER HERE *************************************************************************
    // little stately that loads up a nybble and flings it on the sender and does the strobes and waits and wotnot
    reg [2:0] ntest_state = 0;
    localparam nt_idle = 0, nt_loadnyb = 3'b001, nt_waitend = 3'b010, nt_lockup = 3'b111;

    always @(posedge clk) begin
        //SEE below for button stuff.
        //assume that if button has been pressed, we're not in wb_reset.
        if(button_has_been_pressed) begin

            case (ntest_state)
                nt_idle: begin
                    //so... given we're not in reset, step on out.
                    ntest_state <= nt_loadnyb;
                end

                nt_loadnyb: begin
                    lcd_data_reg <= 4'b1101;       // distinctive test value
                    nybsen_strobe <= 1;
                    ntest_state <= nt_waitend;
                end

                nt_waitend: begin
                    nybsen_strobe <= 0;
                    if(!nybsen_busy) begin
                        ntest_state = nt_lockup;
                    end
                end

                nt_lockup: begin
                    //nothing happens HERE. used to go to idle, which gave us infinity timer calls, so if you want that, etc.
                    //lcd_rs_reg <= 0;         //using rs to track when this state machine is active
                    //st_start_stb <= 0;
                    ntest_state <= nt_lockup;   //do I need to do anything?
                end

                default: begin
                    ntest_state <= nt_lockup;
                    nybsen_strobe <= 0;
                    lcd_data_reg <= 0;
                end

            endcase

            /* this was the first LA test
            //meaningless but logic-analyzer-capturable signals that will start when button is pressed,
            //see below.
            lcd_e_reg <= ~lcd_e_reg;
            lcd_rs_reg <= lcd_data_reg[1];
            lcd_data_reg <= lcd_data_reg + 1;
            */
        end else begin
            //button has NOT been pressed, which amounts to reset.
            ntest_state <= nt_idle;
            nybsen_strobe <= 0;
            lcd_data_reg <= 0;
        end
    end     //state machine always

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
`elsif LCD_TARGET_BYTESEN
    //this doesn't work here $display("doing target timer top!");
    //*****************************************************************************************
    //NOW STUFF FOR TESTING THE LCD PINS!
    //WHICH IS THE ENTIRE POINT OF ALL OF THIS!
    reg lcd_rs_reg = 0;
    reg lcd_e_reg = 0;
    reg [7:0] lcd_byte_reg = 8'b0000_0000;
    //*****************************************************************************************

    reg bytesen_strobe = 0;
    wire bytesen_busy;

    hd44780_bytesender bytesy(
        .RST_I(wb_reset),                    //wishbone reset, also on falling edge of reset we want to do the whole big LCD init.
        .CLK_I(wb_clk),
        .STB_I(bytesen_strobe),                    //to let this module know rs and lcd_data are ready and to do its thing.
        .i_rs(lcd_rs_reg),                     //register select - command or data, will go to LCD RS pin
        .i_lcd_data(lcd_byte_reg),     // byte to send to LCD, one nybble at a time
        .busy(bytesen_busy),
        .o_rs(lcd_rs),				//LCD register select
        .o_lcd_data(lcd_data),   //can you do this? the data bits we send really are 7:4 - I guess others NC? tied low?
        .o_e(lcd_e)                 //LCD enable pin
    );

    // little stately that loads up a byte and flings it on the sender and does the strobes and waits and wotnot
    reg [2:0] btest_state = 0;
    localparam bt_idle = 0, bt_loadbyte = 3'b001, bt_waitend = 3'b010, bt_lockup = 3'b111;

    always @(posedge clk) begin
        //SEE below for button stuff.
        //assume that if button has been pressed, we're not in wb_reset.
        if(button_has_been_pressed) begin
            case (btest_state)
                bt_idle: begin
                    //so... given we're not in reset, step on out.
                    btest_state <= bt_loadbyte;
                end

                bt_loadbyte: begin
                    lcd_byte_reg <= 8'b0100_0111;       // distinctive test value
                    bytesen_strobe <= 1;
                    btest_state <= bt_waitend;
                end

                bt_waitend: begin
                    bytesen_strobe <= 0;
                    if(!bytesen_busy) begin
                        btest_state = bt_lockup;
                    end
                end

                bt_lockup: begin
                    //nothing happens HERE. used to go to idle, which gave us infinity timer calls, so if you want that, etc.
                    //lcd_rs_reg <= 0;         //using rs to track when this state machine is active
                    //st_start_stb <= 0;
                    btest_state <= bt_lockup;   //do I need to do anything?
                end

                default: begin
                    btest_state <= bt_lockup;
                    bytesen_strobe <= 0;
                    lcd_byte_reg <= 0;
                end

            endcase

            /* this was the first LA test
            //meaningless but logic-analyzer-capturable signals that will start when button is pressed,
            //see below.
            lcd_e_reg <= ~lcd_e_reg;
            lcd_rs_reg <= lcd_data_reg[1];
            lcd_data_reg <= lcd_data_reg + 1;
            */
        end else begin
            //button has NOT been pressed, which amounts to reset.
            btest_state <= bt_idle;
            bytesen_strobe <= 0;
            lcd_byte_reg <= 0;
        end
    end     //state machine always

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
`elsif LCD_TARGET_RAM

    reg lcd_rs_reg = 0;
    reg lcd_e_reg = 0;

    parameter address_bits = 8, data_bits = 16;      // try a 256x16

    reg [address_bits-1:0] start_addr = 0;
    reg [address_bits-1:0] addr_w_reg = 0;
    reg [address_bits-1:0] addr_r_reg = 0;
    reg [data_bits-1:0] data_w_reg = 0;
    reg [data_bits-1:0] data_r_reg = 0;
    wire [data_bits-1:0] data_r_wire;
    reg ram_wen = 0;        //write enable

    hd44780_ram #(.addr_width(address_bits),.data_width(data_bits)) rammy(
        .din(data_w_reg),
        .write_en(ram_wen),
        .waddr(addr_w_reg),
        .wclk(clk),
        .raddr(addr_r_reg),
        .rclk(clk),
        .dout(data_r_wire));

    //we need this module to actually do SOMETHING
    // little stately that loads up a byte and flings it on the sender and does the strobes and waits and wotnot
    reg [2:0] rtest_state = 0;
    localparam rt_idle = 0, rt_upwen = 3'b001, rt_downwen = 3'b010, rt_lockup = 3'b111;

    //#90 addr_w_reg = 8'b0110_1101;            //distinctive nybbles
    //data_w_reg = 8'b1010_0101;                //value to write to ram
    //addr_r_reg = 8'b0110_1101;
    //#10 ram_wen = 1;                                    // write enable should shovel it in on the next clock, yes?
    //#170 ram_wen = 0;            //drop write_enable and see if it then reads

    always @(posedge clk) begin

        //SEE below for button stuff.
        //assume that if button has been pressed, we're not in wb_reset.
        if(button_has_been_pressed) begin
            data_r_reg <= data_r_wire;      //as long as we're not in reset

            case (rtest_state)
                rt_idle: begin
                    //so... given we're not in reset, step on out.
                    rtest_state <= rt_upwen;
                    addr_w_reg <= 8'b0110_1101;     // address to write to
                    data_w_reg <= 8'b1010_0101;     // recognizable bit pattern
                    addr_r_reg <= 8'b0110_1101;     // address to read from
                end

                rt_upwen: begin
                    ram_wen <= 1;
                    rtest_state <= rt_downwen;
                end

                rt_downwen: begin
                    ram_wen <= 0;
                    rtest_state <= rt_lockup;
                end

                rt_lockup: begin
                    rtest_state <= rt_lockup;   //do I need to do anything?
                end

                default: begin
                    rtest_state <= rt_lockup;
                    ram_wen <= 0;
                    addr_r_reg <= 0;
                    addr_w_reg <= 0;
                    data_r_reg <= 0;
                end

            endcase

        end else begin
            //button has NOT been pressed, which amounts to reset.
            rtest_state <= rt_idle;
            addr_r_reg <= 0;
            addr_w_reg <= 0;
            data_r_reg <= 0;
            data_w_reg <= 0;
            ram_wen <= 0;
        end
    end

    //put some data out there - LCD data 0-3 will be data_r_reg 0..3, say, and alive led 0-3 are data_r_reg 4-7
    //never mind that LED's are active low, we just want the values
    assign lcd_data = { data_r_reg[3], data_r_reg[2], data_r_reg[1], data_r_reg[0]};      //hope order works
    assign o_led0 = data_r_reg[4];     //act low
    assign o_led1 = data_r_reg[5];     //act low
    assign o_led2 = data_r_reg[6];     //act low
    assign o_led3 = data_r_reg[7];     //act low

    //then we still have these wires poking out somewhere
    assign lcd_rs = lcd_rs_reg;
    assign lcd_e = lcd_e_reg;

    // can you use this to synthesize initial contents?
    initial begin
        //let's load some stuff in the memory! per https://timetoexplore.net/blog/initialize-memory-in-verilog
        //and see if we can reach into the ram to do it from here
        //tiny mem file $readmemh("settings/testmem.mem", rammy.mem);
        //drat, iverilog is ok with this but yosys isn't
        //Warning: wire '\btest_state' is assigned in a block at hd44780_top.v:542.
        //Warning: wire '\bytesen_strobe' is assigned in a block at hd44780_top.v:543.
        //Warning: wire '\lcd_byte_reg' is assigned in a block at hd44780_top.v:544.
        //hd44780_top.v:566: ERROR: Failed to evaluate system function `\$readmemh' with non-memory 2nd argument.
        //outcomment for now
        `ifdef SIM_STEP
            $readmemh("settings/echomem.mem", rammy.mem);       //should fill entire 256x16 where every word is itself e.g. addr 0123 contains 0x0123
            //turns out, per https://github.com/YosysHQ/yosys/issues/344, hierarchical names only work in simulation.
            //Clifford Wolf says:
            //"In synthesizable verilog hierarchical references are forbidden. No synthesis tool would (or should) accept this code."
            //so...he says defines that govern filenames are the usual way to parameterize preloading with memory - ?
            //let me see what happens if I load echnomem in the ram module itself.

        `endif
    end

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


    // END TESTER OF ALL LEDs ===================================================================================
`elsif LCD_TARGET_CONTROLLER

    //HEY PUT STUFF IN HERE
    //HEY PUT STUFF IN HERE
    //HEY PUT STUFF IN HERE
    //HEY PUT STUFF IN HERE
    //HEY PUT STUFF IN HERE
    //HEY PUT STUFF IN HERE
    //HEY PUT STUFF IN HERE
    initial begin
        $display("HEY WRITE SOME KIND OF CONTROLLER TEST HERE!!!!!!!!!!!!!!!!!!!!!!!");
    end
`endif //LCD_TARGET_RAM - work out what else can be extracted






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
