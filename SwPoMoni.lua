--[[
A simple Telemetry window monitor to show the poti's analog value 
and digital switch digital values in a Telemetry window. 
This might be helpful, when the logfile is played just to get an idea what is going on.

When other inputs should be display, just change the <ch> or <sw> value according to 
the specification and the desired Poti or Switch or ...


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
--------------------------------------------------------------------------------
local appName ="Sw-Poti Monitor"

local ch={"P1","P2","P3","P4","P5","P6","P7","P8"}	-- analog and number displayed
local sw={"SA","SB","SC","SD","SE","SF","SG","SH"}	-- only digital displayed

--------------------------------------------------------------------------------
local function displayInputs(width, height)
    local i={}
	i[1],i[2],i[3],i[4],i[5],i[6],i[7],i[8]=system.getInputs(ch[1],ch[2],ch[3],ch[4],ch[5],ch[6],ch[7],ch[8])
	for n=1,4,1 do
		i[n]=i[n]*100
		local text=string.format("%5d",i[n])
		lcd.drawText((38*(n-1)),1,ch[n],FONT_MINI)
		lcd.drawText((38*n)-3-lcd.getTextWidth(FONT_MINI,text),1,text,FONT_MINI)
		if i[n] > 0 then
			lcd.drawFilledRectangle(38*(n-1)+17,11,(i[n]/6)+1,6)
		else
			lcd.setColor(255,0,0)
			local width=-(i[n]/6)
			lcd.drawFilledRectangle(38*(n-1)+17-width,11,width+1,6)		
			lcd.setColor(0,0,0)
		end

		i[n+4]=i[n+4]*100
		text=string.format("%5d",i[n+4])
		lcd.drawText((38*(n-1)),20,ch[n+4],FONT_MINI)
		lcd.drawText((38*n)-3-lcd.getTextWidth(FONT_MINI,text),20,text,FONT_MINI)

		if i[n+4] >= 0 then
			lcd.drawFilledRectangle(38*(n-1)+17,30,(i[n+4]/6)+1,6)
		else
			lcd.setColor(255,0,0)
			local width=-(i[n+4]/6)
			lcd.drawFilledRectangle(38*(n-1)+17-width,30,width+1,6)		
			lcd.setColor(0,0,0)
		end
	end

	i[1],i[2],i[3],i[4],i[5],i[6],i[7],i[8]=system.getInputs(sw[1],sw[2],sw[3],sw[4],sw[5],sw[6],sw[7],sw[8])
	for n=1,4,1 do
		i[n]=i[n]*100
		lcd.drawText((38*(n-1)),46,sw[n],FONT_MINI)
-- if you remove this -- then you comment out the complete if statement
--		local text=string.format("%5d",i[n])
--		lcd.drawText((38*n)-3-lcd.getTextWidth(FONT_MINI,text),46,text,FONT_MINI)
		if -50 < i[n] and i[n] <50 then
			lcd.drawLine(24+38*(n-1),49,24+38*(n-1),54)
		elseif i[n] > 0 then
			lcd.drawFilledRectangle(38*(n-1)+24,49,9,6)
		else
			lcd.setColor(255,0,0)
			lcd.drawFilledRectangle(38*(n-1)+15,49,9,6)
			lcd.setColor(0,0,0)
		end
--
		i[n+4]=i[n+4]*100
		lcd.drawText((38*(n-1)),57,sw[n+4],FONT_MINI)
--		text=string.format("%4d",i[n+4])
--		lcd.drawText((38*n)-3-lcd.getTextWidth(FONT_MINI,text),57,text,FONT_MINI)

		if -50 < i[n+4] and i[n+4] <50 then
			lcd.drawLine(24+38*(n-1),60,24+38*(n-1),65)
		elseif i[n+4] > 0 then
			lcd.drawFilledRectangle(38*(n-1)+24,60,9,6)
		else
			lcd.setColor(255,0,0)
			lcd.drawFilledRectangle(38*(n-1)+15,60,9,6)
			lcd.setColor(0,0,0)
		end
	end
end

--------------------------------------------------------------------------------
local function loop()
end

--------------------------------------------------------------------------------
local function init()
	system.registerTelemetry(1,appName,2,displayInputs)
end

return {init=init, loop=loop, author="Andre", version="0.02", name=appName}