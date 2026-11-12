--!strict
-- Turns a player's character into a donut (Mini Donut when caught, Rogue Donut when
-- they use the Donut Key). The avatar is hidden and a donut is welded in its place.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local DonutModel = require(script.Parent.DonutModel)

local CharacterDonut = {}

function CharacterDonut.apply(character: Model, kind: string)
	local cfg = if kind == "Rogue" then Config.RogueDonut else Config.MiniDonut
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp or not hrp:IsA("BasePart") then
		return
	end

	local old = character:FindFirstChild("DonutBody")
	if old then
		old:Destroy()
	end

	-- Hide the avatar.
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

	local frosting = if kind == "Rogue" then Color3.fromRGB(150, 40, 200) else nil
	local donut = DonutModel.build(cfg.Scale, frosting)
	donut.Name = "DonutBody"
	local root = donut.PrimaryPart :: BasePart
	root.Anchored = false
	root.Massless = true

	-- How far the root part sits above the floor depends on the rig type.
	local rootHeight = if humanoid.RigType == Enum.HumanoidRigType.R6
		then 3
		else humanoid.HipHeight + hrp.Size.Y / 2
	local offsetY = DonutModel.centerHeight(cfg.Scale) - rootHeight
	donut:PivotTo(hrp.CFrame * CFrame.new(0, offsetY, 0)) -- moves every part, not just the root
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hrp
	weld.Part1 = root
	weld.Parent = root
	donut.Parent = character

	humanoid.WalkSpeed = cfg.WalkSpeed
	character:SetAttribute("DonutKind", kind)
end

return CharacterDonut
