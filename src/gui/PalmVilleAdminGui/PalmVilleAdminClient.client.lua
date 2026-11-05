local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("PalmVilleAdminRemote", 20)
if not remote then
	warn("[PalmVille Admin V2] PalmVilleAdminRemote was not found.")
	return
end

local gui = script.Parent
gui.Name = "PalmVilleAdminGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 96
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local C = {
	bg = Color3.fromRGB(12, 17, 15),
	panel = Color3.fromRGB(19, 27, 22),
	surface = Color3.fromRGB(26, 36, 30),
	surfaceHover = Color3.fromRGB(36, 51, 41),
	green = Color3.fromRGB(54, 105, 72),
	greenBright = Color3.fromRGB(94, 157, 109),
	line = Color3.fromRGB(53, 68, 58),
	text = Color3.fromRGB(241, 245, 239),
	muted = Color3.fromRGB(170, 183, 172),
	dim = Color3.fromRGB(119, 135, 123),
	red = Color3.fromRGB(184, 72, 72),
	amber = Color3.fromRGB(222, 181, 105),
	blue = Color3.fromRGB(54, 151, 238),
}

local role = ""
local permissions = {}
local authorized = false
local panelOpen = false
local activeTab = "OVERVIEW"
local snapshot = {players = {}, metrics = {}}
local staffRows = {}
local allPermissions = {}
local logs = {}
local history = {}
local selectedUserId
local selectedUsername
local selectedStaffId
local audience = "This Server"
local itemTargetMode = "Player"
local invisibleEnabled = false
local adminTitleEnabled = true
local currentReason = ""
local savedCamera

local function make(className, properties, parent)
	local object = Instance.new(className)
	if object:IsA("GuiObject") and parent and parent:IsA("GuiObject") then
		object.ZIndex = parent.ZIndex + 1
		if parent:FindFirstChildOfClass("UIListLayout") and not (properties and properties.LayoutOrder ~= nil) then
			local nextOrder = (parent:GetAttribute("_NextLayoutOrder") or 0) + 1
			parent:SetAttribute("_NextLayoutOrder", nextOrder)
			object.LayoutOrder = nextOrder
		end
	end
	for key, value in pairs(properties or {}) do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function addCorner(object, radius)
	make("UICorner", {CornerRadius = UDim.new(0, radius or 8)}, object)
end

local function addStroke(object, color, transparency, thickness)
	make("UIStroke", {
		Color = color or C.line,
		Transparency = transparency == nil and 0 or transparency,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, object)
end

local function text(parent, value, size, color, height, bold)
	return make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height or 24),
		Text = tostring(value or ""),
		Font = bold and Enum.Font.Nunito or Enum.Font.Nunito,
		TextSize = size or 13,
		TextColor3 = color or C.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = true,
	}, parent)
end

local function button(parent, caption, callback, options)
	options = options or {}
	local b = make("TextButton", {
		Size = options.size or UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = options.primary and C.green or C.surface,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = caption,
		TextColor3 = options.danger and Color3.fromRGB(255, 226, 226) or C.text,
		Font = Enum.Font.Nunito,
		TextSize = options.textSize or 12,
		TextWrapped = true,
	}, parent)
	addCorner(b, options.radius or 8)
	addStroke(b, options.danger and C.red or (options.primary and C.greenBright or C.line), 0.2)
	b.MouseEnter:Connect(function()
		if not options.disabled then
			b.BackgroundColor3 = options.danger and Color3.fromRGB(111, 45, 45) or C.surfaceHover
		end
	end)
	b.MouseLeave:Connect(function()
		b.BackgroundColor3 = options.primary and C.green or C.surface
	end)
	b.Activated:Connect(function()
		if callback then callback(b) end
	end)
	return b
end

local function input(parent, placeholder, defaultText, height)
	local box = make("TextBox", {
		Size = UDim2.new(1, 0, 0, height or 38),
		BackgroundColor3 = C.bg,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Font = Enum.Font.Nunito,
		TextSize = 13,
		TextColor3 = C.text,
		PlaceholderColor3 = C.dim,
		PlaceholderText = placeholder,
		Text = defaultText or "",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = false,
	}, parent)
	addCorner(box, 7)
	addStroke(box, C.line, 0.12)
	make("UIPadding", {
		PaddingLeft = UDim.new(0, 11),
		PaddingRight = UDim.new(0, 11),
	}, box)
	return box
end

local function vertical(parent, padding)
	local layout = make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, padding or 8),
	}, parent)
	return layout
end

local function card(parent, titleText, subtitle)
	local root = make("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.panel,
		BorderSizePixel = 0,
	}, parent)
	addCorner(root, 11)
	addStroke(root, C.line, 0.18)
	make("UIPadding", {
		PaddingTop = UDim.new(0, 14),
		PaddingBottom = UDim.new(0, 14),
		PaddingLeft = UDim.new(0, 15),
		PaddingRight = UDim.new(0, 15),
	}, root)
	local layout = vertical(root, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	local heading = text(root, titleText, 14, C.text, 22, true)
	if subtitle and subtitle ~= "" then
		local sub = text(root, subtitle, 11, C.muted, 30)
	end
	return root
end

local function addRow(parent, height)
	local row = make("Frame", {
		Size = UDim2.new(1, 0, 0, height or 38),
		BackgroundTransparency = 1,
	}, parent)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, row)
	return row
end

local function addField(parent, caption, placeholder, defaultText)
	local label = text(parent, caption, 10, C.muted, 16, true)
	local box = input(parent, placeholder, defaultText)
	return box
end

local function managerRole()
	return role == "OWNER" or role == "MASTER DEVELOPER"
end

local function canAccess(area)
	return managerRole() or permissions[area] == true
end

local function displayRole(value)
	return value == "MASTER DEVELOPER" and "DEV" or tostring(value or "PLAYER")
end

local function sendAction(action, data)
	if not authorized then return end
	data = data or {}
	data.action = action
	remote:FireServer("Action", data)
end

local function targetData()
	return {
		targetUserId = selectedUserId,
		username = selectedUsername or "",
	}
end

local announcementSound = make("Sound", {
	Name = "PalmVilleAnnouncementSound",
	SoundId = "rbxassetid://107498514393918",
	Volume = 0.7,
	Looped = false,
}, game:GetService("SoundService"))

local banner = make("Frame", {
	Name = "AnnouncementBannerV2",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 76),
	Size = UDim2.fromOffset(640, 54),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 80,
}, gui)

local bannerLine = make("TextLabel", {
	Name = "AnnouncementLine",
	BackgroundTransparency = 1,
	Font = Enum.Font.Nunito,
	TextSize = 27,
	TextColor3 = C.text,
	TextStrokeColor3 = Color3.new(0, 0, 0),
	TextStrokeTransparency = 0.25,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Center,
	TextWrapped = true,
	RichText = true,
	Size = UDim2.fromScale(1, 1),
	ZIndex = 81,
}, banner)

local bannerPreview = make("TextLabel", {
	Name = "PreviewLabel",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 0, -3),
	Size = UDim2.new(1, 0, 0, 18),
	BackgroundTransparency = 1,
	Text = "PREVIEW · ONLY YOU CAN SEE THIS",
	TextColor3 = C.muted,
	Font = Enum.Font.Nunito,
	TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Center,
	Visible = false,
	ZIndex = 82,
}, banner)

local bannerToken = 0
local bannerTween
local function escapeRichText(value)
	return tostring(value):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
end

local function showAnnouncement(data, preview)
	if type(data) ~= "table" then return end

	local incomingRole = tostring(data.role or "")
	local roleLabel = displayRole(incomingRole)
	local author = incomingRole == "MASTER DEVELOPER" and "Lupin" or tostring(data.by or "Staff")
	local message = tostring(data.text or ""):gsub("[\\r\\n]+", " ")
	if message:gsub("%s", "") == "" then return end

	local viewport = gui.AbsoluteSize
	local fontSize = math.clamp(math.floor(math.min(viewport.X, viewport.Y) / 28), 19, 27)
	local availableWidth = math.max(220, math.min(1180, viewport.X - 40))
	local roleText = "[" .. roleLabel .. "] "
	local authorText = author
	local badgeText = "  ✓  "
	local prefixText = roleText .. authorText .. badgeText
	local prefixWidth = TextService:GetTextSize(prefixText, fontSize, Enum.Font.Nunito, Vector2.new(4000, 100)).X
	local remainingWidth = math.max(96, availableWidth - prefixWidth - 6)
	local messageBounds = TextService:GetTextSize(message, fontSize, Enum.Font.Nunito, Vector2.new(remainingWidth, 10000))
	local messageHeight = math.max(fontSize + 12, messageBounds.Y + 10)
	local bannerHeight = math.max(fontSize + 18, messageHeight)
	local totalWidth = math.min(availableWidth, prefixWidth + math.min(remainingWidth, messageBounds.X + 8))

	banner.Size = UDim2.fromOffset(totalWidth, bannerHeight)
	bannerLine.TextSize = fontSize
	local roleColor = (incomingRole == "OWNER" or incomingRole == "MASTER DEVELOPER")
		and "rgb(234,197,108)" or "rgb(166,201,133)"
	bannerLine.Text = string.format(
		'<font color="%s"><b>%s</b></font><b>%s</b> <font color="rgb(54,151,238)">%s</font><font color="rgb(241,245,239)">%s</font>',
		roleColor,
		escapeRichText(roleText),
		escapeRichText(authorText),
		"✓",
		escapeRichText(" : " .. message)
	)

	bannerToken += 1
	local token = bannerToken
	if bannerTween then bannerTween:Cancel(); bannerTween = nil end
	bannerPreview.Visible = preview == true
	banner.Visible = true
	bannerLine.TextTransparency = 1
	local y = 76
	banner.Position = UDim2.new(0.5, 0, 0, y - 10)
	bannerTween = TweenService:Create(bannerLine, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 0,
	})
	bannerTween:Play()
	TweenService:Create(banner, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, y),
	}):Play()

	if not preview then
		announcementSound:Stop()
		announcementSound.TimePosition = 0
		announcementSound:Play()
	end

	task.delay(math.clamp(tonumber(data.duration) or 8, 3, 12), function()
		if bannerToken ~= token then return end
		local fade = TweenService:Create(bannerLine, TweenInfo.new(0.2), {TextTransparency = 1})
		fade:Play()
		fade.Completed:Once(function()
			if bannerToken == token then
				banner.Visible = false
				bannerPreview.Visible = false
			end
		end)
	end)
end

gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	if banner.Visible then
		local fontSize = math.clamp(math.floor(math.min(gui.AbsoluteSize.X, gui.AbsoluteSize.Y) / 28), 19, 27)
		bannerLine.TextSize = fontSize
	end
end)

local launcher = button(gui, "ADMIN", function() end, {size = UDim2.fromOffset(116, 40), primary = true, textSize = 12})
launcher.Name = "PalmVilleAdminLauncherV2"
launcher.AnchorPoint = Vector2.new(1, 0)
launcher.Position = UDim2.new(1, -22, 0, 20)
launcher.Visible = false

local shade = make("TextButton", {
	Name = "AdminShadeV2",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.42,
	Text = "",
	AutoButtonColor = false,
	Visible = false,
	ZIndex = 20,
}, gui)

local panel = make("Frame", {
	Name = "AdminPanelV2",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(1080, 690),
	BackgroundColor3 = C.bg,
	BorderSizePixel = 0,
	Visible = false,
	Active = true,
	ZIndex = 21,
}, gui)
addCorner(panel, 15)
addStroke(panel, C.line, 0.05)
local panelScale = make("UIScale", {Scale = 1}, panel)

local sidebar = make("Frame", {
	Size = UDim2.new(0, 218, 1, 0),
	BackgroundColor3 = C.panel,
	BorderSizePixel = 0,
	ZIndex = 22,
}, panel)
addCorner(sidebar, 15)
local sideMask = make("Frame", {
	Position = UDim2.new(1, -15, 0, 0),
	Size = UDim2.new(0, 15, 1, 0),
	BackgroundColor3 = C.panel,
	BorderSizePixel = 0,
	ZIndex = 22,
}, sidebar)
local profileName = text(sidebar, "PalmVille Admin", 17, C.text, 24, true)
profileName.Position = UDim2.fromOffset(18, 20)
profileName.Size = UDim2.new(1, -36, 0, 24)
local profileUser = text(sidebar, "Verifying account...", 11, C.muted, 18)
profileUser.Position = UDim2.fromOffset(18, 48)
profileUser.Size = UDim2.new(1, -36, 0, 18)
local profileRole = make("TextLabel", {
	Position = UDim2.fromOffset(18, 78),
	Size = UDim2.fromOffset(90, 22),
	BackgroundColor3 = C.green,
	BorderSizePixel = 0,
	Text = "STAFF",
	TextColor3 = C.text,
	Font = Enum.Font.Nunito,
	TextSize = 10,
}, sidebar)
addCorner(profileRole, 6)
local sideDivider = make("Frame", {
	Position = UDim2.fromOffset(16, 117),
	Size = UDim2.new(1, -32, 0, 1),
	BackgroundColor3 = C.line,
	BorderSizePixel = 0,
}, sidebar)

local header = make("Frame", {
	Position = UDim2.fromOffset(218, 0),
	Size = UDim2.new(1, -218, 0, 66),
	BackgroundColor3 = C.panel,
	BorderSizePixel = 0,
	ZIndex = 22,
}, panel)
local pageTitle = text(header, "Overview", 18, C.text, 26, true)
pageTitle.Position = UDim2.fromOffset(24, 12)
pageTitle.Size = UDim2.new(1, -100, 0, 26)
local pageSubtitle = text(header, "PalmVille server administration", 10, C.muted, 16)
pageSubtitle.Position = UDim2.fromOffset(24, 37)
pageSubtitle.Size = UDim2.new(1, -100, 0, 16)
local closeButton = button(header, "×", function()
	panelOpen = false
end, {size = UDim2.fromOffset(36, 36), textSize = 22})
closeButton.AnchorPoint = Vector2.new(1, 0.5)
closeButton.Position = UDim2.new(1, -16, 0.5, 0)

local content = make("Frame", {
	Position = UDim2.fromOffset(218, 66),
	Size = UDim2.new(1, -218, 1, -100),
	BackgroundTransparency = 1,
	ClipsDescendants = true,
	ZIndex = 22,
}, panel)
local footer = text(panel, "READY", 10, C.dim, 22)
footer.Position = UDim2.new(0, 240, 1, -28)
footer.Size = UDim2.new(1, -260, 0, 18)

local function setStatus(message, isError)
	footer.Text = tostring(message or "")
	footer.TextColor3 = isError and Color3.fromRGB(235, 145, 145) or C.greenBright
end

local pages = {}
local navButtons = {}
local navOrder = {
	{"OVERVIEW", "Overview", nil},
	{"PLAYERS", "Players", "Players"},
	{"ANNOUNCEMENTS", "Announcements", "Announcements"},
	{"MODERATION", "Moderation", "Moderation"},
	{"STAFF", "Staff & Roles", "MANAGER"},
	{"TOOLS", "Tools", "Tools"},
	{"LOGS", "Logs", "Logs"},
}

for navIndex, entry in ipairs(navOrder) do
	local key, caption = entry[1], entry[2]
	local nav = button(sidebar, caption, function()
		activeTab = key
	end, {size = UDim2.new(1, -26, 0, 38), textSize = 12})
	nav.Name = "Nav_" .. key
	nav.Position = UDim2.fromOffset(13, 134 + ((navIndex - 1) * 45))
	nav.TextXAlignment = Enum.TextXAlignment.Left
	make("UIPadding", {PaddingLeft = UDim.new(0, 12)}, nav)
	navButtons[key] = nav

	local page = make("ScrollingFrame", {
		Name = "Page_" .. key,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.dim,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
	}, content)
	make("UIPadding", {
		PaddingTop = UDim.new(0, 20),
		PaddingBottom = UDim.new(0, 24),
		PaddingLeft = UDim.new(0, 22),
		PaddingRight = UDim.new(0, 22),
	}, page)
	vertical(page, 12)
	pages[key] = page
end

local function refreshNavigation()
	for _, entry in ipairs(navOrder) do
		local key, area = entry[1], entry[3]
		local allowed = area == nil or (area == "MANAGER" and managerRole()) or (area ~= "MANAGER" and canAccess(area))
		local nav = navButtons[key]
		nav.Visible = allowed
		local active = activeTab == key
		nav.BackgroundColor3 = active and C.green or C.surface
		nav.TextColor3 = active and C.text or C.muted
		pages[key].Visible = panelOpen and active and allowed
	end
	if activeTab == "STAFF" and not managerRole() then activeTab = "OVERVIEW" end
	if activeTab == "PLAYERS" and not canAccess("Players") then activeTab = "OVERVIEW" end
	pageTitle.Text = ({
		OVERVIEW = "Overview",
		PLAYERS = "Players",
		ANNOUNCEMENTS = "Announcements",
		MODERATION = "Moderation",
		STAFF = "Staff & Roles",
		TOOLS = "Tools",
		LOGS = "Logs",
	})[activeTab] or "Overview"
end

for key, nav in pairs(navButtons) do
	nav.Activated:Connect(function()
		activeTab = key
		refreshNavigation()
		if key == "OVERVIEW" then remote:FireServer("RequestSnapshot") end
		if key == "PLAYERS" then remote:FireServer("RequestSnapshot") end
		if key == "STAFF" then remote:FireServer("RequestStaff") end
		if key == "LOGS" then remote:FireServer("RequestLogs") end
	end)
end

local function showPageStatus(parent, message)
	local item = text(parent, message, 11, C.muted, 24)
	return item
end

local function metric(parent, caption, initial)
	local box = make("Frame", {
		Size = UDim2.new(0.24, -8, 0, 82),
		BackgroundColor3 = C.surface,
		BorderSizePixel = 0,
	}, parent)
	addCorner(box, 9)
	addStroke(box, C.line, 0.25)
	local small = text(box, caption, 10, C.muted, 16)
	small.Position = UDim2.fromOffset(12, 11)
	small.Size = UDim2.new(1, -24, 0, 16)
	local value = text(box, initial or "—", 23, C.text, 31, true)
	value.Position = UDim2.fromOffset(12, 34)
	value.Size = UDim2.new(1, -24, 0, 31)
	return value
end

local overviewCard = card(pages.OVERVIEW, "SERVER OVERVIEW", "Live session metrics from the authoritative server.")
local metricRow = addRow(overviewCard, 82)
local metricPlayers = metric(metricRow, "PLAYERS ONLINE", "0 / 6")
local metricFps = metric(metricRow, "SERVER FPS", "—")
local metricUptime = metric(metricRow, "UPTIME", "—")
local metricMemory = metric(metricRow, "MEMORY", "—")
local overviewActions = card(pages.OVERVIEW, "QUICK ACTIONS", "Refresh server status and open the main management pages.")
local quickRow = addRow(overviewActions, 38)
button(quickRow, "REFRESH OVERVIEW", function() remote:FireServer("RequestSnapshot") end, {size = UDim2.new(0.5, -4, 0, 36), primary = true})
button(quickRow, "VIEW PLAYERS", function() activeTab = "PLAYERS"; refreshNavigation(); remote:FireServer("RequestSnapshot") end, {size = UDim2.new(0.5, -4, 0, 36)})
local identityCard = card(pages.OVERVIEW, "SESSION IDENTITY", "Authorization is resolved by PalmVilleAdminServerV2.")
local identityLabel = text(identityCard, "Waiting for server authorization...", 12, C.muted, 42)
local overviewHint = text(pages.OVERVIEW, "The game is limited to six players per server. Changes made in Studio DataStore fallback mode are temporary for that session.", 10, C.dim, 32)

local playersCard = card(pages.PLAYERS, "PLAYER DIRECTORY", "Players currently in this server. Select a player before using an action.")
local playersRefresh = button(playersCard, "REFRESH PLAYER LIST", function() remote:FireServer("RequestSnapshot") end, {primary = true})
local selectedLabel = text(playersCard, "No player selected.", 12, C.muted, 24)
local playerRows = make("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1}, playersCard)
vertical(playerRows, 5)
local playerActions = card(pages.PLAYERS, "PLAYER ACTIONS", "Server-side permission and target protection are enforced for every action.")
local playerActionRow1 = addRow(playerActions, 36)
button(playerActionRow1, "TELEPORT TO", function()
	if not selectedUserId then setStatus("Select a player first.", true); return end
	sendAction("Teleport", targetData())
end, {size = UDim2.new(0.5, -4, 0, 34)})
button(playerActionRow1, "BRING", function()
	if not selectedUserId then setStatus("Select a player first.", true); return end
	sendAction("Bring", targetData())
end, {size = UDim2.new(0.5, -4, 0, 34), primary = true})
local playerActionRow2 = addRow(playerActions, 36)
button(playerActionRow2, "RESET PLAYER", function()
	if not selectedUserId then setStatus("Select a player first.", true); return end
	sendAction("ResetTarget", targetData())
end, {size = UDim2.new(0.5, -4, 0, 34), danger = true})
button(playerActionRow2, "RETURN TO PREVIOUS POSITION", function()
	sendAction("Return")
end, {size = UDim2.new(0.5, -4, 0, 34)})

local playerActionRow3 = addRow(playerActions, 36)
button(playerActionRow3, "FREEZE", function()
	if not selectedUserId then setStatus("Select a player first.", true); return end
	sendAction("Freeze", targetData())
end, {size = UDim2.new(0.25, -6, 0, 34)})
button(playerActionRow3, "UNFREEZE", function()
	if not selectedUserId then setStatus("Select a player first.", true); return end
	sendAction("Unfreeze", targetData())
end, {size = UDim2.new(0.25, -6, 0, 34)})
button(playerActionRow3, "SPECTATE", function()
	if not selectedUserId then setStatus("Select a player first.", true); return end
	sendAction("Spectate", targetData())
end, {size = UDim2.new(0.25, -6, 0, 34)})
button(playerActionRow3, "STOP SPECTATING", function()
	sendAction("StopSpectate")
end, {size = UDim2.new(0.25, -6, 0, 34)})

local function renderPlayers()
	for _, child in ipairs(playerRows:GetChildren()) do
		if child:IsA("TextButton") or child:IsA("Frame") then child:Destroy() end
	end
	local roster = snapshot.players or {}
	if #roster == 0 then
		showPageStatus(playerRows, "No players are currently listed. Use Refresh Player List.")
		return
	end
	for _, row in ipairs(roster) do
		local item = button(playerRows, string.format("%s   ·   %s   ·   %d/%d HP", row.username or "Player", displayRole(row.role), row.health or 0, row.maxHealth or 0), function()
			selectedUserId = row.userId
			selectedUsername = row.username
			selectedLabel.Text = string.format("SELECTED  ·  %s (@%s)  ·  %s", row.displayName or row.username, row.username, displayRole(row.role))
			for _, child in ipairs(playerRows:GetChildren()) do
				if child:IsA("TextButton") then
					child.BackgroundColor3 = child:GetAttribute("UserId") == selectedUserId and C.green or C.surface
				end
			end
		end, {size = UDim2.new(1, 0, 0, 38)})
		item:SetAttribute("UserId", row.userId)
		item.BackgroundColor3 = row.userId == selectedUserId and C.green or C.surface
	end
end

local announceCard = card(pages.ANNOUNCEMENTS, "NEW ANNOUNCEMENT", "Send to this server or every active PalmVille server.")
local announceBox = make("TextBox", {
	Size = UDim2.new(1, 0, 0, 118),
	BackgroundColor3 = C.bg,
	BorderSizePixel = 0,
	ClearTextOnFocus = false,
	Font = Enum.Font.Nunito,
	TextSize = 14,
	TextColor3 = C.text,
	PlaceholderColor3 = C.dim,
	PlaceholderText = "Write your announcement...",
	Text = "",
	TextWrapped = true,
	MultiLine = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
}, announceCard)
addCorner(announceBox, 8)
addStroke(announceBox, C.line, 0.12)
make("UIPadding", {PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 11), PaddingRight = UDim.new(0, 11)}, announceBox)
local announceCount = text(announceCard, "0 / 280", 10, C.dim, 16)
announceBox:GetPropertyChangedSignal("Text"):Connect(function()
	announceCount.Text = tostring(#announceBox.Text) .. " / 280"
	announceCount.TextColor3 = #announceBox.Text > 280 and C.red or C.dim
end)
local audienceRow = addRow(announceCard, 38)
local serverAudience
local allAudience
serverAudience = button(audienceRow, "THIS SERVER  ✓", function()
	audience = "This Server"
	serverAudience.Text = "THIS SERVER  ✓"
	allAudience.Text = "ALL SERVERS"
	serverAudience.BackgroundColor3 = C.green
	allAudience.BackgroundColor3 = C.surface
end, {size = UDim2.new(0.5, -4, 0, 36), primary = true})
allAudience = button(audienceRow, "ALL SERVERS", function()
	audience = "All Servers"
	serverAudience.Text = "THIS SERVER"
	allAudience.Text = "ALL SERVERS  ✓"
	serverAudience.BackgroundColor3 = C.surface
	allAudience.BackgroundColor3 = C.green
end, {size = UDim2.new(0.5, -4, 0, 36)})
local announceButtons = addRow(announceCard, 38)
button(announceButtons, "PREVIEW", function()
	local value = announceBox.Text
	if value:gsub("%s", "") == "" then setStatus("Enter an announcement first.", true); return end
	if #value > 280 or not utf8.len(value) then setStatus("Announcement must be 280 characters or fewer.", true); return end
	showAnnouncement({role = role, by = managerRole() and "Lupin" or player.DisplayName, text = value, duration = 8}, true)
	setStatus("Preview shown. Only you can see it.")
end, {size = UDim2.new(0.5, -4, 0, 36)})
button(announceButtons, "SEND ANNOUNCEMENT", function()
	local value = announceBox.Text
	if value:gsub("%s", "") == "" then setStatus("Enter an announcement first.", true); return end
	if #value > 280 or not utf8.len(value) then setStatus("Announcement must be 280 characters or fewer.", true); return end
	sendAction("Announce", {message = value, audience = audience})
	setStatus("Sending announcement...")
end, {size = UDim2.new(0.5, -4, 0, 36), primary = true})
showPageStatus(announceCard, "Only Owner, Developer, and Head Admin can send announcements. All Servers is disabled in Studio.")

local moderationCard = card(pages.MODERATION, "TARGET PLAYER", "Online targets are required for warning, mute, kick, and bans. Unban/history can use a username.")
local moderationUsername = addField(moderationCard, "USERNAME", "Select from Players or enter username")
local reasonBox = addField(moderationCard, "REASON", "Reason required for warn, kick, and ban")
local durationBox = addField(moderationCard, "TEMP BAN DAYS", "1–365", "1")

local function moderationTarget()
	local username = tostring(moderationUsername.Text or "")
	if username == "" and selectedUsername then username = selectedUsername end
	local userId = selectedUserId
	if selectedUsername and string.lower(username) ~= string.lower(selectedUsername) then
		userId = nil
	end
	return {targetUserId = userId, username = username}
end
local modActionRow1 = addRow(moderationCard, 36)
button(modActionRow1, "WARN", function()
	local target = moderationTarget()
	target.username = moderationUsername.Text
	target.reason = reasonBox.Text
	if target.reason:gsub("%s", "") == "" then setStatus("A reason is required.", true); return end
	sendAction("Warn", target)
end, {size = UDim2.new(0.33, -5, 0, 34)})
button(modActionRow1, "TOGGLE CHAT MUTE", function()
	local target = moderationTarget()
	target.username = moderationUsername.Text
	sendAction("MuteChat", target)
end, {size = UDim2.new(0.33, -5, 0, 34)})
button(modActionRow1, "KICK", function()
	local target = moderationTarget()
	target.username = moderationUsername.Text
	target.reason = reasonBox.Text
	if target.reason:gsub("%s", "") == "" then setStatus("A reason is required.", true); return end
	sendAction("Kick", target)
end, {size = UDim2.new(0.34, -5, 0, 34), danger = true})
local modActionRow2 = addRow(moderationCard, 36)
button(modActionRow2, "TEMP BAN", function()
	local target = moderationTarget()
	target.username = moderationUsername.Text
	target.reason = reasonBox.Text
	target.durationDays = math.clamp(math.floor(tonumber(durationBox.Text) or 1), 1, 365)
	if target.reason:gsub("%s", "") == "" then setStatus("A reason is required.", true); return end
	sendAction("TempBan", target)
end, {size = UDim2.new(0.33, -5, 0, 34), danger = true})
button(modActionRow2, "PERMANENT BAN", function()
	local target = moderationTarget()
	target.username = moderationUsername.Text
	target.reason = reasonBox.Text
	if target.reason:gsub("%s", "") == "" then setStatus("A reason is required.", true); return end
	sendAction("PermanentBan", target)
end, {size = UDim2.new(0.33, -5, 0, 34), danger = true})
button(modActionRow2, "UNBAN", function()
	local target = moderationTarget()
	target.username = moderationUsername.Text
	target.reason = reasonBox.Text
	sendAction("Unban", target)
end, {size = UDim2.new(0.34, -5, 0, 34)})
local historyCard = card(pages.MODERATION, "MODERATION HISTORY", "Saved actions for the entered or selected account.")
local historyButton = button(historyCard, "LOAD HISTORY", function()
	local target = moderationTarget()
	target.username = moderationUsername.Text
	if not target.targetUserId and target.username == "" then setStatus("Enter a username or select a player.", true); return end
	sendAction("ModerationHistory", target)
end, {primary = true})
local historyText = text(historyCard, "No history loaded.", 11, C.muted, 90)
historyText.TextYAlignment = Enum.TextYAlignment.Top

local staffCard = card(pages.STAFF, "STAFF MANAGEMENT", "Owner and Developer only. The server validates all role changes.")
local staffUsername = addField(staffCard, "ROBLOX USERNAME", "Username to assign")
local staffRole = "ADMIN"
local staffRoleRow = addRow(staffCard, 34)
for _, staffRoleName in ipairs({"HEAD ADMIN", "ADMIN", "MODERATOR", "HELPER"}) do
	button(staffRoleRow, staffRoleName, function(b)
		staffRole = staffRoleName
		for _, other in ipairs(staffRoleRow:GetChildren()) do
			if other:IsA("TextButton") then other.BackgroundColor3 = other == b and C.green or C.surface end
		end
	end, {size = UDim2.new(0.25, -6, 0, 32), textSize = 10})
end
local staffActions = addRow(staffCard, 36)
button(staffActions, "ASSIGN ROLE", function()
	if staffUsername.Text:gsub("%s", "") == "" then setStatus("Enter a Roblox username.", true); return end
	sendAction("AddStaff", {username = staffUsername.Text, role = staffRole})
end, {size = UDim2.new(0.5, -4, 0, 34), primary = true})
button(staffActions, "REMOVE SELECTED", function()
	if not selectedStaffId then setStatus("Select a staff account first.", true); return end
	sendAction("RemoveStaff", {targetUserId = selectedStaffId})
end, {size = UDim2.new(0.5, -4, 0, 34), danger = true})
local staffListCard = card(pages.STAFF, "AUTHORIZED STAFF", "Select a row to prepare removal.")
local staffList = make("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1}, staffListCard)
vertical(staffList, 4)
local permissionsCard = card(pages.STAFF, "ROLE PERMISSIONS", "Change which sections an assignable role may access.")
local permissionRole = "ADMIN"
local permissionRoleRow = addRow(permissionsCard, 34)
for _, permissionRoleName in ipairs({"HEAD ADMIN", "ADMIN", "MODERATOR", "HELPER"}) do
	button(permissionRoleRow, permissionRoleName, function(b)
		permissionRole = permissionRoleName
		for _, other in ipairs(permissionRoleRow:GetChildren()) do
			if other:IsA("TextButton") then other.BackgroundColor3 = other == b and C.green or C.surface end
		end
		remote:FireServer("RequestStaff")
	end, {size = UDim2.new(0.25, -6, 0, 32), textSize = 10})
end
local permissionList = make("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1}, permissionsCard)
vertical(permissionList, 4)

local toolsCard = card(pages.TOOLS, "GIVE ITEM", "Uses the registered item catalog and server-enforced role limits.")
local itemCode = addField(toolsCard, "ITEM CODE", "Registered item code", "RICE_SEED")
local itemAmount = addField(toolsCard, "AMOUNT", "1–99", "1")
local itemModeRow = addRow(toolsCard, 34)
for _, mode in ipairs({"Player", "Self", "All"}) do
	button(itemModeRow, string.upper(mode), function(b)
		itemTargetMode = mode
		for _, other in ipairs(itemModeRow:GetChildren()) do
			if other:IsA("TextButton") then other.BackgroundColor3 = other == b and C.green or C.surface end
		end
	end, {size = UDim2.new(0.33, -5, 0, 32)})
end
button(toolsCard, "GIVE REGISTERED ITEM", function()
	if itemTargetMode == "Player" and not selectedUserId then setStatus("Select a player in Players first.", true); return end
	sendAction("GiveItem", {
		itemCode = itemCode.Text,
		amount = tonumber(itemAmount.Text),
		targetMode = itemTargetMode,
		targetUserId = selectedUserId,
		username = selectedUsername,
	})
end, {primary = true})
local toolsToggleCard = card(pages.TOOLS, "PLAYER OPTIONS", "Server-side tools with the existing Admin V2 permission checks.")
button(toolsToggleCard, "TOGGLE INVISIBILITY", function()
	invisibleEnabled = not invisibleEnabled
	sendAction("SetInvisible", {enabled = invisibleEnabled})
end)
button(toolsToggleCard, "TOGGLE ADMIN ROLE TITLE", function()
	adminTitleEnabled = not adminTitleEnabled
	sendAction("SetAdminTitle", {enabled = adminTitleEnabled})
end)

local logsCard = card(pages.LOGS, "SERVER ACTIVITY", "Recent server-side administrative actions.")
button(logsCard, "REFRESH LOGS", function() remote:FireServer("RequestLogs") end, {primary = true})
local logList = make("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1}, logsCard)
vertical(logList, 5)

local function renderStaff()
	for _, child in ipairs(staffList:GetChildren()) do
		if child:IsA("TextButton") or child:IsA("TextLabel") then child:Destroy() end
	end
	if #staffRows == 0 then
		showPageStatus(staffList, "No assignable staff records were returned.")
	else
		table.sort(staffRows, function(a, b) return tostring(a.role) < tostring(b.role) end)
		for _, row in ipairs(staffRows) do
			local name = tostring(row.username or row.name or row.userId or "Staff")
			local item = button(staffList, string.format("%s  ·  %s  ·  %s", name, displayRole(row.role), row.online and "ONLINE" or "OFFLINE"), function(b)
				selectedStaffId = tonumber(row.userId)
				selectedUserId = tonumber(row.userId)
				selectedUsername = name
				moderationUsername.Text = name
				selectedLabel.Text = "SELECTED  ·  " .. name
				for _, other in ipairs(staffList:GetChildren()) do
					if other:IsA("TextButton") then other.BackgroundColor3 = other == b and C.green or C.surface end
				end
			end, {size = UDim2.new(1, 0, 0, 34)})
			item.BackgroundColor3 = selectedStaffId == tonumber(row.userId) and C.green or C.surface
		end
	end

	for _, child in ipairs(permissionList:GetChildren()) do
		if child:IsA("TextButton") or child:IsA("TextLabel") then child:Destroy() end
	end
	local current = allPermissions[permissionRole] or {}
	for _, area in ipairs({"Players", "Monitoring", "Announcements", "GiveItem", "Environment", "Moderation", "Tools", "Logs", "Server"}) do
		local enabled = current[area] == true
		button(permissionList, area .. "   ·   " .. (enabled and "ON" or "OFF"), function()
			sendAction("SetPermission", {role = permissionRole, area = area, enabled = not enabled})
		end, {size = UDim2.new(1, 0, 0, 32), primary = enabled})
	end
end

local function renderLogs()
	for _, child in ipairs(logList:GetChildren()) do
		if child:IsA("TextLabel") or child:IsA("Frame") then child:Destroy() end
	end
	if #logs == 0 then
		showPageStatus(logList, "No activity records received.")
		return
	end
	for index = 1, math.min(#logs, 40) do
		local row = logs[index]
		local titleLine = tostring(row.action or row.event or "Admin action")
		local detail = string.format("%s  ·  %s  ·  %s", tostring(row.actor or row.username or "Unknown"), tostring(row.target or "—"), tostring(row.result or row.status or "Recorded"))
		local line = make("Frame", {Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = C.surface, BorderSizePixel = 0}, logList)
		addCorner(line, 7)
		local titleLabel = text(line, titleLine, 12, C.text, 18, true)
		titleLabel.Position = UDim2.fromOffset(10, 5)
		titleLabel.Size = UDim2.new(1, -20, 0, 18)
		local detailLabel = text(line, detail, 10, C.muted, 16)
		detailLabel.Position = UDim2.fromOffset(10, 25)
		detailLabel.Size = UDim2.new(1, -20, 0, 16)
	end
end

local function renderHistory()
	local lines = {}
	for index = 1, math.min(#history, 12) do
		local row = history[index]
		table.insert(lines, string.format("%s  ·  %s  ·  %s", os.date("%m/%d %H:%M", tonumber(row.time) or 0), tostring(row.action or ""), tostring(row.reason or "")))
	end
	historyText.Text = #lines > 0 and table.concat(lines, "\n") or "No saved moderation history."
end

local function updateMetrics()
	local metrics = snapshot.metrics or {}
	metricPlayers.Text = string.format("%s / %s", tostring(metrics.playerCount or #snapshot.players), tostring(metrics.maxPlayers or 6))
	metricFps.Text = tostring(metrics.serverFps or "—")
	metricUptime.Text = tostring(metrics.uptime or 0) .. "s"
	metricMemory.Text = metrics.memoryMb and (tostring(metrics.memoryMb) .. " MB") or "—"
	renderPlayers()
end

local function applyPanel()
	shade.Visible = panelOpen
	panel.Visible = panelOpen
	refreshNavigation()
end

local function fitPanel()
	local size = gui.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then return end
	panelScale.Scale = math.min(1, (size.X - 24) / 1080, (size.Y - 24) / 690)
end

gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitPanel)
task.defer(fitPanel)

launcher.Activated:Connect(function()
	if authorized then
		panelOpen = not panelOpen
		applyPanel()
	end
end)
closeButton.Activated:Connect(function()
	panelOpen = false
	applyPanel()
end)
shade.Activated:Connect(function()
	panelOpen = false
	applyPanel()
end)

UserInputService.InputBegan:Connect(function(inputObject, processed)
	if processed then return end
	if inputObject.KeyCode == Enum.KeyCode.RightShift and authorized then
		panelOpen = not panelOpen
		applyPanel()
	end
	if inputObject.KeyCode == Enum.KeyCode.Escape and panelOpen then
		panelOpen = false
		applyPanel()
	end
end)

local function restoreCamera()
	if savedCamera then
		local camera = Workspace.CurrentCamera
		if camera then
			camera.CameraType = savedCamera.type
			camera.CameraSubject = savedCamera.subject
			camera.FieldOfView = savedCamera.fov
		end
	end
	savedCamera = nil
end

remote.OnClientEvent:Connect(function(event, data)
	if event == "AccessGranted" then
		if type(data) ~= "table" or type(data.role) ~= "string" then return end
		role = data.role
		permissions = type(data.permissions) == "table" and data.permissions or {}
		authorized = true
		launcher.Visible = true
		profileUser.Text = "@" .. player.Name
		profileRole.Text = displayRole(role)
		identityLabel.Text = string.format("Signed in as %s  ·  %s\nUserId: %d", player.Name, role, player.UserId)
		setStatus("AUTHORIZED  ·  " .. role)
		refreshNavigation()
		if canAccess("Monitoring") or canAccess("Server") then remote:FireServer("RequestSnapshot") end
		if managerRole() then remote:FireServer("RequestStaff") end
	elseif event == "AccessDenied" then
		authorized = false
		launcher.Visible = false
	elseif event == "Notice" then
		setStatus(tostring(data), true)
	elseif event == "Snapshot" then
		if type(data) == "table" then
			snapshot = data
			updateMetrics()
			if activeTab == "PLAYERS" then renderPlayers() end
		end
	elseif event == "StaffData" then
		if type(data) == "table" then
			staffRows = type(data.staff) == "table" and data.staff or {}
			allPermissions = type(data.permissions) == "table" and data.permissions or {}
			permissions = allPermissions[role] or permissions
			renderStaff()
			refreshNavigation()
		end
	elseif event == "LogsData" then
		logs = type(data) == "table" and data or {}
		renderLogs()
	elseif event == "ModerationHistory" then
		history = type(data) == "table" and data.items or {}
		renderHistory()
	elseif event == "Announcement" then
		showAnnouncement(data, false)
	elseif event == "AnnouncementSent" then
		if type(data) == "table" then
			if announceBox.Text == data.message then announceBox.Text = "" end
			setStatus(data.delivered and "ANNOUNCEMENT SENT" or "ANNOUNCEMENT DELIVERY INCOMPLETE", not data.delivered)
		end
	elseif event == "Warning" then
		setStatus("STAFF WARNING  ·  " .. tostring(data), true)
	elseif event == "ChatMuteState" then
		setStatus(data and "TEXT CHAT MUTED" or "TEXT CHAT UNMUTED")
	elseif event == "SetInvisible" then
		invisibleEnabled = data == true
	elseif event == "SetAdminTitle" then
		adminTitleEnabled = data == true
	elseif event == "SpectateStarted" then
		local target = type(data) == "table" and Players:GetPlayerByUserId(tonumber(data.targetUserId))
		if target and target.Character then
			local camera = Workspace.CurrentCamera
			if camera then
				savedCamera = savedCamera or {type = camera.CameraType, subject = camera.CameraSubject, fov = camera.FieldOfView}
				camera.CameraType = Enum.CameraType.Custom
				camera.CameraSubject = target.Character:FindFirstChildOfClass("Humanoid")
			end
		end
	elseif event == "SpectateStopped" then
		restoreCamera()
	end
end)

local function runAccessHandshake()
	for _ = 1, 8 do
		if authorized then return end
		remote:FireServer("RequestAccess")
		task.wait(1.5)
	end
end

task.spawn(runAccessHandshake)
