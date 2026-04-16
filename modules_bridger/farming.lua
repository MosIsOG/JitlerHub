-- Jitler Hub - Farming Module (Bridger)
-- Auto-Fish system using Bait + FishingRod remotes

if not shared then shared = {} end
local Hub = shared.JitlerHub
local Players = Hub.Players
local LocalPlayer = Hub.LocalPlayer
local Notify = Hub.Notify
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
local UseTool = Remotes and Remotes:FindFirstChild("UseTool")
local UpdateSlotData = Remotes and Remotes:FindFirstChild("UpdateSlotData")

-- ================================================================
-- AUTO FISH
-- ================================================================
Hub.AutoFish = {
    Enabled = false,
    Thread = nil,
    BiteDelay = 0.3,
    CastDelay = 1.5,
    UseBait = true,
}

local function waitForFishBite(timeout)
    local char = LocalPlayer.Character
    if not char then return false end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    local elapsed = 0
    local step = 0.1
    while elapsed < timeout do
        if not Hub.AutoFish.Enabled then return false end
        local bite = root:FindFirstChild("FishBite")
        if bite and bite:IsA("Sound") then
            return true
        end
        task.wait(step)
        elapsed = elapsed + step
    end
    return false
end

local function autoFishLoop()
    Notify("Auto Fish started", 2)

    while Hub.AutoFish.Enabled do
        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            task.wait(1)
            continue
        end

        -- Use bait first if enabled
        if Hub.AutoFish.UseBait and UseTool then
            pcall(function()
                UseTool:FireServer("Bait", "Primary")
            end)
            task.wait(0.5)
        end

        -- Cast fishing rod
        if UseTool then
            pcall(function()
                UseTool:FireServer("FishingRod", "Primary")
            end)
        end

        -- Wait for fish bite (max 30 seconds)
        local gotBite = waitForFishBite(30)

        if gotBite and Hub.AutoFish.Enabled then
            task.wait(Hub.AutoFish.BiteDelay)
            -- Reel in
            if UseTool then
                pcall(function()
                    UseTool:FireServer("FishingRod", "Primary")
                end)
            end
        end

        task.wait(Hub.AutoFish.CastDelay)
    end

    Notify("Auto Fish stopped", 2)
end

function Hub.StartAutoFish()
    if Hub.AutoFish.Thread then pcall(task.cancel, Hub.AutoFish.Thread) end
    Hub.AutoFish.Enabled = true
    Hub.AutoFish.Thread = task.spawn(autoFishLoop)
end

function Hub.StopAutoFish()
    Hub.AutoFish.Enabled = false
    if Hub.AutoFish.Thread then pcall(task.cancel, Hub.AutoFish.Thread); Hub.AutoFish.Thread = nil end
end
