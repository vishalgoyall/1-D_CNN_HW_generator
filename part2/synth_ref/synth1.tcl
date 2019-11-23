##############################################
# Setup: fill out the following parameters: name of clock signal, clock period (ns),
# reset signal name (if used), name of top-level module, name of source file
set CLK_NAME "clk";
set CLK_PERIOD 0.92
set RST_NAME "reset";
set TOP_MOD_NAME "conv_43_16_32_1";
set SRC_FILE [list "../rtl_files_43_16_32_1/conv_43_16_32_1.sv" "../rtl_files_43_16_32_1/fmem_ROM.sv" "../rtl_files_43_16_32_1/memory.sv" "../rtl_files_43_16_32_1/ctrl_mem_write.sv" "../rtl_files_43_16_32_1/ctrl_conv_output.sv" "../rtl_files_43_16_32_1/mac.sv"];