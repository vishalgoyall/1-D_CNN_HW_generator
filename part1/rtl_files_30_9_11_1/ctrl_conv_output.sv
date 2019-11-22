
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// Control Module to 
// 1. generate signals required to fetch data from memories
// 2. generate signals to control MAC operations
// 3. generate valid signal for AXI interface
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

module ctrl_conv_output (
        input clk,            
        input reset,           
        input conv_start,     
        input m_ready_y,       
        input [3:0] fmem_addr,       
        output logic conv_done,       
        output logic load_xaddr,    
        output logic en_xaddr_incr, 
        output logic load_faddr,   
        output logic en_faddr_incr, 
        output logic reset_accum,  
        output logic en_accum,        
        output logic m_valid_y,       
        output logic [4: 0] load_xaddr_val
);

logic [4:0] cnt_conv;
logic m_pre_pre_valid_y, conv_start_accum, m_pre_valid_y;

//Generate Control Signals for Address counters in memories 
always_comb begin
    if (conv_start == 1'b1) begin   //if conv has not started then no action required
	if (m_ready_y == 1'b1 && m_valid_y == 1'b1) begin //when data transaction is done at output and new computation is required
		load_xaddr     = 1'b1;       //load xaddr counter for next conv calculation
		load_faddr     = 1'b1;       //load faddr counter for next conv calculation
		load_xaddr_val = cnt_conv;   //load xaddr counter with the starting address of next set to be done
		en_xaddr_incr  = 1'b0;       //pause counter from being incremented
		en_faddr_incr  = 1'b0;       //pause counter from being incremented
	end
	else if (m_pre_pre_valid_y == 1'b1) begin
         	load_xaddr     = 1'b0;       
		load_faddr     = 1'b0;       
		load_xaddr_val = cnt_conv;   //dont care
		en_xaddr_incr  = 1'b0;       //pause counter from being incremented
		en_faddr_incr  = 1'b0;       //pause counter from being incremented
	end
	else begin
		load_xaddr     = 1'b0;       
		load_faddr     = 1'b0;       
		load_xaddr_val = cnt_conv;   //dont care
		en_xaddr_incr  = 1'b1;       //pause counter from being incremented
		en_faddr_incr  = 1'b1;       //pause counter from being incremented
	end
    end
    else begin
	load_xaddr     = 1'b0;       
	load_faddr     = 1'b0;       
	load_xaddr_val = 0;   
	en_xaddr_incr  = 1'b0;  
	en_faddr_incr  = 1'b0; 
    end
end


//Generate control signals for accumulator in MAC engine
always_comb begin 
	if ((m_valid_y == 1'b1 && m_ready_y == 1'b1) || (conv_start_accum == 1'b0)) begin  //clear accum before starting new convolution
		reset_accum = 1'b1;
		en_accum    = 1'b0;
	end
	else if (m_valid_y == 1'b1 && conv_start_accum == 1'b1) begin  //hold accum till m_valid is set, m_valid deasserts with m_ready
		reset_accum = 1'b0;
		en_accum    = 1'b0;
	end
	else begin
		reset_accum = 1'b0;
		en_accum    = 1'b1;
	end
end

//Valid, Pre Valid, Convolution Done and Convolution tracker implementation
always_ff @(posedge clk) begin
	if (reset == 1'b1) begin
		m_pre_valid_y     <= 1'b0;  //dummy signal to delay valid by one cycle
		m_valid_y         <= 1'b0;  //valid signal for AXI
		cnt_conv          <= 0;     //convolution tracker
		conv_start_accum  <= 1'b0;  //accum should start once cycle after first read from memory is done
		m_pre_pre_valid_y <= 1'b0;  //required to hold mem address with valid signal assertion
		conv_done         <= 1'b0;  //final dine signal
	end
	else begin
		if (m_ready_y == 1'b1 && m_valid_y == 1'b1)  //reset when ready is recieved and valid was asserted
		       m_pre_valid_y <= 1'b0;	
		else if (m_pre_pre_valid_y == 1'b1 && conv_start == 1'b1)  //assert with final accumulation; used to generate valid one cycle after this 
			m_pre_valid_y <= 1'b1;

		if (m_ready_y == 1'b1 && m_valid_y == 1'b1)  //reset when ready is recieved and valid was asserted
		       m_valid_y <= 1'b0;	
	       else if (m_pre_valid_y == 1'b1 && conv_start == 1'b1) // assert when pre_valid is 1
		       m_valid_y <= 1'b1;

		if (m_ready_y == 1'b1 && m_pre_pre_valid_y == 1'b1 && m_valid_y == 1'b1)   //reset when ready is recieved
			m_pre_pre_valid_y <= 1'b0;
		else if (fmem_addr == unsigned'(8) && conv_start == 1'b1)  //assert when 1 accumulation away from final result
			m_pre_pre_valid_y <= 1'b1;

		if (conv_done == 1'b1)   //reset after completion of convolution
                        cnt_conv <= 0;
		else if (m_pre_pre_valid_y == 1'b1 && m_pre_valid_y == 1'b0) //detect only for rise edge of pre-valid, require to be stable before loading xaddr
			cnt_conv <= cnt_conv + 1;

		if (cnt_conv == unsigned'(22) && m_valid_y == 1'b1 && m_ready_y == 1'b1)  //end of convolution
		       conv_done <= 1'b1;
	        else
		       conv_done <= 1'b0;  //just generate a pulse

		if (m_ready_y == 1'b1 && m_valid_y == 1'b1)  //reset when ready is recieved and valid was asserted, to clear the accumulator
			conv_start_accum <= 1'b0;
		else
			conv_start_accum <= conv_start;


	end
end

endmodule