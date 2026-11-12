--!strict
-- Small helpers for building anchored scenery from code.

local Players = game:GetService("Players")

local Parts = {}

export type PartProps = {
	Name: string?,
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3?,
	Material: Enum.Material?,
	Transparency: number?,
	CanCollide: boolean?,
	Shape: Enum.PartType?,
}

local function finish(p: BasePart, parent: Instance, props: PartProps)
	p.Name = props.Name or p.Name
	p.Anchored = true
	p.Size = props.Size
	p.CFrame = props.CFrame
	p.Color = props.Color or Color3.fromRGB(200, 200, 200)
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Transparency = props.Transparency or 0
	p.CanCollide = if props.CanCollide == nil then true else props.CanCollide
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
end

function Parts.block(parent: Instance, props: PartProps): Part
	local p = Instance.new("Part")
	if props.Shape then
		p.Shape = props.Shape
	end
	finish(p, parent, props)
	return p
end

function Parts.wedge(parent: Instance, props: PartProps): WedgePart
	local p = Instance.new("WedgePart")
	finish(p, parent, props)
	return p
end

-- A ramp that starts at ground level at `lowEnd` and rises along `direction`.
-- (A WedgePart's tall edge is on its +Z side, so we point +Z along the direction.)
function Parts.ramp(
	parent: Instance,
	lowEnd: Vector3,
	direction: Vector3,
	length: number,
	height: number,
	width: number,
	color: Color3?,
	material: Enum.Material?
): WedgePart
	local dir = Vector3.new(direction.X, 0, direction.Z).Unit
	local center = lowEnd + dir * (length / 2) + Vector3.new(0, height / 2, 0)
	return Parts.wedge(parent, {
		Name = "Ramp",
		Size = Vector3.new(width, height, length),
		CFrame = CFrame.lookAt(center, center - dir),
		Color = color or Color3.fromRGB(255, 170, 60),
		Material = material or Enum.Material.DiamondPlate,
	})
end

-- A floating name label above a part.
function Parts.billboard(adornee: BasePart, text: string, color: Color3, offsetY: number, maxDistance: number?): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(240, 50)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	gui.MaxDistance = maxDistance or 200
	gui.LightInfluence = 0
	gui.Adornee = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.Parent = gui
	gui.Parent = adornee
	return gui
end

-- Text printed on the front and back faces of a part (signs).
function Parts.sign(part: BasePart, text: string, textColor: Color3?)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.LightInfluence = 0.3
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextColor3 = textColor or Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.2
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.Parent = gui
		gui.Parent = part
	end
end

function Parts.playerFromHit(hit: BasePart): Player?
	local model = hit:FindFirstAncestorOfClass("Model")
	while model do
		local player = Players:GetPlayerFromCharacter(model)
		if player then
			return player
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

-- Welds `part` to `root` at `offset` (relative to root) and makes it a passenger part.
function Parts.weldTo(root: BasePart, part: BasePart, offset: CFrame, parent: Instance)
	part.Anchored = false
	part.Massless = true
	part.CFrame = root.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	part.Parent = parent
end

return Parts
