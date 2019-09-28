#!/bin/bash

#echo "Usage 1:"
#echo "./build.sh (hw target)"
#echo "compiles using \"production\" settings (SIM_STEP not defined.) If everything compiles and places and packs up right, it will emit a .bin suitable for sending to hardware."
#echo "Target is required. It's one of, sans quotes, \"timer\", \"nybsen\", \"bytesen\", \"ctrlr\" for the different tests we have - "
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
	echo "Target is required. It's one of, sans quotes, \"timer\", \"nybsen\", \"bytesen\", \"ctrlr\" for the different tests we have - "
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
	#builddef="UNKNOWN"
	if [ "$target" == "timer" ]
	then
		echo building timer top
		YS_BUILD_TARGET="LCD_TARGET_TIMER"
	elif [ "$target" == "nybsen" ]
	then
		echo building nybsen top
		YS_BUILD_TARGET="LCD_TARGET_NYBSEN"
	elif [ "$target" == "bytesen" ]
	then
		echo buidling bytesend top
		YS_BUILD_TARGET="LCD_TARGET_BYTESEN"
	elif [ "$target" == "ctrlr" ]
	then
		echo ctrlr placeholder - build not implemented yet!
        #echo but I will drop thru
		exit 1
	else
		echo "UNRECOGNIZED TARGET ${target}"
		exit 1
	fi

	# AND THE GUTS FOR EACH OF THOSE WILL LOOK SOMETHING LIKE THIS
	# or just have the top.v use the define - how to pass it in?
	# https://stackoverflow.com/questions/44463230/parameters-to-script
	# says:
	# The only way to do that at the moment is using environment variables and TCL scripts. For example, you can write a TCL script test.tcl:
	# yosys read_verilog $::env(VLOG_FILE_NAME)
	# yosys synth -top $::env(TOP_MODULE)
	# yosys write_verilog output.v
	# And then call if with VLOG_FILE_NAME and TOP_MODULE set in the environment:
	# VLOG_FILE_NAME=tests/simple/fiedler-cooley.v TOP_MODULE=up3down5 yosys test.tcl
	# If you are running Yosys from a shell script you can also simply run something like export VLOG_FILE_NAME=...
	# at the top of your script. Similarly you can use the export Makefile statement when you are running Yosys from a Makefile.
	# though that's not quite what I'm looking for
	# aha, the yosys manual says that the ys file command read_verilog takes options, one of which is
	# -Dname[=definition]
	# define the preprocessor symbol ’name’ and set its optional value ’definition’
	# so let's do something in the ys like symbol name YS_BUILD_TARGET and the value $target.
	# how to communicate?
	# - could see if that could be put in as an -m on the yosys command line, doing just the $proj_top.v module
	# there, and the rest are in the ys?
	# - could see if setting it in here as an environment var and picking it up in ys is possible?
	# there's that command line format like VAR=value command options...
	# manual has e.g. YOSYS_COVER_DIR="{dir-name}" yosys {args}
	# **************************************************************************************************************
	# **************************************************************************************************************
	# **************************************************************************************************************
	# yosys produces the .json file from all the verilog sources. See the .ys file for details.
	# not sure this works, plus I want like YS_BUILD_TARGET_TIMER so can just do ifdef YS_BUILD_TARGET=$builddef
	# so just have the if block above do it with exports - ok, got that.
	# now how to communicate them to the yosys script? Wait, maybe back to YS_BUILD_TARGET having difft values
	# ok hardcode worked in ys
	# read_verilog -DLCD_TARGET_TIMER hd44780_top.v
	# OK THIS BOTH IMPROVES AND DISIMPROVES the process of duplicating projects. moving this stuff out of the ys
	# file because I can't figure out how to communicate env vars or whatever over there, so this has to be hardcoded
	# to use the list of modules specific to this project.
	# so, I've put the proj-spec stuff in the first line, and can probably pull it out into a variable.
	# DO THAT!
	# on the plus side, the ys file had to be maintained separately too.
	yosys -p "read_verilog hd44780_timer.v; read_verilog hd44780_nybsen.v; read_verilog hd44780_bytesender.v; read_verilog hd44780_syscon.v; \
		read_verilog -D$YS_BUILD_TARGET ${proj}_top.v; \
		synth_ice40 -top ${proj}_top; write_json ${proj}.json"
	#used to just be yosys "$proj".ys

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
	elif [ "$target" == "bytesen" ]
	then
		# ASSUMES CONTROLLER DOES NOTHING BUT SEND A BYTE, a la goal 3
		iverilog -D SIM_STEP -o hd44780_bytesend_tb.vvp hd44780_bytesender.v hd44780_nybsen.v hd44780_bytesend_tb.v hd44780_syscon.v 1>> sim_tb_out.txt 2>> sim_tb_err.txt
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
