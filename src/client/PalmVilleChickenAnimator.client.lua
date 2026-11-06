local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local TAG = "PalmVilleChickenNPC"

local BONE_NAMES = {
	"CHICKEN_-L-Thigh",
	"CHICKEN_-L-Calf",
	"CHICKEN_-R-Thigh",
	"CHICKEN_-R-Calf",
	"CHICKEN_-Spine",
	"CHICKEN_-L-Clavicle",
	"CHICKEN_-Neck",
	"CHICKEN_-R-Clavicle",
	"CHICKEN_-Tail",
}

local REQUIRED_BONES = {
	"CHICKEN_-L-Thigh",
	"CHICKEN_-L-Calf",
	"CHICKEN_-R-Thigh",
	"CHICKEN_-R-Calf",
}

local CONFIG = {
	Cadence = 7.2,
	ThighSwing = math.rad(23),
	KneeBend = math.rad(14),
	WingSwing = math.rad(1),
	HeadNod = math.rad(6),
	IdleHeadLook = math.rad(7),
	PeckAngle = math.rad(27),
	PeckDuration = 0.62,
}

local states = {}

local function findMesh(model)
	local mesh = model:FindFirstChild("pollo", true)
	if mesh and mesh:IsA("MeshPart") then
		return mesh
	end
	return nil
end

local function getAxisInBoneSpace(bone, worldAxis)
	local localAxis = bone.WorldCFrame:VectorToObjectSpace(worldAxis)
	if localAxis.Magnitude < 0.001 then
		return Vector3.xAxis
	end
	return localAxis.Unit
end

local function registerChicken(model)
	if states[model] or not model:IsA("Model") then
		return states[model] ~= nil
	end

	if not model:GetAttribute("PalmVilleChickenControllerReady") then
		return false
	end

	local mesh = findMesh(model)
	if not mesh then return false end

	local bones = {}
	for _, name in ipairs(BONE_NAMES) do
		local bone = mesh:FindFirstChild(name, true)
		if bone and bone:IsA("Bone") then
			bones[name] = bone
		end
	end

	for _, name in ipairs(REQUIRED_BONES) do
		if not bones[name] then
			warn(string.format("[PalmVille Chicken] %s is missing required client bone %s.", model.Name, name))
			return false
		end
	end

	local base = {}
	for name, bone in pairs(bones) do
		base[name] = bone.Transform
	end

	local worldSide = model:GetPivot().RightVector
	local hingeAxes = {}

	for _, name in ipairs(REQUIRED_BONES) do
		hingeAxes[name] = getAxisInBoneSpace(bones[name], worldSide)
	end

	local neckPitchAxis
	local neckYawAxis
	if bones["CHICKEN_-Neck"] then
		neckPitchAxis = getAxisInBoneSpace(bones["CHICKEN_-Neck"], worldSide)
		neckYawAxis = getAxisInBoneSpace(bones["CHICKEN_-Neck"], Vector3.yAxis)
	end

	states[model] = {
		model = model,
		mesh = mesh,
		bones = bones,
		base = base,
		hingeAxes = hingeAxes,
		neckPitchAxis = neckPitchAxis,
		neckYawAxis = neckYawAxis,
		phase = 0,
		pecking = false,
		peckStarted = 0,
		nextPeck = os.clock() + Random.new():NextNumber(1.5, 5),
		rng = Random.new(),
	}

	print("[PalmVille Chicken] Client animation registered: " .. model:GetFullName())
	return true
end

local function tryRegisterChicken(model)
	task.spawn(function()
		for _ = 1, 40 do
			if not model.Parent then return end
			if registerChicken(model) then return end
			task.wait(0.25)
		end
		warn("[PalmVille Chicken] Could not bind animation to " .. model.Name)
	end)
end

local function setHinge(state, name, angle)
	local bone = state.bones[name]
	local axis = state.hingeAxes[name]
	if bone and axis then
		bone.Transform = state.base[name] * CFrame.fromAxisAngle(axis, angle)
	end
end

local function setBone(state, name, transform)
	local bone = state.bones[name]
	if bone then
		bone.Transform = transform
	end
end

local function animateChicken(state, dt, now)
	local model = state.model
	local walking = model:GetAttribute("PalmVilleChickenIsWalking") == true

	if walking then
		state.phase += dt * CONFIG.Cadence
	end

	local phase = state.phase
	local leftWave = walking and math.sin(phase) or 0
	local rightWave = walking and math.sin(phase + math.pi) or 0

	local leftStride = CONFIG.ThighSwing * leftWave
	local rightStride = CONFIG.ThighSwing * rightWave
	local leftKnee = CONFIG.KneeBend * (walking and math.max(0, math.sin(phase + 0.45)) or 0)
	local rightKnee = CONFIG.KneeBend * (walking and math.max(0, math.sin(phase + math.pi + 0.45)) or 0)

	setHinge(state, "CHICKEN_-L-Thigh", leftStride)
	setHinge(state, "CHICKEN_-R-Thigh", rightStride)
	setHinge(state, "CHICKEN_-L-Calf", -leftKnee)
	setHinge(state, "CHICKEN_-R-Calf", -rightKnee)

	local walkWing = walking and math.sin(phase * 2) * CONFIG.WingSwing or 0
	local idleWing = math.sin(now * 1.7 + state.phase * 0.015) * math.rad(0.7)
	local wingMotion = walkWing + idleWing

	if state.base["CHICKEN_-L-Clavicle"] then
		setBone(state, "CHICKEN_-L-Clavicle",
			state.base["CHICKEN_-L-Clavicle"] * CFrame.Angles(0, 0, wingMotion))
	end
	if state.base["CHICKEN_-R-Clavicle"] then
		setBone(state, "CHICKEN_-R-Clavicle",
			state.base["CHICKEN_-R-Clavicle"] * CFrame.Angles(0, 0, -wingMotion))
	end

	if state.base["CHICKEN_-Spine"] then
		local lean = walking and math.sin(phase * 2) * math.rad(0.5) or 0
		setBone(state, "CHICKEN_-Spine",
			state.base["CHICKEN_-Spine"] * CFrame.Angles(lean, 0, 0))
	end

	local neckMotion = walking and math.sin(phase * 2) * CONFIG.HeadNod or 0
	local idleLook = not walking and math.sin(now * 0.72 + state.phase * 0.02) * CONFIG.IdleHeadLook or 0
	local peckMotion = 0

	if not walking then
		if not state.pecking and now >= state.nextPeck then
			state.pecking = true
			state.peckStarted = now
		end

		if state.pecking then
			local alpha = math.clamp((now - state.peckStarted) / CONFIG.PeckDuration, 0, 1)
			if alpha >= 1 then
				state.pecking = false
				state.nextPeck = now + state.rng:NextNumber(3, 7)
			elseif alpha < 0.38 then
				local down = alpha / 0.38
				peckMotion = math.sin(down * math.pi * 0.5) * CONFIG.PeckAngle
			else
				local up = (alpha - 0.38) / 0.62
				peckMotion = math.cos(up * math.pi * 0.5) * CONFIG.PeckAngle
			end
		end
	else
		state.pecking = false
	end

	if state.bones["CHICKEN_-Neck"] and state.neckPitchAxis and state.neckYawAxis then
		local pitch = CFrame.fromAxisAngle(state.neckPitchAxis, neckMotion + peckMotion)
		local look = CFrame.fromAxisAngle(state.neckYawAxis, idleLook)
		state.bones["CHICKEN_-Neck"].Transform = state.base["CHICKEN_-Neck"] * pitch * look
	end

	if state.base["CHICKEN_-Tail"] then
		local sway = walking and math.sin(phase) * math.rad(1.2) or math.sin(now * 1.1 + state.phase * 0.01) * math.rad(1.2)
		setBone(state, "CHICKEN_-Tail",
			state.base["CHICKEN_-Tail"] * CFrame.Angles(0, 0, sway))
	end
end

-- Bind any chickens already tagged by the server.
for _, model in ipairs(CollectionService:GetTagged(TAG)) do
	tryRegisterChicken(model)
end

-- Bind future chickens, including duplicates inserted during runtime.
CollectionService:GetInstanceAddedSignal(TAG):Connect(tryRegisterChicken)

CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(model)
	local state = states[model]
	if not state then return end

	for name, bone in pairs(state.bones) do
		if bone.Parent then
			bone.Transform = state.base[name]
		end
	end
	states[model] = nil
end)

RunService.PreSimulation:Connect(function(dt)
	dt = math.min(dt, 0.05)
	local now = os.clock()

	for model, state in pairs(states) do
		if model.Parent and state.mesh.Parent then
			animateChicken(state, dt, now)
		else
			states[model] = nil
		end
	end
end)

print("[PalmVille Chicken] Multi-NPC animator ready. Each tagged chicken has independent leg, wing, neck and peck animation.")
