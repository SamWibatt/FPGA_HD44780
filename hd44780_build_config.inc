//automatically generated .inc file for FPGA_HD44780
//Created by hd44780_config.py 6000000

//system frequency 6000000.0Hz
//1 system clock tick = 166.66666666666666 nanoseconds

//"long" delays needed for LCD initialization, in clock ticks
`define H4_SYSFREQ       (6_000_000)
`define H4_DELAY_53US    (318)
`define H4_DELAY_100MS   (600_000)
`define H4_DELAY_4P1MS   (24_600)
`define H4_DELAY_3MS     (18_000)
`define H4_DELAY_100US   (600)
`define H4_TIMER_BITS    (20)

//short delays for hd44780 nybble sender, in clock ticks
`define H4NS_TICKS_TAS   (1)
`define H4NS_TICKS_PWEH  (3)
`define H4NS_TICKS_TAH   (1)
`define H4NS_TICKS_E_PAD (4)
`define H4NS_COUNT_TOP   (9)
`define H4NS_COUNT_BITS  (4)
