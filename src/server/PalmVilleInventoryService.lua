local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Economy = require(ServerScriptService:WaitForChild("PalmVilleEconomy"))
local ItemRegistry = require(ServerScriptService:WaitForChild("PalmVilleItemRegistry"))

local InventoryService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local inventorySnapshot = ReplicatedStorage:FindFirstChild("PalmVilleGetInventory")
if not inventorySnapshot then
	inventorySnapshot = Instance.new("RemoteFunction")
	inventorySnapshot.Name = "PalmVilleGetInventory"
	inventorySnapshot.Parent = ReplicatedStorage
end

local function buildSnapshot(player)
	local profile = Economy.GetProfile(player)
	if not profile then return nil end

	local items = {}
	local function addEntries(source, category, registryCategory)
		if type(source) ~= "table" then return end
		for code, rawValue in pairs(source) do
			local amount = type(rawValue) == "table"
				and math.floor(tonumber(rawValue.amount or rawValue.count or rawValue.quantity) or 0)
				or math.floor(tonumber(rawValue) or 0)
			if amount > 0 then
				local definition = ItemRegistry[code]
				if not registryCategory or (definition and definition.inventoryCategory == registryCategory) then
					local displayName = definition and definition.displayName
						or (type(rawValue) == "table" and (rawValue.displayName or rawValue.name))
						or tostring(code):gsub("_", " ")
					local icon = nil
					if definition and definition.template then
						local handle = definition.template:FindFirstChild("Handle")
						local decal = handle and handle:FindFirstChildWhichIsA("Decal")
						icon = decal and decal.Texture or nil
					end
					table.insert(items, {
						code = tostring(code),
						name = tostring(displayName),
						amount = math.clamp(amount, 1, 999999),
						category = category,
						icon = icon,
					})
				end
			end
		end
	end

	local inventory = type(profile.inventory) == "table" and profile.inventory or {}
	addEntries(inventory.seedPacks, "Seeds", "seedPacks")
	addEntries(profile.seeds, "Seeds")
	addEntries(inventory.crops, "Crops")
	addEntries(inventory.products, "Product")
	addEntries(inventory.misc, "Misc")
	return {items = items, capacity = 50}
end

inventorySnapshot.OnServerInvoke = function(player)
	if not Economy.IsLoaded(player) then
		return {items = {}, capacity = 50, loaded = false}
	end
	return buildSnapshot(player) or {items = {}, capacity = 50, loaded = false}
end


local MAX_STACK = 999
local ServerScriptService = game:GetService("ServerScriptService")
local auditEvent = ServerScriptService:FindFirstChild("PalmVilleAuditEvent")
if not auditEvent then
	auditEvent = Instance.new("BindableEvent")
	auditEvent.Name = "PalmVilleAuditEvent"
	auditEvent.Parent = ServerScriptService
end

local function getSeedFolder(profile)
	profile.inventory = type(profile.inventory) == "table" and profile.inventory or {}
	profile.inventory.seedPacks = type(profile.inventory.seedPacks) == "table"
		and profile.inventory.seedPacks or {}
	return profile.inventory.seedPacks
end

local function clearSeedTools(container)
	if not container then return end
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Tool") and child:GetAttribute("PalmVilleSeedPack") == true then
			child:Destroy()
		end
	end
end

function InventoryService.SyncPlayer(player)
	local profile = Economy.GetProfile(player)
	if not profile then return false end

	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	if not backpack then return false end

	clearSeedTools(backpack)
	clearSeedTools(player.Character)

	local seedPacks = getSeedFolder(profile)
	for code, rawAmount in pairs(seedPacks) do
		local item = ItemRegistry[code]
		local amount = math.clamp(math.floor(tonumber(rawAmount) or 0), 0, MAX_STACK)
		if item and item.inventoryCategory == "seedPacks" and amount > 0 then
			local tool = item.template:Clone()
			tool.Name = item.displayName .. " x" .. tostring(amount)
			tool:SetAttribute("ItemCode", code)
			tool:SetAttribute("SeedCode", code)
			tool:SetAttribute("StackCount", amount)
			tool.Parent = backpack
		end
	end

	return true
end

function InventoryService.GiveSeedPacks(player, code, amount)
	local item = ItemRegistry[code]
	if not item or item.inventoryCategory ~= "seedPacks" then
		return false, "Seed pack is not registered."
	end
	local profile = Economy.GetProfile(player)
	if not profile then
		return false, "Player data is not loaded."
	end

	local seedPacks = getSeedFolder(profile)
	local current = math.clamp(math.floor(tonumber(seedPacks[code]) or 0), 0, MAX_STACK)
	local addAmount = math.floor(tonumber(amount) or 0)
	if addAmount < 1 or current + addAmount > MAX_STACK then
		return false, "Seed pack stack limit reached."
	end

	seedPacks[code] = current + addAmount
	InventoryService.SyncPlayer(player)
	auditEvent:Fire("Inventory Received", player, {
		itemCode = code,
		amount = addAmount,
		balance = seedPacks[code],
		reason = item.displayName,
	})
	return true, seedPacks[code]
end

function InventoryService.GetSeedPackCount(player, code)
	local profile = Economy.GetProfile(player)
	if not profile then return 0 end
	local seedPacks = getSeedFolder(profile)
	return math.clamp(math.floor(tonumber(seedPacks[code]) or 0), 0, MAX_STACK)
end

return InventoryService
