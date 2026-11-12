--!strict
-- Builds the open-world town once at server start. Layout (north = +Z):
--
--   NW Stunt Park + Tower | N  Lake, bridge, lake jump | NE Acorn Bank + balloon field
--   W  Houses             | C  Central Park, Great Oak | E  Nut Mart + house
--   SW Spawn + Garage     | S  Skate Park              | SE Houses
--
-- Roads run between the blocks at x = ±160 and z = ±160.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Parts = require(script.Parent.Parts)
local BuildingBuilder = require(script.Parent.BuildingBuilder)

local WorldBuilder = {}

type Rect = BuildingBuilder.Rect
type Building = BuildingBuilder.Building
type Opening = BuildingBuilder.Opening

export type SpawnPoint = { kind: string, cframe: CFrame }

export type World = {
	folder: Folder,
	buildings: { Building },
	blockedRects: { Rect }, -- areas the squirrel's centre may not enter
	spawnPositions: { Vector3 },
	squirrelSpawn: Vector3,
	minionSpawns: { Vector3 },
	acornSpots: { Vector3 },
	vault: BasePart,
	balloonSpots: { Vector3 },
	vehicleSpawns: { SpawnPoint },
	boostPads: { BasePart },
}

local GRASS = Color3.fromRGB(110, 190, 95)
local ROAD = Color3.fromRGB(55, 55, 60)
local CONCRETE = Color3.fromRGB(185, 185, 190)
local PAVE = Color3.fromRGB(255, 214, 230)
local HEDGE = Color3.fromRGB(64, 140, 70)
local LEAVES = Color3.fromRGB(70, 160, 60)
local TRUNK = Color3.fromRGB(110, 75, 45)

local NORTH = Vector3.new(0, 0, 1)
local SOUTH = Vector3.new(0, 0, -1)
local EAST = Vector3.new(1, 0, 0)
local WEST = Vector3.new(-1, 0, 0)

local LAKE: Rect = { minX = -100, maxX = 100, minZ = 224, maxZ = 276 }
local BRIDGE_X = -40

local function facing(pos: Vector3, dir: Vector3): CFrame
	return CFrame.lookAt(pos, pos + dir)
end

local function expand(r: Rect, m: number): Rect
	return { minX = r.minX - m, maxX = r.maxX + m, minZ = r.minZ - m, maxZ = r.maxZ + m }
end

local function inside(r: Rect, p: Vector3): boolean
	return p.X >= r.minX and p.X <= r.maxX and p.Z >= r.minZ and p.Z <= r.maxZ
end

-- ---------------------------------------------------------------- building specs

local function houseSpec(name: string, wall: Color3, roof: Color3): BuildingBuilder.Spec
	local FH = 14
	local win1: Opening = { c = 0, w = 6, b = 4, t = 9 }
	local function w1(c: number): Opening
		return { c = c, w = 6, b = 4, t = 9 }
	end
	local function w2(c: number): Opening
		return { c = c, w = 6, b = 3, t = 10 }
	end
	return {
		name = name,
		width = 32,
		depth = 26,
		floors = 2,
		floorHeight = FH,
		wallColor = wall,
		roofColor = roof,
		front = { { { c = 0, w = 8, b = 0, t = 10 }, w1(-10), w1(10) }, { w2(-10), w2(0), w2(10) } },
		back = { { { c = 10, w = 6, b = 0, t = 9 }, w1(-8) }, { w2(8) } },
		left = { { win1 }, { w2(0) } },
		right = { { win1 }, { w2(0) } },
		stairs = true,
		acornSpots = { Vector3.new(0, FH + 2, -4), Vector3.new(10, 2, -6) },
		decorate = function(model, cf)
			local function put(n: string, size: Vector3, pos: Vector3, color: Color3, material: Enum.Material?)
				Parts.block(model, { Name = n, Size = size, CFrame = cf * CFrame.new(pos), Color = color, Material = material or Enum.Material.Fabric })
			end
			put("Sofa", Vector3.new(8, 2.2, 3), Vector3.new(-8, 1.1, -9), Color3.fromRGB(200, 80, 80))
			put("SofaBack", Vector3.new(8, 2, 1), Vector3.new(-8, 3, -7.8), Color3.fromRGB(180, 70, 70))
			put("Table", Vector3.new(5, 0.5, 3), Vector3.new(-8, 2, -3), Color3.fromRGB(150, 100, 60), Enum.Material.Wood)
			put("Bed", Vector3.new(6, 1.6, 9), Vector3.new(10, FH + 0.8, -6), Color3.fromRGB(150, 100, 60), Enum.Material.Wood)
			put("Blanket", Vector3.new(6.2, 0.5, 6), Vector3.new(10, FH + 1.8, -4.5), Color3.fromRGB(80, 140, 230))
			put("Pillow", Vector3.new(4, 0.7, 1.8), Vector3.new(10, FH + 1.9, -9.2), Color3.new(1, 1, 1))
		end,
	}
end

local function shopSpec(): BuildingBuilder.Spec
	local FH = 16
	return {
		name = "NutMart",
		label = "🛒 NUT MART",
		labelColor = Color3.fromRGB(255, 200, 80),
		width = 50,
		depth = 34,
		floors = 1,
		floorHeight = FH,
		wallColor = Color3.fromRGB(250, 235, 200),
		roofColor = Color3.fromRGB(200, 90, 50),
		wallMaterial = Enum.Material.Concrete,
		front = { { { c = 0, w = 14, b = 0, t = 12 }, { c = -16, w = 10, b = 3, t = 12 }, { c = 16, w = 10, b = 3, t = 12 } } },
		back = { { { c = -15, w = 6, b = 0, t = 9 } } },
		left = { { { c = 0, w = 8, b = 4, t = 10 } } },
		right = { { { c = 0, w = 8, b = 4, t = 10 } } },
		acornSpots = { Vector3.new(0, 1.5, 4.5), Vector3.new(-18, 1.5, 12), Vector3.new(0, 7.5, 0) },
		decorate = function(model, cf)
			for _, z in { 0, 9 } do
				Parts.block(model, {
					Name = "Shelf",
					Size = Vector3.new(30, 6, 2),
					CFrame = cf * CFrame.new(0, 3, z),
					Color = Color3.fromRGB(120, 85, 55),
					Material = Enum.Material.Wood,
				})
			end
			Parts.block(model, {
				Name = "Counter",
				Size = Vector3.new(8, 3.5, 3),
				CFrame = cf * CFrame.new(16, 1.75, -9),
				Color = Color3.fromRGB(200, 60, 60),
			})
			local sign = Parts.block(model, {
				Name = "Sign",
				Size = Vector3.new(30, 6, 1),
				CFrame = cf * CFrame.new(0, FH + 3, -17.6),
				Color = Color3.fromRGB(200, 90, 50),
			})
			Parts.sign(sign, "NUT MART", Color3.fromRGB(255, 230, 120))
		end,
	}
end

local function garageSpec(): BuildingBuilder.Spec
	return {
		name = "Garage",
		label = "🚗 GARAGE",
		labelColor = Color3.fromRGB(120, 200, 255),
		width = 60,
		depth = 36,
		floors = 1,
		floorHeight = 18,
		wallColor = Color3.fromRGB(150, 150, 160),
		roofColor = Color3.fromRGB(80, 80, 90),
		wallMaterial = Enum.Material.Metal,
		front = { { { c = 0, w = 46, b = 0, t = 14 } } },
		right = { { { c = 0, w = 6, b = 0, t = 9 } } },
	}
end

local function bankSpec(): BuildingBuilder.Spec
	return {
		name = "AcornBank",
		label = "🏦 ACORN BANK",
		labelColor = Color3.fromRGB(255, 200, 40),
		width = 44,
		depth = 32,
		floors = 1,
		floorHeight = 18,
		wallColor = Color3.fromRGB(240, 235, 225),
		roofColor = Color3.fromRGB(120, 110, 100),
		wallMaterial = Enum.Material.Marble,
		front = { { { c = 0, w = 10, b = 0, t = 12 }, { c = -14, w = 6, b = 4, t = 12 }, { c = 14, w = 6, b = 4, t = 12 } } },
		back = { { { c = 12, w = 6, b = 0, t = 9 } } },
		decorate = function(model, cf)
			for _, x in { -18, -9, 9, 18 } do
				Parts.block(model, {
					Name = "Column",
					Size = Vector3.new(18, 3, 3),
					CFrame = cf * CFrame.new(x, 9, -18) * CFrame.Angles(0, 0, math.pi / 2),
					Color = Color3.fromRGB(245, 245, 240),
					Material = Enum.Material.Marble,
					Shape = Enum.PartType.Cylinder,
				})
			end
		end,
	}
end

local function towerSpec(): BuildingBuilder.Spec
	return {
		name = "WatchTower",
		label = "🗼 WATCH TOWER",
		labelColor = Color3.fromRGB(200, 230, 255),
		width = 16,
		depth = 16,
		floors = 1,
		floorHeight = 44,
		wallColor = Color3.fromRGB(170, 150, 130),
		roofColor = Color3.fromRGB(110, 90, 70),
		wallMaterial = Enum.Material.Cobblestone,
		front = { { { c = 0, w = 6, b = 0, t = 9 } } },
		left = { { { c = 0, w = 4, b = 24, t = 30 } } },
		right = { { { c = 0, w = 4, b = 24, t = 30 } } },
		back = { { { c = 0, w = 4, b = 34, t = 40 } } },
		ladder = true,
		acornSpots = { Vector3.new(-3, 47, -3), Vector3.new(3, 47, -4) },
	}
end

-- ---------------------------------------------------------------- props

local function tree(parent: Instance, pos: Vector3, size: number)
	Parts.block(parent, {
		Name = "Trunk",
		Size = Vector3.new(size, 2 * size / 10 + 1.5, 2 * size / 10 + 1.5),
		CFrame = CFrame.new(pos + Vector3.new(0, size / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = TRUNK,
		Material = Enum.Material.Wood,
		Shape = Enum.PartType.Cylinder,
	})
	Parts.block(parent, {
		Name = "Leaves",
		Size = Vector3.one * (size * 1.1),
		CFrame = CFrame.new(pos + Vector3.new(0, size * 1.15, 0)),
		Color = LEAVES,
		Material = Enum.Material.LeafyGrass,
		Shape = Enum.PartType.Ball,
	})
end

local function boostPad(parent: Instance, pos: Vector3, dir: Vector3, width: number?): BasePart
	local pad = Parts.block(parent, {
		Name = "BoostPad",
		Size = Vector3.new(width or 12, 0.2, 8),
		CFrame = facing(pos, dir),
		Color = Color3.fromRGB(0, 220, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "⚡ BOOST ⚡"
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Parent = gui
	gui.Parent = pad
	return pad
end

-- ---------------------------------------------------------------- world

function WorldBuilder.build(): World
	local W = Config.World
	local HS = W.HalfSize
	local folder = Instance.new("Folder")
	folder.Name = "Town"

	local buildings: { Building } = {}
	local acornSpots: { Vector3 } = {}
	local vehicleSpawns: { SpawnPoint } = {}
	local boostPads: { BasePart } = {}

	local function addBuilding(cf: CFrame, spec: BuildingBuilder.Spec): Building
		local b = BuildingBuilder.build(folder, cf, spec)
		table.insert(buildings, b)
		for _, p in b.acornSpots do
			table.insert(acornSpots, p)
		end
		return b
	end
	local function spot(x: number, y: number, z: number)
		table.insert(acornSpots, Vector3.new(x, y, z))
	end
	local function vehicle(kind: string, pos: Vector3, dir: Vector3)
		local lifted = pos + Vector3.new(0, 0.5, 0) -- drop in gently instead of spawning inside the floor
		table.insert(vehicleSpawns, { kind = kind, cframe = facing(lifted, dir) })
	end
	local function flatPart(name: string, x0: number, x1: number, z0: number, z1: number, top: number, color: Color3, material: Enum.Material)
		Parts.block(folder, {
			Name = name,
			Size = Vector3.new(x1 - x0, 0.2, z1 - z0),
			CFrame = CFrame.new((x0 + x1) / 2, top - 0.1, (z0 + z1) / 2),
			Color = color,
			Material = material,
		})
	end

	-- Ground (with a hole for the lake).
	local function ground(x0: number, x1: number, z0: number, z1: number)
		Parts.block(folder, {
			Name = "Ground",
			Size = Vector3.new(x1 - x0, 2, z1 - z0),
			CFrame = CFrame.new((x0 + x1) / 2, -1, (z0 + z1) / 2),
			Color = GRASS,
			Material = Enum.Material.Grass,
		})
	end
	ground(-HS, HS, -HS, LAKE.minZ)
	ground(-HS, HS, LAKE.maxZ, HS)
	ground(-HS, LAKE.minX, LAKE.minZ, LAKE.maxZ)
	ground(LAKE.maxX, HS, LAKE.minZ, LAKE.maxZ)

	-- Edge hedges
	for _, e in {
		{ Vector3.new(2, W.FenceHeight, HS * 2 + 2), Vector3.new(-HS - 1, W.FenceHeight / 2, 0) },
		{ Vector3.new(2, W.FenceHeight, HS * 2 + 2), Vector3.new(HS + 1, W.FenceHeight / 2, 0) },
		{ Vector3.new(HS * 2 + 2, W.FenceHeight, 2), Vector3.new(0, W.FenceHeight / 2, -HS - 1) },
		{ Vector3.new(HS * 2 + 2, W.FenceHeight, 2), Vector3.new(0, W.FenceHeight / 2, HS + 1) },
	} do
		Parts.block(folder, { Name = "EdgeHedge", Size = e[1], CFrame = CFrame.new(e[2]), Color = HEDGE, Material = Enum.Material.LeafyGrass })
	end

	-- Roads
	for _, line in W.RoadLines do
		Parts.block(folder, {
			Name = "Road",
			Size = Vector3.new(W.RoadWidth, 0.2, HS * 2),
			CFrame = CFrame.new(line, 0, 0),
			Color = ROAD,
			Material = Enum.Material.Asphalt,
		})
		Parts.block(folder, {
			Name = "Road",
			Size = Vector3.new(HS * 2, 0.2, W.RoadWidth),
			CFrame = CFrame.new(0, 0.02, line),
			Color = ROAD,
			Material = Enum.Material.Asphalt,
		})
		Parts.block(folder, {
			Name = "RoadLine",
			Size = Vector3.new(0.6, 0.05, HS * 2),
			CFrame = CFrame.new(line, 0.13, 0),
			Color = Color3.fromRGB(255, 210, 60),
			CanCollide = false,
		})
		Parts.block(folder, {
			Name = "RoadLine",
			Size = Vector3.new(HS * 2, 0.05, 0.6),
			CFrame = CFrame.new(0, 0.15, line),
			Color = Color3.fromRGB(255, 210, 60),
			CanCollide = false,
		})
	end
	-- Road boost pads and little kickers
	table.insert(boostPads, boostPad(folder, Vector3.new(-60, 0.2, -160), EAST))
	table.insert(boostPads, boostPad(folder, Vector3.new(60, 0.2, 160), WEST))
	table.insert(boostPads, boostPad(folder, Vector3.new(160, 0.2, 40), NORTH))
	table.insert(boostPads, boostPad(folder, Vector3.new(-160, 0.2, -40), SOUTH))
	Parts.ramp(folder, Vector3.new(-160, 0.1, 80), NORTH, 10, 3, 12)
	Parts.ramp(folder, Vector3.new(160, 0.1, -80), SOUTH, 10, 3, 12)
	Parts.ramp(folder, Vector3.new(80, 0.1, -160), EAST, 10, 3, 12)

	-- ===== SW: spawn plaza + garage =====
	flatPart("Plaza", -HS, -174, -250, -174, 0.1, PAVE, Enum.Material.Pavement)
	local garage = addBuilding(facing(Vector3.new(-262, 0, -284), NORTH), garageSpec())
	vehicle("Roadster", garage.cframe:PointToWorldSpace(Vector3.new(-17, 0, 0)), NORTH)
	vehicle("Kart", garage.cframe:PointToWorldSpace(Vector3.new(0, 0, 0)), NORTH)
	vehicle("Truck", garage.cframe:PointToWorldSpace(Vector3.new(17, 0, 0)), NORTH)
	vehicle("Kart", Vector3.new(-185, 0.1, -240), NORTH)
	vehicle("Kart", Vector3.new(-200, 0.1, -240), NORTH)
	local title = Parts.block(folder, {
		Name = "TitleSign",
		Size = Vector3.new(60, 12, 1),
		CFrame = CFrame.new(-247, 26, -258),
		Color = Color3.fromRGB(165, 98, 52),
		CanCollide = false,
	})
	Parts.sign(title, "🐿️ ESCAPE FROM SQUIRREL 🌰", Color3.new(1, 1, 1))
	local spawnPositions = {}
	for row = 0, 2 do
		for col = 0, 3 do
			table.insert(spawnPositions, Vector3.new(-300 + col * 30, 3, -232 + row * 18))
		end
	end
	spot(-300, 2, -190)
	spot(-190, 2, -205)

	-- ===== S: skate park =====
	flatPart("SkatePark", -146, 146, -HS, -174, 0.1, CONCRETE, Enum.Material.Concrete)
	Parts.block(folder, {
		Name = "Funbox",
		Size = Vector3.new(24, 4, 16),
		CFrame = CFrame.new(0, 2, -262),
		Color = Color3.fromRGB(90, 90, 110),
		Material = Enum.Material.Concrete,
	})
	Parts.ramp(folder, Vector3.new(-26, 0, -262), EAST, 14, 4, 16)
	Parts.ramp(folder, Vector3.new(26, 0, -262), WEST, 14, 4, 16)
	Parts.ramp(folder, Vector3.new(-90, 0, -275), NORTH, 14, 5, 12)
	Parts.ramp(folder, Vector3.new(90, 0, -275), NORTH, 14, 5, 12)
	Parts.block(folder, {
		Name = "QuarterDeck",
		Size = Vector3.new(240, 10, 12),
		CFrame = CFrame.new(0, 5, -312),
		Color = Color3.fromRGB(90, 90, 110),
		Material = Enum.Material.Concrete,
	})
	Parts.ramp(folder, Vector3.new(0, 0, -292), SOUTH, 14, 10, 240, Color3.fromRGB(120, 120, 140), Enum.Material.Concrete)
	Parts.ramp(folder, Vector3.new(0, 0, -205), NORTH, 22, 8, 16) -- launches over the road into the park
	table.insert(boostPads, boostPad(folder, Vector3.new(0, 0.2, -222), NORTH, 16))
	vehicle("Truck", Vector3.new(110, 0.1, -230), WEST)
	spot(0, 6, -262)
	spot(-80, 12, -312)
	spot(80, 12, -312)

	-- ===== SE: houses =====
	addBuilding(facing(Vector3.new(210, 0, -212), NORTH), houseSpec("HouseSE1", Color3.fromRGB(255, 220, 180), Color3.fromRGB(170, 70, 60)))
	addBuilding(facing(Vector3.new(285, 0, -212), NORTH), houseSpec("HouseSE2", Color3.fromRGB(190, 225, 255), Color3.fromRGB(60, 80, 140)))
	tree(folder, Vector3.new(200, 0, -290), 12)
	tree(folder, Vector3.new(300, 0, -265), 10)
	spot(230, 2, -300)

	-- ===== W: houses =====
	addBuilding(facing(Vector3.new(-215, 0, -60), EAST), houseSpec("HouseW1", Color3.fromRGB(255, 240, 170), Color3.fromRGB(150, 80, 40)))
	addBuilding(facing(Vector3.new(-215, 0, 60), EAST), houseSpec("HouseW2", Color3.fromRGB(220, 255, 210), Color3.fromRGB(60, 120, 70)))
	for _, z in { -110, 0, 110 } do
		tree(folder, Vector3.new(-292, 0, z), 11)
	end
	spot(-300, 2, -60)
	spot(-300, 2, 60)

	-- ===== C: Central Park + the Great Oak =====
	flatPart("Path", -146, 146, -5, 5, 0.08, CONCRETE, Enum.Material.Pavement)
	flatPart("Path", -5, 5, -146, 146, 0.08, CONCRETE, Enum.Material.Pavement)
	Parts.block(folder, {
		Name = "OakTrunk",
		Size = Vector3.new(40, 14, 14),
		CFrame = CFrame.new(0, 20, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = TRUNK,
		Material = Enum.Material.Wood,
		Shape = Enum.PartType.Cylinder,
	})
	local canopy: { { pos: Vector3, size: number } } = {
		{ pos = Vector3.new(0, 46, 0), size = 44 },
		{ pos = Vector3.new(15, 39, 8), size = 30 },
		{ pos = Vector3.new(-15, 41, -6), size = 32 },
		{ pos = Vector3.new(6, 40, -17), size = 28 },
		{ pos = Vector3.new(-8, 37, 15), size = 28 },
	}
	for _, c in canopy do
		Parts.block(folder, {
			Name = "OakLeaves",
			Size = Vector3.one * c.size,
			CFrame = CFrame.new(c.pos),
			Color = LEAVES,
			Material = Enum.Material.LeafyGrass,
			Shape = Enum.PartType.Ball,
			CanCollide = false,
		})
	end
	local hole = Parts.block(folder, {
		Name = "SquirrelHole",
		Size = Vector3.one * 6,
		CFrame = CFrame.new(0, 26, -5.5),
		Color = Color3.fromRGB(25, 15, 10),
		Shape = Enum.PartType.Ball,
		CanCollide = false,
	})
	Parts.billboard(hole, "🌰 THE GREAT OAK", Color3.fromRGB(255, 200, 80), 30, 400)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2 + math.pi / 8
		tree(folder, Vector3.new(math.cos(a) * 95, 0, math.sin(a) * 95), 10)
		Parts.block(folder, {
			Name = "Bench",
			Size = Vector3.new(6, 1, 2),
			CFrame = CFrame.new(math.cos(a) * 60, 1.5, math.sin(a) * 60) * CFrame.Angles(0, -a, 0),
			Color = Color3.fromRGB(150, 100, 60),
			Material = Enum.Material.Wood,
		})
	end
	vehicle("Mower", Vector3.new(60, 0.1, -110), EAST)
	for _, p in { Vector3.new(12, 2, 0), Vector3.new(-12, 2, 0), Vector3.new(0, 2, 12), Vector3.new(0, 2, -12) } do
		spot(p.X, p.Y, p.Z)
	end
	spot(110, 2, 0)
	spot(-110, 2, 0)
	spot(0, 2, 110)
	spot(0, 2, -110)

	-- ===== E: Nut Mart + house =====
	addBuilding(facing(Vector3.new(230, 0, -60), WEST), shopSpec())
	addBuilding(facing(Vector3.new(230, 0, 70), WEST), houseSpec("HouseE1", Color3.fromRGB(255, 200, 220), Color3.fromRGB(140, 60, 110)))
	vehicle("Kart", Vector3.new(295, 0.1, 0), WEST)
	spot(300, 2, -60)
	spot(300, 2, 120)

	-- ===== NW: stunt park + watch tower =====
	Parts.ramp(folder, Vector3.new(-260, 0, 180), NORTH, 48, 22, 20)
	Parts.block(folder, {
		Name = "MegaPlatform",
		Size = Vector3.new(20, 22, 16),
		CFrame = CFrame.new(-260, 11, 236),
		Color = Color3.fromRGB(255, 170, 60),
		Material = Enum.Material.DiamondPlate,
	})
	Parts.ramp(folder, Vector3.new(-260, 22, 240), NORTH, 4, 2.5, 20, Color3.fromRGB(255, 80, 80))
	Parts.ramp(folder, Vector3.new(-260, 0, 300), SOUTH, 32, 13, 24)
	local megaSign = Parts.block(folder, {
		Name = "MegaSign",
		Size = Vector3.new(20, 5, 1),
		CFrame = CFrame.new(-260, 30, 244),
		Color = Color3.fromRGB(255, 80, 80),
		CanCollide = false,
	})
	Parts.sign(megaSign, "🚀 MEGA RAMP", Color3.new(1, 1, 1))
	table.insert(boostPads, boostPad(folder, Vector3.new(-260, 0.2, 177), NORTH, 20))
	spot(-260, 25, 232)
	addBuilding(facing(Vector3.new(-200, 0, 290), SOUTH), towerSpec())

	-- ===== N: the lake =====
	Parts.block(folder, {
		Name = "LakeBed",
		Size = Vector3.new(LAKE.maxX - LAKE.minX, 2, LAKE.maxZ - LAKE.minZ),
		CFrame = CFrame.new(0, -13, (LAKE.minZ + LAKE.maxZ) / 2),
		Color = Color3.fromRGB(200, 180, 130),
		Material = Enum.Material.Sand,
	})
	local lakeDepth, lakeTop = 10, -2
	for _, wall in {
		{ Vector3.new(LAKE.maxX - LAKE.minX + 2, lakeDepth, 1), Vector3.new(0, -7, LAKE.minZ - 0.5) },
		{ Vector3.new(LAKE.maxX - LAKE.minX + 2, lakeDepth, 1), Vector3.new(0, -7, LAKE.maxZ + 0.5) },
		{ Vector3.new(1, lakeDepth, LAKE.maxZ - LAKE.minZ), Vector3.new(LAKE.minX - 0.5, -7, (LAKE.minZ + LAKE.maxZ) / 2) },
		{ Vector3.new(1, lakeDepth, LAKE.maxZ - LAKE.minZ), Vector3.new(LAKE.maxX + 0.5, -7, (LAKE.minZ + LAKE.maxZ) / 2) },
	} do
		Parts.block(folder, { Name = "LakeWall", Size = wall[1], CFrame = CFrame.new(wall[2]), Color = Color3.fromRGB(200, 180, 130), Material = Enum.Material.Sand })
	end
	workspace.Terrain:FillBlock(
		CFrame.new(0, lakeTop - lakeDepth / 2, (LAKE.minZ + LAKE.maxZ) / 2),
		Vector3.new(LAKE.maxX - LAKE.minX, lakeDepth, LAKE.maxZ - LAKE.minZ),
		Enum.Material.Water
	)
	-- Bridge
	Parts.ramp(folder, Vector3.new(BRIDGE_X, 0, 198), NORTH, 16, 5, 14, Color3.fromRGB(150, 100, 60), Enum.Material.WoodPlanks)
	Parts.ramp(folder, Vector3.new(BRIDGE_X, 0, 302), SOUTH, 16, 5, 14, Color3.fromRGB(150, 100, 60), Enum.Material.WoodPlanks)
	Parts.block(folder, {
		Name = "BridgeDeck",
		Size = Vector3.new(14, 1, 72),
		CFrame = CFrame.new(BRIDGE_X, 4.5, 250),
		Color = Color3.fromRGB(150, 100, 60),
		Material = Enum.Material.WoodPlanks,
	})
	for _, side in { -1, 1 } do
		Parts.block(folder, {
			Name = "BridgeRail",
			Size = Vector3.new(0.6, 3, 72),
			CFrame = CFrame.new(BRIDGE_X + side * 7.3, 6.5, 250),
			Color = Color3.fromRGB(120, 80, 50),
			Material = Enum.Material.Wood,
		})
		for _, z in { 232, 250, 268 } do
			Parts.block(folder, {
				Name = "BridgePillar",
				Size = Vector3.new(2, 16, 2),
				CFrame = CFrame.new(BRIDGE_X + side * 6, -4, z),
				Color = Color3.fromRGB(120, 80, 50),
				Material = Enum.Material.Wood,
			})
		end
	end
	-- Island you can only reach by swimming
	Parts.block(folder, {
		Name = "Island",
		Size = Vector3.new(12, 11, 12),
		CFrame = CFrame.new(60, -6.5, 250),
		Color = Color3.fromRGB(230, 210, 150),
		Material = Enum.Material.Sand,
	})
	tree(folder, Vector3.new(63, -1, 253), 6)
	-- Lake jump: only a fast car clears it
	Parts.ramp(folder, Vector3.new(50, 0, 200), NORTH, 18, 10, 16, Color3.fromRGB(255, 80, 80))
	local jumpSign = Parts.block(folder, {
		Name = "JumpSign",
		Size = Vector3.new(16, 4, 1),
		CFrame = CFrame.new(50, 14, 196),
		Color = Color3.fromRGB(255, 80, 80),
		CanCollide = false,
	})
	Parts.sign(jumpSign, "LAKE JUMP 🌊 (need speed!)", Color3.new(1, 1, 1))
	vehicle("Roadster", Vector3.new(100, 0.1, 190), WEST)
	spot(60, 1.5, 250)
	spot(BRIDGE_X, 7, 250)
	spot(0, 2, 300)
	spot(-90, 2, 300)

	-- ===== NE: Acorn Bank + balloon field =====
	local bank = addBuilding(facing(Vector3.new(247, 0, 220), SOUTH), bankSpec())
	local vault = Parts.block(folder, {
		Name = "Vault",
		Size = Vector3.new(14, 0.4, 14),
		CFrame = bank.cframe * CFrame.new(0, 0.4, 4),
		Color = Color3.fromRGB(255, 200, 40),
		Material = Enum.Material.Neon,
	})
	Parts.billboard(vault, "🌰 DEPOSIT ACORNS HERE", Color3.fromRGB(255, 220, 80), 5, 120)
	flatPart("BalloonField", 190, 310, 262, 312, 0.1, Color3.fromRGB(150, 220, 120), Enum.Material.Grass)
	vehicle("Kart", Vector3.new(300, 0.1, 190), WEST)

	-- Areas the squirrel can't enter: buildings, the oak trunk, the lake (except the bridge),
	-- and the edge of the map.
	local margin = Config.Squirrel.BuildingMargin
	local blockedRects: { Rect } = {}
	for _, b in buildings do
		table.insert(blockedRects, expand(b.rect, margin))
	end
	table.insert(blockedRects, expand({ minX = -7, maxX = 7, minZ = -7, maxZ = 7 }, margin))
	table.insert(blockedRects, { minX = LAKE.minX, maxX = BRIDGE_X - 8, minZ = LAKE.minZ, maxZ = LAKE.maxZ })
	table.insert(blockedRects, { minX = BRIDGE_X + 8, maxX = LAKE.maxX, minZ = LAKE.minZ, maxZ = LAKE.maxZ })

	folder.Parent = workspace

	return {
		folder = folder,
		buildings = buildings,
		blockedRects = blockedRects,
		spawnPositions = spawnPositions,
		squirrelSpawn = Vector3.new(0, 0, -24),
		minionSpawns = { Vector3.new(100, 3, 100), Vector3.new(-100, 3, 100), Vector3.new(100, 3, -100), Vector3.new(-100, 3, -100) },
		acornSpots = acornSpots,
		vault = vault,
		balloonSpots = { Vector3.new(250, 0, -285), Vector3.new(90, 0, 90), Vector3.new(250, 0, 287) },
		vehicleSpawns = vehicleSpawns,
		boostPads = boostPads,
	}
end

function WorldBuilder.isBlocked(world: World, pos: Vector3): boolean
	local HS = Config.World.HalfSize - 6
	if math.abs(pos.X) > HS or math.abs(pos.Z) > HS then
		return true
	end
	for _, r in world.blockedRects do
		if inside(r, pos) then
			return true
		end
	end
	return false
end

function WorldBuilder.buildingAt(world: World, pos: Vector3): Building?
	for _, b in world.buildings do
		if inside(b.rect, pos) then
			return b
		end
	end
	return nil
end

function WorldBuilder.buildLobby(): SpawnLocation
	local L = Config.Lobby
	local folder = Instance.new("Folder")
	folder.Name = "Lobby"
	Parts.block(folder, {
		Name = "LobbyFloor",
		Size = Vector3.new(L.Size, 2, L.Size),
		CFrame = CFrame.new(L.Position - Vector3.new(0, 1, 0)),
		Color = PAVE,
		Material = Enum.Material.Pavement,
	})
	for _, offset in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
		local alongX = offset.Z ~= 0
		Parts.block(folder, {
			Name = "LobbyRail",
			Size = if alongX then Vector3.new(L.Size, 4, 1) else Vector3.new(1, 4, L.Size),
			CFrame = CFrame.new(L.Position + offset * (L.Size / 2) + Vector3.new(0, 2, 0)),
			Color = Color3.fromRGB(165, 98, 52),
		})
	end
	local sign = Parts.block(folder, {
		Name = "LobbySign",
		Size = Vector3.new(40, 10, 1),
		CFrame = CFrame.new(L.Position + Vector3.new(0, 10, L.Size / 2 - 2)),
		Color = Color3.fromRGB(165, 98, 52),
		CanCollide = false,
	})
	Parts.sign(sign, "🐿️ ESCAPE FROM SQUIRREL\nGrab golden acorns, bank them, fly away!", Color3.new(1, 1, 1))
	tree(folder, L.Position + Vector3.new(-30, 0, 30), 10)
	tree(folder, L.Position + Vector3.new(30, 0, 30), 10)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(L.Position + Vector3.new(0, 0.5, 0))
	spawn.Color = Color3.fromRGB(255, 190, 40)
	spawn.Material = Enum.Material.Neon
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = folder
	folder.Parent = workspace
	return spawn
end

return WorldBuilder
