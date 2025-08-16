## Zybo Z7 Rev. B - constraints (IMU on JA, UART on JC, PWMs on JD/JE)

# 125 MHz clock
set_property -dict { PACKAGE_PIN K17 IOSTANDARD LVCMOS33 } [get_ports {clk_125mhz}]
create_clock -add -name sys_clk_pin -period 8.000 -waveform {0 4} [get_ports {clk_125mhz}]

# Reset button (BTN0), active-high
set_property -dict { PACKAGE_PIN R18 IOSTANDARD LVCMOS33 } [get_ports {rst_btn}]

# SPI to IMU on PMOD JA
# JA1 N15 = imu_sclk
# JA2 L14 = imu_mosi
# JA3 K16 = imu_miso
# JA4 K14 = imu_cs_n   (active low)
set_property -dict { PACKAGE_PIN N15 IOSTANDARD LVCMOS33 } [get_ports {imu_sclk}]
set_property -dict { PACKAGE_PIN L14 IOSTANDARD LVCMOS33 } [get_ports {imu_mosi}]
set_property -dict { PACKAGE_PIN K16 IOSTANDARD LVCMOS33 } [get_ports {imu_miso}]
set_property -dict { PACKAGE_PIN K14 IOSTANDARD LVCMOS33 } [get_ports {imu_cs_n}]

# UART on PMOD JC (3.3V USB-TTL dongle)
# JC1 V15 = uart_tx  (to dongle RXD)
# JC2 W15 = uart_rx  (from dongle TXD)
set_property -dict { PACKAGE_PIN V15 IOSTANDARD LVCMOS33 } [get_ports {uart_tx}]
set_property -dict { PACKAGE_PIN W15 IOSTANDARD LVCMOS33 } [get_ports {uart_rx}]

# PWM outputs: split across two PMODs for easier measurement
# Left motor PWM on JD1 (T14)
set_property -dict { PACKAGE_PIN T14 IOSTANDARD LVCMOS33 } [get_ports {pwm_left}]
# Right motor PWM on JE1 (V12)
set_property -dict { PACKAGE_PIN V12 IOSTANDARD LVCMOS33 } [get_ports {pwm_right}]

