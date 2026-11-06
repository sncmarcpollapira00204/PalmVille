local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local oldGui = playerGui:FindFirstChild("PalmVilleCashHUD")
if oldGui then
	oldGui:Destroy()
end

local function make(className, properties, parent)
	local object = Instance.new(className)
	for key, value in pairs(properties) do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function formatMoney(value)
	value = math.max(0, math.floor(tonumber(value) or 0))
	local formatted = tostring(value)
	while true do
		local changed
		formatted, changed = formatted:gsub("^(%d+)(%d%d%d)", "%1,%2")
		if changed == 0 then break end
	end
	return formatted
end

local gui = make("ScreenGui", {
	Name = "PalmVilleCashHUD",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 25,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

local holder = make("Frame", {
	Name = "CashPanel",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 24, 1, UserInputService.TouchEnabled and -190 or -30),
	Size = UDim2.fromOffset(218, 66),
	BackgroundColor3 = Color3.fromRGB(11, 34, 23),
	BackgroundTransparency = 0.06,
	BorderSizePixel = 0,
}, gui)

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 16)
corner.Parent = holder

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(204, 170, 91)
stroke.Thickness = 1.5
stroke.Transparency = 0.08
stroke.Parent = holder

local coin = make("Frame", {
	Name = "CoinIcon",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 11, 0.5, 0),
	Size = UDim2.fromOffset(46, 46),
	BackgroundColor3 = Color3.fromRGB(238, 174, 44),
	BorderSizePixel = 0,
}, holder)

local coinCorner = Instance.new("UICorner")
coinCorner.CornerRadius = UDim.new(1, 0)
coinCorner.Parent = coin

local coinStroke = Instance.new("UIStroke")
coinStroke.Color = Color3.fromRGB(255, 225, 130)
coinStroke.Thickness = 2
coinStroke.Parent = coin

make("TextLabel", {
	Name = "CurrencySymbol",
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Text = "₱",
	Font = Enum.Font.GothamBlack,
	TextSize = 27,
	TextColor3 = Color3.fromRGB(255, 249, 218),
	TextStrokeColor3 = Color3.fromRGB(143, 83, 16),
	TextStrokeTransparency = 0.25,
}, coin)

make("TextLabel", {
	Name = "CashCaption",
	Position = UDim2.fromOffset(68, 9),
	Size = UDim2.new(1, -78, 0, 17),
	BackgroundTransparency = 1,
	Text = "CASH BALANCE",
	Font = Enum.Font.GothamBold,
	TextSize = 10,
	TextColor3 = Color3.fromRGB(194, 190, 158),
	TextXAlignment = Enum.TextXAlignment.Left,
}, holder)

local balanceLabel = make("TextLabel", {
	Name = "CashAmount",
	Position = UDim2.fromOffset(67, 26),
	Size = UDim2.new(1, -77, 0, 29),
	BackgroundTransparency = 1,
	Text = "Loading...",
	Font = Enum.Font.GothamBold,
	TextSize = 22,
	TextColor3 = Color3.fromRGB(255, 240, 190),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
}, holder)

local moneyConnection

local function showLoadedBalance()
	if moneyConnection then
		moneyConnection:Disconnect()
		moneyConnection = nil
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local money = leaderstats and leaderstats:FindFirstChild("Money")

	if money and (money:IsA("IntValue") or money:IsA("NumberValue")) then
		balanceLabel.Text = "₱" .. formatMoney(money.Value)
		balanceLabel.TextColor3 = Color3.fromRGB(255, 240, 190)
		moneyConnection = money:GetPropertyChangedSignal("Value"):Connect(function()
			balanceLabel.Text = "₱" .. formatMoney(money.Value)
		end)
		return true
	end

	return false
end

local function bindMoney()
	if not player:GetAttribute("PalmVilleDataLoaded") then
		balanceLabel.Text = "Loading..."
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local money = leaderstats and leaderstats:FindFirstChild("Money")
	if money and (money:IsA("IntValue") or money:IsA("NumberValue")) then
		showLoadedBalance()
	else
		balanceLabel.Text = "Unavailable"
		balanceLabel.TextColor3 = Color3.fromRGB(255, 145, 125)
		warn("[PalmVille Cash HUD] Data loaded, but leaderstats.Money is missing.")
	end
end

player:GetAttributeChangedSignal("PalmVilleDataLoaded"):Connect(bindMoney)

player.ChildAdded:Connect(function(child)
	if child.Name == "leaderstats" then
		task.defer(bindMoney)
		child.ChildAdded:Connect(function(value)
			if value.Name == "Money" then
				task.defer(bindMoney)
			end
		end)
	end
end)

task.spawn(function()
	for _ = 1, 40 do
		if player:GetAttribute("PalmVilleDataLoaded") then
			bindMoney()
			return
		end
		task.wait(0.25)
	end
	if balanceLabel.Text == "Loading..." then
		balanceLabel.Text = "Waiting for data"
	end
end)
