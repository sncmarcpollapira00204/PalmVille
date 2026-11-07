local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local TAG = "PalmVilleRooster"
local CROW_SOUND_ID = "rbxassetid://135218417"
local DEFAULT_IDLE_ANIMATION_ID = ""

local CONFIG = {
	MinCrowDelay = 45,
	MaxCrowDelay = 85,
	CrowVolume = 0.55,
	CrowRollOffMinDistance = 8,
	CrowRollOffMaxDistance = 75,
	AnimationFadeTime = 0.25,
}

local active = {}
local registering = setmetatable({}, {__mode = "k"})

local function isRoosterModel(instance)
	if not instance:IsA("Model") then
		return false
	end

	if CollectionService:HasTag(instance, TAG) then
		return true
	end

	local name = string.lower(instance.Name)
	return name == "chicken - loof"
		or name == "rooster"
		or name == "palmvillerooster"
		or string.find(name, "chicken rooster", 1, true) ~= nil
end

local function findSoundParent(model)
	if model.PrimaryPart then
		return model.PrimaryPart
	end

	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("MeshPart") or item:IsA("BasePart") then
			return item
		end
	end

	return nil
end

local function getAnimator(model)
	local controller = model:FindFirstChildWhichIsA("AnimationController", true)
	local humanoid = model:FindFirstChildWhichIsA("Humanoid", true)
	local animator

	if humanoid then
		animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
		return animator
	end

	if not controller then
		controller = Instance.new("AnimationController")
		controller.Name = "PalmVilleRoosterAnimationController"
		controller.Parent = model
	end

	animator = controller:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = controller
	end

	return animator
end

local function getAnimationId(model)
	local id = model:GetAttribute("PalmVilleIdleAnimationId")
	if typeof(id) == "string" and id ~= "" then
		return id
	end
	return DEFAULT_IDLE_ANIMATION_ID
end

local function startIdleAnimation(model, state)
	local animationId = getAnimationId(model)
	if animationId == "" then
		warn("[PalmVille Rooster] Set the PalmVilleIdleAnimationId attribute on " .. model:GetFullName() .. " after publishing the FBX idle clip.")
		return
	end

	if not string.find(animationId, "rbxassetid://", 1, true) then
		animationId = "rbxassetid://" .. animationId
	end

	local animator = getAnimator(model)
	local animation = Instance.new("Animation")
	animation.Name = "PalmVilleRoosterIdle"
	animation.AnimationId = animationId
	animation.Parent = model

	local ok, trackOrError = pcall(function()
		return animator:LoadAnimation(animation)
	end)

	if not ok then
		warn("[PalmVille Rooster] Failed to load idle animation for " .. model.Name .. ": " .. tostring(trackOrError))
		animation:Destroy()
		return
	end

	local track = trackOrError
	track.Looped = true
	track.Priority = Enum.AnimationPriority.Idle
	track:Play(CONFIG.AnimationFadeTime)
	state.animation = animation
	state.track = track
end

local function setupCrowSound(model, state)
	local parent = findSoundParent(model)
	if not parent then
		warn("[PalmVille Rooster] No BasePart found for positional crow sound: " .. model:GetFullName())
		return
	end

	local sound = parent:FindFirstChild("PalmVilleRoosterCrow")
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = "PalmVilleRoosterCrow"
		sound.SoundId = CROW_SOUND_ID
		sound.Volume = CONFIG.CrowVolume
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = CONFIG.CrowRollOffMinDistance
		sound.RollOffMaxDistance = CONFIG.CrowRollOffMaxDistance
		sound.Parent = parent
	end

	state.crowSound = sound
end

local function register(model)
	if active[model] or registering[model] or not model:IsDescendantOf(Workspace) then
		return
	end

	registering[model] = true
	local hasMesh = findSoundParent(model) ~= nil
	if not hasMesh then
		registering[model] = nil
		return
	end

	local state = {
		random = Random.new(),
		nextCrow = os.clock() + Random.new():NextNumber(CONFIG.MinCrowDelay, CONFIG.MaxCrowDelay),
	}
	active[model] = state
	registering[model] = nil
	CollectionService:AddTag(model, TAG)

	startIdleAnimation(model, state)
	setupCrowSound(model, state)
end

local function tryRegister(model)
	if not isRoosterModel(model) or active[model] or registering[model] then
		return
	end

	task.spawn(function()
		for _ = 1, 30 do
			if not model.Parent then
				return
			end
			register(model)
			if active[model] then
				return
			end
			task.wait(0.25)
		end
	end)
end

for _, item in ipairs(Workspace:GetDescendants()) do
	if item:IsA("Model") and isRoosterModel(item) then
		tryRegister(item)
	end
end

Workspace.DescendantAdded:Connect(function(item)
	if item:IsA("Model") then
		tryRegister(item)
	end
end)

CollectionService:GetInstanceAddedSignal(TAG):Connect(tryRegister)

task.spawn(function()
	while true do
		task.wait(1)

		local now = os.clock()
		for model, state in pairs(active) do
			if not model.Parent then
				if state.track then
					state.track:Stop(0)
					state.track:Destroy()
				end
				if state.animation then
					state.animation:Destroy()
				end
				active[model] = nil
			elseif state.crowSound and now >= state.nextCrow then
				if not state.crowSound.IsPlaying then
					state.crowSound:Play()
				end
				state.nextCrow = now + state.random:NextNumber(CONFIG.MinCrowDelay, CONFIG.MaxCrowDelay)
			end
		end
	end
end)
