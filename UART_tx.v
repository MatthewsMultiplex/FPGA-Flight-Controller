module UART_Tx(
  input clk, 
  input Tx_Valid,
  input [7:0] dataIn, //Byte
  output o_Tx_Signal, 
  output reg Tx_Serial,
  output o_Tx_Done
    );
    
    parameter CLKS_PER_BIT = 2; //Subject to change? Clock may want to be altered via wizard
    parameter IDLE = 0,
              TX_START_BIT = 1,
              TX_DATA = 2,
              TX_STOP_BIT = 3,
              CLEANUP = 4; 
              
    reg [2:0] state = 0; 
    reg [2:0] Bit_Index = 0;  
    reg [7:0] Tx_Clock_Count = 0;
    reg [7:0] Tx_Data = 0;
    reg Tx_Done = 0;
    reg Tx_Signal = 0; 
    
    always @ (posedge clk)
    begin
    
    case(state)
    IDLE: 
    begin
        Tx_Serial <= 1; //Drive the port high
        Tx_Done <= 0;
        Tx_Clock_Count <= 0;
        Bit_Index <= 0;
        
        if(Tx_Valid == 1)
        begin
            Tx_Signal <= 1;
            Tx_Data <= dataIn;
            state <= TX_START_BIT;
           end
        else
            state <= IDLE;
       end
    
    TX_START_BIT:
    begin
         Tx_Serial <= 0; 
         
         if(Tx_Clock_Count < CLKS_PER_BIT - 1)
            begin
            Tx_Clock_Count <= Tx_Clock_Count + 1;
            state <= TX_START_BIT;
            end
          else
            begin
              Tx_Clock_Count <= 0;
              state <= TX_DATA;
              end
           end
     
    
    TX_DATA: 
    begin 
        Tx_Serial <= Tx_Data[Bit_Index];
        
        if(Tx_Clock_Count < CLKS_PER_BIT - 1)
            begin
                Tx_Clock_Count <= Tx_Clock_Count + 1;
                state <= TX_DATA;
            end
          else
            begin
                Tx_Clock_Count <= 0;
                
                if(Bit_Index < 7)
                begin
                    Bit_Index <= Bit_Index + 1; 
                    state <= TX_DATA;
                    end
                 else
                    begin
                        Bit_Index <= 0;
                        state <= TX_STOP_BIT; 
                    end
            end
     end
     
    TX_STOP_BIT: 
        begin
            Tx_Serial <= 1;
            
            if (Tx_Clock_Count < CLKS_PER_BIT - 1)
                begin
                    Tx_Clock_Count <= Tx_Clock_Count + 1;
                    state <= TX_STOP_BIT;
                end
             else
                begin
                    Tx_Done <= 1;
                    Tx_Clock_Count <= 0;
                    state <= CLEANUP;
                    Tx_Signal <= 0;
               end
            end
            
   CLEANUP: 
   begin
    Tx_Done <= 1;
    state <= IDLE;
    end
