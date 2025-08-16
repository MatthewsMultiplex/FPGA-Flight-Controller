// filename: Formatting_FSM.v
// Sends: "Gyro X:0xXXXX | Y:0xXXXX | Z:0xXXXX\r\n"
// Handshake: start -> (streams bytes when tx_ready=1) -> done (1-cycle)
`timescale 1ns/1ps

module Formatting_FSM(
    input  wire        clk,
    input  wire        reset,

    input  wire        start,
    output reg         done,

    input  wire signed [15:0] gx,
    input  wire signed [15:0] gy,
    input  wire signed [15:0] gz,

    output reg  [7:0]  tx_data,
    output reg         tx_valid,
    input  wire        tx_ready
);
    // ---- hex helpers (no divide) ----
    function [7:0] hex8;
        input [3:0] n;
        begin
            hex8 = (n < 10) ? (8'd48 + n[3:0]) : (8'd55 + n[3:0]); // '0'..'9','A'..'F'
        end
    endfunction

    // hold snapshot so values don't change mid-line
    reg [15:0] gx_r, gy_r, gz_r;

    // which byte are we sending
    localparam S_IDLE=2'd0, S_SEND=2'd1, S_DONE=2'd2;
    reg [1:0]  state;
    reg [5:0]  idx; // up to ~44 chars

    // map idx -> byte
    reg [7:0] ch;

    always @* begin
        case (idx)
            // "Gyro X:0x"
            0:  ch=8'd71;  // G
            1:  ch=8'd121; // y
            2:  ch=8'd114; // r
            3:  ch=8'd111; // o
            4:  ch=8'd32;  // space
            5:  ch=8'd88;  // X
            6:  ch=8'd58;  // :
            7:  ch=8'd48;  // 0
            8:  ch=8'd120; // x
            9:  ch=hex8(gx_r[15:12]);
            10: ch=hex8(gx_r[11:8]);
            11: ch=hex8(gx_r[7:4]);
            12: ch=hex8(gx_r[3:0]);
            13: ch=8'd32;  // space
            14: ch=8'd124; // |
            15: ch=8'd32;  // space
            // "Y:0x"
            16: ch=8'd89;  // Y
            17: ch=8'd58;  // :
            18: ch=8'd48;  // 0
            19: ch=8'd120; // x
            20: ch=hex8(gy_r[15:12]);
            21: ch=hex8(gy_r[11:8]);
            22: ch=hex8(gy_r[7:4]);
            23: ch=hex8(gy_r[3:0]);
            24: ch=8'd32;  // space
            25: ch=8'd124; // |
            26: ch=8'd32;  // space
            // "Z:0x"
            27: ch=8'd90;  // Z
            28: ch=8'd58;  // :
            29: ch=8'd48;  // 0
            30: ch=8'd120; // x
            31: ch=hex8(gz_r[15:12]);
            32: ch=hex8(gz_r[11:8]);
            33: ch=hex8(gz_r[7:4]);
            34: ch=hex8(gz_r[3:0]);
            35: ch=8'd13;  // CR
            36: ch=8'd10;  // LF
            default: ch=8'd10;
        endcase
    end

    always @(posedge clk) begin
        if (reset) begin
            state<=S_IDLE; idx<=0; tx_valid<=0; tx_data<=0; done<=0;
            gx_r<=0; gy_r<=0; gz_r<=0;
        end else begin
            tx_valid <= 1'b0;
            done     <= 1'b0;

            case (state)
            S_IDLE: begin
                if (start) begin
                    gx_r  <= gx;
                    gy_r  <= gy;
                    gz_r  <= gz;
                    idx   <= 0;
                    state <= S_SEND;
                end
            end

            S_SEND: begin
                if (tx_ready) begin
                    tx_data  <= ch;
                    tx_valid <= 1'b1;
                    if (idx == 6'd36) state <= S_DONE;
                    else               idx   <= idx + 1'b1;
                end
            end

            S_DONE: begin
                done  <= 1'b1;   // one-cycle pulse
                state <= S_IDLE;
            end

            default: state <= S_IDLE;
            endcase
        end
    end
