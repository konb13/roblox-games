--!strict
-- Server entry point for Escape from Donut.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local Services = script.Parent.Services
local PlayerService = require(Services.PlayerService)
local WorldBuilder = require(Services.WorldBuilder)
local RoundService = require(Services.RoundService)

-- Remove template leftovers that would overlap the maze or steal spawns.
local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate then
	baseplate:Destroy()
end
for _, d in workspace:GetDescendants() do
	if d:IsA("SpawnLocation") then
		d:Destroy()
	end
end

Lighting.ClockTime = 14.5
Lighting.Brightness = 2
Players.RespawnTime = 3

WorldBuilder.buildLobby()
PlayerService.init()
RoundService.init()
task.spawn(RoundService.run)
