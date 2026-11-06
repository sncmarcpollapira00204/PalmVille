local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Economy = require(ServerScriptService:WaitForChild("PalmVilleEconomy"))

local STARTING_MONEY = 500
local AUTOSAVE_INTERVAL = 60
local SESSION_LOCK_SECONDS = 150
local LOAD_ATTEMPTS = 8
local SAVE_ATTEMPTS = 4
local MAX_MONEY = 2_000_000_000

-- Studio writes go to a separate test store, never the published game's live wallet store.
local DATASTORE_NAME = RunService:IsStudio()
	and "PalmVille_PlayerData_Test_v1"
	or "PalmVille_PlayerData_v1"

local STORE_OK, PlayerStore = pcall(function()
	return DataStoreService:GetDataStore(DATASTORE_NAME)
end)

if not STORE_OK then
	error("[PalmVille PlayerData] Could not initialize DataStore: " .. tostring(PlayerStore))
end

local SERVER_ID = game.JobId ~= "" and game.JobId or ("Studio-" .. HttpService:GenerateGUID(false))
local sessions = {}
local saving = {}
local shuttingDown = false
local random = Random.new()

local function integer(value, default, minimum, maximum)
	local number = tonumber(value)
	if not number or number ~= number or number == math.huge or number == -math.huge then
		return default
	end
	return math.clamp(math.floor(number), minimum, maximum)
end

local function dayStamp()
	return os.date("!%Y-%m-%d", os.time() + 8 * 60 * 60)
end

local function defaultProfile()
	return {
		schemaVersion = 1,
		money = STARTING_MONEY,
		level = 1,
		xp = 0,
		xpNeeded = 100,
		seeds = {},
		inventory = {},
		farm = {
			plots = {},
		},
		statistics = {
			totalEarned = 0,
			earnedToday = 0,
			earningsDay = dayStamp(),
			totalSpent = 0,
			totalXP = 0,
			totalHarvests = 0,
			totalPlaytimeSeconds = 0,
		},
		createdAt = os.time(),
		lastSeenAt = os.time(),
		lastSavedAt = 0,
	}
end

local function copySerializable(value, depth)
	depth = depth or 0
	if depth > 8 then return nil end

	local valueType = typeof(value)
	if valueType == "string" or valueType == "boolean" then
		return value
	end
	if valueType == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			return nil
		end
		return value
	end
	if valueType ~= "table" then
		return nil
	end

	local copy = {}
	for key, child in pairs(value) do
		local keyType = typeof(key)
		if keyType == "string" or keyType == "number" then
			local childCopy = copySerializable(child, depth + 1)
			if childCopy ~= nil then
				copy[key] = childCopy
			end
		end
	end
	return copy
end

local function sanitizeProfile(raw)
	local data = defaultProfile()
	if type(raw) ~= "table" then
		return data
	end

	data.schemaVersion = 1
	data.money = integer(raw.money, STARTING_MONEY, 0, MAX_MONEY)
	data.level = integer(raw.level, 1, 1, 10000)
	data.xp = integer(raw.xp, 0, 0, MAX_MONEY)
	data.xpNeeded = integer(raw.xpNeeded, 100, 100, 1_000_000)

	data.seeds = type(raw.seeds) == "table" and (copySerializable(raw.seeds) or {}) or {}
	data.inventory = type(raw.inventory) == "table" and (copySerializable(raw.inventory) or {}) or {}

	if type(raw.farm) == "table" then
		data.farm = copySerializable(raw.farm) or {plots = {}}
	end
	if type(data.farm.plots) ~= "table" then
		data.farm.plots = {}
	end

	if type(raw.statistics) == "table" then
		local stats = raw.statistics
		data.statistics.totalEarned = integer(stats.totalEarned, 0, 0, MAX_MONEY)
		data.statistics.earnedToday = integer(stats.earnedToday, 0, 0, MAX_MONEY)
		data.statistics.earningsDay = type(stats.earningsDay) == "string" and stats.earningsDay or dayStamp()
		data.statistics.totalSpent = integer(stats.totalSpent, 0, 0, MAX_MONEY)
		data.statistics.totalXP = integer(stats.totalXP, 0, 0, MAX_MONEY)
		data.statistics.totalHarvests = integer(stats.totalHarvests, 0, 0, MAX_MONEY)
		data.statistics.totalPlaytimeSeconds = integer(stats.totalPlaytimeSeconds, 0, 0, MAX_MONEY)
	end

	if data.statistics.earningsDay ~= dayStamp() then
		data.statistics.earningsDay = dayStamp()
		data.statistics.earnedToday = 0
	end

	data.createdAt = integer(raw.createdAt, os.time(), 0, MAX_MONEY)
	data.lastSeenAt = os.time()
	data.lastSavedAt = integer(raw.lastSavedAt, 0, 0, MAX_MONEY)

	return data
end

local function keyFor(player)
	return "Player_" .. tostring(player.UserId)
end

local function releaseUnattachedLock(key, token)
	pcall(function()
		PlayerStore:UpdateAsync(key, function(current)
			if type(current) ~= "table" then return nil end
			local lock = current._sessionLock
			if type(lock) ~= "table" or lock.token ~= token then
				return nil
			end
			current._sessionLock = nil
			return current
		end)
	end)
end

local function acquireProfile(player, token)
	local key = keyFor(player)
	local lastError
	local sawActiveSession = false

	for attempt = 1, LOAD_ATTEMPTS do
		local lockConflict = false
		local ok, result = pcall(function()
			return PlayerStore:UpdateAsync(key, function(current)
				local now = os.time()
				if type(current) == "table" and type(current._sessionLock) == "table" then
					local lock = current._sessionLock
					local expiresAt = tonumber(lock.expiresAt) or 0
					if lock.token ~= token and expiresAt > now then
						lockConflict = true
						return nil
					end
				end

				local nextData = sanitizeProfile(current)
				nextData._sessionLock = {
					token = token,
					serverId = SERVER_ID,
					placeId = game.PlaceId,
					expiresAt = now + SESSION_LOCK_SECONDS,
				}
				return nextData
			end)
		end)

		if ok and type(result) == "table"
			and type(result._sessionLock) == "table"
			and result._sessionLock.token == token then
			return sanitizeProfile(result), nil
		end

		if lockConflict then
			sawActiveSession = true
		elseif not ok then
			lastError = result
			warn(string.format(
				"[PalmVille PlayerData] Load attempt %d/%d failed for %s: %s",
				attempt,
				LOAD_ATTEMPTS,
				player.Name,
				tostring(result)
			))
		end

		if attempt < LOAD_ATTEMPTS then
			local delaySeconds = lockConflict and 4 or math.min(2 ^ (attempt - 1), 8)
			task.wait(delaySeconds + random:NextNumber(0, 0.6))
		end
	end

	if sawActiveSession then
		return nil, "Your data is still active on another server. Please wait a little and rejoin."
	end
	return nil, "Your data could not be loaded. Please rejoin. " .. tostring(lastError or "")
end

local function getOrCreateValue(parent, className, name, value)
	local object = parent:FindFirstChild(name)
	if object and not object:IsA(className) then
		object:Destroy()
		object = nil
	end
	if not object then
		object = Instance.new(className)
		object.Name = name
		object.Parent = parent
	end
	object.Value = value
	return object
end

local function attachLeaderstats(player, data)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local moneyValue = getOrCreateValue(leaderstats, "IntValue", "Money", data.money)
	local levelValue = getOrCreateValue(leaderstats, "IntValue", "Level", data.level)

	Economy.RegisterProfile(player, data, moneyValue, levelValue)
	player:SetAttribute("PalmVilleDataLoaded", true)
	player:SetAttribute("PalmVilleDataVersion", 1)
end

local function loadPlayer(player)
	if player.Parent ~= Players or shuttingDown then return end

	local token = HttpService:GenerateGUID(false)
	local data, loadError = acquireProfile(player, token)
	if not data then
		warn(string.format("[PalmVille PlayerData] Refusing to create an unsaved profile for %s: %s", player.Name, tostring(loadError)))
		if player.Parent == Players then
			player:Kick("PalmVille couldn't load your saved data. Your progress was protected. Please rejoin.")
		end
		return
	end

	if player.Parent ~= Players then
		releaseUnattachedLock(keyFor(player), token)
		return
	end

	sessions[player] = {
		token = token,
		startedAt = os.clock(),
	}
	attachLeaderstats(player, data)

	print(string.format(
		"[PalmVille PlayerData] Loaded %s | Money: ₱%d | Level: %d | Store: %s",
		player.Name,
		data.money,
		data.level,
		DATASTORE_NAME
	))
end

local function snapshotProfile(player, session)
	local data = Economy.GetProfile(player)
	if not data then return nil end

	local elapsed = math.max(0, math.floor(os.clock() - session.startedAt))
	data.statistics = type(data.statistics) == "table" and data.statistics or {}
	data.statistics.totalPlaytimeSeconds = integer(
		data.statistics.totalPlaytimeSeconds,
		0,
		0,
		MAX_MONEY
	) + elapsed
	session.startedAt = os.clock()

	local snapshot = sanitizeProfile(data)
	snapshot.lastSavedAt = os.time()
	return snapshot
end

local function savePlayer(player, releaseLock)
	local session = sessions[player]
	if not session then return false, "No active profile session." end

	while saving[player] do
		task.wait(0.05)
	end
	saving[player] = true

	local key = keyFor(player)
	local payload = snapshotProfile(player, session)
	if not payload then
		saving[player] = nil
		return false, "Profile is not available."
	end

	local lastError
	local saved = false

	for attempt = 1, SAVE_ATTEMPTS do
		local ok, result = pcall(function()
			return PlayerStore:UpdateAsync(key, function(current)
				if type(current) ~= "table" then
					return nil
				end

				local lock = current._sessionLock
				if type(lock) ~= "table" or lock.token ~= session.token then
					return nil
				end

				local nextData = copySerializable(payload)
				if not releaseLock then
					nextData._sessionLock = {
						token = session.token,
						serverId = SERVER_ID,
						placeId = game.PlaceId,
						expiresAt = os.time() + SESSION_LOCK_SECONDS,
					}
				end
				return nextData
			end)
		end)

		local lockOkay = releaseLock
			and ok
			and type(result) == "table"
			and result._sessionLock == nil

		local refreshOkay = not releaseLock
			and ok
			and type(result) == "table"
			and type(result._sessionLock) == "table"
			and result._sessionLock.token == session.token

		if lockOkay or refreshOkay then
			saved = true
			break
		end

		if not ok then
			lastError = result
		else
			lastError = "Session lock was missing or owned by another server."
		end

		if attempt < SAVE_ATTEMPTS then
			task.wait(math.min(2 ^ (attempt - 1), 8) + random:NextNumber(0, 0.5))
		end
	end

	saving[player] = nil

	if saved then
		if releaseLock then
			Economy.UnregisterProfile(player)
			sessions[player] = nil
			player:SetAttribute("PalmVilleDataLoaded", false)
		end
		return true
	end

	warn(string.format("[PalmVille PlayerData] Save failed for %s: %s", player.Name, tostring(lastError)))
	return false, lastError
end

local adminAdapter = ServerScriptService:FindFirstChild("PalmVilleAdminPlayerData")
if adminAdapter and not adminAdapter:IsA("BindableFunction") then
	warn("[PalmVille PlayerData] PalmVilleAdminPlayerData exists but is not a BindableFunction.")
	adminAdapter = nil
end
if not adminAdapter then
	adminAdapter = Instance.new("BindableFunction")
	adminAdapter.Name = "PalmVilleAdminPlayerData"
	adminAdapter.Parent = ServerScriptService
end

adminAdapter.OnInvoke = function(player)
	if not player or not player:IsA("Player") then return nil end
	local data = Economy.GetProfile(player)
	if not data then return nil end

	local stats = data.statistics or {}
	return {
		money = data.money,
		earnedToday = stats.earnedToday or 0,
		level = data.level,
		xp = data.xp,
		xpNeeded = data.xpNeeded,
		totalPlaytime = stats.totalPlaytimeSeconds or 0,
	}
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(loadPlayer, player)
end)

Players.PlayerRemoving:Connect(function(player)
	if sessions[player] then
		savePlayer(player, true)
	end
	Economy.UnregisterProfile(player)
	sessions[player] = nil
	player:SetAttribute("PalmVilleDataLoaded", false)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(loadPlayer, player)
end

task.spawn(function()
	task.wait(random:NextNumber(8, 22))
	while not shuttingDown do
		task.wait(AUTOSAVE_INTERVAL)
		for _, player in ipairs(Players:GetPlayers()) do
			if sessions[player] then
				task.spawn(savePlayer, player, false)
			end
			task.wait(0.2)
		end
	end
end)

game:BindToClose(function()
	shuttingDown = true
	local pending = 0

	for _, player in ipairs(Players:GetPlayers()) do
		if sessions[player] then
			pending += 1
			task.spawn(function()
				savePlayer(player, true)
				pending -= 1
			end)
		end
	end

	local started = os.clock()
	while pending > 0 and os.clock() - started < 25 do
		task.wait(0.1)
	end
end)

print(string.format(
	"[PalmVille PlayerData] Ready. Store: %s | Autosave: %ds | Starting Money: ₱%d",
	DATASTORE_NAME,
	AUTOSAVE_INTERVAL,
	STARTING_MONEY
))
