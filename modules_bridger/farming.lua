-- Jitler Hub - Farming Module (Bridger)
-- Auto-Fish system using Bait + FishingRod remotes
-- Debug mode: notifications at each step so we can see what's happening

if not shared then shared = {} end
local Hub = shared.JitlerHub
local LocalPlayer = Hub.LocalPlayer
local Notify = Hub.Notify
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Resolve remotes with retry
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
if not Remotes then
    Notify("[Fish] ERROR: 'Remotes' folder not found in ReplicatedStorage!", 5)
    return
end

-- List all children of Remotes for debugging
local remoteNames = {}
for _, child in ipairs(Remotes:GetChildren()) do
    table.insert(remoteNames, child.Name .. " (" .. child.ClassName .. ")")
end
Notify("[Fish] Found remotes: " .. table.concat(remoteNames, ", "), 5)

local UseTool = Remotes:FindFirstChild("UseTool")
local UpdateSlotData = Remotes:FindFirstChild("UpdateSlotData")

if not UseTool then
    Notify("[Fish] ERROR: 'UseTool' remote not found!", 5)
    return
end
Notify("[Fish] UseTool: " .. UseTool.ClassName .. " | UpdateSlotData: " .. tostring(UpdateSlotData and UpdateSlotData.ClassName or "NOT FOUND"), 4)

-- ================================================================
-- AUTO FISH
-- ================================================================
Hub.AutoFish = {
    Enabled = false,
    Thread = nil,
    BiteDelay = 0.3,
    CastDelay = 1.5,
    UseBait = true,
    Debug = true,
}

local function dbg(msg)
    if Hub.AutoFish.Debug then
        Notify("[Fish] " .. msg, 2)
    end
end

local function waitForFishBite(timeout)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then
        dbg("No HumanoidRootPart!")
        return false
    end

    local gotBite = false
    local conns = {}

    -- Listen for ANY new child on root (log it for debug)
    table.insert(conns, root.ChildAdded:Connect(function(child)
        dbg("Root child added: " .. child.Name .. " (" .. child.ClassName .. ")")
        if child.Name == "FishBite" or (child:IsA("Sound") and child.Name:lower():find("bite")) then
            gotBite = true
        end
    end))

    -- Also listen on the character itself in case the sound is elsewhere
    table.insert(conns, char.DescendantAdded:Connect(function(desc)
        if desc:IsA("Sound") and (desc.Name == "FishBite" or desc.Name:lower():find("bite")) then
            dbg("Bite sound found on: " .. desc:GetFullName())
            gotBite = true
        end
    end))

    -- Check for existing FishBite sound
    local existing = root:FindFirstChild("FishBite")
    if not existing then
        -- Search wider - maybe it's on the character, not root
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("Sound") and (d.Name == "FishBite" or d.Name:lower():find("bite")) then
                existing = d
                dbg("Found existing bite sound at: " .. d:GetFullName())
                break
            end
        end
    end

    if existing and existing:IsA("Sound") then
        table.insert(conns, existing:GetPropertyChangedSignal("Playing"):Connect(function()
            if existing.Playing then
                dbg("Bite sound playing!")
                gotBite = true
            end
        end))
        if existing.Playing then gotBite = true end
    end

    local elapsed = 0
    while elapsed < timeout and not gotBite and Hub.AutoFish.Enabled do
        task.wait(0.15)
        elapsed = elapsed + 0.15
    end

    for _, c in ipairs(conns) do
        pcall(function() c:Disconnect() end)
    end

    if not gotBite then
        dbg("No bite after " .. math.floor(elapsed) .. "s")
    end
    return gotBite
end

local function autoFishLoop()
    Notify("[Fish] Auto Fish STARTED", 2)

    while Hub.AutoFish.Enabled do
        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            dbg("Waiting for character...")
            task.wait(1)
            continue
        end

        -- Step 1: Equip rod via UpdateSlotData if available
        if UpdateSlotData then
            pcall(function()
                UpdateSlotData:FireServer("FishingRod")
            end)
            task.wait(0.3)
        end

        -- Step 2: Use bait
        if Hub.AutoFish.UseBait then
            dbg("Using bait...")
            local ok, err = pcall(function()
                UseTool:FireServer("Bait", "Primary")
            end)
            if not ok then dbg("Bait ERROR: " .. tostring(err)) end
            task.wait(0.5)
        end

        -- Step 3: Cast rod
        dbg("Casting rod...")
        local ok, err = pcall(function()
            UseTool:FireServer("FishingRod", "Primary")
        end)
        if not ok then
            dbg("Cast ERROR: " .. tostring(err))
            task.wait(2)
            continue
        end

        -- Step 4: Wait for bite
        dbg("Waiting for bite...")
        local gotBite = waitForFishBite(30)

        if not Hub.AutoFish.Enabled then break end

        if gotBite then
            dbg("GOT BITE! Reeling in...")
            task.wait(Hub.AutoFish.BiteDelay)
            pcall(function()
                UseTool:FireServer("FishingRod", "Primary")
            end)
            dbg("Reeled in!")
        else
            dbg("No bite, recasting...")
        end

        task.wait(Hub.AutoFish.CastDelay)
    end

    Notify("[Fish] Auto Fish STOPPED", 2)
end

function Hub.StartAutoFish()
    if Hub.AutoFish.Thread then
        Hub.AutoFish.Enabled = false
        task.wait(0.3)
    end
    Hub.AutoFish.Enabled = true
    Hub.AutoFish.Thread = task.spawn(autoFishLoop)
end

function Hub.StopAutoFish()
    Hub.AutoFish.Enabled = false
    Hub.AutoFish.Thread = nil
end

function Hub.StopAutoFish()
    Hub.AutoFish.Enabled = false
    Hub.AutoFish.Thread = nil
end
