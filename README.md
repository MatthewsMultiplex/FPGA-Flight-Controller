# FPGA-Flight-Controller


Materials needed: 
1. Zybo 7020 SOC 
2. DC motors of any type, for the purposes of testing
3. MPU 9250 IMU sensor chip
4. Optional Oscope to confirm working status. 

Instructions: 
1. Wire the IMU into JA PMOD Header (If you are using a different board subsititute this for another PMOD and reflect such in the constraints file) 
1a. Wiring for JA PMOD to IMU
  Vcc -> 3.3V
  GND -> GND
  SCL -> Pin 1
  SDA -> Pin 2
  AD0 -> Pin 3
  NCS -> Pin 4

2. Wire the motors into their respective PMOD ports whichever one you choose to set in the constraints file
3. From here you should have your board programmed and you should be able to fire it up and watch the duty cycles adjust as you move the sensors
4. Note: If you are doing this it is likely you will see small changes because the device as it stands now is not equipped to be moved around alot without risk of loose connections or valuable data to be measured by IMU, essentially expect small differences unless you take it upon yourself to test it outdoors and at steeper angles or altitudes. 
