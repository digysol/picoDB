module(...,package.seeall)
-- require"SeeTables"

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
	Author:		T. Freund

	Version:	pDB_comm.2013.04.22.1

	Component:	picoDB.lua

        Function:	Non-SQL data base management system for microcontrollers

	Assumptions:	Use of eLua platform with number and text support

	Author:		T. Freund

	Version:	pDB_comm.2013.04.22.1

	Background:

		picoDB is based on 2 lists: Metaverse and DBverse. Metaverse provides a list of database 
		names and their corresponding metadata. DBverse provides, for each database listed in 			Metaverse, a list of keys and corresponding data tuples for each data base.

 		The structure of Metaverse is as follows:

				{<database_list>,<metadata_list>}

		where
				<database_list> = list of the names of the active databases

				<metadata_list> = {<db_metadata_list<,<metadata_list>>}

				<db_metadata_list> = {<pair_list><,<db_metadata_list>>}

				<pair_list> = {<pair><,<pair_list>>}
			
				<pair> = {ename = <attribute_name>, content = <attribute_type>}

				<attribute_name> = name of the data attribute in text format

				<attribute_type> = type of data stored for this data attribute
						   (same values as the type() function)

		indices for each of the above Metaverse lists are as follows:

		(LIST)			(INDEX)

		<database_list>		(default numeric table index within Metaverse)
		<metadata_list>		(default numeric table index within Metaverse)
		<db_metadata_list>	element of <database_list> (a database name)
		<pair_list>		(default numeric table index within <db_metadata_list>)
		a database tool for 32-bit microcontrollers<pair>			(default numeric table index within <pair_list>)
		<attribute_name>	"ename" within <pair>
		<attribute_type>	"content" within <pair>
		
		
 		The structure of DBverse is as follows:

				{<key_list>,<data_list>}

		where,
				<key_list> = {<db_key_list><,<key_list>>}

				<db_key_list> = {<key><,<db_key_list>>}

				<key> = key to a data tuple for a particular database

				<data_list> = {<data_tuple_list><,<data_list>>}

				<data_tuple_list> = {<data_tuple><,<data_tuple_list>>}

				<data_tuple> = {<data><,<data_tuple>>}

				<data> = value of a data attribute consistent with the content type

		indices for each of the above Metaverse lists are as follows:

		(LIST)			(INDEX)

		<key_list>		(default numeric table index within DBverse)
		<data_list>		(default numeric table index within DBverse)
		<db_key_list> 		element of <database_list> in Metaverse (a database name)
		<key>			(default numeric table index within <db_key_list>)
		<data_tuple_list>	element of <database_list> in Metaverse (a database name)
		<data_tuple>		<key> within <db_key_list>
		<data>			<attribute_name> within <pair_list> in Metaverse 

		All picoDB databases are analogous to 1-table relational databases.	
 
  	**************************************************************************************

  	_______________________________ CHANGE LOG ________________________________

  	(DATE)		(DESCRIPTION)
  
  	Apr 22 2013	Community version initial build

	
  	**************************************************************************************

--]]

-- global list of databases
dbverse = {};
-- global list of metatuples
metaverse = {};
-- global for the storage area of dbverse
dbvpath = "dbverse";
-- global for the storage area of metaverse
mvpath = "metaverse";


--[[	**** picoDB METHODS ****    --]]

--[[ 
	dbVERIFY_DB:	verify that a database exists

	arguments:
		<dbname>:	name of a "database",

	return value:
		the index of the database in the database list
		or -1 if the database ID is non-existent
--]]

local dbVERIFY_DB = function (x_dbname)
	local i, stuff, locdb
	-- retrieve the database list
	locdb = -1
	if #metaverse > 0 then
		for i, stuff in pairs(metaverse[1]) do
			if x_dbname == stuff then
				locdb = i; break;
			end
		end
	end
	return locdb
end

--[[ 
	dbVERIFY_ATTR:	verify that a data attribute of a database exists

	arguments:
		<dbname>	name of a database
		<attr>		name of a data attribute

	return value:
		the index of the attribute in the metadata list for this database or
		-1 if the database ID is non-existent,
		-2 if no metadata found for this attribute
--]]

local dbVERIFY_ATTR = function (x_dbname, x_attr)
	local i, j, stuff, stuff2;
	i = dbVERIFY_DB(x_dbname)
	if i < 0 then return -1 end
	-- retrieve the metadata for this database
	stuff = metaverse[2]
	stuff = stuff[x_dbname]
	j = -2;
	for i, stuff2 in pairs(stuff) do
		if i == x_attr then 
			j = i; break;
		end
	end
	return j
end

--[[ 
	dbVERIFY_LOC:	verify that a locator expression for a datbase is valid

	arguments:
		<locator>:	list of name-operator-value triples that act as a conjunction
				to locate items.
				NOTE - The format of the list is:
					{<ename>,<op>,<val>,......,<ename>,<op>,<val>}
				where
					<ename>	= 	name of the data attribute 
							consistent with the metadata list of the database
					<op>	=	comparison operator ("=","<=".">=","<",">","in")
					<val>	=	single value or list of values (for "in")
							consistent with the metadata list of the database

		<meta>:		metadata list for the database used with <locator>

	return value:
		a sucess indicator
			0 = OK
			-1 = incorrect comparison operator found in locator
			-2 = incompatible data attribute name or comparison value

	ASSUMPTION: the metaverse entry has been verified through the existence of a database via db_VERIFY_DB
--]]

local dbVERIFY_LOC = function (x_locator, x_meta)
	local ops = {"=",">","<","<=",">=", "in"}
	local i, j, stuff, stat, stuff2, k, cnt
	-- verify that
	--	(1) the data attributes in the locator are consistent with the metadata
	--	(2) the comparison operator is correct	-- 	
	--	(3) the type of the comparison values are consistent with the metadata
	for i=1,#x_locator,3 do
		stat = -1
		for j, stuff in pairs(ops) do
			if x_locator[i+1] == stuff then 
				stat = 0; break;
			end 
		end
		if stat < 0 then return -1 end
		stat = -2
		for j, stuff in pairs(x_meta) do
			if x_locator[i] == j and 
			   type(x_locator[i+2]) == stuff and
			   x_locator[i+1] ~= "in"
			then
				stat = 0;
			elseif x_locator[i] == j and 
			       x_locator[i+1] == "in"
			then
				stuff2 = x_locator[i+2]; cnt = 0;
				for k=1,#stuff2,1 do
					if type(stuff2[k]) == stuff then cnt=cnt+1 end 
				end
				if cnt == #stuff2 then stat = 0 end
			end
		end
	end
	return stat;
end

--[[ 
	dbDO_LOC:	perform a locator constraint check on a dbverse tuple

	arguments:
		<locator>:	list of name-operator-value triples that act as a conjunction
				to locate items.
				NOTE - The format of the list is:
					{<ename>,<op>,<val>,......,<ename>,<op>,<val>}
				where
					<ename>	= 	name of the data attribute 
							consistent with the metadata list of the database
					<op>	=	comparison operator ("=","<=".">=","<",">","in")
					<val>	=	single value or list of values (for "in")
							consistent with the metadata list of the database

		<db_tuple>:	data tuple from dbverse to be checked against the locator

	return value:
		0 = no matches
		1 = fully matched

	ASSUMPTION: the metaverse entry has been verified through db_VERIFY_DB and
		    the locator list has been verfied to be correct
--]]

local dbDO_LOC = function (x_locator, x_tuple)
	local i, stuff2, k, m, fnd, stuff4, amt
	fnd = 0
	for i, stuff2 in pairs(x_tuple) do
		-- verify that the tuple matches the locator
		for k=1,#x_locator, 3 do
			if i == x_locator[k] then
				if (x_locator[k+1] == "=" and
				    stuff2 == x_locator[k+2]) or
				   (x_locator[k+1] == ">" and
				   stuff2 > x_locator[k+2]) or
				   (x_locator[k+1] == "<" and
				   stuff2 < x_locator[k+2]) or
				   (x_locator[k+1] == ">=" and
				   stuff2 >= x_locator[k+2]) or
				   (x_locator[k+1] == "<=" and
				   stuff2 <= x_locator[k+2])
				then
					fnd = fnd+1
				elseif x_locator[k+1] == "in" then
					stat = 0
					for m, stuff4 in pairs(x_locator[k+2]) do
						if stuff2 == stuff4 then 
							stat = m; break;
						end
					end
					if stat > 0 then fnd = fnd+1 end
				end
			end
		end
	end
	amt = math.ceil(#x_locator / 3)
	if fnd == amt then fnd = 1 else fnd = 0 end
	return fnd
end

--[[ 
	dbSERIALIZE:	serialize a table

	arguments:	"dbverse" or "metaverse"

	return value:
		string representing the serialized metaverse or dbverse or
		a negative number to indicate an error consition
--]]

local dbSERIALIZE = function(y)
	local tbl = "{"
	local i, stuff, dbx, stuff2, j, stuff3, k
	tbl="{{"
	if y == "metaverse" then
		-- process the database list
		for i, stuff in pairs(metaverse[1]) do tbl = tbl..stuff.."," end
		-- close off the database list section
		tbl = string.sub(tbl,1,#tbl-1).."},{"
		-- process the metadata for each database
		for i, stuff in pairs(metaverse[2]) do
			tbl = tbl..i.."={"
			-- process all attribute pairs
			for j, stuff2 in pairs(stuff) do
				tbl = tbl..j.."="..stuff2..","
			end
			tbl = string.sub(tbl,1,#tbl-1).."},"
		end
		-- close off the metadata section
		tbl = string.sub(tbl,1,#tbl-1).."}"		
	elseif y == "dbverse" then
		-- process the keys list section
		for i, stuff in pairs(dbverse[1]) do
			tbl = tbl..i.."={"
			for dbx, stuff2 in pairs(stuff) do tbl = tbl..stuff2.."," end
			-- close off the keys list for a database
			tbl = string.sub(tbl,1,#tbl-1).."},"
		end
		-- close off the keys list section
		tbl = string.sub(tbl,1,#tbl-1).."},{"
		-- process the data section
		for i, stuff in pairs(dbverse[2]) do
			tbl = tbl..i.."={"
			-- process an individual, keyed data tuple list
			for j, stuff2 in pairs(stuff) do
				tbl = tbl..j.."={"
				-- process the content of an individual data tuple
				for k, stuff3 in pairs(stuff2) do
					tbl = tbl..k.."="..stuff3.."," 
				end				
				tbl = string.sub(tbl,1,#tbl-1).."},"
			end 
			tbl = string.sub(tbl,1,#tbl-1).."},"
		end		
		-- close off the data section
		tbl = string.sub(tbl,1,#tbl-1).."}"
	else
		-- unknown database universe
		return -1
	end
	-- close off either verse list
	tbl = tbl.."}"		
	return tbl
end

--[[ 
	dbUNSERIALIZE:	unfold a serialized table

	arguments:	

		(1) "dbverse" or "metaverse"
		(2) corresponding serialization (string)

	return value:
		0 - all went OK,
		-1 - invalid table type (not 'dbverse' or 'metaverse')
		-2 - serialization parameter not a string or empty
		-3 - metaverse serialization not properly structured
		-4 - database index in metadata incompatible with master database list
		-5 - metaverse no available to reconstruct dbverse
		-6 - dbverse serialization not properly structured
--]]

local dbUNSERIALIZE = function(tbl, xverse)
	local i, str, lst, nxt1, dblst, metastuff, dbidx, nxtmeta
	local metalst, nxtlst, str2, lst2, nxtitm1, nxtitm2, thislst, keylst, dtlst
	local xstuff, nxttp, j, thiskey
	-- verify appropriate picoDB (TM) table type
	if tbl ~= "dbverse" and tbl ~= "metaverse" then return -1 end
	-- verify that the 2nd parameter is a string and not empty
	if xverse == nil or xverse == "" or type(xverse) ~= "string" then return -2 end
	-- if this is metaverse serialization ....
	if tbl == "metaverse" then
		metaverse = {}
		-- build the database list section (dblst)
		str, lst = string.find(xverse,"{[a-zA-Z0-9,]+}",1)
		if str == nil or lst == nil then return -3 end
		nxt1 = ""; dblst = {}; str = str+1; lst = lst-1;
		for  i=str,lst,1 do
			if string.sub(xverse,i,i) == "," or i == lst then
				if i == lst then nxt1 = nxt1..string.sub(xverse,i,i) end
				dblst[#dblst+1] = nxt1; nxt1 = "";
			else
				nxt1 = nxt1..string.sub(xverse,i,i)
			end
		end
		-- build the metaverse section (metalst)
		str, lst = string.find(xverse,"},{",1)
		str = lst+1; lst = #xverse-2;
		metastuff = string.sub(xverse,str,lst); str = 1; metalst = {};
		while str <= #metastuff do
			-- get the next database name used as index
			str, lst = string.find(metastuff,"[%a%d]+=",str);
			if str == nil or lst == nil then return -3 end
			lst = lst-1; 
			dbidx = string.sub(metastuff,str,lst); j = -1;
			-- verify that the database name is compatible with the database list
			for i=1,#dblst,1 do 
				if dblst[i] == dbidx then j = i; break end			
			end
			if j < 0 then return -4 end 
			-- extract the metadata list for this database
			str = lst+2
			str, lst = string.find(metastuff,"{[%a%d.=,]+}",str)
			if str == nil or lst == nil then return -3 end
			str = str + 1; lst = lst - 1;
			nxtmeta = string.sub(metastuff,str,lst); nxtlst = {}; nxt1="";
			for i=1,#nxtmeta,1 do
				if string.sub(nxtmeta,i,i) == "," or i == #nxtmeta then
					if i == #nxtmeta then nxt1 = nxt1..string.sub(nxtmeta,i,i) end
					str2 = string.find(nxt1,"=",1)
					if str2 == nil then return -3 end
					nxtitm1 = string.sub(nxt1,1,str2-1)
					nxtitm2 = string.sub(nxt1,str2+1,#nxt1)
					nxtlst[nxtitm1] = nxtitm2
					nxt1=""
				else
					nxt1 = nxt1..string.sub(nxtmeta,i,i)
				end
			end
			metalst[dbidx] = nxtlst
			str,lst = string.find(metastuff,"},",lst)
			if str == nil or lst == nil then break end
			str = lst +1
		end
		metaverse[1] = dblst; metaverse[2] = metalst
	elseif tbl == "dbverse" then
		dbverse = {}
		-- dbverse serialization ....
		-- verify that metaverse has been established
		if metaverse == nil then return -5 end
		-- retrieve the data base list and metadata lst from metaverse
		dblst = metaverse[1]; metalst = metaverse[2]; keylst = {}
		-- build the keys list section (keylst)
		str=1
		lst = string.find(xverse,"},{",str) -- locate the end of the keys lst
		if lst == nil then return -6 end
		lst = lst-1; str = 3; xstuff = string.sub(xverse,str,lst) -- get contents of the keys lst
		str = 1
		while str <= #xstuff do
			lst = string.find(xstuff,"=",str)
			if lst == nil then return -6 end
			lst=lst-1
			dbidx = string.sub(xstuff,str,lst) -- get the name of the database used as index
			nxt1 = dbVERIFY_DB(dbidx)	-- verify that this database has been defined
			if nxt1 < 0 then return -6 end
			str = lst + 3
			lst = string.find(xstuff,"}",str) -- end of the list of keys for this database
			if lst == nil then return -6 end
			lst=lst-1
			nxtmeta = string.sub(xstuff,str,lst) -- get the key list for this database index
			nxtlst = {}; nxt1 = "";
			for i=1,#nxtmeta,1 do
				if string.sub(nxtmeta,i,i) == "," or i == #nxtmeta then
					if i == #nxtmeta then nxt1 = nxt1..string.sub(nxtmeta,i,i) end
					nxtlst[#nxtlst + 1] = nxt1; nxt1 = "";
				else
					nxt1 = nxt1..string.sub(nxtmeta,i,i)
				end
			end
			keylst[dbidx] = nxtlst; str = lst+3;
		end

		-- build the data tuples section (dtlst)
		dtlst = {};str = 1;
		lst, str = string.find(xverse,"},{",str) -- get the start of the data tuples
		if lst == nil or str == nil then return -6 end
		str = str + 1
		lst = #xverse-2	-- end of the datatuples
		xstuff = string.sub(xverse,str,lst)  -- contents of the data tuples
		str = 1; thislst = {}
		while str <= #xstuff do
			lst=string.find(xstuff,"=",str)
			if lst == nil then return -6 end
			lst=lst-1
			dbidx = string.sub(xstuff,str,lst) -- get the name of the database used as index
			nxt1 = dbVERIFY_DB(dbidx)	-- verify that this database has been defined
			if nxt1 < 0 then return -6 end
			str = lst+2
			lst=string.find(xstuff,"}}",str) 
			if lst == nil then return -6 end
			nxtmeta = string.sub(xstuff,str,lst)  -- get all the the data tuples and their keys for this database
			str2 = 2; nxtlst = {};
			while str2 < #nxtmeta do
				lst2 = string.find(nxtmeta,"=",str2)
				if lst2 == nil then return -6 end
				lst2 = lst2 - 1 
				nxt1 = string.sub(nxtmeta,str2,lst2); thiskey = nil;
				-- verify the next key as valid per the extracted key list
				for i, j in pairs(keylst[dbidx]) do
					if j == nxt1 then thiskey = j; break end
				end
				if thiskey == nil then return -6 end
				str2 = lst2 + 3	-- start of the content for this data tuple
				lst2 = string.find(nxtmeta,"}",str2)
				if lst2 == nil then return -6 end
				lst2 = lst2 - 1	-- end of the content for this data tuple
				nxttp = string.sub(nxtmeta,str2,lst2); nxt1 = ""; thislst = {};
				for i =1,#nxttp,1 do
					if string.sub(nxttp,i,i) == "," or i == #nxttp then
						if i == #nxttp then nxt1=nxt1..string.sub(nxttp,i,i) end
						j = string.find(nxt1,"=")
						if j == nil then return -6 end
						nxtitm1 = string.sub(nxt1,1,j-1)
						nxtitm2 = string.sub(nxt1,j+1,#nxt1)
						j = dbVERIFY_ATTR(dbidx,nxtitm1)
						if type(j) == "number" and j < -0 then return -6 end
						j = tonumber(nxtitm2)
						if j ~= nil then nxtitm2 = j end
						thislst[nxtitm1] = nxtitm2; nxt1=""; 
					else
						nxt1=nxt1..string.sub(nxttp,i,i)
					end
				end
				nxtlst[thiskey] = thislst
				str2 = lst2 + 3
			end
			dtlst[dbidx] = nxtlst
			str = lst+3
		end
		dbverse[1] = keylst; dbverse[2] = dtlst;
	end
	return 0
end

--[[ 
	dbSETUP:	initialize dbverse and multiverse from storage

	arguments:	NONE

	return value:
		a status code of the change ( 0 = OK, negative number = error occured )
--]]

dbSETUP = function ()

-- open dbverse in storage
local dbv = io.open(dbvpath,"r");
-- open metaverse in storage
local mv = io.open(mvpath,"r");
-- fetch metaverse in storage
dbUNSERIALIZE("metaverse",mv:read("*all"));
-- fetch dbverse in storage
dbUNSERIALIZE("dbverse",dbv:read("*all"));
-- release storage
dbv:close();
mv:close();

return 0;

end

--[[ 
	dbCOMMIT:	commit to storage all universes

	arguments:	NONE

	return value:
		a status code of the change ( 0 = OK, negative number = error occured )
--]]

dbCOMMIT = function ()

-- open dbverse in storage
local dbv = io.open(dbvpath,"w");
-- open metaverse in storage
local mv = io.open(mvpath,"w");
-- write dbverse to storage
dbv:write(dbSERIALIZE("dbverse"));
dbv:flush();
-- write metaverse to storage
mv:write(dbSERIALIZE("metaverse"));
mv:flush();
-- release storage
dbv:close();
mv:close();

end

--[[ 
	dbMESSAGE:	format a string of hexadecimal values that represented
			a message under a protocol

	arguments:	protocol ID - the identifier of the protocol
			message ID - the identifier of a message in this protocol
			message content - a table in the format:
				{<parm_id>,<val>,...., <parm_id>,<val>}

			where
				<parm_id>	the name of a parameter for the message ID 
						under the protocol ID
						as defined in the Protocols database

			`	<val>		a valid value for the associated parameter

			NOTE -
			
			By default, a database named Protocols is added at initialization time
			to every picoDB set of databases. Each record identifies a parameter in a messageI.
			Its metadata is as follows:

			ATTRIBUTE		TYPE		DESCRIPTION
			_________		____		___________
	
			Protocol ID		string		identifier of the protocol,
			Message ID		string		identifier for a message under this protocol,
			Parameter ID		string		name of the parameter in this record,
			Parameter type		string		type for the parameter ("integer", "short", "float" or "string"),
			Parameter range		table		a table having a minimum-maximum pair or an enumeration
								giving the valid range of values for this parameter,
			Parameter default	string		default value for this parameter if none specified
			Parameter location	number		location of the value for this parameter in the
								message structure,
			Parameter size		number		number of bytes occupied by this parameter in the
								message structure.
	
	return value:
		a string of hexadecimal values or
		a negative number indicating a failures as follows:
			-1 = unabled to locate "Protocols" database
			-2 = invalid locator expression
			-3 - message content list not a table
			-4 - invalid parameter name in the message content list
			-5 - invalid parameter value in the message content list
--]]

dbMESSAGE = function (xproto, xmsg, xcontent)
	local lst, msgout, i, parmref, parmsin, j, parmdef, parmrng, nxt, szref, sz, nxt2
	szref = {"short","integer","float"}
	-- retrieve the parameter definitions for this protocol message
	lst = dbLOCATE("Protocols",{"ProtocolID","=",xproto,"MsgID","=",xmsg})
	if type(lst) == "number" then return lst end
	-- verify that the message content list is a table
	if type(xcontent) ~= "table" then return -3 end
	-- restructure the message contents list to be indexed by parameter name
	parmsin = {}
	for i=1,#xcontent,2 do parmsin[xcontent[i]] = xcontent[i+1] end
	-- go through the reference list of the message parameters
	-- and format the message using the message contents list
	msgout = {}
	for i, parmref in pairs(lst) do
		for j, nxt in pairs(szref) do
			if parmref["ParmType"] == nxt then
				sz = math.pow(2,j)
				break
			end
		end
		if parmsin[parmref["ParmID"]] ~= nil then
			-- verify that the value in the message content list is the right type
			if (parmref["ParmType"] == "string" and
			    type(parmsin[parmref["ParmID"]]) ~= "string") or
			   ((parmref["ParmType"] == "float" or
			     parmref["ParmType"] == "short" or 
			     parmref["ParmType"] == "integer") and
			    type(parmsin[parmref["ParmID"]]) ~= "number") then return -5 end
			-- verify that the value in the message content list is in range
			parmrng = {}; parmrng = parmref["ParmRange"];
			if type(parmsin[parmref["ParmID"]]) == "number" and
			   #parmrng == 2 and parmrng[1] <= parmrng[2] and
			   (parmsin[parmref["ParmID"]] >  parmrng[2] or 
			    parmsin[parmref["ParmID"]] <  parmrng[1]) then 
				return -5
			elseif parmref["ParmType"] == "string" then
				j = 1;
				while j <= #parmrng and parmsin[parmref["ParmID"]] ~= parmrng[j]  do j=j+1 end
				if j > #parmrng then return -5 end
			end
			-- add the value at the correct position
			if parmref["ParmType"] == "string" then
				parmrng = parmsin[parmref["ParmID"]]; nxt = "";
				for j=1,parmref["ParmSize"],1 do
					nxt2 = string.sub(parmrng,j,j)
					nxt = nxt..string.format("%02x",string.byte(nxt2))
				end
				msgout[parmref["ParmLoc"]] = nxt
			else
				msgout[parmref["ParmLoc"]] = string.format("%0"..sz.."x", parmsin[parmref["ParmID"]])
			end
			-- remove the parameter entry from the restructured list
			parmsin[parmref["ParmID"]] = nil
		else
		-- parameter missing, apply the default value
			if parmref["ParmType"] == "string" then
				parmrng = parmref["ParmDefault"]; nxt="";
				for j=1,parmref["ParmSize"],1 do
					nxt2 = string.sub(parmrng,j,j)
					nxt = nxt..string.format("%02x",string.byte(nxt2))
				end
				msgout[parmref["ParmLoc"]] = nxt
			else
				nxt = tonumber(parmref["ParmDefault"])
				msgout[parmref["ParmLoc"]] = string.format("%0"..sz.."x",nxt)
			end
		end
	end
	if #parmsin > 0 then return -4 end
	nxt = ""
	for i, sz in pairs(msgout) do nxt = nxt..sz end
	return nxt
end

--[[ 
	dbVERIFY:	verify a received message operating under a protocol
			and perform processing on the parameters making up the message content 

	arguments:	protocol ID - the identifier of the protocol
			message ID - the identifier of a message in this protocol
			message content - a string consisting of hexadecimal values

			By default, a database named Verifier is added at initialization time
			to every picoDB set of databases. Each record identifies a parameter in a messageI.
			Its metadata is as follows:

			ATTRIBUTE		TYPE		DESCRIPTION
			_________		____		___________
	
			Protocol ID		string		identifier of the protocol,
			Message ID		string		identifier for a message under this protocol,
			Parameter ID		string		name of the parameter in this record,
			Parameter processing	string		a string containing a series of mathematical 									operations in a stack machine structure using 									Resources and resulting a change of value for 									a Resource

			ASSUMPTION - The parameter processing attribute is a mathematical formula
				     that results in a numerical value.

			NOTE - 	The contents of the Parameter processing attribute uses a stack machine
				structure. That is, one or more operands followed by an operator. The operator
				is a standard arithmetic operator (+,-,*,/,%,^). The operands can be a 					numerical value or a Resource ID whose value value can be retrieved from the 					Resource database. Once an operator is reached, that operation is performed 					on all prior operands. The result is then pushed onto the stack represented 					through the attribute's table. When all operations are completed, there is 					only one item in the stack: the final result.

				An operand identifies itself as a resource by starting with 'R_'. An operand
				identifies itself as the parameter value associated with this process as 'P_'.
				The last item in the stack is a resource assignment operator which is in the 					format:
	
						=R_<resource_name>
	return value:
		 0 = processing went OK
		-1 = Protocols database cannot be located
		-2 = The protocol ID or message ID records are not in the Protocols database
		-3 = the message content is not a string
		-4 = the message content is not all hexadecimal values
		-5 = message content is not the correct size 
		-6 = Verifier database cannot be located
		-7 = The protocol ID or message ID records are not in the Verifier database
		-8 = mismatch between parameter values in the message and parameter processes 
		     in the Verifier database
		-9 = parameter value out of protocol range
--]]

dbVERIFY = function (xproto, xmsg, xcontent)
	local stat, hexref, i, j, k, lstin, parmref, nxt, idx
	local parmtype, parmsz, parmname, parmrng, ttl, parmval, parmproc, parmstack, opernds, parmv
	local parmmax, parmmin, xval, tkn, rslt, nxt, elemstack
	hexref = {"0","1","2","3","4","5","6","7","8","9","a","b","c","d","e","f"}
	-- verify that the contents is a hex string
	if type(xcontent) ~= "string" then return -3 end
	lstin = string.lower(xcontent)
	for i=1,#lstin,1 do
		j = 1
		while j<= #hexref and string.sub(lstin,i,i) ~= hexref[j] do j=j+1 end
		if j > #hexref then return -4  end
	end
	-- retrieve the parameter definitions for this protocol message
	parmref = dbLOCATE("Protocols",{"ProtocolID","=",xproto,"MsgID","=",xmsg})
	if type(parmref) == "number" then return parmref end
	-- retrieve the parameter ID, its location, and size in bytes of its value in the message content
	parmsz={}; parmloc={}; parmtype={}; parmrng = {};
	for i, nxt in pairs(parmref) do
		parmsz[nxt["ParmID"]] = 2*nxt["ParmSize"] -- record the number of hex characters representing a value
		parmloc[nxt["ParmID"]] = nxt["ParmLoc"]
		parmtype[nxt["ParmID"]] = nxt["ParmType"]
		parmrng[nxt["ParmID"]] = nxt["ParmRange"]
	end
	-- verify that the message content is the correct size per the Protocols database
	ttl = 0
	for i = 1,#parmsz,1 do ttl = ttl+parmsz[i] end
	if ttl ~= #xcontent then return -5 end
	-- retrieve the parameter processing from the Verifier database
	parmv = dbLOCATE("Verifier",{"ProtocolID","=",xproto,"MsgID","=",xmsg})
	if type(parmv) == "number" then return parmref-5 end
	parmproc = {}
	for i, nxt in pairs(parmv) do
		if parmloc[nxt["ParmID"]] == nil then
			return -5
		else
			parmproc[nxt["ParmID"]] = nxt["ParmProcess"] 
		end 
	end
	-- verify that the number of parameter references and the parameter processes match
	if #parmloc ~= #parmproc then return -8 end
	-- if any of the parameters are counter dependent, expand the parameter to include their number
	i = 1
	while i <= #parmsz do
		-- if the parameter location is dependent on a counter ....
		if parmloc[i] < 0 then
			-- get the location in the content string of counter
			idx = math.abs(parmloc[i])
			-- get the actual counter value from the content string
			ttl = tonumber("0x"..string.sub(xcontent,idx,idx + parmsz[idx] - 1))
			if ttl == nil then return -5 end
			-- record the parameter size, type, and procedure for the repeats
			parmval = {}
			parmval[1] = parmsz[i]; parmval[2] = parmtype[i]; 
			parmval[3] = parmproc[i]; parmval[4] = parmrng[i]; 
			-- expand the list to include the appropriate number of values
			parmloc[i] = 2*parmloc[idx]+parmsz[idx];
			idx = idx+2; stat = ttl; ttl = idx+ttl-3;
			for j = idx,ttl,1 do
				table.insert(parmsz,j,parmval[1])
				table.insert(parmtype,j,parmval[2])
				table.insert(parmproc,j,parmval[3])
				table.insert(parmrng,j,parmval[4])
				table.insert(parmloc,j,parmloc[i]+j*parmval[1])
			end
			-- adjust search index
			i = i + stat
		else
			-- adjust the parameter location to conform to the actual start location
			-- in the message content string
			parmloc[i] = 2*parmloc[i]-1
			i = i+1
		end
	end
	-- extract the values associated with each parameter and verify their values against the parameter 		-- range
	parmval = {}; nxt = 1;
	for i=1,#parmsz,1 do
		if parmtype[i] == "short" or
		   parmtype[i] == "integer" or  
		   parmtype[i] == "float" then
			parmval[i] = tonumber("0x"..string.sub(xcontent,nxt,nxt + parmsz[i] - 1))
			-- range check
			idx = parmrng[i];
			if parmval[i] > idx[2] or parmval[i] < idx[1] then return -9 end
		else
			parmval[i]=""
			for j=1,parmsz[i],2 do
				ttl = "0x"..string.sub(xcontent,i,i+1)
				parmval[i] = parmval[i]..string.char(tonumber(ttl))
			end
			-- range check
			idx = parmrng[i]; j = 1;
			while j <= #idx and idx[j] ~= parmval[i] do j = j+1 end
			if j > #idx then return -9 end	
		end
		nxt = nxt + parmsz[i]  
	end
	-- carry out the parameter processes with the available parameter values
	for i, parmv in pairs(parmval) do
		parmstack = parmproc[i];
		elemstack={}; tkn = ""; rslt = "";
		for j=1,string.len(parmstack) do
			nxt = string.sub(parmstack,j,j)
			if nxt == "{" then
				rslt=""; tkn="";
			elseif nxt == "}" then
				if rslt ~= "" then 
					table.insert(elemstack, rslt)
					rslt = ""
				end
			elseif nxt == "," then
				if rslt ~= "" then 
					table.insert(elemstack, rslt)
					rslt = ""
				elseif tkn ~= "" then 
					table.insert(elemstack, tkn)
					tkn = ""
				end
			elseif type(string.match(nxt,"[=%*%+%-/%%%^]")) == "number" then
				op2 = elemstack[#elemstack]
				table.remove(elemstack)
				op1 = elemstack[#elemstack]
				table.remove(elemstack)
				if nxt ~= "=" then
					if op2 == "P_" then
						op2 = parmval[i]
					elseif string.sub(op2,1,2) == "R_" then
						ttl = dbLOCATE("Resource",{"name","=",string.sub(op2,3)})
						if type(ttl) == "number" then return -5 end
						xval = ttl["current_value"]
						op2 = xval[1]
					end
				end
				if op1 == "P_" then
					op1 = parmval[i]
				elseif string.sub(op1,1,2) == "R_" then
					ttl = dbLOCATE("Resource",{"name","=",string.sub(op1,3)})
					if type(ttl) == "number" then return -5 end
					xval = ttl["current_value"]
					op1 = xval[1]
				end
				if nxt == "+" then
					rslt = op1+op2
				elseif nxt == "-" then
					rslt = op1-op2
				elseif nxt == "*" then
					rslt = op1*op2
				elseif nxt == "/" then
					rslt = op1/op2
				elseif nxt == "%" then
					rslt = op1%op2
				elseif nxt == "^" then
					rslt = op1^op2
				elseif nxt == "=" then
					ttl = dbBUILD("Resource",
							{"name","=",string.sub(op2,3)},
							{"current_value",{op1}})
					if type(ttl) == "number" and ttl < 0 then return -5 end
				end
			else
				tkn = tkn..nxt
			end

		end
	end
	return 0
end

--[[ 
	dbLOCATE:	retrieve 1 or more items from a tuple, or a complete tuple

	arguments:
		<dbname>:	database name
		<locator>:	list of data attribute conditions compatible with
				dbVERIFY_LOC

	return value:
		a list of data tuples in <dbname> matched through <locator> or
		an empty list if no data tuples match the locator or
		a negative number indicating a 	failure:
			-1 = invalid database name
			-2 = invalid locator expression
--]]

dbLOCATE = function (x_dbname, x_locator)
	local stat, stuff, i, stuff2, db_lst
	-- verify the database name
	stat = dbVERIFY_DB(x_dbname)
	if stat < 0 then return -1 end
	-- verify the locator expression
	stuff = metaverse[2]; stuff = stuff[x_dbname];
	stat = dbVERIFY_LOC(x_locator, stuff)
	if stat < 0 then return -2 end
	--locate data tuples that match the locator expression
	stuff = dbverse[2]; stuff = stuff[x_dbname]; db_lst={}; fnd = 0
	for i, stuff2 in pairs(stuff) do
		stat = dbDO_LOC(x_locator, stuff2)
		if stat > 0 then db_lst[#db_lst + 1] = stuff2 end
	end
	return db_lst;
end

--[[ 
	dbBUILD:		add or update data to a database

	arguments:
		<dbname>:	database name

		<key>		key for the data tuple in dbverse or
				locator list per dbVERIFY_LOC which indicates one or more updates

		<dbtuple>:	data to be added in the format:
					{<ename>, <val>,....,<ename>, <val>}
				where
					<ename>	=	name of data attribute compatible with
							the metadata of the database
					<val>	=	a value compatible with the type of <ename>
							in the metadata of the database

	return value:
		a status code:
			0 = OK
			-1 = invalid database name
			-2 = invalid data attribute name or corresponding value
			-3 - invalid locator list
--]]

dbBUILD = function (x_dbname, x_key, x_tuple)
	local stat, i, stuff, stuff2, k_fnd, stuff3, stuff4, j
	-- verify the database name
	stat = dbVERIFY_DB(x_dbname)
	if stat < 0 then return -1 end
	-- if the key parameter is a list ....
	stuff = metaverse[2]; stuff = stuff[x_dbname];
	if type(x_key) == "table" then
		-- verify the locator list
		stat = dbVERIFY_LOC(x_key, stuff)
		if stat < 0 then return -3 end
	end
	-- verify the consistency of the attribute names and corresponding values
	-- with respect to the metadata of the database
	for i=1,#x_tuple,2 do
		stat = -2
		for j, stuff2 in pairs(stuff) do
			if j == x_tuple[i] and
			   stuff2 == type(x_tuple[i+1]) 
			then
				stat = 1; break;
			end 
		end
		if stat < 0 then return stat end
	end
	-- create the new data tuple
	stuff3 = {}
	for i=1,#x_tuple,2 do	stuff3[x_tuple[i]] = x_tuple[i+1] end
	
	-- if the key parameter is not a table ....
	if type(x_key) ~= "table" then
		-- if there any keys in dbverse ....			
		if dbverse[1] ~= nil then
			stuff = dbverse[1]; 
			-- if there are any keys for this database ....
			if stuff[x_dbname] ~= nil then
				stuff = stuff[x_dbname]; k_fnd = -1;
				for i, stuff2 in pairs(stuff) do
					if stuff2 == x_key then
						k_fnd = i; break;
					end
				end
				if k_fnd < 0 then stuff[#stuff + 1] = x_key end  
			else
				stuff = {}; stuff[1] = x_key;
			end
			stuff2 = dbverse[1]; stuff2[x_dbname] = stuff; dbverse[1] = stuff2;
		else
			stuff = {}; stuff[1] = x_key; 
			stuff2 = {}; stuff2[x_dbname] = stuff; dbverse[1] = stuff2;
		end
	end

	-- if there any data tuples in dbverse ....
	if dbverse[2] ~= nil then
		stuff = dbverse[2]
		-- if there are any data tuples for this database ....
		if stuff[x_dbname] ~= nil then
			stuff = stuff[x_dbname];
			-- if the key parameter is a locator list ....
			if type(x_key) == "table" then
				-- update only the data tuples that match the locator
				for i, stuff2 in pairs(stuff) do
					stat = dbDO_LOC(x_key, stuff2)
					-- if this data tuple matches ....
					if stat > 0 then
						-- update the matching data tuple
						for j, stuff4 in pairs(stuff3) do stuff2[j] = stuff4 end
						stuff[i] = stuff2
					end
				end
			else
				if stuff[x_key] ~= nil then
					stuff4 = stuff[x_key] 
					for i, stuff2 in pairs(stuff3) do stuff4[i] = stuff2 end
					stuff[x_key] = stuff4
				else
					stuff[x_key] = stuff3
				end
			end
		else
			stuff = {}; stuff[x_key] = stuff3;
		end
		stuff2 = dbverse[2]; stuff2[x_dbname] = stuff; dbverse[2] = stuff2;
	else
		stuff = {}; stuff[x_key] = stuff3;
		stuff2 = {}; stuff2[x_dbname] = stuff; dbverse[2] = stuff2;
	end

	return 0
end

--[[ 
	dbDELETE:	remove 1 or more data tuples from a database in dbverse

	arguments:
		<dbname>:	database name
		<locator>:	list of data attribute conditions compatible with
				dbVERIFY_LOC

	return value:
		a status code of the removal:
			0 = OK
			-1 = database does not exist
			-2 = locator expression is incorrect 
				(missing attribute or comparison data type not compatible)
			-3 = no data tuples match the locator 
--]]

dbDELETE = function (x_dbname, x_locator)
	local locdb, stuff, stat, i, stuff2, j, stuff3, stuff4, fnd = 0
	-- verify the existence of the database
	locdb = dbVERIFY_DB(x_dbname)
	if locdb < 0 then return -1 end
	-- retrieve the metadata for the inpustuffmetalst[x_dbname];
	-- verify the locator expression
	stuff = metaverse[2]; stuff = stuff[x_dbname];
	stat = dbVERIFY_LOC(x_locator, stuff)
	if stat < 0 then return -2 end
	-- retrieve the data tuples for this database
	stuff = dbverse[2]; stuff = stuff[x_dbname]; 
	stuff3 = dbverse[1]; stuff3 = stuff3[x_dbname]; fnd = 0;
	for i, stuff2 in pairs(stuff) do
		-- verify a match for this data tuple per the locator
		stat = dbDO_LOC(x_locator, stuff2)
		-- if there is a match ....
		if stat > 0 then
			fnd = fnd +1
			-- remove the key for this tuple from the key list for this database
			for j, stuff4 in pairs(stuff3) do
				if stuff4 == i then
					stuff3[j] = nil; break;
				end
			end
			-- remove this tuple from the data tuples
			stuff[i] = nil
		end
	end
	if fnd == 0 then return -3 end
	-- refresh the key list
	stuff4 = dbverse[1]; stuff4[x_dbname] = stuff3; dbverse[1] = stuff4;
	-- refresh the data tuples list
	stuff4 = dbverse[2]; stuff4[x_dbname] = stuff; dbverse[2] = stuff4;
	return 0;
end

--[[ 
	dbERASE:	remove a database from dbverse and its related metatuple from metaverse

	arguments:
		<dbname>:	database ID to bec removed

	return value:
		a status code of the removal ( 0 = OK, negative number = error occured )
--]]

dbERASE = function (x_dbname)
	local db_stuff = {}
	local loc
	-- verify the database entry
	loc = dbVERIFY_DB(x_dbname);
	if loc < 0 then return -1 end
	if dbverse ~= nil then
		-- retrieve all data tuples
		dbstuff = dbverse[2]
		-- remove all the data tuples for this database
		dbstuff[x_dbname] = nil
		-- refresh the list of data tuples
		dbverse[2] = dbstuff
		-- retrieve all keys
		dbstuff = dbverse[1]
		-- remove all the keys for this database
		dbstuff[x_dbname] = nil
		-- refresh the list of keys
		dbverse[1] = dbstuff
	end
	if metaverse ~= nil then
		-- retrieve all metadata entries
		dbstuff = metaverse[2]
		-- remove all the metdata for this database
		dbstuff[x_dbname] = nil
		-- refresh the list of metadata
		metaverse[2] = dbstuff
		-- retrieve the list of databases
		dbstuff = metaverse[1]
		-- locate the database in the list and remove it
		dbstuff[loc] = nil
		-- refresh the list of databases
		metaverse[1] = dbstuff
	end
	-- operation went OK
	return 0;
end

--[[ 
	dbDEFINE:	add or change a metaverse tuple

	arguments:
		<dbname>:	database ID for which the tuple is to be added

		<dbmeta>:	list of the metadata for <dbname>
				NOTE - the format for <dbmeta> is:
				{<ename>,<content>,..,<ename>,<content>}

	return value:
		a status code of the addition:
		0 = OK
		-1 = <dbmeta> is not a table

	NOTE - if the database ID does no exist in metaverse it is added
--]]

dbDEFINE = function (x_dbname, x_dbmeta)
	local locdb, stuff, i, stuff2, j, stuff3
	-- verify that the metadata list is a table
	if type(x_dbmeta) ~= "table" then return -1 end
	-- see if the database is already defined
	locdb = dbVERIFY_DB(x_dbname)
	-- if the database is not defined ....
	if locdb < 0 then
		-- add the database to the database list
		if metaverse[2] ~= nil then
			stuff = metaverse[1]; stuff[#stuff+1] = x_dbname; metaverse[1] = stuff;
		else
			metaverse[1] = {x_dbname}
		end
		-- add the metadata corresponding to this database
		stuff = {}
		for i=1,#x_dbmeta,2 do	stuff[x_dbmeta[i]] = x_dbmeta[i+1] end
		if metaverse[2] ~= nil then
			stuff2 = metaverse[2]; stuff2[x_dbname] = stuff; metaverse[2] = stuff2;
		else
			stuff2 = {}; stuff2[x_dbname] = stuff; metaverse[2] = stuff2;
		end
	else
		-- database exists; so change or add the metadata
		stuff = metaverse[2]; stuff = stuff[x_dbname]; stuff2 = x_dbmeta;
		for i, stuff3 in pairs(stuff) do
			for j=1,#stuff2,2 do
				-- if the name of this metaverse data attribute
				-- matches one in the input list ....
				if stuff["ename"] == stuff2[j] then
					stuff["content"] = stuff2[j+1]; 
					stuff2[j] = nil; stuff2[j+1] = nil; break;
				end
			end
		end	 
		-- if there are any leftover items in the input metadat list, add them
		for j=1,#stuff2,2 do
			if stuff2[j] ~= nil then
				stuff3 = {}; stuff3["ename"] = stuff2[j]; stuff3["content"] = stuff2[j+1];
				stuff[#stuff + 1] = stuff3;
			end		
		end
		-- refresh the metadata list with the additions and chanbes to metaverse
		stuff2 = metverse[2]; stuff2[x_dbname] = stuff; metverse2[2] = stuff2;
	end
	return 0
end

--[[ 
	dbDESCRIBE:	retrieve the tuples describing a database in metaverse

	arguments:
		<dbname>:	name in a metatuple entry of type "database",

	return value:
		a list of entries from metaverse defining <dbname> or a negative number for
		a failed invocation (-1 = database not found)
--]]

dbDESCRIBE = function (x_dbname)
	local i = 0; local j = 0; local metalst;
-- locate the metaverse entries for this database
	i = dbVERIFY_DB(x_dbname);
	if i < 0 then return -1 end
-- return the collected list of metaverse tuples
	metalst = metaverse[2];
	return metalst[x_dbname];
end

--[[ 
	dbLISTDB:	list all databases in metaverse

	arguments:	NONE

	return value:
			a list of all databases in metaverse 
--]]

dbLISTDB = function ()
	return metaverse[1];
end

--[[ 
	dbLISTKEYS:	list all the keys for each databases in dbverse

	arguments:	NONE

	return value:
			a list whose indices are the database IS's and
			where the cointents under each index is the
			list of keys for that database
--]]

dbLISTKEYS = function ()
	return dbverse[1];
end

--[[ 
	dbGETVALS:	get all the values of an attribute in a database

	arguments:	
		<dbname>:	database name
		<attribute>	data attribute in <dbname>

	return value:
			a list of all the values of an attribute in a database or
			-1 if the database does not exist,
			-2 if the attribute does not exist
			-3 if there is no data for this database
--]]

dbGETVALS = module(...,package.seeall)
-- require"SeeTables"

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
	Author:		T. Freund

	Version:	pDB_comm.2013.04.22.1

	Component:	picoDB.lua

        Function:	Non-SQL data base management system for microcontrollers

	Assumptions:	Use of eLua platform with number and text support

	Author:		T. Freund

	Version:	pDB_comm.2013.04.22.1

	Background:

		picoDB is based on 2 lists: Metaverse and DBverse. Metaverse provides a list of database 
		names and their corresponding metadata. DBverse provides, for each database listed in 			Metaverse, a list of keys and corresponding data tuples for each data base.

 		The structure of Metaverse is as follows:

				{<database_list>,<metadata_list>}

		where
				<database_list> = list of the names of the active databases

				<metadata_list> = {<db_metadata_list<,<metadata_list>>}

				<db_metadata_list> = {<pair_list><,<db_metadata_list>>}

				<pair_list> = {<pair><,<pair_list>>}
			
				<pair> = {ename = <attribute_name>, content = <attribute_type>}

				<attribute_name> = name of the data attribute in text format

				<attribute_type> = type of data stored for this data attribute
						   (same values as the type() function)

		indices for each of the above Metaverse lists are as follows:

		(LIST)			(INDEX)

		<database_list>		(default numeric table index within Metaverse)
		<metadata_list>		(default numeric table index within Metaverse)
		<db_metadata_list>	element of <database_list> (a database name)
		<pair_list>		(default numeric table index within <db_metadata_list>)
		a database tool for 32-bit microcontrollers<pair>			(default numeric table index within <pair_list>)
		<attribute_name>	"ename" within <pair>
		<attribute_type>	"content" within <pair>
		
		
 		The structure of DBverse is as follows:

				{<key_list>,<data_list>}

		where,
				<key_list> = {<db_key_list><,<key_list>>}

				<db_key_list> = {<key><,<db_key_list>>}

				<key> = key to a data tuple for a particular database

				<data_list> = {<data_tuple_list><,<data_list>>}

				<data_tuple_list> = {<data_tuple><,<data_tuple_list>>}

				<data_tuple> = {<data><,<data_tuple>>}

				<data> = value of a data attribute consistent with the content type

		indices for each of the above Metaverse lists are as follows:

		(LIST)			(INDEX)

		<key_list>		(default numeric table index within DBverse)
		<data_list>		(default numeric table index within DBverse)
		<db_key_list> 		element of <database_list> in Metaverse (a database name)
		<key>			(default numeric table index within <db_key_list>)
		<data_tuple_list>	element of <database_list> in Metaverse (a database name)
		<data_tuple>		<key> within <db_key_list>
		<data>			<attribute_name> within <pair_list> in Metaverse 

		All picoDB databases are analogous to 1-table relational databases.	
 
  	**************************************************************************************

  	_______________________________ CHANGE LOG ________________________________

  	(DATE)		(DESCRIPTION)
  
  	Apr 22 2013	Community version initial build

	
  	**************************************************************************************

--]]

-- global list of databases
dbverse = {};
-- global list of metatuples
metaverse = {};
-- global for the storage area of dbverse
dbvpath = "dbverse";
-- global for the storage area of metaverse
mvpath = "metaverse";


--[[	**** picoDB METHODS ****    --]]

--[[ 
	dbVERIFY_DB:	verify that a database exists

	arguments:
		<dbname>:	name of a "database",

	return value:
		the index of the database in the database list
		or -1 if the database ID is non-existent
--]]

local dbVERIFY_DB = function (x_dbname)
	local i, stuff, locdb
	-- retrieve the database list
	locdb = -1
	if #metaverse > 0 then
		for i, stuff in pairs(metaverse[1]) do
			if x_dbname == stuff then
				locdb = i; break;
			end
		end
	end
	return locdb
end

--[[ 
	dbVERIFY_ATTR:	verify that a data attribute of a database exists

	arguments:
		<dbname>	name of a database
		<attr>		name of a data attribute

	return value:
		the index of the attribute in the metadata list for this database or
		-1 if the database ID is non-existent,
		-2 if no metadata found for this attribute
--]]

local dbVERIFY_ATTR = function (x_dbname, x_attr)
	local i, j, stuff, stuff2;
	i = dbVERIFY_DB(x_dbname)
	if i < 0 then return -1 end
	-- retrieve the metadata for this database
	stuff = metaverse[2]
	stuff = stuff[x_dbname]
	j = -2;
	for i, stuff2 in pairs(stuff) do
		if i == x_attr then 
			j = i; break;
		end
	end
	return j
end

--[[ 
	dbVERIFY_LOC:	verify that a locator expression for a datbase is valid

	arguments:
		<locator>:	list of name-operator-value triples that act as a conjunction
				to locate items.
				NOTE - The format of the list is:
					{<ename>,<op>,<val>,......,<ename>,<op>,<val>}
				where
					<ename>	= 	name of the data attribute 
							consistent with the metadata list of the database
					<op>	=	comparison operator ("=","<=".">=","<",">","in")
					<val>	=	single value or list of values (for "in")
							consistent with the metadata list of the database

		<meta>:		metadata list for the database used with <locator>

	return value:
		a sucess indicator
			0 = OK
			-1 = incorrect comparison operator found in locator
			-2 = incompatible data attribute name or comparison value

	ASSUMPTION: the metaverse entry has been verified through the existence of a database via db_VERIFY_DB
--]]

local dbVERIFY_LOC = function (x_locator, x_meta)
	local ops = {"=",">","<","<=",">=", "in"}
	local i, j, stuff, stat, stuff2, k, cnt
	-- verify that
	--	(1) the data attributes in the locator are consistent with the metadata
	--	(2) the comparison operator is correct	-- 	
	--	(3) the type of the comparison values are consistent with the metadata
	for i=1,#x_locator,3 do
		stat = -1
		for j, stuff in pairs(ops) do
			if x_locator[i+1] == stuff then 
				stat = 0; break;
			end 
		end
		if stat < 0 then return -1 end
		stat = -2
		for j, stuff in pairs(x_meta) do
			if x_locator[i] == j and 
			   type(x_locator[i+2]) == stuff and
			   x_locator[i+1] ~= "in"
			then
				stat = 0;
			elseif x_locator[i] == j and 
			       x_locator[i+1] == "in"
			then
				stuff2 = x_locator[i+2]; cnt = 0;
				for k=1,#stuff2,1 do
					if type(stuff2[k]) == stuff then cnt=cnt+1 end 
				end
				if cnt == #stuff2 then stat = 0 end
			end
		end
	end
	return stat;
end

--[[ 
	dbDO_LOC:	perform a locator constraint check on a dbverse tuple

	arguments:
		<locator>:	list of name-operator-value triples that act as a conjunction
				to locate items.
				NOTE - The format of the list is:
					{<ename>,<op>,<val>,......,<ename>,<op>,<val>}
				where
					<ename>	= 	name of the data attribute 
							consistent with the metadata list of the database
					<op>	=	comparison operator ("=","<=".">=","<",">","in")
					<val>	=	single value or list of values (for "in")
							consistent with the metadata list of the database

		<db_tuple>:	data tuple from dbverse to be checked against the locator

	return value:
		0 = no matches
		1 = fully matched

	ASSUMPTION: the metaverse entry has been verified through db_VERIFY_DB and
		    the locator list has been verfied to be correct
--]]

local dbDO_LOC = function (x_locator, x_tuple)
	local i, stuff2, k, m, fnd, stuff4, amt
	fnd = 0
	for i, stuff2 in pairs(x_tuple) do
		-- verify that the tuple matches the locator
		for k=1,#x_locator, 3 do
			if i == x_locator[k] then
				if (x_locator[k+1] == "=" and
				    stuff2 == x_locator[k+2]) or
				   (x_locator[k+1] == ">" and
				   stuff2 > x_locator[k+2]) or
				   (x_locator[k+1] == "<" and
				   stuff2 < x_locator[k+2]) or
				   (x_locator[k+1] == ">=" and
				   stuff2 >= x_locator[k+2]) or
				   (x_locator[k+1] == "<=" and
				   stuff2 <= x_locator[k+2])
				then
					fnd = fnd+1
				elseif x_locator[k+1] == "in" then
					stat = 0
					for m, stuff4 in pairs(x_locator[k+2]) do
						if stuff2 == stuff4 then 
							stat = m; break;
						end
					end
					if stat > 0 then fnd = fnd+1 end
				end
			end
		end
	end
	amt = math.ceil(#x_locator / 3)
	if fnd == amt then fnd = 1 else fnd = 0 end
	return fnd
end

--[[ 
	dbSERIALIZE:	serialize a table

	arguments:	"dbverse" or "metaverse"

	return value:
		string representing the serialized metaverse or dbverse or
		a negative number to indicate an error consition
--]]

local dbSERIALIZE = function(y)
	local tbl = "{"
	local i, stuff, dbx, stuff2, j, stuff3, k
	tbl="{{"
	if y == "metaverse" then
		-- process the database list
		for i, stuff in pairs(metaverse[1]) do tbl = tbl..stuff.."," end
		-- close off the database list section
		tbl = string.sub(tbl,1,#tbl-1).."},{"
		-- process the metadata for each database
		for i, stuff in pairs(metaverse[2]) do
			tbl = tbl..i.."={"
			-- process all attribute pairs
			for j, stuff2 in pairs(stuff) do
				tbl = tbl..j.."="..stuff2..","
			end
			tbl = string.sub(tbl,1,#tbl-1).."},"
		end
		-- close off the metadata section
		tbl = string.sub(tbl,1,#tbl-1).."}"		
	elseif y == "dbverse" then
		-- process the keys list section
		for i, stuff in pairs(dbverse[1]) do
			tbl = tbl..i.."={"
			for dbx, stuff2 in pairs(stuff) do tbl = tbl..stuff2.."," end
			-- close off the keys list for a database
			tbl = string.sub(tbl,1,#tbl-1).."},"
		end
		-- close off the keys list section
		tbl = string.sub(tbl,1,#tbl-1).."},{"
		-- process the data section
		for i, stuff in pairs(dbverse[2]) do
			tbl = tbl..i.."={"
			-- process an individual, keyed data tuple list
			for j, stuff2 in pairs(stuff) do
				tbl = tbl..j.."={"
				-- process the content of an individual data tuple
				for k, stuff3 in pairs(stuff2) do
					tbl = tbl..k.."="..stuff3.."," 
				end				
				tbl = string.sub(tbl,1,#tbl-1).."},"
			end 
			tbl = string.sub(tbl,1,#tbl-1).."},"
		end		
		-- close off the data section
		tbl = string.sub(tbl,1,#tbl-1).."}"
	else
		-- unknown database universe
		return -1
	end
	-- close off either verse list
	tbl = tbl.."}"		
	return tbl
end

--[[ 
	dbUNSERIALIZE:	unfold a serialized table

	arguments:	

		(1) "dbverse" or "metaverse"
		(2) corresponding serialization (string)

	return value:
		0 - all went OK,
		-1 - invalid table type (not 'dbverse' or 'metaverse')
		-2 - serialization parameter not a string or empty
		-3 - metaverse serialization not properly structured
		-4 - database index in metadata incompatible with master database list
		-5 - metaverse no available to reconstruct dbverse
		-6 - dbverse serialization not properly structured
--]]

local dbUNSERIALIZE = function(tbl, xverse)
	local i, str, lst, nxt1, dblst, metastuff, dbidx, nxtmeta
	local metalst, nxtlst, str2, lst2, nxtitm1, nxtitm2, thislst, keylst, dtlst
	local xstuff, nxttp, j, thiskey
	-- verify appropriate picoDB (TM) table type
	if tbl ~= "dbverse" and tbl ~= "metaverse" then return -1 end
	-- verify that the 2nd parameter is a string and not empty
	if xverse == nil or xverse == "" or type(xverse) ~= "string" then return -2 end
	-- if this is metaverse serialization ....
	if tbl == "metaverse" then
		metaverse = {}
		-- build the database list section (dblst)
		str, lst = string.find(xverse,"{[a-zA-Z0-9,]+}",1)
		if str == nil or lst == nil then return -3 end
		nxt1 = ""; dblst = {}; str = str+1; lst = lst-1;
		for  i=str,lst,1 do
			if string.sub(xverse,i,i) == "," or i == lst then
				if i == lst then nxt1 = nxt1..string.sub(xverse,i,i) end
				dblst[#dblst+1] = nxt1; nxt1 = "";
			else
				nxt1 = nxt1..string.sub(xverse,i,i)
			end
		end
		-- build the metaverse section (metalst)
		str, lst = string.find(xverse,"},{",1)
		str = lst+1; lst = #xverse-2;
		metastuff = string.sub(xverse,str,lst); str = 1; metalst = {};
		while str <= #metastuff do
			-- get the next database name used as index
			str, lst = string.find(metastuff,"[%a%d]+=",str);
			if str == nil or lst == nil then return -3 end
			lst = lst-1; 
			dbidx = string.sub(metastuff,str,lst); j = -1;
			-- verify that the database name is compatible with the database list
			for i=1,#dblst,1 do 
				if dblst[i] == dbidx then j = i; break end			
			end
			if j < 0 then return -4 end 
			-- extract the metadata list for this database
			str = lst+2
			str, lst = string.find(metastuff,"{[%a%d.=,]+}",str)
			if str == nil or lst == nil then return -3 end
			str = str + 1; lst = lst - 1;
			nxtmeta = string.sub(metastuff,str,lst); nxtlst = {}; nxt1="";
			for i=1,#nxtmeta,1 do
				if string.sub(nxtmeta,i,i) == "," or i == #nxtmeta then
					if i == #nxtmeta then nxt1 = nxt1..string.sub(nxtmeta,i,i) end
					str2 = string.find(nxt1,"=",1)
					if str2 == nil then return -3 end
					nxtitm1 = string.sub(nxt1,1,str2-1)
					nxtitm2 = string.sub(nxt1,str2+1,#nxt1)
					nxtlst[nxtitm1] = nxtitm2
					nxt1=""
				else
					nxt1 = nxt1..string.sub(nxtmeta,i,i)
				end
			end
			metalst[dbidx] = nxtlst
			str,lst = string.find(metastuff,"},",lst)
			if str == nil or lst == nil then break end
			str = lst +1
		end
		metaverse[1] = dblst; metaverse[2] = metalst
	elseif tbl == "dbverse" then
		dbverse = {}
		-- dbverse serialization ....
		-- verify that metaverse has been established
		if metaverse == nil then return -5 end
		-- retrieve the data base list and metadata lst from metaverse
		dblst = metaverse[1]; metalst = metaverse[2]; keylst = {}
		-- build the keys list section (keylst)
		str=1
		lst = string.find(xverse,"},{",str) -- locate the end of the keys lst
		if lst == nil then return -6 end
		lst = lst-1; str = 3; xstuff = string.sub(xverse,str,lst) -- get contents of the keys lst
		str = 1
		while str <= #xstuff do
			lst = string.find(xstuff,"=",str)
			if lst == nil then return -6 end
			lst=lst-1
			dbidx = string.sub(xstuff,str,lst) -- get the name of the database used as index
			nxt1 = dbVERIFY_DB(dbidx)	-- verify that this database has been defined
			if nxt1 < 0 then return -6 end
			str = lst + 3
			lst = string.find(xstuff,"}",str) -- end of the list of keys for this database
			if lst == nil then return -6 end
			lst=lst-1
			nxtmeta = string.sub(xstuff,str,lst) -- get the key list for this database index
			nxtlst = {}; nxt1 = "";
			for i=1,#nxtmeta,1 do
				if string.sub(nxtmeta,i,i) == "," or i == #nxtmeta then
					if i == #nxtmeta then nxt1 = nxt1..string.sub(nxtmeta,i,i) end
					nxtlst[#nxtlst + 1] = nxt1; nxt1 = "";
				else
					nxt1 = nxt1..string.sub(nxtmeta,i,i)
				end
			end
			keylst[dbidx] = nxtlst; str = lst+3;
		end

		-- build the data tuples section (dtlst)
		dtlst = {};str = 1;
		lst, str = string.find(xverse,"},{",str) -- get the start of the data tuples
		if lst == nil or str == nil then return -6 end
		str = str + 1
		lst = #xverse-2	-- end of the datatuples
		xstuff = string.sub(xverse,str,lst)  -- contents of the data tuples
		str = 1; thislst = {}
		while str <= #xstuff do
			lst=string.find(xstuff,"=",str)
			if lst == nil then return -6 end
			lst=lst-1
			dbidx = string.sub(xstuff,str,lst) -- get the name of the database used as index
			nxt1 = dbVERIFY_DB(dbidx)	-- verify that this database has been defined
			if nxt1 < 0 then return -6 end
			str = lst+2
			lst=string.find(xstuff,"}}",str) 
			if lst == nil then return -6 end
			nxtmeta = string.sub(xstuff,str,lst)  -- get all the the data tuples and their keys for this database
			str2 = 2; nxtlst = {};
			while str2 < #nxtmeta do
				lst2 = string.find(nxtmeta,"=",str2)
				if lst2 == nil then return -6 end
				lst2 = lst2 - 1 
				nxt1 = string.sub(nxtmeta,str2,lst2); thiskey = nil;
				-- verify the next key as valid per the extracted key list
				for i, j in pairs(keylst[dbidx]) do
					if j == nxt1 then thiskey = j; break end
				end
				if thiskey == nil then return -6 end
				str2 = lst2 + 3	-- start of the content for this data tuple
				lst2 = string.find(nxtmeta,"}",str2)
				if lst2 == nil then return -6 end
				lst2 = lst2 - 1	-- end of the content for this data tuple
				nxttp = string.sub(nxtmeta,str2,lst2); nxt1 = ""; thislst = {};
				for i =1,#nxttp,1 do
					if string.sub(nxttp,i,i) == "," or i == #nxttp then
						if i == #nxttp then nxt1=nxt1..string.sub(nxttp,i,i) end
						j = string.find(nxt1,"=")
						if j == nil then return -6 end
						nxtitm1 = string.sub(nxt1,1,j-1)
						nxtitm2 = string.sub(nxt1,j+1,#nxt1)
						j = dbVERIFY_ATTR(dbidx,nxtitm1)
						if type(j) == "number" and j < -0 then return -6 end
						j = tonumber(nxtitm2)
						if j ~= nil then nxtitm2 = j end
						thislst[nxtitm1] = nxtitm2; nxt1=""; 
					else
						nxt1=nxt1..string.sub(nxttp,i,i)
					end
				end
				nxtlst[thiskey] = thislst
				str2 = lst2 + 3
			end
			dtlst[dbidx] = nxtlst
			str = lst+3
		end
		dbverse[1] = keylst; dbverse[2] = dtlst;
	end
	return 0
end

--[[ 
	dbSETUP:	initialize dbverse and multiverse from storage

	arguments:	NONE

	return value:
		a status code of the change ( 0 = OK, negative number = error occured )
--]]

dbSETUP = function ()

-- open dbverse in storage
local dbv = io.open(dbvpath,"r");
-- open metaverse in storage
local mv = io.open(mvpath,"r");
-- fetch metaverse in storage
dbUNSERIALIZE("metaverse",mv:read("*all"));
-- fetch dbverse in storage
dbUNSERIALIZE("dbverse",dbv:read("*all"));
-- release storage
dbv:close();
mv:close();

return 0;

end

--[[ 
	dbCOMMIT:	commit to storage all universes

	arguments:	NONE

	return value:
		a status code of the change ( 0 = OK, negative number = error occured )
--]]

dbCOMMIT = function ()

-- open dbverse in storage
local dbv = io.open(dbvpath,"w");
-- open metaverse in storage
local mv = io.open(mvpath,"w");
-- write dbverse to storage
dbv:write(dbSERIALIZE("dbverse"));
dbv:flush();
-- write metaverse to storage
mv:write(dbSERIALIZE("metaverse"));
mv:flush();
-- release storage
dbv:close();
mv:close();

end

--[[ 
	dbMESSAGE:	format a string of hexadecimal values that represented
			a message under a protocol

	arguments:	protocol ID - the identifier of the protocol
			message ID - the identifier of a message in this protocol
			message content - a table in the format:
				{<parm_id>,<val>,...., <parm_id>,<val>}

			where
				<parm_id>	the name of a parameter for the message ID 
						under the protocol ID
						as defined in the Protocols database

			`	<val>		a valid value for the associated parameter

			NOTE -
			
			By default, a database named Protocols is added at initialization time
			to every picoDB set of databases. Each record identifies a parameter in a messageI.
			Its metadata is as follows:

			ATTRIBUTE		TYPE		DESCRIPTION
			_________		____		___________
	
			Protocol ID		string		identifier of the protocol,
			Message ID		string		identifier for a message under this protocol,
			Parameter ID		string		name of the parameter in this record,
			Parameter type		string		type for the parameter ("integer", "short", "float" or "string"),
			Parameter range		table		a table having a minimum-maximum pair or an enumeration
								giving the valid range of values for this parameter,
			Parameter default	string		default value for this parameter if none specified
			Parameter location	number		location of the value for this parameter in the
								message structure,
			Parameter size		number		number of bytes occupied by this parameter in the
								message structure.
	
	return value:
		a string of hexadecimal values or
		a negative number indicating a failures as follows:
			-1 = unabled to locate "Protocols" database
			-2 = invalid locator expression
			-3 - message content list not a table
			-4 - invalid parameter name in the message content list
			-5 - invalid parameter value in the message content list
--]]

dbMESSAGE = function (xproto, xmsg, xcontent)
	local lst, msgout, i, parmref, parmsin, j, parmdef, parmrng, nxt, szref, sz, nxt2
	szref = {"short","integer","float"}
	-- retrieve the parameter definitions for this protocol message
	lst = dbLOCATE("Protocols",{"ProtocolID","=",xproto,"MsgID","=",xmsg})
	if type(lst) == "number" then return lst end
	-- verify that the message content list is a table
	if type(xcontent) ~= "table" then return -3 end
	-- restructure the message contents list to be indexed by parameter name
	parmsin = {}
	for i=1,#xcontent,2 do parmsin[xcontent[i]] = xcontent[i+1] end
	-- go through the reference list of the message parameters
	-- and format the message using the message contents list
	msgout = {}
	for i, parmref in pairs(lst) do
		for j, nxt in pairs(szref) do
			if parmref["ParmType"] == nxt then
				sz = math.pow(2,j)
				break
			end
		end
		if parmsin[parmref["ParmID"]] ~= nil then
			-- verify that the value in the message content list is the right type
			if (parmref["ParmType"] == "string" and
			    type(parmsin[parmref["ParmID"]]) ~= "string") or
			   ((parmref["ParmType"] == "float" or
			     parmref["ParmType"] == "short" or 
			     parmref["ParmType"] == "integer") and
			    type(parmsin[parmref["ParmID"]]) ~= "number") then return -5 end
			-- verify that the value in the message content list is in range
			parmrng = {}; parmrng = parmref["ParmRange"];
			if type(parmsin[parmref["ParmID"]]) == "number" and
			   #parmrng == 2 and parmrng[1] <= parmrng[2] and
			   (parmsin[parmref["ParmID"]] >  parmrng[2] or 
			    parmsin[parmref["ParmID"]] <  parmrng[1]) then 
				return -5
			elseif parmref["ParmType"] == "string" then
				j = 1;
				while j <= #parmrng and parmsin[parmref["ParmID"]] ~= parmrng[j]  do j=j+1 end
				if j > #parmrng then return -5 end
			end
			-- add the value at the correct position
			if parmref["ParmType"] == "string" then
				parmrng = parmsin[parmref["ParmID"]]; nxt = "";
				for j=1,parmref["ParmSize"],1 do
					nxt2 = string.sub(parmrng,j,j)
					nxt = nxt..string.format("%02x",string.byte(nxt2))
				end
				msgout[parmref["ParmLoc"]] = nxt
			else
				msgout[parmref["ParmLoc"]] = string.format("%0"..sz.."x", parmsin[parmref["ParmID"]])
			end
			-- remove the parameter entry from the restructured list
			parmsin[parmref["ParmID"]] = nil
		else
		-- parameter missing, apply the default value
			if parmref["ParmType"] == "string" then
				parmrng = parmref["ParmDefault"]; nxt="";
				for j=1,parmref["ParmSize"],1 do
					nxt2 = string.sub(parmrng,j,j)
					nxt = nxt..string.format("%02x",string.byte(nxt2))
				end
				msgout[parmref["ParmLoc"]] = nxt
			else
				nxt = tonumber(parmref["ParmDefault"])
				msgout[parmref["ParmLoc"]] = string.format("%0"..sz.."x",nxt)
			end
		end
	end
	if #parmsin > 0 then return -4 end
	nxt = ""
	for i, sz in pairs(msgout) do nxt = nxt..sz end
	return nxt
end

--[[ 
	dbVERIFY:	verify a received message operating under a protocol
			and perform processing on the parameters making up the message content 

	arguments:	protocol ID - the identifier of the protocol
			message ID - the identifier of a message in this protocol
			message content - a string consisting of hexadecimal values

			By default, a database named Verifier is added at initialization time
			to every picoDB set of databases. Each record identifies a parameter in a messageI.
			Its metadata is as follows:

			ATTRIBUTE		TYPE		DESCRIPTION
			_________		____		___________
	
			Protocol ID		string		identifier of the protocol,
			Message ID		string		identifier for a message under this protocol,
			Parameter ID		string		name of the parameter in this record,
			Parameter processing	table		a table containing a list of operations on a 
								parameter combined with Resources and
								resulting a change of value for a Resource

			ASSUMPTION - The parameter processing attribute is a mathematical formula
				     that results in a numerical value.

			NOTE - 	The contents of the Parameter processing attribute uses a stack machine
				structure. That is, one or more operands followed by an operator. The operator
				is a standard arithmetic operator (+,-,*,/,%,^). The operands can be a numerical
				value or a Resource ID whose value value can be retrieved from the Resource database.
				Once an operator is reached, that operation is performed on all prior operands.
				The result is then pushed onto the stack represented through the attribute's table.
				When all operations are completed, there is only one item in the stack: the final result.

				An operand identifies itself as a resource by starting with 'R_'. An operand
				identifies itself as the parameter value associated with this process as 'P_'.
				The last item in the stack is a resource assignment operator which is in the format:
	
						=R_<resource_name>
	return value:
		 0 = processing went OK
		-1 = Protocols database cannot be located
		-2 = The protocol ID or message ID records are not in the Protocols database
		-3 = the message content is not a string
		-4 = the message content is not all hexadecimal values
		-5 = message content is not the correct size 
		-6 = Verifier database cannot be located
		-7 = The protocol ID or message ID records are not in the Verifier database
		-8 = mismatch between parameter values in the message and parameter processes in the Verifier database
		-9 = parameter value out of protocol range
--]]

dbVERIFY = function (xproto, xmsg, xcontent)
	local stat, hexref, i, j, k, lstin, parmref, nxt, idx
	local parmtype, parmsz, parmname, parmrng, ttl, parmval, parmproc, parmstack, opernds, parmv
	local parmmax, parmmin, xval
	hexref = {"0","1","2","3","4","5","6","7","8","9","a","b","c","d","e","f"}
	-- verify that the contents is a hex string
	if type(xcontent) ~= "string" then return -3 end
	lstin = string.lower(xcontent)
	for i=1,#lstin,1 do
		j = 1
		while j<= #hexref and string.sub(lstin,i,i) ~= hexref[j] do j=j+1 end
		if j > #hexref then return -4  end
	end
	-- retrieve the parameter definitions for this protocol message
	parmref = dbLOCATE("Protocols",{"ProtocolID","=",xproto,"MsgID","=",xmsg})
	if type(parmref) == "number" then return parmref end
	-- retrieve the parameter ID, its location, and size in bytes of its value in the message content
	parmsz={}; parmloc={}; parmtype={}; parmrng = {};
	for i, nxt in pairs(parmref) do
		parmsz[nxt["ParmID"]] = 2*nxt["ParmSize"] -- record the number of hex characters representing a value
		parmloc[nxt["ParmID"]] = nxt["ParmLoc"]
		parmtype[nxt["ParmID"]] = nxt["ParmType"]
		parmrng[nxt["ParmID"]] = nxt["ParmRange"]
	end
	-- verify that the message content is the correct size per the Protocols database
	ttl = 0
	for i = 1,#parmsz,1 do ttl = ttl+parmsz[i] end
	if ttl ~= #xcontent then return -5 end
	-- retrieve the parameter processing from the Verifier database
	parmv = dbLOCATE("Verifier",{"ProtocolID","=",xproto,"MsgID","=",xmsg})
	if type(parmv) == "number" then return parmref-5 end
	parmproc = {}
	for i, nxt in pairs(parmv) do
		if parmloc[nxt["ParmID"]] == nil then
			return -5
		else
			parmproc[nxt["ParmID"]] = nxt["ParmProcess"] 
		end 
	end
	-- verify that the number of parameter references and the parameter processes match
	if #parmloc ~= #parmproc then return -8 end
	-- if any of the parameters are counter dependent, expand the parameter to include their number
	i = 1
	while i <= #parmsz do
		-- if the parameter location is dependent on a counter ....
		if parmloc[i] < 0 then
			-- get the location in the content string of counter
			idx = math.abs(parmloc[i])
			-- get the actual counter value from the content string
			ttl = tonumber("0x"..string.sub(xcontent,idx,idx + parmsz[idx] - 1))
			if ttl == nil then return -5 end
			-- record the parameter size, type, and procedure for the repeats
			parmval = {}
			parmval[1] = parmsz[i]; parmval[2] = parmtype[i]; 
			parmval[3] = parmproc[i]; parmval[4] = parmrng[i]; 
			-- expand the list to include the appropriate number of values
			parmloc[i] = 2*parmloc[idx]+parmsz[idx];
			idx = idx+2; stat = ttl; ttl = idx+ttl-3;
			for j = idx,ttl,1 do
				table.insert(parmsz,j,parmval[1])
				table.insert(parmtype,j,parmval[2])
				table.insert(parmproc,j,parmval[3])
				table.insert(parmrng,j,parmval[4])
				table.insert(parmloc,j,parmloc[i]+j*parmval[1])
			end
			-- adjust search index
			i = i + stat
		else
			-- adjust the parameter location to conform to the actual start locatiion
			-- in the message content string
			parmloc[i] = 2*parmloc[i]-1
			i = i+1
		end
	end
	-- extract the values associated with each parameter and verify their values against the parameter range
	parmval = {}; nxt = 1;
	for i=1,#parmsz,1 do
		if parmtype[i] == "short" or
		   parmtype[i] == "integer" or  
		   parmtype[i] == "float" then
			parmval[i] = tonumber("0x"..string.sub(xcontent,nxt,nxt + parmsz[i] - 1))
			-- range check
			idx = parmrng[i];
			if parmval[i] > idx[2] or parmval[i] < idx[1] then return -9 end
		else
			parmval[i]=""
			for j=1,parmsz[i],2 do
				ttl = "0x"..string.sub(xcontent,i,i+1)
				parmval[i] = parmval[i]..string.char(tonumber(ttl))
			end
			-- range check
			idx = parmrng[i]; j = 1;
			while j <= #idx and idx[j] ~= parmval[i] do j = j+1 end
			if j > #idx then return -9 end	
		end
		nxt = nxt + parmsz[i]  
	end
	-- carry out the parameter processes with the available parameter values
	for i, nxt in pairs(parmval) do
		parmstack = parmproc[i];
		j = 1; opernds = {}; lstin = 1;
		while j <= #parmstack do
			if string.match(parmstack[j],"[=%*%+%-/%%%^]") == nil then
				if parmstack[j] == "P_" then
					opernds[lstin] = parmval[i]
				elseif string.sub(parmstack[j],1,2) == "R_" then
					ttl = dbLOCATE("Resource",{"name","=",string.sub(parmstack[j],3)})
					if type(ttl) == "number" then return -5 end
					xval = ttl["current_value"]
					opernds[lstin] = xval[1]
				else
					opernds[lstin] = parmstack[j]
				end
				lstin = lstin + 1;
			else
				ttl = 0
				if parmstack[j] == "+" then
					ttl = 0
					for k =1,#opernds,1 do ttl = ttl + opernds[k] end
				elseif parmstack[j] == "-" then
					ttl = opernds[1]
					for k =1,#opernds,1 do ttl = ttl - opernds[k] end
				elseif parmstack[j] == "*" then
					ttl = 1
					for k =1,#opernds,1 do ttl = ttl * opernds[k] end
				elseif parmstack[j] == "/" and  opernds[2] ~= 0 then
					ttl = opernds[1] / opernds[2]
				elseif parmstack[j] == "^" then
					ttl = opernds[1] ^ opernds[2]
				elseif parmstack[j] == "%" then
					ttl = opernds[1] % opernds[2]
				elseif string.sub(parmstack[j],1,3) == "=R_" then
					ttl = dbBUILD("Resource",
							{"name","=",string.sub(parmstack[j],4)},
							{"current_value",{opernds[1]}})
					if type(ttl) == "number" and ttl < 0 then return -5 end
					break 
				end
				opernds = {}; opernds[1] = ttl; lstin = 2;
			end
			j = j+1
		end
	end
	return 0
end

--[[ 
	dbLOCATE:	retrieve 1 or more items from a tuple, or a complete tuple

	arguments:
		<dbname>:	database name
		<locator>:	list of data attribute conditions compatible with
				dbVERIFY_LOC

	return value:
		a list of data tuples in <dbname> matched through <locator> or
		an empty list if no data tuples match the locator or
		a negative number indicating a 	failure:
			-1 = invalid database name
			-2 = invalid locator expression
--]]

dbLOCATE = function (x_dbname, x_locator)
	local stat, stuff, i, stuff2, db_lst
	-- verify the database name
	stat = dbVERIFY_DB(x_dbname)
	if stat < 0 then return -1 end
	-- verify the locator expression
	stuff = metaverse[2]; stuff = stuff[x_dbname];
	stat = dbVERIFY_LOC(x_locator, stuff)
	if stat < 0 then return -2 end
	--locate data tuples that match the locator expression
	stuff = dbverse[2]; stuff = stuff[x_dbname]; db_lst={}; fnd = 0
	for i, stuff2 in pairs(stuff) do
		stat = dbDO_LOC(x_locator, stuff2)
		if stat > 0 then db_lst[#db_lst + 1] = stuff2 end
	end
	return db_lst;
end

--[[ 
	dbBUILD:		add or update data to a database

	arguments:
		<dbname>:	database name

		<key>		key for the data tuple in dbverse or
				locator list per dbVERIFY_LOC which indicates one or more updates

		<dbtuple>:	data to be added in the format:
					{<ename>, <val>,....,<ename>, <val>}
				where
					<ename>	=	name of data attribute compatible with
							the metadata of the database
					<val>	=	a value compatible with the type of <ename>
							in the metadata of the database

	return value:
		a status code:
			0 = OK
			-1 = invalid database name
			-2 = invalid data attribute name or corresponding value
			-3 - invalid locator list
--]]

dbBUILD = function (x_dbname, x_key, x_tuple)
	local stat, i, stuff, stuff2, k_fnd, stuff3, stuff4, j
	-- verify the database name
	stat = dbVERIFY_DB(x_dbname)
	if stat < 0 then return -1 end
	-- if the key parameter is a list ....
	stuff = metaverse[2]; stuff = stuff[x_dbname];
	if type(x_key) == "table" then
		-- verify the locator list
		stat = dbVERIFY_LOC(x_key, stuff)
		if stat < 0 then return -3 end
	end
	-- verify the consistency of the attribute names and corresponding values
	-- with respect to the metadata of the database
	for i=1,#x_tuple,2 do
		stat = -2
		for j, stuff2 in pairs(stuff) do
			if j == x_tuple[i] and
			   stuff2 == type(x_tuple[i+1]) 
			then
				stat = 1; break;
			end 
		end
		if stat < 0 then return stat end
	end
	-- create the new data tuple
	stuff3 = {}
	for i=1,#x_tuple,2 do	stuff3[x_tuple[i]] = x_tuple[i+1] end
	
	-- if the key parameter is not a table ....
	if type(x_key) ~= "table" then
		-- if there any keys in dbverse ....			
		if dbverse[1] ~= nil then
			stuff = dbverse[1]; 
			-- if there are any keys for this database ....
			if stuff[x_dbname] ~= nil then
				stuff = stuff[x_dbname]; k_fnd = -1;
				for i, stuff2 in pairs(stuff) do
					if stuff2 == x_key then
						k_fnd = i; break;
					end
				end
				if k_fnd < 0 then stuff[#stuff + 1] = x_key end  
			else
				stuff = {}; stuff[1] = x_key;
			end
			stuff2 = dbverse[1]; stuff2[x_dbname] = stuff; dbverse[1] = stuff2;
		else
			stuff = {}; stuff[1] = x_key; 
			stuff2 = {}; stuff2[x_dbname] = stuff; dbverse[1] = stuff2;
		end
	end

	-- if there any data tuples in dbverse ....
	if dbverse[2] ~= nil then
		stuff = dbverse[2]
		-- if there are any data tuples for this database ....
		if stuff[x_dbname] ~= nil then
			stuff = stuff[x_dbname];
			-- if the key parameter is a locator list ....
			if type(x_key) == "table" then
				-- update only the data tuples that match the locator
				for i, stuff2 in pairs(stuff) do
					stat = dbDO_LOC(x_key, stuff2)
					-- if this data tuple matches ....
					if stat > 0 then
						-- update the matching data tuple
						for j, stuff4 in pairs(stuff3) do stuff2[j] = stuff4 end
						stuff[i] = stuff2
					end
				end
			else
				if stuff[x_key] ~= nil then
					stuff4 = stuff[x_key] 
					for i, stuff2 in pairs(stuff3) do stuff4[i] = stuff2 end
					stuff[x_key] = stuff4
				else
					stuff[x_key] = stuff3
				end
			end
		else
			stuff = {}; stuff[x_key] = stuff3;
		end
		stuff2 = dbverse[2]; stuff2[x_dbname] = stuff; dbverse[2] = stuff2;
	else
		stuff = {}; stuff[x_key] = stuff3;
		stuff2 = {}; stuff2[x_dbname] = stuff; dbverse[2] = stuff2;
	end

	return 0
end

--[[ 
	dbDELETE:	remove 1 or more data tuples from a database in dbverse

	arguments:
		<dbname>:	database name
		<locator>:	list of data attribute conditions compatible with
				dbVERIFY_LOC

	return value:
		a status code of the removal:
			0 = OK
			-1 = database does not exist
			-2 = locator expression is incorrect 
				(missing attribute or comparison data type not compatible)
			-3 = no data tuples match the locator 
--]]

dbDELETE = function (x_dbname, x_locator)
	local locdb, stuff, stat, i, stuff2, j, stuff3, stuff4, fnd = 0
	-- verify the existence of the database
	locdb = dbVERIFY_DB(x_dbname)
	if locdb < 0 then return -1 end
	-- retrieve the metadata for the inpustuffmetalst[x_dbname];
	-- verify the locator expression
	stuff = metaverse[2]; stuff = stuff[x_dbname];
	stat = dbVERIFY_LOC(x_locator, stuff)
	if stat < 0 then return -2 end
	-- retrieve the data tuples for this database
	stuff = dbverse[2]; stuff = stuff[x_dbname]; 
	stuff3 = dbverse[1]; stuff3 = stuff3[x_dbname]; fnd = 0;
	for i, stuff2 in pairs(stuff) do
		-- verify a match for this data tuple per the locator
		stat = dbDO_LOC(x_locator, stuff2)
		-- if there is a match ....
		if stat > 0 then
			fnd = fnd +1
			-- remove the key for this tuple from the key list for this database
			for j, stuff4 in pairs(stuff3) do
				if stuff4 == i then
					stuff3[j] = nil; break;
				end
			end
			-- remove this tuple from the data tuples
			stuff[i] = nil
		end
	end
	if fnd == 0 then return -3 end
	-- refresh the key list
	stuff4 = dbverse[1]; stuff4[x_dbname] = stuff3; dbverse[1] = stuff4;
	-- refresh the data tuples list
	stuff4 = dbverse[2]; stuff4[x_dbname] = stuff; dbverse[2] = stuff4;
	return 0;
end

--[[ 
	dbERASE:	remove a database from dbverse and its related metatuple from metaverse

	arguments:
		<dbname>:	database ID to bec removed

	return value:
		a status code of the removal ( 0 = OK, negative number = error occured )
--]]

dbERASE = function (x_dbname)
	local db_stuff = {}
	local loc
	-- verify the database entry
	loc = dbVERIFY_DB(x_dbname);
	if loc < 0 then return -1 end
	if dbverse ~= nil then
		-- retrieve all data tuples
		dbstuff = dbverse[2]
		-- remove all the data tuples for this database
		dbstuff[x_dbname] = nil
		-- refresh the list of data tuples
		dbverse[2] = dbstuff
		-- retrieve all keys
		dbstuff = dbverse[1]
		-- remove all the keys for this database
		dbstuff[x_dbname] = nil
		-- refresh the list of keys
		dbverse[1] = dbstuff
	end
	if metaverse ~= nil then
		-- retrieve all metadata entries
		dbstuff = metaverse[2]
		-- remove all the metdata for this database
		dbstuff[x_dbname] = nil
		-- refresh the list of metadata
		metaverse[2] = dbstuff
		-- retrieve the list of databases
		dbstuff = metaverse[1]
		-- locate the database in the list and remove it
		dbstuff[loc] = nil
		-- refresh the list of databases
		metaverse[1] = dbstuff
	end
	-- operation went OK
	return 0;
end

--[[ 
	dbDEFINE:	add or change a metaverse tuple

	arguments:
		<dbname>:	database ID for which the tuple is to be added

		<dbmeta>:	list of the metadata for <dbname>
				NOTE - the format for <dbmeta> is:
				{<ename>,<content>,..,<ename>,<content>}

	return value:
		a status code of the addition:
		0 = OK
		-1 = <dbmeta> is not a table

	NOTE - if the database ID does no exist in metaverse it is added
--]]

dbDEFINE = function (x_dbname, x_dbmeta)
	local locdb, stuff, i, stuff2, j, stuff3
	-- verify that the metadata list is a table
	if type(x_dbmeta) ~= "table" then return -1 end
	-- see if the database is already defined
	locdb = dbVERIFY_DB(x_dbname)
	-- if the database is not defined ....
	if locdb < 0 then
		-- add the database to the database list
		if metaverse[2] ~= nil then
			stuff = metaverse[1]; stuff[#stuff+1] = x_dbname; metaverse[1] = stuff;
		else
			metaverse[1] = {x_dbname}
		end
		-- add the metadata corresponding to this database
		stuff = {}
		for i=1,#x_dbmeta,2 do	stuff[x_dbmeta[i]] = x_dbmeta[i+1] end
		if metaverse[2] ~= nil then
			stuff2 = metaverse[2]; stuff2[x_dbname] = stuff; metaverse[2] = stuff2;
		else
			stuff2 = {}; stuff2[x_dbname] = stuff; metaverse[2] = stuff2;
		end
	else
		-- database exists; so change or add the metadata
		stuff = metaverse[2]; stuff = stuff[x_dbname]; stuff2 = x_dbmeta;
		for i, stuff3 in pairs(stuff) do
			for j=1,#stuff2,2 do
				-- if the name of this metaverse data attribute
				-- matches one in the input list ....
				if stuff["ename"] == stuff2[j] then
					stuff["content"] = stuff2[j+1]; 
					stuff2[j] = nil; stuff2[j+1] = nil; break;
				end
			end
		end	 
		-- if there are any leftover items in the input metadat list, add them
		for j=1,#stuff2,2 do
			if stuff2[j] ~= nil then
				stuff3 = {}; stuff3["ename"] = stuff2[j]; stuff3["content"] = stuff2[j+1];
				stuff[#stuff + 1] = stuff3;
			end		
		end
		-- refresh the metadata list with the additions and chanbes to metaverse
		stuff2 = metverse[2]; stuff2[x_dbname] = stuff; metverse2[2] = stuff2;
	end
	return 0
end

--[[ 
	dbDESCRIBE:	retrieve the tuples describing a database in metaverse

	arguments:
		<dbname>:	name in a metatuple entry of type "database",

	return value:
		a list of entries from metaverse defining <dbname> or a negative number for
		a failed invocation (-1 = database not found)
--]]

dbDESCRIBE = function (x_dbname)
	local i = 0; local j = 0; local metalst;
-- locate the metaverse entries for this database
	i = dbVERIFY_DB(x_dbname);
	if i < 0 then return -1 end
-- return the collected list of metaverse tuples
	metalst = metaverse[2];
	return metalst[x_dbname];
end

--[[ 
	dbLISTDB:	list all databases in metaverse

	arguments:	NONE

	return value:
			a list of all databases in metaverse 
--]]

dbLISTDB = function ()
	return metaverse[1];
end

--[[ 
	dbLISTKEYS:	list all the keys for each databases in dbverse

	arguments:	NONE

	return value:
			a list whose indices are the database IS's and
			where the cointents under each index is the
			list of keys for that database
--]]

dbLISTKEYS = function ()
	return dbverse[1];
end

--[[ 
	dbGETVALS:	get all the values of an attribute in a database

	arguments:	
		<dbname>:	database name
		<attribute>	data attribute in <dbname>

	return value:
			a list of all the values of an attribute in a database or
			-1 if the database does not exist,
			-2 if the attribute does not exist
			-3 if there is no data for this database
--]]

dbGETVALS = function (x_dbname, x_attr)
	local locdb, locattr, i, stuff, stuff2, stuff3
	-- verify the database exists
	locdb = dbVERIFY_DB(x_dbname)
	if locdb < 0 then return locdb end
	-- verify the data attribute exists
	locattr = dbVERIFY_ATTR(x_dbname, x_attr)
	if type(locattr) == "number" and locattr < 0 then return locattr end
	-- retrieve the data entries for this database
	-- and store their values in a list
	stuff = dbverse[2]
	if stuff[x_dbname] == nil then return -3 end
	stuff = stuff[x_dbname]
	stuff3 = {}
	for i, stuff2 in pairs(stuff) do
		if stuff2[x_attr] ~= nil then stuff3[#stuff3 + 1] = stuff2[x_attr] end
	end
	return stuff3;
end
function (x_dbname, x_attr)
	local locdb, locattr, i, stuff, stuff2, stuff3
	-- verify the database exists
	locdb = dbVERIFY_DB(x_dbname)
	if locdb < 0 then return locdb end
	-- verify the data attribute exists
	locattr = dbVERIFY_ATTR(x_dbname, x_attr)
	if type(locattr) == "number" and locattr < 0 then return locattr end
	-- retrieve the data entries for this database
	-- and store their values in a list
	stuff = dbverse[2]
	if stuff[x_dbname] == nil then return -3 end
	stuff = stuff[x_dbname]
	stuff3 = {}
	for i, stuff2 in pairs(stuff) do
		if stuff2[x_attr] ~= nil then stuff3[#stuff3 + 1] = stuff2[x_attr] end
	end
	return stuff3;
end
