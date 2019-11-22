use strict;
use warnings;

 my $file = "synth1.tcl";
 open(my $fh, '>', $file) or die "$file could not be created"; 

 my $N       = $ARGV[0];
 my $M       = $ARGV[1];
 my $T       = $ARGV[2];
 my $P       = $ARGV[3];

print $fh "##############################################
# Setup: fill out the following parameters: name of clock signal, clock period (ns),
# reset signal name (if used), name of top-level module, name of source file
set CLK_NAME \"clk\";
set CLK_PERIOD 0.92
set RST_NAME \"reset\";
set TOP_MOD_NAME \"conv_$N\_$M\_$T\_$P\";
set SRC_FILE [list \"../rtl_files_$N\_$M\_$T\_$P\/conv_$N\_$M\_$T\_$P.sv\" \"../rtl_files_$N\_$M\_$T\_$P\/fmem_ROM.sv\" \"../rtl_files_$N\_$M\_$T\_$P\/memory.sv\" \"../rtl_files_$N\_$M\_$T\_$P\/ctrl_mem_write.sv\" \"../rtl_files_$N\_$M\_$T\_$P\/ctrl_conv_output.sv\" \"../rtl_files_$N\_$M\_$T\_$P\/mac.sv\"];";

close $fh;
