`timescale 1ns/1ns

module tb_top;

  // -----------------------------
  // DUT I/O
  // -----------------------------
  reg         clk;
  reg         rst;
  reg  [7:0]  data_in;
  wire        duty_high0;
  wire        duty_low0;
  wire        duty_high1;
  wire        duty_low1;
  wire        duty_high2;
  wire        duty_low2;
  wire        duty_high3;
  wire        duty_low3;
  wire        convst_bar;

  // -----------------------------
  // Instantiate DUT
  // -----------------------------
  top dut (
    .clk(clk),
    .rst(rst),
    .data_in(data_in),
    .duty_high0(duty_high0),
    .duty_low0(duty_low0),
    .duty_high1(duty_high1),
    .duty_low1(duty_low1),
    .duty_high2(duty_high2),
    .duty_low2(duty_low2),
    .duty_high3(duty_high3),
    .duty_low3(duty_low3),
    .convst_bar(convst_bar)
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
