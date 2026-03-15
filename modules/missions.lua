-- Jitler Hub - Missions Module (Mission System, Case Handlers, Auto Mission)
local Hub = shared.JitlerHub
local Players = Hub.Players
local RunService = Hub.RunService
local LocalPlayer = Hub.LocalPlayer
local Notify = Hub.Notify
local Format = Hub.Format
local TeleportTo = Hub.TeleportTo
local PressE = Hub.PressE

-- ================================================================
-- MISSION SYSTEM
-- ================================================================
local MissionSystem = {
    VillageName = nil,
    Board = nil,
    AvailableMissions = {},
    SelectedMission = nil,
    Cooldowns = {},
    ActiveMission = nil,
    AutoEnabled = false,
    Thread = nil,
    AnchorConn = nil,
    AttackThread = nil,
    CurrentTarget = nil,
    CurrentHeightOffset = nil,
    CurrentAttackDelay = nil,
    ExtraHeightBoost = 0,
}

local VALID_VILLAGES = { Snow = true, Sorythia = true, Rain = true, Durana = true, Rogue = true }

local function GetPlayerVillage()
    local team = LocalPlayer.Team
    if not team then return nil end
    local name = team.Name
    if VALID_VILLAGES[name] then return name end
    return nil
end

local function FindMissionBoard()
    local village = GetPlayerVillage()
    if not village then return nil, nil end
    MissionSystem.VillageName = village
    local boards = workspace:FindFirstChild("Mission Boards")
    if not boards then return nil, village end
    for _, board in ipairs(boards:GetChildren()) do
        local attr = nil
        pcall(function() attr = board:GetAttribute("Village") end)
        if attr and attr == village then
            MissionSystem.Board = board
            return board, village
        end
    end
    return nil, village
end

local function GetAvailableVillageMissions()
    local board, village = FindMissionBoard()
    if not village then return {} end
    if not board then return {} end
    local missions = {}
    for _, child in ipairs(board:GetChildren()) do
        local missionName = nil
        pcall(function() missionName = child:GetAttribute("Mission") end)
        if missionName and missionName ~= "" then
            if not MissionSystem.Cooldowns[missionName] or tick() > MissionSystem.Cooldowns[missionName] then
                table.insert(missions, missionName)
            end
        end
    end
    MissionSystem.AvailableMissions = missions
    return missions
end

local function RefreshMissionBoard()
    local missions = GetAvailableVillageMissions()
    if #missions == 0 then
        Notify("No available missions! (all on cooldown or no board)", 3)
    else
        Notify("Found " .. #missions .. " missions", 2)
    end
    return missions
end

-- Notification parser
local function GetMissionNotifications()
    local results = {}
    pcall(function()
        local gui = LocalPlayer.PlayerGui:FindFirstChild("ClientGui")
        if not gui then return end
        local mainframe = gui:FindFirstChild("Mainframe")
        if not mainframe then return end
        local notifFrame = mainframe:FindFirstChild("Notification")
        if not notifFrame then return end
        for i = 1, 3 do
            local nf = notifFrame:FindFirstChild("Notif" .. i)
            if nf then
                local msg = nf:FindFirstChild("Message")
                if msg and msg:IsA("TextLabel") and msg.Text ~= "" then
                    table.insert(results, msg.Text)
                end
            end
        end
    end)
    return results
end

local function CheckNotification(pattern)
    for _, text in ipairs(GetMissionNotifications()) do
        if text:find(pattern) then return true, text end
    end
    return false, nil
end

local function ParseCooldownFromNotif(text)
    local minutes = text:match("come back in (%d+)")
    if minutes then return tonumber(minutes) * 60 end
    local hours = text:match("come back in (%d+) hour")
    if hours then return tonumber(hours) * 3600 end
    return 300
end

-- Mission marker scanner
local function ScanMissionMarkersFixed()
    local markers = {}
    local debris = workspace:FindFirstChild("Debris"); if not debris then return markers end
    local ml = debris:FindFirstChild("Mission Locations"); if not ml then return markers end
    local myUserId = LocalPlayer.UserId
    for _, villageFolder in ipairs(ml:GetChildren()) do
        for _, child in ipairs(villageFolder:GetDescendants()) do
            if child.Name == "MissionMarker" then
                -- Check Active property - skip inactive markers
                local active = true
                pcall(function()
                    local activeVal = child:FindFirstChild("Active")
                    if activeVal then
                        local v = activeVal.Value
                        if v == false or v == "Off" or v == "off" or v == "OFF" then active = false end
                    else
                        local attr = child:GetAttribute("Active")
                        if attr ~= nil then
                            if attr == false or attr == "Off" or attr == "off" or attr == "OFF" then active = false end
                        end
                    end
                end)
                if not active then continue end

                -- Check UserId attribute - only use markers assigned to us
                local userIdOk = false
                pcall(function()
                    local uidVal = child:FindFirstChild("UserId")
                    if uidVal then
                        if tonumber(uidVal.Value) == myUserId then userIdOk = true end
                    else
                        local attr = child:GetAttribute("UserId")
                        if attr ~= nil then
                            if tonumber(attr) == myUserId then userIdOk = true end
                        end
                    end
                end)
                if not userIdOk then continue end

                local parent = child.Parent
                local pos = nil
                -- Try getting position from the marker itself
                pcall(function()
                    if child:IsA("BasePart") then pos = child.Position
                    elseif child:IsA("Attachment") then pos = child.WorldPosition
                    elseif child:IsA("Model") then pos = child:GetPivot().Position
                    else
                        local bp = child:FindFirstChildWhichIsA("BasePart", true)
                        if bp then pos = bp.Position end
                    end
                end)
                -- Try getting position from the parent spawner
                if not pos and parent then
                    pcall(function()
                        if parent:IsA("BasePart") then pos = parent.Position
                        elseif parent:IsA("Model") then
                            local root = parent:FindFirstChild("HumanoidRootPart") or parent:FindFirstChild("Head") or parent:FindFirstChildWhichIsA("BasePart")
                            if root then pos = root.Position else pos = parent:GetPivot().Position end
                        else
                            local bp = parent:FindFirstChildWhichIsA("BasePart", true)
                            if bp then pos = bp.Position end
                        end
                    end)
                end
                -- Walk up one more level if still no position
                if not pos and parent and parent.Parent then
                    pcall(function()
                        local gp = parent.Parent
                        local bp = gp:FindFirstChildWhichIsA("BasePart", true)
                        if bp then pos = bp.Position end
                    end)
                end
                if pos then
                    local label = villageFolder.Name .. "/" .. (parent and parent.Name or "unknown")
                    table.insert(markers, { name = label, pos = pos, parent = parent })
                end
            end
        end
    end
    return markers
end

local function GetNearestMissionMarker()
    local markers = ScanMissionMarkersFixed()
    if #markers == 0 then return nil end
    local char = LocalPlayer.Character; if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart"); if not root then return nil end
    local pp = root.Position
    local nearest, minD = nil, math.huge
    for _, m in ipairs(markers) do
        local d = (pp - m.pos).Magnitude
        if d < minD then minD = d; nearest = m end
    end
    return nearest
end

local function TeleportToNearestMissionMarker()
    local m = GetNearestMissionMarker()
    if not m then Notify("No mission markers found!", 2); return nil end
    TeleportTo(m.pos); Notify("TP: " .. m.name, 2)
    return m
end

-- Find NPC near a position
local function FindNPCNear(pos, radius, nameFilter)
    local found = {}
    local function check(model)
        if not model:IsA("Model") then return end
        local hum = model:FindFirstChildOfClass("Humanoid"); if not hum or hum.Health <= 0 then return end
        local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head") or model:FindFirstChildWhichIsA("BasePart"); if not root then return end
        if (root.Position - pos).Magnitude > radius then return end
        if nameFilter then
            if type(nameFilter) == "string" then
                if not model.Name:find(nameFilter) then return end
            elseif type(nameFilter) == "table" then
                local match = false
                for _, n in ipairs(nameFilter) do if model.Name == n then match = true; break end end
                if not match then return end
            end
        end
        table.insert(found, { model = model, humanoid = hum, root = root })
    end
    for _, fn in ipairs({"NPCs", "Mobs", "Enemies"}) do
        local f = workspace:FindFirstChild(fn); if f then for _, m in ipairs(f:GetChildren()) do check(m) end end
    end
    for _, m in ipairs(workspace:GetChildren()) do check(m) end
    return found
end

-- Wait for mission notification (also monitors mob death to keep attacking)
local function WaitForMissionResult(timeout)
    timeout = timeout or 120
    local start = tick()
    while tick() - start < timeout do
        local complete = CheckNotification("Mission Complete")
        local failed = CheckNotification("Mission Failed!")
        local cooldown, cdText = CheckNotification("already completed this mission")
        if complete then return "complete" end
        if failed then return "failed" end
        if cooldown then return "cooldown", cdText end
        -- Check if the attack thread died (mob dead) but mission not done yet
        -- This means the mob died but we need to keep waiting for the result
        if MissionSystem.AttackThread == nil or (MissionSystem.CurrentTarget and MissionSystem.CurrentTarget.humanoid and (not MissionSystem.CurrentTarget.humanoid.Parent or MissionSystem.CurrentTarget.humanoid.Health <= 0)) then
            -- Mob is dead, just wait for the notification a bit longer
            task.wait(0.5)
        else
            task.wait(0.5)
        end
    end
    return "timeout"
end

-- Assign a mission from the board
local function AssignMission(missionName)
    local board = MissionSystem.Board
    if not board then FindMissionBoard(); board = MissionSystem.Board end
    if not board then Notify("No mission board!", 3); return false end
    for _, child in ipairs(board:GetChildren()) do
        local attr = nil; pcall(function() attr = child:GetAttribute("Mission") end)
        if attr == missionName then
            pcall(function()
                local root = child:FindFirstChildWhichIsA("BasePart") or child:FindFirstChild("HumanoidRootPart")
                if root then TeleportTo(root.Position) end
                task.wait(0.5)
                local prox = child:FindFirstChildOfClass("ProximityPrompt")
                if prox then
                    if fireproximityprompt then fireproximityprompt(prox) end
                end
                local click = child:FindFirstChildOfClass("ClickDetector")
                if click then
                    if fireclickdetector then fireclickdetector(click) end
                end
                if not prox and not click then
                    if getconnections then
                        for _, sig in ipairs({"MouseClick", "MouseButton1Click", "Activated"}) do
                            local obj = child:FindFirstChild(sig)
                            if obj then for _, c in ipairs(getconnections(obj)) do pcall(function() c:Fire() end) end end
                        end
                    end
                    PressE()
                end
            end)
            task.wait(1)
            if CheckNotification("You already have a mission") then return false end
            local _, cdText = CheckNotification("already completed this mission")
            if cdText then
                local cdSec = ParseCooldownFromNotif(cdText)
                MissionSystem.Cooldowns[missionName] = tick() + cdSec
                return false
            end
            return true
        end
    end
    return false
end

Hub.MissionSystem = MissionSystem
Hub.RefreshMissionBoard = RefreshMissionBoard
Hub.GetAvailableVillageMissions = GetAvailableVillageMissions
Hub.ScanMissionMarkersFixed = ScanMissionMarkersFixed
Hub.TeleportToNearestMissionMarker = TeleportToNearestMissionMarker

-- ================================================================
-- MISSION CASE HANDLERS
-- ================================================================

local function MissionFarmLoop(target, heightOffset, attackDelay)
    attackDelay = attackDelay or 0.12
    local model = target.model; local hum = target.humanoid

    -- Save current target info for Chakra Safety reattach
    MissionSystem.CurrentTarget = target
    MissionSystem.CurrentHeightOffset = heightOffset
    MissionSystem.CurrentAttackDelay = attackDelay

    -- Auto-detect weapon from hotbar and equip it
    local weaponHeightBoost = 0
    if Hub.ScanHotbarForWeapon then
        local detectedWeapon = Hub.ScanHotbarForWeapon()
        if detectedWeapon then
            if Hub.DataEvent then pcall(function() Hub.DataEvent:FireServer("Item", "Selected", detectedWeapon) end) end
            if Hub.WEAPON_HEIGHT_BOOSTS and Hub.WEAPON_HEIGHT_BOOSTS[detectedWeapon] then
                weaponHeightBoost = Hub.WEAPON_HEIGHT_BOOSTS[detectedWeapon]
            end
        end
    end
    local effectiveHeight = heightOffset + weaponHeightBoost

    -- Start charging + animation
    if Hub.StartCharging then Hub.StartCharging() end

    MissionSystem.AnchorConn = RunService.Heartbeat:Connect(function()
        pcall(function()
            if not MissionSystem.ActiveMission then return end
            if not hum or not hum.Parent or hum.Health <= 0 then return end
            local bossRoot = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head") or model:FindFirstChildWhichIsA("BasePart"); if not bossRoot then return end
            local char = LocalPlayer.Character; if not char then return end; local root = char:FindFirstChild("HumanoidRootPart"); if not root then return end
            root.CFrame = CFrame.lookAt(bossRoot.Position + Vector3.new(0, effectiveHeight + MissionSystem.ExtraHeightBoost, 0), bossRoot.Position)
        end)
    end)

    MissionSystem.AttackThread = task.spawn(function()
        while MissionSystem.ActiveMission and hum and hum.Parent and hum.Health > 0 do
            -- Check if Chakra Safety is hiding us - pause attacking
            if Hub.ChakraSafety and Hub.ChakraSafety.Hiding then
                task.wait(0.5)
                continue
            end
            -- Pause attacks while AutoBlock is blocking
            if Hub.AutoBlock and Hub.AutoBlock.CurrentlyBlocking then task.wait(0.05); continue end
            pcall(function()
                if Hub.DataEvent then
                    local br = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head")
                    if br then Hub.DataEvent:FireServer("Dash", "Sub", br.Position) end
                    task.wait(0.05)
                    Hub.DataEvent:FireServer("CheckMeleeHit", nil, "NormalAttack", false)
                end
            end)
            task.wait(attackDelay)
        end
    end)
end

local function StopMissionFarm()
    if Hub.StopCharging then Hub.StopCharging() end
    if MissionSystem.AnchorConn then MissionSystem.AnchorConn:Disconnect(); MissionSystem.AnchorConn = nil end
    if MissionSystem.AttackThread then pcall(task.cancel, MissionSystem.AttackThread); MissionSystem.AttackThread = nil end
    MissionSystem.CurrentTarget = nil
    MissionSystem.CurrentHeightOffset = nil
    MissionSystem.CurrentAttackDelay = nil
    MissionSystem.ExtraHeightBoost = 0
end

local function MonitorKnockedForGrip(model)
    local settings = model:FindFirstChild("Settings")
    if not settings then return end
    local knocked = settings:FindFirstChild("Knocked")
    if not knocked then return end
    task.spawn(function()
        while MissionSystem.ActiveMission and model and model.Parent do
            local isKnocked = false
            pcall(function()
                if knocked.Value == true or (type(knocked.Value) == "string" and knocked.Value:upper() == "ON") or (type(knocked.Value) == "number" and knocked.Value ~= 0) then
                    isKnocked = true
                end
            end)
            if isKnocked then
                Hub.Notify("Mob knocked! Gripping...", 2)
                -- Stop anchor and attack so we can move to the mob
                if MissionSystem.AnchorConn then MissionSystem.AnchorConn:Disconnect(); MissionSystem.AnchorConn = nil end
                if MissionSystem.AttackThread then pcall(task.cancel, MissionSystem.AttackThread); MissionSystem.AttackThread = nil end
                Hub.StopCharging()
                -- Teleport to mob and grip
                local mobRoot = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head") or model:FindFirstChildWhichIsA("BasePart")
                if mobRoot then
                    local char = Hub.LocalPlayer.Character
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    if root then root.CFrame = CFrame.new(mobRoot.Position) end
                    task.wait(0.1)
                    if Hub.DataEvent then pcall(function() Hub.DataEvent:FireServer("Grip") end) end
                end
                task.wait(0.5)
                StopMissionFarm()
                return
            end
            task.wait(0.2)
        end
    end)
end

local function ExecuteMissionCase(missionName)
    MissionSystem.ActiveMission = missionName
    StopMissionFarm()

    local marker = nil
    local markerPos = nil

    if missionName ~= "Crate Delivery" then
        marker = TeleportToNearestMissionMarker()
        if not marker then
            Notify("No mission marker for: " .. missionName, 3)
            MissionSystem.ActiveMission = nil
            return "failed"
        end
        task.wait(1.5)
        markerPos = marker.pos
    end

    if missionName == "Defeat a Boss" then
        local targets = FindNPCNear(markerPos, 300, {"The Barbarian", "Barbarit The Rose"})
        if #targets == 0 then Notify("Boss not found near marker!", 3); MissionSystem.ActiveMission = nil; return "failed" end
        local target = targets[1]
        MonitorKnockedForGrip(target.model)
        MissionFarmLoop(target, 12, 0.12)
        local result = WaitForMissionResult(180)
        StopMissionFarm(); MissionSystem.ActiveMission = nil; return result

    elseif missionName == "Bandit Camp" then
        local function farmBandits()
            for attempt = 1, 30 do
                if not MissionSystem.ActiveMission then return "cancelled" end
                if CheckNotification("Mission Complete") then return "complete" end
                local targets = FindNPCNear(markerPos, 300, "Bandit")
                if #targets == 0 then
                    if CheckNotification("Mission Complete") then return "complete" end
                    task.wait(2); continue
                end
                -- Attack the first alive bandit
                local target = targets[1]
                if not MissionSystem.ActiveMission then return "cancelled" end
                MissionFarmLoop(target, 10.75, 0.12)
                while MissionSystem.ActiveMission and target.humanoid and target.humanoid.Parent and target.humanoid.Health > 0 do task.wait(0.3) end
                StopMissionFarm()
                if CheckNotification("Mission Complete") then return "complete" end
                task.wait(0.5)
            end
            return WaitForMissionResult(30)
        end
        local result = farmBandits()
        StopMissionFarm(); MissionSystem.ActiveMission = nil; return result

    elseif missionName == "Corrupted Point" then
        -- CorruptedPoint is a Model in workspace with Health (NumberValue), Destroyed (BoolValue), no Humanoid
        -- After teleporting to marker, find the nearest CorruptedPoint, teleport to it with -10 offset, and M1 spam
        local char = LocalPlayer.Character; local lr = char and char:FindFirstChild("HumanoidRootPart")
        local playerPos = lr and lr.Position or markerPos
        local cpModel = nil
        for attempt = 1, 15 do
            local bestDist = math.huge
            pcall(function()
                for _, obj in ipairs(workspace:GetChildren()) do
                    if obj:IsA("Model") and obj.Name == "CorruptedPoint" then
                        local healthVal = obj:FindFirstChild("Health")
                        local destroyed = obj:FindFirstChild("Destroyed")
                        if healthVal and (not destroyed or destroyed.Value ~= true) then
                            local part = obj:FindFirstChildWhichIsA("BasePart")
                            if part then
                                local dist = (part.Position - playerPos).Magnitude
                                if dist < bestDist then bestDist = dist; cpModel = obj end
                            end
                        end
                    end
                end
            end)
            if cpModel then break end
            Notify("Waiting for Corrupted Point... (" .. attempt .. "/15)", 2)
            task.wait(2)
        end
        if not cpModel then Notify("Corrupted Point not found after retries!", 3); MissionSystem.ActiveMission = nil; return "failed" end
        -- Equip weapon and start charging
        if Hub.ScanHotbarForWeapon then
            local detectedWeapon = Hub.ScanHotbarForWeapon()
            if detectedWeapon and Hub.DataEvent then pcall(function() Hub.DataEvent:FireServer("Item", "Selected", detectedWeapon) end) end
        end
        if Hub.StartCharging then Hub.StartCharging() end
        -- Teleport to it with -5 Y offset, facing up toward the CorruptedPoint
        local cpPart = cpModel:FindFirstChildWhichIsA("BasePart")
        if cpPart then
            local pos = cpPart.Position + Vector3.new(0, -5, 0)
            TeleportTo(pos); task.wait(0.3)
            local c = LocalPlayer.Character; if c then local r = c:FindFirstChild("HumanoidRootPart"); if r then r.CFrame = CFrame.new(pos) * CFrame.Angles(math.pi / 2, 0, 0) end end
            task.wait(0.2)
        end
        local healthVal = cpModel:FindFirstChild("Health")
        -- Anchor with -5 offset, facing up toward the CorruptedPoint, until destroyed
        MissionSystem.AnchorConn = RunService.Heartbeat:Connect(function()
            pcall(function()
                if not MissionSystem.ActiveMission or not cpModel or not cpModel.Parent then return end
                local part = cpModel:FindFirstChildWhichIsA("BasePart"); if not part then return end
                local c = LocalPlayer.Character; if not c then return end; local root = c:FindFirstChild("HumanoidRootPart"); if not root then return end
                local pos = part.Position + Vector3.new(0, -5, 0)
                root.CFrame = CFrame.new(pos) * CFrame.Angles(math.pi / 2, 0, 0)
                root.Velocity = Vector3.zero; root.RotVelocity = Vector3.zero
            end)
        end)
        MissionSystem.AttackThread = task.spawn(function()
            while MissionSystem.ActiveMission and cpModel and cpModel.Parent do
                local destroyed = cpModel:FindFirstChild("Destroyed")
                if destroyed and destroyed.Value == true then break end
                if healthVal and healthVal:IsA("NumberValue") and healthVal.Value <= 0 then break end
                if Hub.AutoBlock and Hub.AutoBlock.CurrentlyBlocking then task.wait(0.05); continue end
                if Hub.ChakraSafety and Hub.ChakraSafety.Hiding then task.wait(0.5); continue end
                pcall(function()
                    if Hub.DataEvent then
                        local cpPartNow = cpModel:FindFirstChildWhichIsA("BasePart")
                        if cpPartNow then Hub.DataEvent:FireServer("Dash", "Sub", cpPartNow.Position) end
                        task.wait(0.05)
                        Hub.DataEvent:FireServer("CheckMeleeHit", nil, "NormalAttack", false)
                    end
                end)
                task.wait(0.12)
            end
            if Hub.StopCharging then Hub.StopCharging() end
        end)
        local result = WaitForMissionResult(180)
        StopMissionFarm(); MissionSystem.ActiveMission = nil; return result

    elseif missionName == "Cratos" then
        local targets = FindNPCNear(markerPos, 300, {"Cratos"})
        if #targets == 0 then Notify("Cratos not found near marker!", 3); MissionSystem.ActiveMission = nil; return "failed" end
        MissionFarmLoop(targets[1], 10.75, 0.12)
        local result = WaitForMissionResult(180)
        StopMissionFarm(); MissionSystem.ActiveMission = nil; return result

    elseif missionName == "Capture Manda" then
        local targets = FindNPCNear(markerPos, 300, {"Manda"})
        if #targets == 0 then Notify("Manda not found near marker!", 3); MissionSystem.ActiveMission = nil; return "failed" end
        local target = targets[1]
        pcall(function()
            local hum = target.humanoid; local animator = hum:FindFirstChildOfClass("Animator")
            if animator then
                local mandaConn
                mandaConn = animator.AnimationPlayed:Connect(function(track)
                    if not MissionSystem.ActiveMission then mandaConn:Disconnect(); return end
                    local assetId = track.Animation.AnimationId:match("rbxassetid://(%d+)") or track.Animation.AnimationId
                    if assetId == "9954909571" then
                        MissionSystem.ExtraHeightBoost = 6
                        task.spawn(function()
                            while track and track.IsPlaying and MissionSystem.ActiveMission do task.wait(0.1) end
                            task.wait(0.5)
                            MissionSystem.ExtraHeightBoost = 0
                        end)
                    end
                end)
            end
        end)
        MissionFarmLoop(target, 38, 0.12)
        local result = WaitForMissionResult(180)
        StopMissionFarm(); MissionSystem.ActiveMission = nil; return result

    elseif missionName == "Defeat a Bandit" then
        local targets = FindNPCNear(markerPos, 300, "Bandit")
        if #targets == 0 then Notify("Bandit not found near marker!", 3); MissionSystem.ActiveMission = nil; return "failed" end
        MissionFarmLoop(targets[1], 10.75, 0.12)
        local result = WaitForMissionResult(180)
        StopMissionFarm(); MissionSystem.ActiveMission = nil; return result

    elseif missionName == "Crate Delivery" then
        -- Scan NPCs/Mobs/Enemies for MissionMarker assigned to our UserId
        local npc = nil
        pcall(function()
            for _, fn in ipairs({"NPCs", "Mobs", "Enemies"}) do
                if npc then break end
                local f = workspace:FindFirstChild(fn)
                if f then
                    for _, m in ipairs(f:GetDescendants()) do
                        if m.Name == "MissionMarker" then
                            local uid = nil
                            pcall(function() uid = m:GetAttribute("UserId") or (m:FindFirstChild("UserId") and m:FindFirstChild("UserId").Value) end)
                            if uid and tonumber(uid) == LocalPlayer.UserId then
                                npc = m.Parent; break
                            end
                        end
                    end
                end
            end
        end)
        -- Fallback: scan workspace and Debris
        if not npc then
            pcall(function()
                for _, container in ipairs({workspace, workspace:FindFirstChild("Debris")}) do
                    if npc then break end
                    if container then
                        for _, m in ipairs(container:GetDescendants()) do
                            if m.Name == "MissionMarker" then
                                local uid = nil
                                pcall(function() uid = m:GetAttribute("UserId") or (m:FindFirstChild("UserId") and m:FindFirstChild("UserId").Value) end)
                                if uid and tonumber(uid) == LocalPlayer.UserId then
                                    npc = m.Parent; break
                                end
                            end
                        end
                    end
                end
            end)
        end
        -- Last resort: try mission marker system
        if not npc then
            local m = TeleportToNearestMissionMarker()
            if m and m.parent then npc = m.parent end
        end
        if npc then
            local root = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Head") or npc:FindFirstChildWhichIsA("BasePart")
            if root then TeleportTo(root.Position); task.wait(0.5) end
            -- Try ProximityPrompt (search descendants)
            local prox = nil
            pcall(function() for _, desc in ipairs(npc:GetDescendants()) do if desc:IsA("ProximityPrompt") then prox = desc; break end end end)
            if prox then
                if fireproximityprompt then fireproximityprompt(prox) end
            else
                PressE()
            end
        else
            Notify("Crate Delivery NPC not found!", 3)
        end
        task.wait(0.5)
        -- Fire remote once, then spam E until Mission Complete (max 3 seconds)
        pcall(function() Hub.RefreshDataFunction(); if Hub.DataFunction then Hub.DataFunction:InvokeServer("Crate Delivery") end end)
        task.wait(0.3)
        local startTime = tick()
        while tick() - startTime < 3 do
            if CheckNotification("Mission Complete") then break end
            PressE()
            task.wait(0.15)
        end
        local result = WaitForMissionResult(30)
        MissionSystem.ActiveMission = nil; return result

    else
        Notify("Unknown mission: " .. missionName, 3)
        MissionSystem.ActiveMission = nil
        return "unknown"
    end
end

-- ================================================================
-- AUTO MISSION
-- ================================================================
local function StopAutoMission()
    MissionSystem.AutoEnabled = false
    MissionSystem.ActiveMission = nil
    StopMissionFarm()
    if MissionSystem.Thread then pcall(task.cancel, MissionSystem.Thread); MissionSystem.Thread = nil end
end

local function StartAutoMission()
    StopAutoMission()
    MissionSystem.AutoEnabled = true
    local village = GetPlayerVillage()
    if not village then
        Notify("You need to join a village for this feature!", 3)
        MissionSystem.AutoEnabled = false
        return
    end
    FindMissionBoard()

    MissionSystem.Thread = task.spawn(function()
        while MissionSystem.AutoEnabled do
            local missions = GetAvailableVillageMissions()
            if #missions == 0 then
                Notify("All missions on cooldown!", 3)
                MissionSystem.AutoEnabled = false
                break
            end

            local missionToRun = MissionSystem.SelectedMission
            if not missionToRun or not table.find(missions, missionToRun) then
                missionToRun = missions[1]
            end

            Notify("AutoMission: " .. missionToRun, 2)

            local assigned = AssignMission(missionToRun)
            if not assigned then
                if CheckNotification("You already have a mission") then
                    -- Already have a mission, try to execute it
                else
                    Notify("Failed to assign: " .. missionToRun, 2)
                    task.wait(2); continue
                end
            end
            task.wait(1)

            local result = ExecuteMissionCase(missionToRun)
            if result == "complete" then
                Notify("Mission complete: " .. missionToRun, 2)
            elseif result == "failed" then
                Notify("Mission failed: " .. missionToRun, 2)
            elseif result == "cooldown" then
                MissionSystem.Cooldowns[missionToRun] = tick() + 300
                Notify("Mission on cooldown: " .. missionToRun, 2)
            end

            if not MissionSystem.AutoEnabled then break end
            task.wait(3)
        end
    end)
end

Hub.StartAutoMission = StartAutoMission
Hub.StopAutoMission = StopAutoMission
Hub.AssignMission = AssignMission
Hub.ExecuteMissionCase = ExecuteMissionCase
