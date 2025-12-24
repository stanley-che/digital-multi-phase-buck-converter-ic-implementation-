// ============================================================
// Shift-Register Phase-Shifter (iverilog-friendly)
// - Same duty, phase shift by delay taps
// - Avoid always_comb + constant select issue in iverilog
// ============================================================
module shift_register_phase_shifter #(
    parameter integer PERIOD  = 128, // ticks per PWM period
    parameter integer NPHASES = 4     // number of phases
)(
    input  wire                  clk,
    input  wire                  rst,     // synchronous reset
    input  wire                  en,
    input  wire                  pwm_in,
    output wire [NPHASES-1:0]    pwm_ph
);

    reg [PERIOD-1:0] shreg;

    localparam integer PHASE_STEP = (NPHASES == 0) ? 0 : (PERIOD / NPHASES);

    // shift register
    always @(posedge clk) begin
        if (rst) begin
            shreg <= {PERIOD{1'b0}};
        end else if (en) begin
            shreg <= {shreg[PERIOD-2:0], pwm_in};
        end
    end

    // phase taps (continuous assigns)
    genvar k;
    generate
        for (k = 0; k < NPHASES; k = k + 1) begin : GEN_TAPS
            localparam integer DLY = k * PHASE_STEP;

            if (k == 0 || DLY == 0) begin : TAP0
                assign pwm_ph[k] = pwm_in;
            end else if (DLY >= PERIOD) begin : TAPCLAMP
                assign pwm_ph[k] = shreg[PERIOD-1];
            end else begin : TAPD
                // DLY=1 -> shreg[0]
                assign pwm_ph[k] = shreg[DLY-1];
            end
        end
    endgenerate

endmodule
