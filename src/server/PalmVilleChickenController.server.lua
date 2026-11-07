local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local TAG = "PalmVilleChickenNPC"
local MODEL_NAMES = {
	["PalmVilleChicken - Owned"] = true,
	PalmVilleChicken = true,
	fullpollo = true,
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
}

local states = {}
local registering = setmetatable({}, {__mode = "k"})

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

	local valid, missingBone = hasRequiredBones(mesh)
	if not valid then
		registering[model] = nil
		warn(string.format("[PalmVille Chicken] %s is missing bone %s.", model:GetFullName(), missingBone))
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
		homePosition = homePosition,
		homeRotation = homePivot.Rotation,
		homeForward = homeForward,
		fixedY = homePosition.Y,
		position = Vector3.new(homePosition.X, homePosition.Y, homePosition.Z),
		direction = homeForward,
		target = Vector3.new(homePosition.X, homePosition.Y, homePosition.Z),
		walking = false,
		nextDecision = os.clock() + rng:NextNumber(1, 4),
		rng = rng,
	}

	states[model] = state
	registering[model] = nil
	model:SetAttribute("PalmVilleChickenControllerReady", true)
	model:SetAttribute("PalmVilleChickenIsWalking", false)
	CollectionService:AddTag(model, TAG)
	return true
end

local function tryRegister(model)
	if states[model] or registering[model] or not MODEL_NAMES[model.Name] then
		return
	end

	task.spawn(function()
		for _ = 1, 20 do
			if not model.Parent then return end
			if registerChicken(model) then return end
			task.wait(0.25)
		end

		if model.Parent and MODEL_NAMES[model.Name] then
			warn("[PalmVille Chicken] Could not register model: " .. model:GetFullName())
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
	local yawDelta = math.atan2(crossY, dot) + math.rad(CONFIG.FaceYawOffset)
	local yawRotation = CFrame.fromAxisAngle(Vector3.yAxis, yawDelta)
	local targetPivot = CFrame.new(state.position) * yawRotation * state.homeRotation

	model:PivotTo(model:GetPivot():Lerp(targetPivot, math.clamp(dt * CONFIG.TurnSpeed, 0, 1)))
	return true
end

for _, descendant in ipairs(Workspace:GetDescendants()) do
	if descendant:IsA("Model") and MODEL_NAMES[descendant.Name] then
		tryRegister(descendant)
	end
end

Workspace.DescendantAdded:Connect(function(instance)
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
