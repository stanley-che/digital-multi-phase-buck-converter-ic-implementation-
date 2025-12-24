`timescale 1ns/1ns
module stanley (
    input              clk,
    input              rst,
    input      [3:0]   err_in,
    output     [9:0]   d_comp
);

    reg  [3:0] en, en1, en2, en3;

    // ?? signed 16-bit?????????
    reg  signed [15:0] ae_product, be_product, ce_product, de_product;
    reg  signed [15:0] d_n_1, d_n_reg;

    // 18-bit ??????? overflow?
    wire signed [17:0] d_n_pre_wide;

    // 0.95 duty ?????? 16-bit ???
    localparam signed [15:0] DUTY_MAX      = 16'b0111100011001101;
    localparam signed [17:0] DUTY_MAX_WIDE = {{2{DUTY_MAX[15]}}, DUTY_MAX};

    // ===== delay chain =====
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            en    <= 4'd0;
            en1   <= 4'd0;
            en2   <= 4'd0;
            en3   <= 4'd0;
            d_n_1 <= 16'd0;
        end else begin
            en    <= err_in;   // e[n]
            en1   <= en;       // e[n-1]
            en2   <= en1;      // e[n-2]
            en3   <= en2;      // e[n-3]
            d_n_1 <= d_n_reg;  // ?????????????
        end
    end

    // ===== 18-bit ????? sign-extend ???? =====
    assign d_n_pre_wide =
          {{2{ae_product[15]}}, ae_product} +
          {{2{be_product[15]}}, be_product} +
          {{2{ce_product[15]}}, ce_product} +
          {{2{de_product[15]}}, de_product} +
          {{2{d_n_1[15]}},     d_n_1};

    // ===== LUT A =====
    always @(*) begin
        case (en)
            4'b1100: ae_product = 16'b1110100000000000; 
            4'b1101: ae_product = 16'b1110111000000000;
            4'b1110: ae_product = 16'b1111010000000000;
            4'b1111: ae_product = 16'b1111101000000000;
            4'b0000: ae_product = 16'b0000000000000000;
            4'b0001: ae_product = 16'b0000011000000000;
            4'b0010: ae_product = 16'b0000110000000000;
            4'b0011: ae_product = 16'b0001001000000000;
            4'b0100: ae_product = 16'b0001100000000000;
            default: ae_product = 16'd0;
        endcase
    end

    // ===== LUT B =====
    always @(*) begin
        case (en1)
            4'b1100: be_product = 16'b0001001111110100;
            4'b1101: be_product = 16'b0000111011110111;
            4'b1110: be_product = 16'b0000100111111010;
            4'b1111: be_product = 16'b0000010011111101;
            4'b0000: be_product = 16'b0000000000000000;
            4'b0001: be_product = 16'b1111101100000011;
            4'b0010: be_product = 16'b1111011000000110;
            4'b0011: be_product = 16'b1111000100001001;
            4'b0100: be_product = 16'b1110110000001100;
            default: be_product = 16'd0;
        endcase
    end

    // ===== LUT C =====
    always @(*) begin
        case (en2)
            4'b1100: ce_product = 16'b0001011111111100;
            4'b1101: ce_product = 16'b0001000111111101;
            4'b1110: ce_product = 16'b0000101111111110;
            4'b1111: ce_product = 16'b0000010111111111;
            4'b0000: ce_product = 16'b0000000000000000;
            4'b0001: ce_product = 16'b1111101000000001;
            4'b0010: ce_product = 16'b1111010000000010;
            4'b0011: ce_product = 16'b1110111000000011;
            4'b0100: ce_product = 16'b1110100000000100;
            default: ce_product = 16'd0;
        endcase
    end

    // ===== LUT D =====
    always @(*) begin
        case (en3)
            4'b1100: de_product = 16'b1110110000001000; // -4
            4'b1101: de_product = 16'b1111000100000110; // -3
            4'b1110: de_product = 16'b1111011000000100; // -2
            4'b1111: de_product = 16'b1111101100000010; // -1
            4'b0000: de_product = 16'b0000000000000000; //  0
            4'b0001: de_product = 16'b0000010011111110; // +1
            4'b0010: de_product = 16'b0000100111111100; // +2
            4'b0011: de_product = 16'b0000111011111010; // +3
            4'b0100: de_product = 16'b0001001111111000; // +4
            default: de_product = 16'd0;
        endcase
    end

    // ===== limiter =====
    always @(d_n_pre_wide) begin
        if (d_n_pre_wide < 0)
            d_n_reg = 16'd0;
        else if (d_n_pre_wide > DUTY_MAX_WIDE)
            d_n_reg = DUTY_MAX;
        else
            d_n_reg = d_n_pre_wide[15:0];
    end

    // duty 
    assign d_comp = d_n_reg[15:6];

endmodule


