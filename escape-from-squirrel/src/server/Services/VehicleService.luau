--!strict
-- Spawns the cars, drives them from VehicleSeat input, pays coins for air time,
-- handles boost pads, flips cars back over, and sends abandoned or sunk cars home.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local VehicleBuilder = require(script.Parent.VehicleBuilder)
local PlayerService = require(script.Parent.PlayerService)

local VehicleService = {}

export type SpawnPoint = { kind: string, cframe: CFrame }

type Record = {
	kind: string,
	spawnCFrame: CFrame,
	built: VehicleBuilder.Built?,
	boostUntil: number,
	airtime: number,
	idleSince: number?,
	flipTime: number,
	sunkTime: number,
}

local Tuning = Config.VehicleTuning
local records: { Record } = {}
local recordByModel: { [Model]: Record } = {}
local folder: Folder
local announce: (text: string, kind: string?, target: Player?) -> () = function() end

local function occupants(b: VehicleBuilder.Built): { Humanoid }
	local list = {}
	if b.seat.Occupant then
		table.insert(list, b.seat.Occupant)
	end
	for _, s in b.passengerSeats do
		if s.Occupant then
			table.insert(list, s.Occupant)
		end
	end
	return list
end

-- Pulls a humanoid out of whatever seat it is in.
function VehicleService.eject(humanoid: Humanoid)
	local seatPart = humanoid.SeatPart
	if seatPart then
		local weld = seatPart:FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end
	end
	humanoid.Sit = false
end

local function addPrompt(seat: Seat | VehicleSeat, actionText: string, objectText: string)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = seat
	prompt.Triggered:Connect(function(player)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and not seat.Occupant and not humanoid.SeatPart then
			(seat :: any):Sit(humanoid)
		end
	end)
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		prompt.Enabled = seat.Occupant == nil
	end)
end

local function spawnVehicle(rec: Record)
	local old = rec.built
	if old then
		for _, humanoid in occupants(old) do
			VehicleService.eject(humanoid)
		end
		recordByModel[old.model] = nil
		old.model:Destroy()
	end

	local b = VehicleBuilder.build(rec.kind, rec.spawnCFrame, folder)
	rec.built = b
	rec.boostUntil = 0
	rec.airtime = 0
	rec.idleSince = nil
	rec.flipTime = 0
	rec.sunkTime = 0
	recordByModel[b.model] = rec

	local name = Config.Vehicles[rec.kind].DisplayName
	addPrompt(b.seat, "Drive", name)
	for _, s in b.passengerSeats do
		addPrompt(s, "Ride", name)
	end

	-- The driver's computer simulates the car, so steering feels instant.
	b.seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local occupant = b.seat.Occupant
		local player = occupant and Players:GetPlayerFromCharacter(occupant.Parent)
		pcall(function()
			if player then
				b.chassis:SetNetworkOwner(player)
			else
				b.chassis:SetNetworkOwnershipAuto()
			end
		end)
	end)
end

local function setUpright(rec: Record)
	local b = rec.built
	if not b then
		return
	end
	local pos = b.chassis.Position + Vector3.new(0, 5, 0)
	local look = Vector3.new(b.chassis.CFrame.LookVector.X, 0, b.chassis.CFrame.LookVector.Z)
	if look.Magnitude < 0.1 then
		look = rec.spawnCFrame.LookVector
	end
	b.model:PivotTo(CFrame.lookAt(pos, pos + look.Unit))
	for _, d in b.model:GetDescendants() do
		if d:IsA("BasePart") then
			d.AssemblyLinearVelocity = Vector3.zero
			d.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = false

local function step(dt: number)
	local ignore: { Instance } = { folder }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	rayParams.FilterDescendantsInstances = ignore

	for _, rec in records do
		local b = rec.built
		if not b or not b.chassis.Parent then
			continue
		end
		local spec = Config.Vehicles[rec.kind]
		local seat = b.seat
		local throttle, steer = seat.ThrottleFloat, seat.SteerFloat
		local boosting = os.clock() < rec.boostUntil

		local maxSpeed = spec.MaxSpeed * (if boosting then Tuning.BoostMultiplier else 1)
		if throttle < 0 then
			maxSpeed *= Tuning.ReverseFactor
		end
		local wheelSpeed = throttle * maxSpeed / spec.WheelRadius * Tuning.DriveSign
		local torque = if throttle ~= 0 then spec.Torque * (if boosting then 1.5 else 1) else spec.Torque * 0.1
		for _, hinge in b.driveHinges do
			hinge.AngularVelocity = wheelSpeed
			hinge.MotorMaxTorque = torque
		end
		for _, hinge in b.steerHinges do
			hinge.TargetAngle = steer * spec.SteerAngle * Tuning.SteerSign
		end

		-- Air time: no ground under the car while someone is driving.
		local driverHumanoid = seat.Occupant
		if driverHumanoid then
			local hit = workspace:Raycast(b.chassis.Position, Vector3.new(0, -(b.restHeight + 2.5), 0), rayParams)
			if hit then
				if rec.airtime >= Config.Rewards.AirTimeMin then
					local driver = Players:GetPlayerFromCharacter(driverHumanoid.Parent)
					if driver then
						local coins = math.floor(rec.airtime * Config.Rewards.AirTimeCoinsPerSecond + 0.5)
						PlayerService.addCoins(driver, coins)
						announce(string.format("🚀 AIR TIME %.1fs! +%d coins", rec.airtime, coins), "good", driver)
					end
				end
				rec.airtime = 0
			else
				rec.airtime += dt
			end
		else
			rec.airtime = 0
		end
	end
end

local function maintenance()
	while true do
		task.wait(0.5)
		local now = os.clock()
		for _, rec in records do
			local b = rec.built
			if not b or not b.chassis.Parent or b.chassis.Position.Y < -40 then
				spawnVehicle(rec)
				continue
			end
			local chassis = b.chassis

			-- Upside down or on its side for 2 seconds: flip it back.
			if chassis.CFrame.UpVector.Y < 0.3 then
				rec.flipTime += 0.5
				if rec.flipTime >= 2 then
					rec.flipTime = 0
					setUpright(rec)
				end
			else
				rec.flipTime = 0
			end

			-- Sunk in the lake.
			if chassis.Position.Y < -3 then
				rec.sunkTime += 0.5
				if rec.sunkTime >= 3 then
					spawnVehicle(rec)
					continue
				end
			else
				rec.sunkTime = 0
			end

			-- Abandoned away from home: send it back.
			if #occupants(b) == 0 then
				local idleSince = rec.idleSince
				if not idleSince then
					rec.idleSince = now
				elseif now - idleSince > Tuning.IdleRespawnTime and (chassis.Position - rec.spawnCFrame.Position).Magnitude > 25 then
					spawnVehicle(rec)
				end
			else
				rec.idleSince = nil
			end
		end
	end
end

function VehicleService.init(spawnPoints: { SpawnPoint }, boostPads: { BasePart }, announceFn: (text: string, kind: string?, target: Player?) -> ())
	announce = announceFn
	folder = Instance.new("Folder")
	folder.Name = "Vehicles"
	folder.Parent = workspace

	for _, sp in spawnPoints do
		local rec: Record = {
			kind = sp.kind,
			spawnCFrame = sp.cframe,
			built = nil,
			boostUntil = 0,
			airtime = 0,
			idleSince = nil,
			flipTime = 0,
			sunkTime = 0,
		}
		table.insert(records, rec)
		spawnVehicle(rec)
	end

	for _, pad in boostPads do
		pad.Touched:Connect(function(hit)
			local model = hit:FindFirstAncestorOfClass("Model")
			while model and not recordByModel[model] do
				model = model:FindFirstAncestorOfClass("Model")
			end
			local rec = model and recordByModel[model]
			if rec and rec.built and rec.built.seat.Occupant and os.clock() >= rec.boostUntil then
				rec.boostUntil = os.clock() + Tuning.BoostDuration
				local driver = Players:GetPlayerFromCharacter(rec.built.seat.Occupant.Parent)
				if driver then
					announce("⚡ BOOST!", "good", driver)
				end
			end
		end)
	end

	RunService.Heartbeat:Connect(step)
	task.spawn(maintenance)
end

-- Puts every car back at its spawn (between rounds).
function VehicleService.resetAll()
	for _, rec in records do
		spawnVehicle(rec)
	end
end

function VehicleService.folder(): Folder
	return folder
end

return VehicleService
