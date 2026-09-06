-- VantaUI x Infinite Yield bridge
-- Keeps VantaUI as the visible interface while using the official Infinite Yield
-- command engine underneath. Infinite Yield is licensed under the MIT License.
-- Source: https://github.com/EdgeIY/infiniteyield

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local ENV = (getgenv and getgenv()) or _G
local IY_SOURCE = "https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"
local VANTA_SOURCE = "https://raw.githubusercontent.com/MrRos3/VantaUI/main/main.lua"

local function httpGet(url)
    local ok, result = pcall(function()
        return game:HttpGet(url)
    end)
    if not ok then
        error("[VantaUI/IY] HTTP request failed: " .. tostring(result), 0)
    end
    return result
end

local function loadChunk(source, name)
    local fn, err = loadstring(source)
    if not fn then
        error("[VantaUI/IY] Failed to compile " .. tostring(name) .. ": " .. tostring(err), 0)
    end
    return fn()
end

-- Load Infinite Yield once. Its globals (execCmd, CMDs, etc.) become the backend
-- used by the VantaUI shell below.
local function ensureInfiniteYield()
    if type(ENV.execCmd) == "function" and type(ENV.CMDs) == "table" then
        return
    end

    ENV.IY_LOADED = nil
    loadChunk(httpGet(IY_SOURCE), "Infinite Yield")
end

ensureInfiniteYield()

local execCommand = ENV.execCmd or execCmd
local commandMetadata = ENV.CMDs or CMDs or {}

if type(execCommand) ~= "function" then
    error("[VantaUI/IY] Infinite Yield command engine was not found after loading.", 0)
end

-- Hide Infinite Yield's normal command bar. We leave its support windows alive so
-- commands such as logs/server-info that own a special view can still function.
local function hideLegacyMainUI()
    local holder = ENV.Holder or Holder
    local scaledHolder = ENV.ScaledHolder or ScaledHolder
    local settings = ENV.Settings or Settings

    for _, object in ipairs({holder, scaledHolder, settings}) do
        if typeof(object) == "Instance" and object:IsA("GuiObject") then
            object.Visible = false
        end
    end

    if typeof(holder) == "Instance" and holder:IsA("GuiObject") then
        holder:GetPropertyChangedSignal("Visible"):Connect(function()
            if holder.Visible then
                holder.Visible = false
            end
        end)
    end
end

hideLegacyMainUI()

local cacheBuster = tostring(os.time()) .. "-" .. tostring(math.random(100000, 999999))
local VantaUI = loadChunk(httpGet(VANTA_SOURCE .. "?v=" .. cacheBuster), "VantaUI")

local Window = VantaUI:CreateWindow({
    Title = "VantaUI • Infinite Yield",
    Icon = VantaUI.Brand.Image,
    Theme = "Vanta AMOLED",
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
        Title = "Open VantaUI",
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
    Title = "IY " .. tostring(ENV.currentVersion or currentVersion or "6.x"),
    Icon = "terminal",
    Color = Color3.fromHex("#151116"),
    Border = true,
})

local function vantaNotify(title, content, icon)
    pcall(function()
        VantaUI:Notify({
            Title = title or "VantaUI",
            Content = content or "",
            Icon = icon or "terminal",
        })
    end)
end

-- Route normal Infinite Yield notifications through VantaUI whenever commands use
-- the global notify helper.
local oldIYNotify = ENV.notify or notify
ENV.notify = function(title, text, duration)
    local notificationTitle = tostring(title or "Infinite Yield")
    local notificationText = text ~= nil and tostring(text) or notificationTitle
    if text == nil then
        notificationTitle = "Infinite Yield"
    end

    local ok = pcall(function()
        VantaUI:Notify({
            Title = notificationTitle,
            Content = notificationText,
            Icon = "terminal",
            Duration = tonumber(duration) or 4,
        })
    end)

    if not ok and type(oldIYNotify) == "function" then
        pcall(oldIYNotify, title, text, duration)
    end
end

local lastCommand = ""

local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$") or ""
end

local function runCommand(text)
    local command = trim(text)
    if command == "" then
        return
    end

    lastCommand = command
    local ok, err = pcall(function()
        execCommand(command, LocalPlayer, true)
    end)

    if not ok then
        vantaNotify("Command failed", tostring(err), "triangle-alert")
    end
end

local function commandBase(syntax)
    return tostring(syntax or ""):match("^%s*([^%s/]+)")
end

local function commandTemplate(syntax)
    syntax = tostring(syntax or "")
    local base = commandBase(syntax)
    if not base then
        return ""
    end

    local placeholders = {}
    for placeholder in syntax:gmatch("%b[]") do
        table.insert(placeholders, placeholder)
    end

    if #placeholders > 0 then
        return base .. " " .. table.concat(placeholders, " ")
    end
    return base
end

local function requiresArguments(syntax)
    return tostring(syntax or ""):find("[", 1, true) ~= nil
end

local Home = Window:Tab({
    Title = "Home",
    Icon = "house",
})

local Movement = Window:Tab({
    Title = "Movement",
    Icon = "move",
})

local Visuals = Window:Tab({
    Title = "Visuals",
    Icon = "eye",
})

local Camera = Window:Tab({
    Title = "Camera",
    Icon = "camera",
})

local Server = Window:Tab({
    Title = "Server",
    Icon = "server",
})

local CommandsAF = Window:Tab({
    Title = "Commands A-F",
    Icon = "list-filter",
})

local CommandsGL = Window:Tab({
    Title = "Commands G-L",
    Icon = "list-filter",
})

local CommandsMR = Window:Tab({
    Title = "Commands M-R",
    Icon = "list-filter",
})

local CommandsSZ = Window:Tab({
    Title = "Commands S-Z",
    Icon = "list-filter",
})

local CommandsMisc = Window:Tab({
    Title = "Commands Misc",
    Icon = "list",
})

Home:Paragraph({
    Title = "Infinite Yield, wearing VantaUI",
    Desc = "The original Infinite Yield command bar is hidden. Its command engine stays loaded underneath, while VantaUI provides the visible controls, search, command catalog, and quick actions.",
    Icon = "sparkles",
})

local commandText = ""
local runnerInput = Home:Input({
    Title = "Command Runner",
    Desc = "Type any Infinite Yield command here, then press Run Command.",
    Value = "",
    Type = "Input",
    Placeholder = "Example: fly 2",
    Callback = function(value)
        commandText = tostring(value or "")
    end,
})

Home:Button({
    Title = "Run Command",
    Desc = "Runs the command currently entered above.",
    Icon = "play",
    Callback = function()
        runCommand(commandText)
    end,
})

Home:Button({
    Title = "Run Last Command",
    Desc = "Runs the previous Vanta command again.",
    Icon = "rotate-ccw",
    Callback = function()
        if lastCommand == "" then
            vantaNotify("Nothing to repeat", "Run a command first.", "info")
            return
        end
        runCommand(lastCommand)
    end,
})

Home:Button({
    Title = "Infinite Yield command count",
    Desc = "Shows how many command entries were imported into the VantaUI catalog.",
    Icon = "list",
    Callback = function()
        local count = 0
        for _, entry in ipairs(commandMetadata) do
            if type(entry) == "table" and trim(entry.NAME) ~= "" then
                count += 1
            end
        end
        vantaNotify("Command catalog", tostring(count) .. " Infinite Yield command entries loaded.", "list")
    end,
})

-- Quick movement controls -----------------------------------------------------
local flyEnabled = false
local flyToggle

local function setFly(enabled, syncToggle)
    flyEnabled = enabled and true or false
    runCommand(flyEnabled and "fly" or "unfly")
    if syncToggle and flyToggle then
        pcall(function()
            flyToggle:Set(flyEnabled, false, true)
        end)
    end
end

flyToggle = Movement:Toggle({
    Title = "Fly",
    Desc = "Infinite Yield fly. Press F anywhere to toggle it too.",
    Icon = "plane",
    Value = false,
    Callback = function(value)
        flyEnabled = value and true or false
        runCommand(flyEnabled and "fly" or "unfly")
    end,
})

Movement:Toggle({
    Title = "Noclip",
    Desc = "Walk through collisions. Turning it off runs clip.",
    Icon = "move-3d",
    Value = false,
    Callback = function(value)
        runCommand(value and "noclip" or "clip")
    end,
})

Movement:Toggle({
    Title = "Infinite Jump",
    Desc = "Allows repeated jumping while airborne.",
    Icon = "arrow-up",
    Value = false,
    Callback = function(value)
        runCommand(value and "infinitejump" or "uninfinitejump")
    end,
})

local walkSpeedValue = "16"
Movement:Input({
    Title = "Walk Speed",
    Desc = "Set the number, then press Apply Walk Speed.",
    Value = walkSpeedValue,
    Type = "Input",
    Placeholder = "16",
    Callback = function(value)
        walkSpeedValue = tostring(value or "16")
    end,
})
Movement:Button({
    Title = "Apply Walk Speed",
    Icon = "gauge",
    Callback = function()
        runCommand("walkspeed " .. walkSpeedValue)
    end,
})

local jumpPowerValue = "50"
Movement:Input({
    Title = "Jump Power",
    Desc = "Set the number, then press Apply Jump Power.",
    Value = jumpPowerValue,
    Type = "Input",
    Placeholder = "50",
    Callback = function(value)
        jumpPowerValue = tostring(value or "50")
    end,
})
Movement:Button({
    Title = "Apply Jump Power",
    Icon = "arrow-up-from-line",
    Callback = function()
        runCommand("jumppower " .. jumpPowerValue)
    end,
})

local gravityValue = tostring(workspace.Gravity)
Movement:Input({
    Title = "Gravity",
    Desc = "Set workspace gravity through Infinite Yield.",
    Value = gravityValue,
    Type = "Input",
    Placeholder = tostring(workspace.Gravity),
    Callback = function(value)
        gravityValue = tostring(value or workspace.Gravity)
    end,
})
Movement:Button({
    Title = "Apply Gravity",
    Icon = "orbit",
    Callback = function()
        runCommand("gravity " .. gravityValue)
    end,
})

-- Quick visual controls -------------------------------------------------------
Visuals:Toggle({
    Title = "ESP",
    Desc = "Shows players and status information.",
    Icon = "scan-eye",
    Value = false,
    Callback = function(value)
        runCommand(value and "esp" or "noesp")
    end,
})

Visuals:Toggle({
    Title = "Chams",
    Desc = "Highlights players without ESP text.",
    Icon = "scan",
    Value = false,
    Callback = function(value)
        runCommand(value and "chams" or "nochams")
    end,
})

Visuals:Toggle({
    Title = "X-Ray",
    Desc = "Makes workspace parts transparent for your client.",
    Icon = "layers",
    Value = false,
    Callback = function(value)
        runCommand(value and "xray" or "unxray")
    end,
})

Visuals:Button({
    Title = "Fullbright",
    Desc = "Makes the map brighter on your client.",
    Icon = "sun",
    Callback = function()
        runCommand("fullbright")
    end,
})

Visuals:Button({
    Title = "No Fog",
    Desc = "Removes fog on your client.",
    Icon = "cloud-off",
    Callback = function()
        runCommand("nofog")
    end,
})

Visuals:Button({
    Title = "Day",
    Icon = "sun",
    Callback = function()
        runCommand("day")
    end,
})

Visuals:Button({
    Title = "Night",
    Icon = "moon",
    Callback = function()
        runCommand("night")
    end,
})

-- Camera ---------------------------------------------------------------------
Camera:Toggle({
    Title = "Freecam",
    Desc = "Infinite Yield free camera.",
    Icon = "video",
    Value = false,
    Callback = function(value)
        runCommand(value and "freecam" or "unfreecam")
    end,
})

local fovValue = "70"
Camera:Input({
    Title = "Field of View",
    Desc = "Set a camera FOV value.",
    Value = fovValue,
    Type = "Input",
    Placeholder = "70",
    Callback = function(value)
        fovValue = tostring(value or "70")
    end,
})
Camera:Button({
    Title = "Apply FOV",
    Icon = "focus",
    Callback = function()
        runCommand("fov " .. fovValue)
    end,
})

Camera:Button({
    Title = "First Person",
    Icon = "scan-face",
    Callback = function()
        runCommand("firstp")
    end,
})

Camera:Button({
    Title = "Third Person",
    Icon = "person-standing",
    Callback = function()
        runCommand("thirdp")
    end,
})

Camera:Button({
    Title = "Fix Camera",
    Icon = "refresh-cw",
    Callback = function()
        runCommand("fixcam")
    end,
})

-- Server / utility ------------------------------------------------------------
Server:Button({
    Title = "Anti AFK",
    Desc = "Prevents idle kicks using Infinite Yield's antiidle command.",
    Icon = "coffee",
    Callback = function()
        runCommand("antiidle")
    end,
})

Server:Button({
    Title = "Server Info",
    Icon = "info",
    Callback = function()
        runCommand("serverinfo")
    end,
})

Server:Button({
    Title = "Copy Job ID",
    Icon = "copy",
    Callback = function()
        runCommand("jobid")
    end,
})

Server:Button({
    Title = "Rejoin",
    Icon = "refresh-cw",
    Callback = function()
        runCommand("rejoin")
    end,
})

Server:Button({
    Title = "Server Hop",
    Icon = "shuffle",
    Callback = function()
        runCommand("serverhop")
    end,
})

-- Full command catalog --------------------------------------------------------
local bucketTabs = {
    AF = CommandsAF,
    GL = CommandsGL,
    MR = CommandsMR,
    SZ = CommandsSZ,
    MISC = CommandsMisc,
}

local function bucketFor(base)
    local first = tostring(base or ""):sub(1, 1):lower()
    if first >= "a" and first <= "f" then
        return bucketTabs.AF
    elseif first >= "g" and first <= "l" then
        return bucketTabs.GL
    elseif first >= "m" and first <= "r" then
        return bucketTabs.MR
    elseif first >= "s" and first <= "z" then
        return bucketTabs.SZ
    end
    return bucketTabs.MISC
end

local imported = 0

for _, entry in ipairs(commandMetadata) do
    if type(entry) == "table" then
        local syntax = trim(entry.NAME)
        if syntax ~= "" then
            local base = commandBase(syntax)
            local template = commandTemplate(syntax)
            local needsArgs = requiresArguments(syntax)
            local tab = bucketFor(base)

            if tab and base and template ~= "" then
                imported += 1
                tab:Button({
                    Title = syntax,
                    Desc = tostring(entry.DESC or "Infinite Yield command"),
                    Icon = needsArgs and "terminal" or "play",
                    Callback = function()
                        if needsArgs then
                            commandText = template
                            pcall(function()
                                runnerInput:Set(template)
                            end)
                            pcall(function()
                                Window:SelectTab(Home.Index)
                            end)
                            vantaNotify("Command ready", "Fill in the bracketed values, then press Run Command.", "terminal")
                        else
                            runCommand(template)
                        end
                    end,
                })
            end
        end
    end
end

-- F-to-fly shortcut. Ignore F while typing in any text box.
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or UserInputService:GetFocusedTextBox() then
        return
    end

    if input.KeyCode == Enum.KeyCode.F then
        setFly(not flyEnabled, true)
    end
end)

vantaNotify(
    "VantaUI + Infinite Yield",
    tostring(imported) .. " command entries imported. Press F to toggle Fly.",
    "sparkles"
)

return {
    VantaUI = VantaUI,
    Window = Window,
    RunCommand = runCommand,
    Commands = commandMetadata,
    InfiniteYieldVersion = ENV.currentVersion or currentVersion,
}
