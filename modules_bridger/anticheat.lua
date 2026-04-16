-- Adonis Anti-Cheat Bypass (Bridger)
-- DO NOT use hookfunction on Kick → Adonis detects it as "Method 0x3"
-- Strategy:
--   1. __namecall hook to block :Kick() on LocalPlayer
--   2. __namecall hook to intercept FireServer/InvokeServer on Adonis remotes
--      and silently drop anti-cheat detection reports so the server never kicks
-- Note: External tools (remote spy, dex, etc.) may trigger SEPARATE Adonis
--       detections — disable them when testing.

if not shared then shared = {} end
local Hub = shared.JitlerHub
local Notify = Hub and Hub.Notify or function() end

local player = game:GetService("Players").LocalPlayer
local bypassed = false

-- Collect Adonis remote instances for targeted filtering
local adonisRemotes = {}
pcall(function()
    for _, svc in ipairs({
        game:GetService("ReplicatedStorage"),
        player:WaitForChild("PlayerGui", 5),
        game:GetService("StarterGui"),
    }) do
        if svc then
            for _, d in ipairs(svc:GetDescendants()) do
                if (d:IsA("RemoteEvent") or d:IsA("RemoteFunction")) then
                    if d:GetFullName():lower():find("adonis") then
                        adonisRemotes[d] = true
                    end
                end
            end
        end
    end
end)

pcall(function()
    local mt = getrawmetatable(game)
    if not mt then return end

    local oldNamecall = mt.__namecall
    setreadonly(mt, false)

    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()

        -- Block :Kick() on local player (catches any client-side kicks)
        if (method == "Kick" or method == "kick") and typeof(self) == "Instance" and self == player then
            return
        end

        -- Block anti-cheat reports on Adonis remotes
        if adonisRemotes[self] and (method == "FireServer" or method == "InvokeServer") then
            local args = {...}
            for _, a in ipairs(args) do
                if type(a) == "string" then
                    local l = a:lower()
                    if l:find("kick") or l:find("detect") or l:find("cheat") or l:find("ban") or l:find("exploit") or l:find("violation") then
                        return
                    end
                end
                if type(a) == "table" then
                    for _, v in pairs(a) do
                        if type(v) == "string" then
                            local l = v:lower()
                            if l:find("kick") or l:find("detect") or l:find("cheat") then
                                return
                            end
                        end
                    end
                end
            end
        end

        return oldNamecall(self, ...)
    end)

    setreadonly(mt, true)
    bypassed = true
end)

local rc = 0
for _ in pairs(adonisRemotes) do rc = rc + 1 end

if bypassed then
    Notify("Adonis bypassed (" .. rc .. " remotes tracked)", 3)
else
    Notify("Adonis bypass FAILED", 5)
end
