local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local TAG = "PalmVilleChickenNPC"

local CHICKEN_BONE_NAMES = {
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

local ROOSTER_BONE_NAMES = {
	"rooster L Thigh",
	"rooster L Calf",
	"rooster L Foot",
	"rooster L Toe0",
	"rooster L Toe1",
	"rooster R Thigh",
	"rooster R Calf",
	"rooster R Foot",
	"rooster R Toe0",
	"rooster R Toe1",
	"rooster Spine",
	"rooster Neck",
	"rooster Neck1",
	"rooster Neck2",
	"rooster Head",
	"rooster Tail",
}

local CONFIG = {
	Cadence = 7.2,
	ThighSwing = math.rad(25),
	KneeBend = math.rad(24),
	FootSwing = math.rad(9),
	SpineBob = math.rad(1.8),
	NeckWalkNod = math.rad(5),
	HeadIdleLook = math.rad(8),
	PeckAngle = math.rad(31),
	PeckDuration = 0.72,
	TailSway = math.rad(3),
}

local states = {}

local function getAxisInBoneSpace(bone, worldAxis)
	local localAxis = bone.WorldCFrame:VectorToObjectSpace(worldAxis)
	if localAxis.Magnitude < 0.001 then return Vector3.xAxis end
	return localAxis.Unit
end

local function findMesh(model)
	local mesh = model:FindFirstChild("pollo", true)
	if mesh and mesh:IsA("MeshPart") then return mesh, "Chicken" end

	mesh = model:FindFirstChild("rooster_ground1", true)
	if mesh and mesh:IsA("MeshPart") then return mesh, "StaticRooster" end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("MeshPart") then
			local leftThigh = descendant:FindFirstChild("rooster L Thigh", true)
			local rightThigh = descendant:FindFirstChild("rooster R Thigh", true)
			if leftThigh and rightThigh and leftThigh:IsA("Bone") and rightThigh:IsA("Bone") then
				return descendant, "Rooster"
			end
		end
	end
	return nil
end

local function registerChicken(model)
	if states[model] or not model:IsA("Model") then return states[model] ~= nil end
	if not model:GetAttribute("PalmVilleChickenControllerReady") then return false end

	local mesh, kind = findMesh(model)
	if not mesh then return false end
	if kind == "StaticRooster" then return true end

	local names = kind == "Rooster" and ROOSTER_BONE_NAMES or CHICKEN_BONE_NAMES
	local bones = {}
	for _, name in ipairs(names) do
		local bone = mesh:FindFirstChild(name, true)
		if bone and bone:IsA("Bone") then bones[name] = bone end
	end

	if kind == "Rooster" then
		for _, required in ipairs({"rooster L Thigh", "rooster L Calf", "rooster R Thigh", "rooster R Calf", "rooster Neck", "rooster Neck1", "rooster Neck2", "rooster Head"}) do
			if not bones[required] then
				warn("[PalmVille Rooster] Missing bone: " .. required)
				return false
			end
		end
	else
		for _, required in ipairs({"CHICKEN_-L-Thigh", "CHICKEN_-L-Calf", "CHICKEN_-R-Thigh", "CHICKEN_-R-Calf"}) do
			if not bones[required] then return false end
		end
	end

	local base = {}
	for name, bone in pairs(bones) do base[name] = bone.Transform end

	local worldSide = model:GetPivot().RightVector
	local axes = {}
	for name, bone in pairs(bones) do
		if string.find(name, "Thigh") or string.find(name, "Calf") or string.find(name, "Foot") then
			axes[name] = getAxisInBoneSpace(bone, worldSide)
		end
	end

	local state = {
		model = model,
		mesh = mesh,
		kind = kind,
		bones = bones,
		base = base,
		axes = axes,
		phase = Random.new():NextNumber(0, math.pi * 2),
		pecking = false,
		peckStarted = 0,
		nextPeck = os.clock() + Random.new():NextNumber(2, 5),
		rng = Random.new(),
	}
	states[model] = state
	return true
end

local function tryRegisterChicken(model)
	task.spawn(function()
		for _ = 1, 40 do
			if not model.Parent then return end
			if registerChicken(model) then return end
			task.wait(0.25)
		end
	end)
end

local function setBoneRotation(state, name, axis, angle)
	local bone = state.bones[name]
	if bone and state.base[name] then
		bone.Transform = state.base[name] * CFrame.fromAxisAngle(axis, angle)
	end
end

local function animateRooster(state, dt, now)
	local walking = state.model:GetAttribute("PalmVilleChickenIsWalking") == true
	if walking then state.phase += dt * CONFIG.Cadence end

	local phase = state.phase
	local left = walking and math.sin(phase) or 0
	local right = walking and math.sin(phase + math.pi) or 0

	setBoneRotation(state, "rooster L Thigh", state.axes["rooster L Thigh"] or Vector3.xAxis, CONFIG.ThighSwing * left)
	setBoneRotation(state, "rooster R Thigh", state.axes["rooster R Thigh"] or Vector3.xAxis, CONFIG.ThighSwing * right)
	setBoneRotation(state, "rooster L Calf", state.axes["rooster L Calf"] or Vector3.xAxis, -CONFIG.KneeBend * math.max(0, math.sin(phase + 0.45)) * (walking and 1 or 0))
	setBoneRotation(state, "rooster R Calf", state.axes["rooster R Calf"] or Vector3.xAxis, -CONFIG.KneeBend * math.max(0, math.sin(phase + math.pi + 0.45)) * (walking and 1 or 0))
	setBoneRotation(state, "rooster L Foot", state.axes["rooster L Foot"] or Vector3.xAxis, CONFIG.FootSwing * left)
	setBoneRotation(state, "rooster R Foot", state.axes["rooster R Foot"] or Vector3.xAxis, CONFIG.FootSwing * right)

	for _, name in ipairs({"rooster L Toe0", "rooster L Toe1", "rooster R Toe0", "rooster R Toe1"}) do
		local bone = state.bones[name]
		if bone then
			local side = string.find(name, " L ") and left or right
			bone.Transform = state.base[name] * CFrame.Angles(math.rad(5) * side, 0, 0)
		end
	end

	local neckAxis = getAxisInBoneSpace(state.bones["rooster Neck"], state.model:GetPivot().RightVector)
	local neckYawAxis = getAxisInBoneSpace(state.bones["rooster Neck"], Vector3.yAxis)
	local neckNod = walking and math.sin(phase * 2) * CONFIG.NeckWalkNod or 0
	local idleLook = not walking and math.sin(now * 0.65 + state.phase * 0.02) * CONFIG.HeadIdleLook or 0
	local peck = 0

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
				peck = math.sin((alpha / 0.38) * math.pi * 0.5) * CONFIG.PeckAngle
			else
				peck = math.cos(((alpha - 0.38) / 0.62) * math.pi * 0.5) * CONFIG.PeckAngle
			end
		end
	else
		state.pecking = false
	end

	local neck1 = state.bones["rooster Neck1"]
	local neck2 = state.bones["rooster Neck2"]
	local head = state.bones["rooster Head"]
	if neck1 then
		neck1.Transform = state.base["rooster Neck1"] * CFrame.fromAxisAngle(neckAxis, neckNod * 0.45 + peck * 0.35)
	end
	if neck2 then
		neck2.Transform = state.base["rooster Neck2"] * CFrame.fromAxisAngle(neckAxis, neckNod * 0.55 + peck * 0.65)
	end
	if head then
		head.Transform = state.base["rooster Head"]
			* CFrame.fromAxisAngle(neckAxis, peck * 0.25)
			* CFrame.fromAxisAngle(neckYawAxis, idleLook)
	end

	local spine = state.bones["rooster Spine"]
	if spine then
		local bob = walking and math.sin(phase * 2) * CONFIG.SpineBob or math.sin(now * 1.4) * math.rad(0.45)
		spine.Transform = state.base["rooster Spine"] * CFrame.Angles(bob, 0, 0)
	end

	local tail = state.bones["rooster Tail"]
	if tail then
		local sway = math.sin(now * 1.15 + state.phase * 0.03) * CONFIG.TailSway
		tail.Transform = state.base["rooster Tail"] * CFrame.Angles(0, sway, 0)
	end
end

local function animateChicken(state, dt, now)
	if state.kind == "Rooster" then
		animateRooster(state, dt, now)
		return
	end

	local model = state.model
	local walking = model:GetAttribute("PalmVilleChickenIsWalking") == true
	if walking then state.phase += dt * CONFIG.Cadence end

	local phase = state.phase
	local leftWave = walking and math.sin(phase) or 0
	local rightWave = walking and math.sin(phase + math.pi) or 0
	local leftKnee = CONFIG.KneeBend * (walking and math.max(0, math.sin(phase + 0.45)) or 0)
	local rightKnee = CONFIG.KneeBend * (walking and math.max(0, math.sin(phase + math.pi + 0.45)) or 0)

	local function setChickenHinge(name, angle)
		local bone = state.bones[name]
		local axis = state.axes[name] or Vector3.xAxis
		if bone then bone.Transform = state.base[name] * CFrame.fromAxisAngle(axis, angle) end
	end

	setChickenHinge("CHICKEN_-L-Thigh", math.rad(23) * leftWave)
	setChickenHinge("CHICKEN_-R-Thigh", math.rad(23) * rightWave)
	setChickenHinge("CHICKEN_-L-Calf", -leftKnee)
	setChickenHinge("CHICKEN_-R-Calf", -rightKnee)

	local neck = state.bones["CHICKEN_-Neck"]
	if neck then
		local axis = getAxisInBoneSpace(neck, model:GetPivot().RightVector)
		neck.Transform = state.base["CHICKEN_-Neck"] * CFrame.fromAxisAngle(axis, walking and math.sin(phase * 2) * math.rad(6) or 0)
	end
	local tail = state.bones["CHICKEN_-Tail"]
	if tail then tail.Transform = state.base["CHICKEN_-Tail"] * CFrame.Angles(0, 0, math.sin(now) * math.rad(1.2)) end
end

for _, model in ipairs(CollectionService:GetTagged(TAG)) do
	tryRegisterChicken(model)
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(tryRegisterChicken)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(model)
	local state = states[model]
	if not state then return end
	for name, bone in pairs(state.bones) do
		if bone.Parent then bone.Transform = state.base[name] end
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
