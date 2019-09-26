/*
	hd44780 bytesender
    **************************************************************************************
    **************************************************************************************
    **************************************************************************************
    ANYWAY what it does is cue up one nybble of i_lcd_data, then call the nybble sender,
    then cue up the other one, and send that.
    **************************************************************************************
    **************************************************************************************
    **************************************************************************************
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


module hd44780_bytesender(
    input wire RST_I,                    //wishbone reset, also on falling edge of reset we want to do the whole big LCD init.
    input wire CLK_I,
    input wire STB_I,                    //to let this module know rs and lcd_data are ready and to do its thing.
    input wire i_rs,                     //register select - command or data, will go to LCD RS pin
    input wire[7:0] i_lcd_data,     // byte to send to LCD, one nybble at a time
    output wire busy,
    output wire o_rs,				//LCD register select
    output wire [3:0] o_lcd_data,   //can you do this? the data bits we send really are 7:4 - I guess others NC? tied low?
    output wire o_e                 //LCD enable pin
);



    //here is our nybble sender.
    reg ns_ststrobe = 0;                    //start strobe for nybble sender
    wire ns_busy;                           //nybble sender's busy, which is not the same as byte sender's
    reg [3:0] ns_nybbin = 4'b0000;          //nybble we wish to send
	reg byts_rs_reg = 0;

    hd44780_nybble_sender nybsen(
        .RST_I(RST_I),
        .CLK_I(CLK_I),
        .STB_I(ns_ststrobe),
		.i_rs(byts_rs_reg),		//was (i_rs), but that passes through async changes in rs line which is bad
        .i_nybble(ns_nybbin),
        .o_busy(ns_busy),
        .o_lcd_data(o_lcd_data),
        .o_rs(o_rs),
        .o_e(o_e)
    );

    //so little state machine
    //************************************************************************************************************
    //************************************************************************************************************
    //************************************************************************************************************
    // state succession is pretty easy, bc nybble sender does its own e-cycle timing, and you just
    // wait for not busy first!
    // load nybble, pulse strobe, wait for not busy (and can load next nybble in the meantime!)
    // pulse strobe and wait done.
    // note that the thing is still running, but since we wait for not busy at first, this
    // lets us zoom off and do other stuff and if there are further bytes to send, no problem.
    // if not, or if like in initialization we're doing pauses in between, it'll just be immediately not-busy
    // by the time the second invocation happens.
    //************************************************************************************************************
    //************************************************************************************************************
    //************************************************************************************************************

    reg [2:0] byts_state = 0;
    reg byts_busy_reg = 0;
    reg [7:0] i_lcd_data_shadow = 0;    // save off a copy of i_lcd data so spurious changes on the input lines don't trash nybbles

    //state defines
    localparam st_c_idle = 3'b000;
    localparam st_c_waitstb = 3'b001;
    localparam st_c_nyb1 = 3'b010;
    localparam st_c_stb1 = 3'b011;
    localparam st_c_dstb1 = 3'b100;
    localparam st_c_nyb2 = 3'b101;
    localparam st_c_stb2 = 3'b110;
    localparam st_c_dstb2 = 3'b111;

    always @(posedge CLK_I) begin
        if(RST_I) begin
            //reset!
            ns_ststrobe <= 0;
            ns_nybbin <= 0;
            byts_state <= 0;
            byts_busy_reg <= 0;
			byts_rs_reg <= 0;
		end else if (STB_I & ~busy)	begin	//Can I do this? was & ~byts_busy_reg & ~ns_busy) begin			//busy output is cont busy reg | ns_busy... this is clumsy
            //strobe came along while we're not busy and nybble sender isn't either! let's get rolling
            byts_busy_reg <= 1;
			byts_rs_reg <= i_rs;		//synchronize RS line
            byts_state <= 3'b001; //bump out of idle
        end else begin
            // load nybble, pulse strobe, wait for not busy (and can load next nybble in the meantime!)
            // or maybe not, depending on how the nybble is handled.
            // pulse strobe and wait done.

            //state 0 is idle.
            case(byts_state)
                st_c_idle: begin
                    byts_busy_reg <= 0;
                end

                st_c_waitstb: begin
                    //wait for strobe to drop
                    if(~STB_I) begin
                        i_lcd_data_shadow <= i_lcd_data;    //save off input byte so changes on the input lines don't mess up nybbles asynchronously
                        byts_state <= byts_state + 1;
                    end
                end

                //state 1, cue up first nybble
                st_c_nyb1: begin
                    //do we send lower nybble first? if so, do this, otherwise swap with the other one
                    //nope, we send upper nyb first.
                    ns_nybbin <= {i_lcd_data_shadow[7],i_lcd_data_shadow[6],i_lcd_data_shadow[5],i_lcd_data_shadow[4]};
                    byts_state <= byts_state + 1;
                end

                st_c_stb1: begin
                    //raise strobe - may not need all these states but can tighten up yes?
                    ns_ststrobe <= 1;
                    byts_state <= byts_state + 1;
                end

                st_c_dstb1: begin
                    //drop strobe - may not need all these states but can tighten up yes?
                    ns_ststrobe <= 0;
                    byts_state <= byts_state + 1;
                end

                st_c_nyb2: begin
                    //wait for busy to drop - MAY NEED A WAIT STATE ? nope seems to work
                    if(~ns_busy) begin
                        byts_state <= byts_state +1;
                        //do we send upper nybble last? if so, do this, otherwise swap with the other one
                        //nope, it's last, so moved low nybble here
                        ns_nybbin <= {i_lcd_data_shadow[3],i_lcd_data_shadow[2],i_lcd_data_shadow[1],i_lcd_data_shadow[0]};
                    end
                end

                st_c_stb2: begin
                    //raise strobe - may not need all these states but can tighten up yes?
                    ns_ststrobe <= 1;
                    byts_state <= byts_state + 1;
                end

                st_c_dstb2: begin
                    //drop strobe - may not need all these states but can tighten up yes?
                    ns_ststrobe <= 0;
                    byts_state <= 0;           //go back to idle. subsequent calls will wait for busy.
                end
            endcase
        end
    end

	assign busy = byts_busy_reg | ns_busy;		//adding ns_busy bc byte sender is busy if ns is.

endmodule
