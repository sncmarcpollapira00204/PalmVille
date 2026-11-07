local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local TAG = "PalmVilleChickenNPC"
local MODEL_NAMES = {
	["PalmVilleChicken - Owned"] = true,
	PalmVilleChicken = true,
	fullpollo = true,
	Cock = true,
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
}

local states = {}
local registering = setmetatable({}, {__mode = "k"})
local random = Random.new()

local REQUIRED_BONES = {
	"CHICKEN_-L-Thigh",
	"CHICKEN_-L-Calf",
	"CHICKEN_-R-Thigh",
	"CHICKEN_-R-Calf",
}

local function findChickenMesh(model)
	if not model:IsA("Model") or not MODEL_NAMES[model.Name] then
		return nil
	end

	local mesh = model:FindFirstChild("pollo", true)
	if mesh and mesh:IsA("MeshPart") then
		return mesh
	end

	mesh = model:FindFirstChild("rooster_ground1", true)
	if mesh and mesh:IsA("MeshPart") then
		return mesh
	end

	return nil
end

local function hasRequiredBones(mesh)
	for _, name in ipairs(REQUIRED_BONES) do
		local bone = mesh:FindFirstChild(name, true)
		if not bone or not bone:IsA("Bone") then
			return false, name
		end
	end
	return true
end

local function registerChicken(model)
	if states[model] or registering[model] or not model:IsDescendantOf(Workspace) then
		return false
	end
	registering[model] = true

	local mesh = findChickenMesh(model)
	if not mesh then
		registering[model] = nil
		return false
	end

	local isStaticRooster = model.Name == "Cock" and mesh.Name == "rooster_ground1"
	local valid, missingBone = hasRequiredBones(mesh)
	if not valid and not isStaticRooster then
		registering[model] = nil
		warn(string.format("[PalmVille Chicken] %s is missing bone %s.", model:GetFullName(), missingBone))
		return false
	end

	-- Each duplicated model gets its own fixed-height movement state.
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

	local state = {
		model = model,
		mesh = mesh,
		homePosition = homePosition,
		homeRotation = homeRotation,
		homeForward = homeForward,
		fixedY = homePosition.Y,
		position = Vector3.new(homePosition.X, homePosition.Y, homePosition.Z),
		direction = homeForward,
		target = Vector3.new(homePosition.X, homePosition.Y, homePosition.Z),
		walking = false,
		nextDecision = os.clock() + random:NextNumber(1, 4),
		rng = Random.new(),
		isStaticRooster = isStaticRooster,
		animationPhase = random:NextNumber(0, math.pi * 2),
		nextPeck = os.clock() + random:NextNumber(2, 5),
		peckStarted = 0,
		pecking = false,
	}

	states[model] = state
	registering[model] = nil
	model:SetAttribute("PalmVilleChickenControllerReady", true)
	model:SetAttribute("PalmVilleChickenIsWalking", false)
	CollectionService:AddTag(model, TAG)

	print("[PalmVille Chicken] Registered: " .. model:GetFullName())
	return true
end

local function tryRegister(model)
	if states[model] or registering[model] then return end

	task.spawn(function()
		for _ = 1, 20 do
			if not model.Parent then return end
			if registerChicken(model) then return end
			task.wait(0.25)
		end

		if model.Parent and MODEL_NAMES[model.Name] then
			warn("[PalmVille Chicken] Could not register duplicated model: " .. model:GetFullName())
		end
	end)
end

local function chooseTarget(state)
	for _ = 1, 12 do
		local angle = state.rng:NextNumber(0, math.pi * 2)
		local distance = state.rng:NextNumber(
			CONFIG.MinWalkDistance,
			CONFIG.MaxWalkDistance
		)

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
	if not model.Parent or not state.mesh.Parent then
		return false
	end

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
	local faceOffset = state.isStaticRooster and CONFIG.RoosterFaceYawOffset or CONFIG.FaceYawOffset
	local yawDelta = math.atan2(crossY, dot) + math.rad(faceOffset)
	local yawRotation = CFrame.fromAxisAngle(Vector3.yAxis, yawDelta)
	local targetPivot = CFrame.new(state.position) * yawRotation * state.homeRotation

	if state.isStaticRooster then
		if state.walking then
			state.animationPhase += dt * 7.2
		else
			if not state.pecking and now >= state.nextPeck then
				state.pecking = true
				state.peckStarted = now
			end
			if state.pecking and now - state.peckStarted >= 0.62 then
				state.pecking = false
				state.nextPeck = now + state.rng:NextNumber(3, 7)
			end
		end

		local bob = state.walking and math.abs(math.sin(state.animationPhase * 2)) * 0.055 or math.sin(now * 1.7) * 0.012
		local roll = state.walking and math.sin(state.animationPhase) * math.rad(2.5) or 0
		local peck = 0
		if state.pecking then
			local progress = math.clamp((now - state.peckStarted) / 0.62, 0, 1)
			peck = math.sin(progress * math.pi) * math.rad(10)
		end
		targetPivot = targetPivot
			* CFrame.new(0, bob, 0)
			* CFrame.Angles(peck, 0, roll)
	end

	local alpha = math.clamp(dt * CONFIG.TurnSpeed, 0, 1)
	model:PivotTo(model:GetPivot():Lerp(targetPivot, alpha))
	return true
end

-- Register every imported chicken already in Workspace.
for _, descendant in ipairs(Workspace:GetDescendants()) do
	if descendant:IsA("Model") and MODEL_NAMES[descendant.Name] then
		tryRegister(descendant)
	end
end

-- Also register chickens duplicated or inserted while the server is running.
Workspace.DescendantAdded:Connect(function(instance)
	if instance:IsA("Model") and MODEL_NAMES[instance.Name] then
		tryRegister(instance)
	end
end)

Workspace.ChildAdded:Connect(function(instance)
	if instance:IsA("Model") and MODEL_NAMES[instance.Name] then
		tryRegister(instance)
	end
end)

RunService.Heartbeat:Connect(function(dt)
	dt = math.min(dt, 0.05)
	local now = os.clock()

	for model, state in pairs(states) do
		if not updateChicken(state, dt, now) then
			states[model] = nil
		end
	end
end)

print("[PalmVille Chicken] Multi-NPC controller ready. Every imported chicken clone gets independent wandering.")
