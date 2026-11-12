--!strict
-- Server entry point for Escape from Squirrel.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Config = require(ReplicatedStorage.Shared.Config)
local Services = script.Parent.Services
local PlayerService = require(Services.PlayerService)
local WorldBuilder = require(Services.WorldBuilder)
local VehicleService = require(Services.VehicleService)
local RoundService = require(Services.RoundService)

-- Remove template leftovers that would overlap the town or steal spawns.
local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate then
	baseplate:Destroy()
end
for _, d in workspace:GetDescendants() do
	if d:IsA("SpawnLocation") then
		d:Destroy()
	end
end

Lighting.ClockTime = 15
Lighting.Brightness = 2
workspace.Gravity = Config.World.Gravity
-- Keep normal jump height even with the lower gravity.
StarterPlayer.CharacterUseJumpPower = false
StarterPlayer.CharacterJumpHeight = 7.2
Players.RespawnTime = 3

WorldBuilder.buildLobby()
local world = WorldBuilder.build()
PlayerService.init()
RoundService.init(world)
VehicleService.init(world.vehicleSpawns, world.boostPads, RoundService.announce)
task.spawn(RoundService.run)
