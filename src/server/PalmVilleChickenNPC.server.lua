local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local OLD_NAME = "Chicken"
local NEW_ATTRIBUTE = "PalmVilleCustomHen"

local oldChicken = Workspace:FindFirstChild(OLD_NAME)
if not oldChicken then
	warn("[PalmVille Chicken] Workspace.Chicken was not found; no replacement was spawned.")
	return
end

if oldChicken:GetAttribute(NEW_ATTRIBUTE) then
	return
end

local oldPivot
if oldChicken:IsA("Model") then
	oldPivot = oldChicken:GetPivot()
elseif oldChicken:IsA("BasePart") then
	oldPivot = oldChicken.CFrame
else
	warn("[PalmVille Chicken] Workspace.Chicken must be a Model or BasePart.")
	return
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = {oldChicken}
rayParams.IgnoreWater = true

local oldPosition = oldPivot.Position
local groundResult = Workspace:Raycast(
	oldPosition + Vector3.new(0, 18, 0),
	Vector3.new(0, -100, 0),
	rayParams
)

local groundY = groundResult and groundResult.Position.Y or (oldPosition.Y - 1.5)
local spawnPosition = Vector3.new(oldPosition.X, groundY + 0.04, oldPosition.Z)
local facing = oldPivot - oldPivot.Position
local rootFrame = CFrame.new(spawnPosition) * facing

local hen = Instance.new("Model")
hen.Name = "Chicken_Rig_Building"
hen:SetAttribute(NEW_ATTRIBUTE, true)
hen:SetAttribute("NPCType", "Hen")
hen.Parent = Workspace

local function makePart(name, size, localFrame, color, shape, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = rootFrame * localFrame
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Shape = shape or Enum.PartType.Block
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = true
	part.Parent = parent or hen
	return part
end

local function ball(name, size, localFrame, color, parent)
	return makePart(name, size, localFrame, color, Enum.PartType.Ball, parent)
end

local function weld(part0, part1, name)
	local joint = Instance.new("WeldConstraint")
	joint.Name = name or (part1.Name .. "Weld")
	joint.Part0 = part0
	joint.Part1 = part1
	joint.Parent = part0
	return joint
end

local function motor(part0, part1, worldJoint, name)
	local joint = Instance.new("Motor6D")
	joint.Name = name
	joint.Part0 = part0
	joint.Part1 = part1
	joint.C0 = part0.CFrame:ToObjectSpace(worldJoint)
	joint.C1 = part1.CFrame:ToObjectSpace(worldJoint)
	joint.Parent = part0
	return joint
end

local root = Instance.new("Part")
root.Name = "HumanoidRootPart"
root.Size = Vector3.new(0.4, 0.4, 0.4)
root.CFrame = rootFrame
root.Transparency = 1
root.Anchored = true
root.CanCollide = false
root.CanTouch = false
root.CanQuery = false
root.CastShadow = false
root.Parent = hen
hen.PrimaryPart = root

local body = ball(
	"Body",
	Vector3.new(1.85, 1.55, 2.55),
	CFrame.new(0, 1.95, 0.05),
	Color3.fromRGB(151, 91, 42)
)
local rootJoint = motor(
	root,
	body,
	rootFrame * CFrame.new(0, 1.95, 0.05),
	"RootJoint"
)

local breast = ball(
	"WarmCreamBreast",
	Vector3.new(1.48, 1.30, 1.25),
	CFrame.new(0, 1.77, -0.72),
	Color3.fromRGB(213, 172, 112)
)
weld(body, breast)

local bellyFeather = ball(
	"SoftBellyFeathers",
	Vector3.new(1.42, 0.72, 1.35),
	CFrame.new(0, 1.46, -0.08),
	Color3.fromRGB(194, 145, 84)
)
weld(body, bellyFeather)

local neck = ball(
	"Neck",
	Vector3.new(0.78, 1.18, 0.78),
	CFrame.new(0, 2.56, -0.83),
	Color3.fromRGB(151, 91, 42)
)
weld(body, neck)

local neckFront = ball(
	"NeckFeathers",
	Vector3.new(0.64, 0.88, 0.20),
	CFrame.new(0, 2.53, -1.12),
	Color3.fromRGB(218, 177, 116)
)
weld(body, neckFront)

local head = ball(
	"Head",
	Vector3.new(0.88, 0.78, 0.86),
	CFrame.new(0, 3.28, -1.05),
	Color3.fromRGB(166, 99, 48)
)
local headJoint = motor(
	body,
	head,
	rootFrame * CFrame.new(0, 2.91, -0.91),
	"NeckJoint"
)

local combRed = Color3.fromRGB(177, 42, 35)
for index, offset in ipairs({
	Vector3.new(-0.19, 3.68, -1.04),
	Vector3.new(0, 3.78, -1.08),
	Vector3.new(0.19, 3.68, -1.04),
}) do
	local lobe = ball(
		"CombLobe" .. index,
		Vector3.new(0.29, 0.36, 0.23),
		CFrame.new(offset),
		combRed
	)
	weld(head, lobe)
end

local beak = makePart(
	"Beak",
	Vector3.new(0.34, 0.24, 0.42),
	CFrame.new(0, 3.13, -1.59) * CFrame.Angles(math.rad(90), 0, 0),
	Color3.fromRGB(224, 151, 48),
	Enum.PartType.Wedge
)
weld(head, beak)

for side = -1, 1, 2 do
	local wattle = ball(
		side == -1 and "LeftWattle" or "RightWattle",
		Vector3.new(0.19, 0.34, 0.17),
		CFrame.new(side * 0.19, 2.91, -1.40),
		Color3.fromRGB(174, 46, 38)
	)
	weld(head, wattle)

	local eyeSocket = ball(
		side == -1 and "LeftEyeSocket" or "RightEyeSocket",
		Vector3.new(0.19, 0.21, 0.12),
		CFrame.new(side * 0.405, 3.34, -1.37),
		Color3.fromRGB(219, 177, 107)
	)
	weld(head, eyeSocket)

	local eye = ball(
		side == -1 and "LeftEye" or "RightEye",
		Vector3.new(0.105, 0.12, 0.075),
		CFrame.new(side * 0.447, 3.35, -1.425),
		Color3.fromRGB(25, 21, 17)
	)
	weld(head, eye)

	local glint = ball(
		"EyeHighlight",
		Vector3.new(0.035, 0.04, 0.025),
		CFrame.new(side * 0.455, 3.385, -1.459),
		Color3.fromRGB(255, 245, 218)
	)
	weld(head, glint)
end

local tailFeatherColors = {
	Color3.fromRGB(119, 69, 35),
	Color3.fromRGB(137, 78, 38),
	Color3.fromRGB(157, 91, 43),
	Color3.fromRGB(124, 72, 39),
	Color3.fromRGB(145, 83, 41),
}
for index = 1, 5 do
	local spread = index - 3
	local feather = ball(
		"TailFeather" .. index,
		Vector3.new(0.30, 0.28, 1.02),
		CFrame.new(spread * 0.19, 2.48 + math.abs(spread) * 0.035, 1.13)
			* CFrame.Angles(math.rad(-24), math.rad(spread * 12), math.rad(spread * 5)),
		tailFeatherColors[index]
	)
	weld(body, feather)
end

local wingJoints = {}
for side = -1, 1, 2 do
	local wing = ball(
		side == -1 and "LeftWing" or "RightWing",
		Vector3.new(0.38, 0.91, 1.36),
		CFrame.new(side * 0.82, 2.02, 0.10)
			* CFrame.Angles(0, math.rad(side * -5), math.rad(side * -7)),
		Color3.fromRGB(184, 119, 58)
	)
	local wingJoint = motor(
		body,
		wing,
		rootFrame * CFrame.new(side * 0.70, 2.27, 0.02),
		side == -1 and "LeftWingJoint" or "RightWingJoint"
	)
	table.insert(wingJoints, {joint = wingJoint, base = wingJoint.C0, side = side})

	for featherIndex = 1, 5 do
		local feather = ball(
			(side == -1 and "LeftWingFeather" or "RightWingFeather") .. featherIndex,
			Vector3.new(0.20, 0.24, 0.64),
			CFrame.new(side * 0.88, 1.77, -0.31 + featherIndex * 0.19)
				* CFrame.Angles(math.rad(-8), 0, math.rad(side * -5)),
			featherIndex % 2 == 0 and Color3.fromRGB(206, 157, 91) or Color3.fromRGB(170, 107, 52)
		)
		weld(wing, feather)
	end
end

local legJoints = {}

local function makeFoot(side, label)
	local x = side * 0.47

	local upper = ball(
		label .. "UpperLeg",
		Vector3.new(0.20, 0.54, 0.20),
		CFrame.new(x, 1.08, 0.18),
		Color3.fromRGB(198, 133, 54)
	)

	local hipWorld = rootFrame * CFrame.new(x, 1.34, 0.18)
	local hip = motor(body, upper, hipWorld, label .. "Hip")
	table.insert(legJoints, {joint = hip, base = hip.C0, kind = "Hip", side = side})

	local lower = makePart(
		label .. "Shin",
		Vector3.new(0.13, 0.49, 0.13),
		CFrame.new(x, 0.55, 0.13) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(211, 145, 60),
		Enum.PartType.Cylinder
	)
	local kneeWorld = rootFrame * CFrame.new(x, 0.81, 0.16)
	local knee = motor(upper, lower, kneeWorld, label .. "Knee")
	table.insert(legJoints, {joint = knee, base = knee.C0, kind = "Knee", side = side})

	local foot = ball(
		label .. "Foot",
		Vector3.new(0.34, 0.14, 0.53),
		CFrame.new(x, 0.14, -0.10),
		Color3.fromRGB(220, 151, 62)
	)
	local ankleWorld = rootFrame * CFrame.new(x, 0.28, 0.02)
	local ankle = motor(lower, foot, ankleWorld, label .. "Ankle")
	table.insert(legJoints, {joint = ankle, base = ankle.C0, kind = "Ankle", side = side})

	for toeIndex = 1, 3 do
		local toeX = (toeIndex - 2) * 0.105
		local toe = ball(
			label .. "Toe" .. toeIndex,
			Vector3.new(0.095, 0.075, 0.34),
			CFrame.new(x + toeX, 0.105, -0.34)
				* CFrame.Angles(0, math.rad((toeIndex - 2) * 13), 0),
			Color3.fromRGB(220, 151, 62)
		)
		weld(foot, toe)

		local claw = ball(
			label .. "Claw" .. toeIndex,
			Vector3.new(0.065, 0.055, 0.12),
			CFrame.new(x + toeX, 0.105, -0.51)
				* CFrame.Angles(0, math.rad((toeIndex - 2) * 13), 0),
			Color3.fromRGB(239, 211, 157)
		)
		weld(foot, claw)
	end

	local rearToe = ball(
		label .. "RearToe",
		Vector3.new(0.085, 0.07, 0.22),
		CFrame.new(x, 0.105, 0.20),
		Color3.fromRGB(220, 151, 62)
	)
	weld(foot, rearToe)
end

makeFoot(-1, "Left")
makeFoot(1, "Right")

local bodyFeatherColors = {
	Color3.fromRGB(178, 113, 54),
	Color3.fromRGB(194, 132, 67),
	Color3.fromRGB(160, 96, 45),
	Color3.fromRGB(207, 151, 83),
}
for side = -1, 1, 2 do
	for index = 1, 4 do
		local feather = ball(
			"BodyFeather_" .. side .. "_" .. index,
			Vector3.new(0.10, 0.27, 0.47),
			CFrame.new(side * 0.90, 1.77, -0.55 + index * 0.37)
				* CFrame.Angles(0, 0, math.rad(side * 14)),
			bodyFeatherColors[index]
		)
		weld(body, feather)
	end
end

hen.PrimaryPart = root
hen.Name = "Chicken"
hen.Parent = Workspace

oldChicken:Destroy()

local currentPosition = spawnPosition
local targetPosition = spawnPosition
local direction = rootFrame.LookVector
local isWalking = false
local nextDecision = os.clock() + 1.5
local walkPhase = 0
local nextPeck = os.clock() + 3
local peckStarted = 0
local peckDuration = 0.42
local pecking = false

local function getGround(x, z)
	local result = Workspace:Raycast(
		Vector3.new(x, groundY + 12, z),
		Vector3.new(0, -35, 0),
		rayParams
	)
	if not result or result.Normal.Y < 0.82 then
		return nil
	end
	return result.Position
end

local function chooseTarget()
	for _ = 1, 10 do
		local angle = math.random() * math.pi * 2
		local distance = math.random(30, 75) / 10
		local x = spawnPosition.X + math.cos(angle) * distance
		local z = spawnPosition.Z + math.sin(angle) * distance
		local ground = getGround(x, z)

		if ground and math.abs(ground.Y - currentPosition.Y) <= 0.45 then
			targetPosition = Vector3.new(x, currentPosition.Y, z)
			isWalking = true
			return
		end
	end

	isWalking = false
	nextDecision = os.clock() + 2
end

local function animate(dt, now)
	local speedBlend = isWalking and 1 or 0
	if isWalking then
		walkPhase += dt * 10.5
	end

	local stride = math.sin(walkPhase) * math.rad(28) * speedBlend
	local leftKneeBend = math.max(0, math.sin(walkPhase + math.pi * 0.35)) * math.rad(30) * speedBlend
	local rightKneeBend = math.max(0, math.sin(walkPhase + math.pi + math.pi * 0.35)) * math.rad(30) * speedBlend

	for _, item in ipairs(legJoints) do
		local joint = item.joint
		if item.kind == "Hip" then
			joint.C0 = item.base * CFrame.Angles(item.side == -1 and stride or -stride, 0, 0)
		elseif item.kind == "Knee" then
			local bend = item.side == -1 and leftKneeBend or rightKneeBend
			joint.C0 = item.base * CFrame.Angles(-bend, 0, 0)
		elseif item.kind == "Ankle" then
			joint.C0 = item.base * CFrame.Angles(-stride * 0.35, 0, 0)
		end
	end

	for _, item in ipairs(wingJoints) do
		local flap = isWalking and math.sin(walkPhase * 2) * math.rad(2.5) or math.sin(now * 1.8) * math.rad(1)
		item.joint.C0 = item.base * CFrame.Angles(0, 0, flap * item.side)
	end

	local peck = 0
	if not isWalking then
		if not pecking and now >= nextPeck then
			pecking = true
			peckStarted = now
		end
		if pecking then
			local alpha = (now - peckStarted) / peckDuration
			if alpha >= 1 then
				pecking = false
				nextPeck = now + math.random(3, 7)
			else
				peck = math.sin(alpha * math.pi) * math.rad(22)
			end
		end
	end
	headJoint.C0 = headJoint.Part0.CFrame:ToObjectSpace(
		rootFrame * CFrame.new(0, 2.91, -0.91)
	) * CFrame.Angles(peck + (isWalking and math.sin(walkPhase * 2) * math.rad(2) or 0), 0, 0)
end

local heartbeat
heartbeat = RunService.Heartbeat:Connect(function(dt)
	if not hen.Parent or not root.Parent then
		heartbeat:Disconnect()
		return
	end

	dt = math.min(dt, 0.05)
	local now = os.clock()

	if isWalking then
		local offset = Vector3.new(
			targetPosition.X - currentPosition.X,
			0,
			targetPosition.Z - currentPosition.Z
		)
		local distance = offset.Magnitude

		if distance <= 0.18 then
			isWalking = false
			nextDecision = now + math.random(15, 40) / 10
		else
			direction = offset.Unit
			local step = math.min(1.8 * dt, distance)
			currentPosition += direction * step

			local obstacle = Workspace:Raycast(
				root.Position + Vector3.new(0, 0.9, 0),
				direction * 1.1,
				rayParams
			)
			if obstacle and obstacle.Instance.CanCollide then
				isWalking = false
				nextDecision = now + 1
			else
				local desired = CFrame.lookAt(currentPosition, currentPosition + direction)
				local rotation = root.CFrame.Rotation:Lerp(desired.Rotation, math.clamp(dt * 9, 0, 1))
				root.CFrame = CFrame.new(currentPosition) * rotation
			end
		end
	elseif now >= nextDecision then
		chooseTarget()
	end

	animate(dt, now)
end)

hen:SetAttribute("ChickenAIReady", true)
print("[PalmVille Chicken] Realistic hen rig spawned with leg, wing, head, idle, peck, and walk animation.")
