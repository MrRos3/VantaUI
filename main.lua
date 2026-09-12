--[[
    VantaUI
    Roblox UI library by MrRos3.

    Production wrapper with deterministic shutdown cleanup.
    Pressing the red X now performs two cleanup passes:
      1) auto-reset Vanta controls (toggles/sliders)
      2) run explicitly registered cleanup resources
]]

local CACHE_BUSTER = tostring(os.time()) .. "-" .. tostring(math.random(100000, 999999))
local STABLE_BASE_URL =
    "https://raw.githubusercontent.com/MrRos3/VantaUI/1b1821b3d6c8ee343195ce317ba27a97f54a36d3/main.lua?v="
    .. CACHE_BUSTER

local ok, source = pcall(function()
    return game:HttpGet(STABLE_BASE_URL)
end)
assert(ok and type(source) == "string" and #source > 0, "[VantaUI] Failed to download the stable production base")

local loader, loadError = loadstring(source)
assert(loader, "[VantaUI] Failed to compile the stable production base: " .. tostring(loadError))

local VantaUI = loader()
assert(type(VantaUI) == "table", "[VantaUI] Stable production base returned an invalid value")

VantaUI.Version = "0.3.6"
if type(VantaUI.GuiInfo) == "table" then
    VantaUI.GuiInfo.Version = VantaUI.Version
end

local function cloneValue(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}
    if seen[value] then
        return seen[value]
    end

    local copy = {}
    seen[value] = copy

    for key, item in pairs(value) do
        copy[cloneValue(key, seen)] = cloneValue(item, seen)
    end

    return copy
end

local function cleanupResource(resource, customCleanup)
    if customCleanup then
        customCleanup(resource)
        return
    end

    if type(resource) == "function" then
        resource()
        return
    end

    local kind = typeof(resource)
    if kind == "RBXScriptConnection" then
        if resource.Connected then
            resource:Disconnect()
        end
        return
    end

    if kind == "Instance" then
        resource:Destroy()
        return
    end

    if type(resource) == "table" then
        local methods = {
            "Cleanup",
            "Destroy",
            "Disconnect",
            "Stop",
            "Disable",
            "Cancel",
        }

        for _, methodName in ipairs(methods) do
            local method = resource[methodName]
            if type(method) == "function" then
                method(resource)
                return
            end
        end
    end
end

local BaseCreateWindow = VantaUI.CreateWindow

local FACTORY_METHODS = {
    "Toggle",
    "Slider",
    "Dropdown",
    "Colorpicker",
    "Keybind",
    "Input",
    "Button",
    "Paragraph",
    "ProgressBar",
    "Section",
    "Group",
    "HStack",
    "VStack",
    "Image",
    "Code",
    "Viewport",
    "Divider",
    "Space",
}

function VantaUI:CreateWindow(config)
    config = config or {}

    local window = BaseCreateWindow(self, config)
    local BaseDestroy = window.Destroy
    local BaseTab = window.Tab

    local cleanupStack = {}
    local cleanupRan = false
    local autoResetRan = false
    local destroying = false

    local elementBaselines = setmetatable({}, { __mode = "k" })
    local elementOrder = {}
    local wrappedContainers = setmetatable({}, { __mode = "k" })

    local function captureElement(element)
        if type(element) ~= "table" or elementBaselines[element] then
            return element
        end

        local baseline = {
            Type = element.__type,
            HasValue = false,
            Value = nil,
        }

        if element.__type == "Slider" and type(element.Value) == "table" then
            baseline.HasValue = element.Value.Default ~= nil
            baseline.Value = cloneValue(element.Value.Default)
        elseif element.Value ~= nil then
            baseline.HasValue = true
            baseline.Value = cloneValue(element.Value)
        end

        elementBaselines[element] = baseline
        table.insert(elementOrder, element)

        return element
    end

    local wrapContainer
    wrapContainer = function(container)
        if type(container) ~= "table" or wrappedContainers[container] then
            return container
        end

        wrappedContainers[container] = true

        for _, factoryName in ipairs(FACTORY_METHODS) do
            local baseFactory = container[factoryName]
            if type(baseFactory) == "function" then
                container[factoryName] = function(selfContainer, elementConfig)
                    local element = baseFactory(selfContainer, elementConfig)
                    captureElement(element)
                    wrapContainer(element)
                    return element
                end
            end
        end

        return container
    end

    if type(BaseTab) == "function" then
        function window:Tab(tabConfig)
            local tab = BaseTab(self, tabConfig)
            return wrapContainer(tab)
        end
    end

    -- Register anything a feature needs to undo when the window is destroyed.
    -- Supported automatically:
    --   * function
    --   * RBXScriptConnection
    --   * Instance
    --   * table exposing Cleanup/Destroy/Disconnect/Stop/Disable/Cancel
    function window:RegisterCleanup(resource, customCleanup)
        if resource == nil or cleanupRan then
            return resource
        end

        table.insert(cleanupStack, {
            Resource = resource,
            Cleanup = customCleanup,
        })

        return resource
    end

    window.AddCleanup = window.RegisterCleanup
    window.RegisterReset = window.RegisterCleanup
    window.TrackFeature = window.RegisterCleanup

    function window:TrackConnection(connection)
        return self:RegisterCleanup(connection)
    end

    function window:TrackInstance(instance)
        return self:RegisterCleanup(instance)
    end

    function window:TrackProperty(instance, propertyName)
        if instance == nil or type(propertyName) ~= "string" then
            return nil
        end

        local success, originalValue = pcall(function()
            return instance[propertyName]
        end)
        if not success then
            return nil
        end

        self:RegisterCleanup(function()
            pcall(function()
                instance[propertyName] = originalValue
            end)
        end)

        return originalValue
    end

    function window:TrackProperties(instance, propertyNames)
        local originals = {}
        if type(propertyNames) ~= "table" then
            return originals
        end

        for _, propertyName in ipairs(propertyNames) do
            originals[propertyName] = self:TrackProperty(instance, propertyName)
        end

        return originals
    end

    function window:TrackState(getter, setter)
        if type(getter) ~= "function" or type(setter) ~= "function" then
            return nil
        end

        local success, originalValue = pcall(getter)
        if not success then
            return nil
        end

        self:RegisterCleanup(function()
            setter(originalValue)
        end)

        return originalValue
    end

    -- Best-effort automatic feature reset for ordinary Vanta scripts.
    -- Toggles are always forced OFF and their callbacks are executed
    -- synchronously. Sliders are restored to the value they had when created.
    function window:ResetFeatures()
        if autoResetRan then
            return
        end
        autoResetRan = true

        if config.AutoCleanupFeatures == false then
            return
        end

        for index = #elementOrder, 1, -1 do
            local element = elementOrder[index]
            local baseline = elementBaselines[element]

            if type(element) == "table" and baseline then
                if baseline.Type == "Toggle" then
                    if type(element.Set) == "function" then
                        pcall(element.Set, element, false, false, true)
                    end

                    if type(element.Callback) == "function" then
                        local success, err = pcall(element.Callback, false)
                        if not success then
                            warn("[VantaUI AutoReset] Toggle cleanup failed: " .. tostring(err))
                        end
                    end
                elseif baseline.Type == "Slider" and baseline.HasValue then
                    if type(element.Set) == "function" then
                        local success, err = pcall(element.Set, element, cloneValue(baseline.Value))
                        if not success then
                            warn("[VantaUI AutoReset] Slider cleanup failed: " .. tostring(err))
                        end
                    elseif type(element.Callback) == "function" then
                        local success, err = pcall(element.Callback, cloneValue(baseline.Value))
                        if not success then
                            warn("[VantaUI AutoReset] Slider callback cleanup failed: " .. tostring(err))
                        end
                    end
                end
            end
        end
    end

    function window:Cleanup()
        if cleanupRan then
            return
        end
        cleanupRan = true

        for index = #cleanupStack, 1, -1 do
            local entry = cleanupStack[index]
            cleanupStack[index] = nil

            local success, err = pcall(cleanupResource, entry.Resource, entry.Cleanup)
            if not success then
                warn("[VantaUI Cleanup] " .. tostring(err))
            end
        end
    end

    function window:IsCleanupComplete()
        return cleanupRan and autoResetRan
    end

    -- The red X uses Window:Destroy(). Minimize still uses Window:Close().
    function window:Destroy(...)
        if destroying then
            return
        end
        destroying = true

        self:ResetFeatures()
        self:Cleanup()

        if BaseDestroy then
            return BaseDestroy(self, ...)
        end
    end

    if type(config.Cleanup) == "function" then
        window:RegisterCleanup(config.Cleanup)
    elseif type(config.Cleanup) == "table" then
        for _, cleanup in ipairs(config.Cleanup) do
            window:RegisterCleanup(cleanup)
        end
    end

    return window
end

return VantaUI
