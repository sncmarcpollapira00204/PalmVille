local Players = game:GetService("Players")

local Roles = {
	[7125208724] = {
		title = "OWNER",
		color = Color3.fromRGB(245, 72, 82),
		glow = Color3.fromRGB(255, 62, 76),
		outline = Color3.fromRGB(78, 22, 30),
	},
	[9419687160] = {
		title = "HEAD ADMIN",
		color = Color3.fromRGB(255, 150, 195),
		glow = Color3.fromRGB(255, 138, 190),
		outline = Color3.fromRGB(88, 43, 65),
	},
	[11199335797] = {
		title = "ALIPIN",
		color = Color3.fromRGB(255, 235, 207),
		glow = Color3.fromRGB(255, 220, 170),
		outline = Color3.fromRGB(82, 70, 54),
	},
}

local GUI_NAME = "FarmVilleRoleTitle"
local connectedPlayers = setmetatable({}, { __mode = "k" })
local handledCharacters = setmetatable({}, { __mode = "k" })

local function createRoleTitle(player, character)
	local role = Roles[player.UserId]
	if not role or handledCharacters[character] then
		return
	end
	handledCharacters[character] = true

	local head = character:WaitForChild("Head", 10)
	if not head or not head:IsA("BasePart") or player.Character ~= character then
		handledCharacters[character] = nil
		return
	end

	for _, child in ipairs(head:GetChildren()) do
		if child:IsA("BillboardGui") and child.Name == GUI_NAME then
			child:Destroy()
		end
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = GUI_NAME
	billboard.Adornee = head
	billboard.Size = UDim2.fromOffset(190, 42)
	billboard.StudsOffset = Vector3.new(0, 2.8, 0)
	billboard.MaxDistance = 120
	billboard.AlwaysOnTop = false
	billboard.LightInfluence = 0.15

	local label = Instance.new("TextLabel")
	label.Name = "Title"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = role.title
	label.TextColor3 = role.color
	label.TextStrokeColor3 = role.outline
	label.TextStrokeTransparency = 0.25
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = billboard

	local textLimit = Instance.new("UITextSizeConstraint")
	textLimit.MinTextSize = 14
	textLimit.MaxTextSize = 23
	textLimit.Parent = label

	local glow = Instance.new("UIStroke")
	glow.Name = "SoftGlow"
	glow.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	glow.Color = role.glow
	glow.Thickness = 1.2
	glow.Transparency = 0.62
	glow.Parent = label

	billboard.Parent = head
end

local function onPlayerAdded(player)
	if connectedPlayers[player] then
		return
	end
	connectedPlayers[player] = true

	player.CharacterAdded:Connect(function(character)
		createRoleTitle(player, character)
	end)

	if player.Character then
		task.spawn(createRoleTitle, player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)

for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end