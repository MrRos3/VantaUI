-- Vanta Universal
-- VantaUI is used only as the interface layer. All feature logic lives in this file.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = workspace.CurrentCamera

local cacheBuster = tostring(os.time()) .. "-" .. tostring(math.random(100000, 999999))
local VantaUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/MrRos3/VantaUI/main/main.lua?v=" .. cacheBuster
))()

local Window = VantaUI:CreateWindow({
    Title = "Vanta Universal",
    Icon = VantaUI.Brand.Image,
    Theme = "Salty Special",
    HideSearchBar = false,
    StartupTab = "Home",
    Branding = {
        Name = "VANTA",
        Image = VantaUI.Brand.Image,
        Folder = "VantaUI",
        IconSize = 24,
        IconRadius = 7,
        OpenButtonIconRadius = 8,
        Intro = false,
    },
    OpenButton = {
        Title = "Open Vanta Universal",
        Icon = VantaUI.Brand.Image,
        Enabled = true,
        Draggable = true,
        OnlyMobile = false,
        OnlyIcon = true,
        CornerRadius = UDim.new(0, 11),
        StrokeThickness = 2,
        ImageZoom = 1,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromHex("#000000")),
            ColorSequenceKeypoint.new(1, Color3.fromHex("#000000")),
        }),
    },
})

Window:Tag({
    Title = "Universal",
    Icon = "sparkles",
    Color = Color3.fromHex("#151116"),
    Border = true,
})

local State = {
    fly = false,
    flySpeed = 70,
    noclip = false,
    infiniteJump = false,
    walkLock = false,
    walkSpeed = 16,
    jumpLock = false,
    jumpPower = 50,
    spin = false,
    spinSpeed = 12,
    antiSit = false,
    clickTeleport = false,
    antiVoid = false,
    esp = false,
    chams = false,
    xray = false,
    fullbright = false,
    noFog = false,
    disableEffects = false,
    freecam = false,
    freecamSpeed = 64,
    fov = 70,
    fovLock = false,
    antiAfk = false,
    selectedPlayer = nil,
    savedCFrame = nil,
    deathCFrame = nil,
    lastSafeCFrame = nil,
}

local Connections = {}
local CollisionBackup = setmetatable({}, { __mode = "k" })
local XrayBackup = setmetatable({}, { __mode = "k" })
local InvisibleBackup = setmetatable({}, { __mode = "k" })
local EffectBackup = setmetatable({}, { __mode = "k" })
local PlayerVisuals = {}

local LightingBackup = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd,
    FogStart = Lighting.FogStart,
    GlobalShadows = Lighting.GlobalShadows,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    ExposureCompensation = Lighting.ExposureCompensation,
}

local CameraBackup = {}
local freecamPosition
local freecamPitch = 0
local freecamYaw = 0

local function notify(title, content, icon)
    pcall(function()
        VantaUI:Notify({
            Title = title or "Vanta Universal",
            Content = content or "",
            Icon = icon or "sparkles",
        })
    end)
end

local function safe(fn)
    local ok, err = pcall(fn)
    if not ok then
        warn("[Vanta Universal]", err)
    end
    return ok, err
end

local function disconnect(name)
    local connection = Connections[name]
    if connection then
        pcall(function()
            connection:Disconnect()
        end)
        Connections[name] = nil
    end
end

local function bind(name, connection)
    disconnect(name)
    Connections[name] = connection
    return connection
end

local function getCharacter()
    return LocalPlayer.Character
end

local function getHumanoid()
    local character = getCharacter()
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function getRoot()
    local character = getCharacter()
    if not character then
        return nil
    end
    return character:FindFirstChild("HumanoidRootPart")
        or character:FindFirstChild("Torso")
        or character:FindFirstChild("UpperTorso")
end

local function playerNames()
    local names = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(names, player.Name)
        end
    end
    table.sort(names, function(a, b)
        return a:lower() < b:lower()
    end)
    if #names == 0 then
        table.insert(names, "No players")
    end
    return names
end

local function resolvePlayer(name)
    if not name or name == "No players" then
        return nil
    end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if player.Name:lower() == tostring(name):lower() or player.DisplayName:lower() == tostring(name):lower() then
                return player
            end
        end
    end
    return nil
end

local function targetRoot(player)
    local character = player and player.Character
    return character and (character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso"))
end

-- Movement ------------------------------------------------------------------
local function stopFly()
    State.fly = false
    disconnect("flyRender")
    local root = getRoot()
    local humanoid = getHumanoid()
    if root then
        local velocity = root:FindFirstChild("VantaFlyVelocity")
        local gyro = root:FindFirstChild("VantaFlyGyro")
        if velocity then velocity:Destroy() end
        if gyro then gyro:Destroy() end
        root.AssemblyLinearVelocity = Vector3.zero
    end
    if humanoid then
        humanoid.PlatformStand = false
        humanoid.AutoRotate = true
    end
end

local function startFly()
    stopFly()
    local root = getRoot()
    local humanoid = getHumanoid()
    if not root or not humanoid then
        return false
    end

    State.fly = true
    humanoid.PlatformStand = true
    humanoid.AutoRotate = false

    local velocity = Instance.new("BodyVelocity")
    velocity.Name = "VantaFlyVelocity"
    velocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    velocity.P = 1250
    velocity.Velocity = Vector3.zero
    velocity.Parent = root

    local gyro = Instance.new("BodyGyro")
    gyro.Name = "VantaFlyGyro"
    gyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    gyro.P = 9000
    gyro.D = 250
    gyro.CFrame = root.CFrame
    gyro.Parent = root

    bind("flyRender", RunService.RenderStepped:Connect(function()
        if not State.fly then return end
        if not root.Parent or not humanoid.Parent then
            return
        end

        local camera = workspace.CurrentCamera
        local direction = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then direction += camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then direction -= camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then direction += camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then direction -= camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then direction += Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
            direction -= Vector3.yAxis
        end

        if direction.Magnitude > 0 then
            velocity.Velocity = direction.Unit * State.flySpeed
        else
            velocity.Velocity = Vector3.zero
        end

        local flatLook = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
        if flatLook.Magnitude > 0.01 then
            gyro.CFrame = CFrame.lookAt(root.Position, root.Position + flatLook.Unit)
        end
    end))

    return true
end

local function setNoclip(enabled)
    State.noclip = enabled
    if enabled then
        bind("noclip", RunService.Stepped:Connect(function()
            local character = getCharacter()
            if not character then return end
            for _, object in ipairs(character:GetDescendants()) do
                if object:IsA("BasePart") then
                    if CollisionBackup[object] == nil then
                        CollisionBackup[object] = object.CanCollide
                    end
                    object.CanCollide = false
                end
            end
        end))
    else
        disconnect("noclip")
        for part, value in pairs(CollisionBackup) do
            if part and part.Parent then
                pcall(function() part.CanCollide = value end)
            end
            CollisionBackup[part] = nil
        end
    end
end

local function setInfiniteJump(enabled)
    State.infiniteJump = enabled
    if enabled then
        bind("infiniteJump", UserInputService.JumpRequest:Connect(function()
            local humanoid = getHumanoid()
            if humanoid then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end))
    else
        disconnect("infiniteJump")
    end
end

local function setWalkLock(enabled)
    State.walkLock = enabled
    if enabled then
        bind("walkLock", RunService.Heartbeat:Connect(function()
            local humanoid = getHumanoid()
            if humanoid then humanoid.WalkSpeed = State.walkSpeed end
        end))
    else
        disconnect("walkLock")
    end
end

local function setJumpLock(enabled)
    State.jumpLock = enabled
    if enabled then
        bind("jumpLock", RunService.Heartbeat:Connect(function()
            local humanoid = getHumanoid()
            if humanoid then
                pcall(function() humanoid.UseJumpPower = true end)
                humanoid.JumpPower = State.jumpPower
            end
        end))
    else
        disconnect("jumpLock")
    end
end

local function setSpin(enabled)
    State.spin = enabled
    if enabled then
        bind("spin", RunService.Heartbeat:Connect(function()
            local root = getRoot()
            if root then
                root.AssemblyAngularVelocity = Vector3.new(0, State.spinSpeed, 0)
            end
        end))
    else
        disconnect("spin")
        local root = getRoot()
        if root then root.AssemblyAngularVelocity = Vector3.zero end
    end
end

local function setAntiSit(enabled)
    State.antiSit = enabled
    if enabled then
        bind("antiSit", RunService.Heartbeat:Connect(function()
            local humanoid = getHumanoid()
            if humanoid and humanoid.Sit then humanoid.Sit = false end
        end))
    else
        disconnect("antiSit")
    end
end

local function setClickTeleport(enabled)
    State.clickTeleport = enabled
    if enabled then
        bind("clickTeleport", Mouse.Button1Down:Connect(function()
            if not State.clickTeleport then return end
            local ctrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
                or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
            if not ctrl then return end
            local root = getRoot()
            if root and Mouse.Hit then
                root.CFrame = CFrame.new(Mouse.Hit.Position + Vector3.new(0, 3, 0))
            end
        end))
    else
        disconnect("clickTeleport")
    end
end

local function setAntiVoid(enabled)
    State.antiVoid = enabled
    if enabled then
        bind("antiVoid", RunService.Heartbeat:Connect(function()
            local root = getRoot()
            local humanoid = getHumanoid()
            if not root or not humanoid then return end

            if humanoid.FloorMaterial ~= Enum.Material.Air and root.Position.Y > workspace.FallenPartsDestroyHeight + 25 then
                State.lastSafeCFrame = root.CFrame
            end

            if root.Position.Y <= workspace.FallenPartsDestroyHeight + 12 and State.lastSafeCFrame then
                root.CFrame = State.lastSafeCFrame + Vector3.new(0, 4, 0)
                root.AssemblyLinearVelocity = Vector3.zero
            end
        end))
    else
        disconnect("antiVoid")
    end
end

-- Visuals -------------------------------------------------------------------
local function clearPlayerVisual(player)
    local info = PlayerVisuals[player]
    if info then
        if info.highlight then pcall(function() info.highlight:Destroy() end) end
        if info.billboard then pcall(function() info.billboard:Destroy() end) end
        PlayerVisuals[player] = nil
    end
end

local function visualColor(player)
    if LocalPlayer.Team ~= nil and player.Team == LocalPlayer.Team then
        return Color3.fromRGB(70, 220, 120)
    end
    return Color3.fromRGB(255, 65, 90)
end

local function applyPlayerVisual(player)
    if player == LocalPlayer then return end
    clearPlayerVisual(player)
    if not State.esp and not State.chams then return end

    local character = player.Character
    if not character then return end
    local head = character:FindFirstChild("Head")

    local info = {}
    local highlight = Instance.new("Highlight")
    highlight.Name = "VantaHighlight"
    highlight.Adornee = character
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = visualColor(player)
    highlight.OutlineColor = Color3.new(1, 1, 1)
    highlight.FillTransparency = State.chams and 0.45 or 0.78
    highlight.OutlineTransparency = 0.15
    highlight.Parent = character
    info.highlight = highlight

    if State.esp and head then
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "VantaESP"
        billboard.Adornee = head
        billboard.AlwaysOnTop = true
        billboard.Size = UDim2.fromOffset(220, 44)
        billboard.StudsOffset = Vector3.new(0, 2.8, 0)
        billboard.Parent = head

        local text = Instance.new("TextLabel")
        text.Name = "Label"
        text.BackgroundTransparency = 1
        text.Size = UDim2.fromScale(1, 1)
        text.Font = Enum.Font.GothamBold
        text.TextSize = 13
        text.TextStrokeTransparency = 0.25
        text.TextColor3 = visualColor(player)
        text.Text = player.DisplayName .. " (@" .. player.Name .. ")"
        text.Parent = billboard

        info.billboard = billboard
        info.label = text
    end

    PlayerVisuals[player] = info
end

local function refreshAllPlayerVisuals()
    for player in pairs(PlayerVisuals) do
        clearPlayerVisual(player)
    end
    for _, player in ipairs(Players:GetPlayers()) do
        applyPlayerVisual(player)
    end
end

local function ensureVisualUpdater()
    if State.esp then
        bind("espDistance", RunService.RenderStepped:Connect(function()
            local localRoot = getRoot()
            for player, info in pairs(PlayerVisuals) do
                if info.label and info.label.Parent and player.Character then
                    local root = targetRoot(player)
                    if root and localRoot then
                        local distance = math.floor((root.Position - localRoot.Position).Magnitude)
                        info.label.Text = string.format("%s (@%s)  •  %d studs", player.DisplayName, player.Name, distance)
                    end
                end
            end
        end))
    else
        disconnect("espDistance")
    end
end

local function setESP(enabled)
    State.esp = enabled
    refreshAllPlayerVisuals()
    ensureVisualUpdater()
end

local function setChams(enabled)
    State.chams = enabled
    refreshAllPlayerVisuals()
    ensureVisualUpdater()
end

local function applyXrayTo(part)
    if part:IsA("BasePart") then
        local character = getCharacter()
        if character and part:IsDescendantOf(character) then return end
        if XrayBackup[part] == nil then XrayBackup[part] = part.LocalTransparencyModifier end
        part.LocalTransparencyModifier = math.max(part.LocalTransparencyModifier, 0.65)
    end
end

local function setXray(enabled)
    State.xray = enabled
    if enabled then
        for _, object in ipairs(workspace:GetDescendants()) do
            applyXrayTo(object)
        end
        bind("xrayAdded", workspace.DescendantAdded:Connect(function(object)
            if State.xray then applyXrayTo(object) end
        end))
    else
        disconnect("xrayAdded")
        for part, value in pairs(XrayBackup) do
            if part and part.Parent then
                pcall(function() part.LocalTransparencyModifier = value end)
            end
            XrayBackup[part] = nil
        end
    end
end

local function applyFullbright()
    Lighting.Brightness = 3
    Lighting.ClockTime = 14
    Lighting.FogEnd = 1000000
    Lighting.FogStart = 0
    Lighting.GlobalShadows = false
    Lighting.Ambient = Color3.fromRGB(180, 180, 180)
    Lighting.OutdoorAmbient = Color3.fromRGB(180, 180, 180)
    Lighting.ExposureCompensation = 0.25
end

local function setFullbright(enabled)
    State.fullbright = enabled
    if enabled then
        applyFullbright()
        bind("fullbright", RunService.Heartbeat:Connect(function()
            if State.fullbright then applyFullbright() end
        end))
    else
        disconnect("fullbright")
        for property, value in pairs(LightingBackup) do
            pcall(function() Lighting[property] = value end)
        end
        if State.noFog then
            Lighting.FogEnd = 1000000
        end
    end
end

local function setNoFog(enabled)
    State.noFog = enabled
    if enabled then
        Lighting.FogEnd = 1000000
        bind("noFog", Lighting:GetPropertyChangedSignal("FogEnd"):Connect(function()
            if State.noFog and Lighting.FogEnd < 999999 then
                Lighting.FogEnd = 1000000
            end
        end))
    else
        disconnect("noFog")
        if not State.fullbright then
            Lighting.FogEnd = LightingBackup.FogEnd
            Lighting.FogStart = LightingBackup.FogStart
        end
    end
end

local effectClasses = {
    BloomEffect = true,
    BlurEffect = true,
    ColorCorrectionEffect = true,
    DepthOfFieldEffect = true,
    SunRaysEffect = true,
}

local function setDisableEffects(enabled)
    State.disableEffects = enabled
    if enabled then
        for _, object in ipairs(Lighting:GetDescendants()) do
            if effectClasses[object.ClassName] and object:IsA("PostEffect") then
                if EffectBackup[object] == nil then EffectBackup[object] = object.Enabled end
                object.Enabled = false
            end
        end
        bind("effectsAdded", Lighting.DescendantAdded:Connect(function(object)
            if State.disableEffects and effectClasses[object.ClassName] and object:IsA("PostEffect") then
                EffectBackup[object] = object.Enabled
                object.Enabled = false
            end
        end))
    else
        disconnect("effectsAdded")
        for object, enabledValue in pairs(EffectBackup) do
            if object and object.Parent then
                pcall(function() object.Enabled = enabledValue end)
            end
            EffectBackup[object] = nil
        end
    end
end

local function showInvisibleParts(enabled)
    if enabled then
        for _, object in ipairs(workspace:GetDescendants()) do
            if object:IsA("BasePart") and object.Transparency >= 0.95 then
                InvisibleBackup[object] = object.LocalTransparencyModifier
                object.LocalTransparencyModifier = -0.5
            end
        end
    else
        for part, value in pairs(InvisibleBackup) do
            if part and part.Parent then
                pcall(function() part.LocalTransparencyModifier = value end)
            end
            InvisibleBackup[part] = nil
        end
    end
end

local function fpsBoost()
    for _, object in ipairs(workspace:GetDescendants()) do
        if object:IsA("BasePart") then
            object.Material = Enum.Material.Plastic
            object.Reflectance = 0
        elseif object:IsA("Decal") or object:IsA("Texture") then
            object.Transparency = math.max(object.Transparency, 0.35)
        elseif object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam") then
            object.Enabled = false
        end
    end
    setDisableEffects(true)
    Lighting.GlobalShadows = false
    notify("FPS Boost", "Client-side visual effects were reduced.", "gauge")
end

-- Camera --------------------------------------------------------------------
local function setFovLock(enabled)
    State.fovLock = enabled
    Camera = workspace.CurrentCamera
    if Camera then Camera.FieldOfView = State.fov end
    if enabled then
        bind("fovLock", RunService.RenderStepped:Connect(function()
            local camera = workspace.CurrentCamera
            if camera and camera.FieldOfView ~= State.fov then
                camera.FieldOfView = State.fov
            end
        end))
    else
        disconnect("fovLock")
    end
end

local function stopFreecam()
    if not State.freecam then return end
    State.freecam = false
    disconnect("freecam")
    local camera = workspace.CurrentCamera
    if camera then
        camera.CameraType = CameraBackup.CameraType or Enum.CameraType.Custom
        camera.CFrame = CameraBackup.CFrame or camera.CFrame
        camera.FieldOfView = CameraBackup.FieldOfView or State.fov
        local humanoid = getHumanoid()
        if humanoid then camera.CameraSubject = humanoid end
    end
    UserInputService.MouseBehavior = CameraBackup.MouseBehavior or Enum.MouseBehavior.Default
    UserInputService.MouseIconEnabled = CameraBackup.MouseIconEnabled ~= false
end

local function startFreecam()
    stopFreecam()
    local camera = workspace.CurrentCamera
    if not camera then return false end

    State.freecam = true
    CameraBackup.CameraType = camera.CameraType
    CameraBackup.CFrame = camera.CFrame
    CameraBackup.FieldOfView = camera.FieldOfView
    CameraBackup.MouseBehavior = UserInputService.MouseBehavior
    CameraBackup.MouseIconEnabled = UserInputService.MouseIconEnabled

    freecamPosition = camera.CFrame.Position
    local rx, ry = camera.CFrame:ToOrientation()
    freecamPitch = rx
    freecamYaw = ry

    camera.CameraType = Enum.CameraType.Scriptable
    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    UserInputService.MouseIconEnabled = false

    bind("freecam", RunService.RenderStepped:Connect(function(dt)
        if not State.freecam then return end
        local cam = workspace.CurrentCamera
        if not cam then return end

        local delta = UserInputService:GetMouseDelta()
        freecamYaw -= delta.X * 0.0025
        freecamPitch = math.clamp(freecamPitch - delta.Y * 0.0025, math.rad(-89), math.rad(89))

        local rotation = CFrame.Angles(0, freecamYaw, 0) * CFrame.Angles(freecamPitch, 0, 0)
        local move = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += Vector3.new(0, 0, -1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then move += Vector3.new(0, 0, 1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += Vector3.new(1, 0, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then move += Vector3.new(-1, 0, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.E) then move += Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.Q) then move += Vector3.new(0, -1, 0) end

        local speed = State.freecamSpeed
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then speed *= 3 end
        if move.Magnitude > 0 then
            move = move.Unit
            local worldMove = rotation:VectorToWorldSpace(move)
            freecamPosition += worldMove * speed * dt
        end

        cam.CFrame = CFrame.new(freecamPosition) * rotation
    end))
    return true
end

local function stopSpectate()
    local camera = workspace.CurrentCamera
    local humanoid = getHumanoid()
    if camera and humanoid then
        camera.CameraType = Enum.CameraType.Custom
        camera.CameraSubject = humanoid
    end
end

-- Server / session ------------------------------------------------------------
local function setAntiAfk(enabled)
    State.antiAfk = enabled
    if enabled then
        bind("antiAfk", LocalPlayer.Idled:Connect(function()
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new(0, 0))
            end)
        end))
    else
        disconnect("antiAfk")
    end
end

local function serverHop()
    task.spawn(function()
        local ok, result = pcall(function()
            return game:HttpGet(string.format(
                "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&excludeFullGames=true",
                game.PlaceId
            ))
        end)
        if not ok then
            notify("Server Hop", "Could not fetch the public server list.", "triangle-alert")
            return
        end

        local decodedOk, data = pcall(function() return HttpService:JSONDecode(result) end)
        if not decodedOk or type(data) ~= "table" or type(data.data) ~= "table" then
            notify("Server Hop", "Roblox returned an invalid server list.", "triangle-alert")
            return
        end

        for _, server in ipairs(data.data) do
            if server.id ~= game.JobId and tonumber(server.playing or 0) < tonumber(server.maxPlayers or 0) then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
                return
            end
        end
        notify("Server Hop", "No different non-full server was found on this page.", "info")
    end)
end

-- Character lifecycle ---------------------------------------------------------
local flyToggle

local function hookCharacter(character)
    task.defer(function()
        local humanoid = character:WaitForChild("Humanoid", 10)
        local root = character:WaitForChild("HumanoidRootPart", 10)
        if humanoid and root then
            bind("deathTracker", humanoid.Died:Connect(function()
                State.deathCFrame = root.CFrame
            end))

            if State.walkLock then humanoid.WalkSpeed = State.walkSpeed end
            if State.jumpLock then
                pcall(function() humanoid.UseJumpPower = true end)
                humanoid.JumpPower = State.jumpPower
            end
            if State.fly then
                task.wait(0.25)
                startFly()
                if flyToggle then pcall(function() flyToggle:Set(true, false, true) end) end
            end
            if State.noclip then setNoclip(true) end
        end
    end)
end

if LocalPlayer.Character then hookCharacter(LocalPlayer.Character) end
bind("characterAdded", LocalPlayer.CharacterAdded:Connect(hookCharacter))

-- Player lifecycle for ESP / dropdowns ---------------------------------------
local targetDropdown
local spectateDropdown

local function refreshPlayerDropdowns()
    local values = playerNames()
    if targetDropdown then pcall(function() targetDropdown:Refresh(values) end) end
    if spectateDropdown then pcall(function() spectateDropdown:Refresh(values) end) end
end

local function hookOtherPlayer(player)
    if player == LocalPlayer then return end
    player.CharacterAdded:Connect(function()
        task.wait(0.5)
        if State.esp or State.chams then applyPlayerVisual(player) end
    end)
end

for _, player in ipairs(Players:GetPlayers()) do hookOtherPlayer(player) end
bind("playerAdded", Players.PlayerAdded:Connect(function(player)
    hookOtherPlayer(player)
    refreshPlayerDropdowns()
end))
bind("playerRemoving", Players.PlayerRemoving:Connect(function(player)
    clearPlayerVisual(player)
    if State.selectedPlayer == player then State.selectedPlayer = nil end
    refreshPlayerDropdowns()
end))

-- Tabs -----------------------------------------------------------------------
local Home = Window:Tab({ Title = "Home", Icon = "house" })
local PlayerTab = Window:Tab({ Title = "Player", Icon = "user" })
local Movement = Window:Tab({ Title = "Movement", Icon = "move" })
local Visuals = Window:Tab({ Title = "Visuals", Icon = "eye" })
local CameraTab = Window:Tab({ Title = "Camera", Icon = "camera" })
local TeleportTab = Window:Tab({ Title = "Teleport", Icon = "map-pin" })
local ServerTab = Window:Tab({ Title = "Server", Icon = "server" })
local Misc = Window:Tab({ Title = "Misc", Icon = "wrench" })
local Themes = Window:Tab({ Title = "Themes", Icon = "palette" })

Home:Paragraph({
    Title = "Vanta Universal",
    Desc = "VantaUI is only the GUI. Fly, noclip, ESP, camera tools, teleport tools and the rest are implemented directly inside this script — no Infinite Yield backend is loaded.",
    Icon = "sparkles",
})

Home:Button({
    Title = "Runtime Info",
    Desc = "Shows VantaUI and current session information.",
    Icon = "info",
    Callback = function()
        notify(
            "Vanta Universal",
            string.format("VantaUI %s • Place %s • %d/%d players", tostring(VantaUI.Version), tostring(game.PlaceId), #Players:GetPlayers(), Players.MaxPlayers),
            "package"
        )
    end,
})

Home:Button({
    Title = "Reset All Runtime Features",
    Desc = "Turns off movement, visual, camera and session loops started by this script.",
    Icon = "rotate-ccw",
    Callback = function()
        stopFly()
        setNoclip(false)
        setInfiniteJump(false)
        setWalkLock(false)
        setJumpLock(false)
        setSpin(false)
        setAntiSit(false)
        setClickTeleport(false)
        setAntiVoid(false)
        setESP(false)
        setChams(false)
        setXray(false)
        setFullbright(false)
        setNoFog(false)
        setDisableEffects(false)
        showInvisibleParts(false)
        stopFreecam()
        stopSpectate()
        setFovLock(false)
        setAntiAfk(false)
        notify("Reset", "Vanta Universal runtime features were disabled.", "check")
    end,
})

-- Player tab -----------------------------------------------------------------
PlayerTab:Button({
    Title = "Sit",
    Icon = "armchair",
    Callback = function()
        local humanoid = getHumanoid()
        if humanoid then humanoid.Sit = true end
    end,
})

PlayerTab:Button({
    Title = "Stand",
    Icon = "person-standing",
    Callback = function()
        local humanoid = getHumanoid()
        if humanoid then
            humanoid.Sit = false
            humanoid.PlatformStand = false
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end,
})

PlayerTab:Toggle({
    Title = "Anti Sit",
    Desc = "Immediately stands back up if a seat tries to sit your character.",
    Icon = "shield",
    Value = false,
    Callback = setAntiSit,
})

PlayerTab:Button({
    Title = "Respawn",
    Desc = "Respawns your local character.",
    Icon = "refresh-cw",
    Callback = function()
        local humanoid = getHumanoid()
        if humanoid then humanoid.Health = 0 end
    end,
})

PlayerTab:Button({
    Title = "Refresh Position",
    Desc = "Respawns and returns to the same position when possible.",
    Icon = "map-pin-check",
    Callback = function()
        local root = getRoot()
        local humanoid = getHumanoid()
        if not root or not humanoid then return end
        local saved = root.CFrame
        humanoid.Health = 0
        task.spawn(function()
            local character = LocalPlayer.CharacterAdded:Wait()
            local newRoot = character:WaitForChild("HumanoidRootPart", 10)
            if newRoot then
                task.wait(0.3)
                newRoot.CFrame = saved
            end
        end)
    end,
})

PlayerTab:Button({
    Title = "Remove Accessories (Client)",
    Desc = "Removes accessories from your character locally.",
    Icon = "eraser",
    Callback = function()
        local character = getCharacter()
        if not character then return end
        for _, object in ipairs(character:GetChildren()) do
            if object:IsA("Accessory") then object:Destroy() end
        end
    end,
})

-- Movement tab ---------------------------------------------------------------
flyToggle = Movement:Toggle({
    Title = "Fly",
    Desc = "Camera-relative flight. W/A/S/D move, Space up, Ctrl down. Press F to toggle too.",
    Icon = "plane",
    Value = false,
    Callback = function(value)
        if value then
            if not startFly() then
                notify("Fly", "Character root was not ready.", "triangle-alert")
                pcall(function() flyToggle:Set(false, false, true) end)
            end
        else
            stopFly()
        end
    end,
})

Movement:Input({
    Title = "Fly Speed",
    Desc = "Movement speed used by Fly.",
    Value = tostring(State.flySpeed),
    Type = "Input",
    Placeholder = "70",
    Callback = function(value)
        State.flySpeed = math.clamp(tonumber(value) or State.flySpeed, 1, 1000)
    end,
})

Movement:Toggle({
    Title = "Noclip",
    Desc = "Disables collisions on your character while enabled.",
    Icon = "move-3d",
    Value = false,
    Callback = setNoclip,
})

Movement:Toggle({
    Title = "Infinite Jump",
    Desc = "Allows jumping again while airborne.",
    Icon = "arrow-up",
    Value = false,
    Callback = setInfiniteJump,
})

Movement:Input({
    Title = "Walk Speed",
    Desc = "Value used by Walk Speed Lock.",
    Value = tostring(State.walkSpeed),
    Type = "Input",
    Placeholder = "16",
    Callback = function(value)
        State.walkSpeed = math.clamp(tonumber(value) or State.walkSpeed, 0, 1000)
        if State.walkLock then
            local humanoid = getHumanoid()
            if humanoid then humanoid.WalkSpeed = State.walkSpeed end
        end
    end,
})

Movement:Toggle({
    Title = "Walk Speed Lock",
    Desc = "Continuously keeps your WalkSpeed at the value above.",
    Icon = "gauge",
    Value = false,
    Callback = setWalkLock,
})

Movement:Input({
    Title = "Jump Power",
    Desc = "Value used by Jump Power Lock.",
    Value = tostring(State.jumpPower),
    Type = "Input",
    Placeholder = "50",
    Callback = function(value)
        State.jumpPower = math.clamp(tonumber(value) or State.jumpPower, 0, 1000)
    end,
})

Movement:Toggle({
    Title = "Jump Power Lock",
    Desc = "Continuously keeps your JumpPower at the value above.",
    Icon = "arrow-up-from-line",
    Value = false,
    Callback = setJumpLock,
})

Movement:Input({
    Title = "Gravity",
    Desc = "Changes workspace gravity for your client.",
    Value = tostring(workspace.Gravity),
    Type = "Input",
    Placeholder = "196.2",
    Callback = function(value)
        local number = tonumber(value)
        if number then workspace.Gravity = number end
    end,
})

Movement:Button({
    Title = "Reset Gravity",
    Icon = "rotate-ccw",
    Callback = function()
        workspace.Gravity = 196.2
    end,
})

Movement:Input({
    Title = "Spin Speed",
    Desc = "Angular velocity used by Spin.",
    Value = tostring(State.spinSpeed),
    Type = "Input",
    Placeholder = "12",
    Callback = function(value)
        State.spinSpeed = math.clamp(tonumber(value) or State.spinSpeed, -500, 500)
    end,
})

Movement:Toggle({
    Title = "Spin",
    Icon = "refresh-cw",
    Value = false,
    Callback = setSpin,
})

Movement:Toggle({
    Title = "Anti Void",
    Desc = "Returns you to the last grounded position if you fall below the destroy height.",
    Icon = "shield-alert",
    Value = false,
    Callback = setAntiVoid,
})

-- Visuals tab ----------------------------------------------------------------
Visuals:Toggle({
    Title = "ESP",
    Desc = "Player names, usernames and distance with always-on-top highlights.",
    Icon = "scan-eye",
    Value = false,
    Callback = setESP,
})

Visuals:Toggle({
    Title = "Chams",
    Desc = "Always-on-top player highlights without requiring labels.",
    Icon = "scan",
    Value = false,
    Callback = setChams,
})

Visuals:Toggle({
    Title = "X-Ray",
    Desc = "Makes world geometry partially transparent on your client.",
    Icon = "layers",
    Value = false,
    Callback = setXray,
})

Visuals:Toggle({
    Title = "Fullbright",
    Desc = "Continuously keeps the client lighting bright and readable.",
    Icon = "sun",
    Value = false,
    Callback = setFullbright,
})

Visuals:Toggle({
    Title = "No Fog",
    Desc = "Keeps FogEnd far away while enabled.",
    Icon = "cloud-off",
    Value = false,
    Callback = setNoFog,
})

Visuals:Toggle({
    Title = "Disable Post Effects",
    Desc = "Disables blur, bloom, depth of field, sun rays and color correction locally.",
    Icon = "sparkles-off",
    Value = false,
    Callback = setDisableEffects,
})

Visuals:Toggle({
    Title = "Show Invisible Parts",
    Desc = "Reveals fully transparent BaseParts locally.",
    Icon = "eye",
    Value = false,
    Callback = showInvisibleParts,
})

Visuals:Button({
    Title = "Day",
    Icon = "sun",
    Callback = function() Lighting.ClockTime = 14 end,
})

Visuals:Button({
    Title = "Night",
    Icon = "moon",
    Callback = function() Lighting.ClockTime = 0 end,
})

Visuals:Button({
    Title = "FPS Boost",
    Desc = "Reduces client-side materials and effects for performance.",
    Icon = "gauge",
    Callback = fpsBoost,
})

-- Camera tab -----------------------------------------------------------------
CameraTab:Input({
    Title = "Field of View",
    Desc = "Camera FOV value.",
    Value = tostring(State.fov),
    Type = "Input",
    Placeholder = "70",
    Callback = function(value)
        State.fov = math.clamp(tonumber(value) or State.fov, 1, 120)
        local camera = workspace.CurrentCamera
        if camera then camera.FieldOfView = State.fov end
    end,
})

CameraTab:Toggle({
    Title = "FOV Lock",
    Desc = "Prevents the game from changing your selected FOV.",
    Icon = "focus",
    Value = false,
    Callback = setFovLock,
})

CameraTab:Button({
    Title = "First Person",
    Icon = "scan-face",
    Callback = function()
        LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
    end,
})

CameraTab:Button({
    Title = "Third Person",
    Icon = "person-standing",
    Callback = function()
        LocalPlayer.CameraMode = Enum.CameraMode.Classic
        LocalPlayer.CameraMinZoomDistance = 0.5
        LocalPlayer.CameraMaxZoomDistance = 128
    end,
})

spectateDropdown = CameraTab:Dropdown({
    Title = "Spectate Player",
    Desc = "Choose a player for camera spectate.",
    Values = playerNames(),
    Value = playerNames()[1],
    SearchBarEnabled = true,
    Callback = function(value)
        State.selectedPlayer = resolvePlayer(value)
    end,
})

CameraTab:Button({
    Title = "Start Spectating",
    Icon = "eye",
    Callback = function()
        local player = State.selectedPlayer
        local humanoid = player and player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            local camera = workspace.CurrentCamera
            camera.CameraType = Enum.CameraType.Custom
            camera.CameraSubject = humanoid
        else
            notify("Spectate", "Select an available player first.", "info")
        end
    end,
})

CameraTab:Button({
    Title = "Stop Spectating",
    Icon = "eye-off",
    Callback = stopSpectate,
})

CameraTab:Input({
    Title = "Freecam Speed",
    Desc = "W/A/S/D move, Q/E vertical, Shift boosts speed, mouse looks around.",
    Value = tostring(State.freecamSpeed),
    Type = "Input",
    Placeholder = "64",
    Callback = function(value)
        State.freecamSpeed = math.clamp(tonumber(value) or State.freecamSpeed, 1, 1000)
    end,
})

CameraTab:Toggle({
    Title = "Freecam",
    Desc = "Detaches the camera and gives full keyboard/mouse movement.",
    Icon = "video",
    Value = false,
    Callback = function(value)
        if value then startFreecam() else stopFreecam() end
    end,
})

CameraTab:Button({
    Title = "Reset Camera",
    Icon = "refresh-cw",
    Callback = function()
        stopFreecam()
        stopSpectate()
        local camera = workspace.CurrentCamera
        if camera then
            camera.CameraType = Enum.CameraType.Custom
            camera.FieldOfView = State.fov
        end
    end,
})

-- Teleport tab ---------------------------------------------------------------
targetDropdown = TeleportTab:Dropdown({
    Title = "Target Player",
    Desc = "Choose a player for teleport actions.",
    Values = playerNames(),
    Value = playerNames()[1],
    SearchBarEnabled = true,
    Callback = function(value)
        State.selectedPlayer = resolvePlayer(value)
    end,
})

TeleportTab:Button({
    Title = "Go To Player",
    Icon = "map-pin",
    Callback = function()
        local root = getRoot()
        local target = targetRoot(State.selectedPlayer)
        if root and target then
            root.CFrame = target.CFrame * CFrame.new(0, 0, 3)
        else
            notify("Teleport", "Select an available player first.", "info")
        end
    end,
})

local tweenSpeed = 150
TeleportTab:Input({
    Title = "Tween Speed",
    Desc = "Studs per second used by Tween To Player.",
    Value = tostring(tweenSpeed),
    Type = "Input",
    Placeholder = "150",
    Callback = function(value)
        tweenSpeed = math.clamp(tonumber(value) or tweenSpeed, 1, 5000)
    end,
})

TeleportTab:Button({
    Title = "Tween To Player",
    Icon = "route",
    Callback = function()
        local root = getRoot()
        local target = targetRoot(State.selectedPlayer)
        if not root or not target then
            notify("Teleport", "Select an available player first.", "info")
            return
        end
        local destination = target.CFrame * CFrame.new(0, 0, 3)
        local distance = (root.Position - destination.Position).Magnitude
        TweenService:Create(root, TweenInfo.new(distance / tweenSpeed, Enum.EasingStyle.Linear), { CFrame = destination }):Play()
    end,
})

TeleportTab:Button({
    Title = "Save Position",
    Icon = "bookmark",
    Callback = function()
        local root = getRoot()
        if root then
            State.savedCFrame = root.CFrame
            notify("Position Saved", "Current position stored for this session.", "bookmark")
        end
    end,
})

TeleportTab:Button({
    Title = "Return To Saved Position",
    Icon = "undo-2",
    Callback = function()
        local root = getRoot()
        if root and State.savedCFrame then
            root.CFrame = State.savedCFrame
        else
            notify("Saved Position", "No saved position exists yet.", "info")
        end
    end,
})

TeleportTab:Button({
    Title = "Return To Death Position",
    Icon = "skull",
    Callback = function()
        local root = getRoot()
        if root and State.deathCFrame then
            root.CFrame = State.deathCFrame + Vector3.new(0, 3, 0)
        else
            notify("Death Position", "No death position has been recorded yet.", "info")
        end
    end,
})

TeleportTab:Toggle({
    Title = "Ctrl + Click Teleport",
    Desc = "Hold Ctrl and click the world to teleport your character there.",
    Icon = "mouse-pointer-click",
    Value = false,
    Callback = setClickTeleport,
})

TeleportTab:Button({
    Title = "Teleport To Camera",
    Icon = "camera",
    Callback = function()
        local root = getRoot()
        local camera = workspace.CurrentCamera
        if root and camera then root.CFrame = camera.CFrame end
    end,
})

-- Server tab -----------------------------------------------------------------
ServerTab:Toggle({
    Title = "Anti AFK",
    Desc = "Sends a harmless local input when Roblox marks you idle.",
    Icon = "coffee",
    Value = false,
    Callback = setAntiAfk,
})

ServerTab:Button({
    Title = "Server Info",
    Icon = "info",
    Callback = function()
        notify(
            "Server Info",
            string.format("Players %d/%d • PlaceId %s • JobId %s", #Players:GetPlayers(), Players.MaxPlayers, tostring(game.PlaceId), tostring(game.JobId)),
            "server"
        )
    end,
})

ServerTab:Button({
    Title = "Copy Job ID",
    Icon = "copy",
    Callback = function()
        if type(setclipboard) == "function" then
            setclipboard(tostring(game.JobId))
            notify("Clipboard", "Job ID copied.", "copy")
        else
            notify("Clipboard", "This executor does not expose setclipboard.", "info")
        end
    end,
})

ServerTab:Button({
    Title = "Copy Place ID",
    Icon = "copy",
    Callback = function()
        if type(setclipboard) == "function" then
            setclipboard(tostring(game.PlaceId))
            notify("Clipboard", "Place ID copied.", "copy")
        else
            notify("Clipboard", "This executor does not expose setclipboard.", "info")
        end
    end,
})

ServerTab:Button({
    Title = "Rejoin",
    Icon = "refresh-cw",
    Callback = function()
        if #Players:GetPlayers() <= 1 then
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        else
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end
    end,
})

ServerTab:Button({
    Title = "Server Hop",
    Desc = "Moves to another public non-full server when one is available.",
    Icon = "shuffle",
    Callback = serverHop,
})

-- Misc tab -------------------------------------------------------------------
Misc:Input({
    Title = "FPS Cap",
    Desc = "Applies setfpscap when your executor provides it.",
    Value = "240",
    Type = "Input",
    Placeholder = "240",
    Callback = function(value)
        local cap = tonumber(value)
        if cap and type(setfpscap) == "function" then
            pcall(setfpscap, math.clamp(cap, 15, 1000))
        end
    end,
})

Misc:Button({
    Title = "Copy Coordinates",
    Icon = "copy",
    Callback = function()
        local root = getRoot()
        if not root then return end
        local p = root.Position
        local text = string.format("%.3f, %.3f, %.3f", p.X, p.Y, p.Z)
        if type(setclipboard) == "function" then
            setclipboard(text)
            notify("Coordinates", text .. " copied.", "copy")
        else
            notify("Coordinates", text, "map-pin")
        end
    end,
})

Misc:Button({
    Title = "Zero Velocity",
    Desc = "Stops current linear and angular character velocity.",
    Icon = "circle-stop",
    Callback = function()
        local root = getRoot()
        if root then
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end,
})

Misc:Button({
    Title = "Reset Lighting",
    Icon = "sun",
    Callback = function()
        setFullbright(false)
        setNoFog(false)
        setDisableEffects(false)
        for property, value in pairs(LightingBackup) do
            pcall(function() Lighting[property] = value end)
        end
    end,
})

-- Themes ---------------------------------------------------------------------
local function addThemeButton(themeName, icon)
    Themes:Button({
        Title = themeName,
        Desc = "Switch Vanta Universal to " .. themeName .. ".",
        Icon = icon,
        Callback = function()
            VantaUI:SetTheme(themeName)
            notify("Theme", "Changed to " .. themeName .. ".", icon)
        end,
    })
end

addThemeButton("Salty Special", "sparkles")
addThemeButton("Vanta Smoked", "cloud-fog")
addThemeButton("Vanta Dark", "moon")
addThemeButton("Vanta AMOLED", "circle-dot")
addThemeButton("Vanta Violet", "wand-sparkles")

-- Global F fly shortcut. Ignore F while typing in an input box.
bind("flyKeybind", UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.F then
        local nextValue = not State.fly
        if flyToggle then
            pcall(function() flyToggle:Set(nextValue, true, true) end)
        else
            if nextValue then startFly() else stopFly() end
        end
    end
end))

refreshPlayerDropdowns()
notify("Vanta Universal", "Loaded with VantaUI as the GUI only. Press F to toggle Fly.", "sparkles")

return {
    UI = VantaUI,
    Window = Window,
    State = State,
    StartFly = startFly,
    StopFly = stopFly,
}
