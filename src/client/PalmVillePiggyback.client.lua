local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("PalmVillePiggybackEvent")

local gui = Instance.new("ScreenGui")
gui.Name = "PalmVillePiggybackGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 40
gui.Parent = player:WaitForChild("PlayerGui")

local toast = Instance.new("TextLabel")
toast.Name = "PiggybackNotice"
toast.AnchorPoint = Vector2.new(0.5, 1)
toast.Position = UDim2.new(0.5, 0, 1, -34)
toast.Size = UDim2.new(0.8, 0, 0, 42)
toast.BackgroundColor3 = Color3.fromRGB(27, 29, 35)
toast.BackgroundTransparency = 0.08
toast.BorderSizePixel = 0
toast.Font = Enum.Font.GothamMedium
toast.TextSize = 14
toast.TextColor3 = Color3.fromRGB(245, 245, 248)
toast.TextWrapped = true
toast.Visible = false
toast.Parent = gui
local toastCorner = Instance.new("UICorner")
toastCorner.CornerRadius = UDim.new(0, 10)
toastCorner.Parent = toast
local toastStroke = Instance.new("UIStroke")
toastStroke.Color = Color3.fromRGB(95, 101, 116)
toastStroke.Transparency = 0.55
toastStroke.Parent = toast

local card = Instance.new("Frame")
card.Name = "PiggybackRequest"
card.AnchorPoint = Vector2.new(0.5, 1)
card.Position = UDim2.new(0.5, 0, 1, -92)
card.Size = UDim2.new(0.86, 0, 0, 156)
card.BackgroundColor3 = Color3.fromRGB(25, 27, 33)
card.BorderSizePixel = 0
card.Visible = false
card.Parent = gui
local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MinSize = Vector2.new(280, 156)
sizeLimit.MaxSize = Vector2.new(410, 156)
sizeLimit.Parent = card
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 16)
corner.Parent = card
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(105, 112, 130)
stroke.Transparency = 0.38
stroke.Thickness = 1.2
stroke.Parent = card

local heading = Instance.new("TextLabel")
heading.BackgroundTransparency = 1
heading.Position = UDim2.fromOffset(18, 14)
heading.Size = UDim2.new(1, -36, 0, 25)
heading.Font = Enum.Font.GothamBold
heading.Text = "PIGGYBACK REQUEST"
heading.TextSize = 17
heading.TextColor3 = Color3.fromRGB(255, 255, 255)
heading.TextXAlignment = Enum.TextXAlignment.Left
heading.Parent = card

local message = Instance.new("TextLabel")
message.BackgroundTransparency = 1
message.Position = UDim2.fromOffset(18, 43)
message.Size = UDim2.new(1, -36, 0, 38)
message.Font = Enum.Font.Gotham
message.Text = "A nearby player wants to give you a piggyback ride."
message.TextSize = 14
message.TextColor3 = Color3.fromRGB(198, 202, 212)
message.TextWrapped = true
message.TextXAlignment = Enum.TextXAlignment.Left
message.Parent = card

local function makeButton(name, caption, color, xScale)
	local button = Instance.new("TextButton")
	button.Name = name
	button.AnchorPoint = Vector2.new(xScale, 1)
	button.Position = UDim2.new(xScale == 0 and 0 or 1, xScale == 0 and 18 or -18, 1, -15)
	button.Size = UDim2.new(0.5, -25, 0, 42)
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Text = caption
	button.TextSize = 14
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Parent = card
	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 10)
	buttonCorner.Parent = button
	return button
end

local accept = makeButton("Accept", "ACCEPT", Color3.fromRGB(64, 155, 105), 0)
local decline = makeButton("Decline", "DECLINE", Color3.fromRGB(76, 79, 89), 1)

local activeRequestId
local activeRequesterId
local toastVersion = 0

local function showNotice(text)
	toastVersion += 1
	local version = toastVersion
	toast.Text = tostring(text)
	toast.Visible = true
	toast.TextTransparency = 0
	toast.BackgroundTransparency = 0.08
	task.delay(3.2, function()
		if toastVersion == version and toast.Parent then
			local fade = TweenService:Create(toast, TweenInfo.new(0.2), {TextTransparency = 1, BackgroundTransparency = 1})
			fade:Play()
			fade.Completed:Wait()
			if toastVersion == version then toast.Visible = false end
		end
	end)
end

local function respond(accepted)
	if not activeRequestId then return end
	remote:FireServer("Respond", activeRequesterId, accepted, activeRequestId)
	activeRequestId = nil
	activeRequesterId = nil
	card.Visible = false
end

accept.Activated:Connect(function() respond(true) end)
decline.Activated:Connect(function() respond(false) end)

remote.OnClientEvent:Connect(function(action, a, b, c)
	if action == "Request" then
		activeRequesterId = tonumber(a)
		activeRequestId = c
		message.Text = tostring(b) .. " wants to give you a piggyback ride."
		card.Visible = true
	elseif action == "Notice" then
		showNotice(a)
	end
end)
