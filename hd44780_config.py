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

# tiny utility fiddlement - given a number of nanoseconds, x, figur out how many clock ticks that is in the
# given freq (Hz)
#`define TICKS_PER_NS(x) ($ceil(($itor(  x)/$itor(1_000_000_000)) / ($itor(1)/$itor(`G_SYSFREQ))))
def ticks_per_ns(x,freq):
    return math.ceil((float(x)/1000000000.0) / (1.0/freq))

# given an int like 1000, turns into verilog underscored style for readability like 1_000
def make_verilog_number_str(x):
    num = int(x)
    if num < 1000:
        return str(num)
    else:
        # ok here figure out how to stick a _ in all the right spots.
        # ha, can just do this, per https://stackoverflow.com/questions/1823058/how-to-print-number-with-commas-as-thousands-separators/10742904
        # >>> f'{value:_}'
        # '48_000_000'
        # better, '{:_}'.format(value) bc the previous kind needs python 3.7 and people might be a bit behind
        return '{:_}'.format(num)


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
    # then the number of bits we need to construct the timer module's counter.
    #//`define BITS_TO_HOLD_100MS(x) ($rtoi($ceil($clog2(($itor(x)/$itor(10))+1) )))
    # (x/10)+1, not (x+1)/10
    # we want 11 bits for 1024, 10 bits for 1023, yes?
    bits_to_hold_100ms = math.ceil(math.log2(int((g_sysfreq / 10.0) + 1.0)))

    # shorter delays for the nybble sender, which will do timing with its own little (unless you're running at petaHz) downcounter
    #//TAS = 60ns, TCYCE = 1000 ns, PWEH = 450 ns
    #//so: how many clock ticks?
    #//(450÷1000000000)÷(1÷48000000) = 450ns / 1 48MHz tick = 21.6, so
    #//ceil of all that
    #`define TICKS_PER_NS(x) ($ceil(($itor(  x)/$itor(1_000_000_000)) / ($itor(1)/$itor(`G_SYSFREQ))))
    #`define TAS_TICKS `TICKS_PER_NS(60)
    ticks_tas = ticks_per_ns(60,g_sysfreq)

    #`define TCYCE_TICKS `TICKS_PER_NS(1000)
    #ticks_tcyce = ticks_per_ns(1000,g_sysfreq)

    #`define PWEH_TICKS `TICKS_PER_NS(450)
    ticks_pweh = ticks_per_ns(450,g_sysfreq)

    # and let's also account for tah (address hold time)
    ticks_tah = ticks_per_ns(20,g_sysfreq)

    # then the rest of TcycE - 1000 - (450+20) ns, yes? bc tas is before tcyce is counted.
    ticks_e_pad = ticks_per_ns((1000-(450+20)),g_sysfreq)

    # then the # of bits for the nybble sender's downcounter.
    # the duration it has to downcount is the E cycle length ticks_tcyce plus the
    # address setup time, ticks_tas.
    #`define NSEND_TIMER_BITS ($ceil($clog2($itor(`TCYCE_TICKS)+$itor(`TAS_TICKS))))
    # fails in the case of tcyce and tas < 1 bits_to_hold_nsend = math.ceil(math.log2(int(ticks_tcyce + ticks_tas)))
    # in fact should probably add up tas, pweh, tah (?)
    #bits_to_hold_nsend = math.ceil(math.log2(int(ticks_tcyce) + int(ticks_tas)))
    # so the idea here is that at low clock speeds, these tick counts all get distorted
    # so that tcyce, pweh, tah, etc. are all 1 tick. Which is correct, but then you have to account for
    # them all, still, and not just let the tcyce+tas = 2 be the whole duration.
    # so, add up tas, then the ecycle parts: pweh, tah, and the rest of tcyce, which I call e_pad.
    count_top = int(ticks_tas) + int(ticks_pweh) + int(ticks_tah) + int(ticks_e_pad)
    # I believe we need to fudge count_top up by one in bit container like we did with bit length for timer
    # i.e. the number 4 needs 3 bits to hold though its log2 is 2.
    bits_to_hold_nsend = math.ceil(math.log2(count_top+1))



    # output! We need everything to be integers.
    # prefix with H4 as the shortest form of hd44780.
    print("//automatically generated .inc file for FPGA_HD44780")
    print("//Created by hd44780_config.py {}\n".format(int(g_sysfreq)))
    print("//system frequency {}Hz".format(g_sysfreq))
    print("//1 system clock tick = {} nanoseconds".format((1.0 / g_sysfreq) / (1.0/1000000000.0)))
    print('\n//"long" delays needed for LCD initialization, in clock ticks')
    print("`define H4_SYSFREQ       ({})".format(make_verilog_number_str(int(math.ceil(g_sysfreq)))))
    print("`define H4_DELAY_53US    ({})".format(make_verilog_number_str(int(delay_53us))))
    print("`define H4_DELAY_100MS   ({})".format(make_verilog_number_str(int(delay_100ms))))
    print("`define H4_DELAY_4P1MS   ({})".format(make_verilog_number_str(int(delay_4p1ms))))
    print("`define H4_DELAY_3MS     ({})".format(make_verilog_number_str(int(delay_3ms))))
    print("`define H4_DELAY_100US   ({})".format(make_verilog_number_str(int(delay_100us))))
    print("`define H4_TIMER_BITS    ({})".format(make_verilog_number_str(int(bits_to_hold_100ms))))
    print("\n//short delays for hd44780 nybble sender, in clock ticks")
    print("`define H4NS_TICKS_TAS   ({})".format(make_verilog_number_str(int(ticks_tas))))
    print("`define H4NS_TICKS_PWEH  ({})".format(make_verilog_number_str(int(ticks_pweh))))
    print("`define H4NS_TICKS_TAH   ({})".format(make_verilog_number_str(int(ticks_tah))))
    print("`define H4NS_TICKS_E_PAD ({})".format(make_verilog_number_str(int(ticks_e_pad))))
    print("`define H4NS_COUNT_TOP   ({})".format(make_verilog_number_str(int(count_top))))
    print("`define H4NS_COUNT_BITS  ({})".format(make_verilog_number_str(int(bits_to_hold_nsend))))
