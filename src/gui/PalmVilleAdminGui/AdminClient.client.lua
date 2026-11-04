local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Remote = ReplicatedStorage:WaitForChild("PalmVilleAdminRemote")

local OWNER_USERNAME = "lupiners0"
local isOwner = false
local selectedUserId = nil
local selectedName = nil
local flyEnabled = false
local flyConnection = nil
local flyVelocity = nil
local flyGyro = nil
local heldKeys = {}

local function make(className, props, parent)
	local object = Instance.new(className)
	for key, value in pairs(props or {}) do object[key] = value end
	object.Parent = parent
	return object
end

local function corner(object, radius)
	make("UICorner", {CornerRadius = UDim.new(0, radius or 12)}, object)
end

local function stroke(object, color, thickness, transparency)
	make("UIStroke", {Color = color, Thickness = thickness or 1, Transparency = transparency or 0}, object)
end

local C = {
	bg = Color3.fromRGB(8, 8, 11),
	panel = Color3.fromRGB(18, 18, 23),
	panel2 = Color3.fromRGB(24, 24, 31),
	panel3 = Color3.fromRGB(30, 30, 38),
	blue = Color3.fromRGB(255, 38, 138), -- hot-pink accent
	blue2 = Color3.fromRGB(34, 29, 38), -- dark action buttons
	red = Color3.fromRGB(255, 75, 90),
	red2 = Color3.fromRGB(112, 28, 42),
	text = Color3.fromRGB(247, 247, 250),
	muted = Color3.fromRGB(150, 150, 168),
	line = Color3.fromRGB(43, 43, 53),
	gold = Color3.fromRGB(255, 95, 164),
	green = Color3.fromRGB(70, 225, 125)
}

local gui = script.Parent
gui.Name = "PalmVilleAdminGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 80
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Owner-only launcher (hidden until the server grants access)
local launcher = make("TextButton", {
	Name = "AdminLauncher", Size = UDim2.fromOffset(132, 38),
	Position = UDim2.new(0, 18, 0, 90), BackgroundColor3 = C.panel2,
	Text = "♛  ADMIN PANEL", TextColor3 = C.text,
	Font = Enum.Font.GothamBold, TextSize = 13, Visible = false,
	AutoButtonColor = true
}, gui)
corner(launcher, 11); stroke(launcher, C.blue, 1.5, 0.15)

local panel = make("Frame", {
	Name = "MainPanel", AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(930, 570),
	BackgroundColor3 = C.bg, Visible = false, ClipsDescendants = true
}, gui)
corner(panel, 20); stroke(panel, C.line, 2, 0)
make("UISizeConstraint", {MinSize = Vector2.new(700, 500), MaxSize = Vector2.new(1240, 820)}, panel)

local header = make("Frame", {
	Name = "Header", Size = UDim2.new(1, 0, 0, 76),
	BackgroundColor3 = C.panel, BorderSizePixel = 0, Active = true
}, panel)
make("Frame", {Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -2), BackgroundColor3 = C.line, BorderSizePixel = 0}, header)

local brand = make("TextLabel", {
	BackgroundTransparency = 1, Position = UDim2.fromOffset(22, 10),
	Size = UDim2.fromOffset(168, 52), Text = "Palm Ville",
	TextColor3 = C.gold, Font = Enum.Font.FredokaOne, TextSize = 29,
	TextXAlignment = Enum.TextXAlignment.Left
}, header)
make("Frame", {Position = UDim2.fromOffset(190, 16), Size = UDim2.new(0, 2, 0, 43), BackgroundColor3 = C.line, BorderSizePixel = 0}, header)
make("TextLabel", {
	BackgroundTransparency = 1, Position = UDim2.fromOffset(210, 9),
	Size = UDim2.fromOffset(350, 33), Text = "♛  ADMIN PANEL",
	TextColor3 = C.text, Font = Enum.Font.GothamBlack, TextSize = 25,
	TextXAlignment = Enum.TextXAlignment.Left
}, header)
make("TextLabel", {
	BackgroundTransparency = 1, Position = UDim2.fromOffset(212, 42),
	Size = UDim2.fromOffset(300, 20), Text = "GAME ADMINISTRATION",
	TextColor3 = C.muted, Font = Enum.Font.GothamBold, TextSize = 11,