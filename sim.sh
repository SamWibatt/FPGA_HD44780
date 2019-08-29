#!/bin/bash
# this one simulates with hd44780_tb instead of hd44780_sim_tb
echo "SIMULATION =============================================================================================== " > sim_tb_out.txt
#if we don't do this, error file will be 0 bytes on successful run
#echo "SIMULATION =============================================================================================== " > sim_tb_err.txt
# but we need to do SOMETHING or they pile up: let's just delete it
rm -f sim_tb_err.txt

# simulation, old: DO IT THIS WAY TO SEE THE SENSIBLE SIMULATION TRACE
iverilog -D SIM_STEP -o hd44780_tb.vvp hd44780_controller.v hd44780_tb.v hd44780_syscon.v 1>> sim_tb_out.txt 2>> sim_tb_err.txt
vvp hd44780_tb.vvp  1>> sim_tb_out.txt 2>> sim_tb_err.txt
#gtkwave -o does optimization of vcd to FST format, good for the big sims
# or just do it here
vcd2fst hd44780_tb.vcd hd44780_tb.fst
rm -f hd44780_tb.vcd
#gtkwave -o hd44780_tb.vcd &
