`timescale 1ns / 1ps

module UART_Rx (
   input clk,
   input Rx_Serial,
   output o_Rx_Valid,
   output [7:0] o_Rx_Data
   );
   
   parameter CLKS_PER_BIT = 87;
   parameter IDLE = 0,
             RX_START_BIT = 1,
             RX_DATA = 2,
             RX_STOP_BIT = 3,
             CLEANUP = 4;
 
 reg Rx_Data_R = 1;
 reg Rx_Data = 1;
 
 reg [7:0] Clock_Count = 0;
 reg [7:0] Rx_Byte = 0;
 reg [2:0] Bit_Index = 0;
 reg [2:0] state = 0;
 reg r_Rx_Valid = 0;

 always @ (posedge clk)
    begin
        Rx_Data_R <= Rx_Serial;
        Rx_Data <= Rx_Data_R; 
    end
    
    
  always @(posedge clk)
    begin
        
        case(state)
            IDLE: 
                begin
                  r_Rx_Valid <= 0;
                  Clock_Count <= 0;
                  Bit_Index <= 0;
                  
                  if (Rx_Data == 0)
                     state <= RX_START_BIT;
                  else
                    state <= IDLE;
                  end
           
           RX_START_BIT: 
            begin
                if(Clock_Count == (CLKS_PER_BIT - 1)/2)
                    begin
                        if (Rx_Data == 0)
                            begin
                                Clock_Count <= 0;
                                state <= RX_DATA;
                            end
                          else
                            state <= IDLE;
                        end
                     else
                        begin
                            Clock_Count <= Clock_Count + 1;
                            state <= RX_START_BIT; 
                        end
                     end
          
           RX_DATA:
            begin
                if(Clock_Count < CLKS_PER_BIT - 1)
                    begin       
                        Clock_Count <= Clock_Count + 1;
                        state <= RX_DATA;
                    end
                    
                  else
                    begin
                        Clock_Count <= 0;
                        Rx_Byte[Bit_Index] <= Rx_Data;   
                        
                        if(Bit_Index < 7)
                            begin
                                Bit_Index <= Bit_Index + 1;
                                state <= RX_DATA;
                            end
                          else
                            begin
                                Bit_Index <= 0;
                                state <= RX_STOP_BIT;
                             end
                          end
                          
                      end   
           RX_STOP_BIT: 
                begin
                  if(Clock_Count < CLKS_PER_BIT - 1)
                    begin
                        Clock_Count <= Clock_Count + 1;
                        state <= RX_STOP_BIT;
                       end
                     else
                        begin
                           r_Rx_Valid <= 1;
                           Clock_Count <= 0;
                           state <= CLEANUP;
                        end
                      end
            
            CLEANUP:
            
                begin
                    state <= IDLE;
                    r_Rx_Valid <= 0;
                end
                
           default:
           state <= IDLE;
      endcase
      
      end                     
                          
     assign o_Rx_Valid = r_Rx_Valid; 
     assign o_Rx_Data = Rx_Byte;                       
                         
  
endmodule