--!strict
-- Runs the power effects that happen on your own character: X-Ray, Parachute, Rewind,
-- Double Jump, plus bounce pads. (Zoomies and Moon Boots are applied by the server.)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local player = Players.LocalPlayer

local function getParts(): (Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	return humanoid, if root and root:IsA("BasePart") then root else nil
end

-- ------------------------------------------------------------------ last safe ground (for Rewind)

local UNSAFE = { CrumbleTile = true, BlinkPlatform = true, BouncePad = true }
local lastSafe: Vector3? = nil
task.spawn(function()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	while true do
		task.wait(0.2)
		local humanoid, root = getParts()
		if humanoid and root and humanoid.FloorMaterial ~= Enum.Material.Air then
			params.FilterDescendantsInstances = { player.Character :: Model }
			local hit = workspace:Raycast(root.Position, Vector3.new(0, -8, 0), params)
			local part = hit and hit.Instance
			if hit and part and not UNSAFE[part.Name] and not part:GetAttribute("Fake") then
				lastSafe = hit.Position
			end
		end
	end
end)
player.CharacterAdded:Connect(function()
	lastSafe = nil
end)

-- ------------------------------------------------------------------ effects

local parachuteUntil = 0
local parachuteStart = 0
local canopy: BasePart? = nil

local function xray(duration: number)
	local boxes = {}
	local _, root = getParts()
	for _, tile in CollectionService:GetTagged("GlassTile") do
		if tile:IsA("BasePart") and (not root or (tile.Position - root.Position).Magnitude < 200) then
			local box = Instance.new("SelectionBox")
			box.Adornee = tile
			local fake = tile:GetAttribute("Fake") == true
			box.Color3 = if fake then Color3.fromRGB(255, 40, 40) else Color3.fromRGB(40, 255, 90)
			box.SurfaceColor3 = box.Color3
			box.SurfaceTransparency = 0.45
			box.LineThickness = 0.08
			box.Parent = tile
			table.insert(boxes, box)
		end
	end
	task.delay(duration, function()
		for _, b in boxes do
			b:Destroy()
		end
	end)
end

local function parachute(duration: number)
	parachuteStart = os.clock()
	parachuteUntil = parachuteStart + duration
	local _, root = getParts()
	if root and not canopy then
		local c = Instance.new("Part")
		c.Name = "Parachute"
		c.Shape = Enum.PartType.Ball
		c.Size = Vector3.new(9, 9, 9)
		c.Color = Color3.fromRGB(255, 120, 200)
		c.Material = Enum.Material.Fabric
		c.Transparency = 0.15
		c.CanCollide = false
		c.CanQuery = false
		c.CanTouch = false
		c.Massless = true
		c.CFrame = root.CFrame * CFrame.new(0, 8, 0)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = c
		weld.Parent = c
		c.Parent = player.Character
		canopy = c
	end
end

local function rewind()
	local _, root = getParts()
	local target = lastSafe
	if root and target then
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = CFrame.new(target + Vector3.new(0, 3.5, 0)) * root.CFrame.Rotation
	end
end

Remotes.event("PowerActivated").OnClientEvent:Connect(function(id: string, duration: number)
	if id == "XRay" then
		xray(duration)
	elseif id == "Parachute" then
		parachute(duration)
	elseif id == "Rewind" then
		rewind()
	end
end)

RunService.Heartbeat:Connect(function()
	local humanoid, root = getParts()
	local active = os.clock() < parachuteUntil
	if active and root then
		-- Cap the fall speed: a slow, floaty glide.
		local v = root.AssemblyLinearVelocity
		if v.Y < -9 then
			root.AssemblyLinearVelocity = Vector3.new(v.X, -9, v.Z)
		end
		if humanoid and humanoid.FloorMaterial ~= Enum.Material.Air and os.clock() - parachuteStart > 0.4 then
			parachuteUntil = 0 -- landed
		end
	end
	if not active and canopy then
		canopy:Destroy()
		canopy = nil
	end
end)

-- ------------------------------------------------------------------ double jump

local airJumpUsed = false
local lastJump = 0
UserInputService.JumpRequest:Connect(function()
	if player:GetAttribute("Power_DoubleJump") ~= true then
		return
	end
	local humanoid = getParts()
	if not humanoid or airJumpUsed or os.clock() - lastJump < 0.25 then
		return
	end
	if humanoid:GetState() == Enum.HumanoidStateType.Freefall then
		airJumpUsed = true
		lastJump = os.clock()
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end)

local function hookHumanoid(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
			airJumpUsed = false
		elseif new == Enum.HumanoidStateType.Jumping then
			lastJump = os.clock()
		end
	end)
end
player.CharacterAdded:Connect(hookHumanoid)
if player.Character then
	task.spawn(hookHumanoid, player.Character)
end

-- ------------------------------------------------------------------ bounce pads

local lastBounce = 0
local function hookPad(pad: Instance)
	if not pad:IsA("BasePart") then
		return
	end
	pad.Touched:Connect(function(hit)
		local character = player.Character
		if not character or not hit:IsDescendantOf(character) or os.clock() - lastBounce < 0.5 then
			return
		end
		local _, root = getParts()
		if root then
			lastBounce = os.clock()
			local up = pad:GetAttribute("Up")
			local forward = pad:GetAttribute("Forward")
			root.AssemblyLinearVelocity = Vector3.new(
				root.AssemblyLinearVelocity.X * 0.3,
				if typeof(up) == "number" then up else 70,
				if typeof(forward) == "number" then forward else 30
			)
		end
	end)
end
for _, pad in CollectionService:GetTagged("BouncePad") do
	hookPad(pad)
end
CollectionService:GetInstanceAddedSignal("BouncePad"):Connect(hookPad)
