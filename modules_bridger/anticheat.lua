-- Jitler Hub - Adonis Anti-Cheat Bypass Module (Bridger)
-- Two-layer bypass:
--   1) Hook the Detected() reporting function (filtergc + debug.info spoof)
--   2) Hook Adonis metamethod handlers found via getgc (kick/crash prevention)

if not shared then shared = {} end
local Hub = shared.JitlerHub
local Notify = Hub and Hub.Notify or function() end

local bypassCount = 0

-- ================================================================
-- LAYER 1: Detected() function bypass via filtergc
-- ================================================================
pcall(function()
    if typeof(filtergc) ~= "function" or typeof(hookfunction) ~= "function" then return end

    -- Get the real environment's debug.info (not executor-overridden)
    local realDebugInfo
    if typeof(getrenv) == "function" then
        local renv = getrenv()
        realDebugInfo = renv and renv.debug and renv.debug.info
    end
    realDebugInfo = realDebugInfo or debug.info

    -- Find the Adonis Detected function via GC constants
    local results = filtergc("function", {
        Constants = { " - On Xbox", " - On mobile" },
        IgnoreExecutor = true,
    })

    local detectedFunc = results and results[1]
    if not detectedFunc then return end

    -- Cache debug.info results before hooking to defeat Adonis's hook-detection
    local cachedSource, cachedLine, cachedName, cachedNParams, cachedIsVarArg =
        realDebugInfo(detectedFunc, "slnfa")

    -- Spoof debug.info for the Detected function
    local originalDebugInfo = hookfunction(realDebugInfo, function(target, ...)
        if target == detectedFunc then
            return cachedSource, cachedLine, cachedName, cachedNParams, cachedIsVarArg
        end
        return originalDebugInfo(target, ...)
    end)

    -- Neutralize Detected — must return true to avoid "not Detected(...)" checks
    hookfunction(detectedFunc, function()
        return true
    end)

    bypassCount = bypassCount + 1
end)

-- ================================================================
-- LAYER 2: Adonis metamethod handler hooks via getgc
-- ================================================================
pcall(function()
    if typeof(getgc) ~= "function" or typeof(hookfunction) ~= "function" then return end
    local islclosure = islclosure or function(f) return type(f) == "function" and debug.info(f, "s") ~= "[C]" end

    local function hookAdonisHandlers(metaTbl)
        for _, handlerTable in pairs(metaTbl) do
            if type(handlerTable) == "table" then
                for _, func in pairs(handlerTable) do
                    if type(func) == "function" and islclosure(func) then
                        hookfunction(func, function()
                            return true
                        end)
                    end
                end
            end
        end
    end

    for _, v in pairs(getgc(true)) do
        if
            typeof(v) == "table"
            and rawget(v, "indexInstance")
            and rawget(v, "newindexInstance")
            and rawget(v, "namecallInstance")
            and type(rawget(v, "newindexInstance")) == "table"
        then
            if v["newindexInstance"][1] == "kick" then
                hookAdonisHandlers(v)
                bypassCount = bypassCount + 1
                break
            end
        end
    end
end)

-- ================================================================
if bypassCount > 0 then
    Notify("Adonis anti-cheat bypassed (" .. bypassCount .. " layers)", 3)
end
