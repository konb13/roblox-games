--!strict
-- On-screen interface: round status, objective, role, carried key, toasts and the
-- "Become the Donut" button. Built entirely in code so it works on phones and PCs.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local player = Players.LocalPlayer
local announceRemote = Remotes.get("Announce")
local useDonutKeyRemote = Remotes.get("UseDonutKey")

local FONT = Enum.Font.FredokaOne
local PINK = Color3.fromRGB(255, 105, 180)

local gui = Instance.new("ScreenGui")
gui.Name = "DonutHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
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

-- Top: status + objective
local topBar = Instance.new("Frame")
topBar.AnchorPoint = Vector2.new(0.5, 0)
topBar.Position = UDim2.new(0.5, 0, 0, 8)
topBar.Size = UDim2.new(0.6, 0, 0, 74)
topBar.BackgroundColor3 = Color3.fromRGB(40, 20, 35)
topBar.BackgroundTransparency = 0.35
topBar.Parent = gui
corner(topBar, 14)
local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MaxSize = Vector2.new(620, 74)
sizeLimit.MinSize = Vector2.new(300, 60)
sizeLimit.Parent = topBar

local statusLabel = label(topBar, {
	Size = UDim2.new(1, -16, 0.55, 0),
	Position = UDim2.new(0, 8, 0, 4),
	Text = "Loading...",
})
local objectiveLabel = label(topBar, {
	Size = UDim2.new(1, -16, 0.35, 0),
	Position = UDim2.new(0, 8, 0.6, 0),
	Text = "",
	TextColor3 = Color3.fromRGB(255, 220, 120),
})

-- Left: role + carried key
local roleLabel = label(gui, {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 12, 1, -96),
	Size = UDim2.new(0, 260, 0, 34),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "",
})
local keySlot = Instance.new("Frame")
keySlot.AnchorPoint = Vector2.new(0, 1)
keySlot.Position = UDim2.new(0, 12, 1, -40)
keySlot.Size = UDim2.new(0, 220, 0, 48)
keySlot.BackgroundColor3 = Color3.fromRGB(40, 20, 35)
keySlot.BackgroundTransparency = 0.3
keySlot.Visible = false
keySlot.Parent = gui
corner(keySlot, 12)
local keyStroke = Instance.new("UIStroke")
keyStroke.Thickness = 3
keyStroke.Parent = keySlot
local keyLabel = label(keySlot, {
	Size = UDim2.new(1, -16, 1, -8),
	Position = UDim2.new(0, 8, 0, 4),
	Text = "",
})

-- Right: Donut Key button
local donutButton = Instance.new("TextButton")
donutButton.AnchorPoint = Vector2.new(1, 1)
donutButton.Position = UDim2.new(1, -16, 1, -110)
donutButton.Size = UDim2.new(0, 200, 0, 70)
donutButton.BackgroundColor3 = PINK
donutButton.Font = FONT
donutButton.TextScaled = true
donutButton.TextColor3 = Color3.new(1, 1, 1)
donutButton.Text = "🍩 BECOME THE DONUT (Q)"
donutButton.Visible = false
donutButton.Parent = gui
corner(donutButton, 16)
local buttonStroke = Instance.new("UIStroke")
buttonStroke.Thickness = 3
buttonStroke.Color = Color3.new(1, 1, 1)
buttonStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
buttonStroke.Parent = donutButton

-- Toasts
local toastList = Instance.new("Frame")
toastList.AnchorPoint = Vector2.new(0.5, 0)
toastList.Position = UDim2.new(0.5, 0, 0, 92)
toastList.Size = UDim2.new(0.6, 0, 0, 200)
toastList.BackgroundTransparency = 1
toastList.Parent = gui
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = toastList

local TOAST_COLORS = {
	info = Color3.fromRGB(60, 60, 80),
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
	local children = toastList:GetChildren()
	local frames = 0
	for _, c in children do
		if c:IsA("Frame") then
			frames += 1
		end
	end
	if frames > 5 then
		for _, c in children do
			if c:IsA("Frame") and c ~= frame then
				c:Destroy()
				break
			end
		end
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

-- Full-screen flash (e.g. when you get caught).
local flash = Instance.new("Frame")
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = PINK
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
	local speed = ReplicatedStorage:GetAttribute("DonutSpeed") or 0
	if state == "Waiting" then
		statusLabel.Text = "Waiting for players..."
	elseif state == "Intermission" then
		statusLabel.Text = `Next round in {timeLeft}`
	elseif state == "HeadStart" then
		statusLabel.Text = `🍩 Donut wakes up in {timeLeft}... RUN!`
	elseif state == "Chase" then
		statusLabel.Text = `⏱️ {formatTime(timeLeft)}   🍩 Speed {speed}`
	elseif state == "Results" then
		statusLabel.Text = `Round over! Back to lobby in {timeLeft}`
	else
		statusLabel.Text = ""
	end
	objectiveLabel.Text = ReplicatedStorage:GetAttribute("Objective") or ""
end

local ROLE_TEXT = {
	Lobby = "🏠 In the lobby",
	Runner = "🏃 RUNNER - escape the donut!",
	MiniDonut = "🍩 MINI DONUT - catch runners!",
	RogueDonut = "😈 ROGUE DONUT - catch runners!",
	Escaped = "🎉 ESCAPED!",
}

local lastRole = player:GetAttribute("Role")
local function refreshRole()
	local role = player:GetAttribute("Role")
	roleLabel.Text = ROLE_TEXT[role] or ""
	if role == "MiniDonut" and lastRole == "Runner" then
		flashScreen(PINK)
	elseif role == "Escaped" then
		flashScreen(Color3.fromRGB(80, 255, 120))
	end
	lastRole = role
end

local function refreshKeys()
	local kind = player:GetAttribute("CarryingKey")
	if typeof(kind) == "string" then
		local color = Config.KeyColors[kind] or Color3.new(1, 1, 1)
		keySlot.Visible = true
		keyStroke.Color = color
		keyLabel.TextColor3 = color
		keyLabel.Text = `🔑 {string.upper(kind)} KEY`
	else
		keySlot.Visible = false
	end
	donutButton.Visible = player:GetAttribute("HasDonutKey") == true and player:GetAttribute("Role") == "Runner"
end

for _, name in { "RoundState", "TimeLeft", "DonutSpeed", "Objective" } do
	ReplicatedStorage:GetAttributeChangedSignal(name):Connect(refreshStatus)
end
player:GetAttributeChangedSignal("Role"):Connect(function()
	refreshRole()
	refreshKeys()
end)
player:GetAttributeChangedSignal("CarryingKey"):Connect(refreshKeys)
player:GetAttributeChangedSignal("HasDonutKey"):Connect(refreshKeys)
refreshStatus()
refreshRole()
refreshKeys()

announceRemote.OnClientEvent:Connect(function(text: string, kind: string?)
	toast(text, kind)
end)

-- Donut Key: button or Q.
local function useDonutKey()
	if donutButton.Visible then
		useDonutKeyRemote:FireServer()
	end
end
donutButton.Activated:Connect(useDonutKey)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.Q then
		useDonutKey()
	end
end)

-- Spin and bob the keys lying in the world (visual only, on this client).
RunService.RenderStepped:Connect(function(dt: number)
	for _, part in CollectionService:GetTagged("SpinKey") do
		if part:IsA("BasePart") and part:IsDescendantOf(workspace) then
			part.CFrame = part.CFrame * CFrame.Angles(0, dt * 2, 0)
		end
	end
end)
