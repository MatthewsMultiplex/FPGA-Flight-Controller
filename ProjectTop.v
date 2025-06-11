`timescale 1ns / 1ps

module ProjectTop(
    input clk,
    input reset,
    output pwm_out

);

wire spi_start, spi_done, uart_start, delay_done;
wire [7:0] duty_cycle; 
wire [15:0] sensor_data; 
wire [31:0] delay_length;
wire delay_enable;


Control_FSM fsm_inst (.clk(clk),.reset(reset),.start(1'b1),.spi_done(spi_done),.sensor_data(sensor_data),.uart_done(1'b1),
                        .spi_start(spi_start),.uart_start(uart_start),.duty_cycle(duty_cycle));
                        
spiMaster spi_inst (.clk(clk),.reset(reset),.start(spi_start),.MISO(MISO),.wordReg(sensor_data));

PWM_Gen pwm_inst(.clk(clk),.reset(reset),.duty_cycle(duty_cycle),.pwm_out(pwm_out));

delayTimer timer_inst( .clk(clk),.reset(reset),.enable(delay_enable),.length(delay_length),.done(delay_done));
                       
endmodule