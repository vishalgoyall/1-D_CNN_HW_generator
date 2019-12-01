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
 my $N             = $ARGV[0];
 my $M             = $ARGV[1];
 my $T             = $ARGV[2];
 my $P             = $ARGV[3];
 my $fileROM       = $ARGV[4];
 my $genSubModules = $ARGV[5]; # Set this to 1 if submodules like mac, y_buffer need to be created; 0 if they are already created, but just need to be instantiated
 my $topHier       = $ARGV[6];

# Open toplevel SV design file
 my $fileTop = "$topHier/conv_$N\_$M\_$T\_$P.sv";
 print "../$topHier\/conv_$N\_$M\_$T\_$P.sv\n";

 open(my $fhMain, '>', $fileTop) or die "$fileTop could not be created";  

 my $xSize   = ceil(log($N)/log(2));
 my $fSize   = ceil(log($M)/log(2));

# Start with Module declaration and logic definitions
print $fhMain "
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// Toplevel file to do 1D convolution for N=$N, M=$M, T=$T, P=$P 
// Authors: Prateek Jain and Vishal Goyal
// ESE 507 Project 3
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n
module conv_$N\_$M\_$T\_$P  
#(
  parameter ADDR_XRAM = $xSize, 
  parameter ADDR_ROM = $fSize, 
  parameter N = $N, 
  parameter M = $M, 
  parameter P = $P,
  parameter T = $T
)
(
	input clk, 
	input reset, 
	input signed [T-1:0] s_data_in_x, 
	input s_valid_x, 
	output logic s_ready_x,
	output logic signed [T-1:0] m_data_out_y,
	output logic m_valid_y, 
	input m_ready_y
);

 logic [P-1:0]  m_ready_y_int;
 logic [P-1:0]  m_valid_y_int;
 logic [P-1:0]  conv_done_int;
 logic [P-1:0]  load_xaddr_int;
 logic [P-1:0]  load_faddr_int;
 logic [P-1:0]  en_xaddr_incr;
 logic [P-1:0]  en_faddr_incr_int;
 logic [P-1:0]  en_accum;
 logic [P-1:0]  reset_accum;
 logic          en_faddr_incr;
 logic          load_faddr;

 ";

# generate ROM file 
genROM($fileROM, $fhMain);

# generate memory control module for XRAM
genCtrlMemWrite($fhMain);

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
genXRAM($fhMain);

# generate output control module
genCtrlConvOutput($fhMain);

# generate MAC unit
genMAC($fhMain);

# generate y buffer unit
genYBuf($fhMain);

# generate serialiser to send data from y_buffers
genSerialiser($fhMain);

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
 my $fileROM = $_[0];  # ROM file should be 1st Argument
 my $fhMain  = $_[1];  # Top level design file handle should be 2nd Argument
 
 my $designFile = "$topHier/fmem_ROM_$N\_$M.sv";  # output RTL file paths
 print "../$topHier\/fmem_ROM_$N\_$M.sv\n";
 my $rowCnt = 0;
 
 open(my $fhi, '<', $fileROM) or die "$fileROM could not be opened";         #create input file handle
 open(my $fho, '>', $designFile) or die "$designFile could not be created";  #create output file
 
 #start printing module
 print $fho "
 // SV file containing ROM type memory storage for FMEM words, picked from constant file input to gen_cnn.pl script\n
 module fmem_ROM_$N\_$M #(parameter ADDR_ROM = 6, parameter WORD_SIZE = 8) (
    input clk,
    input [ADDR_ROM-1:0] addr,
    output logic [WORD_SIZE-1:0] z
 );
 
  always_ff @(posedge clk) begin
 	case(addr)\n";
 
 # for loop to print all ROM words	
 while (my $row = <$fhi>) {
 	chomp $row;
	if ($row =~ m/-/) {
	$row =~ s/^-//;
 	print $fho "		$rowCnt	: z <= -WORD_SIZE\'($row);\n";
        } else { 
 	print $fho "		$rowCnt	: z <= WORD_SIZE\'($row);\n";
        }
 	$rowCnt++;
 }

 #condition to check whether constant file had sufficient number of ROM words or not 
 if($rowCnt < $fSize) {
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
 
 logic [ADDR_ROM-1:0] fmem_addr;
 logic [T-1:0] fmem_data;
 logic fmem_reset;
 logic conv_done;

 //Reset generation. 
 //Conv_done is a one cycle pulse generated after convolution is complete
 assign fmem_reset = reset || conv_done;

 always_ff @ (posedge clk) begin
    if (fmem_reset == 1)
       fmem_addr <= 'b0;
    else begin
       if (load_faddr)
          fmem_addr <= 'b0;
       else if (en_faddr_incr) begin
          fmem_addr <= fmem_addr + 1;
          if (fmem_addr == M)
             fmem_addr <= 'b0;
       end
    end
 end

 fmem_ROM_$N\_$M #(.ADDR_ROM(ADDR_ROM), .WORD_SIZE(T)) fmem_inst (
 	.clk  (clk),
	.addr (fmem_addr),
	.z    (fmem_data)
 );\n";
}


#---------------------------------------------------
# Subroutine to generate control module for memory
#---------------------------------------------------
sub genCtrlMemWrite {

 my $fhMain   = $_[0]; 

 my $designFile = "$topHier/ctrl_mem_write.sv";  
 if ($genSubModules == 1) {
    print "../$topHier\/ctrl_mem_write.sv\n";  
    open(my $fho, '>', $designFile) or die "$designFile could not be created";  

    #print module
    print $fho "
 //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 // 1. Generate control signals to load XMEMs with input data from Master
 // 2. Follow AXI protocol and generate READY signal
 //++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 module ctrl_mem_write #(parameter N = 32, parameter ADDR_XRAM = 6) 
 (
         input clk,  
         input reset,
         input s_valid,
         output logic  s_ready,
         output logic [ADDR_XRAM-1:0] mem_addr,
         output logic  mem_wr_en
 );
 
 //Block to generate s_ready signal and mem_addr 
 always_ff @(posedge clk) begin
 	if (reset == 1'b1) begin  //with reset, restart the memory writing from address 0
 		s_ready  <= 1'b1;
 		mem_addr <= 0;
 	end
 	else begin
 		if (mem_wr_en == 1'b1 && mem_addr == unsigned'(N-1))
 		       s_ready <= 1'b0;
 
 	        if (mem_wr_en == 1'b1 && mem_addr == unsigned'(N-1))
 			mem_addr <= 0;
 	        else if (mem_wr_en == 1'b1)  
 		       mem_addr <= mem_addr + 1;	 
 	end
 end
 
 assign mem_wr_en = s_valid & s_ready; 
 
 endmodule";

  close $fho;
 }

 #print instantiation
 print $fhMain "\n
 //++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 // Control Module to write data from Master to XMEMs using AXI

  logic xmem_reset;
  logic [ADDR_XRAM-1:0] xmem_waddr;
  logic xmem_wr_en;

  assign xmem_reset = reset || conv_done;

 //ctrl module instantiation
  ctrl_mem_write #(.ADDR_XRAM(ADDR_XRAM), .N(N)) ctrl_xmem_write_inst (
	  .clk               (clk),  
	  .reset             (xmem_reset),
	  .s_valid           (s_valid_x),
	  .s_ready           (s_ready_x),
	  .mem_addr          (xmem_waddr),
	  .mem_wr_en         (xmem_wr_en)
  );

  assign xmem_full = ~s_ready_x;\n";

}

#---------------------------------------------------
# Subroutine to generate XMEM RAM
#---------------------------------------------------
sub genXRAM {
 
 my $fhMain   = $_[0]; 
 
 my $designFile = "$topHier/memory.sv";  
 if ($genSubModules == 1) {
 print "../$topHier\/memory.sv\n";  
 open(my $fho, '>', $designFile) or die "$designFile could not be created";  
 
 
 #print module
 print $fho "//Module to work as RAM\n
 module memory (clk, data_in, data_out, addr, wr_en);
  parameter WIDTH = 8; parameter LOGSIZE = 6; parameter SIZE = 32;
  input [WIDTH-1:0] data_in;
  input [LOGSIZE-1:0] addr;
  input	clk, wr_en;
  output logic [WIDTH-1:0] data_out;
  
  logic [SIZE-1:0][WIDTH-1:0] mem;
  
  always_ff @(posedge clk) begin
   data_out <= mem[addr];
   if (wr_en)
      mem[addr] <= data_in;
   end
 endmodule";

 close $fho;

 }
 
 #print instantiation
 my $instCnt = 0;
 print $fhMain "\n
 //++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 // XMEMs instantiation. One XMEM per MAC unit.

 logic [ADDR_XRAM-1:0] xmem_addr_vector    [P-1:0];
 logic [ADDR_XRAM-1:0] xmem_raddr_vector   [P-1:0];
 logic [T-1:0]         xmem_data_out_vector[P-1:0];
 logic [ADDR_XRAM-1:0] load_xaddr_val      [P-1:0];

 genvar i;
 generate for (i=0; i<P; i++) begin : xmem

   always_ff @ (posedge clk) begin
      if (reset == 1 || conv_done == 1) begin
         xmem_raddr_vector[i] <= i; // loading i-th location as the default of i-th MAC unit's x-mem
      end else begin
         if (load_xaddr_int[i] == 1'b1) begin
            xmem_raddr_vector[i] <= (load_xaddr_val[i] * P) + i;
         end else if (en_xaddr_incr[i]) begin
	    if (xmem_raddr_vector[i] == N-1)
	       xmem_raddr_vector[i] <= 'b0;
	    else
               xmem_raddr_vector[i] <= xmem_raddr_vector[i] + 1;
         end 
      end
   end

   assign xmem_addr_vector[i] = (conv_start) ? xmem_raddr_vector[i] : xmem_waddr;
   memory #(.WIDTH(T), .SIZE(N),  .LOGSIZE(ADDR_XRAM)) xmem_inst (
     .clk        (clk),
     .data_in    (s_data_in_x),
     .data_out   (xmem_data_out_vector[i]),
     .addr       (xmem_addr_vector[i]),
     .wr_en      (xmem_wr_en)
   );
 end
 endgenerate\n";

}

#-----------------------------------------------------
# Subroutine to MAC unit
#-----------------------------------------------------   
sub genMAC
{
 my $fhMain = $_[0];

 my $designFile = "$topHier/mac.sv";  # output RTL file paths
 if ($genSubModules == 1) {
 open(my $fho, '>', $designFile) or die "$designFile could not be created";
 print "../$topHier\/mac.sv\n";

 #print module
 print $fho "
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// MAC Unit (Contains one multiplier and accumulator)
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

 module mac #(parameter WORD_SIZE = 8)
 (
 	input  clk,
 	input  reset,
 	input  en_mult_reg,
 	input  en_adder_reg,
 	input  signed [WORD_SIZE-1:0] fmem_data,
 	input  signed [WORD_SIZE-1:0] xmem_data,
 	output signed [WORD_SIZE-1:0] data_out
 
 );

   logic signed [2*WORD_SIZE-1:0] x_mult_f;
   localparam logic signed [WORD_SIZE-1:0] min_negative_val = {1<<WORD_SIZE-1};
   localparam logic signed [WORD_SIZE-1:0] max_positive_val = ~min_negative_val;
   logic signed [WORD_SIZE-1:0] x_mult_f_reg;
   logic signed [WORD_SIZE:0] adder_in;
   logic signed [WORD_SIZE-1:0] adder_reg;

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
 
   // Adding relu logic
   assign data_out = (adder_reg[\$left(adder_reg)]) ? signed'('b0) : adder_reg;
   
endmodule"; 

 close $fho;

}

 # print instantiation
   print $fhMain "\n
 //++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 // MAC Instantitaion
 
 logic signed [T-1:0] mac_dout_vector [P-1:0];
 logic [P-1:0] en_mac_vector;
 logic [P-1:0] reset_mac;

 assign en_mac_vector = en_accum;

 genvar j;
 generate for(j = 0; j< P; j++) begin : mac_block

   assign reset_mac[j] = reset || reset_accum[j];

   mac #(.WORD_SIZE(T)) mac_inst (
       .clk          (clk),
       .reset        (reset_mac[j]),
       .xmem_data    (xmem_data_out_vector[j]),
       .fmem_data    (fmem_data),
       .en_mult_reg  (conv_start),
       .en_adder_reg (en_mac_vector[j]),
       .data_out     (mac_dout_vector[j])
   );
 end
 endgenerate\n";

}

#-----------------------------------------------------
# Subroutine to generate conv output control module
#-----------------------------------------------------   
sub genCtrlConvOutput
{
 my $fhMain = $_[0];

 my $designFile = "$topHier/ctrl_conv_output.sv";
 if ($genSubModules == 1) {
 open(my $fho, '>', $designFile) or die "$designFile could not be created";
 print "../$topHier\/ctrl_conv_output.sv\n";

 print $fho "

//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// Control Module to 
// 1. generate signals required to fetch data from memories
// 2. generate signals to control MAC operations
// 3. generate valid signal for AXI interface
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

module ctrl_conv_output #(parameter ADDR_ROM = 5, parameter ADDR_XRAM = 6, parameter N = 32, parameter M = 8, parameter P = 1)(
        input clk,            
        input reset,           
        input conv_start,     
        input m_ready_y,       
        input [ADDR_ROM-1:0] fmem_addr,       
        output logic conv_done,       
        output logic load_xaddr,    
        output logic en_xaddr_incr, 
        output logic load_faddr,   
        output logic en_faddr_incr, 
        output logic reset_accum,  
        output logic en_accum,        
        output logic m_valid_y,       
        output logic [ADDR_XRAM-1: 0] load_xaddr_val
);

logic [ADDR_XRAM-1:0] cnt_conv;
logic m_pre_pre_valid_y, conv_start_accum, m_pre_valid_y;

logic [ADDR_XRAM-1:0] num_mac_runs;

// to keep track of number of times each MAC unit should be run
// In case, N-M+1 is divisible by P, it will be equal to the quotient
// Otherwise, it will be quotient+1, to take care of remainder y[n] components
assign num_mac_runs = (unsigned'((N-M+1) % P) == 0) ? (unsigned'((N-M+1)/P)) : (unsigned'((N-M+1)/P)) + 1;

//Generate Control Signals for Address counters in memories 
always_comb begin
    if (conv_start == 1'b1) begin   //if conv has not started then no action required
	if (m_ready_y == 1'b1 && m_valid_y == 1'b1) begin //when data transaction is done at output and new computation is required
		load_xaddr         = 1'b1;       //load xaddr counter for next conv calculation
		load_faddr         = 1'b1;       //load faddr counter for next conv calculation
		load_xaddr_val     = cnt_conv;   //load xaddr counter with the starting address of next set to be done
		en_xaddr_incr      = 1'b0;       //pause counter from being incremented
		en_faddr_incr      = 1'b0;       //pause counter from being incremented
	end
	else if (m_pre_pre_valid_y == 1'b1) begin
         	load_xaddr         = 1'b0;       
		load_faddr         = 1'b0;       
		load_xaddr_val     = cnt_conv;   //dont care
		en_xaddr_incr      = 1'b0;       //pause counter from being incremented
		en_faddr_incr      = 1'b0;       //pause counter from being incremented
	end
	else begin
		load_xaddr         = 1'b0;       
		load_faddr         = 1'b0;       
		load_xaddr_val     = cnt_conv;   //dont care
		en_xaddr_incr      = 1'b1;       //pause counter from being incremented
		en_faddr_incr      = 1'b1;       //pause counter from being incremented
	end
    end
    else begin
	load_xaddr         = 1'b0;       
	load_faddr         = 1'b0;       
	load_xaddr_val     = 'b0;   
	en_xaddr_incr      = 1'b0;  
	en_faddr_incr      = 1'b0; 
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
		else if (fmem_addr == unsigned'(M-1) && conv_start == 1'b1)  //assert when 1 accumulation away from final result
			m_pre_pre_valid_y <= 1'b1;

		if (conv_done == 1'b1)   //reset after completion of convolution
                        cnt_conv <= 0;
		else if (m_pre_pre_valid_y == 1'b1 && m_pre_valid_y == 1'b0) //detect only for rise edge of pre-valid, require to be stable before loading xaddr
			cnt_conv <= cnt_conv + 1;

		if (cnt_conv > (num_mac_runs-1) && m_valid_y == 1'b1 && m_ready_y == 1'b1)  //end of convolution
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

 close $fho;

}

# insantiate it inside the main module
 print $fhMain "\n
 //++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 // output convolution control module instantitaion

 // Control Module for Convulation and AXI on output with master
 genvar k;
 generate for (k=0; k<P; k++) begin : ctrl_conv_output_block
    ctrl_conv_output #(.ADDR_ROM(ADDR_ROM), .ADDR_XRAM(ADDR_XRAM), .N(N), .M(M), .P(P)) ctrl_conv_output_inst (
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
  assign load_faddr = |load_faddr_int;

 ";

}

#-----------------------------------------------------
# Subroutine to generate Y buffers for each y[n] component
#-----------------------------------------------------   
sub genYBuf
{
 my $fhMain = $_[0];

 my $designFile = "$topHier/y_buffer.sv";
 if ($genSubModules == 1) {
 open(my $fho, '>', $designFile) or die "$designFile could not be created";
 print "../$topHier\/y_buffer.sv\n";

 print $fho "
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// Master Slave pair: to buffer y[n] components in case of parallel MAC operations
//
module y_buffer #(
	parameter T = 8, parameter P = 1
) (
	input clk,
	input reset,
	input conv_output_done,
	input [P-1:0] s_valid_in,
	input signed [T-1:0] s_data_in [P-1:0],
	output logic [P-1:0] s_ready_out,

	input [P-1:0] m_ready_in,
	output logic signed [T-1:0] m_data_out [P-1:0],
	output logic [P-1:0] m_valid_out

);

  logic m_valid_out_int;
  // to check if any of the outputs is still pending
  assign m_valid_out_int = |m_valid_out; 

  genvar i;
  generate for (i=0; i <P; i++) begin : y_buffer_label

  // if there is any previous output which is not read yet,
  // and there is a new request, pull the ready down
     assign s_ready_out[i] = s_valid_in[i] == 1 && m_valid_out_int == 0 && conv_output_done == 0;

  // generating output valid and data
     always_ff @ (posedge clk) begin
        if (reset == 1 || conv_output_done == 1) begin
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

 close $fho;

}


# insantiate it inside the main module
 print $fhMain "\n
 //++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 // Y_buffer instantiation

 // Signals to/from y_buffers from/to serialiser
 logic signed [T-1:0] m_data_out_y_ser[P-1:0];
 logic [P-1:0]  m_ready_y_ser;
 logic [P-1:0]  m_valid_y_ser;
 logic conv_output_done;

    y_buffer #(.T(T), .P(P)) y_buffer_inst_0 (
	  .clk	            (clk),
	  .reset            (reset),
	  .conv_output_done (conv_output_done),
	  .s_data_in        (mac_dout_vector),
	  .s_valid_in       (m_valid_y_int),
	  .m_ready_in       (m_ready_y_ser),
	  .s_ready_out      (m_ready_y_int),
	  .m_data_out       (m_data_out_y_ser),
	  .m_valid_out      (m_valid_y_ser)
     );

 ";
}

#-----------------------------------------------------
# Subroutine to generate serialise outputs from different MAC units' y_buffers to a single AXI stream
#-----------------------------------------------------   
sub genSerialiser
{
  my $fhMain = $_[0];

# insantiate it inside the main module
 print $fhMain "
 //++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 // Adding serialiser logic to serialise outputs from multiple y_buffers to single output AXI interface

  logic [ADDR_XRAM-1:0] y_offset;

  always_comb begin
     m_ready_y_ser = 'b0;
     m_data_out_y  = m_data_out_y_ser[y_offset % P];
     m_valid_y     = m_valid_y_ser[y_offset % P];
     m_ready_y_ser[y_offset % P] = m_ready_y;
  end

  always_ff @ (posedge clk) begin
     if (reset == 1) begin
        y_offset <= 'b0;
	conv_output_done <= 'b0;
     end else begin
	if (conv_output_done == 'b1)
	   conv_output_done <= 'b0;
        else if (m_valid_y == 1'b1 && m_ready_y == 1'b1) begin
	   if (y_offset == N - M) begin // Once N-M+1 y[n] components have been received,
	      y_offset <= 'b0;		  // reset offset to 0
	      conv_output_done <= 'b1;    // and assert done signal
	   end else begin
	      y_offset <= y_offset + 1;
	   end
	end
     end
  end
  ";
}

