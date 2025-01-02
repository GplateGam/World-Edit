local BlockModule = loadstring(game:HttpGet("https://raw.githubusercontent.com/GplateGam/World-Edit-Elected-Admin/refs/heads/main/BlockModule.Lua"))()
local CFrameUtilities = loadstring(game:HttpGet("https://raw.githubusercontent.com/GplateGam/World-Edit-Elected-Admin/refs/heads/main/CFrameUtilities.Lua"))()

local PlaceBlockDelayTime = 0.07
local RemoveBlockDelayTime = 0.03

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local BlockSize = Vector3.new(3, 3, 3)
local CurrentBlockType = "Block"
local ToolEquipped = false
local DisplayPart = nil
local LastClickCFrame = nil
local Tool = nil

local SetFirstCFrame = nil
local SetSecondCFrame = nil

local function CreateDisplayPart()
    if DisplayPart then
        DisplayPart:Destroy()
        DisplayPart = nil
    end

    DisplayPart = Instance.new("Part")
    DisplayPart.Anchored = true
    DisplayPart.BottomSurface = Enum.SurfaceType.Smooth
    DisplayPart.CFrame = CFrame.new(0, 0, 0)
    DisplayPart.Size = Vector3.new(BlockSize.X, 0.01, BlockSize.Z)
    DisplayPart.TopSurface = Enum.SurfaceType.Smooth
    DisplayPart.Transparency = 1
    DisplayPart.CanCollide = false
    DisplayPart.CanQuery = false

    local SelectionBox = Instance.new("SelectionBox")
    SelectionBox.LineThickness = 0.03
    SelectionBox.SurfaceColor3 = Color3.fromRGB(0, 0, 0)
    SelectionBox.Color3 = Color3.fromRGB(0, 0, 0)
    SelectionBox.Adornee = DisplayPart

    DisplayPart.Parent = Workspace
    SelectionBox.Parent = DisplayPart
end

local function FillArea(FirstCFrame, SecondCFrame, BlockName, Grid)
    for _, Position in pairs(CFrameUtilities.GetPositions(Grid, FirstCFrame, SecondCFrame)) do
        BlockModule.PlaceBlock(BlockName, CFrame.new(Position))
        task.wait(PlaceBlockDelayTime)
    end
end

local function DeleteArea(FirstCFrame, SecondCFrame)
    for _, Block in pairs(CFrameUtilities.GetBlocks(FirstCFrame, SecondCFrame)) do
        BlockModule.DeleteBlock(Block)
        task.wait(RemoveBlockDelayTime)
    end
end

local function HandleClick()
    if not ToolEquipped then return end

    local RaycastResult = CFrameUtilities.CastRay()

    if RaycastResult then
        local HitPos = RaycastResult.Position + RaycastResult.Normal * (BlockSize / 2)
        LastClickCFrame = CFrame.new(CFrameUtilities.RoundToGrid(HitPos, BlockSize))
        StarterGui:SetCore("SendNotification", {
            Title = "Position Selected",
            Text = "Use /set 1 or /set 2 to set this position",
            Duration = 3
        })
    else
        StarterGui:SetCore("SendNotification", {
            Title = "Error",
            Text = "No valid position found! Click on a block or terrain.",
            Duration = 3
        })
    end
end

-- Chat Commands
local ChatCommands = {
    [1] = {
        CommandName = "SetBlockType",
        ShortCuts = {"SetType", "Type", "SetBlock"},
        CommandArgs = {"String"},
        CommandFunction = function(BlockName)
            if BlockName then
                local Block = ReplicatedStorage.Blocks:FindFirstChild(BlockName)

                if Block then
                    CurrentBlockType = BlockName
                    BlockSize = Block.Size
                    if DisplayPart then
                        DisplayPart:Destroy()
                        DisplayPart = nil
                    end
                    CreateDisplayPart()

                    StarterGui:SetCore("SendNotification", {
                        Title = "Success",
                        Text = "Block type set to: " .. BlockName,
                        Duration = 3
                    })
                else
                    StarterGui:SetCore("SendNotification", {
                        Title = "Error",
                        Text = "Block type not found: " .. BlockName,
                        Duration = 3
                    })
                end
            else
                StarterGui:SetCore("SendNotification", {
                    Title = "Error",
                    Text = "Please specify a block type",
                    Duration = 3
                })
            end
        end
    },
    [2] = {
        CommandName = "Fill",
        ShortCuts = {},
        CommandArgs = {},
        CommandFunction = function()
            if SetFirstCFrame and SetSecondCFrame then
                FillArea(SetFirstCFrame, SetSecondCFrame, CurrentBlockType, BlockSize)
                StarterGui:SetCore("SendNotification", {
                    Title = "Success",
                    Text = "Area filled successfully!",
                    Duration = 3
                })
            else
                StarterGui:SetCore("SendNotification", {
                    Title = "Error",
                    Text = "Please set both positions first using /set 1 and /set 2",
                    Duration = 3
                })
            end
        end
    },
    [3] = {
        CommandName = "Remove",
        ShortCuts = {"Delete", "Destroy"},
        CommandArgs = {},
        CommandFunction = function()
            if SetFirstCFrame and SetSecondCFrame then
                DeleteArea(SetFirstCFrame, SetSecondCFrame)
                StarterGui:SetCore("SendNotification", {
                    Title = "Success",
                    Text = "Area deleted successfully!",
                    Duration = 3
                })
            else
                StarterGui:SetCore("SendNotification", {
                    Title = "Error",
                    Text = "Please set both positions first using /set 1 and /set 2",
                    Duration = 3
                })
            end
        end
    },
    [4] = {
        CommandName = "Set",
        ShortCuts = {"SetArea"},
        CommandArgs = {"Number"},
        CommandFunction = function(Number)
            if Number then
                if LastClickCFrame then
                    if Number == 1 then
                        SetFirstCFrame = LastClickCFrame
                        StarterGui:SetCore("SendNotification", {
                            Title = "Success",
                            Text = "Position 1 set successfully!",
                            Duration = 3
                        })
                    elseif Number == 2 then
                        SetSecondCFrame = LastClickCFrame
                        StarterGui:SetCore("SendNotification", {
                            Title = "Success",
                            Text = "Position 2 set successfully!",
                            Duration = 3
                        })
                    end
                else
                    StarterGui:SetCore("SendNotification", {
                        Title = "Error",
                        Text = "Please click a position first!",
                        Duration = 3
                    })
                end
            end
        end
    }
}

local function Trim(str)
	return string.match(str, "^%s*(.-)%s*$")
end

local function HandleChat(Message)
	if not Tool or not ToolEquipped then 
		return 
	end

	if string.sub(Message, 1, 1) == "/" then
		local Command = string.sub(Message, 2, -1)
		Command = string.gsub(Command, "%s+", " ")
		Command = Trim(Command)
		local CommandName = string.split(Command, " ")[1]
		local CommandArgs = string.split(Command, " ")
		table.remove(CommandArgs, 1)

		for _, CommandData in pairs(ChatCommands) do
			local CommandMatches = string.lower(CommandName) == string.lower(CommandData.CommandName)

			if not CommandMatches then
				for _, Shortcut in ipairs(CommandData.ShortCuts) do
					if string.lower(CommandName) == string.lower(Shortcut) then
						CommandMatches = true
						break
					end
				end
			end

			if CommandMatches then
				if #CommandData.CommandArgs > #CommandArgs then
					StarterGui:SetCore("SendNotification", {
						Title = "Error",
						Text = "Missing arguments for command: " .. CommandData.CommandName,
						Duration = 3
					})
					return
				end

				for i, argType in ipairs(CommandData.CommandArgs) do
					if argType == "Number" then
						local num = tonumber(CommandArgs[i])
						if not num then
							StarterGui:SetCore("SendNotification", {
								Title = "Error", 
								Text = "Argument " .. i .. " must be a number",
								Duration = 3
							})
							return
						end
						CommandArgs[i] = num
					elseif argType == "String" then
						local remainingArgs = {}
						for j = i, #CommandArgs do
							table.insert(remainingArgs, CommandArgs[j])
						end
						CommandArgs = {table.concat(remainingArgs, " ")}
						break
					end
				end

				CommandData.CommandFunction(unpack(CommandArgs))
				return
			end
		end

		StarterGui:SetCore("SendNotification", {
			Title = "Error",
			Text = "Unknown command: " .. CommandName,
			Duration = 3
		})
	end
end

Tool = Instance.new("Tool")
Tool.Parent = LocalPlayer:WaitForChild("Backpack", 2)
Tool.RequiresHandle = false
Tool.Name = "World Edit"

Tool.Activated:Connect(HandleClick)

StarterGui:SetCore("SendNotification", {
	Title = "World Edit",
	Text = "Tool Loaded!",
	Duration = 2
})

TextChatService.TextChannels.RBXGeneral.MessageReceived:Connect(function(MessageObject)
	if MessageObject.TextSource and MessageObject.TextSource.UserId and MessageObject.TextSource.UserId == LocalPlayer.UserId then
		HandleChat(MessageObject.Text)
	end
end)

Tool.Equipped:Connect(function()
	if not DisplayPart then
		CreateDisplayPart()
	end
	ToolEquipped = true
end)

Tool.Unequipped:Connect(function()
	if DisplayPart then
		DisplayPart:Destroy()
		DisplayPart = nil
	end
	ToolEquipped = false
end)

Tool.Destroying:Connect(function()
	if DisplayPart then
		DisplayPart:Destroy()
		DisplayPart = nil
	end
	ToolEquipped = false
end)

RunService.Heartbeat:Connect(function()
	if not DisplayPart then return end

	local RaycastResult = CFrameUtilities.CastRay()

	if RaycastResult then
		local HitPos = RaycastResult.Position + RaycastResult.Normal * (BlockSize / 2)
		local PosGrid = CFrameUtilities.RoundToGrid(HitPos ,BlockSize)
		local FinalPos = PosGrid - RaycastResult.Normal * (BlockSize / 2)
		DisplayPart.CFrame = CFrame.new(FinalPos, FinalPos + RaycastResult.Normal) * CFrame.Angles(0, math.rad(90), math.rad(90))
	end
end)
