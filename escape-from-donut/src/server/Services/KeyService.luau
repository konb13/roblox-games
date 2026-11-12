--!strict
-- Keys, doors and the exit.
--
-- Key chain: the Red key is loose in the maze -> opens the Red house -> inside is the
-- Blue key -> ... -> the last house holds the MASTER key -> opens the Exit Gate.
-- A runner carries one coloured key at a time (it floats above their head so everyone
-- can see who has it). If they get caught, the key drops where they were.
--
-- The rare DONUT KEY is separate: picking it up lets that runner switch sides and
-- become a Rogue Donut (handled by RoundService through the UseDonutKey remote).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Parts = require(script.Parent.Parts)
local DonutModel = require(script.Parent.DonutModel)
local PlayerService = require(script.Parent.PlayerService)
local WorldBuilder = require(script.Parent.WorldBuilder)

type World = WorldBuilder.World

local KeyService = {}

type Callbacks = {
	announce: (text: string, kind: string?, target: Player?) -> (),
	onEscape: (player: Player) -> (),
}

local active = false
local world: World? = nil
local callbacks: Callbacks? = nil
local connections: { RBXScriptConnection } = {}
local worldKeys: { [string]: Model } = {} -- keys lying in the world, by kind
local homeSpots: { [string]: Vector3 } = {} -- where each key first spawned
local carriedVisuals: { [Player]: Model } = {}
local exitOpen = false

local function displayName(kind: string): string
	return string.upper(kind) .. " KEY"
end

local function setObjective(text: string)
	ReplicatedStorage:SetAttribute("Objective", text)
end

local function nextKindAfter(color: string): string
	local colors = Config.Houses.Colors
	local index = table.find(colors, color)
	if index and index < #colors then
		return colors[index + 1]
	end
	return "Master"
end

-- Builds a key model. Root is anchored; everything else is welded to it.
local function buildKeyModel(kind: string, scale: number): Model
	local color = Config.KeyColors[kind] or Color3.new(1, 1, 1)
	local model = Instance.new("Model")
	model.Name = kind .. "Key"

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.one * 0.5
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = CFrame.identity
	root.Parent = model
	model.PrimaryPart = root

	local function attach(part: BasePart, offset: CFrame)
		part.Anchored = false
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CFrame = root.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
	end

	local material = if kind == "Master" then Enum.Material.Foil else Enum.Material.Neon

	if kind == "Donut" then
		-- The bow of the Donut Key is a tiny donut.
		local donut = DonutModel.build(0.32 * scale, Config.KeyColors.Donut)
		for _, child in donut:GetChildren() do
			if child:IsA("BasePart") and child.Name ~= "Root" then
				local offset = child.CFrame
				child:ClearAllChildren()
				attach(child, CFrame.new(0, 1.6 * scale, 0) * offset)
			end
		end
		donut:Destroy()
	else
		local bow = Instance.new("Part")
		bow.Shape = Enum.PartType.Cylinder
		bow.Size = Vector3.new(0.5, 2.2, 2.2) * scale
		bow.Color = color
		bow.Material = material
		attach(bow, CFrame.new(0, 1.6 * scale, 0) * CFrame.Angles(0, math.pi / 2, 0))
	end

	local shaft = Instance.new("Part")
	shaft.Size = Vector3.new(0.45, 3, 0.45) * scale
	shaft.Color = color
	shaft.Material = material
	attach(shaft, CFrame.new(0, -0.6 * scale, 0))

	for i = 0, 1 do
		local tooth = Instance.new("Part")
		tooth.Size = Vector3.new(0.9, 0.4, 0.4) * scale
		tooth.Color = color
		tooth.Material = material
		attach(tooth, CFrame.new(0.55 * scale, (-1.8 + i * 0.7) * scale, 0))
	end

	return model
end

local function removeWorldKey(kind: string)
	local key = worldKeys[kind]
	if key then
		key:Destroy()
		worldKeys[kind] = nil
	end
end

local function attachCarriedVisual(player: Player, kind: string)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not hrp then
		return
	end
	local old = carriedVisuals[player]
	if old then
		old:Destroy()
	end
	local visual = buildKeyModel(kind, 0.6)
	visual.Name = "CarriedKey"
	local root = visual.PrimaryPart :: BasePart
	root.Anchored = false
	root.Massless = true
	root.CFrame = hrp.CFrame * CFrame.new(0, 5, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hrp
	weld.Part1 = root
	weld.Parent = root
	visual.Parent = character
	carriedVisuals[player] = visual
end

local function clearCarriedVisual(player: Player)
	local visual = carriedVisuals[player]
	if visual then
		visual:Destroy()
		carriedVisuals[player] = nil
	end
end

local spawnKey: (kind: string, position: Vector3) -> ()

local function pickUp(player: Player, kind: string)
	local cb = callbacks :: Callbacks
	if kind == "Donut" then
		player:SetAttribute("HasDonutKey", true)
		cb.announce(`{player.DisplayName} found the 🍩 DONUT KEY!`, "danger")
		cb.announce("You have the DONUT KEY! Press Q or tap the button to BECOME THE DONUT.", "good", player)
	else
		player:SetAttribute("CarryingKey", kind)
		attachCarriedVisual(player, kind)
		PlayerService.addCoins(player, Config.Rewards.KeyPickup)
		if kind == "Master" then
			cb.announce(`{player.DisplayName} has the MASTER KEY! Get to the EXIT!`, "good")
			setObjective("Take the MASTER KEY to the EXIT gate (north side of the maze)")
		else
			cb.announce(`{player.DisplayName} picked up the {displayName(kind)}`, "info")
			setObjective(`Bring the {displayName(kind)} to the {string.upper(kind)} HOUSE`)
		end
	end
end

spawnKey = function(kind: string, position: Vector3)
	local w = world :: World
	removeWorldKey(kind)
	if not homeSpots[kind] then
		homeSpots[kind] = position
	end

	local model = buildKeyModel(kind, 1)
	local root = model.PrimaryPart :: BasePart
	root.CFrame = CFrame.new(position)
	CollectionService:AddTag(root, "SpinKey") -- the client spins these

	local light = Instance.new("PointLight")
	light.Color = Config.KeyColors[kind]
	light.Range = 14
	light.Brightness = 2
	light.Parent = root
	Parts.billboard(root, if kind == "Donut" then "🍩 DONUT KEY" else displayName(kind), Config.KeyColors[kind], 3.5, 60)

	local hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox"
	hitbox.Size = Vector3.new(6, 9, 6)
	hitbox.CFrame = CFrame.new(position)
	hitbox.Transparency = 1
	hitbox.Anchored = true
	hitbox.CanCollide = false
	hitbox.CanQuery = false
	hitbox.Parent = model

	local taken = false
	hitbox.Touched:Connect(function(hit)
		if taken or not active then
			return
		end
		local player = Parts.playerFromHit(hit)
		if not player or player:GetAttribute("Role") ~= "Runner" then
			return
		end
		if kind == "Donut" then
			if player:GetAttribute("HasDonutKey") then
				return
			end
		elseif player:GetAttribute("CarryingKey") then
			return -- hands full: one coloured key at a time
		end
		taken = true
		worldKeys[kind] = nil
		model:Destroy()
		pickUp(player, kind)
	end)

	model.Parent = w.folder
	worldKeys[kind] = model
end

local function openDoor(door: BasePart)
	door.CanCollide = false
	door:SetAttribute("Open", true)
	local goal = { CFrame = door.CFrame + Vector3.new(0, Config.Houses.DoorHeight - 0.5, 0) }
	TweenService:Create(door, TweenInfo.new(0.8, Enum.EasingStyle.Quad), goal):Play()
end

-- Drops whatever the player is carrying at `position` (or back at its home spot).
function KeyService.dropFor(player: Player, position: Vector3?)
	if not active then
		return
	end
	local w = world :: World
	local dropAt = if position then Vector3.new(position.X, w.floorY + 3, position.Z) else nil

	local kind = player:GetAttribute("CarryingKey")
	if typeof(kind) == "string" then
		player:SetAttribute("CarryingKey", nil)
		clearCarriedVisual(player)
		spawnKey(kind, dropAt or homeSpots[kind])
		;(callbacks :: Callbacks).announce(`The {displayName(kind)} was dropped! Grab it!`, "info")
		setObjective(`Someone dropped the {displayName(kind)}! Find it and bring it to its door`)
	end
	if player:GetAttribute("HasDonutKey") then
		player:SetAttribute("HasDonutKey", nil)
		spawnKey("Donut", dropAt or homeSpots["Donut"])
	end
end

-- Removes the carried coloured key without dropping it (used when a runner escapes).
function KeyService.forget(player: Player)
	player:SetAttribute("CarryingKey", nil)
	player:SetAttribute("HasDonutKey", nil)
	clearCarriedVisual(player)
end

function KeyService.setup(newWorld: World, rng: Random, cb: Callbacks)
	KeyService.cleanup()
	world = newWorld
	callbacks = cb
	active = true
	exitOpen = false
	local w = newWorld
	local maze = w.maze

	-- Red key: a dead end in the southern half of the maze, if there is one.
	local southDeadEnds = {}
	local northDeadEnds = {}
	for _, cell in maze.deadEnds do
		if cell.Y >= 4 and cell.Y <= math.floor(maze.height / 2) then
			table.insert(southDeadEnds, cell)
		elseif cell.Y > math.floor(maze.height / 2) then
			table.insert(northDeadEnds, cell)
		end
	end
	local firstColor = Config.Houses.Colors[1]
	local firstSpot: Vector3
	if #southDeadEnds > 0 then
		local cell = southDeadEnds[rng:NextInteger(1, #southDeadEnds)]
		firstSpot = w.cellCenter(cell.X, cell.Y)
	else
		firstSpot = w.randomOpenCell(rng, 4, math.floor(maze.height / 2))
	end
	spawnKey(firstColor, firstSpot + Vector3.new(0, 3, 0))

	-- Each house holds the next key in the chain.
	for _, house in w.houses do
		spawnKey(nextKindAfter(house.color), house.keySpot)

		table.insert(connections, house.door.Touched:Connect(function(hit)
			if not active or house.door:GetAttribute("Open") then
				return
			end
			local player = Parts.playerFromHit(hit)
			if not player or player:GetAttribute("Role") ~= "Runner" then
				return
			end
			if player:GetAttribute("CarryingKey") ~= house.color then
				return
			end
			player:SetAttribute("CarryingKey", nil)
			clearCarriedVisual(player)
			openDoor(house.door)
			PlayerService.addCoins(player, Config.Rewards.DoorOpened)
			local nextKind = nextKindAfter(house.color)
			cb.announce(`{player.DisplayName} opened the {string.upper(house.color)} HOUSE!`, "good")
			setObjective(`Grab the {displayName(nextKind)} inside the {string.upper(house.color)} HOUSE`)
		end))
	end

	-- Sometimes there is a Donut Key hidden in a far dead end.
	if rng:NextNumber() < Config.DonutKey.SpawnChance then
		local spot: Vector3
		if #northDeadEnds > 0 then
			local cell = northDeadEnds[rng:NextInteger(1, #northDeadEnds)]
			spot = w.cellCenter(cell.X, cell.Y)
		else
			spot = w.randomOpenCell(rng, math.floor(maze.height / 2), maze.height)
		end
		spawnKey("Donut", spot + Vector3.new(0, 3, 0))
	end

	-- Exit gate + pad.
	table.insert(connections, w.exitGate.Touched:Connect(function(hit)
		if not active or exitOpen then
			return
		end
		local player = Parts.playerFromHit(hit)
		if not player or player:GetAttribute("Role") ~= "Runner" or player:GetAttribute("CarryingKey") ~= "Master" then
			return
		end
		exitOpen = true
		player:SetAttribute("CarryingKey", nil)
		clearCarriedVisual(player)
		w.exitGate.CanCollide = false
		local goal = { CFrame = w.exitGate.CFrame + Vector3.new(0, Config.Maze.WallHeight, 0) }
		TweenService:Create(w.exitGate, TweenInfo.new(1.2, Enum.EasingStyle.Quad), goal):Play()
		cb.announce("🚪 THE EXIT IS OPEN! RUN!", "good")
		setObjective("THE EXIT IS OPEN! Run to the green pad behind the gate!")
	end))

	table.insert(connections, w.exitPad.Touched:Connect(function(hit)
		if not active or not exitOpen then
			return
		end
		local player = Parts.playerFromHit(hit)
		if player and player:GetAttribute("Role") == "Runner" then
			cb.onEscape(player)
		end
	end))

	setObjective(`Find the {displayName(firstColor)} somewhere in the maze`)
end

function KeyService.cleanup()
	active = false
	for _, c in connections do
		c:Disconnect()
	end
	connections = {}
	for kind in worldKeys do
		removeWorldKey(kind)
	end
	for player in carriedVisuals do
		clearCarriedVisual(player)
	end
	homeSpots = {}
	world = nil
	setObjective("")
end

return KeyService
