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

# Command line arguments
 my $N       = $ARGV[0];
 my $M       = $ARGV[1];
 my $T       = $ARGV[2];
 my $P       = $ARGV[3];
 my $fileROM = $ARGV[4];

# Open toplevel SV design file
 my $fileTop = "rtl_files_$N\_$M\_$T\_$P/conv_$N\_$M\_$T\_$P.sv";
 print "../rtl_files_$N\_$M\_$T\_$P\/conv_$N\_$M\_$T\_$P.sv\n";

 open(my $fhMain, '>', $fileTop) or die "$fileTop could not be created";  

 my $xSize   = ceil(log($N)/log(2))-1;
 my $fSize   = ceil(log($M)/log(2))-1;
 my $Tminus1 = $T-1;

# Start with Module declaration and logic definitions
print $fhMain "
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// Toplevel file to do 1D convolution for N=$N, M=$M, T=$T, P=$P 
// Authors: Prateek Jain and Vishal Goyal
// ESE 507 Project 3
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n
module conv_$N\_$M\_$T\_$P (
	input clk, 
	input reset, 
	input signed [$Tminus1:0] s_data_in_x, 
	input s_valid_x, 
	output logic s_ready_x,
	output logic signed [$Tminus1:0] m_data_out_y,
	output logic m_valid_y, 
	input m_ready_y
);";

# generate ROM file 
genROM($M, $fileROM, $fhMain, $T);

# generate memory control module for XRAM
genCtrlMemWrite($N, $xSize, $fhMain);

print $fhMain "
  logic conv_pre_start;

  //Accum flush out cycle
   always_ff @(posedge clk) begin
   	if (reset == 1'b1)
   		conv_pre_start <= 1'b0;
   	else 
   		conv_pre_start <= xmem_full;  //one cycle delay required to flush out X from memory during read start
    end
    assign conv_start = conv_pre_start && xmem_full; // F vector is coming from ROM, thus conv start depends only on X vector
";

# generate RAM file
genXRAM($T, $N, $fhMain, $P);

# TODO generate xmem read ctrl and MAC ctrl logic
genCtrlMAC($xSize,$fhMain,$P);

# TODO generate output control module

# generate MAC unit
genMAC($T, $fhMain);

print $fhMain "
endmodule";
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
 
 my $designFile = "rtl_files_$N\_$M\_$T\_$P/fmem_ROM.sv";  # output RTL file paths
 print "../rtl_files_$N\_$M\_$T\_$P\/fmem_ROM.sv\n";
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
	if ($row =~ m/-/) {
	$row =~ s/^-//;
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
 print $fhMain "\n
 //++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 // FMEM ROM instantitation
 
 logic [@{[$addrROM-1]}:0] fmem_addr;
 logic [@{[$T-1]}:0] fmem_data;

 fmem_ROM fmem_inst (
 	.clk  (clk),
	.addr (fmem_addr),
	.z    (fmem_data)
 );\n";
}


#---------------------------------------------------
# Subroutine to generate control module for memory
#---------------------------------------------------
sub genCtrlMemWrite {

 my $memWords  = $_[0];
 my $memSize = $_[1];
 my $fhMain   = $_[2]; 

 my $designFile = "rtl_files_$N\_$M\_$T\_$P/ctrl_mem_write.sv";  
 print "../rtl_files_$N\_$M\_$T\_$P\/ctrl_mem_write.sv\n";  
 open(my $fho, '>', $designFile) or die "$designFile could not be created";  

 #print module
 print $fho "
 //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 // 1. Generate control signals to load XMEMs with input data from Master
 // 2. Follow AXI protocol and generate READY signal
 //++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 module ctrl_mem_write (
         input clk,  
         input reset,
         input s_valid,
         output logic  s_ready,
         output logic [$memSize:0] mem_addr,
         output logic  mem_wr_en
 );
 
 //Block to generate s_ready signal and mem_addr 
 always_ff @(posedge clk) begin
 	if (reset == 1'b1) begin  //with reset, restart the memory writing from address 0
 		s_ready  <= 1'b1;
 		mem_addr <= 0;
 	end
 	else begin
 		if (mem_wr_en == 1'b1 && mem_addr == unsigned'(@{[$memWords - 1]}))
 		       s_ready <= 1'b0;
 
 	        if (mem_wr_en == 1'b1 && mem_addr == unsigned'(@{[$memWords - 1]}))
 			mem_addr <= 0;
 	        else if (mem_wr_en == 1'b1)  
 		       mem_addr <= mem_addr + 1;	 
 	end
 end
 
 assign mem_wr_en = s_valid & s_ready; 
 
 endmodule";

 #print instantiation
 print $fhMain "\n
 //++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 // Control Module to write data from Master to XMEMs using AXI

  logic xmem_reset;
  logic [$memSize:0] xmem_waddr;
  logic xmem_wr_en;
  logic conv_done; //TODO correct location in code

  assign xmem_reset = reset || conv_done;

 //ctrl module instantiation
  ctrl_mem_write ctrl_xmem_write_inst (
	  .clk               (clk),  
	  .reset             (xmem_reset),
	  .s_valid           (s_valid_x),
	  .s_ready           (s_ready_x),
	  .mem_addr          (xmem_waddr),
	  .mem_wr_en         (xmem_wr_en)
  );

  assign xmem_full = ~s_ready_x;\n";

  close $fho;
}

#---------------------------------------------------
# Subroutine to generate XMEM RAM
#---------------------------------------------------
sub genXRAM {
 
 my $wordWidth_minus1 = $_[0]-1;
 my $memSize_minus1   = $_[1]-1;
 my $fhMain   = $_[2]; 
 my $P        = $_[3]; 
 
 my $memAddr = ceil(log($memSize_minus1+1)/log(2))-1;
 
 my $designFile = "rtl_files_$N\_$M\_$T\_$P/memory.sv";  
 print "../rtl_files_$N\_$M\_$T\_$P\/memory.sv\n";  
 open(my $fho, '>', $designFile) or die "$designFile could not be created";  
 
 
 #print module
 print $fho "//Module to work as RAM\n
 module memory(clk, data_in, data_out, addr, wr_en);
  input [$wordWidth_minus1:0] data_in;
  input [$memAddr:0] addr;
  input	clk, wr_en;
  output logic [$wordWidth_minus1:0] data_out;
  
  logic [$memSize_minus1:0][$wordWidth_minus1:0] mem;
  
  always_ff @(posedge clk) begin
   data_out <= mem[addr];
   if (wr_en)
      mem[addr] <= data_in;
   end
 endmodule";
 
 #print instantiation
 my $instCnt = 0;
 print $fhMain "\n
 //++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 // XMEMs instantiation. One XMEM per MAC unit.

 logic [$memAddr:0] xmem_addr_vector [@{[$P-1]}:0];
 logic [$memAddr:0] xmem_raddr_vector [@{[$P-1]}:0];
 logic [$wordWidth_minus1:0] xmem_data_out_vector[@{[$P-1]}:0];

 genvar i;
 generate for (i=0; i<$P; i++) begin : xmem
   assign xmem_addr_vector[i] = (conv_start) ? xmem_raddr_vector[i] : xmem_waddr; //TODO connect xmem_raddr_vector from mac_ctrl unit
   memory xmem_inst (
     .clk        (clk),
     .data_in    (s_data_in_x),
     .data_out   (xmem_data_out_vector[i]),
     .addr       (xmem_addr_vector[i]),
     .wr_en      (xmem_wr_en)
   );
 end
 endgenerate\n";

 close $fho;
}

#-----------------------------------------------------
# Subroutine to MAC unit
#-----------------------------------------------------   
sub genMAC
{
 my $DW_minus1 = $_[0]-1;
 my $fhMain = $_[1];

 my $designFile = "rtl_files_$N\_$M\_$T\_$P/mac.sv";  # output RTL file paths
 open(my $fho, '>', $designFile) or die "$designFile could not be created";
 print "../rtl_files_$N\_$M\_$T\_$P\/mac.sv\n";

 my $multWidth = 2*$_[0] - 1;

 #print module
 print $fho "
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// MAC Unit (Contains one multiplier and accumulator)
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

 module mac 
 (
 	input  clk,
 	input  reset,
 	input  en_mult_reg,
 	input  en_adder_reg,
 	input  signed [$DW_minus1:0] fmem_data,
 	input  signed [$DW_minus1:0] xmem_data,
 	output signed [$DW_minus1:0] data_out
 
 );

   logic signed [@{[2*$DW_minus1+1]}:0] x_mult_f;
   localparam logic signed [$DW_minus1:0] min_negative_val = {1<<$DW_minus1};
   localparam logic signed [$DW_minus1:0] max_positive_val = ~min_negative_val;
   logic signed [$DW_minus1:0] x_mult_f_reg;
   logic signed [$_[0]:0] adder_in;
   logic signed [$DW_minus1:0] adder_reg;

   //multiply
   assign x_mult_f = xmem_data*fmem_data;  

   //saturate and register 
   always @ (posedge clk) begin
	   if (reset == 1)
		   x_mult_f_reg <= 'b0;
	   else if (en_mult_reg)
		   x_mult_f_reg <= (x_mult_f > max_positive_val) ? max_positive_val : ((x_mult_f < min_negative_val) ? min_negative_val : x_mult_f);
   end

   //addition
   assign adder_in = adder_reg + x_mult_f_reg;

   // Using accumulator enable as adder register enable
   // Saturate and register
   always @ (posedge clk) begin
	   if (reset == 1)
		   adder_reg <= 'b0;
	   else if (en_adder_reg)
		   adder_reg <= (adder_in > max_positive_val) ? max_positive_val : ((adder_in < min_negative_val) ? min_negative_val : adder_in);
   end
 
   assign data_out = adder_reg;
   
endmodule"; 

 # print instantiation
   print $fhMain "\n
 //++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 // MAC Instantitaion
 
 logic reset_mac;
 logic signed [$DW_minus1:0] mac_dout_vector [@{[$P-1]}:0];
 logic [@{[$P-1]}:0] en_mac_vector;
 logic reset_accum;  //TODO connect properly

 assign reset_mac = reset || reset_accum;

 genvar j;
 generate for(j = 0; j< $P; j++) begin : mac_block
   mac mac_inst (
       .clk          (clk),
       .reset        (reset_mac),
       .xmem_data    (xmem_data_out_vector[j]),
       .fmem_data    (fmem_data),
       .en_mult_reg  (conv_start),
       .en_adder_reg (en_mac_vector[j]),
       .data_out     (mac_dout_vector[j])
   );
 end
 endgenerate\n";

 close $fho;
}

#-----------------------------------------------------
# Subroutine to MAC unit
#-----------------------------------------------------
sub genCtrlMAC {
 my $memSize = $_[0];
 my $fhMain  = $_[1];
 my $P       = $_[2];

 #my $designFile = "rtl_files_$N\_$M\_$T\_$P/ctrl_mac.sv";  # output RTL file paths
 #open(my $fho, '>', $designFile) or die "$designFile could not be created";
 #print "../rtl_files_$N\_$M\_$T\_$P\/ctrl_mac.sv\n";
 #close $fho;
 
 #TODO
}


