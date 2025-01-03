local Module = {}

local CellSeparator = "|"
local KeyValueSeparator = "="
local PairSeparator = ";"
local EscapeCharacter = "\\"
local EscapeMap = {
	["|"] = "p",
	[";"] = "s",
	["="] = "e",
	["\\"] = "b"
}
local ReverseEscapeMap = {
	p = "|",
	s = ";",
	e = "=",
	b = "\\"
}

local function ConvertValueToString(InputValue)
	local ValueType = type(InputValue)

	if ValueType == "string" then
		return InputValue
	elseif ValueType == "number" or ValueType == "boolean" then
		return tostring(InputValue)
	elseif ValueType == "table" then
		return "t"
	elseif ValueType == "nil" then
		return "nil"
	else
		return ValueType
	end
end

local function EscapeString(InputString)
	return InputString:gsub("([|;=\\])", function(MatchCharacter)
		return EscapeCharacter .. EscapeMap[MatchCharacter]
	end)
end

function Module.Encode(InputTable)
	if type(InputTable) ~= "table" then
		return EscapeString(ConvertValueToString(InputTable))
	end

	local PairList = {}
	for TableKey, TableValue in next, InputTable do
		local EncodedKey = EscapeString(ConvertValueToString(TableKey))
		local EncodedValue = EscapeString(ConvertValueToString(TableValue))
		table.insert(PairList, EncodedKey .. KeyValueSeparator .. EncodedValue)
	end

	return table.concat(PairList, PairSeparator)
end

local function RestoreValue(InputString)
	if InputString == "nil" then
		return nil
	elseif InputString == "true" then
		return true
	elseif InputString == "false" then
		return false
	elseif InputString == "t" then
		return {}
	else
		return tonumber(InputString) or InputString
	end
end

function Module.Decode(InputString)
	if type(InputString) ~= "string" then
		error("Input must be a string")
	end

	if InputString == "" then
		return {}
	end

	local ResultTable = {}
	local CurrentKey = ""
	local CurrentValue = ""
	local CurrentPart = ""
	local IsEscaped = false
	local IsKeyBuilding = true

	for Index = 1, #InputString do
		local CurrentCharacter = InputString:sub(Index, Index)

		if IsEscaped then
			local SpecialCharacter = ReverseEscapeMap[CurrentCharacter]
			if SpecialCharacter then
				CurrentPart = CurrentPart .. SpecialCharacter
				IsEscaped = false
			else
				error(string.format("Invalid escape sequence: %s%s", EscapeCharacter, CurrentCharacter))
			end
		elseif CurrentCharacter == EscapeCharacter then
			IsEscaped = true
		elseif CurrentCharacter == KeyValueSeparator and IsKeyBuilding then
			CurrentKey = CurrentPart
			CurrentPart = ""
			IsKeyBuilding = false
		elseif CurrentCharacter == PairSeparator then
			CurrentValue = CurrentPart
			local FinalKey = RestoreValue(CurrentKey)
			local FinalValue = RestoreValue(CurrentValue)
			ResultTable[FinalKey] = FinalValue
			CurrentPart = ""
			IsKeyBuilding = true
		else
			CurrentPart = CurrentPart .. CurrentCharacter
		end
	end

	if #CurrentPart > 0 then
		if IsKeyBuilding then
			error("Incomplete key-value pair")
		else
			CurrentValue = CurrentPart
			local FinalKey = RestoreValue(CurrentKey)
			local FinalValue = RestoreValue(CurrentValue)
			ResultTable[FinalKey] = FinalValue
		end
	end

	return ResultTable
end

return Module
