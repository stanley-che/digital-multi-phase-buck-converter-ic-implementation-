`timescale 1ns/1ns
module top(clk,rst,data_in,duty_high0,duty_low0,duty_high1,duty_low1,duty_high2,duty_low2,duty_high3,duty_low3,convst_bar);
    input clk,rst;
    input [7:0]data_in;
    output duty_high0;
    output duty_low0;
    output duty_high1;
    output duty_low1;
    output duty_high2;
    output duty_low2;
    output duty_high3;
    output duty_low3;
    output wire convst_bar;
    wire [6:0]d_n_input;
    wire [9:0]d_n;
    wire [3:0]err;
    wire [6:0]count;
    wire clk_dpwm,clk_comp;
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