--!strict
-- Builds a donut out of plain parts (no uploaded meshes needed).
-- The donut stands upright like a face: the hole is its mouth, with eyes on top.
-- Every part is welded to an invisible "Root" part; move the Root to move the donut.

local DonutModel = {}

local BASE_RING_RADIUS = 3.6 -- distance from donut center to the middle of the dough
local BASE_TUBE_RADIUS = 2.1 -- thickness of the dough

local DOUGH = Color3.fromRGB(214, 160, 90)
local FROSTINGS = {
	Color3.fromRGB(255, 140, 190), -- strawberry
	Color3.fromRGB(110, 66, 38), -- chocolate
	Color3.fromRGB(250, 244, 232), -- vanilla
}
local SPRINKLE_COLORS = {
	Color3.fromRGB(255, 70, 70),
	Color3.fromRGB(70, 160, 255),
	Color3.fromRGB(255, 230, 60),
	Color3.fromRGB(90, 220, 110),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(190, 90, 255),
}

function DonutModel.dimensions(scale: number): (number, number)
	return BASE_RING_RADIUS * scale, BASE_TUBE_RADIUS * scale
end

-- Height of the donut's center above the floor when it sits on the ground.
function DonutModel.centerHeight(scale: number): number
	local R, r = DonutModel.dimensions(scale)
	return R + r
end

function DonutModel.build(scale: number, frosting: Color3?, rng: Random?): Model
	local random = rng or Random.new()
	local R, r = DonutModel.dimensions(scale)
	local frostingColor = frosting or FROSTINGS[random:NextInteger(1, #FROSTINGS)]

	local model = Instance.new("Model")
	model.Name = "Donut"

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 1, 1)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = CFrame.identity
	root.Parent = model
	model.PrimaryPart = root

	local function attach(part: BasePart, offset: CFrame)
		part.Anchored = false
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CastShadow = scale >= 0.6
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CFrame = root.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
	end

	local function ball(diameter: number, color: Color3, material: Enum.Material?): Part
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.one * diameter
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		return p
	end

	-- Ring of dough, with a slightly smaller ring of frosting pushed toward the front (-Z).
	local segments = if scale < 0.6 then 10 else 16
	for i = 1, segments do
		local a = (i / segments) * math.pi * 2
		local x, y = math.cos(a) * R, math.sin(a) * R
		local dough = ball(r * 2, DOUGH)
		dough.Name = "Dough"
		attach(dough, CFrame.new(x, y, 0))
		local icing = ball(r * 1.84, frostingColor)
		icing.Name = "Frosting"
		attach(icing, CFrame.new(x, y, -r * 0.28))
	end

	-- Sprinkles on the frosting.
	local sprinkleCount = math.floor(28 * math.clamp(scale, 0.35, 1))
	local frontSurfaceRadius = r * 0.92
	for _ = 1, sprinkleCount do
		local a = random:NextNumber(0, math.pi * 2)
		local u = random:NextNumber(-0.65, 0.65) * frontSurfaceRadius
		local z = -r * 0.28 - math.sqrt(math.max(frontSurfaceRadius ^ 2 - u ^ 2, 0)) + 0.05 * scale
		local s = Instance.new("Part")
		s.Name = "Sprinkle"
		s.Size = Vector3.new(0.18, 0.18, 0.7) * math.max(scale, 0.5)
		s.Color = SPRINKLE_COLORS[random:NextInteger(1, #SPRINKLE_COLORS)]
		s.Material = Enum.Material.SmoothPlastic
		local tilt = CFrame.Angles(random:NextNumber(-0.4, 0.4), random:NextNumber(0, math.pi * 2), 0)
		attach(s, CFrame.new((R + u) * math.cos(a), (R + u) * math.sin(a), z) * tilt)
	end

	-- Eyes on the top of the ring, looking forward.
	for _, angle in { math.rad(58), math.rad(122) } do
		local ex, ey = math.cos(angle) * R, math.sin(angle) * R
		local eye = ball(r * 1.05, Color3.new(1, 1, 1))
		eye.Name = "Eye"
		attach(eye, CFrame.new(ex, ey, -r * 1.05))
		local pupil = ball(r * 0.5, Color3.new(0.05, 0.05, 0.05))
		pupil.Name = "Pupil"
		attach(pupil, CFrame.new(ex * 0.97, ey * 0.95, -r * 1.5))
		-- Angry eyebrow, slanted toward the middle.
		local brow = Instance.new("Part")
		brow.Name = "Brow"
		brow.Size = Vector3.new(r * 1.1, r * 0.22, r * 0.25)
		brow.Color = Color3.new(0.1, 0.06, 0.04)
		brow.Material = Enum.Material.SmoothPlastic
		local slant = if ex > 0 then 0.45 else -0.45
		attach(brow, CFrame.new(ex, ey + r * 0.65, -r * 1.35) * CFrame.Angles(0, 0, slant))
	end

	-- Teeth along the bottom of the hole (the mouth).
	local innerRadius = R - r * 0.85
	for i = 0, 5 do
		local a = math.rad(235 + i * 14)
		local tooth = Instance.new("WedgePart")
		tooth.Name = "Tooth"
		tooth.Size = Vector3.new(r * 0.3, r * 0.55, r * 0.3)
		tooth.Color = Color3.new(1, 1, 1)
		tooth.Material = Enum.Material.SmoothPlastic
		attach(tooth, CFrame.new(math.cos(a) * innerRadius, math.sin(a) * innerRadius + r * 0.2, -r * 0.4))
	end

	return model
end

return DonutModel
