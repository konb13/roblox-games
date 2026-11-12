--!strict
-- Builds a chubby cartoon squirrel out of plain parts (no uploaded meshes needed).
-- Faces local -Z. Every part is welded to an invisible "Root" at the body's centre.

local SquirrelModel = {}

local FUR = Color3.fromRGB(165, 98, 52)
local TAIL = Color3.fromRGB(190, 120, 65)
local CREAM = Color3.fromRGB(245, 225, 195)
local BLACK = Color3.fromRGB(20, 15, 15)
local GOLD = Color3.fromRGB(255, 190, 40)

-- Distance from the root (body centre) down to the bottom of the feet, at scale 1.
local FEET_DEPTH = 5.75

function SquirrelModel.centerHeight(scale: number): number
	return FEET_DEPTH * scale
end

type PartSpec = {
	name: string,
	shape: string, -- "ball" | "block" | "wedge"
	size: Vector3,
	pos: Vector3,
	color: Color3,
	rot: Vector3?, -- degrees
	material: Enum.Material?,
}

local SPECS: { PartSpec } = {
	-- Body
	{ name = "Body", shape = "ball", size = Vector3.one * 10, pos = Vector3.new(0, 0, 0), color = FUR },
	{ name = "Chest", shape = "ball", size = Vector3.one * 8, pos = Vector3.new(0, 3.2, -1.6), color = FUR },
	{ name = "Belly", shape = "ball", size = Vector3.one * 7, pos = Vector3.new(0, 1.2, -2.6), color = CREAM },
	-- Head
	{ name = "Head", shape = "ball", size = Vector3.one * 7, pos = Vector3.new(0, 8, -3.6), color = FUR },
	{ name = "Cheek", shape = "ball", size = Vector3.one * 3.2, pos = Vector3.new(2.2, 7, -6), color = CREAM },
	{ name = "Cheek", shape = "ball", size = Vector3.one * 3.2, pos = Vector3.new(-2.2, 7, -6), color = CREAM },
	{ name = "Ear", shape = "wedge", size = Vector3.new(1, 3, 2), pos = Vector3.new(2.4, 11.8, -3.4), color = FUR, rot = Vector3.new(0, 0, -15) },
	{ name = "Ear", shape = "wedge", size = Vector3.new(1, 3, 2), pos = Vector3.new(-2.4, 11.8, -3.4), color = FUR, rot = Vector3.new(0, 0, 15) },
	{ name = "Eye", shape = "ball", size = Vector3.one * 1.7, pos = Vector3.new(1.5, 9, -6.6), color = BLACK },
	{ name = "Eye", shape = "ball", size = Vector3.one * 1.7, pos = Vector3.new(-1.5, 9, -6.6), color = BLACK },
	{ name = "Shine", shape = "ball", size = Vector3.one * 0.55, pos = Vector3.new(1.3, 9.4, -7.4), color = Color3.new(1, 1, 1) },
	{ name = "Shine", shape = "ball", size = Vector3.one * 0.55, pos = Vector3.new(-1.7, 9.4, -7.4), color = Color3.new(1, 1, 1) },
	{ name = "Brow", shape = "block", size = Vector3.new(1.8, 0.35, 0.4), pos = Vector3.new(1.6, 10.2, -6.8), color = BLACK, rot = Vector3.new(0, 0, 20) },
	{ name = "Brow", shape = "block", size = Vector3.new(1.8, 0.35, 0.4), pos = Vector3.new(-1.6, 10.2, -6.8), color = BLACK, rot = Vector3.new(0, 0, -20) },
	{ name = "Nose", shape = "ball", size = Vector3.one * 1.2, pos = Vector3.new(0, 7.8, -7.4), color = Color3.fromRGB(60, 30, 30) },
	{ name = "Tooth", shape = "block", size = Vector3.new(0.7, 1.3, 0.3), pos = Vector3.new(0.38, 6.3, -7.1), color = Color3.new(1, 1, 1) },
	{ name = "Tooth", shape = "block", size = Vector3.new(0.7, 1.3, 0.3), pos = Vector3.new(-0.38, 6.3, -7.1), color = Color3.new(1, 1, 1) },
	-- Paws holding a golden acorn
	{ name = "Paw", shape = "ball", size = Vector3.one * 2.4, pos = Vector3.new(1.6, 3, -5.6), color = FUR },
	{ name = "Paw", shape = "ball", size = Vector3.one * 2.4, pos = Vector3.new(-1.6, 3, -5.6), color = FUR },
	{ name = "Acorn", shape = "ball", size = Vector3.one * 2.2, pos = Vector3.new(0, 3.6, -6.4), color = GOLD, material = Enum.Material.Foil },
	-- Feet
	{ name = "Foot", shape = "ball", size = Vector3.one * 3.5, pos = Vector3.new(3, -4, -2.5), color = FUR },
	{ name = "Foot", shape = "ball", size = Vector3.one * 3.5, pos = Vector3.new(-3, -4, -2.5), color = FUR },
	-- Big bushy tail curling up behind
	{ name = "Tail", shape = "ball", size = Vector3.one * 5, pos = Vector3.new(0, -1.5, 5), color = TAIL, material = Enum.Material.Fabric },
	{ name = "Tail", shape = "ball", size = Vector3.one * 6.5, pos = Vector3.new(0, 2.5, 7.5), color = TAIL, material = Enum.Material.Fabric },
	{ name = "Tail", shape = "ball", size = Vector3.one * 7.5, pos = Vector3.new(0, 7.5, 8.5), color = TAIL, material = Enum.Material.Fabric },
	{ name = "Tail", shape = "ball", size = Vector3.one * 7, pos = Vector3.new(0, 12.5, 7.5), color = TAIL, material = Enum.Material.Fabric },
	{ name = "Tail", shape = "ball", size = Vector3.one * 5.5, pos = Vector3.new(0, 15.5, 4.5), color = CREAM, material = Enum.Material.Fabric },
}

function SquirrelModel.build(scale: number): Model
	local model = Instance.new("Model")
	model.Name = "Squirrel"

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.one
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = CFrame.identity
	root.Parent = model
	model.PrimaryPart = root

	for _, s in SPECS do
		local part: BasePart
		if s.shape == "wedge" then
			part = Instance.new("WedgePart")
		else
			local p = Instance.new("Part")
			if s.shape == "ball" then
				p.Shape = Enum.PartType.Ball
			end
			part = p
		end
		part.Name = s.name
		part.Size = s.size * scale
		part.Color = s.color
		part.Material = s.material or Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Anchored = false
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CastShadow = scale >= 0.5
		local rot = s.rot or Vector3.zero
		part.CFrame = CFrame.new(s.pos * scale) * CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
	end

	return model
end

return SquirrelModel
