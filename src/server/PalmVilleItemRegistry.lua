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

local seedImageIds = {
	GUAVA_SEED = "70816857330256",
	JACKFRUIT_SEED = "71443769507864",
	LANZONES_SEED = "91322190769726",
	APPLE_SEED = "115506822841450",
	AVOCADO_SEED = "94689677516114",
	BANANA_SEED = "105532706817104",
	CACAO_SEED = "135297163632194",
	CALAMANSI_SEED = "139490728979617",
	COCONUT_SEED = "119931315882044",
	DURIAN_SEED = "135395803762791",
	LEMON_SEED = "86723798587896",
	MANGO_SEED = "80116271049635",
	ORANGE_SEED = "131336919043305",
	PAPAYA_SEED = "89599684306545",
	RAMBUTAN_SEED = "139427647144792",
}

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
	tool.Grip = CFrame.new()
	tool:SetAttribute("PalmVilleSeedPack", true)
	tool:SetAttribute("SeedCode", code)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.42, 0.58, 0.1)
	handle.Color = Color3.fromRGB(190, 133, 76)
	handle.Material = Enum.Material.Fabric
	handle.CanCollide = false
	handle.Massless = true
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.Parent = tool

	for _, side in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
		local artwork = Instance.new("Decal")
		artwork.Name = "SeedPackArtwork"
		artwork.Face = side
		artwork.Texture = "rbxassetid://" .. seedImageIds[code]
		artwork.Parent = handle
	end

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
