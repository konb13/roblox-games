--!strict
-- Builds one locked house on a maze plot. Each house is colour-coded and only opens
-- with the matching key. The next key in the chain sits on a pedestal inside.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Parts = require(script.Parent.Parts)
local MazeGenerator = require(script.Parent.MazeGenerator)

local HouseBuilder = {}

export type House = {
	color: string,
	model: Model,
	door: BasePart,
	center: Vector3,
	keySpot: Vector3,
}

local WOOD = Color3.fromRGB(160, 110, 70)

local function darker(c: Color3, amount: number): Color3
	return c:Lerp(Color3.new(0, 0, 0), amount)
end

-- Builds a wall running along one axis, optionally with a door gap.
-- axis "X": runs along X at z = fixed. axis "Z": runs along Z at x = fixed.
local function wall(
	parent: Instance,
	axis: string,
	a0: number,
	a1: number,
	fixed: number,
	floorY: number,
	color: Color3,
	doorCenter: number?
)
	local T = Config.Maze.WallThickness
	local H = Config.Houses.WallHeight
	local DW, DH = Config.Houses.DoorWidth, Config.Houses.DoorHeight

	local function segment(from: number, to: number, y0: number, y1: number)
		local len = to - from
		if len <= 0.05 then
			return
		end
		local mid = (from + to) / 2
		local h = y1 - y0
		local size = if axis == "X" then Vector3.new(len, h, T) else Vector3.new(T, h, len)
		local pos = if axis == "X"
			then Vector3.new(mid, floorY + y0 + h / 2, fixed)
			else Vector3.new(fixed, floorY + y0 + h / 2, mid)
		Parts.block(parent, {
			Name = "Wall",
			Size = size,
			CFrame = CFrame.new(pos),
			Color = color,
			Material = Enum.Material.Plastic,
		})
	end

	if doorCenter then
		segment(a0, doorCenter - DW / 2, 0, H)
		segment(doorCenter + DW / 2, a1, 0, H)
		segment(doorCenter - DW / 2, doorCenter + DW / 2, DH, H) -- above the door
	else
		segment(a0, a1, 0, H)
	end
end

function HouseBuilder.build(parent: Instance, maze: MazeGenerator.Maze, plot: MazeGenerator.Plot, colorName: string, rng: Random): House
	local S, T = Config.Maze.CellSize, Config.Maze.WallThickness
	local O = Config.Maze.Origin
	local H = Config.Houses.WallHeight
	local color = Config.KeyColors[colorName]
	local floorY = O.Y

	local model = Instance.new("Model")
	model.Name = colorName .. "House"

	local x0 = O.X + (plot.x - 1) * S
	local x1 = O.X + (plot.x - 1 + plot.size) * S
	local z0 = O.Z + (plot.z - 1) * S
	local z1 = O.Z + (plot.z - 1 + plot.size) * S
	local center = Vector3.new((x0 + x1) / 2, floorY, (z0 + z1) / 2)

	-- Pick a side for the door that opens onto a maze cell.
	local sides = {}
	for i = 0, plot.size - 1 do
		if MazeGenerator.isOpenCell(maze, plot.x + i, plot.z - 1) then
			table.insert(sides, { side = "S", index = i })
		end
		if MazeGenerator.isOpenCell(maze, plot.x + i, plot.z + plot.size) then
			table.insert(sides, { side = "N", index = i })
		end
		if MazeGenerator.isOpenCell(maze, plot.x - 1, plot.z + i) then
			table.insert(sides, { side = "W", index = i })
		end
		if MazeGenerator.isOpenCell(maze, plot.x + plot.size, plot.z + i) then
			table.insert(sides, { side = "E", index = i })
		end
	end
	local choice = sides[rng:NextInteger(1, #sides)]
	local doorAlongX = x0 + (choice.index + 0.5) * S
	local doorAlongZ = z0 + (choice.index + 0.5) * S

	local wallColor = color:Lerp(Color3.new(1, 1, 1), 0.55)
	wall(model, "X", x0 - T / 2, x1 + T / 2, z0, floorY, wallColor, if choice.side == "S" then doorAlongX else nil)
	wall(model, "X", x0 - T / 2, x1 + T / 2, z1, floorY, wallColor, if choice.side == "N" then doorAlongX else nil)
	wall(model, "Z", z0 + T / 2, z1 - T / 2, x0, floorY, wallColor, if choice.side == "W" then doorAlongZ else nil)
	wall(model, "Z", z0 + T / 2, z1 - T / 2, x1, floorY, wallColor, if choice.side == "E" then doorAlongZ else nil)

	-- The locked door.
	local DW, DH = Config.Houses.DoorWidth, Config.Houses.DoorHeight
	local doorPos: Vector3
	local doorRot = CFrame.identity
	if choice.side == "S" then
		doorPos = Vector3.new(doorAlongX, floorY + DH / 2, z0)
	elseif choice.side == "N" then
		doorPos = Vector3.new(doorAlongX, floorY + DH / 2, z1)
	elseif choice.side == "W" then
		doorPos = Vector3.new(x0, floorY + DH / 2, doorAlongZ)
		doorRot = CFrame.Angles(0, math.pi / 2, 0)
	else
		doorPos = Vector3.new(x1, floorY + DH / 2, doorAlongZ)
		doorRot = CFrame.Angles(0, math.pi / 2, 0)
	end
	local door = Parts.block(model, {
		Name = "Door",
		Size = Vector3.new(DW, DH, T * 0.8),
		CFrame = CFrame.new(doorPos) * doorRot,
		Color = color,
		Material = Enum.Material.SmoothPlastic,
	})
	door:SetAttribute("KeyColor", colorName)
	Parts.sign(door, `🔒 {string.upper(colorName)}`, Color3.new(1, 1, 1))

	-- Floor, roof and chimney.
	Parts.block(model, {
		Name = "Floorboards",
		Size = Vector3.new(x1 - x0 - T, 0.2, z1 - z0 - T),
		CFrame = CFrame.new(center.X, floorY + 0.1, center.Z),
		Color = WOOD,
		Material = Enum.Material.WoodPlanks,
	})
	local roof = Parts.block(model, {
		Name = "Roof",
		Size = Vector3.new(x1 - x0 + 4, 1.2, z1 - z0 + 4),
		CFrame = CFrame.new(center.X, floorY + H + 0.6, center.Z),
		Color = darker(color, 0.25),
		Material = Enum.Material.Slate,
	})
	Parts.block(model, {
		Name = "Chimney",
		Size = Vector3.new(4, 6, 4),
		CFrame = CFrame.new(x0 + 6, floorY + H + 4, z1 - 6),
		Color = Color3.fromRGB(150, 70, 60),
		Material = Enum.Material.Brick,
	})
	Parts.billboard(roof, `{string.upper(colorName)} HOUSE`, color, 6, 220)

	-- Inside: lamp, bed, table and the key pedestal.
	local lamp = Parts.block(model, {
		Name = "Lamp",
		Size = Vector3.new(3, 0.6, 3),
		CFrame = CFrame.new(center.X, floorY + H - 0.4, center.Z),
		Color = Color3.fromRGB(255, 240, 200),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local light = Instance.new("PointLight")
	light.Range = 32
	light.Brightness = 1.6
	light.Color = Color3.fromRGB(255, 230, 190)
	light.Parent = lamp

	-- Furniture goes against the wall opposite the door so the doorway stays clear.
	local inset = 7
	local backA: Vector3, backB: Vector3
	if choice.side == "S" then
		backA, backB = Vector3.new(x0 + inset, 0, z1 - inset - 2), Vector3.new(x1 - inset, 0, z1 - inset)
	elseif choice.side == "N" then
		backA, backB = Vector3.new(x0 + inset, 0, z0 + inset - 2), Vector3.new(x1 - inset, 0, z0 + inset)
	elseif choice.side == "W" then
		backA, backB = Vector3.new(x1 - inset, 0, z0 + inset - 2), Vector3.new(x1 - inset, 0, z1 - inset)
	else
		backA, backB = Vector3.new(x0 + inset, 0, z0 + inset - 2), Vector3.new(x0 + inset, 0, z1 - inset)
	end
	local bedX, bedZ = backA.X, backA.Z
	Parts.block(model, {
		Name = "Bed",
		Size = Vector3.new(7, 1.6, 10),
		CFrame = CFrame.new(bedX, floorY + 1, bedZ + 2),
		Color = WOOD,
		Material = Enum.Material.Wood,
	})
	Parts.block(model, {
		Name = "Blanket",
		Size = Vector3.new(7.2, 0.6, 7),
		CFrame = CFrame.new(bedX, floorY + 2, bedZ + 3.5),
		Color = color,
		Material = Enum.Material.Fabric,
	})
	Parts.block(model, {
		Name = "Pillow",
		Size = Vector3.new(5, 0.8, 2),
		CFrame = CFrame.new(bedX, floorY + 2.1, bedZ - 1.8),
		Color = Color3.new(1, 1, 1),
		Material = Enum.Material.Fabric,
	})
	Parts.block(model, {
		Name = "Table",
		Size = Vector3.new(6, 0.5, 6),
		CFrame = CFrame.new(backB.X, floorY + 3, backB.Z),
		Color = WOOD,
		Material = Enum.Material.Wood,
	})
	Parts.block(model, {
		Name = "TableLeg",
		Size = Vector3.new(1, 3, 1),
		CFrame = CFrame.new(backB.X, floorY + 1.5, backB.Z),
		Color = WOOD,
		Material = Enum.Material.Wood,
	})
	Parts.block(model, {
		Name = "Pedestal",
		Size = Vector3.new(4, 4, 4),
		CFrame = CFrame.new(center.X, floorY + 2, center.Z) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(240, 240, 240),
		Material = Enum.Material.Marble,
		Shape = Enum.PartType.Cylinder,
	})

	model.Parent = parent
	return {
		color = colorName,
		model = model,
		door = door,
		center = center,
		keySpot = Vector3.new(center.X, floorY + 6, center.Z),
	}
end

return HouseBuilder
