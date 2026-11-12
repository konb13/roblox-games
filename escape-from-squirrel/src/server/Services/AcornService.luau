--!strict
-- Golden acorns, the Acorn Bank, and the escape balloon.
--
-- Runners pick up golden acorns (up to MaxCarry) and bank them on the vault inside the
-- Acorn Bank. When the team has banked enough, the escape balloon lands somewhere in
-- town; touching it escapes. Carrying acorns makes you the squirrel's favourite target,
-- and getting caught scatters them on the ground.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Parts = require(script.Parent.Parts)
local PlayerService = require(script.Parent.PlayerService)
local WorldBuilder = require(script.Parent.WorldBuilder)

local AcornService = {}

type Callbacks = {
	announce: (text: string, kind: string?, target: Player?) -> (),
	onEscape: (player: Player) -> (),
}

type World = WorldBuilder.World

local A = Config.Acorns
local token = 0 -- bumps every round so delayed respawns from an old round do nothing
local active = false
local world: World? = nil
local callbacks: Callbacks? = nil
local rng = Random.new()
local acornFolder: Folder? = nil
local spotTaken: { [number]: boolean } = {}
local connections: { RBXScriptConnection } = {}
local teamAcorns = 0
local goal = 0
local balloon: Model? = nil
local balloonReady = false

local function setObjective(text: string)
	ReplicatedStorage:SetAttribute("Objective", text)
end

local function publish()
	ReplicatedStorage:SetAttribute("TeamAcorns", teamAcorns)
	ReplicatedStorage:SetAttribute("AcornGoal", goal)
end

local function carried(player: Player): number
	local n = player:GetAttribute("Acorns")
	return if typeof(n) == "number" then n else 0
end

-- Shows "🌰 3" over a player's head so everyone (and the squirrel) knows who is loaded.
local function setCarried(player: Player, n: number)
	player:SetAttribute("Acorns", if n > 0 then n else nil)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		return
	end
	local gui = hrp:FindFirstChild("AcornCount")
	if n <= 0 then
		if gui then
			gui:Destroy()
		end
		return
	end
	if not gui then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "AcornCount"
		billboard.Size = UDim2.fromOffset(90, 40)
		billboard.StudsOffset = Vector3.new(0, 4.5, 0)
		billboard.MaxDistance = 150
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(255, 200, 40)
		label.TextStrokeTransparency = 0
		label.Font = Enum.Font.FredokaOne
		label.Parent = billboard
		billboard.Parent = hrp
		gui = billboard
	end
	local label = (gui :: Instance):FindFirstChild("Text")
	if label and label:IsA("TextLabel") then
		label.Text = `🌰 {n}`
	end
end

local function buildAcorn(position: Vector3): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "GoldenAcorn"
	local nut = Instance.new("Part")
	nut.Name = "Nut"
	nut.Shape = Enum.PartType.Ball
	nut.Size = Vector3.one * 2
	nut.Color = Color3.fromRGB(255, 190, 40)
	nut.Material = Enum.Material.Foil
	nut.Anchored = true
	nut.CanCollide = false
	nut.CanQuery = false
	nut.CanTouch = false
	nut.CFrame = CFrame.new(position)
	nut.Parent = model
	model.PrimaryPart = nut
	local cap = Instance.new("Part")
	cap.Name = "Cap"
	cap.Shape = Enum.PartType.Cylinder
	cap.Size = Vector3.new(0.7, 2.3, 2.3)
	cap.Color = Color3.fromRGB(120, 75, 40)
	cap.Material = Enum.Material.Fabric
	cap.CanCollide = false
	cap.CanQuery = false
	cap.CanTouch = false
	Parts.weldTo(nut, cap, CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.pi / 2), model)
	local stem = Instance.new("Part")
	stem.Name = "Stem"
	stem.Size = Vector3.new(0.3, 0.8, 0.3)
	stem.Color = Color3.fromRGB(90, 55, 30)
	stem.CanCollide = false
	stem.CanQuery = false
	stem.CanTouch = false
	Parts.weldTo(nut, stem, CFrame.new(0, 1.5, 0), model)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 200, 60)
	light.Range = 10
	light.Brightness = 1.5
	light.Parent = nut
	CollectionService:AddTag(nut, "Spin")

	local hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox"
	hitbox.Size = Vector3.new(5, 6, 5)
	hitbox.CFrame = CFrame.new(position)
	hitbox.Transparency = 1
	hitbox.Anchored = true
	hitbox.CanCollide = false
	hitbox.CanQuery = false
	hitbox.Parent = model
	return model, hitbox
end

local spawnAtFreeSpot: () -> ()

-- spotIndex is nil for acorns dropped by a caught player (they don't respawn).
local function spawnAcorn(position: Vector3, spotIndex: number?)
	local folder = acornFolder
	if not folder then
		return
	end
	local myToken = token
	local model, hitbox = buildAcorn(position)
	if spotIndex then
		spotTaken[spotIndex] = true
	end
	local taken = false
	hitbox.Touched:Connect(function(hit)
		if taken or not active then
			return
		end
		local player = Parts.playerFromHit(hit)
		if not player or PlayerService.getRole(player) ~= "Runner" then
			return
		end
		local n = carried(player)
		if n >= A.MaxCarry then
			return
		end
		taken = true
		model:Destroy()
		setCarried(player, n + 1)
		local cb = callbacks :: Callbacks
		if n + 1 >= A.MaxCarry then
			cb.announce(`🌰 Pockets full ({n + 1}/{A.MaxCarry})! Get to the ACORN BANK!`, "info", player)
		else
			cb.announce(`🌰 Golden acorn! ({n + 1}/{A.MaxCarry})`, "good", player)
		end
		if spotIndex then
			spotTaken[spotIndex] = nil
			task.delay(A.RespawnDelay, function()
				if active and token == myToken then
					spawnAtFreeSpot()
				end
			end)
		end
	end)
	model.Parent = folder
end

spawnAtFreeSpot = function()
	local w = world
	if not w then
		return
	end
	local free = {}
	for i = 1, #w.acornSpots do
		if not spotTaken[i] then
			table.insert(free, i)
		end
	end
	if #free > 0 then
		local i = free[rng:NextInteger(1, #free)]
		spawnAcorn(w.acornSpots[i], i)
	end
end

local function buildBalloon(): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "EscapeBalloon"
	local base = Parts.block(model, {
		Name = "Basket",
		Size = Vector3.new(8, 5, 8),
		CFrame = CFrame.new(0, 2.5, 0),
		Color = Color3.fromRGB(150, 100, 55),
		Material = Enum.Material.Wood,
	})
	model.PrimaryPart = base
	Parts.block(model, { Name = "Envelope", Size = Vector3.one * 26, CFrame = CFrame.new(0, 26, 0), Color = Color3.fromRGB(230, 60, 60), Shape = Enum.PartType.Ball, CanCollide = false })
	Parts.block(model, { Name = "Envelope", Size = Vector3.one * 22, CFrame = CFrame.new(0, 31, 0), Color = Color3.fromRGB(255, 220, 80), Shape = Enum.PartType.Ball, CanCollide = false })
	Parts.block(model, { Name = "Burner", Size = Vector3.new(2, 1.5, 2), CFrame = CFrame.new(0, 9, 0), Color = Color3.fromRGB(255, 140, 0), Material = Enum.Material.Neon, CanCollide = false })
	for _, c in { Vector3.new(3.6, 0, 3.6), Vector3.new(-3.6, 0, 3.6), Vector3.new(3.6, 0, -3.6), Vector3.new(-3.6, 0, -3.6) } do
		local from, to = c + Vector3.new(0, 5, 0), c * 1.6 + Vector3.new(0, 15, 0)
		Parts.block(model, {
			Name = "Rope",
			Size = Vector3.new(0.25, 0.25, (to - from).Magnitude),
			CFrame = CFrame.lookAt((from + to) / 2, to),
			Color = Color3.fromRGB(80, 60, 40),
			CanCollide = false,
		})
	end
	local zone = Parts.block(model, {
		Name = "EscapeZone",
		Size = Vector3.new(20, 12, 20),
		CFrame = CFrame.new(0, 6, 0),
		Transparency = 1,
		CanCollide = false,
	})
	local marker = Instance.new("BillboardGui")
	marker.Size = UDim2.fromOffset(220, 60)
	marker.StudsOffsetWorldSpace = Vector3.new(0, 44, 0)
	marker.AlwaysOnTop = true
	marker.MaxDistance = 2000
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "🎈 ESCAPE BALLOON"
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 230, 120)
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.FredokaOne
	label.Parent = marker
	marker.Adornee = base
	marker.Parent = base
	return model, zone
end

local function callBalloon()
	local w = world :: World
	local cb = callbacks :: Callbacks
	local spot = w.balloonSpots[rng:NextInteger(1, #w.balloonSpots)]
	local model, zone = buildBalloon()
	model:PivotTo(CFrame.new(spot + Vector3.new(0, 160, 0)))
	model.Parent = w.folder
	balloon = model
	cb.announce("🎈 The team banked enough acorns! The ESCAPE BALLOON is coming down. Follow the marker!", "good")
	setObjective("🎈 The ESCAPE BALLOON is landing. Follow the marker and get in!")

	local myToken = token
	table.insert(connections, zone.Touched:Connect(function(hit)
		if not balloonReady then
			return
		end
		local player = Parts.playerFromHit(hit)
		if player and PlayerService.getRole(player) == "Runner" then
			cb.onEscape(player)
		end
	end))

	task.spawn(function()
		local steps = 60
		for i = 1, steps do
			if token ~= myToken or not model.Parent then
				return
			end
			local height = 160 * (1 - i / steps) ^ 2
			model:PivotTo(CFrame.new(spot + Vector3.new(0, height + 0.1, 0)))
			task.wait(0.1)
		end
		if token == myToken then
			balloonReady = true
			cb.announce("🎈 The balloon has LANDED! Get in to escape!", "good")
		end
	end)
end

local function deposit(player: Player)
	local n = carried(player)
	if n <= 0 or not active then
		return
	end
	setCarried(player, 0)
	teamAcorns += n
	publish()
	PlayerService.addCoins(player, n * Config.Rewards.AcornDeposit)
	local cb = callbacks :: Callbacks
	cb.announce(`🏦 {player.DisplayName} banked {n} acorn{if n == 1 then "" else "s"}! ({math.min(teamAcorns, goal)}/{goal})`, "good")
	if not balloon then
		if teamAcorns >= goal then
			callBalloon()
		else
			setObjective(`Bank golden acorns 🌰 at the ACORN BANK: {teamAcorns}/{goal}`)
		end
	end
end

function AcornService.setup(newWorld: World, roundRng: Random, runnerCount: number, cb: Callbacks)
	AcornService.cleanup()
	token += 1
	active = true
	world = newWorld
	callbacks = cb
	rng = roundRng
	teamAcorns = 0
	goal = math.clamp(A.GoalPerRunner * runnerCount, A.MinGoal, A.MaxGoal)
	publish()

	local folder = Instance.new("Folder")
	folder.Name = "Acorns"
	folder.Parent = newWorld.folder
	acornFolder = folder

	for _ = 1, math.min(A.ActiveCount, #newWorld.acornSpots) do
		spawnAtFreeSpot()
	end

	table.insert(connections, newWorld.vault.Touched:Connect(function(hit)
		local player = Parts.playerFromHit(hit)
		if player and PlayerService.getRole(player) == "Runner" then
			deposit(player)
		end
	end))

	setObjective(`Bank golden acorns 🌰 at the ACORN BANK: 0/{goal}`)
end

-- Scatters whatever the player was carrying around `position`.
function AcornService.dropFor(player: Player, position: Vector3?)
	local n = carried(player)
	setCarried(player, 0)
	if not active or n <= 0 then
		return
	end
	if not position then
		for _ = 1, n do
			spawnAtFreeSpot()
		end
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	for i = 1, n do
		local a = i / n * math.pi * 2
		local p = position + Vector3.new(math.cos(a) * 6, 6, math.sin(a) * 6)
		local hit = workspace:Raycast(p, Vector3.new(0, -40, 0), params)
		spawnAcorn(if hit then hit.Position + Vector3.new(0, 2, 0) else position, nil)
	end
	;(callbacks :: Callbacks).announce(`🌰 {player.DisplayName} dropped {n} acorn{if n == 1 then "" else "s"}!`, "info")
end

function AcornService.forget(player: Player)
	setCarried(player, 0)
end

function AcornService.carried(player: Player): number
	return carried(player)
end

function AcornService.cleanup()
	token += 1
	active = false
	balloonReady = false
	for _, c in connections do
		c:Disconnect()
	end
	connections = {}
	if acornFolder then
		acornFolder:Destroy()
		acornFolder = nil
	end
	if balloon then
		balloon:Destroy()
		balloon = nil
	end
	spotTaken = {}
	world = nil
	for _, player in Players:GetPlayers() do
		setCarried(player, 0)
	end
	ReplicatedStorage:SetAttribute("TeamAcorns", 0)
	ReplicatedStorage:SetAttribute("AcornGoal", 0)
	setObjective("")
end

return AcornService
