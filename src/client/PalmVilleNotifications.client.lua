local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("PalmVilleNotificationEvent")

-- All notification types share one blue PalmVille design.
-- WARNING is the only type with a distinct amber accent and warning icon.
local STANDARD_STYLE = {accent = Color3.fromRGB(126, 190, 245), icon = "♡"}
local WARNING_STYLE = {accent = Color3.fromRGB(245, 202, 112), icon = "⚠"}
local CATEGORIES = {GENERAL = true, INFO = true, SUCCESS = true, ERROR = true, WARNING = true}
local CARD_COLOR = Color3.fromRGB(29, 36, 49)
local CHIP_COLOR = Color3.fromRGB(48, 58, 75)
local ICON_BUBBLE_COLOR = Color3.fromRGB(48, 58, 75)
local MESSAGE_COLOR = Color3.fromRGB(245, 247, 250)

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
stack.Position = UDim2.new(1, -24, 1, -24)
stack.Size = UDim2.new(0, 320, 1, -40)
stack.BackgroundTransparency = 1
stack.Parent = gui

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Vertical
layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 10)
layout.Parent = stack

local active = {}
local nextId = 0
local MAX_VISIBLE = 3
local DISPLAY_TIME = 4.5

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
	if not CATEGORIES[category] then category = "GENERAL" end
	message = tostring(message or "")
	if message == "" then return end

	nextId += 1
	local style = category == "WARNING" and WARNING_STYLE or STANDARD_STYLE
	local card = Instance.new("Frame")
	card.Name = "Notification_" .. tostring(nextId)
	card.Size = UDim2.new(1, 0, 0, 78)
	card.BackgroundColor3 = CARD_COLOR
	card.BackgroundTransparency = 0.06
	card.BorderSizePixel = 0
	card.ClipsDescendants = true
	card.LayoutOrder = nextId
	card.Parent = stack

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = style.accent
	stroke.Transparency = 0.62
	stroke.Thickness = 1
	stroke.Parent = card

	local iconBubble = Instance.new("Frame")
	iconBubble.Name = "IconBubble"
	iconBubble.Position = UDim2.fromOffset(14, 22)
	iconBubble.Size = UDim2.fromOffset(34, 34)
	iconBubble.BackgroundColor3 = ICON_BUBBLE_COLOR
	iconBubble.BorderSizePixel = 0
	iconBubble.Parent = card
	local bubbleCorner = Instance.new("UICorner")
	bubbleCorner.CornerRadius = UDim.new(1, 0)
	bubbleCorner.Parent = iconBubble

	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromScale(1, 1)
	icon.Font = Enum.Font.Nunito
	icon.Text = style.icon
	icon.TextColor3 = style.accent
	icon.TextSize = 18
	icon.Parent = iconBubble

	local title = Instance.new("TextLabel")
	title.Name = "Category"
	title.Position = UDim2.fromOffset(58, 9)
	title.Size = UDim2.fromOffset(category == "GENERAL" and 82 or (category == "SUCCESS" and 74 or 78), 20)
	title.BackgroundColor3 = CHIP_COLOR
	title.BorderSizePixel = 0
	title.Font = Enum.Font.Nunito
	title.Text = category
	title.TextColor3 = style.accent
	title.TextSize = 11
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Parent = card
	local titleCorner = Instance.new("UICorner")
	titleCorner.CornerRadius = UDim.new(1, 0)
	titleCorner.Parent = title

	local body = Instance.new("TextLabel")
	body.Name = "Message"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(58, 32)
	body.Size = UDim2.new(1, -72, 0, 38)
	body.Font = Enum.Font.Nunito
	body.Text = message
	body.TextColor3 = MESSAGE_COLOR
	body.TextSize = 15
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
		BackgroundTransparency = 0.06,
	}):Play()

	task.delay(DISPLAY_TIME, function()
		removeCard(card)
	end)
end

remote.OnClientEvent:Connect(showNotification)
