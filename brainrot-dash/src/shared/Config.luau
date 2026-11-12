--!strict
-- Central tuning values for Brainrot Dash.

local Config = {}

Config.Course = {
	Height = 100, -- the course floats this high over the void
	Width = 24,
	FallDistance = 35, -- fall this far below the course and you go back to your checkpoint
}

-- Speedrun pace: everyone runs fast.
Config.Player = {
	WalkSpeed = 24,
	JumpHeight = 7.2,
}

Config.Coins = {
	PickupValue = 5,
	RespawnTime = 15,
	FinishReward = 500,
	RebirthMultiplier = 0.5, -- each rebirth adds +50% to all coin income
}

-- Superpowers. Actives are used with number keys 1-5 (or the on-screen buttons).
export type Power = {
	id: string,
	name: string,
	icon: string,
	description: string,
	price: number,
	passive: boolean?,
	cooldown: number?,
	duration: number?,
	key: Enum.KeyCode?,
}

Config.Powers = {
	{
		id = "Zoomies",
		name = "Zoomies",
		icon = "⚡",
		description = "Run even faster for 5 seconds.",
		price = 25,
		cooldown = 12,
		duration = 5,
		key = Enum.KeyCode.One,
	},
	{
		id = "MoonBoots",
		name = "Moon Boots",
		icon = "🥾",
		description = "Giant jumps for 6 seconds.",
		price = 100,
		cooldown = 15,
		duration = 6,
		key = Enum.KeyCode.Two,
	},
	{
		id = "Parachute",
		name = "Parachute",
		icon = "🪂",
		description = "Float down slowly. Pop it while you're falling!",
		price = 250,
		cooldown = 10,
		duration = 6,
		key = Enum.KeyCode.Three,
	},
	{
		id = "XRay",
		name = "X-Ray Goggles",
		icon = "👓",
		description = "See which glass tiles are fake for 4 seconds.",
		price = 750,
		cooldown = 20,
		duration = 4,
		key = Enum.KeyCode.Four,
	},
	{
		id = "Rewind",
		name = "Rewind",
		icon = "⏪",
		description = "Teleport back to the last solid ground you stood on. Saves you mid-fall!",
		price = 1500,
		cooldown = 25,
		duration = 0,
		key = Enum.KeyCode.Five,
	},
	{
		id = "DoubleJump",
		name = "Double Jump",
		icon = "🦘",
		description = "Jump again in mid-air. Always on once bought.",
		price = 400,
		passive = true,
	},
} :: { Power }

Config.PowerTuning = {
	ZoomiesSpeed = 40,
	SpeedPadSpeed = 38, -- ⚡ pads on every checkpoint
	SpeedPadDuration = 2.5,
	MoonBootsJumpHeight = 24,
	ParachuteLift = 0.88, -- fraction of gravity cancelled while gliding
}

-- Chaos Events: one random event hits the whole server every so often.
Config.Chaos = {
	Every = 60,
	Duration = 20,
	LowGravity = 70,
	FrenzySpeed = 32,
	CoinRainCount = 30,
}

Config.DataStoreName = "BrainrotDash_v1"

return Config
