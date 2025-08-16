// filename: PWM_Gen.v
`timescale 1ns/1ps

module PWM_Gen #(
    parameter integer CLK_HZ = 125_000_000,
    parameter integer PWM_HZ = 20_000
)(
    input  wire       clk,
    input  wire       reset,
    input  wire [7:0] duty_cycle, // 0..255
    output wire       pwm_out
);
    localparam integer MAX_COUNT = CLK_HZ / PWM_HZ;
    reg [31:0] counter;

    always @(posedge clk) begin
        if (reset) counter <= 0;
        else if (counter >= MAX_COUNT-1) counter <= 0;
        else counter <= counter + 1;
    end

    assign pwm_out = (counter < ((duty_cycle * MAX_COUNT) >> 8)) ? 1'b1 : 1'b0;
endmodule
