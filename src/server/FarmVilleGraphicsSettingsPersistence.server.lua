local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local REMOTE_NAME = "FarmVilleGraphicsSettingsRemote"
local STORE_NAME = "FarmVilleGraphicsSettings_v1"
local SAVE_COOLDOWN = 1

local remote = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
if remote and not remote:IsA("RemoteFunction") then
	return
end
if not remote then
	remote = Instance.new("RemoteFunction")
	remote.Name = REMOTE_NAME
	remote.Parent = ReplicatedStorage
end

local store = DataStoreService:GetDataStore(STORE_NAME)
local cached = {}
local lastSaveAt = {}

Players.PlayerRemoving:Connect(function(player)
	cached[player.UserId] = nil
	lastSaveAt[player.UserId] = nil
end)

local function validNumber(value)
	return typeof(value) == "number"
		and value == value
		and value > -math.huge
		and value < math.huge
end

local function sanitizePosition(value)
	if typeof(value) ~= "table" or not validNumber(value.x) or not validNumber(value.y) then
		return nil
	end
	return {
		x = math.clamp(value.x, 0, 1),
		y = math.clamp(value.y, 0, 1),
	}
end

local function sanitizeSettings(value)
	if typeof(value) ~= "table" then
		return nil
	end
	local button = sanitizePosition(value.button)
	local panel = sanitizePosition(value.panel)
	if not button or not panel then
		return nil
	end
	return {button = button, panel = panel}
end

local function copySettings(value)
	return {
		button = {x = value.button.x, y = value.button.y},
		panel = {x = value.panel.x, y = value.panel.y},
	}
end

remote.OnServerInvoke = function(player, action, value)
	local key = "Player_" .. tostring(player.UserId)
	if action == "Load" then
		if RunService:IsStudio() then
			return nil
		end
		if cached[player.UserId] then
			return copySettings(cached[player.UserId])
		end
		local ok, saved = pcall(function()
			return store:GetAsync(key)
		end)
		if not ok then
			return nil
		end
		local clean = sanitizeSettings(saved)
		if clean then
			cached[player.UserId] = clean
			return copySettings(clean)
		end
		return nil
	end

	if action ~= "Save" then
		return {ok = false, disabled = true}
	end
	if RunService:IsStudio() then
		return {ok = false, disabled = true}
	end
	local now = os.clock()
	local elapsed = now - (lastSaveAt[player.UserId] or 0)
	if elapsed < SAVE_COOLDOWN then
		return {ok = false, retryAfter = SAVE_COOLDOWN - elapsed}
	end
	local clean = sanitizeSettings(value)
	if not clean then
		return {ok = false, disabled = true}
	end
	lastSaveAt[player.UserId] = now
	local ok = pcall(function()
		store:UpdateAsync(key, function()
			return clean
		end)
	end)
	if not ok then
		return {ok = false, retryAfter = SAVE_COOLDOWN + 0.1}
	end
	cached[player.UserId] = clean
	return {ok = true}
end

