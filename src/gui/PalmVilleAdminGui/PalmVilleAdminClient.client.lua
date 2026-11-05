local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remote = ReplicatedStorage:WaitForChild("PalmVilleAdminRemote")
local gui = script.Parent
gui.Name = "PalmVilleAdminGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 90
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local C = {
	background = Color3.fromRGB(14, 19, 17),
	panel = Color3.fromRGB(22, 29, 25),
	surface = Color3.fromRGB(30, 40, 34),
	surface2 = Color3.fromRGB(49, 95, 65),
	line = Color3.fromRGB(55, 70, 61),
	text = Color3.fromRGB(242, 246, 239),
	muted = Color3.fromRGB(177, 188, 179),
	dim = Color3.fromRGB(125, 140, 130),
	white = Color3.fromRGB(250, 252, 248),
	red = Color3.fromRGB(198, 70, 70),
}

local authorized = false
local accessDeniedLogged = false
local role = ""
local permissions = {}
local panelOpen = false
local minimized = false
local selectedUserId = nil
local selectedName = nil
local selectedStaffId = nil
local permissionRole = "HEAD ADMIN"
local roster = {}
local staffRows = {}
local logRows = {}
local historyRows = {}
local activeTab = nil
local activeMoreTab = nil
local activeUtilityPage = nil
local toolsSubpage = "ABILITIES"
local setToolsSubpage
local utilityRequestVersion = 0
local announcementKind = "Server"
local announcementUI = {}
local isDragging = false
local panelMoved = false
local dragInput
local dragStart
local panelStart
local openVersion = 0
local clientFps = 0
local clientFrameCount = 0
local clientSample = os.clock()
local weatherType = "Sunny"
local rainTweens = {}
local rainGui
local flightPad
local flyVertical = 0
local flyEnabled = false
local invisibleEnabled = false
local abilityToggleButtons = {}
local abilityToggleLabels = {
	SetFly = "FLY",
	SetInvisible = "INVISIBLE",
	SetFreeCamera = "FREECAM",
	SetNoclip = "NOCLIP",
	SetAdminTitle = "ADMIN TITLE",
}
local refreshMoreTabs
local flyConnection
local freeCamEnabled = false
local freeCamConnection
local freeCamInputConnections = {}
local freeCamTouchLook = false
local freeCamSpeed = 42
local speedBox
local updatePanelSize
local freeCamPitch = 0
local freeCamYaw = 0
local savedCamera
local currentSpectateToken = nil
local spectateActive = false
local cameraFeedTokens = {}
local serverMetrics = nil
local statusMessage = ""
local statusUntil = 0
local playerSearch
local selectedInfo
local playerList
local moderationSearch
local moderationList
local moderationSelectedInfo
local moderatorUsername
local reasonBox
local durationBox
local announcementBox
local announcementDuration
local itemCodeBox
local itemAmountBox
local itemTargetMode = "Player"
local itemTargetButtons = {}
local watchPopup
local watchNameLabel
local currentAdminLabel
local managerShortcutGroup
local itemTargetLabel
local staffUsername
local staffList
local permissionList
local logsSearch
local logsList
local statusLabel
local tabs = {}

local function make(className, properties, parent)
	local object = Instance.new(className)
	for property, value in pairs(properties or {}) do
		object[property] = value
	end
	object.Parent = parent
	return object
end

local function corner(object, radius)
	make("UICorner", {CornerRadius = UDim.new(0, radius or 8)}, object)
end

local function stroke(object, color, transparency)
	make("UIStroke", {Color = color or C.line, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Transparency = transparency == nil and 0.12 or transparency}, object)
end

local function setStatus(message)
	statusMessage = tostring(message or "")
	statusUntil = os.clock() + 4
	if statusLabel then statusLabel.Text = statusMessage end
end

local function formatTime(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local remaining = seconds % 60
	if hours > 0 then
		return string.format("%dh %02dm", hours, minutes)
	end
	return string.format("%dm %02ds", minutes, remaining)
end

local function formatClock(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))
	return string.format("%02d:%02d:%02d", math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60)
end

local function isManager()
	return role == "OWNER" or role == "MASTER DEVELOPER"
end

local function displayRole(value)
	return value == "MASTER DEVELOPER" and "DEV" or tostring(value or "")
end

local function hasArea(area)
	if area=="Announcements" and role~="OWNER" and role~="MASTER DEVELOPER" and role~="HEAD ADMIN" then return false end
	if isManager() then return true end
	return permissions[area] == true
end

local launcher = make("TextButton", {
	Name = "AdminLauncher",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 56),
	Size = UDim2.fromOffset(112, 40),
	BackgroundColor3 = C.surface2,
	BorderSizePixel = 0,
	Text = "ADMIN",
	TextColor3 = C.white,
	Font = Enum.Font.Nunito,
	TextSize = 15,
	Visible = false,
	AutoButtonColor = false,
	ZIndex = 20,
}, gui)

corner(launcher, 12)
stroke(launcher, Color3.fromRGB(182, 202, 112))
-- Give the text room for the icon
make("UIPadding", {
	PaddingLeft = UDim.new(0, 26),
	PaddingRight = UDim.new(0, 4),
}, launcher)

local adminIcon = make("ImageLabel", {
	Name = "AdminIcon",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, -16, 0.5, 0),
	Size = UDim2.fromOffset(24, 26),
	Image = "rbxassetid://76963372950843",
	ScaleType = Enum.ScaleType.Fit,
	ZIndex = 21,
}, launcher)
local panelBackdrop = make("Frame", {Name = "PanelBackdrop", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.42, BorderSizePixel = 0, Visible = false, Active = true, ZIndex = 5}, gui)
local panel = make("Frame", {
	Name = "MainPanel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(1480, 720),
	BackgroundColor3 = C.background,
	BorderSizePixel = 0,
	Visible = false,
	ClipsDescendants = true,
	ZIndex = 10,
}, gui)
corner(panel, 18)
stroke(panel, C.line)

local panelScale = make("UIScale", {Scale = UserInputService.TouchEnabled and 0.9 or 0.88}, panel)
local header = make("Frame", {
	Name = "Header",
	Size = UDim2.new(1, 0, 0, 82),
	BackgroundColor3 = C.background,
	BorderSizePixel = 0,
	Active = true,
	ZIndex = 11,
}, panel)
make("Frame", {Name = "HeaderDivider", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = C.line, BorderSizePixel = 0, ZIndex = 12}, header)
local brand = make("TextLabel", {
	Name = "Brand",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(136, 0),
	Size = UDim2.new(0.32, 0, 1, 0),
	Text = "Admin",
	TextColor3 = C.text,
	Font = Enum.Font.Nunito,
	TextSize = 34,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 12,
}, header)
local headerDots = make("Frame", {Name = "DragHandle", Position = UDim2.fromOffset(30, 28), Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 1, ZIndex = 12}, header)
for row = 0, 2 do
	for column = 0, 2 do
		local dot = make("Frame", {Position = UDim2.fromOffset(column * 9, row * 9), Size = UDim2.fromOffset(5, 5), BackgroundColor3 = C.muted, BorderSizePixel = 0, ZIndex = 13}, headerDots)
		corner(dot, 2)
	end
end
local shieldIcon = make("ImageLabel", {
	Name = "ShieldIcon", BackgroundTransparency = 1,
	Position = UDim2.fromOffset(24, 14), Size = UDim2.fromOffset(42, 50),
	Image = "rbxassetid://76963372950843", ScaleType = Enum.ScaleType.Fit, ZIndex = 13,
}, header)
local roleLabel = make("TextLabel", {
	Name = "Role",
	BackgroundTransparency = 1,
	Position = UDim2.new(0.35, 0, 0, 0),
	Size = UDim2.new(0.3, 0, 1, 0),
	Text = "",
	TextColor3 = C.muted,
	Font = Enum.Font.Nunito,
	TextSize = 10,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 12,
}, header)

local function headerButton(name, label, width, callback)
	local button = make("TextButton", {
		Name = name,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(width, 44),
		BackgroundColor3 = C.panel,
		BackgroundTransparency = 1,
		Text = label,
		TextColor3 = C.text,
		Font = Enum.Font.Nunito,
		TextSize = 36,
		AutoButtonColor = false,
		ZIndex = 13,
	}, header)
	corner(button, 5)
	stroke(button, C.line, 1)
	button.Activated:Connect(callback)
	return button
end

local function closePanel()
	openVersion += 1
	local version = openVersion
	panelOpen = false
	TweenService:Create(panelScale, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = (UserInputService.TouchEnabled and 0.9 or 0.78) * 0.97}):Play()
	task.delay(0.15, function()
		if version == openVersion and not panelOpen then
			panel.Visible = false
			panelBackdrop.Visible = false
			launcher.Visible = true
		end
	end)
end
local controlGlyph = {}
local closeButton = headerButton("Close", "", 52, closePanel)
closeButton.Position = UDim2.new(1, -14, 0.5, 0)

-- Matching window controls: same 18px glyph box and 2px strokes.
controlGlyph.close = make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 1, ZIndex = 15}, closeButton)
for _, angle in ipairs({45, -45}) do
	local segment = make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(18, 2), Rotation = angle, BackgroundColor3 = C.text, BorderSizePixel = 0, ZIndex = 16}, controlGlyph.close)
	corner(segment, 1)
end
-- Browser-style hover states with matching hit areas and centered glyphs.
for _, button in ipairs({closeButton}) do
	button.MouseEnter:Connect(function()
		button.BackgroundColor3 = button == closeButton and Color3.fromRGB(174, 52, 52) or C.surface
		button.BackgroundTransparency = 0
	end)
	button.MouseLeave:Connect(function()
		button.BackgroundTransparency = 1
	end)
end
local resetButton = headerButton("ResetPosition", "RESET", 52, function()
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panelMoved = false
end)
resetButton.Position = UDim2.new(1, -116, 0.5, 0)
resetButton.Visible = false

local statusBar = make("Frame", {
	Name = "StatusBar",
	Position = UDim2.new(0, 0, 0, 48),
	Size = UDim2.new(1, 0, 0, 24),
	BackgroundColor3 = C.background,
	BorderSizePixel = 0,
	ZIndex = 11,
}, panel)
statusLabel = make("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 0),
	Size = UDim2.new(1, -32, 1, 0),
	Text = "READY",
	TextColor3 = C.muted,
	Font = Enum.Font.Nunito,
	TextSize = 10,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 12,
}, statusBar)

local sidebar = make("Frame", {
	Name = "Sidebar",
	Position = UDim2.new(0, 0, 0, 82),
	Size = UDim2.new(0, 380, 1, -82),
	BackgroundColor3 = C.panel,
	BorderSizePixel = 0,
	ZIndex = 11,
}, panel)
make("Frame", {Name = "SidebarDivider", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = C.line, BorderSizePixel = 0, ZIndex = 12}, sidebar)
-- Sidebar profile uses the signed-in player's actual Roblox avatar and role.
corner(sidebar, 18)
local profile = {}
profile.root = make("Frame", {Name = "AdminProfile", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 104), ZIndex = 12}, sidebar)
profile.avatar = make("ImageLabel", {Position = UDim2.fromOffset(12, 16), Size = UDim2.fromOffset(44, 44), BackgroundColor3 = C.surface, BorderSizePixel = 0, ZIndex = 13}, profile.root)
corner(profile.avatar, 22)
profile.name = make("TextLabel", {Position = UDim2.fromOffset(68, 14), Size = UDim2.new(1, -80, 0, 22), BackgroundTransparency = 1, Text = player.Name, TextColor3 = C.text, Font = Enum.Font.Nunito, TextSize = 15, TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13}, profile.root)
profile.role = make("TextLabel", {AnchorPoint = Vector2.zero, Position = UDim2.fromOffset(68, 40), Size = UDim2.fromOffset(124, 20), BackgroundColor3 = Color3.fromRGB(74, 132, 91), BorderSizePixel = 0, Text = "STAFF", TextColor3 = C.white, Font = Enum.Font.Nunito, TextSize = 10, TextScaled = true, ZIndex = 13}, profile.root)
corner(profile.role, 6)
make("UITextSizeConstraint", {MinTextSize = 9, MaxTextSize = 16}, profile.role)
make("Frame", {Position = UDim2.new(0, 16, 1, -1), Size = UDim2.new(1, -32, 0, 2), BackgroundColor3 = C.line, BorderSizePixel = 0, ZIndex = 13}, profile.root)
profile.subtitle = make("TextLabel", {Position = UDim2.fromOffset(82, 48), Size = UDim2.new(1, -210, 0, 20), BackgroundTransparency = 1, Text = "Server overview", TextColor3 = C.muted, Font = Enum.Font.Nunito, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13}, header)
headerDots.Visible = false
task.spawn(function()
	local ok, thumbnail = pcall(function()
		return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
	end)
	if ok and profile.avatar.Parent then profile.avatar.Image = thumbnail end
end)
local tabStrip = make("ScrollingFrame", {
	Name = "Tabs",
	Position = UDim2.fromOffset(8, 8),
	Size = UDim2.new(1, -16, 1, -16),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ScrollBarThickness = 2,
	ScrollBarImageColor3 = C.dim,
	ZIndex = 12,
}, sidebar)
local tabLayout = make("UIListLayout", {
	FillDirection = Enum.FillDirection.Vertical,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 6),
}, tabStrip)

local content = make("Frame", {
	Name = "Content",
	Position = UDim2.new(0, 406, 0, 94),
	Size = UDim2.new(1, -420, 1, -106),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 11,
}, panel)
corner(content, 7)

local pages = {}
local function createPage(name, targetParent)
	local page = make("ScrollingFrame", {
		Name = name,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = C.dim,
		Visible = false,
		ZIndex = 12,
	}, targetParent or content)
	make("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
	}, page)
	make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 7),
	}, page)
	pages[name] = page
	return page
end

local function section(parent, text, order)
	return make("TextLabel", {
		LayoutOrder = order or 0,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 32),
		Text = text,
		TextColor3 = C.text,
		Font = Enum.Font.Nunito,
		TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 13,
	}, parent)
end

local function textLabel(parent, text, height, order, properties)
	local props = {
		LayoutOrder = order or 0,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height or 26),
		Text = text or "",
		TextColor3 = C.text,
		Font = Enum.Font.Nunito,
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 13,
	}
	for key, value in pairs(properties or {}) do props[key] = value end
	return make("TextLabel", props, parent)
end

local function inputBox(parent, placeholder, order, height)
	local box = make("TextBox", {
		LayoutOrder = order or 0,
		Size = UDim2.new(1, 0, 0, height or (UserInputService.TouchEnabled and 42 or 34)),
		BackgroundColor3 = C.surface,
		TextColor3 = C.text,
		PlaceholderColor3 = C.dim,
		PlaceholderText = placeholder,
		Text = "",
		Font = Enum.Font.Nunito,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		MultiLine = false,
		ZIndex = 13,
	}, parent)
	corner(box, 5)
	stroke(box, C.line)
	make("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 8)}, box)
	return box
end

local function actionButton(parent, label, callback, order, widthScale)
	local button = make("TextButton", {
		LayoutOrder = order or 0,
		Size = UDim2.new(widthScale or 1, 0, 0, UserInputService.TouchEnabled and 44 or 32),
		BackgroundColor3 = C.surface,
		Text = label,
		TextColor3 = C.text,
		Font = Enum.Font.Nunito,
		TextSize = UserInputService.TouchEnabled and 12 or 13,
		TextWrapped = true,
		AutoButtonColor = false,
		ZIndex = 13,
	}, parent)
	corner(button, 5)
	stroke(button, C.line)
	button.Activated:Connect(callback)
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.1), {BackgroundColor3 = C.surface2}):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.1), {BackgroundColor3 = C.surface}):Play()
	end)
	return button
end

local function buttonRow(parent, labels, callback, order)
	local row = make("Frame", {
		LayoutOrder = order or 0,
		Size = UDim2.new(1, 0, 0, UserInputService.TouchEnabled and 44 or 32),
		BackgroundTransparency = 1,
		ZIndex = 13,
	}, parent)
	local layout = make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
	}, row)
	local buttons = {}
	for index, label in ipairs(labels) do
		local button = actionButton(row, label, function() callback(label, index) end, index, 1 / #labels)
		button.Size = UDim2.new(1 / #labels, -6, 1, 0)
		buttons[label] = button
	end
	return row, buttons
end

local activateTab
local function createTab(name, area, managerOnly, page, label)
	local button = make("TextButton", {
		Name = name .. "Tab",
		Size = UDim2.new(1, -4, 0, 40),
		BackgroundColor3 = C.surface,
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = C.text,
		Font = Enum.Font.Nunito,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutoButtonColor = false,
		Visible = false,
		ZIndex = 13,
	}, tabStrip)
	corner(button, 8)
	local activeBar = make("Frame", {
		Name = "ActiveIndicator",
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.fromOffset(3, 24),
		BackgroundColor3 = Color3.fromRGB(112, 184, 130),
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 15,
	}, button)
	corner(activeBar, 2)
	local tabLabel = make("TextLabel", {
		Name = "Label",
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(1, -24, 1, 0),
		BackgroundTransparency = 1,
		Text = label or name,
		TextColor3 = C.muted,
		Font = Enum.Font.Nunito,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 14,
	}, button)
	tabs[name] = {button = button, label = tabLabel, activeBar = activeBar, area = area, managerOnly = managerOnly, page = page}
	button.Activated:Connect(function() activateTab(name) end)
	button.MouseEnter:Connect(function()
		if activeTab ~= name then button.BackgroundTransparency = 0.45 end
	end)
	button.MouseLeave:Connect(function()
		if activeTab ~= name then button.BackgroundTransparency = 1 end
	end)
	return button
end

local homePage = createPage("HomePage")
homePage:FindFirstChildOfClass("UIPadding").PaddingTop = UDim.new(0, 17)
homePage:FindFirstChildOfClass("UIListLayout").Padding = UDim.new(0, 15)
local playersPage = createPage("PlayersPage")
local worldPage = createPage("EnvironmentPage")
local announcementPage = createPage("AnnouncementPage")
local giveItemPage = createPage("GiveItemPage")
local togglePage = createPage("TogglePage")
local moreContainer = make("Frame", {
	Name = "MorePage",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 12,
}, content)
local moreNav = make("ScrollingFrame", {
	Name = "MoreTabs",
	Size = UDim2.new(1, 0, 0, 36),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.X,
	ScrollingDirection = Enum.ScrollingDirection.X,
	ScrollBarThickness = 2,
	ScrollBarImageColor3 = C.dim,
	ZIndex = 13,
}, moreContainer)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, UserInputService.TouchEnabled and 3 or 6),
}, moreNav)
local moreContent = make("Frame", {
	Name = "MoreContent",
	Position = UDim2.new(0, 0, 0, 40),
	Size = UDim2.new(1, 0, 1, -40),
	BackgroundTransparency = 1,
	ZIndex = 12,
}, moreContainer)
local moderationPage = createPage("ModerationPage")
local staffPage = createPage("StaffPage")
local logsPage = createPage("LogsPage")
local statusPage = createPage("StatusPage")
local moreTabs = {}

local function activateMoreTab(name)
	local selected = moreTabs[name]
	if not selected or not selected.button.Visible then return end
	for tabName, item in pairs(moreTabs) do
		local active = tabName == name
		item.page.Visible = active
		item.button.BackgroundColor3 = active and C.surface2 or C.background
		item.button.BackgroundTransparency = active and 0 or 1
		item.button.TextColor3 = active and C.text or C.muted
	end
	activeMoreTab = name
	if not moreContainer.Visible then return end
	if name == "STAFF" then remote:FireServer("RequestStaff") end
	if name == "LOGS" then remote:FireServer("RequestLogs") end
	if name == "STATUS" then remote:FireServer("RequestSnapshot") end
end

local function createMoreTab(name, area, managerOnly, page)
	local button = make("TextButton", {
		Name = name .. "MoreTab",
		Size = UDim2.fromOffset(UserInputService.TouchEnabled and 56 or 82, UserInputService.TouchEnabled and 36 or 30),
		BackgroundColor3 = C.background,
		Text = name,
		TextColor3 = C.muted,
		Font = Enum.Font.Nunito,
		TextSize = 9,
		AutoButtonColor = false,
		Visible = false,
		ZIndex = 14,
	}, moreNav)
	corner(button, 5)
	stroke(button, C.line)
	moreTabs[name] = {button = button, area = area, managerOnly = managerOnly, page = page}
	button.Activated:Connect(function() activateMoreTab(name) end)
end

createMoreTab("MOD", "Moderation", false, moderationPage)
createMoreTab("STAFF", nil, true, staffPage)
createMoreTab("LOGS", "Logs", false, logsPage)
createMoreTab("STATUS", "Monitoring", false, statusPage)

refreshMoreTabs = function()
	for _, item in pairs(moreTabs) do
		item.button.Visible = authorized and ((item.managerOnly and isManager()) or (not item.managerOnly and item.area and hasArea(item.area)))
	end
	local selected = activeMoreTab and moreTabs[activeMoreTab]
	if not selected or not selected.button.Visible then
		activeMoreTab = nil
		for _, name in ipairs({"MOD", "STAFF", "LOGS", "STATUS"}) do
			local item = moreTabs[name]
			if item and item.button.Visible then
				activateMoreTab(name)
				break
			end
		end
	else
		activateMoreTab(activeMoreTab)
	end
	local available = false
	for _, item in pairs(moreTabs) do
		if item.button.Visible then available = true break end
	end
	if tabs.MORE then tabs.MORE.button.Visible = authorized and available end
end

createTab("OVERVIEW", nil, false, homePage, "Overview")
createTab("PLAYERS", "Players", false, playersPage, "Players")
createTab("ANNOUNCEMENT", "Announcements", false, announcementPage, "Announcements")
createTab("MODERATION", "Moderation", false, moderationPage, "Moderation")
createTab("ADMIN_MANAGEMENT", nil, true, staffPage, "Staff & Roles")
createTab("TOOLS", "Tools", false, togglePage, "Tools")
createTab("LOGS", "Logs", false, logsPage, "Logs")

local TAB_DESCRIPTIONS = {
	OVERVIEW = "Server overview and activity",
	PLAYERS = "Player directory and details",
	ANNOUNCEMENT = "Server-wide messages",
	MODERATION = "Player safety and moderation",
	ADMIN_MANAGEMENT = "Staff access and permissions",
	TOOLS = "Admin abilities and item tools",
	LOGS = "Administrative activity history",
}

activateTab = function(name)
	utilityRequestVersion += 1
	local selected = tabs[name]
	if not selected or not selected.button.Visible then return end
	if selected.managerOnly and not isManager() then return end
	if selected.area and not hasArea(selected.area) then return end
	for tabName, item in pairs(tabs) do
		local active = tabName == name
		item.page.Visible = active
		item.button.BackgroundColor3 = active and C.surface2 or C.background
		item.button.BackgroundTransparency = active and 0 or 1
		item.label.TextColor3 = active and C.text or C.muted
		if item.activeBar then item.activeBar.Visible = active end
	end
	activeUtilityPage = nil
	activeTab = name
	profile.subtitle.Text = TAB_DESCRIPTIONS[name] or "Admin controls"
	giveItemPage.Visible = name == "TOOLS" and toolsSubpage == "GIVE ITEM"
	togglePage.Visible = name == "TOOLS" and toolsSubpage == "ABILITIES"
	if name == "OVERVIEW" or name == "PLAYERS" or name == "MODERATION" or name == "TOOLS" then
		remote:FireServer("RequestSnapshot")
	elseif name == "ANNOUNCEMENT" then
		return
	end
end

setToolsSubpage = function(name)
	toolsSubpage = name
	if activeTab == "TOOLS" then
		togglePage.Visible = name == "ABILITIES"
		giveItemPage.Visible = name == "GIVE ITEM"
	end
end

local function openUtilityPage(page, request)
	if not isManager() then return end
	utilityRequestVersion += 1
	local version = utilityRequestVersion
	activeTab = "OVERVIEW"
	for name, item in pairs(tabs) do
		local active = name == "OVERVIEW"
		item.page.Visible = false
		item.button.BackgroundColor3 = active and C.surface2 or C.background
		item.button.BackgroundTransparency = active and 0 or 1
		item.label.TextColor3 = active and C.text or C.muted
		if item.activeBar then item.activeBar.Visible = active end
	end
	homePage.Visible = false
	staffPage.Visible = false
	logsPage.Visible = false
	statusPage.Visible = false
	page.Visible = true
	activeUtilityPage = page
	if request then
		task.delay(0.6, function()
			if activeUtilityPage == page and utilityRequestVersion == version then
				remote:FireServer(request)
			end
		end)
	end
end

local function refreshTabs()
	if managerShortcutGroup then managerShortcutGroup.Visible = false end
	for _, item in pairs(tabs) do
		local areaAllowed = item.area == nil or hasArea(item.area)
		local roleAllowed = not item.managerOnly or isManager()
		item.button.Visible = authorized and areaAllowed and roleAllowed
	end
	if activeUtilityPage and authorized and isManager() then
		for name, item in pairs(tabs) do
			local active = name == activeTab
			item.page.Visible = false
			item.button.BackgroundColor3 = active and C.surface2 or C.background
			item.button.BackgroundTransparency = active and 0 or 1
			item.label.TextColor3 = active and C.text or C.muted
			if item.activeBar then item.activeBar.Visible = active end
		end
		homePage.Visible = false
		activeUtilityPage.Visible = true
	elseif activeTab and tabs[activeTab] and tabs[activeTab].button.Visible then
		activateTab(activeTab)
	else
		activeTab = nil
		for _, name in ipairs({"OVERVIEW", "PLAYERS", "ANNOUNCEMENT", "MODERATION", "ADMIN_MANAGEMENT", "TOOLS", "LOGS"}) do
			local item = tabs[name]
			if item and item.button.Visible then
				activateTab(name)
				break
			end
		end
	end
end

local function sendAction(action, extra)
	local data = extra or {}
	data.action = action
	remote:FireServer("Action", data)
end

local function updateAbilityToggle(action, enabled)
	enabled = enabled == true
	local button = abilityToggleButtons[action]
	if not button then return end
	button:SetAttribute("Enabled", enabled)
	button.Text = abilityToggleLabels[action] .. "\n" .. (enabled and "ON" or "OFF")
	button.BackgroundColor3 = enabled and C.surface2 or C.surface
	button.TextColor3 = enabled and C.white or C.text
end

local function toggleAbility(action)
	local button = abilityToggleButtons[action]
	if not button then return end
	local enabled = button:GetAttribute("Enabled") ~= true
	if action == "SetFreeCamera" and enabled and spectateActive then
		setStatus("Stop spectating before opening Freecam.")
		return
	end
	updateAbilityToggle(action, enabled)
	sendAction(action, {enabled = enabled})
end

local function askConfirm(title, detail, callback)
	local previous=gui:FindFirstChild("ConfirmShade")
	if previous then previous:Destroy() end
	local shade=make("TextButton",{Name="ConfirmShade",Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),
		BackgroundTransparency=0.42,Text="",AutoButtonColor=false,ZIndex=50},gui)
	local bodyHeight=math.clamp(game:GetService("TextService"):GetTextSize(tostring(detail),21,Enum.Font.Nunito,Vector2.new(428,10000)).Y+10,76,330)
	local modalHeight=bodyHeight+170
	local modal=make("Frame",{Name="ConfirmModal",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),
		Size=UDim2.fromOffset(480,modalHeight),BackgroundColor3=C.panel,BorderSizePixel=0,Active=true,ZIndex=51},shade)
	corner(modal,16);stroke(modal,C.line)
	local sizing=make("UIScale",{Scale=1},modal)
	local function fit()
		local size=shade.AbsoluteSize
		sizing.Scale=math.min(1,math.max(0.1,(size.X-32)/480),math.max(0.1,(size.Y-32)/modalHeight))
	end
	local fitConnection=shade:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	shade.Destroying:Connect(function()fitConnection:Disconnect()end)
	task.defer(fit)
	local readableTitle=tostring(title):lower():gsub("(%a)([%w']*)",function(first,rest)return first:upper()..rest end)
	make("TextLabel",{Position=UDim2.fromOffset(26,22),Size=UDim2.new(1,-52,0,42),BackgroundTransparency=1,
		Text=readableTitle,Font=Enum.Font.Nunito,TextSize=30,TextColor3=C.text,TextXAlignment=Enum.TextXAlignment.Left,
		TextYAlignment=Enum.TextYAlignment.Center,TextWrapped=true,ZIndex=52},modal)
	make("TextLabel",{Position=UDim2.fromOffset(26,76),Size=UDim2.new(1,-52,0,bodyHeight),BackgroundTransparency=1,
		Text=tostring(detail),Font=Enum.Font.Nunito,TextSize=21,TextColor3=C.muted,TextXAlignment=Enum.TextXAlignment.Left,
		TextYAlignment=Enum.TextYAlignment.Top,TextWrapped=true,ZIndex=52},modal)
	local actions=make("Frame",{Position=UDim2.new(0,26,1,-74),Size=UDim2.new(1,-52,0,48),BackgroundTransparency=1,ZIndex=52},modal)
	local cancel=actionButton(actions,"Cancel",function()shade:Destroy()end,1)
	cancel.Size=UDim2.new(0.5,-6,1,0);cancel.TextSize=22;cancel.ZIndex=53;corner(cancel,10)
	local confirm=actionButton(actions,"Confirm",function()
		if not shade.Parent then return end
		shade:Destroy();callback()
	end,2)
	confirm.Position=UDim2.new(0.5,6,0,0);confirm.Size=UDim2.new(0.5,-6,1,0)
	confirm.TextSize=22;confirm.ZIndex=53;confirm.BackgroundColor3=C.surface2;corner(confirm,10)
end

local function selectedTarget()
	local username = (moderatorUsername and moderatorUsername.Text ~= "" and moderatorUsername.Text) or selectedName or ""
	local targetUserId = selectedUserId
	if selectedName and string.lower(username) ~= string.lower(selectedName) then
		targetUserId = nil
	end
	return {targetUserId = targetUserId, username = username}
end

local function confirmTargetAction(action, display, includeReason)
	local target = selectedTarget()
	local reason = includeReason and reasonBox and reasonBox.Text or ""
	askConfirm(display, "Apply to " .. (target.username ~= "" and target.username or "the selected player") .. "?", function()
		sendAction(action, {
			targetUserId = target.targetUserId,
			username = target.username,
			reason = reason,
			durationDays = math.clamp(math.floor(tonumber(durationBox and durationBox.Text) or 1), 1, 365),
		})
	end)
end

-- Players directory uses a separate server service; existing moderation targeting is retained.
local playersView = {}
local function renderPlayers()
	if playersView.render then playersView.render() end
end
do
	(function()
		local directory, directoryJob, service = nil, nil, nil
		local thumbnailCache = {}
		local repaint
		local feedback, feedbackUntil = nil, 0
		local function showPlayersMessage(text)
			setStatus(text)
			feedbackUntil=os.clock()+8
			if feedback then feedback.Text=tostring(text) end
		end
		local busy = false
		local detailsRow = nil
		local root = make("Frame", {Name="PlayersWorkspace",LayoutOrder=1,Size=UDim2.new(1,0,0,578),BackgroundTransparency=1,ZIndex=12},playersPage)
		local left = make("Frame",{Size=UDim2.new(0.5,-8,1,0),BackgroundColor3=C.panel,BorderSizePixel=0,ZIndex=13},root)
		local shell=make("Frame",{Position=UDim2.new(0.44,8,0,0),Size=UDim2.new(0.56,-8,1,0),BackgroundColor3=C.panel,BorderSizePixel=0,ZIndex=13},root)
		corner(left,12);corner(shell,12)
		local right=make("ScrollingFrame",{Position=UDim2.fromOffset(18,54),Size=UDim2.new(1,-36,1,-164),BackgroundTransparency=1,
			BorderSizePixel=0,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollBarThickness=3,ScrollBarImageColor3=C.dim,ZIndex=14},shell)
		make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,4)},right)
		local dock=make("Frame",{Position=UDim2.new(0,18,1,-108),Size=UDim2.new(1,-36,0,98),BackgroundTransparency=1,ZIndex=18},shell)

		local function label(parent,text,size,height,order,color)
			return make("TextLabel",{LayoutOrder=order,Size=UDim2.new(1,0,0,height),BackgroundTransparency=1,Text=text,
				Font=Enum.Font.Nunito,TextSize=size,TextColor3=color or C.text,TextXAlignment=Enum.TextXAlignment.Left,
				TextWrapped=true,ZIndex=15},parent)
		end
		make("TextLabel",{Position=UDim2.fromOffset(14,10),Size=UDim2.new(1,-28,0,32),BackgroundTransparency=1,
			Text="Players",Font=Enum.Font.Nunito,TextSize=20,TextColor3=C.text,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=14},left)
		local scope=make("TextLabel",{Position=UDim2.fromOffset(14,44),Size=UDim2.new(1,-28,0,22),BackgroundTransparency=1,
			Text="All servers · Loading...",Font=Enum.Font.Nunito,TextSize=12,TextColor3=C.muted,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=14},left)
		playerSearch=make("TextBox",{Position=UDim2.fromOffset(14,74),Size=UDim2.new(1,-28,0,38),BackgroundColor3=C.background,
			PlaceholderText="Search name or username",PlaceholderColor3=C.dim,Text="",ClearTextOnFocus=false,
			Font=Enum.Font.Nunito,TextSize=13,TextColor3=C.text,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=14},left)
		corner(playerSearch,8);stroke(playerSearch,C.line)
		make("UIPadding",{PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,8)},playerSearch)
		playerList=make("ScrollingFrame",{Position=UDim2.fromOffset(14,124),Size=UDim2.new(1,-28,1,-138),BackgroundTransparency=1,
			BorderSizePixel=0,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollBarThickness=3,ScrollBarImageColor3=C.dim,ZIndex=14},left)
		make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,8)},playerList)
		local detailTitle=label(shell,"Player details",18,38,1);detailTitle.Position=UDim2.fromOffset(18,12);detailTitle.Size=UDim2.new(1,-36,0,38)
		local profile=make("Frame",{LayoutOrder=2,Size=UDim2.new(1,0,0,100),BackgroundTransparency=1,ZIndex=14},right)
		local avatar=make("ImageLabel",{Position=UDim2.fromOffset(0,2),Size=UDim2.fromOffset(84,84),BackgroundColor3=C.surface,BorderSizePixel=0,ZIndex=15},profile)
		corner(avatar,42)
		local display=make("TextLabel",{Position=UDim2.fromOffset(96,0),Size=UDim2.new(1,-96,0,38),Text="Select a player",
			BackgroundTransparency=1,Font=Enum.Font.Nunito,TextSize=18,TextColor3=C.text,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=15},profile)
		local handle=make("TextLabel",{Position=UDim2.fromOffset(96,39),Size=UDim2.new(1,-96,0,28),Text="",BackgroundTransparency=1,
			Font=Enum.Font.Nunito,TextSize=13,TextColor3=C.muted,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=15},profile)
		local online=make("TextLabel",{Position=UDim2.fromOffset(96,70),Size=UDim2.new(1,-96,0,26),Text="",BackgroundTransparency=1,
			Font=Enum.Font.Nunito,TextSize=12,TextColor3=Color3.fromRGB(112,184,130),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=15},profile)
		local metadata=make("Frame",{LayoutOrder=3,Size=UDim2.new(1,0,0,58),BackgroundColor3=C.surface,BorderSizePixel=0,ZIndex=14},right)
		corner(metadata,8);stroke(metadata,C.line)
		local idTitle=label(metadata,"User ID",18,24,1,C.muted);idTitle.Position=UDim2.fromOffset(8,2);idTitle.Size=UDim2.new(0.32,-12,0,24)
		local idBox=make("TextBox",{Position=UDim2.fromOffset(8,27),Size=UDim2.new(0.32,-12,0,28),BackgroundTransparency=1,Text="--",
			TextEditable=false,ClearTextOnFocus=false,Font=Enum.Font.Nunito,TextSize=13,TextColor3=C.text,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=15},metadata)
		local serverTitle=label(metadata,"Server",18,24,1,C.muted);serverTitle.Position=UDim2.new(0.33,6,0,2);serverTitle.Size=UDim2.new(0.32,-12,0,24)
		local serverValue=label(metadata,"--",21,28,2);serverValue.Position=UDim2.new(0.33,6,0,27);serverValue.Size=UDim2.new(0.32,-12,0,28)
		local sessionTitle=label(metadata,"Current Session",18,24,1,C.muted);sessionTitle.Position=UDim2.new(0.66,6,0,2);sessionTitle.Size=UDim2.new(0.34,-12,0,24);sessionTitle.TextWrapped=false;sessionTitle.TextScaled=true;make("UITextSizeConstraint",{MinTextSize=14,MaxTextSize=18},sessionTitle)
		local session=label(metadata,"--",21,28,2);session.Position=UDim2.new(0.66,6,0,27);session.Size=UDim2.new(0.34,-12,0,28)
		for _,v in ipairs({0.33,0.66})do make("Frame",{Position=UDim2.new(v,0,0,8),Size=UDim2.new(0,1,1,-16),BackgroundColor3=C.line,BorderSizePixel=0,ZIndex=15},metadata)end
		label(right,"Progress",28,32,5)
		local stats=make("Frame",{LayoutOrder=6,Size=UDim2.new(1,0,0,118),BackgroundTransparency=1,ZIndex=14},right)
		make("UIGridLayout",{CellSize=UDim2.new(0.5,-4,0,56),CellPadding=UDim2.fromOffset(8,6),SortOrder=Enum.SortOrder.LayoutOrder},stats)
		local statLabels={}
		for i,definition in ipairs({{"money","Money"},{"earnedToday","Earned Today"},{"level","Level"},{"totalPlaytime","Total Playtime"}}) do
			local box=make("Frame",{LayoutOrder=i,BackgroundColor3=C.surface,BorderSizePixel=0,ZIndex=14},stats);corner(box,8)
			local text=make("TextLabel",{Position=UDim2.fromOffset(8,3),Size=UDim2.new(1,-16,1,-6),BackgroundTransparency=1,
				Text=definition[2].."\nNot available",Font=Enum.Font.Nunito,TextSize=13,TextColor3=C.text,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=15},box)
			statLabels[definition[1]]={label=text,title=definition[2]}
		end
		local xpBox=make("Frame",{LayoutOrder=7,Size=UDim2.new(1,0,0,46),BackgroundColor3=C.surface,BorderSizePixel=0,ZIndex=14},right);corner(xpBox,8)
		local xp=make("TextLabel",{Position=UDim2.fromOffset(8,2),Size=UDim2.new(1,-16,0,24),BackgroundTransparency=1,
			Text="XP · Not available",Font=Enum.Font.Nunito,TextSize=13,TextColor3=C.text,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=15},xpBox)
		local track=make("Frame",{Position=UDim2.new(0,8,1,-12),Size=UDim2.new(1,-16,0,6),BackgroundColor3=C.background,BorderSizePixel=0,ZIndex=15},xpBox);corner(track,4)
		local fill=make("Frame",{Size=UDim2.fromScale(0,1),BackgroundColor3=Color3.fromRGB(163,197,130),BorderSizePixel=0,ZIndex=16},track);corner(fill,4)
		local function button(parent,text,order,callback)
			local b=actionButton(parent,text,callback,order);b.Size=UDim2.new(1,0,0,38);b.TextSize=13;b.ZIndex=19
			if parent==dock then
				local n=order-11
				b.Position=UDim2.new((n%2)*0.5,n%2==0 and 0 or 4,0,math.floor(n/2)*52)
				b.Size=UDim2.new(0.5,-4,0,44)
				b.BackgroundColor3=C.surface
			end
			return b
		end


		local function selected()return detailsRow and detailsRow.userId==selectedUserId and detailsRow end
		local function resultAction(result)
			if type(result)~="table" then showPlayersMessage("Players service unavailable.");return end
			if result.message then showPlayersMessage(result.message) end
			if result.localSpectate then sendAction("Spectate",{targetUserId=result.localSpectate,username=result.username}) end
		end
		local function request(action)
			local row=selected()
			if not row then showPlayersMessage("Select an online player first.");return end
			if not service then showPlayersMessage("Players service is loading.");return end
			if busy then return end
			busy=true
			task.spawn(function()
				local ok,result=pcall(function()return service:InvokeServer("Action",{userId=row.userId,action=action})end)
				busy=false
				if ok then resultAction(result) else showPlayersMessage("Player action failed. Check Output.") end
			end)
		end
		button(dock,"Go to Player",11,function()request("Go")end)
		button(dock,"Bring Player",12,function()
			local row=selected();if not row then showPlayersMessage("Select a player.");return end
			local uid=row.userId
			askConfirm("BRING PLAYER","Bring @"..row.username.." to your location?",function()
				if selectedUserId==uid then request("Bring") end
			end)
		end)
		button(dock,"Spectate",13,function()request("Spectate")end)
		local dismiss=make("TextButton",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text="",Visible=false,ZIndex=30},shell)
		local moreMenu=make("Frame",{AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-18,1,-46),Size=UDim2.fromOffset(300,190),BackgroundColor3=C.background,BorderSizePixel=0,Visible=false,ZIndex=31},shell)
		corner(moreMenu,10);stroke(moreMenu,C.line)
		make("UIPadding",{PaddingTop=UDim.new(0,8),PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8)},moreMenu)
		make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,6)},moreMenu)
		local function closeMenu()moreMenu.Visible=false;dismiss.Visible=false end
		dismiss.Activated:Connect(closeMenu)
		button(dock,"More Actions",14,function()moreMenu.Visible=not moreMenu.Visible;dismiss.Visible=moreMenu.Visible end)
		button(moreMenu,"Return Player",1,function()request("Return")end)
		button(moreMenu,"Reset Character",2,function()
			local row=selected();if not row then showPlayersMessage("Select a player.");return end
			local uid=row.userId
			askConfirm("RESET CHARACTER","Respawn @"..row.username.."?",function()if selectedUserId==uid then request("Reset") end end)
		end)
		button(moreMenu,"Select User ID",3,function()
			if not selected() then return end
			idBox:CaptureFocus();idBox.CursorPosition=1;idBox.SelectionStart=#idBox.Text+1
			showPlayersMessage("Press Ctrl+C to copy the User ID.")
		end)
		button(moreMenu,"Open in Moderation",4,function()
			local row=selected();if not row then showPlayersMessage("Select a player.");return end
			if not hasArea("Moderation") then showPlayersMessage("Moderation permission required.");return end
			if moderatorUsername then moderatorUsername.Text=row.username end
			activateTab("MODERATION")
		end)
		for _,item in ipairs(moreMenu:GetChildren())do
			if item:IsA("TextButton")then
				item.ZIndex=32;item.TextXAlignment=Enum.TextXAlignment.Left;item.TextSize=22
				make("UIPadding",{PaddingLeft=UDim.new(0,10)},item)
				item.Activated:Connect(closeMenu)
			end
		end
		local spectateControls=make("Frame",{Position=UDim2.new(0,18,1,-54),Size=UDim2.new(1,-36,0,36),BackgroundTransparency=1,Visible=false,ZIndex=19},shell)
		make("UIGridLayout",{CellSize=UDim2.new(1/3,-4,1,0),CellPadding=UDim2.fromOffset(6,0),SortOrder=Enum.SortOrder.LayoutOrder},spectateControls)
		button(spectateControls,"Stop Spectating",1,function()sendAction("StopSpectate")end)
		local function stepPlayer(delta)
			local rows=directory or roster
			if #rows==0 then return end
			local at=1
			for i,row in ipairs(rows) do if row.userId==selectedUserId then at=i;break end end
			for offset=1,#rows do
				local row=rows[((at-1+delta*offset)%#rows)+1]
				if row.userId~=player.UserId then
					selectedUserId,selectedName=row.userId,row.username
					if moderatorUsername then moderatorUsername.Text=row.username end
					repaint();request("Spectate");break
				end
			end
		end
		button(spectateControls,"Previous Player",2,function()stepPlayer(-1)end)
		button(spectateControls,"Next Player",3,function()stepPlayer(1)end)
		feedback=label(shell,"",16,40,17,C.text);feedback.Position=UDim2.new(0,18,1,-154);feedback.Size=UDim2.new(1,-36,0,40);feedback.BackgroundColor3=C.background;feedback.BackgroundTransparency=0;feedback.ZIndex=25;feedback.Visible=false;corner(feedback,6)
		local function avatarImage(widget,uid)
			widget:SetAttribute("ThumbnailUserId",uid)
			widget.Image=thumbnailCache[uid] or ""
			if thumbnailCache[uid] then return end
			task.spawn(function()
				local ok,url,ready=pcall(function()return Players:GetUserThumbnailAsync(uid,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size150x150)end)
				if ok and ready then thumbnailCache[uid]=url;if widget.Parent and widget:GetAttribute("ThumbnailUserId")==uid then widget.Image=url end end
			end)
		end
		local function timeText(value)
			if type(value)~="number" then return "Not available" end
			local seconds=math.max(0,math.floor(value))
			if seconds>=3600 then return string.format("%dh %02dm",math.floor(seconds/3600),math.floor(seconds/60)%60) end
			return string.format("%dm %02ds",math.floor(seconds/60),seconds%60)
		end
		local function valueText(value)
			if type(value)~="number" then return "Not available" end
			return tostring(math.floor(value)):reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,","")
		end
		local function paintDetails()
			local row=detailsRow
			if not row then
				display.Text=selectedUserId and "Player offline / unavailable" or "Select a player"
				handle.Text="";online.Text="";avatar.Image="";idBox.Text="--";serverValue.Text="--";session.Text="--"
			else
				display.Text=row.displayName or row.username;handle.Text="@"..row.username;online.Text="● Online"
				avatarImage(avatar,row.userId);idBox.Text=tostring(row.userId)
				local elapsed=row.joinedAt and os.time()-row.joinedAt or row.playtime
				serverValue.Text=(row.serverLabel or "This server"):gsub("^Server ","");session.Text=timeText(elapsed)
			end
			local progress=row and row.progress or {}
			for key,entry in pairs(statLabels) do
				entry.label.Text=entry.title.."\n"..(key=="totalPlaytime" and timeText(progress[key]) or valueText(progress[key]))
			end
			if type(progress.xp)=="number" and type(progress.xpNeeded)=="number" and progress.xpNeeded>0 then
				xp.Text="XP · "..valueText(progress.xp).." / "..valueText(progress.xpNeeded)
				fill.Size=UDim2.fromScale(math.clamp(progress.xp/progress.xpNeeded,0,1),1)
			else xp.Text="XP · Not available";fill.Size=UDim2.fromScale(0,1) end
			spectateControls.Visible=spectateActive
			dock.Position=UDim2.new(0,18,1,spectateActive and -150 or -108)
			right.Size=UDim2.new(1,-36,1,spectateActive and -206 or -164)
			feedback.Visible=os.clock()<feedbackUntil and feedback.Text~=""
		end
		local function clearRows(list)
			if not list then return end
			for _,child in ipairs(list:GetChildren()) do
				if child:IsA("TextButton") or child:IsA("TextLabel") then child:Destroy() end
			end
		end
		repaint=function()
			local rows=directory or roster
			scope.Text="All servers · "..#rows.." online"..(not directory and " · Loading directory" or "")
			clearRows(playerList)
			local query=playerSearch.Text:lower()
			local shown=0
			detailsRow=nil
			for _,row in ipairs(rows) do
				if row.userId==selectedUserId then detailsRow=row end
				if query=="" or (row.username or ""):lower():find(query,1,true) or (row.displayName or ""):lower():find(query,1,true) then
					shown+=1
					local b=make("TextButton",{LayoutOrder=shown,Size=UDim2.new(1,-5,0,98),BackgroundColor3=row.userId==selectedUserId and C.surface2 or C.surface,
						Text="",AutoButtonColor=false,BorderSizePixel=0,ZIndex=15},playerList);corner(b,9)
					if row.userId==selectedUserId then stroke(b,Color3.fromRGB(163,197,130)) end
					local thumb=make("ImageLabel",{Position=UDim2.fromOffset(8,11),Size=UDim2.fromOffset(60,60),BackgroundColor3=C.panel,BorderSizePixel=0,ZIndex=16},b)
					corner(thumb,30);avatarImage(thumb,row.userId)
					make("TextLabel",{Position=UDim2.fromOffset(78,6),Size=UDim2.new(1,-86,0,32),BackgroundTransparency=1,Text=row.displayName or row.username,
						Font=Enum.Font.Nunito,TextSize=29,TextColor3=C.text,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=16},b)
					make("TextLabel",{Position=UDim2.fromOffset(78,39),Size=UDim2.new(1,-86,0,26),BackgroundTransparency=1,Text="@"..row.username,
						Font=Enum.Font.Nunito,TextSize=22,TextColor3=C.muted,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=16},b)
					make("TextLabel",{Position=UDim2.fromOffset(78,66),Size=UDim2.new(1,-86,0,23),BackgroundTransparency=1,Text=row.serverLabel or "This server",
						Font=Enum.Font.Nunito,TextSize=20,TextColor3=C.muted,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=16},b)
					b.Activated:Connect(function()
						selectedUserId,selectedName=row.userId,row.username
						if moderatorUsername then moderatorUsername.Text=row.username end
						repaint()
					end)
				end
			end
			if shown==0 then label(playerList,"No matching online players",16,42,1,C.dim) end
			-- Existing Moderation page keeps its selected target, now including directory results.
			if moderationList then
				clearRows(moderationList)
				local q=moderationSearch and moderationSearch.Text:lower() or ""
				for i,row in ipairs(rows) do
					if q=="" or row.username:lower():find(q,1,true) or (row.displayName or ""):lower():find(q,1,true) then
						local b=actionButton(moderationList,(row.displayName or row.username).."  @"..row.username,function()
							selectedUserId,selectedName=row.userId,row.username
							if moderatorUsername then moderatorUsername.Text=row.username end
							repaint()
						end,i)
						b.Size=UDim2.new(1,-4,0,36)
					end
				end
			end
			if moderationSelectedInfo then moderationSelectedInfo.Text=detailsRow and ("@"..detailsRow.username.." · "..(detailsRow.serverLabel or "This server")) or "Select a player." end
			if itemTargetLabel then itemTargetLabel.Text=detailsRow and ("Target: @"..detailsRow.username) or "Target: select a player" end
			paintDetails()
		end
		local function fitWorkspace()
			local logicalWidth=root.AbsoluteSize.X/math.max(panelScale.Scale,0.01)
			if logicalWidth<620 then
				root.Size=UDim2.new(1,0,0,1050)
				left.Position=UDim2.fromOffset(0,0);left.Size=UDim2.new(1,0,0,410)
				shell.Position=UDim2.fromOffset(0,424);shell.Size=UDim2.new(1,0,0,620)
			else
				root.Size=UDim2.new(1,0,0,578)
				left.Position=UDim2.fromOffset(0,0);left.Size=UDim2.new(0.44,-8,1,0)
				shell.Position=UDim2.new(0.44,8,0,0);shell.Size=UDim2.new(0.56,-8,1,0)
			end
		end
		root:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitWorkspace)
		task.defer(fitWorkspace)
		playersView.render=repaint
		playerSearch:GetPropertyChangedSignal("Text"):Connect(repaint)
		task.spawn(function()
			service=ReplicatedStorage:WaitForChild("PalmVillePlayersDirectory",20)
			if not service then scope.Text="Add PalmVillePlayersServer to ServerScriptService";return end
			local resumed=false
			local resumeAttempts=0
			while gui.Parent do
				if authorized and hasArea("Players") then
					if not resumed and resumeAttempts<12 then
						resumeAttempts+=1
						local ok,result=pcall(function()return service:InvokeServer("Resume")end)
						if ok and result then
							if result.localSpectate then resultAction(result);resumed=true end
						end
					end
					if panel.Visible and not minimized and (activeTab=="PLAYERS" or activeTab=="MODERATION") then
						local ok,result=pcall(function()return service:InvokeServer("List")end)
						if ok and type(result)=="table" and result.ok then directory=result.players;directoryJob=result.jobId;repaint()
						elseif ok and result and result.message then scope.Text=result.message end
					end
				end
				task.wait(10)
			end
		end)
		task.spawn(function()
			while gui.Parent do
				if panel.Visible and activeTab=="PLAYERS" then
					paintDetails()
					if feedback and os.clock()>feedbackUntil then feedback.Text="" end
				end
				task.wait(1)
			end
		end)
		repaint()
	end)()
end

-- Overview analytics. Server data comes from the separate PalmVilleAnalyticsServer script.
local function updateDashboardMetrics() end
local function renderOverviewStaff() end
-- Keep analytics locals in their own function scope (Luau has a per-function local limit).
do
	(function()
		local analyticsData = nil
		local analyticsMetric = "visits"
		local selectedDay = 7
		local statValues = {}
		local filters = {}
		local dateButtons = {}
		local chartObjects = {}
		local repaintAnalytics
		local statRow = make("Frame", {Name = "OverviewStats", LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 116), BackgroundTransparency = 1, ZIndex = 12}, homePage)
		make("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder}, statRow)
		local statDefinitions = {
			{"online", "Online\nPlayers", "PLAYERS"}, {"visits", "Total\nVisits", "SPECTATE"},
			{"unique", "Unique\nPlayers", "PLAYERS"}, {"peak", "All-Time\nPeak", "PERFORMANCE"},
			{"servers", "Active\nServers", "TOGGLE"},
		}
		local function numberText(value)
			if value == nil then return "--" end
			local s = tostring(math.floor(value))
			local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
			return formatted
		end
		for index, definition in ipairs(statDefinitions) do
			local card = make("Frame", {LayoutOrder = index, Size = UDim2.new(0.2, -8, 1, 0),
				BackgroundColor3 = C.surface, BorderSizePixel = 0, ZIndex = 13}, statRow)
			corner(card, 12)
						make("TextLabel", {Position = UDim2.fromOffset(12, 10), Size = UDim2.new(1, -24, 0, 44),
				BackgroundTransparency = 1, Text = definition[2], Font = Enum.Font.Nunito,
				TextColor3 = C.text, TextSize = 13, TextScaled = true, ZIndex = 14}, card)
			statValues[definition[1]] = make("TextLabel", {Position = UDim2.new(0, 8, 0, 57),
				Size = UDim2.new(1, -16, 0, 46), BackgroundTransparency = 1, Text = "--",
				Font = Enum.Font.Nunito, TextColor3 = C.text, TextSize = 28, TextScaled = true, ZIndex = 14}, card)
			make("UITextSizeConstraint", {MinTextSize = 14, MaxTextSize = 34}, statValues[definition[1]])
		end
		local activity = make("Frame", {Name = "DailyActivity", LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 430), BackgroundColor3 = C.panel, BorderSizePixel = 0, ZIndex = 12}, homePage)
		corner(activity, 14)
		stroke(activity, C.line, 0.35)
		make("TextLabel", {Position = UDim2.fromOffset(18, 12), Size = UDim2.new(0.65, -18, 0, 40),
			BackgroundTransparency = 1, Text = "Daily Activity", Font = Enum.Font.Nunito,
			TextSize = 30, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13}, activity)
		local rangeLabel = make("TextLabel", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 18),
			Size = UDim2.new(0.27, 0, 0, 28), BackgroundColor3 = Color3.fromRGB(163, 197, 130),
			Text = "Last 7 days", Font = Enum.Font.Nunito, TextSize = 16, TextColor3 = C.background, ZIndex = 13}, activity)
		corner(rangeLabel, 14)
		local filterRow = make("Frame", {Position = UDim2.fromOffset(18, 64), Size = UDim2.new(1, -36, 0, 36),
			BackgroundTransparency = 1, ZIndex = 13}, activity)
		make("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder}, filterRow)
		local metricDefinitions = {{"visits", "Visits"}, {"unique", "Unique Players"}, {"newPlayers", "New Players"}, {"peak", "Daily Peak"}}
		for index, definition in ipairs(metricDefinitions) do
			local key = definition[1]
			local button = make("TextButton", {LayoutOrder = index, Size = UDim2.new(0.25, -6, 1, 0),
				BackgroundColor3 = C.background, Text = definition[2], Font = Enum.Font.Nunito,
				TextSize = 17, TextScaled = true, TextColor3 = C.text, AutoButtonColor = false, ZIndex = 14}, filterRow)
			corner(button, 8); stroke(button, C.line)
			make("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6)}, button)
			make("UITextSizeConstraint", {MinTextSize = 9, MaxTextSize = 17}, button)
			button.Activated:Connect(function() analyticsMetric = key; repaintAnalytics() end)
			filters[key] = button
		end
		local chart = make("Frame", {Position = UDim2.fromOffset(55, 126), Size = UDim2.new(1, -83, 0, 192),
			BackgroundTransparency = 1, ZIndex = 13}, activity)
		local summary = make("TextLabel", {Position = UDim2.new(0, 18, 1, -80), Size = UDim2.new(1, -36, 0, 42),
			BackgroundColor3 = C.surface2, Text = "Waiting for analytics...", Font = Enum.Font.Nunito,
			TextSize = 15, TextWrapped = true, TextColor3 = C.text, ZIndex = 14}, activity)
		corner(summary, 12)
		make("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}, summary)
		local analyticsFooter = make("TextLabel", {Position = UDim2.new(0, 18, 1, -30), Size = UDim2.new(1, -36, 0, 22),
			BackgroundTransparency = 1, Text = "Resets at 12 AM PHT", Font = Enum.Font.Nunito,
			TextSize = 12, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 14}, activity)
		local function chartMake(className, props)
			props.ZIndex = props.ZIndex or 14
			local object = make(className, props, chart)
			table.insert(chartObjects, object)
			return object
		end
		local function lineBetween(x1, y1, x2, y2, color, thickness)
			local dx, dy = x2 - x1, y2 - y1
			chartMake("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset((x1+x2)/2, (y1+y2)/2),
				Size = UDim2.fromOffset(math.sqrt(dx*dx+dy*dy), thickness or 3), Rotation = math.deg(math.atan2(dy, dx)),
				BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 16})
		end
		repaintAnalytics = function()
			for _, object in ipairs(chartObjects) do object:Destroy() end
			table.clear(chartObjects)
			local data = analyticsData
			local days = data and data.days or {}
			local stale = data and data.updatedAt and os.time() - data.updatedAt > 90
			for key, label in pairs(statValues) do label.Text = data and data.ready and numberText(data[key]) or "--" end
			for key, button in pairs(filters) do
				button.BackgroundColor3 = analyticsMetric == key and Color3.fromRGB(163, 197, 130) or C.background
				button.TextColor3 = analyticsMetric == key and C.background or C.text
			end
			-- AbsoluteSize includes the panel UIScale; drawing offsets use unscaled UI pixels.
			local uiScale = math.max(panelScale.Scale, 0.01)
			local width, height = chart.AbsoluteSize.X / uiScale, chart.AbsoluteSize.Y / uiScale
			if width <= 0 or height <= 0 then return end
			local maximum = 1
			for _, day in ipairs(days) do if day.hasData then maximum = math.max(maximum, day[analyticsMetric] or 0) end end
			local step = 10 ^ math.floor(math.log10(maximum))
			maximum = math.max(3, math.ceil(maximum / (3 * step)) * 3 * step)
			for tick = 0, 3 do
				local y = height - height * tick / 3
				chartMake("Frame", {Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 1),
					BackgroundColor3 = C.line, BackgroundTransparency = 0.3, BorderSizePixel = 0})
				chartMake("TextLabel", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromOffset(-8, y),
					Size = UDim2.fromOffset(43, 22), BackgroundTransparency = 1, Text = numberText(maximum * tick / 3),
					Font = Enum.Font.Nunito, TextSize = 13, TextColor3 = C.muted})
			end
			local selected = days[selectedDay]
			local prevX, prevY = nil, nil
			local sage = Color3.fromRGB(177, 210, 132)
			for index = 1, 7 do
				local day = days[index]
				local x = 12 + (width - 24) * (index - 1) / 6
				local label = day and day.label or "--"
				local button = chartMake("TextButton", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(x, height + 8),
					Size = UDim2.fromOffset(math.max(28, (width-24)/7), 26), BackgroundTransparency = 1, Text = label,
					Font = Enum.Font.Nunito, TextSize = 13, TextScaled = true,
					TextColor3 = index == selectedDay and sage or C.text})
				make("UITextSizeConstraint", {MinTextSize = 8, MaxTextSize = 13}, button)
				button.Activated:Connect(function() selectedDay = index; repaintAnalytics() end)
				if day and day.hasData then
					local y = height * (1 - (day[analyticsMetric] or 0) / maximum)
					if prevX then
						-- Translucent vertical strips fill the area under each measured segment.
						local slices = math.max(1, math.ceil((x - prevX) / 6))
						for slice = 0, slices - 1 do
							local t = (slice + 0.5) / slices
							local top = prevY + (y - prevY) * t
							chartMake("Frame", {Position = UDim2.fromOffset(prevX + (x-prevX)*slice/slices, top),
								Size = UDim2.fromOffset((x-prevX)/slices + 1, math.max(0, height-top)),
								BackgroundColor3 = sage, BackgroundTransparency = 0.82, BorderSizePixel = 0, ZIndex = 13})
						end
						lineBetween(prevX, prevY, x, y, sage, 3)
					end
					local dot = chartMake("TextButton", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y),
						Size = UDim2.fromOffset(index == selectedDay and 14 or 10, index == selectedDay and 14 or 10),
						BackgroundColor3 = sage, BorderSizePixel = 0, Text = "", ZIndex = 18})
					corner(dot, 20)
					if index == selectedDay then stroke(dot, C.text, 0) end
					dot.Activated:Connect(function() selectedDay = index; repaintAnalytics() end)
					if index == selectedDay then
						for dash = 0, math.floor(height/12) do
							chartMake("Frame", {Position = UDim2.fromOffset(x, dash*12), Size = UDim2.fromOffset(1, 6),
								BackgroundColor3 = C.muted, BorderSizePixel = 0, ZIndex = 15})
						end
					end
					prevX, prevY = x, y
				else
					prevX, prevY = nil, nil -- Missing history is not drawn as zero.
				end
			end
			if not data or not data.ready then
				summary.Text = data and data.message or "Waiting for analytics server..."
			elseif selected and selected.hasData then
				local prefix = selected.key == data.today and "Today · " or ""
				local text = prefix .. selected.label .. " — Visits " .. numberText(selected.visits)
					.. " · Unique " .. numberText(selected.unique) .. " · New " .. numberText(selected.newPlayers)
					.. " · Daily Peak " .. numberText(selected.peak)
				local previous = days[selectedDay - 1]
				-- Compare completed days only, rather than a partial today against all of yesterday.
				if previous and previous.hasData and selected.key ~= data.today then
					local delta = selected[analyticsMetric] - previous[analyticsMetric]
					text ..= delta == 0 and " · same as previous day" or (" · " .. (delta > 0 and "+" or "") .. numberText(delta) .. " vs previous day")
				end
				summary.Text = text
			else
				summary.Text = (selected and selected.label or "Selected day") .. " · No tracked data"
			end
			local note = data and data.studio and "Studio test data · " or ""
			if stale then note ..= "Update delayed · " end
			analyticsFooter.Text = note .. "Resets at 12 AM PHT"
		end
		chart:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() task.defer(repaintAnalytics) end)
		panelScale:GetPropertyChangedSignal("Scale"):Connect(function() task.defer(repaintAnalytics) end)
		task.spawn(function()
			local analyticsRemote = ReplicatedStorage:WaitForChild("PalmVilleOverviewAnalytics", 20)
			if not analyticsRemote then
				analyticsData = {ready = false, message = "Add PalmVilleAnalyticsServer to ServerScriptService."}
				repaintAnalytics()
				return
			end
			while gui.Parent do
				if authorized and panel.Visible and not minimized and activeTab == "OVERVIEW" then
					local ok, result = pcall(function() return analyticsRemote:InvokeServer() end)
					if ok and type(result) == "table" then
						local oldKey = analyticsData and analyticsData.days and analyticsData.days[selectedDay] and analyticsData.days[selectedDay].key
						analyticsData = result
						selectedDay = 7
						if oldKey and result.days then
							for index, day in ipairs(result.days) do if day.key == oldKey then selectedDay = index end end
						end
					elseif not analyticsData then
						analyticsData = {ready = false, message = "Analytics unavailable. Check server access and Output."}
					end
					repaintAnalytics()
				end
				task.wait(15)
			end
		end)

	end)()
end

-- Announcements composer.
do
	(function()
		local audience = "This Server"
		local root = make("Frame", {
			Name = "AnnouncementsWorkspace",
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 580),
			BackgroundTransparency = 1,
		}, announcementPage)
		local compose = make("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = C.panel,
			BorderSizePixel = 0,
			ZIndex = 13,
		}, root)
		corner(compose, 12)
		stroke(compose, C.line, 0.35)
		local function title(parent, text, y, size, height)
			return make("TextLabel", {
				Position = UDim2.fromOffset(20, y),
				Size = UDim2.new(1, -40, 0, height),
				BackgroundTransparency = 1,
				Text = text,
				Font = Enum.Font.Nunito,
				TextSize = size,
				TextColor3 = C.text,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				ZIndex = 14,
			}, parent)
		end
		title(compose, "New announcement", 18, 22, 30)
		title(compose, "Write a message for the selected audience.", 48, 12, 22).TextColor3 = C.muted
		title(compose, "MESSAGE", 88, 11, 20).TextColor3 = C.muted
		announcementBox = make("TextBox", {
			Position = UDim2.fromOffset(20, 112),
			Size = UDim2.new(1, -40, 0, 168),
			BackgroundColor3 = C.background,
			BorderSizePixel = 0,
			Text = "",
			PlaceholderText = "Write your announcement...",
			PlaceholderColor3 = C.dim,
			TextColor3 = C.text,
			Font = Enum.Font.Nunito,
			TextSize = 16,
			MultiLine = true,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			ClearTextOnFocus = false,
			ZIndex = 14,
		}, compose)
		corner(announcementBox, 9)
		stroke(announcementBox, C.line)
		make("UIPadding", {
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 13),
			PaddingRight = UDim.new(0, 13),
		}, announcementBox)
		local count = title(compose, "0 / 280", 284, 11, 20)
		count.TextXAlignment = Enum.TextXAlignment.Right
		local function updateCount()
			count.Text = #announcementBox.Text .. " / 280"
			count.TextColor3 = #announcementBox.Text > 280 and Color3.fromRGB(240, 140, 130) or C.dim
		end
		announcementBox:GetPropertyChangedSignal("Text"):Connect(updateCount)
		title(compose, "AUDIENCE", 324, 11, 20).TextColor3 = C.muted
		local audienceRow = make("Frame", {
			Position = UDim2.fromOffset(20, 350),
			Size = UDim2.new(1, -40, 0, 48),
			BackgroundTransparency = 1,
			ZIndex = 14,
		}, compose)
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		}, audienceRow)
		local serverButton
		local allButton
		local function refreshAudienceButtons()
			for _, item in ipairs({
				{button = serverButton, value = "This Server"},
				{button = allButton, value = "All Servers"},
			}) do
				if item.button then
					local selected = audience == item.value
					item.button.BackgroundColor3 = selected and C.surface2 or C.surface
					item.button.BackgroundTransparency = selected and 0 or 0.1
					item.button.TextColor3 = selected and C.white or C.muted
					item.button.Text = (selected and "✓  " or "") .. string.upper(item.value)
					local outline = item.button:FindFirstChildOfClass("UIStroke")
					if outline then
						outline.Color = selected and Color3.fromRGB(112, 184, 130) or C.line
						outline.Thickness = selected and 2 or 1
						outline.Transparency = selected and 0 or 0.2
					end
				end
			end
		end
		local function audienceButton(label, order, callback)
			local button = make("TextButton", {
				Name = label:gsub("%s", "") .. "Audience",
				LayoutOrder = order,
				Size = UDim2.new(0.5, -5, 1, 0),
				BackgroundColor3 = C.surface,
				BorderSizePixel = 0,
				Text = string.upper(label),
				TextColor3 = C.muted,
				Font = Enum.Font.Nunito,
				TextSize = 13,
				AutoButtonColor = false,
				ZIndex = 15,
			}, audienceRow)
			corner(button, 9)
			stroke(button, C.line, 0.2)
			button.Activated:Connect(callback)
			button.MouseEnter:Connect(function()
				if audience ~= label then button.BackgroundColor3 = C.surface2 end
			end)
			button.MouseLeave:Connect(refreshAudienceButtons)
			return button
		end
		serverButton = audienceButton("This Server", 1, function()
			audience = "This Server"
			refreshAudienceButtons()
		end)
		allButton = audienceButton("All Servers", 2, function()
			audience = "All Servers"
			refreshAudienceButtons()
		end)
		refreshAudienceButtons()
		local feedback = title(compose, "Only Owner, Dev, and Head Admin can send announcements.", 410, 12, 34)
		feedback.TextColor3 = C.muted
		local function validate()
			if not hasArea("Announcements") then
				feedback.Text = "Announcement permission required."
				return nil
			end
			local message = announcementBox.Text
			if message:gsub("%s", "") == "" then
				feedback.Text = "Type a message first."
				return nil
			end
			if #message > 280 or not utf8.len(message) then
				feedback.Text = "Shorten your message to fit the 280-character limit."
				return nil
			end
			return message
		end
		local previewButton = actionButton(compose, "PREVIEW", function()
			local message = validate()
			if not message then return end
			announcementUI.show({role = role, by = role == "MASTER DEVELOPER" and "Lupin" or (player.DisplayName ~= "" and player.DisplayName or player.Name), text = message, duration = 8}, true)
			feedback.Text = "Preview is visible only to you."
		end, 1)
		previewButton.Name = "PreviewAnnouncement"
		previewButton.Position = UDim2.new(0, 20, 0, 466)
		previewButton.Size = UDim2.fromOffset(150, 42)
		previewButton.TextSize = 13
		local sendButton = actionButton(compose, "SEND ANNOUNCEMENT", function()
			local message = validate()
			if not message then return end
			local target = audience
			askConfirm("Send announcement", target .. "\n\n" .. message, function()
				sendAction("Announce", {message = message, audience = target})
				feedback.Text = "Sending to " .. target .. "..."
			end)
		end, 2)
		sendButton.Name = "SendAnnouncement"
		sendButton.Position = UDim2.new(1, -210, 0, 466)
		sendButton.Size = UDim2.fromOffset(190, 42)
		sendButton.TextSize = 13
		sendButton.BackgroundColor3 = C.surface2
		sendButton.MouseLeave:Connect(function()
			sendButton.BackgroundColor3 = C.surface2
		end)
		function announcementUI.sent(data)
			if announcementBox.Text == data.message then announcementBox.Text = "" end
			feedback.Text = data.delivered and "Announcement sent." or "Shown in this server; all-server delivery failed."
		end
		function announcementUI.notice(message)
			if activeTab == "ANNOUNCEMENT" then feedback.Text = tostring(message) end
		end
	end)()
end

-- give item

-- give item
actionButton(giveItemPage, "BACK TO TOOLS", function() setToolsSubpage("ABILITIES") end, 0)
section(giveItemPage, "GIVE ITEM", 1)
itemCodeBox = inputBox(giveItemPage, "Item code", 2)
itemCodeBox.Text = "RICE_SEED"
itemTargetLabel = textLabel(giveItemPage, "Target: select a player", 32, 3, {TextColor3 = C.muted, TextSize = 11})
local targetRow
targetRow, itemTargetButtons = buttonRow(giveItemPage, {"PLAYER", "ALL", "SELF"}, function(label)
	itemTargetMode = label == "PLAYER" and "Player" or label == "ALL" and "All" or "Self"
	for name, button in pairs(itemTargetButtons) do
		local active = (name == "PLAYER" and itemTargetMode == "Player") or (name == "ALL" and itemTargetMode == "All") or (name == "SELF" and itemTargetMode == "Self")
		button.BackgroundColor3 = active and C.surface2 or C.surface
	end
end, 4)
targetRow.Size = UDim2.new(1, 0, 0, UserInputService.TouchEnabled and 44 or 38)
for name, button in pairs(itemTargetButtons) do
	button.BackgroundColor3 = name == "PLAYER" and C.surface2 or C.surface
end
itemAmountBox = inputBox(giveItemPage, "Amount", 5)
itemAmountBox.Text = "1"
actionButton(giveItemPage, "GIVE ITEM", function()
	if itemTargetMode == "Player" and not selectedUserId then
		setStatus("Select a player first.")
		return
	end
	sendAction("GiveItem", {
		itemCode = itemCodeBox.Text,
		amount = tonumber(itemAmountBox.Text),
		targetMode = itemTargetMode,
		targetUserId = selectedUserId,
		username = selectedName,
	})
end, 6)

-- toggle
actionButton(togglePage, "GIVE ITEM", function() setToolsSubpage("GIVE ITEM") end, 0)
section(togglePage, "ABILITIES", 1)
local abilityGrid = make("Frame", {
	Name = "AbilityToggles",
	LayoutOrder = 2,
	Size = UDim2.new(1, 0, 0, UserInputService.TouchEnabled and 162 or 138),
	BackgroundTransparency = 1,
	ZIndex = 12,
}, togglePage)
make("UIGridLayout", {
	CellSize = UDim2.new(0.5, -5, 0, UserInputService.TouchEnabled and 48 or 42),
	CellPadding = UDim2.fromOffset(8, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, abilityGrid)
for index, action in ipairs({"SetNoclip", "SetFly", "SetFreeCamera", "SetInvisible", "SetAdminTitle"}) do
	local button = actionButton(abilityGrid, abilityToggleLabels[action] .. "\nOFF", function()
		toggleAbility(action)
	end, index)
	abilityToggleButtons[action] = button
	updateAbilityToggle(action, false)
end
section(togglePage, "MOVEMENT SPEED", 3)
speedBox = inputBox(togglePage, "Speed (8–120)", 4)
speedBox.Text = tostring(freeCamSpeed)
speedBox:GetPropertyChangedSignal("Text"):Connect(function()
	local value = tonumber(speedBox.Text)
	if value then freeCamSpeed = math.clamp(value, 8, 120) end
end)
textLabel(togglePage, "Fly: WASD + Space/Ctrl. Touch controls appear while active.", 28, 5, {TextColor3 = C.dim, TextSize = 10})

-- moderation
local function moderationCard(titleText, descriptionText, order)
	local card = make("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.panel,
		BorderSizePixel = 0,
		ZIndex = 12,
	}, moderationPage)
	corner(card, 10)
	stroke(card, C.line, 0.35)
	make("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}, card)
	make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
	}, card)
	local heading = textLabel(card, titleText, 22, 1, {TextSize = 16, TextColor3 = C.text})
	local description = textLabel(card, descriptionText, 28, 2, {TextSize = 11, TextColor3 = C.muted})
	return card
end

local targetCard = moderationCard("TARGET PLAYER", "Select an online player for moderation. Enter a username only for offline unban or history.", 1)
moderationSearch = inputBox(targetCard, "Search online players...", 3)
moderationList = make("ScrollingFrame", {
	LayoutOrder = 4,
	Size = UDim2.new(1, 0, 0, 126),
	BackgroundColor3 = C.background,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ScrollBarThickness = 3,
	ScrollBarImageColor3 = C.dim,
	ZIndex = 13,
}, targetCard)
corner(moderationList, 7)
stroke(moderationList, C.line, 0.25)
make("UIPadding", {
	PaddingTop = UDim.new(0, 5),
	PaddingBottom = UDim.new(0, 5),
	PaddingLeft = UDim.new(0, 5),
	PaddingRight = UDim.new(0, 5),
}, moderationList)
make("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4)}, moderationList)
moderationSelectedInfo = textLabel(targetCard, "No player selected.", 22, 5, {
	TextColor3 = Color3.fromRGB(112, 184, 130),
	TextSize = 11,
})
moderatorUsername = inputBox(targetCard, "Username for offline unban / history...", 6)
reasonBox = inputBox(targetCard, "Reason (required for warn, kick, and bans)...", 7)
reasonBox.Size = UDim2.new(1, 0, 0, 38)

local function requireOnlineModerationTarget()
	if not selectedUserId then
		setStatus("Select an online player from the target list first.")
		return nil
	end
	return selectedTarget()
end

local function confirmOnlineAction(action, label, includeReason)
	if not requireOnlineModerationTarget() then return end
	if includeReason and reasonBox.Text:gsub("%s", "") == "" then
		setStatus("Enter a reason before using " .. label .. ".")
		return
	end
	confirmTargetAction(action, label, includeReason)
end

moderationSearch:GetPropertyChangedSignal("Text"):Connect(renderPlayers)
moderatorUsername:GetPropertyChangedSignal("Text"):Connect(function()
	if selectedName and string.lower(moderatorUsername.Text) ~= string.lower(selectedName) then
		selectedUserId, selectedName = nil, nil
		renderPlayers()
	end
end)

local movementCard = moderationCard("MOVEMENT & MONITORING", "Move or observe an online player. Select a target first.", 2)
buttonRow(movementCard, {"BRING", "FREEZE", "UNFREEZE"}, function(label)
	local target = requireOnlineModerationTarget()
	if not target then return end
	if label == "BRING" then
		askConfirm("BRING PLAYER", "Bring @" .. target.username .. " to your location?", function()
			sendAction("Bring", target)
		end)
	elseif label == "FREEZE" then
		sendAction("Freeze", target)
	else
		sendAction("Unfreeze", target)
	end
end, 3)
buttonRow(movementCard, {"SPECTATE", "WATCH SCREEN", "STOP SPECTATING"}, function(label)
	if label == "STOP SPECTATING" then
		sendAction("StopSpectate")
		return
	end
	local target = requireOnlineModerationTarget()
	if not target then return end
	if label == "WATCH SCREEN" then
		sendAction("WatchScreen", target)
	else
		sendAction("Spectate", target)
	end
end, 4)

local disciplineCard = moderationCard("DISCIPLINE", "Warnings, chat restrictions, and removal from the current server.", 3)
buttonRow(disciplineCard, {"WARN PLAYER", "TOGGLE CHAT MUTE", "KICK PLAYER"}, function(label)
	if label == "WARN PLAYER" then
		confirmOnlineAction("Warn", "WARN PLAYER", true)
	elseif label == "TOGGLE CHAT MUTE" then
		confirmOnlineAction("MuteChat", "TOGGLE CHAT MUTE", false)
	else
		confirmOnlineAction("Kick", "KICK PLAYER", true)
	end
end, 3)

local banCard = moderationCard("BAN MANAGEMENT", "Temporary and permanent experience bans. Unban accepts an offline username.", 4)
durationBox = inputBox(banCard, "Temporary ban duration in days (1–365)", 3)
durationBox.Text = "1"
buttonRow(banCard, {"TEMPORARY BAN", "PERMANENT BAN", "UNBAN"}, function(label)
	if label == "UNBAN" then
		local target = selectedTarget()
		if target.username == "" and not target.targetUserId then
			setStatus("Enter or select a username to unban.")
			return
		end
		askConfirm("UNBAN ACCOUNT", "Unban " .. (target.username ~= "" and ("@" .. target.username) or "the selected account") .. "?", function()
			sendAction("Unban", {
				targetUserId = target.targetUserId,
				username = target.username,
				reason = reasonBox.Text,
			})
		end)
		return
	end
	if not requireOnlineModerationTarget() then return end
	if reasonBox.Text:gsub("%s", "") == "" then
		setStatus("Enter a reason before issuing a ban.")
		return
	end
	if label == "TEMPORARY BAN" then
		confirmOnlineAction("TempBan", "TEMPORARY BAN", true)
	else
		confirmOnlineAction("PermanentBan", "PERMANENT BAN", true)
	end
end, 4)

local historyCard = moderationCard("MODERATION HISTORY", "Review saved moderation actions for the selected or entered account.", 5)
actionButton(historyCard, "LOAD MODERATION HISTORY", function()
	local target = selectedTarget()
	if target.username == "" and not target.targetUserId then
		setStatus("Select a player or enter a username first.")
		return
	end
	sendAction("ModerationHistory", target)
end, 3)
local historyLabel = textLabel(historyCard, "No history loaded.", 38, 4, {
	TextColor3 = C.muted,
	TextSize = 11,
	TextYAlignment = Enum.TextYAlignment.Top,
})

-- staff management

-- staff management
actionButton(staffPage, "OVERVIEW", function() activateTab("OVERVIEW") end, 0)
section(staffPage, "ADD STAFF", 1)
staffUsername = inputBox(staffPage, "Roblox username", 2)
buttonRow(staffPage, {"HEAD ADMIN", "ADMIN"}, function(label)
	local newRole = label == "HEAD ADMIN" and "HEAD ADMIN" or "ADMIN"
	if staffUsername.Text == "" then setStatus("Enter a username first."); return end
	askConfirm("ASSIGN " .. newRole, "Resolve and add " .. staffUsername.Text .. " as " .. newRole .. "?", function()
		sendAction("AddStaff", {username = staffUsername.Text, role = newRole})
	end)
end, 3)
buttonRow(staffPage, {"MODERATOR", "HELPER"}, function(label)
	if staffUsername.Text == "" then setStatus("Enter a username first."); return end
	askConfirm("ASSIGN " .. label, "Resolve and add " .. staffUsername.Text .. " as " .. label .. "?", function()
		sendAction("AddStaff", {username = staffUsername.Text, role = label})
	end)
end, 4)
section(staffPage, "AUTHORIZED STAFF", 5)
staffList = make("ScrollingFrame", {
	LayoutOrder = 6,
	Size = UDim2.new(1, 0, 0, 144),
	BackgroundColor3 = C.background,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 2,
	ScrollBarImageColor3 = C.dim,
	ZIndex = 13,
}, staffPage)
corner(staffList, 5)
stroke(staffList, C.line)
make("UIPadding", {PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4)}, staffList)
make("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3)}, staffList)
local removeStaffButton = actionButton(staffPage, "REMOVE SELECTED STAFF", function()
	if not selectedStaffId then setStatus("Select an assignable staff account."); return end
	local chosen
	for _, row in ipairs(staffRows) do if row.userId == selectedStaffId then chosen = row break end end
	if not chosen then return end
	askConfirm("REMOVE STAFF", "Remove " .. chosen.username .. " from " .. chosen.role .. "?", function()
		sendAction("RemoveStaff", {targetUserId = selectedStaffId})
	end)
end, 7)
section(staffPage, "ROLE PERMISSIONS", 8)
buttonRow(staffPage, {"HEAD ADMIN", "ADMIN", "MODERATOR", "HELPER"}, function(label)
	permissionRole = label
	for _, child in ipairs(permissionList:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end
	for index, area in ipairs({"Players", "Monitoring", "Announcements", "Environment", "Moderation", "Tools", "Logs", "Server"}) do
		local enabled = permissions[permissionRole] and permissions[permissionRole][area] == true
		local button = actionButton(permissionList, area .. "  /  " .. (enabled and "ON" or "OFF"), function()
			sendAction("SetPermission", {role = permissionRole, area = area, enabled = not enabled})
		end, index)
		button.Size = UDim2.new(1, 0, 0, 28)
	end
end, 9)
permissionList = make("ScrollingFrame", {
	LayoutOrder = 10,
	Size = UDim2.new(1, 0, 0, 220),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 2,
	ScrollBarImageColor3 = C.dim,
	ZIndex = 13,
}, staffPage)
make("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3)}, permissionList)
textLabel(staffPage, "Original Owner, Dev, and Head Admin assignments are protected.", 30, 11, {TextColor3 = C.muted, TextSize = 10})

local function renderStaff()
	if not staffList then return end
	for _, child in ipairs(staffList:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end
	table.sort(staffRows, function(a, b) return (a.role or "") < (b.role or "") end)
	for index, row in ipairs(staffRows) do
		local state = row.online and "ONLINE" or "OFFLINE"
		local item = actionButton(staffList, row.username .. "  ·  " .. displayRole(row.role) .. "  ·  " .. state, function()
			selectedStaffId = row.userId
			selectedUserId = row.userId
			selectedName = row.username
			if moderatorUsername then moderatorUsername.Text = row.username end
			if selectedInfo then selectedInfo.Text = row.username .. "  ·  " .. displayRole(row.role) .. "  ·  " .. state end
			renderStaff()
		end, index)
		item.Size = UDim2.new(1, 0, 0, 30)
		item.TextXAlignment = Enum.TextXAlignment.Left
		make("UIPadding", {PaddingLeft = UDim.new(0, 8)}, item)
		if selectedStaffId == row.userId then item.BackgroundColor3 = C.surface2 end
	end
end
permissionRole = "HEAD ADMIN"

-- logs
actionButton(logsPage, "OVERVIEW", function() activateTab("OVERVIEW") end, 0)
section(logsPage, "ADMIN ACTIVITY", 1)
logsSearch = inputBox(logsPage, "Search action, username, role, or result", 2)
local logsRefresh = actionButton(logsPage, "REFRESH", function() remote:FireServer("RequestLogs") end, 3)
logsList = make("ScrollingFrame", {
	LayoutOrder = 4,
	Size = UDim2.new(1, 0, 0, 410),
	BackgroundColor3 = C.background,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 2,
	ScrollBarImageColor3 = C.dim,
	ZIndex = 13,
}, logsPage)
corner(logsList, 5)
stroke(logsList, C.line)
make("UIPadding", {PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7)}, logsList)
make("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5)}, logsList)
local function renderLogs()
	if not logsList then return end
	for _, child in ipairs(logsList:GetChildren()) do
		if child:IsA("TextLabel") then child:Destroy() end
	end
	local query = string.lower(logsSearch.Text or "")
	local order = 0
	for _, entry in ipairs(logRows) do
		local text = string.format("%s  ·  %s (%s)  ·  %s  ·  %s  ·  %s",
			os.date("%m/%d %H:%M", tonumber(entry.time) or 0),
			tostring(entry.actor or "?"), displayRole(entry.role),
			tostring(entry.action or ""), tostring(entry.target or ""),
			tostring(entry.result or ""))
		if query == "" or string.find(string.lower(text), query, 1, true) then
			order += 1
			textLabel(logsList, text, 46, order, {BackgroundColor3 = C.surface, BackgroundTransparency = 0, TextColor3 = C.muted, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left})
		end
	end
	if order == 0 then textLabel(logsList, "No matching activity.", 30, 1, {TextColor3 = C.muted, TextSize = 10}) end
end
logsSearch:GetPropertyChangedSignal("Text"):Connect(renderLogs)

-- performance
section(statusPage, "SERVER", 1)
local metricsLabel = textLabel(statusPage, "Waiting for server metrics.", 98, 2, {TextColor3 = C.text, TextSize = 13, TextYAlignment = Enum.TextYAlignment.Top})
section(statusPage, "CLIENT", 3)
local clientLabel = textLabel(statusPage, "Local rendering FPS: measuring", 34, 4, {TextColor3 = C.muted, TextSize = 11})
local refreshStatus = actionButton(statusPage, "REFRESH", function() remote:FireServer("RequestSnapshot") end, 5)
textLabel(statusPage, "Server FPS is measured from server Heartbeat. Client FPS is this device's rendered frames.", 44, 6, {TextColor3 = C.dim, TextSize = 10})

local notice = make("TextLabel", {
	Name = "Notice",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -28),
	Size = UDim2.new(0.9, 0, 0, 48),
	BackgroundColor3 = C.panel,
	BackgroundTransparency = 0.08,
	BorderSizePixel = 0,
	Text = "",
	TextColor3 = C.text,
	TextStrokeColor3 = Color3.new(0, 0, 0),
	TextStrokeTransparency = 0.14,
	Font = Enum.Font.Nunito,
	TextSize = 15,
	TextWrapped = true,
	Visible = false,
	ZIndex = 60,
}, gui)
local noticeVersion = 0
local function toast(message, duration)
	noticeVersion += 1
	local version = noticeVersion
	notice.Text = tostring(message)
	notice.Visible = true
	notice.TextTransparency = 0
	notice.BackgroundTransparency = 1
	task.delay(duration or 3, function()
		if version == noticeVersion then
			notice.TextTransparency = 1
			notice.Visible = false
		end
	end)
end

-- Public announcement overlay: everyone receives the banner; only staff can compose.
do
	(function()
		local TextMeasure=game:GetService("TextService")
		local GuiService=game:GetService("GuiService")
		local colors={OWNER=Color3.fromRGB(234,197,108),["MASTER DEVELOPER"]=Color3.fromRGB(234,197,108),["HEAD ADMIN"]=Color3.fromRGB(166,201,133)}
		local root=make("CanvasGroup",{Name="AnnouncementBanner",AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,86),Size=UDim2.fromOffset(900,100),BackgroundTransparency=1,Visible=false,ZIndex=55},gui)
		local prefix=make("TextLabel",{BackgroundTransparency=1,Font=Enum.Font.Nunito,TextSize=28,TextColor3=C.text,RichText=true,TextStrokeColor3=Color3.new(),TextStrokeTransparency=0.2,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,TextWrapped=false,TextTruncate=Enum.TextTruncate.None,ClipsDescendants=false,ZIndex=56},root)
		local badge=make("Frame",{Size=UDim2.fromOffset(26,26),BackgroundColor3=Color3.fromRGB(0,149,255),BorderSizePixel=0,ZIndex=56},root);corner(badge,13)
		make("Frame",{Position=UDim2.fromOffset(6,13),Size=UDim2.fromOffset(7,3),Rotation=45,BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,ZIndex=57},badge)
		make("Frame",{Position=UDim2.fromOffset(10,11),Size=UDim2.fromOffset(12,3),Rotation=-45,BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,ZIndex=57},badge)
		local message=make("TextLabel",{BackgroundTransparency=1,Font=Enum.Font.Nunito,TextSize=28,TextColor3=C.text,TextStrokeColor3=Color3.new(),TextStrokeTransparency=0.2,TextXAlignment=Enum.TextXAlignment.Center,TextYAlignment=Enum.TextYAlignment.Center,TextWrapped=true,ZIndex=56},root)
		local previewTag=make("TextLabel",{Position=UDim2.fromOffset(0,-20),Size=UDim2.new(1,0,0,18),BackgroundTransparency=1,Text="PREVIEW · Only you can see this",Font=Enum.Font.Nunito,TextSize=12,TextColor3=C.text,TextStrokeTransparency=0.3,TextXAlignment=Enum.TextXAlignment.Center,Visible=false,ZIndex=56},root)
		local announcementSound=make("Sound",{Name="AnnouncementSound",SoundId="rbxassetid://107498514393918",Volume=0.7},SoundService)
		local serial=0
		local running
		local current
		local function escape(text)return tostring(text):gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"):gsub('"',"&quot;")end
		local function fit()
			if not current then return end
			local viewport = gui.AbsoluteSize
			local fontSize = viewport.X < 650 and 22 or 28
			local available = math.max(220, math.min(1080, viewport.X - 40))
			local tag = displayRole(current.role)
			local name = tostring(current.by or "Staff"):gsub("[\\r\\n]", " ")
			local measureFont = Enum.Font.Nunito

			local function measure(text, width)
				return TextMeasure:GetTextSize(text, fontSize, measureFont, Vector2.new(width or 10000, 10000))
			end
			local function prefixText()
				return "[" .. tag .. "] " .. name
			end

			local maxPrefixWidth = available * 0.48
			local prefixPadding = 72
			local prefixWidth = measure(prefixText()).X + prefixPadding
			if prefixWidth > maxPrefixWidth then
				local parts = {}
				for _, codepoint in utf8.codes(name) do
					table.insert(parts, utf8.char(codepoint))
				end
				while #parts > 6 and measure(prefixText()).X + prefixPadding > maxPrefixWidth do
					table.remove(parts)
					name = table.concat(parts) .. "…"
				end
				prefixWidth = math.min(maxPrefixWidth, measure(prefixText()).X + prefixPadding)
			end

			local badgeSize = fontSize < 24 and 20 or 22
			local badgeGap = 10
			local messageGap = 14
			local messageText = ": " .. tostring(current.text or ""):gsub("[\\r\\n]+", " ")
			local minimumMessageWidth = math.min(88, math.max(56, available * 0.25))
			local maxMessageWidth = math.max(minimumMessageWidth, available - prefixWidth - badgeGap - badgeSize - messageGap)
			local naturalMessageWidth = measure(messageText).X + 6
			local messageWidth = math.min(naturalMessageWidth, maxMessageWidth)
			local bounds = measure(messageText, messageWidth)
			local messageHeight = math.max(fontSize + 12, bounds.Y + 10)
			local contentWidth = prefixWidth + badgeGap + badgeSize + messageGap + messageWidth
			local totalHeight = math.max(fontSize + 14, messageHeight)

			root.Size = UDim2.fromOffset(contentWidth, totalHeight)
			root.AnchorPoint = Vector2.new(0.5, 0)
			root.Position = UDim2.new(0.5, 0, root.Position.Y.Scale, root.Position.Y.Offset)
			prefix.Position = UDim2.fromOffset(0, 2)
			prefix.Size = UDim2.fromOffset(prefixWidth, fontSize + 12)
			prefix.Font = measureFont
			prefix.TextSize = fontSize
			prefix.TextWrapped = false
			prefix.TextTruncate = Enum.TextTruncate.None
			prefix.TextXAlignment = Enum.TextXAlignment.Left
			prefix.TextYAlignment = Enum.TextYAlignment.Center
			local color = colors[current.role]
			prefix.Text = string.format('<b><font color="rgb(%d,%d,%d)">[%s]</font> %s</b>',
				math.round(color.R * 255), math.round(color.G * 255), math.round(color.B * 255), escape(tag), escape(name))

			badge.Size = UDim2.fromOffset(badgeSize, badgeSize)
			badge.Position = UDim2.fromOffset(prefixWidth + badgeGap, math.floor((fontSize + 12 - badgeSize) / 2))
			message.Position = UDim2.fromOffset(prefixWidth + badgeGap + badgeSize + messageGap, 2)
			message.Size = UDim2.fromOffset(messageWidth, messageHeight)
			message.Font = measureFont
			message.TextSize = fontSize
			message.TextXAlignment = Enum.TextXAlignment.Center
			message.TextYAlignment = Enum.TextYAlignment.Center
			message.Text = messageText
			previewTag.Font = Enum.Font.Nunito
			previewTag.TextSize = 12
		end
		function announcementUI.show(data,isPreview)
			if type(data)~="table" or not colors[data.role]then return end
			if not isPreview then
				announcementSound:Stop();announcementSound.TimePosition=0;announcementSound:Play()
			end
			serial+=1;local token=serial;current=data
			if running then running:Cancel()end
			fit();previewTag.Visible=isPreview==true
			local inset=GuiService:GetGuiInset()
			local y=math.max(86,inset.Y+26)
			root.Position=UDim2.new(0.5,0,0,y-12);root.GroupTransparency=1;root.Visible=true
			running=TweenService:Create(root,TweenInfo.new(0.22),{GroupTransparency=0,Position=UDim2.new(0.5,0,0,y)});running:Play()
			task.delay(math.clamp(tonumber(data.duration)or 8,3,12),function()
				if serial~=token then return end
				running=TweenService:Create(root,TweenInfo.new(0.25),{GroupTransparency=1,Position=UDim2.new(0.5,0,0,y-8)})
				running.Completed:Connect(function()if serial==token then root.Visible=false end end);running:Play()
			end)
		end
		gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	end)()
end
local function showAnnouncement(data)announcementUI.show(data,false)end

watchPopup = make("Frame", {
	Name = "WatchScreenPopup",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 18),
	Size = UDim2.new(0.82, 0, 0, 46),
	BackgroundColor3 = C.panel,
	BackgroundTransparency = 0.06,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 70,
}, gui)
corner(watchPopup, 8)
stroke(watchPopup, C.line, 0.12)
watchNameLabel = make("TextLabel", {
	Name = "LiveTarget",
	Position = UDim2.fromOffset(14, 0),
	Size = UDim2.new(1, -64, 1, 0),
	BackgroundTransparency = 1,
	Text = "LIVE  ·  @player",
	TextColor3 = C.text,
	Font = Enum.Font.Nunito,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	ZIndex = 71,
}, watchPopup)
local watchClose = actionButton(watchPopup, "X", function()
	watchPopup.Visible = false
	sendAction("StopSpectate")
end, 1)
watchClose.AnchorPoint = Vector2.new(1, 0.5)
watchClose.Position = UDim2.new(1, -7, 0.5, 0)
watchClose.Size = UDim2.fromOffset(38, 32)
watchClose.ZIndex = 72

local function clearRain()
	for _, tween in ipairs(rainTweens) do
		pcall(function() tween:Cancel() end)
	end
	table.clear(rainTweens)
	if rainGui then rainGui:Destroy(); rainGui = nil end
end

local function setRain(kind)
	clearRain()
	weatherType = kind
	if kind ~= "Rain" and kind ~= "Storm" then return end
	rainGui = make("Frame", {
		Name = "LocalWeather",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 4,
	}, gui)
	local count = kind == "Storm" and 34 or 22
	for index = 1, count do
		local drop = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Size = UDim2.fromOffset(1, math.random(12, 23)),
			Position = UDim2.new(math.random(), 0, -0.2, 0),
			BackgroundColor3 = C.white,
			BackgroundTransparency = 0.66,
			BorderSizePixel = 0,
			ZIndex = 4,
		}, rainGui)
		local function runDrop()
			if not rainGui or drop.Parent ~= rainGui then return end
			drop.Position = UDim2.new(math.random(), 0, -0.1, 0)
			local viewport = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(800, 600)
			local tween = TweenService:Create(drop, TweenInfo.new(kind == "Storm" and 0.48 or 0.68, Enum.EasingStyle.Linear), {
				Position = UDim2.new(drop.Position.X.Scale, 0, 1, viewport.Y * 0.1),
			})
			table.insert(rainTweens, tween)
			tween:Play()
			tween.Completed:Connect(function()
				if rainGui and drop.Parent == rainGui then runDrop() end
			end)
		end
		task.delay(math.random() * 1.2, runDrop)
	end
end

local function getAllowedActions()
	local camera = Workspace.CurrentCamera
	if not camera then return Vector3.zero end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local direction = humanoid and humanoid.MoveDirection or Vector3.zero
	if not UserInputService.TouchEnabled then
		direction = Vector3.zero
		local frame = camera.CFrame
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then direction += frame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then direction -= frame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then direction += frame.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then direction -= frame.RightVector end
		direction = Vector3.new(direction.X, 0, direction.Z)
	end
	local vertical = flyVertical
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then vertical += 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.C) then vertical -= 1 end
	local output = Vector3.new(direction.X, vertical, direction.Z)
	return output.Magnitude > 1 and output.Unit or output
end

local function setFly(enabled)
	flyEnabled = enabled == true
	updateAbilityToggle("SetFly", flyEnabled)
	if flyConnection then flyConnection:Disconnect(); flyConnection = nil end
	if flightPad then flightPad.Visible = (flyEnabled or freeCamEnabled) and UserInputService.TouchEnabled end
	if not flyEnabled then return end
	local lastSend = 0
	flyConnection = RunService.RenderStepped:Connect(function()
		if os.clock() - lastSend >= 0.095 then
			lastSend = os.clock()
			local camera = Workspace.CurrentCamera
			local look = camera and camera.CFrame.LookVector or Vector3.new(0, 0, -1)
			local facing = Vector3.new(look.X, 0, look.Z)
			if facing.Magnitude < 0.01 then facing = Vector3.new(0, 0, -1) end
			local speed = math.clamp(tonumber(speedBox and speedBox.Text) or freeCamSpeed, 8, 120)
			remote:FireServer("AbilityMove", {direction = getAllowedActions(), facing = facing.Unit, speed = speed})
		end
	end)
end

local function disconnectFreeCam()
	for _, connection in ipairs(freeCamInputConnections) do
		connection:Disconnect()
	end
	table.clear(freeCamInputConnections)
	if freeCamConnection then freeCamConnection:Disconnect(); freeCamConnection = nil end
end

local function setFreeCamera(enabled)
	freeCamEnabled = enabled == true
	updateAbilityToggle("SetFreeCamera", freeCamEnabled)
	if not freeCamEnabled then
		disconnectFreeCam()
		if savedCamera and Workspace.CurrentCamera then
			Workspace.CurrentCamera.CameraType = savedCamera.type
			Workspace.CurrentCamera.CameraSubject = savedCamera.subject
			Workspace.CurrentCamera.FieldOfView = savedCamera.fov
			UserInputService.MouseBehavior = savedCamera.mouseBehavior or Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = savedCamera.mouseIconEnabled ~= false
		else
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
		savedCamera = nil
		if flightPad then flightPad.Visible = flyEnabled and UserInputService.TouchEnabled end
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then return end
	savedCamera = {
		type = camera.CameraType,
		subject = camera.CameraSubject,
		fov = camera.FieldOfView,
		mouseBehavior = UserInputService.MouseBehavior,
		mouseIconEnabled = UserInputService.MouseIconEnabled,
	}
	camera.CameraType = Enum.CameraType.Scriptable
	freeCamPitch, freeCamYaw = camera.CFrame:ToOrientation()
	local held = {}
	local rotating = false
	freeCamSpeed = math.clamp(tonumber(speedBox and speedBox.Text) or freeCamSpeed, 8, 120)
	local function moveKeys(input, down)
		local name = input.KeyCode.Name
		if name == "W" or name == "A" or name == "S" or name == "D" or name == "Q" or name == "E" or name == "LeftShift" then
			held[name] = down
		end
	end
	table.insert(freeCamInputConnections, UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			rotating = true
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		end
		moveKeys(input, true)
	end))
	table.insert(freeCamInputConnections, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			rotating = false
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
		moveKeys(input, false)
	end))
	table.insert(freeCamInputConnections, UserInputService.InputChanged:Connect(function(input)
		if rotating and input.UserInputType == Enum.UserInputType.MouseMovement then
			freeCamYaw -= input.Delta.X * 0.0025
			freeCamPitch = math.clamp(freeCamPitch - input.Delta.Y * 0.0025, -1.45, 1.45)
		elseif input.UserInputType == Enum.UserInputType.Touch and freeCamTouchLook then
			freeCamYaw -= input.Delta.X * 0.0025
			freeCamPitch = math.clamp(freeCamPitch - input.Delta.Y * 0.0025, -1.45, 1.45)
		end
	end))
	updateAbilityToggle("SetFreeCamera", freeCamEnabled)
	if flightPad then flightPad.Visible = (flyEnabled or freeCamEnabled) and UserInputService.TouchEnabled end
	local last = os.clock()
	freeCamConnection = RunService.RenderStepped:Connect(function()
		local currentCamera = Workspace.CurrentCamera
		if not currentCamera then return end
		currentCamera.CameraType = Enum.CameraType.Scriptable
		local dt = math.min(os.clock() - last, 0.05)
		last = os.clock()
		local frame = CFrame.fromOrientation(freeCamPitch, freeCamYaw, 0)
		local movement = Vector3.zero
		if held.W or (flightPad and flightPad:GetAttribute("Forward")) then movement += frame.LookVector end
		if held.S or (flightPad and flightPad:GetAttribute("Backward")) then movement -= frame.LookVector end
		if held.D or (flightPad and flightPad:GetAttribute("Right")) then movement += frame.RightVector end
		if held.A or (flightPad and flightPad:GetAttribute("Left")) then movement -= frame.RightVector end
		if held.E or (flightPad and flightPad:GetAttribute("Up")) then movement += Vector3.yAxis end
		if held.Q or (flightPad and flightPad:GetAttribute("Down")) then movement -= Vector3.yAxis end
		local multiplier = held.LeftShift and 2.5 or 1
		local position = currentCamera.CFrame.Position
		if movement.Magnitude > 0 then
			local speed = math.clamp(tonumber(speedBox and speedBox.Text) or freeCamSpeed, 8, 120)
			position += movement.Unit * speed * multiplier * dt
		end
		currentCamera.CFrame = CFrame.new(position) * frame
	end)
end

flightPad = make("Frame", {
	Name = "TouchControls",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -14, 1, UserInputService.TouchEnabled and -150 or -22),
	Size = UDim2.fromOffset(UserInputService.TouchEnabled and 188 or 156, UserInputService.TouchEnabled and 124 or 132),
	BackgroundColor3 = C.panel,
	BackgroundTransparency = 0.2,
	Visible = false,
	ZIndex = 35,
}, gui)
corner(flightPad, 8)
stroke(flightPad, C.line, 0.2)
local padLayout = make("UIGridLayout", {
	CellSize = UDim2.fromOffset(UserInputService.TouchEnabled and 56 or 46, UserInputService.TouchEnabled and 44 or 36),
	CellPadding = UDim2.fromOffset(4, 4),
	FillDirectionMaxCells = 3,
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
}, flightPad)
local function padButton(label, attribute, order)
	local button = actionButton(flightPad, label, function() end, order)
	button.Size = UDim2.fromOffset(UserInputService.TouchEnabled and 56 or 46, UserInputService.TouchEnabled and 44 or 36)
	button.LayoutOrder = order
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			flightPad:SetAttribute(attribute, true)
			if attribute == "Up" then flyVertical = 1 end
			if attribute == "Down" then flyVertical = -1 end
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			flightPad:SetAttribute(attribute, false)
			if (attribute == "Up" and flyVertical == 1) or (attribute == "Down" and flyVertical == -1) then flyVertical = 0 end
		end
	end)
	return button
end
padButton("UP", "Up", 1)
padButton("FWD", "Forward", 2)
padButton("DOWN", "Down", 3)
padButton("LEFT", "Left", 4)
padButton("BACK", "Backward", 5)
padButton("RIGHT", "Right", 6)

local function restoreSpectateCamera()
	local camera = Workspace.CurrentCamera
	if camera and savedCamera then
		camera.CameraType = savedCamera.type
		camera.CameraSubject = savedCamera.subject
		camera.FieldOfView = savedCamera.fov
		UserInputService.MouseBehavior = savedCamera.mouseBehavior or Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = savedCamera.mouseIconEnabled ~= false
	end
	savedCamera = nil
	currentSpectateToken = nil
end

remote.OnClientEvent:Connect(function(event, data)
	if event == "AccessGranted" then
		if type(data) ~= "table" or type(data.role) ~= "string" or data.role == "" then
			warn("[PalmVille Admin] Ignored an incomplete AccessGranted response.")
			return
		end
		authorized = true
		accessDeniedLogged = false
		role = data.role
		permissions = type(data.permissions) == "table" and data.permissions or {}
		launcher.Visible = true
		print(string.format("[PalmVille Admin] Access granted: %s (%s).", player.Name, role))
		local visibleRole = displayRole(role)
		roleLabel.Text = visibleRole
		profile.role.Text = visibleRole
		profile.role.Size = UDim2.fromOffset(math.clamp(#visibleRole * 8 + 28, 100, 180), 28)
		if currentAdminLabel then currentAdminLabel.Text = "@" .. player.Name .. "  ·  " .. visibleRole end
		updateAbilityToggle("SetAdminTitle", player:GetAttribute("PalmVilleAdminTitleVisible") ~= false)
		setStatus("AUTHORIZED")
		refreshTabs()
		if isManager() then
			task.delay(0.6, function()
				if authorized and isManager() then remote:FireServer("RequestStaff") end
			end)
		end
	elseif event == "AccessDenied" then
		if not accessDeniedLogged and type(data) == "table" and tonumber(data.userId) == player.UserId then
			accessDeniedLogged = true
			warn(string.format("[PalmVille Admin] Server denied access for %s (UserId %d). Configured developer: %s (UserId %s).", player.Name, player.UserId, tostring(data.masterUsername or "unknown"), tostring(data.masterUserId or "unknown")))
		end
	elseif event == "Notice" then
		if announcementUI.notice then announcementUI.notice(data)end
		setStatus(tostring(data))
		toast(tostring(data))
	elseif event == "Snapshot" then
		if type(data) ~= "table" then return end
		roster = type(data.players) == "table" and data.players or {}
		serverMetrics = data.metrics
		updateDashboardMetrics()
		renderOverviewStaff()
		renderPlayers()
		if serverMetrics and metricsLabel then
			local memory = serverMetrics.memoryMb and (tostring(serverMetrics.memoryMb) .. " MB") or "n/a"
			metricsLabel.Text = string.format("Server FPS     %s\nUptime          %s\nPlayers         %s / %s\nServer memory   %s",
				tostring(serverMetrics.serverFps or "n/a"), formatTime(serverMetrics.uptime),
				tostring(serverMetrics.playerCount), tostring(serverMetrics.maxPlayers), memory)
		end
	elseif event == "StaffData" then
		if type(data) == "table" then
			staffRows = type(data.staff) == "table" and data.staff or {}
			permissions = type(data.permissions) == "table" and (data.permissions[role] or permissions) or permissions
			renderStaff()
			renderOverviewStaff()
			refreshTabs()
			if permissionList then
				for _, child in ipairs(permissionList:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
				local current = data.permissions and data.permissions[permissionRole] or {}
				for index, area in ipairs({"Players", "Monitoring", "Announcements", "GiveItem", "Environment", "Moderation", "Tools", "Logs", "Server"}) do
					local enabled = current[area] == true
					local button = actionButton(permissionList, area .. "  /  " .. (enabled and "ON" or "OFF"), function()
						sendAction("SetPermission", {role = permissionRole, area = area, enabled = not enabled})
					end, index)
					button.Size = UDim2.new(1, 0, 0, 28)
				end
			end
		end
	elseif event == "LogsData" then
		logRows = type(data) == "table" and data or {}
		renderLogs()
	elseif event == "ModerationHistory" then
		historyRows = type(data.items) == "table" and data.items or {}
		local lines = {}
		for index = 1, math.min(#historyRows, 6) do
			local entry = historyRows[index]
			table.insert(lines, string.format("%s  ·  %s  ·  %s", os.date("%m/%d %H:%M", tonumber(entry.time) or 0), tostring(entry.action or ""), tostring(entry.reason or "")))
		end
		historyLabel.Text = #lines > 0 and table.concat(lines, "\n") or "No saved moderation history."
	elseif event == "AnnouncementHistory" then
		-- History remains stored server-side but is intentionally hidden in this menu.
	elseif event == "AnnouncementSent" then
		if announcementUI.sent then announcementUI.sent(data)end
	elseif event == "Announcement" then
		showAnnouncement(data)
	elseif event == "Warning" then
		toast("STAFF WARNING  ·  " .. tostring(data), 6)
	elseif event == "ChatMuteState" then
		toast(data and "You are muted in text chat." or "Your text chat mute was removed.", 5)
	elseif event == "SpectateNotice" then
		local message = type(data) == "table" and (data.active and ("A staff member is spectating you: " .. tostring(data.admin)) or ("Spectating ended: " .. tostring(data.admin))) or "Spectating update."
		toast(message, 6)
	elseif event == "SpectateStarted" then
		spectateActive = true
		currentSpectateToken = nil
		if freeCamEnabled then
			setFreeCamera(false)
			sendAction("SetFreeCamera", {enabled = false})
		end
		local camera = Workspace.CurrentCamera
		if camera then
			savedCamera = savedCamera or {
				type = camera.CameraType,
				subject = camera.CameraSubject,
				fov = camera.FieldOfView,
				mouseBehavior = UserInputService.MouseBehavior,
				mouseIconEnabled = UserInputService.MouseIconEnabled,
			}
			camera.CameraType = Enum.CameraType.Scriptable
			setStatus("SPECTATING  ·  " .. tostring(data.username))
		end
	elseif event == "WatchScreenStarted" then
		if watchNameLabel then watchNameLabel.Text = "LIVE  ·  @" .. tostring(data.username or "player") end
		if watchPopup then watchPopup.Visible = true end
	elseif event == "SpectateStopped" then
		spectateActive = false
		if watchPopup then watchPopup.Visible = false end
		restoreSpectateCamera()
		setStatus("SPECTATING STOPPED")
	elseif event == "BeginCameraFeed" then
		cameraFeedTokens[data.token] = true
	elseif event == "StopCameraFeed" then
		cameraFeedTokens[data.token] = nil
	elseif event == "LiveCamera" then
		if type(data) == "table" and (currentSpectateToken == nil or currentSpectateToken == data.token) and typeof(data.cframe) == "CFrame" and Workspace.CurrentCamera then
			currentSpectateToken = data.token
			Workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
			Workspace.CurrentCamera.CFrame = data.cframe
			Workspace.CurrentCamera.FieldOfView = math.clamp(tonumber(data.fov) or 70, 20, 120)
		end
	elseif event == "SetFly" then
		setFly(data == true)
		toast(data and "Fly enabled." or "Fly disabled.")
	elseif event == "SetInvisible" then
		invisibleEnabled = data == true
		updateAbilityToggle("SetInvisible", invisibleEnabled)
		if invisibleEnabled then toast("Invisible mode enabled.") else toast("Invisible mode disabled.") end
	elseif event == "SetNoclip" then
		updateAbilityToggle("SetNoclip", data == true)
	elseif event == "SetAdminTitle" then
		updateAbilityToggle("SetAdminTitle", data == true)
	elseif event == "SetFreeCamera" then
		setFreeCamera(data == true)
		toast(data and "Free camera enabled." or "Free camera disabled.")
	elseif event == "Weather" then
		setRain(tostring(data or "Sunny"))
	end
end)

local lastCameraReport = 0
RunService.Heartbeat:Connect(function()
	if next(cameraFeedTokens) == nil or os.clock() - lastCameraReport < 0.12 then return end
	local camera = Workspace.CurrentCamera
	if not camera then return end
	lastCameraReport = os.clock()
	for token in pairs(cameraFeedTokens) do
		remote:FireServer("CameraFrame", {token = token, cframe = camera.CFrame, fov = camera.FieldOfView})
	end
end)

updatePanelSize = function()
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1024, 768)
	local touch = UserInputService.TouchEnabled
	local width = math.max(280, math.min(touch and 820 or 1180, viewport.X - (touch and 20 or 80)))
	local height = math.max(240, math.min(touch and 560 or 740, viewport.Y - (touch and 24 or 70)))
	local headerHeight = touch and 78 or 86
	panel.Size = minimized and UDim2.fromOffset(width, headerHeight) or UDim2.fromOffset(width, height)
	local sidebarWidth = math.floor(math.clamp(width * 0.235, touch and 130 or 200, touch and 190 or 280))
	homePage:FindFirstChildOfClass("UIPadding").PaddingTop = UDim.new(0, touch and 10 or 17)
	homePage:FindFirstChildOfClass("UIListLayout").Padding = UDim.new(0, touch and 7 or 15)
	sidebar.Position = UDim2.new(0, 0, 0, 0)
	sidebar.Size = UDim2.new(0, sidebarWidth, 1, 0)
	header.Position = UDim2.fromOffset(sidebarWidth, 0)
	header.Size = UDim2.new(1, -sidebarWidth, 0, headerHeight)
	profile.root.Size = UDim2.new(1, 0, 0, touch and 76 or 92)
	profile.avatar.Visible = true
	profile.avatar.Size = UDim2.fromOffset(touch and 36 or 44, touch and 36 or 44)
	profile.avatar.Position = UDim2.fromOffset(12, touch and 18 or 22)
	profile.name.Position = UDim2.fromOffset(touch and 58 or 68, touch and 14 or 17)
	profile.name.Size = UDim2.new(1, touch and -68 or -80, 0, 22)
	profile.name.TextSize = touch and 13 or 15
	profile.role.AnchorPoint = Vector2.zero
	profile.role.Position = UDim2.fromOffset(touch and 58 or 68, touch and 40 or 44)
	profile.role.Size = UDim2.fromOffset(touch and 108 or 124, 18)
	profile.role.TextSize = 10
	profile.subtitle.Text = TAB_DESCRIPTIONS[activeTab or "OVERVIEW"] or "Admin controls"
	statusBar.Visible = false
	roleLabel.Visible = false
	resetButton.Visible = false
	launcher.Position = UDim2.new(1, -12, 0, touch and 110 or 56)
	brand.Text = "PalmVille Admin"
	brand.Position = UDim2.fromOffset(82, touch and 14 or 19)
	profile.subtitle.Position = UDim2.fromOffset(82, touch and 42 or 49)
	shieldIcon.Position = UDim2.fromOffset(24, math.floor((headerHeight - 50) / 2))
	profile.avatar.Position = UDim2.fromOffset(12, touch and 18 or 22)
	brand.Size = UDim2.new(1, -210, 0, 39)
	brand.TextSize = touch and 18 or 24
	brand.TextScaled = false
	brand.Font = Enum.Font.Nunito
	closeButton.Size = UDim2.fromOffset(58, 48)
	closeButton.Position = UDim2.new(1, -14, 0.5, 0)
	tabStrip.Position = UDim2.fromOffset(10, touch and 86 or 108)
	tabStrip.Size = UDim2.new(1, -20, 1, touch and -96 or -118)
	tabLayout.Padding = UDim.new(0, touch and 4 or 6)
	content.Position = UDim2.new(0, sidebarWidth + 22, 0, headerHeight + 10)
	content.Size = UDim2.new(1, -sidebarWidth - 34, 1, -headerHeight - 20)
	moreNav.Size = UDim2.new(1, 0, 0, touch and 44 or 36)
	moreContent.Position = UDim2.new(0, 0, 0, touch and 48 or 40)
	moreContent.Size = UDim2.new(1, 0, 1, touch and -48 or -40)
end

updatePanelSize()

local function showPanel()
	if not authorized then return end
	panelOpen = true
	minimized = false
	launcher.Visible = false
	panelBackdrop.Visible = true
	updatePanelSize()
	for _, child in ipairs(panel:GetChildren()) do
		if child:IsA("GuiObject") and child ~= header and child ~= panelScale then child.Visible = true end
	end
	panel.Visible = true
	updatePanelSize()
	openVersion += 1
	panelScale.Scale = (UserInputService.TouchEnabled and 0.9 or 0.78) * 0.97
	TweenService:Create(panelScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = UserInputService.TouchEnabled and 0.9 or 0.78}):Play()
	refreshTabs()
end

launcher.Activated:Connect(function()
	if panelOpen and not minimized then
		closePanel()
	elseif panelOpen and minimized then
		minimized = false
		updatePanelSize()
		panelBackdrop.Visible = true
		controlGlyph.line.Visible = true
		controlGlyph.restore.Visible = false
		for _, child in ipairs(panel:GetChildren()) do
			if child:IsA("GuiObject") and child ~= header and child ~= panelScale then child.Visible = true end
		end
		updatePanelSize()
		refreshTabs()
	else
		showPanel()
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if input.UserInputType == Enum.UserInputType.Touch and freeCamEnabled then
		local point = input.Position
		local inPanel = panel.Visible and point.X >= panel.AbsolutePosition.X and point.X <= panel.AbsolutePosition.X + panel.AbsoluteSize.X
			and point.Y >= panel.AbsolutePosition.Y and point.Y <= panel.AbsolutePosition.Y + panel.AbsoluteSize.Y
		local inPad = flightPad and flightPad.Visible and point.X >= flightPad.AbsolutePosition.X and point.X <= flightPad.AbsolutePosition.X + flightPad.AbsoluteSize.X
			and point.Y >= flightPad.AbsolutePosition.Y and point.Y <= flightPad.AbsolutePosition.Y + flightPad.AbsoluteSize.Y
		freeCamTouchLook = not inPanel and not inPad
	end
	if processed then return end
	if input.KeyCode == Enum.KeyCode.RightShift and authorized then
		if panelOpen and not minimized then
			closePanel()
		else
			showPanel()
		end
	end
end)

header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		isDragging = true
		dragStart = input.Position
		panelStart = Vector2.new(panel.AbsolutePosition.X + panel.AbsoluteSize.X / 2, panel.AbsolutePosition.Y + panel.AbsoluteSize.Y / 2)
		dragInput = input
	end
end)
header.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if isDragging and dragInput == input then
		local delta = input.Position - dragStart
		local camera = Workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1024, 768)
		local nextX = panelStart.X + delta.X
		local nextY = panelStart.Y + delta.Y
		panel.Position = UDim2.fromOffset(
			math.clamp(nextX, panel.AbsoluteSize.X / 2, viewport.X - panel.AbsoluteSize.X / 2),
			math.clamp(nextY, panel.AbsoluteSize.Y / 2, viewport.Y - panel.AbsoluteSize.Y / 2)
		)
		panelMoved = true
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then freeCamTouchLook = false end
	if input == dragInput or input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		isDragging = false
	end
end)

RunService.RenderStepped:Connect(function()
	clientFrameCount += 1
	local now = os.clock()
	if now - clientSample >= 1 then
		clientFps = math.floor(clientFrameCount / (now - clientSample) + 0.5)
		clientFrameCount = 0
		clientSample = now
		if clientLabel then clientLabel.Text = "Local rendering FPS: " .. tostring(clientFps) end
		if authorized and panel.Visible and not minimized then remote:FireServer("RequestSnapshot") end
	end
	if statusLabel then
		statusLabel.Text = os.clock() < statusUntil and statusMessage or "READY"
	end
end)

if Workspace.CurrentCamera then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updatePanelSize)
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updatePanelSize)
	end
	updatePanelSize()
end)

task.spawn(function()
	while gui.Parent do
		task.wait(1.25)
		if authorized and panel.Visible and not minimized then
			remote:FireServer("RequestSnapshot")
		end
	end
end)

task.spawn(function()
	local attempts = 0
	print(string.format("[PalmVille Admin] Starting access handshake for %s (UserId %d).", player.Name, player.UserId))
	while gui.Parent and not authorized do
		attempts += 1
		remote:FireServer("RequestAccess")
		if attempts == 8 and not authorized then
			warn("[PalmVille Admin] Access is still pending. Retrying; check Server Output for the server-side identity diagnostic.")
		end
		task.wait(attempts < 8 and 1.5 or 5)
	end
end)