module encoder(clk, rst, datain, en);
    input clk, rst;
    input [7:0] datain;
    output reg [3:0] en;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            en <= 4'b0000;
        end else begin
            case (1'b1)
                (datain <= 8'd176): en <= 4'b0100; // +4
                (datain <= 8'd180): en <= 4'b0011; // +3
                (datain <= 8'd184): en <= 4'b0010; // +2
                (datain <= 8'd188): en <= 4'b0001; // +1
                (datain <= 8'd192): en <= 4'b0000; //  0
                (datain <= 8'd196): en <= 4'b1111; // -1
                (datain <= 8'd200): en <= 4'b1110; // -2
                (datain <= 8'd204): en <= 4'b1101; // -3
                default           : en <= 4'b1100; // default
            endcase
        end
    end
endmodule
