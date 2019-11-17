//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// ESE 507 : Project 2 
// Authors : Prateek Jain and Vishal Goyal
// Purpose : 
// 1. Generate control signals to load memory with input data from Master
// 2. Follow AXI protocol and generate READY signal
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
module ctrl_mem_write #(parameter MEM_ADDR_WIDTH = 3, parameter MEM_SIZE = 8) (
        input                             clk,  
        input                             reset,
        input                             s_valid,
	input                             ext_load_addr,
	input        [MEM_ADDR_WIDTH-1:0] ext_load_addr_val,
	input                             ext_incr_addr,
	input                             en_ext_ctrl,
        output logic                      s_ready,
        output logic [MEM_ADDR_WIDTH-1:0] mem_addr,
        output logic                      mem_wr_en
);

//Block to generate s_ready signal and mem_addr 
always_ff @(posedge clk) begin
	if (reset == 1'b1) begin  //with reset, restart the memory writing from address 0
		s_ready  <= 1'b1;
		mem_addr <= 0;
	end
	else begin
		if (mem_wr_en == 1'b1 && mem_addr == unsigned'(MEM_SIZE - 1)) //if data is written in last memory address, then pull down s_ready along with write
		       s_ready <= 1'b0;

		if (en_ext_ctrl == 1'b0) begin   //if external rd ctrl required for memory address
	                if (mem_wr_en == 1'b1 && mem_addr == unsigned'(MEM_SIZE - 1)) //if data is written in last memory address, reset addr to 0
		        	mem_addr <= 0;
	                else if (mem_wr_en == 1'b1)  //else if wr_en is asserted, keep on incrementing the address to point to next mem location
		               mem_addr <= mem_addr + 1;	 
		end
		else begin
			if (ext_load_addr == 1'b1)   //load with approprate mem address
				mem_addr <= ext_load_addr_val; 
			else if (ext_incr_addr == 1'b1)  //incr mem address
				mem_addr <= mem_addr + 1;
		end
	end
end

assign mem_wr_en = s_valid & s_ready; //wr_en is combo logic of ready and valid

endmodule



