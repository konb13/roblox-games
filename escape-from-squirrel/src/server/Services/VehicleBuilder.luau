--!strict
-- Builds a drivable car from parts: a physics chassis, a VehicleSeat, and four wheels on
-- HingeConstraints (motors on all wheels, servo steering on the front ones).
-- The car faces local -Z. VehicleService turns seat input into motor speeds.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Parts = require(script.Parent.Parts)

local VehicleBuilder = {}

export type Built = {
	model: Model,
	chassis: BasePart,
	seat: VehicleSeat,
	passengerSeats: { Seat },
	driveHinges: { HingeConstraint },
	steerHinges: { HingeConstraint },
	restHeight: number, -- chassis centre height above the ground when parked
}

local DARK = Color3.fromRGB(30, 30, 35)
local GLASS = Color3.fromRGB(150, 200, 255)

local function decor(chassis: BasePart, model: Model, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?)
	local p = Instance.new("Part")
	p.Name = name
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	Parts.weldTo(chassis, p, offset, model)
	return p
end

-- Kind-specific bodywork. (w, h, l) is the chassis size.
local function bodywork(kind: string, chassis: BasePart, model: Model, size: Vector3, color: Color3)
	local w, h, l = size.X, size.Y, size.Z
	if kind == "Kart" then
		decor(chassis, model, "Bumper", Vector3.new(w + 0.6, 0.6, 0.8), CFrame.new(0, 0, -l / 2 - 0.3), DARK)
		decor(chassis, model, "Engine", Vector3.new(2.4, 1.2, 1.8), CFrame.new(0, h / 2 + 0.6, l / 2 - 1.2), DARK, Enum.Material.Metal)
		decor(chassis, model, "SteeringWheel", Vector3.new(0.3, 1.4, 1.4), CFrame.new(0, h / 2 + 1.6, -0.8) * CFrame.Angles(math.rad(-30), 0, 0), DARK, nil, Enum.PartType.Cylinder)
		decor(chassis, model, "Number", Vector3.new(2, 0.2, 2), CFrame.new(0, h / 2 + 0.1, -l / 2 + 1.4), Color3.new(1, 1, 1))
	elseif kind == "Roadster" then
		decor(chassis, model, "Hood", Vector3.new(w - 0.2, 0.8, l * 0.4), CFrame.new(0, h / 2 + 0.4, -l * 0.28), color)
		decor(chassis, model, "Windshield", Vector3.new(w - 0.6, 1.4, 0.3), CFrame.new(0, h / 2 + 1.2, -l * 0.06) * CFrame.Angles(math.rad(-35), 0, 0), GLASS, Enum.Material.Glass)
		decor(chassis, model, "Trunk", Vector3.new(w - 0.2, 0.9, l * 0.25), CFrame.new(0, h / 2 + 0.45, l * 0.37), color)
		decor(chassis, model, "Spoiler", Vector3.new(w, 0.25, 1.2), CFrame.new(0, h / 2 + 1.7, l / 2 - 0.6), DARK)
		decor(chassis, model, "Stripe", Vector3.new(1, 0.1, l * 0.4), CFrame.new(0, h / 2 + 0.85, -l * 0.28), Color3.fromRGB(40, 140, 255), Enum.Material.Neon)
		for _, x in { -w / 2 + 1, w / 2 - 1 } do
			decor(chassis, model, "Headlight", Vector3.new(1.2, 0.5, 0.2), CFrame.new(x, h / 2 + 0.2, -l / 2 - 0.05), Color3.fromRGB(255, 255, 220), Enum.Material.Neon)
			decor(chassis, model, "Taillight", Vector3.new(1.2, 0.5, 0.2), CFrame.new(x, h / 2 + 0.2, l / 2 + 0.05), Color3.fromRGB(255, 40, 40), Enum.Material.Neon)
		end
	elseif kind == "Truck" then
		decor(chassis, model, "Cab", Vector3.new(w - 0.6, 3.6, l * 0.38), CFrame.new(0, h / 2 + 1.8, -l * 0.12), color)
		decor(chassis, model, "Windshield", Vector3.new(w - 1, 2, 0.3), CFrame.new(0, h / 2 + 2.4, -l * 0.31), GLASS, Enum.Material.Glass)
		decor(chassis, model, "Hood", Vector3.new(w - 0.6, 1.4, l * 0.2), CFrame.new(0, h / 2 + 0.7, -l * 0.4), color)
		decor(chassis, model, "BedRail", Vector3.new(0.4, 1.4, l * 0.4), CFrame.new(w / 2 - 0.2, h / 2 + 0.7, l * 0.29), color)
		decor(chassis, model, "BedRail", Vector3.new(0.4, 1.4, l * 0.4), CFrame.new(-w / 2 + 0.2, h / 2 + 0.7, l * 0.29), color)
		decor(chassis, model, "LightBar", Vector3.new(w - 1.5, 0.5, 0.6), CFrame.new(0, h / 2 + 3.85, -l * 0.18), Color3.fromRGB(255, 240, 150), Enum.Material.Neon)
	elseif kind == "Mower" then
		decor(chassis, model, "Deck", Vector3.new(w + 0.8, 0.5, 2.6), CFrame.new(0, -h / 2 + 0.2, -0.4), DARK, Enum.Material.Metal)
		decor(chassis, model, "Engine", Vector3.new(w - 1, 1.6, 2), CFrame.new(0, h / 2 + 0.8, -l / 2 + 1.2), color)
		decor(chassis, model, "SteeringWheel", Vector3.new(0.3, 1.2, 1.2), CFrame.new(0, h / 2 + 1.9, -0.6) * CFrame.Angles(math.rad(-40), 0, 0), DARK, nil, Enum.PartType.Cylinder)
		decor(chassis, model, "Flag", Vector3.new(0.1, 1.2, 1.6), CFrame.new(-w / 2 + 0.3, h / 2 + 4.5, l / 2 - 0.5), Color3.fromRGB(255, 200, 0))
		decor(chassis, model, "Pole", Vector3.new(0.15, 4, 0.15), CFrame.new(-w / 2 + 0.3, h / 2 + 2, l / 2 - 0.5), DARK)
	end
end

function VehicleBuilder.build(kind: string, cf: CFrame, parent: Instance): Built
	local spec = Config.Vehicles[kind]
	assert(spec, `Unknown vehicle kind {kind}`)
	local size: Vector3 = spec.ChassisSize
	local r: number = spec.WheelRadius
	local ww: number = spec.WheelWidth
	local w, h, l = size.X, size.Y, size.Z

	local model = Instance.new("Model")
	model.Name = kind
	model:SetAttribute("VehicleKind", kind)

	-- Chassis centre: wheels touch the ground, the chassis floats a little above it.
	local restHeight = r + h / 2 + math.max(0.3, r * 0.15)
	local base = cf * CFrame.new(0, restHeight, 0)

	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = size
	chassis.CFrame = base
	chassis.Color = spec.Color
	chassis.Material = Enum.Material.SmoothPlastic
	chassis.TopSurface = Enum.SurfaceType.Smooth
	chassis.BottomSurface = Enum.SurfaceType.Smooth
	chassis.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.1)
	chassis.Parent = model
	model.PrimaryPart = chassis

	-- Heavy, invisible ballast low down keeps the car from flipping.
	local ballast = Instance.new("Part")
	ballast.Name = "Ballast"
	ballast.Size = Vector3.new(w * 0.8, 0.4, l * 0.8)
	ballast.Transparency = 1
	ballast.CanCollide = false
	ballast.CanQuery = false
	ballast.CustomPhysicalProperties = PhysicalProperties.new(4, 0.3, 0)
	ballast.Anchored = false
	ballast.CFrame = base * CFrame.new(0, -h / 2 + 0.2, 0)
	local bw = Instance.new("WeldConstraint")
	bw.Part0 = chassis
	bw.Part1 = ballast
	bw.Parent = ballast
	ballast.Parent = model

	bodywork(kind, chassis, model, size, spec.Color)

	-- Driver seat (+ prompt so phone players can hop in easily).
	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(2, 1, 2)
	seat.Color = Color3.fromRGB(40, 40, 40)
	seat.HeadsUpDisplay = false
	seat.CanCollide = false
	Parts.weldTo(chassis, seat, CFrame.new(0, h / 2 + 0.5, if kind == "Truck" then -l * 0.1 else l * 0.05), model)
	seat.Massless = true

	local passengerSeats: { Seat } = {}
	local passengerOffsets = {
		Roadster = { Vector3.new(0, 0, l * 0.22) },
		Truck = { Vector3.new(-w / 4, 0, l * 0.25), Vector3.new(w / 4, 0, l * 0.25) },
	}
	for i = 1, spec.Passengers do
		local offset = (passengerOffsets[kind] or {})[i] or Vector3.new(0, 0, l * 0.25)
		local ps = Instance.new("Seat")
		ps.Name = "PassengerSeat"
		ps.Size = Vector3.new(2, 1, 2)
		ps.Color = Color3.fromRGB(60, 60, 60)
		ps.CanCollide = false
		Parts.weldTo(chassis, ps, CFrame.new(offset + Vector3.new(0, h / 2 + 0.5, 0)), model)
		ps.Massless = true
		table.insert(passengerSeats, ps)
	end

	-- Wheels
	local driveHinges: { HingeConstraint } = {}
	local steerHinges: { HingeConstraint } = {}
	local wheelX = w / 2 + ww / 2 + 0.2
	local wheelZ = l / 2 - r * 0.9
	local wheelY = -restHeight + r -- relative to the chassis centre
	local wheelProps = PhysicalProperties.new(0.7, 2, 0, 100, 1)

	for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local sx, sz = corner[1], corner[2]
		local isFront = sz < 0
		local offset = Vector3.new(sx * wheelX, wheelY, sz * wheelZ)

		local wheel = Instance.new("Part")
		wheel.Name = if isFront then "FrontWheel" else "RearWheel"
		wheel.Shape = Enum.PartType.Cylinder
		wheel.Size = Vector3.new(ww, r * 2, r * 2)
		wheel.CFrame = base * CFrame.new(offset)
		wheel.Color = DARK
		wheel.Material = Enum.Material.SmoothPlastic
		wheel.CustomPhysicalProperties = wheelProps
		wheel.TopSurface = Enum.SurfaceType.Smooth
		wheel.BottomSurface = Enum.SurfaceType.Smooth
		wheel.Parent = model

		local hub = Instance.new("Part")
		hub.Name = "Hub"
		hub.Shape = Enum.PartType.Cylinder
		hub.Size = Vector3.new(ww + 0.1, r * 1.1, r * 1.1)
		hub.Color = Color3.fromRGB(200, 200, 210)
		hub.Material = Enum.Material.Metal
		hub.CanCollide = false
		hub.CanQuery = false
		Parts.weldTo(wheel, hub, CFrame.identity, model)

		local noCollide = Instance.new("NoCollisionConstraint")
		noCollide.Part0 = chassis
		noCollide.Part1 = wheel
		noCollide.Parent = wheel

		local wheelAttachment = Instance.new("Attachment")
		wheelAttachment.Name = "Axle"
		wheelAttachment.Parent = wheel

		local driveParent: BasePart = chassis
		if isFront then
			-- Steering knuckle: turns left/right on a vertical servo hinge.
			local knuckle = Instance.new("Part")
			knuckle.Name = "Knuckle"
			knuckle.Size = Vector3.new(1, 1, 1)
			knuckle.CustomPhysicalProperties = PhysicalProperties.new(3, 0.3, 0) -- not too light, or joints jitter
			knuckle.Transparency = 1
			knuckle.CanCollide = false
			knuckle.CanQuery = false
			knuckle.CFrame = base * CFrame.new(offset)
			knuckle.Parent = model

			local upright = CFrame.Angles(0, 0, math.pi / 2) -- attachment X axis pointing up
			local a0 = Instance.new("Attachment")
			a0.Name = "SteerBase"
			a0.CFrame = CFrame.new(offset) * upright
			a0.Parent = chassis
			local a1 = Instance.new("Attachment")
			a1.Name = "SteerKnuckle"
			a1.CFrame = upright
			a1.Parent = knuckle

			local steer = Instance.new("HingeConstraint")
			steer.Name = "Steer"
			steer.Attachment0 = a0
			steer.Attachment1 = a1
			steer.ActuatorType = Enum.ActuatorType.Servo
			steer.ServoMaxTorque = 1e6
			steer.AngularSpeed = 6
			steer.LimitsEnabled = true
			steer.LowerAngle = -spec.SteerAngle - 5
			steer.UpperAngle = spec.SteerAngle + 5
			steer.Parent = chassis
			table.insert(steerHinges, steer)
			driveParent = knuckle
		end

		local axleBase = Instance.new("Attachment")
		axleBase.Name = "AxleBase"
		axleBase.CFrame = if driveParent == chassis then CFrame.new(offset) else CFrame.identity
		axleBase.Parent = driveParent

		local motor = Instance.new("HingeConstraint")
		motor.Name = "Motor"
		motor.Attachment0 = axleBase
		motor.Attachment1 = wheelAttachment
		motor.ActuatorType = Enum.ActuatorType.Motor
		motor.MotorMaxTorque = spec.Torque * 0.1
		motor.MotorMaxAcceleration = 80
		motor.AngularVelocity = 0
		motor.Parent = wheel
		table.insert(driveHinges, motor)
	end

	model.Parent = parent
	return {
		model = model,
		chassis = chassis,
		seat = seat,
		passengerSeats = passengerSeats,
		driveHinges = driveHinges,
		steerHinges = steerHinges,
		restHeight = restHeight,
	}
end

return VehicleBuilder
