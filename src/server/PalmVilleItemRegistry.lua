local ServerStorage = game:GetService("ServerStorage")

local adminTemplates = ServerStorage:FindFirstChild("PalmVilleAdminItems")
if not adminTemplates then
	adminTemplates = Instance.new("Folder")
	adminTemplates.Name = "PalmVilleAdminItems"
	adminTemplates.Parent = ServerStorage
end
local seedTemplates = ServerStorage:FindFirstChild("PalmVilleSeedPackTemplates")
if not seedTemplates then
	seedTemplates = Instance.new("Folder")
	seedTemplates.Name = "PalmVilleSeedPackTemplates"
	seedTemplates.Parent = ServerStorage
end

local function makeSeedPackTemplate(code, displayName, fruitName)
	local existing = seedTemplates:FindFirstChild(code)
	if existing and existing:IsA("Tool") then
		return existing
	end
	if existing then existing:Destroy() end

	local tool = Instance.new("Tool")
	tool.Name = displayName
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = displayName
	tool.Grip = CFrame.new(0, -0.12, -0.28)
	tool:SetAttribute("PalmVilleSeedPack", true)
	tool:SetAttribute("SeedCode", code)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.9, 1.08, 0.22)
	handle.Color = Color3.fromRGB(190, 133, 76)
	handle.Material = Enum.Material.Fabric
	handle.CanCollide = false
	handle.Massless = true
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.Parent = tool

	local face = Instance.new("SurfaceGui")
	face.Name = "SeedPackLabel"
	face.Face = Enum.NormalId.Front
	face.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	face.PixelsPerStud = 72
	face.LightInfluence = 0
	face.Parent = handle

	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromScale(0.88, 0.88)
	panel.Position = UDim2.fromScale(0.06, 0.06)
	panel.BackgroundColor3 = Color3.fromRGB(247, 222, 169)
	panel.BorderSizePixel = 0
	panel.Parent = face

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.08, 0)
	corner.Parent = panel

	local brand = Instance.new("TextLabel")
	brand.Name = "Brand"
	brand.BackgroundTransparency = 1
	brand.Position = UDim2.fromScale(0.04, 0.12)
	brand.Size = UDim2.fromScale(0.92, 0.25)
	brand.Font = Enum.Font.GothamBold
	brand.Text = "PalmVille"
	brand.TextColor3 = Color3.fromRGB(36, 83, 35)
	brand.TextScaled = true
	brand.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "SeedName"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.04, 0.4)
	title.Size = UDim2.fromScale(0.92, 0.38)
	title.Font = Enum.Font.GothamBold
	title.Text = string.upper(fruitName) .. "\nSEEDS"
	title.TextColor3 = Color3.fromRGB(77, 43, 31)
	title.TextScaled = true
	title.TextWrapped = true
	title.Parent = panel

	local quality = Instance.new("TextLabel")
	quality.Name = "Quality"
	quality.BackgroundTransparency = 1
	quality.Position = UDim2.fromScale(0.04, 0.8)
	quality.Size = UDim2.fromScale(0.92, 0.12)
	quality.Font = Enum.Font.GothamBold
	quality.Text = "PREMIUM QUALITY"
	quality.TextColor3 = Color3.fromRGB(52, 52, 38)
	quality.TextScaled = true
	quality.Parent = panel

	tool.Parent = seedTemplates
	return tool
end

local riceTemplate = adminTemplates:FindFirstChild("RICE_SEED")
if not riceTemplate or not riceTemplate:IsA("Tool") then
	if riceTemplate then riceTemplate:Destroy() end
	riceTemplate = Instance.new("Tool")
	riceTemplate.Name = "RICE_SEED"
	riceTemplate.RequiresHandle = true
	riceTemplate.CanBeDropped = false
	riceTemplate.ToolTip = "Rice Seed"
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.9, 1.08, 0.22)
	handle.Color = Color3.fromRGB(190, 133, 76)
	handle.Material = Enum.Material.Fabric
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = riceTemplate
	local label = Instance.new("SurfaceGui")
	label.Face = Enum.NormalId.Front
	label.Parent = handle
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundColor3 = Color3.fromRGB(247, 222, 169)
	text.Text = "PalmVille\nRICE SEEDS"
	text.TextColor3 = Color3.fromRGB(77, 43, 31)
	text.TextScaled = true
	text.Font = Enum.Font.GothamBold
	text.Parent = label
	riceTemplate.Parent = adminTemplates
end

local registry = {
	RICE_SEED = {
		displayName = "Rice Seed",
		template = riceTemplate,
		maxAmount = 99,
	},
}

local seedItems = {
	{code = "GUAVA_SEED", displayName = "Guava Seed Pack", fruitName = "GUAVA"},
	{code = "JACKFRUIT_SEED", displayName = "Jackfruit Seed Pack", fruitName = "JACKFRUIT"},
	{code = "LANZONES_SEED", displayName = "Lanzones Seed Pack", fruitName = "LANZONES"},
	{code = "APPLE_SEED", displayName = "Apple Seed Pack", fruitName = "APPLE"},
	{code = "AVOCADO_SEED", displayName = "Avocado Seed Pack", fruitName = "AVOCADO"},
	{code = "BANANA_SEED", displayName = "Banana Seed Pack", fruitName = "BANANA"},
	{code = "CACAO_SEED", displayName = "Cacao Seed Pack", fruitName = "CACAO"},
	{code = "CALAMANSI_SEED", displayName = "Calamansi Seed Pack", fruitName = "CALAMANSI"},
	{code = "COCONUT_SEED", displayName = "Coconut Seed Pack", fruitName = "COCONUT"},
	{code = "DURIAN_SEED", displayName = "Durian Seed Pack", fruitName = "DURIAN"},
	{code = "LEMON_SEED", displayName = "Lemon Seed Pack", fruitName = "LEMON"},
	{code = "MANGO_SEED", displayName = "Mango Seed Pack", fruitName = "MANGO"},
	{code = "ORANGE_SEED", displayName = "Orange Seed Pack", fruitName = "ORANGE"},
	{code = "PAPAYA_SEED", displayName = "Papaya Seed Pack", fruitName = "PAPAYA"},
	{code = "RAMBUTAN_SEED", displayName = "Rambutan Seed Pack", fruitName = "RAMBUTAN"},
}

for _, definition in ipairs(seedItems) do
	registry[definition.code] = {
		displayName = definition.displayName,
		template = makeSeedPackTemplate(definition.code, definition.displayName, definition.fruitName),
		maxAmount = 999,
		inventoryCategory = "seedPacks",
	}
end

return registry
