local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local TAG = "PalmVilleRooster"

local CONFIG = {
	WalkCycleSpeed = 7.8,
	LegSwing = math.rad(26),
	LegBend = math.rad(12),
	HeadIdle = math.rad(4),
	HeadWalk = math.rad(5),
	PeckAngle = math.rad(22),
	PeckDuration = 0.72,
	TailSway = math.rad(2),
	BodySway = math.rad(1.2),
}

local states = setmetatable({}, {__mode = "k"})

local function collectBones(mesh)
	local result = {}
	for _, item in ipairs(mesh:GetDescendants()) do
		if item:IsA("Bone") then
			table.insert(result, {
				bone = item,
				name = item.Name:lower(),
				position = mesh.CFrame:PointToObjectSpace(item.WorldCFrame.Position),
				base = item.Transform,
			})
		end
	end
	return result
end

local function register(model)
	if states[model] or not model:IsA("Model") or not model:GetAttribute("PalmVilleRoosterReady") then
		return false
	end

	local mesh
	local maxCount = 0
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("MeshPart") then
			local count = 0
			for _, child in ipairs(item:GetDescendants()) do
				if child:IsA("Bone") then
					count += 1
				end
			end
			if count > maxCount then
				mesh = item
				maxCount = count
			end
		end
	end
	if not mesh or maxCount < 6 then
		return false
	end

	local bones = collectBones(mesh)
	table.sort(bones, function(a, b)
		return a.position.Y < b.position.Y
	end)

	local legCount = math.clamp(math.floor(#bones * 0.36), 2, 6)
	local legs = {}
	for index = 1, legCount do
		legs[index] = bones[index]
	end

	local headBones = {}
	for index = #bones, math.max(1, #bones - 2), -1 do
		table.insert(headBones, bones[index])
	end

	local midBones = {}
	for index = legCount + 1, #bones - #headBones do
		table.insert(midBones, bones[index])
	end

	local minX, maxX = math.huge, -math.huge
	for _, item in ipairs(legs) do
		minX = math.min(minX, item.position.X)
		maxX = math.max(maxX, item.position.X)
	end
	local splitX = (minX + maxX) * 0.5
	for _, item in ipairs(legs) do
		item.side = item.position.X >= splitX and 1 or -1
	end

	states[model] = {
		model = model,
		mesh = mesh,
		legs = legs,
		headBones = headBones,
		midBones = midBones,
		phase = math.random() * math.pi * 2,
		nextPeck = os.clock() + math.random(2, 6),
		peckStart = 0,
		pecking = false,
		rng = Random.new(),
	}
	return true
end

local function tryRegister(model)
	task.spawn(function()
		for _ = 1, 40 do
			if not model.Parent then
				return
			end
			if register(model) then
				return
			end
			task.wait(0.25)
		end
		if model.Parent then
			warn("[PalmVille Rooster] No skinned MeshPart with bones found in " .. model:GetFullName())
		end
	end)
end

local function animate(state, dt, now)
	local walking = state.model:GetAttribute("PalmVilleRoosterWalking") == true
	if walking then
		state.phase += dt * CONFIG.WalkCycleSpeed
	end

	local phase = state.phase
	for index, item in ipairs(state.legs) do
		local bone = item.bone
		if bone.Parent then
			local sidePhase = phase + (item.side == 1 and 0 or math.pi)
			local swing = walking and math.sin(sidePhase) * CONFIG.LegSwing or 0
			local bend = walking and math.max(0, math.sin(sidePhase + 0.55)) * CONFIG.LegBend or 0
			local scale = index <= 2 and 1 or 0.6
			bone.Transform = item.base * CFrame.Angles((swing + bend) * scale, 0, 0)
		end
	end

	local peck = 0
	if not walking then
		if not state.pecking and now >= state.nextPeck then
			state.pecking = true
			state.peckStart = now
		end
		if state.pecking then
			local alpha = math.clamp((now - state.peckStart) / CONFIG.PeckDuration, 0, 1)
			if alpha >= 1 then
				state.pecking = false
				state.nextPeck = now + state.rng:NextNumber(4, 9)
			else
				peck = math.sin(alpha * math.pi) * CONFIG.PeckAngle
			end
		end
	else
		state.pecking = false
	end

	for index, item in ipairs(state.headBones) do
		local bone = item.bone
		if bone.Parent then
			local idle = walking and math.sin(phase * 2) * CONFIG.HeadWalk
				or math.sin(now * 0.8 + index) * CONFIG.HeadIdle
			local multiplier = index == 1 and 1 or 0.5
			bone.Transform = item.base * CFrame.Angles(idle + peck * multiplier, 0, 0)
		end
	end

	for index, item in ipairs(state.midBones) do
		local bone = item.bone
		if bone.Parent then
			local motion
			if item.position.Y > 0 then
				motion = math.sin(now * 1.1 + index) * CONFIG.TailSway
			else
				motion = math.sin(now * 1.8 + index) * CONFIG.BodySway
			end
			if walking then
				motion += math.sin(phase * 2 + index) * math.rad(0.6)
			end
			bone.Transform = item.base * CFrame.Angles(motion, 0, motion * 0.3)
		end
	end
end

for _, model in ipairs(CollectionService:GetTagged(TAG)) do
	tryRegister(model)
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(tryRegister)
Workspace.DescendantAdded:Connect(function(item)
	if item:IsA("Model") and item:GetAttribute("PalmVilleRoosterReady") then
		tryRegister(item)
	end
end)

RunService.PreSimulation:Connect(function(dt)
	dt = math.min(dt, 0.05)
	local now = os.clock()
	for model, state in pairs(states) do
		if model.Parent and state.mesh.Parent then
			animate(state, dt, now)
		else
			states[model] = nil
		end
	end
end)
