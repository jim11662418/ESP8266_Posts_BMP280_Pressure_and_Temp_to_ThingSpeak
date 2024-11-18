# ESP8266 Posts BMP280 Pressure and Temp to ThingSpeak
This [NodeMCU Lua](https://nodemcu.readthedocs.io/en/master/) script for the ESP8266 reads the barometric pressure and temperature from a BMP280 module every 10 minutes and sends the date to ThingSpeak for graphing. Syncs the RTC with a NTP server every 30 minutes.

[Custom build](https://nodemcu-build.com/) your NodeMCU firmware with the bmp280, sntp and rtctime modules.
