// SPI periphery (Verilog-2001)

module SPI_Periphery
#(
    parameter LENGTH_SEND     = 16,   // Peripheral --> Controller
    parameter LENGTH_RECIEVED = 16,   // Controller --> Peripheral
    parameter LENGTH_COUNT    = 6,   // counter width
    parameter PAUSE           = 10   // not used in this code (kept)
)
(
    input  logic                     rst,          // active-low in your comment, but logic uses rst&&~CS
    input  logic                     SCK,          // serial clock
    input  logic                     COPI,         // MOSI
    input  logic                       CS,           // chip select (active low)
    input  logic [LENGTH_SEND-1:0]     data_send,    // data sent to controller
    output logic                        CIPO,         // MISO
    output logic  [LENGTH_RECIEVED-1:0] COPI_register
);

    // Internal registers
    logic [LENGTH_SEND-1:0]  CIPO_register;
    logic [LENGTH_COUNT-1:0] count;
    
    // Internal reset enable (active     when rst=1 and CS=0)
    logic rst_internal;
    assign rst_internal = rst && ~CS;

    // ============================================================
    // Receive data from controller on posedge SCK
    // ============================================================
    always @(posedge SCK or negedge rst_internal) begin
        if (!rst_internal) begin
            count         <= {LENGTH_COUNT{1'b0}};
            COPI_register <= {LENGTH_RECIEVED{1'b0}};
        end else if (count < LENGTH_RECIEVED) begin
            COPI_register <= {COPI, COPI_register[LENGTH_RECIEVED-1:1]};
            count         <= count + 1'b1;
        end else if (count < (LENGTH_RECIEVED + LENGTH_SEND)) begin
            count         <= count + 1'b1;
        end else if (count == (LENGTH_RECIEVED + LENGTH_SEND)) begin
            count         <= {LENGTH_COUNT{1'b0}};
        end
    end

    // ============================================================
    // Send data to controller on negedge SCK
    // ============================================================
    always @(negedge SCK or negedge rst_internal) begin
        if (!rst_internal) begin
            // tri-state style (note: real tri-state only works on top-level IO pads)
            CIPO          <= (~CS) ? 1'b0 : 1'bx;
            CIPO_register <= {LENGTH_SEND{1'b0}};
        end else if (count == LENGTH_RECIEVED) begin
            // sample outgoing data
            CIPO_register <= data_send;
        end else if (count < (LENGTH_RECIEVED + LENGTH_SEND + 2)) begin
            CIPO          <= (~CS) ? CIPO_register[0] : 1'bx;
            CIPO_register <= (CIPO_register >> 1);
        end
    end

endmodule
