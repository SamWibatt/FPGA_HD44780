/*
	hd44780 controller

    a bit different from my previous projects' controllers; this is just the LCD driver.
    top and syscon handle the top-level stuff.


    ************************************************************** CURRENTLY THE SAME AS hd44780_bytesender! FIX!
    ************************************************************** CURRENTLY THE SAME AS hd44780_bytesender! FIX!
    ************************************************************** CURRENTLY THE SAME AS hd44780_bytesender! FIX!
    ************************************************************** CURRENTLY THE SAME AS hd44780_bytesender! FIX!
    ************************************************************** CURRENTLY THE SAME AS hd44780_bytesender! FIX!
    ************************************************************** CURRENTLY THE SAME AS hd44780_bytesender! FIX!
    ************************************************************** CURRENTLY THE SAME AS hd44780_bytesender! FIX!


*/
`default_nettype	none

//new way with include

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

/*
OK CURRENTLY NEED TO THINK OUT ARCHITECTURE OF THIS
CONTROLLER WOULD NOT HAVE A PET RAM, THE WAY IT IS WRITTEN
CALLER WOULD HAVE A RAM IN MIND and hand its read port over to the controller, yes?
bc controller can only read to the ram.
Might want controller to have an error line or a way to return the address of the next thing it would have run,
so we can have multiple "scripts" in a ram block and pass the controller:
- address of first script line in the ram
- data address lines for the ram that caller knows
- number of script lines to run? Or should there be a script code for halt?
*/

module hd44780_controller(
    input wire RST_I,                    //wishbone reset, also on falling edge of reset we want to do the whole big LCD init.
    input wire CLK_I,
    input wire STB_I,                    //to let this module know rs and lcd_data are ready and to do its thing.
    /*
    input wire i_rs,                     //register select - command or data, will go to LCD RS pin
    //input wire[7:0] i_lcd_addr    //is there an address we have to send? looks like not, it's cursor-based.
    input wire[7:0] i_lcd_data,     // byte to send to LCD, one nybble at a time
    */
    input wire[7:0] i_start_addr,          //address from which to start reading control words in the given ram.
                                            //DANGER: hardcoded width, should be ram_dwidth-1:0
    output wire busy,
	output wire alive_led //,			//this is THE LED, the green one that shows the controller is alive
    /*
    output wire o_rs,
    output wire [3:0] o_lcd_data,   //can you do this? the data bits we send really are 7:4 - I guess others NC? tied low?
                                    //see above in nybble sender
    output wire o_e                 //LCD enable pin
    */
);

	// Super simple "I'm Alive" blinky on one of the external LEDs.
	parameter GREENBLINKBITS = `H4_TIMER_BITS + 4;		//see if can adjust to sim or build clock speed			//25;			// at 12 MHz 23 is ok - it's kind of hyper at 48. KEY THIS TO GLOBAL SYSTEM CLOCK FREQ DEFINE
											// and hey why not define that in top or tb instead of in the controller or even on command line - ok
											// now the define above is wrapped in `ifndef G_SYSFREQ so there you go
	reg[GREENBLINKBITS-1:0] greenblinkct = 0;
	always @(posedge CLK_I) begin
		greenblinkct <= greenblinkct + 1;
	end

	assign alive_led = ~greenblinkct[GREENBLINKBITS-1];	   //controller_alive, always block just above this


    // DEBUG ===============================================================================
    // can I print out defines like this? yarp! Shouldn't synthesize anything
    //yosys doesn't like these defines so only do them in iverilog
    `ifdef SIM_STEP
    initial begin
        $display("H4_DELAY_100MS is %d",`H4_DELAY_100MS);
        $display("H4_DELAY_4P1MS is %d",`H4_DELAY_4P1MS);
		$display("H4_DELAY_3MS is   %d",`H4_DELAY_3MS);
        $display("H4_DELAY_100US is %d",`H4_DELAY_100US);
		$display("H4_DELAY_53US is  %d",`H4_DELAY_53US);
		$display("H4_TIMER_BITS is  %d",`H4_TIMER_BITS);
		$display("---");
		$display("H4NS_TICKS_TAS is   %d",`H4NS_TICKS_TAS);
		$display("H4NS_TICKS_PWEH is  %d",`H4NS_TICKS_PWEH);
        $display("H4NS_TICKS_TAH is   %d",`H4NS_TICKS_TAH);
        $display("H4NS_TICKS_E_PAD is %d",`H4NS_TICKS_E_PAD);
        $display("H4NS_COUNT_TOP is   %d",`H4NS_COUNT_TOP);
		$display("H4NS_COUNT_BITS is  %d",`H4NS_COUNT_BITS);
	end
    `endif
    // END DEBUG ===========================================================================

    /*
    **************************************************************************************
    **************************************************************************************
    **************************************************************************************
    so ok now for what it really does

    **************************************************************************************
    **************************************************************************************
    **************************************************************************************
    */

    //for which we need a ramlet; here the dual ported one from TN1250, tweaked to be 256x16
    parameter ram_dwidth = 16;
    parameter ram_awidth = 8;

    reg [ram_dwidth-1:0] ram_data_reg = 0;
    reg [ram_awidth-1:0] ram_rdaddr_reg = 0;
    reg [ram_awidth-1:0] ram_wraddr_reg = 0;
    reg ram_wen = 0;            //write enable
    wire [ram_dwidth-1:0] ram_data_out;

    reg cont_busy = 0;

    //REPLACE SETTINGS/TESTMEM.MEM with something meaningful to this, like the HD44780 init data
    hd44780_ram #(.initfile("settings/testmem.mem"),.data_width(ram_dwidth),.addr_width(ram_awidth)) rammy (
        .din(ram_data_reg),
        .write_en(ram_wen),
        .waddr(ram_wraddr_reg),
        .wclk(CLK_I),
        .raddr(ram_rdaddr_reg),
        .rclk(CLK_I),
        .dout(ram_data_out));

    localparam cst_idle = 3'b000, cst_waitst = 3'b001, cst_lockup = 3'b111;
    reg[2:0] ctrl_state = 3'b000;

    //so little state machine
    //****************************************************************************************
    //****************************************************************************************
    //****************************************************************************************
    //****************************************************************************************
    //****************************************************************************************
    //****************************************************************************************
    //****************************************************************************************
    //HEY THIS IS NOT FINISHED finish it 
    //****************************************************************************************
    //****************************************************************************************
    //****************************************************************************************
    //****************************************************************************************
    //****************************************************************************************
    //****************************************************************************************
    //****************************************************************************************
    always @(posedge CLK_I) begin
        if(RST_I) begin
            ram_data_reg <= 0;
            ram_rdaddr_reg <= 0;
            ram_wraddr_reg <= 0;
            ram_wen <= 0;
            ctrl_state <= 3'b000;
            cont_busy <= 0;
        end else begin
            if(STB_I & ~cont_busy) begin
                //got our strobe!
                ctrl_state <= cst_waitst;
                cont_busy <= 1;
            end else begin
                ram_rdaddr_reg <= ram_rdaddr_reg + 1;
                //and here we have a state machine
            end
        end
    end

    assign busy = cont_busy;


endmodule
