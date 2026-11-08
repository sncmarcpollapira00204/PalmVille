local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local CONFIG = {
	ButtonPosition = UDim2.fromOffset(215, 12),
	PanelPosition = UDim2.fromOffset(215, 58),
	ButtonSize = 38,
	PanelWidth = 480,
	PanelHeightVertical = 400,
	PanelHeightHorizontal = 330,
	ButtonSpacing = 6,
	ToggleRowHeight = 30,
	ToggleSpacing = 4,
	UIScale = 1,
	OptionLayout = "Auto", -- Auto, Vertical, or Horizontal
	ScreenMargin = 12,
	DragThreshold = 8,
	PositionSaveMaxAttempts = 3,
	PositionSaveRetryDelay = 1.1,
}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
if playerGui:FindFirstChild("FarmVilleGraphicsUI") then
	return
end

local isMobile = UserInputService.TouchEnabled
local currentPreset = "MID"
local presetModified = false
local graphicsToggles = {
	HideBushes = false,
	HideTrees = false,
	HideGrass = false,
	Shadows = true,
	Effects = true,
}
local customizationMode = false
local originals = {}
local managedEffects = {}
local cameraConnection
local cameraDescendantConnection
local activeDrag
local panelOpen = false
local panelBaseScale = 1
local panelAnimationId = 0
local panelTweens = {}
local saveTicket = 0
local buttonNormalized
local panelNormalized
local buttonPositionInitialized = false
local panelPositionInitialized = false
local layoutInitialized = false
local buttonUserMoved = false
local panelUserMoved = false
local settingsRemote
local micButton
local micConnections = {}

local VISIBILITY_TAGS = {
	HideBushes = "GraphicsBush",
	HideTrees = "GraphicsTree",
	HideGrass = "GraphicsGrass",
}
local VISIBILITY_TAG_LIST = {"GraphicsBush", "GraphicsTree", "GraphicsGrass"}

local QUALITY_PROFILES = {
	-- Lightweight cool daylight with a restrained blue atmosphere.
	LOW = {
		-- Clear tropical afternoon with inexpensive distance haze and readable shadows.
		Technology = Enum.Technology.ShadowMap,
		ClockTime = 15.5,
		Brightness = 2.15,
		Ambient = Color3.fromRGB(135, 145, 158),
		OutdoorAmbient = Color3.fromRGB(164, 178, 194),
		EnvironmentDiffuseScale = 0.48,
		EnvironmentSpecularScale = 0.28,
		ExposureCompensation = 0.02,
		ShadowSoftness = 0.38,
		Atmosphere = {Density = 0.14, Offset = 0.08, Color = Color3.fromRGB(198, 222, 242), Decay = Color3.fromRGB(133, 163, 190), Haze = 0.65, Glare = 0.015},
		Color = {Brightness = 0.015, Contrast = 0.025, Saturation = 0.045, TintColor = Color3.fromRGB(250, 250, 246)},
		Bloom = {Intensity = 0, Size = 12, Threshold = 2},
		SunRays = {Intensity = 0, Spread = 0.8},
		Clouds = false,
	},
	-- Recommended PalmVille look: cinematic blue haze, realistic depth, soft natural daylight.
	MID = {
		-- PalmVille's recommended tropical cinematic preset.
		Technology = Enum.Technology.Future,
		ClockTime = 15.5,
		Brightness = 2.1,
		Ambient = Color3.fromRGB(126, 138, 153),
		OutdoorAmbient = Color3.fromRGB(159, 176, 194),
		EnvironmentDiffuseScale = 0.72,
		EnvironmentSpecularScale = 0.58,
		ExposureCompensation = 0.015,
		ShadowSoftness = 0.42,
		Atmosphere = {Density = 0.20, Offset = 0.06, Color = Color3.fromRGB(191, 218, 241), Decay = Color3.fromRGB(111, 145, 177), Haze = 1.05, Glare = 0.035},
		Color = {Brightness = 0.012, Contrast = 0.045, Saturation = 0.035, TintColor = Color3.fromRGB(248, 250, 255)},
		Bloom = {Intensity = 0.12, Size = 22, Threshold = 1.65},
		SunRays = {Intensity = 0.045, Spread = 0.82},
		Clouds = true,
	},
	-- HD preset: sharper contrast, richer reflections and more detailed atmospheric depth.
	-- Still uses ShadowMap to avoid the heavier Future renderer.
	HIGH = {
		-- Maximum visual fidelity; Future lighting and richer reflections.
		Technology = Enum.Technology.Future,
		ClockTime = 15.5,
		Brightness = 2.12,
		Ambient = Color3.fromRGB(119, 132, 150),
		OutdoorAmbient = Color3.fromRGB(163, 181, 201),
		EnvironmentDiffuseScale = 0.9,
		EnvironmentSpecularScale = 0.85,
		ExposureCompensation = 0.025,
		ShadowSoftness = 0.48,
		Atmosphere = {Density = 0.22, Offset = 0.06, Color = Color3.fromRGB(188, 216, 240), Decay = Color3.fromRGB(102, 137, 170), Haze = 1.25, Glare = 0.05},
		Color = {Brightness = 0.015, Contrast = 0.055, Saturation = 0.045, TintColor = Color3.fromRGB(250, 250, 255)},
		Bloom = {Intensity = 0.16, Size = 24, Threshold = 1.6},
		SunRays = {Intensity = 0.06, Spread = 0.84},
		Clouds = true,
	},
}

local function make(className, properties, parent)
	local object = Instance.new(className)
	for property, value in pairs(properties or {}) do
		object[property] = value
	end
	object.Parent = parent
	return object
end

local function addCorner(object, radius)
	make("UICorner", {CornerRadius = UDim.new(0, radius)}, object)
end

local function addStroke(object, color, transparency, thickness)
	return make("UIStroke", {
		Color = color,
		Transparency = transparency,
		Thickness = thickness,
	}, object)
end

local function isOptionalEffect(object)
	return object:IsA("ParticleEmitter")
		or object:IsA("Trail")
		or object:IsA("Beam")
		or object:IsA("Fire")
		or object:IsA("Smoke")
		or object:IsA("Sparkles")
end

local function isSupportedGraphicsObject(object)
	return object:IsA("BasePart")
		or object:IsA("Light")
		or object:IsA("PostEffect")
		or isOptionalEffect(object)
		or object:IsA("Clouds")
		or object:IsA("Atmosphere")
end

local function hasTagAncestor(object, tag)
	local current = object
	while current and current ~= Workspace do
		if CollectionService:HasTag(current, tag) then
			return true
		end
		current = current.Parent
	end
	return false
end

local function hasVisibilityTag(object)
	for _, tag in ipairs(VISIBILITY_TAG_LIST) do
		if hasTagAncestor(object, tag) then
			return true
		end
	end
	return false
end

local function remember(object)
	if originals[object] or managedEffects[object] or not isSupportedGraphicsObject(object) then
		return
	end

	local saved = {}
	if object:IsA("BasePart") then
		saved.CastShadow = object.CastShadow
		saved.LocalTransparencyModifier = object.LocalTransparencyModifier
	elseif object:IsA("Light") then
		saved.Shadows = object.Shadows
	elseif object:IsA("PostEffect") or isOptionalEffect(object) or object:IsA("Clouds") then
		saved.Enabled = object.Enabled
	elseif object:IsA("Atmosphere") then
		saved.Density = object.Density
		saved.Offset = object.Offset
		saved.Color = object.Color
		saved.Decay = object.Decay
		saved.Haze = object.Haze
		saved.Glare = object.Glare
	end
	originals[object] = saved
end

local function forgetAfterRemoval(object)
	if not object:IsDescendantOf(Workspace) and not object:IsDescendantOf(Lighting) then
		originals[object] = nil
	end
end

local function forgetRemoved(object)
	task.defer(forgetAfterRemoval, object)
end

local function applyObject(object)
	if not object.Parent or managedEffects[object] then
		return
	end
	remember(object)
	local saved = originals[object]
	if not saved then
		return
	end
	local profile = QUALITY_PROFILES[currentPreset]

	local hideObject = (graphicsToggles.HideBushes and hasTagAncestor(object, VISIBILITY_TAGS.HideBushes))
		or (graphicsToggles.HideTrees and hasTagAncestor(object, VISIBILITY_TAGS.HideTrees))
		or (graphicsToggles.HideGrass and hasTagAncestor(object, VISIBILITY_TAGS.HideGrass))

	if saved.CastShadow ~= nil then
		object.CastShadow = graphicsToggles.Shadows and saved.CastShadow or false
	end
	if saved.Shadows ~= nil then
		object.Shadows = graphicsToggles.Shadows and saved.Shadows or false
	end
	if saved.LocalTransparencyModifier ~= nil then
		object.LocalTransparencyModifier = hideObject and 1 or saved.LocalTransparencyModifier
	end
	if object:IsA("Clouds") then
		object.Enabled = profile.Clouds and graphicsToggles.Effects
	elseif saved.Enabled ~= nil then
		local disable = not graphicsToggles.Effects
		if currentPreset == "LOW" then
			disable = disable or object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam")
				or object:IsA("Fire") or object:IsA("Smoke") or object:IsA("Sparkles")
		elseif currentPreset == "MID" then
			disable = disable or object:IsA("DepthOfFieldEffect")
		end
		if disable then
			object.Enabled = false
		else
			object.Enabled = saved.Enabled
		end
	end
	if saved.Density ~= nil then
		-- Only the single managed PalmVille atmosphere should contribute haze.
		-- Extra Atmosphere instances can stack density and create uneven, overly dark fog.
		if managedEffects[object] then
			local atmosphere = profile.Atmosphere
			if graphicsToggles.Effects then
				object.Density = atmosphere.Density
				object.Offset = atmosphere.Offset
				object.Color = atmosphere.Color
				object.Decay = atmosphere.Decay
				object.Haze = atmosphere.Haze
				object.Glare = atmosphere.Glare
			else
				object.Density = 0
				object.Haze = 0
				object.Glare = 0
			end
		else
			object.Density = 0
			object.Haze = 0
			object.Glare = 0
		end
	end
end

local function applyLightingProfile()
	local profile = QUALITY_PROFILES[currentPreset]
	pcall(function()
		Lighting.Technology = profile.Technology
	end)
	Lighting.Brightness = profile.Brightness
	Lighting.ClockTime = profile.ClockTime
	Lighting.Ambient = profile.Ambient
	Lighting.OutdoorAmbient = profile.OutdoorAmbient
	Lighting.EnvironmentDiffuseScale = profile.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = profile.EnvironmentSpecularScale
	Lighting.ExposureCompensation = profile.ExposureCompensation
	Lighting.GlobalShadows = graphicsToggles.Shadows
	pcall(function()
		Lighting.ShadowSoftness = graphicsToggles.Shadows and profile.ShadowSoftness or 0
	end)

	local function ensureEffect(className, name)
		local effect = Lighting:FindFirstChild(name)
		if effect and not effect:IsA(className) then
			effect = nil
		end
		if not effect then
			for _, candidate in ipairs(Lighting:GetChildren()) do
				if candidate:IsA(className) then
					effect = candidate
					break
				end
			end
		end
		if not effect then
			effect = Instance.new(className)
			effect.Name = name
			effect.Parent = Lighting
		end
		managedEffects[effect] = true
		return effect
	end

	local atmosphere = ensureEffect("Atmosphere", "PalmVilleRealisticAtmosphere")
	for property, value in pairs(profile.Atmosphere) do atmosphere[property] = value end
	local color = ensureEffect("ColorCorrectionEffect", "PalmVilleRealisticColor")
	for property, value in pairs(profile.Color) do color[property] = value end
	local bloom = ensureEffect("BloomEffect", "PalmVilleRealisticBloom")
	for property, value in pairs(profile.Bloom) do bloom[property] = value end
	local rays = ensureEffect("SunRaysEffect", "PalmVilleRealisticSunRays")
	for property, value in pairs(profile.SunRays) do rays[property] = value end

	-- Keep lightweight atmosphere and color grading on LOW; heavier effects stay off.
	atmosphere.Enabled = graphicsToggles.Effects
	color.Enabled = graphicsToggles.Effects
	bloom.Enabled = graphicsToggles.Effects and currentPreset ~= "LOW"
	rays.Enabled = graphicsToggles.Effects and currentPreset ~= "LOW"
end

for _, object in ipairs(Lighting:GetDescendants()) do remember(object) end
for _, object in ipairs(Workspace:GetDescendants()) do remember(object) end
local originalGlobalShadows = Lighting.GlobalShadows
graphicsToggles.Shadows = originalGlobalShadows

local function applyGraphicsSettings()
	applyLightingProfile()
	for object in pairs(originals) do
		applyObject(object)
	end
end

local FOLIAGE_LOD = {
	GrassShadow = false,
	TreeBushShadowDistance = 115,
	UpdateInterval = 0.8,
}

local function eachTaggedPart(tag, callback)
	for _, root in ipairs(CollectionService:GetTagged(tag)) do
		if root:IsA("BasePart") then
			callback(root)
		end
		for _, descendant in ipairs(root:GetDescendants()) do
			if descendant:IsA("BasePart") then
				callback(descendant)
			end
		end
	end
end

local function updateFoliageShadowLod()
	if currentPreset ~= "LOW" then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local cameraPosition = camera.CFrame.Position
	local function updatePart(part, tag)
		remember(part)
		local saved = originals[part]
		if not saved or saved.CastShadow == nil then
			return
		end
		local reduceShadow = tag == "GraphicsGrass"
		if not reduceShadow then
			reduceShadow = (part.Position - cameraPosition).Magnitude > FOLIAGE_LOD.TreeBushShadowDistance
		end
		part.CastShadow = graphicsToggles.Shadows and saved.CastShadow and not reduceShadow or false
	end
	for _, tag in ipairs({"GraphicsGrass", "GraphicsBush", "GraphicsTree"}) do
		eachTaggedPart(tag, function(part)
			updatePart(part, tag)
		end)
	end
end

task.spawn(function()
	while script.Parent do
		if currentPreset == "LOW" then
			updateFoliageShadowLod()
		end
		task.wait(FOLIAGE_LOD.UpdateInterval)
	end
end)

local function applyPreset(preset)
	currentPreset = QUALITY_PROFILES[preset] and preset or "MID"
	-- HIGH remains selectable on mobile; users can lower it if performance drops.
	presetModified = false
	graphicsToggles.Shadows = originalGlobalShadows
	-- The LOW preset keeps subtle atmosphere/color grading while applyObject
	-- removes costly particles, trails, beams, and other optional effects.
	graphicsToggles.Effects = true
	applyGraphicsSettings()
end

local function handleAdded(object)
	if isSupportedGraphicsObject(object) then
		applyObject(object)
	elseif hasVisibilityTag(object) then
		for _, descendant in ipairs(object:GetDescendants()) do
			applyObject(descendant)
		end
	end
end

Workspace.DescendantAdded:Connect(handleAdded)
Lighting.DescendantAdded:Connect(handleAdded)
Workspace.DescendantRemoving:Connect(forgetRemoved)
Lighting.DescendantRemoving:Connect(forgetRemoved)
for _, tag in ipairs(VISIBILITY_TAG_LIST) do
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(root)
		for _, descendant in ipairs(root:GetDescendants()) do
			applyObject(descendant)
		end
	end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(root)
		for _, descendant in ipairs(root:GetDescendants()) do
			applyObject(descendant)
		end
	end)
end

local gui = make("ScreenGui", {
	Name = "FarmVilleGraphicsUI",
	ResetOnSpawn = false,
	DisplayOrder = 50,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	ClipToDeviceSafeArea = true,
}, playerGui)

local openButton = make("TextButton", {
	Name = "GraphicsButton",
	Size = UDim2.fromOffset(CONFIG.ButtonSize, CONFIG.ButtonSize),
	Position = CONFIG.ButtonPosition,
	BackgroundColor3 = Color3.fromRGB(18, 18, 20),
	BackgroundTransparency = 0.08,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	Active = true,
}, gui)
addCorner(openButton, 12)
local buttonStroke = addStroke(openButton, Color3.fromRGB(98, 98, 106), 0.38, 1)
local buttonScale = make("UIScale", {Scale = 1}, openButton)

	local gearTeeth = {
		{0, -10, 0}, {7, -7, 45}, {10, 0, 90}, {7, 7, 135},
		{0, 10, 0}, {-7, 7, 45}, {-10, 0, 90}, {-7, -7, 135},
	}
for index, tooth in ipairs(gearTeeth) do
	local spoke = make("Frame", {
		Name = "GearTooth" .. tostring(index),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, tooth[1], 0.5, tooth[2]),
		Size = UDim2.fromOffset(4, 7),
		Rotation = tooth[3],
		BackgroundColor3 = Color3.fromRGB(244, 244, 246),
		BorderSizePixel = 0,
		Active = false,
	}, openButton)
	addCorner(spoke, 2)
end
local gearCenter = make("Frame", {
	Name = "GearCenter",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(10, 10),
	BackgroundColor3 = Color3.fromRGB(18, 18, 20),
	BorderSizePixel = 0,
	Active = false,
}, openButton)
addCorner(gearCenter, 6)
addStroke(gearCenter, Color3.fromRGB(244, 244, 246), 0, 1.5)

local panel = make("Frame", {
	Name = "GraphicsPanel",
	Size = UDim2.fromOffset(CONFIG.PanelWidth, CONFIG.PanelHeightVertical),
	Position = CONFIG.PanelPosition,
	BackgroundColor3 = Color3.fromRGB(16, 16, 18),
	BackgroundTransparency = 0.08,
	BorderSizePixel = 0,
	Visible = false,
	ClipsDescendants = false,
}, gui)
addCorner(panel, 14)
local panelStroke = addStroke(panel, Color3.fromRGB(74, 74, 82), 0.3, 1)
local panelScale = make("UIScale", {Scale = 1}, panel)

local header = make("Frame", {
	Name = "Header",
	Size = UDim2.new(1, 0, 0, 52),
	BackgroundTransparency = 1,
	Active = true,
}, panel)
local title = make("TextLabel", {
	Name = "Title",
	Position = UDim2.fromOffset(18, 15),
	Size = UDim2.new(1, -68, 0, 22),
	BackgroundTransparency = 1,
	Text = "GRAPHICS",
	TextColor3 = Color3.fromRGB(245, 245, 247),
	Font = Enum.Font.GothamSemibold,
	TextSize = 16,
	TextXAlignment = Enum.TextXAlignment.Left,
}, header)
-- Keep the header compact with a single title.
local closeButton = make("TextButton", {
	Name = "CloseButton",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 12),
	Size = UDim2.fromOffset(30, 30),
	BackgroundColor3 = Color3.fromRGB(36, 36, 40),
	BorderSizePixel = 0,
	Text = "×",
	TextColor3 = Color3.fromRGB(225, 225, 229),
	Font = Enum.Font.Gotham,
	TextSize = 21,
	AutoButtonColor = false,
}, header)
addCorner(closeButton, 9)

local qualityLabel = make("TextLabel", {
	Name = "QualityLabel",
	Position = UDim2.fromOffset(16, 62),
	Size = UDim2.new(0, 140, 0, 14),
	BackgroundTransparency = 1,
	Text = "QUALITY",
	TextColor3 = Color3.fromRGB(156, 156, 164),
	Font = Enum.Font.GothamBold,
	TextSize = 9,
	TextXAlignment = Enum.TextXAlignment.Left,
}, panel)
local options = make("Frame", {
	Name = "QualityOptions",
	Position = UDim2.fromOffset(16, 83),
	Size = UDim2.new(0, 148, 0, 34),
	BackgroundTransparency = 1,
}, panel)
local optionLayout = make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Left,
	VerticalAlignment = Enum.VerticalAlignment.Top,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, CONFIG.ButtonSpacing),
}, options)

local presetButtons = {}
local updatePresetSelection
for index, key in ipairs({"LOW", "MID", "HIGH"}) do
	local button = make("TextButton", {
		Name = key .. "Preset",
		LayoutOrder = index,
		Size = UDim2.new(1 / 3, -4, 1, 0),
		BackgroundColor3 = Color3.fromRGB(29, 29, 33),
		BorderSizePixel = 0,
		Text = key,
		TextColor3 = Color3.fromRGB(236, 236, 239),
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		AutoButtonColor = false,
	}, options)
	addCorner(button, 7)
	local stroke = addStroke(button, Color3.fromRGB(74, 74, 82), 0.55, 1)
	presetButtons[key] = {button = button, stroke = stroke}
end

local optionsTitle = make("TextLabel", {
	Name = "OptionsTitle",
	Position = UDim2.fromOffset(182, 62),
	Size = UDim2.new(1, -198, 0, 14),
	BackgroundTransparency = 1,
	Text = "OPTIONS",
	TextColor3 = Color3.fromRGB(156, 156, 164),
	Font = Enum.Font.GothamBold,
	TextSize = 9,
	TextXAlignment = Enum.TextXAlignment.Left,
}, panel)
local toggleRows = make("Frame", {
	Name = "ToggleRows",
	Position = UDim2.fromOffset(182, 83),
	Size = UDim2.new(1, -198, 0, CONFIG.ToggleRowHeight * 5 + CONFIG.ToggleSpacing * 4),
	BackgroundTransparency = 1,
}, panel)
local toggleLayout = make("UIListLayout", {
	FillDirection = Enum.FillDirection.Vertical,
	HorizontalAlignment = Enum.HorizontalAlignment.Left,
	VerticalAlignment = Enum.VerticalAlignment.Top,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, CONFIG.ToggleSpacing),
}, toggleRows)
local toggleEntries = {}
local toggleInfo = {
	{key = "HideBushes", label = "Hide Bushes"},
	{key = "HideTrees", label = "Hide Trees"},
	{key = "HideGrass", label = "Hide Grass"},
	{key = "Shadows", label = "Shadows"},
	{key = "Effects", label = "Effects"},
}

local function updateToggleVisuals()
	for key, entry in pairs(toggleEntries) do
		local enabled = graphicsToggles[key]
		entry.track.BackgroundColor3 = enabled and Color3.fromRGB(224, 224, 230) or Color3.fromRGB(65, 65, 72)
		entry.thumb.BackgroundColor3 = enabled and Color3.fromRGB(18, 18, 20) or Color3.fromRGB(244, 244, 246)
		entry.thumb.Position = enabled and UDim2.new(1, -9, 0.5, 0) or UDim2.new(0, 9, 0.5, 0)
	end
end

for index, info in ipairs(toggleInfo) do
	local row = make("TextButton", {
		Name = info.key .. "Toggle",
		LayoutOrder = index,
		Size = UDim2.new(1, 0, 0, CONFIG.ToggleRowHeight),
		BackgroundColor3 = Color3.fromRGB(29, 29, 33),
		BorderSizePixel = 0,
		Text = info.label,
		TextColor3 = Color3.fromRGB(236, 236, 239),
		Font = Enum.Font.GothamMedium,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutoButtonColor = false,
	}, toggleRows)
	addCorner(row, 7)
	make("UIPadding", {PaddingLeft = UDim.new(0, 10)}, row)
	local track = make("Frame", {
		Name = "SwitchTrack",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -9, 0.5, 0),
		Size = UDim2.fromOffset(32, 18),
		BackgroundColor3 = Color3.fromRGB(65, 65, 72),
		BorderSizePixel = 0,
		Active = false,
	}, row)
	addCorner(track, 9)
	local thumb = make("Frame", {
		Name = "SwitchThumb",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 9, 0.5, 0),
		Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = Color3.fromRGB(244, 244, 246),
		BorderSizePixel = 0,
		Active = false,
	}, track)
	addCorner(thumb, 6)
	toggleEntries[info.key] = {row = row, track = track, thumb = thumb}
	row.Activated:Connect(function()
		graphicsToggles[info.key] = not graphicsToggles[info.key]
		presetModified = true
		applyGraphicsSettings()
		if updatePresetSelection then
			updatePresetSelection()
		end
		updateToggleVisuals()
	end)
end
local customizeButton = make("TextButton", {
	Name = "CustomizeButton",
	Position = UDim2.new(0, 16, 1, -50),
	Size = UDim2.new(1, -32, 0, 36),
	BackgroundColor3 = Color3.fromRGB(38, 38, 43),
	BorderSizePixel = 0,
	Text = "MOVE UI",
	TextColor3 = Color3.fromRGB(240, 240, 243),
	Font = Enum.Font.GothamSemibold,
	TextSize = 11,
	AutoButtonColor = false,
}, panel)
addCorner(customizeButton, 9)
addStroke(customizeButton, Color3.fromRGB(94, 94, 102), 0.4, 1)
local resetButton = make("TextButton", {
	Name = "ResetPositionButton",
	Position = UDim2.new(0, 16, 1, -50),
	Size = UDim2.new(1, -112, 0, 36),
	BackgroundColor3 = Color3.fromRGB(36, 36, 40),
	BorderSizePixel = 0,
	Text = "RESET",
	TextColor3 = Color3.fromRGB(220, 220, 226),
	Font = Enum.Font.GothamMedium,
	TextSize = 10,
	Visible = false,
	AutoButtonColor = false,
}, panel)
addCorner(resetButton, 9)
local doneButton = make("TextButton", {
	Name = "DoneButton",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 1, -50),
	Size = UDim2.fromOffset(78, 36),
	BackgroundColor3 = Color3.fromRGB(222, 222, 228),
	BorderSizePixel = 0,
	Text = "DONE",
	TextColor3 = Color3.fromRGB(18, 18, 20),
	Font = Enum.Font.GothamSemibold,
	TextSize = 11,
	Visible = false,
	AutoButtonColor = false,
}, panel)
addCorner(doneButton, 9)

updatePresetSelection = function()
	for key, entry in pairs(presetButtons) do
		local active = not presetModified and key == currentPreset
		entry.button.BackgroundColor3 = active and Color3.fromRGB(230, 230, 234) or Color3.fromRGB(29, 29, 33)
		entry.button.TextColor3 = active and Color3.fromRGB(18, 18, 20) or Color3.fromRGB(236, 236, 239)
		entry.stroke.Color = active and Color3.fromRGB(230, 230, 234) or Color3.fromRGB(74, 74, 82)
		entry.stroke.Transparency = active and 0.08 or 0.55
	end
end

for key, entry in pairs(presetButtons) do
	entry.button.Activated:Connect(function()
		applyPreset(key)
		updatePresetSelection()
		updateToggleVisuals()
	end)
end

local function viewportSize()
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	if viewport.X <= 0 or viewport.Y <= 0 then
		viewport = Vector2.new(1280, 720)
	end
	local topLeftInset, bottomRightInset = GuiService:GetGuiInset()
	return Vector2.new(
		math.max(1, viewport.X - topLeftInset.X - bottomRightInset.X),
		math.max(1, viewport.Y - topLeftInset.Y - bottomRightInset.Y)
	)
end

local function clampPosition(object, x, y)
	local viewport = viewportSize()
	local size = object.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		local scale = object == panel and panelScale.Scale or buttonScale.Scale
		size = Vector2.new(object.Size.X.Offset * scale, object.Size.Y.Offset * scale)
	end
	local margin = CONFIG.ScreenMargin
	local maxX = math.max(margin, viewport.X - size.X - margin)
	local maxY = math.max(margin, viewport.Y - size.Y - margin)
	x = math.clamp(x, margin, maxX)
	y = math.clamp(y, margin, maxY)
	object.Position = UDim2.fromOffset(x, y)
end

local function applyNormalizedPosition(object, normalized)
	local viewport = viewportSize()
	local size = object.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		local scale = object == panel and panelScale.Scale or buttonScale.Scale
		size = Vector2.new(object.Size.X.Offset * scale, object.Size.Y.Offset * scale)
	end
	local rangeX = math.max(0, viewport.X - size.X - CONFIG.ScreenMargin * 2)
	local rangeY = math.max(0, viewport.Y - size.Y - CONFIG.ScreenMargin * 2)
	clampPosition(object, CONFIG.ScreenMargin + rangeX * normalized.x, CONFIG.ScreenMargin + rangeY * normalized.y)
end

local function saveablePosition(object)
	local viewport = viewportSize()
	local size = object.AbsoluteSize
	local maxX = math.max(1, viewport.X - size.X - CONFIG.ScreenMargin * 2)
	local maxY = math.max(1, viewport.Y - size.Y - CONFIG.ScreenMargin * 2)
	return {
		x = math.clamp((object.Position.X.Offset - CONFIG.ScreenMargin) / maxX, 0, 1),
		y = math.clamp((object.Position.Y.Offset - CONFIG.ScreenMargin) / maxY, 0, 1),
	}
end

local function persistPositions()
	saveTicket += 1
	local ticket = saveTicket

	local function save(attempt)
		if ticket ~= saveTicket then
			return
		end

		local remote = settingsRemote
		if not remote or not remote.Parent then
			remote = ReplicatedStorage:WaitForChild("FarmVilleGraphicsSettingsRemote", 5)
		end
		if not remote or not remote:IsA("RemoteFunction") then
			if attempt < CONFIG.PositionSaveMaxAttempts then
				task.delay(CONFIG.PositionSaveRetryDelay, function()
					save(attempt + 1)
				end)
			end
			return
		end
		settingsRemote = remote

		local payload = {
			button = buttonNormalized or saveablePosition(openButton),
			panel = panelNormalized or saveablePosition(panel),
		}
		local callSucceeded, response = pcall(function()
			return remote:InvokeServer("Save", payload)
		end)
		if ticket ~= saveTicket then
			return
		end
		if callSucceeded and (response == true or (typeof(response) == "table" and response.ok == true)) then
			return
		end
		if callSucceeded and typeof(response) == "table" and response.disabled then
			return
		end
		if attempt >= CONFIG.PositionSaveMaxAttempts then
			return
		end

		local retryDelay = CONFIG.PositionSaveRetryDelay
		if callSucceeded and typeof(response) == "table" and typeof(response.retryAfter) == "number" then
			retryDelay = math.clamp(response.retryAfter + 0.05, 0.2, 5)
		end
		task.delay(retryDelay, function()
			save(attempt + 1)
		end)
	end

	task.defer(save, 1)
end

local function refreshPresetLayout()
	local camera = Workspace.CurrentCamera
	if not camera or camera.ViewportSize.X < 200 or camera.ViewportSize.Y < 160 then
		return
	end
	local topLeftInset, bottomRightInset = GuiService:GetGuiInset()
	if topLeftInset.X + bottomRightInset.X >= camera.ViewportSize.X
		or topLeftInset.Y + bottomRightInset.Y >= camera.ViewportSize.Y then
		return
	end
	local viewport = viewportSize()
	local availableWidth = math.max(220, viewport.X - CONFIG.ScreenMargin * 2)
	local availableHeight = math.max(190, viewport.Y - CONFIG.ScreenMargin * 2)
	local scale = math.clamp(math.min(availableWidth / CONFIG.PanelWidth, availableHeight / CONFIG.PanelHeightVertical), 0.72, 1)
	scale = math.clamp(scale * CONFIG.UIScale, 0.65, 1.1)
	local vertical = CONFIG.OptionLayout == "Vertical"
		or (CONFIG.OptionLayout == "Auto" and viewport.X < 820)
	local baseHeight = vertical and CONFIG.PanelHeightVertical or CONFIG.PanelHeightHorizontal
	local targetWidth = math.min(CONFIG.PanelWidth * scale, math.max(220, viewport.X - CONFIG.ScreenMargin * 2))
	local targetHeight = math.min(baseHeight * scale, math.max(190, viewport.Y - CONFIG.ScreenMargin * 2))
	local baseWidth = targetWidth / scale

	buttonScale.Scale = UserInputService.TouchEnabled and math.max(scale, 0.95) or scale
	panelBaseScale = scale
	panelScale.Scale = scale
	panel.Size = UDim2.fromOffset(baseWidth, targetHeight / scale)
	optionLayout.FillDirection = Enum.FillDirection.Horizontal
	optionLayout.Padding = UDim.new(0, CONFIG.ButtonSpacing)
	if vertical then
		qualityLabel.Position = UDim2.fromOffset(16, 61)
		options.Position = UDim2.fromOffset(16, 82)
		options.Size = UDim2.new(1, -32, 0, 34)
		optionsTitle.Position = UDim2.fromOffset(16, 126)
		toggleRows.Position = UDim2.fromOffset(16, 145)
		toggleRows.Size = UDim2.new(1, -32, 0, CONFIG.ToggleRowHeight * 5 + CONFIG.ToggleSpacing * 4)
	else
		qualityLabel.Position = UDim2.fromOffset(16, 62)
		options.Position = UDim2.fromOffset(16, 83)
		options.Size = UDim2.new(0, 148, 0, 34)
		optionsTitle.Position = UDim2.fromOffset(182, 62)
		toggleRows.Position = UDim2.fromOffset(182, 83)
		toggleRows.Size = UDim2.new(1, -198, 0, CONFIG.ToggleRowHeight * 5 + CONFIG.ToggleSpacing * 4)
	end
	for _, entry in pairs(presetButtons) do
		entry.button.Size = UDim2.new(1 / 3, -4, 1, 0)
	end
	local footerY = panel.Size.Y.Offset - 50
	customizeButton.Position = UDim2.new(0, 16, 0, footerY)
	customizeButton.Size = UDim2.new(1, -32, 0, 36)
	resetButton.Position = UDim2.new(0, 16, 0, footerY)
	resetButton.Size = UDim2.new(1, -112, 0, 36)
	doneButton.Position = UDim2.new(1, -16, 0, footerY)
	
	if buttonNormalized then
		applyNormalizedPosition(openButton, buttonNormalized)
		buttonPositionInitialized = true
	elseif not buttonPositionInitialized then
		clampPosition(openButton, CONFIG.ButtonPosition.X.Offset, CONFIG.ButtonPosition.Y.Offset)
		buttonPositionInitialized = true
	else
		clampPosition(openButton, openButton.Position.X.Offset, openButton.Position.Y.Offset)
	end
	if panelNormalized then
		applyNormalizedPosition(panel, panelNormalized)
		panelPositionInitialized = true
	elseif not panelPositionInitialized then
		clampPosition(panel, CONFIG.PanelPosition.X.Offset, CONFIG.PanelPosition.Y.Offset)
		panelPositionInitialized = true
	else
		clampPosition(panel, panel.Position.X.Offset, panel.Position.Y.Offset)
	end
	layoutInitialized = true
end

local function watchCamera(camera)
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end
	if cameraDescendantConnection then
		cameraDescendantConnection:Disconnect()
		cameraDescendantConnection = nil
	end
	if camera then
		cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshPresetLayout)
		for _, object in ipairs(camera:GetDescendants()) do
			remember(object)
			applyObject(object)
		end
		cameraDescendantConnection = camera.DescendantAdded:Connect(handleAdded)
	end
	if layoutInitialized then
		refreshPresetLayout()
	else
		task.defer(function()
			RunService.Heartbeat:Wait()
			RunService.Heartbeat:Wait()
			if Workspace.CurrentCamera == camera then
				refreshPresetLayout()
			end
		end)
	end
end

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	watchCamera(Workspace.CurrentCamera)
end)
watchCamera(Workspace.CurrentCamera)

local function cancelPanelTweens()
	for _, tween in ipairs(panelTweens) do
		if tween.PlaybackState == Enum.PlaybackState.Playing then
			tween:Cancel()
		end
	end
	panelTweens = {}
end

local function setPanelOpen(isOpen)
	if panelOpen == isOpen then
		return
	end
	panelOpen = isOpen
	panelAnimationId += 1
	local animationId = panelAnimationId
	cancelPanelTweens()

	local targetScale = panelBaseScale
	if isOpen then
		panel.Visible = true
		panel.BackgroundTransparency = 1
		panelStroke.Transparency = 1
		panelScale.Scale = targetScale * 0.94
	end

	local duration = isOpen and 0.18 or 0.14
	local direction = isOpen and Enum.EasingDirection.Out or Enum.EasingDirection.In
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, direction)
	local scaleTarget = isOpen and targetScale or targetScale * 0.94
	local scaleTween = TweenService:Create(panelScale, info, {Scale = scaleTarget})
	local backgroundTween = TweenService:Create(panel, info, {BackgroundTransparency = isOpen and 0.08 or 1})
	local strokeTween = TweenService:Create(panelStroke, info, {Transparency = isOpen and 0.3 or 1})
	panelTweens = {scaleTween, backgroundTween, strokeTween}

	scaleTween.Completed:Connect(function(playbackState)
		if animationId ~= panelAnimationId or playbackState ~= Enum.PlaybackState.Completed then
			return
		end
		panelTweens = {}
		panelScale.Scale = targetScale
		if isOpen then
			panel.BackgroundTransparency = 0.08
			panelStroke.Transparency = 0.3
		elseif not panelOpen then
			panel.Visible = false
			panel.BackgroundTransparency = 0.08
			panelStroke.Transparency = 0.3
		end
	end)

	scaleTween:Play()
	backgroundTween:Play()
	strokeTween:Play()
end

local function setCustomizationMode(enabled)
	customizationMode = enabled
	customizeButton.Visible = not enabled
	resetButton.Visible = enabled
	doneButton.Visible = enabled
	buttonStroke.Color = enabled and Color3.fromRGB(236, 236, 239) or Color3.fromRGB(98, 98, 106)
	buttonStroke.Transparency = enabled and 0.05 or 0.38
	if not enabled then
		updatePresetSelection()
	end
end

local function beginDrag(object, input)
	if not customizationMode then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	activeDrag = {
		object = object,
		pointer = input,
		inputType = input.UserInputType,
		startPointer = input.Position,
		startObject = Vector2.new(object.Position.X.Offset, object.Position.Y.Offset),
		moved = false,
	}
end

openButton.InputBegan:Connect(function(input)
	beginDrag(openButton, input)
end)
header.InputBegan:Connect(function(input)
	beginDrag(panel, input)
end)

UserInputService.InputChanged:Connect(function(input)
	local drag = activeDrag
	if not drag then
		return
	end
	local isPointerMovement = drag.inputType == Enum.UserInputType.Touch and input == drag.pointer
		or (drag.inputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement)
	if not isPointerMovement then
		return
	end
	local delta = input.Position - drag.startPointer
	if not drag.moved and delta.Magnitude < CONFIG.DragThreshold then
		return
	end
	drag.moved = true
	local scale = drag.object == panel and panelScale.Scale or buttonScale.Scale
	clampPosition(drag.object, drag.startObject.X + delta.X / scale, drag.startObject.Y + delta.Y / scale)
end)

UserInputService.InputEnded:Connect(function(input)
	local drag = activeDrag
	if not drag then
		return
	end
	local ended = input == drag.pointer or (drag.inputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1)
	if not ended then
		return
	end
	activeDrag = nil
	if drag.moved then
		if drag.object == panel then
			panelNormalized = saveablePosition(panel)
			panelPositionInitialized = true
			panelUserMoved = true
		else
			buttonNormalized = saveablePosition(openButton)
			buttonPositionInitialized = true
			buttonUserMoved = true
		end
		persistPositions()
	end
end)

openButton.Activated:Connect(function()
	if not customizationMode then
		setPanelOpen(not panelOpen)
	end
end)
closeButton.Activated:Connect(function()
	setPanelOpen(false)
end)
customizeButton.Activated:Connect(function()
	setCustomizationMode(true)
end)
doneButton.Activated:Connect(function()
	setCustomizationMode(false)
	persistPositions()
end)
resetButton.Activated:Connect(function()
	buttonNormalized = nil
	panelNormalized = nil
	buttonPositionInitialized = false
	panelPositionInitialized = false
	buttonUserMoved = false
	panelUserMoved = false
	openButton.Position = CONFIG.ButtonPosition
	panel.Position = CONFIG.PanelPosition
	refreshPresetLayout()
	buttonNormalized = saveablePosition(openButton)
	panelNormalized = saveablePosition(panel)
	persistPositions()
end)

openButton.MouseEnter:Connect(function()
	if not customizationMode then
		openButton.BackgroundColor3 = Color3.fromRGB(39, 39, 44)
		buttonStroke.Transparency = 0.08
	end
end)
openButton.MouseLeave:Connect(function()
	if not customizationMode then
		openButton.BackgroundColor3 = Color3.fromRGB(18, 18, 20)
		buttonStroke.Transparency = 0.38
	end
end)

local function findOpenMicButton(object)
	if not object:IsA("GuiButton") or not object.Visible or object:IsDescendantOf(gui) then
		return false
	end
	local text = object:IsA("TextButton") and object.Text or ""
	local label = string.lower(object.Name .. " " .. text)
	return string.find(label, "open%s*mic") ~= nil
		or string.find(label, "microphone", 1, true) ~= nil
		or string.find(label, "%f[%a]mic%f[%A]") ~= nil
end

local function attachBesideMic(object)
	if micButton or not findOpenMicButton(object) then
		return
	end
	micButton = object
	local function syncPosition()
		if not micButton.Parent or buttonNormalized then
			return
		end
		local position = micButton.AbsolutePosition
		local size = micButton.AbsoluteSize
		local topLeftInset = GuiService:GetGuiInset()
		clampPosition(openButton, position.X - topLeftInset.X + size.X + CONFIG.ButtonSpacing, position.Y - topLeftInset.Y)
		buttonPositionInitialized = true
	end
	for _, property in ipairs({"AbsolutePosition", "AbsoluteSize"}) do
		table.insert(micConnections, micButton:GetPropertyChangedSignal(property):Connect(syncPosition))
	end
	syncPosition()
end

for _, object in ipairs(playerGui:GetDescendants()) do
	attachBesideMic(object)
end
playerGui.DescendantAdded:Connect(attachBesideMic)

task.delay(0.5, function()
	if not customizationMode and not activeDrag and not micButton and not buttonUserMoved and not buttonNormalized then
		clampPosition(openButton, CONFIG.ButtonPosition.X.Offset, CONFIG.ButtonPosition.Y.Offset)
	end
	if not customizationMode and not activeDrag and not panelUserMoved and not panelNormalized then
		clampPosition(panel, CONFIG.PanelPosition.X.Offset, CONFIG.PanelPosition.Y.Offset)
	end
end)

applyPreset(currentPreset)
updatePresetSelection()
updateToggleVisuals()

task.spawn(function()
	local remote = ReplicatedStorage:WaitForChild("FarmVilleGraphicsSettingsRemote", 8)
	if not remote or not remote:IsA("RemoteFunction") then
		return
	end
	settingsRemote = remote
	local ok, saved = pcall(function()
		return remote:InvokeServer("Load")
	end)
	if not ok or typeof(saved) ~= "table" then
		return
	end
	if typeof(saved.button) == "table" and typeof(saved.button.x) == "number" and typeof(saved.button.y) == "number" then
		buttonNormalized = {x = math.clamp(saved.button.x, 0, 1), y = math.clamp(saved.button.y, 0, 1)}
		buttonPositionInitialized = true
	end
	if typeof(saved.panel) == "table" and typeof(saved.panel.x) == "number" and typeof(saved.panel.y) == "number" then
		panelNormalized = {x = math.clamp(saved.panel.x, 0, 1), y = math.clamp(saved.panel.y, 0, 1)}
		panelPositionInitialized = true
	end
	refreshPresetLayout()
end)

