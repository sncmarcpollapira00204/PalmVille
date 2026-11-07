local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local resolver = ServerScriptService:WaitForChild("PalmVilleGetAdminRole", 30)
if not resolver or not resolver:IsA("BindableFunction") then
	warn("[PalmVille Role Tags] PalmVilleGetAdminRole resolver was not found.")
	return
end

local roleChanged = ServerScriptService:WaitForChild("PalmVilleAdminRoleChanged", 30)
local GUI_NAME = "FarmVilleRoleTitle"
local connected = setmetatable({}, {__mode = "k"})
local handled = setmetatable({}, {__mode = "k"})

-- Premium PalmVille staff nameplates. Each rank has its own accent, emblem and identity.
local styles = {
	OWNER = {
		text = "OWNER",
		kicker = "PALMVILLE  /  FOUNDER",
		icon = "★",
		accent = Color3.fromRGB(255, 207, 74),
		deep = Color3.fromRGB(100, 65, 13),
	},
	["MASTER DEVELOPER"] = {
		text = "MASTER DEVELOPER",
		kicker = "PALMVILLE  /  DEVELOPMENT",
		icon = "✦",
		accent = Color3.fromRGB(91, 190, 255),
		deep = Color3.fromRGB(17, 65, 105),
	},
	["HEAD ADMIN"] = {
		text = "HEAD ADMIN",
		kicker = "PALMVILLE  /  LEAD STAFF",
		icon = "◆",
		accent = Color3.fromRGB(255, 112, 194),
		deep = Color3.fromRGB(105, 31, 77),
	},
	ADMIN = {
		text = "ADMIN",
		kicker = "PALMVILLE  /  STAFF",
		icon = "⬟",
		accent = Color3.fromRGB(103, 224, 145),
		deep = Color3.fromRGB(24, 82, 51),
	},
	MODERATOR = {
		text = "MODERATOR",
		kicker = "PALMVILLE  /  COMMUNITY",
		icon = "◆",
		accent = Color3.fromRGB(188, 202, 220),
		deep = Color3.fromRGB(61, 72, 88),
	},
	HELPER = {
		text = "HELPER",
		kicker = "PALMVILLE  /  SUPPORT",
		icon = "✚",
		accent = Color3.fromRGB(255, 190, 126),
		deep = Color3.fromRGB(105, 62, 34),
	},
}

local function getRole(player)
	local ok, role = pcall(function()
		return resolver:Invoke(player)
	end)
	if ok and type(role) == "string" then
		return role
	end
	return nil
end

local function removeTitle(character)
	local head = character and character:FindFirstChild("Head")
	if not head then return end
	for _, child in ipairs(head:GetChildren()) do
		if child.Name == GUI_NAME and child:IsA("BillboardGui") then
			child:Destroy()
		end
	end
end

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

local function createTitle(player, character)
	if not character or player.Character ~= character or handled[character] then return end
	if player:GetAttribute("PalmVilleAdminTitleVisible") == false then
		removeTitle(character)
		handled[character] = nil
		return
	end

	handled[character] = true
	local role = getRole(player)
	local style = role and styles[role]
	local head = character:WaitForChild("Head", 10)
	if not head or not head:IsA("BasePart") or player.Character ~= character
		or player:GetAttribute("PalmVilleAdminTitleVisible") == false then
		handled[character] = nil
		removeTitle(character)
		return
	end

	removeTitle(character)
	if not style then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = GUI_NAME
	billboard.Adornee = head
	billboard.Size = UDim2.fromOffset(246, 68)
	billboard.StudsOffset = Vector3.new(0, 3.45, 0)
	billboard.MaxDistance = 125
	billboard.AlwaysOnTop = false
	billboard.LightInfluence = 0
	billboard.Enabled = player:GetAttribute("PalmVilleAdminTitleVisible") ~= false

	local plate = Instance.new("Frame")
	plate.Name = "Nameplate"
	plate.Size = UDim2.fromScale(1, 1)
	plate.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
	plate.BackgroundTransparency = 0.08
	plate.BorderSizePixel = 0
	plate.Parent = billboard
	addCorner(plate, 13)

	local plateStroke = Instance.new("UIStroke")
	plateStroke.Name = "RankBorder"
	plateStroke.Color = style.accent
	plateStroke.Thickness = 1.65
	plateStroke.Transparency = 0.12
	plateStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	plateStroke.Parent = plate

	local plateGradient = Instance.new("UIGradient")
	plateGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(31, 34, 43)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(13, 15, 20)),
	})
	plateGradient.Rotation = 90
	plateGradient.Parent = plate

	local accentBar = Instance.new("Frame")
	accentBar.Name = "RankAccent"
	accentBar.Size = UDim2.new(0, 4, 1, -18)
	accentBar.Position = UDim2.fromOffset(0, 9)
	accentBar.BackgroundColor3 = style.accent
	accentBar.BorderSizePixel = 0
	accentBar.Parent = plate
	addCorner(accentBar, 3)

	local emblem = Instance.new("Frame")
	emblem.Name = "RankEmblem"
	emblem.Size = UDim2.fromOffset(44, 44)
	emblem.Position = UDim2.fromOffset(13, 12)
	emblem.BackgroundColor3 = style.deep
	emblem.BackgroundTransparency = 0.08
	emblem.BorderSizePixel = 0
	emblem.Parent = plate
	addCorner(emblem, 11)

	local emblemStroke = Instance.new("UIStroke")
	emblemStroke.Color = style.accent
	emblemStroke.Thickness = 1
	emblemStroke.Transparency = 0.38
	emblemStroke.Parent = emblem

	local emblemIcon = Instance.new("TextLabel")
	emblemIcon.Name = "Icon"
	emblemIcon.BackgroundTransparency = 1
	emblemIcon.Size = UDim2.fromScale(1, 1)
	emblemIcon.Font = Enum.Font.GothamBold
	emblemIcon.Text = style.icon
	emblemIcon.TextColor3 = style.accent
	emblemIcon.TextScaled = true
	emblemIcon.Parent = emblem

	local iconLimit = Instance.new("UITextSizeConstraint")
	iconLimit.MinTextSize = 20
	iconLimit.MaxTextSize = 28
	iconLimit.Parent = emblemIcon

	local kicker = Instance.new("TextLabel")
	kicker.Name = "BrandLine"
	kicker.BackgroundTransparency = 1
	kicker.Position = UDim2.fromOffset(68, 11)
	kicker.Size = UDim2.new(1, -80, 0, 15)
	kicker.Font = Enum.Font.GothamBold
	kicker.Text = style.kicker
	kicker.TextColor3 = style.accent
	kicker.TextSize = 9
	kicker.TextTransparency = 0.08
	kicker.TextXAlignment = Enum.TextXAlignment.Left
	kicker.TextYAlignment = Enum.TextYAlignment.Center
	kicker.Parent = plate

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(67, 27)
	title.Size = UDim2.new(1, -78, 0, 27)
	title.Font = Enum.Font.GothamBlack
	title.Text = style.text
	title.TextColor3 = Color3.fromRGB(248, 249, 252)
	title.TextSize = role == "MASTER DEVELOPER" and 16 or 19
	title.TextScaled = false
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextYAlignment = Enum.TextYAlignment.Center
	title.Parent = plate

	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = style.deep
	titleStroke.Thickness = 0.5
	titleStroke.Transparency = 0.55
	titleStroke.Parent = title

	billboard.Parent = head
end

local function refreshPlayer(player)
	if player.Character then
		handled[player.Character] = nil
		task.spawn(createTitle, player, player.Character)
	end
end

local function bindPlayer(player)
	if connected[player] then return end
	connected[player] = true

	player.CharacterAdded:Connect(function(character)
		task.spawn(createTitle, player, character)
	end)

	player:GetAttributeChangedSignal("PalmVilleAdminTitleVisible"):Connect(function()
		local character = player.Character
		if not character then return end
		if player:GetAttribute("PalmVilleAdminTitleVisible") == false then
			removeTitle(character)
			handled[character] = nil
		else
			handled[character] = nil
			task.spawn(createTitle, player, character)
		end
	end)

	if player.Character then
		task.spawn(createTitle, player, player.Character)
	end
end

Players.PlayerAdded:Connect(bindPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	bindPlayer(player)
end

if roleChanged and roleChanged:IsA("BindableEvent") then
	roleChanged.Event:Connect(function(userId)
		local player = Players:GetPlayerByUserId(tonumber(userId))
		if player then refreshPlayer(player) end
	end)
end
