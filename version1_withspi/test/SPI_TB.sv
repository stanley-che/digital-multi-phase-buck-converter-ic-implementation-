    `timescale 1ns/1ns

    module tb_spi_top_combined;

    // ============================================================
    // Parameters (跟你 SPI_TB 一樣，用 16-bit frame)
    // ============================================================
    localparam int PAUSE            = 10;
    localparam int LENGTH_SEND_C     = 16;
    localparam int LENGTH_SEND_P     = 16;
    localparam int LENGTH_RECIEVED_C = 16;
    localparam int LENGTH_RECIEVED_P = 16;
    localparam int LENGTH_COUNT_C    = 6;
    localparam int LENGTH_COUNT_P    = 6;
    localparam int PERIPHERY_COUNT   = 1;
    localparam int PERIPHERY_SELECT  = 2;

    // ============================================================
    // TB signals (只留一份！)
    // ============================================================
    logic clk;
    logic rst;

    // SPI control
    logic start_comm;
    logic [PERIPHERY_SELECT-1:0] CS_in;
    logic [LENGTH_SEND_C-1:0] data_send_c;
    logic [LENGTH_SEND_P-1:0] data_send_p;
    logic [LENGTH_SEND_P-1:0] COPI_register_compare;

    // your system input into top
    logic [7:0] data_in;

    // DUT outputs (from your SPI wrapper that contains top)
    wire duty_high0, duty_low0;
    wire duty_high1, duty_low1;
    wire duty_high2, duty_low2;
    wire duty_high3, duty_low3;
    wire convst_bar;

    wire mode_manual;
    wire en_pwm;
    wire [9:0] freq_switch;
    wire [9:0] mon_duty_high;
    wire [9:0] mon_duty_low;
    wire  [LENGTH_RECIEVED_P-1:0] COPI_register;
    // random
    integer k;
    integer wait_rand;
    integer SEED;

    // ============================================================
    // Instantiate DUT (SPI wrapper)
    // 你要確定你的 SPI module 真的有這些 ports
    // ============================================================
    SPI #(
        .PAUSE(PAUSE),
        .LENGTH_SEND_C(LENGTH_SEND_C),
        .LENGTH_SEND_P(LENGTH_SEND_P),
        .LENGTH_RECIEVED_C(LENGTH_RECIEVED_C),
        .LENGTH_RECIEVED_P(LENGTH_RECIEVED_P),
        .LENGTH_COUNT_C(LENGTH_COUNT_C),
        .LENGTH_COUNT_P(LENGTH_COUNT_P),
        .PERIPHERY_COUNT(PERIPHERY_COUNT),
        .PERIPHERY_SELECT(PERIPHERY_SELECT)
    ) dut (
    .rst(rst),
    .clk(clk),
    .start_comm(start_comm),
    .CS_in(CS_in),
    .data_send_c(data_send_c),
    .data_send_p(data_send_p),
    .data_in(data_in),
    .COPI_register(COPI_register),   
    .duty_high0(duty_high0), .duty_low0(duty_low0),
    .duty_high1(duty_high1), .duty_low1(duty_low1),
    .duty_high2(duty_high2), .duty_low2(duty_low2),
    .duty_high3(duty_high3), .duty_low3(duty_low3),
    .convst_bar(convst_bar),
    .mode_manual(mode_manual),
    .en_pwm(en_pwm),
    .freq_switch(freq_switch),
    .mon_duty_high(mon_duty_high),
    .mon_duty_low(mon_duty_low)
    );


    // ============================================================
    // Clock
    // ============================================================
    localparam int CLK_PERIOD_NS = 10;
    initial clk = 1'b0;
    always #(CLK_PERIOD_NS/2) clk = ~clk;

    // ============================================================
    // ====== (A) data_in sample generator (from tb_top) ===========
    // ============================================================
    integer sample_idx;
    integer seed_wave;

    function automatic [7:0] clamp_u8(input integer x);
        begin
        if (x < 0)        clamp_u8 = 8'd0;
        else if (x > 255) clamp_u8 = 8'd255;
        else              clamp_u8 = x[7:0];
        end
    endfunction

    function automatic [7:0] sample_gen(input integer kk);
        integer base;
        integer noise;
        begin
        noise = ($random(seed_wave) % 5) - 2; // -2..+2

        if (kk < 200) begin
            base = (192 * kk) / 200;  // ramp 0->192
        end else begin
            base = 192;

            if (kk == 260) base = 210;
            if (kk == 261) base = 185;
            if (kk == 262) base = 195;

            if (kk == 520) base = 175;
            if (kk == 521) base = 205;
            if (kk == 522) base = 192;

            if (kk == 780) base = 215;
            if (kk == 781) base = 182;
            if (kk == 782) base = 196;

            if (kk == 1020) base = 178;
            if (kk == 1021) base = 198;
            if (kk == 1022) base = 190;
        end

        sample_gen = clamp_u8(base + noise);
        end
    endfunction

    task automatic drive_next_sample;
        reg [7:0] s;
        begin
        s = sample_gen(sample_idx);
        data_in = s;
        sample_idx++;
        end
    endtask

    // 用 convst_bar 當取樣點（最貼近真實 ADC strobe）
    always @(negedge convst_bar) begin
        if (!rst) drive_next_sample();
    end

    // fallback：如果 convst_bar 壞掉，還是每 5us 更新一次
    initial begin
        wait(rst == 1'b0);
        forever begin
        #(5000);
        drive_next_sample();
        end
    end

    // ============================================================
    // ====== (B) SPI random tests (from SPI_TB) ===================
    // ============================================================
    // 你原本 TB 會偷看 dut 內部：
    //   dut.CIPO_register, dut.COPI_register_0..3
    // 所以這裡也照做（white-box）。
    //
    // 注意：你 DUT 內部 instance/訊號名字要對得上，
    // 若你在 SPI 裡面改名了，就要同步改這裡的階層路徑。
    //
    // 這裡假設：
    //   CIPO_register 在 SPI module 內叫 CIPO_register
    //   COPI_register_0..3 在 SPI module 內叫 COPI_register_0..3
    // ============================================================
    task automatic do_one_transaction;
        integer ncycles;
        begin
        start_comm <= 1'b1;

        // 一筆 transaction 等待時間
        ncycles = LENGTH_SEND_C + PAUSE + LENGTH_SEND_P + 4;

        repeat(ncycles) begin
            @(posedge clk);
            start_comm <= 1'b0;
        end

        #1;
        end
    endtask

    // 選 peripheral 對應的 COPI_register
    always @(*) begin
        case (CS_in)
        2'd0: COPI_register_compare = dut.COPI_register_0;
        2'd1: COPI_register_compare = dut.COPI_register_1;
        2'd2: COPI_register_compare = dut.COPI_register_2;
        default: COPI_register_compare = dut.COPI_register_3;
        endcase
    end

    initial begin
        // init
        SEED      = 15;
        seed_wave = 32'h1234ABCD;
        sample_idx = 0;

        rst        = 1'b1;
        start_comm = 1'b0;
        CS_in      = 2'd0;
        data_send_c = '0;
        data_send_p = '0;
        data_in     = 8'd0;

        // dump
        $dumpfile("tb_spi_top_combined.vcd");
        $dumpvars(0, tb_spi_top_combined);

        // reset hold
        #(200);
        rst = 1'b0;

        // ----------------------------------------------------------
        // Test 1: 固定 CS=0，隨機資料
        // ----------------------------------------------------------
        CS_in = 2'd0;
        for (k = 0; k < 10; k++) begin
        data_send_c = $dist_uniform(SEED, 0, (1<<LENGTH_SEND_C)-1);
        data_send_p = $dist_uniform(SEED, 0, (1<<LENGTH_SEND_P)-1);

        do_one_transaction();

        if (dut.CIPO_register === data_send_p)
            $display("[T1] MISO OK  sent_p=%h recv_c=%h iter=%0d", data_send_p, dut.CIPO_register, k);
        else begin
            $display("[T1] MISO FAIL sent_p=%h recv_c=%h iter=%0d", data_send_p, dut.CIPO_register, k);
            //$finish;
        end

        if (dut.COPI_register_0 === data_send_c)
            $display("[T1] MOSI OK  sent_c=%h recv_p0=%h iter=%0d", data_send_c, dut.COPI_register_0, k);
        else begin
            $display("[T1] MOSI FAIL sent_c=%h recv_p0=%h iter=%0d", data_send_c, dut.COPI_register_0, k);
            //$finish;
        end
        end
        $display("Test1 done.");

        // ----------------------------------------------------------
        // Test 2: busy 時重觸發 start_comm
        // ----------------------------------------------------------
        CS_in = 2'd0;
        for (k = 0; k < 10; k++) begin
        data_send_c = $dist_uniform(SEED, 0, (1<<LENGTH_SEND_C)-1);
        data_send_p = $dist_uniform(SEED, 0, (1<<LENGTH_SEND_P)-1);
        wait_rand   = $dist_uniform(SEED, 0, LENGTH_SEND_C+PAUSE+LENGTH_SEND_P);

        start_comm <= 1'b1;
        repeat(wait_rand) begin
            @(posedge clk);
            start_comm <= 1'b0;
        end
        @(posedge clk);
        start_comm <= 1'b1;

        repeat(LENGTH_SEND_C+PAUSE+LENGTH_SEND_P+3-wait_rand) begin
            @(posedge clk);
            start_comm <= 1'b0;
        end
        #1;

        if (dut.CIPO_register !== data_send_p) begin
            $display("[T2] MISO FAIL sent_p=%h recv_c=%h iter=%0d", data_send_p, dut.CIPO_register, k);
            //$finish;
        end

        if (dut.COPI_register_0 !== data_send_c) begin
            $display("[T2] MOSI FAIL sent_c=%h recv_p0=%h iter=%0d", data_send_c, dut.COPI_register_0, k);
            //$finish;
        end

        $display("[T2] OK iter=%0d", k);
        end
        $display("Test2 done.");

        // ----------------------------------------------------------
        // Test 3: 隨機 CS（注意：你的 SPI wrapper 目前若只 instantiate 一顆 peripheral，
        //        CS!=0 時會不成立！要真的 4 顆 peripheral 才能跑過）
        // ----------------------------------------------------------
        for (k = 0; k < 20; k++) begin
        data_send_c = $dist_uniform(SEED, 0, (1<<LENGTH_SEND_C)-1);
        data_send_p = $dist_uniform(SEED, 0, (1<<LENGTH_SEND_P)-1);
        CS_in       = $dist_uniform(SEED, 0, PERIPHERY_COUNT-1);

        do_one_transaction();

        if (dut.CIPO_register !== data_send_p) begin
            $display("[T3] MISO FAIL CS=%0d sent_p=%h recv_c=%h iter=%0d",
                    CS_in, data_send_p, dut.CIPO_register, k);
            //$finish;
        end

        if (COPI_register_compare !== data_send_c) begin
            $display("[T3] MOSI FAIL CS=%0d sent_c=%h recv_p=%h iter=%0d",
                    CS_in, data_send_c, COPI_register_compare, k);
            //$finish;
        end

        $display("[T3] OK CS=%0d iter=%0d", CS_in, k);
        end
        $display("Test3 done.");

        // 跑久一點看波形
        #(5_000_000);
        $finish;
    end

    endmodule
