/*
	hd44780 controller

    a "main" for the hardware

*/
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
`define G_SYSFREQ 48_000_000


//parameter STATE_TIMER_BITS = 7;     //will derive counts from clock freq at some point
//per https://stackoverflow.com/questions/5602167/logarithm-in-verilog,
// If it is a logarithm base 2 you are trying to do, you can use the built-in function $clog2()
// is this right?
`define BITS_TO_HOLD_TENTH(x) ($clog2(x/10))
`define G_STATE_TIMER_BITS (`BITS_TO_HOLD_TENTH(`G_SYSFREQ))


// VERILOG COMPILER HATES THESE DEFINES, I get 
//hd44780_controller.v:54: error: Unable to bind parameter `STATE_TIMER_BITS' in `hd44780_tb.controller.timey'
//hd44780_controller.v:54: error: Range expressions must be constant.
//let's try the parameters-up-front way
// a la https://stackoverflow.com/questions/31054022/in-verilog-how-can-i-define-the-width-of-a-port-at-instantiation

//*************************************************************************************
//aha, it's the backtick before referring to a define that makes them work like numbers
//*************************************************************************************

module state_timer #(parameter SYSFREQ = `G_SYSFREQ, parameter STATE_TIMER_BITS = `BITS_TO_HOLD_TENTH(SYSFREQ)) (
    input wire RST_I,
    input wire CLK_I,
	input wire [STATE_TIMER_BITS-1:0] DAT_I,	//[STATE_TIMER_BITS-1:0] DAT_I,
    input wire start_strobe,            // causes timer to load
    output wire end_strobe              // nudges caller to advance state
    );
	
    reg [STATE_TIMER_BITS-1:0] st_count = 0;
	//reg [22:0] st_count = 0;
    reg end_strobe_reg = 0;

	always @(posedge CLK_I) begin
		if(RST_I == 1) begin
			end_strobe_reg <= 0;
		end else if(start_strobe == 1) begin
			end_strobe_reg <= 0;
			st_count <= DAT_I;
		end else if(|st_count) begin
			//count is not 0 - raise strobe in the last tick before it goes 0
			if(st_count == 1) begin
				end_strobe_reg <= 1;
			end
			st_count <= st_count-1;
		end else begin
			//counter is 0
			end_strobe_reg <= 0;
		end
	end
		
    assign end_strobe = end_strobe_reg;

endmodule




//***********************************************************************************************************
//***********************************************************************************************************
//***********************************************************************************************************
// HEREAFTER UNCHANGED **************************************************************************************
//***********************************************************************************************************
//***********************************************************************************************************
//***********************************************************************************************************


// MAIN ********************************************************************************************************************************************
module hd44780_controller(
    input i_clk,
    input button_internal,       //active high button. Pulled up and inverted in top module.
    input wire[7:0] dip_switch,     // dip swicth swicths, active low, not inverted by top mod.
	output the_led,			//this is THE LED, the green one that follows the pattern.
	output o_led0,			//these others are just external and they
	output o_led1,          // act as "alive" indicators for the sub-modules.
	output o_led2,          // All LED logic is active high and inverted; alive-LEDs are all active low IRL
	output o_led3
);
	

	// Super simple "I'm Alive" blinky on one of the external LEDs.
	parameter REDBLINKBITS = 23;			// at 12 MHz this is ok
	reg[REDBLINKBITS-1:0] redblinkct = 0;
	always @(posedge i_clk) begin
		redblinkct <= redblinkct + 1;
	end

	//now let's try alive leds for the modules
	wire blinky_alive;
	wire mentor_alive;
    wire debounce_alive;

	// sean changes: Upduino LEDs active low unlike icestick. Invert here to allow LED logic in the modules to remain
    // active high.
	assign o_led3 = ~debounce_alive;                //otherLEDs[3];
	assign o_led2 = ~mentor_alive;	               //otherLEDs[2];
	assign o_led1 = ~blinky_alive;                  //otherLEDs[1];
	assign o_led0 = ~redblinkct[REDBLINKBITS-1];	   //controller_alive, always block just above this

    // SYSCON ============================================================================================================================
    // Wishbone-like syscon responsible for clock and reset.

    //after https://electronics.stackexchange.com/questions/405363/is-it-possible-to-generate-internal-RST_O-pulse-in-verilog-with-machxo3lf-fpga
    //tis worky, drops RST_O to 0 at 15 clocks. ADJUST THIS IF IT'S INSUFFICIENT
    reg [3:0] rst_cnt = 0;
    wire RST_O = ~rst_cnt[3];       // My RST_O is active high, original was active low; I think that's why it was called rst_n
    wire CLK_O;                     // avoid default_nettype error
	always @(posedge CLK_O)         // see if I can use the output that way
		if( RST_O )                 // active high RST_O
            rst_cnt <= rst_cnt + 1;

	assign CLK_O = i_clk;
	// END SYSCON ========================================================================================================================

	
	//HERE INSTANTIATE A STATE TIMER MODULE SO I CAN SEE HOW IT LOOKS IN GTKWAVE
    //input wire RST_I,
    //input wire CLK_I,
	//input wire [22:0] DAT_I,	//[STATE_TIMER_BITS-1:0] DAT_I,
    //input wire start_strobe,            // causes timer to load
    //output wire end_strobe              // nudges caller to advance state

	//just to test - and got 10 bits, which would hold 1/10 of 1000!
	//parameter slow_freq = 10_000;
	//parameter slow_bits = `BITS_TO_HOLD_TENTH(slow_freq);
	//reg[slow_bits-1:0] timer_value = 0;
	//really use
	reg[`G_STATE_TIMER_BITS-1:0] timer_value = 0;
	reg timer_start = 0;
	wire timer_done;
	
	//should just be state_timer timey
	//state_timer #(.SYSFREQ(slow_freq)) timey 			//should figure out bits by itself - but this is gross, need to do the bits calc here and in the module :P but ok
	state_timer timey
	(
		.RST_I(RST_O),
		.CLK_I(CLK_O),
		.DAT_I(timer_value),			//can I use regs here?
		.start_strobe(timer_start),		//and here?
		.end_strobe(timer_done)
	);


	//DUMB STOPGAP WARNING AVOIDER - FIX IN TB/TOP
    parameter NEWMASK_CLK_BITS=30;		//was 28 for 12MHz clock - now 48MHz - default for "build"
	parameter BLINKY_MASK_CLK_BITS = NEWMASK_CLK_BITS - 7;	//default for build, swh //3;			//default for short sim


endmodule
