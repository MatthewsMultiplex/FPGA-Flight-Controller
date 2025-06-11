`timescale 1ns / 1ps


module Control_FSM (
input clk,
input reset,
input start, 
input spi_done,
input uart_done,
input data_flag,
input [15:0] sensor_data, 
output reg spi_start,
output reg uart_start,
output reg [7:0] duty_cycle
);

localparam IDLE = 0,
           READ_IMU = 1,
           WAIT_SPI = 2,
           PROCESS = 3,
           UPDATE_PWM = 4,
           TX_UART = 5;
           

reg [2:0] state;
reg [15:0] sensor_buffer;


           
           
 // possible delay instantiation? 
 
always @ (posedge clk) begin
    if(reset) begin
    spi_start <= 0; 
    uart_start <= 0;
    duty_cycle <= 0; 
    sensor_buffer <= 0;
    state <= IDLE; 
    end
    
    else begin
    spi_start <= 0; 
    uart_start <=0;
    
    case(state) 
    IDLE: begin
        state <= READ_IMU; 
        end
    READ_IMU: begin 
        spi_start <= 1;
        state <= WAIT_SPI;
        end
    WAIT_SPI: begin
    if(spi_done)
        state <= PROCESS;
    end
    
    PROCESS: begin
    sensor_buffer <= sensor_data;
    state <= UPDATE_PWM;
    end
    
    UPDATE_PWM: begin
        duty_cycle <= sensor_buffer[15:8];
        state <= TX_UART;
        end
    TX_UART: begin
        uart_start <= 1;
        if (uart_done)
            state <= READ_IMU;
        end
        
     default: state <= IDLE;
     
     endcase
  end

end

endmodule