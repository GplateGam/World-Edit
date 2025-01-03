local BlockSerializer = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
if not ReplicatedStorage then
    error("Failed to get ReplicatedStorage")
    return
end

local BlockModule
local Success, Result = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/GplateGam/World-Edit-Elected-Admin/refs/heads/main/BlockModule.Lua"))()
end)

if Success then
    BlockModule = Result
else
    warn("Failed to load BlockModule:", Result)
    BlockModule = {
        PlaceBlock = function() warn("BlockModule not loaded - PlaceBlock unavailable") end,
        ResizeBlock = function() warn("BlockModule not loaded - ResizeBlock unavailable") end,
        PaintBlock = function() warn("BlockModule not loaded - PaintBlock unavailable") end
    }
end

local TableCodec
local Success2, Result2 = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/GplateGam/World-Edit-Elected-Admin/refs/heads/main/TableCodec.Lua"))()
end)

if Success2 then
    TableCodec = Result2
else
    warn("Failed to load TableCodec:", Result2)
    return
end

local MaterialList = Enum.Material:GetEnumItems()
local MaterialToCodeDictionary = {}
local CodeToMaterialDictionary = {}

for MaterialIndex, MaterialItem in ipairs(MaterialList) do
    MaterialToCodeDictionary[MaterialItem.Name] = MaterialIndex
    CodeToMaterialDictionary[MaterialIndex] = MaterialItem
end

local function RoundToThousandth(InputValue)
    if type(InputValue) ~= "number" then
        warn("RoundToThousandth received non-number input:", InputValue)
        return 0
    end
    return math.round(InputValue * 1000) / 1000
end

local function CompareColors(ColorA, ColorB)
    if not ColorA or not ColorB then
        warn("CompareColors received nil color")
        return false
    end
    local Threshold = 0.001
    return math.abs(ColorA.R - ColorB.R) < Threshold 
        and math.abs(ColorA.G - ColorB.G) < Threshold 
        and math.abs(ColorA.B - ColorB.B) < Threshold
end

local function AreBlocksTouching(BlockA, BlockB)
    if not BlockA or not BlockB or not BlockA.CFrame or not BlockB.CFrame then
        warn("AreBlocksTouching received invalid blocks")
        return false
    end
    
    local PosA = BlockA.CFrame.Position
    local SizeA = BlockA.Size
    local PosB = BlockB.CFrame.Position
    local SizeB = BlockB.Size
    
    if not PosA or not PosB or not SizeA or not SizeB then
        return false
    end
    
    local DeltaX = math.abs(PosA.X - PosB.X)
    local DeltaY = math.abs(PosA.Y - PosB.Y)
    local DeltaZ = math.abs(PosA.Z - PosB.Z)
    local MinX = (SizeA.X + SizeB.X) / 2
    local MinY = (SizeA.Y + SizeB.Y) / 2
    local MinZ = (SizeA.Z + SizeB.Z) / 2
    local Tolerance = 0.01
    return DeltaX <= MinX + Tolerance and DeltaY <= MinY + Tolerance and DeltaZ <= MinZ + Tolerance
end

local function FindGroups(Blocks)
    if not Blocks or type(Blocks) ~= "table" then
        warn("FindGroups received invalid input")
        return {}
    end

    local Groups = {}
    local Visited = {}

    local function FindConnectedBlocks(Block)
        if not Block then return {} end
        
        local Group = {Block}
        Visited[Block] = true
        local Index = 1
        
        while Index <= #Group do
            local CurrentBlock = Group[Index]
            if CurrentBlock then
                for _, OtherBlock in ipairs(Blocks) do
                    if OtherBlock and not Visited[OtherBlock] and AreBlocksTouching(CurrentBlock, OtherBlock) then
                        table.insert(Group, OtherBlock)
                        Visited[OtherBlock] = true
                    end
                end
            end
            Index = Index + 1
        end
        return Group
    end

    for _, Block in ipairs(Blocks) do
        if Block and not Visited[Block] then
            local Group = FindConnectedBlocks(Block)
            if #Group > 0 then
                table.insert(Groups, Group)
            end
        end
    end
    return Groups
end

local function SortBlocks(BlocksData)
    if not BlocksData or type(BlocksData) ~= "table" then
        warn("SortBlocks received invalid input")
        return {}
    end

    local TempBlocks = {}
    for _, BlockInfo in ipairs(BlocksData) do
        if BlockInfo and BlockInfo[2] and #BlockInfo[2] >= 6 then
            local BlockPosition = Vector3.new(BlockInfo[2][1], BlockInfo[2][2], BlockInfo[2][3])
            local BlockRotation = Vector3.new(BlockInfo[2][4], BlockInfo[2][5], BlockInfo[2][6])
            local BlockSize = BlockInfo[3] ~= 0 and Vector3.new(unpack(BlockInfo[3])) or Vector3.new(3, 3, 3)

            local TempBlock = {
                CFrame = CFrame.new(BlockPosition) * CFrame.Angles(math.rad(BlockRotation.X), math.rad(BlockRotation.Y), math.rad(BlockRotation.Z)),
                Size = BlockSize,
                Data = BlockInfo
            }
            table.insert(TempBlocks, TempBlock)
        end
    end

    local SortedBlocks = {}
    local Groups = FindGroups(TempBlocks)

    for GroupId, Group in ipairs(Groups) do
        if #Group > 0 then
            local LowestBlock = Group[1]
            for _, Block in ipairs(Group) do
                if Block.CFrame.Position.Y < LowestBlock.CFrame.Position.Y then
                    LowestBlock = Block
                end
            end

            local ProcessedBlocks = {}
            local CurrentBlock = LowestBlock
            local CurrentIndex = 1
            local Processed = {}

            while CurrentIndex <= #Group and CurrentBlock do
                Processed[CurrentBlock] = true
                CurrentBlock.Index = CurrentIndex
                CurrentBlock.StructureId = GroupId
                table.insert(ProcessedBlocks, CurrentBlock)

                local Candidates = {}
                for _, Block in ipairs(Group) do
                    if Block and not Processed[Block] then
                        for _, ProcessedBlock in ipairs(ProcessedBlocks) do
                            if AreBlocksTouching(Block, ProcessedBlock) then
                                table.insert(Candidates, Block)
                                break
                            end
                        end
                    end
                end

                table.sort(Candidates, function(A, B)
                    if not A or not B or not A.CFrame or not B.CFrame or not CurrentBlock.CFrame then
                        return false
                    end
                    
                    local PosA = A.CFrame.Position
                    local PosB = B.CFrame.Position
                    local PosCurrent = CurrentBlock.CFrame.Position
                    local ATouchingCurrent = AreBlocksTouching(A, CurrentBlock)
                    local BTouchingCurrent = AreBlocksTouching(B, CurrentBlock)
                    
                    if ATouchingCurrent ~= BTouchingCurrent then
                        return ATouchingCurrent
                    end
                    
                    local AAtCurrentY = math.abs(PosA.Y - PosCurrent.Y) < 0.01
                    local BAtCurrentY = math.abs(PosB.Y - PosCurrent.Y) < 0.01
                    
                    if AAtCurrentY ~= BAtCurrentY then
                        return AAtCurrentY
                    end
                    
                    if math.abs(PosA.Y - PosB.Y) > 0.01 then
                        return PosA.Y < PosB.Y
                    end
                    
                    return (PosA - PosCurrent).Magnitude < (PosB - PosCurrent).Magnitude
                end)

                if #Candidates > 0 then
                    CurrentBlock = Candidates[1]
                else
                    break
                end
                CurrentIndex = CurrentIndex + 1
            end

            for _, Block in ipairs(ProcessedBlocks) do
                if Block and Block.Data then
                    table.insert(SortedBlocks, Block.Data)
                end
            end
        end
    end

    return SortedBlocks
end

local function EncodeBlock(BlockInstance)
    if not BlockInstance then 
        warn("EncodeBlock received nil instance")
        return nil 
    end

    local TemplateBlock = ReplicatedStorage.Blocks:FindFirstChild(BlockInstance.Name)
    if not TemplateBlock then 
        warn("Template block not found for:", BlockInstance.Name)
        return nil 
    end

    local BlockData = {BlockInstance.Name}

    if not BlockInstance.Position or not BlockInstance.Rotation then
        warn("Block missing Position or Rotation:", BlockInstance.Name)
        return nil
    end

    local BlockPosition = BlockInstance.Position
    local BlockRotation = BlockInstance.Rotation
    local BlockTransformData = {
        RoundToThousandth(BlockPosition.X),
        RoundToThousandth(BlockPosition.Y),
        RoundToThousandth(BlockPosition.Z),
        RoundToThousandth(BlockRotation.X),
        RoundToThousandth(BlockRotation.Y),
        RoundToThousandth(BlockRotation.Z)
    }
    table.insert(BlockData, BlockTransformData)

    if BlockInstance.Size ~= TemplateBlock.Size then
        table.insert(BlockData, {
            RoundToThousandth(BlockInstance.Size.X),
            RoundToThousandth(BlockInstance.Size.Y),
            RoundToThousandth(BlockInstance.Size.Z)
        })
    else
        table.insert(BlockData, 0)
    end

    local AppearanceData = {}

    if CompareColors(BlockInstance.Color, TemplateBlock.Color) then
        AppearanceData[1] = 0
    else
        AppearanceData[1] = {
            math.floor(BlockInstance.Color.R * 255),
            math.floor(BlockInstance.Color.G * 255),
            math.floor(BlockInstance.Color.B * 255)
        }
    end

    if BlockInstance.Material ~= TemplateBlock.Material then
        local MaterialCode = MaterialToCodeDictionary[BlockInstance.Material.Name]
        if MaterialCode then
            AppearanceData[2] = MaterialCode
        end
    end

    table.insert(BlockData, AppearanceData)
    return BlockData
end

function BlockSerializer.Encode(InputBlocks)
    if not InputBlocks then
        warn("Encode received nil input")
        return nil
    end

    local EncodedBlocks = {}

    if typeof(InputBlocks) == "Instance" then
        local Encoded = EncodeBlock(InputBlocks)
        if Encoded then
            table.insert(EncodedBlocks, Encoded)
        end
    else
        for _, BlockInstance in pairs(InputBlocks) do
            local Encoded = EncodeBlock(BlockInstance)
            if Encoded then
                table.insert(EncodedBlocks, Encoded)
            end
        end
    end

    return TableCodec.Encode(EncodedBlocks)
end

function BlockSerializer.Decode(EncodedBlockData, PlacementDelay)
    if not EncodedBlockData then
        warn("Decode received nil input")
        return
    end

    PlacementDelay = PlacementDelay or 0.07
    
    local Success, DecodedBlockData = pcall(function()
        return TableCodec.Decode(EncodedBlockData)
    end)
    
    if not Success then
        warn("Failed to decode block data:", DecodedBlockData)
        return
    end

    local SortedBlockData = SortBlocks(DecodedBlockData)

    local function ResizeBlockToOriginal(BlockInstance, TargetSize)
        if not BlockInstance or not TargetSize then return end
        
        local CurrentSize = BlockInstance.Size
        if not CurrentSize then return end

        local function ResizeAxis(AxisIndex, TargetValue)
            if type(TargetValue) ~= "number" then return end
            
            local CurrentValue = (AxisIndex == 1 and CurrentSize.X) or (AxisIndex == 2 and CurrentSize.Y) or CurrentSize.Z
            local SizeDifference = TargetValue - CurrentValue

            if SizeDifference ~= 0 then
                local ResizeDirection
                if AxisIndex == 1 then
                    ResizeDirection = Vector3.new(SizeDifference, 0, 0)
                elseif AxisIndex == 2 then
                    ResizeDirection = Vector3.new(0, SizeDifference, 0)
                else
                    ResizeDirection = Vector3.new(0, 0, SizeDifference)
                end

                local ResizeAction = SizeDifference > 0 and "Grow" or "Shrink"

                if BlockModule and BlockModule.ResizeBlock then
                    BlockModule.ResizeBlock(BlockInstance, ResizeDirection * 0.5, ResizeAction)
                    BlockModule.ResizeBlock(BlockInstance, ResizeDirection * -0.5, ResizeAction)
                else
                    warn("BlockModule.ResizeBlock not found")
                end
            end
        end

        ResizeAxis(1, TargetSize.X)
        ResizeAxis(2, TargetSize.Y)
        ResizeAxis(3, TargetSize.Z)
    end

    local function ApplyBlockAppearance(BlockInstance, AppearanceData)
        if not BlockInstance or not AppearanceData then return end

        local BlockColor = BlockInstance.Color
        local BlockMaterial = BlockInstance.Material

        if AppearanceData[1] and AppearanceData[1] ~= 0 then
            BlockColor = Color3.fromRGB(unpack(AppearanceData[1]))
        end

        if AppearanceData[2] then
            local NewMaterial = CodeToMaterialDictionary[AppearanceData[2]]
            if NewMaterial then
                BlockMaterial = NewMaterial
            end
        end

        if BlockModule and BlockModule.PaintBlock then
            BlockModule.PaintBlock(BlockInstance, BlockColor, BlockMaterial)
        end
    end

    for _, BlockInfo in pairs(SortedBlockData) do
        if not BlockInfo or type(BlockInfo) ~= "table" or not BlockInfo[1] or not BlockInfo[2] then
            warn("Invalid block data encountered")
            continue
        end

        local PlacedBlock = nil
        local ChildAddedConnection = nil

        local BlockPosition = Vector3.new(BlockInfo[2][1], BlockInfo[2][2], BlockInfo[2][3])
        local BlockRotation = Vector3.new(BlockInfo[2][4], BlockInfo[2][5], BlockInfo[2][6])
        local TargetTransform = CFrame.new(BlockPosition) * CFrame.Angles(math.rad(BlockRotation.X), math.rad(BlockRotation.Y), math.rad(BlockRotation.Z))
        local TargetSize = nil

        if BlockInfo[3] and type(BlockInfo[3]) == "table" and #BlockInfo[3] >= 3 then
            TargetSize = Vector3.new(unpack(BlockInfo[3]))
        end

        local BlockPlaced = false
        local Timeout = 5

        local function Cleanup()
            if ChildAddedConnection then
                ChildAddedConnection:Disconnect()
                ChildAddedConnection = nil
            end
        end

        local PlacementComplete = false
        
        ChildAddedConnection = workspace.Blocks.ChildAdded:Connect(function(NewBlock)
            if NewBlock.CFrame == TargetTransform then
                PlacedBlock = NewBlock
                BlockPlaced = true
                PlacementComplete = true
                Cleanup()
            end
        end)

        local Success, Error = pcall(function()
            if TargetSize then
                BlockModule.PlaceBlock(BlockInfo[1], TargetTransform, TargetSize + Vector3.new(2,2,2))
            else
                BlockModule.PlaceBlock(BlockInfo[1], TargetTransform)
            end
        end)

        if not Success then
            warn("Failed to place block:", Error)
            Cleanup()
            continue
        end

        local StartTime = tick()
        while not PlacementComplete and (tick() - StartTime) < Timeout do
            task.wait(PlacementDelay)
        end

        if not PlacementComplete then
            warn("Block placement timed out")
            Cleanup()
            continue
        end

        if PlacedBlock then
            if TargetSize then
                task.wait(0.01)
                local Success, Error = pcall(function()
                    ResizeBlockToOriginal(PlacedBlock, TargetSize)
                end)
                if not Success then
                    warn("Failed to resize block:", Error)
                end
            end

            if BlockInfo[4] then
                task.wait(0.01)
                local Success, Error = pcall(function()
                    ApplyBlockAppearance(PlacedBlock, BlockInfo[4])
                end)
                if not Success then
                    warn("Failed to apply block appearance:", Error)
                end
            end
        end
    end
end

return BlockSerializer
