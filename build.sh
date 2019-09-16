#!/bin/bash

#echo "Usage 1:"
#echo "./build.sh (hw target)"
#echo "compiles using \"production\" settings (SIM_STEP not defined.) If everything compiles and places and packs up right, it will emit a .bin suitable for sending to hardware."
#echo "Target is required. It's one of, sans quotes, \"timer\", \"nybsen\", \"bytesend\", \"ctrlr\" for the different tests we have - "
#echo "state timer, nybble sender, byte sender, controller."
#echo "Usage 2:"
#echo "./build.sh sim [sim target]"
#echo "where \"sim\" is a literal. Sim target defaults to ctrlr if not given."



set -ex
# and so this is easy to copy to other projects and rename stuff
proj="hd44780"

if [ "$1" == "" ]
then
	set +x
	echo "Usage 1:"
	echo "./build.sh (hw target)"
	echo "compiles using \"production\" settings (SIM_STEP not defined.) If everything compiles and places and packs up right, it will emit a .bin suitable for sending to hardware."
	echo "Target is required. It's one of, sans quotes, \"timer\", \"nybsen\", \"bytesend\", \"ctrlr\" for the different tests we have - "
	echo "state timer, nybble sender, byte sender, controller."
	echo "Usage 2:"
	echo "./build.sh sim [sim target]"
	echo "where \"sim\" is a literal. Sim target defaults to ctrlr if not given."
	exit 1
fi




if [ "$1" != "sim" ]
then
	# first arg, if any, is not "sim", so just do a build.
	# HOW TO DIFFERENTIATE WHAT HW TEST TO BUILD? arg 1, I suppose, is assumed to represent a test.
	# ****************************** HAVE TO FIGURE THIS OUT!
	if [ "$1" != "" ]
	then
		target=$1
	else
		target="ctrlr"
	fi

	echo "Non-sim build! Target is ${target}"
	
	# device targeted, use one of the architecture flags from nextpnr-ice40's help:
	#Architecture specific options:
	#  --lp384                     set device type to iCE40LP384
	#  --lp1k                      set device type to iCE40LP1K
	#  --lp8k                      set device type to iCE40LP8K
	#  --hx1k                      set device type to iCE40HX1K
	#  --hx8k                      set device type to iCE40HX8K
	#  --up5k                      set device type to iCE40UP5K
	#  --u4k                       set device type to iCE5LP4K
	# only without the --
	device="up5k"

	# similar for package. The options can be found by grepping around in the nextpnr source,
	# in the nextpnr/ice40/main.cc file, look for the word "package."
	package="sg48"

	# **************************************************************************************************************
	# **************************************************************************************************************
	# **************************************************************************************************************
	# HEREAFTER ACCOUNT FOR DIFFERENT TARGETS IN REAL BUILD
	# **************************************************************************************************************
	# **************************************************************************************************************
	# **************************************************************************************************************
	if [ "$target" == "timer" ]
	then
		echo timer placeholder - build not implemented yet!
		exit 1
	elif [ "$target" == "nybsen" ]
	then
		echo nybsen placeholder - build not implemented yet!
		exit 1
	elif [ "$target" == "bytesend" ]
	then
		echo bytesend placeholder - build not implemented yet!
		exit 1
	elif [ "$target" == "ctrlr" ]
	then
		echo ctrlr placeholder - build not implemented yet!
		exit 1
	else
		echo "UNRECOGNIZED TARGET ${target}"
		exit 1
	fi

	# AND THE GUTS FOR EACH OF THOSE WILL LOOK SOMETHING LIKE THIS
	# **************************************************************************************************************
	# **************************************************************************************************************
	# **************************************************************************************************************
	# yosys produces the .json file from all the verilog sources. See the .ys file for details.
	yosys "$proj".ys

	# nextpnr does place-and-route, associating the design with the particular hardware layout
	# given in the .pcf.
	nextpnr-ice40 --"$device" --package "$package" --json "$proj".json --pcf "$proj".pcf --asc "$proj".asc

	# icepack converts nextpnr's output to a bitstream usable by the target hardware.
	icepack "$proj".asc "$proj".bin

	# use
	# iceprog (proj).bin
	# to send the binary to the chip.
	# iceprog -v shows LOTS of info
	# you may have to sudo.
	# **************************************************************************************************************
	# **************************************************************************************************************
	# **************************************************************************************************************	
else
	# ok, this IS a simulation run, have target $2 default to controller too
	if [ "$2" != "" ]
	then
		target=$2
	else
		target="ctrlr"
	fi

	echo "Simulation build! Target is ${target}"

	# common to all sim builds
	echo "SIMULATION =============================================================================================== " > sim_tb_out.txt
	#if we don't do this, error file will be 0 bytes on successful run
	#echo "SIMULATION =============================================================================================== " > sim_tb_err.txt
	# but we need to do SOMETHING or they pile up: let's just delete it
	rm -f sim_tb_err.txt

	if [ "$target" == "timer" ]
	then
		# this is just the guts of sim_timer.sh transplanted
		iverilog -D SIM_STEP -o hd44780_timer_tb.vvp hd44780_timer.v hd44780_timer_tb.v hd44780_syscon.v 1>> sim_tb_out.txt 2>> sim_tb_err.txt
		vvp hd44780_timer_tb.vvp  1>> sim_tb_out.txt 2>> sim_tb_err.txt
		#gtkwave -o does optimization of vcd to FST format, good for the big sims
		# or just do it here
		vcd2fst hd44780_timer_tb.vcd hd44780_timer_tb.fst
		rm -f hd44780_timer_tb.vcd
		#gtkwave -o hd44780_timer_tb.fst &
	elif [ "$target" == "nybsen" ]
	then
		iverilog -D SIM_STEP -o hd44780_nybsen_tb.vvp hd44780_nybsen.v hd44780_nybsen_tb.v hd44780_syscon.v 1>> sim_tb_out.txt 2>> sim_tb_err.txt
		vvp hd44780_nybsen_tb.vvp  1>> sim_tb_out.txt 2>> sim_tb_err.txt
		#gtkwave -o does optimization of vcd to FST format, good for the big sims
		# or just do it here
		vcd2fst hd44780_nybsen_tb.vcd hd44780_nybsen_tb.fst
		rm -f hd44780_nybsen_tb.vcd
		#gtkwave -o hd44780_nybsen_tb.fst &	
	elif [ "$target" == "bytesend" ]
	then
		# ASSUMES CONTROLLER DOES NOTHING BUT SEND A BYTE, a la goal 3
		iverilog -D SIM_STEP -o hd44780_bytesend_tb.vvp hd44780_controller.v hd44780_nybsen.v hd44780_tb.v hd44780_syscon.v 1>> sim_tb_out.txt 2>> sim_tb_err.txt
		# and so there is this kludge too
		mv hd44780_tb.vcd hd44780_bytesend_tb.vcd
		vvp hd44780_bytesend_tb.vvp  1>> sim_tb_out.txt 2>> sim_tb_err.txt
		#gtkwave -o does optimization of vcd to FST format, good for the big sims
		# or just do it here
		vcd2fst hd44780_bytesend_tb.vcd hd44780_bytesend_tb.fst
		rm -f hd44780_bytesend_tb.vcd
		#gtkwave -o hd44780_tb.vcd &
	elif [ "$target" == "ctrlr" ]
	then
		echo ctrlr placeholder - test not implemented yet!
		exit 1
	else
		echo "UNRECOGNIZED TARGET ${target}"
		exit 1
	fi




fi