local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local MAX_DISTANCE = 12
local REQUEST_TIMEOUT = 12
local REQUEST_COOLDOWN = 3
local CARRY_OFFSET = CFrame.new(0, 0.85, 0.95)

local remote = ReplicatedStorage:FindFirstChild("PalmVillePiggybackEvent")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "PalmVillePiggybackEvent"
	remote.Parent = ReplicatedStorage
end

local pendingByTarget = {}
local carrying = {}
local carriedBy = {}
local carryRecords = {}
local lastRequestAt = {}

local function notify(player, message)
	if player and player.Parent == Players then
		remote:FireClient(player, "Notice", message)
	end
end

local function getLivingCharacter(player)
	local character = player and player.Character
	if not character then return nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then return nil end
	return character, humanoid, root
end

local function restoreCarriedPlayer(target)
	local record = carryRecords[target]
	if not record then return end
	carryRecords[target] = nil

	if record.weld and record.weld.Parent then
		record.weld:Destroy()
	end

	local character = target.Character
	if character then
		for part, properties in pairs(record.parts) do
			if part and part.Parent then
				part.CanCollide = properties.CanCollide
				part.Massless = properties.Massless
			end
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			pcall(function() root:SetNetworkOwnershipAuto() end)
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = record.WalkSpeed
			humanoid.JumpPower = record.JumpPower
			humanoid.JumpHeight = record.JumpHeight
			humanoid.AutoRotate = record.AutoRotate
			humanoid.PlatformStand = record.PlatformStand
			humanoid.Sit = false
			if humanoid.Health > 0 then
				humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
		end
	end
end

local function releaseCarry(carrier, reason)
	local target = carrying[carrier]
	if not target then return end
	carrying[carrier] = nil
	carriedBy[target] = nil
	restoreCarriedPlayer(target)
	notify(carrier, reason or "Piggyback ended.")
	notify(target, reason or "Piggyback ended.")
end

local function releaseIfCarried(player, reason)
	local carrier = carriedBy[player]
	if carrier then
		releaseCarry(carrier, reason)
	end
end

local function findNearestPlayer(requester)
	local _, _, requesterRoot = getLivingCharacter(requester)
	if not requesterRoot then return nil end

	local nearest, nearestDistance
	for _, candidate in ipairs(Players:GetPlayers()) do
		if candidate ~= requester and not carriedBy[candidate] and not carrying[candidate] then
			local _, _, candidateRoot = getLivingCharacter(candidate)
			if candidateRoot then
				local distance = (candidateRoot.Position - requesterRoot.Position).Magnitude
				if distance <= MAX_DISTANCE and (not nearestDistance or distance < nearestDistance) then
					nearest = candidate
					nearestDistance = distance
				end
			end
		end
	end
	return nearest, nearestDistance
end

local function beginCarry(carrier, target)
	local carrierCharacter, carrierHumanoid, carrierRoot = getLivingCharacter(carrier)
	local targetCharacter, targetHumanoid, targetRoot = getLivingCharacter(target)
	if not carrierRoot or not targetRoot then
		return false, "Both players must be alive to piggyback."
	end
	if (carrierRoot.Position - targetRoot.Position).Magnitude > MAX_DISTANCE then
		return false, "That player is too far away now."
	end
	if carrying[carrier] or carriedBy[carrier] or carrying[target] or carriedBy[target] then
		return false, "One of the players is already in a piggyback."
	end

	local parts = {}
	for _, descendant in ipairs(targetCharacter:GetDescendants()) do
		if descendant:IsA("BasePart") then
			parts[descendant] = {
				CanCollide = descendant.CanCollide,
				Massless = descendant.Massless,
			}
			descendant.CanCollide = false
			descendant.Massless = true
		end
	end

	local record = {
		parts = parts,
		WalkSpeed = targetHumanoid.WalkSpeed,
		JumpPower = targetHumanoid.JumpPower,
		JumpHeight = targetHumanoid.JumpHeight,
		AutoRotate = targetHumanoid.AutoRotate,
		PlatformStand = targetHumanoid.PlatformStand,
	}
	carryRecords[target] = record

	targetRoot.CFrame = carrierRoot.CFrame * CARRY_OFFSET
	targetHumanoid.WalkSpeed = 0
	targetHumanoid.JumpPower = 0
	targetHumanoid.JumpHeight = 0
	targetHumanoid.AutoRotate = false
	targetHumanoid.PlatformStand = false
	targetHumanoid.Sit = false
	targetHumanoid:ChangeState(Enum.HumanoidStateType.Physics)
	pcall(function() targetRoot:SetNetworkOwner(nil) end)

	local weld = Instance.new("WeldConstraint")
	weld.Name = "PalmVillePiggybackWeld"
	weld.Part0 = carrierRoot
	weld.Part1 = targetRoot
	weld.Parent = carrierRoot
	record.weld = weld

	carrying[carrier] = target
	carriedBy[target] = carrier
	notify(carrier, "You are carrying " .. target.DisplayName .. ". Type /buhatkita again to stop.")
	notify(target, carrier.DisplayName .. " is giving you a piggyback ride.")
	return true
end

local function requestPiggyback(requester)
	if carrying[requester] then
		releaseCarry(requester, "You ended the piggyback.")
		return
	end
	if carriedBy[requester] then
		notify(requester, "You are already being carried.")
		return
	end

	local now = os.clock()
	if now - (lastRequestAt[requester] or 0) < REQUEST_COOLDOWN then
		return
	end
	lastRequestAt[requester] = now

	local target = findNearestPlayer(requester)
	if not target then
		notify(requester, "No available player nearby. Move within " .. MAX_DISTANCE .. " studs.")
		return
	end
	if pendingByTarget[target] then
		notify(requester, "That player already has a pending piggyback request.")
		return
	end

	local requestId = tostring(requester.UserId) .. ":" .. tostring(target.UserId) .. ":" .. tostring(math.floor(now * 1000))
	pendingByTarget[target] = {requester = requester, id = requestId, expiresAt = now + REQUEST_TIMEOUT}
	remote:FireClient(target, "Request", requester.UserId, requester.DisplayName, requestId)
	notify(requester, "Piggyback request sent to " .. target.DisplayName .. ".")

	task.delay(REQUEST_TIMEOUT, function()
		local pending = pendingByTarget[target]
		if pending and pending.id == requestId then
			pendingByTarget[target] = nil
			notify(requester, "Piggyback request expired.")
			notify(target, "Piggyback request expired.")
		end
	end)
end

remote.OnServerEvent:Connect(function(target, action, requesterUserId, accepted, requestId)
	if action ~= "Respond" then return end
	local pending = pendingByTarget[target]
	if not pending or pending.id ~= requestId then
		notify(target, "This piggyback request is no longer available.")
		return
	end
	if pending.requester.UserId ~= tonumber(requesterUserId) or os.clock() > pending.expiresAt then
		pendingByTarget[target] = nil
		notify(target, "This piggyback request has expired.")
		return
	end
	pendingByTarget[target] = nil

	local requester = pending.requester
	if not requester or requester.Parent ~= Players then
		notify(target, "That player is no longer here.")
		return
	end
	if accepted ~= true then
		notify(requester, target.DisplayName .. " declined your piggyback request.")
		notify(target, "You declined the piggyback request.")
		return
	end

	local ok, message = beginCarry(requester, target)
	if not ok then
		notify(requester, message)
		notify(target, message)
	end
end)

local command = TextChatService:FindFirstChild("PalmVillePiggybackCommand")
if not command then
	command = Instance.new("TextChatCommand")
	command.Name = "PalmVillePiggybackCommand"
	command.PrimaryAlias = "/buhatkita"
	command.Parent = TextChatService
end
command.Triggered:Connect(function(textSource)
	local requester = textSource and Players:GetPlayerByUserId(textSource.UserId)
	if requester then requestPiggyback(requester) end
end)

local function hookPlayer(player)
	player.CharacterRemoving:Connect(function()
		releaseCarry(player, "Piggyback ended because a character reset.")
		releaseIfCarried(player, "Piggyback ended because a character reset.")
	end)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid then
			humanoid.Died:Connect(function()
				releaseCarry(player, "Piggyback ended.")
				releaseIfCarried(player, "Piggyback ended.")
			end)
		end
	end)
end

Players.PlayerAdded:Connect(hookPlayer)
for _, player in ipairs(Players:GetPlayers()) do hookPlayer(player) end

Players.PlayerRemoving:Connect(function(player)
	local pending = pendingByTarget[player]
	if pending then
		pendingByTarget[player] = nil
		notify(pending.requester, "Piggyback request cancelled because the player left.")
	end
	releaseCarry(player, "Piggyback ended because a player left.")
	releaseIfCarried(player, "Piggyback ended because a player left.")
	lastRequestAt[player] = nil
end)
