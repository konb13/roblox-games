--!strict
-- Saves each player's progress with DataStoreService: coins, rebirths, best stage,
-- rescued brainrots, bought powers and equipped pet.
--
-- In Studio, saving only works after Home → Game Settings → Security →
-- "Enable Studio Access to API Services". Without it the game still runs, it just
-- doesn't remember anything.
--
-- Clients see the data through leaderstats (Coins, Stage, Rebirths) and attributes:
--   Brainrot_<id> = true, Power_<id> = true, Pet = <id>, Income = coins per second

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Brainrots = require(ReplicatedStorage.Shared.Brainrots)

local DataService = {}

export type Profile = {
	coins: number,
	rebirths: number,
	bestStage: number,
	brainrots: { [string]: boolean },
	powers: { [string]: boolean },
	pet: string?,
}

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("DataService: saving disabled (", result, ")")
	end
end

local profiles: { [Player]: Profile } = {}
local loaded: { [Player]: boolean } = {}

local function defaultProfile(): Profile
	return { coins = 0, rebirths = 0, bestStage = 0, brainrots = {}, powers = {}, pet = nil }
end

local function key(player: Player): string
	return "player_" .. player.UserId
end

local function stat(player: Player, name: string): IntValue?
	local stats = player:FindFirstChild("leaderstats")
	local v = stats and stats:FindFirstChild(name)
	return if v and v:IsA("IntValue") then v else nil
end

local function syncStats(player: Player, profile: Profile)
	local coins, stage, rebirths = stat(player, "Coins"), stat(player, "Stage"), stat(player, "Rebirths")
	if coins then
		coins.Value = math.floor(profile.coins)
	end
	if stage then
		stage.Value = profile.bestStage
	end
	if rebirths then
		rebirths.Value = profile.rebirths
	end
end

function DataService.multiplier(player: Player): number
	local profile = profiles[player]
	return 1 + (if profile then profile.rebirths else 0) * Config.Coins.RebirthMultiplier
end

function DataService.income(player: Player): number
	local profile = profiles[player]
	if not profile then
		return 0
	end
	local total = 0
	for id in profile.brainrots do
		local info = Brainrots.get(id)
		if info then
			total += info.income
		end
	end
	return total * DataService.multiplier(player)
end

local function syncAll(player: Player, profile: Profile)
	syncStats(player, profile)
	for id in profile.brainrots do
		player:SetAttribute("Brainrot_" .. id, true)
	end
	for id in profile.powers do
		player:SetAttribute("Power_" .. id, true)
	end
	player:SetAttribute("Pet", profile.pet)
	player:SetAttribute("Income", DataService.income(player))
end

function DataService.load(player: Player): Profile
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, name in { "Coins", "Stage", "Rebirths" } do
		local v = Instance.new("IntValue")
		v.Name = name
		v.Parent = stats
	end
	stats.Parent = player

	local profile = defaultProfile()
	local s = store
	if s then
		local ok, data = pcall(function()
			return s:GetAsync(key(player))
		end)
		if ok and typeof(data) == "table" then
			profile.coins = tonumber(data.coins) or 0
			profile.rebirths = tonumber(data.rebirths) or 0
			profile.bestStage = tonumber(data.bestStage) or 0
			profile.brainrots = if typeof(data.brainrots) == "table" then data.brainrots else {}
			profile.powers = if typeof(data.powers) == "table" then data.powers else {}
			profile.pet = if typeof(data.pet) == "string" then data.pet else nil
		elseif not ok then
			warn("DataService: could not load", player.Name, data)
		end
	end
	profiles[player] = profile
	loaded[player] = true
	syncAll(player, profile)
	return profile
end

function DataService.save(player: Player)
	local profile = profiles[player]
	local s = store
	if not profile or not s or not loaded[player] then
		return
	end
	local ok, err = pcall(function()
		s:SetAsync(key(player), {
			coins = math.floor(profile.coins),
			rebirths = profile.rebirths,
			bestStage = profile.bestStage,
			brainrots = profile.brainrots,
			powers = profile.powers,
			pet = profile.pet,
		})
	end)
	if not ok then
		warn("DataService: could not save", player.Name, err)
	end
end

function DataService.get(player: Player): Profile?
	return profiles[player]
end

function DataService.addCoins(player: Player, amount: number)
	local profile = profiles[player]
	if profile then
		profile.coins += amount
		syncStats(player, profile)
	end
end

function DataService.spendCoins(player: Player, amount: number): boolean
	local profile = profiles[player]
	if not profile or profile.coins < amount then
		return false
	end
	profile.coins -= amount
	syncStats(player, profile)
	return true
end

function DataService.setBestStage(player: Player, stage: number)
	local profile = profiles[player]
	if profile and stage > profile.bestStage then
		profile.bestStage = stage
		syncStats(player, profile)
	end
end

function DataService.addRebirth(player: Player)
	local profile = profiles[player]
	if profile then
		profile.rebirths += 1
		syncAll(player, profile)
	end
end

-- Returns true if this is a new brainrot for the player.
function DataService.grantBrainrot(player: Player, id: string): boolean
	local profile = profiles[player]
	if not profile or profile.brainrots[id] then
		return false
	end
	profile.brainrots[id] = true
	profile.pet = id -- newest rescue follows you around
	syncAll(player, profile)
	return true
end

function DataService.grantPower(player: Player, id: string)
	local profile = profiles[player]
	if profile then
		profile.powers[id] = true
		player:SetAttribute("Power_" .. id, true)
	end
end

function DataService.setPet(player: Player, id: string)
	local profile = profiles[player]
	if profile and profile.brainrots[id] then
		profile.pet = id
		player:SetAttribute("Pet", id)
	end
end

function DataService.init()
	Players.PlayerRemoving:Connect(function(player)
		DataService.save(player)
		profiles[player] = nil
		loaded[player] = nil
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			task.spawn(DataService.save, player)
		end
		task.wait(2)
	end)
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				task.spawn(DataService.save, player)
			end
		end
	end)
end

return DataService
