##############################################
# Setup: fill out the following parameters: name of clock signal, clock period (ns),
# reset signal name (if used), name of top-level module, name of source file
set CLK_NAME "clk";
set CLK_PERIOD 0.92
set RST_NAME "reset";
set TOP_MOD_NAME "conv_64_33_16_16";
set SRC_FILE [list "../rtl_files_64_33_16_16/conv_64_33_16_16.sv" "../rtl_files_64_33_16_16/fmem_ROM.sv" "../rtl_files_64_33_16_16/memory.sv" "../rtl_files_64_33_16_16/ctrl_mem_write.sv" "../rtl_files_64_33_16_16/ctrl_conv_output.sv" "../rtl_files_64_33_16_16/mac.sv" "../rtl_files_64_33_16_16/y_buffer.sv"];