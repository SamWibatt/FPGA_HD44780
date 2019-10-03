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
/* from goal 4 page:
*wishbone-type interface: clk, rst, stb
*busy and error lines
*data address lines (inputs to a mux somewhere, may not need one for this test, but figure it out)
-LATER: mux selector lines (width set with a define, I reckon)
*data start address
    - HEY what if special start addrs did things like all-1s means just send the
      rs bit and byte, 9 bits in all at the bottom of read_addr_lines to the LCD with
      a standard delay of some sort, for calls to it that don't need to use a RAM or something
    - prolly better to have a separate module for that, or even just have a byte sender handy
*data from RAM lines (output from muxen somewhere) 16 bits
-TABLED: number of entries to read? Or should that be part of the ram list? like there's a stop command
    ram entries include data byte, r/s bit, 3 bit index into list of delays, 1 bit for single nybble send (see goal 4 9/26), ???
    Let's do it with a command, so no need for ports
*lcd out 4 bits
*lcd rs and e
*/



module hd44780_controller(
    input wire RST_I,                    //wishbone reset, also on falling edge of reset we want to do the whole big LCD init.
    input wire CLK_I,
    input wire STB_I,                    //to let this module know rs and lcd_data are ready and to do its thing.

    //parameters related to RAMlet that contains instructions
    output wire[ram_awidth-1:0] o_read_addr_lines,    //wires that lead to input ports of a ram or a mux of several accessors to ram
    input wire[ram_awidth-1:0] i_start_addr,          //address from which to start reading control words in the given ram.
    input wire[ram_dwidth-1:0] i_read_data_lines,     //data returned from ram

    //might be part of wishbone too, but these are for communicating with caller
    output wire busy,
    output wire error,

    //actual chip pins hereafter!
    //out to LCD module
    output wire [3:0] o_lcd_nybble,
    output wire o_rs,
    output wire o_e,                //LCD enable pin

    //alive_led, not sure we need, but why not
    output wire alive_led //,			//this is THE LED, the green one that shows the controller is alive
);

    //for which we need a ramlet; here the dual ported one from TN1250, tweaked to be 256x16
    parameter ram_dwidth = 16;
    parameter ram_awidth = 8;



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
    ONLY NOW CONTROLLER DOES NOT CONTAIN THE RAM, TOP DOES!
    **************************************************************************************
    **************************************************************************************
    **************************************************************************************

    //here is our little ram module setup, ram_dwidth and ram_awidth defined above
    reg [ram_dwidth-1:0] ram_data_reg = 0;
    reg [ram_awidth-1:0] ram_rdaddr_reg = 0;
    reg [ram_awidth-1:0] ram_wraddr_reg = 0;
    reg ram_wen = 0;            //write enable
    wire [ram_dwidth-1:0] ram_data_out;


    //REPLACE SETTINGS/TESTMEM.MEM with something meaningful to this, like the HD44780 init data
    hd44780_ram #(.initfile("settings/testmem.mem"),.data_width(ram_dwidth),.addr_width(ram_awidth)) rammy (
        .din(ram_data_reg),
        .write_en(ram_wen),
        .waddr(ram_wraddr_reg),
        .wclk(CLK_I),
        .raddr(ram_rdaddr_reg),
        .rclk(CLK_I),
        .dout(ram_data_out));
    */

    //lcd output vars - don't think I need an e bc bytesender handles that
    reg lcd_rs_reg = 0;
    reg [7:0] lcd_byte_reg = 0;
    wire bytesen_busy;

    //here is the byte sender that the controller will use! and its support vars
    reg bytesen_stb_reg = 0;
    hd44780_bytesender bytesen(
        .RST_I(RST_I), //input wire RST_I,                    //wishbone reset, also on falling edge of reset we want to do the whole big LCD init.
        .CLK_I(CLK_I), //input wire CLK_I,
        .STB_I(bytesen_stb_reg), //input wire STB_I,                    //to let this module know rs and lcd_data are ready and to do its thing.
        .i_rs(lcd_rs_reg), //input wire i_rs,                     //register select - command or data, will go to LCD RS pin
        .i_lcd_data(lcd_byte_reg), //input wire[7:0] i_lcd_data,     // byte to send to LCD, one nybble at a time
        .busy(bytesen_busy), //output wire busy,
    	//.alive_led(led_outwire), //output wire alive_led,			//this is THE LED, the green one that shows the controller is alive
        .o_rs(o_rs), //output wire o_rs,
        .o_lcd_data(o_lcd_nybble), //output wire [3:0] o_lcd_data,   //can you do this? the data bits we send really are 7:4 - I guess others NC? tied low?
                                        //see above in nybble sender
        .o_e(o_e) //output wire o_e                 //LCD enable pin
        );

    //THEN a timer for the delays between sends
    reg[`H4_TIMER_BITS-1:0] time_len = 0;
    reg timer_stb_reg = 0;                       //start strobe
    //wire ststrobe_wire = ststrobe;        //try this assign to see if start strobe will work with it
    wire timer_end_stb;
    hd44780_state_timer stimey(
        .RST_I(RST_I),
        .CLK_I(CLK_I),
        .DAT_I(time_len),
        .start_strobe(timer_stb_reg), //(ststrobe_wire),       //this was ststrobe, and we weren't seeing the strobe in controller
        .end_strobe(timer_end_stb)
        );


    //so little state machine
    //****************************************************************************************
    //****************************************************************************************
    //****************************************************************************************
    //****************************************************************************************
    //****************************************************************************************
    //****************************************************************************************
    //****************************************************************************************
    // Now for actual controller state machine & wev
    //****************************************************************************************
    //****************************************************************************************
    //****************************************************************************************
    //****************************************************************************************
    //****************************************************************************************
    //****************************************************************************************
    //****************************************************************************************
    //output port vars
    reg cont_busy = 0;
    reg cont_error = 0;

    //ram vars
    //output wire[ram_awidth-1:0] o_read_addr_lines,    //wires that lead to input ports of a ram or a mux of several accessors to ram
    reg[ram_awidth-1:0] read_addr_reg = 0;
    //input wire[ram_awidth-1:0] i_start_addr,          //address from which to start reading control words in the given ram.
    reg[ram_awidth-1:0] cur_addr_reg = 0;     //this acts like a current-addr / program counter, loaded at strobe from i_start_addr
    //input wire[ram_dwidth-1:0] i_read_data_lines,     //data returned from ram
    reg[ram_dwidth-1:0] read_data_reg = 0;      //these register i_read_data_lines in the fetch cycle


    //state vars
    localparam cst_idle = 3'b000, cst_waitst = 3'b001, cst_lockup = 3'b111;
    reg[2:0] ctrl_state = 3'b000;

    always @(posedge CLK_I) begin
        if(RST_I) begin
            read_data_reg <= 0;
            read_addr_reg <= 0;
            cur_addr_reg <= 0;
            ctrl_state <= cst_idle;
            lcd_rs_reg <= 0;
            lcd_byte_reg <= 0;
            cont_busy <= 0;
            cont_error <= 0;
        end else begin
            if(STB_I & ~cont_busy) begin
                //got our strobe!
                ctrl_state <= cst_waitst;
                cont_busy <= 1;
                cur_addr_reg <= i_start_addr;       //program counter into ram
                read_addr_reg <= i_start_addr;      //might as well get started there ...?
            end else begin
                read_addr_reg <= read_addr_reg + 1;       //temp debug
                //and here we have a state machine
            end
        end
    end

    assign busy = cont_busy;
    assign error = cont_error;
    assign o_read_addr_lines = read_addr_reg;

    //these are handled by the bytesender
    //assign o_lcd_data = lcd_data_reg;
    //assign o_rs = lcd_rs_reg;
    //assign o_e = lcd_e_reg;

    //===================== BLINKY ===============================================================================================================================================================================================
    // Super simple "I'm Alive" blinky on one of the external LEDs.
	parameter GREENBLINKBITS = `H4_TIMER_BITS + 4;		//see if can adjust to sim or build clock speed			//25;			// at 12 MHz 23 is ok - it's kind of hyper at 48. KEY THIS TO GLOBAL SYSTEM CLOCK FREQ DEFINE
											// and hey why not define that in top or tb instead of in the controller or even on command line - ok
											// now the define above is wrapped in `ifndef G_SYSFREQ so there you go
	reg[GREENBLINKBITS-1:0] greenblinkct = 0;
	always @(posedge CLK_I) begin
		greenblinkct <= greenblinkct + 1;
	end

	assign alive_led = ~greenblinkct[GREENBLINKBITS-1];	   //controller_alive, always block just above this


endmodule
