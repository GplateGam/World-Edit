local Module = {}

local CellSeparator = "|"
local KeyValueSeparator = "="
local PairSeparator = ";"
local TableStart = "{"
local TableEnd = "}"
local EscapeCharacter = "\\"
local EscapeMap = {
    ["|"] = "p",
    [";"] = "s",
    ["="] = "e",
    ["\\"] = "b",
    ["{"] = "t",
    ["}"] = "c"
}
local ReverseEscapeMap = {
    p = "|",
    s = ";",
    e = "=",
    b = "\\",
    t = "{",
    c = "}"
}

local ProcessedCharacterCount = 0

local function YieldCheck()
    ProcessedCharacterCount = ProcessedCharacterCount + 1
    if ProcessedCharacterCount >= 200 then
        ProcessedCharacterCount = 0
        task.wait(0)
    end
end

local function ConvertValueToString(InputValue)
    local ValueType = type(InputValue)
    
    if ValueType == "string" then
        return InputValue
    elseif ValueType == "number" or ValueType == "boolean" then
        return tostring(InputValue)
    elseif ValueType == "nil" then
        return "nil"
    else
        return ValueType
    end
end

local function EscapeString(InputString)
    return InputString:gsub("([|;=\\{}])", function(MatchCharacter)
        YieldCheck()
        return EscapeCharacter .. EscapeMap[MatchCharacter]
    end)
end

local function EncodeTableValue(InputValue)
    if type(InputValue) == "table" then
        local PairList = {}
        for TableKey, TableValue in next, InputValue do
            YieldCheck()
            local EncodedKey = EscapeString(ConvertValueToString(TableKey))
            local EncodedValue = EncodeTableValue(TableValue)
            table.insert(PairList, EncodedKey .. KeyValueSeparator .. EncodedValue)
        end
        return TableStart .. table.concat(PairList, PairSeparator) .. TableEnd
    else
        return EscapeString(ConvertValueToString(InputValue))
    end
end

function Module.Encode(InputTable)
    ProcessedCharacterCount = 0
    if type(InputTable) ~= "table" then
        return EscapeString(ConvertValueToString(InputTable))
    end
    return EncodeTableValue(InputTable)
end

local function RestoreValue(InputString)
    if InputString == "nil" then
        return nil
    elseif InputString == "true" then
        return true
    elseif InputString == "false" then
        return false
    else
        return tonumber(InputString) or InputString
    end
end

local function DecodeValue(InputString)
    if InputString:sub(1, 1) == TableStart then
        return Module.Decode(InputString:sub(2, -2))
    end
    return RestoreValue(InputString)
end

function Module.Decode(InputString)
    ProcessedCharacterCount = 0
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
    local NestedLevel = 0
    
    for Index = 1, #InputString do
        YieldCheck()
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
        elseif CurrentCharacter == TableStart then
            NestedLevel = NestedLevel + 1
            CurrentPart = CurrentPart .. CurrentCharacter
        elseif CurrentCharacter == TableEnd then
            NestedLevel = NestedLevel - 1
            CurrentPart = CurrentPart .. CurrentCharacter
        elseif NestedLevel > 0 then
            CurrentPart = CurrentPart .. CurrentCharacter
        elseif CurrentCharacter == KeyValueSeparator and IsKeyBuilding then
            CurrentKey = CurrentPart
            CurrentPart = ""
            IsKeyBuilding = false
        elseif CurrentCharacter == PairSeparator and NestedLevel == 0 then
            CurrentValue = CurrentPart
            local FinalKey = RestoreValue(CurrentKey)
            local FinalValue = DecodeValue(CurrentValue)
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
            local FinalValue = DecodeValue(CurrentValue)
            ResultTable[FinalKey] = FinalValue
        end
    end
    
    return ResultTable
end

return Module
