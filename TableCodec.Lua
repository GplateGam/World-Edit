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
			while Index <= Length and not InputString:sub(Index, Index):match("[%s=;}]") do
				Value = Value .. InputString:sub(Index, Index)
				Index = Index + 1
			end
			return Value
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
				table.insert(Parts, EncodeValue(Key) .. "=" .. EncodeValue(SubValue))
			end
			return "{" .. table.concat(Parts, ";") .. "}"
		else
			return tostring(Val)
		end
	end

	return EncodeValue(Value)
end

return Module
