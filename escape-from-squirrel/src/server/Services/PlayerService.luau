--!strict
-- Leaderstats (Coins, Escapes) and player roles.
-- Role attribute values: "Lobby", "Runner", "Minion", "Escaped".
-- NOTE: coins are not saved between sessions yet (DataStore saving comes in Stage 5).

local Players = game:GetService("Players")

local PlayerService = {}

local function setup(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = stats
	local escapes = Instance.new("IntValue")
	escapes.Name = "Escapes"
	escapes.Parent = stats
	stats.Parent = player
	player:SetAttribute("Role", "Lobby")
end

function PlayerService.init()
	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do
		if not player:FindFirstChild("leaderstats") then
			setup(player)
		end
	end
end

local function stat(player: Player, name: string): IntValue?
	local stats = player:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild(name)
	if value and value:IsA("IntValue") then
		return value
	end
	return nil
end

function PlayerService.addCoins(player: Player, amount: number)
	local coins = stat(player, "Coins")
	if coins then
		coins.Value += amount
	end
end

function PlayerService.addEscape(player: Player)
	local escapes = stat(player, "Escapes")
	if escapes then
		escapes.Value += 1
	end
end

function PlayerService.getRole(player: Player): string
	local role = player:GetAttribute("Role")
	return if typeof(role) == "string" then role else "Lobby"
end

function PlayerService.setRole(player: Player, role: string)
	player:SetAttribute("Role", role)
end

function PlayerService.withRole(role: string): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if PlayerService.getRole(player) == role then
			table.insert(list, player)
		end
	end
	return list
end

function PlayerService.aliveRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

return PlayerService
