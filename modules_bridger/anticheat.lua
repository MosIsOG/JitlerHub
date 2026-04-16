-- Jitler Hub - Adonis Anti-Cheat Bypass Module (Bridger)
-- Bypasses the Adonis "Anti" and "Anti-Cheat" modules by
-- neutralizing the Detected() reporting function.

if not shared then shared = {} end
local Hub = shared.JitlerHub
local Notify = Hub and Hub.Notify or function() end

local success = false

pcall(function()
    -- Require UNC functions
    if not filtergc or not hookfunction then
        Notify("Adonis bypass: missing filtergc or hookfunction", 3)
        return
    end

    -- Get the real environment's debug.info (not executor-overridden)
    local realDebugInfo
    if typeof(getrenv) == "function" then
        local renv = getrenv()
        realDebugInfo = renv and renv.debug and renv.debug.info
    end
    realDebugInfo = realDebugInfo or debug.info

    -- Find the Adonis Detected function via GC constants
    local detectedFunc = nil
    local results = filtergc("function", {
        Constants = { " - On Xbox", " - On mobile" },
        IgnoreExecutor = true,
    })

    if results and #results > 0 then
        detectedFunc = results[1]
    end

    if not detectedFunc then
        -- Adonis Anti module not present in this game
        return
    end

    -- Cache debug.info results for the Detected function before hooking
    -- debug.info(func, "slnfa") returns: source, line, name, nparams, isvararg
    local cachedSource, cachedLine, cachedName, cachedNParams, cachedIsVarArg =
        realDebugInfo(detectedFunc, "slnfa")

    -- Hook debug.info to return cached results when queried about the Detected function
    local originalDebugInfo = hookfunction(realDebugInfo, function(target, ...)
        if target == detectedFunc then
            return cachedSource, cachedLine, cachedName, cachedNParams, cachedIsVarArg
        end
        return originalDebugInfo(target, ...)
    end)

    -- Hook the Detected function itself - return true to prevent kick/crash
    -- Returning true is critical: "not Detected(...)" checks would catch false/nil
    hookfunction(detectedFunc, function()
        return true
    end)

    success = true
end)

if success then
    Notify("Adonis anti-cheat bypassed", 3)
end
