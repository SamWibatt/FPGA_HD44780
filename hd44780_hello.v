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

module hd44780_hello(
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
                //MOVING TO STATE MACHINE TO PUT AFTER 100ms wait
                //logan_strobe_reg <= 1;      // yay, fling logic analyzer strobe to a pin tt
            end
        end
    end

    //extend the reset to wait for the button to be pressed.
    //that way, the wishbone-like stuff won't trigger until we're ready to
    //capture it.
    assign wb_reset = syscon_reset | ~button_has_been_pressed;
    //logic analyzer waits for pos edge of this
    // LET'S HAVE IT WAIT UNTIL AFTER THE 100ms - moving below
    //assign logan_strobe = logan_strobe_reg;


    // alive-blinky wires:
    wire led_g_outwire; // = ~greenblinkct[GREENBLINKBITS-1];	   //controller_alive, always block just above this - this line causes multiple driver problem
    wire led_b_outwire; // = greenblinkct[GREENBLINKBITS-1];
    wire led_r_outwire; // = ~greenblinkct[GREENBLINKBITS-2];


    // end MULTI-USEFUL STUFF ===================================================================================
    //we need a ram and a controller. Here is the ram.
    parameter address_bits = 8, data_bits = 16;      // try a 256x16
    localparam text_instr_addr = 16;                //@address in the init-totoro mem file, should make a tool that makes defines?

    reg [address_bits-1:0] start_addr = 0;
    reg [address_bits-1:0] addr_w_reg = 0;
    //reg [address_bits-1:0] addr_r_reg = 0;        //controller sets these, so use wires
    wire [address_bits-1:0] addr_r_wires;
    reg [data_bits-1:0] data_w_reg = 0;
    //reg [data_bits-1:0] data_r_reg = 0;
    wire [data_bits-1:0] data_r_wire;
    reg ram_wen = 0;        //write enable

    //********* load ram up with the test memory
    hd44780_ram #(.initfile("settings/init-totoro.mem"),.filehex(0),.addr_width(address_bits),.data_width(data_bits)) rammy(
        .din(data_w_reg),
        .write_en(ram_wen),
        .waddr(addr_w_reg),
        .wclk(clk),
        .raddr(addr_r_wires),
        .rclk(clk),
        .dout(data_r_wire));


    reg cont_stb = 0;
    wire cont_busy;
    wire cont_error;

    //and an actual controller!
    hd44780_controller ctrlr(
        .RST_I(wb_reset),                    //wishbone reset, also on falling edge of reset we want to do the whole big LCD init.
        .CLK_I(wb_clk),
        .STB_I(cont_stb),                    //to let this module know rs and lcd_data are ready and to do its thing.

        //parameters related to RAMlet that contains instructions
        .o_read_addr_lines(addr_r_wires),    //wires that lead to input ports of a ram or a mux of several accessors to ram
        .i_start_addr(start_addr),          //address from which to start reading control words in the given ram.
        .i_read_data_lines(data_r_wire),     //data returned from ram

        //might be part of wishbone too, but these are for communicating with caller
        .busy(cont_busy),
        .error(cont_error),

        //actual chip pins hereafter!
        //out to LCD module
        .o_lcd_nybble(lcd_data),
        .o_rs(lcd_rs),
        .o_e(lcd_e) //,                //LCD enable pin
    );

    //STUFF THAT SHUTS UP THE WARNINGS ABOUT UNUSUED PORTS -
    reg reg_led0 = 0;
    reg reg_led1 = 0;
    reg reg_led2 = 0;
    reg reg_led3 = 0;

    //timer for initial 100ms
    reg[`H4_TIMER_BITS-1:0] htime_len = 0;
    reg htimer_stb_reg = 0;                       //start strobe
    //wire ststrobe_wire = ststrobe;        //try this assign to see if start strobe will work with it
    wire htimer_busy;
    hd44780_state_timer stimey(
        .RST_I(wb_reset),
        .CLK_I(wb_clk),
        .DAT_I(htime_len),
        .start_strobe(htimer_stb_reg),
        .busy(htimer_busy)
        );


    //so finally! Our state machine.
    reg[3:0] hello_state = 0;
    localparam hello_begin = 4'b0000, hello_100ms_drop = 4'b0001, hello_100ms_wait = 4'b0010,
        hello_init_drop = 4'b0011, hello_init_wait = 4'b0100,
        hello_text_begin = 4'b0101, hello_text_raise = 4'b0110, hello_text_drop = 4'b0111, hello_text_wait = 4'b1000,
        hello_lockup = 4'b1001;

    always @(posedge wb_clk) begin
        case(hello_state)
            hello_begin: begin
                //shut off LEDs, all active low
                reg_led0 <= 1;
                reg_led1 <= 1;
                reg_led2 <= 1;
                reg_led3 <= 1;
                htime_len <= `H4_DELAY_100MS;
                //wait for button press then trigger controller
                if(button_has_been_pressed) begin
                    //strobe timer
                    htimer_stb_reg <= 1;
                    hello_state <= hello_100ms_drop;
                    reg_led0 <= 0;              //light led 0 active low meaning button pressed
                end
            end

            hello_100ms_drop: begin
                htimer_stb_reg <= 0;
                hello_state <= hello_100ms_wait;
            end

            hello_100ms_wait: begin
                //wait for timer to finish
                if(~htimer_busy) begin
                    cont_stb <= 1;
                    reg_led1 <= 0;              //light led 1 active low meaning 100ms has elapsed
                    logan_strobe_reg <= 1;      //for this test we wait until after the button and the 100ms.
                    hello_state <= hello_init_drop;
                end
            end

            hello_init_drop: begin
                cont_stb <= 0;
                hello_state <= hello_init_wait;
            end

            hello_init_wait: begin
                if(~cont_busy) begin
                    reg_led2 <= 0;              //light led 2 active low meaning controller has finished init!
                    hello_state <= hello_text_begin;
                end
            end

            hello_text_begin: begin
                start_addr <= text_instr_addr;      //load up the address of the text rendering list
                hello_state <= hello_text_raise;
            end

            hello_text_raise: begin
                cont_stb <= 1;
                hello_state <= hello_text_drop;
            end

            hello_text_drop: begin
                cont_stb <= 0;
                hello_state <= hello_text_wait;
            end

            hello_text_wait: begin
                //wait for controller busy to drop, and when it does, turn on led 2 (active low)
                if(~cont_busy) begin
                    reg_led3 <= 0;          // light LED 3 (active low) showing that the text call is done.
                    hello_state <= hello_lockup;
                end
            end

            hello_lockup: begin
                //just stay here forever
                hello_state <= hello_lockup;
            end
        endcase
    end

    //logic analyzer waits for pos edge of this
    assign logan_strobe = logan_strobe_reg;


    // status LEDs in case NOTHING SEEMS TO HAPPEN we see how far it gets
    assign o_led0 = reg_led0;     //act low
    assign o_led1 = reg_led1;     //act low
    assign o_led2 = reg_led2;     //act low
    assign o_led3 = reg_led3;     //act low


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



endmodule
