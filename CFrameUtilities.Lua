local CFrameUtilities = {}

function CFrameUtilities.GetPositions(Grid, StarterCFrame, EndCFrame)
    local StarterPosition, EndPosition = StarterCFrame.Position, EndCFrame.Position
    local MinimumPosition = Vector3.new(
        math.min(StarterPosition.X, EndPosition.X),
        math.min(StarterPosition.Y, EndPosition.Y),
        math.min(StarterPosition.Z, EndPosition.Z)
    )
    local MaximumPosition = Vector3.new(
        math.max(StarterPosition.X, EndPosition.X),
        math.max(StarterPosition.Y, EndPosition.Y),
        math.max(StarterPosition.Z, EndPosition.Z)
    )

    local Positions = {}

    for X = MinimumPosition.X, MaximumPosition.X, Grid.X do
        for Y = MinimumPosition.Y, MaximumPosition.Y, Grid.Y do
            for Z = MinimumPosition.Z, MaximumPosition.Z, Grid.Z do
                table.insert(Positions, Vector3.new(X, Y, Z))
                if Z % 100 == 50 then
                    task.wait()
                end
            end
            if Y % 100 == 50 then
                task.wait()
            end
        end
        if X % 100 == 50 then
            task.wait()
        end
    end

    return Positions
end

function CFrameUtilities.GetBlocks(StarterCFrame, EndCFrame)
    local StarterPosition, EndPosition = StarterCFrame.Position, EndCFrame.Position

    local MinimumPosition = Vector3.new(
        math.min(StarterPosition.X, EndPosition.X),
        math.min(StarterPosition.Y, EndPosition.Y),
        math.min(StarterPosition.Z, EndPosition.Z)
    )
    local MaximumPosition = Vector3.new(
        math.max(StarterPosition.X, EndPosition.X),
        math.max(StarterPosition.Y, EndPosition.Y),
        math.max(StarterPosition.Z, EndPosition.Z)
    )

    local BoxSize = MaximumPosition - MinimumPosition
    local BoxCFrame = CFrame.new((MinimumPosition + MaximumPosition) / 2)

    local OverlapParameters = OverlapParams.new()
    OverlapParameters.FilterType = Enum.RaycastFilterType.Include
    OverlapParameters.FilterDescendantsInstances = {game:GetService("Workspace").Blocks}

    local BoundingParts = workspace:GetPartBoundsInBox(BoxCFrame, Vector3.new(
        math.abs(BoxSize.X),
        math.abs(BoxSize.Y),
        math.abs(BoxSize.Z)
    ) - Vector3.new(0.2, 0.2, 0.2), OverlapParameters)

    local Blocks = {}
    for Index, Block in ipairs(BoundingParts) do
        if Block.Parent == game:GetService("Workspace").Blocks then
            table.insert(Blocks, Block)
        end
        if Index % 100 == 50 then
            task.wait()
        end
    end

    return Blocks
end

function CFrameUtilities.CastRay()
   local UserInputService = game:GetService("UserInputService")
   local Workspace = game:GetService("Workspace") 
   local Camera = Workspace.CurrentCamera
   local LocalPlayer = game:GetService("Players").LocalPlayer
   
   local RayParams = RaycastParams.new()
   local RayFilterDescendants = {}
   
   for _, Player in ipairs(game:GetService("Players"):GetPlayers()) do
       if Player.Character and Player.Character.Parent then
           table.insert(RayFilterDescendants, Player.Character)
       end
   end
   
   RayParams.FilterDescendantsInstances = RayFilterDescendants
   RayParams.FilterType = Enum.RaycastFilterType.Exclude
   
   local MouseLocation = UserInputService:GetMouseLocation()
   local Ray = Camera:ViewportPointToRay(MouseLocation.X, MouseLocation.Y)
   
   local Direction = Ray.Direction.Unit * 2048
   
   local RaycastResult = Workspace:Raycast(Ray.Origin, Direction, RayParams)
   
   if RaycastResult then
       return RaycastResult
   end
   
   return nil
end

function CFrameUtilities.RoundToGrid(Position, Grid)
	return Vector3.new(
		math.round(Position.X / Grid.X) * Grid.X,
		math.floor(Position.Y / Grid.Y) * Grid.Y + Grid.Y / 2,
		math.round(Position.Z / Grid.Z) * Grid.Z
	)
end

return CFrameUtilities
