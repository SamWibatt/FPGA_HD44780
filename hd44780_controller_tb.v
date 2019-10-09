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

    // RAM with special instruction set
    //we need a ram and a controller. Here is the ram.
    parameter address_bits = 8, data_bits = 16;      // try a 256x16

    reg [address_bits-1:0] start_addr = 0;
    reg [address_bits-1:0] addr_w_reg = 0;
    //reg [address_bits-1:0] addr_r_reg = 0;        //controller sets these, so use wires
    wire [address_bits-1:0] addr_r_wires;
    reg [data_bits-1:0] data_w_reg = 0;
    //reg [data_bits-1:0] data_r_reg = 0;
    wire [data_bits-1:0] data_r_wire;
    reg ram_wen = 0;        //write enable

    hd44780_ram #(.initfile("settings/ctrlrtest1.mem"),.addr_width(address_bits),.data_width(data_bits)) rammy(
        .din(data_w_reg),
        .write_en(ram_wen),
        .waddr(addr_w_reg),
        .wclk(wb_clk),
        .raddr(addr_r_wires),
        .rclk(wb_clk),
        .dout(data_r_wire));


    //and the controller!
    reg cont_ststart = 0;
    wire cont_busy;
    wire cont_error;
    wire o_rs;
    wire o_e;
    wire [3:0] o_lcd_data;

    hd44780_controller #(.ram_dwidth(16),.ram_awidth(8)) cont (
        .RST_I(wb_reset),                    //wishbone reset, also on falling edge of reset we want to do the whole big LCD init.
        .CLK_I(wb_clk),
        .STB_I(cont_ststart),                    //to let this module know rs and lcd_data are ready and to do its thing.

        //parameters related to RAMlet that contains instructions
        .o_read_addr_lines(addr_r_wires),    //wires that lead to input ports of a ram or a mux of several accessors to ram
        .i_start_addr(start_addr),          //address from which to start reading control words in the given ram.
        .i_read_data_lines(data_r_wire),     //data returned from ram

        //might be part of wishbone too, but these are for communicating with caller
        .busy(cont_busy),
        .error(cont_error),

        //actual chip pins hereafter!
        //out to LCD module
        .o_lcd_nybble(o_lcd_data),
        .o_rs(o_rs),
        .o_e(o_e) //,                //LCD enable pin
    );


    //we need this module to actually do SOMETHING... do we?
    /*
    always @(posedge clk) begin
        start_addr = start_addr + 1;
    end
    */

    //whatever we're testing, we need to dump gtkwave-viewable trace
    initial begin
        $dumpfile("hd44780_controller_tb.vcd");
        $dumpvars(0, hd44780_controller_tb);
    end

    initial begin
        //#5 tick, 10 ticks/syclc

        #90 start_addr = 0;            //distinctive nybbles
        #10 cont_ststart = 1;                   //strobe lcd controller
        #10 cont_ststart = 0;
        //this'll take a while to run!
        #700000 $finish;
    end

endmodule
