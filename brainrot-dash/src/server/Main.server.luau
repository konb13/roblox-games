--!strict
-- Server entry point for Brainrot Dash.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Config = require(ReplicatedStorage.Shared.Config)
local Services = script.Parent.Services
local CourseBuilder = require(Services.CourseBuilder)
local DataService = require(Services.DataService)
local PowerService = require(Services.PowerService)
local ProgressService = require(Services.ProgressService)
local ChaosService = require(Services.ChaosService)

-- Remove template leftovers: no floor under the course (falling is the point!).
local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate then
	baseplate:Destroy()
end
workspace.Terrain:Clear()
for _, d in workspace:GetDescendants() do
	if d:IsA("SpawnLocation") then
		d:Destroy()
	end
end

-- Bright cartoon sky.
Lighting.ClockTime = 13
Lighting.Brightness = 2.5
Lighting.OutdoorAmbient = Color3.fromRGB(170, 160, 200)
Lighting.FogColor = Color3.fromRGB(180, 140, 255)
Lighting.FogStart = 300
Lighting.FogEnd = 1400

StarterPlayer.CharacterUseJumpPower = false
StarterPlayer.CharacterJumpHeight = Config.Player.JumpHeight
StarterPlayer.CharacterWalkSpeed = Config.Player.WalkSpeed
Players.RespawnTime = 2

local course = CourseBuilder.build()
DataService.init()
PowerService.init()
ProgressService.init(course)
ChaosService.start(course, {
	announce = function(text, kind)
		ProgressService.announce(text, kind)
	end,
	coinRain = ProgressService.coinRain,
})
