# kvis2vcd.py - script to convert csv file exported from KingstVIS logic analyzer software to vcd for use with gtkwave
# Usage: kvis2vcd (csv exported from KingstVIS) (output gtkw) [yaml config file]
# where (csv exported from KingstVIS) contains the logic analyzer traces from a KingstVIS session
# where (output gtkw) is path/name for gtkwave file
# (yaml config file) specifies arrangements of the signals into gtkwave signals / signal groupings
# first version doesn't allow for hierarchy in the output, like organizing the KingstVIS signals into modules
# but maybe it should.

import csv
import sys
import yaml

if __name__ == "__main__":

    if(len(sys.argv) < 3):
        print("Usage: kvis2vcd (csv exported from KingstVIS) (output gtkw) [yaml config file]")
        print("where (csv exported from KingstVIS) contains the logic analyzer traces from a KingstVIS session")
        print("where (output gtkw) is path/name for gtkwave file")
        print("(yaml config file) specifies arrangements of the signals into gtkwave signals / signal groupings")
        print("if config file not given, all signals treated as 1 bit wire in csv column order")
        print("first version doesn't allow for hierarchy in the output, like organizing the KingstVIS signals into modules")
        sys.exit(1)

    csv_file_name = sys.argv[1]
    gtkw_file_name = sys.argv[2]
    if len(sys.argv) > 3:
        config_file_name = sys.argv[3]
    else:
        print("NOTE: no config file given. treating all signals as 1 bit wire in csv column order")
        config_file_name = None

    #>>> import csv
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

    # so let us build:
    # list of column names
    # list of rows, where each row is a [timestamp, [values]]
    column_names = []
    csv_rows = []

    print("Reading csv file {}...".format(csv_file_name))
    with open(csv_file_name) as csvfile:
        linenum = 1
        r = csv.reader(csvfile, delimiter = ',', quotechar = '"')
        for row in r:
            nurow = [x.strip() for x in row]            # trim leading/trailing whitespace
            if linenum == 1:
                # first row assumed to be column names
                column_names = nurow
            else:
                # subsequent rows are [timestamp, [values]]
                csv_rows.append([nurow[0], nurow[1:]])
            linenum += 1

    print("Column names: {}".format(", ".join(['"'+c+'"' for c in column_names])))
    print("First <= 10 Rows:")
    linenum = 1
    for row in csv_rows:
        print("time {}: {}".format(row[0], "|".join(row[1])))
        linenum += 1
        if(linenum > 10):
            break


    # we want something like this, from the random-lcd-garbage csv I have
    #Time[s], LCD Data 0, LCD Data 1, LCD Data 2, LCD Data 3, LCD RS, LCD E, Logan Stb
    #0.000000000, 0, 1, 0, 1, 0, 1, 0
    #0.000001156, 1, 1, 0, 1, 0, 1, 0
    #0.000002812, 1, 1, 0, 1, 1, 1, 0
    #0.000003813, 1, 0, 0, 1, 1, 1, 0
    #0.000005969, 1, 0, 0, 1, 1, 1, 1
    #[...]

    # configuration!
    
    
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

    # reading that as yaml appears to work - this is after doing pip install PyYAML
    #Yamdoc dict: {'LData': {'type': 'wire', 'width': 4, 'vars': ['LCD Data 0', 'LCD Data 1', 'LCD Data 2', 'LCD Data 3']},
    #              'RS': {'type': 'wire', 'width': 1, 'vars': ['LCD RS']},
    #              'E': {'type': 'wire', 'width': 1, 'vars': ['LCD E']},
    #              'LA_Strobe': {'vars': ['Logan Stb']}}
    
    if config_file_name is not None:
        with open(config_file_name) as yamfile:
            yamdocs - yaml.load_all(yamfile)
            first_yamdoc = next(yamdocs)        # yaml file may have multiple documents, may use that to implement modules
    else:
        # set up default dictionary mapping each signal to 1 bit wire
        # guessing at dictionary comprehension syntax on the bus in mad traffic at 6:26 am
        # keeping order and names from csv
        # def gotta refac this to have a better var name
        first_yamdoc = { k, {'type': 'wire', 'width': 1, 'vars': [k]} for k in column_names}



    # OK SO HERE IS WHERE WE DO STUFF MASHING TOGETHER CSV AND YAML
    # don't bother opening output until here bc we now know the csv exists and config 
    # is set up. 



    # OUTPUT SIDE ===============================================================================================
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
    # 	$var reg 1 ( clk $end	<================================= I should be able to have everything be wires
    #   [...]
    # 	$var reg 1 + lcd_rs $end
    # 		$scope module cont $end
    # 			$var wire 1 ) STB_I $end
    # 			$var wire 1 & alive_led $end
    # 			$var wire 1 ' busy $end
    #           [...]
    # 			$var reg 1 5 ns_ststrobe $end
    # 				$scope module nybsen $end
    # 					$var wire 1 5 STB_I $end
    # 					$var reg 4 : o_lcd_reg [3:0] $end
    # 					$var reg 1 ; rs_reg $end
    # 				$upscope $end
    # 		$upscope $end
    # 	$scope module syscon $end
    # 		$var wire 1 ( i_clk $end
    # 		$var reg 4 < rst_cnt [3:0] $end
    # 	$upscope $end
    # $upscope $end

    # Do I care about supporting nesting? Yes, eventually, bud this off into its own little repo-chan
