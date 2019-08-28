#!/usr/bin/env python3
# configuration for FPGA_HD44780
# since I'm doing something with the calculated defines that yosys doesn't like, let's just
# calculate them externally and #include them.
#
# usage: hd44780_config.py (sysclock Hz) > (includefile).v
# e.g. for up5K at 48MHz do
# hd44780_config.py 48000000 > hd44780_inc.v
#
# can make multiple include files and switch between them depending on simulation or production
#
import math
import sys


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: hd44780_config.py (sysclock Hz) > (includefile).v")
        print("e.g. for up5K at 48MHz do")
        print("hd44780_config.py 48000000 > hd44780_def.inc")
        print("Then `include hd44780_def.inc in your design")
        print(
        '''
        Can use a define to switch between different configs in your .v -
        `ifndef SIM_STEP
        `include hd44780_build_config.inc
        `else
        `include hd44780_sim_config.inc
        `endif
        ''')
        sys.exit(1)

    # ok, calc some stuff
    g_sysfreq = float(sys.argv[1])              # the heart of it all, system frequency.

    # delays in system ticks for various fixed delays related to LCD init
    #`define DELAY_100MS ($ceil($itor(`G_SYSFREQ) / $itor(10)))
    delay_100ms = math.ceil(g_sysfreq / 10.0)       # 1/10 second
    #`define DELAY_53US ($ceil(($itor(`G_SYSFREQ) * $itor(53)) / $itor(1_000_000)))
    delay_53us = math.ceil((g_sysfreq * 53.0) / 1000000.0)
    #4.1 ms - call it 41/10_000
    #`define DELAY_4P1MS ($ceil(($itor(`G_SYSFREQ) * $itor(41)) / $itor(10_000)))
    delay_4p1ms = math.ceil((g_sysfreq * 4.1) / 1000.0)
    #//3 ms
    #`define DELAY_3MS ($ceil(($itor(`G_SYSFREQ) * $itor(3)) / $itor(1_000)))
    delay_3ms = math.ceil((g_sysfreq * 3.0) / 1000.0)
    #//100 us
    #`define DELAY_100US ($ceil(($itor(`G_SYSFREQ) * $itor(100)) / $itor(1_000_000)))
    delay_100us = math.ceil((g_sysfreq * 100.0) / 1000000.0)

    ********** OK DO THE REST

    # output! We need everything to be integers.
    print("`define G_SYSFREQ   ({})".format(int(math.ceil(g_sysfreq))))
    print("`define DELAY_53US  ({})".format(int(delay_53us)))
    print("`define DELAY_100MS ({})".format(int(delay_100ms)))
    print("`define DELAY_4P1MS ({})".format(int(delay_4p1ms)))
    print("`define DELAY_3MS   ({})".format(int(delay_3ms)))
    print("`define DELAY_100US ({})".format(int(delay_100us)))

# Here is all the stuff to define
'''
//then values we load into the delay thing, why not
//MAKE SURE THESE ARE AT LEAST 1 (likely not a problem with real clock freqs)
`define DELAY_100MS ($ceil($itor(`G_SYSFREQ) / $itor(10)))
//I think this works - gets correct 2544 out of 48MHz
//gets 1 out of 100Hz
//6 out of 100KHz - yup, ceil(5.3) - looks like it oughta work!
`define DELAY_53US ($ceil(($itor(`G_SYSFREQ) * $itor(53)) / $itor(1_000_000)))
//4.1 ms - call it 41/10_000
`define DELAY_4P1MS ($ceil(($itor(`G_SYSFREQ) * $itor(41)) / $itor(10_000)))
//3 ms
`define DELAY_3MS ($ceil(($itor(`G_SYSFREQ) * $itor(3)) / $itor(1_000)))
//100 us
`define DELAY_100US ($ceil(($itor(`G_SYSFREQ) * $itor(100)) / $itor(1_000_000)))

//parameter STATE_TIMER_BITS = 7;     //will derive counts from clock freq at some point
//per https://stackoverflow.com/questions/5602167/logarithm-in-verilog,
// If it is a logarithm base 2 you are trying to do, you can use the built-in function $clog2()
// is this right?
//MAKE SURE THIS IS RIGHT on some edge cases - yay, 10240 got 10 bits and 10250 got 11 bits.
//but maybe 1023 should get 10, 1024 11 - try x+1 where x was
//no, wait, (x/10)+1, not (x+1)/10
//and now it is right.
//...drat, these don't work in yosys


//`define BITS_TO_HOLD_100MS(x) ($rtoi($ceil($clog2(($itor(x)/$itor(10))+1) )))
//`define G_STATE_TIMER_BITS (`BITS_TO_HOLD_100MS(`G_SYSFREQ))
//ok, needed integer arg to clog2
`define G_STATE_TIMER_BITS ($ceil($clog2( $rtoi($itor(`G_SYSFREQ)/$itor(10)) +1) ))


#//TAS = 60ns, TCYCE = 1000 ns, PWEH = 450 ns
#//so: how many clock ticks?
#//(450÷1000000000)÷(1÷48000000) = 450ns / 1 48MHz tick = 21.6, so
#//ceil of all that
#`define TICKS_PER_NS(x) ($ceil(($itor(  x)/$itor(1_000_000_000)) / ($itor(1)/$itor(`G_SYSFREQ))))
#`define TAS_TICKS `TICKS_PER_NS(60)
#`define TCYCE_TICKS `TICKS_PER_NS(1000)
#`define PWEH_TICKS `TICKS_PER_NS(450)
#`define NSEND_TIMER_BITS ($ceil($clog2($itor(`TCYCE_TICKS)+$itor(`TAS_TICKS))))
'''
