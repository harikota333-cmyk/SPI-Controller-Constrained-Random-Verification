// SystemVerilog testbench for spi_master
// Uses constrained-random transactions and a simple SPI slave model.

`timescale 1ns/1ps

module spi_tb;

    reg clk;
    reg rst_n;
    reg start;
    reg [7:0] tx_data;
    reg miso;

    wire [7:0] rx_data;
    wire busy;
    wire done;
    wire sclk;
    wire cs_n;
    wire mosi;

    reg [7:0] observed_tx;
    reg [7:0] expected_rx;

    integer pass_count;
    integer fail_count;
    integer i;

    spi_master #(
        .CLK_DIV(2)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .tx_data(tx_data),
        .miso(miso),
        .rx_data(rx_data),
        .busy(busy),
        .done(done),
        .sclk(sclk),
        .cs_n(cs_n),
        .mosi(mosi)
    );

    // 100 MHz system clock (10 ns period)
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Constrained-random transaction class.
    class spi_transaction;
        rand bit [7:0] tx_byte;
        rand bit [7:0] slave_byte;

        // Avoid only-zero/all-ones test data and exercise varied bit patterns.
        constraint legal_bytes {
            tx_byte    inside {[8'h10:8'hEF]};
            slave_byte inside {[8'h20:8'hDF]};
        }
    endclass

    // Simple SPI Mode-0 slave model:
    // Drives MISO before each rising edge and observes MOSI after that edge.
    task automatic spi_slave_model(
        input  reg [7:0] slave_byte,
        output reg [7:0] master_byte_seen
    );
        integer bit_index;
        begin
            master_byte_seen = 8'h00;
            @(negedge cs_n);
            miso = slave_byte[7];

            for (bit_index = 7; bit_index >= 0; bit_index = bit_index - 1) begin
                @(posedge sclk);
                #1 master_byte_seen[bit_index] = mosi;

                if (bit_index > 0) begin
                    @(negedge sclk);
                    #1 miso = slave_byte[bit_index-1];
                end
            end
        end
    endtask

    spi_transaction tr;

    initial begin
        rst_n       = 1'b0;
        start       = 1'b0;
        tx_data     = 8'h00;
        miso        = 1'b0;
        observed_tx = 8'h00;
        expected_rx = 8'h00;
        pass_count  = 0;
        fail_count  = 0;

        // Reset
        repeat (4) @(negedge clk);
        rst_n = 1'b1;
        repeat (2) @(negedge clk);

        tr = new();

        // Run 20 constrained-random SPI transactions
        for (i = 0; i < 20; i = i + 1) begin
            if (!tr.randomize()) begin
                $display("ERROR: Randomization failed at transaction %0d", i);
                $fatal(1);
            end

            tx_data     = tr.tx_byte;
            expected_rx = tr.slave_byte;
            observed_tx = 8'h00;

            // Start slave model before asserting the master start request.
            fork
                spi_slave_model(expected_rx, observed_tx);
            join_none

            @(negedge clk);
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;

            wait (done == 1'b1);
            wait fork;

            if ((rx_data === expected_rx) && (observed_tx === tx_data)) begin
                pass_count = pass_count + 1;
                $display("PASS txn=%0d TX=%02h RX=%02h", i,
                         observed_tx, rx_data);
            end else begin
                fail_count = fail_count + 1;
                $display("FAIL txn=%0d TX_expected=%02h TX_seen=%02h RX_expected=%02h RX_seen=%02h",
                         i, tx_data, observed_tx, expected_rx, rx_data);
            end

            @(negedge clk);
        end

        $display("-----------------------------------------");
        $display("SPI TEST SUMMARY: PASS=%0d FAIL=%0d",
                 pass_count, fail_count);
        $display("-----------------------------------------");

        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("TESTS FAILED - DEBUG THE RTL / TESTBENCH");

        #20;
        $finish;
    end

endmodule
