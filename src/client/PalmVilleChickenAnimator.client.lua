local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MODEL_NAMES = {
	"PalmVilleChicken - Owned",
	"PalmVilleChicken",
	"fullpollo",
}

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

local CONFIG = {
	Cadence = 8.5,
	ThighSwing = math.rad(31),
	KneeBend = math.rad(25),
	WingSwing = math.rad(2),
	HeadNod = math.rad(2),
	PeckAngle = math.rad(24),
	PeckDuration = 0.48,
}

local function findChicken()
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
for _ = 1, 120 do
	model, mesh = findChicken()
	if model and mesh and model:GetAttribute("PalmVilleChickenControllerReady") then
		break
	end
	task.wait(0.5)
end

if not model or not mesh or not model:GetAttribute("PalmVilleChickenControllerReady") then
	warn("[PalmVille Chicken] Client animator could not find the server-controlled imported rig.")
	return
end

local function getBone(name, required)
	local bone = mesh:FindFirstChild(name, true)
	if bone and bone:IsA("Bone") then
		return bone
	end
	if required then
		warn("[PalmVille Chicken] Client rig is missing required bone: " .. name)
	end
	return nil
end

local bones = {}
for _, name in ipairs(BONE_NAMES) do
	bones[name] = getBone(name, name == "CHICKEN_-L-Thigh"
		or name == "CHICKEN_-L-Calf"
		or name == "CHICKEN_-R-Thigh"
		or name == "CHICKEN_-R-Calf")
end

for _, requiredName in ipairs({
	"CHICKEN_-L-Thigh",
	"CHICKEN_-L-Calf",
	"CHICKEN_-R-Thigh",
	"CHICKEN_-R-Calf",
}) do
	if not bones[requiredName] then
		return
	end
end

local base = {}
for name, bone in pairs(bones) do
	if bone then
		base[name] = bone.Transform
	end
end

local phase = 0
local pecking = false
local peckStarted = 0
local nextPeck = os.clock() + 2.5
local alive = true

local function setBone(name, transform)
	local bone = bones[name]
	if bone then
		bone.Transform = transform
	end
end

local connection
connection = RunService.PreSimulation:Connect(function(dt)
	if not alive or not model.Parent or not mesh.Parent then
		connection:Disconnect()
		return
	end

	dt = math.min(dt, 0.05)
	local now = os.clock()
	local walking = model:GetAttribute("PalmVilleChickenIsWalking") == true

	if walking then
		phase += dt * CONFIG.Cadence
	end

	local leftWave = walking and math.sin(phase) or 0
	local rightWave = walking and math.sin(phase + math.pi) or 0

	local leftStride = CONFIG.ThighSwing * leftWave
	local rightStride = CONFIG.ThighSwing * rightWave
	local leftKnee = CONFIG.KneeBend * (walking and math.max(0, math.sin(phase + 0.45)) or 0)
	local rightKnee = CONFIG.KneeBend * (walking and math.max(0, math.sin(phase + math.pi + 0.45)) or 0)

	setBone("CHICKEN_-L-Thigh", base["CHICKEN_-L-Thigh"] * CFrame.Angles(leftStride, 0, 0))
	setBone("CHICKEN_-R-Thigh", base["CHICKEN_-R-Thigh"] * CFrame.Angles(rightStride, 0, 0))
	setBone("CHICKEN_-L-Calf", base["CHICKEN_-L-Calf"] * CFrame.Angles(-leftKnee, 0, 0))
	setBone("CHICKEN_-R-Calf", base["CHICKEN_-R-Calf"] * CFrame.Angles(-rightKnee, 0, 0))

	local walkWing = walking and math.sin(phase * 2) * CONFIG.WingSwing or 0
	local idleWing = math.sin(now * 1.7) * math.rad(0.7)
	local wingMotion = walkWing + idleWing

	if base["CHICKEN_-L-Clavicle"] then
		setBone("CHICKEN_-L-Clavicle",
			base["CHICKEN_-L-Clavicle"] * CFrame.Angles(0, 0, wingMotion))
	end
	if base["CHICKEN_-R-Clavicle"] then
		setBone("CHICKEN_-R-Clavicle",
			base["CHICKEN_-R-Clavicle"] * CFrame.Angles(0, 0, -wingMotion))
	end

	if base["CHICKEN_-Spine"] then
		local lean = walking and math.sin(phase * 2) * math.rad(1.2) or 0
		setBone("CHICKEN_-Spine",
			base["CHICKEN_-Spine"] * CFrame.Angles(lean, 0, 0))
	end

	local neckMotion = walking and math.sin(phase * 2) * CONFIG.HeadNod or 0
	local peckMotion = 0

	if not walking then
		if not pecking and now >= nextPeck then
			pecking = true
			peckStarted = now
		end

		if pecking then
			local alpha = (now - peckStarted) / CONFIG.PeckDuration
			if alpha >= 1 then
				pecking = false
				nextPeck = now + 3 + math.random() * 4
			else
				peckMotion = math.sin(alpha * math.pi) * CONFIG.PeckAngle
			end
		end
	else
		pecking = false
	end

	if base["CHICKEN_-Neck"] then
		setBone("CHICKEN_-Neck",
			base["CHICKEN_-Neck"] * CFrame.Angles(neckMotion + peckMotion, 0, 0))
	end

	if base["CHICKEN_-Tail"] then
		local sway = walking and math.sin(phase) * math.rad(2.5) or math.sin(now * 1.1) * math.rad(1.2)
		setBone("CHICKEN_-Tail",
			base["CHICKEN_-Tail"] * CFrame.Angles(0, 0, sway))
	end
end)

model.Destroying:Connect(function()
	alive = false
	if connection then
		connection:Disconnect()
	end
end)

print("[PalmVille Chicken] Client-side skinned-bone animation active.")
