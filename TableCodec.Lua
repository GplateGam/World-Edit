local Module = {}

local function YieldCheck(Count)
	if Count % 200 == 0 then
		task.wait(0)
	end
end

function Module.Decode(InputString)
	if type(InputString) ~= "string" then
		error("Input must be a string")
	end
	local Index = 1
	local Length = #InputString
	local function ParseValue()
		YieldCheck(Index)
		while Index <= Length and InputString:sub(Index, Index):match("%s") do
			Index = Index + 1
		end
		local Char = InputString:sub(Index, Index)
		if Char == "{" then
			Index = Index + 1
			local Table = {}
			while Index <= Length and InputString:sub(Index, Index) ~= "}" do
				local Key = ParseValue()
				while Index <= Length and InputString:sub(Index, Index):match("[%s=]") do
					Index = Index + 1
				end
				local Value = ParseValue()
				if type(Key) == "string" and Key:find("%s") then
					-- Handle strings with spaces
					local Parts = {}
					for Part in Key:gmatch("%S+") do
						table.insert(Parts, Part)
					end
					if #Parts > 0 then
						Key = table.concat(Parts, " ")
					end
				end
				Table[Key] = Value
				while Index <= Length and InputString:sub(Index, Index):match("[%s;]") do
					Index = Index + 1
				end
			end
			Index = Index + 1
			return Table
		elseif Char:match("%d") then
			local Number = ""
			while Index <= Length and InputString:sub(Index, Index):match("[%d%.]") do
				Number = Number .. InputString:sub(Index, Index)
				Index = Index + 1
			end
			return tonumber(Number)
		else
			local Value = ""
			local InQuotes = false
			while Index <= Length do
				local CurrentChar = InputString:sub(Index, Index)
				if CurrentChar == '"' then
					InQuotes = not InQuotes
				elseif not InQuotes and CurrentChar:match("[%s=;}]") then
					break
				else
					Value = Value .. CurrentChar
				end
				Index = Index + 1
			end
			return Value:gsub('^"(.*)"$', '%1')
		end
	end
	return ParseValue()
end

function Module.Encode(Value)
	local ProcessedCount = 0
	local function EncodeValue(Val)
		ProcessedCount = ProcessedCount + 1
		YieldCheck(ProcessedCount)
		if type(Val) == "table" then
			local Parts = {}
			for Key, SubValue in pairs(Val) do
				if type(Key) == "string" and Key:find("%s") then
					Key = '"' .. Key .. '"'
				end
				table.insert(Parts, EncodeValue(Key) .. "=" .. EncodeValue(SubValue))
			end
			return "{" .. table.concat(Parts, ";") .. "}"
		else
			local Str = tostring(Val)
			if type(Val) == "string" and Str:find("%s") then
				return '"' .. Str .. '"'
			end
			return Str
		end
	end
	return EncodeValue(Value)
end

return Module
