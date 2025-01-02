local BlockSerializer = {}

local HttpService = game:GetService("HttpService")
local BlockModule = loadstring(game:HttpGet("https://raw.githubusercontent.com/GplateGam/World-Edit-Elected-Admin/refs/heads/main/BlockModule.Lua"))()

local MaterialList = Enum.Material:GetEnumItems()
local MaterialToCodeDictionary = {}
local CodeToMaterialDictionary = {}

for MaterialIndex, MaterialItem in ipairs(MaterialList) do
    MaterialToCodeDictionary[MaterialItem.Name] = MaterialIndex
    CodeToMaterialDictionary[MaterialIndex] = MaterialItem
end

local function RoundToThousandth(InputValue)
    return math.round(InputValue * 1000) / 1000
end

local function EncodeBlock(BlockInstance)
    local TemplateBlock = game.ReplicatedStorage.Blocks:FindFirstChild(BlockInstance.Name)
    local BlockData = {BlockInstance.Name}
    
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
    
    if TemplateBlock then
        if BlockInstance.Size ~= TemplateBlock.Size then
            table.insert(BlockData, {
                RoundToThousandth(BlockInstance.Size.X),
                RoundToThousandth(BlockInstance.Size.Y),
                RoundToThousandth(BlockInstance.Size.Z)
            })
        end
        
        local HasColorChanged = BlockInstance.Color ~= TemplateBlock.Color
        local HasMaterialChanged = BlockInstance.Material ~= TemplateBlock.Material
        
        if HasColorChanged or HasMaterialChanged then
            local AppearanceData = {}
            if HasColorChanged then
                AppearanceData[1] = {
                    RoundToThousandth(BlockInstance.Color.R * 255),
                    RoundToThousandth(BlockInstance.Color.G * 255),
                    RoundToThousandth(BlockInstance.Color.B * 255)
                }
            end
            if HasMaterialChanged then
                AppearanceData[2] = MaterialToCodeDictionary[BlockInstance.Material.Name]
            end
            table.insert(BlockData, AppearanceData)
        end
    end
    
    return BlockData
end

function BlockSerializer.Encode(InputBlocks)
    local EncodedBlocks = {}
    
    if typeof(InputBlocks) == "Instance" then
        table.insert(EncodedBlocks, EncodeBlock(InputBlocks))
    else
        for _, BlockInstance in pairs(InputBlocks) do
            table.insert(EncodedBlocks, EncodeBlock(BlockInstance))
        end
    end
    
    return HttpService:JSONEncode(EncodedBlocks)
end

function BlockSerializer.Decode(EncodedBlockData, PlacementDelay)
    PlacementDelay = PlacementDelay or 0.07
    local DecodedBlockData = HttpService:JSONDecode(EncodedBlockData)
    
    local function ResizeBlockToOriginal(BlockInstance, TargetSize)
        if not BlockInstance then return end
        local CurrentSize = BlockInstance.Size
        
        local function ResizeAxis(AxisIndex, TargetValue)
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

    table.sort(DecodedBlockData, function(FirstBlock, SecondBlock)
        return FirstBlock[2][2] < SecondBlock[2][2]
    end)
    
    for _, BlockInfo in pairs(DecodedBlockData) do
        local PlacedBlock = nil
        local ChildAddedConnection
        
        local BlockPosition = Vector3.new(BlockInfo[2][1], BlockInfo[2][2], BlockInfo[2][3])
        local BlockRotation = Vector3.new(BlockInfo[2][4], BlockInfo[2][5], BlockInfo[2][6])
        local TargetTransform = CFrame.new(BlockPosition) * CFrame.Angles(math.rad(BlockRotation.X), math.rad(BlockRotation.Y), math.rad(BlockRotation.Z))
        
        ChildAddedConnection = workspace.Blocks.ChildAdded:Connect(function(NewBlock)
            if NewBlock.CFrame == TargetTransform then
                PlacedBlock = NewBlock
                ChildAddedConnection:Disconnect()
                ChildAddedConnection = nil
            end
        end)
        
        BlockModule.PlaceBlock(BlockInfo[1], TargetTransform)
        
        task.wait(PlacementDelay)
        if ChildAddedConnection then
            ChildAddedConnection:Disconnect()
            ChildAddedConnection = nil
        end
        
        if PlacedBlock then
            if BlockInfo[3] and type(BlockInfo[3]) == "table" and #BlockInfo[3] == 3 then
                local TargetSize = Vector3.new(unpack(BlockInfo[3]))
                ResizeBlockToOriginal(PlacedBlock, TargetSize)
                
                if BlockInfo[4] then
                    if BlockInfo[4][1] then
                        local BlockColor = Color3.fromRGB(unpack(BlockInfo[4][1]))
                        local BlockMaterial = BlockInfo[4][2] and CodeToMaterialDictionary[BlockInfo[4][2]] or PlacedBlock.Material
                        BlockModule.PaintBlock(PlacedBlock, BlockColor, BlockMaterial)
                    elseif BlockInfo[4][2] then
                        BlockModule.PaintBlock(PlacedBlock, PlacedBlock.Color, CodeToMaterialDictionary[BlockInfo[4][2]])
                    end
                end
            elseif BlockInfo[3] and (BlockInfo[3][1] or BlockInfo[3][2]) then
                if BlockInfo[3][1] then
                    local BlockColor = Color3.fromRGB(unpack(BlockInfo[3][1]))
                    local BlockMaterial = BlockInfo[3][2] and CodeToMaterialDictionary[BlockInfo[3][2]] or PlacedBlock.Material
                    BlockModule.PaintBlock(PlacedBlock, BlockColor, BlockMaterial)
                else
                    BlockModule.PaintBlock(PlacedBlock, PlacedBlock.Color, CodeToMaterialDictionary[BlockInfo[3][2]])
                end
            end
        end
    end
end

return BlockSerializer
