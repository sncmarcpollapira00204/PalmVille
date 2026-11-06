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
for _ = 1, 60 do
	model, mesh = findImportedChicken()
	if model and mesh then break end
	task.wait(1)
end

if not model or not mesh then
	warn("[PalmVille Chicken] Imported model not found. Expected a Workspace model containing a MeshPart named 'pollo'.")
	return
end

local requiredBones = {
	"CHICKEN_-L-Thigh",
	"CHICKEN_-L-Calf",
	"CHICKEN_-R-Thigh",
	"CHICKEN_-R-Calf",
}
for _, name in ipairs(requiredBones) do
	local bone = mesh:FindFirstChild(name, true)
	if not bone or not bone:IsA("Bone") then
		warn("[PalmVille Chicken] Required rig bone missing: " .. name)
		return
	end
end

-- Server owns world movement. Bone.Transform is animated by each client,
-- because Bone.Transform itself does not replicate.
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

model:SetAttribute("PalmVilleChickenControllerReady", true)
model:SetAttribute("PalmVilleChickenIsWalking", false)

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
			model:SetAttribute("PalmVilleChickenIsWalking", true)
			return
		end
	end

	walking = false
	model:SetAttribute("PalmVilleChickenIsWalking", false)
	nextDecision = os.clock() + 2
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
			model:SetAttribute("PalmVilleChickenIsWalking", false)
			nextDecision = now + rng:NextNumber(CONFIG.MinPause, CONFIG.MaxPause)
		else
			currentDirection = difference.Unit
			currentPosition += currentDirection * math.min(CONFIG.WalkSpeed * dt, distance)
		end
	elseif now >= nextDecision then
		chooseTarget()
	end

	-- Fixed Y prevents artificial hopping or bobbing.
	currentPosition = Vector3.new(currentPosition.X, fixedY, currentPosition.Z)

	local targetPivot = CFrame.lookAt(
		currentPosition,
		currentPosition + currentDirection
	) * CFrame.Angles(0, math.rad(CONFIG.FaceYawOffset), 0)

	local alpha = math.clamp(dt * CONFIG.TurnSpeed, 0, 1)
	model:PivotTo(model:GetPivot():Lerp(targetPivot, alpha))
end)

print(string.format(
	"[PalmVille Chicken] World movement ready for %s. Fixed-height wandering enabled; client bone animation is separate.",
	model:GetFullName()
))
