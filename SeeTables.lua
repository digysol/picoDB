module(...,package.seeall)

--[[
  **************************************************************************************

	>>>>>> picoDB - community version <<<<<<
	______________________________________________________________________________________

	Copyright 2013 Dig.y.SoL

   	Licensed under the Apache License, Version 2.0 (the "License");
   	you may not use this file except in compliance with the License.
   	You may obtain a copy of the License at

       	http://www.apache.org/licenses/LICENSE-2.0

   	Unless required by applicable law or agreed to in writing, software
   	distributed under the License is distributed on an "AS IS" BASIS,
   	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   	See the License for the specific language governing permissions and
   	limitations under the License.
	______________________________________________________________________________________

        Function:	Debug tool for display of Lua table contents

	Assumptions:	Use of eLua platform with number and text support

  	**************************************************************************************

  	_______________________________ CHANGE LOG ________________________________

  	(DATE)		(DESCRIPTION)
  
  	Apr 29 2013	Community version initial build
	
  	**************************************************************************************

--]]

ResetGather = function()
	GatherMsg = ""
end

DoGather = function(tbl, lvl)
		local i, s, shft
		shft = ""
		for i=1,lvl,1 do shft = shft.."..." end
		if type(tbl) == "table" then
			for i, s in pairs(tbl) do
				if type(s) == "table" then
					GatherMsg = GatherMsg..shft.." "..i.." > ** table **\n"
					DoGather(s, lvl+1)
				else
					if type(s) == "function" then
						GatherMsg = GatherMsg..shft.." "..i.." > ** function **\n"
					elseif type(s) == "userdata" then
						GatherMsg = GatherMsg..shft.." "..i.." > 0x"..string.format("%x\n",s)
					elseif type(s) == "boolean" then
						x = "true"
						if not x then x = "false" end
						GatherMsg = GatherMsg..shft.." "..i.." > "..x.."\n"
					else				
						GatherMsg = GatherMsg..shft.." "..i.." > "..s.."\n"
					end
				end
			end
		else
		GatherMsg = GatherMsg..shft.." ".."This is not a table\n"
		end
		if lvl == 0 then return GatherMsg end
end

SeeTables = function(tbl, lvl)
		local i, s, shft, x
		shft = ""
		for i=1,lvl,1 do shft = shft.."..." end
		if type(tbl) == "table" then
			for i, s in pairs(tbl) do
				if type(s) == "table" then
					print(shft.." "..i.." > ** table **");
					SeeTables(s, lvl+1)
				else
					if type(s) == "function" then
						print(shft.." "..i.." > ** function **")
					elseif type(s) == "userdata" then
						print(shft.." "..i.." > 0x"..string.format("%x",s)) 						elseif type(s) == "boolean" then
						x = "true"
						if not x then x = "false" end
						print(shft.." "..i.." > "..x)
					else				
						print(shft.." "..i.." > "..s)
					end
				end
			end
		else
		print(shft.." ".."This is not a table")
		end

end
