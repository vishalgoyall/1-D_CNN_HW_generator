##########################################################################################################
# Perl file to generate design for Project 3 : 1D convolution neural network
# Part 2
# Authors: Prateek Jain and Vishal Goyal
# -> Script has been divided into subroutines, each tasked to generate individual component of the design
# -> Expected order of argument list is <N M T P constant.txt>
##########################################################################################################

use strict;
use warnings;
use POSIX qw(ceil);

###############################################################
# MAIN SECTION
###############################################################

 my $N        = $ARGV[0];
 my $M1       = $ARGV[1];
 my $M2       = $ARGV[2];
 my $M3       = $ARGV[3];
 my $T        = $ARGV[4];
 my $A        = $ARGV[5];
 my $fileROM  = $ARGV[6];

 my $L1 = $N  - $M1 + 1;
 my $L2 = $L1 - $M2 + 1;
 my $L3 = $L2 - $M3 + 1;

 #init values for P1, P2 and P3
 my $P1 = $L1; 
 my $P2 = $L2;
 my $P3 = $L3;
 my $found = 0;


 my @P1_vals;
 my @P2_vals;
 my @P3_vals;

 open (my $logFile, '>', "log.txt") or die "Could not open log.txt";

 if ($A > 2) {
	 while ($P1 >= 1) {  #continue till P1 becomes less than 1
		 if ($L1 % $P1 == 0) { #check for integer relation between L and P
			 $P2 = $L2;
			 while ($P2 >= 1) {  #continue till P2 becomes less than 1
				 if ($L2 % $P2 == 0) {   #check for integer relation between L and P
					 $P3 = $L3;
					 while ($P3 >= 1) { #continue till P3 becomes less than 1
						 if ($L3 % $P3 == 0){  #check for integer relation between L and P
							 if ($P1 + $P2 + $P3 <= $A) {  #if a combination is found then exit all loops
								 push (@P1_vals,$P1);
								 push (@P2_vals,$P2);
								 push (@P3_vals,$P3);
								 last;
							 }
							 elsif ($P3 != 1) {$P3 = $P3-1;}
							 elsif ($P3 == 1) {last;}
						 }
						 else {
							 $P3 = $P3-1;
						 }
					 }
					 if ($P2 != 1) {$P2= $P2-1;}
					 else {last;}

				 }
				 else {
					 $P2 = $P2-1;
				 }
			 }
			 if ($P1 == 1) {last;}
			 else {$P1 = $P1-1;}

		 } 
		 else {
			 $P1 = $P1-1;
		 }
	 }
	 print $logFile "\nAll possible solutions for P1, P2 and P3";
	 print $logFile "\nP1 = @P1_vals";
	 print $logFile "\nP2 = @P2_vals";
	 print $logFile "\nP3 = @P3_vals\n";

	 #find best possible solution
	 my $bestOptim;
	 my $bestOptimIndex;
	 for my $i (0..(scalar(@P1_vals)-1)) {
		 my $Layer1_cycles = (3+$M1)*($L1/$P1_vals[$i]);
		 my $Layer2_cycles = (3+$M2)*($L2/$P2_vals[$i]);
		 my $Layer3_cycles = (3+$M3)*($L3/$P3_vals[$i]);
		 my $currCycles = $Layer1_cycles + $Layer2_cycles + $Layer3_cycles;
		 print $logFile "**$currCycles cycles (convolution only) if we use P1 P2 P3 at index $i\n";
		 if ($i == 0) {
			 $bestOptim = $currCycles;
			 $bestOptimIndex = $i;
		 }
		 elsif ($currCycles < $bestOptim) {
			 $bestOptim = $currCycles;
			 $bestOptimIndex = $i;
		 }
	 }

	 $P1 = $P1_vals[$bestOptimIndex];
	 $P2 = $P2_vals[$bestOptimIndex];
	 $P3 = $P3_vals[$bestOptimIndex];
	 
	 print $logFile "\n--> Best possible combination is for index $bestOptimIndex : P1 = $P1; P2 = $P2; P3 = $P3\n\n";

 } else {
	 print $logFile "Minimum expected value of A is 3 as this is a 3 layer CNN system"
 }

 ###########################################
 ### Reading ROM file and generating separating ROM files for each layer
 my $rowCnt = 0;
 open(my $fhi, '<', $fileROM) or die "$fileROM could not be opened";
 
 ## For first layer
 my $fileROM_1 = "tbgen_$N\_$M1\_$M2\_$M3\_$T\_$A/const_fmem_ROM1.txt";
 open(my $fho1, '>', $fileROM_1) or die "$fileROM_1 could not be created";
 ## For second layer
 my $fileROM_2 = "tbgen_$N\_$M1\_$M2\_$M3\_$T\_$A/const_fmem_ROM2.txt";
 open(my $fho2, '>', $fileROM_2) or die "$fileROM_2 could not be created";
 ## For third layer
 my $fileROM_3 = "tbgen_$N\_$M1\_$M2\_$M3\_$T\_$A/const_fmem_ROM3.txt";
 open(my $fho3, '>', $fileROM_3) or die "$fileROM_3 could not be created";

 ## Copying only M1 lines from input const file
 while (my $row = <$fhi>) {
	 chomp $row;
	 if ($rowCnt < $M1) { # lines 1 - M1 for first layer
		 print $fho1 "$row\n";
	 } elsif ($rowCnt < $M1+$M2) { # lines M1+1 - M2 for second layer
		 print $fho2 "$row\n";
	 } elsif ($rowCnt < $M1+$M2+$M3) { # lines M2+1 - M3 for third layer
		 print $fho3 "$row\n";
	 }
	 $rowCnt++;
 }

 close $fho1;
 close $fho2;
 close $fho3;

 close $fhi;

 ###########################################
 ### Creating conv modules for each layer
 
 my $topRtlHier = "rtl_files_$N\_$M1\_$M2\_$M3\_$T\_$A";
 my $N1 = $N;
 my $N2 = $L1;
 my $N3 = $L2;

 system("perl gen_cnn.pl $N1 $M1 $T $P1 $fileROM_1 1 $topRtlHier");
 system("perl gen_cnn.pl $N2 $M2 $T $P2 $fileROM_2 0 $topRtlHier");
 system("perl gen_cnn.pl $N3 $M3 $T $P3 $fileROM_3 0 $topRtlHier");

 ##########################################
 ### Creating top wrapper module for all the three layers
 my $top_module_layer1 = "conv_$N1\_$M1\_$T\_$P1";
 my $top_module_layer2 = "conv_$N2\_$M2\_$T\_$P2";
 my $top_module_layer3 = "conv_$N3\_$M3\_$T\_$P3";

 my $wrapper_module = "multi_$N\_$M1\_$M2\_$M3\_$T\_$A";

 my $fileTop = "$topRtlHier/$wrapper_module.sv";
 print "../$topRtlHier/$wrapper_module.sv\n";

 open(my $topWrapper, '>', $fileTop) or die "$fileTop could not be created\n";

 print $topWrapper "
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// Toplevel file to do 3 layered 1D convolution for N=$N, M1=$M1, M2=$M2, M3=$M3, T=$T, A=$A 
// Authors: Prateek Jain and Vishal Goyal
// ESE 507 Project 3
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n
 module multi_$N\_$M1\_$M2\_$M3\_$T\_$A #(
    parameter N  = $N,
    parameter M1 = $M1,
    parameter M2 = $M2,
    parameter M3 = $M3,
    parameter T  = $T,
    parameter A  = $A
 ) (
 	input clk, 
	input reset, 

	input signed [T-1:0] s_data_in_x, 
	input s_valid_x, 
	output logic s_ready_x,

	output logic signed [T-1:0] m_data_out_y,
	output logic m_valid_y, 
	input m_ready_y
 ); ";

 for (my $ii = 1; $ii <= 3; $ii++) {
	 print $topWrapper "\n
	 logic [T-1:0] s_data_in_x_$ii;
	 logic         s_valid_x_$ii;
	 logic         s_ready_x_$ii;
	 logic [T-1:0] m_data_out_y_$ii;
	 logic         m_valid_y_$ii;
	 logic         m_ready_y_$ii;";
 }

 print $topWrapper "\n
 // Making internal connections between different layers
 assign s_data_in_x_1 = s_data_in_x;
 assign s_valid_x_1   = s_valid_x;
 assign s_ready_x     = s_ready_x_1;

 assign s_data_in_x_2 = m_data_out_y_1;
 assign s_valid_x_2   = m_valid_y_1;
 assign m_ready_y_1   = s_ready_x_2;

 assign s_data_in_x_3 = m_data_out_y_2;
 assign s_valid_x_3   = m_valid_y_2;
 assign m_ready_y_2   = s_ready_x_3;

 assign m_data_out_y  = m_data_out_y_3;
 assign m_valid_y     = m_valid_y_3;
 assign m_ready_y_3   = m_ready_y;

 $top_module_layer1 # (.N($N1), .M($M1), .P($P1), .T($T)) cnn_layer1_inst (
    .clk              (clk),
    .reset            (reset),
    .s_data_in_x      (s_data_in_x_1),
    .s_valid_x        (s_valid_x_1),
    .s_ready_x        (s_ready_x_1),
    .m_data_out_y     (m_data_out_y_1),
    .m_valid_y        (m_valid_y_1),
    .m_ready_y        (m_ready_y_1)
 );

 $top_module_layer2 # (.N($N2), .M($M2), .P($P2), .T($T)) cnn_layer2_inst (
    .clk              (clk),
    .reset            (reset),
    .s_data_in_x      (s_data_in_x_2),
    .s_valid_x        (s_valid_x_2),
    .s_ready_x        (s_ready_x_2),
    .m_data_out_y     (m_data_out_y_2),
    .m_valid_y        (m_valid_y_2),
    .m_ready_y        (m_ready_y_2)
 );

 $top_module_layer3 # (.N($N3), .M($M3), .P($P3), .T($T)) cnn_layer3_inst (
    .clk              (clk),
    .reset            (reset),
    .s_data_in_x      (s_data_in_x_3),
    .s_valid_x        (s_valid_x_3),
    .s_ready_x        (s_ready_x_3),
    .m_data_out_y     (m_data_out_y_3),
    .m_valid_y        (m_valid_y_3),
    .m_ready_y        (m_ready_y_3)
 );

 endmodule";

 close $topWrapper;

