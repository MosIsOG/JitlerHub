-- Adonis Anti-Cheat Bypass (Bridger)
-- Layer 1: hookfunction on Player.Kick (catches direct function calls)
-- Layer 2: __namecall hook (catches :Kick() method syntax)

if not shared then shared = {} end
local Hub = shared.JitlerHub
local Notify = Hub and Hub.Notify or function() end

local player = game:GetService("Players").LocalPlayer
local layers = 0

-- Layer 1: Hook the actual Kick function so even direct calls are blocked
pcall(function()
    if typeof(hookfunction) ~= "function" or typeof(newcclosure) ~= "function" then return end
    local oldKick
    oldKick = hookfunction(player.Kick, newcclosure(function(self, ...)
        if typeof(self) == "Instance" and self:IsA("Player") and self == player then
            return
        end
        return oldKick(self, ...)
    end))
    layers = layers + 1
end)

-- Layer 2: Hook __namecall to block :Kick() method-call syntax
pcall(function()
    if typeof(getrawmetatable) ~= "function" or typeof(setreadonly) ~= "function" then return end
    local mt = getrawmetatable(game)
    if not mt then return end

    local oldNamecall = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if (method == "Kick" or method == "kick") and typeof(self) == "Instance" and self:IsA("Player") and self == player then
            return
        end
        return oldNamecall(self, ...)
    end)
    setreadonly(mt, true)
    layers = layers + 1
end)

if layers > 0 then
    Notify("Adonis bypassed (" .. layers .. " layers)", 2)
else
    Notify("Adonis bypass FAILED - no hooks applied", 5)
end
