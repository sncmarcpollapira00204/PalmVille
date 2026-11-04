-- Add as a NEW Script named PalmVilleAnalyticsServer in ServerScriptService.
-- Keep PalmVilleAdminServerV2 and its role resolver. Install in every place/server.
-- Counts start at installation; visits mean tracked place joins (including repeat joins).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local DS = game:GetService("DataStoreService")
local MS = game:GetService("MemoryStoreService")
local Http = game:GetService("HttpService")
local Run = game:GetService("RunService")
-- Studio has no cross-server travel: keep temporary coordination in this test server.
-- Persisted test counters still use the existing _Test_v1 DataStore; live data is unchanged.
local testMaps = {}
local function coordinationMap(name)
	if not Run:IsStudio() then return MS:GetHashMap(name) end
	if testMaps[name] then return testMaps[name] end
	local values = {}
	local map = {}
	function map:GetAsync(key)
		local item = values[key]
		if item and item.expires > os.clock() then return item.value end
		values[key] = nil
		return nil
	end
	function map:SetAsync(key, value, expiration)
		values[key] = {value=value, expires=os.clock() + expiration}
	end
	function map:RemoveAsync(key) values[key] = nil end
	function map:UpdateAsync(key, transform, expiration)
		local result = transform(self:GetAsync(key))
		if result ~= nil then self:SetAsync(key, result, expiration) end
		return result
	end
	function map:ListItemsAsync(_pageSize)
		local items = {}
		for key in pairs(values) do
			local value = self:GetAsync(key)
			if value ~= nil then table.insert(items, {key=key, value=value}) end
		end
		return {IsFinished=true, GetCurrentPage=function()return items end}
	end
	testMaps[name] = map
	return map
end
local PREFIX = Run:IsStudio() and "PalmVilleOverview_Test_v1" or "PalmVilleOverview_v1"
local SHARDS = 64
local store = DS:GetDataStore(PREFIX)
local servers = coordinationMap(PREFIX .. "_servers")
local shared = coordinationMap(PREFIX .. "_shared")
local job = game.JobId ~= "" and game.JobId or Http:GenerateGUID(false)
if RS:FindFirstChild("PalmVilleOverviewAnalytics") then
	warn("PalmVille analytics: duplicate script detected; keep only one copy.")
	return
end
local remote = Instance.new("RemoteFunction")
remote.Name = "PalmVilleOverviewAnalytics"
remote.Parent = RS
local stopping = false
local pending = {}
local active = {}
local snapshot = {ready = false, message = "Collecting analytics..."}
local nextRequest = {}
local function dayKey(t)
	return os.date("!%Y-%m-%d", (t or os.time()) + 8 * 3600)
end
local function recentDays()
	local result = {}
	for offset = 6, 0, -1 do
		local t = os.time() - offset * 86400
		table.insert(result, {key = dayKey(t), label = os.date("!%b %d", t + 28800)})
	end
	return result
end
-- Atomic, idempotent per-user projection. Each shard keeps user totals plus eight daily records.
-- Monitor shard size if the game grows to millions of accounts; migrate/shard further before 4MB/key.
local function enqueue(userId, isJoin)
	local key = dayKey()
	table.insert(pending, {uid = tostring(userId), shard = userId % SHARDS,
		day = key, token = Http:GenerateGUID(false), visit = isJoin and 1 or 0,
		cutoff = dayKey(os.time() - 8 * 86400)})
end
local function flushOne(event)
	store:UpdateAsync("users_" .. event.shard, function(data)
		data = data or {users = {}}
		local user = data.users[event.uid] or {visits = 0, firstDay = event.day, days = {}, tokens = {}}
		if table.find(user.tokens, event.token) then return data end
		user.visits += event.visit
		user.days[event.day] = (user.days[event.day] or 0) + event.visit
		for date in pairs(user.days) do if date < event.cutoff then user.days[date] = nil end end
		table.insert(user.tokens, event.token)
		while #user.tokens > 16 do table.remove(user.tokens, 1) end
		data.users[event.uid] = user
		return data
	end)
end
local workerBusy = false
local function flushQueue(deadline)
	if workerBusy then return end
	workerBusy = true
	while #pending > 0 and (not deadline or os.clock() < deadline) do
		local event = pending[1]
		local ok, err = pcall(flushOne, event)
		if not ok then
			warn("PalmVille analytics: tracking write delayed: " .. tostring(err))
			break -- Retain the same token for retry; do not double-count ambiguous successful writes.
		end
		table.remove(pending, 1)
	end
	workerBusy = false
end
local function joined(player)
	if active[player] then return end
	active[player] = dayKey()
	enqueue(player.UserId, true)
end
Players.PlayerAdded:Connect(joined)
Players.PlayerRemoving:Connect(function(player) active[player] = nil; nextRequest[player] = nil end)
for _, player in ipairs(Players:GetPlayers()) do joined(player) end
-- Request endpoint uses the existing server-side admin authorization, never client-supplied roles.
remote.OnServerInvoke = function(player)
	local resolver = SSS:FindFirstChild("PalmVilleGetAdminRole")
	if not resolver or not resolver:IsA("BindableFunction") then return nil end
	local ok, role = pcall(function() return resolver:Invoke(player) end)
	if not ok or not role or role == "" then return nil end
	if os.clock() < (nextRequest[player] or 0) then return snapshot end
	nextRequest[player] = os.clock() + 10
	local result = table.clone(snapshot)
	local localCount = #Players:GetPlayers()
	if result.ready then
		result.online = math.max(result.online or 0, localCount)
		result.servers = math.max(result.servers or 0, localCount > 0 and 1 or 0)
	end
	return result
end
local function heartbeat()
	local ids = {}
	for _, player in ipairs(Players:GetPlayers()) do
		table.insert(ids, player.UserId)
		if active[player] ~= dayKey() then
			active[player] = dayKey()
			enqueue(player.UserId, false) -- Count overnight players as daily unique, without another visit.
		end
	end
	servers:SetAsync(job, {ids = ids, time = os.time()}, 60)
end
local function population()
	-- The map listing can lag its latest write. Count our live server directly,
	-- then merge other recent servers without counting this job twice.
	local users, count = {}, 0
	local localPlayers = Players:GetPlayers()
	if #localPlayers > 0 then count = 1 end
	for _, player in ipairs(localPlayers) do users[tostring(player.UserId)] = true end
	local pages = servers:ListItemsAsync(100)
	while true do
		for _, entry in ipairs(pages:GetCurrentPage()) do
			local value = entry.value
			if entry.key ~= job and value and os.time() - value.time <= 45 and #value.ids > 0 then
				count += 1
				for _, uid in ipairs(value.ids) do users[tostring(uid)] = true end
			end
		end
		if pages.IsFinished then break end
		pages:AdvanceToNextPageAsync()
	end
	local online = 0
	for _ in pairs(users) do online += 1 end
	return online, count
end
local function becomeLeader()
	local owner = shared:UpdateAsync("leader", function(old)
		if not old or old.job == job or old.untilTime <= os.time() then
			return {job = job, untilTime = os.time() + 45}
		end
		return old
	end, 60)
	return owner and owner.job == job
end
local totals, history, loadedAt = nil, nil, 0
local peakPending = {}
local function loadCounts()
	local dates = recentDays()
	local days = {}
	for _, d in ipairs(dates) do
		days[d.key] = {key = d.key, label = d.label, visits = 0, unique = 0, newPlayers = 0, peak = 0, hasData = false}
	end
	local result = {visits = 0, unique = 0}
	for shard = 0, SHARDS - 1 do
		local data = store:GetAsync("users_" .. shard)
		for _, user in pairs(data and data.users or {}) do
			result.visits += user.visits
			result.unique += 1
			for date, visits in pairs(user.days) do
				if days[date] then
					local d = days[date]
					d.hasData = true
					d.visits += visits
					d.unique += 1
					if user.firstDay == date then d.newPlayers += 1 end
				end
			end
		end
	end
	local rows = {}
	for _, d in ipairs(dates) do table.insert(rows, days[d.key]) end
	totals, history, loadedAt = result, rows, os.time()
end
local lastPeakSave = 0
local function publish()
	local online, serverCount = population()
	local today = dayKey()
	peakPending[today] = math.max(peakPending[today] or 0, online)
	if not totals or os.time() - loadedAt >= 60 or history[#history].key ~= today then loadCounts() end
	if os.time() - lastPeakSave >= 60 then
		-- Preserve sampled peaks across midnight and retry failed writes on the next cycle.
		local saved = store:UpdateAsync("peaks", function(data)
			data = data or {allTime = 0, days = {}}
			for date, peak in pairs(peakPending) do
				data.allTime = math.max(data.allTime, peak)
				data.days[date] = math.max(data.days[date] or 0, peak)
			end
			local cutoff = dayKey(os.time() - 8 * 86400)
			for date in pairs(data.days) do if date < cutoff then data.days[date] = nil end end
			return data
		end)
		lastPeakSave = os.time()
		shared:SetAsync("peaks", saved, 180)
	end
	local peaks = shared:GetAsync("peaks") or store:GetAsync("peaks") or {allTime = 0, days = {}}
	local rows = {}
	for _, d in ipairs(history) do
		local row = table.clone(d)
		row.peak = math.max(peaks.days[d.key] or 0, peakPending[d.key] or 0)
		row.hasData = row.hasData or row.peak > 0
		table.insert(rows, row)
	end
	local allPeak = math.max(peaks.allTime or 0, online)
	for _, peak in pairs(peakPending) do allPeak = math.max(allPeak, peak) end
	local data = {ready = true, online = online, servers = serverCount, visits = totals.visits,
		unique = totals.unique, peak = allPeak, days = rows, today = today,
		updatedAt = os.time(), countsUpdatedAt = loadedAt, studio = Run:IsStudio()}
	shared:SetAsync("snapshot", data, 180)
	snapshot = data
end
-- A single leased leader aggregates shards. Other servers reuse the shared snapshot.
task.spawn(function()
	while not stopping do
		flushQueue()
		task.wait(3)
	end
end)
task.spawn(function()
	local retryDelay = 15
	while not stopping do
		local ok, err = pcall(function()
			heartbeat()
			if becomeLeader() then publish() end
			local cached = shared:GetAsync("snapshot")
			if cached then snapshot = cached end
		end)
		if not ok then
			retryDelay = math.min(retryDelay * 2, 120)
			warn("PalmVille analytics: " .. tostring(err))
			if snapshot.ready then snapshot.message = "Update delayed" else snapshot.message = "Analytics temporarily unavailable. Retrying..." end
		else
			retryDelay = 15
			if snapshot.ready then snapshot.message = nil end
		end
		task.wait(retryDelay)
	end
end)
game:BindToClose(function()
	stopping = true
	local deadline = os.clock() + 24
	while workerBusy and os.clock() < deadline do task.wait(0.1) end
	flushQueue(deadline)
	pcall(function()
		if next(peakPending) then
			store:UpdateAsync("peaks", function(data)
				data = data or {allTime = 0, days = {}}
				for date, peak in pairs(peakPending) do
					data.allTime = math.max(data.allTime, peak)
					data.days[date] = math.max(data.days[date] or 0, peak)
				end
				return data
			end)
		end
	end)
	pcall(function() servers:RemoveAsync(job) end)
	-- A successor may take over immediately after a graceful shutdown.
	pcall(function()
		shared:UpdateAsync("leader", function(old)
			if old and old.job == job then return {job = job, untilTime = 0} end
			return old
		end, 60)
	end)
end)

