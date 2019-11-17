//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// ESE 507 : Project 2 (Convolution)
// Authors : Prateek Jain and Vishal Goyal
// Description: This is the top level module for convolution of X (128) and F (32)
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

module conv_128_32_8_1 #(
	parameter int T = 8, 
	parameter int N = 128, 
	parameter int M = 32
) (
	input clk, 
	input reset, 
	input s_valid_x, 
	input m_ready_y,
	input signed [T-1:0] s_data_in_x, 
	output logic s_ready_x,
	output logic m_valid_y, 
	output logic signed [T-1:0] m_data_out_y
);

//logic and parameter declarations
localparam X_MEM_ADDR_WIDTH = $clog2(N);  //bus width for x mem addr
localparam F_MEM_ADDR_WIDTH = $clog2(M);  //bus width for f mem addr
localparam logic [F_MEM_ADDR_WIDTH-1:0] load_faddr_val = 0;

logic xmem_full;
logic xmem_addr_wr_ctrl;
logic xmem_addr_rd_ctrl;
logic [X_MEM_ADDR_WIDTH-1:0] xmem_addr;
logic xmem_wr_en;
logic xmem_reset;
logic [X_MEM_ADDR_WIDTH-1:0] load_xaddr_val;
logic signed [T-1:0] xmem_data;

logic [F_MEM_ADDR_WIDTH-1 :0] fmem_addr;
logic fmem_wr_en;
logic fmem_reset;
logic signed [T-1:0] fmem_data;

logic conv_start, conv_pre_start;
logic conv_done;

logic signed [T+T-1:0] x_mult_f;
logic signed [T-1:0] accum_in;
logic signed [T-1:0] accum_out;

logic load_xaddr; 
logic en_xaddr_incr; 
logic load_faddr; 
logic en_faddr_incr;
logic reset_accum; 
logic en_accum;


//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// Control Module to write data from Master into  X MEM using AXI
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  //Reset generation. 
  //Conv_done is a one cycle pulse generated after convulation is complete
  assign xmem_reset = reset || conv_done;   
  
  //ctrl module instantiation
  ctrl_mem_write #(.MEM_ADDR_WIDTH(X_MEM_ADDR_WIDTH), .MEM_SIZE(N)) ctrl_xmem_write_inst (
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

  assign xmem_full = ~s_ready_x;
  
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// X_MEM instantiation
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

  memory #(.WIDTH(T), .SIZE(N),  .LOGSIZE(X_MEM_ADDR_WIDTH)) xmem_inst (
          .clk        (clk),
          .data_in    (s_data_in_x),
          .data_out   (xmem_data),
          .addr       (xmem_addr),
          .wr_en      (xmem_wr_en)
   );

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  //Reset generation. 
  //Conv_done is a one cycle pulse generated after convolution is complete
  assign fmem_reset = reset || conv_done;   
   
  // controlling f ROM read address
  always_ff @ (posedge clk) begin
	  if (fmem_reset == 1)
		  fmem_addr <= 'b0;
	  else begin
		  if (ext_incr_addr) begin
			  fmem_addr <= fmem_addr + 1;
			  if (fmem_addr == M)
				  fmem_addr <= 'b0;
		  end
	  end
  end

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// F_MEM instantiation
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

  memory #(.WIDTH(T), .SIZE(M),  .LOGSIZE(F_MEM_ADDR_WIDTH)) fmem_inst (
          .clk        (clk),
          .data_out   (fmem_data),
          .addr       (fmem_addr)
   );

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// Control Module for Convulation and AXI on output with master
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 
 always_ff @(posedge clk) begin
	if (reset == 1'b1)
		conv_pre_start <= 1'b0;
	else 
		conv_pre_start <= xmem_full;  //one cycle delay required to flush out X from memory during read start
 end
 assign conv_start = conv_pre_start && xmem_full; // F vector is coming from ROM, thus conv start depends only on X vector

  ctrl_conv_output #(.F_MEM_SIZE(M), .X_MEM_SIZE(N), .X_MEM_ADDR_WIDTH(X_MEM_ADDR_WIDTH), .F_MEM_ADDR_WIDTH(F_MEM_ADDR_WIDTH))
  ctrl_conv_output_inst (
          .clk             (clk),
	  .reset           (reset),
	  .conv_start      (conv_start),
	  .conv_done       (conv_done),
	  .load_xaddr      (load_xaddr),
	  .en_xaddr_incr   (en_xaddr_incr),
	  .load_faddr      (load_faddr),
	  .en_faddr_incr   (en_faddr_incr),
	  .load_xaddr_val  (load_xaddr_val),
	  .reset_accum     (reset_accum),
	  .en_accum        (en_accum),
	  .fmem_addr       (fmem_addr),
	  .m_ready_y       (m_ready_y),
	  .m_valid_y       (m_valid_y)
  );

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// MAC unit of design
// It uses signals coming from control convolution module to accumulate and reset
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// multiply xmem data with f mem data
   assign x_mult_f = xmem_data*fmem_data;  

   logic [T-1:0] max_positive_val = {1'b0,T-1{1'b1}};
   logic [T-1:0] min_negative_val = {1'b1,T-1{1'b0}};

   logic signed [T-1:0] x_mult_f_reg;
   logic en_mult_reg;

   // Overflow condition: if greater than max positive value or lesser than min negative value
   logic mult_overflow = (((x_mult_f[$left(x_mult_f)] == 1'b0) && (|x_mult_f[($left(x_mult_f)-1):T-1])) || // if positive number and no other bit left of T-1 is high
	   		  ((x_mult_f[$left(x_mult_f)] == 1'b1) && (~&x_mult_f[($left(x_mult_f)-1):T-1]))); // if negative number and no other bit left of T-1 is low

   assign en_mult_reg = conv_start;
   // Checking if overflow; if not, assign a new value, else saturate
   always @ (posedge clk) begin
	   if (reset == 1)
		   x_mult_f_reg <= 'b0;
	   else if (en_mult_reg) // <TODO> make it more readable
		   x_mult_f_reg <= mult_overflow ? (x_mult_f[$left(x_mult_f)] ? min_negative_val : max_positive_val) : x_mult_f;
   end

   logic signed [T:0] adder_in
   logic signed [T-1:0] adder_reg;
   logic en_adder_reg;

   assign adder_in = adder_reg + x_mult_f_reg;
   logic adder_overflow = (((adder_in[$left(adder_in)] == 1'b0) && (|adder_in[($left(adder_in)-1):T-1])) || // if positive number and no other bit left of T-1 is high
	   		  ((adder_in[$left(adder_in)] == 1'b1) && (~&adder_in[($left(adder_in)-1):T-1]))); // if negative number and no other bit left of T-1 is low
   
   // Using accumulator enable as adder register enable
   assign en_adder_reg = en_accum;
   // Checking if overflow; if not, assign a new value, else saturate
   always @ (posedge clk) begin
	   if (reset == 1)
		   adder_reg <= 'b0;
	   else if (en_adder_reg)
		   adder_reg <= adder_overflow ? (adder_in[$left(adder_in)] ? min_negative_val : max_positive_val) : adder_in;
   end

   // Implement ReLU
   assign accum_in = (adder_reg[$left(adder_reg)]) ? T'b0 : adder_reg;

   always_ff @(posedge clk) begin
   	if (reset == 1'b1 || reset_accum == 1'b1) begin
   		accum_out <= 0;
   	end
   	else if (en_accum) begin
   		accum_out <= accum_in;
   	end
   end

  assign m_data_out_y = accum_out;   //send output data from accumulator output

endmodule

