--!strict
-- Chaos Events: every minute something silly happens to the whole server.
-- Clients read ReplicatedStorage attributes ChaosEvent (name) and ChaosEnds (server time).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CourseBuilder = require(script.Parent.CourseBuilder)
local PowerService = require(script.Parent.PowerService)

local ChaosService = {}

type Hooks = {
	announce: (text: string, kind: string?) -> (),
	coinRain: (count: number) -> (),
}

local EVENTS = {
	{
		id = "LowGravity",
		text = "🌙 LOW GRAVITY! Everything floats!",
		duration = Config.Chaos.Duration,
	},
	{
		id = "SpeedFrenzy",
		text = "⚡ SPEED FRENZY! Everyone is zooming!",
		duration = Config.Chaos.Duration,
	},
	{
		id = "CoinRain",
		text = "💰 COIN RAIN! Grab them before they vanish!",
		duration = Config.Chaos.Duration,
	},
	{
		id = "TileShuffle",
		text = "🔀 TILE SHUFFLE! The fake glass tiles have moved!",
		duration = 5,
	},
}

function ChaosService.start(course: CourseBuilder.Course, hooks: Hooks)
	local normalGravity = workspace.Gravity
	ReplicatedStorage:SetAttribute("ChaosEvent", "")
	task.spawn(function()
		local rng = Random.new()
		local last = ""
		while true do
			task.wait(Config.Chaos.Every)
			local event = EVENTS[rng:NextInteger(1, #EVENTS)]
			if event.id == last then
				event = EVENTS[(table.find(EVENTS, event) :: number) % #EVENTS + 1]
			end
			last = event.id

			ReplicatedStorage:SetAttribute("ChaosEnds", workspace:GetServerTimeNow() + event.duration)
			ReplicatedStorage:SetAttribute("ChaosEvent", event.id)
			hooks.announce(event.text, "danger")

			if event.id == "LowGravity" then
				workspace.Gravity = Config.Chaos.LowGravity
			elseif event.id == "SpeedFrenzy" then
				PowerService.setFrenzy(true)
			elseif event.id == "CoinRain" then
				hooks.coinRain(Config.Chaos.CoinRainCount)
			elseif event.id == "TileShuffle" then
				CourseBuilder.shuffleAll(course)
			end

			task.wait(event.duration)

			workspace.Gravity = normalGravity
			PowerService.setFrenzy(false)
			ReplicatedStorage:SetAttribute("ChaosEvent", "")
		end
	end)
end

return ChaosService
