--!strict
-- Buying and using superpowers. The server owns prices, ownership and cooldowns.
-- Zoomies and Moon Boots change the humanoid here; Parachute, X-Ray and Rewind run on
-- the player's own client (see Powers.client.luau) after the server says "go".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

local PowerService = {}

local lastUse: { [Player]: { [string]: number } } = {}
local zoomUntil: { [Player]: number } = {}
local moonUntil: { [Player]: number } = {}
local frenzy = false

local function powerInfo(id: string): Config.Power?
	for _, p in Config.Powers do
		if p.id == id then
			return p
		end
	end
	return nil
end

-- Applies walk speed / jump height from base values, Chaos Events and active powers.
function PowerService.refreshMovement(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local now = os.clock()
	local speed = if frenzy then Config.Chaos.FrenzySpeed else Config.Player.WalkSpeed
	if (zoomUntil[player] or 0) > now then
		speed = math.max(speed, Config.PowerTuning.ZoomiesSpeed)
	end
	humanoid.UseJumpPower = false
	humanoid.WalkSpeed = speed
	humanoid.JumpHeight = if (moonUntil[player] or 0) > now then Config.PowerTuning.MoonBootsJumpHeight else Config.Player.JumpHeight
end

function PowerService.setFrenzy(on: boolean)
	frenzy = on
	for _, player in Players:GetPlayers() do
		PowerService.refreshMovement(player)
	end
end

function PowerService.init()
	local activated = Remotes.event("PowerActivated")

	Remotes.func("BuyPower").OnServerInvoke = function(player: Player, id: any): (boolean, string)
		if typeof(id) ~= "string" then
			return false, "Unknown power"
		end
		local p = powerInfo(id)
		local profile = DataService.get(player)
		if not p then
			return false, "Unknown power"
		elseif not profile then
			return false, "Still loading, try again!"
		elseif profile.powers[id] then
			return false, "You already own it!"
		elseif not DataService.spendCoins(player, p.price) then
			return false, `You need {p.price} coins`
		end
		DataService.grantPower(player, id)
		return true, `You got {p.icon} {p.name}!`
	end

	Remotes.event("UsePower").OnServerEvent:Connect(function(player: Player, id: any)
		if typeof(id) ~= "string" then
			return
		end
		local p = powerInfo(id)
		local profile = DataService.get(player)
		if not p or p.passive or not profile or not profile.powers[id] then
			return
		end
		local now = os.clock()
		local uses = lastUse[player] or {}
		lastUse[player] = uses
		if now - (uses[id] or -math.huge) < (p.cooldown or 0) then
			return
		end
		uses[id] = now
		local duration = p.duration or 0

		if id == "Zoomies" then
			zoomUntil[player] = now + duration
		elseif id == "MoonBoots" then
			moonUntil[player] = now + duration
		end
		PowerService.refreshMovement(player)
		if duration > 0 then
			task.delay(duration + 0.05, PowerService.refreshMovement, player)
		end
		activated:FireClient(player, id, duration, p.cooldown or 0)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastUse[player] = nil
		zoomUntil[player] = nil
		moonUntil[player] = nil
	end)
end

return PowerService
