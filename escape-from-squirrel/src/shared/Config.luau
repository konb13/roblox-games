--!strict
-- Central tuning values for Escape from Squirrel.
-- Change numbers here to rebalance the game without touching any other script.

local Config = {}

Config.Round = {
	MinPlayers = 1,
	IntermissionTime = 15,
	HeadStartTime = 12, -- the squirrel naps in its oak while runners get going
	RoundTime = 420,
	SecondSquirrelAt = 240, -- seconds into the chase
	ResultsTime = 8,
}

Config.World = {
	HalfSize = 320, -- the town is 640 x 640 studs, centred on (0, 0, 0)
	RoadLines = { -160, 160 }, -- roads run along both axes at these coordinates
	RoadWidth = 28,
	FenceHeight = 30,
	Gravity = 150, -- a bit floatier than Roblox's 196.2 so car jumps feel good
}

Config.Squirrel = {
	Scale = 1,
	BaseSpeed = 15, -- runners walk at 16...
	SpeedGain = 1, -- ...but the squirrel keeps getting faster
	SpeedGainEvery = 25,
	MaxSpeed = 24,
	CatchDistance = 9,
	AgentRadius = 5,
	RepathInterval = 0.5,
	BuildingMargin = 6, -- how close to a building wall the squirrel's centre may get
	-- Pounce: crouch (with a ❗ warning), then leap at where the target is heading.
	PounceMinRange = 14,
	PounceMaxRange = 42,
	PounceWindup = 0.65,
	PounceDuration = 0.85,
	PounceHeight = 14,
	PounceCooldown = 4,
	RecoverTime = 0.6,
	AcornTargetBonus = 25, -- each carried acorn makes you look this many studs "closer"
}

Config.Minion = { Scale = 0.32, WalkSpeed = 18, CatchDistance = 5 }

Config.Acorns = {
	ActiveCount = 30, -- golden acorns lying around at once
	MaxCarry = 5,
	RespawnDelay = 15,
	GoalPerRunner = 5, -- team goal = runners x this, clamped below
	MinGoal = 10,
	MaxGoal = 30,
}

Config.Rewards = {
	AcornDeposit = 5, -- coins per acorn banked
	Escape = 60,
	Survive = 20,
	CatchAsMinion = 10,
	AirTimeMin = 0.6, -- seconds in the air before a jump pays out
	AirTimeCoinsPerSecond = 10,
}

-- Vehicles. MaxSpeed in studs/second. Steering in degrees.
Config.Vehicles = {
	Kart = {
		DisplayName = "Go-Kart",
		ChassisSize = Vector3.new(5, 1.2, 8),
		WheelRadius = 1.3,
		WheelWidth = 1.2,
		MaxSpeed = 75,
		Torque = 9000,
		SteerAngle = 32,
		Color = Color3.fromRGB(230, 50, 50),
		Passengers = 0,
	},
	Roadster = {
		DisplayName = "Volt Roadster",
		ChassisSize = Vector3.new(6.5, 1.4, 12),
		WheelRadius = 1.5,
		WheelWidth = 1.3,
		MaxSpeed = 95,
		Torque = 14000,
		SteerAngle = 28,
		Color = Color3.fromRGB(245, 245, 250),
		Passengers = 1,
	},
	Truck = {
		DisplayName = "Monster Truck",
		ChassisSize = Vector3.new(8, 2, 13),
		WheelRadius = 3,
		WheelWidth = 2.4,
		MaxSpeed = 62,
		Torque = 30000,
		SteerAngle = 30,
		Color = Color3.fromRGB(60, 120, 230),
		Passengers = 2,
	},
	Mower = {
		DisplayName = "Lawn Mower",
		ChassisSize = Vector3.new(4.5, 1.5, 6),
		WheelRadius = 1.1,
		WheelWidth = 1,
		MaxSpeed = 38,
		Torque = 6000,
		SteerAngle = 38,
		Color = Color3.fromRGB(70, 180, 70),
		Passengers = 0,
	},
}

Config.VehicleTuning = {
	DriveSign = -1, -- flip to 1 if every car drives backwards
	SteerSign = -1, -- flip to 1 if steering is reversed
	ReverseFactor = 0.5,
	BoostMultiplier = 1.6,
	BoostDuration = 3,
	IdleRespawnTime = 45, -- an empty car far from home goes back after this long
}

Config.Lobby = {
	Position = Vector3.new(0, 0, -480),
	Size = 90,
}

Config.RunnerWalkSpeed = 16

return Config
