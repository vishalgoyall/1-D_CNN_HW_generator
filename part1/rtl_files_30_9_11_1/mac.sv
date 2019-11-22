
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
 	input  signed [10:0] fmem_data,
 	input  signed [10:0] xmem_data,
 	output signed [10:0] accum_in
 
 );

  // multiply xmem data with f mem data
   logic signed [21:0] x_mult_f;
   localparam logic signed [10:0] min_negative_val = {1<<10};
   localparam logic signed [10:0] max_positive_val = ~min_negative_val;
   logic signed [10:0] x_mult_f_reg;

   assign x_mult_f = xmem_data*fmem_data;  

   // Checking if overflow; if not, assign a new value, else saturate
   always @ (posedge clk) begin
	   if (reset == 1 || reset_accum == 1'b1)
		   x_mult_f_reg <= 'b0;
	   else if (en_mult_reg)
		   x_mult_f_reg <= (x_mult_f > max_positive_val) ? max_positive_val : ((x_mult_f < min_negative_val) ? min_negative_val : x_mult_f);
   end

   logic signed [11:0] adder_in;
   logic signed [10:0] adder_reg;

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
 
   assign accum_in = (adder_reg[$left(adder_reg)]) ? signed'('b0) : adder_reg;

endmodule