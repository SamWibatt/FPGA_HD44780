# kvis2vcd.py - script to convert csv file exported from KingstVIS logic analyzer software to vcd for use with gtkwave
# Usage: kvis2vcd (csv exported from KingstVIS) (output vcd) [yaml config file]
# where (csv exported from KingstVIS) contains the logic analyzer traces from a KingstVIS session
# where (output vcd) is path/name for gtkwave input (vcd) file
# (yaml config file) specifies arrangements of the signals into gtkwave signals / signal groupings
# first version doesn't allow for hierarchy in the output, like organizing the KingstVIS signals into modules
# but maybe it should.
# sample command line:
# python3 kvis2vcd.py settings/RandomGarbageInLCDSettings.csv ~/tmp/dum.vcd settings/RandomGarbageKVtoCSV.yaml

import csv
import sys
import yaml
import datetime
import re
import math

# input_vals is a list of single bit values from the csv exported - all the columns except the first, Time[s]
# returns a dict of output var -> value string
def build_var_vals(input_vals):
    global input_names, config_dict, var_order

    valdict = {}
    # so: step through the list of output variables, assemble their values from their inputs.
    # for instance:
    # 'LData': {'type': 'wire', 'width': 4, 'vars': ['LCD Data 3', 'LCD Data 2', 'LCD Data 1', 'LCD Data 0']}
    # because it has a width > 1, its value will be 'b' + the values of the inputs LCD Data 3 ... LCD Data 0 in that order.
    for v in var_order:
        valstr = ""
        # concatenate all the input values corresponding to this variable
        for i in config_dict[v]['vars']:
            valstr += input_vals[input_names.index(i)]

        # multi-bit values start with "b" and have a space after - value has leading zeroes trimmed
        if config_dict[v]['width'] != 1:
            if '1' not in valstr:
                valstr = '0'            # if there were no 1s, value is just 0
            else:
                valstr = re.sub("^0+","",valstr)
            valstr = "b"+valstr+" "

        valdict[v] = valstr

    return valdict

if __name__ == "__main__":

    if(len(sys.argv) < 3):
        print("Usage: kvis2vcd (csv exported from KingstVIS) (output vcd) [yaml config file]")
        print("where (csv exported from KingstVIS) contains the logic analyzer traces from a KingstVIS session")
        print("where (output vcd) is path/name for gtkwave input (vcd) file")
        print("(yaml config file) specifies arrangements of the signals into gtkwave signals / signal groupings")
        print("if config file not given, all signals treated as 1 bit wire in csv column order")
        print("first version doesn't allow for hierarchy in the output, like organizing the KingstVIS signals into modules")
        sys.exit(1)

    csv_file_name = sys.argv[1]
    vcd_file_name = sys.argv[2]
    if len(sys.argv) > 3:
        config_file_name = sys.argv[3]
    else:
        print("NOTE: no config file given. treating all signals as 1 bit wire in csv column order")
        config_file_name = None

    # so let us build:
    # list of input names - columns, minus the first one, which is time[s]
    # list of rows, where each row is a [timestamp, [values]]
    input_names = []
    csv_rows = []

    print("Reading csv file {}...".format(csv_file_name))
    with open(csv_file_name) as csvfile:
        linenum = 1
        r = csv.reader(csvfile, delimiter = ',', quotechar = '"')
        for row in r:
            nurow = [x.strip() for x in row]            # trim leading/trailing whitespace
            if linenum == 1:
                # first row assumed to be input names, after the time column
                input_names = nurow[1:]
            else:
                # subsequent rows are [timestamp, [values]]
                csv_rows.append([nurow[0], nurow[1:]])
            linenum += 1

    print("Input names: {}".format(", ".join(['"'+c+'"' for c in input_names])))
    print("First <= 10 Rows:")
    linenum = 1
    for row in csv_rows:
        print("time {}: {}".format(row[0], "|".join(row[1])))
        linenum += 1
        if(linenum > 10):
            break

    # configuration!

    if config_file_name is not None:
        with open(config_file_name) as yamfile:
            yamdocs = yaml.load_all(yamfile)
            config_dict = next(yamdocs)         # yaml file may have multiple documents, may use that to implement modules...
            var_order = list(config_dict.keys())  # not sure order will be right
    else:
        # set up default dictionary mapping each signal to 1 bit wire
        # guessing at dictionary comprehension syntax on the bus in mad traffic at 6:26 am
        # keeping order and names from csv
        # ASSUME FIRST COLUMN IS TIME so skip it
        config_dict = { k:{'type': 'wire', 'width': 1, 'vars': [k]} for k in input_names}     # MAY NEED TO LEGITIFY INPUT_NAMES AS VARIABLE NAMES bc "Time[s]" might not be a legal label in vcd
        var_order = input_names

    # TIMESCALE SETTINGS - FIGURE OUT HOW TO HANDLE THESE IN THE YAML
    timescale_coefficient = 1
    timescale_units = "ns"

    # OK SO HERE IS WHERE WE DO STUFF MASHING TOGETHER CSV AND YAML
    # don't bother opening output until here bc we now know the csv exists and config
    # is set up.

    with open(vcd_file_name,'wt') as vcdfile:
        # OUTPUT SIDE ===============================================================================================
        # so ok, there is some header stuff we need on any file
        #$date
        #	Mon Sep 16 13:05:26 2019
        #$end
        datetime_object = datetime.datetime.now()
        datetime_str = datetime_object.strftime("%a %b %-d %H:%M:%S %Y")
        vcdfile.write("$date\n    {}\n$end\n".format(datetime_str))

        #$version
        #	Icarus Verilog
        #$end
        vcdfile.write("$version\n    kvis2vcd.py\n$end\n")

        # - then after that comes all the stuff we want to put in the config file
        # FIGURE OUT HOW TO CONFIGURE THIS IN THE YAML! *************************************************************************************
        #$timescale
        #	1ns
        #$end
        vcdfile.write("$timescale\n    {}{}\n$end\n".format(timescale_coefficient,timescale_units))


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

        # ! is the first allowable variable name in vcd, and just keep incrementing from there. Max is what? 126?
        id_ascii = 33           # start with !

        # MAKE MODULE NAME CONFIGGABLE TOO
        module_name = csv_file_name.replace(".csv","")
        module_name = re.sub("[^A-Za-z0-9_]","_",module_name)
        vcdfile.write("$scope module {} $end\n".format(module_name))

        # then step through the var names - here we just need the width, type, and identifier
        #Yamdoc dict: {'LData': {'type': 'wire', 'width': 4, 'vars': ['LCD Data 0', 'LCD Data 1', 'LCD Data 2', 'LCD Data 3']},
        #              'RS': {'type': 'wire', 'width': 1, 'vars': ['LCD RS']},
        #              'E': {'type': 'wire', 'width': 1, 'vars': ['LCD E']},
        #              'LA_Strobe': {'vars': ['Logan Stb']}}

        # this maps the variable names to their vcd single-char identifier
        var_to_vcd_id = {}

        for v in var_order:
            print("{}...".format(v))
            var_config = config_dict[v]
            if var_config is None:
                print("ARGH no entry for var {} - dumping out".format(v))

            # default width, if none given, is 1 bit. Warn.
            if 'width' not in var_config:
                print("Warning: no width given for var {} - assuming 1".format(v))
                var_config['width'] = 1

            # similar, default type is wire.
            if 'type' not in var_config:
                print("Warning: no type given for var {} - assuming wire".format(v))
                var_config['type'] = 'wire'

            var_to_vcd_id[v] = chr(id_ascii)

            if var_config['width'] == 1:
                vcdfile.write("    $var {} {} {} {} $end\n".format(var_config['type'],var_config['width'],chr(id_ascii),v))
            else:
                vcdfile.write("    $var {} {} {} {} [{}:0] $end\n".format(var_config['type'],var_config['width'],chr(id_ascii),v,(var_config['width']-1)))
            id_ascii += 1
            if id_ascii > 126:
                print("ERROR: too many variables! ASCII counter went over 126")
                sys.exit(1)


        vcdfile.write("$upscope $end\n")

        vcdfile.write("$enddefinitions $end\n")

        # OK NOW HERE WE GET DOWN TO DUMPING STUFF
        # rows are [timestamp, [values]]
        # where values are in the order of input_names

        # figure out how long one tick is!
        # s, ms, us, ns, ps, or fs are the possible units.
        timescale_tick_sec = 0.0
        if timescale_units == 's':
            timescale_tick_sec = 1.0
        elif timescale_units == 'ms':
            timescale_tick_sec = (1.0 / 1000.0)
        elif timescale_units == 'us':
            timescale_tick_sec = (1.0 / 1000000.0)
        elif timescale_units == 'ns':
            timescale_tick_sec = (1.0 / 1000000000.0)
        elif timescale_units == 'ps':
            timescale_tick_sec = (1.0 / 1000000000000.0)
        elif timescale_units == 'fs':
            timescale_tick_sec = (1.0 / 1000000000000000.0)     # see if python can handle precisions like this!

        # timescale coefficient can only be 1, 10, or 100
        timescale_tick_sec *= float(timescale_coefficient)

        print("Timescale of {}{} means #1 = {}sec".format(timescale_coefficient,timescale_units,timescale_tick_sec))

        # so now as we march through the timestamps we can use ceil(timestamp / timescale_tick_sec) or something in order to get the integer #timings.
        # NEXT UP NORMALIZE THE TIMESTAMPS S.T. THE EARLIEST IS AT 0.00000 BC I BELIEVE the KingstVIS files can start before 0,
        # like with TimerLATest.csv's first row, -0.002500129, 0, 0, 0
        # DO THAT!
        # then go through and convert all the 'stamps to integer, and may need to do them as deltas
        # but emit the #time and the changes, and that should be that
        first_time = csv_rows[0][0]
        #print("first_time is {} of type {}".format(first_time,type(first_time)))

        # figure out how much to fudge times by to normalize
        # do even if first_time is 0, to cast every timestamp to float.
        # COULD just do the int conversion here too why not
        timefudge = -float(first_time)
        lastvaldict = {}
        for crow in csv_rows:
            crow[0] = '#' + str(int(math.ceil((float(crow[0]) + timefudge) / timescale_tick_sec)))
            # we need a la
            # #0
            # $dumpvars
            # b0 <
            #      ^^^ $var reg 4 < rst_cnt [3:0] $end; also see e.g. b110 <, I think it zero-fills to left
            # 0;
            #      ^^^ $var reg 1 ; rs_reg $end
            # b0 :
            #      ^^^ $var reg 4 : o_lcd_reg [3:0] $end
            # 09
            # [...]
            # 1"
            #      ^^^ $var wire 1 " CLK_I $end
            # 1!
            # $end
            # #5
            # [...]
            # hereafter don't need the $dumpvars and $end.
            vcdfile.write("{}\n".format(crow[0]))

            # at every step, find the values of all variables. This is not a really efficient way to do it,
            # but I'm not expecting that to matter - logic analyzers don't have THAT many channels and we have
            # at most that many variables based on the inputs.
            valdict = build_var_vals(crow[1])

            if crow[0] == '#0':
                ## first time step, emit initial values, how to order? Try var_order
                vcdfile.write("$dumpvars\n")
                #debug vcdfile.write("{}\n".format("|".join(crow[1])))
                for v in var_order:
                    vcdfile.write("{}{}\n".format(valdict[v],var_to_vcd_id[v]))
                vcdfile.write("$end\n")
            else:
                # FIGURE OUT HERE HOW THINGS CHANGED AND EMIT IT - so step through valdict by vars, and if
                # lastvaldict[v] != valdict[v], emit valdict[v]
                # debug vcdfile.write("{}\n".format("|".join(crow[1])))
                for v in var_order:
                    if lastvaldict[v] != valdict[v]:
                        vcdfile.write("{}{}\n".format(valdict[v],var_to_vcd_id[v]))
            lastvaldict = valdict


        first_time = csv_rows[0][0]
        print("first_time after normalization is {} of type {}".format(first_time,type(first_time)))
