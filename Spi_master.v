// filename: spi_master.v
`timescale 1ns/1ps

module spi_master #(
    parameter integer CLKS_PER_HALF_SCLK = 6, // SCLK = clk/(2*CLKS_PER_HALF_SCLK)
    parameter         CPOL = 1'b0,
    parameter         CPHA = 1'b0
)(
    input  wire       clk,
    input  wire       reset,

    input  wire       start,         // pulse to begin a burst
    input  wire [7:0] nbytes,        // total bytes in this burst

    input  wire [7:0] tx_data,       // present next byte when tx_ready=1 and assert tx_valid
    input  wire       tx_valid,
    output reg        tx_ready,

    output reg  [7:0] rx_data,       // valid when rx_valid=1
    output reg        rx_valid,

    output reg        busy,
    output reg        done,          // 1-cycle at end of burst

    output reg        MOSI,
    input  wire       MISO,
    output reg        SCLK,
    output reg        CS
);
    // timing
    reg [15:0] dcnt;
    reg        sclk_en;

    // counters
    reg [7:0]  bytes_total;
    reg [7:0]  bytes_sent;
    reg [2:0]  bitcnt;

    // shifters
    reg [7:0]  sh_out;
    reg [7:0]  sh_in;

    // FSM
    localparam ST_IDLE=0, ST_LOAD=1, ST_SHIFT=2, ST_NEXT=3, ST_DONE=4;
    reg [2:0] state;

    wire sclk_base = CPOL ? 1'b1 : 1'b0;

    // default outputs
    always @(posedge clk) begin
        if (reset) begin
            state<=ST_IDLE; dcnt<=0; sclk_en<=0;
            SCLK<=sclk_base; CS<=1'b1; MOSI<=1'b0;
            tx_ready<=1'b0; rx_valid<=1'b0; rx_data<=8'h00;
            busy<=1'b0; done<=1'b0;
            bytes_total<=0; bytes_sent<=0; bitcnt<=0; sh_out<=0; sh_in<=0;
        end else begin
            done     <= 1'b0;
            rx_valid <= 1'b0;
            tx_ready <= 1'b0;

            case (state)
            ST_IDLE: begin
                SCLK <= sclk_base;
                CS   <= 1'b1;
                busy <= 1'b0;
                sclk_en <= 1'b0;
                if (start && nbytes!=0) begin
                    busy        <= 1'b1;
                    bytes_total <= nbytes;
                    bytes_sent  <= 8'd0;
                    CS          <= 1'b0;   // assert CS
                    state       <= ST_LOAD;
                end
            end

            ST_LOAD: begin
                // request a byte from upstream
                tx_ready <= 1'b1;
                if (tx_valid) begin
                    sh_out  <= tx_data;
                    bitcnt  <= 3'd7;
                    dcnt    <= 0;
                    SCLK    <= sclk_base;
                    sclk_en <= 1'b1;
                    // if CPHA=0, first data is valid before first rising edge
                    MOSI    <= tx_data[7];
                    state   <= ST_SHIFT;
                end
            end

            ST_SHIFT: begin
                // clock generator
                if (dcnt == CLKS_PER_HALF_SCLK-1) begin
                    dcnt <= 0;
                    SCLK <= ~SCLK;

                    // Mode 0: sample on rising edge, shift on falling edge
                    if (CPHA==1'b0) begin
                        if (SCLK == 1'b0) begin
                            // rising edge next
                            // sample MISO on rising edge
                            // but we are toggling now to 1: sample now
                            sh_in[bitcnt] <= MISO;
                        end else begin
                            // falling edge next: shift out next bit
                            if (bitcnt != 0) begin
                                bitcnt <= bitcnt - 1;
                                MOSI   <= sh_out[bitcnt-1];
                            end else begin
                                // completed 8 bits (we just drove last falling edge)
                                state <= ST_NEXT;
                                sclk_en <= 1'b0;
                            end
                        end
                    end else begin
                        // CPHA=1 not used here; keeping simple
                        // (extend if you need other modes)
                    end
                end else begin
                    dcnt <= dcnt + 1;
                end
            end

            ST_NEXT: begin
                rx_data  <= sh_in;
                rx_valid <= 1'b1;
                bytes_sent <= bytes_sent + 1;
                SCLK <= sclk_base;

                if (bytes_sent == bytes_total) begin
                    // should not happen; guard
                    state <= ST_DONE;
                end else if (bytes_sent == bytes_total-1) begin
                    // last byte was just received
                    state <= ST_DONE;
                end else begin
                    // request next byte
                    state <= ST_LOAD;
                end
            end

            ST_DONE: begin
                CS   <= 1'b1;
                busy <= 1'b0;
                done <= 1'b1;
                state<= ST_IDLE;
            end

            default: state <= ST_IDLE;
            endcase
        end
    end
endmodule
