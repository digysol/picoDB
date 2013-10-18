require "picoDB"

--[[
	**************************************************************************************


	Component:	pE_TMP102_sim.lua

        Function:	Setup and simulate a data acq process for the TI TMP102 temperature sensor

	Assumptions:	Use of picoDB along eLua platform with number, text.

	Author:		T. Freund

	Version:	pE.i.2013.09.29.N

 
  	**************************************************************************************

  	_______________________________ CHANGE LOG ________________________________

  	(DATE)		(DESCRIPTION)
  
  	Sep 29 2013	Initial build.

  	**************************************************************************************


--]]

-- delay factor between imulated data acquisition loops (half a second)
local TMP102_DELAY = 500000
-- max TMP102 allowable temperature (deg C)
local TMP102_T_MAX = 85
-- min TMP102 allowable temperature (deg C)
local TMP102_T_MIN = -25
-- max TMP102 allowable temperature (deg F)
local TMP102_T_MAX_F = 185
-- min TMP102 allowable temperature (deg F)
local TMP102_T_MIN_F = -13

local stat, msg, rcv, shft, i, msk, msb, str, lst, ttl, lim

-- retrieve the count of number of data requests from the TMP102
lim = tonumber(arg[1])	 

print("Initializing Protocol DB....")
-- definition of the Resource table for use in internal storage
stat = picoDB.dbDEFINE("Resource",{"name","string","type","number","source","string",
			"current_value","table","last_value","table",
			"units","string","max","number","min","number",
			"enumeration","table"});
if stat < 0 then print(stat.."- Resource def") end

-- definition of the Protocols table for use with the picoDB dbMESSAGE function
-- defining the request command to the TMP102
stat = picoDB.dbDEFINE("Protocols",{"ProtocolID","string",
			"MsgID","string","ParmID","number",
			"ParmType","string", "ParmRange","table","ParmDefault", "string",
			"ParmLoc","number", "ParmSize", "number"});		
if stat < 0 then print(stat.."- Protocols def") end

-- definition of the Verifier table for use with the picoDB dbVERIFY function
-- verifying the response message from the TMP102 and processing the received raw data
stat = picoDB.dbDEFINE("Verifier",{"ProtocolID","string",
			"MsgID","string","ParmID","number",
			"ParmProcess","string"});		
if stat < 0 then print(stat.."- Verifier def") end

-- PROTOCOLS

print("Populating Protocol DB....")

-- Request temperature command
stat = picoDB.dbBUILD("Protocols","RQ_Temp_Addr",
		{"ProtocolID","Temp","MsgID","RQTemp",
		"ParmID",1,"ParmType","integer",
		"ParmRange",{0x92},"ParmDefault","0x92","ParmLoc",1, "ParmSize",1})
if stat < 0 then print(stat.."_RQ_Temp_Addr") end

-- Received temperature message structure
stat = picoDB.dbBUILD("Protocols","RS_Temp_Val",
		{"ProtocolID","Temp","MsgID","RSTemp",
		"ParmID",1,"ParmType","integer",
		"ParmRange",{TMP102_T_MIN,TMP102_T_MAX},"ParmDefault","0","ParmLoc",1, "ParmSize",1})
if stat < 0 then print(stat.."_RS_Temp_Val") end

-- VERIFIER

-- Received temperature message processing via conversion of raw data to deg F from deg C
stat = picoDB.dbBUILD("Verifier","R_Temp_Val",
		{"ProtocolID","Temp","MsgID","RSTemp",
		"ParmID",1,"ParmProcess","{P_,1.8,*,32,+,R_Temp_Val,=}"})
if stat < 0 then print(stat.."_V_R_Temp_Val") end

-- RESOURCES

-- Internal parameter (object) storing the verified data value
stat = picoDB.dbBUILD("Resource","Temp_Val",
		{"name","Temp_MSB","type",0,"source","internal",
			"current_value",{0},"last_value",{0},
			"units","NONE","max",TMP102_T_MAX_F,"min",TMP102_T_MIN_F,
			"enumeration",{}})
if stat < 0 then print(stat.."_R_Temp_Val") end

if stat >= 0 then
	for i=1,lim do
		-- mark 'watch' for one loop
		str = tmr.start(0)
		-- formulate temperature reading request
		msg = picoDB.dbMESSAGE("Temp","RQTemp",{1,0x92})
		if type(msg) ~= "string" then 
			print("ERROR ("..msg..") - fault formulating request")
		else
			print("REQUEST: "..msg)		
		end
		-- simulate getting a temperature value back from the TMP102
		rcv = math.random(TMP102_T_MIN,TMP102_T_MAX)
		rcv = string.format("%02x", rcv)
		print("RESPONSE: "..rcv)
		-- verify the 'received' raw data value
		stat = picoDB.dbVERIFY("Temp","RSTemp",rcv)
		if stat ~= 0 then 
			print("ERROR - temperature response is over range")
		else
			-- stop 'watch' for one loop
			lst = tmr.read(0)
			-- get total time elapsed and display it
			ttl = tmr.gettimediff(0,str,lst)/1000000
			print("Total time .. "..ttl)	 
		end
		collectgarbage("collect")
		-- wait until next reading
		tmr.delay(tmr.SYS_TIMER, TMP102_DELAY)
	end
end
