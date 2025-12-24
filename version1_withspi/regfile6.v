`timescale 1ns/1ps
// regfile6.v
module regfile6 #(
    parameter integer DATA_BITS = 16
)(
    input  wire                 clk,
    input  wire                 rst,

    input  wire                 wr_en,      // 1 clk pulse
    input  wire [2:0]           wr_addr,    // 0..5
    input  wire [DATA_BITS-1:0] wr_data,

    input  wire [2:0]           rd_addr,
    output reg  [DATA_BITS-1:0] rd_data,

    // optional: expose regs to top
    output reg  [DATA_BITS-1:0] reg0,
    output reg  [DATA_BITS-1:0] reg1,
    output reg  [DATA_BITS-1:0] reg2,
    output reg  [DATA_BITS-1:0] reg3,
    output reg  [DATA_BITS-1:0] reg4,
    output reg  [DATA_BITS-1:0] reg5
);

    // write
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            reg0 <= 0;
            reg1 <= 0;
            reg2 <= 0;
            reg3 <= 0;
            reg4 <= 0;
            reg5 <= 0;
        end else if (wr_en) begin
            case (wr_addr)
                3'd0: reg0 <= wr_data;
                3'd1: reg1 <= wr_data;
                3'd2: reg2 <= wr_data;
                3'd3: reg3 <= wr_data;
                3'd4: reg4 <= wr_data;
                3'd5: reg5 <= wr_data;
                default: ; // ignore
            endcase
        end
    end

    // read (combinational-ish but registered output for clean timing)
    always @(*) begin
        case (rd_addr)
            3'd0: rd_data = reg0;
            3'd1: rd_data = reg1;
            3'd2: rd_data = reg2;
            3'd3: rd_data = reg3;
            3'd4: rd_data = reg4;
            3'd5: rd_data = reg5;
            default: rd_data = {DATA_BITS{1'b0}};
        endcase
    end

endmodule
