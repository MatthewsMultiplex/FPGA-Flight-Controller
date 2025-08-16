// filename: mpu9250_spi_if.v
`timescale 1ns/1ps

module mpu9250_spi_if #(
    parameter integer CLKS_PER_HALF_SCLK = 6
)(
    input  wire        clk,
    input  wire        reset,

    input  wire        start,
    output wire        busy,
    output reg         valid,

    output reg  signed [15:0] gx,
    output reg  signed [15:0] gy,
    output reg  signed [15:0] gz,

    output wire MOSI,
    input  wire MISO,
    output wire SCLK,
    output wire CS
);
    localparam [7:0] REG_GYRO_XOUT_H = 8'h43;
    localparam [7:0] CMD_BYTE        = 8'h80 | REG_GYRO_XOUT_H; // read bit | addr
    localparam [7:0] TOTAL           = 8'd7; // 1 cmd + 6 data

    reg        m_start;
    reg [7:0]  m_nbytes;
    wire       m_busy, m_done;
    wire       m_tx_ready;
    reg  [7:0] m_tx_data;
    reg        m_tx_valid;
    wire [7:0] m_rx_data;
    wire       m_rx_valid;

    spi_master #(
        .CLKS_PER_HALF_SCLK(CLKS_PER_HALF_SCLK),
        .CPOL(1'b0),
        .CPHA(1'b0)
    ) u_spi (
        .clk      (clk),
        .reset    (reset),
        .start    (m_start),
        .nbytes   (m_nbytes),
        .tx_data  (m_tx_data),
        .tx_valid (m_tx_valid),
        .tx_ready (m_tx_ready),
        .rx_data  (m_rx_data),
        .rx_valid (m_rx_valid),
        .busy     (m_busy),
        .done     (m_done),
        .MOSI     (MOSI),
        .MISO     (MISO),
        .SCLK     (SCLK),
        .CS       (CS)
    );

    assign busy = m_busy;

    reg [2:0] state;
    localparam IDLE=0, START=1, SEND_CMD=2, SEND_DUMMIES=3, DONE=4;
    reg [2:0]  rx_idx;

    always @(posedge clk) begin
        if (reset) begin
            state<=IDLE; m_start<=0; m_nbytes<=0; m_tx_valid<=0; m_tx_data<=8'h00;
            rx_idx<=0; valid<=0; gx<=0; gy<=0; gz<=0;
        end else begin
            valid<=0; m_tx_valid<=0; m_start<=0;

            case(state)
            IDLE: begin
                if (start && !m_busy) begin
                    m_start  <= 1'b1;
                    m_nbytes <= TOTAL;
                    state    <= START;
                end
            end
            START: begin
                if (m_tx_ready) begin
                    m_tx_data  <= CMD_BYTE;  // READ + starting address
                    m_tx_valid <= 1'b1;
                    rx_idx     <= 0;
                    state      <= SEND_CMD;
                end
            end
            SEND_CMD: begin
                if (m_tx_ready) begin
                    m_tx_data  <= 8'h00;     // first dummy to clock in data
                    m_tx_valid <= 1'b1;
                    state      <= SEND_DUMMIES;
                end
                if (m_rx_valid) begin
                    if (rx_idx < 3'd7) rx_idx <= rx_idx + 1'b1; // discard cmd response
                end
            end
            SEND_DUMMIES: begin
                if (m_tx_ready) begin
                    m_tx_data  <= 8'h00;     // subsequent dummies
                    m_tx_valid <= 1'b1;
                end
                if (m_rx_valid) begin
                    case(rx_idx)
                        3'd1: gx[15:8] <= m_rx_data;
                        3'd2: gx[7:0]  <= m_rx_data;
                        3'd3: gy[15:8] <= m_rx_data;
                        3'd4: gy[7:0]  <= m_rx_data;
                        3'd5: gz[15:8] <= m_rx_data;
                        3'd6: gz[7:0]  <= m_rx_data;
                    endcase
                    if (rx_idx < 3'd7) rx_idx <= rx_idx + 1'b1;
                end
                if (m_done) state<=DONE;
            end
            DONE: begin
                valid<=1'b1;    // one-cycle strobe
                state<=IDLE;
            end
            default: state<=IDLE;
            endcase
        end
    end
endmodule

