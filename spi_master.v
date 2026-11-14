// Project: SPI Controller Using Constrained Random Verification
// SPI Mode: 0 (CPOL=0, CPHA=0), 8-bit, MSB-first
// Synthesizable Verilog-2001 RTL

module spi_master #(
    parameter integer CLK_DIV = 2
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,
    input  wire [7:0] tx_data,
    input  wire       miso,

    output reg  [7:0] rx_data,
    output reg        busy,
    output reg        done,
    output reg        sclk,
    output reg        cs_n,
    output reg        mosi
);

    localparam [1:0] ST_IDLE     = 2'b00;
    localparam [1:0] ST_TRANSFER = 2'b01;

    reg [1:0] state;
    reg [7:0] tx_shift;
    reg [7:0] rx_shift;
    reg [2:0] bit_count;
    integer   clk_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= ST_IDLE;
            tx_shift  <= 8'h00;
            rx_shift  <= 8'h00;
            bit_count <= 3'd0;
            clk_count <= 0;
            rx_data   <= 8'h00;
            busy      <= 1'b0;
            done      <= 1'b0;
            sclk      <= 1'b0;
            cs_n      <= 1'b1;
            mosi      <= 1'b0;
        end else begin
            // done is a one-system-clock pulse
            done <= 1'b0;

            case (state)
                ST_IDLE: begin
                    sclk      <= 1'b0;
                    cs_n      <= 1'b1;
                    busy      <= 1'b0;
                    clk_count <= 0;

                    if (start) begin
                        tx_shift  <= tx_data;
                        rx_shift  <= 8'h00;
                        bit_count <= 3'd7;
                        mosi      <= tx_data[7];
                        cs_n      <= 1'b0;
                        busy      <= 1'b1;
                        state     <= ST_TRANSFER;
                    end
                end

                ST_TRANSFER: begin
                    if (clk_count == (CLK_DIV - 1)) begin
                        clk_count <= 0;

                        if (sclk == 1'b0) begin
                            // Mode 0: sample MISO on rising SCLK edge
                            sclk     <= 1'b1;
                            rx_shift <= {rx_shift[6:0], miso};
                        end else begin
                            // Falling SCLK edge: prepare next MOSI bit
                            sclk <= 1'b0;

                            if (bit_count == 3'd0) begin
                                // Last bit was sampled on the previous rising edge
                                rx_data <= rx_shift;
                                cs_n    <= 1'b1;
                                busy    <= 1'b0;
                                done    <= 1'b1;
                                mosi    <= 1'b0;
                                state   <= ST_IDLE;
                            end else begin
                                bit_count <= bit_count - 1'b1;
                                tx_shift  <= {tx_shift[6:0], 1'b0};
                                mosi      <= tx_shift[6];
                            end
                        end
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end

                default: begin
                    state     <= ST_IDLE;
                    sclk      <= 1'b0;
                    cs_n      <= 1'b1;
                    busy      <= 1'b0;
                    clk_count <= 0;
                end
            endcase
        end
    end

    // CLK_DIV must be >= 1. SCLK frequency = clk / (2 * CLK_DIV).
endmodule
