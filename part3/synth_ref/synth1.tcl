##############################################
# Setup: fill out the following parameters: name of clock signal, clock period (ns),
# reset signal name (if used), name of top-level module, name of source file
set CLK_NAME "clk";
set CLK_PERIOD 0.92
set RST_NAME "reset";
set TOP_MOD_NAME "multi_64_33_9_10_16_50";
set SRC_FILE [list "../rtl_files_64_33_9_10_16_50/multi_64_33_9_10_16_50.sv" "../rtl_files_64_33_9_10_16_50/conv_64_33_16_32.sv" "../rtl_files_64_33_9_10_16_50/conv_32_9_16_12.sv" "../rtl_files_64_33_9_10_16_50/conv_24_10_16_5.sv" "../rtl_files_64_33_9_10_16_50/fmem_ROM_64_33.sv" "../rtl_files_64_33_9_10_16_50/fmem_ROM_32_9.sv" "../rtl_files_64_33_9_10_16_50/fmem_ROM_24_10.sv" "../rtl_files_64_33_9_10_16_50/memory.sv" "../rtl_files_64_33_9_10_16_50/ctrl_mem_write.sv" "../rtl_files_64_33_9_10_16_50/ctrl_conv_output.sv" "../rtl_files_64_33_9_10_16_50/mac.sv" "../rtl_files_64_33_9_10_16_50/y_buffer.sv"];