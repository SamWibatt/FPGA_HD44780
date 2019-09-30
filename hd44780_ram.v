//hd44780_ram.v
//But first: let's put in lattice's own implementation of a dual port ram.
//verbatim from TN1250, where they had it organized as 512x8bit.
//I hypothesize I can use 256x16 by changing the addr_width and data_width params.
module hd44780_ram (din, write_en, waddr, wclk, raddr, rclk, dout);
    //initialization file
    parameter initfile = "settings/echomem.mem";

     //512x8 default
    parameter addr_width = 9;
    parameter data_width = 8;

    input [addr_width-1:0] waddr, raddr;
    input [data_width-1:0] din;
    input write_en, wclk, rclk;
    output reg [data_width-1:0] dout;

    reg [data_width-1:0] mem [(1<<addr_width)-1:0];
    always @(posedge wclk) begin // Write memory.
        if (write_en)
        mem[waddr] <= din; // Using write address bus.
    end
    always @(posedge rclk) begin // Read memory.
        dout <= mem[raddr]; // Using read address bus.
    end

    //test: will yosys let you preload a file here?
    `ifndef SIM_STEP
    initial begin
    //see https://github.com/YosysHQ/yosys/issues/333
    $readmemh(initfile, mem);       //should fill entire 256x16 where every word is itself e.g. addr 0123 contains 0x0123
    end
    `endif
endmodule
