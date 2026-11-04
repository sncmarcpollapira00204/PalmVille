local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")

local REMOTE = ReplicatedStorage:WaitForChild("PalmVilleAdminRemote")
local OWNER_USERNAME = "lupiners0"
local OWNER_USER_ID = nil

-- Resolve the username to a numeric UserId before accepting access requests.
local lookupOK, lookupResult = pcall(function()
    return Players:GetUserIdFromNameAsync(OWNER_USERNAME)
end)
if lookupOK then
    OWNER_USER_ID = lookupResult
    print("[PalmVille Admin] Owner verified:", OWNER_USERNAME, OWNER_USER_ID)
else
    warn("[PalmVille Admin] Could not resolve owner username. Check OWNER_USERNAME and Studio internet access.")
end

local frozen = {}
local boosted = {}

local function isOwner(player)
    return OWNER_USER_ID ~= nil and player.UserId == OWNER_USER_ID
end

local function notify(player, message)
    REMOTE:FireClient(player, "Notice", tostring(message))
end

local function getPlayerByUserId(userId)
    userId = tonumber(userId)
    if not userId then return nil end
    for _, candidate in ipairs(Players:GetPlayers()) do
        if candidate.UserId == userId then return candidate end
    end
    return nil
end

local function getCharacter(player)
    return player and player.Character
end

local function getHumanoid(player)
    local character = getCharacter(player)
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function findStat(player, names)
    local containers = {}
    for _, containerName in ipairs({"leaderstats", "Data", "Stats"}) do
        local container = player:FindFirstChild(containerName)
        if container then table.insert(containers, container) end
    end
    for _, container in ipairs(containers) do
        if container then
            for _, name in ipairs(names) do
                local value = container:FindFirstChild(name)
                if value and (value:IsA("IntValue") or value:IsA("NumberValue")) then
                    return value
                end
            end
        end
    end
    return nil
end

local function makeFireworks(player)
    local character = getCharacter(player)
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    local anchor = Instance.new("Part")
    anchor.Name = "PalmVilleAdminFirework"
    anchor.Anchored = true
    anchor.CanCollide = false
    anchor.CanTouch = false
    anchor.CanQuery = false
    anchor.Transparency = 1
    anchor.Size = Vector3.new(1, 1, 1)
    anchor.Position = root.Position + Vector3.new(0, 9, 0)
    anchor.Parent = workspace

    local attachment = Instance.new("Attachment")
    attachment.Parent = anchor

    local emitter = Instance.new("ParticleEmitter")
    emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    emitter.Rate = 0
    emitter.Lifetime = NumberRange.new(1.1, 1.8)
    emitter.Speed = NumberRange.new(15, 27)
    emitter.SpreadAngle = Vector2.new(180, 180)
    emitter.RotSpeed = NumberRange.new(-120, 120)
    emitter.LightEmission = 0.8
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.45),
        NumberSequenceKeypoint.new(1, 0)
    })
    emitter.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 205, 80)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 90, 75)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 190, 255))
    })
    emitter.Parent = attachment
    emitter:Emit(85)
    Debris:AddItem(anchor, 3)
    return true
end

REMOTE.OnServerEvent:Connect(function(player, action, data)
    data = typeof(data) == "table" and data or {}

    if action == "RequestAccess" then
        if isOwner(player) then
            REMOTE:FireClient(player, "AccessGranted")
        end
        return
    end

    -- All administrative actions are checked on the server.
    if not isOwner(player) then
        warn("[PalmVille Admin] Blocked unauthorized request from", player.Name, action)
        return
    end

    local target = getPlayerByUserId(data.targetUserId)
    local adminCharacter = getCharacter(player)
    local adminRoot = adminCharacter and adminCharacter:FindFirstChild("HumanoidRootPart")

    if action == "Teleport" then
        local targetCharacter = getCharacter(target)
        if not adminRoot or not targetCharacter then notify(player, "Player character not available."); return end
        adminCharacter:PivotTo(targetCharacter:GetPivot() * CFrame.new(0, 0, 4))
        notify(player, "Teleported to " .. target.Name .. ".")

    elseif action == "Bring" then
        local targetCharacter = getCharacter(target)
        if not adminRoot or not targetCharacter then notify(player, "Player character not available."); return end
        targetCharacter:PivotTo(adminCharacter:GetPivot() * CFrame.new(4, 0, 0))
        notify(player, "Brought " .. target.Name .. ".")

    elseif action == "Freeze" then
        if not target then notify(player, "Select a player first."); return end
        local humanoid = getHumanoid(target)
        if not humanoid then notify(player, "Target character not available."); return end
        if frozen[target.UserId] then
            local saved = frozen[target.UserId]
            humanoid.WalkSpeed = saved.WalkSpeed
            humanoid.UseJumpPower = saved.UseJumpPower
            if saved.UseJumpPower then humanoid.JumpPower = saved.JumpPower else humanoid.JumpHeight = saved.JumpHeight end
            humanoid.AutoRotate = saved.AutoRotate
            frozen[target.UserId] = nil
            notify(player, "Unfroze " .. target.Name .. ".")
        else
            frozen[target.UserId] = {
                WalkSpeed = humanoid.WalkSpeed,
                JumpPower = humanoid.JumpPower,
                JumpHeight = humanoid.JumpHeight,
                UseJumpPower = humanoid.UseJumpPower,
                AutoRotate = humanoid.AutoRotate
            }
            humanoid.WalkSpeed = 0
            if humanoid.UseJumpPower then humanoid.JumpPower = 0 else humanoid.JumpHeight = 0 end
            humanoid.AutoRotate = false
            notify(player, "Froze " .. target.Name .. ".")
        end

    elseif action == "Kick" then
        if not target then notify(player, "Select a player first."); return end
        if target == player then notify(player, "You cannot kick yourself."); return end
        target:Kick("Removed by a Palm Ville moderator.")
        notify(player, "Kicked " .. target.Name .. ".")

    elseif action == "GiveCoins" or action == "GiveSeeds" then
        if not target then notify(player, "Select a player first."); return end
        local amount = math.floor(tonumber(data.amount) or 0)
        if amount < 1 then notify(player, "Enter an amount greater than zero."); return end
        amount = math.clamp(amount, 1, 1000000)
        local stat
        if action == "GiveCoins" then
            stat = findStat(target, {"Coins", "Coin", "Cash", "Money"})
        else
            stat = findStat(target, {"Seeds", "Seed"})
        end
        if not stat then
            local expected = action == "GiveCoins" and "Coins/Cash/Money" or "Seeds"
            notify(player, "Could not find a " .. expected .. " value for " .. target.Name .. ". We need to connect your actual data system.")
            return
        end
        stat.Value += amount
        notify(player, "Added " .. amount .. " to " .. target.Name .. ".")

    elseif action == "SetDay" then
        Lighting.ClockTime = 14
        notify(player, "World time set to daytime.")

    elseif action == "SetNight" then
        Lighting.ClockTime = 0
        notify(player, "World time set to nighttime.")

    elseif action == "SetDefaultTime" then
        Lighting.ClockTime = 14
        notify(player, "World time reset to 2 PM.")

    elseif action == "Fly" then
        REMOTE:FireClient(player, "SetFly", data.enabled == true)
        notify(player, data.enabled and "Fly enabled. Use WASD, Space, and Ctrl." or "Fly disabled.")

    elseif action == "Speed" or action == "Jump" then
        local humanoid = getHumanoid(player)
        if not humanoid then notify(player, "Your character is not ready."); return end
        boosted[action] = boosted[action] ~= true
        if action == "Speed" then
            humanoid.WalkSpeed = boosted[action] and 30 or 16
            notify(player, boosted[action] and "Super speed enabled." or "Speed reset.")
        else
            humanoid.UseJumpPower = true
            humanoid.JumpPower = boosted[action] and 85 or 50
            notify(player, boosted[action] and "Super jump enabled." or "Jump reset.")
        end

    elseif action == "Fireworks" then
        if makeFireworks(player) then notify(player, "Fireworks launched!") else notify(player, "Your character is not ready.") end

    elseif action == "Announce" then
        local message = tostring(data.message or ""):sub(1, 180)
        if message:gsub("%s", "") == "" then notify(player, "Type an announcement first."); return end
        REMOTE:FireAllClients("Announcement", message)
        notify(player, "Announcement sent.")
    end
end)

Players.PlayerRemoving:Connect(function(player)
    frozen[player.UserId] = nil
end)

print("[PalmVille Admin] Server system loaded. Owner:", OWNER_USERNAME)
