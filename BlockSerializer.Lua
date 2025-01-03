local BlockSerializer = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlacementTimeoutDuration = 0.2
local DefaultPlacementInterval = 0.07
local BlockResizeInterval = 0.001
local BlockAppearanceInterval = 0.001
local BlockPositionTolerance = 0.01
local BlockColorTolerance = 0.001

local DirectionVectors = {}

for X = -1, 1 do
    for Y = -1, 1 do
        for Z = -1, 1 do
            table.insert(DirectionVectors, Vector3.new(X, Y, Z))
        end
    end
end

local function RequireExternalModule(ModuleUrl, FallbackModule)
    local LoadSuccess, ModuleResult = pcall(function()
        return loadstring(game:HttpGet(ModuleUrl))()
    end)
    
    if LoadSuccess then
        return ModuleResult
    else
        warn(string.format("Failed to load module from %s: %s", ModuleUrl, ModuleResult))
        return FallbackModule
    end
end

local BlockManipulator = RequireExternalModule(
    "https://raw.githubusercontent.com/GplateGam/World-Edit-Elected-Admin/refs/heads/main/BlockModule.Lua",
    {
        PlaceBlock = function() warn("BlockModule not loaded - PlaceBlock unavailable") end,
        ResizeBlock = function() warn("BlockModule not loaded - ResizeBlock unavailable") end,
        PaintBlock = function() warn("BlockModule not loaded - PaintBlock unavailable") end
    }
)

local DataSerializer = RequireExternalModule(
    "https://raw.githubusercontent.com/GplateGam/World-Edit-Elected-Admin/refs/heads/main/TableCodec.Lua"
)

local MaterialCollection = Enum.Material:GetEnumItems()
local MaterialNameToIndex = {}
local MaterialIndexToType = {}

for MaterialIndex, MaterialItem in ipairs(MaterialCollection) do
    MaterialNameToIndex[MaterialItem.Name] = MaterialIndex
    MaterialIndexToType[MaterialIndex] = MaterialItem
end

local function RoundValueToThousandth(InputNumber)
    assert(type(InputNumber) == "number", "Expected number input")
    return math.round(InputNumber * 1000) / 1000
end

local function CompareColorValues(FirstColor, SecondColor)
    assert(FirstColor and SecondColor, "Colors cannot be nil")
    return math.abs(FirstColor.R - SecondColor.R) < BlockColorTolerance 
        and math.abs(FirstColor.G - SecondColor.G) < BlockColorTolerance 
        and math.abs(FirstColor.B - SecondColor.B) < BlockColorTolerance
end

local function GetRotatedDimensions(Block)
    local CF = Block.CFrame
    local Size = Block.Size
    local _, _, _, R11, R12, R13, R21, R22, R23, R31, R32, R33 = CF:components()
    
    return Vector3.new(
        math.abs(R11 * Size.X) + math.abs(R12 * Size.Y) + math.abs(R13 * Size.Z),
        math.abs(R21 * Size.X) + math.abs(R22 * Size.Y) + math.abs(R23 * Size.Z),
        math.abs(R31 * Size.X) + math.abs(R32 * Size.Y) + math.abs(R33 * Size.Z)
    )
end

local function GetBlockBoundingBox(Block)
    local RotatedDimensions = GetRotatedDimensions(Block)
    return {
        Min = Block.CFrame.Position - RotatedDimensions/2,
        Max = Block.CFrame.Position + RotatedDimensions/2
    }
end

local function AreBlocksAdjacent(FirstBlock, SecondBlock)
    assert(FirstBlock and SecondBlock and FirstBlock.CFrame and SecondBlock.CFrame, "Invalid block parameters")
    
    local FirstBox = GetBlockBoundingBox(FirstBlock)
    local SecondBox = GetBlockBoundingBox(SecondBlock)
    
    FirstBox.Min -= Vector3.new(BlockPositionTolerance, BlockPositionTolerance, BlockPositionTolerance)
    FirstBox.Max += Vector3.new(BlockPositionTolerance, BlockPositionTolerance, BlockPositionTolerance)
    SecondBox.Min -= Vector3.new(BlockPositionTolerance, BlockPositionTolerance, BlockPositionTolerance)
    SecondBox.Max += Vector3.new(BlockPositionTolerance, BlockPositionTolerance, BlockPositionTolerance)
    
    return not (FirstBox.Min.X > SecondBox.Max.X or SecondBox.Min.X > FirstBox.Max.X or
                FirstBox.Min.Y > SecondBox.Max.Y or SecondBox.Min.Y > FirstBox.Max.Y or
                FirstBox.Min.Z > SecondBox.Max.Z or SecondBox.Min.Z > FirstBox.Max.Z)
end

local function FindConnectedBlockCluster(InitialBlock, BlockCollection, ProcessedBlocks)
    local BlockCluster = {InitialBlock}
    ProcessedBlocks[InitialBlock] = true
    local CurrentIndex = 1
    
    while CurrentIndex <= #BlockCluster do
        local ActiveBlock = BlockCluster[CurrentIndex]
        for _, CandidateBlock in ipairs(BlockCollection) do
            if not ProcessedBlocks[CandidateBlock] and AreBlocksAdjacent(ActiveBlock, CandidateBlock) then
                table.insert(BlockCluster, CandidateBlock)
                ProcessedBlocks[CandidateBlock] = true
            end
        end
        CurrentIndex = CurrentIndex + 1
    end
    
    return BlockCluster
end

local function IdentifyBlockClusters(BlockCollection)
    assert(type(BlockCollection) == "table", "Expected table of blocks")
    
    local BlockClusters = {}
    local ProcessedBlocks = {}
    
    for _, Block in ipairs(BlockCollection) do
        if not ProcessedBlocks[Block] then
            local NewCluster = FindConnectedBlockCluster(Block, BlockCollection, ProcessedBlocks)
            if #NewCluster > 0 then
                table.insert(BlockClusters, NewCluster)
            end
        end
    end
    
    return BlockClusters
end

local function SortBlockCluster(BlockCluster)
    local OrderedBlocks = {}
    local CurrentBlock = BlockCluster[1]
    local ProcessedBlocks = {}
    local ProcessingIndex = 1
    
    while ProcessingIndex <= #BlockCluster and CurrentBlock do
        ProcessedBlocks[CurrentBlock] = true
        CurrentBlock.ProcessingIndex = ProcessingIndex
        table.insert(OrderedBlocks, CurrentBlock)
        
        local CandidateBlocks = {}
        for _, Block in ipairs(BlockCluster) do
            if not ProcessedBlocks[Block] then
                for _, ProcessedBlock in ipairs(OrderedBlocks) do
                    if AreBlocksAdjacent(Block, ProcessedBlock) then
                        table.insert(CandidateBlocks, Block)
                        break
                    end
                end
            end
        end
        
        table.sort(CandidateBlocks, function(FirstBlock, SecondBlock)
            local FirstPosition = FirstBlock.CFrame.Position
            local SecondPosition = SecondBlock.CFrame.Position
            local ReferencePosition = CurrentBlock.CFrame.Position
            
            local FirstTouching = AreBlocksAdjacent(FirstBlock, CurrentBlock)
            local SecondTouching = AreBlocksAdjacent(SecondBlock, CurrentBlock)
            
            if FirstTouching ~= SecondTouching then return FirstTouching end
            
            local FirstMatchesY = math.abs(FirstPosition.Y - ReferencePosition.Y) < BlockPositionTolerance
            local SecondMatchesY = math.abs(SecondPosition.Y - ReferencePosition.Y) < BlockPositionTolerance
            
            if FirstMatchesY ~= SecondMatchesY then return FirstMatchesY end
            if math.abs(FirstPosition.Y - SecondPosition.Y) > BlockPositionTolerance then return FirstPosition.Y < SecondPosition.Y end
            
            return (FirstPosition - ReferencePosition).Magnitude < (SecondPosition - ReferencePosition).Magnitude
        end)
        
        CurrentBlock = CandidateBlocks[1]
        ProcessingIndex = ProcessingIndex + 1
    end
    
    return OrderedBlocks
end

local function SerializeBlock(BlockInstance, BlockTypes, SerializedData)
    assert(BlockInstance and BlockTypes and SerializedData, "Missing required parameters")
    
    local TemplateBlock = ReplicatedStorage.Blocks:FindFirstChild(BlockInstance.Name)
    assert(TemplateBlock, "Template block not found: " .. BlockInstance.Name)
    
    local BlockTypeIndex
    for TypeIndex, BlockType in ipairs(BlockTypes) do
        if BlockType == BlockInstance.Name then
            BlockTypeIndex = TypeIndex
            break
        end
    end
    
    if not BlockTypeIndex then
        table.insert(BlockTypes, BlockInstance.Name)
        BlockTypeIndex = #BlockTypes
    end
    
    local BlockEntry = {}
    table.insert(BlockEntry, BlockTypeIndex)
    
    local BlockPosition = BlockInstance.Position
    local BlockRotation = BlockInstance.Rotation
    local TransformData = {
        RoundValueToThousandth(BlockPosition.X),
        RoundValueToThousandth(BlockPosition.Y),
        RoundValueToThousandth(BlockPosition.Z),
        RoundValueToThousandth(BlockRotation.X),
        RoundValueToThousandth(BlockRotation.Y),
        RoundValueToThousandth(BlockRotation.Z)
    }
    table.insert(BlockEntry, TransformData)
    
    if BlockInstance.Size == TemplateBlock.Size then
        table.insert(BlockEntry, 0)
    else
        table.insert(BlockEntry, {
            RoundValueToThousandth(BlockInstance.Size.X),
            RoundValueToThousandth(BlockInstance.Size.Y),
            RoundValueToThousandth(BlockInstance.Size.Z)
        })
    end
    
    local AppearanceProperties = {}
    
    if CompareColorValues(BlockInstance.Color, TemplateBlock.Color) then
        AppearanceProperties[1] = 0
    else
        AppearanceProperties[1] = {
            math.floor(BlockInstance.Color.R * 255),
            math.floor(BlockInstance.Color.G * 255),
            math.floor(BlockInstance.Color.B * 255)
        }
    end
    
    if BlockInstance.Material ~= TemplateBlock.Material then
        local MaterialIndex = MaterialNameToIndex[BlockInstance.Material.Name]
        if MaterialIndex then
            AppearanceProperties[2] = MaterialIndex
        end
    end
    
    table.insert(BlockEntry, AppearanceProperties)
    table.insert(SerializedData, BlockEntry)
end

function BlockSerializer.SerializeBlocks(BlockCollection)
    assert(BlockCollection, "Input blocks cannot be nil")
    
    local SerializedStructure = {
        [1] = {},
        [2] = {}
    }
    
    if typeof(BlockCollection) == "Instance" then
        SerializeBlock(BlockCollection, SerializedStructure[1], SerializedStructure[2])
    else
        for _, Block in pairs(BlockCollection) do
            SerializeBlock(Block, SerializedStructure[1], SerializedStructure[2])
        end
    end
    
    return DataSerializer.Encode(SerializedStructure)
end

local function FindDirectionVector(BlockCFrame, TargetDimensions, TemplateBlock, BlockData)
    for _, DirectionVector in pairs(DirectionVectors) do
        local Offset = DirectionVector * (TargetDimensions / 2) - DirectionVector * (TemplateBlock.Size / 2)
        local FinalCFrame = BlockCFrame * CFrame.new(Offset)
        for _, Block in pairs(BlockData) do
            if AreBlocksAdjacent({["Size"] = TemplateBlock.Size, ["CFrame"] = FinalCFrame}, Block) then
                return true, DirectionVector
            end
        end
    end
    return false, nil
end

local function ResizeBlockWithDirection(Block, TargetDimensions, TemplateBlock, DirectionVector)
    local SizeDifference = TargetDimensions - TemplateBlock.Size
    
    if SizeDifference.X ~= 0 then
        local ResizeMode = SizeDifference.X < 0 and "Shrink" or "Grow"
        local ResizeVector = Vector3.new(math.abs(SizeDifference.X), 0, 0)
        BlockManipulator.ResizeBlock(Block, ResizeVector, "Add", ResizeMode)
    end
    
    if SizeDifference.Y ~= 0 then
        local ResizeMode = SizeDifference.Y < 0 and "Shrink" or "Grow"
        local ResizeVector = Vector3.new(0, math.abs(SizeDifference.Y), 0)
        BlockManipulator.ResizeBlock(Block, ResizeVector, "Add", ResizeMode)
    end
    
    if SizeDifference.Z ~= 0 then
        local ResizeMode = SizeDifference.Z < 0 and "Shrink" or "Grow"
        local ResizeVector = Vector3.new(0, 0, math.abs(SizeDifference.Z))
        BlockManipulator.ResizeBlock(Block, ResizeVector, "Add", ResizeMode)
    end
end

function BlockSerializer.DeserializeBlocks(SerializedData, PlacementInterval)
    assert(SerializedData, "Serialized data cannot be nil")
    PlacementInterval = PlacementInterval or DefaultPlacementInterval
    
    local DeserializeSuccess, DeserializedStructure = pcall(DataSerializer.Decode, SerializedData)
    assert(DeserializeSuccess, "Failed to deserialize block data: " .. tostring(DeserializedStructure))
    
    assert(DeserializedStructure[1] and DeserializedStructure[2], "Invalid data structure")
    local BlockTypes = DeserializedStructure[1]
    local BlockEntries = DeserializedStructure[2]
    
    local TemporaryBlocks = {}
    for _, BlockEntry in ipairs(BlockEntries) do
        if BlockEntry and BlockEntry[2] and #BlockEntry[2] >= 6 then
            local BlockType = BlockTypes[BlockEntry[1]]
            local Position = Vector3.new(BlockEntry[2][1], BlockEntry[2][2], BlockEntry[2][3])
            local Rotation = Vector3.new(BlockEntry[2][4], BlockEntry[2][5], BlockEntry[2][6])
            local Dimensions = BlockEntry[3] ~= 0 and Vector3.new(unpack(BlockEntry[3])) or Vector3.new(3, 3, 3)
            
            local TemporaryBlock = {
                CFrame = CFrame.new(Position) * CFrame.Angles(math.rad(Rotation.X), math.rad(Rotation.Y), math.rad(Rotation.Z)),
                Size = Dimensions,
                Data = BlockEntry,
                Type = BlockType
            }
            table.insert(TemporaryBlocks, TemporaryBlock)
        end
    end
    
    local BlockClusters = IdentifyBlockClusters(TemporaryBlocks)
    for _, Cluster in ipairs(BlockClusters) do
        local SortedBlocks = SortBlockCluster(Cluster)
        for _, Block in ipairs(SortedBlocks) do
            local TargetTransform = Block.CFrame
            local TargetDimensions = Block.Size

            local TemplateBlock = ReplicatedStorage.Blocks:FindFirstChild(Block.Type)
            if not TemplateBlock then return end
            local BlockTemplateSize = TemplateBlock.Size

            local HasAdjacent, DirectionVector = FindDirectionVector(TargetTransform, TargetDimensions, TemplateBlock, SortedBlocks)
            if not (HasAdjacent and DirectionVector) then continue end
            
            local Offset = DirectionVector * (TargetDimensions / 2) - DirectionVector * (BlockTemplateSize / 2)
            local AdjustedTransform = TargetTransform * CFrame.new(Offset)
            
            local PlacedBlock
            local BlockAddedConnection
            local PlacementCompleted = false
            
            BlockAddedConnection = workspace.Blocks.ChildAdded:Connect(function(NewBlock)
                if NewBlock.CFrame == AdjustedTransform then
                    PlacedBlock = NewBlock
                    PlacementCompleted = true
                    BlockAddedConnection:Disconnect()
                end
            end)
            
            local PlacementSuccess = pcall(function()
                if BlockTemplateSize then
                    BlockManipulator.PlaceBlock(Block.Type, AdjustedTransform, BlockTemplateSize + Vector3.new(2,2,2))
                else
                    BlockManipulator.PlaceBlock(Block.Type, AdjustedTransform)
                end
            end)
            
            if not PlacementSuccess then continue end
            
            local StartTime = tick()
            while not PlacementCompleted and (tick() - StartTime) < PlacementTimeoutDuration do
                task.wait(0.01)
            end
            
            if not PlacementCompleted then
                BlockAddedConnection:Disconnect()
                continue
            end
            
            if PlacedBlock then
                if TargetDimensions and PlacedBlock.Size ~= TargetDimensions then
                    local HasAdjacent, DirectionVector = FindDirectionVector(TargetTransform, TargetDimensions, TemplateBlock, SortedBlocks)
                    if HasAdjacent and DirectionVector then
                        task.wait(BlockResizeInterval)
                        ResizeBlockWithDirection(PlacedBlock, TargetDimensions, TemplateBlock, DirectionVector)
                    end
                end
                
                local BlockData = Block.Data
                if BlockData[4] then
                    task.wait(BlockAppearanceInterval)
                    pcall(function()
                        local ShouldPaint = false
                        local BlockColor = PlacedBlock.Color
                        local BlockMaterial = PlacedBlock.Material

                        if BlockData[4][1] ~= 0 then
                            BlockColor = Color3.fromRGB(unpack(BlockData[4][1]))
                            ShouldPaint = true
                        elseif not CompareColorValues(PlacedBlock.Color, TemplateBlock.Color) then
                            BlockColor = TemplateBlock.Color
                            ShouldPaint = true
                        end

                        if BlockData[4][2] then
                            BlockMaterial = MaterialIndexToType[BlockData[4][2]]
                            ShouldPaint = true
                        elseif PlacedBlock.Material ~= TemplateBlock.Material then
                            BlockMaterial = TemplateBlock.Material
                            ShouldPaint = true
                        end

                        if ShouldPaint then
                            BlockManipulator.PaintBlock(PlacedBlock, BlockColor, BlockMaterial)
                        end
                    end)
                end
                task.wait(PlacementInterval)
            end
        end
    end
end

return BlockSerializer
