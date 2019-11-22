
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// 1. Generate control signals to load memory with input data from Master
// 2. Follow AXI protocol and generate READY signal
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
module ctrl_mem_write (
        input clk,  
        input reset,
        input s_valid,
	input ext_load_addr,
	input [5:0] ext_load_addr_val,
	input ext_incr_addr,
	input en_ext_ctrl,
        output logic  s_ready,
        output logic [5:0] mem_addr,
        output logic  mem_wr_en
);

//Block to generate s_ready signal and mem_addr 
always_ff @(posedge clk) begin
	if (reset == 1'b1) begin  //with reset, restart the memory writing from address 0
		s_ready  <= 1'b1;
		mem_addr <= 0;
	end
	else begin
		if (mem_wr_en == 1'b1 && mem_addr == unsigned'(42))
		       s_ready <= 1'b0;

		if (en_ext_ctrl == 1'b0) begin   
	                if (mem_wr_en == 1'b1 && mem_addr == unsigned'(42))
		        	mem_addr <= 0;
	                else if (mem_wr_en == 1'b1)  
		               mem_addr <= mem_addr + 1;	 
		end
		else begin
			if (ext_load_addr == 1'b1)   
				mem_addr <= ext_load_addr_val; 
			else if (ext_incr_addr == 1'b1)  
				mem_addr <= mem_addr + 1;
		end
	end
end

assign mem_wr_en = s_valid & s_ready; 

endmodule