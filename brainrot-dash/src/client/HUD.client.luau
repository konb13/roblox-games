--!strict
-- On-screen interface: stats, Chaos Event banner, power hotbar with cooldowns, the
-- Shop, the Brainrot collection, pop-up messages and funny fall messages.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Brainrots = require(Shared:WaitForChild("Brainrots"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local usePower = Remotes.event("UsePower")
local buyPower = Remotes.func("BuyPower")
local equipPet = Remotes.event("EquipPet")

local FONT = Enum.Font.FredokaOne
local PINK = Color3.fromRGB(255, 100, 180)
local PANEL = Color3.fromRGB(35, 20, 55)

local gui = Instance.new("ScreenGui")
gui.Name = "BrainrotHUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

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

local function button(parent: Instance, props: { [string]: any }): TextButton
	local b = Instance.new("TextButton")
	b.Font = FONT
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextScaled = true
	b.AutoButtonColor = true
	for k, v in props do
		(b :: any)[k] = v
	end
	b.Parent = parent
	corner(b, 12)
	return b
end

local function frame(parent: Instance, props: { [string]: any }): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in props do
		(f :: any)[k] = v
	end
	f.Parent = parent
	return f
end

-- ------------------------------------------------------------------ stats (top left)

local stats = frame(gui, {
	Position = UDim2.new(0, 10, 0, 10),
	Size = UDim2.new(0, 210, 0, 128),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.25,
})
corner(stats, 14)
local coinsLabel = label(stats, { Position = UDim2.new(0, 10, 0, 4), Size = UDim2.new(1, -20, 0, 34), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 210, 60) })
local incomeLabel = label(stats, { Position = UDim2.new(0, 10, 0, 38), Size = UDim2.new(1, -20, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(150, 255, 150) })
local stageLabel = label(stats, { Position = UDim2.new(0, 10, 0, 60), Size = UDim2.new(1, -20, 0, 22), TextXAlignment = Enum.TextXAlignment.Left })
local miscLabel = label(stats, { Position = UDim2.new(0, 10, 0, 86), Size = UDim2.new(1, -20, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(220, 200, 255) })

local timerLabel = label(gui, {
	Position = UDim2.new(0, 10, 0, 144),
	Size = UDim2.new(0, 210, 0, 40),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(120, 255, 255),
	Text = "",
})
local bestLabel = label(gui, {
	Position = UDim2.new(0, 10, 0, 184),
	Size = UDim2.new(0, 210, 0, 22),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(200, 240, 255),
	Text = "",
})
local function formatTime(seconds: number): string
	return string.format("%d:%05.2f", seconds // 60, seconds % 60)
end

local function formatNumber(n: number): string
	n = math.floor(n)
	if n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e4 then
		return string.format("%.1fK", n / 1e3)
	end
	return tostring(n)
end

local function statValue(name: string): number
	local ls = player:FindFirstChild("leaderstats")
	local v = ls and ls:FindFirstChild(name)
	return if v and v:IsA("IntValue") then v.Value else 0
end

local function refreshStats()
	coinsLabel.Text = `💰 {formatNumber(statValue("Coins"))}`
	local income = player:GetAttribute("Income")
	incomeLabel.Text = `+{formatNumber(if typeof(income) == "number" then income else 0)} coins/s`
	local cp = player:GetAttribute("Checkpoint")
	stageLabel.Text = `🏁 Stage {if typeof(cp) == "number" then cp else 0}/10  (best {statValue("Stage")})`
	local falls = player:GetAttribute("Falls")
	miscLabel.Text = `♻️ Rebirths {statValue("Rebirths")}   💀 Falls {if typeof(falls) == "number" then falls else 0}`
end

task.spawn(function()
	local ls = player:WaitForChild("leaderstats")
	for _, v in ls:GetChildren() do
		if v:IsA("IntValue") then
			v.Changed:Connect(refreshStats)
		end
	end
	ls.ChildAdded:Connect(function(v)
		if v:IsA("IntValue") then
			v.Changed:Connect(refreshStats)
		end
		refreshStats()
	end)
	refreshStats()
end)
for _, a in { "Income", "Checkpoint", "Falls" } do
	player:GetAttributeChangedSignal(a):Connect(refreshStats)
end
refreshStats()

-- ------------------------------------------------------------------ chaos banner (top centre)

local CHAOS_TEXT = {
	LowGravity = "🌙 LOW GRAVITY",
	SpeedFrenzy = "⚡ SPEED FRENZY",
	CoinRain = "💰 COIN RAIN",
	TileShuffle = "🔀 TILE SHUFFLE",
}
local chaosBanner = frame(gui, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.new(0, 300, 0, 50),
	BackgroundColor3 = Color3.fromRGB(255, 60, 120),
	Visible = false,
})
corner(chaosBanner, 14)
local chaosLabel = label(chaosBanner, { Size = UDim2.new(1, -16, 1, -8), Position = UDim2.new(0, 8, 0, 4) })

-- ------------------------------------------------------------------ toasts

local toastList = frame(gui, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 70),
	Size = UDim2.new(0.5, 0, 0, 180),
	BackgroundTransparency = 1,
})
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = toastList
local TOAST_COLORS = {
	info = Color3.fromRGB(70, 50, 100),
	good = Color3.fromRGB(40, 150, 70),
	danger = Color3.fromRGB(200, 50, 90),
}
local toastOrder = 0
local function toast(text: string, kind: string?)
	toastOrder += 1
	local f = frame(toastList, {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = TOAST_COLORS[kind or "info"] or TOAST_COLORS.info,
		BackgroundTransparency = 0.15,
		LayoutOrder = toastOrder,
	})
	corner(f, 10)
	local l = label(f, { Size = UDim2.new(1, -12, 1, -6), Position = UDim2.new(0, 6, 0, 3), Text = text })
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
		if f.Parent then
			TweenService:Create(f, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(l, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			task.wait(0.5)
			f:Destroy()
		end
	end)
end
Remotes.event("Announce").OnClientEvent:Connect(toast)

-- ------------------------------------------------------------------ fall messages

local FALL_LINES = {
	"YOU FELL FOR IT 💀",
	"SKILL ISSUE 😭",
	"GRAVITY SAYS HI 👋",
	"THAT TILE WAS LYING 🤥",
	"BRO REALLY JUMPED 💀",
	"NOT THE VOID AGAIN 😩",
	"CERTIFIED FALL MOMENT 🏅",
	"THE FLOOR WAS FAKE 🫠",
}
local fallText = label(gui, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.4),
	Size = UDim2.new(0.7, 0, 0, 70),
	TextColor3 = Color3.fromRGB(255, 80, 120),
	TextTransparency = 1,
	TextStrokeTransparency = 1,
	ZIndex = 5,
})
Remotes.event("Fell").OnClientEvent:Connect(function(falls: number)
	fallText.Text = FALL_LINES[math.random(1, #FALL_LINES)] .. `\nFall #{falls}`
	fallText.TextTransparency = 0
	fallText.TextStrokeTransparency = 0
	fallText.Rotation = math.random(-8, 8)
	TweenService:Create(fallText, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
end)

-- ------------------------------------------------------------------ power hotbar (bottom)

local KEY_NAMES = {
	[Enum.KeyCode.One] = "1",
	[Enum.KeyCode.Two] = "2",
	[Enum.KeyCode.Three] = "3",
	[Enum.KeyCode.Four] = "4",
	[Enum.KeyCode.Five] = "5",
}
local hotbar = frame(gui, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -14),
	Size = UDim2.new(0, 0, 0, 70),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
})
local hotbarLayout = Instance.new("UIListLayout")
hotbarLayout.FillDirection = Enum.FillDirection.Horizontal
hotbarLayout.Padding = UDim.new(0, 8)
hotbarLayout.SortOrder = Enum.SortOrder.LayoutOrder
hotbarLayout.Parent = hotbar

local cooldownEnds: { [string]: number } = {}
local cooldownTotal: { [string]: number } = {}
local slotShades: { [string]: Frame } = {}

local function owns(id: string): boolean
	return player:GetAttribute("Power_" .. id) == true
end

local function rebuildHotbar()
	for _, c in hotbar:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	slotShades = {}
	for i, p in Config.Powers do
		if not p.passive and owns(p.id) then
			local slot = button(hotbar, {
				Size = UDim2.new(0, 70, 0, 70),
				BackgroundColor3 = PANEL,
				BackgroundTransparency = 0.15,
				Text = p.icon,
				LayoutOrder = i,
			})
			label(slot, {
				Size = UDim2.new(0, 20, 0, 20),
				Position = UDim2.new(0, 4, 0, 2),
				Text = if p.key then KEY_NAMES[p.key] or "" else "",
				TextColor3 = Color3.fromRGB(255, 220, 120),
				ZIndex = 3,
			})
			local shade = frame(slot, {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.fromScale(1, 0),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.4,
				ZIndex = 2,
			})
			corner(shade, 12)
			slotShades[p.id] = shade
			slot.Activated:Connect(function()
				usePower:FireServer(p.id)
			end)
		end
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	for _, p in Config.Powers do
		if p.key and input.KeyCode == p.key and owns(p.id) then
			usePower:FireServer(p.id)
		end
	end
end)

Remotes.event("PowerActivated").OnClientEvent:Connect(function(id: string, _duration: number, cooldown: number)
	cooldownEnds[id] = os.clock() + cooldown
	cooldownTotal[id] = cooldown
end)

-- ------------------------------------------------------------------ side buttons + panels

local shopButton = button(gui, {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -12, 0.5, -40),
	Size = UDim2.new(0, 120, 0, 60),
	BackgroundColor3 = Color3.fromRGB(255, 170, 40),
	Text = "🛒 Shop",
})
local collectionButton = button(gui, {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -12, 0.5, 30),
	Size = UDim2.new(0, 120, 0, 60),
	BackgroundColor3 = PINK,
	Text = "🧠 Brainrots",
})

local function makePanel(title: string): (Frame, ScrollingFrame)
	local panel = frame(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.8, 0, 0.75, 0),
		BackgroundColor3 = PANEL,
		Visible = false,
		ZIndex = 20,
	})
	corner(panel, 18)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(720, 520)
	limit.Parent = panel
	label(panel, { Size = UDim2.new(1, -80, 0, 44), Position = UDim2.new(0, 16, 0, 8), Text = title, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21 })
	local close = button(panel, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.new(0, 44, 0, 44),
		BackgroundColor3 = Color3.fromRGB(220, 60, 80),
		Text = "✕",
		ZIndex = 21,
	})
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.new(0, 12, 0, 62)
	list.Size = UDim2.new(1, -24, 1, -74)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 8
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ZIndex = 21
	list.Parent = panel
	return panel, list
end

local shopPanel, shopList = makePanel("🛒 Superpowers")
local shopLayout = Instance.new("UIListLayout")
shopLayout.Padding = UDim.new(0, 8)
shopLayout.SortOrder = Enum.SortOrder.LayoutOrder
shopLayout.Parent = shopList

local collectionPanel, collectionList = makePanel("🧠 Your Brainrots")
local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.new(0, 160, 0, 178)
grid.CellPadding = UDim2.new(0, 10, 0, 10)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = collectionList

local function rebuildShop()
	for _, c in shopList:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	for i, p in Config.Powers do
		local row = frame(shopList, {
			Size = UDim2.new(1, -12, 0, 76),
			BackgroundColor3 = Color3.fromRGB(60, 40, 90),
			LayoutOrder = i,
			ZIndex = 22,
		})
		corner(row, 12)
		label(row, { Size = UDim2.new(0, 60, 0, 60), Position = UDim2.new(0, 8, 0, 8), Text = p.icon, ZIndex = 23 })
		label(row, {
			Position = UDim2.new(0, 76, 0, 6),
			Size = UDim2.new(1, -230, 0, 30),
			Text = p.name .. (if p.passive then " (always on)" else ""),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 23,
		})
		label(row, {
			Position = UDim2.new(0, 76, 0, 38),
			Size = UDim2.new(1, -230, 0, 30),
			Text = p.description,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(210, 200, 230),
			TextScaled = true,
			ZIndex = 23,
		})
		local owned = owns(p.id)
		local buy = button(row, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.new(0, 140, 0, 52),
			BackgroundColor3 = if owned then Color3.fromRGB(90, 90, 110) else Color3.fromRGB(60, 200, 90),
			Text = if owned then "Owned ✔" else `💰 {formatNumber(p.price)}`,
			ZIndex = 23,
		})
		if not owned then
			buy.Activated:Connect(function()
				local ok, message = buyPower:InvokeServer(p.id)
				toast(message, if ok then "good" else "danger")
			end)
		end
	end
end

local function rebuildCollection()
	for _, c in collectionList:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local pet = player:GetAttribute("Pet")
	for i, info in Brainrots.List do
		local owned = player:GetAttribute("Brainrot_" .. info.id) == true
		local color = Brainrots.RarityColors[info.rarity]
		local card = frame(collectionList, {
			BackgroundColor3 = if owned then Color3.fromRGB(60, 40, 90) else Color3.fromRGB(40, 35, 50),
			LayoutOrder = i,
			ZIndex = 22,
		})
		corner(card, 12)
		local stroke = Instance.new("UIStroke")
		stroke.Color = color
		stroke.Thickness = if owned then 3 else 1
		stroke.Parent = card
		label(card, {
			Position = UDim2.new(0, 6, 0, 6),
			Size = UDim2.new(1, -12, 0, 40),
			Text = if owned then info.name else "???",
			ZIndex = 23,
		})
		label(card, {
			Position = UDim2.new(0, 6, 0, 48),
			Size = UDim2.new(1, -12, 0, 24),
			Text = info.rarity,
			TextColor3 = color,
			ZIndex = 23,
		})
		label(card, {
			Position = UDim2.new(0, 6, 0, 74),
			Size = UDim2.new(1, -12, 0, 22),
			Text = if owned then `+{info.income} coins/s` else `Clear stage {info.stage}`,
			TextColor3 = Color3.fromRGB(200, 255, 200),
			ZIndex = 23,
		})
		if owned then
			label(card, {
				Position = UDim2.new(0, 6, 0, 98),
				Size = UDim2.new(1, -12, 0, 30),
				Text = `"{info.chant}"`,
				TextColor3 = Color3.fromRGB(255, 220, 150),
				Font = Enum.Font.GothamMedium,
				ZIndex = 23,
			})
		end
		if owned then
			local equipped = pet == info.id
			local b = button(card, {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -8),
				Size = UDim2.new(1, -20, 0, 36),
				BackgroundColor3 = if equipped then Color3.fromRGB(90, 90, 110) else PINK,
				Text = if equipped then "Following you" else "Equip pet",
				ZIndex = 23,
			})
			b.Activated:Connect(function()
				equipPet:FireServer(info.id)
			end)
		end
	end
end

shopButton.Activated:Connect(function()
	collectionPanel.Visible = false
	shopPanel.Visible = not shopPanel.Visible
	if shopPanel.Visible then
		rebuildShop()
	end
end)
collectionButton.Activated:Connect(function()
	shopPanel.Visible = false
	collectionPanel.Visible = not collectionPanel.Visible
	if collectionPanel.Visible then
		rebuildCollection()
	end
end)

-- Rebuild things when ownership changes.
player.AttributeChanged:Connect(function(name)
	if string.sub(name, 1, 6) == "Power_" then
		rebuildHotbar()
		if shopPanel.Visible then
			rebuildShop()
		end
	elseif (string.sub(name, 1, 9) == "Brainrot_" or name == "Pet") and collectionPanel.Visible then
		rebuildCollection()
	end
end)
rebuildHotbar()

-- ------------------------------------------------------------------ per-frame updates

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for id, shade in slotShades do
		local ends, total = cooldownEnds[id], cooldownTotal[id]
		local left = if ends and total and total > 0 then math.max(0, ends - now) / total else 0
		shade.Size = UDim2.fromScale(1, left)
	end

	local runStart = player:GetAttribute("RunStart")
	timerLabel.Text = if typeof(runStart) == "number"
		then `⏱️ {formatTime(workspace:GetServerTimeNow() - runStart)}`
		else "⏱️ Cross the start line!"
	local best = player:GetAttribute("BestTime")
	bestLabel.Text = if typeof(best) == "number" then `🏆 Best {formatTime(best)}` else ""

	local event = ReplicatedStorage:GetAttribute("ChaosEvent")
	if typeof(event) == "string" and event ~= "" then
		local ends = ReplicatedStorage:GetAttribute("ChaosEnds")
		local left = if typeof(ends) == "number" then math.max(0, math.ceil(ends - workspace:GetServerTimeNow())) else 0
		chaosBanner.Visible = true
		chaosLabel.Text = `{CHAOS_TEXT[event] or event}  {left}s`
	else
		chaosBanner.Visible = false
	end
end)
