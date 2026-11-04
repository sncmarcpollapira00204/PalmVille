-- LocalScript: StarterPlayer > StarterPlayerScripts
-- Camera-local deep-ocean lighting. It samples one Terrain voxel every 0.25s,
-- so each player gets a private smooth transition without writing global Lighting.
local TweenService = game:GetService("TweenService")
local Terrain = workspace.Terrain
local WATER_SURFACE_Y = 28 -- measured from the existing Terrain water volume
local POLL_INTERVAL = 0.25
local GRADE_NAME = "UnderwaterColorGrade"
local RAYS_NAME = "UnderwaterSunRays"
local HAZE_NAME = "UnderwaterDepthHaze"

local activeCamera
local grade
local rays
local haze
local lastTarget
local activeTweens = {}

local function colorClose(a, b)
    local dr = a.R - b.R
    local dg = a.G - b.G
    local db = a.B - b.B
    return dr * dr + dg * dg + db * db < 0.000225
end

local function cancelTween(key)
    local tween = activeTweens[key]
    if tween then
        activeTweens[key] = nil
        tween:Cancel()
    end
end

local function tweenProperties(key, instance, properties, enableNow, disableAfter)
    if enableNow then
        instance.Enabled = true
    elseif not instance.Enabled then
        return
    end

    cancelTween(key)
    local tween = TweenService:Create(
        instance,
        TweenInfo.new(0.75, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
        properties
    )
    activeTweens[key] = tween
    tween.Completed:Connect(function(playbackState)
        if activeTweens[key] ~= tween then
            return
        end
        activeTweens[key] = nil
        if playbackState == Enum.PlaybackState.Completed and disableAfter then
            instance.Enabled = false
        end
    end)
    tween:Play()
end

local function bindCamera(camera)
    if activeCamera == camera then
        return
    end

    if activeCamera then
        for _, key in ipairs({"grade", "rays", "haze"}) do
            cancelTween(key)
        end
        for _, name in ipairs({GRADE_NAME, RAYS_NAME, HAZE_NAME}) do
            local old = activeCamera:FindFirstChild(name)
            if old then
                old:Destroy()
            end
        end
    end

    activeCamera = camera
    grade = camera:FindFirstChild(GRADE_NAME) or Instance.new("ColorCorrectionEffect")
    grade.Name = GRADE_NAME
    grade.Parent = camera
    grade.Enabled = true

    rays = camera:FindFirstChild(RAYS_NAME) or Instance.new("SunRaysEffect")
    rays.Name = RAYS_NAME
    rays.Intensity = 0
    rays.Spread = 0.2
    rays.Parent = camera
    rays.Enabled = false

    haze = camera:FindFirstChild(HAZE_NAME) or Instance.new("BlurEffect")
    haze.Name = HAZE_NAME
    haze.Size = 0
    haze.Parent = camera
    haze.Enabled = false

    lastTarget = nil
end

local function isCameraInTerrainWater(position)
    local cellMin = Vector3.new(
        math.floor(position.X / 4) * 4,
        math.floor(position.Y / 4) * 4,
        math.floor(position.Z / 4) * 4
    )
    local region = Region3.new(cellMin, cellMin + Vector3.new(4, 4, 4))
    local ok, materials, occupancies = pcall(function()
        return Terrain:ReadVoxels(region, 4)
    end)
    if not ok or not materials or not occupancies then
        return false
    end

    for x = 1, materials.Size.X do
        for y = 1, materials.Size.Y do
            for z = 1, materials.Size.Z do
                if materials[x][y][z] == Enum.Material.Water and occupancies[x][y][z] > 0.05 then
                    return true
                end
            end
        end
    end
    return false
end

local function applyGrade(underwater, depth)
    local factor = underwater and math.clamp(depth / 23, 0, 1) or 0
    local target = {
        underwater = underwater,
        Brightness = underwater and (-0.07 - 0.15 * factor) or 0,
        Contrast = underwater and (0.07 + 0.075 * factor) or 0,
        Saturation = underwater and (0.015 - 0.045 * factor) or 0,
        TintColor = underwater and Color3.fromRGB(
            185 - math.floor(38 * factor),
            222 - math.floor(34 * factor),
            244
        ) or Color3.new(1, 1, 1),
        rayIntensity = underwater and (0.045 - 0.033 * factor) or 0,
        hazeSize = underwater and (0.25 + 0.8 * factor) or 0,
    }

    if lastTarget
        and lastTarget.underwater == target.underwater
        and math.abs(lastTarget.Brightness - target.Brightness) < 0.012
        and math.abs(lastTarget.Contrast - target.Contrast) < 0.012
        and math.abs(lastTarget.Saturation - target.Saturation) < 0.015
        and colorClose(lastTarget.TintColor, target.TintColor)
        and math.abs(lastTarget.rayIntensity - target.rayIntensity) < 0.006
        and math.abs(lastTarget.hazeSize - target.hazeSize) < 0.12
    then
        return
    end

    tweenProperties("grade", grade, {
        Brightness = target.Brightness,
        Contrast = target.Contrast,
        Saturation = target.Saturation,
        TintColor = target.TintColor,
    }, underwater, not underwater)

    tweenProperties("rays", rays, {
        Intensity = target.rayIntensity,
        Spread = 0.2,
    }, underwater, not underwater)

    tweenProperties("haze", haze, {
        Size = target.hazeSize,
    }, underwater, not underwater)

    lastTarget = target
end

while true do
    local camera = workspace.CurrentCamera
    if camera then
        bindCamera(camera)
        local position = camera.CFrame.Position
        local underwater = isCameraInTerrainWater(position)
        local depth = math.max(0, WATER_SURFACE_Y - position.Y)
        applyGrade(underwater, depth)
    end
    task.wait(POLL_INTERVAL)
end