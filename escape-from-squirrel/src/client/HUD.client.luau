--!strict
-- On-screen interface: round status, objective, team acorn progress, role, carried
-- acorns, a speedometer while driving, and pop-up messages. Built in code; works on
-- phones and PCs.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local player = Players.LocalPlayer
local announceRemote = Remotes.get("Announce")

local FONT = Enum.Font.FredokaOne
local GOLD = Color3.fromRGB(255, 200, 40)
local PANEL = Color3.fromRGB(45, 30, 20)

local gui = Instance.new("ScreenGui")
gui.Name = "SquirrelHUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.3
	l.TextScaled = true
	for k, v in props do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

-- Top panel: status, objective, team progress bar
local top = Instance.new("Frame")
top.AnchorPoint = Vector2.new(0.5, 0)
top.Position = UDim2.new(0.5, 0, 0, 8)
top.Size = UDim2.new(0.6, 0, 0, 96)
top.BackgroundColor3 = PANEL
top.BackgroundTransparency = 0.3
top.Parent = gui
corner(top, 14)
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(640, 96)
limit.MinSize = Vector2.new(300, 80)
limit.Parent = top

local statusLabel = label(top, { Size = UDim2.new(1, -16, 0, 34), Position = UDim2.new(0, 8, 0, 4), Text = "Loading..." })
local objectiveLabel = label(top, {
	Size = UDim2.new(1, -16, 0, 24),
	Position = UDim2.new(0, 8, 0, 40),
	Text = "",
	TextColor3 = Color3.fromRGB(255, 225, 140),
})
local bar = Instance.new("Frame")
bar.Position = UDim2.new(0, 12, 0, 70)
bar.Size = UDim2.new(1, -24, 0, 18)
bar.BackgroundColor3 = Color3.fromRGB(20, 15, 10)
bar.Visible = false
bar.Parent = top
corner(bar, 9)
local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = GOLD
fill.Parent = bar
corner(fill, 9)
local barText = label(bar, { Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 2 })

-- Bottom left: role and carried acorns
local roleLabel = label(gui, {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 12, 1, -96),
	Size = UDim2.new(0, 300, 0, 34),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "",
})
local acornLabel = label(gui, {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 12, 1, -46),
	Size = UDim2.new(0, 220, 0, 44),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = GOLD,
	Text = "",
})

-- Bottom centre: speedometer while in a car
local speedLabel = label(gui, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -24),
	Size = UDim2.new(0, 260, 0, 48),
	Text = "",
	Visible = false,
})

-- Toasts
local toastList = Instance.new("Frame")
toastList.AnchorPoint = Vector2.new(0.5, 0)
toastList.Position = UDim2.new(0.5, 0, 0, 112)
toastList.Size = UDim2.new(0.6, 0, 0, 200)
toastList.BackgroundTransparency = 1
toastList.Parent = gui
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = toastList

local TOAST_COLORS = {
	info = Color3.fromRGB(70, 60, 50),
	good = Color3.fromRGB(40, 150, 70),
	danger = Color3.fromRGB(200, 50, 60),
}
local toastOrder = 0

local function toast(text: string, kind: string?)
	toastOrder += 1
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 32)
	frame.BackgroundColor3 = TOAST_COLORS[kind or "info"] or TOAST_COLORS.info
	frame.BackgroundTransparency = 0.15
	frame.LayoutOrder = toastOrder
	frame.Parent = toastList
	corner(frame, 10)
	local l = label(frame, { Size = UDim2.new(1, -12, 1, -6), Position = UDim2.new(0, 6, 0, 3), Text = text })
	local frames = {}
	for _, c in toastList:GetChildren() do
		if c:IsA("Frame") then
			table.insert(frames, c)
		end
	end
	if #frames > 5 then
		table.sort(frames, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		frames[1]:Destroy()
	end
	task.delay(4, function()
		if frame.Parent then
			TweenService:Create(frame, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(l, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			task.wait(0.5)
			frame:Destroy()
		end
	end)
end

local flash = Instance.new("Frame")
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundTransparency = 1
flash.ZIndex = 10
flash.Parent = gui
local function flashScreen(color: Color3)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 0.3
	TweenService:Create(flash, TweenInfo.new(1.2), { BackgroundTransparency = 1 }):Play()
end

local function formatTime(seconds: number): string
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function refreshStatus()
	local state = ReplicatedStorage:GetAttribute("RoundState")
	local timeLeft = ReplicatedStorage:GetAttribute("TimeLeft") or 0
	local speed = ReplicatedStorage:GetAttribute("SquirrelSpeed") or 0
	if state == "Waiting" then
		statusLabel.Text = "Waiting for players..."
	elseif state == "Intermission" then
		statusLabel.Text = `Next round in {timeLeft}`
	elseif state == "HeadStart" then
		statusLabel.Text = `🐿️ Squirrel wakes up in {timeLeft}... GO!`
	elseif state == "Chase" then
		statusLabel.Text = `⏱️ {formatTime(timeLeft)}   🐿️ Speed {speed}`
	elseif state == "Results" then
		statusLabel.Text = `Round over! Back to lobby in {timeLeft}`
	else
		statusLabel.Text = ""
	end
	objectiveLabel.Text = ReplicatedStorage:GetAttribute("Objective") or ""

	local goal = ReplicatedStorage:GetAttribute("AcornGoal") or 0
	local banked = ReplicatedStorage:GetAttribute("TeamAcorns") or 0
	bar.Visible = goal > 0
	if goal > 0 then
		local ratio = math.clamp(banked / goal, 0, 1)
		TweenService:Create(fill, TweenInfo.new(0.3), { Size = UDim2.fromScale(ratio, 1) }):Play()
		barText.Text = `🌰 Team: {math.min(banked, goal)} / {goal}`
	end
end

local ROLE_TEXT = {
	Lobby = "🏠 In the lobby",
	Runner = "🏃 RUNNER - grab acorns, don't get caught!",
	Minion = "🐿️ SQUIRREL MINION - catch runners!",
	Escaped = "🎈 ESCAPED!",
}

local lastRole = player:GetAttribute("Role")
local function refreshRole()
	local role = player:GetAttribute("Role")
	roleLabel.Text = ROLE_TEXT[role] or ""
	if role == "Minion" and lastRole == "Runner" then
		flashScreen(Color3.fromRGB(165, 98, 52))
	elseif role == "Escaped" then
		flashScreen(Color3.fromRGB(80, 255, 120))
	end
	lastRole = role
end

local function refreshAcorns()
	local n = player:GetAttribute("Acorns")
	acornLabel.Text = if typeof(n) == "number" and n > 0 then `🌰 x {n}` else ""
end

for _, name in { "RoundState", "TimeLeft", "SquirrelSpeed", "Objective", "TeamAcorns", "AcornGoal" } do
	ReplicatedStorage:GetAttributeChangedSignal(name):Connect(refreshStatus)
end
player:GetAttributeChangedSignal("Role"):Connect(refreshRole)
player:GetAttributeChangedSignal("Acorns"):Connect(refreshAcorns)
refreshStatus()
refreshRole()
refreshAcorns()

announceRemote.OnClientEvent:Connect(function(text: string, kind: string?)
	toast(text, kind)
end)

RunService.RenderStepped:Connect(function(dt: number)
	-- Spin the golden acorns (visual only).
	for _, part in CollectionService:GetTagged("Spin") do
		if part:IsA("BasePart") and part:IsDescendantOf(workspace) then
			part.CFrame = part.CFrame * CFrame.Angles(0, dt * 2.5, 0)
		end
	end
	-- Speedometer
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if seat and seat:IsA("VehicleSeat") then
		local speed = seat.AssemblyLinearVelocity.Magnitude
		speedLabel.Visible = true
		speedLabel.Text = `🚗 {math.floor(speed + 0.5)} studs/s`
	else
		speedLabel.Visible = false
	end
end)
