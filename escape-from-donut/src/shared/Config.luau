--!strict
-- Central tuning values for Escape from Donut.
-- Change numbers here to rebalance the game without touching any other script.

local Config = {}

Config.Round = {
	MinPlayers = 1,
	IntermissionTime = 15, -- lobby countdown (seconds)
	HeadStartTime = 10, -- runners move before the donut wakes up
	RoundTime = 360, -- max chase length
	SecondDonutAt = 180, -- seconds into the chase when a 2nd donut appears
	ResultsTime = 8,
}

Config.Maze = {
	Width = 21, -- cells
	Height = 21, -- cells
	CellSize = 20, -- studs per cell
	WallHeight = 16,
	WallThickness = 2,
	LoopChance = 0.4, -- chance each dead end gets an extra opening (more escape routes)
	Origin = Vector3.new(0, 0, 0), -- south-west corner of the maze, floor level
	PlazaDepth = 60, -- start plaza south of the maze
	EntranceColumns = { 4, 11, 18 }, -- openings from the plaza into the maze
	ExitColumn = 11, -- the Exit Gate sits in the north wall above this column
}

Config.Houses = {
	-- Order of the key chain: the Red key is loose in the maze, the Red house holds the
	-- Blue key, ... the last house holds the Master Key for the Exit Gate.
	Colors = { "Red", "Blue", "Green", "Yellow" },
	SizeCells = 2,
	WallHeight = 14,
	DoorWidth = 12,
	DoorHeight = 11,
}

Config.KeyColors = {
	Red = Color3.fromRGB(235, 64, 52),
	Blue = Color3.fromRGB(52, 120, 235),
	Green = Color3.fromRGB(60, 200, 90),
	Yellow = Color3.fromRGB(245, 205, 50),
	Master = Color3.fromRGB(255, 170, 0),
	Donut = Color3.fromRGB(255, 105, 180),
}

Config.Donut = {
	Scale = 1,
	BaseSpeed = 14, -- players walk at 16, so the donut starts slower...
	SpeedGain = 1, -- ...but gains speed over time
	SpeedGainEvery = 20,
	MaxSpeed = 23,
	CatchDistance = 7.5,
	AgentRadius = 3.5,
	RepathInterval = 0.4,
	DirectChaseRange = 14, -- inside this range with clear sight, skip pathfinding
}

Config.MiniDonut = { Scale = 0.45, WalkSpeed = 18, CatchDistance = 4.5 }
Config.RogueDonut = { Scale = 0.8, WalkSpeed = 21, CatchDistance = 6.5 }

Config.DonutKey = {
	SpawnChance = 0.5, -- chance a round contains a Donut Key
}

Config.Rewards = {
	Escape = 50,
	Survive = 15,
	KeyPickup = 5,
	DoorOpened = 10,
	CatchAsMini = 10,
	CatchAsRogue = 20,
}

Config.Lobby = {
	Position = Vector3.new(-200, 0, 200),
	Size = 90,
}

Config.RunnerWalkSpeed = 16

return Config
