// =====================================================================
//  marx_gen1_controller.v
//  Student: Arash Rahmatian
//  Purpose : Generates the exact switching sequence (SL, SC, S1..S4)
//            for "Design 1" of the Marx-based HV pulse generator
//            (Kholgh Khiz & Banaei, Int J Circ Theor Appl. 2022;50(4):1101-1118),
//            sized for n = 4 modules, fs = 1 kHz, D1 = 0.9088, D2 = 0.0912,
//            5*tau (discharge window) = 62.5 us.
//
//  Timeline per period Ts = 1/fs :
//      [0                , T_DISCHARGE)      : SL=1, S1=S2=S3=S4=1  (HV pulse to load)
//      [T_DISCHARGE       , T_SL_END)         : SL=1, S1..S4=0        (inductor charging)
//      [T_SL_END          , T_SC_START)       : SL=0, SC=0            (dead time #1)
//      [T_SC_START        , T_SC_END)         : SC=1                  (capacitors charging)
//      [T_SC_END          , T_PERIOD)         : SL=0, SC=0            (dead time #2)
//      -> wraps back to 0 (next period: SL & S1..S4 turn on together again)
//
//  IMPORTANT SAFETY NOTE:
//      SL and SC must NEVER be high at the same time (it would short Vin
//      through the SL/SC path). A configurable dead time is inserted
//      around every SL<->SC transition to guard against gate-driver /
//      opto-isolator propagation-delay mismatches in real hardware.
//
//  All outputs are registered (glitch-free) logic-level (0/3.3V or 0/5V
//  depending on your FPGA I/O bank) signals meant to feed the LED side
//  of the isolated gate-driver opto-couplers (e.g. HCPL-3120) discussed
//  in the accompanying design report -- NOT the power MOSFET/IGBT gates
//  directly.
// =====================================================================

module marx_gen1_controller #(
    parameter integer CLK_FREQ_HZ      = 50_000_000, // <-- SET to your board's actual system clock (Hz)
    parameter integer PWM_FREQ_HZ      = 1_000,       // fs : pulse repetition frequency (Hz)
    parameter integer DISCHARGE_X10000 = 625,          // (5*tau / Ts) * 10000  ->  6.25%  = 625
    parameter integer D1_X10000        = 9088,         // D1 (SL duty)          -> 90.88%  = 9088
    parameter integer DEAD_TIME_CYCLES = 50            // dead time between SL and SC, in clk cycles
)(
    input  wire clk,       // system clock
    input  wire rst_n,     // asynchronous active-low reset
    input  wire enable,    // global enable; LOW forces all outputs to the safe (all-off) state
    output reg  SL,        // input-inductor charging switch
    output reg  SC,        // capacitor-charging switch
    output reg  S1,        // module-1 discharge switch
    output reg  S2,        // module-2 discharge switch
    output reg  S3,        // module-3 discharge switch
    output reg  S4         // module-4 discharge switch
);

    // ------------------------------------------------------------------
    // Derived timing constants (computed once, at elaboration time only)
    // ------------------------------------------------------------------
    localparam integer T_PERIOD    = CLK_FREQ_HZ / PWM_FREQ_HZ;                  // Ts, in clock cycles
    localparam integer T_DISCHARGE = (T_PERIOD * DISCHARGE_X10000) / 10000;      // 5*tau, in clock cycles
    localparam integer T_SL_RAW    = (T_PERIOD * D1_X10000)        / 10000;      // D1*Ts (before dead-time trim)
    localparam integer T_SL_END    = T_SL_RAW - DEAD_TIME_CYCLES;               // SL actually turns off here
    localparam integer T_SC_START  = T_SL_RAW;                                  // SC turns on here
    localparam integer T_SC_END    = T_PERIOD - DEAD_TIME_CYCLES;               // SC turns off here

    // Counter width: enough bits to hold (T_PERIOD - 1)
    localparam integer CNT_WIDTH = 32; // generous fixed width; trims fine in synthesis

    reg [CNT_WIDTH-1:0] cnt;
    reg discharge_int, sl_int, sc_int;

    // ------------------------------------------------------------------
    // Free-running period counter (0 .. T_PERIOD-1), synchronous reset
    // on !enable so re-enabling always restarts cleanly at the start of
    // a period (SL + discharge switches turning on together).
    // ------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cnt <= {CNT_WIDTH{1'b0}};
        else if (!enable)
            cnt <= {CNT_WIDTH{1'b0}};
        else if (cnt == T_PERIOD - 1)
            cnt <= {CNT_WIDTH{1'b0}};
        else
            cnt <= cnt + 1'b1;
    end

    // ------------------------------------------------------------------
    // Combinational region decode (pure function of cnt)
    // ------------------------------------------------------------------
    always @(*) begin
        discharge_int = 1'b0;
        sl_int        = 1'b0;
        sc_int        = 1'b0;

        if (cnt < T_DISCHARGE) begin
            // 0 .. T_DISCHARGE-1 : HV discharge pulse (S1..S4 ON, SL also ON)
            discharge_int = 1'b1;
            sl_int        = 1'b1;
        end
        else if (cnt < T_SL_END) begin
            // T_DISCHARGE .. T_SL_END-1 : SL alone ON, inductor continues charging
            sl_int = 1'b1;
        end
        else if (cnt < T_SC_START) begin
            // T_SL_END .. T_SC_START-1 : dead time #1 (SL and SC both OFF)
        end
        else if (cnt < T_SC_END) begin
            // T_SC_START .. T_SC_END-1 : SC ON, capacitors charge from inductor
            sc_int = 1'b1;
        end
        else begin
            // T_SC_END .. T_PERIOD-1 : dead time #2 (SL and SC both OFF)
        end
    end

    // ------------------------------------------------------------------
    // Registered outputs (one clock of latency, glitch-free)
    // ------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || !enable) begin
            SL <= 1'b0;
            SC <= 1'b0;
            S1 <= 1'b0;
            S2 <= 1'b0;
            S3 <= 1'b0;
            S4 <= 1'b0;
        end else begin
            SL <= sl_int;
            SC <= sc_int;
            S1 <= discharge_int;
            S2 <= discharge_int;
            S3 <= discharge_int;
            S4 <= discharge_int;
        end
    end

    // ------------------------------------------------------------------
    // Synthesis-time sanity checks (elaboration-time assertions)
    // ------------------------------------------------------------------
    initial begin
        if (T_DISCHARGE <= 0)
            $error("T_DISCHARGE computed as <= 0 -- check DISCHARGE_X10000 / clock settings");
        if (T_SL_END <= T_DISCHARGE)
            $error("Dead time too large relative to SL window -- reduce DEAD_TIME_CYCLES or increase CLK_FREQ_HZ");
        if (T_SC_END <= T_SC_START)
            $error("Dead time too large relative to SC window -- reduce DEAD_TIME_CYCLES or increase CLK_FREQ_HZ");
    end

endmodule
