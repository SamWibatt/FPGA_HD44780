//automatically generated .inc file for FPGA_HD44780
//Created by hd44780_config.py 48000000

//system frequency 48000000.0Hz
//1 system clock tick = 20.833333333333332 nanoseconds

//"long" delays needed for LCD initialization, in clock ticks
`define H4_SYSFREQ       (48_000_000)
`define H4_DELAY_53US    (2_544)
`define H4_DELAY_100MS   (4_800_000)
`define H4_DELAY_4P1MS   (196_800)
`define H4_DELAY_3MS     (144_000)
`define H4_DELAY_100US   (4_800)
`define H4_TIMER_BITS    (23)

//short delays for hd44780 nybble sender, in clock ticks
`define H4NS_TICKS_TAS   (3)
`define H4NS_TICKS_TCYCE (48)
`define H4NS_TICKS_PWEH  (22)
`define H4NS_COUNT_BITS  (6)
