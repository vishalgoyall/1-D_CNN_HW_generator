
# If you have multiple source files, change the line above to list them all like this:
# set SRC_FILE [list "file1.sv" "file2.sv"];
###############################################

source setupdc.tcl
file mkdir work_synth

define_design_lib WORK -path work_synth
analyze $SRC_FILE -format sverilog
elaborate -work WORK $TOP_MOD_NAME

###### CLOCKS AND PORTS #######
set CLK_PORT [get_ports $CLK_NAME]
set TMP1 [remove_from_collection [all_inputs] $CLK_PORT]
set INPUTS [remove_from_collection $TMP1 $RST_NAME]
create_clock -period $CLK_PERIOD [get_ports clk]
# set delay for inputs to be 0.2ns
set_input_delay 0.2 -max -clock clk $INPUTS
set_output_delay 0.2 -max -clock clk [all_outputs]

###### OPTIMIZATION #######
set_max_area 0 

###### RUN #####
compile_ultra
report_area
report_power
report_timing
write -f verilog $TOP_MOD_NAME -output gates.v -hierarchy

quit

