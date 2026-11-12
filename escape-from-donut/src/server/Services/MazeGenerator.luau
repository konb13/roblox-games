--!strict
-- Pure maze logic (no parts). Generates a grid maze with blocked-off "plots" where
-- houses go. Cells are (x, z), 1-indexed; z = 1 is the south row (start plaza side).
--
-- Walls:
--   eastWall[x][z]  = wall between (x, z) and (x + 1, z)
--   northWall[x][z] = wall between (x, z) and (x, z + 1)
-- Edges that touch a plot cell are ignored here; the house builds its own walls there.

local MazeGenerator = {}

export type Plot = { x: number, z: number, size: number, index: number }

export type Maze = {
	width: number,
	height: number,
	eastWall: { { boolean } },
	northWall: { { boolean } },
	plotAt: { { number } }, -- 0 = normal maze cell, otherwise plot index
	plots: { Plot },
	deadEnds: { Vector2 },
}

local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

local function grid<T>(w: number, h: number, value: T): { { T } }
	local g = {}
	for x = 1, w do
		g[x] = {}
		for z = 1, h do
			g[x][z] = value
		end
	end
	return g
end

local function inBounds(maze: Maze, x: number, z: number): boolean
	return x >= 1 and x <= maze.width and z >= 1 and z <= maze.height
end

function MazeGenerator.isOpenCell(maze: Maze, x: number, z: number): boolean
	return inBounds(maze, x, z) and maze.plotAt[x][z] == 0
end

function MazeGenerator.hasWall(maze: Maze, x: number, z: number, nx: number, nz: number): boolean
	if nx == x + 1 then
		return maze.eastWall[x][z]
	elseif nx == x - 1 then
		return maze.eastWall[nx][z]
	elseif nz == z + 1 then
		return maze.northWall[x][z]
	else
		return maze.northWall[x][nz]
	end
end

local function setWall(maze: Maze, x: number, z: number, nx: number, nz: number, value: boolean)
	if nx == x + 1 then
		maze.eastWall[x][z] = value
	elseif nx == x - 1 then
		maze.eastWall[nx][z] = value
	elseif nz == z + 1 then
		maze.northWall[x][z] = value
	else
		maze.northWall[x][nz] = value
	end
end

local function shuffle<T>(list: { T }, rng: Random)
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
end

-- Number of open passages out of a maze cell.
local function openings(maze: Maze, x: number, z: number): number
	local count = 0
	for _, d in DIRS do
		local nx, nz = x + d[1], z + d[2]
		if MazeGenerator.isOpenCell(maze, nx, nz) and not MazeGenerator.hasWall(maze, x, z, nx, nz) then
			count += 1
		end
	end
	return count
end

local function placePlots(maze: Maze, count: number, size: number, rng: Random)
	-- Keep plots off the border, out of the first 2 rows (start) and away from each other,
	-- so the remaining maze cells always stay connected.
	local minX, maxX = 2, maze.width - size
	local minZ, maxZ = 3, maze.height - size
	local attempts = 0
	while #maze.plots < count and attempts < 2000 do
		attempts += 1
		local px, pz = rng:NextInteger(minX, maxX), rng:NextInteger(minZ, maxZ)
		local free = true
		for x = px - 1, px + size do
			for z = pz - 1, pz + size do
				if inBounds(maze, x, z) and maze.plotAt[x][z] ~= 0 then
					free = false
				end
			end
		end
		if free then
			local plot: Plot = { x = px, z = pz, size = size, index = #maze.plots + 1 }
			table.insert(maze.plots, plot)
			for x = px, px + size - 1 do
				for z = pz, pz + size - 1 do
					maze.plotAt[x][z] = plot.index
				end
			end
		end
	end
	if #maze.plots < count then
		warn(`MazeGenerator: only placed {#maze.plots}/{count} house plots`)
	end
end

local function carve(maze: Maze, rng: Random)
	-- Iterative depth-first search ("recursive backtracker").
	local visited = grid(maze.width, maze.height, false)
	local stack = { Vector2.new(1, 1) }
	visited[1][1] = true
	while #stack > 0 do
		local cell = stack[#stack]
		local x, z = cell.X, cell.Y
		local options = {}
		for _, d in DIRS do
			local nx, nz = x + d[1], z + d[2]
			if MazeGenerator.isOpenCell(maze, nx, nz) and not visited[nx][nz] then
				table.insert(options, Vector2.new(nx, nz))
			end
		end
		if #options == 0 then
			table.remove(stack)
		else
			local nextCell = options[rng:NextInteger(1, #options)]
			setWall(maze, x, z, nextCell.X, nextCell.Y, false)
			visited[nextCell.X][nextCell.Y] = true
			table.insert(stack, nextCell)
		end
	end
end

-- Knock extra holes in some dead ends so there are loops to run around.
local function braid(maze: Maze, chance: number, rng: Random)
	for x = 1, maze.width do
		for z = 1, maze.height do
			if MazeGenerator.isOpenCell(maze, x, z) and openings(maze, x, z) == 1 and rng:NextNumber() < chance then
				local walled = {}
				for _, d in DIRS do
					local nx, nz = x + d[1], z + d[2]
					if MazeGenerator.isOpenCell(maze, nx, nz) and MazeGenerator.hasWall(maze, x, z, nx, nz) then
						table.insert(walled, Vector2.new(nx, nz))
					end
				end
				if #walled > 0 then
					shuffle(walled, rng)
					setWall(maze, x, z, walled[1].X, walled[1].Y, false)
				end
			end
		end
	end
end

function MazeGenerator.generate(
	width: number,
	height: number,
	plotCount: number,
	plotSize: number,
	loopChance: number,
	rng: Random
): Maze
	local maze: Maze = {
		width = width,
		height = height,
		eastWall = grid(width, height, true),
		northWall = grid(width, height, true),
		plotAt = grid(width, height, 0),
		plots = {},
		deadEnds = {},
	}
	placePlots(maze, plotCount, plotSize, rng)
	carve(maze, rng)
	braid(maze, loopChance, rng)

	for x = 1, width do
		for z = 1, height do
			if MazeGenerator.isOpenCell(maze, x, z) and openings(maze, x, z) == 1 then
				table.insert(maze.deadEnds, Vector2.new(x, z))
			end
		end
	end
	return maze
end

return MazeGenerator
