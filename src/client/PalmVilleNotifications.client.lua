local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("PalmVilleNotificationEvent")

local COLORS = {
	GENERAL = {accent = Color3.fromRGB(150, 158, 170), icon = "▤"},
	INFO = {accent = Color3.fromRGB(76, 157, 238), icon = "●"},
	SUCCESS = {accent = Color3.fromRGB(67, 194, 155), icon = "✓"},
	ERROR = {accent = Color3.fromRGB(230, 83, 87), icon = "▤"},
	WARNING = {accent = Color3.fromRGB(238, 194, 57), icon = "▲"},
}

local gui = Instance.new("ScreenGui")
gui.Name = "PalmVilleNotificationsGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 120
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local stack = Instance.new("Frame")
stack.Name = "NotificationStack"
stack.AnchorPoint = Vector2.new(1, 1)
stack.Position = UDim2.new(1, -22, 1, -22)
stack.Size = UDim2.new(0, 330, 1, -40)
stack.BackgroundTransparency = 1
stack.Parent = gui

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Vertical
layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 9)
layout.Parent = stack

local active = {}
local nextId = 0
local MAX_VISIBLE = 5
local DISPLAY_TIME = 4.8

local function removeCard(card)
	if not card or not card.Parent then return end
	local fade = TweenService:Create(card, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1,
		Position = card.Position + UDim2.fromOffset(24, 0),
	})
	for _, descendant in ipairs(card:GetDescendants()) do
		if descendant:IsA("TextLabel") then
			TweenService:Create(descendant, TweenInfo.new(0.16), {TextTransparency = 1}):Play()
		end
	end
	fade:Play()
	fade.Completed:Wait()
	for index, entry in ipairs(active) do
		if entry.card == card then
			table.remove(active, index)
			break
		end
	end
	card:Destroy()
end

local function showNotification(category, message)
	category = string.upper(tostring(category or "GENERAL"))
	if not COLORS[category] then category = "GENERAL" end
	message = tostring(message or "")
	if message == "" then return end

	nextId += 1
	local style = COLORS[category]
	local card = Instance.new("Frame")
	card.Name = "Notification_" .. tostring(nextId)
	card.Size = UDim2.new(1, 0, 0, 76)
	card.BackgroundColor3 = Color3.fromRGB(31, 34, 41)
	card.BackgroundTransparency = 0.04
	card.BorderSizePixel = 0
	card.ClipsDescendants = true
	card.LayoutOrder = nextId
	card.Parent = stack

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(91, 97, 109)
	stroke.Transparency = 0.58
	stroke.Thickness = 1
	stroke.Parent = card

	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.Size = UDim2.new(0, 5, 1, 0)
	accent.BackgroundColor3 = style.accent
	accent.BorderSizePixel = 0
	accent.Parent = card

	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Position = UDim2.fromOffset(18, 12)
	icon.Size = UDim2.fromOffset(20, 18)
	icon.Font = Enum.Font.GothamBold
	icon.Text = style.icon
	icon.TextColor3 = style.accent
	icon.TextSize = 15
	icon.Parent = card

	local title = Instance.new("TextLabel")
	title.Name = "Category"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(43, 10)
	title.Size = UDim2.new(1, -57, 0, 20)
	title.Font = Enum.Font.GothamBold
	title.Text = category
	title.TextColor3 = style.accent
	title.TextSize = 13
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = card

	local body = Instance.new("TextLabel")
	body.Name = "Message"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(18, 34)
	body.Size = UDim2.new(1, -34, 0, 32)
	body.Font = Enum.Font.GothamMedium
	body.Text = message
	body.TextColor3 = Color3.fromRGB(245, 246, 249)
	body.TextSize = 14
	body.TextWrapped = true
	body.TextTruncate = Enum.TextTruncate.AtEnd
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Center
	body.Parent = card

	card.Position = UDim2.fromOffset(28, 0)
	card.BackgroundTransparency = 1
	table.insert(active, {card = card})
	while #active > MAX_VISIBLE do
		local oldest = table.remove(active, 1)
		if oldest and oldest.card then oldest.card:Destroy() end
	end

	TweenService:Create(card, TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 0.04,
	}):Play()

	task.delay(DISPLAY_TIME, function()
		removeCard(card)
	end)
end

remote.OnClientEvent:Connect(showNotification)
