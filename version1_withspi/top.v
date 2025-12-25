module top #(
    parameter PAUSE            = 10,   // Number of clk cycles between transmit and receive
    parameter LENGTH_SEND_C     = 16,   // Controller -> Peripheral
    parameter LENGTH_SEND_P     = 16,   // Peripheral -> Controller
    parameter LENGTH_RECIEVED_C = 16,   // Peripheral -> Controller (controller receives)
    parameter LENGTH_RECIEVED_P = 16,   // Controller -> Peripheral (peripheral receives)
    parameter LENGTH_COUNT_C    = 6,   // counter width in controller
    parameter LENGTH_COUNT_P    = 6,   // counter width in peripheral
    parameter PERIPHERY_COUNT   = 1,   // number of peripherals
    parameter PERIPHERY_SELECT  = 2    // log2(PERIPHERY_COUNT)
)(
    input  logic        clk,
    input  logic        rst,
    input  logic [7:0]  data_in,
    input  logic [LENGTH_SEND_P-1:0] data_send_p, 
    // SPI pins
    input  logic        SCK,
    input  logic        CS,
    input  logic        COPI,
    output logic        CIPO,
    output logic  [LENGTH_SEND_P-1:0] COPI_register,
    output logic        duty_high0,
    output logic        duty_low0,
    output logic        duty_high1,
    output logic        duty_low1,
    output logic        duty_high2,
    output logic        duty_low2,
    output logic        duty_high3,
    output logic        duty_low3,
    output logic        convst_bar,
    output logic [9:0]  mon_duty_high,
    output logic [9:0]  mon_duty_low,
    output logic        mode_manual,
    output logic        en_pwm,
    output logic [9:0]  freq_switch,
    output logic [9:0]  duty_high_manual,
    output logic [9:0]  duty_low_manual,
    //output logic [9:0] regfile [0:5]    // 6 registers, each 10-bit wide

);

    assign mon_duty_high=duty_high_manual;
    assign mon_duty_low =duty_low_manual;
    //spi reg module connection
    logic [6:0]d_n_input;
    logic [9:0]d_n;
    logic [3:0]err;
    logic [6:0]count;
    logic clk_dpwm,clk_comp;
    //module connection
    encoder encoder(
    .clk(clk),
    .rst(rst),
    .datain(data_in),
    .en(err)
    );
    clkdivider clkdivider(
        .clk(clk),
        .rst(rst),
        .count(count),
        .convst_bar(convst_bar),
        .clk_comp(clk_comp),
        .clk_dpwm(clk_dpwm)
    );
    dither dither(
        .clk_in(clk_dpwm),
        .rst(rst),
        .d_n_input(d_n),
        .d_dith(d_n_input)
    );
    
    dither_time dither_time(
        .clk(clk),
        .rst(rst),
        .d_n_input(d_n_input),
        .duty_high(duty_high),
        .duty_low(duty_low),
        .count(count)
    );
    
    stanley stanley(
        .clk(clk_comp),
        .rst(rst),
        .err_in(err),
        .d_comp(d_n)
    );
    wire [3:0]duty_high_reg;
    //high
    shift_register_phase_shifter #(
        .PERIOD(128), // ticks per PWM period
        .NPHASES(4)   // number of phases
    )u_shift_high(
        .clk(clk),
        .rst(rst),      // synchronous reset
        .en(1'b1),       // enable shifting
        .pwm_in(duty_high),   // base PWM (phase 0)
        .pwm_ph(duty_high_reg)    // phase-shifted PWMs
    );


spi_reg #(
    .PAUSE(PAUSE),
    .LENGTH_SEND_C(LENGTH_SEND_C),
    .LENGTH_SEND_P(LENGTH_SEND_P),
    .LENGTH_RECIEVED_C(LENGTH_RECIEVED_C),
    .LENGTH_RECIEVED_P(LENGTH_RECIEVED_P),
    .LENGTH_COUNT_C(LENGTH_COUNT_C),
    .LENGTH_COUNT_P(LENGTH_COUNT_P),
    .PERIPHERY_COUNT(PERIPHERY_COUNT),
    .PERIPHERY_SELECT(PERIPHERY_SELECT)
) u_spi_reg1 (
    .rst(rst),
    .SCK(SCK),
    .COPI(COPI),
    .CS(CS),          // active-low select
    .data_send_p(data_send_p),
    .CIPO(CIPO),            
    .mode_manual(mode_manual),
    .en_pwm(en_pwm),
    .duty_high(duty_high_manual),
    .duty_low(duty_low_manual),
    .freq_switch(freq_switch),
    .COPI_register(COPI_register)
);


   
    wire [3:0]duty_low_reg;
    //low phase shift
    shift_register_phase_shifter #(
        .PERIOD(128), // ticks per PWM period
        .NPHASES(4)   // number of phases
    )u_shift_low(
        .clk(clk),
        .rst(rst),      // synchronous reset
        .en(1'b1),       // enable shifting
        .pwm_in(duty_low),   // base PWM (phase 0)
        .pwm_ph(duty_low_reg)    // phase-shifted PWMs
    );

    //assign high
    assign duty_high0=duty_high_reg[0];
    assign duty_high1=duty_high_reg[1];
    assign duty_high2=duty_high_reg[2];
    assign duty_high3=duty_high_reg[3];

    //assign low
    assign duty_low0=duty_low_reg[0];
    assign duty_low1=duty_low_reg[1];
    assign duty_low2=duty_low_reg[2];
    assign duty_low3=duty_low_reg[3];
endmodule