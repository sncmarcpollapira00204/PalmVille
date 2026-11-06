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

-- Upload the supplied transparent PNG to Roblox and paste its image asset ID here.
local COIN_IMAGE_ID = "rbxassetid://0"

local holder = make("Frame", {
	Name = "CashDisplay",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 18, 1, UserInputService.TouchEnabled and -184 or -22),
	Size = UDim2.fromOffset(250, 76),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
}, gui)

local coinImage = make("ImageLabel", {
	Name = "CashCoinImage",
	Position = UDim2.fromOffset(0, 2),
	Size = UDim2.fromOffset(104, 69),
	BackgroundTransparency = 1,
	Image = COIN_IMAGE_ID,
	ImageTransparency = 0,
	ScaleType = Enum.ScaleType.Fit,
	BorderSizePixel = 0,
}, holder)

local balanceLabel = make("TextLabel", {
	Name = "CashAmount",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 105, 0.5, 0),
	Size = UDim2.new(1, -110, 0, 48),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Text = "Loading...",
	Font = Enum.Font.GothamBlack,
	TextSize = 25,
	TextColor3 = Color3.fromRGB(255, 244, 207),
	TextStrokeColor3 = Color3.fromRGB(77, 43, 12),
	TextStrokeTransparency = 0.22,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Center,
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
		balanceLabel.Text = formatMoney(money.Value)
		balanceLabel.TextColor3 = Color3.fromRGB(255, 240, 190)
		moneyConnection = money:GetPropertyChangedSignal("Value"):Connect(function()
			balanceLabel.Text = formatMoney(money.Value)
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
