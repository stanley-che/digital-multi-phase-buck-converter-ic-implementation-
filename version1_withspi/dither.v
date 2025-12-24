module dither(clk_in,rst,d_n_input,d_dith);
  input clk_in,rst;
  input wire [9:0] d_n_input;
  output wire [6:0]d_dith;
  reg [2:0]count;
  reg [7:0] dith_T[7:0];
  wire [7:0]dith_raw;
  reg dith_point;
  
  //initial table
  initial begin
      dith_T[3'b000]=8'b00000000;
      dith_T[3'b001]=8'b00000001;
      dith_T[3'b010]=8'b00010001;
      dith_T[3'b011]=8'b00100101;
      dith_T[3'b100]=8'b01010101;
      dith_T[3'b101]=8'b01011011;
      dith_T[3'b110]=8'b01110111;
      dith_T[3'b111]=8'b01111111;  
  end
      
  //count
  always@(posedge clk_in or posedge rst)begin
      if(rst)begin
          count<=3'b0;
      end else if(count==3'b111)begin
          count<=3'b0;
      end else begin
          count<=count+3'b1;        
      end
  end
  //find dither table
  assign dith_raw=dith_T[d_n_input[2:0]];
  //check
  always@(count)begin
      case(count)
          3'b000: dith_point=dith_raw[7];
          3'b001: dith_point=dith_raw[6];
          3'b010: dith_point=dith_raw[5];
          3'b011: dith_point=dith_raw[4];
          3'b100: dith_point=dith_raw[3];
          3'b101: dith_point=dith_raw[2];
          3'b110: dith_point=dith_raw[1];
          3'b111: dith_point=dith_raw[0];
          default:dith_point=1'b0;
      endcase  
  end
  assign d_dith=d_n_input[9:3]+dith_point;
endmodule