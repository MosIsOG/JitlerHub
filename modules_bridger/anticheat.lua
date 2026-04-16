-- Adonis Anti-Cheat Bypass (Bridger)

if not shared then shared = {} end
local Hub = shared.JitlerHub
local Notify = Hub and Hub.Notify or function() end

local function infiniteYield()
    return game.Workspace:WaitForChild("")
end

local bypassed = false

pcall(function()
    if typeof(getgc) ~= "function" or typeof(setreadonly) ~= "function" then return end

    for _, v in pairs(getgc(true)) do
        local ok, idx = pcall(function() return rawget(v, "indexInstance") end)
        if ok and type(idx) == "table" and idx[1] == "kick" then
            setreadonly(v, false)

            if type(rawget(v, "indexInstance")) == "table" then
                v.indexInstance = { "kick", infiniteYield }
            end
            if type(rawget(v, "newindexInstance")) == "table" then
                v.newindexInstance = { "kick", infiniteYield }
            end
            if type(rawget(v, "namecallInstance")) == "table" then
                v.namecallInstance = { "kick", infiniteYield }
            end

            setreadonly(v, true)
            bypassed = true
            break
        end
    end
end)

if bypassed then
    Notify("Adonis bypassed", 2)
end
