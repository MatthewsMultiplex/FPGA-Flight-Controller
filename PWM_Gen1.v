`timescale 1ns/ 1ps

module PWM_Gen(
    input clk,
    input reset, 
    input [7:0] duty_cycle,
    output pwm_out
    );
 
parameter CLK_FREQ = 100000000;
parameter PWM_FREQ = 20000;

localparam integer MAX_COUNT = CLK_FREQ / PWM_FREQ;   

reg [31:0] counter = 0; 

always @ (posedge clk) begin

    if (reset)
            counter <= 0; 
    else if (counter >= MAX_COUNT - 1)
            counter <= 0;
    else 
            counter <= counter + 1; 

end

assign pwm_out = (counter < ((duty_cycle * MAX_COUNT) >> 8)) ? 1'b1 : 1'b0;

endmodule
