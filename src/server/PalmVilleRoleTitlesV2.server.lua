local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local resolver = ServerScriptService:WaitForChild("PalmVilleGetAdminRole", 30)
if not resolver or not resolver:IsA("BindableFunction") then return end
local roleChanged = ServerScriptService:WaitForChild("PalmVilleAdminRoleChanged", 30)
local GUI_NAME = "FarmVilleRoleTitle"
local connected = setmetatable({}, {__mode = "k"})
local handled = setmetatable({}, {__mode = "k"})

local styles = {
	OWNER = {
		text = "OWNER",
		color = Color3.fromRGB(255, 224, 75),
		glow = Color3.fromRGB(255, 190, 0),
		outline = Color3.fromRGB(91, 58, 0),
		glowThickness = 2.2,
		glowTransparency = 0.18,
	},
	["MASTER DEVELOPER"] = {
		text = "DEV",
		color = Color3.fromRGB(85, 185, 255),
		glow = Color3.fromRGB(0, 125, 255),
		outline = Color3.fromRGB(15, 48, 91),
		glowThickness = 1.8,
		glowTransparency = 0.28,
	},
	["HEAD ADMIN"] = {
		text = "HEAD ADMIN",
		color = Color3.fromRGB(255, 72, 190),
		glow = Color3.fromRGB(255, 0, 170),
		outline = Color3.fromRGB(91, 13, 62),
		glowThickness = 2,
		glowTransparency = 0.2,
	},
	ADMIN = {
		text = "ADMIN",
		color = Color3.fromRGB(92, 255, 125),
		glow = Color3.fromRGB(0, 225, 75),
		outline = Color3.fromRGB(17, 82, 39),
		glowThickness = 1.8,
		glowTransparency = 0.26,
	},
	MODERATOR = {
		text = "MODERATOR",
		color = Color3.fromRGB(230, 230, 230),
		glow = Color3.fromRGB(205, 205, 205),
		outline = Color3.fromRGB(55, 55, 55),
		glowThickness = 1.2,
		glowTransparency = 0.62,
	},
	HELPER = {
		text = "HELPER",
		color = Color3.fromRGB(255, 235, 207),
		glow = Color3.fromRGB(255, 220, 170),
		outline = Color3.fromRGB(82, 70, 54),
		glowThickness = 1.2,
		glowTransparency = 0.62,
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
	if not head or not head:IsA("BasePart") or player.Character ~= character or player:GetAttribute("PalmVilleAdminTitleVisible") == false then
		handled[character] = nil
		removeTitle(character)
		return
	end
	removeTitle(character)
	if not style then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = GUI_NAME
	billboard.Adornee = head
	billboard.Size = UDim2.fromScale(2.4, 0.56)
	billboard.StudsOffset = Vector3.new(0, 2.65, 0)
	billboard.MaxDistance = 80
	billboard.AlwaysOnTop = false
	billboard.LightInfluence = 0.15
	billboard.Enabled = player:GetAttribute("PalmVilleAdminTitleVisible") ~= false

	local label = Instance.new("TextLabel")
	label.Name = "Title"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Nunito
	label.Text = style.text
	label.TextColor3 = style.color
	label.TextStrokeColor3 = style.outline
	label.TextStrokeTransparency = 0.25
	label.TextScaled = true
	label.TextWrapped = false
	label.Parent = billboard

	local sizeLimit = Instance.new("UITextSizeConstraint")
	sizeLimit.MinTextSize = 14
	sizeLimit.MaxTextSize = 24
	sizeLimit.Parent = label

	local glow = Instance.new("UIStroke")
	glow.Name = "SoftGlow"
	glow.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	glow.Color = style.glow
	glow.Thickness = style.glowThickness or 1.2
	glow.Transparency = style.glowTransparency or 0.62
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