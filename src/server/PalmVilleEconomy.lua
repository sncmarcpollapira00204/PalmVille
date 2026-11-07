local Economy = {}

local MAX_MONEY = 2_000_000_000
local profiles = {}
local ServerScriptService = game:GetService("ServerScriptService")
local auditEvent = ServerScriptService:FindFirstChild("PalmVilleAuditEvent")
if not auditEvent then
	auditEvent = Instance.new("BindableEvent")
	auditEvent.Name = "PalmVilleAuditEvent"
	auditEvent.Parent = ServerScriptService
end

local function emitAudit(player, action, amount, balance, reason)
	auditEvent:Fire(action, player, {
		amount = amount,
		balance = balance,
		reason = tostring(reason or action):sub(1, 80),
	})
end

local function toInteger(value, minimum, maximum)
	local number = tonumber(value)
	if not number or number ~= number or number == math.huge or number == -math.huge then
		return nil
	end
	return math.clamp(math.floor(number), minimum, maximum)
end

local function dayStamp()
	return os.date("!%Y-%m-%d", os.time() + 8 * 60 * 60)
end

local function getEntry(player)
	return profiles[player]
end

local function updateValue(valueObject, value)
	if valueObject and valueObject.Parent then
		valueObject.Value = value
	end
end

function Economy.RegisterProfile(player, data, moneyValue, levelValue)
	assert(player and player:IsA("Player"), "RegisterProfile requires a Player")
	assert(type(data) == "table", "RegisterProfile requires profile data")
	assert(moneyValue and moneyValue:IsA("IntValue"), "RegisterProfile requires an IntValue for Money")

	local oldEntry = profiles[player]
	if oldEntry then
		for _, connection in ipairs(oldEntry.connections) do
			connection:Disconnect()
		end
	end

	local entry = {
		data = data,
		moneyValue = moneyValue,
		levelValue = levelValue,
		connections = {},
	}
	profiles[player] = entry

	table.insert(entry.connections, moneyValue:GetPropertyChangedSignal("Value"):Connect(function()
		if profiles[player] ~= entry then return end
		local normalized = toInteger(moneyValue.Value, 0, MAX_MONEY) or 0
		if moneyValue.Value ~= normalized then
			moneyValue.Value = normalized
		end
		data.money = normalized
	end))

	if levelValue then
		table.insert(entry.connections, levelValue:GetPropertyChangedSignal("Value"):Connect(function()
			if profiles[player] ~= entry then return end
			local normalized = toInteger(levelValue.Value, 1, 10000) or 1
			if levelValue.Value ~= normalized then
				levelValue.Value = normalized
			end
			data.level = normalized
		end))
	end

	data.money = toInteger(data.money, 0, MAX_MONEY) or 0
	data.level = toInteger(data.level, 1, 10000) or 1
	updateValue(moneyValue, data.money)
	updateValue(levelValue, data.level)

	return true
end

function Economy.IsLoaded(player)
	return profiles[player] ~= nil
end

function Economy.GetProfile(player)
	local entry = getEntry(player)
	return entry and entry.data or nil
end

function Economy.GetMoney(player)
	local entry = getEntry(player)
	if not entry then return nil end
	return toInteger(entry.moneyValue.Value, 0, MAX_MONEY) or 0
end

function Economy.AddMoney(player, amount, reason)
	local entry = getEntry(player)
	if not entry then
		return false, "Player profile is not loaded."
	end

	local value = toInteger(amount, 1, MAX_MONEY)
	if not value then
		return false, "Money amount must be a positive whole number."
	end

	local current = toInteger(entry.moneyValue.Value, 0, MAX_MONEY) or 0
	if current > MAX_MONEY - value then
		return false, "Money balance limit reached."
	end

	local nextBalance = current + value
	entry.data.money = nextBalance

	local stats = entry.data.statistics
	if type(stats) == "table" then
		local today = dayStamp()
		if stats.earningsDay ~= today then
			stats.earningsDay = today
			stats.earnedToday = 0
		end
		stats.totalEarned = (toInteger(stats.totalEarned, 0, MAX_MONEY) or 0) + value
		stats.earnedToday = (toInteger(stats.earnedToday, 0, MAX_MONEY) or 0) + value
		stats.lastMoneyReason = tostring(reason or "Unknown"):sub(1, 40)
	end

	updateValue(entry.moneyValue, nextBalance)
	emitAudit(player, "Currency Earned", value, nextBalance, reason or "AddMoney")
	return true, nextBalance
end

function Economy.SpendMoney(player, amount, reason)
	local entry = getEntry(player)
	if not entry then
		return false, "Player profile is not loaded."
	end

	local value = toInteger(amount, 1, MAX_MONEY)
	if not value then
		return false, "Money amount must be a positive whole number."
	end

	local current = toInteger(entry.moneyValue.Value, 0, MAX_MONEY) or 0
	if current < value then
		return false, "Not enough Money."
	end

	local nextBalance = current - value
	entry.data.money = nextBalance

	local stats = entry.data.statistics
	if type(stats) == "table" then
		stats.totalSpent = (toInteger(stats.totalSpent, 0, MAX_MONEY) or 0) + value
		stats.lastMoneyReason = tostring(reason or "Purchase"):sub(1, 40)
	end

	updateValue(entry.moneyValue, nextBalance)
	emitAudit(player, "Currency Spent", -value, nextBalance, reason or "Purchase")
	return true, nextBalance
end

function Economy.SetMoney(player, amount, reason)
	local entry = getEntry(player)
	if not entry then
		return false, "Player profile is not loaded."
	end

	local value = toInteger(amount, 0, MAX_MONEY)
	if not value then
		return false, "Money must be a non-negative whole number."
	end

	entry.data.money = value
	if type(entry.data.statistics) == "table" then
		entry.data.statistics.lastMoneyReason = tostring(reason or "SetMoney"):sub(1, 40)
	end
	local previous = toInteger(entry.moneyValue.Value, 0, MAX_MONEY) or 0
	updateValue(entry.moneyValue, value)
	emitAudit(player, "Currency Adjusted", value - previous, value, reason or "SetMoney")
	return true, value
end

function Economy.AddXP(player, amount)
	local entry = getEntry(player)
	if not entry then
		return false, "Player profile is not loaded."
	end

	local value = toInteger(amount, 1, 1_000_000)
	if not value then
		return false, "XP amount must be a positive whole number."
	end

	local data = entry.data
	data.xp = (toInteger(data.xp, 0, 2_000_000_000) or 0) + value
	data.statistics = type(data.statistics) == "table" and data.statistics or {}
	data.statistics.totalXP = (toInteger(data.statistics.totalXP, 0, 2_000_000_000) or 0) + value

	local levelsGained = 0
	while data.xp >= (toInteger(data.xpNeeded, 100, 1_000_000) or 100) do
		data.xp -= data.xpNeeded
		data.level = math.min((toInteger(data.level, 1, 10000) or 1) + 1, 10000)
		data.xpNeeded = math.min(100 + (data.level - 1) * 25, 1_000_000)
		levelsGained += 1
	end

	updateValue(entry.levelValue, data.level)
	emitAudit(player, "XP Earned", value, data.xp, "Experience")
	return true, {
		level = data.level,
		xp = data.xp,
		xpNeeded = data.xpNeeded,
		levelsGained = levelsGained,
	}
end

function Economy.UnregisterProfile(player)
	local entry = profiles[player]
	if not entry then return end

	for _, connection in ipairs(entry.connections) do
		connection:Disconnect()
	end
	profiles[player] = nil
end

return Economy
