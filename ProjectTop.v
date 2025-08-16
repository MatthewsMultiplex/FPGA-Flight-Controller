// filename: top_zybo.v                                                                                  
`timescale 1ns/1ps                                                                                       
                                                                                                         
module top_zybo(                                                                                         
    input  wire clk_125mhz,                                                                              
    input  wire rst_btn,        // active-high pushbutton reset                                          
                                                                                                         
    // SPI to IMU (PMOD header pins)                                                                     
    output wire imu_mosi,                                                                                
    input  wire imu_miso,                                                                                
    output wire imu_sclk,                                                                                
    output wire imu_cs_n,       // active-low CS to IMU                                                  
                                                                                                         
    // UART to USB serial                                                                                
    output wire uart_tx,                                                                                 
    input  wire uart_rx,                                                                                 
                                                                                                         
    // PWM outputs to your two motor drivers                                                             
    output wire pwm_left,                                                                                
    output wire pwm_right                                                                                
);                                                                                                       
    // ----------------------------------------------------------------                                  
    // Synchronous reset (deglitch the button)                                                           
    // ----------------------------------------------------------------                                  
    reg [2:0] rst_sync;                                                                                  
    always @(posedge clk_125mhz) begin                                                                   
        rst_sync <= {rst_sync[1:0], rst_btn};                                                            
    end                                                                                                  
    wire reset = rst_sync[2];                                                                            
                                                                                                         
    // ----------------------------------------------------------------                                  
    // IMU (MPU-9250) SPI interface                                                                      
    //   - uses internal spiMaster with MOSI and burst read (Mode 0)                                     
    //   - outputs signed gx/gy/gz; 'imu_valid' pulses when fresh                                        
    // ----------------------------------------------------------------                                  
    wire                imu_start;                                                                       
    wire                imu_busy;                                                                        
    wire                imu_valid;                                                                       
    wire signed [15:0]  gx, gy, gz;                                                                      
                                                                                                         
    mpu9250_spi_if #(                                                                                    
        .CLKS_PER_HALF_SCLK(6)          // ~10.4 MHz SCLK from 125 MHz                                   
    ) u_imu (                                                                                            
        .clk   (clk_125mhz),                                                                             
        .reset (reset),                                                                                  
        .start (imu_start),                                                                              
        .busy  (imu_busy),                                                                               
        .valid (imu_valid),                                                                              
        .gx    (gx),                                                                                     
        .gy    (gy),                                                                                     
        .gz    (gz),                                                                                     
        .MOSI  (imu_mosi),                                                                               
        .MISO  (imu_miso),                                                                               
        .SCLK  (imu_sclk),                                                                               
        .CS    (imu_cs_n)               // this is active-low on the board                               
    );                                                                                                   
                                                                                                         
    // ----------------------------------------------------------------                                  
    // Control FSM                                                                                       
    //   - triggers IMU reads at ~1 kHz (SAMPLE_DIV)                                                     
    //   - computes left/right duties from gyro Y (simple P control)                                     
    //   - kicks the formatter to print one line per sample                                              
    // ----------------------------------------------------------------                                  
    wire        tx_start;                                                                                
    wire        tx_done_line;                                                                            
    wire [7:0]  duty_l, duty_r;                                                                          
                                                                                                         
    Control_FSM #(                                                                                       
        .SAMPLE_DIV(125_000),           // 1 kHz @ 125 MHz                                               
        .BASE_DUTY (8'd128),            // 50% neutral                                                   
        .KP_SHIFT  (10),                                                                                 
        .Kp        (32),                                                                                 
        .DEADBAND  (50)                                                                                  
    ) u_ctl (                                                                                            
        .clk       (clk_125mhz),                                                                         
        .reset     (reset),                                                                              
        .imu_start (imu_start),                                                                          
        .imu_busy  (imu_busy),                                                                           
        .imu_valid (imu_valid),                                                                          
        .gx        (gx),                                                                                 
        .gy        (gy),                                                                                 
        .gz        (gz),                                                                                 
        .tx_start  (tx_start),                                                                           
        .tx_done   (tx_done_line),                                                                       
        .duty_left (duty_l),                                                                             
        .duty_right(duty_r)                                                                              
    );                                                                                                   
                                                                                                         
    // ----------------------------------------------------------------                                  
    // Formatter → UART (prints one CRLF-terminated line per tx_start)                                   
    // ----------------------------------------------------------------                                  
    wire       uart_tx_ready;   // UART ready for next byte                                              
    wire [7:0] uart_tx_data;                                                                             
    wire       uart_tx_valid;   // 1-clk pulse from formatter                                            
    wire       uart_tx_done_b;  // per-byte done (unused)                                                
                                                                                                         
    Formatting_FSM u_fmt (                                                                               
        .clk      (clk_125mhz),                                                                          
        .reset    (reset),                                                                               
        .start    (tx_start),                                                                            
        .done     (tx_done_line),   // signals Control_FSM when a line finished                          
        .gx       (gx),                                                                                  
        .gy       (gy),                                                                                  
        .gz       (gz),                                                                                  
        .tx_data  (uart_tx_data),                                                                        
        .tx_valid (uart_tx_valid),                                                                       
        .tx_ready (uart_tx_ready)                                                                        
    );                                                                                                   
                                                                                                         
    // UART (115200 baud @ 125 MHz)                                                                      
    wire       rx_valid;                                                                                 
    wire [7:0] rx_data;                                                                                  
    uart #(                                                                                              
        .CLK_HZ(125_000_000),                                                                            
        .BAUD  (115_200)                                                                                 
    ) u_uart (                                                                                           
        .clk        (clk_125mhz),                                                                        
        .reset      (reset),                                                                             
        .ld_tx_data (uart_tx_valid),   // pulse when a byte is ready                                     
        .tx_data    (uart_tx_data),                                                                      
        .tx_ready   (uart_tx_ready),   // high when idle/ready                                           
        .tx_done    (uart_tx_done_b),  // per-byte done (not used here)                                  
        .tx_serial  (uart_tx),                                                                           
        .rx_serial  (uart_rx),                                                                           
        .rx_valid   (rx_valid),                                                                          
        .rx_data    (rx_data)                                                                            
    );                                                                                                   
                                                                                                         
    // ----------------------------------------------------------------                                  
    // Dual PWMs @ 20 kHz                                                                                
    // ----------------------------------------------------------------                                  
    PWM_Gen #(                                                                                           
        .CLK_HZ (125_000_000),                                                                           
        .PWM_HZ (20_000)                                                                                 
    ) u_pwm_left (                                                                                       
        .clk        (clk_125mhz),                                                                        
        .reset      (reset),                                                                             
        .duty_cycle (duty_l),                                                                            
        .pwm_out    (pwm_left)                                                                           
    );                                                                                                   
                                                                                                         
    PWM_Gen #(                                                                                           
        .CLK_HZ (125_000_000),                                                                           
        .PWM_HZ (20_000)                                                                                 
    ) u_pwm_right (                                                                                      
        .clk        (clk_125mhz),                                                                        
        .reset      (reset),                                                                             
        .duty_cycle (duty_r),                                                                            
        .pwm_out    (pwm_right)                                                                          
    );                                                                                                   
                                                                                                         
endmodule                                                                                                
                                                                                                         
