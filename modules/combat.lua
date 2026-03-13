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
local BackAttach = { Enabled = false, Weld = nil, Target = nil, HeartbeatConn = nil, MaxDistance = 200 }

local function GetNearestPlayer()
    local char = LocalPlayer.Character; if not char then return nil end; local root = char:FindFirstChild("HumanoidRootPart"); if not root then return nil end
    local nearest, nearestDist = nil, BackAttach.MaxDistance
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end; local tc = player.Character; if not tc then continue end
        local tr = tc:FindFirstChild("HumanoidRootPart"); if not tr then continue end; local hum = tc:FindFirstChildOfClass("Humanoid"); if not hum or hum.Health <= 0 then continue end
        local dist = (root.Position - tr.Position).Magnitude; if dist < nearestDist then nearestDist = dist; nearest = player end
    end
    return nearest
end

local function StopBackAttach()
    BackAttach.Enabled = false; if BackAttach.Weld then BackAttach.Weld:Destroy(); BackAttach.Weld = nil end
    if BackAttach.HeartbeatConn then BackAttach.HeartbeatConn:Disconnect(); BackAttach.HeartbeatConn = nil end; BackAttach.Target = nil
end

local function StartBackAttach()
    local char = LocalPlayer.Character; if not char then BackAttach.Enabled = false; return end
    local myRoot = char:FindFirstChild("HumanoidRootPart"); if not myRoot then BackAttach.Enabled = false; return end
    local target = GetNearestPlayer(); if not target or not target.Character then Notify("No player within " .. BackAttach.MaxDistance .. " studs!", 3); BackAttach.Enabled = false; return end
    local targetRoot = target.Character:FindFirstChild("HumanoidRootPart"); if not targetRoot then BackAttach.Enabled = false; return end
    BackAttach.Target = target; myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 2.5)
    local weld = Instance.new("WeldConstraint"); weld.Part0 = myRoot; weld.Part1 = targetRoot; weld.Parent = myRoot; BackAttach.Weld = weld
    Notify("Attached to " .. target.Name, 2)
    BackAttach.HeartbeatConn = RunService.Heartbeat:Connect(function() if not BackAttach.Enabled then return end; if not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then StopBackAttach() end end)
end

LocalPlayer.CharacterAdded:Connect(function() if BackAttach.Enabled then task.wait(1); StartBackAttach() end end)

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
local AutoBlock = { Enabled = false, MonitoredEntities = {}, Triggered = {}, ContinuousMonitors = {}, ScanThread = nil }

local function GetDistToEntity(model)
    local lc = LocalPlayer.Character; if not lc or not model then return nil end
    local lr = lc:FindFirstChild("HumanoidRootPart") or lc:FindFirstChild("Head")
    local tr = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head")
    if not lr or not tr then return nil end; return (lr.Position - tr.Position).Magnitude
end

local function Block() if Hub.DataFunction then pcall(function() Hub.DataFunction:InvokeServer("Block") end) end end
local function Unblock() if Hub.DataFunction then pcall(function() Hub.DataFunction:InvokeServer("EndBlock") end) end end

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
        if fn then for _, obj in ipairs(fn:GetChildren()) do if obj:IsA("Model") and obj ~= lc and not checked[obj] then checked[obj] = true; local r = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Head"); if r and (pp - r.Position).Magnitude <= 250 and obj:FindFirstChildOfClass("Humanoid") and not AutoBlock.MonitoredEntities[obj] then MonitorEntity(obj) end end end end
    end
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

-- ================================================================
-- HITBOX EXTENDER
-- ================================================================
local HitboxExtender = { Enabled = false, Size = 5, ShowRadius = false, Connection = nil, Indicators = {} }
local ORIGINAL_HRP_SIZE = Vector3.new(2, 2, 1)

local function UpdateHitboxes()
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local char = player.Character; if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then continue end
        local hum = char:FindFirstChildOfClass("Humanoid"); if not hum or hum.Health <= 0 then continue end
        pcall(function() hrp.Size = Vector3.new(HitboxExtender.Size, HitboxExtender.Size, HitboxExtender.Size); hrp.Transparency = 1 end)
        if HitboxExtender.ShowRadius then
            if not HitboxExtender.Indicators[player] or not HitboxExtender.Indicators[player].Parent then
                pcall(function()
                    if HitboxExtender.Indicators[player] then HitboxExtender.Indicators[player]:Destroy() end
                end)
                local sphere = Instance.new("Part")
                sphere.Name = "HitboxIndicator"; sphere.Shape = Enum.PartType.Ball
                sphere.Color = Color3.fromRGB(255, 0, 0); sphere.Material = Enum.Material.ForceField
                sphere.Transparency = 0.6; sphere.Anchored = true; sphere.CanCollide = false; sphere.CastShadow = false
                sphere.Parent = workspace
                HitboxExtender.Indicators[player] = sphere
            end
            local sphere = HitboxExtender.Indicators[player]
            pcall(function()
                sphere.Size = Vector3.new(HitboxExtender.Size, HitboxExtender.Size, HitboxExtender.Size)
                sphere.CFrame = hrp.CFrame; sphere.Transparency = 0.6
            end)
        else
            if HitboxExtender.Indicators[player] then
                pcall(function() HitboxExtender.Indicators[player]:Destroy() end)
                HitboxExtender.Indicators[player] = nil
            end
        end
    end
end

local function StartHitbox()
    if HitboxExtender.Connection then HitboxExtender.Connection:Disconnect() end
    HitboxExtender.Connection = RunService.Heartbeat:Connect(function()
        if not HitboxExtender.Enabled then return end
        pcall(UpdateHitboxes)
    end)
end

local function StopHitbox()
    if HitboxExtender.Connection then HitboxExtender.Connection:Disconnect(); HitboxExtender.Connection = nil end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            pcall(function()
                local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.Size = ORIGINAL_HRP_SIZE; hrp.Transparency = 1 end
            end)
        end
    end
    for _, indicator in pairs(HitboxExtender.Indicators) do pcall(function() indicator:Destroy() end) end
    HitboxExtender.Indicators = {}
end

Hub.HitboxExtender = HitboxExtender
Hub.StartHitbox = StartHitbox
Hub.StopHitbox = StopHitbox
