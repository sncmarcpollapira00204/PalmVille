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

-- Overhead role tag only: no panel, card, frame, or extra nameplate UI.
local styles = {
	OWNER = {text = "OWNER", color = Color3.fromRGB(255, 211, 82), outline = Color3.fromRGB(86, 57, 8)},
	["MASTER DEVELOPER"] = {text = "DEV", color = Color3.fromRGB(105, 195, 255), outline = Color3.fromRGB(15, 48, 84)},
	["HEAD ADMIN"] = {text = "HEAD ADMIN", color = Color3.fromRGB(255, 123, 198), outline = Color3.fromRGB(91, 20, 62)},
	ADMIN = {text = "ADMIN", color = Color3.fromRGB(112, 235, 151), outline = Color3.fromRGB(19, 77, 42)},
	MODERATOR = {text = "MODERATOR", color = Color3.fromRGB(218, 228, 240), outline = Color3.fromRGB(48, 57, 70)},
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
	billboard.Size = UDim2.new(4.5, 0, 0.8, 0)
	billboard.StudsOffset = Vector3.new(0, 3.15, 0)
	billboard.MaxDistance = 125
	billboard.AlwaysOnTop = false
	billboard.LightInfluence = 0
	billboard.Enabled = player:GetAttribute("PalmVilleAdminTitleVisible") ~= false

	local label = Instance.new("TextLabel")
	label.Name = "RoleTag"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Font.fromId(12187367666, Enum.FontWeight.Heavy, Enum.FontStyle.Normal)
	label.Text = style.text
	label.TextColor3 = style.color
	label.TextSize = 24
	label.TextScaled = true
	label.TextWrapped = false
	local textConstraint = Instance.new("UITextSizeConstraint")
	textConstraint.MinTextSize = 14
	textConstraint.MaxTextSize = 24
	textConstraint.Parent = label
	label.TextStrokeColor3 = style.outline
	label.TextStrokeTransparency = 0.12
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = billboard

	local glow = Instance.new("UIStroke")
	glow.Name = "RoleGlow"
	glow.Color = style.color
	glow.Thickness = 1.15
	glow.Transparency = 0.48
	glow.Parent = label

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
