# bmp280-thingspeak
This NodeMCU Lua script for the ESP8266 reads the barometric pressure and temperature from a BMP280 module every 10 minutes and sends the date to ThingSpeak for graphing. Syncs the RTC with a NTP server every 30 minutes.

Requires firmware bmp280, sntp and rtctime modules.
