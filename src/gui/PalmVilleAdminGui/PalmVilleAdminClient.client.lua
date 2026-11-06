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
	bg = Color3.fromRGB(4, 22, 12),
	panel = Color3.fromRGB(8, 34, 19),
	surface = Color3.fromRGB(17, 49, 28),
	surfaceHover = Color3.fromRGB(31, 75, 41),
	green = Color3.fromRGB(83, 124, 52),
	greenBright = Color3.fromRGB(137, 166, 76),
	line = Color3.fromRGB(127, 148, 82),
	text = Color3.fromRGB(248, 246, 221),
	muted = Color3.fromRGB(216, 218, 185),
	dim = Color3.fromRGB(164, 177, 136),
	red = Color3.fromRGB(184, 72, 65),
	amber = Color3.fromRGB(239, 226, 170),
	blue = Color3.fromRGB(112, 192, 61),
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
		TextSize = size or 15,
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
		TextSize = options.textSize or 15,
		TextWrapped = true,
	}, parent)
	b:SetAttribute("BaseBackgroundColor", baseColor)
	addCorner(b, options.radius or 11)
	addStroke(b, options.danger and C.red or (options.primary and C.amber or C.line), 0.08, 1.3)
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
		BackgroundColor3 = C.bg,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Font = Enum.Font.Gotham,
		TextSize = 15,
		TextColor3 = C.text,
		PlaceholderColor3 = C.dim,
		PlaceholderText = placeholder,
		Text = defaultText or "",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = false,
	}, parent)
	addCorner(box, 10)
	addStroke(box, C.line, 0.08, 1.3)
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
		BorderSizePixel = 0,
	}, parent)
	addCorner(root, 17)
	addStroke(root, C.line, 0.04, 1.4)
	make("UIPadding", {
		PaddingTop = UDim.new(0, 24),
		PaddingBottom = UDim.new(0, 24),
		PaddingLeft = UDim.new(0, 26),
		PaddingRight = UDim.new(0, 26),
	}, root)
	local layout = vertical(root, 13)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	if icon then
		local head = make("Frame", {Size = UDim2.new(1, 0, 0, 62), BackgroundTransparency = 1}, root)
		local headingIcon = drawIcon(head, icon, 38, C.amber)
		headingIcon.Position = UDim2.fromOffset(10, 12)
		local heading = text(head, titleText, 27, C.text, 34, true)
		heading.Position = UDim2.fromOffset(66, 0)
		heading.Size = UDim2.new(1, -66, 0, 34)
		local sub = text(head, subtitle or "", 17, C.muted, 25)
		sub.Position = UDim2.fromOffset(66, 34)
		sub.Size = UDim2.new(1, -66, 0, 25)
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
		Padding = UDim.new(0, 12),
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

local banner = make("Frame", {
	Name = "AnnouncementBannerV2",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 76),
	Size = UDim2.fromOffset(640, 54),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 80,
}, gui)

local bannerPrefix = make("TextLabel", {
	Name = "AnnouncementPrefix",
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 27,
	TextColor3 = C.text,
	TextStrokeColor3 = Color3.new(0, 0, 0),
	TextStrokeTransparency = 0.25,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Center,
	TextWrapped = false,
	RichText = true,
	Size = UDim2.fromOffset(0, 38),
	ZIndex = 81,
}, banner)

local bannerVerified = make("TextLabel", {
	Name = "AnnouncementVerified",
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	Text = "✓",
	TextSize = 23,
	TextColor3 = Color3.fromRGB(0, 149, 255),
	TextStrokeColor3 = Color3.new(0, 0, 0),
	TextStrokeTransparency = 0.25,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextYAlignment = Enum.TextYAlignment.Center,
	TextWrapped = false,
	Size = UDim2.fromOffset(24, 38),
	ZIndex = 81,
}, banner)

local bannerMessage = make("TextLabel", {
	Name = "AnnouncementMessage",
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 27,
	TextColor3 = Color3.fromRGB(241, 245, 239),
	TextStrokeColor3 = Color3.new(0, 0, 0),
	TextStrokeTransparency = 0.25,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Center,
	TextWrapped = true,
	RichText = false,
	Size = UDim2.fromOffset(0, 38),
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
	Font = Enum.Font.Gotham,
	TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Center,
	Visible = false,
	ZIndex = 82,
}, banner)

local bannerToken = 0
local bannerTweens = {}
local function escapeRichText(value)
	return tostring(value):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
end

local function setBannerTextTransparency(value, duration)
	for _, tween in ipairs(bannerTweens) do
		tween:Cancel()
	end
	table.clear(bannerTweens)

	for _, label in ipairs({bannerPrefix, bannerVerified, bannerMessage}) do
		local tween = TweenService:Create(label, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextTransparency = value,
		})
		table.insert(bannerTweens, tween)
		tween:Play()
	end
end

local function showAnnouncement(data, preview)
	if type(data) ~= "table" then return end

	local incomingRole = tostring(data.role or "")
	local roleLabel = displayRole(incomingRole)
	local authorText = incomingRole == "MASTER DEVELOPER" and "Lupin" or tostring(data.by or "Staff")
	local message = tostring(data.text or "")
	if message:gsub("%s", "") == "" then return end

	local availableWidth = math.max(220, math.min(1180, gui.AbsoluteSize.X - 40))
	local fontSize = 27
	local roleText = "[" .. roleLabel .. "] "
	local function measurePrefix()
		local plainPrefix = roleText .. authorText
		local width = TextService:GetTextSize(plainPrefix, fontSize, Enum.Font.GothamBold, Vector2.new(4000, 100)).X
		return plainPrefix, width
	end

	local plainPrefix, prefixWidth = measurePrefix()
	local maxPrefixWidth = availableWidth * 0.62
	if prefixWidth > maxPrefixWidth then
		local count = utf8.len(authorText) or #authorText
		if count > 10 then
			local cut = utf8.offset(authorText, 10) or (#authorText + 1)
			authorText = authorText:sub(1, cut - 1) .. "…"
		end
		plainPrefix, prefixWidth = measurePrefix()
	end
	if prefixWidth > maxPrefixWidth then
		fontSize = 23
		plainPrefix, prefixWidth = measurePrefix()
	end

	local badgeWidth = 24
	local gap = 8
	local messageX = math.ceil(prefixWidth) + badgeWidth + gap
	local messageAvailable = math.max(80, availableWidth - messageX)
	local messageText = ": " .. message
	local messageBounds = TextService:GetTextSize(
		messageText,
		fontSize,
		Enum.Font.GothamBold,
		Vector2.new(messageAvailable, 10000)
	)
	local messageWidth = math.min(messageAvailable, math.max(64, math.ceil(messageBounds.X + 8)))
	local totalWidth = math.min(availableWidth, messageX + messageWidth)
	local bannerHeight = math.max(fontSize + 12, math.ceil(messageBounds.Y + 10))

	banner.Size = UDim2.fromOffset(totalWidth, bannerHeight)
	bannerPrefix.Position = UDim2.fromOffset(0, 0)
	bannerPrefix.Size = UDim2.fromOffset(math.ceil(prefixWidth) + 2, fontSize + 12)
	bannerPrefix.TextSize = fontSize
	bannerVerified.Position = UDim2.fromOffset(math.ceil(prefixWidth) + 2, 0)
	bannerVerified.Size = UDim2.fromOffset(badgeWidth, fontSize + 12)
	bannerVerified.TextSize = fontSize - 2
	bannerMessage.Position = UDim2.fromOffset(messageX, 0)
	bannerMessage.Size = UDim2.fromOffset(messageWidth, bannerHeight)
	bannerMessage.TextSize = fontSize
	bannerMessage.TextYAlignment = messageBounds.Y > fontSize + 4 and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center

	local roleColor = (incomingRole == "OWNER" or incomingRole == "MASTER DEVELOPER")
		and "rgb(234,197,108)" or "rgb(166,201,133)"
	bannerPrefix.Text = string.format(
		'<font color="%s"><b>%s</b></font><b>%s</b>',
		roleColor,
		escapeRichText(roleText),
		escapeRichText(authorText)
	)
	bannerMessage.Text = messageText

	bannerToken += 1
	local token = bannerToken
	bannerPreview.Visible = preview == true
	banner.Visible = true
	bannerPrefix.TextTransparency = 1
	bannerVerified.TextTransparency = 1
	bannerMessage.TextTransparency = 1
	local y = 76
	banner.Position = UDim2.new(0.5, 0, 0, y - 10)
	setBannerTextTransparency(0, 0.18)
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
		setBannerTextTransparency(1, 0.2)
		task.delay(0.22, function()
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
		bannerPrefix.TextSize = fontSize
		bannerVerified.TextSize = fontSize - 2
		bannerMessage.TextSize = fontSize
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
	Size = UDim2.fromOffset(1540, 900),
	BackgroundColor3 = C.bg,
	BorderSizePixel = 0,
	Visible = false,
	Active = true,
	ClipsDescendants = true,
	ZIndex = 21,
}, gui)
addCorner(panel, 25)
addStroke(panel, C.amber, 0.02, 1.7)
make("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(7, 31, 17)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(3, 18, 10)),
	}),
	Rotation = 90,
}, panel)
local panelScale = make("UIScale", {Scale = 1}, panel)

local sidebar = make("Frame", {
	Name = "Sidebar",
	Size = UDim2.new(0, 340, 1, 0),
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
	Position = UDim2.new(0.5, 0, 0, 38),
	Size = UDim2.fromOffset(140, 140),
	BackgroundColor3 = C.surface,
	BorderSizePixel = 0,
	ScaleType = Enum.ScaleType.Crop,
	ZIndex = 24,
}, sidebar)
addCorner(profileAvatar, 70)
addStroke(profileAvatar, C.amber, 0.02, 1.5)
task.spawn(function()
	local ok, thumbnail = pcall(function()
		return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
	end)
	if ok and profileAvatar.Parent then profileAvatar.Image = thumbnail end
end)

local profileName = text(sidebar, player.Name, 25, C.text, 34, true)
profileName.Position = UDim2.fromOffset(18, 186)
profileName.Size = UDim2.new(1, -36, 0, 34)
profileName.TextXAlignment = Enum.TextXAlignment.Center
local profileUser = text(sidebar, "@" .. player.Name, 14, C.muted, 22)
profileUser.Position = UDim2.fromOffset(18, 218)
profileUser.Size = UDim2.new(1, -36, 0, 22)
profileUser.TextXAlignment = Enum.TextXAlignment.Center
local profileRole = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 249),
	Size = UDim2.fromOffset(174, 38),
	BackgroundColor3 = C.amber,
	BorderSizePixel = 0,
	Text = "STAFF",
	TextColor3 = Color3.fromRGB(17, 34, 18),
	Font = Enum.Font.GothamBold,
	TextSize = 15,
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 24,
}, sidebar)
addCorner(profileRole, 20)
make("Frame", {
	Position = UDim2.fromOffset(28, 305),
	Size = UDim2.new(1, -56, 0, 1),
	BackgroundColor3 = C.line,
	BorderSizePixel = 0,
	ZIndex = 24,
}, sidebar)

local header = make("Frame", {
	Name = "Header",
	Position = UDim2.fromOffset(340, 0),
	Size = UDim2.new(1, -340, 0, 110),
	BackgroundColor3 = C.panel,
	BackgroundTransparency = 0.08,
	BorderSizePixel = 0,
	ZIndex = 22,
}, panel)
local logoMark = make("Frame", {
	Position = UDim2.fromOffset(30, 20),
	Size = UDim2.fromOffset(62, 68),
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
local logoIcon = drawIcon(logoInset, "shield", 36, C.amber)
logoIcon.Position = UDim2.fromOffset(10, 13)
logoIcon.ZIndex = 26
local pageTitle = text(header, "PalmVille Admin", 37, C.text, 48, true)
pageTitle.Position = UDim2.fromOffset(116, 16)
pageTitle.Size = UDim2.new(1, -220, 0, 48)
local pageSubtitle = text(header, "Overview", 18, C.muted, 26)
pageSubtitle.Position = UDim2.fromOffset(118, 64)
pageSubtitle.Size = UDim2.new(1, -220, 0, 26)
local closeButton = button(header, "×", function()
	panelOpen = false
end, {size = UDim2.fromOffset(58, 58), textSize = 35, radius = 12})
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
	Position = UDim2.fromOffset(340, 110),
	Size = UDim2.new(1, -340, 1, -110),
	BackgroundTransparency = 1,
	ClipsDescendants = true,
	ZIndex = 22,
}, panel)
local footer = text(panel, "READY", 12, C.dim, 22)
footer.Position = UDim2.new(0, 360, 1, -26)
footer.Size = UDim2.new(1, -390, 0, 18)
footer.TextXAlignment = Enum.TextXAlignment.Right

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
		activeTab = key
	end, {size = UDim2.new(1, -48, 0, 60), textSize = 17, radius = 12})
	nav.Name = "Nav_" .. key
	nav.Position = UDim2.fromOffset(24, 326 + ((navIndex - 1) * 68))
	nav.Text = ""
	nav.RichText = false
	setButtonBackground(nav, C.panel)
	nav.BackgroundTransparency = 0.08
	nav:SetAttribute("NavCaption", caption)
	local navIcon = drawIcon(nav, navIcons[key], 23, C.amber)
	navIcon.Name = "NavIcon"
	navIcon.Position = UDim2.new(0, 18, 0.5, -11)
	local navLabel = text(nav, caption, 17, C.muted, 60, true)
	navLabel.Name = "NavLabel"
	navLabel.Position = UDim2.fromOffset(60, 0)
	navLabel.Size = UDim2.new(1, -72, 1, 0)
	navLabel.TextWrapped = false
	navLabel.ZIndex = nav.ZIndex + 2
	local navStroke = nav:FindFirstChildOfClass("UIStroke")
	if navStroke then navStroke.Transparency = 0.72 end
	navButtons[key] = nav

	local page = make("ScrollingFrame", {
		Name = "Page_" .. key,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.line,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
	}, content)
	make("UIPadding", {
		PaddingTop = UDim.new(0, 24),
		PaddingBottom = UDim.new(0, 34),
		PaddingLeft = UDim.new(0, 30),
		PaddingRight = UDim.new(0, 30),
	}, page)
	vertical(page, 18)
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
		local allowed = area == nil or (area == "MANAGER" and managerRole()) or (area ~= "MANAGER" and canAccess(area))
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
			if canAccess("Monitoring") or canAccess("Server") then remote:FireServer("RequestSnapshot") end
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
		Size = UDim2.fromOffset(72, 72),
		BackgroundColor3 = C.green,
		BorderSizePixel = 0,
	}, box)
	addCorner(iconBox, 16)
	local metricIcon = drawIcon(iconBox, iconName, 36, C.amber)
	metricIcon.Position = UDim2.fromOffset(18, 18)
	make("Frame", {
		Position = UDim2.new(0, 112, 0.18, 0),
		Size = UDim2.new(0, 1, 0.64, 0),
		BackgroundColor3 = C.line,
		BorderSizePixel = 0,
	}, box)
	local small = text(box, caption, 18, C.muted, 26, true)
	small.Position = UDim2.fromOffset(136, 30)
	small.Size = UDim2.new(1, -158, 0, 26)
	local value = text(box, initial or "—", 32, C.text, 42, true)
	value.Position = UDim2.fromOffset(136, 62)
	value.Size = UDim2.new(1, -158, 0, 42)
	value.TextTruncate = Enum.TextTruncate.AtEnd
	return value
end

local overviewMetricRow = addRow(pages.OVERVIEW, 148)
local metricPlayers = metric(overviewMetricRow, "Online", "0", "users")
local metricUptime = metric(overviewMetricRow, "Server Uptime", "0m 0s", "clock")

local playersWorkspace = make("Frame", {
	Name = "PlayersWorkspace",
	Size = UDim2.new(1, 0, 0, 850),
	BackgroundTransparency = 1,
}, pages.PLAYERS)

local playersListPanel = make("Frame", {
	Name = "OnlinePlayersPanel",
	Size = UDim2.new(0.39, -10, 1, 0),
	BackgroundColor3 = C.panel,
	BorderSizePixel = 0,
}, playersWorkspace)
addCorner(playersListPanel, 18)
addStroke(playersListPanel, C.line, 0.06, 1.4)
local playersDetailsPanel = make("Frame", {
	Name = "PlayerDetailsPanel",
	Position = UDim2.new(0.39, 10, 0, 0),
	Size = UDim2.new(0.61, -10, 1, 0),
	BackgroundColor3 = C.panel,
	BorderSizePixel = 0,
}, playersWorkspace)
addCorner(playersDetailsPanel, 18)
addStroke(playersDetailsPanel, C.line, 0.06, 1.4)

local playersHeadingIcon = drawIcon(playersListPanel, "users", 30, C.amber)
playersHeadingIcon.Position = UDim2.fromOffset(26, 23)
local playersHeading = text(playersListPanel, "Online Players", 25, C.text, 34, true)
playersHeading.Position = UDim2.fromOffset(72, 17)
playersHeading.Size = UDim2.new(1, -90, 0, 34)
local playersScope = text(playersListPanel, "This server · 0 online", 15, C.muted, 24)
playersScope.Position = UDim2.fromOffset(72, 51)
playersScope.Size = UDim2.new(1, -90, 0, 24)
local playerSearch = input(playersListPanel, "Search name or username...", "")
playerSearch.Position = UDim2.fromOffset(18, 92)
playerSearch.Size = UDim2.new(1, -36, 0, 48)
local selectedLabel = text(playersListPanel, "Select a player to view details.", 13, C.muted, 26)
selectedLabel.Position = UDim2.fromOffset(20, 145)
selectedLabel.Size = UDim2.new(1, -40, 0, 26)
local playerRows = make("ScrollingFrame", {
	Name = "PlayerRows",
	Position = UDim2.fromOffset(18, 181),
	Size = UDim2.new(1, -36, 1, -199),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = C.line,
}, playersListPanel)
vertical(playerRows, 9)

local detailsIcon = drawIcon(playersDetailsPanel, "file", 29, C.amber)
detailsIcon.Position = UDim2.fromOffset(28, 22)
local detailTitle = text(playersDetailsPanel, "Player Details", 25, C.text, 36, true)
detailTitle.Position = UDim2.fromOffset(78, 18)
detailTitle.Size = UDim2.new(1, -104, 0, 36)
make("Frame", {
	Position = UDim2.fromOffset(24, 68),
	Size = UDim2.new(1, -48, 0, 1),
	BackgroundColor3 = C.line,
	BorderSizePixel = 0,
}, playersDetailsPanel)

local detailAvatar = make("ImageLabel", {
	Position = UDim2.fromOffset(30, 91),
	Size = UDim2.fromOffset(112, 112),
	BackgroundColor3 = C.surface,
	BorderSizePixel = 0,
	ScaleType = Enum.ScaleType.Crop,
}, playersDetailsPanel)
addCorner(detailAvatar, 56)
addStroke(detailAvatar, C.amber, 0.02, 1.4)
local detailName = text(playersDetailsPanel, "Select a player", 30, C.text, 38, true)
detailName.Position = UDim2.fromOffset(166, 92)
detailName.Size = UDim2.new(1, -194, 0, 38)
local detailUsername = text(playersDetailsPanel, "@username", 18, C.muted, 28)
detailUsername.Position = UDim2.fromOffset(168, 132)
detailUsername.Size = UDim2.new(1, -196, 0, 28)
local detailOnline = text(playersDetailsPanel, "●  Waiting for selection", 15, C.muted, 26)
detailOnline.Position = UDim2.fromOffset(168, 166)
detailOnline.Size = UDim2.new(1, -196, 0, 26)
make("Frame", {
	Position = UDim2.fromOffset(24, 222),
	Size = UDim2.new(1, -48, 0, 1),
	BackgroundColor3 = C.line,
	BorderSizePixel = 0,
}, playersDetailsPanel)
local progressTitle = text(playersDetailsPanel, "Progress", 22, C.text, 30, true)
progressTitle.Position = UDim2.fromOffset(28, 236)
progressTitle.Size = UDim2.new(1, -56, 0, 30)

local function detailStat(x, y, width, labelText, initial)
	local tile = make("Frame", {
		Position = UDim2.new(x, x == 0 and 28 or 8, 0, y),
		Size = UDim2.new(width, width == 0.5 and -42 or -56, 0, 66),
		BackgroundColor3 = C.surface,
		BorderSizePixel = 0,
	}, playersDetailsPanel)
	addCorner(tile, 12)
	addStroke(tile, C.line, 0.18, 1.1)
	local label = text(tile, labelText, 14, C.muted, 20, true)
	label.Position = UDim2.fromOffset(14, 8)
	label.Size = UDim2.new(1, -28, 0, 20)
	local value = text(tile, initial, 16, C.text, 24, true)
	value.Position = UDim2.fromOffset(14, 34)
	value.Size = UDim2.new(1, -28, 0, 24)
	return value
end
local detailMoney = detailStat(0, 276, 0.5, "Money", "Not available")
local detailEarned = detailStat(0.5, 276, 0.5, "Earned Today", "Not available")
local detailLevel = detailStat(0, 351, 0.5, "Level", "Not available")
local detailPlaytime = detailStat(0.5, 351, 0.5, "Total Playtime", "Not available")
local detailXp = detailStat(0, 426, 1, "XP", "Not available")
local detailMetadata = text(playersDetailsPanel, "User ID: —   ·   Role: —   ·   Health: —", 14, C.muted, 24)
detailMetadata.Position = UDim2.fromOffset(30, 505)
detailMetadata.Size = UDim2.new(1, -60, 0, 24)
local detailPosition = text(playersDetailsPanel, "Position: —", 13, C.dim, 22)
detailPosition.Position = UDim2.fromOffset(30, 531)
detailPosition.Size = UDim2.new(1, -60, 0, 22)
local playerActionHeading = text(playersDetailsPanel, "Player Actions", 19, C.text, 26, true)
playerActionHeading.Position = UDim2.fromOffset(30, 563)
playerActionHeading.Size = UDim2.new(1, -60, 0, 26)

local playerActionRow = make("Frame", {
	Position = UDim2.fromOffset(28, 594),
	Size = UDim2.new(1, -56, 0, 46),
	BackgroundTransparency = 1,
}, playersDetailsPanel)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 10),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, playerActionRow)
button(playerActionRow, "GO TO PLAYER", function()
	if not selectedUserId then setStatus("Select a player first.", true); return end
	sendAction("Teleport", targetData())
end, {size = UDim2.new(0.5, -5, 0, 44), primary = true, textSize = 14, bold = true})
button(playerActionRow, "SPECTATE", function()
	if not selectedUserId then setStatus("Select a player first.", true); return end
	sendAction("Spectate", targetData())
end, {size = UDim2.new(0.5, -5, 0, 44), textSize = 14, bold = true})

local moreActionsMenu = make("Frame", {
	Position = UDim2.fromOffset(28, 700),
	Size = UDim2.new(1, -56, 0, 126),
	BackgroundColor3 = C.panel,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = playersDetailsPanel.ZIndex + 2,
}, playersDetailsPanel)
addCorner(moreActionsMenu, 12)
addStroke(moreActionsMenu, C.line, 0.08, 1.2)
make("UIPadding", {
	PaddingTop = UDim.new(0, 7),
	PaddingBottom = UDim.new(0, 7),
	PaddingLeft = UDim.new(0, 8),
	PaddingRight = UDim.new(0, 8),
}, moreActionsMenu)
vertical(moreActionsMenu, 5)
local moreRow1 = addRow(moreActionsMenu, 32)
button(moreRow1, "BRING PLAYER", function()
	if not selectedUserId then setStatus("Select a player first.", true); return end
	sendAction("Bring", targetData())
end, {size = UDim2.new(0.5, -5, 0, 32), textSize = 12})
button(moreRow1, "FREEZE", function()
	if not selectedUserId then setStatus("Select a player first.", true); return end
	sendAction("Freeze", targetData())
end, {size = UDim2.new(0.5, -5, 0, 32), textSize = 12})
local moreRow2 = addRow(moreActionsMenu, 32)
button(moreRow2, "UNFREEZE", function()
	if not selectedUserId then setStatus("Select a player first.", true); return end
	sendAction("Unfreeze", targetData())
end, {size = UDim2.new(0.5, -5, 0, 32), textSize = 12})
button(moreRow2, "RESET PLAYER", function()
	if not selectedUserId then setStatus("Select a player first.", true); return end
	sendAction("ResetTarget", targetData())
end, {size = UDim2.new(0.5, -5, 0, 32), danger = true, textSize = 12})
local moreRow3 = addRow(moreActionsMenu, 32)
button(moreRow3, "RETURN", function()
	sendAction("Return")
end, {size = UDim2.new(0.5, -5, 0, 32), textSize = 12})
button(moreRow3, "STOP SPECTATING", function()
	sendAction("StopSpectate")
end, {size = UDim2.new(0.5, -5, 0, 32), textSize = 12})

local moreActionsButton = button(playersDetailsPanel, "MORE ACTIONS", function()
	moreActionsMenu.Visible = not moreActionsMenu.Visible
end, {size = UDim2.new(1, -56, 0, 42), textSize = 14})
moreActionsButton.Position = UDim2.fromOffset(28, 648)
moreActionsButton.TextXAlignment = Enum.TextXAlignment.Center

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
	local isOnline = row.online == nil or row.online == true
	detailOnline.Text = isOnline and "●  Online" or "●  Offline"
	detailOnline.TextColor3 = isOnline and C.greenBright or C.dim
	local healthText = row.health ~= nil and (tostring(row.health) .. "/" .. tostring(row.maxHealth or row.health)) or "Not available"
	detailMetadata.Text = string.format("User ID: %s   ·   Role: %s   ·   Health: %s",
		tostring(row.userId or "—"), displayRole(row.role), healthText)
	detailPosition.Text = "Position: " .. tostring(row.position or "Not available")
	if row.playtime ~= nil then
		detailPlaytime.Text = string.format("%dm %02ds",
			math.floor((tonumber(row.playtime) or 0) / 60),
			math.floor((tonumber(row.playtime) or 0) % 60))
	else
		detailPlaytime.Text = "Not available"
	end
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

local function renderPlayers()
	for _, child in ipairs(playerRows:GetChildren()) do
		if child:IsA("TextButton") or child:IsA("TextLabel") or child:IsA("Frame") then child:Destroy() end
	end
	local query = string.lower(playerSearch.Text or "")
	local roster = snapshot.players or {}
	local visibleCount = 0
	local selectedStillOnline = false
	for _, entry in ipairs(roster) do
		if entry.userId == selectedUserId then selectedStillOnline = true break end
	end
	if selectedUserId and not selectedStillOnline then
		selectedUserId, selectedUsername = nil, nil
		selectedLabel.Text = "Select a player to view details."
		updatePlayerDetails(nil)
	end
	playersScope.Text = string.format("This server · %d online", #roster)
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
			end, {size = UDim2.new(1, -4, 0, 86), radius = 13})
			item:SetAttribute("UserId", row.userId)
			setButtonBackground(item, row.userId == selectedUserId and C.green or C.surface)
			local avatar = make("ImageLabel", {
				Position = UDim2.fromOffset(12, 12),
				Size = UDim2.fromOffset(60, 60),
				BackgroundColor3 = C.panel,
				BorderSizePixel = 0,
				ScaleType = Enum.ScaleType.Crop,
			}, item)
			addCorner(avatar, 30)
			local nameLabel = text(item, displayName, 19, C.text, 27, true)
			nameLabel.Position = UDim2.fromOffset(86, 14)
			nameLabel.Size = UDim2.new(1, -102, 0, 27)
			local usernameLabel = text(item, "@" .. username, 14, C.muted, 22)
			usernameLabel.Position = UDim2.fromOffset(86, 42)
			usernameLabel.Size = UDim2.new(1, -102, 0, 22)
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
text(announceCard, "Message", 18, C.text, 26, true)
local announceBox = make("TextBox", {
	Size = UDim2.new(1, 0, 0, 176),
	BackgroundColor3 = C.bg,
	BorderSizePixel = 0,
	ClearTextOnFocus = false,
	Font = Enum.Font.Gotham,
	TextSize = 17,
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
addStroke(announceBox, C.line, 0.02, 1.4)
make("UIPadding", {PaddingTop = UDim.new(0, 18), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 18)}, announceBox)
local announceCount = text(announceCard, "0 / 280", 14, C.muted, 22)
announceCount.TextXAlignment = Enum.TextXAlignment.Right
announceBox:GetPropertyChangedSignal("Text"):Connect(function()
	announceCount.Text = tostring(#announceBox.Text) .. " / 280"
	announceCount.TextColor3 = #announceBox.Text > 280 and C.red or C.muted
end)
text(announceCard, "Audience", 18, C.text, 26, true)
local audienceRow = addRow(announceCard, 54)
local serverAudience
local allAudience
serverAudience = iconButton(audienceRow, "This Server", "users", function()
	audience = "This Server"
	setButtonBackground(serverAudience, C.green)
	setButtonBackground(allAudience, C.surface)
end, {size = UDim2.new(0.5, -6, 0, 52), textSize = 16, bold = true})
allAudience = iconButton(audienceRow, "All Servers", "globe", function()
	audience = "All Servers"
	setButtonBackground(serverAudience, C.surface)
	setButtonBackground(allAudience, C.green)
end, {size = UDim2.new(0.5, -6, 0, 52), textSize = 16, bold = true})
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
	sendAction("Announce", {message = value, audience = audience})
	setStatus("Sending announcement...")
end, {size = UDim2.new(1, 0, 0, 54), primary = true, textSize = 18, bold = true})
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
local modActionRow1 = addRow(moderationCard, 48)
button(modActionRow1, "WARN", function()
	local target = moderationTarget()
	target.username = moderationUsername.Text
	target.reason = reasonBox.Text
	if target.reason:gsub("%s", "") == "" then setStatus("A reason is required.", true); return end
	sendAction("Warn", target)
end, {size = UDim2.new(0.33, -5, 0, 46), textSize = 14})
button(modActionRow1, "TOGGLE CHAT MUTE", function()
	local target = moderationTarget()
	target.username = moderationUsername.Text
	sendAction("MuteChat", target)
end, {size = UDim2.new(0.33, -5, 0, 46), textSize = 14})
button(modActionRow1, "KICK", function()
	local target = moderationTarget()
	target.username = moderationUsername.Text
	target.reason = reasonBox.Text
	if target.reason:gsub("%s", "") == "" then setStatus("A reason is required.", true); return end
	sendAction("Kick", target)
end, {size = UDim2.new(0.34, -5, 0, 46), danger = true, textSize = 14})
local modActionRow2 = addRow(moderationCard, 48)
button(modActionRow2, "TEMP BAN", function()
	local target = moderationTarget()
	target.username = moderationUsername.Text
	target.reason = reasonBox.Text
	target.durationDays = math.clamp(math.floor(tonumber(durationBox.Text) or 1), 1, 365)
	if target.reason:gsub("%s", "") == "" then setStatus("A reason is required.", true); return end
	sendAction("TempBan", target)
end, {size = UDim2.new(0.33, -5, 0, 46), danger = true, textSize = 14})
button(modActionRow2, "PERMANENT BAN", function()
	local target = moderationTarget()
	target.username = moderationUsername.Text
	target.reason = reasonBox.Text
	if target.reason:gsub("%s", "") == "" then setStatus("A reason is required.", true); return end
	sendAction("PermanentBan", target)
end, {size = UDim2.new(0.33, -5, 0, 46), danger = true, textSize = 14})
button(modActionRow2, "UNBAN", function()
	local target = moderationTarget()
	target.username = moderationUsername.Text
	target.reason = reasonBox.Text
	sendAction("Unban", target)
end, {size = UDim2.new(0.34, -5, 0, 46), textSize = 14})
local historyCard = card(pages.MODERATION, "MODERATION HISTORY", "Saved actions for the entered or selected account.")
local historyButton = button(historyCard, "LOAD HISTORY", function()
	local target = moderationTarget()
	target.username = moderationUsername.Text
	if not target.targetUserId and target.username == "" then setStatus("Enter a username or select a player.", true); return end
	sendAction("ModerationHistory", target)
end, {primary = true})
local historyText = text(historyCard, "No history loaded.", 14, C.muted, 110)
historyText.TextYAlignment = Enum.TextYAlignment.Top

local staffCard = card(pages.STAFF, "STAFF MANAGEMENT", "Owner and Developer only. The server validates all role changes.")
local staffUsername = addField(staffCard, "ROBLOX USERNAME", "Username to assign")
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
button(staffActions, "ASSIGN ROLE", function()
	if staffUsername.Text:gsub("%s", "") == "" then setStatus("Enter a Roblox username.", true); return end
	sendAction("AddStaff", {username = staffUsername.Text, role = staffRole})
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
local itemCode = addField(toolsCard, "ITEM CODE", "Registered item code", "RICE_SEED")
local itemAmount = addField(toolsCard, "AMOUNT", "1–99", "1")
local itemModeRow = addRow(toolsCard, 48)
for _, mode in ipairs({"Player", "Self", "All"}) do
	button(itemModeRow, string.upper(mode), function(b)
		itemTargetMode = mode
		for _, other in ipairs(itemModeRow:GetChildren()) do
			if other:IsA("TextButton") then setButtonBackground(other, other == b and C.green or C.surface) end
		end
	end, {size = UDim2.new(0.33, -5, 0, 46), textSize = 14})
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
				updatePlayerDetails(row)
				for _, other in ipairs(staffList:GetChildren()) do
					if other:IsA("TextButton") then setButtonBackground(other, other == b and C.green or C.surface) end
				end
			end, {size = UDim2.new(1, 0, 0, 44), textSize = 14})
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
		local line = make("Frame", {Size = UDim2.new(1, 0, 0, 60), BackgroundColor3 = C.surface, BorderSizePixel = 0}, logList)
		addCorner(line, 11)
		local titleLabel = text(line, titleLine, 15, C.text, 22, true)
		titleLabel.Position = UDim2.fromOffset(14, 7)
		titleLabel.Size = UDim2.new(1, -28, 0, 22)
		local detailLabel = text(line, detail, 13, C.muted, 20)
		detailLabel.Position = UDim2.fromOffset(14, 32)
		detailLabel.Size = UDim2.new(1, -28, 0, 20)
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
	panelScale.Scale = math.min(1, (size.X - 32) / 1540, (size.Y - 32) / 900)
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
-- Outside clicks no longer close the admin panel; use the close button or Escape.

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
		profileName.Text = player.Name
		profileUser.Text = "@" .. player.Name
		profileRole.Text = role == "MASTER DEVELOPER" and "DEVELOPER" or displayRole(role)
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
