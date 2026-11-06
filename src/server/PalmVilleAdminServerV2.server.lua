local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")
local TextService = game:GetService("TextService")
local TextChatService = game:GetService("TextChatService")
local MessagingService = game:GetService("MessagingService")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")
local ItemRegistry = require(ServerScriptService:WaitForChild("PalmVilleItemRegistry"))

local remote = ReplicatedStorage:FindFirstChild("PalmVilleAdminRemote")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "PalmVilleAdminRemote"
	remote.Parent = ReplicatedStorage
end

local roleResolver = ServerScriptService:FindFirstChild("PalmVilleGetAdminRole") or Instance.new("BindableFunction")
roleResolver.Name = "PalmVilleGetAdminRole"
roleResolver.Parent = ServerScriptService

local roleChanged = ServerScriptService:FindFirstChild("PalmVilleAdminRoleChanged") or Instance.new("BindableEvent")
roleChanged.Name = "PalmVilleAdminRoleChanged"
roleChanged.Parent = ServerScriptService

local OWNER_ID = 7125208724
local MASTER_USERNAME = "lupiners0"
local MASTER_ID = 11199335797
local HEAD_ADMIN_ID = 9419687160
local BOOTSTRAP = {
	[tostring(OWNER_ID)] = {role = "OWNER", name = "tmskye"},
	[tostring(MASTER_ID)] = {role = "MASTER DEVELOPER", name = "lupiners0"},
	[tostring(HEAD_ADMIN_ID)] = {role = "HEAD ADMIN", name = "Butteryvo"},
}
local ASSIGNABLE = {["HEAD ADMIN"] = true, ADMIN = true, MODERATOR = true, HELPER = true}
local RANK = {OWNER = 100, ["MASTER DEVELOPER"] = 100, ["HEAD ADMIN"] = 80, ADMIN = 60, MODERATOR = 40, HELPER = 20}
local AREAS = {"Players", "Monitoring", "Announcements", "GiveItem", "Environment", "Moderation", "Tools", "Logs", "Server"}
local DEFAULT_PERMISSIONS = {
	["HEAD ADMIN"] = {Players = true, Monitoring = true, Announcements = true, GiveItem = true, Moderation = true, Tools = true},
	ADMIN = {Players = true, Monitoring = true, Announcements = false, GiveItem = true, Moderation = true, Tools = true},
	MODERATOR = {Players = true, Monitoring = true, Moderation = true, Logs = true},
	HELPER = {Monitoring = true, Logs = true},
}
local function tryGetDataStore(name)
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(name)
	end)
	if ok then return store end
	warn(string.format("[PalmVille Admin] DataStore %s unavailable; using in-memory fallback for this Studio session. %s", name, tostring(store)))
	return nil
end

local adminStoreSuffix = RunService:IsStudio() and "_StudioTest" or ""
local staffStore = tryGetDataStore("PalmVilleAdminRoles_v2" .. adminStoreSuffix)
local permissionStore = tryGetDataStore("PalmVilleAdminPermissions_v2" .. adminStoreSuffix)
local logStore = tryGetDataStore("PalmVilleAdminLogs_v2" .. adminStoreSuffix)
local moderationStore = tryGetDataStore("PalmVilleAdminModeration_v2" .. adminStoreSuffix)
local staff = {}
local rolePermissions = {}
local memoryLogs = {}
local muted = {}
local flyStates = {}
local invisibleStates = {}
local invisibleSaved = {}
local noclipStates = {}
local frozenStates = {}
local freeCameras = {}
local previousPositions = {}
local spectators = {}
local watchers = {}
local requestTimes = {}
local accessRequestLogged = {}
local cameraTimes = {}
local joinTimes = {}
local serverStarted = os.clock()
local serverFps = 0
local serverMemory = nil
local frameCount = 0
local sampleStarted = os.clock()
local pendingActivity = {}
local activityWorkerRunning = false

local function copyTable(input)
	local output = {}
	for key, value in pairs(input or {}) do
		if type(value) == "table" then
			output[key] = copyTable(value)
		else
			output[key] = value
		end
	end
	return output
end

for id, entry in pairs(BOOTSTRAP) do
	staff[id] = {role = entry.role, name = entry.name}
end
for role, values in pairs(DEFAULT_PERMISSIONS) do
	rolePermissions[role] = copyTable(values)
end

local function getRoleById(userId)
	local entry = staff[tostring(userId)]
	return entry and entry.role or nil
end

local function canManageStaff(player)
	local role = getRoleById(player.UserId)
	return role == "OWNER" or role == "MASTER DEVELOPER"
end

local function hasPermission(player, area)
	local role = getRoleById(player.UserId)
	if role == "OWNER" or role == "MASTER DEVELOPER" then
		return true
	end
	local permissions = role and rolePermissions[role]
	return permissions ~= nil and permissions[area] == true
end

local function notify(player, message)
	if player and player.Parent == Players then
		remote:FireClient(player, "Notice", tostring(message))
	end
end

local function logActivity(actor, action, target, result, extra)
	local entry = {
		id = HttpService:GenerateGUID(false),
		time = os.time(),
		actor = actor and actor.Name or "SYSTEM",
		actorUserId = actor and actor.UserId or 0,
		role = actor and getRoleById(actor.UserId) or "SYSTEM",
		action = tostring(action):sub(1, 48),
		target = target and target.Name or (extra and tostring(extra.target or "")) or "",
		targetUserId = target and target.UserId or (extra and tonumber(extra.targetUserId)) or 0,
		reason = extra and tostring(extra.reason or ""):sub(1, 180) or "",
		result = tostring(result):sub(1, 120),
	}
	table.insert(memoryLogs, 1, entry)
	while #memoryLogs > 100 do
		table.remove(memoryLogs)
	end
	table.insert(pendingActivity, entry)
	if activityWorkerRunning then return end
	activityWorkerRunning = true
	task.spawn(function()
		local failures = 0
		while #pendingActivity > 0 do
			local batch = {}
			for _ = 1, math.min(20, #pendingActivity) do
				table.insert(batch, table.remove(pendingActivity, 1))
			end
			local ok = pcall(function()
				logStore:UpdateAsync("recent", function(current)
					local items = type(current) == "table" and current or {}
					for index = #batch, 1, -1 do table.insert(items, 1, batch[index]) end
					while #items > 100 do table.remove(items) end
					return items
				end)
			end)
			if not ok then
				failures += 1
				for index = #batch, 1, -1 do table.insert(pendingActivity, 1, batch[index]) end
				if failures >= 2 then table.clear(pendingActivity); break end
				task.wait(3)
			else
				failures = 0
				task.wait(1)
			end
		end
		activityWorkerRunning = false
	end)
end

local function recordModeration(userId, entry)
	task.spawn(function()
		pcall(function()
			moderationStore:UpdateAsync("u_" .. tostring(userId), function(current)
				local items = type(current) == "table" and current or {}
				table.insert(items, 1, entry)
				while #items > 50 do
					table.remove(items)
				end
				return items
			end)
		end)
	end)
end

local function loadPersistentData()
	local ok, savedStaff = pcall(function()
		return staffStore:GetAsync("staff")
	end)
	if ok and type(savedStaff) == "table" then
		for id, entry in pairs(savedStaff) do
			if type(id) == "string" and type(entry) == "table" and ASSIGNABLE[entry.role] then
				local userId = tonumber(id)
				if userId and userId > 0 and not BOOTSTRAP[id] then
					staff[id] = {role = entry.role, name = tostring(entry.name or id):sub(1, 20)}
				end
			end
		end
	end
	for id, entry in pairs(BOOTSTRAP) do
		staff[id] = {role = entry.role, name = entry.name}
	end

	local permissionOk, savedPermissions = pcall(function()
		return permissionStore:GetAsync("areas")
	end)
	if permissionOk and type(savedPermissions) == "table" then
		for role, permissions in pairs(savedPermissions) do
			if ASSIGNABLE[role] and type(permissions) == "table" then
				rolePermissions[role] = rolePermissions[role] or {}
				for _, area in ipairs(AREAS) do
					if type(permissions[area]) == "boolean" then
						rolePermissions[role][area] = permissions[area]
					end
				end
			end
		end
	end
end

local function notifyRoleChanged(userId)
	roleChanged:Fire(tonumber(userId))
end

local function applyOnlineRole(userId)
	local player = Players:GetPlayerByUserId(tonumber(userId))
	if player then
		player:SetAttribute("PalmVilleAdminRole", getRoleById(userId) or "")
		notifyRoleChanged(userId)
	end
end

local function publishStaffChange(userId, role, name)
	local payload = {kind = "Staff", jobId = game.JobId, userId = tonumber(userId), role = role or "NONE", name = name or ""}
	task.spawn(function()
		pcall(function() MessagingService:PublishAsync("PalmVilleAdminSync_v2", payload) end)
	end)
end

local function publishPermissionChange(role, area, enabled)
	local payload = {kind = "Permission", jobId = game.JobId, role = role, area = area, enabled = enabled}
	task.spawn(function()
		pcall(function() MessagingService:PublishAsync("PalmVilleAdminSync_v2", payload) end)
	end)
end

local function saveStaffChange(userId, role, name)
	local id = tostring(userId)
	if BOOTSTRAP[id] then
		return false, "The original PalmVille roles are protected."
	end
	if role and not ASSIGNABLE[role] then
		return false, "Choose an available role."
	end
	local ok, result = pcall(function()
		return staffStore:UpdateAsync("staff", function(current)
			local nextStaff = type(current) == "table" and current or {}
			if role then
				nextStaff[id] = {role = role, name = tostring(name or id):sub(1, 20)}
			else
				nextStaff[id] = nil
			end
			for protectedId, protectedEntry in pairs(BOOTSTRAP) do
				nextStaff[protectedId] = {role = protectedEntry.role, name = protectedEntry.name}
			end
			return nextStaff
		end)
	end)
	if not ok or type(result) ~= "table" then
		return false, "Role storage is unavailable. No role change was saved."
	end
	staff = result
	for protectedId, protectedEntry in pairs(BOOTSTRAP) do
		staff[protectedId] = {role = protectedEntry.role, name = protectedEntry.name}
	end
	applyOnlineRole(userId)
	publishStaffChange(userId, role, name)
	return true
end

local function savePermission(role, area, enabled)
	if not ASSIGNABLE[role] or table.find(AREAS, area) == nil or type(enabled) ~= "boolean" then
		return false
	end
	local ok, result = pcall(function()
		return permissionStore:UpdateAsync("areas", function(current)
			local nextPermissions = type(current) == "table" and current or {}
			nextPermissions[role] = type(nextPermissions[role]) == "table" and nextPermissions[role] or {}
			nextPermissions[role][area] = enabled
			return nextPermissions
		end)
	end)
	if not ok or type(result) ~= "table" then
		return false
	end
	rolePermissions[role] = rolePermissions[role] or copyTable(DEFAULT_PERMISSIONS[role])
	rolePermissions[role][area] = enabled
	publishPermissionChange(role, area, enabled)
	return true
end

local syncConnection
if RunService:IsStudio() then
	print("[PalmVille Admin] Studio detected; cross-server MessagingService sync skipped.")
else
	task.spawn(function()
		local ok, result = pcall(function()
			return MessagingService:SubscribeAsync("PalmVilleAdminSync_v2", function(message)
				local payload = message.Data
				if type(payload) ~= "table" or payload.jobId == game.JobId then return end
				if payload.kind == "Staff" then
					local userId = tonumber(payload.userId)
					local id = userId and tostring(userId)
					if not userId or userId < 1 or BOOTSTRAP[id] then return end
					if ASSIGNABLE[payload.role] then
						staff[id] = {role = payload.role, name = tostring(payload.name or id):sub(1, 20)}
					else
						staff[id] = nil
					end
					applyOnlineRole(userId)
				elseif payload.kind == "Permission" and ASSIGNABLE[payload.role] and table.find(AREAS, payload.area) then
					rolePermissions[payload.role] = rolePermissions[payload.role] or copyTable(DEFAULT_PERMISSIONS[payload.role])
					rolePermissions[payload.role][payload.area] = payload.enabled == true
				end
			end)
		end)
		if ok then
			syncConnection = result
		else
			warn("[PalmVille Admin] Cross-server role sync unavailable: " .. tostring(result))
		end
	end)
end

roleResolver.OnInvoke = function(playerOrId)
	local userId = typeof(playerOrId) == "Instance" and playerOrId:IsA("Player") and playerOrId.UserId or tonumber(playerOrId)
	return userId and getRoleById(userId) or nil
end

local function onlinePlayer(userId)
	return userId and Players:GetPlayerByUserId(tonumber(userId)) or nil
end

local function canAffect(actor, targetUserId)
	if not targetUserId or targetUserId == actor.UserId then
		return false
	end
	local actorRole = getRoleById(actor.UserId)
	local targetRole = getRoleById(targetUserId)
	return (RANK[actorRole] or 0) > (RANK[targetRole] or 0)
end

local function filterBroadcast(player, rawText, maxLength)
	local text = tostring(rawText or ""):sub(1, maxLength or 240)
	if text:gsub("%s", "") == "" then
		return nil
	end
	local ok, result = pcall(function()
		local filterResult = TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat)
		return filterResult:GetNonChatStringForBroadcastAsync()
	end)
	if ok and type(result) == "string" and result ~= "" then
		return result
	end
	return nil
end

local function resolveUsername(username)
	local clean = tostring(username or ""):match("^%s*(.-)%s*$")
	if #clean < 3 or #clean > 20 or not clean:match("^[%w_]+$") then
		return nil, nil
	end
	local ok, userId = pcall(function()
		return Players:GetUserIdFromNameAsync(clean)
	end)
	if not ok or type(userId) ~= "number" or userId < 1 then
		return nil, nil
	end
	return userId, clean
end

local function resolveTarget(data, allowOffline)
	local id = tonumber(data.targetUserId)
	if id and id % 1 == 0 and id > 0 then
		local player = onlinePlayer(id)
		if player then
			return id, player.Name, player
		end
	end
	if allowOffline then
		local userId, username = resolveUsername(data.username)
		if userId then
			return userId, username, onlinePlayer(userId)
		end
	end
	return nil, nil, nil
end

local function findCharacterPart(player, name)
	local character = player and player.Character
	return character and character:FindFirstChild(name)
end

local function weatherAtmosphere()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Name = "PalmVilleAdminAtmosphere"
		atmosphere.Parent = Lighting
	end
	return atmosphere
end

local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
local originalAtmosphere = atmosphere and {
	Density = atmosphere.Density,
	Haze = atmosphere.Haze,
	Glare = atmosphere.Glare,
	Color = atmosphere.Color,
	Decay = atmosphere.Decay,
	Offset = atmosphere.Offset,
} or nil
local terrain = Workspace:FindFirstChildOfClass("Terrain")
local clouds = terrain and terrain:FindFirstChildOfClass("Clouds")
local madeClouds = false
if terrain and not clouds then
	clouds = Instance.new("Clouds")
	clouds.Name = "PalmVilleAdminClouds"
	clouds.Cover = 0
	clouds.Density = 0
	clouds.Parent = terrain
	madeClouds = true
end
local originalClouds = clouds and {Cover = clouds.Cover, Density = clouds.Density, Color = clouds.Color} or nil
local originalLighting = {
	Brightness = Lighting.Brightness,
	Ambient = Lighting.Ambient,
	OutdoorAmbient = Lighting.OutdoorAmbient,
}

local function restoreWeather()
	if atmosphere and originalAtmosphere then
		for property, value in pairs(originalAtmosphere) do
			atmosphere[property] = value
		end
	elseif atmosphere and atmosphere.Name == "PalmVilleAdminAtmosphere" then
		atmosphere:Destroy()
	end
	if clouds and originalClouds then
		for property, value in pairs(originalClouds) do
			clouds[property] = value
		end
	elseif madeClouds and clouds then
		clouds:Destroy()
	end
	Lighting.Brightness = originalLighting.Brightness
	Lighting.Ambient = originalLighting.Ambient
	Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
end

local function setWeather(kind)
	if kind == "Sunny" then
		restoreWeather()
	elseif kind == "Cloudy" or kind == "Rain" or kind == "Fog" or kind == "Storm" then
		local haze = weatherAtmosphere()
		if kind == "Cloudy" then
			haze.Density, haze.Haze, haze.Glare = 0.28, 1.2, 0.1
			if clouds then clouds.Cover, clouds.Density = 0.72, 0.32 end
		elseif kind == "Rain" then
			haze.Density, haze.Haze, haze.Glare = 0.34, 1.8, 0
			if clouds then clouds.Cover, clouds.Density = 0.88, 0.48 end
		elseif kind == "Fog" then
			haze.Density, haze.Haze, haze.Glare = 0.48, 2.4, 0
			if clouds then clouds.Cover, clouds.Density = 0.42, 0.2 end
		else
			haze.Density, haze.Haze, haze.Glare = 0.48, 2.2, 0
			if clouds then clouds.Cover, clouds.Density = 0.96, 0.65 end
			Lighting.Brightness = math.max(0.5, originalLighting.Brightness * 0.65)
		end
	else
		return false
	end
	remote:FireAllClients("Weather", kind)
	return true
end

local function hideInvisibleItem(userId, item)
	local saved = invisibleSaved[userId]
	if not saved then return end
	if item:IsA("BasePart") then
		saved[item] = saved[item] or {
			transparency = item.Transparency,
			localTransparencyModifier = item.LocalTransparencyModifier,
		}
		item.Transparency = 1
		pcall(function() item.LocalTransparencyModifier = 1 end)
	elseif item:IsA("Decal") or item:IsA("Texture") then
		saved[item] = saved[item] or {transparency = item.Transparency}
		item.Transparency = 1
	elseif item:IsA("ParticleEmitter") or item:IsA("Trail") or item:IsA("Beam")
		or item:IsA("Fire") or item:IsA("Smoke") or item:IsA("Sparkles") or item:IsA("Highlight") then
		saved[item] = saved[item] or {enabled = item.Enabled}
		item.Enabled = false
	end
end

local function setInvisibleCharacter(player, character)
	if not invisibleStates[player.UserId] or not character then return end
	invisibleSaved[player.UserId] = invisibleSaved[player.UserId] or {}
	for _, item in ipairs(character:GetDescendants()) do
		hideInvisibleItem(player.UserId, item)
	end
end

local function setInvisible(player, enabled)
	local userId = player.UserId
	enabled = enabled == true
	if enabled then
		if invisibleStates[userId] then return end
		invisibleStates[userId] = true
		invisibleSaved[userId] = {}
		setInvisibleCharacter(player, player.Character)
		return
	end
	if not invisibleStates[userId] then return end
	invisibleStates[userId] = nil
	local saved = invisibleSaved[userId] or {}
	invisibleSaved[userId] = nil
	for item, properties in pairs(saved) do
		if item and item.Parent then
			if item:IsA("BasePart") then
				item.Transparency = properties.transparency
				pcall(function() item.LocalTransparencyModifier = properties.localTransparencyModifier end)
			elseif item:IsA("Decal") or item:IsA("Texture") then
				item.Transparency = properties.transparency
			elseif properties.enabled ~= nil then
				item.Enabled = properties.enabled
			end
		end
	end
end

local function setNoclip(player, enabled)
	local userId = player.UserId
	if enabled then
		if noclipStates[userId] then return true end
		local character = player.Character
		if not character then return false end
		local state = {character = character, saved = {}}
		noclipStates[userId] = state
		local function disableCollision(item)
			if item:IsA("BasePart") then
				if state.saved[item] == nil then state.saved[item] = item.CanCollide end
				item.CanCollide = false
			end
		end
		for _, item in ipairs(character:GetDescendants()) do disableCollision(item) end
		state.connection = character.DescendantAdded:Connect(disableCollision)
		return true
	end
	local state = noclipStates[userId]
	if not state then return true end
	noclipStates[userId] = nil
	if state.connection then state.connection:Disconnect() end
	for part, canCollide in pairs(state.saved) do
		if part and part.Parent then part.CanCollide = canCollide end
	end
	return true
end

local function restoreFreeze(userId)
	local state = frozenStates[userId]
	if not state then return end
	frozenStates[userId] = nil
	local humanoid = state.humanoid
	if humanoid and humanoid.Parent then
		humanoid.WalkSpeed = state.walkSpeed
		humanoid.UseJumpPower = state.useJumpPower
		humanoid.JumpPower = state.jumpPower
		humanoid.JumpHeight = state.jumpHeight
		humanoid.AutoRotate = state.autoRotate
	end
	local root = state.root
	if root and root.Parent then root.Anchored = state.rootAnchored end
end

local function setFrozen(target, enabled)
	local userId = target.UserId
	if not enabled then
		restoreFreeze(userId)
		return true
	end
	if frozenStates[userId] then return true end
	local character = target.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or not root then return false end
	frozenStates[userId] = {
		character = character,
		humanoid = humanoid,
		root = root,
		walkSpeed = humanoid.WalkSpeed,
		useJumpPower = humanoid.UseJumpPower,
		jumpPower = humanoid.JumpPower,
		jumpHeight = humanoid.JumpHeight,
		autoRotate = humanoid.AutoRotate,
		rootAnchored = root.Anchored,
	}
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.AutoRotate = false
	root.Anchored = true
	return true
end

local function giveRegisteredItem(target, code, amount)
	local item = ItemRegistry[code]
	if not item or not item.template or not item.template:IsA("Tool") then
		return false
	end
	local backpack = target:FindFirstChildOfClass("Backpack") or target:WaitForChild("Backpack", 5)
	if not backpack then return false end
	for _ = 1, amount do
		local tool = item.template:Clone()
		tool.Name = item.displayName
		tool:SetAttribute("ItemCode", code)
		tool.Parent = backpack
	end
	return true
end

local function stopFly(player)
	local state = flyStates[player.UserId]
	flyStates[player.UserId] = nil
	if state then
		if state.velocity and state.velocity.Parent then state.velocity:Destroy() end
		if state.orientation and state.orientation.Parent then state.orientation:Destroy() end
		if state.attachment and state.attachment.Parent then state.attachment:Destroy() end
		local humanoid = state.humanoid
		if humanoid and humanoid.Parent then
			humanoid.PlatformStand = state.platformStand
			humanoid.AutoRotate = state.autoRotate
			humanoid.WalkSpeed = state.walkSpeed
			humanoid.JumpPower = state.jumpPower
			humanoid.JumpHeight = state.jumpHeight
			if state.humanoidState and humanoid.Health > 0 then
				pcall(function() humanoid:ChangeState(state.humanoidState) end)
			end
		end
		local root = state.root
		if root and root.Parent then
			root.AssemblyLinearVelocity = state.linearVelocity or Vector3.zero
			root.AssemblyAngularVelocity = state.angularVelocity or Vector3.zero
			pcall(function() root:SetNetworkOwnershipAuto() end)
		end
	end
	remote:FireClient(player, "SetFly", false)
end

local function setFly(player, enabled)
	if enabled then
		local existing = flyStates[player.UserId]
		if existing then
			existing.last = os.clock()
			remote:FireClient(player, "SetFly", true)
			return true
		end
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local root = findCharacterPart(player, "HumanoidRootPart")
		if not humanoid or not root then return false end
		local attachment = Instance.new("Attachment")
		attachment.Name = "PalmVilleFlyAttachment"
		attachment.Parent = root
		local velocity = Instance.new("LinearVelocity")
		velocity.Name = "PalmVilleFlyVelocity"
		velocity.Attachment0 = attachment
		velocity.RelativeTo = Enum.ActuatorRelativeTo.World
		velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		velocity.VectorVelocity = Vector3.zero
		velocity.MaxForce = math.max(10000, root.AssemblyMass * Workspace.Gravity * 12)
		velocity.Parent = root
		local orientation = Instance.new("AlignOrientation")
		orientation.Name = "PalmVilleFlyOrientation"
		orientation.Attachment0 = attachment
		orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
		orientation.CFrame = root.CFrame.Rotation
		orientation.MaxTorque = 1000000000
		orientation.MaxAngularVelocity = 20
		orientation.Responsiveness = 30
		orientation.Parent = root
		flyStates[player.UserId] = {
			humanoid = humanoid,
			root = root,
			platformStand = humanoid.PlatformStand,
			autoRotate = humanoid.AutoRotate,
			walkSpeed = humanoid.WalkSpeed,
			jumpPower = humanoid.JumpPower,
			jumpHeight = humanoid.JumpHeight,
			humanoidState = humanoid:GetState(),
			linearVelocity = root.AssemblyLinearVelocity,
			angularVelocity = root.AssemblyAngularVelocity,
			attachment = attachment,
			velocity = velocity,
			orientation = orientation,
			last = os.clock(),
		}
		humanoid.PlatformStand = false
		humanoid.AutoRotate = false
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Freefall) end)
		pcall(function() root:SetNetworkOwner(nil) end)
		remote:FireClient(player, "SetFly", true)
	else
		stopFly(player)
	end
	return true
end

local function stopSpectate(adminUserId, announce)
	local session = spectators[adminUserId]
	if not session then return end
	spectators[adminUserId] = nil
	local targetWatchers = watchers[session.targetUserId]
	if targetWatchers then
		targetWatchers[adminUserId] = nil
		if next(targetWatchers) == nil then
			watchers[session.targetUserId] = nil
		end
	end
	local target = onlinePlayer(session.targetUserId)
	local admin = onlinePlayer(adminUserId)
	if target then
		remote:FireClient(target, "StopCameraFeed", {token = session.token})
		if announce and admin then
			remote:FireClient(target, "SpectateNotice", {admin = admin.Name, active = false})
		end
	end
	if admin then
		remote:FireClient(admin, "SpectateStopped")
	end
end

local function beginSpectate(admin, target)
	stopSpectate(admin.UserId, true)
	local token = HttpService:GenerateGUID(false)
	spectators[admin.UserId] = {targetUserId = target.UserId, token = token}
	watchers[target.UserId] = watchers[target.UserId] or {}
	watchers[target.UserId][admin.UserId] = token
	remote:FireClient(target, "BeginCameraFeed", {token = token, adminUserId = admin.UserId})
	remote:FireClient(target, "SpectateNotice", {admin = admin.Name, active = true})
	remote:FireClient(admin, "SpectateStarted", {targetUserId = target.UserId, username = target.Name})
end

local function setModerationState(userId, action, actor, reason, duration)
	local record = {
		time = os.time(),
		action = action,
		actor = actor.Name,
		actorUserId = actor.UserId,
		role = getRoleById(actor.UserId),
		reason = reason,
		duration = duration or 0,
	}
	recordModeration(userId, record)
end

local announcements = {}
do
	local allowedRoles = {OWNER=true,["MASTER DEVELOPER"]=true,["HEAD ADMIN"]=true}
	local prefix = RunService:IsStudio() and "PalmVilleAnnouncements_Test_v3" or "PalmVilleAnnouncements_v3"
	local historyStore = tryGetDataStore(prefix)
	local topic = prefix
	local history, seen, historyRequests = {}, {}, {}
	local subscription
	local function permitted(player)
		return allowedRoles[getRoleById(player.UserId)] == true and hasPermission(player,"Announcements")
	end
	local function remember(row)
		for _,old in ipairs(history)do if old.id==row.id then return end end
		table.insert(history,1,row)
		table.sort(history,function(a,b)return a.time>b.time end)
		while #history>50 do table.remove(history)end
	end
	local function deliver(row)
		if seen[row.id] then return end
		seen[row.id]=true
		task.delay(120,function()seen[row.id]=nil end)
		remember(row)
		remote:FireAllClients("Announcement",row)
	end
	local function subscribe()
		if RunService:IsStudio() or subscription then return end
		local ok,result=pcall(function()
			return MessagingService:SubscribeAsync(topic,function(message)
				local row=message.Data
				if type(row)~="table" or type(row.id)~="string" or type(row.text)~="string" or #row.text>560
					or not allowedRoles[row.role] or row.audience~="All Servers" or type(row.time)~="number"
					or math.abs(os.time()-row.time)>120 then return end
				deliver(row)
			end)
		end)
		if ok then subscription=result else warn("PalmVille announcements subscription: "..tostring(result))end
	end
	task.spawn(function()while not subscription do subscribe();if RunService:IsStudio()then break end;task.wait(30)end end)
	function announcements.history(player)
		if not permitted(player) then return end
		if os.clock()<(historyRequests[player.UserId] or 0)then return end
		historyRequests[player.UserId]=os.clock()+10
		local ok,stored=false,nil
		if historyStore then
			ok,stored=pcall(function()return historyStore:GetAsync("recent")end)
		end
		if not permitted(player) then return end
		if ok and type(stored)=="table"then for _,row in ipairs(stored)do
				if type(row)=="table" and type(row.id)=="string" and type(row.time)=="number" and allowedRoles[row.role]then remember(row)end
			end end
		remote:FireClient(player,"AnnouncementHistory",{rows=history,warning=not ok and "Saved history unavailable; showing this server's recent announcements." or nil})
	end
	function announcements.send(player,data)
		if not permitted(player)then notify(player,"Only Owner, Dev, and Head Admin can send announcements.");return end
		local raw=type(data.message)=="string" and data.message or ""
		if #raw==0 or #raw>280 or not utf8.len(raw) or raw:gsub("%s","")==""then
			notify(player,"Enter a message within the 280-character limit.");return
		end
		if data.audience~="This Server" and data.audience~="All Servers"then notify(player,"Choose an audience.");return end
		if RunService:IsStudio() and data.audience=="All Servers"then
			notify(player,"All Servers must be tested in the published game. Choose This Server in Studio.");return
		end
		local text=filterBroadcast(player,raw,280)
		if not text then notify(player,"Announcement could not be filtered. Nothing was sent.");return end
		if not permitted(player)then notify(player,"Announcement permission changed. Nothing was sent.");return end
		local authorName = getRoleById(player.UserId) == "MASTER DEVELOPER" and "Lupin" or (player.DisplayName ~= "" and player.DisplayName or player.Name)
		local row={id=HttpService:GenerateGUID(false),text=text,by=authorName,
			userId=player.UserId,role=getRoleById(player.UserId),audience=data.audience,time=os.time(),duration=8,jobId=game.JobId}
		deliver(row)
		local published=true
		if row.audience=="All Servers"then published=pcall(function()MessagingService:PublishAsync(topic,row)end)end
		notify(player,published and "Announcement sent." or "Shown in this server; cross-server delivery failed. Check Output.")
		logActivity(player,"Announcement / "..row.audience,nil,published and "Success" or "Partial")
		remote:FireClient(player,"AnnouncementSent",{id=row.id,message=raw,delivered=published})
		if historyStore then
			task.spawn(function()
				local ok,err=pcall(function()historyStore:UpdateAsync("recent",function(rows)
						rows=type(rows)=="table" and rows or {}
						for _,old in ipairs(rows)do if old.id==row.id then return rows end end
						table.insert(rows,1,row);table.sort(rows,function(a,b)return a.time>b.time end)
						while #rows>50 do table.remove(rows)end
						return rows
					end)end)
				if not ok then warn("PalmVille announcement history save: "..tostring(err));notify(player,"Announcement sent, but history could not be saved.")end
			end)
		end
	end
	Players.PlayerRemoving:Connect(function(player)historyRequests[player.UserId]=nil end)
end

local function applyChatMute(channel)
	if not channel:IsA("TextChannel") then return end
	local ok, oldCallback = pcall(function()
		return channel.ShouldDeliverCallback
	end)
	if not ok then return end
	pcall(function()
		channel.ShouldDeliverCallback = function(message, textSource)
			if textSource and muted[textSource.UserId] then
				return false
			end
			if type(oldCallback) == "function" then
				local allowed = oldCallback(message, textSource)
				if allowed == false then return false end
			end
			return true
		end
	end)
end

local function bindTextChannels(folder)
	if not folder or folder.Name ~= "TextChannels" or not folder:IsA("Folder") then return end
	for _, channel in ipairs(folder:GetChildren()) do
		applyChatMute(channel)
	end
	folder.ChildAdded:Connect(applyChatMute)
end

bindTextChannels(TextChatService:FindFirstChild("TextChannels"))
TextChatService.ChildAdded:Connect(bindTextChannels)

local function playerSnapshot()
	local roster = {}
	for _, target in ipairs(Players:GetPlayers()) do
		local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
		local root = findCharacterPart(target, "HumanoidRootPart")
		local position = root and root.Position
		table.insert(roster, {
			userId = target.UserId,
			username = target.Name,
			displayName = target.DisplayName,
			role = getRoleById(target.UserId) or "PLAYER",
			health = humanoid and math.floor(humanoid.Health + 0.5) or 0,
			maxHealth = humanoid and math.floor(humanoid.MaxHealth + 0.5) or 0,
			position = position and string.format("%.1f, %.1f, %.1f", position.X, position.Y, position.Z) or "—",
			playtime = math.max(0, os.time() - (joinTimes[target.UserId] or os.time())),
		})
	end
	table.sort(roster, function(a, b)
		if a.role ~= "PLAYER" and b.role == "PLAYER" then return true end
		if a.role == "PLAYER" and b.role ~= "PLAYER" then return false end
		return string.lower(a.username) < string.lower(b.username)
	end)
	local memory
	local ok, value = pcall(function()
		return Stats:GetTotalMemoryUsageMb()
	end)
	if ok then memory = math.floor(value + 0.5) end
	return {
		players = roster,
		metrics = {
			serverFps = serverFps,
			uptime = math.floor(os.clock() - serverStarted),
			playerCount = #roster,
			maxPlayers = Players.MaxPlayers,
			memoryMb = memory,
		},
	}
end

local function getStaffRows()
	local rows = {}
	for id, entry in pairs(staff) do
		local userId = tonumber(id)
		if userId and type(entry) == "table" then
			local online = onlinePlayer(userId)
			table.insert(rows, {
				userId = userId,
				username = online and online.Name or tostring(entry.name or id),
				role = entry.role,
				online = online ~= nil,
			})
		end
	end
	table.sort(rows, function(a, b)
		local ar, br = RANK[a.role] or 0, RANK[b.role] or 0
		if ar ~= br then return ar > br end
		return string.lower(a.username) < string.lower(b.username)
	end)
	return rows
end

local function getRecentLogs()
	local ok, saved = pcall(function()
		return logStore:GetAsync("recent")
	end)
	if ok and type(saved) == "table" then return saved end
	return memoryLogs
end

local function canRequest(player, minimumInterval)
	local now = os.clock()
	local last = requestTimes[player.UserId] or 0
	if now - last < (minimumInterval or 0.15) then return false end
	requestTimes[player.UserId] = now
	return true
end

local function handleAction(player, data)
	local action = tostring(data.action or "")
	local role = getRoleById(player.UserId)
	if not role then return end
	if not canRequest(player, 0.12) then return end

	local targetId, targetName, target = resolveTarget(data, action == "TempBan" or action == "PermanentBan" or action == "Unban" or action == "ModerationHistory")
	local function requireArea(area)
		if hasPermission(player, area) then return true end
		notify(player, "You do not have access to that section.")
		logActivity(player, action, target, "Denied")
		return false
	end
	local function requireTarget()
		if targetId and canAffect(player, targetId) then return true end
		notify(player, "That player is protected or unavailable.")
		logActivity(player, action, target, "Denied", {target = targetName, targetUserId = targetId})
		return false
	end

	if action == "Teleport" or action == "Bring" or action == "Return" or action == "ResetTarget" then
		if not requireArea("Players") then return end
		if action == "Return" then
			local saved = previousPositions[player.UserId]
			if not saved or not player.Character then notify(player, "No saved position."); return end
			player.Character:PivotTo(saved)
			previousPositions[player.UserId] = nil
			notify(player, "Returned to your previous position.")
			logActivity(player, action, nil, "Success")
			return
		end
		if not target or not requireTarget() then return end
		if not player.Character or not target.Character then notify(player, "A character is not ready."); return end
		if action == "Teleport" then
			previousPositions[player.UserId] = player.Character:GetPivot()
			player.Character:PivotTo(target.Character:GetPivot() * CFrame.new(0, 0, 4))
		elseif action == "Bring" then
			previousPositions[target.UserId] = target.Character:GetPivot()
			target.Character:PivotTo(player.Character:GetPivot() * CFrame.new(4, 0, 0))
		else
			local humanoid = target.Character:FindFirstChildOfClass("Humanoid")
			if not humanoid then notify(player, "Target character is not ready."); return end
			humanoid.Health = 0
		end
		notify(player, action == "Bring" and ("Brought " .. target.Name .. ".") or action == "ResetTarget" and ("Reset " .. target.Name .. ".") or ("Teleported to " .. target.Name .. "."))
		logActivity(player, action, target, "Success")
		return
	end

	if action == "Freeze" or action == "Unfreeze" then
		if not requireArea("Moderation") then return end
		if not target or not requireTarget() then return end
		local enabled = action == "Freeze"
		if not setFrozen(target, enabled) then notify(player, "The target character is not ready."); return end
		local result = enabled and "Frozen" or "Unfrozen"
		setModerationState(target.UserId, action, player, tostring(data.reason or ""), 0)
		logActivity(player, action, target, "Success", {reason = tostring(data.reason or "")})
		notify(player, target.Name .. " " .. string.lower(result) .. ".")
		return
	end

	if action == "Spectate" or action == "WatchScreen" then
		if not requireArea("Monitoring") then return end
		if not target or not requireTarget() then return end
		beginSpectate(player, target)
		if action == "WatchScreen" then
			remote:FireClient(player, "WatchScreenStarted", {targetUserId = target.UserId, username = target.Name})
		end
		logActivity(player, action, target, "Started")
		return
	elseif action == "StopSpectate" then
		if not requireArea("Monitoring") then return end
		stopSpectate(player.UserId, true)
		logActivity(player, action, nil, "Success")
		return
	end

	if action == "Announce" then
		announcements.send(player,data)
		return
	end

	if action == "SetWeather" then
		if not requireArea("Environment") then return end
		local kind = tostring(data.weather or "")
		if setWeather(kind) then
			notify(player, "Weather changed to " .. kind .. ".")
			logActivity(player, "Weather / " .. kind, nil, "Success")
		else
			notify(player, "Choose a supported weather.")
		end
		return
	elseif action == "SetTime" then
		if not requireArea("Environment") then return end
		local times = {Sunrise = 6, Morning = 9, Afternoon = 14, Sunset = 18.5, Night = 0}
		local kind = tostring(data.time or "")
		if times[kind] then
			Lighting.ClockTime = times[kind]
			notify(player, "Time changed to " .. kind .. ".")
			logActivity(player, "Time / " .. kind, nil, "Success")
		else
			notify(player, "Choose a supported time.")
		end
		return
	end

	if action == "Warn" or action == "MuteChat" or action == "Kick" or action == "TempBan" or action == "PermanentBan" or action == "Unban" or action == "ModerationHistory" then
		if not requireArea("Moderation") then return end
		if action == "ModerationHistory" then
			if not targetId then notify(player, "Enter or select a username."); return end
			local ok, history = pcall(function()
				return moderationStore:GetAsync("u_" .. tostring(targetId))
			end)
			remote:FireClient(player, "ModerationHistory", {userId = targetId, username = targetName, items = ok and type(history) == "table" and history or {}})
			return
		end
		if action == "Unban" then
			if not targetId then notify(player, "Enter the username to unban."); return end
			if not canAffect(player, targetId) then notify(player, "That account is protected."); return end
			local ok = pcall(function()
				Players:UnbanAsync({UserIds = {targetId}, ApplyToUniverse = true})
			end)
			local filteredReason = filterBroadcast(player, data.reason, 180) or "No reason provided."
			setModerationState(targetId, "Unban", player, filteredReason, 0)
			logActivity(player, "Unban", target, ok and "Success" or "Failed", {target = targetName, targetUserId = targetId, reason = filteredReason})
			notify(player, ok and ("Unbanned " .. targetName .. ".") or "Unban failed. Check experience ban settings.")
			return
		end
		if not target or not requireTarget() then return end
		local reason = filterBroadcast(player, data.reason, 180)
		if action ~= "MuteChat" and not reason then
			notify(player, "Enter a reason and make sure it passes Roblox text filtering.")
			return
		end
		local moderationDuration = 0
		if action == "Warn" then
			remote:FireClient(target, "Warning", reason)
		elseif action == "MuteChat" then
			muted[target.UserId] = not muted[target.UserId]
			local state = muted[target.UserId] and "Muted" or "Unmuted"
			setModerationState(target.UserId, state, player, reason or "Chat mute toggled.", 0)
			remote:FireClient(target, "ChatMuteState", muted[target.UserId])
			notify(player, target.Name .. (muted[target.UserId] and " muted in text chat." or " unmuted in text chat."))
			logActivity(player, state .. " text chat", target, "Success", {reason = reason or "Chat mute toggled."})
			return
		elseif action == "Kick" then
			target:Kick("Removed by PalmVille staff. Reason: " .. reason)
		else
			local durationDays = math.floor(tonumber(data.durationDays) or 1)
			moderationDuration = action == "PermanentBan" and -1 or math.clamp(durationDays, 1, 365) * 86400
			local ok, err = pcall(function()
				Players:BanAsync({
					UserIds = {target.UserId},
					Duration = moderationDuration,
					DisplayReason = reason,
					PrivateReason = reason,
					ApplyToUniverse = true,
					ExcludeAltAccounts = false,
				})
			end)
			if not ok then
				notify(player, "Ban failed. Check that experience bans are enabled.")
				logActivity(player, action, target, "Failed", {reason = reason})
				return
			end
		end
		setModerationState(target.UserId, action, player, reason, moderationDuration)
		logActivity(player, action, target, "Success", {reason = reason})
		notify(player, action .. " completed for " .. target.Name .. ".")
		return
	end

	if action == "GiveItem" then
		if not requireArea("GiveItem") then return end
		local code = tostring(data.itemCode or ""):match("^%s*(.-)%s*$"):upper()
		local item = ItemRegistry[code]
		local amount = tonumber(data.amount)
		local roleLimit = role == "HEAD ADMIN" and 10 or role == "ADMIN" and 20 or 99
		if not item or not item.template or not item.template:IsA("Tool") then
			notify(player, "That item code is not registered.")
			logActivity(player, "Give Item", nil, "Invalid item code")
			return
		end
		if not amount or amount % 1 ~= 0 or amount < 1 or amount > math.min(item.maxAmount or 99, roleLimit) then
			notify(player, "Enter a valid amount for your role.")
			logActivity(player, "Give Item / " .. code, nil, "Invalid amount")
			return
		end
		local mode = tostring(data.targetMode or "Player")
		local recipients = {}
		if mode == "Self" then
			table.insert(recipients, player)
		elseif mode == "Player" then
			if not target or not requireTarget() then return end
			table.insert(recipients, target)
		elseif mode == "All" then
			for _, candidate in ipairs(Players:GetPlayers()) do
				if candidate == player or canAffect(player, candidate.UserId) then
					table.insert(recipients, candidate)
				end
			end
		else
			notify(player, "Choose Player, All, or Self.")
			return
		end
		local delivered = 0
		local failures = 0
		for _, recipient in ipairs(recipients) do
			if giveRegisteredItem(recipient, code, amount) then delivered += 1 else failures += 1 end
		end
		local result = string.format("%s player(s), %d item(s) each", tostring(delivered), amount)
		if failures > 0 then result ..= string.format("; %d failed", failures) end
		notify(player, delivered > 0 and ("Gave " .. item.displayName .. " to " .. tostring(delivered) .. " player(s).") or "No eligible player received the item.")
		logActivity(player, "Give Item / " .. code, mode == "Player" and target or nil, result, {
			target = mode == "Player" and target and target.Name or mode,
			targetUserId = mode == "Player" and target and target.UserId or 0,
		})
		return
	end

	if action == "SetFly" or action == "SetInvisible" or action == "SetFreeCamera" or action == "SetNoclip" or action == "SetAdminTitle" then
		if not requireArea("Tools") then return end
		local enabled = data.enabled == true
		if action == "SetFly" then
			if not setFly(player, enabled) then
				remote:FireClient(player, "SetFly", false)
				notify(player, "Your character is not ready.")
				return
			end
		elseif action == "SetInvisible" then
			setInvisible(player, enabled)
			remote:FireClient(player, "SetInvisible", enabled)
		elseif action == "SetNoclip" then
			if not setNoclip(player, enabled) then
				remote:FireClient(player, "SetNoclip", false)
				notify(player, "Your character is not ready.")
				return
			end
			remote:FireClient(player, "SetNoclip", enabled)
		elseif action == "SetAdminTitle" then
			player:SetAttribute("PalmVilleAdminTitleVisible", enabled)
			remote:FireClient(player, "SetAdminTitle", enabled)
		else
			freeCameras[player.UserId] = enabled or nil
			remote:FireClient(player, "SetFreeCamera", enabled)
		end
		notify(player, action:gsub("Set", "") .. (enabled and " enabled." or " disabled."))
		logActivity(player, action:gsub("Set", ""), nil, enabled and "Enabled" or "Disabled")
		return
	end

	if action == "AddStaff" or action == "RemoveStaff" then
		if not canManageStaff(player) then
			notify(player, "Only Owner and Developer can manage staff.")
			logActivity(player, action, target, "Denied")
			return
		end
		local resolvedId, username
		if action == "AddStaff" then
			resolvedId, username = resolveUsername(data.username)
			local newRole = tostring(data.role or "")
			if not resolvedId or not ASSIGNABLE[newRole] then notify(player, "Username or role is not valid."); return end
			local success, message = saveStaffChange(resolvedId, newRole, username)
			if not success then notify(player, message); logActivity(player, "Add staff", nil, message, {target = username, targetUserId = resolvedId}); return end
			local online = onlinePlayer(resolvedId)
			logActivity(player, "Assign " .. newRole, online, "Success", {target = username, targetUserId = resolvedId})
			notify(player, username .. " is now " .. newRole .. ".")
		else
			resolvedId = tonumber(data.targetUserId)
			local existing = resolvedId and staff[tostring(resolvedId)]
			if not existing or not ASSIGNABLE[existing.role] then
				notify(player, "Select an assignable staff account first.")
				logActivity(player, "Remove staff", onlinePlayer(resolvedId), "Denied", {targetUserId = resolvedId})
				return
			end
			local success, message = saveStaffChange(resolvedId, nil, existing.name)
			if not success then notify(player, message); logActivity(player, "Remove staff", nil, message, {target = existing.name, targetUserId = resolvedId}); return end
			local online = onlinePlayer(resolvedId)
			logActivity(player, "Remove " .. existing.role, online, "Success", {target = existing.name, targetUserId = resolvedId})
			notify(player, existing.name .. " was removed from staff.")
		end
		remote:FireClient(player, "StaffData", {staff = getStaffRows(), permissions = rolePermissions})
		return
	elseif action == "SetPermission" then
		if not canManageStaff(player) then notify(player, "Only Owner and Developer can manage permissions."); return end
		local roleName, area, enabled = tostring(data.role or ""), tostring(data.area or ""), data.enabled == true
		if not savePermission(roleName, area, enabled) then
			notify(player, "Permission was not saved.")
			logActivity(player, "Permission / " .. roleName .. " / " .. area, nil, "Failed")
			return
		end
		notify(player, roleName .. " permission updated.")
		logActivity(player, "Permission / " .. roleName .. " / " .. area, nil, enabled and "Enabled" or "Disabled")
		remote:FireClient(player, "StaffData", {staff = getStaffRows(), permissions = rolePermissions})
		return
	end

	notify(player, "That action is unavailable.")
end

print("[PalmVille Admin] Registering remote access/action listener.")
remote.OnServerEvent:Connect(function(player, action, data)
	if type(action) ~= "string" then return end
	data = type(data) == "table" and data or {}
	if action == "RequestAccess" then
		local role = getRoleById(player.UserId)
		if not accessRequestLogged[player.UserId] then
			accessRequestLogged[player.UserId] = true
			print(string.format("[PalmVille Admin] Access request received: %s (UserId %d), resolved role: %s.", player.Name, player.UserId, tostring(role or "NONE")))
		end
		if role then
			player:SetAttribute("PalmVilleAdminRole", role)
			remote:FireClient(player, "AccessGranted", {role = role, permissions = rolePermissions[role] or {}})
		else
			if not accessRequestLogged[player.UserId] then
				accessRequestLogged[player.UserId] = true
				warn(string.format("[PalmVille Admin] Access denied: %s (UserId %d). Configured developer: %s (UserId %d).", player.Name, player.UserId, MASTER_USERNAME, MASTER_ID))
			end
			remote:FireClient(player, "AccessDenied", {username = player.Name, userId = player.UserId, masterUsername = MASTER_USERNAME, masterUserId = MASTER_ID})
		end
		return
	elseif action == "RequestAnnouncementHistory" then
		announcements.history(player)
		return
	elseif action == "RequestSnapshot" then
		if not getRoleById(player.UserId) or (not hasPermission(player, "Monitoring") and not hasPermission(player, "Server")) or not canRequest(player, 0.45) then return end
		remote:FireClient(player, "Snapshot", playerSnapshot())
		return
	elseif action == "RequestStaff" then
		if not canManageStaff(player) or not canRequest(player, 0.25) then return end
		remote:FireClient(player, "StaffData", {staff = getStaffRows(), permissions = rolePermissions})
		return
	elseif action == "RequestLogs" then
		if not hasPermission(player, "Logs") or not canRequest(player, 0.35) then return end
		remote:FireClient(player, "LogsData", getRecentLogs())
		return
	elseif action == "CameraFrame" then
		if not getRoleById(player.UserId) or not canRequest(player, 0.06) then return end
		local token = tostring(data.token or "")
		local cframe = data.cframe
		local fov = tonumber(data.fov)
		if #token < 8 or typeof(cframe) ~= "CFrame" or not fov or fov < 20 or fov > 120 then return end
		local position = cframe.Position
		if position.X ~= position.X or position.Y ~= position.Y or position.Z ~= position.Z or position.Magnitude > 100000 then return end
		local current = watchers[player.UserId]
		if not current then return end
		for adminUserId, activeToken in pairs(current) do
			if activeToken == token then
				local admin = onlinePlayer(adminUserId)
				local session = spectators[adminUserId]
				if admin and session and session.targetUserId == player.UserId and session.token == token and getRoleById(adminUserId) then
					remote:FireClient(admin, "LiveCamera", {token = token, cframe = cframe, fov = fov})
				end
			end
		end
		return
	elseif action == "AbilityMove" then
		local state = flyStates[player.UserId]
		local direction = data.direction
		if not state or not hasPermission(player, "Tools") or typeof(direction) ~= "Vector3" then return end
		if direction.X ~= direction.X or direction.Y ~= direction.Y or direction.Z ~= direction.Z or direction.Magnitude > 1.05 then return end
		local root = state.root
		if not root or not root.Parent or not state.humanoid.Parent then return end
		local speed = math.clamp(tonumber(data.speed) or 54, 8, 120)
		state.last = os.clock()
		if state.velocity and state.velocity.Parent then
			state.velocity.VectorVelocity = direction * speed
		else
			root.AssemblyLinearVelocity = direction * speed
		end
		local facing = data.facing
		if typeof(facing) == "Vector3" and state.orientation and facing.Magnitude > 0.01 and facing.Magnitude < 1.05 then
			local horizontal = Vector3.new(facing.X, 0, facing.Z)
			if horizontal.Magnitude > 0.01 then
				state.orientation.CFrame = CFrame.lookAt(Vector3.zero, horizontal.Unit)
			end
		end
		return
	elseif action == "Action" then
		handleAction(player, data)
	end
end)
print("[PalmVille Admin] Remote access/action listener registered.")

local function onPlayerAdded(player)
	joinTimes[player.UserId] = os.time()
	local assignedRole = getRoleById(player.UserId)
	player:SetAttribute("PalmVilleAdminRole", assignedRole or "")
	if assignedRole and player:GetAttribute("PalmVilleAdminTitleVisible") == nil then
		player:SetAttribute("PalmVilleAdminTitleVisible", true)
	end
	player.CharacterAdded:Connect(function(character)
		if flyStates[player.UserId] then stopFly(player) end
		if noclipStates[player.UserId] then setNoclip(player, false) end
		if frozenStates[player.UserId] then restoreFreeze(player.UserId) end
		if freeCameras[player.UserId] then
			freeCameras[player.UserId] = nil
			remote:FireClient(player, "SetFreeCamera", false)
		end
		remote:FireClient(player, "SetNoclip", false)
		character.DescendantAdded:Connect(function(item)
			if invisibleStates[player.UserId] then
				hideInvisibleItem(player.UserId, item)
			end
		end)
		task.defer(function()
			if player.Character == character then
				setInvisibleCharacter(player, character)
			end
		end)
	end)
	local currentRole = getRoleById(player.UserId)
	if currentRole then
		notifyRoleChanged(player.UserId)
		task.defer(function()
			if player.Parent == Players then
				remote:FireClient(player, "AccessGranted", {role = currentRole, permissions = rolePermissions[currentRole] or {}})
			end
		end)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	stopSpectate(player.UserId, false)
	stopFly(player)
	setNoclip(player, false)
	restoreFreeze(player.UserId)
	local asTarget = watchers[player.UserId]
	if asTarget then
		for adminUserId in pairs(asTarget) do
			stopSpectate(adminUserId, true)
		end
	end
	invisibleStates[player.UserId] = nil
	invisibleSaved[player.UserId] = nil
	freeCameras[player.UserId] = nil
	joinTimes[player.UserId] = nil
	requestTimes[player.UserId] = nil
	accessRequestLogged[player.UserId] = nil
	cameraTimes[player.UserId] = nil
end)

RunService.Heartbeat:Connect(function()
	frameCount += 1
	local now = os.clock()
	local elapsed = now - sampleStarted
	if elapsed >= 1 then
		serverFps = math.floor(frameCount / elapsed + 0.5)
		frameCount = 0
		sampleStarted = now
		local ok, value = pcall(function()
			return Stats:GetTotalMemoryUsageMb()
		end)
		serverMemory = ok and math.floor(value + 0.5) or nil
	end
	for userId, state in pairs(flyStates) do
		if now - state.last > 0.45 then
			if state.velocity and state.velocity.Parent then
				state.velocity.VectorVelocity = Vector3.zero
			elseif state.root and state.root.Parent then
				state.root.AssemblyLinearVelocity = Vector3.zero
			end
		end
	end
end)

loadPersistentData()
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end
for userId in pairs(staff) do
	notifyRoleChanged(userId)
end

print(string.format("[PalmVille Admin] V2 server initialized. Developer: %s (UserId %d). DataStore mode: %s.", MASTER_USERNAME, MASTER_ID, staffStore and "persistent" or "Studio in-memory fallback"))

task.spawn(function()
	local ok, resolvedId = pcall(function()
		return Players:GetUserIdFromNameAsync(MASTER_USERNAME)
	end)
	if not ok or type(resolvedId) ~= "number" or resolvedId < 1 then
		warn("[PalmVille Admin] Could not verify the configured developer username through Roblox. Keeping the configured numeric UserId.")
		return
	end
	if resolvedId ~= MASTER_ID then
		local previousId = MASTER_ID
		BOOTSTRAP[tostring(previousId)] = nil
		MASTER_ID = resolvedId
		BOOTSTRAP[tostring(MASTER_ID)] = {role = "MASTER DEVELOPER", name = MASTER_USERNAME}
		staff[tostring(previousId)] = nil
		staff[tostring(MASTER_ID)] = {role = "MASTER DEVELOPER", name = MASTER_USERNAME}
		warn(string.format("[PalmVille Admin] Developer ID corrected using Roblox username lookup: %d -> %d (%s).", previousId, MASTER_ID, MASTER_USERNAME))
	else
		print(string.format("[PalmVille Admin] Developer identity verified: %s (%d).", MASTER_USERNAME, MASTER_ID))
	end
	local developer = Players:GetPlayerByUserId(MASTER_ID)
	if developer then
		developer:SetAttribute("PalmVilleAdminRole", "MASTER DEVELOPER")
		remote:FireClient(developer, "AccessGranted", {role = "MASTER DEVELOPER", permissions = rolePermissions["MASTER DEVELOPER"] or {}})
	end
end)

do
-- Consolidated cross-server Players directory; uses the Admin V2 role and permission resolver.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local MS = game:GetService("MemoryStoreService")
local TS = game:GetService("TeleportService")
local Messaging = game:GetService("MessagingService")
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
local prefix = Run:IsStudio() and "PalmVillePlayers_Test_v1" or "PalmVillePlayers_v1"
local map = coordinationMap(prefix .. "_servers")
local tickets = coordinationMap(prefix .. "_moves")
local job = game.JobId ~= "" and game.JobId or Http:GenerateGUID(false)
local topic = prefix .. "_commands"
local remote = RS:FindFirstChild("PalmVillePlayersDirectory")
if remote and not remote:IsA("RemoteFunction") then
	error("PalmVillePlayersDirectory exists but is not a RemoteFunction.")
end
if not remote then
	remote = Instance.new("RemoteFunction")
	remote.Name = "PalmVillePlayersDirectory"
	remote.Parent = RS
end
local began, cache, arrivals, rates, pendingMoves = {}, {}, {}, {}, {}
local subscription, stopping = nil, false
local directoryRanks = {OWNER=100,["MASTER DEVELOPER"]=90,["HEAD ADMIN"]=80,ADMIN=60,MODERATOR=40,HELPER=20}
local function roleOf(uid)
	return getRoleById(uid)
end
local function allowed(uid)
	local resolvedRole = roleOf(uid)
	if resolvedRole == "OWNER" or resolvedRole == "MASTER DEVELOPER" then return true end
	local current = resolvedRole and rolePermissions[resolvedRole]
	return current ~= nil and current.Players == true
end
local function directoryCanAffect(actorId, targetId)
	if actorId == targetId then return false end
	local actorRole = roleOf(actorId)
	local targetRole = roleOf(targetId)
	return actorRole ~= nil and (directoryRanks[actorRole] or 0) > (directoryRanks[targetRole] or 0)
end
local function notice(targetPlayer, message)
	notify(targetPlayer, message)
end
local function route()
	if game.PrivateServerId ~= "" then
		return {kind = game.PrivateServerOwnerId > 0 and "vip" or "reserved", id = game.PrivateServerId}
	end
	return {kind = "public", id = game.JobId}
end
local function numeric(v)
	return type(v) == "number" and v == v and v >= 0 and v < math.huge and v or nil
end
-- Optional PalmVilleAdminPlayerData adapter: money=current balance; earnedToday=gross earnings
-- since midnight PHT, including money already spent. Missing values stay unavailable.
local function localRows()
	local rows = {}
	local adapter = SSS:FindFirstChild("PalmVilleAdminPlayerData")
	for _, p in ipairs(Players:GetPlayers()) do
		began[p.UserId] = began[p.UserId] or os.time()
		local progress = {}
		if adapter and adapter:IsA("BindableFunction") then
			local ok, data = pcall(function() return adapter:Invoke(p) end)
			if ok and type(data) == "table" then
				for _, key in ipairs({"money","earnedToday","level","xp","xpNeeded","totalPlaytime"}) do progress[key] = numeric(data[key]) end
			end
		end
		table.insert(rows,{userId=p.UserId,username=p.Name,displayName=p.DisplayName,role=roleOf(p.UserId),
			joinedAt=began[p.UserId],jobId=job,placeId=game.PlaceId,serverLabel="Server "..job:sub(1,6),progress=progress})
	end
	return rows
end
local function localEntry()
	return {time=os.time(),rows=localRows(),placeId=game.PlaceId,jobId=job,route=route(),capacity=Players.MaxPlayers}
end
local function refresh()
	local own = localEntry()
	map:SetAsync(job, own, 60)
	local entries = {[job]=own}
	local pages = map:ListItemsAsync(100)
	while true do
		for _, item in ipairs(pages:GetCurrentPage()) do
			if item.key ~= job and item.value and os.time()-item.value.time <= 45 then entries[item.key]=item.value end
		end
		if pages.IsFinished then break end
		pages:AdvanceToNextPageAsync()
	end
	cache=entries
end
local function findTarget(uid)
	local p=Players:GetPlayerByUserId(uid)
	if p then
		local own=localEntry()
		for _, row in ipairs(own.rows) do if row.userId==uid then return row,own end end
	end
	for _, entry in pairs(cache) do
		if os.time()-entry.time<=45 then
			for _, row in ipairs(entry.rows) do if row.userId==uid then return row,entry end end
		end
	end
	return nil
end
local function packed(cf) return {cf:GetComponents()} end
local function destination(p)
	return {jobId=job,placeId=game.PlaceId,route=route(),cf=p.Character and packed(p.Character:GetPivot())}
end
local function optionsFor(dest)
	local opts=Instance.new("TeleportOptions")
	if dest.route.kind=="vip" then opts.VipServerId=dest.route.id
	elseif dest.route.kind=="reserved" then opts.ReservedServerId=dest.route.id
	else opts.ServerInstanceId=dest.jobId end
	return opts
end
local function move(p, dest, mode, targetId, actorId)
	if Run:IsStudio() then return false,"Cross-server travel must be tested in the published Roblox game." end
	tickets:SetAsync("arrival_"..p.UserId,{destination=dest,mode=mode,targetId=targetId,created=os.time()},120)
	pendingMoves[p.UserId]={actorId=actorId or p.UserId}
	local ok,err=pcall(function() TS:TeleportAsync(dest.placeId,{p},optionsFor(dest)) end)
	if not ok then
		pendingMoves[p.UserId]=nil
		tickets:RemoveAsync("arrival_"..p.UserId)
		return false,"Teleport failed: "..tostring(err)
	end
	return true,"Joining destination server..."
end
local function execute(actorId,targetId,action,dest)
	if not allowed(actorId) or not directoryCanAffect(actorId,targetId) then return false,"Player is protected or access was revoked." end
	local target=Players:GetPlayerByUserId(targetId)
	if not target then return false,"Player moved or left. Refresh the list." end
	if action=="Reset" then target:LoadCharacterAsync(); return true,"Character reset." end
	if action=="Bring" then
		if not target.Character then return false,"Character is not ready." end
		if dest.jobId==job then
			local actor=Players:GetPlayerByUserId(actorId)
			if not actor or not actor.Character then return false,"Admin character is not ready." end
			tickets:SetAsync("return_"..targetId,destination(target),3600)
			target.Character:PivotTo(actor.Character:GetPivot()*CFrame.new(4,0,0))
			return true,"Player brought to you."
		end
		tickets:SetAsync("return_"..targetId,destination(target),3600)
		return move(target,dest,"Bring",actorId,actorId)
	elseif action=="Return" then
		local saved=tickets:GetAsync("return_"..targetId)
		if not saved then return false,"No Bring return position saved (expires after 1 hour)." end
		if saved.jobId==job then
			if not target.Character or not saved.cf then return false,"Return position unavailable." end
			target.Character:PivotTo(CFrame.new(table.unpack(saved.cf)))
			tickets:RemoveAsync("return_"..targetId)
			return true,"Player returned."
		end
		return move(target,saved,"Return",nil,actorId)
	end
	return false,"Unknown action."
end
local function notifyResult(actorId,text)
	local actor=Players:GetPlayerByUserId(actorId)
	if actor then notice(actor,text) end
end
local function processMessage(message)
	local data=message.Data
	if type(data)~="table" then return end
	if data.kind=="Result" then notifyResult(data.actorId,tostring(data.text)); return end
	if data.kind~="Command" or data.jobId~=job or type(data.token)~="string" then return end
	local request=tickets:GetAsync("command_"..data.token)
	if not request or request.jobId~=job or request.claimed then return end
	local claim=Http:GenerateGUID(false)
	local locked=tickets:UpdateAsync("command_"..data.token,function(old)
		if old and not old.claimed then old.claimed=claim end
		return old
	end,60)
	if not locked or locked.claimed~=claim then return end
	local ok,success,text=pcall(execute,request.actorId,request.targetId,request.action,request.destination)
	if not ok then text="Player action failed: "..tostring(success) end
	Messaging:PublishAsync(topic,{kind="Result",actorId=request.actorId,text=text})
end
local function subscribe()
	if Run:IsStudio() or subscription then return end
	local ok,conn=pcall(function()
		return Messaging:SubscribeAsync(topic,function(message)
			task.spawn(function()
				local good,err=pcall(processMessage,message)
				if not good then warn("PalmVille Players command: "..tostring(err)) end
			end)
		end)
	end)
	if ok then subscription=conn end
end
local function actionRequest(actor, uid, action)
	if not directoryCanAffect(actor.UserId,uid) then return {ok=false,message="Select another player with a lower staff rank."} end
	local row,entry=findTarget(uid)
	if not row then return {ok=false,message="Player unavailable. Refresh the list."} end
	if action=="Go" or action=="Spectate" then
		local target=Players:GetPlayerByUserId(uid)
		if target then
			if action=="Spectate" then return {ok=true,localSpectate=uid,username=row.username} end
			if not actor.Character or not target.Character then return {ok=false,message="Character is not ready."} end
			actor.Character:PivotTo(target.Character:GetPivot()*CFrame.new(0,0,4))
			return {ok=true,message="Teleported to player."}
		end
		if #entry.rows>=entry.capacity then return {ok=false,message="Target server is full."} end
		local ok,text=move(actor,{jobId=entry.jobId,placeId=entry.placeId,route=entry.route},action,uid)
		return {ok=ok,message=text}
	end
	if action=="Bring" and not Players:GetPlayerByUserId(uid) and #Players:GetPlayers()>=Players.MaxPlayers then
		return {ok=false,message="Your server is full."}
	end
	if Players:GetPlayerByUserId(uid) then
		local ok,text=execute(actor.UserId,uid,action,destination(actor))
		return {ok=ok,message=text}
	end
	if not subscription then return {ok=false,message="Cross-server commands unavailable. Check Output."} end
	local token=Http:GenerateGUID(false)
	tickets:SetAsync("command_"..token,{actorId=actor.UserId,targetId=uid,action=action,
		destination=destination(actor),jobId=entry.jobId},60)
	Messaging:PublishAsync(topic,{kind="Command",jobId=entry.jobId,token=token})
	return {ok=true,message="Request sent to player's server. A result will follow."}
end
remote.OnServerInvoke=function(actor,kind,data)
	if type(kind)~="string" then return {ok=false} end
	local rateKey=actor.UserId..":"..kind
	local interval=kind=="List" and 3 or 1
	if os.clock()<(rates[rateKey] or 0) then return {ok=false,message="Please wait a moment."} end
	rates[rateKey]=os.clock()+interval
	if not allowed(actor.UserId) then return {ok=false,message="Players permission required."} end
	local ok,result=pcall(function()
		if kind=="Resume" then
			local uid=arrivals[actor.UserId]
			arrivals[actor.UserId]=nil
			if uid and directoryCanAffect(actor.UserId,uid) then
				local p=Players:GetPlayerByUserId(uid)
				return {ok=true,localSpectate=p and uid,username=p and p.Name}
			end
			return {ok=true}
		elseif kind=="List" then
			local unique={}
			for _,entry in pairs(cache) do
				if os.time()-entry.time<=45 then for _,row in ipairs(entry.rows) do unique[row.userId]=row end end
			end
			for _,row in ipairs(localRows()) do unique[row.userId]=row end
			local rows={}
			for _,row in pairs(unique) do table.insert(rows,row) end
			table.sort(rows,function(a,b)return a.username:lower()<b.username:lower() end)
			return {ok=true,players=rows,jobId=job,updatedAt=os.time()}
		elseif kind=="Action" then
			if type(data)~="table" or type(data.userId)~="number" or data.userId%1~=0 then return {ok=false,message="Select a player."} end
			if not table.find({"Go","Bring","Spectate","Reset","Return"},data.action) then return {ok=false,message="Unknown action."} end
			return actionRequest(actor,data.userId,data.action)
		end
		return {ok=false,message="Unknown request."}
	end)
	if not ok then warn("PalmVille Players: "..tostring(result));return {ok=false,message="Service unavailable. Check Output."} end
	return result
end
-- Apply arrival tickets after characters are ready; teleport hints from clients are never trusted.
local function applyArrival(p)
	local ok,ticket=pcall(function()return tickets:GetAsync("arrival_"..p.UserId)end)
	if not ok or not ticket then return end
	if ticket.destination.jobId~=job then notice(p,"Destination server changed; action cancelled.");return end
	local character=p.Character or p.CharacterAdded:Wait()
	local root=character:WaitForChild("HumanoidRootPart",15)
	if not root then return end
	tickets:RemoveAsync("arrival_"..p.UserId)
	if ticket.mode=="Go" or ticket.mode=="Spectate" or ticket.mode=="Bring" then
		if ticket.mode=="Bring" then
			if not allowed(ticket.targetId) or not directoryCanAffect(ticket.targetId,p.UserId) then notice(p,"Bring permission revoked; arrival action cancelled.");return end
		elseif not allowed(p.UserId) or not directoryCanAffect(p.UserId,ticket.targetId) then
			notice(p,"Admin access changed; arrival action cancelled.");return
		end
		local target=Players:GetPlayerByUserId(ticket.targetId or 0)
		if not target or not target.Character then notice(p,"Target player left before arrival.");return end
		character:PivotTo(target.Character:GetPivot()*CFrame.new(4,0,0))
		if ticket.mode=="Spectate" then arrivals[p.UserId]=target.UserId end
	elseif ticket.mode=="Return" and ticket.destination.cf then
		character:PivotTo(CFrame.new(table.unpack(ticket.destination.cf)))
		tickets:RemoveAsync("return_"..p.UserId)
	end
end
Players.PlayerAdded:Connect(function(p)began[p.UserId]=os.time();task.spawn(applyArrival,p)end)
Players.PlayerRemoving:Connect(function(p)began[p.UserId]=nil;arrivals[p.UserId]=nil;pendingMoves[p.UserId]=nil
	for _,kind in ipairs({"List","Resume","Action"}) do rates[p.UserId..":"..kind]=nil end
end)
for _,p in ipairs(Players:GetPlayers()) do began[p.UserId]=os.time();task.spawn(applyArrival,p)end
TS.TeleportInitFailed:Connect(function(p,_,message)
	if pendingMoves[p.UserId] then
		local actorId=pendingMoves[p.UserId].actorId
		pendingMoves[p.UserId]=nil
		pcall(function()tickets:RemoveAsync("arrival_"..p.UserId)end)
		notice(p,"Teleport failed: "..tostring(message))
		if actorId~=p.UserId then
			pcall(function()Messaging:PublishAsync(topic,{kind="Result",actorId=actorId,text="Player teleport failed: "..tostring(message)})end)
		end
	end
end)
task.spawn(function()
	local retryDelay = 15
	while not stopping do
		subscribe()
		local ok,err=pcall(refresh)
		if not ok then
			retryDelay=math.min(retryDelay*2,120)
			warn("PalmVille Players directory: "..tostring(err))
		else retryDelay=15 end
		task.wait(retryDelay)
	end
end)
game:BindToClose(function()stopping=true;pcall(function()map:RemoveAsync(job)end)end)
end

do
-- Consolidated overview analytics collector; preserves existing DataStore and MemoryStore keys.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
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
local store = tryGetDataStore(PREFIX)
if not store then
	local memoryValues = {}
	store = {}
	function store:GetAsync(key) return memoryValues[key] end
	function store:SetAsync(key, value) memoryValues[key] = value; return value end
	function store:UpdateAsync(key, transform)
		local value = transform(memoryValues[key])
		if value ~= nil then memoryValues[key] = value end
		return value
	end
end
local servers = coordinationMap(PREFIX .. "_servers")
local shared = coordinationMap(PREFIX .. "_shared")
local job = game.JobId ~= "" and game.JobId or Http:GenerateGUID(false)
local remote = RS:FindFirstChild("PalmVilleOverviewAnalytics")
if remote and not remote:IsA("RemoteFunction") then
	error("PalmVilleOverviewAnalytics exists but is not a RemoteFunction.")
end
if not remote then
	remote = Instance.new("RemoteFunction")
	remote.Name = "PalmVilleOverviewAnalytics"
	remote.Parent = RS
end
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
	local role = getRoleById(player.UserId)
	if not role or (not hasPermission(player, "Monitoring") and not hasPermission(player, "Server")) then return nil end
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
end
