##############################################
# Setup: fill out the following parameters: name of clock signal, clock period (ns),
# reset signal name (if used), name of top-level module, name of source file
set CLK_NAME "clk";
set CLK_PERIOD 0.92
set RST_NAME "reset";
set TOP_MOD_NAME "multi_64_33_9_10_16_50";
set SRC_FILE [list "../rtl_files_64_33_9_10_16_50/multi_64_33_9_10_16_50.sv" "../rtl_files_64_33_9_10_16_50/conv_64_33_16_32.sv" "../rtl_files_64_33_9_10_16_50/conv_32_9_16_12.sv" "../rtl_files_64_33_9_10_16_50/conv_24_10_16_5.sv" "../rtl_files_64_33_9_10_16_50/fmem_ROM_64_33.sv" "../rtl_files_64_33_9_10_16_50/fmem_ROM_32_9.sv" "../rtl_files_64_33_9_10_16_50/fmem_ROM_24_10.sv" "../rtl_files_64_33_9_10_16_50/memory.sv" "../rtl_files_64_33_9_10_16_50/ctrl_mem_write.sv" "../rtl_files_64_33_9_10_16_50/ctrl_conv_output.sv" "../rtl_files_64_33_9_10_16_50/mac.sv" "../rtl_files_64_33_9_10_16_50/y_buffer.sv"];
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

