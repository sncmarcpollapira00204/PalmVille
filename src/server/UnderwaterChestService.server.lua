local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local FOLDER_NAME = "Underwater Chest"
local CHEST_NAME = "Chest"
local PROMPT_NAME = "UnderwaterChestPrompt"
local FEEDBACK_EVENT_NAME = "UnderwaterChestFeedback"
local INTERACTION_DISTANCE = 10

local REWARDS = {
	{minimum = 1, maximum = 50, amount = 200},
	{minimum = 51, maximum = 90, amount = 150},
	{minimum = 91, maximum = 93, amount = 1500},
}
-- The supplied reward odds total 93%; rolls 94-100 intentionally give no reward.

local random = Random.new()
local claimsByChest = {}
local claimLocks = {}
local registered = setmetatable({}, {__mode = "k"})

local feedback = ReplicatedStorage:FindFirstChild(FEEDBACK_EVENT_NAME)
if feedback and not feedback:IsA("RemoteEvent") then
	warn("[Underwater Chest] ReplicatedStorage." .. FEEDBACK_EVENT_NAME .. " must be a RemoteEvent.")
	return
end
if not feedback then
	feedback = Instance.new("RemoteEvent")
	feedback.Name = FEEDBACK_EVENT_NAME
	feedback.Parent = ReplicatedStorage
end

local function sendFeedback(player, title, message, kind)
	if player and player.Parent == Players then
		feedback:FireClient(player, {
			title = title,
			message = message,
			kind = kind or "normal",
		})
	end
end

local function isInsideChestFolder(instance)
	local current = instance
	while current and current ~= Workspace do
		if current.Name == FOLDER_NAME then
			return true
		end
		current = current.Parent
	end
	return false
end

local function findChestAnchor(chest)
	if chest:IsA("BasePart") then
		return chest
	end
	if not chest:IsA("Model") then
		return nil
	end

	if chest.PrimaryPart then
		return chest.PrimaryPart
	end

	local bestPart
	local bestVolume = -1
	for _, descendant in ipairs(chest:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local size = descendant.Size
			local volume = size.X * size.Y * size.Z
			if volume > bestVolume then
				bestVolume = volume
				bestPart = descendant
			end
		end
	end
	return bestPart
end

local function getChestId(chest)
	local segments = {}
	local current = chest
	while current and current.Name ~= FOLDER_NAME and current ~= Workspace do
		local parent = current.Parent
		local ordinal = 1
		if parent then
			for _, sibling in ipairs(parent:GetChildren()) do
				if sibling == current then
					break
				end
				if sibling.Name == current.Name and sibling.ClassName == current.ClassName then
					ordinal += 1
				end
			end
		end
		table.insert(segments, 1, string.format("%s[%d]", current.Name, ordinal))
		current = parent
	end
	return table.concat(segments, "/")
end

local function getWallet(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local wallet = leaderstats and leaderstats:FindFirstChild("Money")
	if wallet and (wallet:IsA("IntValue") or wallet:IsA("NumberValue")) then
		return wallet
	end

	wallet = player:FindFirstChild("Money")
	if wallet and (wallet:IsA("IntValue") or wallet:IsA("NumberValue")) then
		return wallet
	end

	return nil
end

local function awardMoney(player, amount)
	local adapter = ServerStorage:FindFirstChild("PalmVilleEconomy")
	if adapter and adapter:IsA("ModuleScript") then
		local ok, economy = pcall(require, adapter)
		if ok and type(economy) == "table" and type(economy.AddMoney) == "function" then
			local added, result = pcall(economy.AddMoney, player, amount, "UnderwaterChest")
			if added and result ~= false then
				return true
			end
			if not added then
				warn("[Underwater Chest] PalmVilleEconomy.AddMoney failed: " .. tostring(result))
			end
		elseif not ok then
			warn("[Underwater Chest] Could not load PalmVilleEconomy: " .. tostring(economy))
		end
	end

	local wallet = getWallet(player)
	if not wallet then
		return false
	end

	wallet.Value += amount
	return true
end

local function rollReward()
	local roll = random:NextInteger(1, 100)
	for _, reward in ipairs(REWARDS) do
		if roll >= reward.minimum and roll <= reward.maximum then
			return reward.amount, roll
		end
	end
	return nil, roll
end

local function getCharacterRoot(player)
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

local function getPromptWorldPosition(prompt, anchor)
	if prompt.Parent and prompt.Parent:IsA("Attachment") then
		return prompt.Parent.WorldPosition
	end
	return anchor.Position
end

local function registerChest(chest)
	if registered[chest] or not chest.Parent then
		return
	end
	if chest.Name ~= CHEST_NAME or not (chest:IsA("Model") or chest:IsA("BasePart")) then
		return
	end
	if not isInsideChestFolder(chest) then
		return
	end

	-- Bind only the outermost Chest container, never its nested chest pieces.
	local ancestor = chest.Parent
	while ancestor and ancestor ~= Workspace do
		if ancestor:IsA("Model") and ancestor.Name == CHEST_NAME then
			return
		end
		if ancestor.Name == FOLDER_NAME then
			break
		end
		ancestor = ancestor.Parent
	end

	local anchor = findChestAnchor(chest)
	if not anchor then
		warn("[Underwater Chest] No BasePart found in " .. chest:GetFullName())
		return
	end

	local promptParent = anchor
	local promptAttachment
	if chest:IsA("Model") then
		local existingAttachment = anchor:FindFirstChild("UnderwaterChestPromptAttachment")
		if existingAttachment and existingAttachment:IsA("Attachment") then
			promptAttachment = existingAttachment
		else
			promptAttachment = Instance.new("Attachment")
			promptAttachment.Name = "UnderwaterChestPromptAttachment"
			promptAttachment.Parent = anchor
		end

		local boxCFrame, boxSize = chest:GetBoundingBox()
		local desiredWorldPosition = boxCFrame.Position + Vector3.new(0, math.max(0.5, boxSize.Y * 0.35), 0)
		promptAttachment.Position = anchor.CFrame:PointToObjectSpace(desiredWorldPosition)
		promptParent = promptAttachment
	end

	local prompt = promptParent:FindFirstChild(PROMPT_NAME)
	if prompt and not prompt:IsA("ProximityPrompt") then
		prompt:Destroy()
		prompt = nil
	end
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = PROMPT_NAME
		prompt.Parent = promptParent
	end

	prompt.ActionText = "Claim"
	prompt.ObjectText = "Underwater Chest"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = INTERACTION_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.ClickablePrompt = true
	prompt.Enabled = true

	local chestId = getChestId(chest)
	registered[chest] = true

	prompt.Triggered:Connect(function(player)
		if not player or player.Parent ~= Players then
			return
		end

		local root = getCharacterRoot(player)
		if not root then
			return
		end

		if (root.Position - getPromptWorldPosition(prompt, anchor)).Magnitude > INTERACTION_DISTANCE + 2 then
			return
		end

		local userId = player.UserId
		local lockKey = tostring(userId) .. "|" .. chestId
		if claimLocks[lockKey] then
			return
		end
		claimLocks[lockKey] = true

		local playerClaims = claimsByChest[chestId]
		if playerClaims and playerClaims[userId] then
			sendFeedback(player, "Underwater Chest", "You already claimed this chest.", "warning")
			claimLocks[lockKey] = nil
			return
		end

		local amount = rollReward()
		if amount and not awardMoney(player, amount) then
			sendFeedback(
				player,
				"Underwater Chest",
				"Money wallet not found. Connect leaderstats.Money or ServerStorage.PalmVilleEconomy first.",
				"error"
			)
			claimLocks[lockKey] = nil
			return
		end

		claimsByChest[chestId] = claimsByChest[chestId] or {}
		claimsByChest[chestId][userId] = true
		claimLocks[lockKey] = nil

		if amount then
			local kind = amount == 1500 and "jackpot" or "reward"
			sendFeedback(player, "TREASURE FOUND!", string.format("+₱%s", amount == 1500 and "1,500" or tostring(amount)), kind)
		else
			sendFeedback(player, "UNDERWATER CHEST", "The chest was empty this time. Try another one!", "empty")
		end
	end)
end

local function scanFolder(folder)
	for _, descendant in ipairs(folder:GetDescendants()) do
		if descendant.Name == CHEST_NAME and (descendant:IsA("Model") or descendant:IsA("BasePart")) then
			registerChest(descendant)
		end
	end
end

local function findFolders()
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant.Name == FOLDER_NAME and (descendant:IsA("Folder") or descendant:IsA("Model")) then
			scanFolder(descendant)
		end
	end
end

findFolders()

Workspace.DescendantAdded:Connect(function(instance)
	if instance.Name == FOLDER_NAME and (instance:IsA("Folder") or instance:IsA("Model")) then
		task.defer(scanFolder, instance)
	elseif instance.Name == CHEST_NAME then
		task.defer(registerChest, instance)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId
	for _, claims in pairs(claimsByChest) do
		claims[userId] = nil
	end
	for key in pairs(claimLocks) do
		if string.sub(key, 1, #tostring(userId) + 1) == tostring(userId) .. "|" then
			claimLocks[key] = nil
		end
	end
end)

local boundCount = 0
for _ in pairs(registered) do
	boundCount += 1
end
print(string.format("[Underwater Chest] Ready. Bound %d chest(s). Rewards: ₱200 (50%%), ₱150 (40%%), ₱1,500 (3%%), no reward (7%%).", boundCount))
