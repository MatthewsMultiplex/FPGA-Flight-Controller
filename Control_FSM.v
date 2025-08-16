// filename: Control_FSM.v
`timescale 1ns/1ps

module Control_FSM #(
    parameter integer SAMPLE_DIV = 125_000, // 1 kHz at 125 MHz
    parameter [7:0]   BASE_DUTY  = 8'd0,    // motors off when level (no H-bridge)
    parameter integer KP_SHIFT   = 10,
    parameter integer Kp         = 32,
    parameter integer DEADBAND   = 50
)(
    input  wire        clk,
    input  wire        reset,

    // IMU handshake
    output reg         imu_start,
    input  wire        imu_busy,
    input  wire        imu_valid,
    input  wire signed [15:0] gx,
    input  wire signed [15:0] gy,
    input  wire signed [15:0] gz,

    // Formatter handshake
    output reg         tx_start,
    input  wire        tx_done,

    // PWM duties
    output reg  [7:0]  duty_left,
    output reg  [7:0]  duty_right
);
    // sample timer
    reg [31:0] divcnt;

    // target duties before slew
    reg [7:0] tgt_left, tgt_right;

    // slew-limited outputs
    reg [7:0] duty_left_cur, duty_right_cur;
    localparam integer SLEW_STEP = 1;

    function [7:0] clamp8;
        input signed [15:0] v;
        begin
            if (v < 0) clamp8 = 8'd0;
            else if (v > 255) clamp8 = 8'd255;
            else clamp8 = v[7:0];
        end
    endfunction

    function [7:0] slew8;
        input [7:0] cur, tgt;
        reg signed [8:0] d;
        begin
            d = $signed({1'b0,tgt}) - $signed({1'b0,cur});
            if (d >  SLEW_STEP) slew8 = cur + SLEW_STEP[7:0];
            else if (d < -SLEW_STEP) slew8 = cur - SLEW_STEP[7:0];
            else slew8 = tgt;
        end
    endfunction

    // FSM
    localparam S_IDLE=0, S_KICK=1, S_WAIT=2, S_PROC=3, S_FMT=4;
    reg [2:0] state;

    always @(posedge clk) begin
        if (reset) begin
            divcnt         <= 0;
            imu_start      <= 0;
            tx_start       <= 0;
            state          <= S_IDLE;
            duty_left      <= BASE_DUTY;
            duty_right     <= BASE_DUTY;
            duty_left_cur  <= BASE_DUTY;
            duty_right_cur <= BASE_DUTY;
            tgt_left       <= BASE_DUTY;
            tgt_right      <= BASE_DUTY;
        end else begin
            imu_start <= 1'b0;
            tx_start  <= 1'b0;

            case (state)
            S_IDLE: begin
                if (divcnt == SAMPLE_DIV-1) begin
                    divcnt    <= 0;
                    imu_start <= 1'b1; // 1-cycle pulse
                    state     <= S_KICK;
                end else begin
                    divcnt <= divcnt + 1;
                end
            end

            S_KICK: begin
                state <= S_WAIT;
            end

            S_WAIT: begin
                if (imu_valid && !imu_busy) state <= S_PROC;
            end

            S_PROC: begin
                // Use gy to decide which motor to push
                // positive gy -> speed up left; negative gy -> speed up right
                // deadband to avoid jitter
                if (gy >  $signed(DEADBAND)) begin
                    // left only speeds up
                    tgt_left  <= clamp8($signed(BASE_DUTY) + (($signed(gy) * Kp) >>> KP_SHIFT));
                    tgt_right <= BASE_DUTY;
                end else if (gy < -$signed(DEADBAND)) begin
                    // right only speeds up
                    tgt_left  <= BASE_DUTY;
                    tgt_right <= clamp8($signed(BASE_DUTY) + ((-$signed(gy) * Kp) >>> KP_SHIFT));
                end else begin
                    // near level: both off
                    tgt_left  <= BASE_DUTY;
                    tgt_right <= BASE_DUTY;
                end

                // slew toward targets
                duty_left_cur  <= slew8(duty_left_cur,  tgt_left);
                duty_right_cur <= slew8(duty_right_cur, tgt_right);
                duty_left      <= duty_left_cur;
                duty_right     <= duty_right_cur;

                tx_start <= 1'b1; // one line per sample
                state    <= S_FMT;
            end

            S_FMT: begin
                if (tx_done) state <= S_IDLE;
            end

            default: state <= S_IDLE;
            endcase
        end
    end
endmodule

