# Optimization code
# Inputs are in order N M1 M2 M3 T A
use strict;
use warnings;

 my $N        = $ARGV[0];
 my $M1       = $ARGV[1];
 my $M2       = $ARGV[2];
 my $M3       = $ARGV[3];
 my $T        = $ARGV[4];
 my $A        = $ARGV[5];

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
	 print "\nAll possible solutions for P1, P2 and P3";
	 print "\nP1 = @P1_vals";
	 print "\nP2 = @P2_vals";
	 print "\nP3 = @P3_vals\n";

	 #find best possible solution
	 my $bestOptim;
	 my $bestOptimIndex;
	 for my $i (0..(scalar(@P1_vals)-1)) {
		 my $Layer1_cycles = (3+$M1)*($L1/$P1_vals[$i]);
		 my $Layer2_cycles = (3+$M2)*($L2/$P2_vals[$i]);
		 my $Layer3_cycles = (3+$M3)*($L3/$P3_vals[$i]);
		 my $currCycles = $Layer1_cycles + $Layer2_cycles + $Layer3_cycles;
		 print "**$currCycles cycles (convolution only) if we use P1 P2 P3 at index $i\n";
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
	 
	 print "\n--> Best possible combination is for index $bestOptimIndex : P1 = $P1; P2 = $P2; P3 = $P3\n\n";

 } else {
	 print "Minimum expected value of A is 3 as this is a 3 layer CNN system"
 }



