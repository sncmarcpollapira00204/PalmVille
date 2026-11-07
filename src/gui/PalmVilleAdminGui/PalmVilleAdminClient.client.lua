local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
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
	bg = Color3.fromRGB(13, 14, 16),
	panel = Color3.fromRGB(20, 21, 24),
	surface = Color3.fromRGB(29, 30, 34),
	surfaceHover = Color3.fromRGB(43, 44, 49),
	green = Color3.fromRGB(69, 71, 78),
	greenBright = Color3.fromRGB(255, 255, 255),
	line = Color3.fromRGB(49, 50, 56),
	text = Color3.fromRGB(248, 249, 251),
	muted = Color3.fromRGB(178, 180, 187),
	dim = Color3.fromRGB(126, 129, 138),
	red = Color3.fromRGB(225, 145, 145),
	amber = Color3.fromRGB(232, 234, 238),
	blue = Color3.fromRGB(200, 210, 225),
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
local selectedLogUserIds = {}
local sortLogsByPlayer = false
local renderLogs
local selectedUserId
local selectedUsername
local selectedStaffId
local audience = "This Server"
local itemTargetMode = "Self"
local invisibleEnabled = false
local adminTitleEnabled = true
local flyEnabled = false
local frozenTargets = {}
local spectatingUserId
local watchScreenMode = false
local watchScreenToken
local cameraFeedToken
local cameraFeedConnection
local flyKeys = {}
local lastFlySend = 0
local moderationTargetUserId
local moderationTargetUsername
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
	make("UICorner", {CornerRadius = UDim.new(0, radius or 10)}, object)
end

local function addStroke(object, color, transparency, thickness)
	make("UIStroke", {
		Color = color or C.line,
		Transparency = transparency == nil and 0 or transparency,
		Thickness = thickness or 1.3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, object)
end

local function text(parent, value, size, color, height, bold)
	return make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height or 26),
		Text = tostring(value or ""),
		Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
		TextSize = math.max(10, math.floor((size or 15) * 0.9 + 0.5)),
		TextColor3 = color or C.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = true,
	}, parent)
end

local function drawIcon(parent, name, size, color)
	local root = make("Frame", {
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
	}, parent)
	local scale = size / 32
	local strokeColor = color or C.amber
	local thickness = math.max(1.4, 1.8 * scale)

	local function line(x1, y1, x2, y2, weight)
		local dx, dy = (x2 - x1) * scale, (y2 - y1) * scale
		local length = math.sqrt(dx * dx + dy * dy)
		local stroke = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset((x1 + x2) * 0.5 * scale, (y1 + y2) * 0.5 * scale),
			Size = UDim2.fromOffset(length, weight or thickness),
			Rotation = math.deg(math.atan2(dy, dx)),
			BackgroundColor3 = strokeColor,
			BorderSizePixel = 0,
		}, root)
		addCorner(stroke, 2)
	end

	local function ring(x, y, diameter, weight)
		local circle = make("Frame", {
			Position = UDim2.fromOffset(x * scale, y * scale),
			Size = UDim2.fromOffset(diameter * scale, diameter * scale),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, root)
		addCorner(circle, diameter * scale * 0.5)
		addStroke(circle, strokeColor, 0, weight or thickness)
	end

	local function box(x, y, width, height, radius)
		local outline = make("Frame", {
			Position = UDim2.fromOffset(x * scale, y * scale),
			Size = UDim2.fromOffset(width * scale, height * scale),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, root)
		addCorner(outline, (radius or 3) * scale)
		addStroke(outline, strokeColor, 0, thickness)
	end

	if name == "users" then
		ring(5, 4, 8)
		ring(20, 5, 7)
		line(1, 27, 1, 23)
		line(1, 23, 5, 18)
		line(5, 18, 12, 18)
		line(12, 18, 16, 23)
		line(16, 23, 16, 27)
		line(17, 21, 20, 17)
		line(20, 17, 26, 17)
		line(26, 17, 30, 22)
		line(30, 22, 30, 26)
	elseif name == "home" then
		line(3, 15, 16, 4)
		line(16, 4, 29, 15)
		line(7, 13, 7, 28)
		line(25, 13, 25, 28)
		line(7, 28, 25, 28)
		line(13, 28, 13, 19)
		line(13, 19, 19, 19)
		line(19, 19, 19, 28)
	elseif name == "megaphone" then
		line(4, 12, 23, 5)
		line(23, 5, 23, 26)
		line(23, 26, 4, 19)
		line(4, 19, 4, 12)
		line(8, 20, 12, 29)
		line(12, 29, 17, 28)
		line(27, 9, 30, 7)
		line(27, 16, 31, 16)
		line(27, 23, 30, 25)
	elseif name == "shield" then
		line(16, 3, 27, 7)
		line(27, 7, 26, 19)
		line(26, 19, 16, 29)
		line(16, 29, 6, 19)
		line(6, 19, 5, 7)
		line(5, 7, 16, 3)
		line(11, 16, 15, 20)
		line(15, 20, 22, 12)
	elseif name == "settings" then
		ring(9, 9, 14)
		ring(13, 13, 6)
		line(16, 2, 16, 7)
		line(16, 25, 16, 30)
		line(2, 16, 7, 16)
		line(25, 16, 30, 16)
		line(6, 6, 10, 10)
		line(22, 22, 26, 26)
		line(22, 10, 26, 6)
		line(6, 26, 10, 22)
	elseif name == "wrench" then
		line(8, 25, 22, 11)
		ring(3, 22, 8)
		line(21, 7, 25, 3)
		line(25, 3, 29, 7)
		line(29, 7, 25, 11)
		line(25, 11, 21, 7)
	elseif name == "file" then
		line(8, 3, 21, 3)
		line(21, 3, 26, 8)
		line(26, 8, 26, 29)
		line(26, 29, 7, 29)
		line(7, 29, 7, 3)
		line(7, 3, 8, 3)
		line(21, 3, 21, 8)
		line(21, 8, 26, 8)
		line(11, 15, 22, 15)
		line(11, 20, 22, 20)
		line(11, 25, 19, 25)
	elseif name == "clock" then
		ring(3, 3, 26)
		line(16, 8, 16, 16)
		line(16, 16, 22, 19)
	elseif name == "server" then
		box(4, 3, 24, 10, 2)
		box(4, 19, 24, 10, 2)
		ring(8, 6, 3, thickness)
		ring(8, 22, 3, thickness)
		line(15, 8, 25, 8)
		line(15, 24, 25, 24)
	elseif name == "globe" then
		ring(3, 3, 26)
		line(16, 3, 16, 29)
		line(4, 16, 28, 16)
		line(8, 6, 11, 16)
		line(11, 16, 8, 26)
		line(24, 6, 21, 16)
		line(21, 16, 24, 26)
	elseif name == "eye" then
		line(2, 16, 8, 9)
		line(8, 9, 16, 6)
		line(16, 6, 24, 9)
		line(24, 9, 30, 16)
		line(30, 16, 24, 23)
		line(24, 23, 16, 26)
		line(16, 26, 8, 23)
		line(8, 23, 2, 16)
		ring(12, 12, 8)
	elseif name == "send" then
		line(3, 15, 29, 3)
		line(29, 3, 20, 29)
		line(20, 29, 14, 19)
		line(14, 19, 3, 15)
		line(14, 19, 29, 3)
	end

	return root
end

local function setButtonBackground(target, color)
	if not target then return end
	target:SetAttribute("BaseBackgroundColor", color)
	if target:GetAttribute("PointerHover") ~= true then
		target.BackgroundColor3 = color
	end
end

local function button(parent, caption, callback, options)
	options = options or {}
	local baseColor = options.primary and C.green or C.surface
	local b = make("TextButton", {
		Size = options.size or UDim2.new(1, 0, 0, 46),
		BackgroundColor3 = baseColor,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = caption,
		TextColor3 = options.danger and Color3.fromRGB(255, 226, 218) or C.text,
		Font = options.bold and Enum.Font.GothamBold or Enum.Font.GothamMedium,
		TextSize = math.max(10, math.floor((options.textSize or 15) * 0.9 + 0.5)),
		TextWrapped = true,
	}, parent)
	b:SetAttribute("BaseBackgroundColor", baseColor)
	addCorner(b, options.radius or 11)
	b.MouseEnter:Connect(function()
		if not options.disabled then
			b:SetAttribute("PointerHover", true)
			b.BackgroundColor3 = options.danger and Color3.fromRGB(111, 45, 45) or C.surfaceHover
		end
	end)
	b.MouseLeave:Connect(function()
		b:SetAttribute("PointerHover", false)
		local restore = b:GetAttribute("BaseBackgroundColor")
		b.BackgroundColor3 = typeof(restore) == "Color3" and restore or baseColor
	end)
	b.Activated:Connect(function()
		if callback then callback(b) end
	end)
	return b
end

local function toggleRow(parent, labelText, initialState, callback, options)
	options = options or {}
	local enabled = initialState == true
	local row
	row = button(parent, "", function()
		enabled = not enabled
		local track, knob = row:FindFirstChild("ToggleTrack"), row:FindFirstChild("ToggleKnob", true)
		if track and knob then
			knob.Position = enabled and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
			track.BackgroundColor3 = enabled and C.text or C.surfaceHover
			knob.BackgroundColor3 = enabled and C.bg or C.text
		end
		if callback then callback(enabled) end
	end, {
		size = options.size or UDim2.new(1, 0, 0, 40),
		radius = options.radius or 9,
		textSize = 12,
	})
	row.BackgroundColor3 = C.surface
	row:SetAttribute("BaseBackgroundColor", C.surface)
	local label = text(row, labelText, options.textSize or 13, C.text, 22, true)
	label.Position = UDim2.fromOffset(14, 0)
	label.Size = UDim2.new(1, -76, 1, 0)
	label.ZIndex = row.ZIndex + 2
	local track = make("Frame", {
		Name = "ToggleTrack",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(38, 22),
		BackgroundColor3 = enabled and C.text or C.surfaceHover,
		BorderSizePixel = 0,
		ZIndex = row.ZIndex + 1,
	}, row)
	addCorner(track, 11)
	local knob = make("Frame", {
		Name = "ToggleKnob",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = enabled and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = enabled and C.bg or C.text,
		BorderSizePixel = 0,
		ZIndex = row.ZIndex + 2,
	}, track)
	addCorner(knob, 8)
	return {
		row = row,
		set = function(value)
			enabled = value == true
			knob.Position = enabled and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
			track.BackgroundColor3 = enabled and C.text or C.surfaceHover
			knob.BackgroundColor3 = enabled and C.bg or C.text
		end,
	}
end

local function iconButton(parent, caption, iconName, callback, options)
	options = options or {}
	local buttonOptions = table.clone(options)
	local target = button(parent, "", callback, buttonOptions)
	target.Text = ""
	target.TextXAlignment = Enum.TextXAlignment.Left

	local iconSize = options.iconSize or 20
	local iconRoot = drawIcon(target, iconName, iconSize, C.amber)
	iconRoot.Name = "ButtonIcon"
	iconRoot.Position = UDim2.new(0, 17, 0.5, -iconSize * 0.5)

	local label = text(target, caption, options.textSize or 16, options.danger and Color3.fromRGB(255, 226, 218) or C.text, 24, options.bold == true)
	label.Name = "ButtonLabel"
	label.Position = UDim2.new(0, 48, 0, 0)
	label.Size = UDim2.new(1, -62, 1, 0)
	label.TextWrapped = false
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.ZIndex = target.ZIndex + 2
	return target
end

local function input(parent, placeholder, defaultText, height)
	local box = make("TextBox", {
		Size = UDim2.new(1, 0, 0, height or 46),
		BackgroundColor3 = C.surface,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextColor3 = C.text,
		PlaceholderColor3 = C.dim,
		PlaceholderText = placeholder,
		Text = defaultText or "",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = false,
	}, parent)
	addCorner(box, 10)
		make("UIPadding", {
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 12),
	}, box)
	return box
end

local function vertical(parent, padding)
	return make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, padding or 12),
	}, parent)
end

local function card(parent, titleText, subtitle, icon)
	local root = make("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.panel,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
	}, parent)
	addCorner(root, 14)
	make("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 16),
		PaddingRight = UDim.new(0, 16),
	}, root)
	local layout = vertical(root, 7)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	if icon then
		local head = make("Frame", {Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1}, root)
		local headingIcon = drawIcon(head, icon, 28, C.amber)
		headingIcon.Position = UDim2.fromOffset(8, 8)
		local heading = text(head, titleText, 22, C.text, 28, true)
		heading.Position = UDim2.fromOffset(54, 0)
		heading.Size = UDim2.new(1, -54, 0, 28)
		local sub = text(head, subtitle or "", 13, C.muted, 18)
		sub.Position = UDim2.fromOffset(54, 27)
		sub.Size = UDim2.new(1, -54, 0, 18)
	else
		text(root, titleText, 24, C.text, 32, true)
		if subtitle and subtitle ~= "" then
			text(root, subtitle, 15, C.muted, 24)
		end
	end
	return root
end

local function addRow(parent, height)
	local row = make("Frame", {
		Size = UDim2.new(1, 0, 0, height or 46),
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
	text(parent, caption, 13, C.muted, 20, true)
	return input(parent, placeholder, defaultText)
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

local bannerStack = make("Frame", {
	Name = "AnnouncementBannerStack",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 86),
	Size = UDim2.new(1, -32, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	ClipsDescendants = false,
	ZIndex = 80,
}, gui)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Vertical,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Top,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 8),
}, bannerStack)

local bannerColors = {
	OWNER = Color3.fromRGB(234, 197, 108),
	["MASTER DEVELOPER"] = Color3.fromRGB(234, 197, 108),
	["HEAD ADMIN"] = Color3.fromRGB(166, 201, 133),
	ADMIN = Color3.fromRGB(166, 201, 133),
	MODERATOR = Color3.fromRGB(166, 201, 133),
	HELPER = Color3.fromRGB(166, 201, 133),
}

local activeAnnouncements = {}
local announcementSerial = 0

local function escapeRichText(value)
	return tostring(value):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
end

local function fitAnnouncement(entry)
	local data = entry.data
	local viewport = gui.AbsoluteSize
	local fontSize = viewport.X < 650 and 23 or 32
	local available = math.max(220, math.min(1180, viewport.X - 40))
	local incomingRole = tostring(data.role or "")
	local roleTag = incomingRole == "MASTER DEVELOPER" and "DEV" or displayRole(incomingRole)
	local authorName = tostring(data.by or (incomingRole == "MASTER DEVELOPER" and "Lupin" or "Staff")):gsub("[\r\n]", " ")
	local plainPrefix = "[" .. roleTag .. "] " .. authorName
	local prefixWidth = TextService:GetTextSize(
		plainPrefix,
		fontSize,
		Enum.Font.FredokaOne,
		Vector2.new(10000, 10000)
	).X + 4

	if prefixWidth > available * 0.65 then
		local nameLength = utf8.len(authorName) or #authorName
		if nameLength > 12 then
			local cut = utf8.offset(authorName, 13) or (#authorName + 1)
			authorName = authorName:sub(1, cut - 1) .. "…"
		end
		plainPrefix = "[" .. roleTag .. "] " .. authorName
		prefixWidth = TextService:GetTextSize(
			plainPrefix,
			fontSize,
			Enum.Font.FredokaOne,
			Vector2.new(10000, 10000)
		).X + 4
	end

	local badgeSize = 26
	local messageText = ": " .. tostring(data.text or ""):gsub("[\r\n]+", " ")
	local messageX = prefixWidth + badgeSize + 16
	local messageAvailable = math.max(80, available - messageX)
	local naturalWidth = TextService:GetTextSize(
		messageText,
		fontSize,
		Enum.Font.FredokaOne,
		Vector2.new(10000, 10000)
	).X + 6
	local messageWidth = math.min(messageAvailable, math.max(80, naturalWidth))
	local width = math.min(available, messageX + messageWidth)
	local messageBounds = TextService:GetTextSize(
		messageText,
		fontSize,
		Enum.Font.FredokaOne,
		Vector2.new(messageWidth, 10000)
	)
	local contentHeight = math.max(fontSize + 12, messageBounds.Y + 12)
	local previewOffset = entry.preview and 22 or 0

	entry.container.Size = UDim2.fromOffset(width, contentHeight + previewOffset)
	entry.prefix.Position = UDim2.fromOffset(0, previewOffset)
	entry.prefix.Size = UDim2.fromOffset(prefixWidth, fontSize + 8)
	entry.prefix.TextSize = fontSize

	local roleColor = bannerColors[incomingRole] or C.text
	entry.prefix.Text = string.format(
		'<b><font color="rgb(%d,%d,%d)">[%s]</font> %s</b>',
		math.round(roleColor.R * 255),
		math.round(roleColor.G * 255),
		math.round(roleColor.B * 255),
		escapeRichText(roleTag),
		escapeRichText(authorName)
	)

	entry.badge.Position = UDim2.fromOffset(prefixWidth + 3, previewOffset + math.floor((fontSize + 8 - badgeSize) / 2))
	entry.message.Position = UDim2.fromOffset(messageX, previewOffset)
	entry.message.Size = UDim2.fromOffset(messageWidth, math.max(fontSize + 10, messageBounds.Y + 12))
	entry.message.TextSize = fontSize
	entry.message.TextYAlignment = messageBounds.Y > fontSize + 8 and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center
	entry.message.Text = messageText

	entry.previewLabel.Visible = entry.preview
	entry.previewLabel.Size = UDim2.new(1, 0, 0, 18)
	entry.previewLabel.Position = UDim2.fromOffset(0, 0)
end

local function removeAnnouncement(entry)
	for index = #activeAnnouncements, 1, -1 do
		if activeAnnouncements[index] == entry then
			table.remove(activeAnnouncements, index)
			break
		end
	end
	if entry.container and entry.container.Parent then
		entry.container:Destroy()
	end
end

local function showAnnouncement(data, preview)
	if type(data) ~= "table" then return end
	local message = tostring(data.text or "")
	if message:gsub("%s", "") == "" then return end

	if not preview then
		announcementSound:Stop()
		announcementSound.TimePosition = 0
		announcementSound:Play()
	end

	announcementSerial += 1
	local baseInset = game:GetService("GuiService"):GetGuiInset()
	bannerStack.Position = UDim2.new(0.5, 0, 0, math.max(86, baseInset.Y + 26))

	local container = make("CanvasGroup", {
		Name = "Announcement_" .. announcementSerial,
		Size = UDim2.fromOffset(900, 60),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		LayoutOrder = announcementSerial,
		ZIndex = 80,
	}, bannerStack)

	local prefix = make("TextLabel", {
		Name = "AnnouncementPrefix",
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextSize = 32,
		TextColor3 = C.text,
		RichText = true,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0.35,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = false,
		ZIndex = 81,
	}, container)

	local badge = make("Frame", {
		Name = "AnnouncementVerifiedBadge",
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = Color3.fromRGB(0, 149, 255),
		BorderSizePixel = 0,
		ZIndex = 81,
	}, container)
	addCorner(badge, 13)
	make("Frame", {
		Position = UDim2.fromOffset(6, 13),
		Size = UDim2.fromOffset(7, 3),
		Rotation = 45,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 82,
	}, badge)
	make("Frame", {
		Position = UDim2.fromOffset(10, 11),
		Size = UDim2.fromOffset(12, 3),
		Rotation = -45,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 82,
	}, badge)

	local messageLabel = make("TextLabel", {
		Name = "AnnouncementMessage",
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextSize = 32,
		TextColor3 = C.text,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0.35,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = true,
		RichText = false,
		ZIndex = 81,
	}, container)

	local previewLabel = make("TextLabel", {
		Name = "PreviewLabel",
		BackgroundTransparency = 1,
		Text = "PREVIEW · ONLY YOU CAN SEE THIS",
		Font = Enum.Font.FredokaOne,
		TextSize = 15,
		TextColor3 = C.text,
		TextStrokeTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = preview == true,
		ZIndex = 82,
	}, container)

	local entry = {
		data = data,
		preview = preview == true,
		container = container,
		prefix = prefix,
		badge = badge,
		message = messageLabel,
		previewLabel = previewLabel,
	}
	table.insert(activeAnnouncements, entry)
	fitAnnouncement(entry)

	TweenService:Create(
		container,
		TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{GroupTransparency = 0}
	):Play()

	local duration = math.clamp(tonumber(data.duration) or 8, 3, 12)
	task.delay(duration, function()
		if not container.Parent then return end
		local fade = TweenService:Create(
			container,
			TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{GroupTransparency = 1}
		)
		fade.Completed:Connect(function()
			removeAnnouncement(entry)
		end)
		fade:Play()
	end)
end

gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	for _, entry in ipairs(activeAnnouncements) do
		if entry.container.Parent then
			fitAnnouncement(entry)
		end
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
	Size = UDim2.fromOffset(1040, 720),
	BackgroundColor3 = C.bg,
	BackgroundTransparency = 0,
	BorderSizePixel = 0,
	Visible = false,
	Active = true,
	ClipsDescendants = true,
	ZIndex = 21,
}, gui)
addCorner(panel, 25)
addStroke(panel, C.line, 0.45, 1)
make("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 20, 23)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 12, 14)),
	}),
	Rotation = 90,
}, panel)
local panelScale = make("UIScale", {Scale = 1}, panel)

local flyTouchControls = make("Frame", {
	Name = "FlyTouchControls",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -22, 1, -92),
	Size = UDim2.fromOffset(116, 104),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 80,
}, gui)

local function makeFlyHoldButton(caption, key, y)
	local hold = button(flyTouchControls, caption, nil, {
		size = UDim2.fromOffset(54, 46),
		textSize = 14,
		bold = true,
	})
	hold.Position = UDim2.fromOffset(31, y)
	hold.ZIndex = 81
	hold.InputBegan:Connect(function(inputObject)
		if inputObject.UserInputType == Enum.UserInputType.Touch
			or inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
			flyKeys[key] = true
		end
	end)
	hold.InputEnded:Connect(function(inputObject)
		if inputObject.UserInputType == Enum.UserInputType.Touch
			or inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
			flyKeys[key] = nil
		end
	end)
	return hold
end

makeFlyHoldButton("UP", "Up", 0)
makeFlyHoldButton("DOWN", "Down", 52)

local sidebar = make("Frame", {
	Name = "Sidebar",
	Size = UDim2.new(0, 240, 1, 0),
	BackgroundColor3 = C.panel,
	BorderSizePixel = 0,
	ZIndex = 22,
}, panel)
addCorner(sidebar, 24)
make("Frame", {
	Position = UDim2.new(1, -1, 0, 0),
	Size = UDim2.new(0, 1, 1, 0),
	BackgroundColor3 = C.line,
	BorderSizePixel = 0,
	ZIndex = 25,
}, sidebar)

local profileAvatar = make("ImageLabel", {
	Name = "AdminAvatar",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 20),
	Size = UDim2.fromOffset(104, 104),
	BackgroundColor3 = C.surface,
	BorderSizePixel = 0,
	ScaleType = Enum.ScaleType.Crop,
	ZIndex = 24,
}, sidebar)
addCorner(profileAvatar, 52)
addStroke(profileAvatar, C.line, 0.12, 1)
task.spawn(function()
	local ok, thumbnail = pcall(function()
		return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
	end)
	if ok and profileAvatar.Parent then profileAvatar.Image = thumbnail end
end)

local profileName = text(sidebar, player.Name, 25, C.text, 34, true)
profileName.Position = UDim2.fromOffset(16, 132)
profileName.Size = UDim2.new(1, -32, 0, 30)
profileName.TextXAlignment = Enum.TextXAlignment.Center
local profileUser = text(sidebar, "@" .. player.Name, 14, C.muted, 22)
profileUser.Position = UDim2.fromOffset(16, 161)
profileUser.Size = UDim2.new(1, -32, 0, 20)
profileUser.TextXAlignment = Enum.TextXAlignment.Center
local profileRole = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 190),
	Size = UDim2.fromOffset(150, 30),
	BackgroundColor3 = C.amber,
	BorderSizePixel = 0,
	Text = "STAFF",
	TextColor3 = C.bg,
	Font = Enum.Font.GothamBold,
	TextSize = 15,
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 24,
}, sidebar)
addCorner(profileRole, 16)
make("Frame", {
	Position = UDim2.fromOffset(20, 231),
	Size = UDim2.new(1, -40, 0, 1),
	BackgroundColor3 = C.line,
	BorderSizePixel = 0,
	ZIndex = 24,
}, sidebar)

local header = make("Frame", {
	Name = "Header",
	Position = UDim2.fromOffset(240, 0),
	Size = UDim2.new(1, -240, 0, 86),
	BackgroundColor3 = C.panel,
	BackgroundTransparency = 0.08,
	BorderSizePixel = 0,
	ZIndex = 22,
}, panel)
local logoMark = make("Frame", {
	Position = UDim2.fromOffset(22, 14),
	Size = UDim2.fromOffset(48, 56),
	BackgroundColor3 = C.amber,
	BorderSizePixel = 0,
	ZIndex = 24,
}, header)
addCorner(logoMark, 17)
local logoInset = make("Frame", {
	Position = UDim2.fromOffset(3, 3),
	Size = UDim2.new(1, -6, 1, -6),
	BackgroundColor3 = C.panel,
	BorderSizePixel = 0,
	ZIndex = 25,
}, logoMark)
addCorner(logoInset, 14)
local logoIcon = drawIcon(logoInset, "shield", 30, C.amber)
logoIcon.Position = UDim2.fromOffset(6, 10)
logoIcon.ZIndex = 26
local pageTitle = text(header, "PalmVille Admin", 29, C.text, 38, true)
pageTitle.Position = UDim2.fromOffset(88, 9)
pageTitle.Size = UDim2.new(1, -180, 0, 38)
local pageSubtitle = text(header, "Overview", 15, C.muted, 22)
pageSubtitle.Position = UDim2.fromOffset(90, 46)
pageSubtitle.Size = UDim2.new(1, -180, 0, 22)
local closeButton = button(header, "×", function()
	panelOpen = false
end, {size = UDim2.fromOffset(44, 44), textSize = 29, radius = 11})
closeButton.AnchorPoint = Vector2.new(1, 0.5)
closeButton.Position = UDim2.new(1, -20, 0.5, 0)
addStroke(closeButton, C.line, 0.02, 1.5)
make("Frame", {
	Position = UDim2.new(0, 0, 1, -1),
	Size = UDim2.new(1, 0, 0, 1),
	BackgroundColor3 = C.line,
	BorderSizePixel = 0,
	ZIndex = 24,
}, header)

local content = make("Frame", {
	Name = "Content",
	Position = UDim2.fromOffset(240, 86),
	Size = UDim2.new(1, -240, 1, -110),
	BackgroundTransparency = 1,
	ClipsDescendants = true,
	ZIndex = 22,
}, panel)
local footer = text(panel, "READY", 12, C.dim, 22)
footer.Position = UDim2.new(0, 256, 1, -23)
footer.Size = UDim2.new(1, -280, 0, 16)
footer.TextXAlignment = Enum.TextXAlignment.Right

local function setStatus(message, isError)
	footer.Text = tostring(message or "")
	footer.TextColor3 = isError and Color3.fromRGB(235, 145, 145) or C.greenBright
end


local modalShade = make("Frame", {
	Name = "AdminConfirmationShade",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.38,
	Visible = false,
	ZIndex = 100,
}, gui)

local modalCard = make("Frame", {
	Name = "AdminConfirmationCard",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(500, 270),
	BackgroundColor3 = C.panel,
	BorderSizePixel = 0,
	ZIndex = 101,
}, modalShade)
addCorner(modalCard, 18)
addStroke(modalCard, C.line, 0.18, 1)

local modalTitle = text(modalCard, "CONFIRM ACTION", 23, C.text, 32, true)
modalTitle.Position = UDim2.fromOffset(24, 20)
modalTitle.Size = UDim2.new(1, -48, 0, 32)
modalTitle.ZIndex = 103

local modalDescription = text(modalCard, "", 15, C.muted, 48)
modalDescription.Position = UDim2.fromOffset(24, 58)
modalDescription.Size = UDim2.new(1, -48, 0, 48)
modalDescription.TextYAlignment = Enum.TextYAlignment.Top
modalDescription.ZIndex = 103

local modalReason = make("TextBox", {
	Name = "ConfirmationReason",
	Position = UDim2.fromOffset(24, 116),
	Size = UDim2.new(1, -48, 0, 86),
	BackgroundColor3 = C.surface,
	BorderSizePixel = 0,
	ClearTextOnFocus = false,
	Font = Enum.Font.Gotham,
	TextSize = 15,
	TextColor3 = C.text,
	PlaceholderColor3 = C.dim,
	PlaceholderText = "Type the reason here...",
	Text = "",
	TextWrapped = true,
	MultiLine = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	Visible = false,
	ZIndex = 103,
}, modalCard)
addCorner(modalReason, 10)
addStroke(modalReason, C.line, 0.08, 1.2)
make("UIPadding", {
	PaddingTop = UDim.new(0, 10),
	PaddingBottom = UDim.new(0, 8),
	PaddingLeft = UDim.new(0, 12),
	PaddingRight = UDim.new(0, 10),
}, modalReason)

local modalPicker = make("ScrollingFrame", {
	Name = "ConfirmationPlayerPicker",
	Position = UDim2.fromOffset(24, 112),
	Size = UDim2.new(1, -48, 0, 300),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = C.line,
	Visible = false,
	ZIndex = 103,
}, modalCard)
vertical(modalPicker, 6)

local modalButtonRow = make("Frame", {
	Position = UDim2.new(0, 24, 1, -62),
	Size = UDim2.new(1, -48, 0, 42),
	BackgroundTransparency = 1,
	ZIndex = 103,
}, modalCard)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 10),
}, modalButtonRow)

local modalCallback
local modalPickerCallback
local closeAdminModal
local logFilterModalOpen = false

local modalPickerRosterKey = nil
local function renderModalPlayerPicker()
	local roster = snapshot.players or {}
	local keyParts = {}
	for _, row in ipairs(roster) do
		table.insert(keyParts, tostring(row.userId) .. ":" .. tostring(row.username) .. ":" .. tostring(row.displayName))
	end
	local rosterKey = table.concat(keyParts, "|")
	if rosterKey == modalPickerRosterKey then return end
	modalPickerRosterKey = rosterKey
	for _, child in ipairs(modalPicker:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	if #roster == 0 then
		local empty = text(modalPicker, "No online players available.", 14, C.muted, 36)
		empty.Position = UDim2.fromOffset(4, 4)
	else
		for _, row in ipairs(roster) do
			local username = tostring(row.username or "")
			local displayName = tostring(row.displayName or username)
			button(modalPicker, displayName .. "  ·  @" .. username, function()
				local callback = modalPickerCallback
				closeAdminModal()
				if callback then callback(row) end
			end, {size = UDim2.new(1, -6, 0, 46), textSize = 14})
		end
	end
end

closeAdminModal = function()
	logFilterModalOpen = false
	modalShade.Visible = false
	modalCallback = nil
	modalPickerCallback = nil
	modalReason.Text = ""
end

local modalCancelButton = button(modalButtonRow, "CANCEL", closeAdminModal, {
	size = UDim2.new(0.5, -5, 0, 42),
	textSize = 14,
})
local modalConfirmButton = button(modalButtonRow, "CONFIRM", function()
	local callback = modalCallback
	local reason = modalReason.Text
	closeAdminModal()
	if callback then callback(reason) end
end, {
	size = UDim2.new(0.5, -5, 0, 42),
	primary = true,
	textSize = 14,
	bold = true,
})

local function openConfirmModal(titleText, descriptionText, confirmText, needsReason, callback)
	modalTitle.Text = titleText
	modalConfirmButton.Text = confirmText or "CONFIRM"
	modalDescription.Text = descriptionText
	modalReason.Visible = needsReason == true
	modalPicker.Visible = false
	modalConfirmButton.Visible = true
	modalCancelButton.Size = UDim2.new(0.5, -5, 0, 42)
	modalConfirmButton.Size = UDim2.new(0.5, -5, 0, 42)
	modalButtonRow.Position = UDim2.new(0, 24, 1, -62)
	modalCard.Size = UDim2.fromOffset(500, needsReason and 330 or 255)
	modalReason.Text = ""
	modalCallback = callback
	modalShade.Visible = true
end

local function openPlayerPicker(titleText, descriptionText, callback)
	modalTitle.Text = titleText
	modalDescription.Text = descriptionText
	modalReason.Visible = false
	modalConfirmButton.Visible = false
	modalCancelButton.Size = UDim2.new(1, 0, 0, 42)
	modalButtonRow.Position = UDim2.new(0, 24, 1, -62)
	modalCard.Size = UDim2.fromOffset(500, 470)
	modalPickerCallback = callback
	renderModalPlayerPicker()
	modalPicker.Visible = true
	modalCallback = nil
	modalShade.Visible = true
	remote:FireServer("RequestSnapshot")
end

local pages = {}
local navButtons = {}
local navOrder = {
	{"OVERVIEW", "Overview", nil},
	{"PLAYERS", "Players", "Players"},
	{"ANNOUNCEMENTS", "Announcements", "Announcements"},
	{"MODERATION", "Moderation", "Moderation"},
	{"STAFF", "Admin Management", "MANAGER"},
	{"TOOLS", "Tools", "Tools"},
	{"LOGS", "Logs", "Logs"},
}

local navIcons = {
	OVERVIEW = "home",
	PLAYERS = "users",
	ANNOUNCEMENTS = "megaphone",
	MODERATION = "shield",
	STAFF = "settings",
	TOOLS = "wrench",
	LOGS = "file",
}
for navIndex, entry in ipairs(navOrder) do
	local key, caption = entry[1], entry[2]
	local nav = button(sidebar, "", function()
		if key == "STAFF" and role ~= "OWNER" and role ~= "MASTER DEVELOPER" then
			setStatus("Admin Management is restricted to Owner and Developer.", true)
			return
		end
		activeTab = key
	end, {size = UDim2.new(1, -32, 0, 48), textSize = 15, radius = 10})
	nav.Name = "Nav_" .. key
	nav.Position = UDim2.fromOffset(16, 244 + ((navIndex - 1) * 56))
	nav.Text = ""
	nav.RichText = false
	setButtonBackground(nav, C.panel)
	nav.BackgroundTransparency = 0.08
	nav:SetAttribute("NavCaption", caption)
	local navIcon = drawIcon(nav, navIcons[key], 20, C.amber)
	navIcon.Name = "NavIcon"
	navIcon.Position = UDim2.new(0, 14, 0.5, -10)
	local navLabel = text(nav, caption, 15, C.muted, 48, true)
	navLabel.Name = "NavLabel"
	navLabel.Position = UDim2.fromOffset(50, 0)
	navLabel.Size = UDim2.new(1, -60, 1, 0)
	navLabel.TextWrapped = false
	navLabel.ZIndex = nav.ZIndex + 2
	local navIndicator = make("Frame", {
		Name = "ActiveIndicator",
		Position = UDim2.fromOffset(5, 12),
		Size = UDim2.fromOffset(3, 24),
		BackgroundColor3 = C.text,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = nav.ZIndex + 2,
	}, nav)
	addCorner(navIndicator, 2)
	local navStroke = nav:FindFirstChildOfClass("UIStroke")
	if navStroke then navStroke.Transparency = 0.72 end
	navButtons[key] = nav

	local page = make("ScrollingFrame", {
		Name = "Page_" .. key,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = C.line,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
	}, content)
	make("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}, page)
	vertical(page, 9)
	pages[key] = page
end

local function refreshNavigation()
	local requiredAreas = {
		PLAYERS = "Players",
		ANNOUNCEMENTS = "Announcements",
		MODERATION = "Moderation",
		TOOLS = "Tools",
		LOGS = "Logs",
	}
	if activeTab == "STAFF" and not managerRole() then activeTab = "OVERVIEW" end
	local required = requiredAreas[activeTab]
	if required and not canAccess(required) then activeTab = "OVERVIEW" end

	for _, entry in ipairs(navOrder) do
		local key, area = entry[1], entry[3]
		local allowed = area == "MANAGER" or area == nil or canAccess(area)
		local nav = navButtons[key]
		nav.Visible = allowed
		local active = activeTab == key
		setButtonBackground(nav, active and C.green or C.panel)
		nav.BackgroundTransparency = active and 0 or 0.08
		local navLabel = nav:FindFirstChild("NavLabel")
		if navLabel then
			navLabel.Text = nav:GetAttribute("NavCaption") or key
			navLabel.TextColor3 = active and C.text or C.muted
		end
		local navIndicator = nav:FindFirstChild("ActiveIndicator")
		if navIndicator then navIndicator.Visible = active end
		local navStroke = nav:FindFirstChildOfClass("UIStroke")
		if navStroke then navStroke.Transparency = active and 0.02 or 0.78 end
		pages[key].Visible = panelOpen and active and allowed
	end

	local captions = {
		OVERVIEW = "Overview",
		PLAYERS = "Players",
		ANNOUNCEMENTS = "Announcements",
		MODERATION = "Moderation",
		STAFF = "Admin Management",
		TOOLS = "Tools",
		LOGS = "Logs",
	}
	pageSubtitle.Text = captions[activeTab] or "Overview"
end

for key, nav in pairs(navButtons) do
	nav.Activated:Connect(function()
		activeTab = key
		refreshNavigation()
		if key == "OVERVIEW" then
			if canAccess("Monitoring") or canAccess("Server") or canAccess("Players") or canAccess("Moderation") then remote:FireServer("RequestSnapshot") end
		elseif key == "PLAYERS" then
			remote:FireServer("RequestSnapshot")
		elseif key == "STAFF" then
			remote:FireServer("RequestStaff")
		elseif key == "LOGS" then
			remote:FireServer("RequestLogs")
		end
	end)
end

local function showPageStatus(parent, message)
	local item = text(parent, message, 11, C.muted, 24)
	return item
end

local function metric(parent, caption, initial, iconName)
	local box = make("Frame", {
		Size = UDim2.new(0.5, -8, 1, 0),
		BackgroundColor3 = C.surface,
		BorderSizePixel = 0,
	}, parent)
	addCorner(box, 17)
	addStroke(box, C.line, 0.06, 1.4)
	local iconBox = make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 22, 0.5, 0),
		Size = UDim2.fromOffset(60, 60),
		BackgroundColor3 = C.green,
		BorderSizePixel = 0,
	}, box)
	addCorner(iconBox, 16)
	local metricIcon = drawIcon(iconBox, iconName, 30, C.amber)
	metricIcon.Position = UDim2.fromOffset(15, 15)
	make("Frame", {
		Position = UDim2.new(0, 96, 0.18, 0),
		Size = UDim2.new(0, 1, 0.64, 0),
		BackgroundColor3 = C.line,
		BorderSizePixel = 0,
	}, box)
	local small = text(box, caption, 15, C.muted, 22, true)
	small.Position = UDim2.fromOffset(116, 20)
	small.Size = UDim2.new(1, -132, 0, 22)
	local value = text(box, initial or "—", 27, C.text, 34, true)
	value.Position = UDim2.fromOffset(116, 49)
	value.Size = UDim2.new(1, -132, 0, 34)
	value.TextTruncate = Enum.TextTruncate.AtEnd
	return value
end

local overviewMetricRow = addRow(pages.OVERVIEW, 116)
local metricPlayers = metric(overviewMetricRow, "Online", "0", "users")
local metricUptime = metric(overviewMetricRow, "Server Uptime", "0m 0s", "clock")

local overviewAbilityCard = card(pages.OVERVIEW, "ADMIN CONTROLS", "Personal session settings.", nil)
local overviewAbilityList = make("Frame", {
	Size = UDim2.new(1, 0, 0, 126),
	BackgroundTransparency = 1,
}, overviewAbilityCard)
vertical(overviewAbilityList, 5)

local function abilityControl(titleText, initialState, callback)
	local control = toggleRow(overviewAbilityList, titleText, initialState, function()
		callback()
	end, {size = UDim2.new(1, 0, 0, 38), textSize = 13})
	return {row = control.row, button = control.row, set = control.set}
end

local flyControl = abilityControl("Flight Mode", flyEnabled, function()
	sendAction("SetFly", {enabled = not flyEnabled})
	setStatus(flyEnabled and "Disabling flight..." or "Enabling flight...")
end)
local invisibleControl = abilityControl("Invisible Character", invisibleEnabled, function()
	sendAction("SetInvisible", {enabled = not invisibleEnabled})
	setStatus(invisibleEnabled and "Restoring visibility..." or "Hiding character...")
end)
local titleControl = abilityControl("Developer Role Title", adminTitleEnabled, function()
	sendAction("SetAdminTitle", {enabled = not adminTitleEnabled})
	setStatus(adminTitleEnabled and "Hiding your role title..." or "Showing your role title...")
end)
local nicknameCard = card(pages.OVERVIEW, "OVERHEAD NAME (BELOW YOUR ROLE)", "Change only the name shown on the second line beneath your Owner, Developer, or Head Admin title.")
local ownNicknameInput = addField(nicknameCard, "BOTTOM-LINE NICKNAME", "Enter the name shown below your role", player:GetAttribute("PalmVilleAdminNickname") or player.DisplayName)
button(nicknameCard, "SAVE NICKNAME", function()
	local nickname = ownNicknameInput.Text:gsub("^%s+", ""):gsub("%s+$", "")
	if nickname == "" then setStatus("Enter a nickname first.", true); return end
	sendAction("UpdateStaffNickname", {nickname = nickname})
end, {primary = true, textSize = 14})
local flyButton = flyControl.button
local invisibleButton = invisibleControl.button
local adminTitleButton = titleControl.button

local function refreshAbilityControl(control, enabled)
	control.set(enabled)
end

local function refreshOverviewAbilityButtons()
	refreshAbilityControl(flyControl, flyEnabled)
	refreshAbilityControl(invisibleControl, invisibleEnabled)
	refreshAbilityControl(titleControl, adminTitleEnabled)
end

local playersWorkspace = make("Frame", {
	Name = "PlayersWorkspace",
	Size = UDim2.new(1, 0, 0, 570),
	BackgroundTransparency = 1,
}, pages.PLAYERS)

local playersListPanel = make("Frame", {
	Name = "OnlinePlayersPanel",
	Size = UDim2.new(0.35, -10, 1, 0),
	BackgroundColor3 = C.panel,
	BorderSizePixel = 0,
}, playersWorkspace)
addCorner(playersListPanel, 18)
local playersDetailsPanel = make("Frame", {
	Name = "PlayerDetailsPanel",
	Position = UDim2.new(0.35, 10, 0, 0),
	Size = UDim2.new(0.65, -10, 1, 0),
	BackgroundColor3 = C.panel,
	BorderSizePixel = 0,
}, playersWorkspace)
addCorner(playersDetailsPanel, 18)

local playersHeading = text(playersListPanel, "Online Players", 19, C.text, 28, true)
playersHeading.Position = UDim2.fromOffset(16, 12)
playersHeading.Size = UDim2.new(1, -32, 0, 28)
local playersScope = text(playersListPanel, "This server · 0 online", 12, C.muted, 18)
playersScope.Position = UDim2.fromOffset(16, 40)
playersScope.Size = UDim2.new(1, -32, 0, 18)
local playerSearch = input(playersListPanel, "Search players...", "")
playerSearch.Position = UDim2.fromOffset(12, 66)
playerSearch.Size = UDim2.new(1, -24, 0, 36)
local selectedLabel = text(playersListPanel, "Select a player.", 11, C.muted, 18)
selectedLabel.Position = UDim2.fromOffset(14, 105)
selectedLabel.Size = UDim2.new(1, -28, 0, 18)
local playerRows = make("ScrollingFrame", {
	Name = "PlayerRows",
	Position = UDim2.fromOffset(12, 130),
	Size = UDim2.new(1, -24, 1, -142),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 3,
	ScrollBarImageColor3 = C.line,
}, playersListPanel)
vertical(playerRows, 5)

local detailTitle = text(playersDetailsPanel, "Player Details", 19, C.text, 28, true)
detailTitle.Position = UDim2.fromOffset(18, 12)
detailTitle.Size = UDim2.new(1, -36, 0, 28)
make("Frame", {
	Position = UDim2.fromOffset(16, 46),
	Size = UDim2.new(1, -32, 0, 1),
	BackgroundColor3 = C.line,
	BorderSizePixel = 0,
}, playersDetailsPanel)

local detailAvatar = make("ImageLabel", {
	Position = UDim2.fromOffset(18, 60),
	Size = UDim2.fromOffset(76, 76),
	BackgroundColor3 = C.surface,
	BorderSizePixel = 0,
	ScaleType = Enum.ScaleType.Crop,
}, playersDetailsPanel)
addCorner(detailAvatar, 38)
addStroke(detailAvatar, C.line, 0.12, 1)
local detailName = text(playersDetailsPanel, "Select a player", 21, C.text, 28, true)
detailName.Position = UDim2.fromOffset(108, 60)
detailName.Size = UDim2.new(1, -126, 0, 28)
local detailUsername = text(playersDetailsPanel, "@username", 13, C.muted, 20)
detailUsername.Position = UDim2.fromOffset(108, 89)
detailUsername.Size = UDim2.new(1, -126, 0, 20)
local detailOnline = text(playersDetailsPanel, "Waiting for selection", 11, C.muted, 18)
detailOnline.Position = UDim2.fromOffset(108, 111)
detailOnline.Size = UDim2.new(1, -126, 0, 18)
make("Frame", {
	Position = UDim2.fromOffset(16, 146),
	Size = UDim2.new(1, -32, 0, 1),
	BackgroundColor3 = C.line,
	BorderSizePixel = 0,
}, playersDetailsPanel)
local progressTitle = text(playersDetailsPanel, "Progress", 15, C.text, 22, true)
progressTitle.Position = UDim2.fromOffset(18, 153)
progressTitle.Size = UDim2.new(1, -36, 0, 22)

local function detailStat(x, y, width, labelText, initial)
	local tile = make("Frame", {
		Position = UDim2.new(x, x == 0 and 18 or 6, 0, y),
		Size = UDim2.new(width, width == 0.5 and -27 or -36, 0, 48),
		BackgroundColor3 = C.surface,
		BorderSizePixel = 0,
	}, playersDetailsPanel)
	addCorner(tile, 8)
	local label = text(tile, labelText, 11, C.muted, 15, true)
	label.Position = UDim2.fromOffset(10, 5)
	label.Size = UDim2.new(1, -20, 0, 15)
	local value = text(tile, initial, 13, C.text, 19, true)
	value.Position = UDim2.fromOffset(10, 23)
	value.Size = UDim2.new(1, -20, 0, 19)
	return value
end
local detailMoney = detailStat(0, 181, 0.5, "Money", "Not available")
local detailEarned = detailStat(0.5, 181, 0.5, "Earned Today", "Not available")
local detailLevel = detailStat(0, 235, 0.5, "Level", "Not available")
local detailPlaytime = detailStat(0.5, 235, 0.5, "Total Playtime", "Not available")
local detailXp = detailStat(0, 289, 1, "XP", "Not available")
local detailMetadata = text(playersDetailsPanel, "User ID: —   ·   Role: —   ·   Health: —", 11, C.muted, 18)
detailMetadata.Position = UDim2.fromOffset(18, 342)
detailMetadata.Size = UDim2.new(1, -36, 0, 18)
local detailPosition = text(playersDetailsPanel, "Position: —", 10, C.dim, 16)
detailPosition.Position = UDim2.fromOffset(18, 361)
detailPosition.Size = UDim2.new(1, -36, 0, 16)
local playerActionHeading = text(playersDetailsPanel, "Player Actions", 14, C.text, 20, true)
playerActionHeading.Position = UDim2.fromOffset(18, 383)
playerActionHeading.Size = UDim2.new(1, -36, 0, 20)

local playerActionRow = make("Frame", {
	Position = UDim2.fromOffset(16, 407),
	Size = UDim2.new(1, -32, 0, 36),
	BackgroundTransparency = 1,
}, playersDetailsPanel)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, playerActionRow)
button(playerActionRow, "TELEPORT", function()
	if not selectedUserId then setStatus("Select a player first.", true); return end
	sendAction("Teleport", targetData())
end, {size = UDim2.new(0.333, -4, 0, 34), primary = true, textSize = 10, bold = true})
local spectateButton = button(playerActionRow, "SPECTATE", function()
	if not selectedUserId then setStatus("Select a player first.", true); return end
	if spectatingUserId == selectedUserId then sendAction("StopSpectate") else sendAction("Spectate", targetData()) end
end, {size = UDim2.new(0.333, -4, 0, 34), textSize = 10, bold = true})
local freezeButton = button(playerActionRow, "FREEZE", function()
	if not selectedUserId then setStatus("Select a player first.", true); return end
	sendAction(frozenTargets[selectedUserId] and "Unfreeze" or "Freeze", targetData())
end, {size = UDim2.new(0.334, -4, 0, 34), textSize = 10, bold = true})

local function refreshPlayerActionButtons()
	spectateButton.Text = spectatingUserId == selectedUserId and "STOP" or "SPECTATE"
	freezeButton.Text = frozenTargets[selectedUserId] and "UNFREEZE" or "FREEZE"
	setButtonBackground(spectateButton, spectatingUserId == selectedUserId and C.green or C.surface)
	setButtonBackground(freezeButton, frozenTargets[selectedUserId] and C.green or C.surface)
end

local moreActionsMenu = make("Frame", {
	Position = UDim2.fromOffset(16, 490),
	Size = UDim2.new(1, -32, 0, 70),
	BackgroundColor3 = C.panel,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = playersDetailsPanel.ZIndex + 2,
}, playersDetailsPanel)
addCorner(moreActionsMenu, 9)
make("UIPadding", {
	PaddingTop = UDim.new(0, 5),
	PaddingBottom = UDim.new(0, 5),
	PaddingLeft = UDim.new(0, 6),
	PaddingRight = UDim.new(0, 6),
}, moreActionsMenu)
vertical(moreActionsMenu, 4)
local moreRow1 = addRow(moreActionsMenu, 28)
button(moreRow1, "BRING PLAYER", function()
	if not selectedUserId then setStatus("Select a player first.", true); return end
	sendAction("Bring", targetData())
end, {size = UDim2.new(0.5, -4, 0, 28), textSize = 10})
button(moreRow1, "WATCH SCREEN", function()
	if not selectedUserId then setStatus("Select a player first.", true); return end
	sendAction("WatchScreen", targetData())
end, {size = UDim2.new(0.5, -4, 0, 28), textSize = 10})
local moreActionsButton = button(playersDetailsPanel, "MORE ACTIONS", function()
	moreActionsMenu.Visible = not moreActionsMenu.Visible
end, {size = UDim2.new(1, -32, 0, 30), textSize = 11})
moreActionsButton.Position = UDim2.fromOffset(16, 454)
moreActionsButton.TextXAlignment = Enum.TextXAlignment.Center

local function formatAdminMoney(value)
	local formatted = tostring(math.max(0, math.floor(tonumber(value) or 0)))
	while true do
		local changed
		formatted, changed = formatted:gsub("^(%d+)(%d%d%d)", "%1,%2")
		if changed == 0 then break end
	end
	return "₱" .. formatted
end

local function updatePlayerDetails(row)
	if not row then
		detailName.Text = "Select a player"
		detailUsername.Text = "@username"
		detailOnline.Text = "●  Waiting for selection"
		detailOnline.TextColor3 = C.muted
		detailMetadata.Text = "User ID: —   ·   Role: —   ·   Health: —"
		detailPosition.Text = "Position: —"
		detailMoney.Text = "Not available"
		detailEarned.Text = "Not available"
		detailLevel.Text = "Not available"
		detailPlaytime.Text = "Not available"
		detailXp.Text = "Not available"
		detailAvatar.Image = ""
		return
	end

	detailName.Text = tostring(row.displayName or row.username or "Player")
	detailUsername.Text = "@" .. tostring(row.username or "unknown")
	detailOnline.Text = "●  Online"
	detailOnline.TextColor3 = C.greenBright
	local healthText = row.health ~= nil and (tostring(row.health) .. "/" .. tostring(row.maxHealth or row.health)) or "Not available"
	detailMetadata.Text = string.format("User ID: %s   ·   Role: %s   ·   Health: %s",
		tostring(row.userId or "—"), displayRole(row.role), healthText)
	detailPosition.Text = "Position: " .. tostring(row.position or "Not available")

	local progress = type(row.progress) == "table" and row.progress or {}
	detailMoney.Text = progress.money ~= nil and formatAdminMoney(progress.money) or "Not available"
	detailEarned.Text = progress.earnedToday ~= nil and formatAdminMoney(progress.earnedToday) or "Not available"
	detailLevel.Text = progress.level ~= nil and tostring(math.floor(progress.level)) or "Not available"
	detailPlaytime.Text = progress.totalPlaytime ~= nil
		and string.format("%dh %02dm", math.floor(progress.totalPlaytime / 3600), math.floor((progress.totalPlaytime % 3600) / 60))
		or "Not available"
	detailXp.Text = progress.xp ~= nil
		and (tostring(math.floor(progress.xp)) .. (progress.xpNeeded and (" / " .. tostring(math.floor(progress.xpNeeded))) or " XP"))
		or "Not available"

	if row.frozen ~= nil then
		frozenTargets[tonumber(row.userId)] = row.frozen == true or nil
	end
	refreshPlayerActionButtons()

	local userId = tonumber(row.userId)
	if userId then
		task.spawn(function()
			local ok, thumbnail = pcall(function()
				return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
			end)
			if ok and selectedUserId == userId and detailAvatar.Parent then detailAvatar.Image = thumbnail end
		end)
	end
end

local renderedPlayerRowsKey = nil
local function renderPlayers()
	local query = string.lower(playerSearch.Text or "")
	local roster = snapshot.players or {}
	local keyParts = {query}
	for _, row in ipairs(roster) do
		table.insert(keyParts, tostring(row.userId) .. ":" .. tostring(row.username) .. ":" .. tostring(row.displayName))
	end
	local rowsKey = table.concat(keyParts, "|")
	local visibleCount = 0
	local selectedStillOnline = false
	local selectedRow
	for _, entry in ipairs(roster) do
		if entry.userId == selectedUserId then
			selectedStillOnline = true
			selectedRow = entry
			break
		end
	end
	if selectedUserId and not selectedStillOnline then
		selectedUserId, selectedUsername = nil, nil
		selectedLabel.Text = "Select a player to view details."
		updatePlayerDetails(nil)
	elseif selectedRow then
		updatePlayerDetails(selectedRow)
	end
	playersScope.Text = string.format("This server · %d online", #roster)
	-- Snapshot polling updates live stats every 1.5 seconds. Keep existing row
	-- instances and avatar images when the roster/search identity has not changed.
	if rowsKey == renderedPlayerRowsKey then return end
	renderedPlayerRowsKey = rowsKey
	for _, child in ipairs(playerRows:GetChildren()) do
		if child:IsA("TextButton") or child:IsA("TextLabel") or child:IsA("Frame") then child:Destroy() end
	end
	for _, row in ipairs(roster) do
		local username = tostring(row.username or "")
		local displayName = tostring(row.displayName or username)
		if query == "" or string.find(string.lower(username), query, 1, true) or string.find(string.lower(displayName), query, 1, true) then
			visibleCount += 1
			local item = button(playerRows, "", function()
				selectedUserId = row.userId
				selectedUsername = username
				selectedLabel.Text = "SELECTED  ·  " .. displayName .. "  @" .. username
				updatePlayerDetails(row)
				for _, other in ipairs(playerRows:GetChildren()) do
					if other:IsA("TextButton") then
						setButtonBackground(other, other:GetAttribute("UserId") == selectedUserId and C.green or C.surface)
					end
				end
			end, {size = UDim2.new(1, -4, 0, 70), radius = 12})
			item:SetAttribute("UserId", row.userId)
			setButtonBackground(item, row.userId == selectedUserId and C.green or C.surface)
			local avatar = make("ImageLabel", {
				Position = UDim2.fromOffset(12, 12),
				Size = UDim2.fromOffset(48, 48),
				BackgroundColor3 = C.panel,
				BorderSizePixel = 0,
				ScaleType = Enum.ScaleType.Crop,
			}, item)
			addCorner(avatar, 24)
			local nameLabel = text(item, displayName, 16, C.text, 24, true)
			nameLabel.Position = UDim2.fromOffset(72, 10)
			nameLabel.Size = UDim2.new(1, -90, 0, 24)
			local usernameLabel = text(item, "@" .. username, 12, C.muted, 18)
			usernameLabel.Position = UDim2.fromOffset(72, 34)
			usernameLabel.Size = UDim2.new(1, -90, 0, 18)
			local onlineDot = make("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -15, 0.5, 0),
				Size = UDim2.fromOffset(12, 12),
				BackgroundColor3 = C.greenBright,
				BorderSizePixel = 0,
			}, item)
			addCorner(onlineDot, 6)
			local userId = tonumber(row.userId)
			if userId then
				task.spawn(function()
					local ok, thumbnail = pcall(function()
						return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
					end)
					if ok and avatar.Parent then avatar.Image = thumbnail end
				end)
			end
		end
	end
	if visibleCount == 0 then
		showPageStatus(playerRows, query == "" and "No players are currently online." or "No players match that search.")
	end
end

playerSearch:GetPropertyChangedSignal("Text"):Connect(renderPlayers)

local announceCard = card(pages.ANNOUNCEMENTS, "NEW ANNOUNCEMENT", "Create and send a message to players.", "megaphone")
-- Fill the available announcement page so the panel has no exposed black strip below the form.
announceCard.AutomaticSize = Enum.AutomaticSize.None
announceCard.Size = UDim2.new(1, 0, 1, -22)
text(announceCard, "Message", 18, C.text, 26, true)
local announceBox = make("TextBox", {
	Size = UDim2.new(1, 0, 0, 156),
	BackgroundColor3 = C.surface,
	BorderSizePixel = 0,
	ClearTextOnFocus = false,
	Font = Enum.Font.Gotham,
	TextSize = 16,
	TextColor3 = C.text,
	PlaceholderColor3 = C.dim,
	PlaceholderText = "Write your announcement...",
	Text = "",
	TextWrapped = true,
	MultiLine = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
}, announceCard)
addCorner(announceBox, 14)
make("UIPadding", {PaddingTop = UDim.new(0, 18), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 18)}, announceBox)
local announceCount = text(announceCard, "0 / 280", 14, C.muted, 22)
announceCount.TextXAlignment = Enum.TextXAlignment.Right
announceBox:GetPropertyChangedSignal("Text"):Connect(function()
	announceCount.Text = tostring(#announceBox.Text) .. " / 280"
	announceCount.TextColor3 = #announceBox.Text > 280 and C.red or C.muted
end)
text(announceCard, "Audience", 18, C.text, 26, true)
local audienceRow = addRow(announceCard, 48)
local serverAudience
local allAudience
serverAudience = iconButton(audienceRow, "This Server", "users", function()
	audience = "This Server"
	setButtonBackground(serverAudience, C.green)
	setButtonBackground(allAudience, C.surface)
end, {size = UDim2.new(0.5, -5, 0, 42), textSize = 13, bold = true})
allAudience = iconButton(audienceRow, "All Servers", "globe", function()
	audience = "All Servers"
	setButtonBackground(serverAudience, C.surface)
	setButtonBackground(allAudience, C.green)
end, {size = UDim2.new(0.5, -5, 0, 42), textSize = 13, bold = true})
setButtonBackground(serverAudience, C.green)
local announceDivider = make("Frame", {Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.line, BorderSizePixel = 0}, announceCard)
local previewRow = addRow(announceCard, 52)
local previewButton = iconButton(previewRow, "Preview", "eye", function()
	local value = announceBox.Text
	if value:gsub("%s", "") == "" then setStatus("Enter an announcement first.", true); return end
	if #value > 280 or not utf8.len(value) then setStatus("Announcement must be 280 characters or fewer.", true); return end
	showAnnouncement({role = role, by = managerRole() and "Lupin" or player.DisplayName, text = value, duration = 8}, true)
	setStatus("Preview shown. Only you can see it.")
end, {size = UDim2.new(1, 0, 0, 50), textSize = 17})
local sendRow = addRow(announceCard, 56)
local sendAnnouncementButton = iconButton(sendRow, "Send Announcement", "send", function()
	local value = announceBox.Text
	if value:gsub("%s", "") == "" then setStatus("Enter an announcement first.", true); return end
	if #value > 280 or not utf8.len(value) then setStatus("Announcement must be 280 characters or fewer.", true); return end
	openConfirmModal(
		"CONFIRM ANNOUNCEMENT",
		"Send this announcement to " .. audience .. "?\n\n" .. value,
		"CONFIRM & SEND",
		false,
		function()
			sendAction("Announce", {message = value, audience = audience})
			setStatus("Sending announcement...")
		end
	)
end, {size = UDim2.new(1, 0, 0, 54), primary = true, textSize = 18, bold = true})
showPageStatus(announceCard, "Only Owner, Developer, and Head Admin can send announcements. All Servers is disabled in Studio.")
local moderationCard = card(pages.MODERATION, "CHOOSE PLAYER", "Select an online player before applying a moderation action.")
local moderationTargetButton = button(moderationCard, "SELECT PLAYER", function()
	openPlayerPicker("SELECT MODERATION TARGET", "Choose the online player you want to moderate.", function(row)
		moderationTargetUserId = tonumber(row.userId)
		moderationTargetUsername = tostring(row.username or row.displayName or "Player")
		moderationTargetButton.Text = tostring(row.displayName or moderationTargetUsername) .. "  ·  @" .. moderationTargetUsername
		setStatus("Moderation target selected: " .. moderationTargetUsername)
	end)
end, {primary = true, size = UDim2.new(1, 0, 0, 48), textSize = 15, bold = true})

local function moderationTarget()
	return {targetUserId = moderationTargetUserId, username = moderationTargetUsername or ""}
end

local function hasModerationTarget()
	if not moderationTargetUserId then
		setStatus("Choose a player first.", true)
		return false
	end
	return true
end

local modActionRow1 = addRow(moderationCard, 48)
button(modActionRow1, "WARN", function()
	if not hasModerationTarget() then return end
	local target = moderationTarget()
	target.reason = "Please follow the PalmVille game rules."
	sendAction("Warn", target)
end, {size = UDim2.new(0.333, -6, 0, 46), textSize = 14})
button(modActionRow1, "TOGGLE CHAT MUTE", function()
	if not hasModerationTarget() then return end
	sendAction("MuteChat", moderationTarget())
end, {size = UDim2.new(0.333, -6, 0, 46), textSize = 13})
button(modActionRow1, "KICK", function()
	if not hasModerationTarget() then return end
	local target = moderationTarget()
	openConfirmModal(
		"CONFIRM KICK",
		"Kick @" .. target.username .. " from this server? Enter the reason below.",
		"KICK PLAYER",
		true,
		function(reason)
			if reason:gsub("%s", "") == "" then setStatus("A reason is required.", true); return end
			target.reason = reason
			sendAction("Kick", target)
		end
	)
end, {size = UDim2.new(0.334, -6, 0, 46), danger = true, textSize = 14})

local modActionRow2 = addRow(moderationCard, 48)
button(modActionRow2, "BAN PLAYER", function()
	if not hasModerationTarget() then return end
	local target = moderationTarget()
	openConfirmModal(
		"CONFIRM PERMANENT BAN",
		"Ban @" .. target.username .. " from PalmVille permanently? This cannot be undone here. Enter a reason.",
		"PERMANENT BAN",
		true,
		function(reason)
			if reason:gsub("%s", "") == "" then setStatus("A reason is required.", true); return end
			target.reason = reason
			sendAction("PermanentBan", target)
		end
	)
end, {size = UDim2.new(0.5, -6, 0, 46), danger = true, textSize = 14})
button(modActionRow2, "UNBAN", function()
	if not hasModerationTarget() then return end
	sendAction("Unban", moderationTarget())
end, {size = UDim2.new(0.5, -6, 0, 46), textSize = 14})

local historyCard = card(pages.MODERATION, "MODERATION HISTORY", "Saved actions for the selected account.")
local historyButton = button(historyCard, "LOAD HISTORY", function()
	if not hasModerationTarget() then return end
	sendAction("ModerationHistory", moderationTarget())
end, {primary = true})
local historyText = text(historyCard, "No history loaded.", 14, C.muted, 110)
historyText.TextYAlignment = Enum.TextYAlignment.Top

local staffCard = card(pages.STAFF, "ADD ADMIN", "Choose the Roblox account, assign its role, and set its PalmVille nickname.")
local staffUsername = addField(staffCard, "ROBLOX USERNAME", "Roblox username to add")
local staffNickname = addField(staffCard, "NICKNAME", "Name shown in PalmVille")
local staffRole = "ADMIN"
local staffRoleRow = addRow(staffCard, 48)
for _, staffRoleName in ipairs({"HEAD ADMIN", "ADMIN", "MODERATOR", "HELPER"}) do
	button(staffRoleRow, staffRoleName, function(b)
		staffRole = staffRoleName
		for _, other in ipairs(staffRoleRow:GetChildren()) do
			if other:IsA("TextButton") then setButtonBackground(other, other == b and C.green or C.surface) end
		end
	end, {size = UDim2.new(0.25, -6, 0, 46), textSize = 13})
end
local staffActions = addRow(staffCard, 48)
button(staffActions, "ADD ADMIN", function()
	local username = staffUsername.Text:gsub("^%s+", ""):gsub("%s+$", "")
	local nickname = staffNickname.Text:gsub("^%s+", ""):gsub("%s+$", "")
	if username == "" then setStatus("Enter a Roblox username.", true); return end
	if nickname == "" then setStatus("Enter a nickname for this admin.", true); return end
	sendAction("AddStaff", {username = username, nickname = nickname, role = staffRole})
end, {size = UDim2.new(0.5, -6, 0, 46), primary = true, textSize = 14})
button(staffActions, "REMOVE SELECTED", function()
	if not selectedStaffId then setStatus("Select a staff account first.", true); return end
	sendAction("RemoveStaff", {targetUserId = selectedStaffId})
end, {size = UDim2.new(0.5, -6, 0, 46), danger = true, textSize = 14})
local staffListCard = card(pages.STAFF, "AUTHORIZED STAFF", "Select a row to prepare removal.")
local staffList = make("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1}, staffListCard)
vertical(staffList, 4)
local permissionsCard = card(pages.STAFF, "ROLE PERMISSIONS", "Change which sections an assignable role may access.")
local permissionRole = "ADMIN"
local permissionRoleRow = addRow(permissionsCard, 48)
for _, permissionRoleName in ipairs({"HEAD ADMIN", "ADMIN", "MODERATOR", "HELPER"}) do
	button(permissionRoleRow, permissionRoleName, function(b)
		permissionRole = permissionRoleName
		for _, other in ipairs(permissionRoleRow:GetChildren()) do
			if other:IsA("TextButton") then setButtonBackground(other, other == b and C.green or C.surface) end
		end
		remote:FireServer("RequestStaff")
	end, {size = UDim2.new(0.25, -6, 0, 46), textSize = 13})
end
local permissionList = make("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1}, permissionsCard)
vertical(permissionList, 4)

local toolsCard = card(pages.TOOLS, "GIVE ITEM", "Uses the registered item catalog and server-enforced role limits.")
local itemCode = addField(toolsCard, "ITEM", "Type here", "")
local itemAmount = addField(toolsCard, "AMOUNT", "1–99", "1")
local itemModeRow = addRow(toolsCard, 48)
for _, mode in ipairs({"Self", "All"}) do
	button(itemModeRow, mode == "Self" and "GIVE TO ME" or "GIVE TO ALL", function(b)
		itemTargetMode = mode
		for _, other in ipairs(itemModeRow:GetChildren()) do
			if other:IsA("TextButton") then setButtonBackground(other, other == b and C.green or C.surface) end
		end
	end, {size = UDim2.new(0.5, -6, 0, 46), textSize = 14})
end
button(toolsCard, "GIVE REGISTERED ITEM", function()
	if itemCode.Text:gsub("%s", "") == "" then setStatus("Enter an item code first.", true); return end
	sendAction("GiveItem", {
		itemCode = itemCode.Text,
		amount = tonumber(itemAmount.Text),
		targetMode = itemTargetMode,
	})
end, {primary = true})

local logsCard = card(pages.LOGS, "PLAYER ACTIVITY & AUDIT LOG", "Server-recorded player sessions, currency, inventory, XP and staff actions.")
button(logsCard, "REFRESH LOGS", function() remote:FireServer("RequestLogs") end, {primary = true})
local logControls = make("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1}, logsCard)
local logControlLayout = make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 8),
}, logControls)
local function collectLogPlayerChoices()
	local byId = {}
	for _, row in ipairs(logs) do
		local actorId = tonumber(row.actorUserId) or 0
		local targetId = tonumber(row.targetUserId) or 0
		local actorName = tostring(row.actor or "")
		local targetName = tostring(row.target or "")
		if actorId > 0 then byId[actorId] = actorName ~= "" and actorName or tostring(actorId) end
		if targetId > 0 then byId[targetId] = targetName ~= "" and targetName or tostring(targetId) end
	end
	local choices = {}
	for userId, name in pairs(byId) do table.insert(choices, {userId = userId, name = name}) end
	table.sort(choices, function(a, b) return string.lower(a.name) < string.lower(b.name) end)
	return choices
end

local logFilterButton = button(logControls, "PLAYERS: ALL", function()
	local choices = collectLogPlayerChoices()
	logFilterModalOpen = true
	local draft = {}
	for userId, enabled in pairs(selectedLogUserIds) do if enabled then draft[userId] = true end end
	local function drawChoices()
		for _, child in ipairs(modalPicker:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
		if #choices == 0 then
			local empty = text(modalPicker, "No players found in the current log history.", 14, C.muted, 36)
			empty.Position = UDim2.fromOffset(4, 4)
			return
		end
		for _, choice in ipairs(choices) do
			local userId = choice.userId
			local checked = draft[userId] == true
			button(modalPicker, (checked and "✓   " or "□   ") .. choice.name .. "   ·   " .. tostring(userId), function()
				draft[userId] = not draft[userId] or nil
				drawChoices()
			end, {size = UDim2.new(1, -6, 0, 42), textSize = 13})
		end
	end
	modalTitle.Text = "FILTER LOGS BY PLAYERS"
	modalDescription.Text = "Select one or more players. Leave all unchecked to show everyone."
	modalReason.Visible = false
	modalPicker.Visible = true
	modalConfirmButton.Visible = true
	modalConfirmButton.Text = "APPLY FILTER"
	modalCancelButton.Visible = true
	modalCancelButton.Text = "CANCEL"
	modalCancelButton.Size = UDim2.new(0.5, -5, 0, 42)
	modalConfirmButton.Size = UDim2.new(0.5, -5, 0, 42)
	modalButtonRow.Position = UDim2.new(0, 24, 1, -62)
	modalCard.Size = UDim2.fromOffset(500, 470)
	modalPicker.Position = UDim2.fromOffset(24, 112)
	modalPicker.Size = UDim2.new(1, -48, 0, 300)
	drawChoices()
	modalCallback = function()
		selectedLogUserIds = draft
		closeAdminModal()
		renderLogs()
	end
	modalPickerCallback = nil
	modalShade.Visible = true
end, {size = UDim2.new(0.5, -4, 0, 40), textSize = 12})
local logSortButton
logSortButton = button(logControls, "SORT: NEWEST", function()
	sortLogsByPlayer = not sortLogsByPlayer
	logSortButton.Text = sortLogsByPlayer and "SORT: PLAYER" or "SORT: NEWEST"
	renderLogs()
end, {size = UDim2.new(0.5, -4, 0, 40), textSize = 12})
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
			local username = tostring(row.username or row.name or row.userId or "Staff")
			local roleName = displayRole(row.role)
			local statusName = row.online and "ONLINE" or "OFFLINE"
			local item = button(staffList, string.format("%s  -  %s  -  %s", username, roleName, statusName), function(b)
				selectedStaffId = tonumber(row.userId)
				selectedUserId = tonumber(row.userId)
				selectedUsername = username
				moderationTargetUserId = tonumber(row.userId)
				moderationTargetUsername = username
				moderationTargetButton.Text = username .. "  ·  @" .. username
				selectedLabel.Text = "SELECTED  ·  " .. username
				updatePlayerDetails(row)
				for _, other in ipairs(staffList:GetChildren()) do
					if other:IsA("TextButton") then setButtonBackground(other, other == b and C.green or C.surface) end
				end
			end, {size = UDim2.new(1, 0, 0, 44), textSize = 14})
			item.TextXAlignment = Enum.TextXAlignment.Left
			item.TextWrapped = false
			item.TextTruncate = Enum.TextTruncate.AtEnd
			item.Text = "   " .. string.format("%s  -  %s  -  %s", username, roleName, statusName)
			setButtonBackground(item, selectedStaffId == tonumber(row.userId) and C.green or C.surface)
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
		end, {size = UDim2.new(1, 0, 0, 42), primary = enabled, textSize = 14})
	end
end

renderLogs = function()
	for _, child in ipairs(logList:GetChildren()) do
		if child:IsA("TextLabel") or child:IsA("Frame") then child:Destroy() end
	end

	local filtered = {}
	local selectedCount = 0
	for _, enabled in pairs(selectedLogUserIds) do if enabled then selectedCount += 1 end end
	for _, row in ipairs(logs) do
		local actorId = tonumber(row.actorUserId) or 0
		local targetId = tonumber(row.targetUserId) or 0
		local matches = selectedCount == 0
			or selectedLogUserIds[actorId] == true
			or selectedLogUserIds[targetId] == true
		if matches then table.insert(filtered, row) end
	end
	logFilterButton.Text = selectedCount == 0 and "PLAYERS: ALL" or ("PLAYERS: " .. tostring(selectedCount) .. " SELECTED")

	table.sort(filtered, function(a, b)
		if sortLogsByPlayer then
			local aName = string.lower(tostring(a.target or a.actor or "SYSTEM"))
			local bName = string.lower(tostring(b.target or b.actor or "SYSTEM"))
			if aName ~= bName then return aName < bName end
		end
		return (tonumber(a.time) or 0) > (tonumber(b.time) or 0)
	end)

	if #filtered == 0 then
		showPageStatus(logList, selectedCount > 0 and "No activity found for the selected players." or "No activity records received.")
		return
	end

	for index = 1, math.min(#filtered, 40) do
		local row = filtered[index]
		local titleLine = tostring(row.action or row.event or "Player activity")
		local playerName = tostring(row.target or row.actor or row.username or "Unknown")
		local resultText = tostring(row.result or row.status or "Recorded")
		local timestamp = os.date("%b %d  %H:%M", tonumber(row.time) or 0)
		local detail = string.format("%s  ·  %s  ·  %s", playerName, resultText, timestamp)
		local line = make("Frame", {Size = UDim2.new(1, 0, 0, 66), BackgroundColor3 = C.surface, BorderSizePixel = 0}, logList)
		addCorner(line, 11)
		local titleLabel = text(line, titleLine, 15, C.text, 22, true)
		titleLabel.Position = UDim2.fromOffset(14, 6)
		titleLabel.Size = UDim2.new(1, -28, 0, 22)
		local detailLabel = text(line, detail, 12, C.muted, 28)
		detailLabel.Position = UDim2.fromOffset(14, 31)
		detailLabel.Size = UDim2.new(1, -28, 0, 28)
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
	metricPlayers.Text = tostring(metrics.playerCount or #snapshot.players or 0)
	local uptime = math.max(0, math.floor(tonumber(metrics.uptime) or 0))
	metricUptime.Text = string.format("%dm %02ds", math.floor(uptime / 60), uptime % 60)
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
	panelScale.Scale = math.max(0.5, math.min(0.94, (size.X - 32) / 1040, (size.Y - 32) / 720))
end

gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitPanel)
task.defer(fitPanel)

-- The top-right launcher is intentionally disabled; /tx opens the menu.
launcher.Visible = false
closeButton.Activated:Connect(function()
	panelOpen = false
	applyPanel()
end)
-- Outside clicks no longer close the admin panel; use the close button or Escape.

local FLY_KEY_MAP = {
	[Enum.KeyCode.W] = "Forward",
	[Enum.KeyCode.Up] = "Forward",
	[Enum.KeyCode.S] = "Backward",
	[Enum.KeyCode.Down] = "Backward",
	[Enum.KeyCode.A] = "Left",
	[Enum.KeyCode.Left] = "Left",
	[Enum.KeyCode.D] = "Right",
	[Enum.KeyCode.Right] = "Right",
	[Enum.KeyCode.Space] = "Up",
	[Enum.KeyCode.LeftControl] = "Down",
	[Enum.KeyCode.C] = "Down",
	[Enum.KeyCode.LeftAlt] = "Fast",
}

UserInputService.InputBegan:Connect(function(inputObject, processed)
	if inputObject.UserInputType == Enum.UserInputType.Keyboard then
		local flyKey = FLY_KEY_MAP[inputObject.KeyCode]
		if flyKey and not processed then
			flyKeys[flyKey] = true
		end
	end
	if processed then return end
	if inputObject.KeyCode == Enum.KeyCode.RightShift and authorized then
		panelOpen = not panelOpen
		applyPanel()
	end
	if inputObject.KeyCode == Enum.KeyCode.Escape then
		if modalShade.Visible then
			closeAdminModal()
		elseif panelOpen then
			panelOpen = false
			applyPanel()
		end
	end
end)

UserInputService.InputEnded:Connect(function(inputObject)
	if inputObject.UserInputType == Enum.UserInputType.Keyboard then
		local flyKey = FLY_KEY_MAP[inputObject.KeyCode]
		if flyKey then
			flyKeys[flyKey] = nil
		end
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

local function stopCameraFeed(token)
	if token and cameraFeedToken and token ~= cameraFeedToken then return end
	if cameraFeedConnection then
		cameraFeedConnection:Disconnect()
		cameraFeedConnection = nil
	end
	cameraFeedToken = nil
end

local function startCameraFeed(token)
	stopCameraFeed()
	cameraFeedToken = token
	if type(token) ~= "string" or #token < 8 then
		cameraFeedToken = nil
		return
	end
	local lastSent = 0
	cameraFeedConnection = RunService.RenderStepped:Connect(function()
		if not cameraFeedToken or cameraFeedToken ~= token then
			stopCameraFeed(token)
			return
		end
		local now = os.clock()
		if now - lastSent < 0.12 then return end
		local camera = Workspace.CurrentCamera
		if not camera then return end
		lastSent = now
		remote:FireServer("CameraFrame", {
			token = token,
			cframe = camera.CFrame,
			fov = camera.FieldOfView,
		})
	end)
end

local function flyDirection()
	local camera = Workspace.CurrentCamera
	if not camera then return Vector3.zero, Vector3.new(0, 0, -1), 0 end

	local look = camera.CFrame.LookVector
	local flatForward = Vector3.new(look.X, 0, look.Z)
	if flatForward.Magnitude < 0.01 then flatForward = Vector3.new(0, 0, -1) end
	flatForward = flatForward.Unit

	local right = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z)
	if right.Magnitude < 0.01 then right = Vector3.xAxis end
	right = right.Unit

	local direction = Vector3.zero
	if flyKeys.Forward then direction += look end
	if flyKeys.Backward then direction -= look end
	if flyKeys.Right then direction += right end
	if flyKeys.Left then direction -= right end
	if flyKeys.Up then direction += Vector3.yAxis end
	if flyKeys.Down then direction -= Vector3.yAxis end

	-- Touch thumbstick/gamepad movement remains available while flight is enabled.
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local moveDirection = humanoid.MoveDirection
		if moveDirection.Magnitude > 0.05 then
			direction += Vector3.new(moveDirection.X, 0, moveDirection.Z)
		end
	end

	if direction.Magnitude > 1 then direction = direction.Unit end
	local strafe = (flyKeys.Right and 1 or 0) - (flyKeys.Left and 1 or 0)
	if strafe == 0 and direction.Magnitude > 0.01 then
		strafe = math.clamp(direction:Dot(right), -1, 1)
	end
	local bank = math.clamp(-strafe * 0.2, -0.22, 0.22)
	return direction, flatForward, bank
end

RunService.RenderStepped:Connect(function()
	if not flyEnabled then return end
	local now = os.clock()
	if now - lastFlySend < 0.1 then return end
	lastFlySend = now
	local direction, facing, bank = flyDirection()
	remote:FireServer("AbilityMove", {
		direction = direction,
		facing = facing,
		bank = bank,
		speed = flyKeys.Fast and 72 or 48,
	})
end)

remote.OnClientEvent:Connect(function(event, data)
	if event == "AccessGranted" then
		if type(data) ~= "table" or type(data.role) ~= "string" then return end
		role = data.role
		permissions = type(data.permissions) == "table" and data.permissions or {}
		authorized = true
		launcher.Visible = false
		profileName.Text = player.Name
		profileUser.Text = "@" .. player.Name
		profileRole.Text = role == "MASTER DEVELOPER" and "DEV" or displayRole(role)
		adminTitleEnabled = player:GetAttribute("PalmVilleAdminTitleVisible") ~= false
		overviewAbilityCard.Visible = canAccess("Tools")
		refreshOverviewAbilityButtons()
		refreshPlayerActionButtons()
		setStatus("AUTHORIZED  ·  " .. role)
		refreshNavigation()
		if canAccess("Monitoring") or canAccess("Server") or canAccess("Players") or canAccess("Moderation") then remote:FireServer("RequestSnapshot") end
		if managerRole() then remote:FireServer("RequestStaff") end
	elseif event == "AccessDenied" then
		authorized = false
		panelOpen = false
		launcher.Visible = false
		applyPanel()
	elseif event == "OpenAdminMenu" then
		if authorized then
			panelOpen = true
			applyPanel()
		end
	elseif event == "Notice" then
		setStatus(tostring(data), true)
	elseif event == "Snapshot" then
		if type(data) == "table" then
			snapshot = data
			updateMetrics()
			if modalPicker.Visible and not logFilterModalOpen then renderModalPlayerPicker() end
			if activeTab == "PLAYERS" then renderPlayers() end
			if managerRole() and activeTab == "STAFF" then remote:FireServer("RequestStaff") end
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
	elseif event == "SetFly" then
		flyEnabled = data == true
		if not flyEnabled then table.clear(flyKeys) end
		flyTouchControls.Visible = flyEnabled and UserInputService.TouchEnabled
		refreshOverviewAbilityButtons()
		setStatus(flyEnabled and "FLY ENABLED · WASD / SPACE / CTRL" or "FLY DISABLED")
	elseif event == "SetInvisible" then
		invisibleEnabled = data == true
		refreshOverviewAbilityButtons()
	elseif event == "SetAdminTitle" then
		adminTitleEnabled = data == true
		refreshOverviewAbilityButtons()
	elseif event == "FreezeState" then
		if type(data) == "table" and tonumber(data.userId) then
			frozenTargets[tonumber(data.userId)] = data.enabled == true or nil
			if selectedUserId == tonumber(data.userId) then
				refreshPlayerActionButtons()
			end
		end
	elseif event == "SpectateStarted" then
		if type(data) ~= "table" then return end
		spectatingUserId = tonumber(data.targetUserId)
		watchScreenMode = data.watchScreen == true
		watchScreenToken = data.token
		refreshPlayerActionButtons()
		local camera = Workspace.CurrentCamera
		if camera then
			savedCamera = savedCamera or {type = camera.CameraType, subject = camera.CameraSubject, fov = camera.FieldOfView}
			if watchScreenMode then
				camera.CameraType = Enum.CameraType.Scriptable
			else
				local target = Players:GetPlayerByUserId(spectatingUserId)
				local humanoid = target and target.Character and target.Character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					camera.CameraType = Enum.CameraType.Custom
					camera.CameraSubject = humanoid
				end
			end
		end
	elseif event == "WatchScreenStarted" then
		if type(data) == "table" then
			watchScreenMode = true
			watchScreenToken = data.token
			local camera = Workspace.CurrentCamera
			if camera then
				savedCamera = savedCamera or {type = camera.CameraType, subject = camera.CameraSubject, fov = camera.FieldOfView}
				camera.CameraType = Enum.CameraType.Scriptable
			end
		end
	elseif event == "LiveCamera" then
		if watchScreenMode and type(data) == "table" and data.token == watchScreenToken then
			local camera = Workspace.CurrentCamera
			if camera and typeof(data.cframe) == "CFrame" then
				camera.CameraType = Enum.CameraType.Scriptable
				camera.CFrame = data.cframe
				camera.FieldOfView = math.clamp(tonumber(data.fov) or 70, 20, 120)
			end
		end
	elseif event == "BeginCameraFeed" then
		if type(data) == "table" then startCameraFeed(data.token) end
	elseif event == "StopCameraFeed" then
		if type(data) == "table" then stopCameraFeed(data.token) end
	elseif event == "SpectateStopped" then
		spectatingUserId = nil
		watchScreenMode = false
		watchScreenToken = nil
		refreshPlayerActionButtons()
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

task.spawn(function()
	while gui.Parent do
		task.wait(1.5)
		if authorized and panelOpen and (
			canAccess("Monitoring")
			or canAccess("Server")
			or canAccess("Players")
			or canAccess("Moderation")
		) then
			remote:FireServer("RequestSnapshot")
		end
	end
end)
