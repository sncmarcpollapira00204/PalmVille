-- Add ONE normal Script in ServerScriptService. Keep AdminServerV2 and AnalyticsServer.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local MS = game:GetService("MemoryStoreService")
local DS = game:GetService("DataStoreService")
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
if RS:FindFirstChild("PalmVillePlayersDirectory") then warn("Duplicate Players server script; keep one."); return end
local prefix = Run:IsStudio() and "PalmVillePlayers_Test_v1" or "PalmVillePlayers_v1"
local map = coordinationMap(prefix .. "_servers")
local tickets = coordinationMap(prefix .. "_moves")
local permissionStore = DS:GetDataStore("PalmVilleAdminPermissions_v2")
local job = game.JobId ~= "" and game.JobId or Http:GenerateGUID(false)
local topic = prefix .. "_commands"
local remote = Instance.new("RemoteFunction")
remote.Name = "PalmVillePlayersDirectory"; remote.Parent = RS
local began, cache, arrivals, rates, pendingMoves = {}, {}, {}, {}, {}
local subscription, stopping = nil, false
local ranks = {OWNER=100,["MASTER DEVELOPER"]=90,["HEAD ADMIN"]=80,ADMIN=60,MODERATOR=40,HELPER=20}
local defaults = {["HEAD ADMIN"]={Players=true,Monitoring=true},ADMIN={Players=true,Monitoring=true},MODERATOR={Players=true,Monitoring=true},HELPER={Monitoring=true}}
local function roleOf(uid)
	local resolver = SSS:FindFirstChild("PalmVilleGetAdminRole")
	if not resolver then return nil end
	local ok, value = pcall(function() return resolver:Invoke(uid) end)
	return ok and value or nil
end
local function allowed(uid)
	local role = roleOf(uid)
	if role == "OWNER" or role == "MASTER DEVELOPER" then return true end
	if not role then return false end
	local ok, overrides = pcall(function() return permissionStore:GetAsync("areas") end)
	if not ok then return false end -- Fail closed when permissions cannot be checked.
	local entry = type(overrides) == "table" and overrides[role]
	if entry and type(entry.Players) == "boolean" then return entry.Players end
	return defaults[role] and defaults[role].Players == true
end
local function canAffect(actorId, targetId)
	if actorId == targetId then return false end
	local actor = roleOf(actorId)
	local target = roleOf(targetId)
	return actor ~= nil and (ranks[actor] or 0) > (ranks[target] or 0)
end
local function notice(player, text)
	local adminRemote = RS:FindFirstChild("PalmVilleAdminRemote")
	if player and player.Parent == Players and adminRemote then adminRemote:FireClient(player, "Notice", text) end
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
	if not allowed(actorId) or not canAffect(actorId,targetId) then return false,"Player is protected or access was revoked." end
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
	if not canAffect(actor.UserId,uid) then return {ok=false,message="Select another player with a lower staff rank."} end
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
			if uid and canAffect(actor.UserId,uid) then
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
			if not allowed(ticket.targetId) or not canAffect(ticket.targetId,p.UserId) then notice(p,"Bring permission revoked; arrival action cancelled.");return end
		elseif not allowed(p.UserId) or not canAffect(p.UserId,ticket.targetId) then
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
