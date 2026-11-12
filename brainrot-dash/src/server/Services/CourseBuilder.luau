--!strict
-- Builds the sky course (runs along +Z over a bottomless void) and runs its traps.
--
--   Hub -> 1 Glass Lanes -> 2 Crumble Road -> 3 Sweeper Alley -> 4 Blink Road
--       -> 5 Glass Gamble -> 6 Launch Pads -> 7 Boulder Hill -> 8 Double Sweep
--       -> 9 Blink Panic -> 10 Glass Gauntlet -> FINISH
-- Speedrun style: everything is run through, nothing requires a jump.
--
-- Every stage ends in a checkpoint holding that stage's brainrot.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Brainrots = require(ReplicatedStorage.Shared.Brainrots)
local Parts = require(script.Parent.Parts)

local CourseBuilder = {}

export type Row = { tiles: { BasePart }, safe: number }

export type Course = {
	folder: Folder,
	checkpoints: { [number]: CFrame }, -- 0 = hub spawn, 1..N = end of each stage
	checkpointPads: { [number]: BasePart },
	stageNames: { string },
	stageCount: number,
	finishPad: BasePart,
	startLine: BasePart,
	speedPads: { BasePart },
	coinSpots: { Vector3 },
	tileRows: { Row },
	killY: number,
	length: number,
}

type Ctx = {
	folder: Folder,
	rng: Random,
	coinSpots: { Vector3 },
	tileRows: { Row },
	serverOwned: { BasePart },
	speedPads: { BasePart },
}

local speedPad: (ctx: Ctx, pos: Vector3) -> ()

local GLASS = Color3.fromRGB(170, 230, 255)
local GLASS_ALPHA = 0.35
local STAGE_COLORS = {
	Color3.fromRGB(255, 120, 180),
	Color3.fromRGB(255, 170, 70),
	Color3.fromRGB(255, 230, 80),
	Color3.fromRGB(120, 220, 120),
	Color3.fromRGB(90, 200, 255),
	Color3.fromRGB(130, 130, 255),
	Color3.fromRGB(200, 110, 255),
	Color3.fromRGB(255, 100, 100),
	Color3.fromRGB(100, 255, 200),
	Color3.fromRGB(255, 215, 0),
}

local function isCharacterPart(hit: BasePart): boolean
	local model = hit:FindFirstAncestorOfClass("Model")
	return model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil
end

local function platform(ctx: Ctx, name: string, x0: number, x1: number, z0: number, z1: number, top: number, color: Color3, material: Enum.Material?): Part
	return Parts.block(ctx.folder, {
		Name = name,
		Size = Vector3.new(x1 - x0, 2, z1 - z0),
		CFrame = CFrame.new((x0 + x1) / 2, top - 1, (z0 + z1) / 2),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
end

local function stageSign(ctx: Ctx, index: number, name: string, z: number, y: number)
	local anchor = Parts.block(ctx.folder, {
		Name = "StageSign",
		Size = Vector3.one,
		CFrame = CFrame.new(0, y + 12, z + 2),
		Transparency = 1,
		CanCollide = false,
	})
	Parts.billboard(anchor, `STAGE {index}: {name}`, STAGE_COLORS[index] or Color3.new(1, 1, 1), 0, 160)
end

-- ------------------------------------------------------------------ glass tiles

local function shatter(tile: BasePart)
	for _ = 1, 5 do
		local shard = Instance.new("Part")
		shard.Size = Vector3.new(2, 0.3, 2)
		shard.CFrame = tile.CFrame * CFrame.new(math.random(-2, 2), 0, math.random(-2, 2))
		shard.Color = GLASS
		shard.Material = Enum.Material.Glass
		shard.Transparency = 0.3
		shard.CanCollide = false
		shard.CanQuery = false
		shard.CanTouch = false
		shard.AssemblyLinearVelocity = Vector3.new(math.random(-12, 12), math.random(0, 10), math.random(-12, 12))
		shard.Parent = workspace
		Debris:AddItem(shard, 2)
	end
end

local function hookGlass(tile: BasePart)
	local broken = false
	tile.Touched:Connect(function(hit)
		if broken or not tile:GetAttribute("Fake") or not isCharacterPart(hit) then
			return
		end
		broken = true
		shatter(tile)
		tile.CanCollide = false
		tile.Transparency = 1
		task.delay(4, function()
			tile.CanCollide = true
			tile.Transparency = GLASS_ALPHA
			broken = false
		end)
	end)
end

function CourseBuilder.shuffleRow(row: Row, rng: Random)
	local order = {}
	for i = 1, #row.tiles do
		order[i] = i
	end
	for i = #order, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	for rank, index in order do
		row.tiles[index]:SetAttribute("Fake", rank > row.safe)
	end
end

local function stageGlass(ctx: Ctx, z: number, y: number, rows: number, cols: number, safe: number): (number, number)
	-- Rows sit right next to each other: you run straight across and pick a lane.
	local size, pitch = 7, 7.4
	local colPitch = 7.4
	local zStart = z + 0.4
	for r = 1, rows do
		local zc = zStart + size / 2 + (r - 1) * pitch
		local tiles: { BasePart } = {}
		for c = 1, cols do
			local x = (c - (cols + 1) / 2) * colPitch
			local tile = Parts.block(ctx.folder, {
				Name = "GlassTile",
				Size = Vector3.new(size, 1, size),
				CFrame = CFrame.new(x, y - 0.5, zc),
				Color = GLASS,
				Material = Enum.Material.Glass,
				Transparency = GLASS_ALPHA,
			})
			CollectionService:AddTag(tile, "GlassTile")
			hookGlass(tile)
			table.insert(tiles, tile)
		end
		local row: Row = { tiles = tiles, safe = safe }
		CourseBuilder.shuffleRow(row, ctx.rng)
		table.insert(ctx.tileRows, row)
	end
	return zStart + (rows - 1) * pitch + size + 0.4, y
end

-- ------------------------------------------------------------------ crumble road

local function stageCrumble(ctx: Ctx, z: number, y: number, rows: number, color: Color3): (number, number)
	local size, pitch = 4.4, 4.8
	for r = 1, rows do
		for c = 1, 5 do
			local tile = Parts.block(ctx.folder, {
				Name = "CrumbleTile",
				Size = Vector3.new(size, 1.5, size),
				CFrame = CFrame.new((c - 3) * pitch, y - 0.75, z + 2 + pitch / 2 + (r - 1) * pitch),
				Color = color,
				Material = Enum.Material.Sandstone,
			})
			CollectionService:AddTag(tile, "CrumbleTile")
			local busy = false
			tile.Touched:Connect(function(hit)
				if busy or not isCharacterPart(hit) then
					return
				end
				busy = true
				tile.Color = Color3.fromRGB(255, 80, 60)
				task.delay(0.45, function()
					tile.CanCollide = false
					tile.Transparency = 1
					task.delay(3.5, function()
						tile.CanCollide = true
						tile.Transparency = 0
						tile.Color = color
						busy = false
					end)
				end)
			end)
		end
	end
	for _ = 1, 3 do
		table.insert(ctx.coinSpots, Vector3.new((ctx.rng:NextInteger(1, 5) - 3) * pitch, y + 3, z + 2 + ctx.rng:NextNumber(0.2, 0.9) * rows * pitch))
	end
	return z + 2 + rows * pitch + 2, y
end

-- ------------------------------------------------------------------ sweepers
-- Tall spinning walls: too high to jump, so you time your dash or get knocked off.

local function stageSpin(ctx: Ctx, z: number, y: number, speeds: { number }, color: Color3): (number, number)
	local W = Config.Course.Width
	local section = 28
	local length = 12 + #speeds * section
	platform(ctx, "SpinFloor", -W / 2, W / 2, z, z + length, y, color)
	local upright = CFrame.Angles(0, 0, math.pi / 2) -- attachment X axis pointing up
	for i, speed in speeds do
		local zc = z + 6 + (i - 0.5) * section
		local pole = Parts.block(ctx.folder, {
			Name = "SpinPole",
			Size = Vector3.new(8, 2, 2),
			CFrame = CFrame.new(0, y + 4, zc) * upright,
			Color = Color3.fromRGB(60, 60, 70),
			Material = Enum.Material.Metal,
			Shape = Enum.PartType.Cylinder,
		})
		local bar = Instance.new("Part")
		bar.Name = "SpinBar"
		bar.Size = Vector3.new(W - 2, 6, 1.6)
		bar.CFrame = CFrame.new(0, y + 3.6, zc)
		bar.Color = Color3.fromRGB(255, 60, 60)
		bar.Material = Enum.Material.Neon
		bar.CustomPhysicalProperties = PhysicalProperties.new(5, 0.3, 0.6)
		bar.Parent = ctx.folder
		local noCollide = Instance.new("NoCollisionConstraint")
		noCollide.Part0 = pole
		noCollide.Part1 = bar
		noCollide.Parent = bar
		local a0 = Instance.new("Attachment")
		a0.CFrame = pole.CFrame:ToObjectSpace(CFrame.new(0, y + 3.6, zc) * upright)
		a0.Parent = pole
		local a1 = Instance.new("Attachment")
		a1.CFrame = upright
		a1.Parent = bar
		local hinge = Instance.new("HingeConstraint")
		hinge.Attachment0 = a0
		hinge.Attachment1 = a1
		hinge.ActuatorType = Enum.ActuatorType.Motor
		hinge.AngularVelocity = speed
		hinge.MotorMaxTorque = 1e8
		hinge.MotorMaxAcceleration = 1e4
		hinge.Parent = bar
		table.insert(ctx.serverOwned, bar)
		table.insert(ctx.coinSpots, Vector3.new(if i % 2 == 0 then 8 else -8, y + 3, zc))
	end
	return z + length, y
end

-- ------------------------------------------------------------------ blinking platforms

local function stageBlink(ctx: Ctx, z: number, y: number, sections: number, period: number, color: Color3): (number, number)
	-- A continuous road cut into sections that take turns vanishing. Wait at the edge
	-- for your section to appear, then sprint across. No jumping needed.
	local W = Config.Course.Width
	local depth = 18
	local plats: { BasePart } = {}
	for i = 1, sections do
		local p = Parts.block(ctx.folder, {
			Name = "BlinkPlatform",
			Size = Vector3.new(W, 1, depth),
			CFrame = CFrame.new(0, y - 0.5, z + depth / 2 + (i - 1) * depth),
			Color = color,
			Material = Enum.Material.Neon,
		})
		p:SetAttribute("Group", i % 2)
		table.insert(plats, p)
	end
	table.insert(ctx.coinSpots, plats[math.max(1, sections // 2)].Position + Vector3.new(6, 3.5, 0))

	local ghost = Color3.fromRGB(80, 80, 90)
	local warn = Color3.fromRGB(255, 140, 0)
	local function show(group: number?, warnGroup: number?)
		for _, p in plats do
			local g = p:GetAttribute("Group")
			local solid = group == nil or g == group
			p.CanCollide = solid
			p.Transparency = if solid then 0 else 0.8
			p.Color = if not solid then ghost elseif g == warnGroup then warn else color
		end
	end
	-- A only -> both (A flashing orange) -> B only -> both (B flashing) -> ...
	task.spawn(function()
		local group = 1
		while true do
			show(group, nil)
			task.wait(period)
			show(nil, group)
			task.wait(1)
			group = 1 - group
		end
	end)
	return z + sections * depth, y
end

-- ------------------------------------------------------------------ bounce pads

local function stageBounce(ctx: Ctx, z: number, y: number, jumps: number, color: Color3): (number, number)
	local W = Config.Course.Width
	local cursor = z
	-- Each segment: a 24-stud platform with a pad at its far end, then a 12-stud gap.
	-- Air steering makes the jump distance vary (roughly 14-31 studs), so landing
	-- platforms are long enough to catch both short and long bounces.
	for _ = 1, jumps do
		platform(ctx, "BounceFloor", -W / 2, W / 2, cursor, cursor + 24, y, color)
		local pad = Parts.block(ctx.folder, {
			Name = "BouncePad",
			Size = Vector3.new(12, 0.4, 5),
			CFrame = CFrame.new(0, y + 0.2, cursor + 21.5),
			Color = Color3.fromRGB(80, 255, 120),
			Material = Enum.Material.Neon,
		})
		pad:SetAttribute("Up", 85)
		pad:SetAttribute("Forward", 30)
		CollectionService:AddTag(pad, "BouncePad")
		table.insert(ctx.coinSpots, Vector3.new(0, y + 14, cursor + 30)) -- grab it mid-air
		cursor += 24 + 12
	end
	platform(ctx, "BounceFloor", -W / 2, W / 2, cursor, cursor + 24, y, color)
	return cursor + 24, y
end

-- ------------------------------------------------------------------ boulder hill

local function stageHill(ctx: Ctx, z: number, y: number, length: number, rise: number, color: Color3): (number, number)
	local W = Config.Course.Width
	platform(ctx, "HillBase", -W / 2, W / 2, z, z + 6, y, color)
	local z0 = z + 6
	local angle = math.atan(rise / length)
	local hyp = math.sqrt(length ^ 2 + rise ^ 2)
	local tilt = CFrame.Angles(-angle, 0, 0)
	local midTop = Vector3.new(0, y + rise / 2, z0 + length / 2)
	local normal = tilt.UpVector
	Parts.block(ctx.folder, {
		Name = "Hill",
		Size = Vector3.new(W, 2, hyp + 1),
		CFrame = CFrame.new(midTop - normal * 1) * tilt,
		Color = color,
		Material = Enum.Material.Grass,
	})
	for _, side in { -1, 1 } do
		Parts.block(ctx.folder, {
			Name = "HillWall",
			Size = Vector3.new(1, 3, hyp + 1),
			CFrame = CFrame.new(midTop + normal * 1.5 + Vector3.new(side * (W / 2 + 0.5), 0, 0)) * tilt,
			Color = Color3.fromRGB(120, 90, 60),
			Material = Enum.Material.Wood,
		})
	end
	local topZ = z0 + length
	local top = y + rise
	platform(ctx, "HillTop", -W / 2, W / 2, topZ, topZ + 8, top, color)
	for i = 1, 3 do
		local f = i / 4
		table.insert(ctx.coinSpots, Vector3.new((i - 2) * 7, y + rise * f + 3, z0 + length * f))
	end

	-- Boulders roll down the hill and vanish at the bottom.
	local boulders: { BasePart } = {}
	task.spawn(function()
		local lastSpawn = 0
		while true do
			task.wait(0.2)
			for i = #boulders, 1, -1 do
				local b = boulders[i]
				if not b.Parent or b.Position.Z < z0 - 1 or b.Position.Y < y - 20 then
					b:Destroy()
					table.remove(boulders, i)
				end
			end
			if os.clock() - lastSpawn > 2.2 then
				lastSpawn = os.clock()
				local b = Instance.new("Part")
				b.Name = "Boulder"
				b.Shape = Enum.PartType.Ball
				b.Size = Vector3.one * 7
				b.Color = Color3.fromRGB(120, 115, 110)
				b.Material = Enum.Material.Slate
				b.CustomPhysicalProperties = PhysicalProperties.new(3, 0.4, 0.3)
				b.CFrame = CFrame.new(ctx.rng:NextNumber(-7, 7), top + 4, topZ - 2)
				b.Parent = ctx.folder
				b:SetNetworkOwner(nil)
				b.AssemblyLinearVelocity = Vector3.new(0, 0, -18)
				Debris:AddItem(b, 12)
				table.insert(boulders, b)
			end
		end
	end)
	return topZ + 8, top
end

-- ------------------------------------------------------------------ checkpoints, hub, finish

-- A ⚡ pad: run over it for a short burst of speed (handled by PowerService).
speedPad = function(ctx: Ctx, pos: Vector3)
	local pad = Parts.block(ctx.folder, {
		Name = "SpeedPad",
		Size = Vector3.new(16, 0.3, 3.5),
		CFrame = CFrame.new(pos + Vector3.new(0, 0.25, 0)),
		Color = Color3.fromRGB(0, 230, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	CollectionService:AddTag(pad, "SpeedPad")
	table.insert(ctx.speedPads, pad)
end

local function checkpoint(ctx: Ctx, stage: number, z: number, y: number): (CFrame, BasePart)
	local W = Config.Course.Width
	local color = STAGE_COLORS[stage] or Color3.new(1, 1, 1)
	platform(ctx, "Checkpoint", -W / 2, W / 2, z, z + 16, y, Color3.fromRGB(245, 245, 250), Enum.Material.Marble)
	local pad = Parts.block(ctx.folder, {
		Name = "CheckpointPad",
		Size = Vector3.new(W - 2, 0.2, 14),
		CFrame = CFrame.new(0, y + 0.1, z + 8),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.4,
		CanCollide = false,
	})
	pad:SetAttribute("Stage", stage)
	speedPad(ctx, Vector3.new(0, y, z + 14))
	local info = Brainrots.forStage(stage)
	if info then
		local pedestal = Parts.block(ctx.folder, {
			Name = "Pedestal",
			Size = Vector3.new(3, 5, 5),
			CFrame = CFrame.new(7.5, y + 1.5, z + 8) * CFrame.Angles(0, 0, math.pi / 2),
			Color = Brainrots.RarityColors[info.rarity],
			Material = Enum.Material.Marble,
			Shape = Enum.PartType.Cylinder,
		})
		local model = Brainrots.build(info.id, 1)
		model:PivotTo(CFrame.new(7.5, y + 7, z + 8))
		model.Parent = ctx.folder
		Parts.billboard(
			pedestal,
			`{info.name}\n"{info.chant}"\n{info.rarity} · +{info.income}/s`,
			Brainrots.RarityColors[info.rarity],
			10,
			120
		)
	end
	local cf = CFrame.lookAt(Vector3.new(-4, y + 3, z + 8), Vector3.new(-4, y + 3, z + 20))
	return cf, pad
end

function CourseBuilder.build(): Course
	local folder = Instance.new("Folder")
	folder.Name = "Course"
	local ctx: Ctx = { folder = folder, rng = Random.new(), coinSpots = {}, tileRows = {}, serverOwned = {}, speedPads = {} }
	local Y = Config.Course.Height

	-- Hub
	platform(ctx, "Hub", -40, 40, -50, 0, Y, Color3.fromRGB(255, 220, 240), Enum.Material.Pavement)
	local title = Parts.block(folder, {
		Name = "Title",
		Size = Vector3.new(50, 12, 1),
		CFrame = CFrame.new(0, Y + 14, -48),
		Color = Color3.fromRGB(255, 100, 180),
		CanCollide = false,
	})
	Parts.sign(title, "🧠 BRAINROT DASH\nDON'T FALL! 💀", Color3.new(1, 1, 1))
	local arch = Parts.block(folder, {
		Name = "StartArch",
		Size = Vector3.new(28, 3, 2),
		CFrame = CFrame.new(0, Y + 12, -1),
		Color = Color3.fromRGB(80, 255, 120),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	Parts.sign(arch, "START ▶", Color3.new(0, 0, 0))
	for _, x in { -14, 14 } do
		Parts.block(folder, {
			Name = "ArchPost",
			Size = Vector3.new(2, 12, 2),
			CFrame = CFrame.new(x, Y + 6, -1),
			Color = Color3.fromRGB(80, 255, 120),
			Material = Enum.Material.Neon,
		})
	end
	-- Crossing the start line starts your run timer.
	local startLine = Parts.block(folder, {
		Name = "StartLine",
		Size = Vector3.new(Config.Course.Width, 10, 1),
		CFrame = CFrame.new(0, Y + 5, -2),
		Transparency = 1,
		CanCollide = false,
	})
	speedPad(ctx, Vector3.new(0, Y, -6))
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(0, Y + 0.5, -30)
	spawn.Color = Color3.fromRGB(255, 100, 180)
	spawn.Material = Enum.Material.Neon
	spawn.Parent = folder

	local checkpoints: { [number]: CFrame } = { [0] = CFrame.lookAt(Vector3.new(0, Y + 3, -30), Vector3.new(0, Y + 3, 0)) }
	local pads: { [number]: BasePart } = {}
	local names: { string } = {}

	local stages: { { name: string, build: (z: number, y: number, color: Color3) -> (number, number) } } = {
		{ name = "Glass Lanes", build = function(z, y)
			return stageGlass(ctx, z, y, 8, 3, 2)
		end },
		{ name = "Crumble Road", build = function(z, y, c)
			return stageCrumble(ctx, z, y, 14, c)
		end },
		{ name = "Sweeper Alley", build = function(z, y, c)
			return stageSpin(ctx, z, y, { 1.3 }, c)
		end },
		{ name = "Blink Road", build = function(z, y, c)
			return stageBlink(ctx, z, y, 4, 2.4, c)
		end },
		{ name = "Glass Gamble", build = function(z, y)
			return stageGlass(ctx, z, y, 10, 4, 2)
		end },
		{ name = "Launch Pads", build = function(z, y, c)
			return stageBounce(ctx, z, y, 3, c)
		end },
		{ name = "Boulder Hill", build = function(z, y, c)
			return stageHill(ctx, z, y, 60, 16, c)
		end },
		{ name = "Double Sweep", build = function(z, y, c)
			return stageSpin(ctx, z, y, { 1.8, -2.1 }, c)
		end },
		{ name = "Blink Panic", build = function(z, y, c)
			return stageBlink(ctx, z, y, 6, 1.5, c)
		end },
		{ name = "Glass Gauntlet", build = function(z, y)
			return stageGlass(ctx, z, y, 12, 4, 1)
		end },
	}

	local z, y = 0, Y
	for i, stage in stages do
		stageSign(ctx, i, stage.name, z, y)
		z, y = stage.build(z, y, STAGE_COLORS[i])
		local cf, pad = checkpoint(ctx, i, z, y)
		checkpoints[i] = cf
		pads[i] = pad
		names[i] = stage.name
		z += 16
	end

	-- Finish
	platform(ctx, "Finish", -20, 20, z, z + 40, y, Color3.fromRGB(255, 215, 0), Enum.Material.Foil)
	local finishPad = Parts.block(folder, {
		Name = "FinishPad",
		Size = Vector3.new(20, 0.4, 12),
		CFrame = CFrame.new(0, y + 0.2, z + 24),
		Color = Color3.fromRGB(255, 255, 255),
		Material = Enum.Material.Neon,
	})
	Parts.billboard(finishPad, "🏆 FINISH! Step here to REBIRTH", Color3.fromRGB(255, 215, 0), 8, 300)
	local trophy = Parts.block(folder, {
		Name = "Trophy",
		Size = Vector3.new(6, 8, 6),
		CFrame = CFrame.new(0, y + 6, z + 36),
		Color = Color3.fromRGB(255, 200, 40),
		Material = Enum.Material.Foil,
		Shape = Enum.PartType.Ball,
	})
	trophy.CanCollide = false

	folder.Parent = workspace
	for _, part in ctx.serverOwned do
		part:SetNetworkOwner(nil) -- the server spins the bars, so every player sees the same thing
	end
	return {
		folder = folder,
		checkpoints = checkpoints,
		checkpointPads = pads,
		stageNames = names,
		stageCount = #stages,
		finishPad = finishPad,
		startLine = startLine,
		speedPads = ctx.speedPads,
		coinSpots = ctx.coinSpots,
		tileRows = ctx.tileRows,
		killY = Y - Config.Course.FallDistance,
		length = z + 40,
	}
end

function CourseBuilder.shuffleAll(course: Course)
	local rng = Random.new()
	for _, row in course.tileRows do
		CourseBuilder.shuffleRow(row, rng)
	end
end

return CourseBuilder
