--!strict
-- The brainrot creatures you rescue (one at the end of every stage). Each one earns
-- coins every second and can follow you around as a pet. All of them are original
-- characters built from plain parts, so no uploaded meshes are needed.
-- Shared so the server (pedestals) and clients (pets) can both build them.

local Brainrots = {}

export type Info = {
	id: string,
	name: string,
	rarity: string,
	income: number, -- coins per second
	stage: number, -- rescued at the end of this stage
}

Brainrots.List = {
	{ id = "Toastino", name = "Toastino Turbo", rarity = "Common", income = 1, stage = 1 },
	{ id = "Cappuccacto", name = "Cappuccacto", rarity = "Common", income = 2, stage = 2 },
	{ id = "Bingus", name = "Bingus Bongus", rarity = "Uncommon", income = 4, stage = 3 },
	{ id = "Pickleton", name = "Sir Pickleton", rarity = "Uncommon", income = 6, stage = 4 },
	{ id = "BananaBandit", name = "Banana Bandit", rarity = "Rare", income = 10, stage = 5 },
	{ id = "Fridgeman", name = "Froggo Fridgeman", rarity = "Rare", income = 15, stage = 6 },
	{ id = "Croissant", name = "Cloudy Croissant", rarity = "Epic", income = 25, stage = 7 },
	{ id = "DuckDynamo", name = "Duck Dynamo", rarity = "Epic", income = 40, stage = 8 },
	{ id = "SneakySock", name = "Sneaky Sock", rarity = "Legendary", income = 60, stage = 9 },
	{ id = "PizzaPharaoh", name = "Pizza Pharaoh", rarity = "Mythic", income = 100, stage = 10 },
} :: { Info }

Brainrots.RarityColors = {
	Common = Color3.fromRGB(200, 200, 200),
	Uncommon = Color3.fromRGB(90, 220, 110),
	Rare = Color3.fromRGB(70, 150, 255),
	Epic = Color3.fromRGB(190, 90, 255),
	Legendary = Color3.fromRGB(255, 170, 40),
	Mythic = Color3.fromRGB(255, 70, 140),
} :: { [string]: Color3 }

function Brainrots.get(id: string): Info?
	for _, info in Brainrots.List do
		if info.id == id then
			return info
		end
	end
	return nil
end

function Brainrots.forStage(stage: number): Info?
	for _, info in Brainrots.List do
		if info.stage == stage then
			return info
		end
	end
	return nil
end

-- ------------------------------------------------------------------ models

type Spec = {
	s: string, -- "ball" | "block" | "vcyl" (vertical cylinder, size = (diameter, height, diameter)) | "wedge"
	size: Vector3,
	pos: Vector3,
	color: Color3,
	mat: Enum.Material?,
	rot: Vector3?, -- degrees
	alpha: number?,
}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.fromRGB(20, 20, 20)
local DARK = Color3.fromRGB(70, 30, 30)

local function eyes(list: { Spec }, x: number, y: number, z: number, size: number)
	for _, side in { -1, 1 } do
		table.insert(list, { s = "ball", size = Vector3.one * size, pos = Vector3.new(side * x, y, z), color = WHITE })
		table.insert(list, { s = "ball", size = Vector3.one * size * 0.5, pos = Vector3.new(side * x, y, z - size * 0.35), color = BLACK })
	end
end

local SPECS: { [string]: () -> { Spec } } = {
	Toastino = function()
		local l: { Spec } = {
			{ s = "block", size = Vector3.new(4, 4.4, 1.2), pos = Vector3.new(0, 0.5, 0), color = Color3.fromRGB(190, 130, 60) },
			{ s = "block", size = Vector3.new(3.4, 3.8, 0.2), pos = Vector3.new(0, 0.5, -0.62), color = Color3.fromRGB(245, 215, 150) },
			{ s = "block", size = Vector3.new(1.2, 0.25, 0.1), pos = Vector3.new(0, -0.3, -0.75), color = DARK },
			{ s = "block", size = Vector3.new(1.1, 0.25, 0.9), pos = Vector3.new(0, 2.85, 0), color = Color3.fromRGB(255, 230, 90) },
		}
		for _, x in { -0.9, 0.9 } do
			table.insert(l, { s = "block", size = Vector3.new(0.45, 1.4, 0.45), pos = Vector3.new(x, -2.4, 0), color = BLACK })
			table.insert(l, { s = "block", size = Vector3.new(1, 0.6, 1.5), pos = Vector3.new(x, -3.2, -0.2), color = Color3.fromRGB(230, 40, 40) })
		end
		eyes(l, 0.8, 1.2, -0.75, 1)
		return l
	end,
	Cappuccacto = function()
		local green = Color3.fromRGB(70, 170, 80)
		local l: { Spec } = {
			{ s = "vcyl", size = Vector3.new(3.2, 3, 3.2), pos = Vector3.new(0, -1.5, 0), color = WHITE, mat = Enum.Material.Marble },
			{ s = "vcyl", size = Vector3.new(2.9, 0.2, 2.9), pos = Vector3.new(0, 0.05, 0), color = Color3.fromRGB(110, 70, 40) },
			{ s = "block", size = Vector3.new(0.5, 1.6, 0.5), pos = Vector3.new(1.9, -1.4, 0), color = WHITE },
			{ s = "vcyl", size = Vector3.new(1.7, 3.4, 1.7), pos = Vector3.new(0, 1.5, 0), color = green },
			{ s = "ball", size = Vector3.one * 0.7, pos = Vector3.new(0, 3.4, 0), color = Color3.fromRGB(255, 110, 180) },
		}
		for _, side in { -1, 1 } do
			table.insert(l, { s = "block", size = Vector3.new(1, 0.6, 0.6), pos = Vector3.new(side * 0.9, 1.4, 0), color = green })
			table.insert(l, { s = "vcyl", size = Vector3.new(0.8, 1.4, 0.8), pos = Vector3.new(side * 1.4, 2, 0), color = green })
		end
		eyes(l, 0.35, 2.4, -0.85, 0.6)
		return l
	end,
	Bingus = function()
		local l: { Spec } = {
			{ s = "ball", size = Vector3.one * 4.5, pos = Vector3.zero, color = Color3.fromRGB(170, 90, 255), mat = Enum.Material.Glass, alpha = 0.2 },
			{ s = "block", size = Vector3.new(3, 0.8, 0.3), pos = Vector3.new(0, 0.6, -2.05), color = BLACK },
			{ s = "block", size = Vector3.new(1.4, 0.3, 0.2), pos = Vector3.new(0, -0.8, -2.1), color = Color3.fromRGB(200, 60, 120) },
			{ s = "vcyl", size = Vector3.new(0.2, 1.2, 0.2), pos = Vector3.new(0, 2.6, 0), color = BLACK },
			{ s = "ball", size = Vector3.one * 0.6, pos = Vector3.new(0, 3.3, 0), color = Color3.fromRGB(255, 230, 60), mat = Enum.Material.Neon },
		}
		return l
	end,
	Pickleton = function()
		local l: { Spec } = {
			{ s = "vcyl", size = Vector3.new(2.4, 5, 2.4), pos = Vector3.zero, color = Color3.fromRGB(90, 160, 60) },
			{ s = "vcyl", size = Vector3.new(3, 0.2, 3), pos = Vector3.new(0, 2.55, 0), color = BLACK },
			{ s = "vcyl", size = Vector3.new(2, 1.8, 2), pos = Vector3.new(0, 3.4, 0), color = BLACK },
			{ s = "ball", size = Vector3.one * 0.9, pos = Vector3.new(0.5, 1, -1.45), color = Color3.fromRGB(255, 210, 80), mat = Enum.Material.Glass, alpha = 0.3 },
			{ s = "block", size = Vector3.new(1.6, 0.3, 0.2), pos = Vector3.new(0, 0.2, -1.25), color = Color3.fromRGB(90, 60, 30) },
		}
		for _, p in { Vector3.new(1.1, -1, -0.3), Vector3.new(-1.1, -1.6, 0.4), Vector3.new(0.9, 1.6, 0.6) } do
			table.insert(l, { s = "ball", size = Vector3.one * 0.6, pos = p, color = Color3.fromRGB(60, 120, 40) })
		end
		eyes(l, 0.5, 1, -1.15, 0.7)
		return l
	end,
	BananaBandit = function()
		local yellow = Color3.fromRGB(255, 220, 60)
		local l: { Spec } = {
			{ s = "ball", size = Vector3.one * 0.6, pos = Vector3.new(0, 3, 1.1), color = Color3.fromRGB(110, 80, 40) },
			{ s = "block", size = Vector3.new(1.9, 0.5, 0.3), pos = Vector3.new(0, 0.6, -0.85), color = BLACK },
			{ s = "block", size = Vector3.new(2.4, 3, 0.2), pos = Vector3.new(0, 0, 1.1), color = Color3.fromRGB(210, 40, 40), mat = Enum.Material.Fabric },
		}
		for _, p in { Vector3.new(0, -1.8, 0.6), Vector3.new(0, -0.8, 0.2), Vector3.new(0, 0.3, 0), Vector3.new(0, 1.4, 0.2), Vector3.new(0, 2.3, 0.7) } do
			table.insert(l, { s = "ball", size = Vector3.one * 1.6, pos = p, color = yellow })
		end
		for _, side in { -1, 1 } do
			table.insert(l, { s = "ball", size = Vector3.one * 0.45, pos = Vector3.new(side * 0.4, 0.6, -1.02), color = WHITE })
		end
		return l
	end,
	Fridgeman = function()
		local l: { Spec } = {
			{ s = "block", size = Vector3.new(3, 4.4, 2.4), pos = Vector3.new(0, -0.6, 0), color = Color3.fromRGB(240, 245, 250) },
			{ s = "block", size = Vector3.new(3.05, 0.1, 2.45), pos = Vector3.new(0, 0.4, 0), color = Color3.fromRGB(150, 150, 160) },
			{ s = "block", size = Vector3.new(0.2, 1.2, 0.3), pos = Vector3.new(1.1, 1.2, -1.3), color = Color3.fromRGB(150, 150, 160) },
			{ s = "ball", size = Vector3.one * 3, pos = Vector3.new(0, 2.6, 0), color = Color3.fromRGB(90, 200, 90) },
			{ s = "block", size = Vector3.new(1.8, 0.2, 0.2), pos = Vector3.new(0, 2.2, -1.45), color = DARK },
		}
		eyes(l, 0.8, 3.7, -0.8, 1.1)
		return l
	end,
	Croissant = function()
		local tan = Color3.fromRGB(230, 170, 90)
		local l: { Spec } = {
			{ s = "ball", size = Vector3.one * 2.4, pos = Vector3.zero, color = tan },
		}
		for _, side in { -1, 1 } do
			table.insert(l, { s = "ball", size = Vector3.one * 1.8, pos = Vector3.new(side * 1.6, -0.4, 0), color = tan })
			table.insert(l, { s = "ball", size = Vector3.one * 1.2, pos = Vector3.new(side * 2.6, -0.9, 0), color = tan })
			table.insert(l, { s = "wedge", size = Vector3.new(0.3, 1.6, 2.2), pos = Vector3.new(side * 1.2, 1.4, 0.8), color = WHITE, rot = Vector3.new(0, 0, side * -30) })
		end
		eyes(l, 0.5, 0.4, -1.1, 0.6)
		return l
	end,
	DuckDynamo = function()
		local yellow = Color3.fromRGB(255, 225, 50)
		local l: { Spec } = {
			{ s = "ball", size = Vector3.one * 3.6, pos = Vector3.new(0, -0.8, 0.3), color = yellow },
			{ s = "ball", size = Vector3.one * 2.4, pos = Vector3.new(0, 1.4, -0.5), color = yellow },
			{ s = "block", size = Vector3.new(1.3, 0.5, 0.9), pos = Vector3.new(0, 1.2, -1.9), color = Color3.fromRGB(255, 140, 30) },
			{ s = "wedge", size = Vector3.new(0.2, 1.6, 0.8), pos = Vector3.new(1.8, -0.6, 0.3), color = Color3.fromRGB(80, 220, 255), mat = Enum.Material.Neon, rot = Vector3.new(0, 0, 20) },
			{ s = "wedge", size = Vector3.new(0.2, 1.6, 0.8), pos = Vector3.new(-1.8, -0.6, 0.3), color = Color3.fromRGB(80, 220, 255), mat = Enum.Material.Neon, rot = Vector3.new(0, 0, -20) },
			{ s = "wedge", size = Vector3.new(1, 0.9, 1), pos = Vector3.new(0, -0.4, 2.2), color = yellow },
		}
		eyes(l, 0.55, 1.9, -1.55, 0.6)
		return l
	end,
	SneakySock = function()
		local l: { Spec } = {
			{ s = "ball", size = Vector3.one * 2.4, pos = Vector3.new(0, -2.2, -0.6), color = Color3.fromRGB(220, 50, 50) },
			{ s = "block", size = Vector3.new(1.4, 0.3, 0.2), pos = Vector3.new(0, 1.2, -1.15), color = BLACK },
			{ s = "block", size = Vector3.new(0.8, 0.2, 0.8), pos = Vector3.new(0, 1, -1.35), color = Color3.fromRGB(255, 120, 150) },
		}
		for i, y in { -1.2, -0.4, 0.4, 1.2, 2 } do
			table.insert(l, {
				s = "vcyl",
				size = Vector3.new(2.2, 0.8, 2.2),
				pos = Vector3.new(0, y, 0),
				color = if i % 2 == 1 then Color3.fromRGB(220, 50, 50) else WHITE,
				mat = Enum.Material.Fabric,
			})
		end
		eyes(l, 0.5, 1.9, -1.1, 0.8)
		return l
	end,
	PizzaPharaoh = function()
		local gold = Color3.fromRGB(255, 200, 50)
		local blue = Color3.fromRGB(40, 70, 200)
		local l: { Spec } = {
			{ s = "block", size = Vector3.new(2.8, 4, 0.6), pos = Vector3.zero, color = Color3.fromRGB(255, 210, 90) },
			{ s = "block", size = Vector3.new(3.2, 0.7, 0.8), pos = Vector3.new(0, 2.2, 0), color = Color3.fromRGB(190, 120, 50) },
			{ s = "block", size = Vector3.new(3.4, 1.6, 1.2), pos = Vector3.new(0, 3.3, 0), color = gold, mat = Enum.Material.Foil },
			{ s = "block", size = Vector3.new(3.45, 0.3, 1.25), pos = Vector3.new(0, 3, 0), color = blue },
			{ s = "block", size = Vector3.new(3.45, 0.3, 1.25), pos = Vector3.new(0, 3.6, 0), color = blue },
			{ s = "block", size = Vector3.new(0.5, 1, 0.3), pos = Vector3.new(0, -2.3, -0.35), color = gold },
		}
		for _, p in { Vector3.new(-0.7, -0.5, -0.35), Vector3.new(0.8, 0.1, -0.35), Vector3.new(-0.2, -1.4, -0.35) } do
			table.insert(l, { s = "ball", size = Vector3.one * 0.8, pos = p, color = Color3.fromRGB(200, 40, 40) })
		end
		eyes(l, 0.6, 1.2, -0.4, 0.7)
		return l
	end,
}

-- Builds a brainrot facing -Z. Root is anchored; everything else is welded to it.
function Brainrots.build(id: string, scale: number): Model
	local model = Instance.new("Model")
	model.Name = id
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

	local builder = SPECS[id]
	if not builder then
		return model
	end
	for _, spec in builder() do
		local part: BasePart
		local rot = spec.rot or Vector3.zero
		local extra = CFrame.identity
		if spec.s == "wedge" then
			part = Instance.new("WedgePart")
			part.Size = spec.size * scale
		else
			local p = Instance.new("Part")
			if spec.s == "ball" then
				p.Shape = Enum.PartType.Ball
				p.Size = spec.size * scale
			elseif spec.s == "vcyl" then
				p.Shape = Enum.PartType.Cylinder
				p.Size = Vector3.new(spec.size.Y, spec.size.X, spec.size.Z) * scale
				extra = CFrame.Angles(0, 0, math.pi / 2)
			else
				p.Size = spec.size * scale
			end
			part = p
		end
		part.Color = spec.color
		part.Material = spec.mat or Enum.Material.SmoothPlastic
		part.Transparency = spec.alpha or 0
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Anchored = false
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CastShadow = scale >= 0.8
		part.CFrame = CFrame.new(spec.pos * scale) * CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z)) * extra
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
	end
	return model
end

return Brainrots
