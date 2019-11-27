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

# generate output control module
genCtrlConvOutput($T, $fhMain, $xSize, $fSize);

# generate MAC unit
genMAC($T, $fhMain);

# generate y buffer unit
genYBuf($T, $fhMain);

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
  logic conv_done;

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
 
 logic signed [$DW_minus1:0] mac_dout_vector [@{[$P-1]}:0];
 logic [@{[$P-1]}:0] en_mac_vector;
 logic [@{[$P-1]}:0] reset_mac;

 genvar j;
 generate for(j = 0; j< $P; j++) begin : mac_block

   assign reset_mac[j] = reset || reset_accum[j];

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

sub genCtrlConvOutput
{
 my $DW_minus1 = $_[0]-1;
 my $fhMain = $_[1];
 my $FMemSize_minus1 = $_[2];
 my $XMemSize_minus1 = $_[3];

 my $designFile = "rtl_files_$N\_$M\_$T\_$P/ctrl_conv_output.sv";
 open(my $fho, '>', $designFile) or die "$designFile could not be created";
 print "../rtl_files_$N\_$M\_$T\_$P\/ctrl_conv_output.sv\n";

 print $fho "

//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// Control Module to 
// 1. generate signals required to fetch data from memories
// 2. generate signals to control MAC operations
// 3. generate valid signal for AXI interface
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

module ctrl_conv_output (
        input clk,            
        input reset,           
        input conv_start,     
        input m_ready_y,       
        input [$FMemSize_minus1:0] fmem_addr,       
        output logic conv_done,       
        output logic load_xaddr,    
        output logic en_xaddr_incr, 
        output logic load_faddr,   
        output logic en_faddr_incr, 
        output logic reset_accum,  
        output logic en_accum,        
        output logic m_valid_y,       
        output logic [$XMemSize_minus1: 0] load_xaddr_val
);

logic [$XMemSize_minus1:0] cnt_conv;
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

# insantiate it inside the main module
 print $fhMain "\n
 //++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 // output convolution control module instantitaion

 logic [@{[$P-1]}:0]  m_ready_y_int;
 logic [@{[$P-1]}:0]  m_valid_y_int;
 logic [@{[$P-1]}:0]  conv_done_int;
 logic [@{[$P-1]}:0]  load_xaddr_int;
 logic [@{[$P-1]}:0]  load_faddr_int;
 logic [@{[$P-1]}:0]  en_xaddr_incr;
 logic [@{[$P-1]}:0]  en_faddr_incr_int;
 logic [@{[$P-1]}:0]  en_accum;
 logic [@{[$P-1]}:0]  reset_accum;
 logic en_faddr_incr;
 logic [$XMemSize_minus1:0]  load_xaddr_val [@{[$P-1]}:0];

 // Control Module for Convulation and AXI on output with master
 genvar k;
 generate for (k=0; k<$P; k++) begin : ctrl_conv_output_block
    ctrl_conv_output ctrl_conv_output_inst (
          // inputs
          .clk             (clk),
	  .reset           (reset),
	  .conv_start      (conv_start),
	  .m_ready_y       (m_ready_y_int[k]),
	  .fmem_addr       (fmem_addr),
	  // outputs
	  .conv_done       (conv_done_int[k]),
	  .load_xaddr      (load_xaddr_int[k]),
	  .load_faddr      (load_faddr_int[k]),
	  .en_xaddr_incr   (en_xaddr_incr[k]),
	  .en_faddr_incr   (en_faddr_incr_int[k]),
	  .load_xaddr_val  (load_xaddr_val[k]),
	  .reset_accum     (reset_accum[k]),
	  .en_accum        (en_accum[k]),
	  .m_valid_y       (m_valid_y_int[k])
     );
  end
  endgenerate

  assign en_faddr_incr = |en_faddr_incr_int;
  assign conv_done = |conv_done_int;

 ";

}

sub genYBuf
{
 my $DW_minus1 = $_[0]-1;
 my $fhMain = $_[1];

 my $designFile = "rtl_files_$N\_$M\_$T\_$P/y_buffer.sv";
 open(my $fho, '>', $designFile) or die "$designFile could not be created";
 print "../rtl_files_$N\_$M\_$T\_$P\/y_buffer.sv\n";

 print $fho "
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// Master Slave pair: to buffer y[n] components in case of parallel MAC operations
//
module y_buffer #(
	parameter T = 8
) (
	input			clk,
	input			reset,
	input [T-1:0]		s_data_in [@{[$P-1]}:0],
	input [@{[$P-1]}:0]	s_valid_in,
	output logic [@{[$P-1]}:0] s_ready_out,

	input [@{[$P-1]}:0]	m_ready_in,
	output logic [T-1:0]	m_data_out [@{[$P-1]}:0],
	output logic [@{[$P-1]}:0] m_valid_out

);

  logic m_valid_out_int = |m_valid_out;

  genvar i;
  generate for (i=0; i <$P; i++) begin : y_buffer
  // if there is any previous output which is not read yet,
  // and there is a new request, pull the ready down
     assign s_ready_out[i] = s_valid_in[i] == 1 && m_valid_out_int == 0;

     always_ff @ (posedge clk) begin
        if (reset == 1) begin
           m_valid_out[i] <= 'b0;
           m_data_out[i]  <= 'b0;
        end else begin
           if (m_valid_out[i] == 1'b1 && m_ready_in[i] == 1'b1) begin
              m_valid_out[i] <= 'b0;
	   end else if (s_valid_in[i] && s_ready_out[i]) begin
              m_valid_out[i] <= 'b1;
	      m_data_out[i]  <= s_data_in[i];
           end
        end
     end

  end
  endgenerate

endmodule";

# insantiate it inside the main module
 print $fhMain "\n

 logic [$DW_minus1:0] m_data_out_y_rr[@{[$P-1]}:0];
 logic [@{[$P-1]}:0]  m_ready_y_rr;
 logic [@{[$P-1]}:0]  m_valid_y_rr;

 //++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 // Y_buffer instantiation
 genvar l;
 generate for (l=0; l<$P; l++) begin : y_buffer_block
    y_buffer #(.T($T)) y_buffer_inst_0 (
          // inputs
	  .clk		(clk),
	  .reset	(reset),
	  .s_data_in	(mac_dout_vector[l]),
	  .s_valid_in	(m_valid_y_int[l]),
	  .m_ready_in	(m_ready_y_rr[l]),
	  // outputs
	  .s_ready_out	(m_ready_y_int[l]),
	  .m_data_out	(m_data_out_y_rr[l]),
	  .m_valid_out	(m_valid_y_rr[l])
     );
  end
  endgenerate

 ";

}

sub genSerialiser
{
  my $fhMain = $_[1];
  my $ySize  = $_[2]; # same as x size, as it cannot be larger than that

  print $fhMain "\n
  logic [$ySize:0] y_offset;

  always_comb begin
     m_ready_y_rr = 'b0;
     m_data_out_y = m_data_out_y_rr[y_offset%$P];
     m_valid_y    = m_valid_y_rr[y_offset%$P];
     m_ready_y_rr[y_offset%$P] = m_ready_y;
  end

  always_ff @ (posedge clk) begin
     if (reset == 1) begin
        y_offset <= 'b0;
     end else begin
        if (m_valid_y == 1'b1 && m_ready_y == 1'b1) begin
	   if (y_offset == $N - $M)
	      y_offset <= 'b0;
	   else
	      y_offset <= y_offset + 1;
	end
     end
  end
  ";
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

