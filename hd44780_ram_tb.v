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

module hd44780_ram_tb;

    //and then the clock, simulation style
    reg clk = 1;            //try this to see if it makes aligning clock delays below work right - they were off by half a cycle
    //was always #1 clk = (clk === 1'b0);
    //test: see if we can make easier-to-count values by having a system tick be 10 clk ticks
    always #5 clk = (clk === 1'b0);

    //------------------------------------------------------------------------------------------
    parameter address_bits = 9, data_bits = 8;      // try a 512x8

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
    always @(posedge clk) begin
        //this is a vestigial little thing to get the simulation working
        //start_addr = start_addr + 1;
        data_r_reg <= data_r_wire;              // grab the output from the ram block
    end

    //whatever we're testing, we need to dump gtkwave-viewable trace
    initial begin
        $dumpfile("hd44780_ram_tb.vcd");
        $dumpvars(0, hd44780_ram_tb);
    end

    initial begin
        //#5 tick, 10 ticks/syclc
        //how to communicate data address width? I guess just use 8 bits and swh
        #90 addr_w_reg = 8'b0110_1101;            //distinctive nybbles
        data_w_reg = 8'b1010_0101;                //value to write to ram
        addr_r_reg = 8'b0110_1101;
        #10 ram_wen = 1;                                    // write enable should shovel it in on the next clock, yes?
        #170 ram_wen = 0;            //drop write_enable and see if it then reads
        //it ALWAYS reads! It's dual ported.
        //I think the ram will just throw the data from addr_r_reg every clock?

        #500 $finish;
    end

endmodule
