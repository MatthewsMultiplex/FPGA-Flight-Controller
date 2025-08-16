// filename: uart.v
`timescale 1ns/1ps

module uart #(
    parameter integer CLK_HZ = 125_000_000,
    parameter integer BAUD   = 115200
)(
    input  wire       clk,
    input  wire       reset,

    // TX side
    input  wire       ld_tx_data,       // 1-cycle strobe to load tx_data
    input  wire [7:0] tx_data,
    output wire       tx_ready,         // high when TX is idle/ready
    output reg        tx_done,          // 1-cycle at end of stop bit
    output reg        tx_serial,        // UART TX line

    // RX side
    input  wire       rx_serial,        // UART RX line
    output reg        rx_valid,         // 1-cycle when new byte ready
    output reg  [7:0] rx_data
);
    localparam integer CLKS_PER_BIT = CLK_HZ / BAUD;

    // ---------------- TX ----------------
    localparam T_IDLE=0, T_START=1, T_DATA=2, T_STOP=3;
    reg [1:0]  tstate;
    reg [15:0] tcnt;
    reg [2:0]  tbit;
    reg [7:0]  tshift;
    reg        tx_busy;

    assign tx_ready = ~tx_busy;

    always @(posedge clk) begin
        if (reset) begin
            tstate<=T_IDLE; tcnt<=0; tbit<=0; tshift<=0; tx_serial<=1'b1; tx_busy<=1'b0; tx_done<=1'b0;
        end else begin
            tx_done <= 1'b0;
            case (tstate)
            T_IDLE: begin
                tx_serial <= 1'b1;
                if (ld_tx_data && !tx_busy) begin
                    tshift   <= tx_data;
                    tbit     <= 3'd0;
                    tcnt     <= 0;
                    tx_busy  <= 1'b1;
                    tstate   <= T_START;
                end
            end
            T_START: begin
                tx_serial <= 1'b0;
                if (tcnt == CLKS_PER_BIT-1) begin tcnt <= 0; tstate <= T_DATA; end
                else tcnt <= tcnt + 1;
            end
            T_DATA: begin
                tx_serial <= tshift[0];
                if (tcnt == CLKS_PER_BIT-1) begin
                    tcnt   <= 0;
                    tshift <= {1'b0, tshift[7:1]};
                    if (tbit == 3'd7) begin
                        tbit   <= 0;
                        tstate <= T_STOP;
                    end else begin
                        tbit   <= tbit + 1;
                    end
                end else tcnt <= tcnt + 1;
            end
            T_STOP: begin
                tx_serial <= 1'b1;
                if (tcnt == CLKS_PER_BIT-1) begin
                    tx_done <= 1'b1;
                    tx_busy <= 1'b0;
                    tcnt    <= 0;
                    tstate  <= T_IDLE;
                end else tcnt <= tcnt + 1;
            end
            default: tstate <= T_IDLE;
            endcase
        end
    end

    // ---------------- RX ----------------
    localparam R_IDLE=0, R_START=1, R_DATA=2, R_STOP=3;
    reg [1:0]  rstate;
    reg [15:0] rcnt;
    reg [2:0]  rbit;
    reg [7:0]  rshift;
    reg        rx_sync1, rx_sync2;

    // synchronize RX line
    always @(posedge clk) begin
        rx_sync1 <= rx_serial;
        rx_sync2 <= rx_sync1;
    end

    always @(posedge clk) begin
        if (reset) begin
            rstate<=R_IDLE; rcnt<=0; rbit<=0; rshift<=0; rx_valid<=1'b0; rx_data<=8'h00;
        end else begin
            rx_valid <= 1'b0;
            case (rstate)
            R_IDLE: begin
                if (rx_sync2 == 1'b0) begin
                    rstate <= R_START;
                    rcnt   <= 0;
                end
            end
            R_START: begin
                if (rcnt == (CLKS_PER_BIT>>1)) begin
                    if (rx_sync2 == 1'b0) begin
                        rcnt  <= 0;
                        rbit  <= 0;
                        rstate<= R_DATA;
                    end else rstate <= R_IDLE;
                end else rcnt <= rcnt + 1;
            end
            R_DATA: begin
                if (rcnt == CLKS_PER_BIT-1) begin
                    rcnt        <= 0;
                    rshift      <= {rx_sync2, rshift[7:1]};
                    if (rbit == 3'd7) begin
                        rbit   <= 0;
                        rstate <= R_STOP;
                    end else rbit <= rbit + 1;
                end else rcnt <= rcnt + 1;
            end
            R_STOP: begin
                if (rcnt == CLKS_PER_BIT-1) begin
                    rcnt    <= 0;
                    rx_data <= rshift;
                    rx_valid<= 1'b1;
                    rstate  <= R_IDLE;
                end else rcnt <= rcnt + 1;
            end
            default: rstate <= R_IDLE;
            endcase
        end
    end
endmodule
