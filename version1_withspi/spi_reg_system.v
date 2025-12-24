`timescale 1ns/1ps
// spi_reg_system.v
module spi_reg_system #(
    parameter integer DATA_BITS = 16
)(
    input  wire clk,
    input  wire rst,

    // SPI
    input  wire sclk,
    input  wire cs_n,
    input  wire mosi,
    output wire miso,

    // expose registers
    output wire [DATA_BITS-1:0] reg0,
    output wire [DATA_BITS-1:0] reg1,
    output wire [DATA_BITS-1:0] reg2,
    output wire [DATA_BITS-1:0] reg3,
    output wire [DATA_BITS-1:0] reg4,
    output wire [DATA_BITS-1:0] reg5
);

    wire                 wr_pulse;
    wire [2:0]           wr_addr;
    wire [DATA_BITS-1:0] wr_data;

    wire                 rd_req;
    wire [2:0]           rd_addr;
    wire [DATA_BITS-1:0] rd_data;

    spi_slave #(
        .ADDR_BITS(3),
        .DATA_BITS(DATA_BITS)
    ) u_spi (
        .clk(clk),
        .rst(rst),
        .sclk(sclk),
        .cs_n(cs_n),
        .mosi(mosi),
        .miso(miso),

        .wr_pulse(wr_pulse),
        .wr_addr(wr_addr),
        .wr_data(wr_data),

        .rd_req(rd_req),
        .rd_addr(rd_addr),
        .rd_data(rd_data)
    );

    regfile6 #(
        .DATA_BITS(DATA_BITS)
    ) u_rf (
        .clk(clk),
        .rst(rst),
        .wr_en(wr_pulse),
        .wr_addr(wr_addr),
        .wr_data(wr_data),
        .rd_addr(rd_addr),
        .rd_data(rd_data),

        .reg0(reg0),
        .reg1(reg1),
        .reg2(reg2),
        .reg3(reg3),
        .reg4(reg4),
        .reg5(reg5)
    );

endmodule
