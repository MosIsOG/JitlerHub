-- Adonis Anti-Cheat Bypass (Bridger)
-- Hooks Player:Kick() via __namecall so Adonis stays alive but can't kick.

if not shared then shared = {} end
local Hub = shared.JitlerHub
local Notify = Hub and Hub.Notify or function() end

local bypassed = false

pcall(function()
    local player = game:GetService("Players").LocalPlayer
    local mt = getrawmetatable(game)
    if not mt or typeof(setreadonly) ~= "function" then return end

    local oldNamecall = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if method == "Kick" and self == player then
            return
        end
        return oldNamecall(self, ...)
    end)
    setreadonly(mt, true)
    bypassed = true
end)

if bypassed then
    Notify("Adonis bypassed", 2)
end
