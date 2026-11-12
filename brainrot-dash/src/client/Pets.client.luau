--!strict
-- Draws every player's equipped brainrot following them around, and spins coins.
-- Pets are built on each client (no physics, no network traffic), so they're smooth.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Brainrots = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Brainrots"))

local PET_SCALE = 0.6

local folder = Instance.new("Folder")
folder.Name = "ClientPets"
folder.Parent = workspace

type PetState = { id: string, model: Model, root: BasePart }
local pets: { [Player]: PetState } = {}
local t = 0

local function removePet(owner: Player)
	local state = pets[owner]
	if state then
		state.model:Destroy()
		pets[owner] = nil
	end
end

Players.PlayerRemoving:Connect(removePet)

RunService.RenderStepped:Connect(function(dt: number)
	t += dt
	for _, owner in Players:GetPlayers() do
		local id = owner:GetAttribute("Pet")
		local character = owner.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if typeof(id) ~= "string" or not hrp or not hrp:IsA("BasePart") then
			removePet(owner)
			continue
		end
		local state: PetState? = pets[owner]
		if state and state.id ~= id then
			removePet(owner)
			state = nil
		end
		local side = if owner.UserId % 2 == 0 then 3.5 else -3.5
		local goal = hrp.CFrame * CFrame.new(side, math.sin(t * 3 + owner.UserId) * 0.4, 3)
		if not state then
			local model = Brainrots.build(id, PET_SCALE)
			model:PivotTo(goal)
			model.Parent = folder
			state = { id = id, model = model, root = model.PrimaryPart :: BasePart }
			pets[owner] = state
		end
		local s = state :: PetState
		local current = s.root.CFrame
		if (current.Position - goal.Position).Magnitude > 60 then
			s.root.CFrame = goal -- teleported (checkpoint, respawn)
		else
			s.root.CFrame = current:Lerp(goal, math.min(1, dt * 8))
		end
	end

	-- Spin coins (visual only).
	for _, part in CollectionService:GetTagged("Spin") do
		if part:IsA("BasePart") and part:IsDescendantOf(workspace) then
			part.CFrame = part.CFrame * CFrame.Angles(0, dt * 3, 0)
		end
	end
end)
