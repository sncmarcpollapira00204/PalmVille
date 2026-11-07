local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local TAG = "PalmVilleChickenNPC"
local MODEL_NAMES = {
	["PalmVilleChicken - Owned"] = true,
	PalmVilleChicken = true,
	fullpollo = true,
	Cock = true,
	Rooster = true,
	Bird_Rooster_Brown_01 = true,
}

local CONFIG = {
	WalkSpeed = 1.55,
	WanderRadius = 9,
	MinWalkDistance = 3,
	MaxWalkDistance = 7,
	MinPause = 2,
	MaxPause = 4.5,
	TurnSpeed = 4.5,
	FaceYawOffset = 180,
	RoosterFaceYawOffset = 0,
	RoosterCrowSoundId = "rbxassetid://135218417",
	RoosterCrowMinDelay = 105,
	RoosterCrowMaxDelay = 210,
}

local states = {}
local registering = setmetatable({}, {__mode = "k"})
local random = Random.new()

local CHICKEN_BONES = {
	"CHICKEN_-L-Thigh",
	"CHICKEN_-L-Calf",
	"CHICKEN_-R-Thigh",
	"CHICKEN_-R-Calf",
}

local ROOSTER_BONES = {
	"rooster L Thigh",
	"rooster L Calf",
	"rooster R Thigh",
	"rooster R Calf",
}

local function findRoosterMesh(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("MeshPart") then
			for _, boneName in ipairs(ROOSTER_BONES) do
				local bone = descendant:FindFirstChild(boneName, true)
				if bone and bone:IsA("Bone") then
					return descendant
				end
			end
		end
	end
	return nil
end

local function findChickenMesh(model)
	if not model:IsA("Model") then return nil end

	local roosterMesh = findRoosterMesh(model)
	if roosterMesh then return roosterMesh, "Rooster" end

	local mesh = model:FindFirstChild("pollo", true)
	if mesh and mesh:IsA("MeshPart") then return mesh, "Chicken" end

	mesh = model:FindFirstChild("rooster_ground1", true)
	if mesh and mesh:IsA("MeshPart") then return mesh, "StaticRooster" end

	return nil
end

local function hasBones(mesh, requiredBones)
	for _, name in ipairs(requiredBones) do
		local bone = mesh:FindFirstChild(name, true)
		if not bone or not bone:IsA("Bone") then
			return false, name
		end
	end
	return true
end

local function isCandidateModel(model)
	if not model:IsA("Model") then return false end
	if MODEL_NAMES[model.Name] then return true end
	return findRoosterMesh(model) ~= nil
end

local function attachRoosterSound(state)
	if CONFIG.RoosterCrowSoundId == "" then return end

	local sound = Instance.new("Sound")
	sound.Name = "PalmVilleRoosterCrow"
	sound.SoundId = CONFIG.RoosterCrowSoundId
	sound.Volume = 0.42
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = 55
	sound.Parent = state.mesh
	state.crowSound = sound
	state.nextCrow = os.clock() + state.rng:NextNumber(
		CONFIG.RoosterCrowMinDelay,
		CONFIG.RoosterCrowMaxDelay
	)
end

local function registerChicken(model)
	if states[model] or registering[model] or not model:IsDescendantOf(Workspace) then
		return false
	end
	registering[model] = true

	local mesh, kind = findChickenMesh(model)
	if not mesh then
		registering[model] = nil
		return false
	end

	local requiredBones = kind == "Chicken" and CHICKEN_BONES or kind == "Rooster" and ROOSTER_BONES
	if requiredBones then
		local valid, missingBone = hasBones(mesh, requiredBones)
		if not valid then
			registering[model] = nil
			warn(string.format("[PalmVille Chicken] %s is missing bone %s.", model:GetFullName(), missingBone))
			return false
		end
	elseif kind == "StaticRooster" and model.Name ~= "Cock" then
		registering[model] = nil
		return false
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
	mesh.Anchored = true

	local homePivot = model:GetPivot()
	local homePosition = homePivot.Position
	local homeRotation = homePivot.Rotation
	local homeLook = homePivot.LookVector
	local homeForward = Vector3.new(homeLook.X, 0, homeLook.Z)

	if homeForward.Magnitude < 0.001 then
		homeForward = Vector3.new(0, 0, -1)
	else
		homeForward = homeForward.Unit
	end

	local rng = Random.new()
	local state = {
		model = model,
		mesh = mesh,
		kind = kind,
		homePosition = homePosition,
		homeRotation = homeRotation,
		homeForward = homeForward,
		fixedY = homePosition.Y,
		position = Vector3.new(homePosition.X, homePosition.Y, homePosition.Z),
		direction = homeForward,
		target = Vector3.new(homePosition.X, homePosition.Y, homePosition.Z),
		walking = false,
		nextDecision = os.clock() + rng:NextNumber(1, 4),
		rng = rng,
		animationPhase = rng:NextNumber(0, math.pi * 2),
		nextPeck = os.clock() + rng:NextNumber(2, 5),
		peckStarted = 0,
		pecking = false,
	}
	states[model] = state
	registering[model] = nil

	model:SetAttribute("PalmVilleChickenControllerReady", true)
	model:SetAttribute("PalmVilleChickenIsWalking", false)
	model:SetAttribute("PalmVilleAnimalType", kind)
	CollectionService:AddTag(model, TAG)

	if kind == "Rooster" then
		attachRoosterSound(state)
	end

	return true
end

local function tryRegister(model)
	if states[model] or registering[model] or not isCandidateModel(model) then return end

	task.spawn(function()
		for _ = 1, 20 do
			if not model.Parent then return end
			if registerChicken(model) then return end
			task.wait(0.25)
		end
		if model.Parent and isCandidateModel(model) then
			warn("[PalmVille Chicken] Could not register animal: " .. model:GetFullName())
		end
	end)
end

local function chooseTarget(state)
	for _ = 1, 12 do
		local angle = state.rng:NextNumber(0, math.pi * 2)
		local distance = state.rng:NextNumber(CONFIG.MinWalkDistance, CONFIG.MaxWalkDistance)
		local candidate = Vector3.new(
			state.homePosition.X + math.cos(angle) * distance,
			state.fixedY,
			state.homePosition.Z + math.sin(angle) * distance
		)
		if (candidate - state.homePosition).Magnitude <= CONFIG.WanderRadius then
			state.target = candidate
			state.walking = true
			state.model:SetAttribute("PalmVilleChickenIsWalking", true)
			return
		end
	end
	state.walking = false
	state.model:SetAttribute("PalmVilleChickenIsWalking", false)
	state.nextDecision = os.clock() + 2
end

local function updateChicken(state, dt, now)
	local model = state.model
	if not model.Parent or not state.mesh.Parent then return false end

	if state.walking then
		local difference = Vector3.new(
			state.target.X - state.position.X,
			0,
			state.target.Z - state.position.Z
		)
		local distance = difference.Magnitude
		if distance <= 0.12 then
			state.walking = false
			model:SetAttribute("PalmVilleChickenIsWalking", false)
			state.nextDecision = now + state.rng:NextNumber(CONFIG.MinPause, CONFIG.MaxPause)
		else
			state.direction = difference.Unit
			state.position += state.direction * math.min(CONFIG.WalkSpeed * dt, distance)
		end
	elseif now >= state.nextDecision then
		chooseTarget(state)
	end

	state.position = Vector3.new(state.position.X, state.fixedY, state.position.Z)
	local desiredDirection = Vector3.new(state.direction.X, 0, state.direction.Z)
	if desiredDirection.Magnitude < 0.001 then
		desiredDirection = state.homeForward
	else
		desiredDirection = desiredDirection.Unit
	end

	local crossY = state.homeForward:Cross(desiredDirection).Y
	local dot = math.clamp(state.homeForward:Dot(desiredDirection), -1, 1)
	local offset = state.kind == "Rooster" and CONFIG.RoosterFaceYawOffset or CONFIG.FaceYawOffset
	local customOffset = model:GetAttribute("PalmVilleForwardYawOffset")
	if typeof(customOffset) == "number" then offset = customOffset end

	local yawDelta = math.atan2(crossY, dot) + math.rad(offset)
	local yawRotation = CFrame.fromAxisAngle(Vector3.yAxis, yawDelta)
	local targetPivot = CFrame.new(state.position) * yawRotation * state.homeRotation

	if state.kind == "StaticRooster" then
		if state.walking then
			state.animationPhase += dt * 7.2
		elseif not state.pecking and now >= state.nextPeck then
			state.pecking = true
			state.peckStarted = now
		end
		if state.pecking and now - state.peckStarted >= 0.62 then
			state.pecking = false
			state.nextPeck = now + state.rng:NextNumber(3, 7)
		end
		local bob = state.walking and math.abs(math.sin(state.animationPhase * 2)) * 0.035 or math.sin(now * 1.7) * 0.008
		targetPivot *= CFrame.new(0, bob, 0)
	end

	if state.kind == "Rooster" and state.crowSound and now >= state.nextCrow then
		if not state.walking and not state.crowSound.IsPlaying then
			state.crowSound:Play()
		end
		state.nextCrow = now + state.rng:NextNumber(CONFIG.RoosterCrowMinDelay, CONFIG.RoosterCrowMaxDelay)
	end

	local alpha = math.clamp(dt * CONFIG.TurnSpeed, 0, 1)
	model:PivotTo(model:GetPivot():Lerp(targetPivot, alpha))
	return true
end

for _, descendant in ipairs(Workspace:GetDescendants()) do
	if descendant:IsA("Model") and isCandidateModel(descendant) then
		tryRegister(descendant)
	end
end

Workspace.DescendantAdded:Connect(function(instance)
	if instance:IsA("Model") and isCandidateModel(instance) then
		tryRegister(instance)
	end
end)

RunService.Heartbeat:Connect(function(dt)
	dt = math.min(dt, 0.05)
	local now = os.clock()
	for model, state in pairs(states) do
		if not updateChicken(state, dt, now) then
			if state.crowSound then state.crowSound:Destroy() end
			states[model] = nil
		end
	end
end)
