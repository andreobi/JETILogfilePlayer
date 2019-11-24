--[[

		This could be your test app 
		
		which will consume the log file data

]]
local appName ="Demo:Logfile Player"
local onlyOnce
local lastTime
--------------------------------------------------------------------------------
local function loop()
  if system.getTime() > lastTime then
    lastTime=system.getTime()
	local prTime=false
    local sensors = system.getSensors()
    for i,sensor in ipairs(sensors) do
      if sensor.valid then
        onlyOnce=true
	    prTime=true
        if (sensor.type == 5) then
          if (sensor.decimals == 0) then
-- Time
            print (string.format("%s = %d:%02d:%02d", sensor.label, sensor.valHour, sensor.valMin, sensor.valSec))
          else
-- Date
            print (string.format("%s = %d-%02d-%02d", sensor.label, sensor.valYear, sensor.valMonth, sensor.valDay))
          end
        elseif (sensor.type == 9) then
-- GPS coordinates
          local nesw = {"N", "E", "S", "W"}
          local minutes = (sensor.valGPS & 0xFFFF) * 0.001
          local degs = (sensor.valGPS >> 16) & 0xFF
          print (string.format("%s = %d° %f' %s", sensor.label, degs, minutes, nesw[sensor.decimals+1]))
        else
          if(sensor.param == 0) then
-- Sensor label
            print (string.format("%s:",sensor.label))
          else
-- Other numeric value
            print (string.format("%s = %.3f %s (min: %.3f, max: %.3f)", sensor.label,
            sensor.value, sensor.unit, sensor.min, sensor.max))
          end
        end
      elseif (onlyOnce) then
        onlyOnce=false
        print("invalid: "..sensor.label)
      end
    end
	if prTime then 
	  print("Timestamp: "..lastTime) 
	  local i1,i2,i3,i4= system.getInputs("P1","P2","P3","P4")
	  print ("P1="..i1.."  ".."P2="..i2.."  ".."P3="..i3.."  ".."P4="..i4)
	end
  end
end
--------------------------------------------------------------------------------
local function init()
  lastTime=system.getTime()
end
--------------------------------------------------------------------------------
return {init=init, loop=loop, author="Andre", version="0.01", name=appName}