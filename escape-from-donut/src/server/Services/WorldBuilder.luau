--!strict
-- Turns a generated maze into a playable world: floor, hedge walls, start plaza,
-- houses, the Exit Gate and the escape pad. Also builds the lobby once at startup.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Parts = require(script.Parent.Parts)
local MazeGenerator = require(script.Parent.MazeGenerator)
local HouseBuilder = require(script.Parent.HouseBuilder)

local WorldBuilder = {}

export type World = {
	folder: Folder,
	maze: MazeGenerator.Maze,
	floorY: number,
	houses: { HouseBuilder.House },
	startPositions: { Vector3 },
	donutSpawn: Vector3,
	exitGate: BasePart,
	exitPad: BasePart,
	cellCenter: (x: number, z: number) -> Vector3,
	randomOpenCell: (rng: Random, minZ: number?, maxZ: number?) -> Vector3,
}

local HEDGE = Color3.fromRGB(64, 140, 70)
local GRASS = Color3.fromRGB(110, 190, 95)
local PLAZA = Color3.fromRGB(255, 214, 230)

local function cellCenter(x: number, z: number): Vector3
	local S, O = Config.Maze.CellSize, Config.Maze.Origin
	return Vector3.new(O.X + (x - 0.5) * S, O.Y, O.Z + (z - 0.5) * S)
end

-- Builds walls along one family of grid lines, merging neighbouring segments into one part.
-- isWall(line, i) says whether segment i (1..count) on grid line `line` has a wall.
local function buildWallLines(
	parent: Instance,
	lines: number,
	count: number,
	alongX: boolean,
	isWall: (line: number, i: number) -> boolean
)
	local S, T, H, O = Config.Maze.CellSize, Config.Maze.WallThickness, Config.Maze.WallHeight, Config.Maze.Origin
	for line = 0, lines do
		local runStart: number? = nil
		for i = 1, count + 1 do
			local wallHere = i <= count and isWall(line, i)
			if wallHere and not runStart then
				runStart = i
			elseif not wallHere and runStart then
				local a, b = runStart, i - 1
				local length = (b - a + 1) * S + T
				local mid = ((a - 1) + b) / 2 * S
				local size, pos
				if alongX then
					size = Vector3.new(length, H, T)
					pos = Vector3.new(O.X + mid, O.Y + H / 2, O.Z + line * S)
				else
					size = Vector3.new(T, H, length)
					pos = Vector3.new(O.X + line * S, O.Y + H / 2, O.Z + mid)
				end
				Parts.block(parent, {
					Name = "Hedge",
					Size = size,
					CFrame = CFrame.new(pos),
					Color = HEDGE,
					Material = Enum.Material.LeafyGrass,
				})
				runStart = nil
			end
		end
	end
end

function WorldBuilder.build(rng: Random): World
	local mc = Config.Maze
	local S, T, O = mc.CellSize, mc.WallThickness, mc.Origin
	local W, H = mc.Width, mc.Height
	local colors = Config.Houses.Colors

	local folder = Instance.new("Folder")
	folder.Name = "Arena"

	local maze = MazeGenerator.generate(W, H, #colors, Config.Houses.SizeCells, mc.LoopChance, rng)

	local function isPlot(x: number, z: number): boolean
		return x >= 1 and x <= W and z >= 1 and z <= H and maze.plotAt[x][z] ~= 0
	end

	-- Floors
	Parts.block(folder, {
		Name = "MazeFloor",
		Size = Vector3.new(W * S, 2, H * S),
		CFrame = CFrame.new(O.X + W * S / 2, O.Y - 1, O.Z + H * S / 2),
		Color = GRASS,
		Material = Enum.Material.Grass,
	})
	Parts.block(folder, {
		Name = "PlazaFloor",
		Size = Vector3.new(W * S, 2, mc.PlazaDepth),
		CFrame = CFrame.new(O.X + W * S / 2, O.Y - 1, O.Z - mc.PlazaDepth / 2),
		Color = PLAZA,
		Material = Enum.Material.Pavement,
	})

	-- Walls that run north-south (grid lines of constant X).
	buildWallLines(folder, W, H, false, function(line, z)
		if line == 0 or line == W then
			return true
		end
		if isPlot(line, z) or isPlot(line + 1, z) then
			return false
		end
		return maze.eastWall[line][z]
	end)

	-- Walls that run east-west (grid lines of constant Z).
	local entrances = {}
	for _, col in mc.EntranceColumns do
		entrances[col] = true
	end
	buildWallLines(folder, H, W, true, function(line, x)
		if line == 0 then
			return not entrances[x]
		elseif line == H then
			return x ~= mc.ExitColumn
		end
		if isPlot(x, line) or isPlot(x, line + 1) then
			return false
		end
		return maze.northWall[x][line]
	end)

	-- Plaza fences (west, east, south).
	local plazaZ = O.Z - mc.PlazaDepth / 2
	for _, x in { O.X, O.X + W * S } do
		Parts.block(folder, {
			Name = "Fence",
			Size = Vector3.new(T, mc.WallHeight, mc.PlazaDepth),
			CFrame = CFrame.new(x, O.Y + mc.WallHeight / 2, plazaZ),
			Color = HEDGE,
			Material = Enum.Material.LeafyGrass,
		})
	end
	Parts.block(folder, {
		Name = "Fence",
		Size = Vector3.new(W * S + T, mc.WallHeight, T),
		CFrame = CFrame.new(O.X + W * S / 2, O.Y + mc.WallHeight / 2, O.Z - mc.PlazaDepth),
		Color = HEDGE,
		Material = Enum.Material.LeafyGrass,
	})
	local title = Parts.block(folder, {
		Name = "TitleSign",
		Size = Vector3.new(60, 12, 1),
		CFrame = CFrame.new(O.X + W * S / 2, O.Y + mc.WallHeight + 8, O.Z - mc.PlazaDepth + 1),
		Color = Color3.fromRGB(255, 120, 180),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	Parts.sign(title, "🍩 ESCAPE FROM DONUT 🍩", Color3.new(1, 1, 1))

	-- Exit Gate in the north wall and the escape room behind it.
	local exitCenter = cellCenter(mc.ExitColumn, H)
	local northZ = O.Z + H * S
	local exitGate = Parts.block(folder, {
		Name = "ExitGate",
		Size = Vector3.new(S - T, mc.WallHeight, T),
		CFrame = CFrame.new(exitCenter.X, O.Y + mc.WallHeight / 2, northZ),
		Color = Config.KeyColors.Master,
		Material = Enum.Material.Metal,
	})
	Parts.sign(exitGate, "EXIT\n🔑 MASTER KEY", Color3.new(1, 1, 1))
	Parts.billboard(exitGate, "🚪 EXIT", Config.KeyColors.Master, mc.WallHeight / 2 + 5, 400)

	local roomDepth = 30
	local roomWidth = S + T
	Parts.block(folder, {
		Name = "ExitFloor",
		Size = Vector3.new(roomWidth, 2, roomDepth),
		CFrame = CFrame.new(exitCenter.X, O.Y - 1, northZ + roomDepth / 2),
		Color = PLAZA,
		Material = Enum.Material.Pavement,
	})
	for _, side in { -1, 1 } do
		Parts.block(folder, {
			Name = "ExitWall",
			Size = Vector3.new(T, mc.WallHeight, roomDepth),
			CFrame = CFrame.new(exitCenter.X + side * roomWidth / 2, O.Y + mc.WallHeight / 2, northZ + roomDepth / 2),
			Color = HEDGE,
			Material = Enum.Material.LeafyGrass,
		})
	end
	Parts.block(folder, {
		Name = "ExitWall",
		Size = Vector3.new(roomWidth + T, mc.WallHeight, T),
		CFrame = CFrame.new(exitCenter.X, O.Y + mc.WallHeight / 2, northZ + roomDepth),
		Color = HEDGE,
		Material = Enum.Material.LeafyGrass,
	})
	local exitPad = Parts.block(folder, {
		Name = "ExitPad",
		Size = Vector3.new(14, 1, 14),
		CFrame = CFrame.new(exitCenter.X, O.Y + 0.5, northZ + roomDepth / 2 + 2),
		Color = Color3.fromRGB(80, 255, 120),
		Material = Enum.Material.Neon,
	})

	-- Houses
	local houses = {}
	for i, plot in maze.plots do
		table.insert(houses, HouseBuilder.build(folder, maze, plot, colors[i], rng))
	end

	-- Start positions spread across the plaza.
	local startPositions = {}
	for i = 1, 12 do
		local x = O.X + (i - 0.5) / 12 * W * S
		table.insert(startPositions, Vector3.new(x, O.Y + 4, O.Z - mc.PlazaDepth * 0.4))
	end

	local function randomOpenCell(random: Random, minZ: number?, maxZ: number?): Vector3
		for _ = 1, 200 do
			local x = random:NextInteger(1, W)
			local z = random:NextInteger(minZ or 1, maxZ or H)
			if MazeGenerator.isOpenCell(maze, x, z) then
				return cellCenter(x, z)
			end
		end
		return cellCenter(1, 1)
	end

	-- The donut starts near the middle of the maze.
	local mid = math.ceil(W / 2)
	local donutSpawn = cellCenter(1, 1)
	for radius = 0, 5 do
		local found = false
		for dx = -radius, radius do
			for dz = -radius, radius do
				if not found and MazeGenerator.isOpenCell(maze, mid + dx, mid + dz) then
					donutSpawn = cellCenter(mid + dx, mid + dz)
					found = true
				end
			end
		end
		if found then
			break
		end
	end

	folder.Parent = workspace

	return {
		folder = folder,
		maze = maze,
		floorY = O.Y,
		houses = houses,
		startPositions = startPositions,
		donutSpawn = donutSpawn,
		exitGate = exitGate,
		exitPad = exitPad,
		cellCenter = cellCenter,
		randomOpenCell = randomOpenCell,
	}
end

-- The lobby: a floating island where players wait between rounds.
function WorldBuilder.buildLobby(): SpawnLocation
	local L = Config.Lobby
	local folder = Instance.new("Folder")
	folder.Name = "Lobby"

	Parts.block(folder, {
		Name = "LobbyFloor",
		Size = Vector3.new(L.Size, 2, L.Size),
		CFrame = CFrame.new(L.Position - Vector3.new(0, 1, 0)),
		Color = PLAZA,
		Material = Enum.Material.Pavement,
	})
	for _, offset in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
		local alongX = offset.Z ~= 0
		Parts.block(folder, {
			Name = "LobbyRail",
			Size = if alongX then Vector3.new(L.Size, 4, 1) else Vector3.new(1, 4, L.Size),
			CFrame = CFrame.new(L.Position + offset * (L.Size / 2) + Vector3.new(0, 2, 0)),
			Color = Color3.fromRGB(255, 150, 200),
			Material = Enum.Material.SmoothPlastic,
		})
	end
	local sign = Parts.block(folder, {
		Name = "LobbySign",
		Size = Vector3.new(40, 10, 1),
		CFrame = CFrame.new(L.Position + Vector3.new(0, 10, L.Size / 2 - 2)),
		Color = Color3.fromRGB(255, 120, 180),
		CanCollide = false,
	})
	Parts.sign(sign, "🍩 ESCAPE FROM DONUT 🍩\nNext round starting soon!", Color3.new(1, 1, 1))

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(L.Position + Vector3.new(0, 0.5, 0))
	spawn.Color = Color3.fromRGB(255, 105, 180)
	spawn.Material = Enum.Material.Neon
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = folder

	folder.Parent = workspace
	return spawn
end

return WorldBuilder
