# FPGA_HD44780
Simple, write-only character LCD core

## work in progress. This is a project I'm using to teach myself programmable logic, so I don't (yet) recommend using it. As of this writing on 10/15/19, it doesn't yet work. I'm making the project public so anyone interested can see the process I'm going through for design, as well as my current skill level.

* platform: [Gnarly Grey Upduino V2.0](https://github.com/gtjennings1/UPDuino_v2_0) - [Sold here](http://www.gnarlygrey.com/)
* toolchain: Icestorm - [github](https://github.com/cliffordwolf/icestorm), [home page](http://www.clifford.at/icestorm/)
    * iverilog
    * yosys
    * nextpnr
    * gtkwave
    * verilator (planned - nothing implemented yet)
* dev system: Ubuntu 18.04 laptop
* Logic analyzer: [Inno-maker LA1010 16ch 100MHz](http://www.inno-maker.com/product/usb-logic-analyzer/) - [also at Amazon](https://smile.amazon.com/gp/product/B07D21GG6J/)


### from FPGA AI Notes:
* WHY NOT WRITE A HD44780 CORE with wishbone interface?
    * That is a thing I have my own sources for in assembly, and am capable of writing in gateware.
    * Also a decent candidate for Verilator? Esp if I roped in ncurses and did the display lol
    * no lol, that is a great idea. Tho maybe need to do it with a grx thing because of special characters.
    * If you really wanted to grit your teeth over it, need to do all the fiddly timings.
    * and I suppose I need to get thinking of all this in terms thereof.
    * So… maybe the way to prove an LCD interface is to prove that
Signals coming in are within min/max time for whatever event
e.g. enable pulse coming in too soon after data lines set = bad
signals come in in a sensible order, like… address before data, or wev
both at nybble and individual-signal level
that's the idea
    * also prove the Wishbone interface, crib from Dr. G
    * What is a minimum viable verilator LCD?
    * hm, look at the interface
    * At first just support 4-bit, can do 8-bit later
    * saved hd44780 datasheet to FPGA/charLCD
    * And some good images Esp one from https://slideplayer.com/slide/3942627/
    ![HD44780 timing diagrams](images/HD44780BusTimingdiagram.jpg)
    * Verify timing w sheet, figure out how to tell if the driver violates. Let's only do write, first
    * and **only write ever** BC level shifter to 5 v
    * ....**is level shift necessary? see re hd44780 input levels**
    * So assert that my driver never sends R/~W high, at least while enable is high
    * Look into hct541 prop delay - worst case is 29ns, typ 13ns
    * Doubt it matters.
    * Also LCD first, wishbone later.
    * Wishbone Blinky to get that sorted out, then merge with this LCD.
    * Can wishbone 32 bus have a wishbone 8 student?
