module dither_time(clk,rst,d_n_input,duty_high,duty_low,count);
	input clk,rst;
	input [6:0]d_n_input;
	output reg duty_high,duty_low;
	output reg[6:0]count;
	always@(posedge clk or posedge rst)begin
		if(rst)begin
		    	count<=0;
		end else if(count==7'b111111)begin
			count<=0;
		end else begin
			count<=count+7'd1;
		end
	end
	//comparator high
	always@(posedge clk or posedge rst)begin
		if(rst)begin
			duty_high<=0;
		end else begin
			if(count==0)begin
				duty_high<=1;
			end
			if(count>=d_n_input)begin
				duty_high<=0;
			end
		end
	end
	
	//comparator low
	always@(posedge clk or posedge rst)begin
		if(rst)begin
			duty_low<=0;
		end else begin
			if(count==0)begin
				duty_low<=0;
			end
			
			if(count>=7'd112)begin
				duty_low<=0;
			end

			if(count >=(d_n_input+7'd10))begin
				duty_low<=1;
			end
		end
	end
endmodule
