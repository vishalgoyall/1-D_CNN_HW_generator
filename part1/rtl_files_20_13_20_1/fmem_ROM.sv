
 // SV file containing ROM type memory storage for FMEM words, picked from constant file input to gen_cnn.pl script

 module fmem_ROM (
    input clk,
    input [3:0] addr,
    output logic [19:0] z
 );
 
  always_ff @(posedge clk) begin
 	case(addr)
		0	: z <= 20'd406;
		1	: z <= 20'd22;
		2	: z <= -20'd125;
		3	: z <= -20'd463;
		4	: z <= -20'd215;
		5	: z <= -20'd403;
		6	: z <= 20'd8;
		7	: z <= 20'd672;
		8	: z <= -20'd785;
		9	: z <= -20'd589;
		10	: z <= 20'd333;
		11	: z <= -20'd18;
		12	: z <= -20'd288;
	endcase
  end
 endmodule