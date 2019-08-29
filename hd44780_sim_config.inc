//automatically generated .inc file for FPGA_HD44780
//Created by hd44780_config.py 32768

//system frequency 32768.0Hz
//1 system clock tick = 30517.578124999996 nanoseconds

//"long" delays needed for LCD initialization, in clock ticks
`define H4_SYSFREQ       (32_768)
`define H4_DELAY_53US    (2)
`define H4_DELAY_100MS   (3_277)
`define H4_DELAY_4P1MS   (135)
`define H4_DELAY_3MS     (99)
`define H4_DELAY_100US   (4)
`define H4_TIMER_BITS    (12)

//short delays for hd44780 nybble sender, in clock ticks
`define H4NS_TICKS_TAS   (1)
`define H4NS_TICKS_TCYCE (1)
`define H4NS_TICKS_PWEH  (1)
`define H4NS_COUNT_BITS  (1)
