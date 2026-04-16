-- Jitler Hub - Farming Module (Bridger)
-- Auto-Fish system using Bait + FishingRod remotes

if not shared then shared = {} end
local Hub = shared.JitlerHub
local LocalPlayer = Hub.LocalPlayer
local Notify = Hub.Notify
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Resolve remotes with retry
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
if not Remotes then
    Notify("Auto Fish: 'Remotes' folder not found!", 5)
    return
end

local UseTool = Remotes:WaitForChild("UseTool", 10)
local UpdateSlotData = Remotes:FindFirstChild("UpdateSlotData")

if not UseTool then
    Notify("Auto Fish: 'UseTool' remote not found!", 5)
    return
end

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
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    local gotBite = false
    local conns = {}

    -- Event: new sound child added to root
    table.insert(conns, root.ChildAdded:Connect(function(child)
        if child.Name == "FishBite" then
            gotBite = true
        end
    end))

    -- Event: existing FishBite sound starts playing
    local existing = root:FindFirstChild("FishBite")
    if existing and existing:IsA("Sound") then
        table.insert(conns, existing:GetPropertyChangedSignal("Playing"):Connect(function()
            if existing.Playing then gotBite = true end
        end))
        -- If it's already playing right now, count it
        if existing.Playing then gotBite = true end
    end

    -- Wait loop with early exit
    local elapsed = 0
    while elapsed < timeout and not gotBite and Hub.AutoFish.Enabled do
        task.wait(0.1)
        elapsed = elapsed + 0.1
        -- Fallback poll in case events didn't fire
        if not existing then
            existing = root:FindFirstChild("FishBite")
            if existing and existing:IsA("Sound") and existing.Playing then
                gotBite = true
            end
        end
    end

    for _, c in ipairs(conns) do
        pcall(function() c:Disconnect() end)
    end
    return gotBite
end

local function autoFishLoop()
    Notify("Auto Fish started", 2)

    while Hub.AutoFish.Enabled do
        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            task.wait(1)
            continue
        end

        -- Step 1: Use bait
        if Hub.AutoFish.UseBait then
            local ok, err = pcall(function()
                UseTool:FireServer("Bait", "Primary")
            end)
            if not ok then Notify("Fish: Bait error - " .. tostring(err), 3) end
            task.wait(0.5)
        end

        -- Step 2: Cast rod
        local ok, err = pcall(function()
            UseTool:FireServer("FishingRod", "Primary")
        end)
        if not ok then
            Notify("Fish: Cast error - " .. tostring(err), 3)
            task.wait(2)
            continue
        end

        -- Step 3: Wait for bite (max 30s)
        local gotBite = waitForFishBite(30)

        if not Hub.AutoFish.Enabled then break end

        if gotBite then
            task.wait(Hub.AutoFish.BiteDelay)
            -- Step 4: Reel in
            pcall(function()
                UseTool:FireServer("FishingRod", "Primary")
            end)
        end

        task.wait(Hub.AutoFish.CastDelay)
    end

    Notify("Auto Fish stopped", 2)
end

function Hub.StartAutoFish()
    if Hub.AutoFish.Thread then
        Hub.AutoFish.Enabled = false
        task.wait(0.2)
    end
    Hub.AutoFish.Enabled = true
    Hub.AutoFish.Thread = task.spawn(autoFishLoop)
end

function Hub.StopAutoFish()
    Hub.AutoFish.Enabled = false
    Hub.AutoFish.Thread = nil
end
