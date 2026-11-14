# SPI Controller Using Constrained Random Verification

## 1. Project overview

This project implements an 8-bit SPI Master controller in synthesizable Verilog and verifies it using a SystemVerilog constrained-random testbench in QuestaSim.

The design targets SPI Mode 0:
- CPOL = 0: SCLK is low when idle.
- CPHA = 0: the receiver samples data on the rising SCLK edge.
- MSB-first transmission.
- Full-duplex data transfer.
- Active-low chip select (`cs_n`).
- Active-low asynchronous reset (`rst_n`).

## 2. Features

- FSM-controlled SPI master.
- Programmable system-clock divider parameter (`CLK_DIV`).
- 8-bit transmit and receive shift registers.
- MOSI and MISO data paths.
- `busy` status and one-clock-cycle `done` pulse.
- SystemVerilog transaction class with constraints.
- SPI Mode-0 slave model in the testbench.
- Automatic comparison of transmitted and received bytes.
- 20 constrained-random transactions by default.

## 3. Interface

| Signal | Direction | Description |
|---|---|---|
| `clk` | Input | System clock |
| `rst_n` | Input | Active-low asynchronous reset |
| `start` | Input | One-cycle transfer request |
| `tx_data[7:0]` | Input | Byte to transmit |
| `miso` | Input | Slave-to-master serial data |
| `rx_data[7:0]` | Output | Received byte, valid when `done` asserts |
| `busy` | Output | High during an SPI transfer |
| `done` | Output | One-system-clock completion pulse |
| `sclk` | Output | SPI serial clock |
| `cs_n` | Output | Active-low slave select |
| `mosi` | Output | Master-to-slave serial data |

## 4. Clock divider

The SCLK frequency is:

`f_SCLK = f_clk / (2 * CLK_DIV)`

The testbench instantiates the master with `CLK_DIV=2`. With a 100 MHz system clock, the generated SCLK frequency is 25 MHz.

`CLK_DIV` must be at least 1.

## 5. Files

```text
SPI_Controller_Constrained_Random_Verification/
├── rtl/
│   └── spi_master.v
├── tb/
│   └── spi_tb.sv
├── docs/
├── run.do
├── .gitignore
└── README.md
```

## 6. Run using QuestaSim GUI

Open QuestaSim and change the working directory to this project folder. In the Transcript window, execute:

```tcl
do run.do
```

The script creates the work library, compiles the Verilog RTL and SystemVerilog testbench, opens the simulation, adds useful waveforms and runs all tests.

Alternatively, run the commands individually:

```tcl
vlib work
vlog -sv rtl/spi_master.v tb/spi_tb.sv
vsim work.spi_tb
add wave -r /*
run -all
```

## 7. Expected verification

The testbench creates 20 randomized transmit/receive byte pairs within the declared constraints. For every transaction it checks:

1. The byte observed by the slave model on MOSI equals the master's input `tx_data`.
2. The master's `rx_data` equals the byte driven by the slave model on MISO.

A successful run should end with:

```text
SPI TEST SUMMARY: PASS=20 FAIL=0
ALL TESTS PASSED
```

This is the expected result, not a recorded simulation result. Run the project in your own QuestaSim installation and retain the actual Transcript and waveform evidence.

## 8. Waveform checks

Inspect:
- `cs_n`: goes low for the transaction and returns high at completion.
- `sclk`: idles low and produces 16 edges (8 rising and 8 falling) per byte.
- `mosi`: presents bits MSB first and is stable at each rising sampling edge.
- `miso`: slave data is presented before each rising sampling edge.
- `busy`: remains high while the byte is transferred.
- `done`: pulses high for one system-clock cycle after the final bit.
- `rx_data`: updates with the received byte at completion.

## 9. Limitations and possible extensions

This is a learning-scale SPI Mode-0, single-slave, 8-bit master. It does not yet implement:
- SPI Modes 1, 2 and 3.
- Multiple slave-select outputs.
- Variable transfer lengths.
- FIFO buffering or bus interfaces.
- Assertions, functional coverage or UVM.

Possible next improvements:
- Add CPOL/CPHA mode selection.
- Add parameterized data width.
- Add assertions and functional coverage.
- Add back-to-back transaction testing.
- Synthesize the RTL and inspect area/timing reports.

## 10. Important engineering note

The RTL is Verilog-2001. The testbench uses SystemVerilog class randomization and constraints, so compile with QuestaSim's `vlog -sv` option. The provided files are a starter implementation; compile and simulate them in your installed QuestaSim version, investigate any tool-specific errors, and only publish verified results.
