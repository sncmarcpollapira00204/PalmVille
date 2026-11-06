local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MODEL_NAMES = {
	"PalmVilleChicken - Owned",
	"PalmVilleChicken",
	"fullpollo",
}

local CONFIG = {
	WalkSpeed = 1.55,
	WanderRadius = 9,
	MinWalkDistance = 3,
	MaxWalkDistance = 7,
	MinPause = 2,
	MaxPause = 4.5,
	TurnSpeed = 4.5,
	WalkCadence = 8.5,
	FaceYawOffset = 0,
}

local rng = Random.new()

local function findImportedChicken()
	for _, name in ipairs(MODEL_NAMES) do
		local candidate = Workspace:FindFirstChild(name)
		if candidate and candidate:IsA("Model") then
			local mesh = candidate:FindFirstChild("pollo", true)
			if mesh and mesh:IsA("MeshPart") then
				return candidate, mesh
			end
		end
	end

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("Model") then
			local mesh = descendant:FindFirstChild("pollo", true)
			if mesh and mesh:IsA("MeshPart") then
				return descendant, mesh
			end
		end
	end

	return nil, nil
end

local model, mesh
for attempt = 1, 60 do
	model, mesh = findImportedChicken()
	if model and mesh then break end
	task.wait(1)
end

if not model or not mesh then
	warn("[PalmVille Chicken] Imported model not found. Expected a Workspace model containing a MeshPart named 'pollo'.")
	return
end

local function findBone(name)
	local bone = mesh:FindFirstChild(name, true)
	if bone and bone:IsA("Bone") then
		return bone
	end
	return nil
end

local boneNames = {
	"CHICKEN_-Pelvis",
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

local bones = {}
for _, name in ipairs(boneNames) do
	bones[name] = findBone(name)
	if not bones[name] then
		warn("[PalmVille Chicken] Missing bone: " .. name)
	end
end

local required = {
	"CHICKEN_-L-Thigh",
	"CHICKEN_-L-Calf",
	"CHICKEN_-R-Thigh",
	"CHICKEN_-R-Calf",
}
for _, name in ipairs(required) do
	if not bones[name] then
		warn("[PalmVille Chicken] Required leg bone is missing. Animation controller stopped.")
		return
	end
end

local function saveBase(bone)
	return bone and bone.Transform or CFrame.identity
end

local base = {}
for name, bone in pairs(bones) do
	base[name] = saveBase(bone)
end

-- This is a skinned mesh controlled by Bone.Transform, not a Humanoid rig.
-- Anchor all imported parts so physics cannot make the hen hop or jitter.
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
local fixedY = homePosition.Y
local currentPosition = Vector3.new(homePosition.X, fixedY, homePosition.Z)
local currentDirection = Vector3.new(0, 0, -1)
local targetPosition = currentPosition
local walking = false
local nextDecision = os.clock() + 1.5
local walkPhase = 0
local nextPeck = os.clock() + rng:NextNumber(2, 5)
local peckStart = 0
local peckDuration = 0.48
local pecking = false

local function resetBone(name)
	local bone = bones[name]
	if bone then
		bone.Transform = base[name]
	end
end

local function chooseTarget()
	for _ = 1, 12 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(CONFIG.MinWalkDistance, CONFIG.MaxWalkDistance)
		local candidate = Vector3.new(
			homePosition.X + math.cos(angle) * distance,
			fixedY,
			homePosition.Z + math.sin(angle) * distance
		)

		if (candidate - homePosition).Magnitude <= CONFIG.WanderRadius then
			targetPosition = candidate
			walking = true
			return
		end
	end

	walking = false
	nextDecision = os.clock() + 2
end

local function animate(dt, now)
	if walking then
		walkPhase += dt * CONFIG.WalkCadence
	end

	local leftWave = math.sin(walkPhase)
	local rightWave = math.sin(walkPhase + math.pi)

	local leftStride = math.rad(31) * leftWave
	local rightStride = math.rad(31) * rightWave
	local leftKnee = math.rad(25) * math.max(0, math.sin(walkPhase + 0.45))
	local rightKnee = math.rad(25) * math.max(0, math.sin(walkPhase + math.pi + 0.45))

	bones["CHICKEN_-L-Thigh"].Transform = base["CHICKEN_-L-Thigh"] * CFrame.Angles(leftStride, 0, 0)
	bones["CHICKEN_-R-Thigh"].Transform = base["CHICKEN_-R-Thigh"] * CFrame.Angles(rightStride, 0, 0)
	bones["CHICKEN_-L-Calf"].Transform = base["CHICKEN_-L-Calf"] * CFrame.Angles(-leftKnee, 0, 0)
	bones["CHICKEN_-R-Calf"].Transform = base["CHICKEN_-R-Calf"] * CFrame.Angles(-rightKnee, 0, 0)

	local walkWing = walking and math.sin(walkPhase * 2) * math.rad(2) or 0
	local idleWing = math.sin(now * 1.7) * math.rad(0.7)
	local wingMotion = walkWing + idleWing

	if bones["CHICKEN_-L-Clavicle"] then
		bones["CHICKEN_-L-Clavicle"].Transform = base["CHICKEN_-L-Clavicle"] * CFrame.Angles(0, 0, wingMotion)
	end
	if bones["CHICKEN_-R-Clavicle"] then
		bones["CHICKEN_-R-Clavicle"].Transform = base["CHICKEN_-R-Clavicle"] * CFrame.Angles(0, 0, -wingMotion)
	end

	if bones["CHICKEN_-Spine"] then
		local bodyLean = walking and math.sin(walkPhase * 2) * math.rad(1.2) or 0
		bones["CHICKEN_-Spine"].Transform = base["CHICKEN_-Spine"] * CFrame.Angles(bodyLean, 0, 0)
	end

	local neckPitch = walking and math.sin(walkPhase * 2) * math.rad(2) or 0
	local peckPitch = 0

	if not walking then
		if not pecking and now >= nextPeck then
			pecking = true
			peckStart = now
		end

		if pecking then
			local alpha = (now - peckStart) / peckDuration
			if alpha >= 1 then
				pecking = false
				nextPeck = now + rng:NextNumber(3, 7)
			else
				peckPitch = math.sin(alpha * math.pi) * math.rad(24)
			end
		end
	end

	if bones["CHICKEN_-Neck"] then
		bones["CHICKEN_-Neck"].Transform = base["CHICKEN_-Neck"] * CFrame.Angles(neckPitch + peckPitch, 0, 0)
	end

	if bones["CHICKEN_-Tail"] then
		local tailSway = walking and math.sin(walkPhase) * math.rad(2.5) or math.sin(now * 1.1) * math.rad(1.2)
		bones["CHICKEN_-Tail"].Transform = base["CHICKEN_-Tail"] * CFrame.Angles(0, 0, tailSway)
	end

	if bones["CHICKEN_-Pelvis"] then
		bones["CHICKEN_-Pelvis"].Transform = base["CHICKEN_-Pelvis"]
	end
end

local heartbeat
heartbeat = RunService.Heartbeat:Connect(function(dt)
	if not model.Parent or not mesh.Parent then
		heartbeat:Disconnect()
		return
	end

	dt = math.min(dt, 0.05)
	local now = os.clock()

	if walking then
		local difference = Vector3.new(
			targetPosition.X - currentPosition.X,
			0,
			targetPosition.Z - currentPosition.Z
		)
		local distance = difference.Magnitude

		if distance <= 0.12 then
			walking = false
			nextDecision = now + rng:NextNumber(CONFIG.MinPause, CONFIG.MaxPause)
		else
			currentDirection = difference.Unit
			currentPosition += currentDirection * math.min(CONFIG.WalkSpeed * dt, distance)
		end
	elseif now >= nextDecision then
		chooseTarget()
	end

	-- Keep height fixed: no jumping, bobbing, or ground-height oscillation.
	currentPosition = Vector3.new(currentPosition.X, fixedY, currentPosition.Z)

	local targetPivot = CFrame.lookAt(
		currentPosition,
		currentPosition + currentDirection
	) * CFrame.Angles(0, math.rad(CONFIG.FaceYawOffset), 0)

	local currentPivot = model:GetPivot()
	local alpha = math.clamp(dt * CONFIG.TurnSpeed, 0, 1)
	model:PivotTo(currentPivot:Lerp(targetPivot, alpha))

	animate(dt, now)
end)

print(string.format(
	"[PalmVille Chicken] Controller active on %s. Rigged legs, idle, peck, wings and fixed-height wandering enabled.",
	model:GetFullName()
))
