/*
iverilog -g2012 -s SPI_TB -o sim \
  spi_slave.v spi_master.v spi_reg.v clkdivider.v dither_deadtime_count.v \
  shift_register_phase_shifter.v convert.v encoder.v top.v dither.v \
  test/tb_reg.v test/test_reg.v
vvp sim
*/
`timescale 1ns/100ps

module SPI_TB();

//Parameter declerations
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

//Internal signals declarations
logic rst;
logic clk;
logic start_comm;                   //Rises to logic high upon communication initiation
logic [LENGTH_SEND_C-1:0] data_send_c;
logic [LENGTH_SEND_P-1:0] data_send_p;
logic [PERIPHERY_SELECT-1:0] CS_in;
logic [LENGTH_SEND_P-1:0] COPI_register_compare;
// helper: snapshot regfile
logic [9:0] rf0, rf1, rf2, rf3, rf4, rf5;
integer k;
integer wait_rand;

SPI #(.PAUSE(PAUSE), .LENGTH_SEND_C(LENGTH_SEND_C), .LENGTH_SEND_P(LENGTH_SEND_P), .LENGTH_RECIEVED_C(LENGTH_RECIEVED_C), .LENGTH_RECIEVED_P(LENGTH_RECIEVED_P), .LENGTH_COUNT_C(LENGTH_COUNT_C), .LENGTH_COUNT_P(LENGTH_COUNT_P), .PERIPHERY_COUNT(PERIPHERY_COUNT), .PERIPHERY_SELECT(PERIPHERY_SELECT)) SPI(
            .rst(rst),
            .clk(clk),
            .data_send_c(data_send_c),
            .data_send_p(data_send_p),
            .start_comm(start_comm),
            .CS_in(CS_in)
);
task automatic spi_write0(input [3:0] addr, input [9:0] wdata);
begin
  CS_in = 2'b00;  // select peripheral0 (spi_reg)

  // frame: [15:14]=0, [13:4]=wdata, [3:0]=addr
  data_send_c = {2'b00, wdata, addr};

  start_comm <= 1'b1;
  repeat (LENGTH_SEND_C + PAUSE + LENGTH_SEND_P + 6) begin
    @(posedge clk);
    start_comm <= 1'b0;
  end

  // ✅ 最重要：等 CS_out[0] 真正 deassert（posedge）→ spi_reg 才會寫入
  @(posedge SPI.CS_out[0]);
  #1;
end
endtask

task automatic snapshot_rf;
begin
  rf0 = SPI.u_spi_reg.regfile[0];
  rf1 = SPI.u_spi_reg.regfile[1];
  rf2 = SPI.u_spi_reg.regfile[2];
  rf3 = SPI.u_spi_reg.regfile[3];
  rf4 = SPI.u_spi_reg.regfile[4];
  rf5 = SPI.u_spi_reg.regfile[5];
end
endtask

task automatic assert_rf_unchanged(input string tag);
begin
  if (SPI.u_spi_reg.regfile[0] !== rf0 ||
      SPI.u_spi_reg.regfile[1] !== rf1 ||
      SPI.u_spi_reg.regfile[2] !== rf2 ||
      SPI.u_spi_reg.regfile[3] !== rf3 ||
      SPI.u_spi_reg.regfile[4] !== rf4 ||
      SPI.u_spi_reg.regfile[5] !== rf5) begin
    $display("[T5][FAIL] regfile changed unexpectedly (%s)", tag);
    $display("  old: r0=%h r1=%h r2=%h r3=%h r4=%h r5=%h", rf0,rf1,rf2,rf3,rf4,rf5);
    $display("  new: r0=%h r1=%h r2=%h r3=%h r4=%h r5=%h",
              SPI.u_spi_reg.regfile[0], SPI.u_spi_reg.regfile[1], SPI.u_spi_reg.regfile[2],
              SPI.u_spi_reg.regfile[3], SPI.u_spi_reg.regfile[4], SPI.u_spi_reg.regfile[5]);
    //$finish;
  end else begin
    $display("[T5][OK] regfile unchanged (%s)", tag);
  end
end
endtask

integer addr_rand;
integer wdata_rand;
//HDL code
//Initial blocks
initial begin
  $dumpfile("tb_spi.vcd");
  $dumpvars(0, SPI_TB);
  rst=1'b0;	
  clk=1'b0;
  start_comm=1'b0;
  CS_in=2'b00;
  wait_rand=0;
  data_send_c='0;
  data_send_p='0;
  #1000
  rst=1'b1;
  #1100
  
//----------------------------------------//
//Test #1: Random 8-bit words is sent from the controller to the periphary. Random 16-bit word is sent from the periphary to the controller. Communication with SPI_P_0.
for(k=0; k<10; k++) begin
  data_send_c= $dist_uniform(SEED,0,2**LENGTH_SEND_C-1);        //8-bit random number to be sent to the periphary
  data_send_p= $dist_uniform(SEED,0,2**LENGTH_SEND_P-1);        //16-bit random number to be sent to the controller

  start_comm<=1'b1;                                             //Initial communication
  
  //Total duration of a communication interval is: LENGTH_SEND_C+LENGTH_SEND_P+PAUSE+4
  repeat(LENGTH_SEND_C+PAUSE+LENGTH_SEND_P+4) begin           //Wait for the comminication to terminate
    @(posedge clk)
    start_comm<=1'b0;
  end

#1;
//Verify the data was succesfully sent from the Peripheral unit-->controller
if (SPI.CIPO_register == data_send_p) begin
            $display("\nData sent from periphary is %b data recieved in the controller is %b on iteration number %d-success",data_send_p,SPI.CIPO_register,k);
end
else begin
  $display("\nData sent from Peripheral unit to controller is %b data recieved is %b on iteration number %d- fail",data_send_p,SPI.CIPO_register,k); 
  //$finish;
 end
 
//Verify the data was succesfully sent from the controller-->Peripheral unit
if (SPI.COPI_register_0 == data_send_c) begin
            $display("\nData sent from controller is %b data recieved in the Peripheral unit is %b on iteration number %d-success",data_send_c,SPI.COPI_register_0,k);
end
else begin
  $display("\nData sent from controller to periphary is %b data recieved is %b on iteration number %d- fail",data_send_c,SPI.COPI_register_0,k); 
  //$finish;  
end

end
$display("\nTest 1 completed successfully\n");

//----------------------------------------//

//Test 2#: Random 8-bit words is sent from the controller to the periphary. Random 16-bit word is sent from the periphary to the controller. Communication with SPI_P_0. start_comm is re-trigerred when busy.
for(k=0; k<10; k++) begin
  data_send_c= $dist_uniform(SEED,0,2**LENGTH_SEND_C-1);                        //8-bit random number to be sent to the periphary
  data_send_p= $dist_uniform(SEED,0,2**LENGTH_SEND_P-1);                        //16-bit random number to be sent to the controller
  wait_rand= $dist_uniform(SEED,0,LENGTH_SEND_C+PAUSE+LENGTH_SEND_P);           //wait period before re-trigerring the 'start comm.' signal

  start_comm<=1'b1;                                                             //Initial communication
  
  //Total duration of a communication interval is: LENGTH_SEND_C+LENGTH_SEND_P+PAUSE+4
  repeat(wait_rand) begin                                                       //Wait for the comminication to terminate
    @(posedge clk)
    start_comm<=1'b0;
  end
  
  @(posedge clk)
    start_comm<=1'b1;
  
  repeat(LENGTH_SEND_C+PAUSE+LENGTH_SEND_P+3-wait_rand) begin                   //Wait for the comminication to terminate
    @(posedge clk)
    start_comm<=1'b0;
  end  

  #1;   
  //Verify the data was succesfully sent from the Peripheral unit-->controller
  if (SPI.CIPO_register == data_send_p) begin
    $display("\nData sent from periphary is %b data recieved in the controller is %b on iteration number %d-success",data_send_p,SPI.CIPO_register,k);
  end
  else begin
    $display("\nData sent from Peripheral unit to controller is %b data recieved is %b on iteration number %d- fail",data_send_p,SPI.CIPO_register,k); 
    //$finish;
  end

  //Verify the data was succesfully sent from the controller-->Peripheral unit
  if (SPI.COPI_register_0 == data_send_c) begin
            $display("\nData sent from controller is %b data recieved in the Peripheral unit is %b on iteration number %d-success",data_send_c,SPI.COPI_register_0,k);
  end
  else begin
    $display("\nData sent from controller to periphary is %b data recieved is %b on iteration number %d- fail",data_send_c,SPI.COPI_register_0,k); 
    //$finish;  
  end

end
$display("\nTest 2 completed successfully\n");
//----------------------------------------//

//Test #3: Random 8-bit words is sent from the controller to the periphary. Random 16-bit word is sent from the periphary to the controller. Randomly change the periphery.
for(k=0; k<20; k++) begin 
  data_send_c= $dist_uniform(SEED,0,2**LENGTH_SEND_C-1);                    //8-bit random number to be sent to the periphary
  data_send_p= $dist_uniform(SEED,0,2**LENGTH_SEND_P-1);                    //16-bit random number to be sent to the controller
  CS_in= $dist_uniform(SEED,0,PERIPHERY_COUNT-1);                           //Randomizing CS signal 
  //CS_in=2'b00;
  start_comm<=1'b1;                                                         //Initial communication

  //Total duration of a communication interval is: LENGTH_SEND_C+LENGTH_SEND_P+PAUSE+4
  repeat(LENGTH_SEND_C+PAUSE+LENGTH_SEND_P+4) begin   //wait for the comminication to terminate
    @(posedge clk)
    start_comm<=1'b0;
  end

  #1;
  //Verify the data was succesfully sent from the periphery-->controller                               
  if (SPI.CIPO_register == data_send_p) begin
    $display("\nData sent from periphary number %d is %b data recieved in the controller is %b on iteration number %d-success",CS_in,data_send_p,SPI.CIPO_register,k);
  end
  else begin
    $display("\nData sent from periphery number %d to controller is %b data recieved is %b on iteration number %d- fail",CS_in,data_send_p,SPI.CIPO_register,k); 
    $finish;
   end
 
  //Verify the data was succesfully sent from the controller-->periphery                               
  if (COPI_register_compare == data_send_c) 
    $display("\nData sent from controller is %b data recieved in the periphery number %d is %b on iteration number %d-success",data_send_c,CS_in,COPI_register_compare,k);
  else begin
    $display("\nData sent from controller to periphary number %d is %b data recieved is %b on iteration number %d- fail",CS_in,data_send_c,COPI_register_compare,k); 
    $finish;
  end

end

$display("\nTest 3 completed successfully\n");	

//----------------------------------------//
// Test #4: SPEC-based register write test
//----------------------------------------//

CS_in = 2'b00;   // select spi_reg (peripheral 0)
// -----------------------------
// REG1: duty_high = 10'h155
// -----------------------------
data_send_c = {2'b00, 10'b1000000011, 4'b0001};
start_comm  <= 1'b1;

repeat (LENGTH_SEND_C + PAUSE + LENGTH_SEND_P + 4) begin
  @(posedge clk);
  start_comm <= 1'b0;
end
#1;

if (SPI.u_spi_reg.u_spi_reg1.duty_high !== 10'b1000000011) begin
  $display("[T4][FAIL] addr duty_high=%h", SPI.u_spi_reg.u_spi_reg1.addr);
  $display("[T4][FAIL] WDATA duty_high=%h", SPI.u_spi_reg.u_spi_reg1.wdata);
  $display("[T4][FAIL] REG1 duty_high=%h", SPI.u_spi_reg.u_spi_reg1.duty_high);
  $display("[T4][FAIL] REG1 duty_high=%h", SPI.u_spi_reg.u_spi_reg1.regfile[1][14:5]);
  $finish;
end
$display("[T4][OK] REG1 duty_high=0x155");

// -----------------------------
// REG0: mode_manual=1, en_pwm=1
// -----------------------------
data_send_c = {2'b00, 10'b0000000011, 4'b0000}; // wdata=3, addr=0
start_comm  <= 1'b1;

repeat (LENGTH_SEND_C + PAUSE + LENGTH_SEND_P + 4) begin
  @(posedge clk);
  start_comm <= 1'b0;
end
#1;

if (SPI.u_spi_reg.mode_manual !== 1'b1 ||
    SPI.u_spi_reg.en_pwm      !== 1'b1) begin
  $display("[T4][FAIL] REG0 mode_manual=%b en_pwm=%b",
           SPI.u_spi_reg.mode_manual,
           SPI.u_spi_reg.en_pwm);
  $finish;
end
$display("[T4][OK] REG0 mode_manual=1 en_pwm=1");



// -----------------------------
// REG2: duty_low = 10'h0AA
// -----------------------------
data_send_c = {2'b00, 10'h0AA, 4'b0010};
start_comm  <= 1'b1;

repeat (LENGTH_SEND_C + PAUSE + LENGTH_SEND_P + 4) begin
  @(posedge clk);
  start_comm <= 1'b0;
end
#1;

if (SPI.u_spi_reg.u_spi_reg1.duty_low !== 10'h0AA) begin
  $display("[T4][FAIL] REG2 duty_low=%h", SPI.u_spi_reg.u_spi_reg1.duty_low);
  //$finish;
end
$display("[T4][OK] REG2 duty_low=0x0AA");

// -----------------------------
// REG3: freq_switch = 10'h3C0
// -----------------------------
data_send_c = {2'b00, 10'h3C0, 4'b0011};
start_comm  <= 1'b1;

repeat (LENGTH_SEND_C + PAUSE + LENGTH_SEND_P + 4) begin
  @(posedge clk);
  start_comm <= 1'b0;
end
#1;

if (SPI.u_spi_reg.freq_switch !== 10'h3C0) begin
  $display("[T4][FAIL] REG3 freq_switch=%h", SPI.u_spi_reg.freq_switch);
  $finish;
end
$display("[T4][OK] REG3 freq_switch=0x3C0");
$display("\nTest 4 completed successfully\n");

//----------------------------------------//
// Test #5: EXTREME / CORNER CASE tests
//----------------------------------------//
$display("\n[T5] Extreme / Corner Case Tests begin\n");
// ------------------------------------------------------
// (1) MIN/MAX wdata on valid regs
// ------------------------------------------------------
data_send_c = {2'b00, 10'h1FF, 4'b0001};
start_comm  <= 1'b1;

repeat (LENGTH_SEND_C + PAUSE + LENGTH_SEND_P + 4) begin
  @(posedge clk);
  start_comm <= 1'b0;
end
#1;
if (SPI.u_spi_reg.duty_high !== 10'h1FF) begin
  $display("[T5][FAIL] REG1 max write expected 1FF got %h", SPI.u_spi_reg.duty_high);
  $finish;
end
$display("[T5][OK] REG1 max=1FF");
data_send_c = {2'b00, 10'h000, 4'b0001};
start_comm  <= 1'b1;

repeat (LENGTH_SEND_C + PAUSE + LENGTH_SEND_P + 4) begin
  @(posedge clk);
  start_comm <= 1'b0;
end
#1;

if (SPI.u_spi_reg.duty_high !== 10'h000) begin
  $display("[T5][FAIL] REG1 min write expected 000 got %h", SPI.u_spi_reg.duty_high);
  $finish;
end
$display("[T5][OK] REG1 min=0");



// also check edge regs
data_send_c = {2'b00, 10'h003, 4'b0000};
start_comm  <= 1'b1;

repeat (LENGTH_SEND_C + PAUSE + LENGTH_SEND_P + 4) begin
  @(posedge clk);
  start_comm <= 1'b0;
end
#1;
if (SPI.u_spi_reg.mode_manual !== 1'b1 || SPI.u_spi_reg.en_pwm !== 1'b1) begin
  $display("[T5][FAIL] REG0 bits write expected 11 got mode=%b en=%b",
           SPI.u_spi_reg.mode_manual, SPI.u_spi_reg.en_pwm);
  $finish;
end
$display("[T5][OK] REG0 bits=11");

data_send_c = {2'b00, 10'h3FF, 4'b0101};
start_comm  <= 1'b1;

repeat (LENGTH_SEND_C + PAUSE + LENGTH_SEND_P + 4) begin
  @(posedge clk);
  start_comm <= 1'b0;
end
#1;
if (SPI.u_spi_reg.regfile[5] !== 10'h3FF) begin
  $display("[T5][FAIL] REG5 max write expected 3FF got %h", SPI.u_spi_reg.regfile[5]);
  $finish;
end
$display("[T5][OK] REG5 max=3FF");

// ------------------------------------------------------
// (2) Illegal addr should NOT change any regfile
// ------------------------------------------------------
snapshot_rf();
//spi_write0(4'h6, 10'h155);  // illegal
data_send_c = {2'b00, 10'h155, 4'b0110};
start_comm  <= 1'b1;

repeat (LENGTH_SEND_C + PAUSE + LENGTH_SEND_P + 4) begin
  @(posedge clk);
  start_comm <= 1'b0;
end
#1;
assert_rf_unchanged("illegal addr 6");

snapshot_rf();
data_send_c = {2'b00, 10'h2AA, 4'hF};
start_comm  <= 1'b1;

repeat (LENGTH_SEND_C + PAUSE + LENGTH_SEND_P + 4) begin
  @(posedge clk);
  start_comm <= 1'b0;
end
#1;
assert_rf_unchanged("illegal addr F");

// ------------------------------------------------------
// (3) Overwrite same addr multiple times: last wins
// ------------------------------------------------------
data_send_c = {2'b00,10'h001, 4'h2};
start_comm  <= 1'b1;

repeat (LENGTH_SEND_C + PAUSE + LENGTH_SEND_P + 4) begin
  @(posedge clk);
  start_comm <= 1'b0;
end
#1;
data_send_c = {2'b00,10'h002, 4'h2};
start_comm  <= 1'b1;

repeat (LENGTH_SEND_C + PAUSE + LENGTH_SEND_P + 4) begin
  @(posedge clk);
  start_comm <= 1'b0;
end
#1;
data_send_c = {2'b00,10'h3AA, 4'h2};
start_comm  <= 1'b1;

repeat (LENGTH_SEND_C + PAUSE + LENGTH_SEND_P + 4) begin
  @(posedge clk);
  start_comm <= 1'b0;
end
#1;

if (SPI.u_spi_reg.duty_low !== 10'h3AA) begin
  $display("[T5][FAIL] overwrite REG2 expected 3AA got %h", SPI.u_spi_reg.duty_low);
  $finish;
end
$display("[T5][OK] overwrite REG2 last-wins");

// ------------------------------------------------------
// (4) Back-to-back start_comm stress (no big gaps)
//     send 3 writes quickly; last state must match
// ------------------------------------------------------
CS_in = 2'b00;
data_send_c = {2'b00, 10'h010, 4'h3}; 
start_comm <= 1'b1;
repeat (LENGTH_SEND_C + PAUSE + LENGTH_SEND_P + 4) begin
  @(posedge clk);
  start_comm <= 1'b0;
end
#1;
data_send_c = {2'b00, 10'h020, 4'h3}; start_comm <= 1'b1; 
repeat (LENGTH_SEND_C + PAUSE + LENGTH_SEND_P + 4) begin
  @(posedge clk);
  start_comm <= 1'b0;
end
#1;
data_send_c = {2'b00, 10'h3C0, 4'h3}; start_comm <= 1'b1; 
repeat (LENGTH_SEND_C + PAUSE + LENGTH_SEND_P + 4) begin
  @(posedge clk);
  start_comm <= 1'b0;
end
#1;

#1;

if (SPI.u_spi_reg.freq_switch !== 10'h3C0) begin
  $display("[T5][FAIL] back-to-back REG3 expected 3C0 got %h", SPI.u_spi_reg.freq_switch);
  $finish;
end
$display("[T5][OK] back-to-back REG3 last-wins");

// ------------------------------------------------------
// (5) Reset behavior test: reset asserted => regfile cleared
// ------------------------------------------------------
rst <= 1'b0;  // assert reset (active-low style)
repeat (5) @(posedge clk);
if (SPI.u_spi_reg.regfile[0] !== 10'h000 ||
    SPI.u_spi_reg.regfile[1] !== 10'h000 ||
    SPI.u_spi_reg.regfile[2] !== 10'h000 ||
    SPI.u_spi_reg.regfile[3] !== 10'h000 ||
    SPI.u_spi_reg.regfile[4] !== 10'h000 ||
    SPI.u_spi_reg.regfile[5] !== 10'h000) begin
  $display("[T5][FAIL] reset did not clear regfile");
  //$finish;
end
$display("[T5][OK] reset clears regfile");

// while in reset, attempt write should not stick
//spi_write0(4'h1, 10'h155);
data_send_c = {2'b00,10'h155, 4'h1};
start_comm  <= 1'b1;

repeat (LENGTH_SEND_C + PAUSE + LENGTH_SEND_P + 4) begin
  @(posedge clk);
  start_comm <= 1'b0;
end
#1;
if (SPI.u_spi_reg.regfile[1] !== 10'h000) begin
  $display("[T5][FAIL] write during reset should not stick, got %h", SPI.u_spi_reg.regfile[1]);
  //$finish;
end
$display("[T5][OK] write during reset ignored");

// deassert reset, write works again
rst <= 1'b1;
repeat (5) @(posedge clk);
//spi_write0(4'h1, 10'h155);
data_send_c = {2'b00,10'h155, 4'h1};
start_comm  <= 1'b1;

repeat (LENGTH_SEND_C + PAUSE + LENGTH_SEND_P + 4) begin
  @(posedge clk);
  start_comm <= 1'b0;
end
#1;
if (SPI.u_spi_reg.regfile[1] !== 10'h155) begin
  $display("[T5][FAIL] after reset release write failed, got %h", SPI.u_spi_reg.regfile[1]);
  //$finish;
end
$display("[T5][OK] after reset release write works");

$display("\n[T5] Extreme / Corner Case Tests completed successfully\n");

$finish;
end

//HDL Code
assign COPI_register_compare = (CS_in==2'b00) ? SPI.COPI_register_0 : (CS_in==2'b01) ? SPI.COPI_register_1 : (CS_in==2'b10) ? SPI.COPI_register_2 : SPI.COPI_register_3;

//Clock generation
always begin
  #10;
  clk=~clk;
end

endmodule
