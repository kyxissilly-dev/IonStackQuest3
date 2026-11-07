local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local env = type(getgenv) == "function" and getgenv() or _G

if type(env.VertexUnload) == "function" then
    pcall(env.VertexUnload)
end

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/gen2"))()
local window = Rayfield:CreateWindow({
    name = "VERTEX",
    subtitle = "Combat & Visuals",
    sidebarLayout = true,
    theme = "cobalt",
    showName = "VERTEX",
    configuration = {
        autoSave = true,
        autoLoad = true,
        fileName = "VertexGen2",
    },
})

local cfg = {
    aim = false,
    autoShoot = false,
    autoReload = false,
    reloadKey = Enum.KeyCode.R,
    triggerTeam = true,
    protect = false,
    mode = "Hold",
    key = Enum.UserInputType.MouseButton2,
    bone = "Head",
    smoothX = 8,
    smoothY = 8,
    radius = 160,
    circle = true,
    sticky = true,
    aimTeam = true,
    visibleOnly = false,
    esp = false,
    boxes = true,
    boxFill = false,
    names = true,
    usernames = false,
    distances = true,
    health = true,
    healthNumbers = false,
    tracers = false,
    skeleton = false,
    chams = false,
    wallChams = true,
    teamColors = false,
    espTeam = true,
    maxDistance = 1000,
    espHz = 45,
    performance = false,
    fly = false,
    flySpeed = 60,
    walkEnabled = false,
    walkSpeed = 24,
    jumpEnabled = false,
    jumpHeight = 10,
    accent = Color3.fromRGB(93, 190, 255),
}

local engaged = false
local lockedPlayer
local lockUsed = false
local connections = {}
local visuals = {}
local unloaded = false
local renderName = "VertexCombatOverlay"
local perfSaved = {}
local perfGeneration = 0
local espElapsed = 0
local mainRemote = ReplicatedStorage:WaitForChild("MainRemotes"):WaitForChild("MainRemoteEvent")
local protectDropoff = CFrame.new(
    749.687012, 112, -669.547058,
    -0.141923323, -8.91651908e-08, 0.989877641,
    -6.98562062e-08, 1, 8.00613762e-08,
    -0.989877641, -5.77865187e-08, -0.141923323
)
local mouse = localPlayer:GetMouse()
local lastTrigger = 0
local lastReload = 0
local reloadWarned = false
local protectLabels = {}
local protectedIds = {}
local protectWatchers = {}
local protectHandled = setmetatable({}, { __mode = "k" })
local protectQueue = {}
local protectBusy = false
local protectVersion = 0
local protectDropdown
local queueProtect
local syncProtectSelection

local r15Links = {
    { "Head", "UpperTorso" },
    { "UpperTorso", "LowerTorso" },
    { "UpperTorso", "LeftUpperArm" },
    { "LeftUpperArm", "LeftLowerArm" },
    { "LeftLowerArm", "LeftHand" },
    { "UpperTorso", "RightUpperArm" },
    { "RightUpperArm", "RightLowerArm" },
    { "RightLowerArm", "RightHand" },
    { "LowerTorso", "LeftUpperLeg" },
    { "LeftUpperLeg", "LeftLowerLeg" },
    { "LeftLowerLeg", "LeftFoot" },
    { "LowerTorso", "RightUpperLeg" },
    { "RightUpperLeg", "RightLowerLeg" },
    { "RightLowerLeg", "RightFoot" },
}
local r6Links = {
    { "Head", "Torso" },
    { "Torso", "Left Arm" },
    { "Torso", "Right Arm" },
    { "Torso", "Left Leg" },
    { "Torso", "Right Leg" },
}

local function create(class, props, parent)
    local obj = Instance.new(class)
    for key, value in pairs(props) do
        obj[key] = value
    end
    obj.Parent = parent
    return obj
end

local overlay = create("ScreenGui", {
    Name = "VertexOverlay",
    IgnoreGuiInset = true,
    ResetOnSpawn = false,
    DisplayOrder = 20,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

local fov = create("Frame", {
    Name = "AimFOV",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(cfg.radius * 2, cfg.radius * 2),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
}, overlay)
create("UICorner", { CornerRadius = UDim.new(1, 0) }, fov)
local fovStroke = create("UIStroke", {
    Color = cfg.accent,
    Thickness = 1.5,
    Transparency = 0.18,
    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
}, fov)
local centerDot = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(4, 4),
    BackgroundColor3 = cfg.accent,
    BorderSizePixel = 0,
}, overlay)
create("UICorner", { CornerRadius = UDim.new(1, 0) }, centerDot)

local function resetAim()
    engaged = false
    lockedPlayer = nil
    lockUsed = false
end

local function parts(player)
    local char = player.Character
    if not char then return end

    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    if not humanoid or humanoid.Health <= 0 or not root or not head then return end

    return char, humanoid, root, head
end

local function sameTeam(player)
    return player.Team ~= nil and player.Team == localPlayer.Team
end

local function unobstructed(cam, pos, char)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { localPlayer.Character }

    local origin = cam.CFrame.Position
    local hit = workspace:Raycast(origin, pos - origin, params)
    return not hit or hit.Instance:IsDescendantOf(char)
end

local function candidate(player, cam, center)
    if cfg.aimTeam and sameTeam(player) then return end

    local char, _, root, head = parts(player)
    if not char then return end

    local part = cfg.bone == "Head" and head or root
    local screen, visible = cam:WorldToViewportPoint(part.Position)
    if not visible or screen.Z <= 0 then return end

    local distance = (Vector2.new(screen.X, screen.Y) - center).Magnitude
    if distance > cfg.radius then return end
    if cfg.visibleOnly and not unobstructed(cam, part.Position, char) then return end

    return distance
end

local function acquire(cam)
    local center = cam.ViewportSize / 2
    local nearest, nearestDistance = nil, math.huge

    for _, player in Players:GetPlayers() do
        if player ~= localPlayer then
            local distance = candidate(player, cam, center)
            if distance and distance < nearestDistance then
                nearest, nearestDistance = player, distance
            end
        end
    end

    return nearest
end

local function aimAt(cam, pos, dt)
    local origin = cam.CFrame.Position
    local current = cam.CFrame.LookVector
    local desired = (pos - origin).Unit

    local yaw = math.atan2(-current.X, -current.Z)
    local pitch = math.asin(math.clamp(current.Y, -1, 1))
    local targetYaw = math.atan2(-desired.X, -desired.Z)
    local targetPitch = math.asin(math.clamp(desired.Y, -1, 1))

    local yawDiff = math.atan2(math.sin(targetYaw - yaw), math.cos(targetYaw - yaw))
    local xAlpha = 1 - math.exp(-dt * 65 / cfg.smoothX)
    local yAlpha = 1 - math.exp(-dt * 65 / cfg.smoothY)
    yaw += yawDiff * xAlpha
    pitch += (targetPitch - pitch) * yAlpha

    local look = Vector3.new(
        -math.sin(yaw) * math.cos(pitch),
        math.sin(pitch),
        -math.cos(yaw) * math.cos(pitch)
    )
    cam.CFrame = CFrame.lookAt(origin, origin + look)
end

local function setPerfProperty(obj, prop, value)
    local saved = perfSaved[obj]
    if not saved then
        saved = {}
        perfSaved[obj] = saved
    end

    if saved[prop] == nil then
        local ok, original = pcall(function() return obj[prop] end)
        if not ok then return end
        saved[prop] = original
    end
    pcall(function() obj[prop] = value end)
end

local function optimizeEffect(obj)
    if obj:IsA("BloomEffect") or obj:IsA("BlurEffect")
        or obj:IsA("DepthOfFieldEffect") or obj:IsA("SunRaysEffect") then
        setPerfProperty(obj, "Enabled", false)
    elseif obj:IsA("ParticleEmitter") and obj.Rate > 16 then
        setPerfProperty(obj, "Rate", math.max(12, obj.Rate * 0.5))
    end
end

local function setPerformance(enabled)
    cfg.performance = enabled
    perfGeneration += 1
    local generation = perfGeneration

    if not enabled then
        for obj, props in pairs(perfSaved) do
            for prop, original in pairs(props) do
                pcall(function() obj[prop] = original end)
            end
        end
        table.clear(perfSaved)
        return
    end

    setPerfProperty(game:GetService("Lighting"), "GlobalShadows", false)
    setPerfProperty(workspace.Terrain, "WaterWaveSize", 0)
    setPerfProperty(workspace.Terrain, "WaterWaveSpeed", 0)

    for _, obj in game:GetService("Lighting"):GetDescendants() do
        optimizeEffect(obj)
    end

    task.spawn(function()
        local descendants = workspace:GetDescendants()
        for idx, obj in descendants do
            if generation ~= perfGeneration or unloaded then return end
            optimizeEffect(obj)
            if idx % 350 == 0 then RunService.Heartbeat:Wait() end
        end
    end)
end

local function setLine(frame, from, to, color, thickness)
    local delta = to - from
    frame.Position = UDim2.fromOffset((from.X + to.X) / 2, (from.Y + to.Y) / 2)
    frame.Size = UDim2.fromOffset(delta.Magnitude, thickness)
    frame.Rotation = math.deg(math.atan2(delta.Y, delta.X))
    frame.BackgroundColor3 = color
    frame.Visible = true
end

local function makeVisual(player)
    local shadow = create("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 2,
    }, overlay)
    create("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 3.5, Transparency = 0.28 }, shadow)

    local fill = create("Frame", {
        BackgroundColor3 = Color3.fromRGB(10, 18, 28),
        BackgroundTransparency = 0.84,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 1,
    }, overlay)

    local box = create("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 3,
    }, overlay)
    local boxStroke = create("UIStroke", { Color = cfg.accent, Thickness = 1.5 }, box)

    local tag = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 1),
        Size = UDim2.fromOffset(178, 28),
        BackgroundColor3 = Color3.fromRGB(15, 20, 30),
        BackgroundTransparency = 0.04,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 4,
    }, overlay)
    create("UICorner", { CornerRadius = UDim.new(0, 7) }, tag)
    create("UIStroke", { Color = Color3.fromRGB(56, 70, 89), Thickness = 1, Transparency = 0.2 }, tag)
    local mark = create("Frame", {
        Position = UDim2.fromOffset(9, 9),
        Size = UDim2.fromOffset(4, 10),
        BackgroundColor3 = cfg.accent,
        BorderSizePixel = 0,
        ZIndex = 5,
    }, tag)
    create("UICorner", { CornerRadius = UDim.new(1, 0) }, mark)
    local displayName = create("TextLabel", {
        Position = UDim2.fromOffset(19, 0),
        Size = UDim2.fromOffset(99, 28),
        BackgroundTransparency = 1,
        Text = player.DisplayName,
        TextColor3 = Color3.fromRGB(239, 245, 255),
        Font = Enum.Font.GothamSemibold,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 5,
    }, tag)
    local usernameText = create("TextLabel", {
        Position = UDim2.fromOffset(19, 20),
        Size = UDim2.fromOffset(145, 16),
        BackgroundTransparency = 1,
        Text = "@" .. player.Name,
        TextColor3 = Color3.fromRGB(140, 159, 183),
        Font = Enum.Font.Gotham,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Visible = false,
        ZIndex = 5,
    }, tag)
    local distanceText = create("TextLabel", {
        Position = UDim2.fromOffset(120, 0),
        Size = UDim2.fromOffset(49, 28),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Color3.fromRGB(162, 174, 193),
        Font = Enum.Font.GothamMedium,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 5,
    }, tag)

    local healthBack = create("Frame", {
        BackgroundColor3 = Color3.fromRGB(12, 17, 25),
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 3,
    }, overlay)
    create("UICorner", { CornerRadius = UDim.new(1, 0) }, healthBack)
    local healthFill = create("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(98, 230, 165),
        BorderSizePixel = 0,
        ZIndex = 4,
    }, healthBack)
    create("UICorner", { CornerRadius = UDim.new(1, 0) }, healthFill)

    local healthText = create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(38, 18),
        Text = "",
        TextColor3 = Color3.fromRGB(240, 247, 255),
        TextStrokeColor3 = Color3.fromRGB(9, 15, 24),
        TextStrokeTransparency = 0.2,
        Font = Enum.Font.GothamSemibold,
        TextSize = 10,
        Visible = false,
        ZIndex = 5,
    }, overlay)

    local tracer = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = cfg.accent,
        BackgroundTransparency = 0.12,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 1,
    }, overlay)
    create("UIStroke", { Color = Color3.fromRGB(5, 9, 17), Thickness = 1.5, Transparency = 0.1 }, tracer)

    local entry = {
        box = box,
        fill = fill,
        stroke = boxStroke,
        shadow = shadow,
        tag = tag,
        mark = mark,
        displayName = displayName,
        username = usernameText,
        distance = distanceText,
        healthBack = healthBack,
        healthFill = healthFill,
        healthText = healthText,
        tracer = tracer,
        lines = {},
        char = nil,
        highlight = nil,
    }
    visuals[player] = entry
    return entry
end

local function hideVisual(entry)
    entry.box.Visible = false
    entry.shadow.Visible = false
    entry.fill.Visible = false
    entry.tag.Visible = false
    entry.healthBack.Visible = false
    entry.healthText.Visible = false
    entry.tracer.Visible = false
    for _, line in entry.lines do line.Visible = false end
    if entry.highlight then entry.highlight.Enabled = false end
end

local function removeVisual(player)
    local entry = visuals[player]
    if not entry then return end

    entry.box:Destroy()
    entry.shadow:Destroy()
    entry.fill:Destroy()
    entry.tag:Destroy()
    entry.healthBack:Destroy()
    entry.healthText:Destroy()
    entry.tracer:Destroy()
    for _, line in entry.lines do line:Destroy() end
    if entry.highlight then entry.highlight:Destroy() end
    visuals[player] = nil
end

local function drawSkeleton(entry, char, humanoid, cam, color)
    local links = humanoid.RigType == Enum.HumanoidRigType.R15 and r15Links or r6Links
    for idx, link in links do
        local line = entry.lines[idx]
        if not line then
            line = create("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                BorderSizePixel = 0,
                Visible = false,
                ZIndex = 4,
            }, overlay)
            create("UIStroke", {
                Color = Color3.fromRGB(5, 9, 17),
                Thickness = 1.7,
                Transparency = 0.1,
            }, line)
            entry.lines[idx] = line
        end

        local a = char:FindFirstChild(link[1])
        local b = char:FindFirstChild(link[2])
        if a and b then
            local p, pOn = cam:WorldToViewportPoint(a.Position)
            local q, qOn = cam:WorldToViewportPoint(b.Position)
            if pOn and qOn and p.Z > 0 and q.Z > 0 then
                setLine(line, Vector2.new(p.X, p.Y), Vector2.new(q.X, q.Y), color, 1.5)
            else
                line.Visible = false
            end
        else
            line.Visible = false
        end
    end
    for idx = #links + 1, #entry.lines do
        entry.lines[idx].Visible = false
    end
end

local function drawVisual(player, cam)
    local entry = visuals[player] or makeVisual(player)
    local char, humanoid, root, head = parts(player)
    if not cfg.esp or not char or (cfg.espTeam and sameTeam(player)) then
        hideVisual(entry)
        return
    end

    local distance = (cam.CFrame.Position - root.Position).Magnitude
    if distance > cfg.maxDistance then
        hideVisual(entry)
        return
    end

    local accent = cfg.teamColors and player.Team and player.TeamColor.Color or cfg.accent
    if cfg.chams then
        if entry.char ~= char or not entry.highlight or entry.highlight.Parent ~= char then
            if entry.highlight then entry.highlight:Destroy() end
            entry.char = char
            entry.highlight = create("Highlight", {
                Name = "VertexChams",
                Adornee = char,
                DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
                FillTransparency = 0.72,
                OutlineTransparency = 0.04,
            }, char)
        end
        entry.highlight.FillColor = accent
        entry.highlight.OutlineColor = accent
        entry.highlight.DepthMode = cfg.wallChams and Enum.HighlightDepthMode.AlwaysOnTop
            or Enum.HighlightDepthMode.Occluded
        entry.highlight.Enabled = true
    elseif entry.highlight then
        entry.highlight.Enabled = false
    end

    if not (cfg.boxes or cfg.names or cfg.health or cfg.tracers or cfg.skeleton) then
        hideVisual(entry)
        if entry.highlight and cfg.chams then entry.highlight.Enabled = true end
        return
    end

    local top, topVisible = cam:WorldToViewportPoint(head.Position + Vector3.new(0, head.Size.Y * 0.7, 0))
    local bottom, bottomVisible = cam:WorldToViewportPoint(root.Position - Vector3.new(0, humanoid.HipHeight + root.Size.Y * 0.5 + 0.35, 0))
    if not topVisible or not bottomVisible or top.Z <= 0 or bottom.Z <= 0 then
        hideVisual(entry)
        if entry.highlight and cfg.chams then entry.highlight.Enabled = true end
        return
    end

    local height = math.abs(bottom.Y - top.Y)
    if height < 5 then
        hideVisual(entry)
        if entry.highlight and cfg.chams then entry.highlight.Enabled = true end
        return
    end

    local width = height * 0.52
    local x = (top.X + bottom.X) / 2 - width / 2
    local y = math.min(top.Y, bottom.Y)
    entry.box.Position = UDim2.fromOffset(x, y)
    entry.box.Size = UDim2.fromOffset(width, height)
    entry.box.Visible = cfg.boxes
    entry.stroke.Color = accent
    entry.fill.Position = entry.box.Position
    entry.fill.Size = entry.box.Size
    entry.fill.Visible = cfg.boxes and cfg.boxFill

    entry.shadow.Position = UDim2.fromOffset(x, y)
    entry.shadow.Size = entry.box.Size
    entry.shadow.Visible = cfg.boxes

    local tagHeight = cfg.usernames and 40 or 28
    entry.tag.Size = UDim2.fromOffset(178, tagHeight)
    entry.tag.Position = UDim2.fromOffset(x + width / 2, y - 8)
    entry.tag.Visible = cfg.names
    entry.mark.BackgroundColor3 = accent
    entry.displayName.Position = UDim2.fromOffset(19, cfg.usernames and 1 or 0)
    entry.username.Visible = cfg.names and cfg.usernames
    entry.distance.Visible = cfg.distances
    entry.distance.Text = string.format("%d st", distance + 0.5)

    entry.healthBack.Position = UDim2.fromOffset(x - 9, y)
    entry.healthBack.Size = UDim2.fromOffset(4, height)
    entry.healthBack.Visible = cfg.health
    local healthRatio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
    entry.healthFill.Size = UDim2.fromScale(1, healthRatio)
    entry.healthFill.BackgroundColor3 = Color3.fromHSV(healthRatio * 0.34, 0.72, 0.95)
    entry.healthText.Position = UDim2.fromOffset(x - 50, y - 2)
    entry.healthText.Text = string.format("%d", humanoid.Health + 0.5)
    entry.healthText.Visible = cfg.health and cfg.healthNumbers

    if cfg.tracers then
        local from = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y - 18)
        local to = Vector2.new(x + width / 2, y + height)
        setLine(entry.tracer, from, to, accent, 1.4)
    else
        entry.tracer.Visible = false
    end

    if cfg.skeleton then
        drawSkeleton(entry, char, humanoid, cam, accent)
    else
        for _, line in entry.lines do line.Visible = false end
    end
end

local function heldCharacter()
    local char = localPlayer.Character
    local effects = char and char:FindFirstChild("BodyEffects")
    local grabbed = effects and effects:FindFirstChild("Grabbed")
    return grabbed and grabbed.Value or nil
end

local function protectStatus(msg)
    print("[VERTEX / PROTECT] " .. msg)
end

local function runProtect(player, targetChar, ko, version)
    local own = localPlayer.Character
    local root = own and own:FindFirstChild("HumanoidRootPart")
    local hum = own and own:FindFirstChildOfClass("Humanoid")
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    local ownEffects = own and own:FindFirstChild("BodyEffects")
    local ownKO = ownEffects and ownEffects:FindFirstChild("K.O")

    if not root or not hum or hum.Health <= 0 or (ownKO and ownKO.Value)
        or not targetRoot or not ko.Value or player.Character ~= targetChar then
        return "Character unavailable"
    end
    if heldCharacter() == targetChar then return "Already carrying " .. player.Name end
    if heldCharacter() then return "Already carrying someone else" end

    local start = own:GetPivot()
    local grabbed = false
    local attempts = 0
    local valid = function()
        return not unloaded and cfg.protect and version == protectVersion
            and protectedIds[player.UserId] and own == localPlayer.Character and player.Character == targetChar
            and ko.Parent ~= nil and ko.Value and targetRoot.Parent ~= nil
    end

    for attempt = 1, 5 do
        if not valid() or heldCharacter() then break end
        attempts = attempt
        local height = hum.HipHeight + root.Size.Y / 2 + 0.4
        own:PivotTo(CFrame.new(targetRoot.Position + Vector3.new(0, height, 0)))
        task.wait(0.15)
        if not valid() then break end

        if heldCharacter() == targetChar then
            grabbed = true
            break
        end
        mainRemote:FireServer("Grabbing", true)

        for _ = 1, 14 do
            task.wait(0.05)
            if heldCharacter() == targetChar then
                grabbed = true
                break
            end
            if not valid() then break end
        end
        if grabbed or not valid() then break end
        if attempt < 5 then task.wait(0.2) end
    end

    if heldCharacter() == targetChar then grabbed = true end
    if not grabbed then
        if own == localPlayer.Character and root.Parent then
            own:PivotTo(start)
        end
        return ("Failed to grab %s (%d/5)"):format(player.Name, attempts)
    end

    -- Give the server time to establish the grab before moving the carrier.
    task.wait(0.5)
    if own ~= localPlayer.Character or not root.Parent then
        return "Character changed during rescue: " .. player.Name
    end
    if heldCharacter() ~= targetChar then
        return "Lost grab before teleport: " .. player.Name
    end

    root.CFrame = protectDropoff

    local arrived = false
    for _ = 1, 50 do
        task.wait(0.05)
        if own ~= localPlayer.Character or not root.Parent then
            return "Character changed at drop-off: " .. player.Name
        end
        if heldCharacter() ~= targetChar then
            return "Lost grab during teleport: " .. player.Name
        end
        if targetRoot.Parent and (targetRoot.Position - protectDropoff.Position).Magnitude <= 16 then
            arrived = true
            break
        end
    end

    if not arrived then
        return "Target didn't reach safe spot; still carrying " .. player.Name
    end

    -- A local position update can arrive before the server accepts the teleport.
    task.wait(0.5)
    if own ~= localPlayer.Character or not root.Parent
        or heldCharacter() ~= targetChar or not targetRoot.Parent
        or (targetRoot.Position - protectDropoff.Position).Magnitude > 16 then
        return "Drop-off not stable; release cancelled for " .. player.Name
    end

    mainRemote:FireServer("Grabbing", false)
    local released = false
    for _ = 1, 40 do
        task.wait(0.05)
        if heldCharacter() ~= targetChar
            and not targetChar:FindFirstChild("GRABBING_CONSTRAINT") then
            released = true
            break
        end
    end

    if not released then
        return "Drop not confirmed at safe spot; still carrying " .. player.Name
    end

    -- Verify that the release remains settled before returning alone.
    task.wait(0.35)
    if heldCharacter() == targetChar or targetChar:FindFirstChild("GRABBING_CONSTRAINT")
        or not targetRoot.Parent
        or (targetRoot.Position - protectDropoff.Position).Magnitude > 20 then
        return "Drop didn't settle at safe spot; return cancelled for " .. player.Name
    end
    if own == localPlayer.Character and root.Parent then
        own:PivotTo(start)
    end
    return "Dropped " .. player.Name .. " at safe spot and returned"
end

local function processProtectQueue()
    if protectBusy or unloaded or not cfg.protect then return end
    protectBusy = true

    while cfg.protect and not unloaded and #protectQueue > 0 do
        local item = table.remove(protectQueue, 1)
        local player, char, ko = item.player, item.char, item.ko
        if protectedIds[player.UserId] and player.Character == char and ko.Parent and ko.Value then
            protectStatus("Rescuing " .. player.Name)
            local ok, result = pcall(runProtect, player, char, ko, protectVersion)
            local msg = ok and result or ("Error rescuing %s: %s"):format(player.Name, tostring(result))
            protectStatus(msg)
            if not unloaded then
                window:Notify({ title = "Auto Protect", content = msg })
            end
        end
    end

    protectBusy = false
    if cfg.protect and #protectQueue > 0 then
        task.defer(processProtectQueue)
    end
end

queueProtect = function(player, char, ko)
    if not cfg.protect or not protectedIds[player.UserId] or not ko.Value
        or protectHandled[char] or unloaded then return end
    protectHandled[char] = true
    table.insert(protectQueue, { player = player, char = char, ko = ko })
    task.defer(processProtectQueue)
end

local function checkProtected()
    for _, player in Players:GetPlayers() do
        if protectedIds[player.UserId] then
            local char = player.Character
            local effects = char and char:FindFirstChild("BodyEffects")
            local ko = effects and effects:FindFirstChild("K.O")
            if ko then queueProtect(player, char, ko) end
        end
    end
end

local function watchProtected(player)
    if player == localPlayer or protectWatchers[player] then return end
    local entry = {}
    protectWatchers[player] = entry

    local function attach(char)
        if entry.koConn then entry.koConn:Disconnect() end
        entry.koConn = nil
        task.spawn(function()
            local effects = char:WaitForChild("BodyEffects", 10)
            local ko = effects and effects:WaitForChild("K.O", 10)
            if not ko or player.Character ~= char or protectWatchers[player] ~= entry then return end
            entry.koConn = ko:GetPropertyChangedSignal("Value"):Connect(function()
                if ko.Value then
                    queueProtect(player, char, ko)
                else
                    protectHandled[char] = nil
                end
            end)
            if ko.Value then queueProtect(player, char, ko) end
        end)
    end

    entry.charConn = player.CharacterAdded:Connect(attach)
    if player.Character then attach(player.Character) end
end

local function refreshProtected()
    if not protectDropdown then return end
    local options, labels = {}, {}
    for _, player in Players:GetPlayers() do
        if player ~= localPlayer then
            local label = ("@%s [%d]"):format(player.Name, player.UserId)
            labels[label] = player.UserId
            table.insert(options, label)
        end
    end
    table.sort(options)
    protectLabels = labels
    protectDropdown:Refresh(options)
end

syncProtectSelection = function(selected)
    table.clear(protectedIds)
    for _, label in selected do
        local id = protectLabels[label]
        if id then protectedIds[id] = true end
    end
    table.clear(protectQueue)
    if cfg.protect then checkProtected() end
end

local function gunEquipped()
    local char = localPlayer.Character
    if not char then return end
    for _, tool in char:GetChildren() do
        if tool:IsA("Tool") and tool.Enabled then
            local ammo = tool:FindFirstChild("Ammo")
            local cooldown = tool:FindFirstChild("ShootingCooldown")
            if ammo and ammo:IsA("ValueBase") and cooldown and cooldown:IsA("ValueBase")
                and tool:FindFirstChild("Range") and tool:FindFirstChild("Damage") then
                return tool, ammo, cooldown
            end
        end
    end
end

local function mousePlayer()
    local hit = mouse.Target
    if not hit then return end

    local node = hit
    while node and node ~= workspace do
        if node:IsA("Model") then
            local player = Players:GetPlayerFromCharacter(node)
            if player and player ~= localPlayer then
                local char, hum = parts(player)
                if char and (not cfg.triggerTeam or not sameTeam(player)) then
                    local effects = char:FindFirstChild("BodyEffects")
                    local ko = effects and effects:FindFirstChild("K.O")
                    local dead = effects and effects:FindFirstChild("Dead")
                    if not (ko and ko.Value) and not (dead and dead.Value) then
                        return player
                    end
                end
                return
            end
        end
        node = node.Parent
    end
end

local function doAutoReload(ammo)
    if not cfg.autoReload or ammo.Value > 0 or os.clock() - lastReload < 1.5 then return end
    local effects = localPlayer.Character and localPlayer.Character:FindFirstChild("BodyEffects")
    local reloading = effects and effects:FindFirstChild("Reload")
    if reloading and reloading.Value then return end
    if typeof(cfg.reloadKey) ~= "EnumItem" or cfg.reloadKey.EnumType ~= Enum.KeyCode then return end
    lastReload = os.clock()

    local key = cfg.reloadKey
    task.spawn(function()
        local ok = pcall(function()
            local vim = game:GetService("VirtualInputManager")
            vim:SendKeyEvent(true, key, false, game)
            task.wait(0.06)
            vim:SendKeyEvent(false, key, false, game)
        end)
        if not ok and not reloadWarned then
            reloadWarned = true
            warn("[VERTEX] Auto Reload needs supported key input; reload handler not supplied.")
        end
    end)
end

local function updateAutoShoot()
    if not cfg.autoShoot and not cfg.autoReload then return end
    local tool, ammo, cooldown = gunEquipped()
    if not tool then return end
    local char = localPlayer.Character
    local effects = char and char:FindFirstChild("BodyEffects")
    local ko = effects and effects:FindFirstChild("K.O")
    if ko and ko.Value then return end
    if effects and effects:FindFirstChild("Reload") and effects.Reload.Value then return end
    if UserInputService:GetFocusedTextBox() then return end
    if ammo.Value <= 0 then
        doAutoReload(ammo)
        return
    end

    if not cfg.autoShoot or UserInputService:GetFocusedTextBox() or not mousePlayer() then return end
    local delayTime = math.max(tonumber(cooldown.Value) or 0.12, 0.08)
    if os.clock() - lastTrigger < delayTime then return end
    if _G.GUN_COMBAT_TOGGLE then return end
    lastTrigger = os.clock()
    tool:Activate()
    tool:Deactivate()
end

local movementHum
local movementDefaults
local flyRoot
local flyAttachment
local flyVelocity
local movementElapsed = 0

local function stopFly()
    if flyVelocity then flyVelocity:Destroy() end
    if flyAttachment then flyAttachment:Destroy() end
    flyRoot, flyAttachment, flyVelocity = nil, nil, nil
end

local function trackMovement()
    local char = localPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum ~= movementHum then
        stopFly()
        movementHum = hum
        movementDefaults = hum and {
            walk = hum.WalkSpeed,
            jumpPower = hum.JumpPower,
            jumpHeight = hum.JumpHeight,
        } or nil
    end
    return hum
end

local function setWalk(enabled)
    cfg.walkEnabled = enabled
    local hum = trackMovement()
    if hum then
        hum.WalkSpeed = enabled and cfg.walkSpeed or movementDefaults.walk
    end
end

local function setJump(enabled)
    cfg.jumpEnabled = enabled
    local hum = trackMovement()
    if not hum then return end
    if enabled then
        if hum.UseJumpPower then
            hum.JumpPower = math.sqrt(2 * workspace.Gravity * cfg.jumpHeight)
        else
            hum.JumpHeight = cfg.jumpHeight
        end
    else
        hum.JumpPower = movementDefaults.jumpPower
        hum.JumpHeight = movementDefaults.jumpHeight
    end
end

local function updateMovement()
    local hum = trackMovement()
    if not hum then return end
    if cfg.walkEnabled then hum.WalkSpeed = cfg.walkSpeed end
    if cfg.jumpEnabled then
        if hum.UseJumpPower then
            hum.JumpPower = math.sqrt(2 * workspace.Gravity * cfg.jumpHeight)
        else
            hum.JumpHeight = cfg.jumpHeight
        end
    end
end

local function updateFly()
    if not cfg.fly then return end

    local char = localPlayer.Character
    local hum = trackMovement()
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root or not hum or hum.Health <= 0 then
        stopFly()
        return
    end

    if root ~= flyRoot then
        stopFly()
        flyRoot = root
        flyAttachment = Instance.new("Attachment")
        flyAttachment.Name = "VertexFlyAttachment"
        flyAttachment.Parent = root
        flyVelocity = Instance.new("LinearVelocity")
        flyVelocity.Name = "VertexFlyVelocity"
        flyVelocity.Attachment0 = flyAttachment
        flyVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
        flyVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
        flyVelocity.ForceLimitsEnabled = false
        flyVelocity.VectorVelocity = Vector3.zero
        flyVelocity.Parent = root
    end

    local cam = workspace.CurrentCamera
    if not cam or UserInputService:GetFocusedTextBox() then
        flyVelocity.VectorVelocity = Vector3.zero
        return
    end

    local cf = cam.CFrame
    local direction = Vector3.zero
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then direction += cf.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then direction -= cf.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then direction += cf.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then direction -= cf.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then direction += Vector3.yAxis end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
        or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
        direction -= Vector3.yAxis
    end

    flyVelocity.VectorVelocity = direction.Magnitude > 0
        and direction.Unit * cfg.flySpeed or Vector3.zero
end

local function copyCFrame()
    local char = localPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then
        window:Notify({ title = "CFrame", content = "HumanoidRootPart not found." })
        return
    end

    local components = { root.CFrame:GetComponents() }
    for i, value in components do
        components[i] = string.format("%.9g", value)
    end
    local code = "CFrame.new(" .. table.concat(components, ", ") .. ")"
    local clipboard = type(setclipboard) == "function" and setclipboard
        or type(toclipboard) == "function" and toclipboard
    if clipboard then
        local ok = pcall(clipboard, code)
        if ok then
            window:Notify({ title = "CFrame copied", content = "Position and rotation copied to clipboard." })
            return
        end
    end
    print("[VERTEX / CFRAME] " .. code)
    window:Notify({ title = "CFrame", content = "Clipboard unavailable. CFrame printed to console." })
end

local aimTab = window:CreateTab({ name = "Aimbot", icon = 100604009889706 })
aimTab:CreateSection({ name = "Targeting" })
local aimToggle = aimTab:CreateToggle({
    name = "Enable Aimbot", flag = "aimEnabled", value = cfg.aim,
    description = "Master switch for camera tracking.",
    callback = function(value)
        cfg.aim = value
        if not value then resetAim() end
    end,
})
local modeDropdown = aimTab:CreateDropdown({
    name = "Activation Mode", flag = "aimMode", options = { "Hold", "Toggle" }, value = cfg.mode,
    callback = function(value)
        cfg.mode = value
        resetAim()
    end,
})
local aimKeybind = aimTab:CreateKeybind({
    name = "Activation Key", flag = "aimKey", value = cfg.key,
    description = "Click to change the key or mouse button.",
    callback = function()
        if not cfg.aim then return end
        if cfg.mode == "Toggle" then
            engaged = not engaged
            if not engaged then
                lockedPlayer = nil
                lockUsed = false
            end
        else
            engaged = true
        end
    end,
    onChanged = function(key)
        cfg.key = key
        resetAim()
    end,
})
local stickyToggle = aimTab:CreateToggle({
    name = "Sticky Aim", flag = "stickyAim", value = cfg.sticky,
    description = "Keep the first target until the key is released or toggled off.",
    callback = function(value)
        cfg.sticky = value
        lockedPlayer = nil
        lockUsed = false
    end,
})
local teamToggle = aimTab:CreateToggle({
    name = "Ignore Teammates", flag = "aimTeam", value = cfg.aimTeam,
    callback = function(value) cfg.aimTeam = value end,
})
local visibleToggle = aimTab:CreateToggle({
    name = "Visibility Check", flag = "aimVisible", value = cfg.visibleOnly,
    callback = function(value) cfg.visibleOnly = value end,
})
local boneDropdown = aimTab:CreateDropdown({
    name = "Aim Part", flag = "aimPart", options = { "Head", "HumanoidRootPart" }, value = cfg.bone,
    callback = function(value) cfg.bone = value end,
})

aimTab:CreateSection({ name = "Smoothing & Field of View" })
local xSlider = aimTab:CreateSlider({
    name = "X Smoothing", flag = "smoothX", range = { 1, 35 }, increment = 1, value = cfg.smoothX,
    description = "Horizontal smoothing. Lower = faster.",
    callback = function(value) cfg.smoothX = value end,
})
local ySlider = aimTab:CreateSlider({
    name = "Y Smoothing", flag = "smoothY", range = { 1, 35 }, increment = 1, value = cfg.smoothY,
    description = "Vertical smoothing. Lower = faster.",
    callback = function(value) cfg.smoothY = value end,
})
local radiusSlider = aimTab:CreateSlider({
    name = "FOV Radius", flag = "aimRadius", range = { 50, 500 }, increment = 5,
    value = cfg.radius, suffix = " px",
    callback = function(value) cfg.radius = value end,
})
local circleToggle = aimTab:CreateToggle({
    name = "Show FOV Circle", flag = "showFov", value = cfg.circle,
    callback = function(value) cfg.circle = value end,
})

aimTab:CreateSection({ name = "Auto Shoot / Reload" })
local autoShootToggle = aimTab:CreateToggle({
    name = "Auto Shoot", flag = "triggerEnabled", value = cfg.autoShoot,
    description = "Fires the equipped gun via Tool:Activate() while your cursor is on a live player.",
    callback = function(value) cfg.autoShoot = value end,
})
local triggerTeamToggle = aimTab:CreateToggle({
    name = "Auto Shoot - Ignore Teammates", flag = "triggerTeam", value = cfg.triggerTeam,
    callback = function(value) cfg.triggerTeam = value end,
})
local autoReloadToggle = aimTab:CreateToggle({
    name = "Auto Reload", flag = "autoReload", value = cfg.autoReload,
    description = "Sends your game's reload key when the equipped gun is empty. No guessed remote calls.",
    callback = function(value) cfg.autoReload = value end,
})
local reloadKeybind = aimTab:CreateKeybind({
    name = "Reload Key", flag = "autoReloadKey", value = cfg.reloadKey,
    description = "Set this to the actual in-game reload key. R is an unverified default.",
    callback = function() end,
    onChanged = function(key) cfg.reloadKey = key end,
})

local protectTab = window:CreateTab({ name = "Auto Protect", icon = 7733960981 })
protectTab:CreateSection({ name = "Rescue Settings" })
local protectToggle = protectTab:CreateToggle({
    name = "Protect", flag = "protectEnabled", value = cfg.protect,
    description = "On KO: grab a selected player, carry them to the safe spot, release, then return.",
    callback = function(value)
        cfg.protect = value
        protectVersion += 1
        table.clear(protectQueue)
        if value then
            table.clear(protectHandled)
            checkProtected()
        end
    end,
})
protectDropdown = protectTab:CreateDropdown({
    name = "Protected Players", flag = "protectPlayers", multiSelect = true,
    options = {}, value = {}, placeholder = "Select players...",
    description = "Select multiple players. List refreshes when players join or leave.",
    callback = function(selected) syncProtectSelection(selected) end,
})
protectTab:CreateButton({
    name = "Refresh Players",
    callback = refreshProtected,
})
protectTab:CreateText({
    name = "Rescue Behavior",
    text = "Up to five grab attempts per KO. After pickup, waits 0.5s, teleports to (749.7, 112, -669.5), waits for arrival and settles 0.5s, releases, confirms the drop, then returns. If release fails, it stays at the drop-off.",
})

local espTab = window:CreateTab({ name = "Visuals", icon = 80387863064905 })
espTab:CreateSection({ name = "Player ESP" })
local espToggle = espTab:CreateToggle({
    name = "Enable ESP", flag = "espEnabled", value = cfg.esp,
    callback = function(value)
        cfg.esp = value
        if not value then
            for _, entry in pairs(visuals) do hideVisual(entry) end
        end
    end,
})
local boxesToggle = espTab:CreateToggle({
    name = "Box ESP", flag = "espBoxes", value = cfg.boxes,
    callback = function(value) cfg.boxes = value end,
})
local fillToggle = espTab:CreateToggle({
    name = "Subtle Box Fill", flag = "espBoxFill", value = cfg.boxFill,
    description = "Tint inside boxes without obscuring the game.",
    callback = function(value) cfg.boxFill = value end,
})
local nameToggle = espTab:CreateToggle({
    name = "Name Tags", flag = "espNames", value = cfg.names,
    callback = function(value) cfg.names = value end,
})
local usernameToggle = espTab:CreateToggle({
    name = "Show @Username", flag = "espUsernames", value = cfg.usernames,
    description = "Adds a second line to display-name tags.",
    callback = function(value) cfg.usernames = value end,
})
local showDistanceToggle = espTab:CreateToggle({
    name = "Distance in Name Tags", flag = "espDistances", value = cfg.distances,
    callback = function(value) cfg.distances = value end,
})
local healthToggle = espTab:CreateToggle({
    name = "Health Bars", flag = "espHealth", value = cfg.health,
    callback = function(value) cfg.health = value end,
})
local healthNumberToggle = espTab:CreateToggle({
    name = "Numeric Health", flag = "espHealthNumbers", value = cfg.healthNumbers,
    callback = function(value) cfg.healthNumbers = value end,
})
espTab:CreateSection({ name = "Extra Overlays" })
local tracerToggle = espTab:CreateToggle({
    name = "Tracer Lines", flag = "espTracers", value = cfg.tracers,
    description = "Thin lines from the bottom of the screen.",
    callback = function(value) cfg.tracers = value end,
})
local skeletonToggle = espTab:CreateToggle({
    name = "Skeleton ESP", flag = "espSkeleton", value = cfg.skeleton,
    description = "R6 and R15 body joints. Off by default for FPS.",
    callback = function(value) cfg.skeleton = value end,
})
local chamsToggle = espTab:CreateToggle({
    name = "Highlight Chams", flag = "espChams", value = cfg.chams,
    description = "Outlines characters through map geometry.",
    callback = function(value) cfg.chams = value end,
})
local wallChamsToggle = espTab:CreateToggle({
    name = "Chams Through Walls", flag = "espWallChams", value = cfg.wallChams,
    callback = function(value) cfg.wallChams = value end,
})
espTab:CreateSection({ name = "Style & Distance" })
local teamColorsToggle = espTab:CreateToggle({
    name = "Use Team Colors", flag = "espTeamColors", value = cfg.teamColors,
    description = "Per-player team color instead of the accent color.",
    callback = function(value) cfg.teamColors = value end,
})
local espTeamToggle = espTab:CreateToggle({
    name = "Ignore Teammates", flag = "espTeam", value = cfg.espTeam,
    callback = function(value) cfg.espTeam = value end,
})
local distanceSlider = espTab:CreateSlider({
    name = "ESP Distance", flag = "espDistance", range = { 50, 2000 }, increment = 50,
    value = cfg.maxDistance, suffix = " studs",
    callback = function(value) cfg.maxDistance = value end,
})
local espHzSlider = espTab:CreateSlider({
    name = "ESP Refresh Rate", flag = "espHz", range = { 15, 60 }, increment = 5,
    value = cfg.espHz, suffix = " Hz",
    description = "Performance Mode caps this at 30 Hz for lower overhead.",
    callback = function(value) cfg.espHz = value end,
})
local accentPicker = espTab:CreateColorPicker({
    name = "Accent Color", flag = "espAccent", color = cfg.accent,
    callback = function(color) cfg.accent = color end,
})

local movementTab = window:CreateTab({ name = "Movement", icon = 9641366185 })
movementTab:CreateSection({ name = "Flight" })
local flyToggle = movementTab:CreateToggle({
    name = "Fly", flag = "movementFly", value = cfg.fly,
    description = "Camera-relative flight using LinearVelocity. No input hooks.",
    callback = function(value)
        cfg.fly = value
        if not value then stopFly() end
    end,
})
local flySpeedSlider = movementTab:CreateSlider({
    name = "Fly Speed", flag = "movementFlySpeed", range = { 10, 200 }, increment = 5,
    value = cfg.flySpeed, suffix = " studs/s",
    callback = function(value) cfg.flySpeed = value end,
})
movementTab:CreateText({
    name = "Flight controls",
    text = "W/A/S/D to fly relative to your camera, Space to ascend, Ctrl to descend. Turning Fly off removes its physics objects.",
})
movementTab:CreateSection({ name = "Character Speed & Jump" })
local walkToggle = movementTab:CreateToggle({
    name = "Override WalkSpeed", flag = "movementWalkEnabled", value = cfg.walkEnabled,
    description = "Restores your original WalkSpeed when disabled.",
    callback = setWalk,
})
local walkSlider = movementTab:CreateSlider({
    name = "WalkSpeed", flag = "movementWalkSpeed", range = { 8, 150 }, increment = 1,
    value = cfg.walkSpeed, suffix = " studs/s",
    callback = function(value)
        cfg.walkSpeed = value
        if cfg.walkEnabled then updateMovement() end
    end,
})
local jumpToggle = movementTab:CreateToggle({
    name = "Override Jump Height", flag = "movementJumpEnabled", value = cfg.jumpEnabled,
    description = "Supports games using either JumpHeight or JumpPower.",
    callback = setJump,
})
local jumpSlider = movementTab:CreateSlider({
    name = "Jump Height", flag = "movementJumpHeight", range = { 3, 50 }, increment = 1,
    value = cfg.jumpHeight, suffix = " studs",
    callback = function(value)
        cfg.jumpHeight = value
        if cfg.jumpEnabled then updateMovement() end
    end,
})

local miscTab = window:CreateTab({ name = "Settings", icon = 129180860773723 })
miscTab:CreateSection({ name = "Optimization" })
local perfToggle = miscTab:CreateToggle({
    name = "Performance Mode - Balanced", flag = "balancedPerformance", value = cfg.performance,
    description = "Reduces shadows, expensive post-FX and dense particles. Keeps colors and textures.",
    callback = setPerformance,
})
miscTab:CreateText({
    name = "What it changes",
    text = "Turns off world shadows, Bloom/Blur/Depth of Field/Sun Rays, and water waves. Dense particle emitters run at a reduced rate. Color correction, atmosphere, textures and materials stay intact. All edits restore on disable/unload.",
})
miscTab:CreateSection({ name = "Position Tools" })
miscTab:CreateButton({
    name = "Copy My CFrame",
    description = "Copies HumanoidRootPart CFrame with rotation as paste-ready Luau.",
    callback = copyCFrame,
})
miscTab:CreateSection({ name = "About" })
miscTab:CreateText({
    name = "VERTEX / Gen2",
    text = "Screen-centered FOV, independent X/Y camera smoothing, sticky targeting, and UI-based ESP. Hold mode releases instantly when the activation key is lifted.",
})
miscTab:CreateButton({
    name = "Unload Script",
    callback = function()
        task.defer(function()
            if type(env.VertexUnload) == "function" then
                env.VertexUnload()
            end
        end)
    end,
})

-- Gen2 returns dropdown handle values as arrays even in single-select mode.
cfg.aim = aimToggle.value
cfg.autoShoot = autoShootToggle.value
cfg.triggerTeam = triggerTeamToggle.value
cfg.autoReload = autoReloadToggle.value
cfg.reloadKey = reloadKeybind.value
cfg.protect = protectToggle.value
cfg.fly = flyToggle.value
cfg.flySpeed = flySpeedSlider.value
cfg.walkEnabled = walkToggle.value
cfg.walkSpeed = walkSlider.value
cfg.jumpEnabled = jumpToggle.value
cfg.jumpHeight = jumpSlider.value
updateMovement()
cfg.mode = modeDropdown.value[1] or cfg.mode
cfg.key = aimKeybind.value
cfg.sticky = stickyToggle.value
cfg.aimTeam = teamToggle.value
cfg.visibleOnly = visibleToggle.value
cfg.bone = boneDropdown.value[1] or cfg.bone
cfg.smoothX = xSlider.value
cfg.smoothY = ySlider.value
cfg.radius = radiusSlider.value
cfg.circle = circleToggle.value
cfg.esp = espToggle.value
cfg.boxes = boxesToggle.value
cfg.boxFill = fillToggle.value
cfg.names = nameToggle.value
cfg.usernames = usernameToggle.value
cfg.distances = showDistanceToggle.value
cfg.health = healthToggle.value
cfg.healthNumbers = healthNumberToggle.value
cfg.tracers = tracerToggle.value
cfg.skeleton = skeletonToggle.value
cfg.chams = chamsToggle.value
cfg.wallChams = wallChamsToggle.value
cfg.teamColors = teamColorsToggle.value
cfg.espTeam = espTeamToggle.value
cfg.maxDistance = distanceSlider.value
cfg.espHz = espHzSlider.value
cfg.accent = accentPicker.value
if perfToggle.value ~= cfg.performance then
    setPerformance(perfToggle.value)
end

for _, player in Players:GetPlayers() do watchProtected(player) end
refreshProtected()
syncProtectSelection(protectDropdown.value)
if cfg.protect then checkProtected() end

local function matchesKey(input)
    return input.KeyCode == cfg.key or input.UserInputType == cfg.key
end

connections[#connections + 1] = UserInputService.InputEnded:Connect(function(input)
    if cfg.mode == "Hold" and matchesKey(input) then
        resetAim()
    end
end)
connections[#connections + 1] = Players.PlayerAdded:Connect(function(player)
    watchProtected(player)
    task.defer(refreshProtected)
end)
connections[#connections + 1] = Players.PlayerRemoving:Connect(function(player)
    removeVisual(player)
    local entry = protectWatchers[player]
    if entry then
        if entry.charConn then entry.charConn:Disconnect() end
        if entry.koConn then entry.koConn:Disconnect() end
        protectWatchers[player] = nil
    end
    protectedIds[player.UserId] = nil
    task.defer(refreshProtected)
end)
connections[#connections + 1] = workspace.DescendantAdded:Connect(function(obj)
    if cfg.performance then optimizeEffect(obj) end
end)
connections[#connections + 1] = game:GetService("Lighting").DescendantAdded:Connect(function(obj)
    if cfg.performance then optimizeEffect(obj) end
end)

connections[#connections + 1] = RunService.Heartbeat:Connect(function(dt)
    if cfg.fly then updateFly() end
    movementElapsed += dt
    if movementElapsed >= 0.2 then
        movementElapsed = 0
        if cfg.walkEnabled or cfg.jumpEnabled then updateMovement() end
    end
end)

RunService:BindToRenderStep(renderName, Enum.RenderPriority.Camera.Value + 1, function(dt)
    local cam = workspace.CurrentCamera
    if not cam then return end

    fov.Visible = cfg.circle
    centerDot.Visible = cfg.circle
    fov.Size = UDim2.fromOffset(cfg.radius * 2, cfg.radius * 2)
    fovStroke.Color = cfg.accent
    fovStroke.Transparency = cfg.aim and engaged and 0 or 0.25
    centerDot.BackgroundColor3 = cfg.accent

    if cfg.aim and engaged then
        local player
        if cfg.sticky then
            if not lockUsed then
                lockedPlayer = acquire(cam)
                lockUsed = lockedPlayer ~= nil
            end
            player = lockedPlayer
        else
            player = acquire(cam)
        end

        if player then
            local char, _, root, head = parts(player)
            if char then
                local part = cfg.bone == "Head" and head or root
                if not cfg.visibleOnly or unobstructed(cam, part.Position, char) then
                    aimAt(cam, part.Position, dt)
                end
            end
        end
    end

    updateAutoShoot()

    if not cfg.esp then return end

    espElapsed += dt
    local espRate = cfg.performance and math.min(cfg.espHz, 30) or cfg.espHz
    if espElapsed >= 1 / espRate then
        espElapsed = 0
        for _, player in Players:GetPlayers() do
            if player ~= localPlayer then
                drawVisual(player, cam)
            end
        end
    end
end)

local function unload()
    if unloaded then return end
    unloaded = true
    RunService:UnbindFromRenderStep(renderName)
    stopFly()
    local hum = movementHum
    if hum and hum.Parent and movementDefaults then
        if cfg.walkEnabled then hum.WalkSpeed = movementDefaults.walk end
        if cfg.jumpEnabled then
            hum.JumpPower = movementDefaults.jumpPower
            hum.JumpHeight = movementDefaults.jumpHeight
        end
    end
    cfg.protect = false
    protectVersion += 1
    table.clear(protectQueue)
    for _, entry in pairs(protectWatchers) do
        if entry.charConn then entry.charConn:Disconnect() end
        if entry.koConn then entry.koConn:Disconnect() end
    end
    table.clear(protectWatchers)
    setPerformance(false)
    for _, connection in connections do
        connection:Disconnect()
    end
    for player in pairs(visuals) do
        removeVisual(player)
    end
    overlay:Destroy()
    if not window.unloaded then window:Unload() end
    if env.VertexUnload == unload then env.VertexUnload = nil end
end

env.VertexUnload = unload
window:Notify({ title = "VERTEX", content = "Loaded. Set a key, then enable the modules you want." })
