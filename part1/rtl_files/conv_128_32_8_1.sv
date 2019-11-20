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

logic xmem_full;
logic xmem_addr_wr_ctrl;
logic xmem_addr_rd_ctrl;
logic [X_MEM_ADDR_WIDTH-1:0] xmem_addr;
logic xmem_wr_en;
logic xmem_reset;
logic [X_MEM_ADDR_WIDTH-1:0] load_xaddr_val;
logic signed [T-1:0] xmem_data;

logic [F_MEM_ADDR_WIDTH-1 :0] fmem_addr;
logic fmem_reset;
logic signed [T-1:0] fmem_data;

logic conv_start, conv_pre_start;
logic conv_done;

logic signed [T-1:0] accum_in;
logic signed [T-1:0] accum_out;

logic load_xaddr; 
logic load_faddr; 
logic en_xaddr_incr; 
logic en_faddr_incr;
logic reset_accum; 
logic en_accum;

// signals for internal master slave at the output
logic m_valid_y_int;
logic m_ready_y_int;
logic [T-1:0] m_data_out_y_int;

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
		  if (load_faddr)
			  fmem_addr <= 'b0;
		  else if (en_faddr_incr) begin
			  fmem_addr <= fmem_addr + 1;
			  if (fmem_addr == M)
				  fmem_addr <= 'b0;
		  end
	  end
  end

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// F_MEM instantiation
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

  conv_128_32_8_1_f_rom fmem_inst (
          .clk        (clk),
          .z          (fmem_data),
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
	  .load_faddr      (load_faddr),
	  .en_xaddr_incr   (en_xaddr_incr),
	  .en_faddr_incr   (en_faddr_incr),
	  .load_xaddr_val  (load_xaddr_val),
	  .reset_accum     (reset_accum),
	  .en_accum        (en_accum),
	  .fmem_addr       (fmem_addr),
	  .m_ready_y       (m_ready_y_int),
	  .m_valid_y       (m_valid_y_int)
  );

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// MAC unit of design
// It uses signals coming from control convolution module to accumulate and reset
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   mac_unit #(.T(T)) mac_unit_inst_0 (
   	.clk		(clk),
	.reset		(reset),
	.reset_accum	(reset_accum),
	.xmem_data	(xmem_data),
	.fmem_data	(fmem_data),
	.en_mult_reg	(conv_start),
	.en_adder_reg	(en_accum),
	.accum_in	(accum_in)
   );

   always_ff @(posedge clk) begin
   	if (reset == 1'b1 || reset_accum == 1'b1) begin
   		accum_out <= 0;
   	end
   	else if (en_accum) begin
   		accum_out <= accum_in;
   	end
   end

  assign m_data_out_y_int = accum_in;   //send output data from accumulator output

  y_buffer #(.T(T)) y_buffer_inst_0 (
	  .clk		(clk),
	  .reset	(reset),
	  .s_data_in	(m_data_out_y_int),
	  .s_valid_in	(m_valid_y_int),
	  .s_ready_out	(m_ready_y_int),
	  .m_ready_in	(m_ready_y),
	  .m_data_out	(m_data_out_y),
	  .m_valid_out	(m_valid_y)
  );

endmodule

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// Master Slave pair: to buffer y[n] components in case of parallel MAC operations
//
module y_buffer #(
	parameter T = 8
) (
	input			clk,
	input			reset,
	input [T-1:0]		s_data_in,
	input			s_valid_in,
	output logic		s_ready_out,

	input			m_ready_in,
	output logic [T-1:0]	m_data_out,
	output logic		m_valid_out

);

  always_ff @ (posedge clk) begin
	  if (reset == 1) begin
		  m_valid_out <= 'b0;
		  m_data_out <= 'b0;
		  s_ready_out <= 'b1;
	  end else begin
		  if (m_valid_out == 1'b1 && m_ready_in == 1'b1) begin
			  m_valid_out <= 'b0;
			  s_ready_out <= 'b1;
		  end
		  if (s_valid_in == 'b1) begin
			  s_ready_out <= 'b0;
			  m_valid_out <= 'b1;
			  m_data_out <= s_data_in;
		  end
	  end
  end

endmodule


//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// MAC Unit (Contains one multiplier and accumulator)
//
module mac_unit #(
	parameter T = 8
) (
	input			clk,
	input			reset,
	input			reset_accum,
	input signed [T-1:0]	xmem_data,
	input signed [T-1:0]	fmem_data,

	input			en_mult_reg,
	input			en_adder_reg,

	output signed [T-1:0] 	accum_in

);

// multiply xmem data with f mem data
   logic signed [T+T-1:0] x_mult_f;
   logic signed [T-1:0] min_negative_val = {1<<(T-1)};
   logic signed [T-1:0] max_positive_val = ~min_negative_val;
   logic signed [T-1:0] x_mult_f_reg;

   assign x_mult_f = xmem_data*fmem_data;  

   // Checking if overflow; if not, assign a new value, else saturate
   always @ (posedge clk) begin
	   if (reset == 1 || reset_accum == 1'b1)
		   x_mult_f_reg <= 'b0;
	   else if (en_mult_reg)
		   x_mult_f_reg <= (x_mult_f > max_positive_val) ? max_positive_val : ((x_mult_f < min_negative_val) ? min_negative_val : x_mult_f);
   end

   logic signed [T:0] adder_in;
   logic signed [T-1:0] adder_reg;

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

   assign accum_in = (adder_reg[$left(adder_reg)]) ? 'b0 : adder_reg;

endmodule


//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//FMEM ROM Implementation (place holder; generated RTL)
 module conv_128_32_8_1_f_rom(clk, addr, z);
   input clk;
   input [4:0] addr;
   output logic signed [7:0] z;
   always_ff @(posedge clk) begin
      case(addr)
        0: z <= -8'd1;
        1: z <= -8'd5;
        2: z <= -8'd6;
        3: z <= -8'd3;
        4: z <= -8'd6;
        5: z <= 8'd8;
        6: z <= -8'd8;
        7: z <= 8'd1;
        8: z <= -8'd10;
        9: z <= 8'd15;
        10: z <= -8'd11;
        11: z <= 8'd7;
        12: z <= -8'd11;
        13: z <= 8'd8;
        14: z <= -8'd9;
        15: z <= -8'd3;
        16: z <= 8'd4;
        17: z <= -8'd15;
        18: z <= -8'd9;
        19: z <= 8'd9;
        20: z <= -8'd9;
        21: z <= 8'd14;
        22: z <= -8'd11;
        23: z <= -8'd1;
        24: z <= 8'd2;
        25: z <= -8'd8;
        26: z <= 8'd5;
        27: z <= 8'd11;
        28: z <= -8'd5;
        29: z <= -8'd5;
        30: z <= 8'd5;
        31: z <= 8'd11;
      endcase
   end
endmodule

