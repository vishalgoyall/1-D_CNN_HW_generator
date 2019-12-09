use strict;
use warnings;

 my $file = "synth1.tcl";
 open(my $fh, '>', $file) or die "$file could not be created"; 

 my $N       = $ARGV[0];
 my $M1      = $ARGV[1];
 my $M2      = $ARGV[2];
 my $M3      = $ARGV[3];
 my $T       = $ARGV[4];
 my $P       = $ARGV[5];
 my $P1      = $ARGV[6];
 my $P2      = $ARGV[7];
 my $P3      = $ARGV[8];

 my $N1 = $N;
 my $N2 = $N1-$M1+1;
 my $N3 = $N2-$M2+1;

print $fh "##############################################
# Setup: fill out the following parameters: name of clock signal, clock period (ns),
# reset signal name (if used), name of top-level module, name of source file
set CLK_NAME \"clk\";
set CLK_PERIOD 0.92
set RST_NAME \"reset\";
set TOP_MOD_NAME \"multi_$N\_$M1\_$M2\_$M3\_$T\_$P\";
set SRC_FILE [list \"../rtl_files_$N\_$M1\_$M2\_$M3\_$T\_$P\/multi_$N\_$M1\_$M2\_$M3\_$T\_$P.sv\" \"../rtl_files_$N\_$M1\_$M2\_$M3\_$T\_$P\/conv\_$N1\_$M1\_$T\_$P1.sv\" \"../rtl_files_$N\_$M1\_$M2\_$M3\_$T\_$P\/conv\_$N2\_$M2\_$T\_$P2.sv\" \"../rtl_files_$N\_$M1\_$M2\_$M3\_$T\_$P\/conv\_$N3\_$M3\_$T\_$P3.sv\" \"../rtl_files_$N\_$M1\_$M2\_$M3\_$T\_$P\/fmem_ROM\_$N1\_$M1.sv\" \"../rtl_files_$N\_$M1\_$M2\_$M3\_$T\_$P\/fmem_ROM\_$N2\_$M2.sv\" \"../rtl_files_$N\_$M1\_$M2\_$M3\_$T\_$P\/fmem_ROM\_$N3\_$M3.sv\" \"../rtl_files_$N\_$M1\_$M2\_$M3\_$T\_$P\/memory.sv\" \"../rtl_files_$N\_$M1\_$M2\_$M3\_$T\_$P\/ctrl_mem_write.sv\" \"../rtl_files_$N\_$M1\_$M2\_$M3\_$T\_$P\/ctrl_conv_output.sv\" \"../rtl_files_$N\_$M1\_$M2\_$M3\_$T\_$P\/mac.sv\" \"../rtl_files_$N\_$M1\_$M2\_$M3\_$T\_$P\/y_buffer.sv\"];";

close $fh;
