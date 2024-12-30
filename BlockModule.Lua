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

local function FindNearbyBlock(TargetCFrame)
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

    local RegionParts = Workspace:GetPartBoundsInBox(TargetCFrame, Vector3.new(5, 5, 5), OverlapParams)
    local AllowedParts = {}

    for _, Model in pairs(FilterDescendants) do
        if Model:IsA("BasePart") then
            table.insert(AllowedParts, Model)
        end
        for _, Descendant in ipairs(Model:GetDescendants()) do
            if Descendant:IsA("BasePart") then
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

function BlockModule.PlaceBlock(BlockTypeName, BlockCFrame)
    local NearbyBlock = FindNearbyBlock(BlockCFrame)
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
    DeleteEvent:FireServer(Block)
end

function BlockModule.PaintBlock(Block, Color, EnumMaterial)
    local Args = {
        [1] = Block,
        [2] = "Paint",
        [3] = Color,
        [4] = EnumMaterial
    }
    DeleteEvent:FireServer(unpack(Args))
end

function BlockModule.Resize(Block, ResizeVector, ShrinkOrGrow)
    if ShrinkOrGrow ~= "Shrink" and ShrinkOrGrow ~= "Grow" then return end
    
    local Args = {
        [1] = Block,
        [2] = "Resize",
        [3] = ResizeVector,
        [4] = ShrinkOrGrow
    }
    DeleteEvent:FireServer(unpack(Args))
end

return BlockModule
