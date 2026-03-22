-- Jitler Hub - Combat Module (NoFall, M1 Spam, Remote Attack, BackAttach, AutoBlock, NoStun)
local Hub = shared.JitlerHub
local Players = Hub.Players
local RunService = Hub.RunService
local UserInputService = Hub.UserInputService
local ReplicatedStorage = Hub.ReplicatedStorage
local LocalPlayer = Hub.LocalPlayer
local VirtualInput = Hub.VirtualInput
local Notify = Hub.Notify

-- ================================================================
-- NO FALL DAMAGE (blocks TakeDamage via namecall)
-- ================================================================
local NoFall = { Enabled = false }
local OldNamecall
OldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local args = { ... }
    if method == "FireServer" and NoFall.Enabled and args[1] == "TakeDamage" then
        return
    end
    return OldNamecall(self, ...)
end)

Hub.NoFall = NoFall

-- ================================================================
-- M1 SPAM
-- ================================================================
local M1Spam = { Enabled = false, Holding = false, Delay = 0.1, Thread = nil }
UserInputService.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then M1Spam.Holding = true end end)
UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then M1Spam.Holding = false end end)

local function StartSpam()
    if M1Spam.Thread then pcall(task.cancel, M1Spam.Thread) end
    M1Spam.Thread = task.spawn(function()
        while M1Spam.Enabled do
            if M1Spam.Holding then pcall(function() local pos = UserInputService:GetMouseLocation(); VirtualInput:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 0) end) end
            task.wait(M1Spam.Delay)
        end
    end)
end

local function StopSpam()
    M1Spam.Holding = false
    if M1Spam.Thread then pcall(task.cancel, M1Spam.Thread); M1Spam.Thread = nil end
end

Hub.M1Spam = M1Spam
Hub.StartSpam = StartSpam
Hub.StopSpam = StopSpam

-- ================================================================
-- REMOTE ATTACK SPAM
-- ================================================================
local RemoteAttackSpam = { Enabled = false, Delay = 0.12, Thread = nil }

local function StartRemoteAttack()
    if RemoteAttackSpam.Thread then pcall(task.cancel, RemoteAttackSpam.Thread) end
    RemoteAttackSpam.Thread = task.spawn(function()
        while RemoteAttackSpam.Enabled do
            if Hub.DataEvent then pcall(function() Hub.DataEvent:FireServer("CheckMeleeHit", nil, "NormalAttack", false) end) end
            task.wait(RemoteAttackSpam.Delay)
        end
    end)
end

local function StopRemoteAttack()
    RemoteAttackSpam.Enabled = false
    if RemoteAttackSpam.Thread then pcall(task.cancel, RemoteAttackSpam.Thread); RemoteAttackSpam.Thread = nil end
end

Hub.RemoteAttackSpam = RemoteAttackSpam
Hub.StartRemoteAttack = StartRemoteAttack
Hub.StopRemoteAttack = StopRemoteAttack

-- ================================================================
-- BACK ATTACH
-- ================================================================
local BackAttach = {
    Enabled = false,
    Target = nil,
    HeartbeatConn = nil,
    MaxDistance = 200,
    Offset = 3,
    LastNoTargetNotify = 0,
}

local function IsValidBackAttachTarget(player)
    if player == LocalPlayer then return false end
    local tc = player and player.Character
    if not tc then return false end
    local tr = tc:FindFirstChild("HumanoidRootPart")
    local hum = tc:FindFirstChildOfClass("Humanoid")
    if not tr or not hum or hum.Health <= 0 then return false end
    return true, tc, tr, hum
end

local function GetNearestPlayerInRange(maxDistance)
    local char = LocalPlayer.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end

    local nearest, nearestRoot, nearestDist = nil, nil, maxDistance or BackAttach.MaxDistance
    for _, player in ipairs(Players:GetPlayers()) do
        local ok, _, tr = IsValidBackAttachTarget(player)
        if ok and tr then
            local dist = (root.Position - tr.Position).Magnitude
            if dist <= (maxDistance or BackAttach.MaxDistance) and dist < nearestDist then
                nearest = player
                nearestRoot = tr
                nearestDist = dist
            end
        end
    end

    return nearest, nearestRoot, nearestDist
end

local function StopBackAttach()
    BackAttach.Enabled = false
    if BackAttach.HeartbeatConn then BackAttach.HeartbeatConn:Disconnect(); BackAttach.HeartbeatConn = nil end
    BackAttach.Target = nil
end

local function StartBackAttach()
    BackAttach.Enabled = true
    if BackAttach.HeartbeatConn then BackAttach.HeartbeatConn:Disconnect(); BackAttach.HeartbeatConn = nil end

    BackAttach.HeartbeatConn = RunService.Heartbeat:Connect(function()
        if not BackAttach.Enabled then return end

        local char = LocalPlayer.Character
        if not char then StopBackAttach(); return end

        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not root or not hum or hum.Health <= 0 then StopBackAttach(); return end

        local target = BackAttach.Target
        local targetRoot = nil

        if target then
            local valid, _, tr = IsValidBackAttachTarget(target)
            if valid and tr and (root.Position - tr.Position).Magnitude <= BackAttach.MaxDistance then
                targetRoot = tr
            else
                BackAttach.Target = nil
            end
        end

        if not targetRoot then
            local nearest, nearestRoot = GetNearestPlayerInRange(BackAttach.MaxDistance)
            if nearest and nearestRoot then
                BackAttach.Target = nearest
                targetRoot = nearestRoot
            end
        end

        if not targetRoot then
            if tick() - BackAttach.LastNoTargetNotify > 2 then
                BackAttach.LastNoTargetNotify = tick()
                Notify("No valid player within 200 studs.", 2)
            end
            return
        end

        local desired = targetRoot.CFrame * CFrame.new(0, 0, -BackAttach.Offset)
        root.CFrame = CFrame.lookAt(desired.Position, targetRoot.Position)
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end)
end

LocalPlayer.CharacterAdded:Connect(function()
    if BackAttach.Enabled then
        task.wait(1)
        StartBackAttach()
    end
end)

Hub.BackAttach = BackAttach
Hub.StartBackAttach = StartBackAttach
Hub.StopBackAttach = StopBackAttach

-- ================================================================
-- AUTO PERFECT BLOCK
-- ================================================================
local BlockRules = {
    { animID = "6360969229", delay = 0.18, distance = 15 }, { animID = "11330795390", delay = 0.115, distance = 6 },
    { animID = "7275651023", delay = 0.2, distance = 19 }, { animID = "86213040968703", delay = 0.0, distance = 25, continuous = true },
    { animID = "116907126244057", delay = 1.1, continuous = true }, { animID = "120758909308511", delay = 1.0, distance = 101, continuous = true },
}
local AutoBlock = { Enabled = false, MonitoredEntities = {}, Triggered = {}, ContinuousMonitors = {}, ScanThread = nil, CurrentlyBlocking = false }

local function GetDistToEntity(model)
    local lc = LocalPlayer.Character; if not lc or not model then return nil end
    local lr = lc:FindFirstChild("HumanoidRootPart") or lc:FindFirstChild("Head")
    local tr = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head")
    if not lr or not tr then return nil end; return (lr.Position - tr.Position).Magnitude
end

local function Block() AutoBlock.CurrentlyBlocking = true; if Hub.DataFunction then pcall(function() Hub.DataFunction:InvokeServer("Block") end) end end
local function Unblock() if Hub.DataFunction then pcall(function() Hub.DataFunction:InvokeServer("EndBlock") end) end; AutoBlock.CurrentlyBlocking = false end

local function ScheduleBlock(name, delay)
    if AutoBlock.Triggered[name] then return end; AutoBlock.Triggered[name] = true
    local function doBlock() if not AutoBlock.Enabled then AutoBlock.Triggered[name] = nil; return end; Block(); task.delay(0.5, function() Unblock(); AutoBlock.Triggered[name] = nil end) end
    if delay <= 0.01 then task.spawn(doBlock) else task.delay(delay, doBlock) end
end

local function StartContinuousBlock(model, track, rule)
    local key = tostring(model) .. "_" .. rule.animID; if AutoBlock.ContinuousMonitors[key] then return end
    local isBlocking, delayApplied = false, false
    AutoBlock.ContinuousMonitors[key] = task.spawn(function()
        while AutoBlock.Enabled and track and track.IsPlaying and model.Parent do
            local dist = GetDistToEntity(model)
            if dist and dist <= (rule.distance or 999) then
                if not isBlocking and not delayApplied then delayApplied = true; task.wait(rule.delay or 0.1)
                    if AutoBlock.Enabled and track and track.IsPlaying then local d2 = GetDistToEntity(model); if d2 and d2 <= (rule.distance or 999) then Block(); isBlocking = true end end end
            else if isBlocking then Unblock(); isBlocking = false; delayApplied = false end end
            task.wait(0.01)
        end; if isBlocking then Unblock() end; AutoBlock.ContinuousMonitors[key] = nil
    end)
end

local function MonitorEntity(model)
    if AutoBlock.MonitoredEntities[model] or model == LocalPlayer.Character then return end
    local hum = model:FindFirstChildOfClass("Humanoid"); if not hum then return end; local animator = hum:FindFirstChildOfClass("Animator"); if not animator then return end
    local function onAnimPlayed(track)
        if not AutoBlock.Enabled then return end; local assetId = track.Animation.AnimationId:match("rbxassetid://(%d+)") or track.Animation.AnimationId
        for _, rule in ipairs(BlockRules) do
            if assetId == rule.animID then
                if rule.continuous then StartContinuousBlock(model, track, rule)
                else if rule.distance then local d = GetDistToEntity(model); if not d or d > rule.distance then return end end; ScheduleBlock(model.Name or "entity", rule.delay or 0.3) end; return
            end
        end
    end
    local conn = animator.AnimationPlayed:Connect(onAnimPlayed)
    AutoBlock.MonitoredEntities[model] = { conn }
    for _, t in ipairs(animator:GetPlayingAnimationTracks()) do onAnimPlayed(t) end
end

local function ScanForEntities()
    local lc = LocalPlayer.Character; if not lc then return end; local lr = lc:FindFirstChild("HumanoidRootPart"); if not lr then return end; local pp = lr.Position; local checked = {}
    for _, fn in ipairs({ workspace:FindFirstChild("NPCs"), workspace:FindFirstChild("Mobs"), workspace:FindFirstChild("Enemies") }) do
        if fn then for _, obj in ipairs(fn:GetDescendants()) do if obj:IsA("Model") and obj ~= lc and not checked[obj] then checked[obj] = true; local r = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Head"); if r and (pp - r.Position).Magnitude <= 250 and obj:FindFirstChildOfClass("Humanoid") and not AutoBlock.MonitoredEntities[obj] then MonitorEntity(obj) end end end end
    end
    -- Also scan workspace direct children (bosses can be top-level)
    for _, obj in ipairs(workspace:GetChildren()) do if obj:IsA("Model") and obj ~= lc and not checked[obj] then checked[obj] = true; local r = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Head"); if r and (pp - r.Position).Magnitude <= 250 and obj:FindFirstChildOfClass("Humanoid") and not AutoBlock.MonitoredEntities[obj] then MonitorEntity(obj) end end end
    for _, player in ipairs(Players:GetPlayers()) do if player ~= LocalPlayer and player.Character and not checked[player.Character] then local cr = player.Character:FindFirstChild("HumanoidRootPart"); if cr and (pp - cr.Position).Magnitude <= 250 and not AutoBlock.MonitoredEntities[player.Character] then MonitorEntity(player.Character) end end end
    for model, conns in pairs(AutoBlock.MonitoredEntities) do
        if not model or not model.Parent then for _, c in ipairs(conns) do if typeof(c) == "RBXScriptConnection" then c:Disconnect() end end; AutoBlock.MonitoredEntities[model] = nil
        else local d = GetDistToEntity(model); if not d or d > 300 then for _, c in ipairs(conns) do if typeof(c) == "RBXScriptConnection" then c:Disconnect() end end; AutoBlock.MonitoredEntities[model] = nil end end
    end
end

local function StartAutoBlock()
    if AutoBlock.ScanThread then pcall(task.cancel, AutoBlock.ScanThread) end
    AutoBlock.ScanThread = task.spawn(function() while AutoBlock.Enabled do ScanForEntities(); task.wait(1) end end)
end

local function StopAutoBlock()
    if AutoBlock.ScanThread then pcall(task.cancel, AutoBlock.ScanThread); AutoBlock.ScanThread = nil end
    for _, conns in pairs(AutoBlock.MonitoredEntities) do for _, c in ipairs(conns) do if typeof(c) == "RBXScriptConnection" then c:Disconnect() end end end
    AutoBlock.MonitoredEntities = {}; AutoBlock.ContinuousMonitors = {}; Unblock()
end

Hub.AutoBlock = AutoBlock
Hub.StartAutoBlock = StartAutoBlock
Hub.StopAutoBlock = StopAutoBlock

-- ================================================================
-- NOSTUN
-- ================================================================
local NoStun = { Enabled = false, Connections = {} }

local function ForceStunnedOff(obj)
    pcall(function()
        if obj:IsA("BoolValue") then obj.Value = false
        elseif obj:IsA("StringValue") then if obj.Value:upper() == "ON" then obj.Value = "OFF" end
        elseif obj:IsA("NumberValue") or obj:IsA("IntValue") then if obj.Value ~= 0 then obj.Value = 0 end end
    end)
end

local function WatchStunned(stunObj)
    if not stunObj then return nil end
    ForceStunnedOff(stunObj)
    local conn = stunObj:GetPropertyChangedSignal("Value"):Connect(function()
        if NoStun.Enabled then ForceStunnedOff(stunObj) end
    end)
    return conn
end

local function StopNoStun()
    for _, c in ipairs(NoStun.Connections) do pcall(function() c:Disconnect() end) end
    NoStun.Connections = {}
end

local function StartNoStun()
    StopNoStun()
    local function hookSettings()
        local settings = pcall(function() return ReplicatedStorage:FindFirstChild("Settings") end) and ReplicatedStorage:FindFirstChild("Settings")
        if not settings then return end
        local pf = settings:FindFirstChild(LocalPlayer.Name); if not pf then return end
        local stunned = pf:FindFirstChild("Stunned")
        if stunned then
            local c = WatchStunned(stunned)
            if c then table.insert(NoStun.Connections, c) end
        end
        local childConn = pf.ChildAdded:Connect(function(child)
            if child.Name == "Stunned" and NoStun.Enabled then
                ForceStunnedOff(child)
                local c = WatchStunned(child)
                if c then table.insert(NoStun.Connections, c) end
            end
        end)
        table.insert(NoStun.Connections, childConn)
    end
    hookSettings()
    local settingsConn = ReplicatedStorage.ChildAdded:Connect(function(child)
        if child.Name == "Settings" and NoStun.Enabled then task.wait(0.2); hookSettings() end
    end)
    table.insert(NoStun.Connections, settingsConn)
end

Hub.NoStun = NoStun
Hub.StartNoStun = StartNoStun
Hub.StopNoStun = StopNoStun


