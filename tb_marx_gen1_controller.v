// =====================================================================
//  tb_marx_gen1_controller.v
//  Student: Arash Rahmatian
//  Shiraz University of Technology
//  Simulation-only testbench for marx_gen1_controller.
//  - Instantiates the controller with a 50 MHz clock (20 ns period).
//  - Applies reset, then enable, and runs for 3 full switching periods
//    (3 x 1 ms) so you can visually confirm SL / SC / S1..S4 timing
//    against the design's timing diagram (SL~908.8us, SC~91.2us,
//    discharge~62.5us, with dead time around the SL<->SC transitions).
//  - Contains a continuous safety assertion: SL and SC must never be
//    high at the same clock edge. If they are, simulation stops
//    immediately with a FATAL message (this is exactly the condition
//    that would short-circuit Vin in real hardware).
//
//  Run in any standard simulator (ModelSim/QuestaSim, Xilinx XSIM,
//  Icarus Verilog, Verilator, etc.). A .vcd waveform file is produced
//  for viewing in GTKWave or your simulator's waveform viewer.
// =====================================================================

`timescale 1ns/1ps

module tb_marx_gen1_controller;

    reg clk   = 1'b0;
    reg rst_n = 1'b0;
    reg enable = 1'b0;

    wire SL, SC, S1, S2, S3, S4;

    // 50 MHz system clock -> 20 ns period (10 ns high, 10 ns low)
    always #10 clk = ~clk;

    marx_gen1_controller #(
        .CLK_FREQ_HZ      (50_000_000),
        .PWM_FREQ_HZ      (1_000),
        .DISCHARGE_X10000 (625),
        .D1_X10000        (9088),
        .DEAD_TIME_CYCLES (50)
    ) dut (
        .clk    (clk),
        .rst_n  (rst_n),
        .enable (enable),
        .SL     (SL),
        .SC     (SC),
        .S1     (S1),
        .S2     (S2),
        .S3     (S3),
        .S4     (S4)
    );

    // ---------------- Stimulus ----------------
    initial begin
        $dumpfile("marx_gen1_tb.vcd");
        $dumpvars(0, tb_marx_gen1_controller);

        rst_n  = 1'b0;
        enable = 1'b0;
        #100;                 // hold reset for 100 ns
        rst_n  = 1'b1;
        #40;
        enable = 1'b1;        // start the controller

        // Run for 3 full periods (3 x 1,000,000 ns = 3 ms)
        #3_000_000;

        $display("Simulation finished normally at time %0t ns.", $time);
        $finish;
    end

    // ---------------- Safety assertion ----------------
    // SL and SC must be mutually exclusive at all times.
    always @(posedge clk) begin
        if (SL && SC) begin
            $display("FATAL @ %0t ns : SL and SC are BOTH HIGH -- shoot-through / Vin short risk!", $time);
            $stop;
        end
    end

    // ---------------- Optional textual trace ----------------
    // Prints a line every time any output changes, useful for a quick
    // sanity check without opening a waveform viewer.
    always @(SL or SC or S1 or S2 or S3 or S4) begin
        $display("t=%0t ns | SL=%b SC=%b S1=%b S2=%b S3=%b S4=%b",
                  $time, SL, SC, S1, S2, S3, S4);
    end

endmodule
