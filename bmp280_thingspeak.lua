-- reads the barometric pressure and temperature from a BMP280 module and sends 
-- to ThingSpeak once every 10 minutes. syncs the rtc with a ntp server every 30 minutes.
-- requires firmware bmp280, sntp and rtctime modules.

   GPIO0  = 3       -- heartbeat LED
-- GPIO1  = 10
-- GPIO2  = 4
-- GPIO3  = 9
-- GPIO4  = 2	
-- GPIO5  = 1	
-- GPIO9  = 11
-- GPIO10 = 12
   GPIO12 = 6		-- BMP280 SDA
-- GPIO13 = 7	
   GPIO14 = 5	    -- BMP280 SCL	
-- GPIO15 = 8
-- GPIO16 = 0	

WRITEKEY = "AXB9T6VGTSV8MHW0"   -- ThingSpeak write api key for this channel

LED=GPIO0	        -- use GPIO0 output for the heartbeat LED
LEDTIME=50          -- 50 milliseconds for LED
ON=0                -- low turns the heartbeat LED on
OFF=1               -- high turns the heartbeat LED off

hour=0              -- global hour
minute=0            -- global minute
second=0            -- global second
updateInterval=15   -- global default re-sync with NTP server every 15 minutes
secs=0              -- seconds from RTC
usecs=0             -- microseconds from RTC
lastsecs=0          -- global previous seconds reading
timeZone=-4         -- Eastern Daylight Time (UTC-4)

function sendToThingSpeak(press,temp)
   local conn=net.createConnection(net.TCP, 0) 
   conn:connect(80,'184.106.153.149')
   
   conn:on("connection", 
      function(conn, payload)
         --print("Connected to ThingSpeak...")
         local buf="GET /update?key="..WRITEKEY.."&field1="..press.."&field2="..temp.." HTTP/1.1\r\n"
         buf=buf.."Host: api.ThingSpeak.com\r\n"
         buf=buf.."Accept: */*\r\n"
         buf=buf.."User-Agent: Mozilla/4.0 (compatible; esp8266 Lua; Windows NT 5.1)\r\n\r\n"
         conn:send(buf)
      end -- function
   ) -- -- end of on "connection" event handler

   conn:on("receive",
      function(conn, payload) 
         --print("Received payload from ThingSpeak...")
         for line in payload:gmatch("[^\r\n]+") do  -- split "payload" into lines
            if string.find(line,"Status") ~= nil then
               print(string.format("Received \""..line.."\" from ThingSpeak at %02d:%02d:%02d.",hour,minute,second))            
               break
            end -- if
         end -- for
         conn:close()
      end -- function
   ) -- end of on "receive" event handler
   
   conn:on("disconnection", 
      function(conn, payload)
         --print("Disconnected from ThingSpeak...")
         conn=nil
         line=nil
         payload=nil
      end -- function
   ) -- end of on "disconnection" event handler
end -- function sendTempToThingSpeak(press,temp)

-- function called by the timer once every 100 milliseonds...
function oneHundredMS()
   secs,usecs=rtctime.get()     -- get the time stamp from the ESP8266 RTC
   if (secs~=lastsecs) then     -- if one second has elapsed...
      lastsecs=secs             -- save it for next time

      gpio.write(LED,ON)        -- turn the heartbeat LED on
      tmr.alarm(0,LEDTIME,tmr.ALARM_SINGLE,function() gpio.write(LED,OFF) end) -- turn the heartbeat LED off after 50 milliseconds     
      
      -- convert from NTP epoch (01/01/1900) to Unix epoch (01/01/1970)
      secs=secs-1104494400-1104494400+(3600*timeZone)
      hour=(secs%86400)/3600     -- hours
      minute=(secs%3600)/60      -- minutes
      second=secs%60             -- seconds

      --print(string.format("%02d:%02d:%02d  %02d/%02d/%04d",hour,minute,second))   
      
      if (second==0) then
         if (minute%10==0) then    -- every 10 minutes...
            press,temp=bme280.baro()    -- read pressure (hectopascals multiplied by 1000) and temperature (celsius multiplied by 100)
            -- For future reference 1 pascal = 0.000295333727 inches of mercury, or 1 inch Hg = 3386.39 Pascal. 
            -- So, for example, if you take the value of 1007.34 hectopasals and divide by 33.8639 you'll get 29.74 inches-Hg.         
            inHg=(press*1000)/338639  -- divide by 33.8639
            print(string.format("Pressure=%d.%02d inHg", inHg/100,inHg%100))
            tempF=(temp*900/500)+3200
            print(string.format("Temperature=%d.%02d Degrees F",tempF/100,tempF%100))
            sendToThingSpeak((inHg/100).."."..(inHg%100),(tempF/100).."."..(tempF%100))
         end    -- if (minute%10==0)
      
         if ((minute==15) or (minute==45)) then -- at 15 and 45 minutes past the hour
            print(string.format("Syncing RTC with NTP server at %02d:%02d:%02d.",hour,minute,second)) 
            sntp.sync(NTPSERVER)                                -- re-sync the ESP8266 RTC with the NTP server every 15 minutes
         end    -- if ((minute==15) or (minute==45))
      end   -- if (second==0) then
   end  -- if (secs~=lastsecs) then
end  -- function oneHundredMS()

-----------------------------------------------------------------------------
-- script execution starts here...
-----------------------------------------------------------------------------

gpio.mode(LED,gpio.OUTPUT)
gpio.write(LED,OFF)                     -- turn off the heartbeat LED

--set the IP of the DNS servers used to resolve hostnames
net.dns.setdnsserver("208.67.222.222",0)    -- OpenDNS.com
net.dns.setdnsserver("8.8.8.8",1)           -- Google.com
NTPSERVER="0.pool.ntp.org"
sntp.sync(NTPSERVER)

bme280.init(GPIO12,GPIO14)            --SCL connected to GPIO14, SDA connected to GPIO12
tmr.alarm(5,100,tmr.ALARM_AUTO,function() oneHundredMS() end) -- every 100 milliseconds...
