local BlockSerializer = {}

local HttpService = game:GetService("HttpService")

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

local function CompareColors(ColorA, ColorB)
    local Threshold = 0.001
    return math.abs(ColorA.R - ColorB.R) < Threshold 
        and math.abs(ColorA.G - ColorB.G) < Threshold 
        and math.abs(ColorA.B - ColorB.B) < Threshold
end

local function AreBlocksTouching(BlockA, BlockB)
    local PosA = BlockA.CFrame.Position
    local SizeA = BlockA.Size
    local PosB = BlockB.CFrame.Position
    local SizeB = BlockB.Size
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
    local Groups = {}
    local Visited = {}

    local function FindConnectedBlocks(Block)
        local Group = {Block}
        Visited[Block] = true
        local Index = 1
        while Index <= #Group do
            local CurrentBlock = Group[Index]
            for _, OtherBlock in ipairs(Blocks) do
                if not Visited[OtherBlock] and AreBlocksTouching(CurrentBlock, OtherBlock) then
                    table.insert(Group, OtherBlock)
                    Visited[OtherBlock] = true
                end
            end
            Index = Index + 1
        end
        return Group
    end

    for _, Block in ipairs(Blocks) do
        if not Visited[Block] then
            local Group = FindConnectedBlocks(Block)
            table.insert(Groups, Group)
        end
    end
    return Groups
end

local function SortBlocks(BlocksData)
    local TempBlocks = {}
    for _, BlockInfo in ipairs(BlocksData) do
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

    local SortedBlocks = {}
    local Groups = FindGroups(TempBlocks)

    for GroupId, Group in ipairs(Groups) do
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

        while CurrentIndex <= #Group do
            Processed[CurrentBlock] = true
            CurrentBlock.Index = CurrentIndex
            CurrentBlock.StructureId = GroupId
            table.insert(ProcessedBlocks, CurrentBlock)

            local Candidates = {}
            for _, Block in ipairs(Group) do
                if not Processed[Block] then
                    for _, ProcessedBlock in ipairs(ProcessedBlocks) do
                        if AreBlocksTouching(Block, ProcessedBlock) then
                            table.insert(Candidates, Block)
                            break
                        end
                    end
                end
            end

            table.sort(Candidates, function(A, B)
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
            table.insert(SortedBlocks, Block.Data)
        end
    end

    return SortedBlocks
end

local function EncodeBlock(BlockInstance)
    if not BlockInstance then return nil end
    
    local TemplateBlock = game.ReplicatedStorage.Blocks:FindFirstChild(BlockInstance.Name)
    if not TemplateBlock then 
        warn("Template block not found for:", BlockInstance.Name)
        return nil 
    end
    
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
            AppearanceData[2] = MaterialToCodeDictionary[BlockInstance.Material.Name]
        end

        table.insert(BlockData, AppearanceData)
    end

    return BlockData
end

function BlockSerializer.Encode(InputBlocks)
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

    return HttpService:JSONEncode(EncodedBlocks)
end

function BlockSerializer.Decode(EncodedBlockData, PlacementDelay)
    PlacementDelay = PlacementDelay or 0.07
    
    local Success, DecodedBlockData = pcall(HttpService.JSONDecode, HttpService, EncodedBlockData)
    if not Success then
        warn("Failed to decode block data:", DecodedBlockData)
        return
    end

    local SortedBlockData = SortBlocks(DecodedBlockData)

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

    local function ApplyBlockAppearance(BlockInstance, AppearanceData)
        if not BlockInstance or not AppearanceData then return end

        local BlockColor = BlockInstance.Color
        local BlockMaterial = BlockInstance.Material

        if AppearanceData[1] and AppearanceData[1] ~= 0 then
            BlockColor = Color3.fromRGB(unpack(AppearanceData[1]))
        end

        if AppearanceData[2] then
            BlockMaterial = CodeToMaterialDictionary[AppearanceData[2]]
        end

        if BlockModule and BlockModule.PaintBlock then
            BlockModule.PaintBlock(BlockInstance, BlockColor, BlockMaterial)
        end
    end

    for _, BlockInfo in pairs(SortedBlockData) do
        local PlacedBlock = nil
        local ChildAddedConnection = nil

        local BlockPosition = Vector3.new(BlockInfo[2][1], BlockInfo[2][2], BlockInfo[2][3])
        local BlockRotation = Vector3.new(BlockInfo[2][4], BlockInfo[2][5], BlockInfo[2][6])
        local TargetTransform = CFrame.new(BlockPosition) * CFrame.Angles(math.rad(BlockRotation.X), math.rad(BlockRotation.Y), math.rad(BlockRotation.Z))
        local TargetSize = nil

        if BlockInfo[3] and type(BlockInfo[3]) == "table" then
            TargetSize = Vector3.new(unpack(BlockInfo[3]))
        end

        local BlockPlaced = false
        
        local function Cleanup()
            if ChildAddedConnection then
                ChildAddedConnection:Disconnect()
                ChildAddedConnection = nil
            end
        end

        ChildAddedConnection = workspace.Blocks.ChildAdded:Connect(function(NewBlock)
            if NewBlock.CFrame == TargetTransform then
                PlacedBlock = NewBlock
                BlockPlaced = true
                Cleanup()
            end
        end)

        if TargetSize then
            BlockModule.PlaceBlock(BlockInfo[1], TargetTransform, TargetSize + Vector3.new(2,2,2))
        else
            BlockModule.PlaceBlock(BlockInfo[1], TargetTransform)
        end

        task.wait(PlacementDelay)
        
        Cleanup()

        if PlacedBlock then
            if TargetSize then
                task.wait(0.01)
                ResizeBlockToOriginal(PlacedBlock, TargetSize)
            end

            if BlockInfo[4] then
                task.wait(0.01)
                ApplyBlockAppearance(PlacedBlock, BlockInfo[4])
            end
        end
    end
end

return BlockSerializer
