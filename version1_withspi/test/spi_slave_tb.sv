`timescale 1ns/1ps
//iverilog -g2012 -o sim spi_slave.v test/spi_slave_tb.sv
//vvp sim

module tb_spi_slave;

  localparam integer ADDR_BITS = 3;
  localparam integer DATA_BITS = 16;

  // DUT I/O
  reg                    clk;
  reg                    rst;

  reg                    sclk;
  reg                    cs_n;
  reg                    mosi;
  wire                   miso;

  wire                   wr_pulse;
  wire [ADDR_BITS-1:0]   wr_addr;
  wire [DATA_BITS-1:0]   wr_data;

  wire                   rd_req;
  wire [ADDR_BITS-1:0]   rd_addr;
  reg  [DATA_BITS-1:0]   rd_data;

  // simple regfile
  reg [DATA_BITS-1:0] regfile [0:5];

  // scoreboard vars (move out of initial)
  integer wr_count;
  integer rd_count;

  // temp vars (move out of initial)
  reg [15:0] rdata;
  reg [2:0]  a;
  reg [15:0] d;
  reg [15:0] rr;
  integer i;
  integer k;

  // SCLK timing
  time T_HALF;

  // DUT
  spi_slave #(
    .ADDR_BITS(ADDR_BITS),
    .DATA_BITS(DATA_BITS)
  ) dut (
    .clk      (clk),
    .rst      (rst),
    .sclk     (sclk),
    .cs_n     (cs_n),
    .mosi     (mosi),
    .miso     (miso),
    .wr_pulse (wr_pulse),
    .wr_addr  (wr_addr),
    .wr_data  (wr_data),
    .rd_req   (rd_req),
    .rd_addr  (rd_addr),
    .rd_data  (rd_data)
  );

  // combinational read
  always @(*) begin
    if (rd_addr < 6)
      rd_data = regfile[rd_addr];
    else
      rd_data = {DATA_BITS{1'b0}};
  end

  // write on wr_pulse
  always @(posedge clk) begin
    if (wr_pulse) begin
      if (wr_addr < 6) regfile[wr_addr] <= wr_data;
    end
  end

  // sys clk 100MHz
  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  // init sclk
  initial begin
    sclk = 1'b0;
  end

  // -----------------------------
  // SPI helpers (Mode0)
  // -----------------------------
  task spi_cs_low;
    begin
      cs_n = 1'b1;
      mosi = 1'b0;
      sclk = 1'b0;
      #(T_HALF);
      cs_n = 1'b0;
      #(T_HALF);
    end
  endtask

  task spi_cs_high;
    begin
      #(T_HALF);
      cs_n = 1'b1;
      mosi = 1'b0;
      sclk = 1'b0;
      #(T_HALF);
    end
  endtask

  task spi_xfer_bit;
    input  reg mosi_bit;
    output reg miso_bit;
    begin
      // setup MOSI while SCLK low
      mosi = mosi_bit;
      #(T_HALF);

      // posedge: DUT samples MOSI, TB samples MISO
      sclk = 1'b1;
      #1;
      miso_bit = miso;
      #(T_HALF-1);

      // negedge: DUT shifts MISO
      sclk = 1'b0;
      #(T_HALF);
    end
  endtask

  task spi_xfer_bits;
    input  reg [31:0] tx;
    input  integer    nbits;
    output reg [31:0] rx;
    reg mb;
    reg sb;
    integer j;
    begin
      rx = 32'h0;
      for (j = nbits-1; j >= 0; j = j-1) begin
        mb = tx[j];
        spi_xfer_bit(mb, sb);
        rx[j] = sb;
      end
    end
  endtask

  function [7:0] make_cmd;
    input reg rw;
    input reg [ADDR_BITS-1:0] addr;
    reg [7:0] c;
    begin
      c = 8'h00;
      c[7] = rw;
      c[ADDR_BITS-1:0] = addr;
      make_cmd = c;
    end
  endfunction

  task spi_write;
    input reg [ADDR_BITS-1:0] addr;
    input reg [DATA_BITS-1:0] data;
    reg [31:0] rx;
    reg [7:0]  cmd;
    begin
      cmd = make_cmd(1'b0, addr);
      repeat (5) @(posedge clk);
      spi_cs_low();
      repeat (5) @(posedge clk);
      spi_xfer_bits({24'h0, cmd}, 8, rx);
      #(10*T_HALF);
      spi_xfer_bits({16'h0, data}, 16, rx);

      spi_cs_high();
    end
  endtask

  task spi_read;
    input  reg [ADDR_BITS-1:0] addr;
    output reg [DATA_BITS-1:0] data_out;
    reg [31:0] rx_cmd;
    reg [31:0] rx_dummy;
    reg [7:0]  cmd;
    begin
      cmd = make_cmd(1'b1, addr);
      spi_cs_low();

      spi_xfer_bits({24'h0, cmd}, 8, rx_cmd);
      #(10*T_HALF);
      spi_xfer_bits(32'h0, 16, rx_dummy);
      #(10*T_HALF);
      spi_cs_high();
      #(10*T_HALF);
      data_out = rx_dummy[15:0];
    end
  endtask

  // monitors
  always @(posedge clk) begin
    if (wr_pulse) begin
      wr_count = wr_count + 1;
      $display("[%0t] WR_PULSE addr=%0d data=0x%04h", $time, wr_addr, wr_data);
    end
    if (rd_req) begin
      rd_count = rd_count + 1;
      $display("[%0t] RD_REQ   addr=%0d rd_data=0x%04h", $time, rd_addr, rd_data);
    end
  end

  // main test
  initial begin
    // init
    T_HALF   = 20;
    cs_n     = 1'b1;
    mosi     = 1'b0;
    rst      = 1'b1;
    wr_count = 0;
    rd_count = 0;
    $dumpfile("tb_spi_slave.vcd");
    $dumpvars(0, tb_spi_slave);
    // init regfile
    for (i = 0; i < 6; i = i + 1) begin
      regfile[i] = 16'h1000 + i;
    end

    // reset
    repeat (5) @(posedge clk);
    rst = 1'b0;
    repeat (5) @(posedge clk);

    $display("=== TEST 1: WRITE then READ back ===");

    spi_write(3'd2, 16'hBEEF);
    repeat (10) @(posedge clk);

    if (regfile[2] !== 16'hBEEF) begin
      $display("WRITE FAIL: regfile[2]=0x%04h expected 0xBEEF", regfile[2]);
      $finish;
    end

    spi_read(3'd2, rdata);
    $display("Readback = 0x%04h", rdata);

    if (rdata !== 16'hBEEF) begin
      $display("READ FAIL: got 0x%04h expected 0xBEEF", rdata);
      $finish;
    end

    $display("=== TEST 2: multiple regs random ===");
    for (k = 0; k < 10; k = k + 1) begin
      a = $urandom % 6;
      d = $urandom;
      spi_write(a, d);
      repeat (6) @(posedge clk);
      spi_read(a, rr);
      if (rr !== d) begin
        $display("MISMATCH addr=%0d wrote 0x%04h read 0x%04h", a, d, rr);
        $finish;
      end
    end

    $display("=== DONE. wr_count=%0d rd_count=%0d ===", wr_count, rd_count);
    $finish;
  end

endmodule
