// spi_reg.v
`timescale 1ns/1ps

`define regm0 4'b0000
`define regm1 4'b0001
`define regm2 4'b0010
`define regm3 4'b0011
`define regm4 4'b0100
`define regm5 4'b0101

module spi_reg #(
    parameter PAUSE             = 10,
    parameter LENGTH_SEND_C     = 16,   // Controller -> Peripheral
    parameter LENGTH_SEND_P     = 16,   // Peripheral -> Controller
    parameter LENGTH_RECIEVED_C = 16,
    parameter LENGTH_RECIEVED_P = 16,  // 你這裡至少要 >= 14 才能用到[13:4]
    parameter LENGTH_COUNT_C    = 6,
    parameter LENGTH_COUNT_P    = 6,
    parameter PERIPHERY_COUNT   = 1,
    parameter PERIPHERY_SELECT  = 1
)(
    input  logic                      rst,   // 這裡我當成 active-high reset（你可自行反相）
    input  logic                      SCK,
    input  logic                      COPI,
    input  logic                      CS,    // active-low
    input  logic [LENGTH_SEND_P-1:0]  data_send_p,  // peripheral -> controller 要送的資料
    output logic                      CIPO,
    // reg outputs (示意：你可以依你的 buck 控制需要調整寬度)
    output logic                      mode_manual,
    output logic                      en_pwm,
    output logic [9:0]                duty_high,
    output logic [9:0]                duty_low,
    output logic [9:0]                freq_switch,
    output logic [LENGTH_RECIEVED_P-1:0] COPI_register,
    output logic [9:0] regfile [0:5]    // 6 registers, each 10-bit wide
);



    // ============================================================
    // 1) peripheral instance (目前只接 P0；你之後可擴成 4 顆+CS decode)
    // ============================================================
    //reg [LENGTH_RECIEVED_P-1:0] COPI_register;

    SPI_Periphery #(
        .LENGTH_SEND     (LENGTH_SEND_P),
        .LENGTH_RECIEVED (LENGTH_RECIEVED_P),
        .LENGTH_COUNT    (LENGTH_COUNT_P),
        .PAUSE           (PAUSE)
    ) SPI_P_0 (
        .rst           (rst),
        .SCK           (SCK),
        .COPI          (COPI),
        .CIPO          (CIPO),
        .CS            (CS),            // 先直接用外部 CS
        .data_send     (data_send_p),
        .COPI_register (COPI_register)
    );

    // ============================================================
    // 2) register file: 6 regs (0..5), each 10-bit payload
    // ============================================================
   

    wire [3:0] addr = COPI_register[3:0];
    wire [9:0] wdata ;
    assign wdata = COPI_register[13:4];

    // 用 CS 上升沿當作一筆 transaction 結束後鎖住資料
    // (因為 SPI shifting 過程 COPI_register_0 會一直變，不能 combinational 寫 reg)
    logic [3:0] addr_lat;
logic [9:0] wdata_lat;
logic       we;
always_ff @(posedge SCK) begin
  if (!rst) begin
    addr_lat  <= 4'h0;
    wdata_lat <= 10'h0;
    we        <= 1'b0;
  end else begin
    addr_lat  <= COPI_register[3:0];
    wdata_lat <= COPI_register[13:4];

    // 只允許 0~5
    we <= (COPI_register[3:0] <= 4'h5);
  end
end
always_ff @(posedge SCK) begin
  if (!rst) begin
    regfile[0] <= '0;
    regfile[1] <= '0;
    regfile[2] <= '0;
    regfile[3] <= '0;
    regfile[4] <= '0;
    regfile[5] <= '0;
  end else if (we) begin
    case (addr_lat)
      4'h0: regfile[0] <= wdata_lat;
      4'h1: regfile[1] <= wdata_lat;
      4'h2: regfile[2] <= wdata_lat;
      4'h3: regfile[3] <= wdata_lat;
      4'h4: regfile[4] <= wdata_lat;
      4'h5: regfile[5] <= wdata_lat;
      default: ; // 現在 default 永遠不會觸發
    endcase
  end
end



    // ============================================================
    // 3) outputs mapping
    // ============================================================
    assign mode_manual = regfile[0][0];
    assign en_pwm      = regfile[0][1];
    assign duty_high   = regfile[1][9:0];
    assign duty_low    = regfile[2][9:0];
    assign freq_switch = regfile[3][9:0];
    

endmodule
