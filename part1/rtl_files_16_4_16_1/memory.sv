//Module to work as RAM

 module memory(clk, data_in, data_out, addr, wr_en);
  input [15:0] data_in;
  input [3:0] addr;
  input	clk, wr_en;
  output logic [15:0] data_out;
  
  logic [15:0][15:0] mem;
  
  always_ff @(posedge clk) begin
   data_out <= mem[addr];
   if (wr_en)
      mem[addr] <= data_in;
   end
 endmodule