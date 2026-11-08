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

local Theme = {
	Colors = {
		Panel = Color3.fromRGB(21, 39, 57),
		PanelTop = Color3.fromRGB(28, 52, 74),
		PanelBottom = Color3.fromRGB(17, 33, 49),
		Slot = Color3.fromRGB(25, 46, 65),
		Stroke = Color3.fromRGB(92, 129, 157),
		Blue = Color3.fromRGB(77, 184, 255),
		ActiveStart = Color3.fromRGB(30, 111, 217), -- #1E6FD9
		ActiveEnd = Color3.fromRGB(58, 160, 255), -- #3AA0FF
		Text = Color3.fromRGB(242, 247, 252),
		Muted = Color3.fromRGB(177, 194, 209),
		Shadow = Color3.fromRGB(5, 15, 25),
	},
	Radius = {Panel = 28, Header = 28, Search = 22, Close = 22, Tab = 14, Slot = 18, Capacity = 18},
	Spacing = {
		PanelWidth = 890, PanelHeight = 520, HeaderHeight = 76, SidebarWidth = 230,
		SidebarTop = 18, SidebarRowHeight = 52, SidebarGap = 7,
		GridInsetX = 16, GridInsetY = 14, GridCell = 110, GridGap = 14,
	},
	Fonts = {Title = Enum.Font.FredokaOne, Body = Enum.Font.GothamMedium, Quantity = Enum.Font.GothamBold},
	Assets = {
		BackpackIcon = "rbxassetid://113023659142897",
		SearchIcon = "", -- Optional 64x64 transparent PNG uploaded by the developer.
		CloseIcon = "", -- Optional 64x64 transparent PNG uploaded by the developer.
		ItemFallback = "", -- Optional 256x256 transparent PNG uploaded by the developer.
		CategoryIcons = {
			["All Items"] = "", Tools = "", Seeds = "", Crops = "", Product = "", Misc = "",
		},
	},
	Glyphs = {
		Categories = {["All Items"] = "▦", Tools = "⚒", Seeds = "❧", Crops = "♧", Product = "◉", Misc = "▣"},
	},
}
local COLORS = {
	panel = Theme.Colors.Panel, panel2 = Theme.Colors.Panel, slot = Theme.Colors.Slot,
	stroke = Theme.Colors.Stroke, blue = Theme.Colors.Blue, blueSoft = Theme.Colors.ActiveStart,
	text = Theme.Colors.Text, muted = Theme.Colors.Muted,
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
		Font = font or Theme.Fonts.Body,
		TextSize = fontSize or 14,
		TextColor3 = color or COLORS.text,
		TextXAlignment = alignment or Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, parent)
end
local function backpackGlyph(parent, position, size)
	local holder = make("Frame", {
		Name = "WhiteBackpackIcon",
		BackgroundTransparency = 1,
		Position = position,
		Size = size,
	}, parent)
	local white = Color3.fromRGB(241, 247, 252)
	local body = make("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0.16, 0, 0.27, 0),
		Size = UDim2.new(0.68, 0, 0.65, 0),
	}, holder)
	corner(body, 5)
	outline(body, white, 0.02, 2)
	local flap = make("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0.28, 0, 0.12, 0),
		Size = UDim2.new(0.44, 0, 0.28, 0),
	}, holder)
	corner(flap, 5)
	outline(flap, white, 0.02, 2)
	make("Frame", {
		BackgroundColor3 = white,
		BorderSizePixel = 0,
		Position = UDim2.new(0.42, 0, 0.51, 0),
		Size = UDim2.new(0.16, 0, 0.08, 0),
	}, holder)
	local leftStrap = make("Frame", {
		BackgroundColor3 = white,
		BorderSizePixel = 0,
		Position = UDim2.new(0.08, 0, 0.39, 0),
		Size = UDim2.new(0.09, 0, 0.42, 0),
	}, holder)
	corner(leftStrap, 3)
	local rightStrap = make("Frame", {
		BackgroundColor3 = white,
		BorderSizePixel = 0,
		Position = UDim2.new(0.83, 0, 0.39, 0),
		Size = UDim2.new(0.09, 0, 0.42, 0),
	}, holder)
	corner(rightStrap, 3)
	return holder
end
local function magnifierGlyph(parent, position)
	local holder = make("Frame", {Name = "SearchIcon", BackgroundTransparency = 1, Position = position, Size = UDim2.fromOffset(22, 22), ZIndex = 7}, parent)
	local ring = make("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(1, 1), Size = UDim2.fromOffset(14, 14)}, holder)
	corner(ring, 10)
	ring.ZIndex = 7
	outline(ring, Color3.fromRGB(218, 232, 243), 0.02, 2)
	local handle = make("Frame", {BackgroundColor3 = COLORS.muted, BorderSizePixel = 0, Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(7, 2), Rotation = 45}, holder)
	corner(handle, 2)
	handle.ZIndex = 7
	return holder
end

local gui = make("ScreenGui", {
	Name = "PalmVilleInventoryGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 35,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

local scale = make("UIScale", {Scale = 1}, gui)
local applyResponsiveLayout
local panelTargetSize = Vector2.new(Theme.Spacing.PanelWidth, Theme.Spacing.PanelHeight)
local compactLayout = false

local function updateScale()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local viewport = camera.ViewportSize
	compactLayout = viewport.X < 720 or viewport.Y < 500

	if compactLayout then
		scale.Scale = 1
		panelTargetSize = Vector2.new(
			math.max(280, viewport.X - 24),
			math.max(260, math.min(viewport.Y - 24, 650))
		)
	else
		local factor = math.min(viewport.X / 980, viewport.Y / 610, 1)
		scale.Scale = math.clamp(factor, 0.32, 1)
		panelTargetSize = Vector2.new(Theme.Spacing.PanelWidth, Theme.Spacing.PanelHeight)
	end

	if applyResponsiveLayout then
		applyResponsiveLayout(viewport, compactLayout)
	end
end

local openButton = make("TextButton", {
	Name = "OpenInventory",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 18, 0.5, 5),
	Size = UDim2.fromOffset(96, 100),
	BackgroundColor3 = COLORS.panel,
	BackgroundTransparency = 0.08,
	Text = "",
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
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.43, 0),
	Size = UDim2.fromOffset(70, 70),
	Image = "rbxassetid://113023659142897",
	ScaleType = Enum.ScaleType.Fit,
}, openButton)
label(openButton, "Inventory", UDim2.new(1, -6, 0, 22), UDim2.new(0, 3, 1, -24), 13, COLORS.text, Enum.Font.FredokaOne, Enum.TextXAlignment.Center)

local shade = make("TextButton", {
	Name = "Backdrop",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(3, 9, 17),
	BackgroundTransparency = 0.72,
	Text = "",
	Visible = false,
	AutoButtonColor = false,
}, gui)

local panel = make("Frame", {
	Name = "InventoryPanel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(Theme.Spacing.PanelWidth, Theme.Spacing.PanelHeight),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 0.12,
	Visible = false,
	ClipsDescendants = true,
}, gui)
local panelCorner = corner(panel, Theme.Radius.Panel)
local panelOutline = outline(panel, COLORS.blue, 0.16, 1.4)
make("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.Colors.PanelTop),
		ColorSequenceKeypoint.new(0.48, Color3.fromRGB(21, 40, 59)),
		ColorSequenceKeypoint.new(1, Theme.Colors.PanelBottom),
	}),
	Rotation = 90,
}, panel)
local panelGlow = outline(panel, Color3.fromRGB(125, 218, 255), 0.84, 3)
local Lighting = game:GetService("Lighting")
local inventoryBlur = Lighting:FindFirstChild("PalmVilleInventoryBlur")
if not inventoryBlur then
	inventoryBlur = Instance.new("BlurEffect")
	inventoryBlur.Name = "PalmVilleInventoryBlur"
	inventoryBlur.Size = 0
	inventoryBlur.Parent = Lighting
end
inventoryBlur.Enabled = false

local header = make("Frame", {
	Name = "Header",
	Size = UDim2.new(1, 0, 0, Theme.Spacing.HeaderHeight),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 0.1,
	BorderSizePixel = 0,
}, panel)
-- UICorner does not clip child backgrounds, so round the header itself and
-- restore its straight lower edge with a matching strip.
local headerCorner = corner(header, Theme.Radius.Header)
make("UIGradient", {
	Color = ColorSequence.new(Color3.fromRGB(31, 57, 80), Color3.fromRGB(22, 42, 61)),
	Rotation = 90,
}, header)
local headerBottomMask = make("Frame", {
	Name = "HeaderBottomMask",
	Position = UDim2.new(0, 0, 1, -28),
	Size = UDim2.new(1, 0, 0, 28),
	BackgroundColor3 = Color3.fromRGB(22, 42, 61),
	BackgroundTransparency = 0.1,
	BorderSizePixel = 0,
}, header)
local headerLine = make("Frame", {
	Position = UDim2.new(0, 0, 1, -1),
	Size = UDim2.new(1, 0, 0, 1),
	BackgroundColor3 = COLORS.blue,
	BackgroundTransparency = 0.72,
	BorderSizePixel = 0,
}, header)
local headerIcon = make("ImageLabel", {
	Name = "HeaderBackpackIcon",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(35, 19),
	Size = UDim2.fromOffset(38, 38),
	Image = Theme.Assets.BackpackIcon,
	ImageColor3 = Color3.new(1, 1, 1),
	ScaleType = Enum.ScaleType.Fit,
}, header)
local titleText = label(header, "Inventory", UDim2.fromOffset(250, 42), UDim2.fromOffset(88, 16), 30, COLORS.text, Theme.Fonts.Title)

local search = make("TextBox", {
	Name = "Search",
	PlaceholderText = "Search item...",
	Text = "",
	ClearTextOnFocus = false,
	Size = UDim2.fromOffset(270, 48),
	Position = UDim2.new(1, -362, 0, 14),
	ZIndex = 6,
	BackgroundColor3 = Color3.fromRGB(34, 61, 83),
	BackgroundTransparency = 0.08,
	TextColor3 = Color3.fromRGB(247, 250, 253),
	TextTransparency = 0,
	PlaceholderColor3 = Color3.fromRGB(190, 207, 221),
	PlaceholderText = "Search item...",
	Font = Enum.Font.GothamMedium,
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Left,
}, header)
local searchCorner = corner(search, Theme.Radius.Search)
outline(search, Color3.fromRGB(112, 157, 190), 0.2, 1.25)
local searchPadding = make("UIPadding", {PaddingLeft = UDim.new(0, 46), PaddingRight = UDim.new(0, 14)}, search)
-- Keep the magnifier outside the padded TextBox: UIPadding also offsets child UI instances.
local searchIcon
if Theme.Assets.SearchIcon ~= "" then
	searchIcon = make("ImageLabel", {
		Name = "SearchIcon", BackgroundTransparency = 1,
		Position = UDim2.new(1, -348, 0, 27), Size = UDim2.fromOffset(22, 22),
		Image = Theme.Assets.SearchIcon, ImageColor3 = Theme.Colors.Text,
		ScaleType = Enum.ScaleType.Fit, ZIndex = 7,
	}, header)
else
	searchIcon = magnifierGlyph(header, UDim2.new(1, -348, 0, 27))
end

local close = make("TextButton", {
	Name = "Close",
	Text = "×",
	Font = Enum.Font.GothamMedium,
	TextSize = 28,
	TextColor3 = COLORS.text,
	BackgroundColor3 = Color3.fromRGB(24, 43, 62),
	Size = UDim2.fromOffset(48, 48),
	Position = UDim2.new(1, -75, 0, 14),
	ZIndex = 4,
	AutoButtonColor = false,
}, header)
local closeCorner = corner(close, Theme.Radius.Close)
outline(close, COLORS.stroke, 0.48, 1)
local closeIconImage
if Theme.Assets.CloseIcon ~= "" then
	close.Text = ""
	closeIconImage = make("ImageLabel", {
		Name = "CloseIcon", BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.56, 0.56), Image = Theme.Assets.CloseIcon,
		ImageColor3 = Theme.Colors.Text, ScaleType = Enum.ScaleType.Fit, ZIndex = 5,
	}, close)
end

local sidebar = make("Frame", {
	Name = "Categories",
	Position = UDim2.fromOffset(0, Theme.Spacing.HeaderHeight),
	Size = UDim2.new(0, Theme.Spacing.SidebarWidth, 1, -77),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
}, panel)
local sidePadding = make("UIPadding", {
	PaddingTop = UDim.new(0, Theme.Spacing.SidebarTop),
	PaddingLeft = UDim.new(0, 20),
	PaddingRight = UDim.new(0, 12),
}, sidebar)
local sideLayout = make("UIListLayout", {
	Padding = UDim.new(0, Theme.Spacing.SidebarGap),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, sidebar)

local content = make("Frame", {
	Name = "ItemsArea",
	Position = UDim2.fromOffset(Theme.Spacing.SidebarWidth, Theme.Spacing.HeaderHeight),
	Size = UDim2.new(1, -Theme.Spacing.SidebarWidth, 1, -77),
	BackgroundTransparency = 1,
}, panel)

local categoryNames = {"All Items", "Tools", "Seeds", "Crops", "Product", "Misc"}
local selectedCategory = "All Items"
local categoryButtons = {}
local setSelectedCategory
local categoryIconObjects = {}
local categoryIconTextLabels = {}
local categoryTextLabels = {}
local itemCards = {}
local currentItems = {}
local selectedTool = nil
local hotbarButtons = {}
local HOTBAR_SLOTS = 5

local gridScroll = make("ScrollingFrame", {
	Name = "ItemGrid",
	Position = UDim2.fromOffset(Theme.Spacing.GridInsetX, Theme.Spacing.GridInsetY),
	Size = UDim2.new(1, -32, 1, -78),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 5,
	ScrollBarImageColor3 = COLORS.blue,
	CanvasSize = UDim2.fromOffset(0, 0),
}, content)
local grid = make("UIGridLayout", {
	CellSize = UDim2.fromOffset(Theme.Spacing.GridCell, Theme.Spacing.GridCell),
	CellPadding = UDim2.fromOffset(Theme.Spacing.GridGap, Theme.Spacing.GridGap),
	FillDirectionMaxCells = 5,
	SortOrder = Enum.SortOrder.LayoutOrder,
}, gridScroll)
grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	-- Avoid manufacturing a scrollbar when exactly three rows already fit.
	gridScroll.CanvasSize = UDim2.fromOffset(0, grid.AbsoluteContentSize.Y)
end)

local footer = make("Frame", {
	Position = UDim2.new(0, 16, 1, -59),
	Size = UDim2.new(1, -38, 0, 40),
	BackgroundTransparency = 1,
}, content)
local capacityPill = make("Frame", {
	Name = "CapacityPill",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, 0, 0.5, 0),
	Size = UDim2.fromOffset(122, 36),
	BackgroundColor3 = Color3.fromRGB(20, 39, 57),
	BackgroundTransparency = 0.08,
}, footer)
local capacityCorner = corner(capacityPill, Theme.Radius.Capacity)
local capacityIcon = backpackGlyph(capacityPill, UDim2.fromOffset(9, 7), UDim2.fromOffset(22, 22))
local capacity = label(capacityPill, "0 / 50", UDim2.new(1, -46, 1, 0), UDim2.fromOffset(37, 0), 14, COLORS.text, Enum.Font.GothamBold, Enum.TextXAlignment.Right)

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

local inventoryRemote = game:GetService("ReplicatedStorage"):WaitForChild("PalmVilleGetInventory", 10)
local savedItems = {}
local inventoryLoaded = false
local inventoryCapacity = 50

local function refreshSavedItems()
	if not inventoryRemote or not inventoryRemote:IsA("RemoteFunction") then return end
	local ok, snapshot = pcall(function()
		return inventoryRemote:InvokeServer()
	end)
	if ok and type(snapshot) == "table" and snapshot.loaded ~= false then
		savedItems = type(snapshot.items) == "table" and snapshot.items or {}
		inventoryCapacity = math.max(1, math.floor(tonumber(snapshot.capacity) or 50))
		inventoryLoaded = true
	end
end

local function getCategory(tool)
	local explicit = tool:GetAttribute("ItemCategory") or tool:GetAttribute("Category")
	if type(explicit) == "string" then
		local normalized = explicit:lower()
		if normalized:find("seed") then return "Seeds" end
		if normalized:find("crop") or normalized:find("fruit") then return "Crops" end
		if normalized:find("tool") then return "Tools" end
		if normalized:find("material") then return "Misc" end
		if normalized:find("consum") or normalized:find("product") then return "Product" end
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

local refreshHotbar

local function renderItems()
	clearCards()
	local tools = getTools()
	local seedToolsByCode = {}
	for _, tool in ipairs(tools) do
		if tool:GetAttribute("PalmVilleSeedPack") == true then
			local code = tool:GetAttribute("ItemCode") or tool:GetAttribute("SeedCode")
			if code then seedToolsByCode[tostring(code)] = tool end
		end
	end

	local displayItems = {}
	for _, item in ipairs(savedItems) do
		local entry = table.clone(item)
		if entry.code then
			entry.tool = seedToolsByCode[tostring(entry.code)]
		end
		table.insert(displayItems, entry)
	end
	for _, tool in ipairs(tools) do
		-- Seed packs are already represented by the saved profile snapshot; don't show them twice.
		if tool:GetAttribute("PalmVilleSeedPack") ~= true then
			table.insert(displayItems, {
				name = tool.Name:gsub("%s+x%d+$", ""),
				amount = math.max(1, math.floor(tonumber(tool:GetAttribute("StackCount")) or 1)),
				category = getCategory(tool),
				icon = getItemIcon(tool),
				tool = tool,
			})
		end
	end
	currentItems = displayItems
	local usedCapacity = 0
	for _, entry in ipairs(displayItems) do usedCapacity += math.max(0, math.floor(tonumber(entry.amount) or 1)) end
	capacity.Text = tostring(usedCapacity) .. " / " .. tostring(inventoryCapacity)
	local query = search.Text:lower()
	local shown = 0
	for _, item in ipairs(displayItems) do
		local category = item.category or "Misc"
		local name = tostring(item.name or "Item")
		local matchesCategory = selectedCategory == "All Items" or category == selectedCategory
		local matchesSearch = query == "" or name:lower():find(query, 1, true) ~= nil
		if matchesCategory and matchesSearch then
			shown += 1
			local card = make("TextButton", {
				Name = "Item_" .. name:gsub("%W", ""),
				Text = "",
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0.08,
				AutoButtonColor = false,
				LayoutOrder = shown,
			}, gridScroll)
			corner(card, Theme.Radius.Slot)
			outline(card, Color3.fromRGB(103, 143, 171), 0.5, 1)
			make("UIGradient", {
				Color = ColorSequence.new(Color3.fromRGB(27, 49, 68), Color3.fromRGB(19, 37, 55)),
				Rotation = 90,
			}, card)
			local itemIcon = item.icon
			if (not itemIcon or itemIcon == "") and item.tool then
				itemIcon = getItemIcon(item.tool)
			end
			local cellSize = math.max(32, grid.CellSize.X.Offset)
			local iconSize = math.max(26, math.floor(cellSize * 0.74))
			if (not itemIcon or itemIcon == "") and Theme.Assets.ItemFallback ~= "" then
				itemIcon = Theme.Assets.ItemFallback
			end
			if itemIcon and itemIcon ~= "" then
				make("ImageLabel", {
					Name = "ItemIcon",
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, math.max(3, math.floor((cellSize - iconSize - 14) / 2))),
					Size = UDim2.fromOffset(iconSize, iconSize),
					Image = itemIcon,
					ScaleType = Enum.ScaleType.Fit,
				}, card)
			else
				local glyph = category == "Seeds" and "❧" or (category == "Tools" and "⚒" or (category == "Crops" and "♧" or "✿"))
				label(card, glyph, UDim2.new(1, 0, 0, math.floor(cellSize * 0.68)), UDim2.fromOffset(0, 3), math.floor(cellSize * 0.36), COLORS.muted, Enum.Font.FredokaOne, Enum.TextXAlignment.Center)
			end
			-- Item names stay hidden; quantities remain anchored to the lower-right corner.
			local quantityWidth = math.max(28, math.floor(cellSize * 0.44))
			local quantityHeight = math.max(16, math.floor(cellSize * 0.2))
			local quantityLabel = label(card, "x" .. tostring(item.amount or 1),
				UDim2.fromOffset(quantityWidth, quantityHeight),
				UDim2.new(1, -quantityWidth - 5, 1, -quantityHeight - 3),
				math.clamp(math.floor(cellSize * 0.14), 10, 16),
				COLORS.text, Theme.Fonts.Quantity, Enum.TextXAlignment.Right)
			quantityLabel.TextStrokeColor3 = Theme.Colors.Shadow
			quantityLabel.TextStrokeTransparency = 0.42
			if item.tool and item.tool.Parent == player.Character then
				local equippedStroke = card:FindFirstChildOfClass("UIStroke")
				if equippedStroke then equippedStroke.Color = COLORS.blue equippedStroke.Thickness = 2 end
			end
			card.Activated:Connect(function()
				if item.tool then
					equipTool(item.tool)
					refreshHotbar()
					renderItems()
				end
			end)
			table.insert(itemCards, card)
		end
	end
	for slotIndex = shown + 1, 15 do
		local emptySlot = make("Frame", {Name = "EmptySlot" .. slotIndex, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.08, LayoutOrder = slotIndex}, gridScroll)
		corner(emptySlot, math.min(20, math.floor(grid.CellSize.X.Offset * 0.18)))
		outline(emptySlot, Color3.fromRGB(91, 128, 157), 0.5, 1)
		make("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(25, 46, 65), Color3.fromRGB(18, 35, 52)),
			Rotation = 90,
		}, emptySlot)
		table.insert(itemCards, emptySlot)
	end
end

for index, category in ipairs(categoryNames) do
	local button = make("TextButton", {
		Name = "Category_" .. category:gsub("%s+", ""),
		Size = UDim2.new(1, 0, 0, Theme.Spacing.SidebarRowHeight),
		BackgroundColor3 = COLORS.panel2,
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = category == selectedCategory and COLORS.text or COLORS.muted,
		TextSize = 14,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutoButtonColor = false,
		LayoutOrder = index,
	}, sidebar)
	local categoryAsset = Theme.Assets.CategoryIcons[category]
	local categoryIcon
	if categoryAsset and categoryAsset ~= "" then
		categoryIcon = make("ImageLabel", {
			Name = "CategoryIcon", BackgroundTransparency = 1,
			Position = UDim2.fromOffset(12, 11), Size = UDim2.fromOffset(26, 30),
			Image = categoryAsset, ImageColor3 = Theme.Colors.Text, ScaleType = Enum.ScaleType.Fit, ZIndex = 2,
		}, button)
	else
		categoryIcon = label(button, Theme.Glyphs.Categories[category] or "•",
			UDim2.fromOffset(26, 30), UDim2.fromOffset(12, 11), 19,
			category == selectedCategory and COLORS.text or COLORS.muted,
			Theme.Fonts.Body, Enum.TextXAlignment.Center)
	end
	categoryIconObjects[category] = categoryIcon
	if categoryIcon:IsA("TextLabel") then categoryIconTextLabels[category] = categoryIcon end
	categoryTextLabels[category] = label(button, category, UDim2.new(1, -58, 1, 0),
		UDim2.fromOffset(52, 0), 14, category == selectedCategory and COLORS.text or COLORS.muted, Theme.Fonts.Body)
	corner(button, Theme.Radius.Tab)
	categoryButtons[category] = button
	button.Activated:Connect(function()
		setSelectedCategory(category)
		renderItems()
	end)
end

setSelectedCategory = function(category)
	selectedCategory = category
	for name, other in pairs(categoryButtons) do
		local active = name == selectedCategory
		other.BackgroundTransparency = active and 0.02 or 1
		other.BackgroundColor3 = active and Color3.new(1, 1, 1) or COLORS.panel2
		other.TextColor3 = active and COLORS.text or COLORS.muted
		for _, child in ipairs(other:GetChildren()) do
			if child:IsA("TextLabel") then
				child.TextColor3 = active and COLORS.text or COLORS.muted
			elseif child:IsA("ImageLabel") then
				child.ImageColor3 = active and COLORS.text or COLORS.muted
			end
		end
		if active then
			local stroke = other:FindFirstChildOfClass("UIStroke")
			if not stroke then outline(other, Theme.Colors.ActiveEnd, 0.38, 1.15) end
			local gradient = other:FindFirstChild("ActiveGradient")
			if not gradient then
				make("UIGradient", {
					Name = "ActiveGradient",
					Color = ColorSequence.new(Theme.Colors.ActiveStart, Theme.Colors.ActiveEnd),
					Rotation = 0,
				}, other)
			end
		else
			local stroke = other:FindFirstChildOfClass("UIStroke")
			if stroke then stroke:Destroy() end
			local gradient = other:FindFirstChild("ActiveGradient")
			if gradient then gradient:Destroy() end
		end
	end
end

setSelectedCategory("All Items")

local hotbar = make("Frame", {
	Name = "CustomHotbar",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -10),
	Size = UDim2.fromOffset(HOTBAR_SLOTS * 76 + (HOTBAR_SLOTS - 1) * 9, 82),
	BackgroundTransparency = 1,
}, gui)

refreshHotbar = function()
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
				local iconSize = math.max(24, math.floor(button.Size.X.Offset * 0.68))
				make("ImageLabel", {
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(0.5, 0),
					Size = UDim2.fromOffset(iconSize, iconSize),
					Position = UDim2.new(0.5, 0, 0, 3),
					Image = icon,
					ScaleType = Enum.ScaleType.Fit,
				}, button)
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


applyResponsiveLayout = function(viewport, compact)
	local width = panelTargetSize.X
	local height = panelTargetSize.Y
	panel.Size = UDim2.fromOffset(width, height)

	if compact then
		local radius = math.clamp(math.floor(math.min(width, height) * 0.055), 14, 22)
		local headerHeight = math.clamp(math.floor(height * 0.105), 52, 68)
		local sidebarWidth = math.clamp(math.floor(width * 0.31), 90, 156)
		local rowHeight = math.clamp(math.floor((height - headerHeight - 48) / #categoryNames), 26, 50)
		local gridGap = 8
		local contentWidth = width - sidebarWidth
		local contentHeight = height - headerHeight
		local cellByWidth = math.floor((contentWidth - 24 - gridGap * 4) / 5)
		local cellByHeight = math.floor((contentHeight - 68 - gridGap * 2) / 3)
		local cellSize = math.max(30, math.min(cellByWidth, cellByHeight, 110))

		panelCorner.CornerRadius = UDim.new(0, radius)
		panelOutline.Thickness = 1.25
		panelGlow.Thickness = 2
		header.Size = UDim2.new(1, 0, 0, headerHeight)
		headerCorner.CornerRadius = UDim.new(0, radius)
		headerBottomMask.Position = UDim2.new(0, 0, 1, -math.min(22, radius))
		headerBottomMask.Size = UDim2.new(1, 0, 0, math.min(22, radius))
		headerIcon.Position = UDim2.fromOffset(17, math.floor((headerHeight - 30) / 2))
		headerIcon.Size = UDim2.fromOffset(30, 30)
		titleText.Position = UDim2.fromOffset(55, 6)
		titleText.Size = UDim2.fromOffset(math.max(78, math.min(118, width - 244)), headerHeight - 12)
		titleText.TextSize = 19

		local closeSize = 36
		close.Size = UDim2.fromOffset(closeSize, closeSize)
		close.Position = UDim2.new(1, -46, 0.5, -closeSize / 2)
		close.TextSize = 23
		closeCorner.CornerRadius = UDim.new(0, 18)
		local searchWidth = math.max(70, width - 226)
		search.Size = UDim2.fromOffset(searchWidth, 36)
		search.Position = UDim2.new(1, -searchWidth - 52, 0.5, -18)
		searchCorner.CornerRadius = UDim.new(0, 18)
		search.TextSize = 11
		searchPadding.PaddingLeft = UDim.new(0, 36)
		searchPadding.PaddingRight = UDim.new(0, 8)
		searchIcon.Position = UDim2.new(1, -searchWidth - 38, 0, math.floor((headerHeight - 22) / 2))

		sidebar.Position = UDim2.fromOffset(0, headerHeight)
		sidebar.Size = UDim2.new(0, sidebarWidth, 1, -headerHeight)
				sidePadding.PaddingTop = UDim.new(0, 8)
		sidePadding.PaddingLeft = UDim.new(0, 8)
		sidePadding.PaddingRight = UDim.new(0, 8)
		sideLayout.Padding = UDim.new(0, 3)
		for _, category in ipairs(categoryNames) do
			categoryButtons[category].Size = UDim2.new(1, 0, 0, rowHeight)
			categoryIconObjects[category].Position = UDim2.fromOffset(5, math.floor((rowHeight - 24) / 2))
			categoryIconObjects[category].Size = UDim2.fromOffset(22, 24)
			if categoryIconTextLabels[category] then categoryIconTextLabels[category].TextSize = 16 end
			categoryTextLabels[category].Position = UDim2.fromOffset(31, 0)
			categoryTextLabels[category].Size = UDim2.new(1, -36, 1, 0)
			categoryTextLabels[category].TextSize = 10
		end

		content.Position = UDim2.fromOffset(sidebarWidth, headerHeight)
		content.Size = UDim2.new(1, -sidebarWidth, 1, -headerHeight)
		gridScroll.Position = UDim2.fromOffset(12, 10)
		gridScroll.Size = UDim2.new(1, -24, 1, -58)
		gridScroll.ScrollBarThickness = 3
		grid.CellSize = UDim2.fromOffset(cellSize, cellSize)
		grid.CellPadding = UDim2.fromOffset(gridGap, gridGap)

		footer.Position = UDim2.new(0, 12, 1, -40)
		footer.Size = UDim2.new(1, -24, 0, 28)
		capacityPill.Size = UDim2.fromOffset(98, 28)
		capacityCorner.CornerRadius = UDim.new(0, 14)
		capacityIcon.Position = UDim2.fromOffset(7, 5)
		capacityIcon.Size = UDim2.fromOffset(18, 18)
		capacity.TextSize = 11
		capacity.Position = UDim2.fromOffset(29, 0)
		capacity.Size = UDim2.new(1, -35, 1, 0)

		hotbar.Size = UDim2.fromOffset(HOTBAR_SLOTS * 50 + (HOTBAR_SLOTS - 1) * 4, 58)
		for index, button in ipairs(hotbarButtons) do
			button.Size = UDim2.fromOffset(50, 54)
			button.Position = UDim2.fromOffset((index - 1) * 54, 0)
		end
		hotbar.Position = UDim2.new(0.5, 0, 1, -4)

		openButton.Size = UDim2.fromOffset(58, 66)
		openButton.Position = UDim2.new(0, 10, 0.5, 0)
		openButton:FindFirstChild("BagIcon").Size = UDim2.fromOffset(44, 44)
		local openCaption = openButton:FindFirstChildOfClass("TextLabel")
		if openCaption then
			openCaption.TextSize = 10
			openCaption.Size = UDim2.new(1, -4, 0, 18)
			openCaption.Position = UDim2.new(0, 2, 1, -18)
		end
	else
		panelCorner.CornerRadius = UDim.new(0, Theme.Radius.Panel)
		panelOutline.Thickness = 1.4
		panelGlow.Thickness = 3
		header.Size = UDim2.new(1, 0, 0, 76)
		headerCorner.CornerRadius = UDim.new(0, Theme.Radius.Header)
		headerBottomMask.Position = UDim2.new(0, 0, 1, -28)
		headerBottomMask.Size = UDim2.new(1, 0, 0, 28)
		headerIcon.Position = UDim2.fromOffset(35, 19)
		headerIcon.Size = UDim2.fromOffset(38, 38)
		titleText.Position = UDim2.fromOffset(88, 16)
		titleText.Size = UDim2.fromOffset(250, 42)
		titleText.TextSize = 30
		search.Size = UDim2.fromOffset(270, 48)
		search.Position = UDim2.new(1, -362, 0, 14)
		searchCorner.CornerRadius = UDim.new(0, Theme.Radius.Search)
		search.TextSize = 14
		searchPadding.PaddingLeft = UDim.new(0, 46)
		searchPadding.PaddingRight = UDim.new(0, 14)
		searchIcon.Position = UDim2.new(1, -348, 0, 27)
		close.Size = UDim2.fromOffset(48, 48)
		close.Position = UDim2.new(1, -75, 0, 14)
		close.TextSize = 28
		closeCorner.CornerRadius = UDim.new(0, Theme.Radius.Close)

		sidebar.Position = UDim2.fromOffset(0, 76)
		sidebar.Size = UDim2.new(0, 230, 1, -77)
				sidePadding.PaddingTop = UDim.new(0, Theme.Spacing.SidebarTop)
		sidePadding.PaddingLeft = UDim.new(0, 20)
		sidePadding.PaddingRight = UDim.new(0, 12)
		sideLayout.Padding = UDim.new(0, Theme.Spacing.SidebarGap)
		for _, category in ipairs(categoryNames) do
			categoryButtons[category].Size = UDim2.new(1, 0, 0, Theme.Spacing.SidebarRowHeight)
			categoryIconObjects[category].Position = UDim2.fromOffset(12, 11)
			categoryIconObjects[category].Size = UDim2.fromOffset(26, 30)
			if categoryIconTextLabels[category] then categoryIconTextLabels[category].TextSize = 19 end
			categoryTextLabels[category].Position = UDim2.fromOffset(52, 0)
			categoryTextLabels[category].Size = UDim2.new(1, -58, 1, 0)
			categoryTextLabels[category].TextSize = 14
		end

		content.Position = UDim2.fromOffset(Theme.Spacing.SidebarWidth, Theme.Spacing.HeaderHeight)
		content.Size = UDim2.new(1, -Theme.Spacing.SidebarWidth, 1, -77)
		gridScroll.Position = UDim2.fromOffset(Theme.Spacing.GridInsetX, Theme.Spacing.GridInsetY)
		gridScroll.Size = UDim2.new(1, -32, 1, -78)
		gridScroll.ScrollBarThickness = 5
		grid.CellSize = UDim2.fromOffset(Theme.Spacing.GridCell, Theme.Spacing.GridCell)
		grid.CellPadding = UDim2.fromOffset(Theme.Spacing.GridGap, Theme.Spacing.GridGap)

		footer.Position = UDim2.new(0, 16, 1, -59)
		footer.Size = UDim2.new(1, -38, 0, 40)
		capacityPill.Size = UDim2.fromOffset(122, 36)
		capacityCorner.CornerRadius = UDim.new(0, Theme.Radius.Capacity)
		capacityIcon.Position = UDim2.fromOffset(9, 7)
		capacityIcon.Size = UDim2.fromOffset(22, 22)
		capacity.TextSize = 14
		capacity.Position = UDim2.fromOffset(34, 0)
		capacity.Size = UDim2.new(1, -42, 1, 0)

		hotbar.Size = UDim2.fromOffset(HOTBAR_SLOTS * 76 + (HOTBAR_SLOTS - 1) * 9, 82)
		for index, button in ipairs(hotbarButtons) do
			button.Size = UDim2.fromOffset(76, 76)
			button.Position = UDim2.fromOffset((index - 1) * 85, 0)
		end
		hotbar.Position = UDim2.new(0.5, 0, 1, -10)

		openButton.Size = UDim2.fromOffset(96, 100)
		openButton.Position = UDim2.new(0, 18, 0.5, 5)
		openButton:FindFirstChild("BagIcon").Size = UDim2.fromOffset(70, 70)
		local openCaption = openButton:FindFirstChildOfClass("TextLabel")
		if openCaption then
			openCaption.TextSize = 13
			openCaption.Size = UDim2.new(1, -6, 0, 22)
			openCaption.Position = UDim2.new(0, 3, 1, -24)
		end
	end
end

updateScale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

local function setOpen(open)
	panel.Visible = open
	shade.Visible = open
	inventoryBlur.Enabled = open
	TweenService:Create(inventoryBlur, TweenInfo.new(0.18), {Size = open and 3 or 0}):Play()
	openButton.Visible = not open
	if open then
		-- Always return to the full inventory when reopened so saved items are not hidden by a stale filter.
		setSelectedCategory("All Items")
		search.Text = ""
		refreshSavedItems()
		renderItems()
		panel.Size = UDim2.fromOffset(
			math.max(260, panelTargetSize.X - 28),
			math.max(240, panelTargetSize.Y - 18)
		)
		TweenService:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(panelTargetSize.X, panelTargetSize.Y),
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
	refreshSavedItems()
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
