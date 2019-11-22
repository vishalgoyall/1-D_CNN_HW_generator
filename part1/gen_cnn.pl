##########################################################################################################
# Perl file to generate design for Project 3 : 1D convolution neural network
# Part 1
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
);

logic xmem_full;
logic xmem_addr_wr_ctrl;
logic xmem_addr_rd_ctrl;
logic [$xSize:0] xmem_addr;
logic xmem_wr_en;
logic xmem_reset;
logic [$xSize:0] load_xaddr_val;
logic signed [$Tminus1:0] xmem_data;

logic [$fSize:0] fmem_addr;
logic fmem_reset;
logic signed [$Tminus1:0] fmem_data;

logic conv_start, conv_pre_start;
logic conv_done;

logic signed [$Tminus1:0] accum_in;
logic signed [$Tminus1:0] accum_out;

logic load_xaddr; 
logic load_faddr; 
logic en_xaddr_incr; 
logic en_faddr_incr;
logic reset_accum; 
logic en_accum;

// signals for internal master slave at the output
logic m_valid_y_int;
logic m_ready_y_int;
logic [$Tminus1:0] m_data_out_y_int;

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// Control Module to write data from Master into  X MEM using AXI
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  //Reset generation. 
  //Conv_done is a one cycle pulse generated after convulation is complete
  assign xmem_reset = reset || conv_done;";

# generate memory control module for XRAM
genCtrlXmem($N, $xSize, $fhMain);

# generate RAM file
genXRAM($T, $N, $fhMain);

# generate ROM file 
genROM($M, $fileROM, $fhMain, $T);

print $fhMain "
  assign xmem_full = ~s_ready_x;
  
//Conv_done is a one cycle pulse generated after convolution is complete
  assign fmem_reset = reset || conv_done;   
   
// controlling f ROM read address
  always_ff @ (posedge clk) begin
	  if (fmem_reset == 1)
		  fmem_addr <= 'b0;
	  else begin
		  if (load_faddr)
			  fmem_addr <= 'b0;
		  else if (en_faddr_incr) begin
			  fmem_addr <= fmem_addr + 1;
			  if (fmem_addr == $M)
				  fmem_addr <= 'b0;
		  end
	  end
  end

  //Accum flush out cycle
   always_ff @(posedge clk) begin
   	if (reset == 1'b1)
   		conv_pre_start <= 1'b0;
   	else 
   		conv_pre_start <= xmem_full;  //one cycle delay required to flush out X from memory during read start
    end
    assign conv_start = conv_pre_start && xmem_full; // F vector is coming from ROM, thus conv start depends only on X vector
";

# generate output control module
genCtrlout($N, $M, $xSize, $fSize, $fhMain);

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
 
 my $designFile = "rtl_files_$N\_$M\_$T\_$P/memory.sv";  
 print "../rtl_files_$N\_$M\_$T\_$P\/memory.sv\n";  
 open(my $fho, '>', $designFile) or die "$designFile could not be created";  
 
 my $ramAddr = ceil(log($ramSize+1)/log(2))-1;
 
 #print module
 print $fho "//Module to work as RAM\n
 module memory(clk, data_in, data_out, addr, wr_en);
  input [$wordSize:0] data_in;
  input [$ramAddr:0] addr;
  input	clk, wr_en;
  output logic [$wordSize:0] data_out;
  
  logic [$ramSize:0][$wordSize:0] mem;
  
  always_ff @(posedge clk) begin
   data_out <= mem[addr];
   if (wr_en)
      mem[addr] <= data_in;
   end
 endmodule";
 
 #print instantiation
 print $fhMain "\n// Instantiate XMEM instance
 memory xmem_inst (
   .clk        (clk),
   .data_in    (s_data_in_x),
   .data_out   (xmem_data),
   .addr       (xmem_addr),
   .wr_en      (xmem_wr_en)
 );\n";


}

#---------------------------------------------------
# Subroutine to generate control module for memory
#---------------------------------------------------
sub genCtrlXmem {

 my $memSize  = $_[0];
 my $wordSize = $_[1];
 my $fhMain   = $_[2]; 

 my $designFile = "rtl_files_$N\_$M\_$T\_$P/ctrl_mem_write.sv";  
 print "../rtl_files_$N\_$M\_$T\_$P\/ctrl_mem_write.sv\n";  
 open(my $fho, '>', $designFile) or die "$designFile could not be created";  

 #print module
 print $fho "
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// 1. Generate control signals to load memory with input data from Master
// 2. Follow AXI protocol and generate READY signal
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
module ctrl_mem_write (
        input clk,  
        input reset,
        input s_valid,
	input ext_load_addr,
	input [$wordSize:0] ext_load_addr_val,
	input ext_incr_addr,
	input en_ext_ctrl,
        output logic  s_ready,
        output logic [$wordSize:0] mem_addr,
        output logic  mem_wr_en
);

//Block to generate s_ready signal and mem_addr 
always_ff @(posedge clk) begin
	if (reset == 1'b1) begin  //with reset, restart the memory writing from address 0
		s_ready  <= 1'b1;
		mem_addr <= 0;
	end
	else begin
		if (mem_wr_en == 1'b1 && mem_addr == unsigned'(@{[$memSize - 1]}))
		       s_ready <= 1'b0;

		if (en_ext_ctrl == 1'b0) begin   
	                if (mem_wr_en == 1'b1 && mem_addr == unsigned'(@{[$memSize - 1]}))
		        	mem_addr <= 0;
	                else if (mem_wr_en == 1'b1)  
		               mem_addr <= mem_addr + 1;	 
		end
		else begin
			if (ext_load_addr == 1'b1)   
				mem_addr <= ext_load_addr_val; 
			else if (ext_incr_addr == 1'b1)  
				mem_addr <= mem_addr + 1;
		end
	end
end

assign mem_wr_en = s_valid & s_ready; 

endmodule";

 #print instantiation
 print $fhMain "\n
 //ctrl module instantiation
  ctrl_mem_write ctrl_xmem_write_inst (
	  .clk               (clk),  
	  .reset             (xmem_reset),
	  .s_valid           (s_valid_x),
	  .s_ready           (s_ready_x),
	  .mem_addr          (xmem_addr),
	  .en_ext_ctrl       (conv_start),
	  .ext_load_addr     (load_xaddr),
	  .ext_load_addr_val (load_xaddr_val),
	  .ext_incr_addr     (en_xaddr_incr),
	  .mem_wr_en         (xmem_wr_en)
  );\n";

  close $fho;
}

#---------------------------------------------------
# Subroutine to generate control module for output
#---------------------------------------------------
sub genCtrlout {

 my $N      = $_[0];
 my $M      = $_[1];
 my $xSize  = $_[2];
 my $fSize  = $_[3];
 my $fhMain = $_[4]; 

 my $designFile = "rtl_files_$N\_$M\_$T\_$P/ctrl_conv_output.sv";  
 print "../rtl_files_$N\_$M\_$T\_$P\/ctrl_conv_output.sv\n";  
 open(my $fho, '>', $designFile) or die "$designFile could not be created";

 #print module
 print $fho "
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// Control Module to 
// 1. generate signals required to fetch data from memories
// 2. generate signals to control MAC operations
// 3. generate valid signal for AXI interface
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

module ctrl_conv_output (
        input clk,            
        input reset,           
        input conv_start,     
        input m_ready_y,       
        input [$fSize:0] fmem_addr,       
        output logic conv_done,       
        output logic load_xaddr,    
        output logic en_xaddr_incr, 
        output logic load_faddr,   
        output logic en_faddr_incr, 
        output logic reset_accum,  
        output logic en_accum,        
        output logic m_valid_y,       
        output logic [$xSize: 0] load_xaddr_val
);

logic [$xSize:0] cnt_conv;
logic m_pre_pre_valid_y, conv_start_accum, m_pre_valid_y;

//Generate Control Signals for Address counters in memories 
always_comb begin
    if (conv_start == 1'b1) begin   //if conv has not started then no action required
	if (m_ready_y == 1'b1 && m_valid_y == 1'b1) begin //when data transaction is done at output and new computation is required
		load_xaddr     = 1'b1;       //load xaddr counter for next conv calculation
		load_faddr     = 1'b1;       //load faddr counter for next conv calculation
		load_xaddr_val = cnt_conv;   //load xaddr counter with the starting address of next set to be done
		en_xaddr_incr  = 1'b0;       //pause counter from being incremented
		en_faddr_incr  = 1'b0;       //pause counter from being incremented
	end
	else if (m_pre_pre_valid_y == 1'b1) begin
         	load_xaddr     = 1'b0;       
		load_faddr     = 1'b0;       
		load_xaddr_val = cnt_conv;   //dont care
		en_xaddr_incr  = 1'b0;       //pause counter from being incremented
		en_faddr_incr  = 1'b0;       //pause counter from being incremented
	end
	else begin
		load_xaddr     = 1'b0;       
		load_faddr     = 1'b0;       
		load_xaddr_val = cnt_conv;   //dont care
		en_xaddr_incr  = 1'b1;       //pause counter from being incremented
		en_faddr_incr  = 1'b1;       //pause counter from being incremented
	end
    end
    else begin
	load_xaddr     = 1'b0;       
	load_faddr     = 1'b0;       
	load_xaddr_val = 0;   
	en_xaddr_incr  = 1'b0;  
	en_faddr_incr  = 1'b0; 
    end
end


//Generate control signals for accumulator in MAC engine
always_comb begin 
	if ((m_valid_y == 1'b1 && m_ready_y == 1'b1) || (conv_start_accum == 1'b0)) begin  //clear accum before starting new convolution
		reset_accum = 1'b1;
		en_accum    = 1'b0;
	end
	else if (m_valid_y == 1'b1 && conv_start_accum == 1'b1) begin  //hold accum till m_valid is set, m_valid deasserts with m_ready
		reset_accum = 1'b0;
		en_accum    = 1'b0;
	end
	else begin
		reset_accum = 1'b0;
		en_accum    = 1'b1;
	end
end

//Valid, Pre Valid, Convolution Done and Convolution tracker implementation
always_ff @(posedge clk) begin
	if (reset == 1'b1) begin
		m_pre_valid_y     <= 1'b0;  //dummy signal to delay valid by one cycle
		m_valid_y         <= 1'b0;  //valid signal for AXI
		cnt_conv          <= 0;     //convolution tracker
		conv_start_accum  <= 1'b0;  //accum should start once cycle after first read from memory is done
		m_pre_pre_valid_y <= 1'b0;  //required to hold mem address with valid signal assertion
		conv_done         <= 1'b0;  //final dine signal
	end
	else begin
		if (m_ready_y == 1'b1 && m_valid_y == 1'b1)  //reset when ready is recieved and valid was asserted
		       m_pre_valid_y <= 1'b0;	
		else if (m_pre_pre_valid_y == 1'b1 && conv_start == 1'b1)  //assert with final accumulation; used to generate valid one cycle after this 
			m_pre_valid_y <= 1'b1;

		if (m_ready_y == 1'b1 && m_valid_y == 1'b1)  //reset when ready is recieved and valid was asserted
		       m_valid_y <= 1'b0;	
	       else if (m_pre_valid_y == 1'b1 && conv_start == 1'b1) // assert when pre_valid is 1
		       m_valid_y <= 1'b1;

		if (m_ready_y == 1'b1 && m_pre_pre_valid_y == 1'b1 && m_valid_y == 1'b1)   //reset when ready is recieved
			m_pre_pre_valid_y <= 1'b0;
		else if (fmem_addr == unsigned'(@{[$M - 1]}) && conv_start == 1'b1)  //assert when 1 accumulation away from final result
			m_pre_pre_valid_y <= 1'b1;

		if (conv_done == 1'b1)   //reset after completion of convolution
                        cnt_conv <= 0;
		else if (m_pre_pre_valid_y == 1'b1 && m_pre_valid_y == 1'b0) //detect only for rise edge of pre-valid, require to be stable before loading xaddr
			cnt_conv <= cnt_conv + 1;

		if (cnt_conv == unsigned'(@{[$N - $M + 1]}) && m_valid_y == 1'b1 && m_ready_y == 1'b1)  //end of convolution
		       conv_done <= 1'b1;
	        else
		       conv_done <= 1'b0;  //just generate a pulse

		if (m_ready_y == 1'b1 && m_valid_y == 1'b1)  //reset when ready is recieved and valid was asserted, to clear the accumulator
			conv_start_accum <= 1'b0;
		else
			conv_start_accum <= conv_start;


	end
end

endmodule";


#print instantitation
print $fhMain "\n
// Control Module for Convulation and AXI on output with master
 ctrl_conv_output ctrl_conv_output_inst (
          .clk             (clk),
	  .reset           (reset),
	  .conv_start      (conv_start),
	  .conv_done       (conv_done),
	  .load_xaddr      (load_xaddr),
	  .load_faddr      (load_faddr),
	  .en_xaddr_incr   (en_xaddr_incr),
	  .en_faddr_incr   (en_faddr_incr),
	  .load_xaddr_val  (load_xaddr_val),
	  .reset_accum     (reset_accum),
	  .en_accum        (en_accum),
	  .fmem_addr       (fmem_addr),
	  .m_ready_y       (m_ready_y),
	  .m_valid_y       (m_valid_y)
  );\n";

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
//
 module mac 
 (
 	input  clk,
 	input  reset,
 	input  reset_accum,
 	input  en_mult_reg,
 	input  en_adder_reg,
 	input  signed [$DW_minus1:0] fmem_data,
 	input  signed [$DW_minus1:0] xmem_data,
 	output signed [$DW_minus1:0] accum_in
 
 );

  // multiply xmem data with f mem data
   logic signed [@{[2*$DW_minus1+1]}:0] x_mult_f;
   localparam logic signed [$DW_minus1:0] min_negative_val = {1<<$DW_minus1};
   localparam logic signed [$DW_minus1:0] max_positive_val = ~min_negative_val;
   logic signed [$DW_minus1:0] x_mult_f_reg;

   assign x_mult_f = xmem_data*fmem_data;  

   // Checking if overflow; if not, assign a new value, else saturate
   always @ (posedge clk) begin
	   if (reset == 1 || reset_accum == 1'b1)
		   x_mult_f_reg <= 'b0;
	   else if (en_mult_reg)
		   x_mult_f_reg <= (x_mult_f > max_positive_val) ? max_positive_val : ((x_mult_f < min_negative_val) ? min_negative_val : x_mult_f);
   end

   logic signed [$_[0]:0] adder_in;
   logic signed [$DW_minus1:0] adder_reg;

   assign adder_in = adder_reg + x_mult_f_reg;

   // Using accumulator enable as adder register enable
   // Checking if overflow; if not, assign a new value, else saturate
   always @ (posedge clk) begin
	   if (reset == 1 || reset_accum == 1'b1)
		   adder_reg <= 'b0;
	   else if (en_adder_reg)
		   adder_reg <= (adder_in > max_positive_val) ? max_positive_val : ((adder_in < min_negative_val) ? min_negative_val : adder_in);
		   //adder_reg <= adder_in;
   end
 
   assign accum_in = (adder_reg[\$left(adder_reg)]) ? signed'('b0) : adder_reg;

endmodule"; 

 # print instantiation
   print $fhMain "\n
 // MAC unit of design
 mac mac_unit_inst (
      .clk          (clk),
      .reset        (reset),
      .reset_accum  (reset_accum),
      .xmem_data    (xmem_data),
      .fmem_data    (fmem_data),
      .en_mult_reg  (conv_start),
      .en_adder_reg (en_accum),
      .accum_in     (m_data_out_y)
 );\n";

 close $fho;
} 
