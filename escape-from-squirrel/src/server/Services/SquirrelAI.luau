--!strict
-- The giant squirrel. Moved directly by script (anchored, no physics): it follows
-- PathfindingService paths, sticks to the ground with raycasts, can't fit inside
-- buildings, and POUNCES: it crouches for a moment with a ❗ over its head, then leaps
-- to where its target is heading. Players who keep moving (or drive) can dodge it.

local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local SquirrelModel = require(script.Parent.SquirrelModel)

local SquirrelAI = {}
SquirrelAI.__index = SquirrelAI

local C = Config.Squirrel

export type Target = {
	player: Player,
	root: BasePart,
	acorns: number,
	inside: boolean, -- inside a building (the squirrel can't follow)
	goal: Vector3, -- where the squirrel should head for this target (a door if inside)
}

export type SquirrelAI = typeof(setmetatable(
	{} :: {
		model: Model,
		root: BasePart,
		position: Vector3, -- body centre, without animation offsets
		facing: Vector3,
		centerHeight: number,
		speed: number,
		state: string, -- "Sleep" | "Chase" | "Windup" | "Leap" | "Recover"
		stateTime: number,
		cooldown: number,
		leapFrom: Vector3,
		leapTo: Vector3,
		leapT: number,
		target: Target?,
		isBlocked: (Vector3) -> boolean,
		path: Path,
		waypoints: { PathWaypoint }?,
		waypointIndex: number,
		computing: boolean,
		lastPathTime: number,
		destroyed: boolean,
		t: number,
		sleepLabel: BillboardGui,
		alertLabel: BillboardGui,
	},
	SquirrelAI
))

local function makeLabel(parent: Instance, text: string, offsetY: number): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 60)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.MaxDistance = 250
	gui.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 60, 60)
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.FredokaOne
	label.Parent = gui
	gui.Parent = parent
	return gui
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function SquirrelAI.new(parent: Instance, spawnPosition: Vector3, isBlocked: (Vector3) -> boolean): SquirrelAI
	local model = SquirrelModel.build(C.Scale)
	model.Name = "GiantSquirrel"
	local centerHeight = SquirrelModel.centerHeight(C.Scale)
	local root = model.PrimaryPart :: BasePart
	local sleepLabel = makeLabel(root, "💤", 20 * C.Scale)
	sleepLabel.AlwaysOnTop = false
	local alertLabel = makeLabel(root, "❗", 20 * C.Scale)
	alertLabel.Enabled = false

	local self = setmetatable({
		model = model,
		root = root,
		position = Vector3.new(spawnPosition.X, spawnPosition.Y + centerHeight, spawnPosition.Z),
		facing = Vector3.new(0, 0, -1),
		centerHeight = centerHeight,
		speed = C.BaseSpeed,
		state = "Sleep",
		stateTime = 0,
		cooldown = 0,
		leapFrom = Vector3.zero,
		leapTo = Vector3.zero,
		leapT = 0,
		target = nil,
		isBlocked = isBlocked,
		path = PathfindingService:CreatePath({
			AgentRadius = C.AgentRadius,
			AgentHeight = 16,
			AgentCanJump = false,
			WaypointSpacing = 8,
			Costs = { Water = 50 },
		}),
		waypoints = nil,
		waypointIndex = 1,
		computing = false,
		lastPathTime = 0,
		destroyed = false,
		t = 0,
		sleepLabel = sleepLabel,
		alertLabel = alertLabel,
	}, SquirrelAI)

	model:PivotTo(CFrame.lookAt(self.position, self.position + self.facing))
	model.Parent = parent
	return self
end

function SquirrelAI.wake(self: SquirrelAI)
	self.state = "Chase"
	self.sleepLabel.Enabled = false
end

local function rayParams(ignore: { Instance }): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	params.IgnoreWater = true
	return params
end

-- Height of the ground under (x, z), searching down from just above the squirrel's feet.
function SquirrelAI.groundAt(self: SquirrelAI, x: number, z: number, fromY: number, ignore: { Instance }): number?
	local result = workspace:Raycast(Vector3.new(x, fromY, z), Vector3.new(0, -80, 0), rayParams(ignore))
	return if result then result.Position.Y else nil
end

function SquirrelAI.canSee(self: SquirrelAI, point: Vector3, ignore: { Instance }): boolean
	local origin = self.position + Vector3.new(0, 4 * C.Scale, 0)
	return workspace:Raycast(origin, point - origin, rayParams(ignore)) == nil
end

function SquirrelAI.computePath(self: SquirrelAI, goal: Vector3)
	self.computing = true
	self.lastPathTime = os.clock()
	local feet = self.position - Vector3.new(0, self.centerHeight - 2, 0)
	task.spawn(function()
		local ok = pcall(function()
			self.path:ComputeAsync(feet, goal)
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

-- Moves along the ground, sliding along building walls instead of entering.
function SquirrelAI.moveBy(self: SquirrelAI, delta: Vector3, dt: number, ignore: { Instance })
	local p = self.position
	local candidates = { p + delta, p + Vector3.new(delta.X, 0, 0), p + Vector3.new(0, 0, delta.Z) }
	for _, c in candidates do
		if not self.isBlocked(c) then
			local feetY = p.Y - self.centerHeight
			local ground = self:groundAt(c.X, c.Z, feetY + 6, ignore)
			local targetY = if ground then ground + self.centerHeight else p.Y
			self.position = Vector3.new(c.X, p.Y + (targetY - p.Y) * math.min(1, dt * 12), c.Z)
			return
		end
	end
end

function SquirrelAI.nextGoal(self: SquirrelAI, target: Target, ignore: { Instance }): Vector3?
	local goal = target.goal
	local distance = flat(goal - self.position).Magnitude
	if distance < 60 and self:canSee(goal, ignore) then
		return goal
	end
	local waypoints = self.waypoints
	if waypoints then
		while self.waypointIndex <= #waypoints do
			local wp = waypoints[self.waypointIndex].Position
			if flat(wp - self.position).Magnitude > 2 then
				return wp
			end
			self.waypointIndex += 1
		end
	end
	if self:canSee(goal, ignore) then
		return goal
	end
	return nil
end

function SquirrelAI.pickTarget(self: SquirrelAI, targets: { Target }): Target?
	local best: Target? = nil
	local bestScore = math.huge
	for _, tg in targets do
		local score = (tg.goal - self.position).Magnitude - tg.acorns * C.AcornTargetBonus
		if tg.inside then
			score += 80 -- rather chase someone it can actually reach
		end
		if score < bestScore then
			bestScore = score
			best = tg
		end
	end
	return best
end

function SquirrelAI.tryPounce(self: SquirrelAI, target: Target, ignore: { Instance }): boolean
	if target.inside or self.cooldown > 0 then
		return false
	end
	local distance = flat(target.root.Position - self.position).Magnitude
	if distance < C.PounceMinRange or distance > C.PounceMaxRange then
		return false
	end
	if not self:canSee(target.root.Position, ignore) then
		return false
	end
	self.state = "Windup"
	self.stateTime = C.PounceWindup
	self.target = target
	self.alertLabel.Enabled = true
	return true
end

function SquirrelAI.startLeap(self: SquirrelAI, ignore: { Instance })
	self.alertLabel.Enabled = false
	local target = self.target
	if not target or not target.root.Parent then
		self.state = "Chase"
		return
	end
	-- Aim where the target is heading, not where it is.
	local root = target.root
	local lead = flat(root.AssemblyLinearVelocity) * (C.PounceDuration * 0.6)
	local aim = flat(root.Position + lead)
	local offset = aim - flat(self.position)
	local maxReach = C.PounceMaxRange + 8
	if offset.Magnitude > maxReach then
		aim = flat(self.position) + offset.Unit * maxReach
	end
	if self.isBlocked(aim) then
		aim = flat(root.Position)
		if self.isBlocked(aim) then
			self.state = "Recover"
			self.stateTime = C.RecoverTime
			return
		end
	end
	local fromY = math.max(root.Position.Y, self.position.Y) + 10
	local ground = self:groundAt(aim.X, aim.Z, fromY, ignore) or (self.position.Y - self.centerHeight)
	self.leapFrom = self.position
	self.leapTo = Vector3.new(aim.X, ground + self.centerHeight, aim.Z)
	self.leapT = 0
	self.state = "Leap"
	self.cooldown = C.PounceCooldown
	local dir = flat(self.leapTo - self.leapFrom)
	if dir.Magnitude > 0.1 then
		self.facing = dir.Unit
	end
end

function SquirrelAI.update(self: SquirrelAI, dt: number, targets: { Target }, ignore: { Instance })
	self.t += dt
	self.cooldown = math.max(0, self.cooldown - dt)
	local moveDir = Vector3.zero

	if self.state == "Windup" then
		self.stateTime -= dt
		local target = self.target
		if target and target.root.Parent then
			local d = flat(target.root.Position - self.position)
			if d.Magnitude > 0.1 then
				self.facing = d.Unit
			end
		end
		if self.stateTime <= 0 then
			self:startLeap(ignore)
		end
	elseif self.state == "Leap" then
		self.leapT = math.min(1, self.leapT + dt / C.PounceDuration)
		local a = self.leapT
		self.position = self.leapFrom:Lerp(self.leapTo, a) + Vector3.new(0, 4 * C.PounceHeight * a * (1 - a), 0)
		if a >= 1 then
			self.position = self.leapTo
			self.state = "Recover"
			self.stateTime = C.RecoverTime
		end
	elseif self.state == "Recover" then
		self.stateTime -= dt
		if self.stateTime <= 0 then
			self.state = "Chase"
		end
	elseif self.state == "Chase" then
		local target = self:pickTarget(targets)
		self.target = target
		if target and not self:tryPounce(target, ignore) then
			if not self.computing and os.clock() - self.lastPathTime > C.RepathInterval then
				self:computePath(target.goal)
			end
			local goal = self:nextGoal(target, ignore)
			if goal then
				local d = flat(goal - self.position)
				if d.Magnitude > 1 then
					moveDir = d.Unit
					self:moveBy(moveDir * math.min(d.Magnitude, self.speed * dt), dt, ignore)
				end
			end
		end
	end

	self:render(dt, moveDir)
end

function SquirrelAI.render(self: SquirrelAI, dt: number, moveDir: Vector3)
	if moveDir.Magnitude > 0 then
		local blended = self.facing:Lerp(moveDir, math.min(1, dt * 8))
		self.facing = if blended.Magnitude > 0.1 then blended.Unit else moveDir
	end
	local s = C.Scale
	local yOffset, pitch = 0, 0
	if self.state == "Sleep" then
		yOffset = math.sin(self.t * 1.5) * 0.15 * s
	elseif self.state == "Windup" then
		yOffset = -1.4 * s -- crouch
		pitch = math.rad(12)
	elseif self.state == "Leap" then
		pitch = (self.leapT - 0.5) * math.rad(50) -- nose up, then down
	elseif self.state == "Recover" then
		yOffset = -0.6 * s
	elseif moveDir.Magnitude > 0 then
		yOffset = math.abs(math.sin(self.t * 10)) * 1.6 * s -- bouncy hop
		pitch = math.rad(8)
	end
	local pos = self.position + Vector3.new(0, yOffset, 0)
	self.root.CFrame = CFrame.lookAt(pos, pos + self.facing) * CFrame.Angles(-pitch, 0, 0)
end

function SquirrelAI.destroy(self: SquirrelAI)
	self.destroyed = true
	self.model:Destroy()
end

return SquirrelAI
