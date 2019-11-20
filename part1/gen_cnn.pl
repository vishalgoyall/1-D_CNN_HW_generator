##########################################################################################################
# Perl file to generate design for Project 3 : 1D convolution neural network
# Part TODO
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

# Command line arguments
 my $N       = $ARGV[0];
 my $M       = $ARGV[1];
 my $T       = $ARGV[2];
 my $P       = $ARGV[3];
 my $fileROM = $ARGV[4];

# Open toplevel SV design file
 my $fileTop = "rtl_files/conv_$N\_$M\_$T\_$P.sv"; 
 open(my $fhMain, '>', $fileTop) or die "$fileTop could not be created";  

# generate ROM file 
genROM($M, $fileROM, $fhMain, $T);

# generate RAM file
genXRAM($T, $N, $fhMain);

#TODO put all stuff here

close $fhMain;


###############################################################
# SUBROUTINES
###############################################################

#-----------------------------------------------------
# Subroutine to generate ROM using constant file
#-----------------------------------------------------   
sub genROM 
{
 my $romSize = $_[0];  # ROM size should be 1st Argument
 my $fileROM = $_[1];  # ROM file should be 2nd Argument
 my $fhMain  = $_[2];  # Top level design file handle should be 3rd Argument
 my $wordSize = $_[3]; # Word Size as 4th Argument 
 
 my $designFile = "rtl_files/fmem_ROM.sv";  # output RTL file paths
 my $addrROM = ceil(log($romSize)/log(2));
 my $rowCnt = 0;
 
 open(my $fhi, '<', $fileROM) or die "$fileROM could not be opened";         #create input file handle
 open(my $fho, '>', $designFile) or die "$designFile could not be created";  #create output file
 
 #start printing module
 print $fho "
 // SV file containing ROM type memory storage for FMEM words, picked from constant file input to gen_cnn.pl script\n
 module fmem_ROM (
    input clk,
    input [@{[$addrROM-1]}:0] addr,
    output logic [@{[$T-1]}:0] z
 );
 
  always_ff @(posedge clk) begin
 	case(addr)\n";
 
 # for loop to print all ROM words	
 while (my $row = <$fhi>) {
 	chomp $row;
	if ($row =~ m/'-'/) {
 	print $fho "		$rowCnt	: z <= -$wordSize\'d$row;\n";
        } else { 
 	print $fho "		$rowCnt	: z <= $wordSize\'d$row;\n";
        }
 	$rowCnt++;
 }

 #condition to check whether constant file had sufficient number of ROM words or not 
 if($rowCnt < $romSize) {
 	die "ERROR !!\nNumber of constants in $fileROM is less than specified value of M";
 } else{
 	print $fho "	endcase
  end
 endmodule"; 
 }

 close $fhi;
 close $fho;

 #start printing module instantiation in toplevel file
 print $fhMain "\n// Instantiation for FMEM ROM
 fmem_ROM fmem_inst (
 	.clk  (clk),
	.addr (fmem_addr),
	.z    (fmem_data)
 );\n";
}

#---------------------------------------------------
# Subroutine to generate XMEM RAM
#---------------------------------------------------
sub genXRAM {
 my $wordSize = $_[0]-1;
 my $ramSize  = $_[1]-1;
 my $fhMain   = $_[2];  
 
 my $designFile = "rtl_files/memory.sv";  
 open(my $fho, '>', $designFile) or die "$designFile could not be created";  
 
 my $ramAddr = ceil(log($ramSize)/log(2));
 
 #print module
 print $fho "//Module to work as RAM\n
 module memory(clk, data_in, data_out, addr, wr_en);
  input [$wordSize:0]		data_in;
  input [$ramAddr:0]		addr;
  input			clk, wr_en;
  output logic [$wordSize:0]	data_out;
  
  logic [$ramSize:0][$wordSize:0] mem;
  
  always_ff @(posedge clk) begin
   data_out <= mem[addr];
   if (wr_en)
      mem[addr] <= data_in;
   end
 endmodule";
 
 #print instantiation
 print $fhMain "// Instantiate XMEM instance
 memory xmem_inst (
   .clk        (clk),
   .data_in    (s_data_in_x),
   .data_out   (xmem_data),
   .addr       (xmem_addr),
   .wr_en      (xmem_wr_en)
 );";


}

