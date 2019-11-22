module tb_conv_16_4_16_1();

    parameter T = 16;
    parameter NUMINPUTVALS = 10000;
    parameter NUMOUTPUTVALS = 8125;
    parameter INFILENAME = "tb_conv_16_4_16_1.in";
    parameter EXPFILENAME = "tb_conv_16_4_16_1.exp";

    logic clk, s_valid_x, s_ready_x, m_valid_y, m_ready_y, reset;
    logic  [T-1:0] s_data_in_x;
    logic signed [T-1:0] m_data_out_y;

    logic signed [T-1:0] inValues [NUMINPUTVALS-1:0];
    logic signed [T-1:0] expValues [NUMOUTPUTVALS-1:0];
    logic s;

    initial clk=0;
    always #5 clk = ~clk;
    
    conv_16_4_16_1 dut(clk, reset, s_data_in_x, s_valid_x, s_ready_x, m_data_out_y, m_valid_y, m_ready_y);

    logic rb, rb2;
    always begin
        @(posedge clk);
        #1;
        s=std::randomize(rb, rb2);
    end

    logic [31:0] j;

    always @* begin
        if (s_valid_x == 1)
            s_data_in_x = inValues[j];
        else
            s_data_in_x = 'x;
    end

    always @* begin
        if ((j>=0) && (j<NUMINPUTVALS) && (rb==1'b1))
            s_valid_x=1;
        else
            s_valid_x=0;
    end

    always @(posedge clk) begin
        if (s_valid_x && s_ready_x)
            j <= #1 j+1;
    end
  
    logic [31:0] i;
    always @* begin
        if ((i>=0) && (i<NUMOUTPUTVALS) && (rb2==1'b1))
            m_ready_y = 1;
        else
            m_ready_y = 0;
    end

    integer errors = 0;

    always @(posedge clk) begin
        if (m_ready_y && m_valid_y) begin
            if (m_data_out_y !== expValues[i]) begin
                $display($time,,"ERROR: y[%d] = %x; expected value = %x", i, m_data_out_y, expValues[i]);
                errors = errors+1;
            end
            i=i+1; 
        end 
    end

    ////////////////////////////////////////////////////////////////////////////////

    initial begin
      $readmemb(INFILENAME, inValues);
      $readmemb(EXPFILENAME, expValues);
      
        j=0; i=0;

        // Before first clock edge, initialize
        m_ready_y = 0; 
        reset = 0;
    
        // reset
        @(posedge clk); #1; reset = 1; 
        @(posedge clk); #1; reset = 0; 

        wait(i==NUMOUTPUTVALS);
        $display("Simulated %d outputs. Found %d errors.", NUMOUTPUTVALS, errors);
        $finish;
    end


endmodule
