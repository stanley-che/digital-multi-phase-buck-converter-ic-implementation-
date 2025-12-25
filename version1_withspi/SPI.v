//SPI communication with four peripheral devices
module SPI (rst,clk,data_send_c,data_send_p,start_comm,CS_in);

//parameters
parameter PAUSE=10;                 //Number of clock cycles between transmit and receive
parameter LENGTH_SEND_C=16;         //Length of sent data (Controller->Peripheral unit
parameter LENGTH_SEND_P=16;         //Length of sent data (Peripheral unit-->Controller)
parameter LENGTH_RECIEVED_C=16;     //Length of recieved data (Peripheral unit-->Controller)
parameter LENGTH_RECIEVED_P=16;     //Length of recieved data (Controller-->Peripheral unit)
parameter LENGTH_COUNT_C=6;        //Default: LENGTH_SEND_C+LENGTH_SEND_P+PAUSE+2=28 -->5 bit counter
parameter LENGTH_COUNT_P=6;        //Default: LENGTH_SEND_C+LENGTH_SEND_P+2=18 -->5 bit counter
parameter PERIPHERY_COUNT=4;       //Number of peripherals
parameter PERIPHERY_SELECT=2;      //Peripheral unit select signals (log2 of PERIPHERY_COUNT)

//Input signals
input  logic rst;                              //Active high logic
input  logic clk;                              //Controller's clock
input  logic [LENGTH_SEND_C-1:0] data_send_c;  //Data to be sent from the controller
input  logic [LENGTH_SEND_P-1:0] data_send_p;  //Data to be sent from the periphary unit
input  logic start_comm;                       //Rises to logic high upon communication initiation
input  logic [PERIPHERY_SELECT-1:0] CS_in;     //Chip-select (set in the TB)

//Internal signals
logic COPI;                                   //Controller-Out Peripheral-In
logic SCK;                                    //Shared serial clock
logic CS;                                     //Chip select (not used)
logic [LENGTH_SEND_P-1:0] CIPO_register;      //Holds the data received at the controller unit
logic [LENGTH_SEND_C-1:0] COPI_register_0;    //Holds the data recieved at the peripheral unit (SPI_P_0)
logic [LENGTH_SEND_C-1:0] COPI_register_1;    //Holds the data recieved at the peripheral unit (SPI_P_1)
logic [LENGTH_SEND_C-1:0] COPI_register_2;    //Holds the data recieved at the peripheral unit (SPI_P_2)
logic [LENGTH_SEND_C-1:0] COPI_register_3;    //Holds the data recieved at the peripheral unit (SPI_P_3)
logic [PERIPHERY_COUNT-1:0] CS_out;           //One-hot encoding
logic [9:0] regfile [0:5];                     // Register file for spi_reg peripheral
logic                      mode_manual;
logic                      en_pwm;
logic [9:0]                duty_high;
logic [9:0]                duty_low;
logic [9:0]                freq_switch;

// ------------------------------------------------------------
// ✅ 改這裡：每個 peripheral 各自一條 cipoX，最後 mux 成 CIPO
// ------------------------------------------------------------
wire cipo0, cipo1, cipo2, cipo3;
wire CIPO;

// 依你原本註解：CS_out[i] 是 active-low（被選到時 = 0）
assign CIPO =
    (!CS_out[0]) ? cipo0 :
    (!CS_out[1]) ? cipo1 :
    (!CS_out[2]) ? cipo2 :
    (!CS_out[3]) ? cipo3 :
    1'bz;

//Controller instantiation
SPI_Controller #(
    .PAUSE(PAUSE),
    .LENGTH_SEND(LENGTH_SEND_C),
    .LENGTH_RECIEVED(LENGTH_RECIEVED_C),
    .LENGTH_COUNT(LENGTH_COUNT_C),
    .PERIPHERY_COUNT(PERIPHERY_COUNT),
    .PERIPHERY_SELECT(PERIPHERY_SELECT)
) SPI_C_0 (
    .rst(rst),
    .clk(clk),
    .SCK(SCK),
    .COPI(COPI),
    .CIPO(CIPO),
    .data_send(data_send_c),
    .start_comm(start_comm),
    .CS_in(CS_in),
    .CS_out(CS_out),
    .CIPO_register(CIPO_register)
);

// Peripheral 0: spi_reg
  logic       convst_bar;
    logic [9:0] mon_duty_high;
    logic [9:0] mon_duty_low;
    logic duty_high0;
    logic duty_low0;
    logic duty_high1;
    logic duty_low1;
    logic duty_high2;
    logic duty_low2;
    logic duty_high3;
    logic duty_low3;
    logic [7:0] data_in;

 top #(
    .PAUSE(PAUSE),
    .LENGTH_SEND_C(LENGTH_SEND_C),
    .LENGTH_SEND_P(LENGTH_SEND_P),
    .LENGTH_RECIEVED_C(LENGTH_RECIEVED_C),
    .LENGTH_RECIEVED_P(LENGTH_RECIEVED_P),
    .LENGTH_COUNT_C(LENGTH_COUNT_C),
    .LENGTH_COUNT_P(LENGTH_COUNT_P),
    .PERIPHERY_COUNT(PERIPHERY_COUNT),
    .PERIPHERY_SELECT(PERIPHERY_SELECT)
) u_spi_reg(
    .clk(clk),
    .rst(rst),
    .data_in(data_in),
    .data_send_p(data_send_p), 
    // SPI pins
    .SCK(SCK),
    .CS(CS_out[0]),
    .COPI(COPI),
    .CIPO(cipo0),
    .COPI_register(COPI_register_0),
    .duty_high0(duty_high0),
    .duty_low0(duty_low0),
    .duty_high1(duty_high1),
    .duty_low1(duty_low1),
    .duty_high2(duty_high2),
    .duty_low2(duty_low2),
    .duty_high3(duty_high3),
    .duty_low3(duty_low3),
    .convst_bar(convst_bar),
    .mon_duty_high(mon_duty_high),
    .mon_duty_low(mon_duty_low),
    .mode_manual(mode_manual),
    .en_pwm(en_pwm),
    .freq_switch(freq_switch),
    .duty_high_manual(duty_high),
    .duty_low_manual(duty_low)
);
// Peripheral 0: spi_reg
/*spi_reg #(
    .PAUSE(PAUSE),
    .LENGTH_SEND_C(LENGTH_SEND_C),
    .LENGTH_SEND_P(LENGTH_SEND_P),
    .LENGTH_RECIEVED_C(LENGTH_RECIEVED_C),
    .LENGTH_RECIEVED_P(LENGTH_RECIEVED_P),
    .LENGTH_COUNT_C(LENGTH_COUNT_C),
    .LENGTH_COUNT_P(LENGTH_COUNT_P),
    .PERIPHERY_COUNT(PERIPHERY_COUNT),
    .PERIPHERY_SELECT(PERIPHERY_SELECT)
) u_spi_reg (
    .rst(rst),
    .SCK(SCK),
    .COPI(COPI),
    .CS(CS_out[0]),          // active-low select
    .data_send_p(data_send_p),
    .CIPO(cipo0),            
    .mode_manual(mode_manual),
    .en_pwm(en_pwm),
    .duty_high(duty_high),
    .duty_low(duty_low),
    .freq_switch(freq_switch),
    .COPI_register(COPI_register_0),
    .regfile (regfile)
);*/

SPI_Periphery #(
    .LENGTH_SEND(LENGTH_SEND_P),
    .LENGTH_RECIEVED(LENGTH_RECIEVED_P),
    .LENGTH_COUNT(LENGTH_COUNT_P),
    .PAUSE(PAUSE)
) SPI_P_1 (
    .SCK(SCK),
    .COPI(COPI),
    .CIPO(cipo1),            // ✅ 改
    .CS(CS_out[1]),
    .data_send(data_send_p),
    .rst(rst),
    .COPI_register(COPI_register_1)
);

SPI_Periphery #(
    .LENGTH_SEND(LENGTH_SEND_P),
    .LENGTH_RECIEVED(LENGTH_RECIEVED_P),
    .LENGTH_COUNT(LENGTH_COUNT_P),
    .PAUSE(PAUSE)
) SPI_P_2 (
    .SCK(SCK),
    .COPI(COPI),
    .CIPO(cipo2),            // ✅ 改
    .CS(CS_out[2]),
    .data_send(data_send_p),
    .rst(rst),
    .COPI_register(COPI_register_2)
);

SPI_Periphery #(
    .LENGTH_SEND(LENGTH_SEND_P),
    .LENGTH_RECIEVED(LENGTH_RECIEVED_P),
    .LENGTH_COUNT(LENGTH_COUNT_P),
    .PAUSE(PAUSE)
) SPI_P_3 (
    .SCK(SCK),
    .COPI(COPI),
    .CIPO(cipo3),            // ✅ 改
    .CS(CS_out[3]),
    .data_send(data_send_p),
    .rst(rst),
    .COPI_register(COPI_register_3)
);

endmodule
