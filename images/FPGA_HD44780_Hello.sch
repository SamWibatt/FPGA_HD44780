EESchema Schematic File Version 4
LIBS:FPGA_HD44780_Hello-cache
EELAYER 30 0
EELAYER END
$Descr USLetter 11000 8500
encoding utf-8
Sheet 1 1
Title "FPGA_HD44780 Hello Totoro Test Circuit"
Date "2019-10-27"
Rev "1"
Comp "SamWibatt"
Comment1 ""
Comment2 ""
Comment3 ""
Comment4 ""
$EndDescr
$Comp
L Display_Character:LCD-016N002L U3
U 1 1 5DB5AE57
P 7850 3750
F 0 "U3" H 7850 4156 50  0000 C CNN
F 1 "LCD-016N002L" V 7850 3762 50  0000 C CNN
F 2 "Display:LCD-016N002L" H 7870 2830 50  0001 C CNN
F 3 "http://www.vishay.com/docs/37299/37299.pdf" H 8350 3450 50  0001 C CNN
	1    7850 3750
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR?
U 1 1 5DB5C0B0
P 7850 4550
F 0 "#PWR?" H 7850 4300 50  0001 C CNN
F 1 "GND" H 7855 4377 50  0000 C CNN
F 2 "" H 7850 4550 50  0001 C CNN
F 3 "" H 7850 4550 50  0001 C CNN
	1    7850 4550
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR?
U 1 1 5DB5C493
P 7200 3450
F 0 "#PWR?" H 7200 3200 50  0001 C CNN
F 1 "GND" H 7205 3277 50  0000 C CNN
F 2 "" H 7200 3450 50  0001 C CNN
F 3 "" H 7200 3450 50  0001 C CNN
	1    7200 3450
	1    0    0    -1  
$EndComp
$Comp
L power:+5V #PWR?
U 1 1 5DB5CE91
P 7850 2900
F 0 "#PWR?" H 7850 2750 50  0001 C CNN
F 1 "+5V" H 7865 3073 50  0000 C CNN
F 2 "" H 7850 2900 50  0001 C CNN
F 3 "" H 7850 2900 50  0001 C CNN
	1    7850 2900
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR?
U 1 1 5DB5EC79
P 6100 5050
F 0 "#PWR?" H 6100 4800 50  0001 C CNN
F 1 "GND" H 6105 4877 50  0000 C CNN
F 2 "" H 6100 5050 50  0001 C CNN
F 3 "" H 6100 5050 50  0001 C CNN
	1    6100 5050
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR?
U 1 1 5DB5F2BE
P 5600 4750
F 0 "#PWR?" H 5600 4500 50  0001 C CNN
F 1 "GND" H 5605 4577 50  0000 C CNN
F 2 "" H 5600 4750 50  0001 C CNN
F 3 "" H 5600 4750 50  0001 C CNN
	1    5600 4750
	1    0    0    -1  
$EndComp
Wire Wire Line
	5600 4650 5600 4750
Connection ~ 5600 4750
Wire Wire Line
	7450 3250 7200 3250
Wire Wire Line
	7200 3250 7200 3450
$Comp
L 74xx:74HCT541 U2
U 1 1 5DB5DF8F
P 6100 4250
F 0 "U2" H 6100 4087 50  0000 C CNN
F 1 "74HCT541" H 6100 3969 50  0000 C CNN
F 2 "" H 6100 4250 50  0001 C CNN
F 3 "http://www.ti.com/lit/gpn/sn74HCT541" H 6100 4250 50  0001 C CNN
	1    6100 4250
	1    0    0    -1  
$EndComp
Wire Wire Line
	7850 2950 7850 2900
$Comp
L Device:R_POT_US RV1
U 1 1 5DB6BA24
P 8500 3150
F 0 "RV1" H 8432 3104 50  0000 R CNN
F 1 "10K" H 8432 3195 50  0000 R CNN
F 2 "" H 8500 3150 50  0001 C CNN
F 3 "~" H 8500 3150 50  0001 C CNN
	1    8500 3150
	-1   0    0    1   
$EndComp
Wire Wire Line
	8350 3150 8250 3150
$Comp
L power:+5V #PWR?
U 1 1 5DB6E4B9
P 8500 2900
F 0 "#PWR?" H 8500 2750 50  0001 C CNN
F 1 "+5V" H 8515 3073 50  0000 C CNN
F 2 "" H 8500 2900 50  0001 C CNN
F 3 "" H 8500 2900 50  0001 C CNN
	1    8500 2900
	1    0    0    -1  
$EndComp
Wire Wire Line
	8500 3000 8500 2900
$Comp
L power:GND #PWR?
U 1 1 5DB6FB85
P 8500 3400
F 0 "#PWR?" H 8500 3150 50  0001 C CNN
F 1 "GND" H 8505 3227 50  0000 C CNN
F 2 "" H 8500 3400 50  0001 C CNN
F 3 "" H 8500 3400 50  0001 C CNN
	1    8500 3400
	1    0    0    -1  
$EndComp
Wire Wire Line
	8500 3300 8500 3400
Wire Wire Line
	6600 3850 6700 3850
Wire Wire Line
	5600 4450 5600 4650
Connection ~ 5600 4650
Wire Wire Line
	6600 4350 7450 4350
Wire Wire Line
	6600 4250 7450 4250
Wire Wire Line
	6600 4150 7450 4150
Wire Wire Line
	6600 4050 7450 4050
Text GLabel 6750 3950 2    50   Output ~ 0
LA_Stb
Wire Wire Line
	6600 3950 6750 3950
Wire Wire Line
	6600 3750 6600 3150
Wire Wire Line
	6600 3150 7450 3150
Wire Wire Line
	6700 3850 6700 3350
Wire Wire Line
	6700 3350 7450 3350
$Comp
L power:+5V #PWR?
U 1 1 5DB9F988
P 6100 3350
F 0 "#PWR?" H 6100 3200 50  0001 C CNN
F 1 "+5V" H 6115 3523 50  0000 C CNN
F 2 "" H 6100 3350 50  0001 C CNN
F 3 "" H 6100 3350 50  0001 C CNN
	1    6100 3350
	1    0    0    -1  
$EndComp
$Comp
L FPGA_SamWibatt:UpduinoV2 U1
U 1 1 5DBAE338
P 3900 4400
F 0 "U1" H 3875 5523 50  0000 C CNN
F 1 "UpduinoV2" H 3875 5614 50  0000 C CNN
F 2 "" H 3900 4650 50  0001 C CNN
F 3 "" H 3900 4650 50  0001 C CNN
	1    3900 4400
	-1   0    0    1   
$EndComp
Wire Wire Line
	5600 4050 5200 4050
Wire Wire Line
	5200 4050 5200 4800
Wire Wire Line
	5200 4800 4700 4800
Wire Wire Line
	5600 4150 5250 4150
Wire Wire Line
	5250 4150 5250 4700
Wire Wire Line
	5250 4700 4700 4700
Wire Wire Line
	5600 4250 5300 4250
Wire Wire Line
	5300 4250 5300 4600
Wire Wire Line
	5300 4600 4700 4600
Wire Wire Line
	5600 4350 5350 4350
Wire Wire Line
	5350 4350 5350 4500
Wire Wire Line
	5350 4500 4700 4500
Wire Wire Line
	6100 3350 6100 3450
$Comp
L Switch:SW_Push SW1
U 1 1 5DB66464
P 2500 4400
F 0 "SW1" V 2546 4352 50  0000 R CNN
F 1 "SW_Push" V 2455 4352 50  0000 R CNN
F 2 "" H 2500 4600 50  0001 C CNN
F 3 "~" H 2500 4600 50  0001 C CNN
	1    2500 4400
	0    -1   -1   0   
$EndComp
Wire Wire Line
	3150 4200 2500 4200
$Comp
L power:GND #PWR?
U 1 1 5DB67B2A
P 2500 4700
F 0 "#PWR?" H 2500 4450 50  0001 C CNN
F 1 "GND" H 2505 4527 50  0000 C CNN
F 2 "" H 2500 4700 50  0001 C CNN
F 3 "" H 2500 4700 50  0001 C CNN
	1    2500 4700
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR?
U 1 1 5DB68279
P 3450 3100
F 0 "#PWR?" H 3450 2850 50  0001 C CNN
F 1 "GND" H 3455 2927 50  0000 C CNN
F 2 "" H 3450 3100 50  0001 C CNN
F 3 "" H 3450 3100 50  0001 C CNN
	1    3450 3100
	1    0    0    -1  
$EndComp
$Comp
L power:+5V #PWR?
U 1 1 5DB68D8E
P 3700 3200
F 0 "#PWR?" H 3700 3050 50  0001 C CNN
F 1 "+5V" H 3715 3373 50  0000 C CNN
F 2 "" H 3700 3200 50  0001 C CNN
F 3 "" H 3700 3200 50  0001 C CNN
	1    3700 3200
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR?
U 1 1 5DB6D3D5
P 4850 4900
F 0 "#PWR?" H 4850 4650 50  0001 C CNN
F 1 "GND" H 4855 4727 50  0000 C CNN
F 2 "" H 4850 4900 50  0001 C CNN
F 3 "" H 4850 4900 50  0001 C CNN
	1    4850 4900
	1    0    0    -1  
$EndComp
Wire Wire Line
	3600 3300 3600 3100
Wire Wire Line
	3600 3100 3450 3100
Wire Wire Line
	3700 3300 3700 3200
Wire Wire Line
	4700 4900 4850 4900
$Comp
L Device:LED D3
U 1 1 5DB70DEE
P 4700 3150
F 0 "D3" V 4700 3100 50  0000 R CNN
F 1 "LED" V 4650 3100 30  0000 R CNN
F 2 "" H 4700 3150 50  0001 C CNN
F 3 "~" H 4700 3150 50  0001 C CNN
	1    4700 3150
	0    -1   -1   0   
$EndComp
$Comp
L Device:LED D0
U 1 1 5DB72CC0
P 5300 3150
F 0 "D0" V 5300 3100 50  0000 R CNN
F 1 "LED" V 5250 3100 30  0000 R CNN
F 2 "" H 5300 3150 50  0001 C CNN
F 3 "~" H 5300 3150 50  0001 C CNN
	1    5300 3150
	0    -1   -1   0   
$EndComp
$Comp
L Device:LED D1
U 1 1 5DB7256B
P 5100 3150
F 0 "D1" V 5100 3100 50  0000 R CNN
F 1 "LED" V 5050 3100 30  0000 R CNN
F 2 "" H 5100 3150 50  0001 C CNN
F 3 "~" H 5100 3150 50  0001 C CNN
	1    5100 3150
	0    -1   -1   0   
$EndComp
$Comp
L Device:LED D2
U 1 1 5DB715B6
P 4900 3150
F 0 "D2" V 4900 3100 50  0000 R CNN
F 1 "LED" V 4850 3100 30  0000 R CNN
F 2 "" H 4900 3150 50  0001 C CNN
F 3 "~" H 4900 3150 50  0001 C CNN
	1    4900 3150
	0    -1   -1   0   
$EndComp
Wire Wire Line
	4700 3500 4700 3300
Wire Wire Line
	4700 3600 4900 3600
Wire Wire Line
	4900 3600 4900 3300
Wire Wire Line
	4700 3700 5100 3700
Wire Wire Line
	5100 3700 5100 3300
Wire Wire Line
	4700 3900 5600 3900
Wire Wire Line
	5600 3900 5600 3950
Wire Wire Line
	4700 4000 5550 4000
Wire Wire Line
	5550 4000 5550 3750
Wire Wire Line
	5550 3750 5600 3750
Wire Wire Line
	4700 4100 5150 4100
Wire Wire Line
	5150 4100 5150 3850
Wire Wire Line
	5150 3850 5600 3850
Wire Wire Line
	4700 3800 5300 3800
Wire Wire Line
	5300 3800 5300 3300
Wire Wire Line
	2500 4700 2500 4600
$Comp
L Device:R_Small_US R1
U 1 1 5DB9FC4C
P 4700 2800
F 0 "R1" H 4750 2850 50  0000 L CNN
F 1 "1K" H 4750 2750 50  0000 L CNN
F 2 "" H 4700 2800 50  0001 C CNN
F 3 "~" H 4700 2800 50  0001 C CNN
	1    4700 2800
	1    0    0    -1  
$EndComp
$Comp
L Device:R_Small_US R2
U 1 1 5DBA141D
P 4900 2800
F 0 "R2" H 4950 2850 50  0000 L CNN
F 1 "1K" H 4950 2750 50  0000 L CNN
F 2 "" H 4900 2800 50  0001 C CNN
F 3 "~" H 4900 2800 50  0001 C CNN
	1    4900 2800
	1    0    0    -1  
$EndComp
$Comp
L Device:R_Small_US R3
U 1 1 5DBA1EF8
P 5100 2800
F 0 "R3" H 5150 2850 50  0000 L CNN
F 1 "1K" H 5150 2750 50  0000 L CNN
F 2 "" H 5100 2800 50  0001 C CNN
F 3 "~" H 5100 2800 50  0001 C CNN
	1    5100 2800
	1    0    0    -1  
$EndComp
$Comp
L Device:R_Small_US R4
U 1 1 5DBA261A
P 5300 2800
F 0 "R4" H 5350 2850 50  0000 L CNN
F 1 "1K" H 5350 2750 50  0000 L CNN
F 2 "" H 5300 2800 50  0001 C CNN
F 3 "~" H 5300 2800 50  0001 C CNN
	1    5300 2800
	1    0    0    -1  
$EndComp
Wire Wire Line
	4700 3000 4700 2900
Wire Wire Line
	4900 3000 4900 2900
Wire Wire Line
	5100 3000 5100 2900
Wire Wire Line
	5300 3000 5300 2900
Wire Wire Line
	4700 2700 4700 2550
Wire Wire Line
	5300 2550 5300 2700
Wire Wire Line
	5100 2700 5100 2550
Wire Wire Line
	4700 2550 4900 2550
Connection ~ 5100 2550
Wire Wire Line
	5100 2550 5300 2550
Wire Wire Line
	4900 2700 4900 2550
Connection ~ 4900 2550
Wire Wire Line
	4900 2550 5000 2550
$Comp
L power:+3.3V #PWR?
U 1 1 5DBB3914
P 5000 2450
F 0 "#PWR?" H 5000 2300 50  0001 C CNN
F 1 "+3.3V" H 5015 2623 50  0000 C CNN
F 2 "" H 5000 2450 50  0001 C CNN
F 3 "" H 5000 2450 50  0001 C CNN
	1    5000 2450
	1    0    0    -1  
$EndComp
$Comp
L power:+3.3V #PWR?
U 1 1 5DBB6662
P 4850 5350
F 0 "#PWR?" H 4850 5200 50  0001 C CNN
F 1 "+3.3V" H 4865 5523 50  0000 C CNN
F 2 "" H 4850 5350 50  0001 C CNN
F 3 "" H 4850 5350 50  0001 C CNN
	1    4850 5350
	1    0    0    -1  
$EndComp
Wire Wire Line
	4700 5000 4700 5350
Wire Wire Line
	4700 5350 4850 5350
Wire Wire Line
	5000 2450 5000 2550
Connection ~ 5000 2550
Wire Wire Line
	5000 2550 5100 2550
$EndSCHEMATC
