`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/13/2025 03:45:43 PM
// Design Name: 
// Module Name: Formatting_FSM
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

//Pull data from WordReg in the SPI module and input it to FSM

module Formatting_FSM(
input clk,
input reset,
input data_ready, //Flag 
input [15:0] raw_data_in, //Reg? not sure
input data_valid,
input Tx_done,
output reg [7:0] Tx_Data,
output reg Tx_Valid,
output reg done
    );
   
reg [1:0] state;
reg [15:0] raw_data;
reg [7:0] ascii_buffer[0:4];
reg [2:0] index;
reg signed [15:0] temp_val;
    
    localparam INIT = 0,
               READ = 1,
               CONVERT = 2,
               SEND_UART = 3;
               
               
function [7:0] to_ascii;
    input [3:0] bin;
    begin
        to_ascii = bin + 8'd48;
    end
 endfunction
               
 always @ (posedge clk or posedge reset)
    if (reset) begin
        state <= INIT;
        Tx_Data <= 0;
        Tx_Valid <= 0;
        done <= 0;
        index <= 0;
        end
    else begin
    case (state) 
        INIT: begin
            done <= 0;
            if (data_valid) begin
                raw_data <= raw_data_in;
                temp_val <= raw_data_in;
                state <= CONVERT;
            end
         end  
        
        CONVERT: begin
            ascii_buffer[0] <= to_ascii((temp_val / 100) % 10);
            ascii_buffer[1] <= to_ascii((temp_val / 10) % 10);
            ascii_buffer[2] <= to_ascii(temp_val % 10);
            ascii_buffer[3] <= 8'd32; //space in ascii
            ascii_buffer[4] <= 8'd124; // | in ascii
            index <= 0;
            state <= SEND_UART;
        end
        
        
        SEND_UART: 
            begin
                if(index < 5) begin
                    if (!Tx_Valid && Tx_done) begin
                        Tx_Data <= ascii_buffer[index];
                        Tx_Valid <= 1;
                        index <= index + 1;
                     end else begin
                        Tx_Valid <= 0;
                     end
                  end else begin
                        state <= INIT;
                        done <= 1;
                  end
              end
              
              default: state <= INIT;
          endcase
      end
 
    
endmodule
