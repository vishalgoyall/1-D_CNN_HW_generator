
 // SV file containing ROM type memory storage for FMEM words, picked from constant file input to gen_cnn.pl script

 module fmem_ROM (
    input clk,
    input [1:0] addr,
    output logic [15:0] z
 );
 
  always_ff @(posedge clk) begin
 	case(addr)
		0	: z <= -16'd62;
		1	: z <= 16'd82;
		2	: z <= -16'd127;
		3	: z <= 16'd83;
	endcase
  end
 endmodule