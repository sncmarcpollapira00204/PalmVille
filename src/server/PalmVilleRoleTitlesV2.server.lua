local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
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

-- Overhead role tag only: no panel, card, frame, or extra nameplate UI.
local styles = {
	OWNER = {text = "OWNER", color = Color3.fromRGB(255, 181, 67), outline = Color3.fromRGB(35, 24, 18)},
	["MASTER DEVELOPER"] = {text = "DEVELOPER", color = Color3.fromRGB(255, 181, 67), outline = Color3.fromRGB(35, 24, 18)},
	["HEAD ADMIN"] = {text = "HEAD ADMIN", color = Color3.fromRGB(255, 181, 67), outline = Color3.fromRGB(35, 24, 18)},
	ADMIN = {text = "ADMIN", color = Color3.fromRGB(255, 181, 67), outline = Color3.fromRGB(35, 24, 18)},
	MODERATOR = {text = "MODERATOR", color = Color3.fromRGB(255, 181, 67), outline = Color3.fromRGB(35, 24, 18)},
}

local function getRole(player)
	local ok, role = pcall(function()
		return resolver:Invoke(player)
	end)
	if ok and type(role) == "string" then return role end
	return nil
end

local function removeTitle(character)
	local head = character and character:FindFirstChild("Head")
	if not head then return end
	for _, child in ipairs(head:GetChildren()) do
		if child.Name == GUI_NAME and child:IsA("BillboardGui") then child:Destroy() end
	end
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
	billboard.Size = UDim2.new(6.5, 0, 1.75, 0)
	billboard.StudsOffset = Vector3.new(0, 2.85, 0)
	billboard.MaxDistance = 125
	billboard.AlwaysOnTop = false
	billboard.LightInfluence = 0
	billboard.Enabled = player:GetAttribute("PalmVilleAdminTitleVisible") ~= false

	-- Rank line: slightly smaller, gently floating above the name.
	local roleLabel = Instance.new("TextLabel")
	roleLabel.Name = "RoleTag"
	roleLabel.BackgroundTransparency = 1
	roleLabel.Position = UDim2.fromScale(0, 0.02)
	roleLabel.Size = UDim2.fromScale(1, 0.43)
	roleLabel.Font = Enum.Font.Cartoon
	roleLabel.Text = style.text
	roleLabel.TextColor3 = style.color
	roleLabel.TextSize = 27
	roleLabel.TextScaled = true
	roleLabel.TextWrapped = false
	roleLabel.TextStrokeColor3 = style.outline
	roleLabel.TextStrokeTransparency = 0
	roleLabel.TextXAlignment = Enum.TextXAlignment.Center
	roleLabel.TextYAlignment = Enum.TextYAlignment.Center
	roleLabel.Parent = billboard

	local roleOutline = Instance.new("UIStroke")
	roleOutline.Name = "DarkLetterOutline"
	roleOutline.Color = style.outline
	roleOutline.Thickness = 1.2
	roleOutline.Transparency = 0.05
	roleOutline.Parent = roleLabel

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "PlayerName"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.fromScale(0, 0.40)
	nameLabel.Size = UDim2.fromScale(1, 0.60)
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.Text = player:GetAttribute("PalmVilleAdminNickname") ~= "" and (player:GetAttribute("PalmVilleAdminNickname") or player.DisplayName) or player.DisplayName
	nameLabel.TextColor3 = Color3.fromRGB(255, 246, 224)
	nameLabel.TextSize = 39
	nameLabel.TextScaled = true
	nameLabel.TextWrapped = false
	nameLabel.TextStrokeColor3 = Color3.fromRGB(28, 22, 24)
	nameLabel.TextStrokeTransparency = 0
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.TextYAlignment = Enum.TextYAlignment.Center
	nameLabel.Parent = billboard

	local nameOutline = Instance.new("UIStroke")
	nameOutline.Name = "DarkLetterOutline"
	nameOutline.Color = Color3.fromRGB(28, 22, 24)
	nameOutline.Thickness = 1.6
	nameOutline.Transparency = 0.04
	nameOutline.Parent = nameLabel

	local glow = Instance.new("UIStroke")
	glow.Name = "SoftRoleGlow"
	glow.Color = style.color
	glow.Thickness = 1.1
	glow.Transparency = 0.5
	glow.Parent = roleLabel

	-- Gentle vertical float on the rank only; the player name stays steady.
	local floatInfo = TweenInfo.new(1.15, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	TweenService:Create(roleLabel, floatInfo, {
		Position = UDim2.fromScale(0, -0.015),
	}):Play()

	local pulseInfo = TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	TweenService:Create(glow, pulseInfo, {
		Thickness = 1.7,
		Transparency = 0.68,
	}):Play()
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
	player:GetAttributeChangedSignal("PalmVilleAdminNickname"):Connect(function()
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		local billboard = head and head:FindFirstChild(GUI_NAME)
		local nameLabel = billboard and billboard:FindFirstChild("PlayerName")
		if nameLabel and nameLabel:IsA("TextLabel") then
			local nickname = player:GetAttribute("PalmVilleAdminNickname")
			nameLabel.Text = type(nickname) == "string" and nickname ~= "" and nickname or player.DisplayName
		end
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
	if player.Character then task.spawn(createTitle, player, player.Character) end
end

Players.PlayerAdded:Connect(bindPlayer)
for _, player in ipairs(Players:GetPlayers()) do bindPlayer(player) end

if roleChanged and roleChanged:IsA("BindableEvent") then
	roleChanged.Event:Connect(function(userId)
		local player = Players:GetPlayerByUserId(tonumber(userId))
		if player then refreshPlayer(player) end
	end)
end
