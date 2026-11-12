--!strict
-- The game loop: Waiting -> Intermission -> HeadStart -> Chase -> Results -> repeat.
-- Publishes state to clients through ReplicatedStorage attributes:
--   RoundState (string), TimeLeft (number), DonutSpeed (number), Objective (string)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local WorldBuilder = require(script.Parent.WorldBuilder)
local KeyService = require(script.Parent.KeyService)
local PlayerService = require(script.Parent.PlayerService)
local CharacterDonut = require(script.Parent.CharacterDonut)
local DonutAI = require(script.Parent.DonutAI)

local RoundService = {}

local announceRemote = Remotes.get("Announce")
local useDonutKeyRemote = Remotes.get("UseDonutKey")

local roundActive = false
local world: WorldBuilder.World? = nil
local donuts: { DonutAI.DonutAI } = {}
local chaseStart = 0
local roundRng = Random.new()
local caughtCount = 0
local escapedCount = 0

local function setState(state: string, timeLeft: number)
	ReplicatedStorage:SetAttribute("RoundState", state)
	ReplicatedStorage:SetAttribute("TimeLeft", timeLeft)
end

local function announce(text: string, kind: string?, target: Player?)
	if target then
		announceRemote:FireClient(target, text, kind or "info")
	else
		announceRemote:FireAllClients(text, kind or "info")
	end
end

local function teleport(player: Player, position: Vector3)
	local character = player.Character
	if character then
		character:PivotTo(CFrame.new(position))
	end
end

-- Respawns a donut player somewhere in the maze, away from the start plaza.
local function placeDonutPlayer(player: Player)
	local w = world
	local character = player.Character
	if not w or not character then
		return
	end
	local kind = if PlayerService.getRole(player) == "RogueDonut" then "Rogue" else "Mini"
	teleport(player, w.randomOpenCell(roundRng, 6, nil) + Vector3.new(0, 4, 0))
	CharacterDonut.apply(character, kind)
end

local function catch(victim: Player, catcher: Player?)
	if not roundActive or PlayerService.getRole(victim) ~= "Runner" then
		return
	end
	local root = PlayerService.aliveRoot(victim)
	KeyService.dropFor(victim, if root then root.Position else nil)
	PlayerService.setRole(victim, "MiniDonut")
	caughtCount += 1
	if victim.Character then
		CharacterDonut.apply(victim.Character, "Mini")
	end
	announce("🍩 You got GLAZED! You're a MINI DONUT now. Catch the others!", "danger", victim)
	if catcher then
		local isRogue = PlayerService.getRole(catcher) == "RogueDonut"
		PlayerService.addCoins(catcher, if isRogue then Config.Rewards.CatchAsRogue else Config.Rewards.CatchAsMini)
		announce(`{catcher.DisplayName} caught {victim.DisplayName}!`, "danger")
	else
		announce(`{victim.DisplayName} got eaten by the DONUT!`, "danger")
	end
end

local function escape(player: Player)
	if not roundActive or PlayerService.getRole(player) ~= "Runner" then
		return
	end
	KeyService.forget(player)
	PlayerService.setRole(player, "Escaped")
	escapedCount += 1
	PlayerService.addCoins(player, Config.Rewards.Escape)
	PlayerService.addEscape(player)
	announce(`🎉 {player.DisplayName} ESCAPED from the Donut!`, "good")
	task.spawn(function()
		player:LoadCharacterAsync() -- back to the lobby spawn
	end)
end

-- Runs every frame during the chase.
local function stepChase(dt: number)
	local runnerRoots: { BasePart } = {}
	local runnerOf: { [BasePart]: Player } = {}
	local ignore: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
		if PlayerService.getRole(player) == "Runner" then
			local root = PlayerService.aliveRoot(player)
			if root then
				table.insert(runnerRoots, root)
				runnerOf[root] = player
			end
		end
	end
	for _, donut in donuts do
		table.insert(ignore, donut.model)
	end

	-- The donut gets faster the longer the chase goes on.
	local elapsed = os.clock() - chaseStart
	local speed = math.min(
		Config.Donut.MaxSpeed,
		Config.Donut.BaseSpeed + math.floor(elapsed / Config.Donut.SpeedGainEvery) * Config.Donut.SpeedGain
	)
	if ReplicatedStorage:GetAttribute("DonutSpeed") ~= speed then
		ReplicatedStorage:SetAttribute("DonutSpeed", speed)
	end

	for _, donut in donuts do
		donut.speed = speed
		donut:update(dt, runnerRoots, ignore)
		for _, root in runnerRoots do
			if (root.Position - donut.position).Magnitude < Config.Donut.CatchDistance then
				catch(runnerOf[root], nil)
			end
		end
	end

	-- Player-controlled donuts catch runners by bumping into them.
	for _, player in Players:GetPlayers() do
		local role = PlayerService.getRole(player)
		if role == "MiniDonut" or role == "RogueDonut" then
			local myRoot = PlayerService.aliveRoot(player)
			if myRoot then
				local reach = if role == "RogueDonut" then Config.RogueDonut.CatchDistance else Config.MiniDonut.CatchDistance
				for _, root in runnerRoots do
					if (root.Position - myRoot.Position).Magnitude < reach then
						catch(runnerOf[root], player)
					end
				end
			end
		end
	end
end

local function cleanup()
	roundActive = false
	for _, donut in donuts do
		donut:destroy()
	end
	donuts = {}
	KeyService.cleanup()
	if world then
		world.folder:Destroy()
		world = nil
	end
	ReplicatedStorage:SetAttribute("DonutSpeed", 0)
	for _, player in Players:GetPlayers() do
		PlayerService.setRole(player, "Lobby")
		KeyService.forget(player)
		task.spawn(function()
			player:LoadCharacterAsync()
		end)
	end
end

local function playRound()
	roundRng = Random.new()
	caughtCount, escapedCount = 0, 0
	local w = WorldBuilder.build(roundRng)
	world = w
	roundActive = true
	KeyService.setup(w, roundRng, { announce = announce, onEscape = escape })

	local index = 0
	for _, player in Players:GetPlayers() do
		if PlayerService.aliveRoot(player) then
			index += 1
			PlayerService.setRole(player, "Runner")
			local humanoid = (player.Character :: Model):FindFirstChildOfClass("Humanoid") :: Humanoid
			humanoid.WalkSpeed = Config.RunnerWalkSpeed
			teleport(player, w.startPositions[(index - 1) % #w.startPositions + 1])
		end
	end
	if index == 0 then
		cleanup()
		return
	end

	donuts = { DonutAI.new(w.folder, w.donutSpawn, w.floorY) }
	announce("Find the keys, open the houses, reach the EXIT. Don't get eaten!", "info")

	-- Head start: the donut sleeps (it still animates).
	local sleepConn = RunService.Heartbeat:Connect(function(dt)
		for _, donut in donuts do
			donut:render(dt, Vector3.zero)
			donut.t += dt
		end
	end)
	for t = Config.Round.HeadStartTime, 1, -1 do
		setState("HeadStart", t)
		task.wait(1)
	end
	sleepConn:Disconnect()

	for _, donut in donuts do
		donut:wake()
	end
	announce("🍩 THE DONUT IS AWAKE! RUN!", "danger")
	chaseStart = os.clock()
	local chaseConn = RunService.Heartbeat:Connect(stepChase)

	local secondDonut = false
	local endTime = os.clock() + Config.Round.RoundTime
	while os.clock() < endTime do
		setState("Chase", math.ceil(endTime - os.clock()))
		if #PlayerService.withRole("Runner") == 0 then
			break
		end
		if not secondDonut and os.clock() - chaseStart >= Config.Round.SecondDonutAt then
			secondDonut = true
			local extra = DonutAI.new(w.folder, w.randomOpenCell(roundRng, 12, nil), w.floorY)
			extra:wake()
			table.insert(donuts, extra)
			announce("😱 A SECOND DONUT has appeared!", "danger")
		end
		task.wait(0.25)
	end
	chaseConn:Disconnect()

	-- Anyone still running when time is up survived.
	local survivors = PlayerService.withRole("Runner")
	for _, player in survivors do
		PlayerService.addCoins(player, Config.Rewards.Survive)
		announce(`⏱️ You survived! +{Config.Rewards.Survive} coins`, "good", player)
	end
	announce(`Round over! Escaped: {escapedCount}  Survived: {#survivors}  Glazed: {caughtCount}`, "info")
	for t = Config.Round.ResultsTime, 1, -1 do
		setState("Results", t)
		task.wait(1)
	end
	cleanup()
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		-- Falling or resetting as a runner counts as getting caught.
		if roundActive and PlayerService.getRole(player) == "Runner" then
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			KeyService.dropFor(player, if root then root.Position else nil)
			PlayerService.setRole(player, "MiniDonut")
			caughtCount += 1
		end
	end)

	local role = PlayerService.getRole(player)
	if roundActive and (role == "MiniDonut" or role == "RogueDonut") then
		character:WaitForChild("HumanoidRootPart")
		task.wait(0.1)
		placeDonutPlayer(player)
	end
end

local function onUseDonutKey(player: Player)
	if not roundActive or PlayerService.getRole(player) ~= "Runner" or not player:GetAttribute("HasDonutKey") then
		return
	end
	local character = player.Character
	local root = PlayerService.aliveRoot(player)
	if not character or not root then
		return
	end
	player:SetAttribute("HasDonutKey", nil)
	KeyService.dropFor(player, root.Position) -- drops any coloured key they held
	PlayerService.setRole(player, "RogueDonut")
	CharacterDonut.apply(character, "Rogue")
	announce(`😈 {player.DisplayName} used the DONUT KEY and turned into a ROGUE DONUT!`, "danger")
	announce("You're a ROGUE DONUT! Catch runners for bonus coins!", "good", player)
end

function RoundService.init()
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		if player.Character then
			task.spawn(onCharacterAdded, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		if roundActive then
			local root = PlayerService.aliveRoot(player)
			KeyService.dropFor(player, if root then root.Position else nil)
		end
	end)

	useDonutKeyRemote.OnServerEvent:Connect(onUseDonutKey)
	setState("Waiting", 0)
end

function RoundService.run()
	while true do
		while #Players:GetPlayers() < Config.Round.MinPlayers do
			setState("Waiting", 0)
			task.wait(1)
		end
		for t = Config.Round.IntermissionTime, 1, -1 do
			setState("Intermission", t)
			task.wait(1)
		end
		if #Players:GetPlayers() >= Config.Round.MinPlayers then
			local ok = xpcall(playRound, function(err)
				warn("Round crashed:", err, debug.traceback())
			end)
			if not ok then
				cleanup()
			end
		end
	end
end

return RoundService
