--!strict
-- The game loop: Waiting -> Intermission -> HeadStart -> Chase -> Results -> repeat.
-- The town is built once; each round resets acorns, cars and squirrels.
-- Publishes to clients through ReplicatedStorage attributes:
--   RoundState, TimeLeft, SquirrelSpeed, Objective, TeamAcorns, AcornGoal

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local WorldBuilder = require(script.Parent.WorldBuilder)
local AcornService = require(script.Parent.AcornService)
local VehicleService = require(script.Parent.VehicleService)
local PlayerService = require(script.Parent.PlayerService)
local CharacterSquirrel = require(script.Parent.CharacterSquirrel)
local SquirrelAI = require(script.Parent.SquirrelAI)

local RoundService = {}

local announceRemote = Remotes.get("Announce")

local world: WorldBuilder.World
local roundActive = false
local squirrels: { SquirrelAI.SquirrelAI } = {}
local chaseStart = 0
local rng = Random.new()
local caughtCount, escapedCount = 0, 0

local function setState(state: string, timeLeft: number)
	ReplicatedStorage:SetAttribute("RoundState", state)
	ReplicatedStorage:SetAttribute("TimeLeft", timeLeft)
end

function RoundService.announce(text: string, kind: string?, target: Player?)
	if target then
		announceRemote:FireClient(target, text, kind or "info")
	else
		announceRemote:FireAllClients(text, kind or "info")
	end
end
local announce = RoundService.announce

local function teleport(player: Player, position: Vector3)
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			VehicleService.eject(humanoid)
		end
		character:PivotTo(CFrame.new(position))
	end
end

local function isBlocked(pos: Vector3): boolean
	return WorldBuilder.isBlocked(world, pos)
end

local function catch(victim: Player, catcher: Player?)
	if not roundActive or PlayerService.getRole(victim) ~= "Runner" then
		return
	end
	local root = PlayerService.aliveRoot(victim)
	AcornService.dropFor(victim, if root then root.Position else nil)
	PlayerService.setRole(victim, "Minion")
	caughtCount += 1
	local character = victim.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character and humanoid then
		VehicleService.eject(humanoid)
		CharacterSquirrel.apply(character)
	end
	announce("🐿️ GOT YOU! You're a SQUIRREL MINION now. Catch the others!", "danger", victim)
	if catcher then
		PlayerService.addCoins(catcher, Config.Rewards.CatchAsMinion)
		announce(`{catcher.DisplayName} caught {victim.DisplayName}!`, "danger")
	else
		announce(`{victim.DisplayName} got snatched by the SQUIRREL!`, "danger")
	end
end

local function escape(player: Player)
	if not roundActive or PlayerService.getRole(player) ~= "Runner" then
		return
	end
	AcornService.forget(player)
	PlayerService.setRole(player, "Escaped")
	escapedCount += 1
	PlayerService.addCoins(player, Config.Rewards.Escape)
	PlayerService.addEscape(player)
	announce(`🎈 {player.DisplayName} ESCAPED in the balloon!`, "good")
	task.spawn(function()
		player:LoadCharacterAsync()
	end)
end

local function stepChase(dt: number)
	local targets: { SquirrelAI.Target } = {}
	local ignore: { Instance } = { VehicleService.folder() }
	for _, s in squirrels do
		table.insert(ignore, s.model)
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
		if PlayerService.getRole(player) == "Runner" then
			local root = PlayerService.aliveRoot(player)
			if root then
				local building = WorldBuilder.buildingAt(world, root.Position)
				local goal = root.Position
				if building and #building.doors > 0 then
					-- Can't get in: wait by the nearest door.
					local best = math.huge
					for _, door in building.doors do
						local d = (door - root.Position).Magnitude
						if d < best then
							best = d
							goal = door
						end
					end
				end
				table.insert(targets, {
					player = player,
					root = root,
					acorns = AcornService.carried(player),
					inside = building ~= nil,
					goal = goal,
				})
			end
		end
	end

	local C = Config.Squirrel
	local elapsed = os.clock() - chaseStart
	local speed = math.min(C.MaxSpeed, C.BaseSpeed + math.floor(elapsed / C.SpeedGainEvery) * C.SpeedGain)
	if ReplicatedStorage:GetAttribute("SquirrelSpeed") ~= speed then
		ReplicatedStorage:SetAttribute("SquirrelSpeed", speed)
	end

	for _, squirrel in squirrels do
		squirrel.speed = speed
		squirrel:update(dt, targets, ignore)
		for _, tg in targets do
			if (tg.root.Position - squirrel.position).Magnitude < C.CatchDistance then
				catch(tg.player, nil)
			end
		end
	end

	-- Minions catch runners by bumping into them.
	for _, player in Players:GetPlayers() do
		if PlayerService.getRole(player) == "Minion" then
			local myRoot = PlayerService.aliveRoot(player)
			if myRoot then
				for _, tg in targets do
					if (tg.root.Position - myRoot.Position).Magnitude < Config.Minion.CatchDistance then
						catch(tg.player, player)
					end
				end
			end
		end
	end
end

local function cleanup()
	roundActive = false
	for _, s in squirrels do
		s:destroy()
	end
	squirrels = {}
	AcornService.cleanup()
	ReplicatedStorage:SetAttribute("SquirrelSpeed", 0)
	for _, player in Players:GetPlayers() do
		PlayerService.setRole(player, "Lobby")
		task.spawn(function()
			player:LoadCharacterAsync()
		end)
	end
	task.wait(0.5) -- let everyone leave their seats before the cars reset
	VehicleService.resetAll()
end

local function playRound()
	rng = Random.new()
	caughtCount, escapedCount = 0, 0
	roundActive = true

	local runners = 0
	for _, player in Players:GetPlayers() do
		if PlayerService.aliveRoot(player) then
			runners += 1
			PlayerService.setRole(player, "Runner")
			local humanoid = (player.Character :: Model):FindFirstChildOfClass("Humanoid") :: Humanoid
			humanoid.WalkSpeed = Config.RunnerWalkSpeed
			teleport(player, world.spawnPositions[(runners - 1) % #world.spawnPositions + 1])
		end
	end
	if runners == 0 then
		cleanup()
		return
	end

	AcornService.setup(world, rng, runners, { announce = announce, onEscape = escape })
	squirrels = { SquirrelAI.new(world.folder, world.squirrelSpawn, isBlocked) }
	announce("Grab golden acorns 🌰, bank them at the ACORN BANK, then escape in the balloon! 🎈", "info")
	announce("Cars are in the GARAGE. Hop in and floor it! 🚗", "info")

	local sleepConn = RunService.Heartbeat:Connect(function(dt)
		for _, s in squirrels do
			s.t += dt
			s:render(dt, Vector3.zero)
		end
	end)
	for t = Config.Round.HeadStartTime, 1, -1 do
		setState("HeadStart", t)
		task.wait(1)
	end
	sleepConn:Disconnect()

	for _, s in squirrels do
		s:wake()
	end
	announce("🐿️ THE SQUIRREL IS AWAKE! RUN!", "danger")
	chaseStart = os.clock()
	local chaseConn = RunService.Heartbeat:Connect(stepChase)

	local second = false
	local endTime = os.clock() + Config.Round.RoundTime
	while os.clock() < endTime do
		setState("Chase", math.ceil(endTime - os.clock()))
		if #PlayerService.withRole("Runner") == 0 then
			break
		end
		if not second and os.clock() - chaseStart >= Config.Round.SecondSquirrelAt then
			second = true
			local extra = SquirrelAI.new(world.folder, world.squirrelSpawn, isBlocked)
			extra:wake()
			table.insert(squirrels, extra)
			announce("😱 ANOTHER SQUIRREL just jumped out of the Great Oak!", "danger")
		end
		task.wait(0.25)
	end
	chaseConn:Disconnect()

	local survivors = PlayerService.withRole("Runner")
	for _, player in survivors do
		PlayerService.addCoins(player, Config.Rewards.Survive)
		announce(`⏱️ You survived! +{Config.Rewards.Survive} coins`, "good", player)
	end
	announce(`Round over! Escaped: {escapedCount}  Survived: {#survivors}  Caught: {caughtCount}`, "info")
	for t = Config.Round.ResultsTime, 1, -1 do
		setState("Results", t)
		task.wait(1)
	end
	cleanup()
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		if roundActive and PlayerService.getRole(player) == "Runner" then
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			AcornService.dropFor(player, if root then root.Position else nil)
			PlayerService.setRole(player, "Minion")
			caughtCount += 1
		end
	end)
	if roundActive and PlayerService.getRole(player) == "Minion" then
		character:WaitForChild("HumanoidRootPart")
		task.wait(0.1)
		teleport(player, world.minionSpawns[rng:NextInteger(1, #world.minionSpawns)])
		CharacterSquirrel.apply(character)
	end
end

function RoundService.init(builtWorld: WorldBuilder.World)
	world = builtWorld
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
			AcornService.dropFor(player, if root then root.Position else nil)
		end
	end)
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
