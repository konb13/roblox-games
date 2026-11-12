--!strict
-- The brainrot creatures you rescue (one at the end of every stage). Each one earns
-- coins every second and can follow you around as a pet.
--
-- They're in the classic brainrot style (an animal fused with an everyday object, an
-- Italian-sounding name, sneakers, a catchphrase) but they are ORIGINAL characters.
-- Copying the famous meme characters can get a Roblox game taken down.
--
-- Built from plain parts so no uploads are needed. Want a fancier model? Put a Model
-- named after the brainrot's id (e.g. "GattinoFrullatino") in a folder called
-- ReplicatedStorage/BrainrotModels. It will be used instead, scaled to fit, facing -Z.
-- Shared so the server (pedestals) and clients (pets) can both build them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brainrots = {}

export type Info = {
	id: string,
	name: string,
	chant: string, -- its catchphrase
	rarity: string,
	income: number, -- coins per second
	stage: number, -- rescued at the end of this stage
}

Brainrots.List = {
	{ id = "GattinoFrullatino", name = "Gattino Frullatino", chant = "Frulla frulla, miao miao!", rarity = "Common", income = 1, stage = 1 },
	{ id = "PomodoroMotorino", name = "Pomodoro Motorino", chant = "Brum brum, pomodorum!", rarity = "Common", income = 2, stage = 2 },
	{ id = "RanocchioLavatrice", name = "Ranocchio Lavatrice", chant = "Splish splash, ribbit-centrifuga!", rarity = "Uncommon", income = 4, stage = 3 },
	{ id = "PinguinoPizzaiolo", name = "Pinguino Pizzaiolo", chant = "Margherita per tutti!", rarity = "Uncommon", income = 6, stage = 4 },
	{ id = "CammelloCaffettiera", name = "Cammello Caffettiera", chant = "Espresso nel deserto!", rarity = "Rare", income = 10, stage = 5 },
	{ id = "PolpoPantofolo", name = "Polpo Pantofolo", chant = "Otto pantofole, zero problemi!", rarity = "Rare", income = 15, stage = 6 },
	{ id = "ElefantinoAspirapolvere", name = "Elefantino Aspirapolvere", chant = "Aspira aspira, tutto sparisce!", rarity = "Epic", income = 25, stage = 7 },
	{ id = "GufoGuantone", name = "Gufo Guantone", chant = "Uh-uh! Un pugno per te!", rarity = "Epic", income = 40, stage = 8 },
	{ id = "TartarugaTrattore", name = "Tartaruga Trattore", chant = "Piano piano... ma col trattore!", rarity = "Legendary", income = 60, stage = 9 },
	{ id = "GiraffaGelatona", name = "Giraffa Gelatona", chant = "Gelato altissimo, ciao ciao!", rarity = "Mythic", income = 100, stage = 10 },
} :: { Info }

Brainrots.RarityColors = {
	Common = Color3.fromRGB(200, 200, 200),
	Uncommon = Color3.fromRGB(90, 220, 110),
	Rare = Color3.fromRGB(70, 150, 255),
	Epic = Color3.fromRGB(190, 90, 255),
	Legendary = Color3.fromRGB(255, 170, 40),
	Mythic = Color3.fromRGB(255, 70, 140),
} :: { [string]: Color3 }

function Brainrots.get(id: string): Info?
	for _, info in Brainrots.List do
		if info.id == id then
			return info
		end
	end
	return nil
end

function Brainrots.forStage(stage: number): Info?
	for _, info in Brainrots.List do
		if info.stage == stage then
			return info
		end
	end
	return nil
end

-- ------------------------------------------------------------------ part specs

type Spec = {
	s: string, -- "ball" | "block" | "wedge" | "vcyl" (upright cylinder, size = (diameter, height, diameter)) | "xcyl" (cylinder along X, size = (length, d, d))
	size: Vector3,
	pos: Vector3,
	color: Color3,
	mat: Enum.Material?,
	rot: Vector3?, -- degrees
	alpha: number?,
}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.fromRGB(20, 20, 20)
local MOUTH = Color3.fromRGB(90, 20, 30)
local METAL = Color3.fromRGB(190, 195, 205)
local PINK = Color3.fromRGB(255, 140, 170)
local ORANGE = Color3.fromRGB(255, 140, 30)

local function add(l: { Spec }, s: string, size: Vector3, pos: Vector3, color: Color3, extra: { mat: Enum.Material?, rot: Vector3?, alpha: number? }?)
	table.insert(l, {
		s = s,
		size = size,
		pos = pos,
		color = color,
		mat = extra and extra.mat,
		rot = extra and extra.rot,
		alpha = extra and extra.alpha,
	})
end

-- Big googly eyes with a little shine.
local function eyes(l: { Spec }, x: number, y: number, z: number, size: number)
	for _, side in { -1, 1 } do
		add(l, "ball", Vector3.one * size, Vector3.new(side * x, y, z), WHITE)
		add(l, "ball", Vector3.one * size * 0.5, Vector3.new(side * x + side * 0.05, y - size * 0.05, z - size * 0.33), BLACK)
		add(l, "ball", Vector3.one * size * 0.16, Vector3.new(side * x + 0.08, y + size * 0.12, z - size * 0.5), WHITE)
	end
end

-- The brainrot staple: a chunky sneaker with a white sole and a side stripe.
local function sneaker(l: { Spec }, x: number, y: number, z: number, s: number, color: Color3)
	add(l, "block", Vector3.new(1.1, 0.3, 1.8) * s, Vector3.new(x, y, z - 0.15 * s), WHITE)
	add(l, "block", Vector3.new(1, 0.65, 1.45) * s, Vector3.new(x, y + 0.45 * s, z), color)
	add(l, "ball", Vector3.one * 0.95 * s, Vector3.new(x, y + 0.35 * s, z - 0.75 * s), color)
	add(l, "block", Vector3.new(1.04, 0.14, 0.9) * s, Vector3.new(x, y + 0.45 * s, z + 0.05 * s), WHITE, { rot = Vector3.new(15, 0, 0) })
end

local function leg(l: { Spec }, x: number, top: number, bottom: number, z: number, width: number, color: Color3)
	add(l, "block", Vector3.new(width, top - bottom, width), Vector3.new(x, (top + bottom) / 2, z), color)
end

local SPECS: { [string]: () -> { Spec } } = {
	-- A cat that is also a blender, mid-smoothie.
	GattinoFrullatino = function()
		local l: { Spec } = {}
		local fur = Color3.fromRGB(255, 160, 60)
		add(l, "block", Vector3.new(2.6, 1.2, 2.6), Vector3.new(0, -2, 0), Color3.fromRGB(80, 80, 90))
		add(l, "block", Vector3.new(0.4, 0.3, 0.1), Vector3.new(-0.5, -2, -1.32), Color3.fromRGB(255, 60, 60), { mat = Enum.Material.Neon })
		add(l, "block", Vector3.new(0.4, 0.3, 0.1), Vector3.new(0.5, -2, -1.32), Color3.fromRGB(60, 255, 90), { mat = Enum.Material.Neon })
		add(l, "vcyl", Vector3.new(2.2, 3, 2.2), Vector3.new(0, -0.1, 0), Color3.fromRGB(190, 230, 255), { mat = Enum.Material.Glass, alpha = 0.45 })
		add(l, "vcyl", Vector3.new(1.9, 1.5, 1.9), Vector3.new(0, -0.8, 0), Color3.fromRGB(255, 120, 170), { alpha = 0.1 })
		add(l, "vcyl", Vector3.new(2.35, 0.4, 2.35), Vector3.new(0, 1.55, 0), BLACK)
		add(l, "ball", Vector3.one * 2.5, Vector3.new(0, 2.9, 0), fur)
		add(l, "ball", Vector3.one * 1.1, Vector3.new(0, 2.6, -0.8), Color3.fromRGB(255, 230, 200))
		for _, side in { -1, 1 } do
			add(l, "wedge", Vector3.new(0.4, 1, 0.9), Vector3.new(side * 0.75, 4.15, 0), fur, { rot = Vector3.new(0, 0, side * -15) })
			add(l, "block", Vector3.new(1.1, 0.05, 0.05), Vector3.new(side * 0.95, 2.6, -1.15), BLACK, { rot = Vector3.new(0, 0, side * 10) })
			leg(l, side * 0.8, -2.6, -3, -0.1, 0.35, fur)
			sneaker(l, side * 0.8, -3.15, -0.1, 0.7, Color3.fromRGB(60, 120, 255))
		end
		add(l, "ball", Vector3.one * 0.35, Vector3.new(0, 2.85, -1.25), PINK)
		eyes(l, 0.5, 3.15, -1.05, 0.6)
		return l
	end,

	-- A tomato riding a tiny scooter.
	PomodoroMotorino = function()
		local l: { Spec } = {}
		local leaf = Color3.fromRGB(60, 170, 60)
		add(l, "ball", Vector3.one * 3.4, Vector3.new(0, 0.4, 0), Color3.fromRGB(230, 40, 40))
		for i = 0, 2 do
			add(l, "block", Vector3.new(1.5, 0.15, 0.45), Vector3.new(0, 2.12, 0), leaf, { rot = Vector3.new(0, i * 60, 0) })
		end
		add(l, "vcyl", Vector3.new(0.25, 0.6, 0.25), Vector3.new(0, 2.4, 0), leaf)
		add(l, "block", Vector3.new(0.9, 0.18, 0.1), Vector3.new(0, -0.15, -1.62), MOUTH)
		add(l, "block", Vector3.new(1.3, 0.3, 3.6), Vector3.new(0, -1.7, 0), Color3.fromRGB(40, 40, 50))
		add(l, "xcyl", Vector3.new(0.4, 1, 1), Vector3.new(0, -2.1, -1.5), BLACK)
		add(l, "xcyl", Vector3.new(0.4, 1, 1), Vector3.new(0, -2.1, 1.5), BLACK)
		add(l, "block", Vector3.new(0.2, 2.6, 0.2), Vector3.new(0, -0.4, -1.85), METAL, { mat = Enum.Material.Metal })
		add(l, "block", Vector3.new(1.8, 0.2, 0.2), Vector3.new(0, 0.9, -1.85), METAL, { mat = Enum.Material.Metal })
		add(l, "ball", Vector3.one * 0.35, Vector3.new(0, 0.5, -2), Color3.fromRGB(255, 240, 150), { mat = Enum.Material.Neon })
		eyes(l, 0.6, 0.95, -1.45, 0.75)
		for _, side in { -1, 1 } do
			add(l, "block", Vector3.new(0.25, 1.4, 0.25), Vector3.new(side * 0.85, 0.2, -1.4), Color3.fromRGB(230, 40, 40), { rot = Vector3.new(-60, 0, 0) })
		end
		return l
	end,

	-- A frog living inside a washing machine.
	RanocchioLavatrice = function()
		local l: { Spec } = {}
		local frog = Color3.fromRGB(90, 200, 90)
		add(l, "block", Vector3.new(3, 3.4, 2.8), Vector3.new(0, -0.8, 0), Color3.fromRGB(245, 248, 252))
		add(l, "block", Vector3.new(3, 0.6, 0.1), Vector3.new(0, 0.6, -1.42), Color3.fromRGB(60, 60, 70))
		add(l, "ball", Vector3.one * 0.4, Vector3.new(1, 0.6, -1.5), METAL)
		add(l, "xcyl", Vector3.new(0.2, 2.1, 2.1), Vector3.new(0, -1, -1.42), METAL, { rot = Vector3.new(0, 90, 0), mat = Enum.Material.Metal })
		add(l, "xcyl", Vector3.new(0.25, 1.7, 1.7), Vector3.new(0, -1, -1.48), Color3.fromRGB(120, 200, 255), { rot = Vector3.new(0, 90, 0), mat = Enum.Material.Glass, alpha = 0.3 })
		add(l, "ball", Vector3.one * 2.9, Vector3.new(0, 2.2, 0.2), frog)
		add(l, "block", Vector3.new(1.9, 0.15, 0.15), Vector3.new(0, 1.75, -1.25), MOUTH)
		for _, p in { Vector3.new(1.5, 2.6, -1.2), Vector3.new(-1.6, 1.9, -1), Vector3.new(1.7, 0.2, -1.5) } do
			add(l, "ball", Vector3.one * 0.45, p, WHITE, { mat = Enum.Material.Glass, alpha = 0.4 })
		end
		for _, side in { -1, 1 } do
			leg(l, side * 0.9, -2.5, -2.9, 0, 0.35, frog)
			sneaker(l, side * 0.9, -3.05, 0, 0.75, Color3.fromRGB(255, 220, 40))
		end
		eyes(l, 0.75, 3.45, -0.45, 1.05)
		return l
	end,

	-- A penguin chef proudly holding a pizza.
	PinguinoPizzaiolo = function()
		local l: { Spec } = {}
		add(l, "ball", Vector3.one * 3.2, Vector3.new(0, -0.3, 0), BLACK)
		add(l, "ball", Vector3.one * 2.6, Vector3.new(0, -0.4, -0.5), WHITE)
		add(l, "ball", Vector3.one * 2.2, Vector3.new(0, 1.9, 0), BLACK)
		add(l, "ball", Vector3.one * 1.6, Vector3.new(0, 1.8, -0.5), WHITE)
		add(l, "wedge", Vector3.new(0.6, 0.4, 0.8), Vector3.new(0, 1.65, -1.35), ORANGE, { rot = Vector3.new(0, 180, 0) })
		add(l, "vcyl", Vector3.new(1.6, 1.2, 1.6), Vector3.new(0, 3.2, 0), WHITE)
		add(l, "ball", Vector3.one * 1.9, Vector3.new(0, 3.9, 0), WHITE)
		add(l, "block", Vector3.new(0.5, 0.12, 0.08), Vector3.new(0, 1.3, -1.25), Color3.fromRGB(200, 40, 40)) -- little moustache
		-- Pizza on one flipper
		add(l, "wedge", Vector3.new(0.4, 1.6, 0.8), Vector3.new(1.75, 0.2, -0.3), BLACK, { rot = Vector3.new(0, 0, -50) })
		add(l, "vcyl", Vector3.new(2.6, 0.2, 2.6), Vector3.new(2.2, 1.1, -0.6), Color3.fromRGB(255, 205, 90))
		add(l, "vcyl", Vector3.new(2.3, 0.22, 2.3), Vector3.new(2.2, 1.12, -0.6), Color3.fromRGB(230, 70, 40))
		for _, p in { Vector3.new(1.7, 1.25, -0.9), Vector3.new(2.6, 1.25, -0.2), Vector3.new(2.4, 1.25, -1.2) } do
			add(l, "vcyl", Vector3.new(0.5, 0.1, 0.5), p, Color3.fromRGB(170, 30, 30))
		end
		add(l, "wedge", Vector3.new(0.4, 1.6, 0.8), Vector3.new(-1.75, -0.3, -0.1), BLACK, { rot = Vector3.new(0, 0, 30) })
		for _, side in { -1, 1 } do
			sneaker(l, side * 0.8, -2.1, -0.2, 0.75, Color3.fromRGB(230, 40, 40))
		end
		eyes(l, 0.35, 2.1, -1.1, 0.5)
		return l
	end,

	-- A camel whose humps are two steaming moka pots.
	CammelloCaffettiera = function()
		local l: { Spec } = {}
		local tan = Color3.fromRGB(215, 170, 110)
		add(l, "block", Vector3.new(1.8, 1.8, 3.6), Vector3.new(0, 0, 0.2), tan)
		add(l, "block", Vector3.new(0.75, 2.4, 0.75), Vector3.new(0, 1.2, -1.75), tan, { rot = Vector3.new(-20, 0, 0) })
		add(l, "block", Vector3.new(0.95, 0.85, 1.5), Vector3.new(0, 2.5, -2.35), tan)
		add(l, "block", Vector3.new(0.7, 0.12, 0.1), Vector3.new(0, 2.2, -3.12), MOUTH)
		for _, z in { -0.5, 1 } do
			add(l, "vcyl", Vector3.new(1.05, 1, 1.05), Vector3.new(0, 1.4, z), METAL, { mat = Enum.Material.Metal })
			add(l, "vcyl", Vector3.new(0.85, 0.9, 0.85), Vector3.new(0, 2.3, z), METAL, { mat = Enum.Material.Metal })
			add(l, "ball", Vector3.one * 0.55, Vector3.new(0, 2.85, z), BLACK)
			add(l, "block", Vector3.new(0.2, 0.75, 0.2), Vector3.new(0.6, 2.1, z), BLACK)
			add(l, "ball", Vector3.one * 0.6, Vector3.new(0, 3.5, z - 0.2), WHITE, { alpha = 0.5 })
			add(l, "ball", Vector3.one * 0.45, Vector3.new(0.2, 4, z - 0.4), WHITE, { alpha = 0.6 })
		end
		for _, x in { -0.6, 0.6 } do
			for _, z in { -1.1, 1.5 } do
				leg(l, x, -0.9, -2.6, z, 0.4, tan)
				sneaker(l, x, -2.75, z, 0.55, Color3.fromRGB(90, 60, 200))
			end
		end
		eyes(l, 0.35, 2.75, -2.75, 0.45)
		return l
	end,

	-- An octopus wearing a fluffy slipper on every tentacle.
	PolpoPantofolo = function()
		local l: { Spec } = {}
		local purple = Color3.fromRGB(170, 80, 220)
		add(l, "ball", Vector3.one * 3.3, Vector3.new(0, 1.2, 0), purple)
		add(l, "ball", Vector3.one * 0.5, Vector3.new(0, 0.45, -1.5), MOUTH)
		add(l, "ball", Vector3.one * 0.45, Vector3.new(0.9, 2.3, -1.1), Color3.fromRGB(220, 140, 255))
		add(l, "ball", Vector3.one * 0.35, Vector3.new(-1, 2.5, -0.8), Color3.fromRGB(220, 140, 255))
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2 + math.pi / 6
			local cx, cz = math.cos(a), math.sin(a)
			add(l, "block", Vector3.new(0.5, 1.9, 0.5), Vector3.new(cx * 1.05, -0.65, cz * 1.05), purple, {
				rot = Vector3.new(math.deg(math.asin(cz)) * 0.45, 0, -math.deg(math.asin(cx)) * 0.45),
			})
			add(l, "block", Vector3.new(0.9, 0.45, 1.3), Vector3.new(cx * 1.6, -1.65, cz * 1.6 - 0.15), PINK, {
				mat = Enum.Material.Fabric,
				rot = Vector3.new(0, -math.deg(a) + 90, 0),
			})
			add(l, "ball", Vector3.one * 0.5, Vector3.new(cx * 1.6, -1.35, cz * 1.6 - 0.6), WHITE, { mat = Enum.Material.Fabric })
		end
		eyes(l, 0.65, 1.45, -1.35, 0.85)
		return l
	end,

	-- An elephant whose trunk is a vacuum-cleaner hose.
	ElefantinoAspirapolvere = function()
		local l: { Spec } = {}
		local grey = Color3.fromRGB(150, 155, 170)
		local hose = Color3.fromRGB(60, 60, 70)
		add(l, "ball", Vector3.one * 3.4, Vector3.new(0, -0.2, 0.3), grey)
		add(l, "ball", Vector3.one * 2.6, Vector3.new(0, 1.4, -1), grey)
		for _, side in { -1, 1 } do
			add(l, "block", Vector3.new(0.2, 2, 1.8), Vector3.new(side * 1.45, 1.5, -0.6), grey, { rot = Vector3.new(0, side * 25, 0) })
			add(l, "block", Vector3.new(0.12, 1.5, 1.3), Vector3.new(side * 1.38, 1.5, -0.68), PINK, { rot = Vector3.new(0, side * 25, 0) })
		end
		for i, p in { Vector3.new(0, 0.9, -2.15), Vector3.new(0, 0.3, -2.45), Vector3.new(0, -0.35, -2.6), Vector3.new(0, -1, -2.65), Vector3.new(0, -1.6, -2.65) } do
			add(l, "ball", Vector3.one * (0.85 - i * 0.04), p, hose)
		end
		add(l, "block", Vector3.new(1.7, 0.3, 0.7), Vector3.new(0, -2.05, -2.85), hose)
		add(l, "block", Vector3.new(1.4, 1.6, 2), Vector3.new(0, 1.2, 1.8), Color3.fromRGB(230, 50, 50))
		add(l, "xcyl", Vector3.new(1.6, 0.6, 0.6), Vector3.new(0, 0.4, 2.8), BLACK)
		add(l, "ball", Vector3.one * 0.35, Vector3.new(0.45, 1.6, 2.82), Color3.fromRGB(80, 255, 120), { mat = Enum.Material.Neon })
		for _, x in { -0.9, 0.9 } do
			for _, z in { -0.4, 1 } do
				add(l, "vcyl", Vector3.new(0.85, 1.1, 0.85), Vector3.new(x, -1.85, z), grey)
				sneaker(l, x, -2.55, z, 0.65, WHITE)
			end
		end
		eyes(l, 0.6, 1.85, -2.05, 0.55)
		return l
	end,

	-- An owl in boxing gloves and a sweatband.
	GufoGuantone = function()
		local l: { Spec } = {}
		local brown = Color3.fromRGB(140, 95, 60)
		local red = Color3.fromRGB(220, 30, 40)
		add(l, "ball", Vector3.one * 3.2, Vector3.new(0, -0.2, 0), brown)
		add(l, "ball", Vector3.one * 2.4, Vector3.new(0, -0.3, -0.6), Color3.fromRGB(240, 220, 180))
		add(l, "ball", Vector3.one * 2.7, Vector3.new(0, 1.95, 0), brown)
		add(l, "vcyl", Vector3.new(2.75, 0.35, 2.75), Vector3.new(0, 2.75, 0), red)
		add(l, "wedge", Vector3.new(0.5, 0.6, 0.6), Vector3.new(0, 1.6, -1.3), ORANGE, { rot = Vector3.new(180, 0, 0) })
		for _, side in { -1, 1 } do
			add(l, "xcyl", Vector3.new(0.2, 1.25, 1.25), Vector3.new(side * 0.55, 2.05, -1.12), WHITE, { rot = Vector3.new(0, 90, 0) })
			add(l, "ball", Vector3.one * 0.55, Vector3.new(side * 0.55, 2.05, -1.28), BLACK)
			add(l, "wedge", Vector3.new(0.3, 0.8, 0.5), Vector3.new(side * 0.9, 3.4, 0), brown, { rot = Vector3.new(0, 0, side * -20) })
			add(l, "ball", Vector3.one * 1.35, Vector3.new(side * 1.9, 0.3, -0.9), red)
			add(l, "vcyl", Vector3.new(0.9, 0.5, 0.9), Vector3.new(side * 1.85, -0.45, -0.75), WHITE)
			sneaker(l, side * 0.75, -2.15, -0.2, 0.7, Color3.fromRGB(30, 30, 30))
		end
		return l
	end,

	-- A turtle whose shell is a tractor.
	TartarugaTrattore = function()
		local l: { Spec } = {}
		local green = Color3.fromRGB(70, 160, 70)
		add(l, "block", Vector3.new(3, 1.8, 3.6), Vector3.new(0, 0, 0.3), green)
		for _, z in { -0.8, 0.5, 1.7 } do
			add(l, "block", Vector3.new(3.05, 0.15, 0.15), Vector3.new(0, 0.92, z), Color3.fromRGB(40, 110, 40))
		end
		add(l, "block", Vector3.new(1.7, 1.5, 1.5), Vector3.new(0, 1.65, 0.7), Color3.fromRGB(230, 40, 40))
		add(l, "block", Vector3.new(1.5, 0.9, 0.08), Vector3.new(0, 1.8, -0.06), Color3.fromRGB(150, 210, 255), { mat = Enum.Material.Glass, alpha = 0.3 })
		add(l, "vcyl", Vector3.new(0.28, 1.3, 0.28), Vector3.new(0.9, 1.6, -0.9), BLACK)
		add(l, "ball", Vector3.one * 0.5, Vector3.new(0.9, 2.6, -0.9), Color3.fromRGB(120, 120, 120), { alpha = 0.4 })
		for _, side in { -1, 1 } do
			add(l, "xcyl", Vector3.new(0.7, 2.3, 2.3), Vector3.new(side * 1.85, -0.75, 1.1), BLACK)
			add(l, "xcyl", Vector3.new(0.75, 1, 1), Vector3.new(side * 1.85, -0.75, 1.1), Color3.fromRGB(255, 200, 40))
			add(l, "xcyl", Vector3.new(0.5, 1.4, 1.4), Vector3.new(side * 1.7, -1.2, -1.2), BLACK)
		end
		add(l, "ball", Vector3.one * 1.5, Vector3.new(0, 0.2, -2.25), Color3.fromRGB(130, 200, 100))
		add(l, "block", Vector3.new(0.7, 0.12, 0.1), Vector3.new(0, -0.15, -2.95), MOUTH)
		add(l, "vcyl", Vector3.new(1.2, 0.5, 1.2), Vector3.new(0, 1, -2.2), Color3.fromRGB(255, 220, 60)) -- straw hat
		add(l, "vcyl", Vector3.new(2, 0.1, 2), Vector3.new(0, 0.8, -2.2), Color3.fromRGB(255, 220, 60))
		eyes(l, 0.38, 0.45, -2.85, 0.45)
		return l
	end,

	-- A giraffe that is a towering ice-cream cone, standing on one sneaker.
	GiraffaGelatona = function()
		local l: { Spec } = {}
		local yellow = Color3.fromRGB(250, 205, 70)
		local spot = Color3.fromRGB(170, 100, 40)
		local waffle = Color3.fromRGB(215, 160, 80)
		sneaker(l, 0, -3.3, -0.1, 1, Color3.fromRGB(255, 70, 140))
		for i, d in { 0.6, 1.1, 1.6, 2.1 } do
			add(l, "vcyl", Vector3.new(d, 0.65, d), Vector3.new(0, -2.75 + i * 0.6, 0), waffle, { mat = Enum.Material.WoodPlanks })
		end
		add(l, "ball", Vector3.one * 2.5, Vector3.new(0, 0.5, 0), Color3.fromRGB(255, 160, 200))
		add(l, "ball", Vector3.one * 2.2, Vector3.new(0, 2, 0), Color3.fromRGB(150, 240, 200))
		add(l, "ball", Vector3.one * 0.6, Vector3.new(0.7, 3, -0.4), Color3.fromRGB(220, 20, 40))
		for _, p in { Vector3.new(-0.8, 0.9, -1), Vector3.new(0.6, 0.2, -1.1), Vector3.new(-0.5, 2.3, -0.9), Vector3.new(0.8, 1.9, -0.7) } do
			add(l, "block", Vector3.new(0.12, 0.12, 0.4), p, Color3.fromRGB(80, 160, 255), { rot = Vector3.new(0, 40, 30) })
		end
		add(l, "vcyl", Vector3.new(0.8, 3, 0.8), Vector3.new(0, 4.3, 0), yellow)
		for _, p in { Vector3.new(0.35, 3.6, -0.2), Vector3.new(-0.35, 4.4, -0.15), Vector3.new(0.3, 5.1, 0.2) } do
			add(l, "ball", Vector3.one * 0.4, p, spot)
		end
		add(l, "block", Vector3.new(1.05, 1.05, 1.7), Vector3.new(0, 6.1, -0.4), yellow)
		add(l, "block", Vector3.new(0.9, 0.5, 0.5), Vector3.new(0, 5.85, -1.35), Color3.fromRGB(240, 180, 90))
		add(l, "block", Vector3.new(0.5, 0.1, 0.1), Vector3.new(0, 5.7, -1.62), MOUTH)
		for _, side in { -1, 1 } do
			add(l, "vcyl", Vector3.new(0.18, 0.6, 0.18), Vector3.new(side * 0.3, 6.9, 0), spot)
			add(l, "ball", Vector3.one * 0.3, Vector3.new(side * 0.3, 7.25, 0), spot)
			add(l, "wedge", Vector3.new(0.15, 0.4, 0.6), Vector3.new(side * 0.65, 6.5, 0.1), yellow, { rot = Vector3.new(0, 0, side * -40) })
		end
		eyes(l, 0.38, 6.35, -1.15, 0.45)
		return l
	end,
}

-- ------------------------------------------------------------------ building

local function prepare(part: BasePart, scale: number)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = scale >= 0.8
end

local function newRoot(model: Model, cf: CFrame): BasePart
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.one
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = cf
	root.Parent = model
	model.PrimaryPart = root
	return root
end

-- A model you added in ReplicatedStorage/BrainrotModels, resized to ~5 studs tall.
local function fromTemplate(template: Model, id: string, scale: number): Model
	local model = template:Clone()
	model.Name = id
	local _, size = model:GetBoundingBox()
	if size.Y > 0 then
		model:ScaleTo(model:GetScale() * (5 * scale) / size.Y)
	end
	local cf = model:GetBoundingBox()
	local root = newRoot(model, CFrame.new(cf.Position))
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			prepare(d, scale)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = d
			weld.Parent = d
		end
	end
	model:PivotTo(CFrame.identity)
	return model
end

-- Builds a brainrot facing -Z with its centre at the origin. Root is anchored and
-- everything else is welded to it; place it with model:PivotTo(...).
function Brainrots.build(id: string, scale: number): Model
	local custom = ReplicatedStorage:FindFirstChild("BrainrotModels")
	local template = custom and custom:FindFirstChild(id)
	if template and template:IsA("Model") then
		return fromTemplate(template, id, scale)
	end

	local model = Instance.new("Model")
	model.Name = id
	local root = newRoot(model, CFrame.identity)

	local builder = SPECS[id]
	if not builder then
		return model
	end
	for _, spec in builder() do
		local part: BasePart
		local rot = spec.rot or Vector3.zero
		local extra = CFrame.identity
		if spec.s == "wedge" then
			part = Instance.new("WedgePart")
			part.Size = spec.size * scale
		else
			local p = Instance.new("Part")
			if spec.s == "ball" then
				p.Shape = Enum.PartType.Ball
				p.Size = spec.size * scale
			elseif spec.s == "vcyl" then
				p.Shape = Enum.PartType.Cylinder
				p.Size = Vector3.new(spec.size.Y, spec.size.X, spec.size.Z) * scale
				extra = CFrame.Angles(0, 0, math.pi / 2)
			elseif spec.s == "xcyl" then
				p.Shape = Enum.PartType.Cylinder
				p.Size = spec.size * scale
			else
				p.Size = spec.size * scale
			end
			part = p
		end
		part.Color = spec.color
		part.Material = spec.mat or Enum.Material.SmoothPlastic
		part.Transparency = spec.alpha or 0
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		prepare(part, scale)
		part.CFrame = CFrame.new(spec.pos * scale) * CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z)) * extra
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
	end
	return model
end

return Brainrots
