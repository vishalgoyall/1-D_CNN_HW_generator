
 // SV file containing ROM type memory storage for FMEM words, picked from constant file input to gen_cnn.pl script

 module fmem_ROM (
    input clk,
    input [3:0] addr,
    output logic [10:0] z
 );
 
  always_ff @(posedge clk) begin
 	case(addr)
		0	: z <= 11'd21;
		1	: z <= -11'd8;
		2	: z <= 11'd11;
		3	: z <= -11'd21;
		4	: z <= 11'd1;
		5	: z <= -11'd19;
		6	: z <= -11'd30;
		7	: z <= 11'd15;
		8	: z <= 11'd20;
	endcase
  end
 endmodule