--!strict
-- Turns a caught player's character into a mini squirrel (a "Squirrel Minion").
-- The avatar is hidden and a small squirrel is welded in its place.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local SquirrelModel = require(script.Parent.SquirrelModel)

local CharacterSquirrel = {}

function CharacterSquirrel.apply(character: Model)
	local cfg = Config.Minion
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp or not hrp:IsA("BasePart") then
		return
	end

	local old = character:FindFirstChild("SquirrelBody")
	if old then
		old:Destroy()
	end
	for _, child in character:GetChildren() do
		if child:IsA("Accessory") then
			child:Destroy()
		end
	end
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = 1
		elseif d:IsA("Decal") then
			d.Transparency = 1
		end
	end

	local squirrel = SquirrelModel.build(cfg.Scale)
	squirrel.Name = "SquirrelBody"
	local root = squirrel.PrimaryPart :: BasePart
	root.Anchored = false
	root.Massless = true
	local rootHeight = if humanoid.RigType == Enum.HumanoidRigType.R6 then 3 else humanoid.HipHeight + hrp.Size.Y / 2
	root.CFrame = hrp.CFrame * CFrame.new(0, SquirrelModel.centerHeight(cfg.Scale) - rootHeight, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hrp
	weld.Part1 = root
	weld.Parent = root
	squirrel.Parent = character

	humanoid.WalkSpeed = cfg.WalkSpeed
end

return CharacterSquirrel
