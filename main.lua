--[[
    VantaUI
    Roblox UI library by MrRos3.

    This entry point preserves the stable production VantaUI wrapper and adds
    deterministic feature cleanup to every window. Pressing the red X runs all
    registered cleanup work before the normal VantaUI destroy path finishes.
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

function VantaUI:CreateWindow(config)
    config = config or {}

    local window = BaseCreateWindow(self, config)
    local BaseDestroy = window.Destroy
    local cleanupStack = {}
    local cleanupRan = false

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

    -- Friendly aliases for scripts that prefer different wording.
    window.AddCleanup = window.RegisterCleanup
    window.RegisterReset = window.RegisterCleanup
    window.TrackFeature = window.RegisterCleanup

    function window:TrackConnection(connection)
        return self:RegisterCleanup(connection)
    end

    function window:TrackInstance(instance)
        return self:RegisterCleanup(instance)
    end

    -- Snapshot one property before a feature changes it. Destroy restores the
    -- exact value that existed before the feature touched it.
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

    -- Snapshot arbitrary script state with a getter and restore it with a setter.
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

    function window:Cleanup()
        if cleanupRan then
            return
        end
        cleanupRan = true

        -- Last-created resources are removed first so dependencies unwind safely.
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
        return cleanupRan
    end

    -- The red X uses Window:Destroy(). Minimize still uses Window:Close(), so
    -- minimizing does not disable active features. A real destroy does.
    function window:Destroy(...)
        self:Cleanup()

        if BaseDestroy then
            return BaseDestroy(self, ...)
        end
    end

    -- Optional cleanup can also be supplied directly in CreateWindow config.
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
