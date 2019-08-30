//automatically generated .inc file for FPGA_HD44780
//Created by hd44780_config.py 12000000

//system frequency 12000000.0Hz
//1 system clock tick = 83.33333333333333 nanoseconds

//"long" delays needed for LCD initialization, in clock ticks
`define H4_SYSFREQ       (12_000_000)
`define H4_DELAY_53US    (636)
`define H4_DELAY_100MS   (1_200_000)
`define H4_DELAY_4P1MS   (49_200)
`define H4_DELAY_3MS     (36_000)
`define H4_DELAY_100US   (1_200)
`define H4_TIMER_BITS    (21)

//short delays for hd44780 nybble sender, in clock ticks
`define H4NS_TICKS_TAS   (1)
`define H4NS_TICKS_PWEH  (6)
`define H4NS_TICKS_TAH   (1)
`define H4NS_TICKS_E_PAD (7)
`define H4NS_COUNT_TOP   (15)
`define H4NS_COUNT_BITS  (4)
