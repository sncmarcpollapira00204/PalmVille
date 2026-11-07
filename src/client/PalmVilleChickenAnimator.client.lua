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

local ROOSTER_BONE_NAMES = {
	"rooster L Thigh", "rooster L Calf", "rooster L Foot", "rooster L Toe0", "rooster L Toe1",
	"rooster R Thigh", "rooster R Calf", "rooster R Foot", "rooster R Toe0", "rooster R Toe1",
	"rooster Spine", "rooster Neck", "rooster Neck1", "rooster Neck2", "rooster Head", "rooster Tail",
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
	RoosterThighSwing = math.rad(25),
	RoosterKneeBend = math.rad(24),
	RoosterFootSwing = math.rad(9),
	RoosterSpineBob = math.rad(1.8),
	RoosterNeckNod = math.rad(5),
	RoosterHeadIdleLook = math.rad(8),
	RoosterPeckAngle = math.rad(31),
	RoosterPeckDuration = 0.72,
	RoosterTailSway = math.rad(3),
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
	if states[model] or not model:IsA("Model") then
		return states[model] ~= nil
	end
	if not model:GetAttribute("PalmVilleChickenControllerReady") then return false end

	local mesh, kind = findMesh(model)
	if not mesh then return false end
	if kind == "StaticRooster" then return true end

	local names = kind == "Rooster" and ROOSTER_BONE_NAMES or BONE_NAMES
	local bones = {}
	for _, name in ipairs(names) do
		local bone = mesh:FindFirstChild(name, true)
		if bone and bone:IsA("Bone") then bones[name] = bone end
	end

	local required = kind == "Rooster"
		and {"rooster L Thigh", "rooster L Calf", "rooster R Thigh", "rooster R Calf", "rooster Neck", "rooster Neck1", "rooster Neck2", "rooster Head"}
		or REQUIRED_BONES
	for _, name in ipairs(required) do
		if not bones[name] then
			warn(string.format("[PalmVille Chicken] %s is missing required bone %s.", model.Name, name))
			return false
		end
	end

	local base = {}
	for name, bone in pairs(bones) do base[name] = bone.Transform end

	local worldSide = model:GetPivot().RightVector
	local hingeAxes = {}
	for name, bone in pairs(bones) do
		if string.find(name, "Thigh") or string.find(name, "Calf") or string.find(name, "Foot") then
			hingeAxes[name] = getAxisInBoneSpace(bone, worldSide)
		end
	end

	local neckPitchAxis
	local neckYawAxis
	local neckBoneName = kind == "Rooster" and "rooster Neck" or "CHICKEN_-Neck"
	if bones[neckBoneName] then
		neckPitchAxis = getAxisInBoneSpace(bones[neckBoneName], worldSide)
		neckYawAxis = getAxisInBoneSpace(bones[neckBoneName], Vector3.yAxis)
	end

	states[model] = {
		model = model,
		mesh = mesh,
		kind = kind,
		bones = bones,
		base = base,
		hingeAxes = hingeAxes,
		neckPitchAxis = neckPitchAxis,
		neckYawAxis = neckYawAxis,
		phase = Random.new():NextNumber(0, math.pi * 2),
		pecking = false,
		peckStarted = 0,
		nextPeck = os.clock() + Random.new():NextNumber(1.5, 5),
		rng = Random.new(),
	}
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
	if bone then bone.Transform = transform end
end

local function animateRooster(state, dt, now)
	local walking = state.model:GetAttribute("PalmVilleChickenIsWalking") == true
	if walking then state.phase += dt * CONFIG.Cadence end

	local phase = state.phase
	local left = walking and math.sin(phase) or 0
	local right = walking and math.sin(phase + math.pi) or 0

	setHinge(state, "rooster L Thigh", CONFIG.RoosterThighSwing * left)
	setHinge(state, "rooster R Thigh", CONFIG.RoosterThighSwing * right)
	setHinge(state, "rooster L Calf", -CONFIG.RoosterKneeBend * math.max(0, math.sin(phase + 0.45)) * (walking and 1 or 0))
	setHinge(state, "rooster R Calf", -CONFIG.RoosterKneeBend * math.max(0, math.sin(phase + math.pi + 0.45)) * (walking and 1 or 0))
	setHinge(state, "rooster L Foot", CONFIG.RoosterFootSwing * left)
	setHinge(state, "rooster R Foot", CONFIG.RoosterFootSwing * right)

	for _, name in ipairs({"rooster L Toe0", "rooster L Toe1", "rooster R Toe0", "rooster R Toe1"}) do
		local bone = state.bones[name]
		if bone then
			local side = string.find(name, " L ") and left or right
			bone.Transform = state.base[name] * CFrame.Angles(math.rad(5) * side, 0, 0)
		end
	end

	local neckAxis = state.neckPitchAxis or Vector3.xAxis
	local neckYawAxis = state.neckYawAxis or Vector3.yAxis
	local neckNod = walking and math.sin(phase * 2) * CONFIG.RoosterNeckNod or 0
	local idleLook = not walking and math.sin(now * 0.65 + state.phase * 0.02) * CONFIG.RoosterHeadIdleLook or 0
	local peck = 0

	if not walking then
		if not state.pecking and now >= state.nextPeck then
			state.pecking = true
			state.peckStarted = now
		end
		if state.pecking then
			local alpha = math.clamp((now - state.peckStarted) / CONFIG.RoosterPeckDuration, 0, 1)
			if alpha >= 1 then
				state.pecking = false
				state.nextPeck = now + state.rng:NextNumber(3, 7)
			elseif alpha < 0.38 then
				peck = math.sin((alpha / 0.38) * math.pi * 0.5) * CONFIG.RoosterPeckAngle
			else
				peck = math.cos(((alpha - 0.38) / 0.62) * math.pi * 0.5) * CONFIG.RoosterPeckAngle
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
		local bob = walking and math.sin(phase * 2) * CONFIG.RoosterSpineBob or math.sin(now * 1.4) * math.rad(0.45)
		spine.Transform = state.base["rooster Spine"] * CFrame.Angles(bob, 0, 0)
	end

	local tail = state.bones["rooster Tail"]
	if tail then
		local sway = math.sin(now * 1.15 + state.phase * 0.03) * CONFIG.RoosterTailSway
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
