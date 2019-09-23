# kvis2vcd.py - script to convert csv file exported from KingstVIS logic analyzer software to vcd for use with gtkwave

import csv

#>>> import csv
#>>> with open('TimerLATest.csv') as csvfile:
#...     r = csv.reader(csvfile, delimiter = ',', quotechar = '"')
#...     for row in r:
#...         print("|".join(row))
#... 
#Time[s]| LCD RS| LCD e| logan_strobe
#-0.002500129| 0| 0| 0
#0.000000000| 0| 0| 1
#0.000000330| 1| 1| 1
#0.000000490| 1| 0| 1
#0.000019450| 1| 1| 1
#0.000019620| 1| 0| 1
#0.000019780| 0| 0| 1
#
# some better, strip the whitespace off the sides of the values
#>>> with open('TimerLATest.csv') as csvfile:
#...     r = csv.reader(csvfile, delimiter = ',', quotechar = '"')
#...     for row in r:
#...         nurow = [x.strip() for x in row]
#...         print("|".join(nurow))
#... 
#Time[s]|LCD RS|LCD e|logan_strobe
#-0.002500129|0|0|0
#0.000000000|0|0|1
#0.000000330|1|1|1
#0.000000490|1|0|1
#0.000019450|1|1|1
#0.000019620|1|0|1
#0.000019780|0|0|1
#
# so ok, there is some header stuff we need on any file
#sean@MakeVM3B:~/FPGAgit/FPGA_HD44780$ more hd44780_tb.vcd 
#$date
#	Mon Sep 16 13:05:26 2019
#$end
#$version
#	Icarus Verilog
#$end
# - then after that comes all the stuff we want to put in the config file
#$timescale
#	1ns
#$end

# here's all the stuff that came from there vars-wise, you can see the nesting of total tb contains cont and syscon, cont contains nybsen

# $scope module hd44780_tb $end
# 	$var wire 1 ! wb_reset $end
# 	$var wire 1 " wb_clk $end
# 	$var wire 1 # o_rs $end
# 	$var wire 4 $ o_lcd_nybble [3:0] $end
# 	$var wire 1 % o_lcd_e $end
# 	$var wire 1 & led_outwire $end
# 	$var wire 1 ' cont_busy $end
# 	$var reg 1 ( clk $end	<================================= I should be able to have everything be wires
# 	$var reg 1 ) cont_ststart $end
# 	$var reg 8 * lcd_byte [7:0] $end
# 	$var reg 1 + lcd_rs $end
# 		$scope module cont $end
# 			$var wire 1 ) STB_I $end
# 			$var wire 1 & alive_led $end
# 			$var wire 1 ' busy $end
# 			$var wire 8 , i_lcd_data [7:0] $end
# 			$var wire 1 + i_rs $end
# 			$var wire 1 # o_rs $end
# 			$var wire 4 - o_lcd_data [3:0] $end
# 			$var wire 1 % o_e $end
# 			$var wire 1 . ns_busy $end
# 			$var wire 1 ! RST_I $end
# 			$var wire 1 " CLK_I $end
# 			$var reg 1 / cont_busy_reg $end
# 			$var reg 1 0 cont_rs_reg $end
# 			$var reg 3 1 cont_state [2:0] $end
# 			$var reg 25 2 greenblinkct [24:0] $end
# 			$var reg 8 3 i_lcd_data_shadow [7:0] $end
# 			$var reg 4 4 ns_nybbin [3:0] $end
# 			$var reg 1 5 ns_ststrobe $end
# 				$scope module nybsen $end
# 					$var wire 1 5 STB_I $end
# 					$var wire 4 6 i_nybble [3:0] $end
# 					$var wire 1 0 i_rs $end
# 					$var wire 1 . o_busy $end
# 					$var wire 1 % o_e $end
# 					$var wire 4 7 o_lcd_data [3:0] $end
# 					$var wire 1 # o_rs $end
# 					$var wire 1 ! RST_I $end
# 					$var wire 1 " CLK_I $end
# 					$var reg 4 8 STDC [3:0] $end
# 					$var reg 1 . busy_reg $end
# 					$var reg 1 9 e_reg $end
# 					$var reg 4 : o_lcd_reg [3:0] $end
# 					$var reg 1 ; rs_reg $end
# 				$upscope $end
# 		$upscope $end
# 	$scope module syscon $end
# 		$var wire 1 " CLK_O $end
# 		$var wire 1 ! RST_O $end
# 		$var wire 1 ( i_clk $end
# 		$var reg 4 < rst_cnt [3:0] $end
# 	$upscope $end
# $upscope $end

# Do I care about supporting nesting?
# we want something like this, from the random-lcd-garbage csv I have
#Time[s], LCD Data 0, LCD Data 1, LCD Data 2, LCD Data 3, LCD RS, LCD E, Logan Stb
#0.000000000, 0, 1, 0, 1, 0, 1, 0
#0.000001156, 1, 1, 0, 1, 0, 1, 0
#0.000002812, 1, 1, 0, 1, 1, 1, 0
#0.000003813, 1, 0, 0, 1, 1, 1, 0
#0.000005969, 1, 0, 0, 1, 1, 1, 1
#[...]

# what if the yaml format were like specifying the rows, and we don't care about any hierarchy because... well, this is version 1
# LData:
#   type: wire
#   width: 4
#   vars:
#     - LCD Data 0
#     - LCD Data 1
#     - LCD Data 2
#     - LCD Data 3
#
# RS:
#  type: wire
#  width: 1
#  vars:
#    - LCD RS
#
# E:
#  type: wire
#  width: 1
#  vars:
#    - LCD E
#
# LA_Strobe:
#  vars:
#    - Logan Stb
#
# where type is optional, defaulting to wire
# width is optional, defaulting to 1
# vars are given in what order? Either msb to lsb or the other way around. 