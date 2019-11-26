--[[
Jeti Log File Player 

Warning

The application is designed to replay log files on the Jeti emulator to test new lua application against previous 
recorded log files. The player is a development tool.
The application should never be used on a real device to to avoid any unpredictable behavior of a remote controlled device.


Description

The application is a development tool to test lua applications with previous recorded log file data.
A free selectable switch can control the player. The control switch is always taken from the emulator.
The player has four states: 
 - initialiesed
 - reset/stopped
 - playing
 - finished
User feedback is given in the emulator debug window.

Usage

1. Install the player application parallel to the to-test-application
2. Select a log file from the "Log" folder
3. Select a switch to "start" or "reset" the log file player
4. The test application can retrieve values form the log file through the system calls:
  - system.getSensors ()
  - system.getSensorByID (sensor ID, sensor param)
  - system.getSensorValueByID (sensor ID, sensor param)
  - system.getInputs (Input1,...)
  - system.getInputsVal (Input1,...)
  - system.getTxTelemetry ()


Licence:

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.

]]
-- Todos / open topics / function limits
-- Requiers JETI SW Version 4.28 or higer
-- after first start or file change: type and decimal might not initialisied so time, date, gps are wrong 
-- system.getTxTelemetry () : supports only receiver 1
-- ??? system.getSensors no check if log file and emulator provide the same sensors
-- only the first error message per block is stored
--
-- see '??? mark1'ware is provided as it is without any laibility or any warranty
-- the direct tx control values have a reduced resolution
-- system.getInputsVal: works only limited because getSwitchInfo properties are not complete 
--  and the switchItem configuration is not part of the log file
-- 
--[[
 version 0.44 initial release
		 0.45 
		- decimal correction for return values
		- TX log parameter values labes must equal the switch or switchItem label
		- TX log parameter <50 treated special: expect 0 to 100% output will be -1 to 1
		- system.getInputsVal added, but limited function due to system.getSwitchInfo limits
		0.46
		- control switch is always taken from the emulator
		0.47
		- sensor.label staus "valid" is now treated like the other values
		- the log file can now contain comment lines after the first logtime >0 line
		- a comment line has to start with non number character
		- display name changed
		- init simplified
		0.48
		- valid return corrected: preset valid=false deleted
]]
local appName="Log File Player"

local logPath="Log/"
local logFile="default.log"

local system_getTxTelemetry=system.getTxTelemetry
local system_getInputs=system.getInputs
local system_getInputsVal=system.getInputsVal
local system_getSensors=system.getSensors
local system_getSensorByID=system.getSensorByID
local system_getSensorValueByID=system.getSensorValueByID

local swReset		-- switchItem to start or reset logPlayer

local lpReset		-- log file player status
local lpRun		
local lpEnd
local lpNewFile		-- newFile selected

local modell		-- log file read values
local sensors		-- sensors[sid][sparam]{["label"],["unit"],["logTime"],["type"],["decimals"],["value"],["min"],["max"]}
local newSensors	-- definition from the previous run
local logTime	 	-- time of the line
local sid			-- sensor ID
local sparam		-- Sensor Value ID
local slabel		-- Sensor Name
local sunit 		-- Senseor Unit

local logStartTime
local systemStartTime

local tx			-- lookup table for input values
local rx			-- sensor id for txTel

local errorList		-- [...]{etime, etype, evalue}

local file			-- log file pointer
local line			-- log file line 
local sPos			-- sub-string start position 
local ePos			-- sub-string end position


--------------------------------------------------------------------
-- helper function
local function getDivisor(i,p)
  local divisor=1.0
  if not pcall(function()
    local d=0
    while d< sensors[i][p]["decimals"] do
      divisor=divisor*10.0
      d=d+1
    end
  end) then
    divisor=1.0
  end
  return divisor
end
--------------------------------------------------------------------
-- telemetrie wreper function
--------------------------------------------------------------------
-- system.getTxTelemetry ()
-- supports only receiver 1
--------------------------------------------------------------------
system.getTxTelemetry=function(...)
  local txTel=system_getTxTelemetry()
  if rx then
    if not pcall(function()
      if rx["RxId"] then
        for param in pairs(sensors[rx["RxId"]]) do
          if sensors[rx["RxId"]][param]["label"] == "U Rx" then
            txTel.rx1Voltage=sensors[rx["RxId"]][param]["value"]/getDivisor(rx["RxId"],param)
          elseif sensors[rx["RxId"]][param]["label"] == "Q" then
            txTel.rx1Percent=sensors[rx["RxId"]][param]["value"]/getDivisor(rx["RxId"],param)
          elseif sensors[rx["RxId"]][param]["label"] == "A1" then
            txTel.RSSI[1]=sensors[rx["RxId"]][param]["value"]/getDivisor(rx["RxId"],param)
          elseif sensors[rx["RxId"]][param]["label"] == "A2" then
            txTel.RSSI[2]=sensors[rx["RxId"]][param]["value"]/getDivisor(rx["RxId"],param)
          end
        end
      end
    end) then
	  if errorList["getTxTelemetry"]==nil then
        errorList["getTxTelemetry"]={}
        errorList["getTxTelemetry"]["etime"]=logTime
	    errorList["getTxTelemetry"]["etype"]="getTxTelemetry"
        errorList["getTxTelemetry"]["evalue"]="unkown value"
	  end
    end
  end
  return txTel
end  

--------------------------------------------------------------------
-- system.getInputs
--------------------------------------------------------------------
system.getInputs=function(...)
  local r={}
  local arg = {...}
  r[1],r[2],r[3],r[4],r[5],r[6],r[7],r[8]=system_getInputs(...)
  
  if tx then
    if not pcall(function()
      for i,input in pairs(arg) do					-- replace original with log file data
        if tx[input] then
		  if tx[input] >50 then						-- handel value as "normal" sensor value
            r[i]=sensors[tx["TxId"]][tx[input]]["value"]/getDivisor(tx["TxId"],tx[input])
		  else
            r[i]=(sensors[tx["TxId"]][tx[input]]["value"] -50)/50	-- log is 0-100 system -1 to 0 to 1
		  end
        end
      end
    end ) then
      if errorList["getInputs"]==nil then
        errorList["getInputs"]={}
        errorList["getInputs"]["etime"]=logTime
        errorList["getInputs"]["etype"]="getInputs"
        errorList["getInputs"]["evalue"]="unkown value"
      end
    end
  end
  return r[1],r[2],r[3],r[4],r[5],r[6],r[7],r[8]
end

--------------------------------------------------------------------
-- system.getInputsVal
--------------------------------------------------------------------
system.getInputsVal=function(...)
  local r={}
  local arg = {...}
  r[1],r[2],r[3],r[4],r[5],r[6],r[7],r[8]=system_getInputsVal(...)
  if tx then
    if not pcall(function()
      for i,input in pairs(arg) do					-- replace original with log file data
        local swItemTab=system.getSwitchInfo(input)
        if tx[swItemTab.label] then
		  if tx[swItemTab.label] >50 then			-- handel value as "normal" sensor value
            r[i]=sensors[tx["TxId"]][tx[swItemTab.label]]["value"]/getDivisor(tx["TxId"],tx[swItemTab.label])
		  else
            r[i]=(sensors[tx["TxId"]][tx[swItemTab.label]]["value"] -50)/50	-- log is 0-100 system -1 to 0 to 1
		  end
-- later convert value to the requeste properties from swItemTab=getSwitchInfo(input) :center, proportional, reverse
-- assuming the UNIT feld in the log file will contain the logded configuration default: log is always proportional
-- default could look somthing like that or check if something else is definfed in the "UNIT"
--		  if not swItemTab.proportional then
--		    if r[i] > 0.7 then r[i] =1
--			elseif  r[i] < -0.7 then r[i] =-1
--			else r[i]=0
--        else
-- 		    if not swItemTab.center then r[i]=(r[i]+1)/2 end
--		  end
--		  if swItemTab.reverse then r[i]=-1*r[i] end
        end
      end
    end ) then
      if errorList["getInputsVal"]==nil then
        errorList["getInputsVal"]={}
        errorList["getInputsVal"]["etime"]=logTime
        errorList["getInputsVal"]["etype"]="getInputsVal"
        errorList["getInputsVal"]["evalue"]="unkown value"
      end
    end
  end
  return r[1],r[2],r[3],r[4],r[5],r[6],r[7],r[8]
end

--------------------------------------------------------------------
-- system.getSensors ()
-- system.getSensorByID (<sensor ID>, <sensor param>)
-- system.getSensorValueByID (<sensor ID>, <sensor param>)
--------------------------------------------------------------------
local function doParameter(fullData,id,param)
  local s={}
  if id==nil or param==nil then		-- definition incomplete
    return s
  end

  if sensors==nil or sensors[id]==nil or sensors[id][param]==nil then
	return system_getSensorValueByID(id,param)	-- sensor request is not part of the logfile
  end

  if fullData then
    s["id"]=id				-- sensors unique identifier
    s["param"]=param		-- parameter identifier
--  if param~=0 then
--    s["sensorName"]= sensors[id][0]["label"]
--  end
    s["sensorName"]=""
  end

  local svalue
  for key,value in pairs(sensors[id][param]) do
    if key=="value" then
      svalue=value			-- handle value later according spec
    elseif key=="logTime" then
      if (sensors[id][param]["logTime"]-logStartTime)+4000 >= system.getTimeCounter()-systemStartTime then
        s["valid"]=true
      else
        s["valid"]=false
      end
    elseif fullData then
      s[key]=value			-- fill in all sensor values
    elseif not fullData and (key=="min" or key=="max" or key=="type") then
      s[key]=value			-- fill in only selected sensor values
    end
  end

-- handle value
  if svalue then
    if s["type"]==5 then
      if sensors[id][param]["decimals"]==0 then				-- time
        s["valSec"]=sensors[id][param]["value"]&0xFF
        s["valMin"]=(sensors[id][param]["value"]>>8)&0xFF
        s["valHour"]=(sensors[id][param]["value"]>>16)&0x1F
      else 													-- date
        s["valDay"]=(sensors[id][param]["value"]&0xFF)
        s["valMonth"]=((sensors[id][param]["value"]>>8)&0xFF)
        s["valYear"]=((sensors[id][param]["value"]>>16)&0x1F)+2000
      end
    elseif s["type"]==9 then								-- gps
      s["valGPS"]= sensors[id][param]["value"]
    else
	  local divisor=getDivisor(id,param)
      s["value"]=sensors[id][param]["value"] /divisor		-- float
	  if sensors[id][param]["min"] then
		s["min"]=sensors[id][param]["min"]   /divisor
      else
        s["min"]=0.0
      end
      if sensors[id][param]["max"] then
        s["max"]=sensors[id][param]["max"]   /divisor
      else
        s["max"]=0.0
      end
    end
  else
    s["value"]=0.0
    s["min"]=0.0
    s["max"]=0.0
  end

  return s
end

--------------------------------------------------------------------
-- getSensors()
--------------------------------------------------------------------
system.getSensors=function(...)
-- value, min, max, valid, type
-- id, param, label, unit, decimals, sensorname
  local sa={}					-- sensor Array
  local index=0;				-- sensor index
  sa=system_getSensors()

-- ??? check here if sensor Id is present in emulator and log file
  for i in ipairs(sa) do		-- find sensors end
    if i>index then
	  index=i
	end
  end

  if sensors then				-- anything read from the log file
    for id,sensor in pairs(sensors) do
	  if not (sensor[0]["label"]:sub(1,2)=="Tx" or sensor[0]["label"]:sub(1,2)=="Rx") then
        for param,senPar in pairs(sensor) do
	      index=index+1
          if sa[index]==nil then
            sa[index]={}
          end
          sa[index]=doParameter(true,id,param) -- add sensor subset to array
        end
      end
    end
  end
  return sa
end

--------------------------------------------------------------------
-- getSensorByID (id,param)
--------------------------------------------------------------------
system.getSensorByID=function(...)
-- value, min, max, valid, type
-- id, param, label, unit, decimals, sensorName
  local arg = {...}
  local id
  local param
  
  for i,v in ipairs(arg) do
    if i==1 then id=v end
    if i==2 then param=tonumber(v) end
  end
  return doParameter(true,id,param)
end

--------------------------------------------------------------------
-- getSensorValueByID (id,param)
--------------------------------------------------------------------
system.getSensorValueByID=function(...)
-- value, min, max, valid, type
  local arg = {...}
  local id
  local param
  
  for i,v in ipairs(arg) do
    if i==1 then id=v end
    if i==2 then param=tonumber(v) end
  end
  return doParameter(false,id,param)
end

--------------------------------------------------------------------
-- log Player
--------------------------------------------------------------------
local function logPlayer()

  local function findPos()					-- find next data in line
    sPos=ePos+1
	ePos = line:find(";",sPos)
	if ePos==nil then
	  ePos=0
	end
	local result =line:sub(sPos,ePos-1)
	if result then
      return result
	else
	  return ""
	end
  end

  if lpReset  then							-- read log from scretch
	errorList={}							-- reset error list
	if file then							-- handle file init
	  io.close(file)
	end
    file = io.open(logPath..logFile,"r")
    if file==nil then
      if errorList["playerInit"]==nil then
	    errorList["playerInit"]={}
	    errorList["playerInit"]["etime"]=0
	    errorList["playerInit"]["etype"]="File error"
	    errorList["playerInit"]["evalue"]=logPath..logFile
	  end
      return
    end

	newSensors={}							-- reset sensor table
	logStartTime=0
	logTime=0
	tx={}	
	rx={}
	
    repeat									-- register sensors
      line = io.readline(file)
      if line==nil then						-- error?
        io.close(file)
        file=nil
        if errorList["playerInit"]==nil then
	      errorList["playerInit"]={}
	      errorList["playerInit"]["etime"]=0
	      errorList["playerInit"]["etype"]="File no data"
	      errorList["playerInit"]["evalue"]=logPath..logFile
	    end
	    return								-- eof and now?
      end
      if 1==line:find("#") then				-- modell name
        modell=line:sub(3)
		if modell then
		  print("LP: "..modell)
		end
      else
        ePos=0								-- new line
        logTime=tonumber(findPos())
		if logTime==nil then
          io.close(file)
          file=nil
          if errorList["playerInit"]==nil then
	        errorList["playerInit"]={}
	        errorList["playerInit"]["etime"]=0
	        errorList["playerInit"]["etype"]="File no logtime"
            errorList["playerInit"]["evalue"]=logPath..logFile
          end
	      return								-- eof and now?
		end
        sid=(findPos())
        if logTime==0 then					-- sensor def
          sparam=tonumber(findPos())
          slabel=findPos()	
          sunit=findPos()
--print ("ID:"..sid..", "..sparam.." Label:"..slabel.." Unit:"..sunit)
          if newSensors[sid]==nil then
            newSensors[sid]={}					--create sensor array
          end
          if newSensors[sid][sparam]==nil then
            newSensors[sid][sparam]={}			--create sensor Parameter
          end
		  if sparam==0 and slabel:sub(1,2)=="Tx" then
		    tx["TxId"]=sid
          elseif sparam==0 and slabel:sub(1,2)=="Rx" then
		    rx["RxId"]=sid
		  end
          newSensors[sid][sparam]["label"]=slabel
          newSensors[sid][sparam]["unit"]=sunit
          newSensors[sid][sparam]["logTime"]=0		-- time => valid
          newSensors[sid][sparam]["value"]	=0		-- value
-- check for sensor type definition in previous sensors definition
          if not pcall(function()
		    newSensors[sid][sparam]["type"]=sensors[sid][sparam]["type"]
			newSensors[sid][sparam]["decimals"]=sensors[sid][sparam]["decimals"]
		  end) then
            newSensors[sid][sparam]["type"]=0
            newSensors[sid][sparam]["decimals"]=0
		  end
		end
      end
    until logTime>0							-- read defenition done
    sensors=newSensors;

	if tx["TxId"] then						-- create tx input, param table
	  for param,senPar in pairs(sensors[tx["TxId"]]) do
        if param~=0 then					-- not for label
		  if param>50 then					-- user Logger?
		    if tx[senPar["label"]] or senPar["label"]=="TxId" then
              if errorList["InputControl"]==nil then
	            errorList["InputControl"]={}
	            errorList["InputControl"]["etime"]="0;"..tx["TxId"]..';'..param
	            errorList["InputControl"]["etype"]="redefinition Input Control"
	            errorList["InputControl"]["evalue"]=senPar["label"]
	          end
			else
              tx[senPar["label"]]=param
			end
		  else								-- tx input control
			local pos = senPar["label"]:find(" ",1)
			if pos then
              local sw=senPar["label"]:sub(pos+1)
	          if sw then
			    if tx[sw] or sw=="TxId" then
                  if errorList["InputControl"]==nil then
		            errorList["InputControl"]={}
		            errorList["InputControl"]["etime"]="0;"..tx["TxId"]..';'..param
		            errorList["InputControl"]["etype"]="redefinition Input Control"
		            errorList["InputControl"]["evalue"]=sw
		          end
				else
	              tx[sw]=param
				end
			  end
			end
		  end
		end
	  end
	end

  elseif lpRun then
    if file==nil then						-- file finished
	  return
	end
    if logStartTime==0 then					-- sync logtime with systemtime
      systemStartTime = system.getTimeCounter()
      logStartTime=logTime
	end
    while logTime-logStartTime <= system.getTimeCounter()-systemStartTime do -- read log file data
      if sid=="0000000000" then				-- sensor value for undefind sensor
--print ("ALARM")
      elseif sensors[sid]==nil then
	    if errorList["playerRun"]==nil then
		  errorList["playerRun"]={}
		  errorList["playerRun"]["etime"]=logTime
		  errorList["playerRun"]["etype"]="unknown ID"
		  errorList["playerRun"]["evalue"]=sid
		end
      else
        while ePos>0 do
          sparam=tonumber(findPos())		-- param
		  if sparam==nil then				-- line ends with ';'
		    break
		  end
          if sensors[sid][sparam]==nil then
	        if errorList["playerRun"]==nil then
		      errorList["playerRun"]={}
		      errorList["playerRun"]["etime"]=logTime
		      errorList["playerRun"]["etype"]="unknown Parameter"
		      errorList["playerRun"]["evalue"]=sparam
		    end
            break
          else														-- store parameter set
            sensors[sid][sparam]["logTime"] = logTime				-- time
            if sensors[sid][0]~=nil then
              sensors[sid][0]["logTime"] = logTime					-- sensorname also has a "valid" time
	        end
            sensors[sid][sparam]["type"]	= tonumber(findPos())	-- type
            sensors[sid][sparam]["decimals"]= tonumber(findPos())	-- decimals
            sensors[sid][sparam]["value"]	= tonumber(findPos())	-- value
            if not(sensors[sid][sparam]["type"]==5 or sensors[sid][sparam]["type"]==9) then
              if sensors[sid][sparam]["min"]==nil then							-- find min value
	            sensors[sid][sparam]["min"]=sensors[sid][sparam]["value"]
              elseif sensors[sid][sparam]["min"]> sensors[sid][sparam]["value"] then
                sensors[sid][sparam]["min"]= sensors[sid][sparam]["value"]
              end
		
              if sensors[sid][sparam]["max"]==nil then							-- find max value
                sensors[sid][sparam]["max"]=sensors[sid][sparam]["value"]
              elseif sensors[sid][sparam]["max"] < sensors[sid][sparam]["value"] then
                sensors[sid][sparam]["max"] = sensors[sid][sparam]["value"]
              end
			end
          end
        end									--eol - next
      end
      repeat
        line = io.readline(file)
        if line==nil then
          io.close(file)
          file=nil
	      return							-- eof - done
        end
        ePos=0
        logTime= tonumber(findPos())
        sid=(findPos())
	  until logTime~=nil 					-- jump over empty lines or comment lines starting with --
    end										-- eotime - return
  elseif lpEnd then							-- finished
	if file then							-- close file if not already done
	  io.close(file)
	  file=nil
	end
  else										-- something went wrong
	if file then							-- close file if not already done
	  io.close(file)
	  file=nil
	end
    if errorList["playerState"]==nil then
      errorList["playerState"]={}
      errorList["playerState"]["etime"]=logTime
      errorList["playerState"]["etype"]="Player State Mashine"
      errorList["playerState"]["evalue"]="unknown State"
    end
  end
end

--------------------------------------------------------------------
-- initForm functions
--------------------------------------------------------------------
local function initForm()
  local logFiles={}							-- file list
  local fileIndex=0							-- selected file index
  local i=1									-- number of files

  local function swResetChanged(value)		-- store configuration
    swReset=value
    system.pSave("swReset",value)
  end

  local function lfChanged(value)
    logFile=logFiles[value]
    system.pSave("logFile",logFile)
	lpNewFile=true
  end

  fileIndex=0								-- read directory 
  for name, filetype in dir(logPath) do
    if filetype=="file" then
	  local pos = name:find(".log")
      if pos then
	    logFiles[i]=name
        if logFile then
	      if name==logFile then				-- index = previous selected file
		    fileIndex=i
          end
	    end
	    i=i+1
	  end
    end
  end

  if logFiles[1] then						-- select log file
    form.addRow(2)
    form.addLabel({label="File"})
    form.addSelectbox (logFiles, fileIndex, true ,lfChanged)
  else
    form.addRow(1)
    form.addLabel({label="NO LOG-File!!"})
  end

  form.addRow(2)							-- select Reset switch
  form.addLabel({label="Player Reset"})
  form.addInputbox(swReset,true,swResetChanged)

end

--------------------------------------------------------------------
-- print status
--------------------------------------------------------------------
local function printStatus(status)
  if errorList then
    for entry, eList in pairs(errorList) do
      print("Error- "..entry..": "..errorList[entry].etime.." - "..errorList[entry].etype.." . "..errorList[entry].evalue)
    end
  end
  print(status)
end

--------------------------------------------------------------------
-- Runtime functions
--------------------------------------------------------------------
local function loop()
  if swReset~=nil then							-- handling & log file defined?
    local valReset = system_getInputsVal(swReset)
    if valReset>0 then						-- Restart log file?
      if lpRun then
	    lpRun=false
		lpEnd=true
		logPlayer()	
        printStatus("LP: stopped")
	  end
	  if ((valReset>0 and lpNewFile) or not lpReset) and logFile then
        lpReset=true
        lpRun=false
		lpEnd=false
		lpNewFile=false
		logPlayer()							-- read log file until log time starts
        printStatus("LP: initillised")
	  end
	else									-- play file
      if lpReset and not lpRun then
        printStatus("LP: playing")
        lpRun=true
        lpReset=false
      end
	  if lpRun then
        logPlayer()							-- read log file until log time offset >= passed system time diff
        if file==nil and not lpEnd then		-- all done: reached end of file
          printStatus("LP: finished")
          lpEnd=true
		  lpRun=false
        end
      end
	end
  end
end

--------------------------------------------------------------------
-- Init function
--------------------------------------------------------------------
local function init(code)
  local deviceName,deviceType=system.getDeviceType ()
  if deviceType==1 then
    system.registerForm(1,MENU_APPS,appName,initForm)
    swReset = system.pLoad("swReset")			-- read old configuration
    logFile= system.pLoad("logFile",logFile)

    lpReset=false								-- state machine
    lpRun=false
	lpEnd=false
	lpNewFile=false
    sensors={}
	errorList={}								-- reset Error list
	systemStartTime=0							-- set player time
	logStartTime=0
  else
    print ("Emulator usage ONLY!!!")
  end
end

return { init=init, loop=loop, author="Andre", version="0.48",name=appName}
