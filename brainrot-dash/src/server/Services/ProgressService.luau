--!strict
-- Checkpoints, falling, rescuing brainrots, coins, passive income and rebirths.
-- Player attributes used by the client: Checkpoint (stage number), Falls.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Brainrots = require(ReplicatedStorage.Shared.Brainrots)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CourseBuilder = require(script.Parent.CourseBuilder)
local DataService = require(script.Parent.DataService)
local PowerService = require(script.Parent.PowerService)
local Parts = require(script.Parent.Parts)

local ProgressService = {}

local course: CourseBuilder.Course
local announceRemote: RemoteEvent
local fellRemote: RemoteEvent
local coinFolder: Folder

function ProgressService.announce(text: string, kind: string?, target: Player?)
	if target then
		announceRemote:FireClient(target, text, kind or "info")
	else
		announceRemote:FireAllClients(text, kind or "info")
	end
end
local announce = ProgressService.announce

local function checkpointOf(player: Player): number
	local c = player:GetAttribute("Checkpoint")
	return if typeof(c) == "number" then c else 0
end

local function sendToCheckpoint(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if character and root and root:IsA("BasePart") then
		local cf = course.checkpoints[checkpointOf(player)] or course.checkpoints[0]
		character:PivotTo(cf)
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

local function rescue(player: Player, stage: number)
	local info = Brainrots.forStage(stage)
	if info and DataService.grantBrainrot(player, info.id) then
		announce(`🧠 You rescued {info.name}! "{info.chant}" ({info.rarity}, +{info.income} coins/s)`, "good", player)
		if info.rarity == "Legendary" or info.rarity == "Mythic" then
			announce(`🌟 {player.DisplayName} rescued the {info.rarity} {info.name}!`, "good")
		end
	end
end

local function reachCheckpoint(player: Player, stage: number)
	if stage <= checkpointOf(player) then
		return
	end
	player:SetAttribute("Checkpoint", stage)
	DataService.setBestStage(player, stage)
	announce(`✅ Checkpoint! Stage {stage}: {course.stageNames[stage]} cleared`, "good", player)
	rescue(player, stage)
end

local function rebirth(player: Player)
	if checkpointOf(player) < course.stageCount then
		return
	end
	-- Stop the run timer.
	local started = player:GetAttribute("RunStart")
	player:SetAttribute("RunStart", nil)
	if typeof(started) == "number" then
		local seconds = workspace:GetServerTimeNow() - started
		local timeText = DataService.formatTime(seconds)
		if DataService.submitTime(player, seconds) then
			announce(`⏱️ {player.DisplayName} set a NEW BEST TIME: {timeText}!`, "good")
		else
			announce(`⏱️ Your time: {timeText}`, "info", player)
		end
	end
	DataService.addRebirth(player)
	local reward = Config.Coins.FinishReward * DataService.multiplier(player)
	DataService.addCoins(player, reward)
	player:SetAttribute("Checkpoint", 0)
	local profile = DataService.get(player)
	local rebirths = if profile then profile.rebirths else 1
	announce(`🏆 {player.DisplayName} finished the course! Rebirth #{rebirths}`, "good")
	announce(`+{math.floor(reward)} coins. Your coin income is now x{DataService.multiplier(player)}!`, "good", player)
	sendToCheckpoint(player)
end

-- ------------------------------------------------------------------ coins

local function spawnCoin(position: Vector3, respawn: boolean)
	local coin = Instance.new("Part")
	coin.Name = "Coin"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(0.4, 3, 3)
	coin.CFrame = CFrame.new(position)
	coin.Color = Color3.fromRGB(255, 200, 40)
	coin.Material = Enum.Material.Foil
	coin.Anchored = true
	coin.CanCollide = false
	coin.Parent = coinFolder
	CollectionService:AddTag(coin, "Spin")
	local taken = false
	coin.Touched:Connect(function(hit)
		if taken then
			return
		end
		local player = Parts.playerFromHit(hit)
		if not player then
			return
		end
		taken = true
		DataService.addCoins(player, Config.Coins.PickupValue * DataService.multiplier(player))
		coin:Destroy()
		if respawn then
			task.delay(Config.Coins.RespawnTime, spawnCoin, position, true)
		end
	end)
	if not respawn then
		task.delay(Config.Chaos.Duration, function()
			if coin.Parent then
				coin:Destroy()
			end
		end)
	end
end

-- Drops coins at random spots along the course (Chaos Event).
function ProgressService.coinRain(count: number)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { course.folder }
	local rng = Random.new()
	local placed = 0
	for _ = 1, count * 4 do
		if placed >= count then
			break
		end
		local x = rng:NextNumber(-10, 10)
		local z = rng:NextNumber(0, course.length)
		local hit = workspace:Raycast(Vector3.new(x, Config.Course.Height + 60, z), Vector3.new(0, -100, 0), params)
		if hit then
			placed += 1
			spawnCoin(hit.Position + Vector3.new(0, 3, 0), false)
		end
	end
end

-- ------------------------------------------------------------------ setup

local function onCharacterAdded(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	task.wait(0.1)
	sendToCheckpoint(player)
	PowerService.refreshMovement(player)
end

local function onPlayerAdded(player: Player)
	player:SetAttribute("Checkpoint", 0)
	player:SetAttribute("Falls", 0)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	DataService.load(player)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

function ProgressService.init(builtCourse: CourseBuilder.Course)
	course = builtCourse
	announceRemote = Remotes.event("Announce")
	fellRemote = Remotes.event("Fell")
	coinFolder = Instance.new("Folder")
	coinFolder.Name = "Coins"
	coinFolder.Parent = workspace

	for stage, pad in course.checkpointPads do
		pad.Touched:Connect(function(hit)
			local player = Parts.playerFromHit(hit)
			if player then
				reachCheckpoint(player, stage)
			end
		end)
	end

	-- Crossing the start line (from the hub) starts a run.
	course.startLine.Touched:Connect(function(hit)
		local player = Parts.playerFromHit(hit)
		if player and checkpointOf(player) == 0 then
			player:SetAttribute("RunStart", workspace:GetServerTimeNow())
		end
	end)

	for _, pad in course.speedPads do
		pad.Touched:Connect(function(hit)
			local player = Parts.playerFromHit(hit)
			if player then
				PowerService.speedBurst(player)
			end
		end)
	end

	local finishing: { [Player]: boolean } = {}
	course.finishPad.Touched:Connect(function(hit)
		local player = Parts.playerFromHit(hit)
		if player and not finishing[player] then
			finishing[player] = true
			rebirth(player)
			task.delay(2, function()
				finishing[player] = nil
			end)
		end
	end)

	for _, spot in course.coinSpots do
		spawnCoin(spot, true)
	end

	Remotes.event("EquipPet").OnServerEvent:Connect(function(player: Player, id: any)
		if typeof(id) == "string" then
			DataService.setPet(player, id)
		end
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	-- Falling: anyone well below the course goes back to their checkpoint.
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then
			return
		end
		acc = 0
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") and root.Position.Y < course.killY then
				local falls = (player:GetAttribute("Falls") or 0) :: number + 1
				player:SetAttribute("Falls", falls)
				sendToCheckpoint(player)
				fellRemote:FireClient(player, falls)
			end
		end
	end)

	-- Passive income from rescued brainrots.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local income = DataService.income(player)
				if income > 0 then
					DataService.addCoins(player, income)
				end
				if player:GetAttribute("Income") ~= income then
					player:SetAttribute("Income", income)
				end
			end
		end
	end)
end

return ProgressService
