--!strict
-- The chasing donut. It is moved directly by script (anchored, no physics), following
-- paths from PathfindingService toward the nearest runner. When a runner is close and
-- in plain sight it charges straight at them.

local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local DonutModel = require(script.Parent.DonutModel)

local DonutAI = {}
DonutAI.__index = DonutAI

export type DonutAI = typeof(setmetatable(
	{} :: {
		model: Model,
		root: BasePart,
		position: Vector3, -- center of the donut, without the hop animation
		facing: Vector3,
		floorY: number,
		centerHeight: number,
		speed: number,
		awake: boolean,
		destroyed: boolean,
		path: Path,
		waypoints: { PathWaypoint }?,
		waypointIndex: number,
		computing: boolean,
		lastPathTime: number,
		t: number,
		sleepLabel: BillboardGui,
	},
	DonutAI
))

function DonutAI.new(parent: Instance, spawnPosition: Vector3, floorY: number): DonutAI
	local model = DonutModel.build(Config.Donut.Scale, Color3.fromRGB(255, 140, 190))
	model.Name = "ChaserDonut"
	local centerHeight = DonutModel.centerHeight(Config.Donut.Scale)
	local position = Vector3.new(spawnPosition.X, floorY + centerHeight, spawnPosition.Z)

	local sleepLabel = Instance.new("BillboardGui")
	sleepLabel.Size = UDim2.fromOffset(120, 50)
	sleepLabel.StudsOffset = Vector3.new(0, centerHeight + 2, 0)
	sleepLabel.MaxDistance = 120
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = "💤 Zzz..."
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0
	text.Font = Enum.Font.FredokaOne
	text.Parent = sleepLabel
	sleepLabel.Parent = model.PrimaryPart

	local self = setmetatable({
		model = model,
		root = model.PrimaryPart :: BasePart,
		position = position,
		facing = Vector3.new(0, 0, -1),
		floorY = floorY,
		centerHeight = centerHeight,
		speed = Config.Donut.BaseSpeed,
		awake = false,
		destroyed = false,
		path = PathfindingService:CreatePath({
			AgentRadius = Config.Donut.AgentRadius,
			AgentHeight = 10,
			AgentCanJump = false,
			WaypointSpacing = 6,
		}),
		waypoints = nil,
		waypointIndex = 1,
		computing = false,
		lastPathTime = 0,
		t = 0,
		sleepLabel = sleepLabel,
	}, DonutAI)

	model:PivotTo(CFrame.lookAt(position, position + self.facing))
	model.Parent = parent
	return self
end

function DonutAI.wake(self: DonutAI)
	self.awake = true
	self.sleepLabel.Enabled = false
end

function DonutAI.computePath(self: DonutAI, goal: Vector3)
	self.computing = true
	self.lastPathTime = os.clock()
	local start = Vector3.new(self.position.X, self.floorY + 2, self.position.Z)
	task.spawn(function()
		local ok = pcall(function()
			self.path:ComputeAsync(start, goal)
		end)
		self.computing = false
		if self.destroyed then
			return
		end
		if ok and self.path.Status == Enum.PathStatus.Success then
			self.waypoints = self.path:GetWaypoints()
			self.waypointIndex = 1
		else
			self.waypoints = nil
		end
	end)
end

-- True if nothing solid is between the donut and the target.
function DonutAI.canSee(self: DonutAI, target: BasePart, ignore: { Instance }): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local origin = Vector3.new(self.position.X, self.floorY + 3, self.position.Z)
	local result = workspace:Raycast(origin, target.Position - origin, params)
	return result == nil
end

function DonutAI.nextGoal(self: DonutAI, target: BasePart, ignore: { Instance }): Vector3?
	local flatDistance = Vector3.new(target.Position.X - self.position.X, 0, target.Position.Z - self.position.Z).Magnitude
	if flatDistance < Config.Donut.DirectChaseRange and self:canSee(target, ignore) then
		return target.Position
	end

	local waypoints = self.waypoints
	if waypoints then
		while self.waypointIndex <= #waypoints do
			local wp = waypoints[self.waypointIndex].Position
			local d = Vector3.new(wp.X - self.position.X, 0, wp.Z - self.position.Z).Magnitude
			if d > 1.5 then
				return wp
			end
			self.waypointIndex += 1
		end
	end

	-- No usable path: charge only if the way is clear.
	if self:canSee(target, ignore) then
		return target.Position
	end
	return nil
end

-- runners: the HumanoidRootParts of everyone the donut may chase.
-- ignore: things the line-of-sight ray should pass through (characters, this donut).
function DonutAI.update(self: DonutAI, dt: number, runners: { BasePart }, ignore: { Instance })
	self.t += dt
	local moveDir = Vector3.zero

	if self.awake then
		local target: BasePart? = nil
		local best = math.huge
		for _, hrp in runners do
			local d = (hrp.Position - self.position).Magnitude
			if d < best then
				best = d
				target = hrp
			end
		end

		if target then
			if not self.computing and os.clock() - self.lastPathTime > Config.Donut.RepathInterval then
				self:computePath(target.Position)
			end
			local goal = self:nextGoal(target, ignore)
			if goal then
				local flat = Vector3.new(goal.X - self.position.X, 0, goal.Z - self.position.Z)
				local dist = flat.Magnitude
				if dist > 0.05 then
					moveDir = flat.Unit
					self.position += moveDir * math.min(dist, self.speed * dt)
				end
			end
		end
	end

	self:render(dt, moveDir)
end

function DonutAI.render(self: DonutAI, dt: number, moveDir: Vector3)
	local moving = moveDir.Magnitude > 0
	if moving then
		local blended = self.facing:Lerp(moveDir, math.min(1, dt * 10))
		self.facing = if blended.Magnitude > 0.1 then blended.Unit else moveDir
	end
	local hop, wobble
	if moving then
		hop = math.abs(math.sin(self.t * 9)) * 1.3
		wobble = math.sin(self.t * 9) * 0.12
	elseif self.awake then
		hop = math.abs(math.sin(self.t * 4)) * 0.5
		wobble = 0
	else
		hop = 0
		wobble = math.sin(self.t * 1.5) * 0.06 -- snoozing sway
	end
	local pos = self.position + Vector3.new(0, hop, 0)
	self.root.CFrame = CFrame.lookAt(pos, pos + self.facing) * CFrame.Angles(0, 0, wobble)
end

function DonutAI.destroy(self: DonutAI)
	self.destroyed = true
	self.model:Destroy()
end

return DonutAI
