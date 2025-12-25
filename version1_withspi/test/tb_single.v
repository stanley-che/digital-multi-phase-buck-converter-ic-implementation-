`timescale 1ns/1ns
/*
iverilog -g2012 -o sim.out \
test/tb_single.v \
top.v \
encoder.v \
clkdivider.v \
dither.v \
dither_deadtime_count.v \
convert.v \
shift_register_phase_shifter.v

*/
module tb_top();

  // -----------------------------
  // DUT I/O
  // -----------------------------
  logic         clk;
  logic         rst;
  logic  [7:0]  data_in;
  logic        duty_high0;
  logic        duty_low0;
  logic        duty_high1;
  logic        duty_low1;
  logic        duty_high2;
  logic        duty_low2;
  logic        duty_high3;
  logic        duty_low3;
  logic        convst_bar;
  
  logic                      mode_manual;
  logic                      en_pwm;
  logic [9:0]                duty_high;
  logic [9:0]                duty_low;
  logic [9:0]                freq_switch;
  
  //Internal signals
  logic COPI;                                   //Controller-Out Peripheral-In
  logic SCK;                                    //Shared serial clock
  logic CS;                                     //Chip select (not used)
  parameter PAUSE=10;                  //Number of clock cycles between transmit and receive
  parameter LENGTH_SEND_C=16;          //Length of sent data (Controller->Peripheral unit)
  parameter LENGTH_SEND_P=16;         //Length of sent data (Peripheral unit-->Controller)
  parameter LENGTH_RECIEVED_C=16;     //Length of recieved data (Peripheral unit-->Controller)
  parameter LENGTH_RECIEVED_P=16;      //Length of recieved data (Controller-->Peripheral unit)
  parameter LENGTH_COUNT_C=6;         //LENGTH_SEND_C+LENGTH_SEND_P+PAUSE+2=28 -->5 bit counter (default settings)
  parameter LENGTH_COUNT_P=6;         //LENGTH_SEND_C+LENGTH_SEND_P+2=18 -->5 bit counter (default settings)
  parameter PERIPHERY_COUNT=4;        //Number of peripherals
  parameter PERIPHERY_SELECT=2;       //Peripheral unit select signals (log2 of PERIPHERY_COUNT)
  integer SEED=15;
  logic [LENGTH_SEND_P-1:0] data_send_p;
  logic [9:0] regfile [0:5];                     // Register file for spi_reg peripheral
  logic [LENGTH_SEND_C-1:0] COPI_register_0;    //Holds the data recieved at the peripheral unit (SPI_P_0)
  wire cipo0, cipo1, cipo2, cipo3;
  wire CIPO;
  //logic SCK; 
  logic [PERIPHERY_COUNT-1:0] CS_out;           //One-hot encoding
  //logic COPI;                                   //Controller-Out Peripheral-In
  // -----------------------------
  // Instantiate DUT
  // -----------------------------
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
    .duty_low_manual(duty_low),
    .regfile(regfile)
  );

  // -----------------------------
  // Clock (ex: 100MHz => 10ns period)
  // -----------------------------
  localparam integer CLK_PERIOD_NS = 10;
  initial clk = 1'b0;
  always #(CLK_PERIOD_NS/2) clk = ~clk;

  // -----------------------------
  // Sample generator controls
  // -----------------------------
  integer sample_idx;
  integer seed;

  // clamp helper
  function automatic [7:0] clamp_u8(input integer x);
    begin
      if (x < 0)       clamp_u8 = 8'd0;
      else if (x > 255) clamp_u8 = 8'd255;
      else             clamp_u8 = x[7:0];
    end
  endfunction

  // A waveform like your plot (192 = 1.5V)
  function automatic [7:0] sample_gen(input integer k);
    integer base;
    integer noise;
    begin
      // small noise: -2..+2
      noise = ($random(seed) % 5) - 2;

      // 1) ramp to 192
      if (k < 200) begin
        // ramp: 0 -> 192 in 200 samples
        base = (192 * k) / 200;
      end
      else begin
        // 2) steady around 192
        base = 192;

        // 3) inject a few spike/disturbance events (like your plot)
        //    You can adjust the k positions below to match your sim time.
        //    Each event lasts a few samples then returns.
        if (k == 260) base = 210;          // upward spike
        if (k == 261) base = 185;          // immediate undershoot
        if (k == 262) base = 195;

        if (k == 520) base = 175;          // downward dip
        if (k == 521) base = 205;          // rebound
        if (k == 522) base = 192;

        if (k == 780) base = 215;          // another spike
        if (k == 781) base = 182;
        if (k == 782) base = 196;

        if (k == 1020) base = 178;         // dip + ring
        if (k == 1021) base = 198;
        if (k == 1022) base = 190;
      end

      sample_gen = clamp_u8(base + noise);
    end
  endfunction

  // Update data_in on each conversion strobe
  task automatic drive_next_sample;
    reg [7:0] s;
    begin
      s = sample_gen(sample_idx);
      data_in = s;
      sample_idx = sample_idx + 1;
    end
  endtask

  // -----------------------------
  // Reset & simulation control
  // -----------------------------
  initial begin
    seed = 32'h1234ABCD;
    sample_idx = 0;

    // init
    rst     = 1'b1;
    data_in = 8'd0;

    // waveform dump
    $dumpfile("tb_top.vcd");
    $dumpvars(0, tb_top);

    // hold reset
    #(200);
    rst = 1'b0;

    // run long enough
    #(5_000_000); // 5ms (adjust as needed)
    $finish;
  end

  // -----------------------------
  // Main stimulus:
  // use convst_bar as sampling point
  // -----------------------------
  // If your clkdivider produces convst_bar pulses, this is the most realistic.
  always @(negedge convst_bar) begin
    if (!rst) drive_next_sample();
  end

  // -----------------------------
  // Safety fallback:
  // If convst_bar never toggles (e.g., divider bug), still drive data periodically.
  // -----------------------------
  initial begin
    // wait reset release
    wait(rst == 1'b0);
    // after some time, if no convst_bar edges, we still update every 5us
    forever begin
      #(5000); // 5us
      // only do fallback if convst_bar seems stuck high/low for long time
      // (simple approach: always update; comment out if not needed)
      drive_next_sample();
    end
  end

endmodule
