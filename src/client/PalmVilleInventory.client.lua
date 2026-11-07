local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local backpack = player:WaitForChild("Backpack")

local old = playerGui:FindFirstChild("PalmVilleInventoryGui")
if old then old:Destroy() end

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local COLORS = {
	panel = Color3.fromRGB(18, 30, 45),
	panel2 = Color3.fromRGB(24, 39, 56),
	slot = Color3.fromRGB(25, 42, 59),
	stroke = Color3.fromRGB(73, 104, 132),
	blue = Color3.fromRGB(65, 174, 242),
	blueSoft = Color3.fromRGB(38, 91, 130),
	text = Color3.fromRGB(242, 247, 252),
	muted = Color3.fromRGB(165, 184, 201),
}

local function make(className, properties, parent)
	local object = Instance.new(className)
	for key, value in pairs(properties) do object[key] = value end
	object.Parent = parent
	return object
end

local function corner(parent, radius)
	return make("UICorner", {CornerRadius = UDim.new(0, radius)}, parent)
end

local function outline(parent, color, transparency, thickness)
	return make("UIStroke", {
		Color = color or COLORS.stroke,
		Transparency = transparency or 0.35,
		Thickness = thickness or 1,
	}, parent)
end

local function label(parent, text, size, position, fontSize, color, font, alignment)
	return make("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		Size = size,
		Position = position,
		Font = font or Enum.Font.GothamMedium,
		TextSize = fontSize or 14,
		TextColor3 = color or COLORS.text,
		TextXAlignment = alignment or Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, parent)
end

local gui = make("ScreenGui", {
	Name = "PalmVilleInventoryGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 35,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

local scale = make("UIScale", {Scale = 1}, gui)
local function updateScale()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local viewport = camera.ViewportSize
	local factor = math.min(viewport.X / 920, viewport.Y / 600, 1)
	scale.Scale = math.clamp(factor, 0.4, 1)
end
updateScale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

local openButton = make("TextButton", {
	Name = "OpenInventory",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 22, 0.5, 5),
	Size = UDim2.fromOffset(82, 76),
	BackgroundColor3 = COLORS.panel,
	BackgroundTransparency = 0.08,
	Text = "Inventory",
	TextColor3 = COLORS.text,
	TextSize = 14,
	Font = Enum.Font.GothamBold,
	AutoButtonColor = false,
}, gui)
corner(openButton, 16)
outline(openButton, COLORS.blue, 0.42, 1.3)
make("ImageLabel", {
	Name = "BagIcon",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.fromOffset(38, 38),
	Image = "rbxassetid://113023659142897",
	ScaleType = Enum.ScaleType.Fit,
}, openButton)
openButton.TextYAlignment = Enum.TextYAlignment.Bottom
openButton.TextXAlignment = Enum.TextXAlignment.Center
openButton.TextSize = 13

local shade = make("TextButton", {
	Name = "Backdrop",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(3, 9, 17),
	BackgroundTransparency = 0.42,
	Text = "",
	Visible = false,
	AutoButtonColor = false,
}, gui)

local panel = make("Frame", {
	Name = "InventoryPanel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(875, 510),
	BackgroundColor3 = COLORS.panel,
	BackgroundTransparency = 0.035,
	Visible = false,
	ClipsDescendants = true,
}, gui)
corner(panel, 24)
outline(panel, COLORS.blue, 0.12, 1.6)

local header = make("Frame", {
	Name = "Header",
	Size = UDim2.new(1, 0, 0, 78),
	BackgroundColor3 = Color3.fromRGB(21, 38, 56),
	BackgroundTransparency = 0.08,
	BorderSizePixel = 0,
}, panel)
local headerLine = make("Frame", {
	Position = UDim2.new(0, 0, 1, -1),
	Size = UDim2.new(1, 0, 0, 1),
	BackgroundColor3 = COLORS.blue,
	BackgroundTransparency = 0.72,
	BorderSizePixel = 0,
}, header)
label(header, "▣", UDim2.fromOffset(42, 48), UDim2.fromOffset(25, 14), 31, COLORS.text, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
label(header, "Inventory", UDim2.fromOffset(250, 42), UDim2.fromOffset(78, 17), 26, COLORS.text, Enum.Font.GothamBold)
label(header, "Your collected items and tools", UDim2.fromOffset(300, 20), UDim2.fromOffset(80, 49), 11, COLORS.muted)

local search = make("TextBox", {
	Name = "Search",
	PlaceholderText = "⌕  Search item...",
	Text = "",
	ClearTextOnFocus = false,
	Size = UDim2.fromOffset(245, 44),
	Position = UDim2.new(1, -315, 0, 17),
	BackgroundColor3 = COLORS.slot,
	TextColor3 = COLORS.text,
	PlaceholderColor3 = COLORS.muted,
	Font = Enum.Font.Gotham,
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Left,
}, header)
corner(search, 22)
outline(search, COLORS.stroke, 0.38, 1)
make("UIPadding", {PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 12)}, search)

local close = make("TextButton", {
	Name = "Close",
	Text = "×",
	Font = Enum.Font.GothamMedium,
	TextSize = 30,
	TextColor3 = COLORS.text,
	BackgroundColor3 = COLORS.slot,
	Size = UDim2.fromOffset(46, 44),
	Position = UDim2.new(1, -58, 0, 17),
	AutoButtonColor = false,
}, header)
corner(close, 22)
outline(close, COLORS.stroke, 0.45, 1)

local sidebar = make("Frame", {
	Name = "Categories",
	Position = UDim2.fromOffset(0, 79),
	Size = UDim2.new(0, 205, 1, -80),
	BackgroundColor3 = Color3.fromRGB(16, 28, 42),
	BackgroundTransparency = 0.18,
	BorderSizePixel = 0,
}, panel)
local sidePadding = make("UIPadding", {
	PaddingTop = UDim.new(0, 18),
	PaddingLeft = UDim.new(0, 14),
	PaddingRight = UDim.new(0, 12),
}, sidebar)
local sideLayout = make("UIListLayout", {
	Padding = UDim.new(0, 7),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, sidebar)

local content = make("Frame", {
	Name = "ItemsArea",
	Position = UDim2.fromOffset(205, 79),
	Size = UDim2.new(1, -205, 1, -80),
	BackgroundTransparency = 1,
}, panel)

local categoryNames = {"All Items", "Seeds", "Crops", "Tools", "Materials", "Consumables", "Misc"}
local categoryIcons = {"▦", "❧", "♧", "⚒", "⬡", "♜", "□"}
local selectedCategory = "All Items"
local categoryButtons = {}
local itemCards = {}
local currentItems = {}
local selectedTool = nil
local hotbarButtons = {}
local HOTBAR_SLOTS = 5

local gridScroll = make("ScrollingFrame", {
	Name = "ItemGrid",
	Position = UDim2.fromOffset(16, 15),
	Size = UDim2.new(1, -32, 1, -76),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 5,
	ScrollBarImageColor3 = COLORS.blue,
	CanvasSize = UDim2.fromOffset(0, 0),
}, content)
local grid = make("UIGridLayout", {
	CellSize = UDim2.fromOffset(105, 112),
	CellPadding = UDim2.fromOffset(12, 12),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, gridScroll)
grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	gridScroll.CanvasSize = UDim2.fromOffset(0, grid.AbsoluteContentSize.Y + 12)
end)

local footer = make("Frame", {
	Position = UDim2.new(0, 16, 1, -52),
	Size = UDim2.new(1, -32, 0, 36),
	BackgroundTransparency = 1,
}, content)
label(footer, "Select an item to equip it to your hotbar", UDim2.new(1, -140, 1, 0), UDim2.fromOffset(2, 0), 11, COLORS.muted)
local capacity = label(footer, "0 / 50", UDim2.fromOffset(110, 36), UDim2.new(1, -110, 0, 0), 14, COLORS.text, Enum.Font.GothamBold, Enum.TextXAlignment.Right)

local function getTools()
	local result, seen = {}, {}
	local character = player.Character
	for _, container in ipairs({backpack, character}) do
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("Tool") and not seen[child] then
					seen[child] = true
					table.insert(result, child)
				end
			end
		end
	end
	table.sort(result, function(a, b) return a.Name:lower() < b.Name:lower() end)
	return result
end

local function getCategory(tool)
	local explicit = tool:GetAttribute("ItemCategory") or tool:GetAttribute("Category")
	if type(explicit) == "string" then
		local normalized = explicit:lower()
		if normalized:find("seed") then return "Seeds" end
		if normalized:find("crop") or normalized:find("fruit") then return "Crops" end
		if normalized:find("tool") then return "Tools" end
		if normalized:find("material") then return "Materials" end
		if normalized:find("consum") then return "Consumables" end
	end
	if tool:GetAttribute("PalmVilleSeedPack") or tool:GetAttribute("SeedCode") then return "Seeds" end
	local name = tool.Name:lower()
	if name:find("seed") then return "Seeds" end
	if name:find("fruit") or name:find("crop") or name:find("carrot") or name:find("tomato") then return "Crops" end
	if name:find("water") or name:find("hoe") or name:find("shovel") or name:find("axe") or name:find("pick") then return "Tools" end
	return "Misc"
end

local function getItemIcon(tool)
	if tool.TextureId and tool.TextureId ~= "" then return tool.TextureId end
	local handle = tool:FindFirstChild("Handle")
	if handle then
		for _, child in ipairs(handle:GetChildren()) do
			if child:IsA("Decal") or child:IsA("Texture") then
				if child.Texture ~= "" then return child.Texture end
			end
		end
	end
	return nil
end

local function equipTool(tool)
	if not tool or not tool.Parent then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	if tool.Parent == character then
		humanoid:UnequipTools()
	else
		humanoid:EquipTool(tool)
	end
	selectedTool = tool
end

local function clearCards()
	for _, card in ipairs(itemCards) do card:Destroy() end
	table.clear(itemCards)
end

local function renderItems()
	clearCards()
	local tools = getTools()
	currentItems = tools
	capacity.Text = tostring(#tools) .. " / 50"
	local query = search.Text:lower()
	local shown = 0
	for _, tool in ipairs(tools) do
		local category = getCategory(tool)
		local matchesCategory = selectedCategory == "All Items" or category == selectedCategory
		local matchesSearch = query == "" or tool.Name:lower():find(query, 1, true) ~= nil
		if matchesCategory and matchesSearch then
			shown += 1
			local card = make("TextButton", {
				Name = "Item_" .. tool.Name,
				Text = "",
				BackgroundColor3 = COLORS.slot,
				AutoButtonColor = false,
				LayoutOrder = shown,
			}, gridScroll)
			corner(card, 17)
			outline(card, COLORS.stroke, 0.42, 1)
			local icon = getItemIcon(tool)
			if icon then
				make("ImageLabel", {
					Name = "ItemIcon",
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(15, 8),
					Size = UDim2.fromOffset(75, 72),
					Image = icon,
					ScaleType = Enum.ScaleType.Fit,
				}, card)
			else
				label(card, category == "Seeds" and "❧" or (category == "Tools" and "⚒" or "◇"),
					UDim2.new(1, 0, 0, 70), UDim2.fromOffset(0, 5), 38, COLORS.muted, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
			end
			label(card, tool.Name, UDim2.new(1, -12, 0, 24), UDim2.new(0, 6, 1, -27), 10, COLORS.text, Enum.Font.GothamMedium, Enum.TextXAlignment.Center)
			local amount = math.max(1, math.floor(tonumber(tool:GetAttribute("StackCount")) or 1))
			label(card, "x" .. tostring(amount), UDim2.fromOffset(35, 22), UDim2.new(1, -41, 1, -49), 13, COLORS.text, Enum.Font.GothamBold, Enum.TextXAlignment.Right)
			if tool.Parent == player.Character then
				local equippedStroke = card:FindFirstChildOfClass("UIStroke")
				if equippedStroke then equippedStroke.Color = COLORS.blue equippedStroke.Thickness = 2 end
			end
			card.Activated:Connect(function()
				equipTool(tool)
				renderItems()
			end)
			table.insert(itemCards, card)
		end
	end
	if shown == 0 then
		local empty = label(gridScroll, "No items found", UDim2.new(1, 0, 0, 70), UDim2.fromOffset(0, 18), 15, COLORS.muted, Enum.Font.GothamMedium, Enum.TextXAlignment.Center)
		table.insert(itemCards, empty)
	end
end

for index, category in ipairs(categoryNames) do
	local button = make("TextButton", {
		Name = "Category_" .. category:gsub("%s+", ""),
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundColor3 = COLORS.panel2,
		BackgroundTransparency = 1,
		Text = categoryIcons[index] .. "   " .. category,
		TextColor3 = category == selectedCategory and COLORS.text or COLORS.muted,
		TextSize = 14,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutoButtonColor = false,
		LayoutOrder = index,
	}, sidebar)
	make("UIPadding", {PaddingLeft = UDim.new(0, 14)}, button)
	corner(button, 14)
	categoryButtons[category] = button
	button.Activated:Connect(function()
		selectedCategory = category
		for name, other in pairs(categoryButtons) do
			local active = name == selectedCategory
			other.BackgroundTransparency = active and 0 or 1
			other.BackgroundColor3 = active and COLORS.blueSoft or COLORS.panel2
			other.TextColor3 = active and COLORS.text or COLORS.muted
			if active then
				local stroke = other:FindFirstChildOfClass("UIStroke")
				if not stroke then outline(other, COLORS.blue, 0.25, 1.2) end
			else
				local stroke = other:FindFirstChildOfClass("UIStroke")
				if stroke then stroke:Destroy() end
			end
		end
		renderItems()
	end)
end
categoryButtons[selectedCategory].BackgroundTransparency = 0
categoryButtons[selectedCategory].BackgroundColor3 = COLORS.blueSoft
outline(categoryButtons[selectedCategory], COLORS.blue, 0.25, 1.2)

local hotbar = make("Frame", {
	Name = "CustomHotbar",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -28),
	Size = UDim2.fromOffset(HOTBAR_SLOTS * 76 + (HOTBAR_SLOTS - 1) * 9, 82),
	BackgroundTransparency = 1,
}, gui)

local function refreshHotbar()
	local tools = getTools()
	for index = 1, HOTBAR_SLOTS do
		local button = hotbarButtons[index]
		local tool = tools[index]
		button:ClearAllChildren()
		button.Text = ""
		local active = tool and tool.Parent == player.Character
		button.BackgroundColor3 = active and COLORS.blueSoft or COLORS.panel
		button.BackgroundTransparency = 0.08
		corner(button, 15)
		outline(button, active and COLORS.blue or COLORS.stroke, active and 0.08 or 0.45, active and 2 or 1)
		if tool then
			local icon = getItemIcon(tool)
			if icon then
				make("ImageLabel", {BackgroundTransparency = 1, Size = UDim2.fromOffset(54, 48), Position = UDim2.fromOffset(7, 3), Image = icon, ScaleType = Enum.ScaleType.Fit}, button)
			else
				label(button, getCategory(tool) == "Seeds" and "❧" or "⚒", UDim2.new(1, 0, 0, 52), UDim2.fromOffset(0, 0), 27, COLORS.muted, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
			end
			label(button, tostring(index), UDim2.fromOffset(20, 18), UDim2.new(0.5, -10, 1, -1), 10, COLORS.text, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
		else
			label(button, "+", UDim2.fromScale(1, 1), UDim2.fromOffset(0, -4), 25, COLORS.muted, Enum.Font.Gotham, Enum.TextXAlignment.Center)
		end
	end
end

for index = 1, HOTBAR_SLOTS do
	local button = make("TextButton", {
		Name = "Slot" .. index,
		Size = UDim2.fromOffset(76, 76),
		Position = UDim2.fromOffset((index - 1) * 85, 0),
		BackgroundColor3 = COLORS.panel,
		Text = "",
		AutoButtonColor = false,
	}, hotbar)
	hotbarButtons[index] = button
	button.Activated:Connect(function()
		local tools = getTools()
		if tools[index] then equipTool(tools[index]) end
		refreshHotbar()
	end)
end

local function setOpen(open)
	panel.Visible = open
	shade.Visible = open
	openButton.Visible = not open
	if open then
		search.Text = ""
		renderItems()
		panel.Size = UDim2.fromOffset(840, 480)
		TweenService:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(875, 510),
		}):Play()
	end
end

openButton.Activated:Connect(function() setOpen(true) end)
close.Activated:Connect(function() setOpen(false) end)
shade.Activated:Connect(function() setOpen(false) end)
search:GetPropertyChangedSignal("Text"):Connect(renderItems)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.B then
		setOpen(not panel.Visible)
	elseif input.KeyCode.Value >= Enum.KeyCode.One.Value and input.KeyCode.Value <= Enum.KeyCode.Five.Value then
		local index = input.KeyCode.Value - Enum.KeyCode.One.Value + 1
		local tools = getTools()
		if tools[index] then equipTool(tools[index]) refreshHotbar() end
	elseif input.KeyCode == Enum.KeyCode.Escape and panel.Visible then
		setOpen(false)
	end
end)

local function refresh()
	renderItems()
	refreshHotbar()
end
backpack.ChildAdded:Connect(refresh)
backpack.ChildRemoved:Connect(refresh)
player.CharacterAdded:Connect(function(character)
	character.ChildAdded:Connect(refresh)
	character.ChildRemoved:Connect(refresh)
	task.defer(refresh)
end)
if player.Character then
	player.Character.ChildAdded:Connect(refresh)
	player.Character.ChildRemoved:Connect(refresh)
end

refresh()
