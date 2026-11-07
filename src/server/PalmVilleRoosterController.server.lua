local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local TAG = "PalmVilleRooster"
local MODEL_NAMES = {
	["Chicken - Loof"] = true,
	["Chicken Rooster idle by Jungle Jim (animated)"] = true,
	["Chicken Rooster idle by Jungle Jim (animated)(1)"] = true,
	Rooster = true,
	PalmVilleRooster = true,
}

local CONFIG = {
	WalkSpeed = 1.15,
	WanderRadius = 8,
	MinWalkDistance = 2.5,
	MaxWalkDistance = 5.5,
	MinPause = 3,
	MaxPause = 7,
	TurnSpeed = 3.5,
	CrowSoundId = "rbxassetid://135218417",
	FirstCrowMin = 18,
	FirstCrowMax = 35,
	CrowMin = 55,
	CrowMax = 105,
	CrowVolume = 0.65,
	CrowDistance = 85,
}

local function makeCollisionProbe(model)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {model}
	params.IgnoreWater = true
	params.RespectCanCollide = true

	local boxCFrame, boxSize = model:GetBoundingBox()
	local pivot = model:GetPivot()
	local boxOffset = pivot:PointToObjectSpace(boxCFrame.Position)
	local halfWidth = math.max(0.35, math.min(boxSize.X, boxSize.Z) * 0.32)
	local halfHeight = math.max(0.6, boxSize.Y * 0.34)

	return {
		params = params,
		boxOffset = boxOffset,
		sideOffset = halfWidth,
		heightOffset = halfHeight,
	}
end

local function canMove(state, direction, distance)
	if distance <= 0 then
		return true
	end

	local probe = state.collisionProbe
	local side = Vector3.new(-direction.Z, 0, direction.X)
	local originBase = state.position + probe.boxOffset
	local castVector = direction * (distance + 0.35)

	for _, sideScale in ipairs({0, -1, 1}) do
		local lateral = side * probe.sideOffset * sideScale
		for _, heightScale in ipairs({-1, 0, 1}) do
			local origin = originBase + lateral + Vector3.yAxis * probe.heightOffset * heightScale
			local hit = Workspace:Raycast(origin, castVector, probe.params)
			if hit and hit.Instance and hit.Instance.CanCollide then
				return false
			end
		end
	end

	return true
end

local states = {}
local registering = setmetatable({}, {__mode = "k"})

local function findRigMesh(model)
	local bestMesh
	local bestBoneCount = 0

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("MeshPart") then
			local count = 0
			for _, child in ipairs(descendant:GetDescendants()) do
				if child:IsA("Bone") then
					count += 1
				end
			end
			if count > bestBoneCount then
				bestMesh = descendant
				bestBoneCount = count
			end
		end
	end

	if bestBoneCount >= 6 then
		return bestMesh, bestBoneCount
	end
	return nil, bestBoneCount
end

local function findSoundParent(model, mesh)
	if mesh then
		return mesh
	end
	if model.PrimaryPart then
		return model.PrimaryPart
	end
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") then
			return item
		end
	end
	return nil
end

local function addCrowSound(parent)
	local sound = parent:FindFirstChild("PalmVilleRoosterCrow")
	if sound and sound:IsA("Sound") then
		return sound
	end

	sound = Instance.new("Sound")
	sound.Name = "PalmVilleRoosterCrow"
	sound.SoundId = CONFIG.CrowSoundId
	sound.Volume = CONFIG.CrowVolume
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 12
	sound.RollOffMaxDistance = CONFIG.CrowDistance
	sound.EmitterSize = 8
	sound.Parent = parent
	return sound
end

local function register(model)
	if states[model] or registering[model] or not model:IsDescendantOf(Workspace) then
		return false
	end
	registering[model] = true

	local mesh, boneCount = findRigMesh(model)
	if not mesh then
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

	local pivot = model:GetPivot()
	local look = pivot.LookVector
	local forward = Vector3.new(look.X, 0, look.Z)
	if forward.Magnitude < 0.001 then
		forward = Vector3.new(0, 0, -1)
	else
		forward = forward.Unit
	end

	local rng = Random.new()
	local soundParent = findSoundParent(model, mesh)
	local now = os.clock()

	states[model] = {
		model = model,
		mesh = mesh,
		position = pivot.Position,
		homePosition = pivot.Position,
		homeRotation = pivot.Rotation,
		homeForward = forward,
		direction = forward,
		target = pivot.Position,
		walking = false,
		nextDecision = now + rng:NextNumber(2, 5),
		nextCrow = now + rng:NextNumber(CONFIG.FirstCrowMin, CONFIG.FirstCrowMax),
		rng = rng,
		sound = soundParent and addCrowSound(soundParent) or nil,
	}

	registering[model] = nil
	model:SetAttribute("PalmVilleRoosterReady", true)
	model:SetAttribute("PalmVilleRoosterWalking", false)
	model:SetAttribute("PalmVilleRoosterBoneCount", boneCount)
	CollectionService:AddTag(model, TAG)
	return true
end

local function isRooster(model)
	if not model:IsA("Model") then
		return false
	end
	if CollectionService:HasTag(model, TAG) then
		return true
	end
	return MODEL_NAMES[model.Name] == true
end

local function tryRegister(model)
	if not isRooster(model) or states[model] or registering[model] then
		return
	end

	task.spawn(function()
		for _ = 1, 30 do
			if not model.Parent then
				return
			end
			if register(model) then
				return
			end
			task.wait(0.25)
		end
		if model.Parent then
			warn("[PalmVille Rooster] Could not find a skinned MeshPart with bones in " .. model:GetFullName())
		end
	end)
end

local function chooseTarget(state, now)
	for _ = 1, 12 do
		local angle = state.rng:NextNumber(0, math.pi * 2)
		local distance = state.rng:NextNumber(CONFIG.MinWalkDistance, CONFIG.MaxWalkDistance)
		local candidate = Vector3.new(
			state.homePosition.X + math.cos(angle) * distance,
			state.position.Y,
			state.homePosition.Z + math.sin(angle) * distance
		)

		if (candidate - state.homePosition).Magnitude <= CONFIG.WanderRadius then
			state.target = candidate
			state.walking = true
			state.model:SetAttribute("PalmVilleRoosterWalking", true)
			return
		end
	end

	state.walking = false
	state.model:SetAttribute("PalmVilleRoosterWalking", false)
	state.nextDecision = now + 2
end

local function update(state, dt, now)
	local model = state.model
	if not model.Parent or not state.mesh.Parent then
		return false
	end

	if state.walking then
		local delta = Vector3.new(
			state.target.X - state.position.X,
			0,
			state.target.Z - state.position.Z
		)
		local distance = delta.Magnitude

		if distance <= 0.12 then
			state.walking = false
			model:SetAttribute("PalmVilleRoosterWalking", false)
			state.nextDecision = now + state.rng:NextNumber(CONFIG.MinPause, CONFIG.MaxPause)
		else
			state.direction = delta.Unit
			state.position += state.direction * math.min(CONFIG.WalkSpeed * dt, distance)
		end
	elseif now >= state.nextDecision then
		chooseTarget(state, now)
	end

	if state.sound and now >= state.nextCrow then
		if state.sound.Parent and not state.sound.IsPlaying then
			state.sound:Play()
		end
		state.nextCrow = now + state.rng:NextNumber(CONFIG.CrowMin, CONFIG.CrowMax)
	end

	local desired = Vector3.new(state.direction.X, 0, state.direction.Z)
	if desired.Magnitude < 0.001 then
		desired = state.homeForward
	else
		desired = desired.Unit
	end

	local crossY = state.homeForward:Cross(desired).Y
	local dot = math.clamp(state.homeForward:Dot(desired), -1, 1)
	local yaw = math.atan2(crossY, dot)
	local targetPivot = CFrame.new(state.position)
		* CFrame.fromAxisAngle(Vector3.yAxis, yaw)
		* state.homeRotation

	model:PivotTo(model:GetPivot():Lerp(targetPivot, math.clamp(dt * CONFIG.TurnSpeed, 0, 1)))
	return true
end

for _, item in ipairs(Workspace:GetDescendants()) do
	if item:IsA("Model") and isRooster(item) then
		tryRegister(item)
	end
end

Workspace.DescendantAdded:Connect(function(item)
	if item:IsA("Model") and isRooster(item) then
		tryRegister(item)
	end
end)

CollectionService:GetInstanceAddedSignal(TAG):Connect(tryRegister)

RunService.Heartbeat:Connect(function(dt)
	dt = math.min(dt, 0.05)
	local now = os.clock()

	for model, state in pairs(states) do
		if not update(state, dt, now) then
			states[model] = nil
		end
	end
end)
