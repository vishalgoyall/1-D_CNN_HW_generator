
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// Toplevel file to do 1D convolution for N=16, M=4, T=16, P=1 
// Authors: Prateek Jain and Vishal Goyal
// ESE 507 Project 3
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

module conv_16_4_16_1 (
	input clk, 
	input reset, 
	input signed [15:0] s_data_in_x, 
	input s_valid_x, 
	output logic s_ready_x,
	output logic signed [15:0] m_data_out_y,
	output logic m_valid_y, 
	input m_ready_y
);

logic xmem_full;
logic xmem_addr_wr_ctrl;
logic xmem_addr_rd_ctrl;
logic [3:0] xmem_addr;
logic xmem_wr_en;
logic xmem_reset;
logic [3:0] load_xaddr_val;
logic signed [15:0] xmem_data;

logic [1:0] fmem_addr;
logic fmem_reset;
logic signed [15:0] fmem_data;

logic conv_start, conv_pre_start;
logic conv_done;

logic signed [15:0] accum_in;
logic signed [15:0] accum_out;

logic load_xaddr; 
logic load_faddr; 
logic en_xaddr_incr; 
logic en_faddr_incr;
logic reset_accum; 
logic en_accum;

// signals for internal master slave at the output
logic m_valid_y_int;
logic m_ready_y_int;
logic [15:0] m_data_out_y_int;

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// Control Module to write data from Master into  X MEM using AXI
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  //Reset generation. 
  //Conv_done is a one cycle pulse generated after convulation is complete
  assign xmem_reset = reset || conv_done;

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
  );

// Instantiate XMEM instance
 memory xmem_inst (
   .clk        (clk),
   .data_in    (s_data_in_x),
   .data_out   (xmem_data),
   .addr       (xmem_addr),
   .wr_en      (xmem_wr_en)
 );

// Instantiation for FMEM ROM
 fmem_ROM fmem_inst (
 	.clk  (clk),
	.addr (fmem_addr),
	.z    (fmem_data)
 );

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
			  if (fmem_addr == 4)
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
  );


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
 );

endmodule