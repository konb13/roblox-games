--!strict
-- Builds enterable buildings from a simple spec: walls with doors and windows on every
-- floor, floor slabs, stairs or a ladder, and a roof. Everything is built in the
-- building's local space (front wall faces local -Z) and placed with one CFrame.

local Parts = require(script.Parent.Parts)

local BuildingBuilder = {}

export type Opening = { c: number, w: number, b: number, t: number } -- centre, width, bottom, top
export type Rect = { minX: number, maxX: number, minZ: number, maxZ: number }

export type Spec = {
	name: string,
	label: string?,
	labelColor: Color3?,
	width: number, -- local X
	depth: number, -- local Z
	floors: number,
	floorHeight: number,
	wallColor: Color3,
	roofColor: Color3,
	wallMaterial: Enum.Material?,
	-- openings[floor] for each wall. Front/back centres are local X, left/right are local Z.
	front: { { Opening } }?,
	back: { { Opening } }?,
	left: { { Opening } }?,
	right: { { Opening } }?,
	stairs: boolean?, -- staircase along the back wall to floor 2
	ladder: boolean?, -- truss ladder to a walkable roof with railings
	acornSpots: { Vector3 }?, -- local positions
	decorate: ((model: Model, cf: CFrame) -> ())?,
}

export type Building = {
	name: string,
	model: Model,
	cframe: CFrame,
	rect: Rect,
	doors: { Vector3 }, -- points just outside each ground-floor door
	acornSpots: { Vector3 },
}

local T = 1 -- wall thickness
local FLOOR_WOOD = Color3.fromRGB(170, 120, 80)

local function wallBand(
	parent: Instance,
	cf: CFrame,
	alongX: boolean,
	fixed: number,
	a0: number,
	a1: number,
	y0: number,
	h: number,
	openings: { Opening },
	color: Color3,
	material: Enum.Material
)
	local sorted = table.clone(openings)
	table.sort(sorted, function(p, q)
		return p.c < q.c
	end)
	local function piece(from: number, to: number, yb: number, yt: number)
		local len, hh = to - from, yt - yb
		if len <= 0.05 or hh <= 0.05 then
			return
		end
		local mid = (from + to) / 2
		local size = if alongX then Vector3.new(len, hh, T) else Vector3.new(T, hh, len)
		local pos = if alongX then Vector3.new(mid, (yb + yt) / 2, fixed) else Vector3.new(fixed, (yb + yt) / 2, mid)
		Parts.block(parent, { Name = "Wall", Size = size, CFrame = cf * CFrame.new(pos), Color = color, Material = material })
	end
	local cursor = a0
	for _, o in sorted do
		local l, r = o.c - o.w / 2, o.c + o.w / 2
		piece(cursor, l, y0, y0 + h)
		piece(l, r, y0, y0 + o.b)
		piece(l, r, y0 + o.t, y0 + h)
		cursor = r
	end
	piece(cursor, a1, y0, y0 + h)
end

-- A horizontal slab from (x0, z0) to (x1, z1) with its top at `top`, optionally with a hole.
function BuildingBuilder.slab(
	parent: Instance,
	cf: CFrame,
	top: number,
	thickness: number,
	x0: number,
	x1: number,
	z0: number,
	z1: number,
	color: Color3,
	material: Enum.Material,
	hole: Rect?
)
	local function piece(ax: number, bx: number, az: number, bz: number)
		if bx - ax <= 0.05 or bz - az <= 0.05 then
			return
		end
		Parts.block(parent, {
			Name = "Slab",
			Size = Vector3.new(bx - ax, thickness, bz - az),
			CFrame = cf * CFrame.new((ax + bx) / 2, top - thickness / 2, (az + bz) / 2),
			Color = color,
			Material = material,
		})
	end
	if not hole then
		piece(x0, x1, z0, z1)
		return
	end
	piece(x0, x1, z0, hole.minZ) -- in front of the hole
	piece(x0, x1, hole.maxZ, z1) -- behind the hole
	piece(x0, hole.minX, hole.minZ, hole.maxZ) -- left of the hole
	piece(hole.maxX, x1, hole.minZ, hole.maxZ) -- right of the hole
end

local function worldRect(cf: CFrame, w: number, d: number): Rect
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, corner in { Vector3.new(-w / 2, 0, -d / 2), Vector3.new(w / 2, 0, -d / 2), Vector3.new(-w / 2, 0, d / 2), Vector3.new(w / 2, 0, d / 2) } do
		local p = cf:PointToWorldSpace(corner)
		minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
		minZ, maxZ = math.min(minZ, p.Z), math.max(maxZ, p.Z)
	end
	return { minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ }
end

function BuildingBuilder.build(parent: Instance, cf: CFrame, spec: Spec): Building
	local W, D, FH, floors = spec.width, spec.depth, spec.floorHeight, spec.floors
	local material = spec.wallMaterial or Enum.Material.Brick
	local model = Instance.new("Model")
	model.Name = spec.name
	local doors: { Vector3 } = {}

	local function openingsFor(list: { { Opening } }?, floor: number): { Opening }
		return if list and list[floor] then list[floor] else {}
	end

	for f = 1, floors do
		local y0 = (f - 1) * FH
		wallBand(model, cf, true, -D / 2, -W / 2 - T / 2, W / 2 + T / 2, y0, FH, openingsFor(spec.front, f), spec.wallColor, material)
		wallBand(model, cf, true, D / 2, -W / 2 - T / 2, W / 2 + T / 2, y0, FH, openingsFor(spec.back, f), spec.wallColor, material)
		wallBand(model, cf, false, -W / 2, -D / 2 + T / 2, D / 2 - T / 2, y0, FH, openingsFor(spec.left, f), spec.wallColor, material)
		wallBand(model, cf, false, W / 2, -D / 2 + T / 2, D / 2 - T / 2, y0, FH, openingsFor(spec.right, f), spec.wallColor, material)
	end

	-- Ground-floor doors (openings that start at the floor).
	local function addDoors(list: { { Opening } }?, toLocal: (c: number) -> Vector3)
		for _, o in openingsFor(list, 1) do
			if o.b <= 0 then
				table.insert(doors, cf:PointToWorldSpace(toLocal(o.c)))
			end
		end
	end
	addDoors(spec.front, function(c)
		return Vector3.new(c, 0, -D / 2 - 9)
	end)
	addDoors(spec.back, function(c)
		return Vector3.new(c, 0, D / 2 + 9)
	end)
	addDoors(spec.left, function(c)
		return Vector3.new(-W / 2 - 9, 0, c)
	end)
	addDoors(spec.right, function(c)
		return Vector3.new(W / 2 + 9, 0, c)
	end)

	-- Ground floor
	Parts.block(model, {
		Name = "Floor",
		Size = Vector3.new(W - T, 0.2, D - T),
		CFrame = cf * CFrame.new(0, 0.1, 0),
		Color = FLOOR_WOOD,
		Material = Enum.Material.WoodPlanks,
	})

	-- Stairs along the back wall, up to floor 2.
	local stairHole: Rect? = nil
	if spec.stairs and floors >= 2 then
		local run, rise, stairWidth = 1.4, 1, 6
		local zMax = D / 2 - T / 2
		local zMin = zMax - stairWidth
		local x0 = -W / 2 + T / 2 + 0.5
		local steps = math.floor(FH / rise)
		for i = 1, steps do
			Parts.block(model, {
				Name = "Step",
				Size = Vector3.new(run, i * rise, stairWidth),
				CFrame = cf * CFrame.new(x0 + (i - 0.5) * run, i * rise / 2, (zMin + zMax) / 2),
				Color = FLOOR_WOOD,
				Material = Enum.Material.Wood,
			})
		end
		stairHole = { minX = x0, maxX = x0 + steps * run, minZ = zMin, maxZ = zMax }
	end

	for f = 2, floors do
		BuildingBuilder.slab(
			model,
			cf,
			(f - 1) * FH,
			1,
			-W / 2 + T / 2,
			W / 2 - T / 2,
			-D / 2 + T / 2,
			D / 2 - T / 2,
			FLOOR_WOOD,
			Enum.Material.WoodPlanks,
			if f == 2 then stairHole else nil
		)
	end

	-- Roof (walkable with railings and a hatch when the building has a ladder).
	local roofTop = floors * FH + 1
	local ladderHole: Rect? = nil
	if spec.ladder then
		local lx, lz = W / 2 - T / 2 - 2, D / 2 - T / 2 - 2
		local truss = Instance.new("TrussPart")
		truss.Name = "Ladder"
		truss.Anchored = true
		truss.Size = Vector3.new(2, roofTop + 2, 2)
		truss.CFrame = cf * CFrame.new(lx, (roofTop + 2) / 2, lz)
		truss.Color = Color3.fromRGB(90, 90, 90)
		truss.Parent = model
		ladderHole = { minX = lx - 2, maxX = lx + 2, minZ = lz - 2, maxZ = lz + 2 }
		BuildingBuilder.slab(model, cf, roofTop, 1, -W / 2 - T / 2, W / 2 + T / 2, -D / 2 - T / 2, D / 2 + T / 2, spec.roofColor, Enum.Material.Concrete, ladderHole)
		local railH = 3.5
		for _, r in {
			{ Vector3.new(W + T, railH, T), Vector3.new(0, roofTop + railH / 2, -D / 2) },
			{ Vector3.new(W + T, railH, T), Vector3.new(0, roofTop + railH / 2, D / 2) },
			{ Vector3.new(T, railH, D), Vector3.new(-W / 2, roofTop + railH / 2, 0) },
			{ Vector3.new(T, railH, D), Vector3.new(W / 2, roofTop + railH / 2, 0) },
		} do
			Parts.block(model, { Name = "Railing", Size = r[1], CFrame = cf * CFrame.new(r[2]), Color = spec.roofColor, Material = Enum.Material.Metal })
		end
	else
		Parts.block(model, {
			Name = "Roof",
			Size = Vector3.new(W + 4, 1.2, D + 4),
			CFrame = cf * CFrame.new(0, floors * FH + 0.6, 0),
			Color = spec.roofColor,
			Material = Enum.Material.Slate,
		})
	end

	-- Ceiling light on each floor.
	for f = 1, floors do
		local lamp = Parts.block(model, {
			Name = "Lamp",
			Size = Vector3.new(2.5, 0.4, 2.5),
			CFrame = cf * CFrame.new(0, f * FH - 0.3, 0),
			Color = Color3.fromRGB(255, 240, 200),
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		local light = Instance.new("PointLight")
		light.Range = math.max(W, D)
		light.Brightness = 1.4
		light.Color = Color3.fromRGB(255, 230, 190)
		light.Parent = lamp
	end

	if spec.label then
		local anchor = Parts.block(model, {
			Name = "LabelAnchor",
			Size = Vector3.new(1, 1, 1),
			CFrame = cf * CFrame.new(0, roofTop + 2, 0),
			Transparency = 1,
			CanCollide = false,
		})
		Parts.billboard(anchor, spec.label, spec.labelColor or Color3.new(1, 1, 1), 6, 260)
	end

	if spec.decorate then
		spec.decorate(model, cf)
	end

	local acornSpots: { Vector3 } = {}
	local localSpots: { Vector3 } = spec.acornSpots or {}
	for _, p in localSpots do
		table.insert(acornSpots, cf:PointToWorldSpace(p))
	end

	model.Parent = parent
	return {
		name = spec.name,
		model = model,
		cframe = cf,
		rect = worldRect(cf, W + T, D + T),
		doors = doors,
		acornSpots = acornSpots,
	}
end

return BuildingBuilder
