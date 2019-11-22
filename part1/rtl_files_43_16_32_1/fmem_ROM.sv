
 // SV file containing ROM type memory storage for FMEM words, picked from constant file input to gen_cnn.pl script

 module fmem_ROM (
    input clk,
    input [3:0] addr,
    output logic [31:0] z
 );
 
  always_ff @(posedge clk) begin
 	case(addr)
		0	: z <= -32'd37226;
		1	: z <= -32'd31499;
		2	: z <= -32'd19346;
		3	: z <= -32'd27059;
		4	: z <= -32'd4213;
		5	: z <= -32'd12043;
		6	: z <= -32'd50397;
		7	: z <= 32'd35919;
		8	: z <= -32'd17676;
		9	: z <= -32'd28346;
		10	: z <= -32'd41084;
		11	: z <= -32'd10487;
		12	: z <= -32'd52878;
		13	: z <= -32'd24752;
		14	: z <= 32'd2831;
		15	: z <= 32'd677;
	endcase
  end
 endmodule