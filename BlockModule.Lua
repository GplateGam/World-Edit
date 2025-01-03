local BlockModule = {}

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local BuildEvent = RemotesFolder:WaitForChild("BuildEvent")
local DeleteEvent = RemotesFolder:WaitForChild("DeleteEvent")

local LocalPlayer = Players.LocalPlayer

local function EquipTool(ToolName)
    local Backpack = LocalPlayer:FindFirstChild("Backpack")
    if not Backpack then return end

    local Tool = Backpack:FindFirstChild(ToolName)
    if not Tool then return end

    local Character = LocalPlayer.Character
    if not Character then return end

    local Humanoid = Character:FindFirstChildWhichIsA("Humanoid")
    if not Humanoid then return end

    Humanoid:EquipTool(Tool)
end

local function FindNearbyBlock(TargetCFrame, CustomSearchSize)
    CustomSearchSize = CustomSearchSize or Vector3.new(5, 5, 5)

    if not TargetCFrame or typeof(TargetCFrame) ~= "CFrame" then
        return nil
    end
    
    local OverlapParams = OverlapParams.new()
    local FilterDescendants = {}

    if Workspace:FindFirstChild("Baseplate") then
        table.insert(FilterDescendants, Workspace:FindFirstChild("Baseplate"))
    end

    if Workspace:FindFirstChild("TerrainBlocks") then
        table.insert(FilterDescendants, Workspace:FindFirstChild("TerrainBlocks"))
    end

    if Workspace:FindFirstChild("Blocks") then
        table.insert(FilterDescendants, Workspace:FindFirstChild("Blocks"))
    end

    OverlapParams.FilterDescendantsInstances = FilterDescendants
    OverlapParams.FilterType = Enum.RaycastFilterType.Include
    local RegionParts = Workspace:GetPartBoundsInBox(TargetCFrame, CustomSearchSize, OverlapParams)
    local AllowedParts = {}

    for _, Model in pairs(FilterDescendants) do
        if typeof(Model) == "Instance" then
            table.insert(AllowedParts, Model)
        end
        for _, Descendant in ipairs(Model:GetDescendants()) do
            if typeof(Descendant) == "Instance" then
                table.insert(AllowedParts, Descendant)
            end
        end
    end

    for _, Part in ipairs(RegionParts) do
        if table.find(AllowedParts, Part) then
            return Part
        end
    end
    
    return nil
end

function BlockModule.PlaceBlock(BlockTypeName, BlockCFrame, CustomSearchSize)
    if not BlockTypeName or typeof(BlockTypeName) ~= "string" then
        warn("BlockTypeName must be a string")
        return nil
    end

    if not BlockCFrame or typeof(BlockCFrame) ~= "CFrame" then
        warn("BlockCFrame must be a CFrame")
        return nil
    end
    
    EquipTool("BuildingTool")

    local NearbyBlock = FindNearbyBlock(BlockCFrame, CustomSearchSize)
    if not NearbyBlock then
        return nil
    end
    
    local BlockTemplate = ReplicatedStorage.Blocks:FindFirstChild(BlockTypeName)
    if not BlockTemplate then
        return nil
    end
    
    local Args = {
        [1] = BlockCFrame,
        [2] = BlockTemplate,
        [3] = NearbyBlock
    }
    
    if BuildEvent:IsA("RemoteEvent") then
        BuildEvent:FireServer(unpack(Args))
    elseif BuildEvent:IsA("RemoteFunction") then
        return BuildEvent:InvokeServer(unpack(Args))
    end

    return nil
end

function BlockModule.DeleteBlock(Block)
    if not Block or typeof(Block) ~= "Instance" then
        warn("Block must be an Instance")
        return
    end
    
    EquipTool("DeleteTool")
    DeleteEvent:FireServer(Block)
end

function BlockModule.PaintBlock(Block, Color, EnumMaterial)
    if not Block or typeof(Block) ~= "Instance" then
        warn("Block must be an Instance")
        return
    end

    if not Color or typeof(Color) ~= "Color3" then
        warn("Color must be a Color3 value")
        return
    end

    if not EnumMaterial or typeof(EnumMaterial) ~= "EnumItem" or EnumMaterial.EnumType ~= Enum.Material then
        warn("EnumMaterial must be an Enum.Material")
        return
    end
    
    EquipTool("PaintTool")

    local Args = {
        [1] = Block,
        [2] = "Paint",
        [3] = Color,
        [4] = EnumMaterial
    }

    DeleteEvent:FireServer(unpack(Args))
end

function BlockModule.ResizeBlock(Block, ResizeVector, Mode, ShrinkOrGrow)
   if not Block or typeof(Block) ~= "Instance" then
       warn("Block must be an Instance")
       return
   end
   if Block:GetAttribute("FakeBlock") then
       return
   end
   if not ResizeVector or typeof(ResizeVector) ~= "Vector3" then
       warn("ResizeVector must be a Vector3")
       return
   end
   if Mode == "Add" and (not ShrinkOrGrow or typeof(ShrinkOrGrow) ~= "string" or (ShrinkOrGrow ~= "Shrink" and ShrinkOrGrow ~= "Grow")) then
       warn("ShrinkOrGrow must be either 'Shrink' or 'Grow' when Mode is 'Add'")
       return
   end
   if not Mode or typeof(Mode) ~= "string" or (Mode ~= "Add" and Mode ~= "Set") then
       warn("Mode must be either 'Add' or 'Set'")
       return
   end

   EquipTool("ResizeTool")
   
   if Mode == "Set" then
       local CurrentSize = Block.Size
       local DifferenceVector = ResizeVector - CurrentSize
       
       local Axes = {"X", "Y", "Z"}
       for _, Axis in ipairs(Axes) do
           local Difference = DifferenceVector[Axis]
           if Difference ~= 0 then
               local AbsDifference = math.abs(Difference)
               local ResizeMode = Difference > 0 and "Grow" or "Shrink"
               
               for _, Multiplier in ipairs({0.5, -0.5}) do
                   local AxisValue = AbsDifference * Multiplier
                   
                   local Args = {
                       [1] = Block,
                       [2] = "Resize",
                       [3] = Vector3.new(
                           Axis == "X" and AxisValue or 0,
                           Axis == "Y" and AxisValue or 0,
                           Axis == "Z" and AxisValue or 0
                       ),
                       [4] = ResizeMode
                   }
                   DeleteEvent:FireServer(unpack(Args))
               end
           end
       end
   else
       local Axes = {"X", "Y", "Z"}
       for _, Axis in ipairs(Axes) do
           local AxisValue = ResizeVector[Axis]
           if AxisValue ~= 0 then
               local Args = {
                   [1] = Block,
                   [2] = "Resize",
                   [3] = Vector3.new(
                       Axis == "X" and AxisValue or 0,
                       Axis == "Y" and AxisValue or 0,
                       Axis == "Z" and AxisValue or 0
                   ),
                   [4] = ShrinkOrGrow
               }
               DeleteEvent:FireServer(unpack(Args))
           end
       end
   end
end

return BlockModule
