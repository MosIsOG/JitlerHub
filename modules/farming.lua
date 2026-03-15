-- Jitler Hub - Farming Module (Visuals, BulkSell, BossFarm, AutoEye, AutoGrip, Trinkets, ServerHop, Chakra, BuyItems)
local Hub = shared.JitlerHub
local Players = Hub.Players
local RunService = Hub.RunService
local LocalPlayer = Hub.LocalPlayer
local Camera = workspace.CurrentCamera
local Lighting = Hub.Lighting
local ReplicatedStorage = Hub.ReplicatedStorage
local Notify = Hub.Notify
local Format = Hub.Format
local TeleportTo = Hub.TeleportTo

-- ================================================================
-- VISUAL FEATURES
-- ================================================================
local OrigFogEnd = Lighting.FogEnd
local OrigBrightness = Lighting.Brightness
local OrigAmbient = Lighting.Ambient
local OrigOutdoorAmbient = Lighting.OutdoorAmbient
local OrigGlobalShadows = Lighting.GlobalShadows
local NoFogEnabled = false
local NoRainEnabled = false

local function ToggleNoFog(enabled)
    NoFogEnabled = enabled
    if enabled then OrigFogEnd = Lighting.FogEnd; Lighting.FogEnd = 9999999
    else Lighting.FogEnd = OrigFogEnd end
end

local NoRainConns = {}
local RainPartsClone = nil

local function ToggleNoRain(enabled)
    NoRainEnabled = enabled
    if enabled then
        for _, c in ipairs(NoRainConns) do pcall(function() c:Disconnect() end) end; NoRainConns = {}
        pcall(function()
            local rainParts = workspace:FindFirstChild("RainParts")
            if rainParts then
                RainPartsClone = rainParts:Clone()
                RainPartsClone.Parent = nil
                pcall(function() rainParts:Destroy() end)
            end
            for _, v in ipairs(Lighting:GetDescendants()) do if v:IsA("ParticleEmitter") then v.Enabled = false end end
            local terrain = workspace:FindFirstChild("Terrain")
            if terrain then for _, v in ipairs(terrain:GetDescendants()) do if v:IsA("ParticleEmitter") then v.Enabled = false end end end
        end)
        table.insert(NoRainConns, workspace.ChildAdded:Connect(function(child)
            if child.Name == "RainParts" then
                task.defer(function()
                    pcall(function()
                        RainPartsClone = child:Clone()
                        RainPartsClone.Parent = nil
                        pcall(function() child:Destroy() end)
                    end)
                end)
            end
        end))
        table.insert(NoRainConns, Lighting.DescendantAdded:Connect(function(child) if child:IsA("ParticleEmitter") then child.Enabled = false end end))
    else
        for _, c in ipairs(NoRainConns) do pcall(function() c:Disconnect() end) end; NoRainConns = {}
        pcall(function()
            if RainPartsClone then RainPartsClone.Parent = workspace; RainPartsClone = nil end
            for _, v in ipairs(Lighting:GetDescendants()) do if v:IsA("ParticleEmitter") then v.Enabled = true end end
        end)
    end
end

local function ToggleFullBright(enabled, level)
    Hub.FullBrightEnabled = enabled; level = level or Hub.FullBrightLevel
    if enabled then
        Lighting.Brightness = level; Lighting.Ambient = Color3.fromRGB(178, 178, 178); Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178); Lighting.GlobalShadows = false
    else
        Lighting.Brightness = OrigBrightness; Lighting.Ambient = OrigAmbient; Lighting.OutdoorAmbient = OrigOutdoorAmbient; Lighting.GlobalShadows = OrigGlobalShadows
    end
end

Hub.ToggleNoFog = ToggleNoFog
Hub.ToggleNoRain = ToggleNoRain
Hub.ToggleFullBright = ToggleFullBright

-- ================================================================
-- CHARGING + ANIMATION HELPERS (used by Boss Farm & Mission Farm)
-- ================================================================
local CHARGE_ANIM_ID = "rbxassetid://9864206537"
local ChargingState = { Active = false, AnimTrack = nil }

local function StartCharging()
    if ChargingState.Active then return end
    ChargingState.Active = true
    pcall(function()
        Hub.RefreshDataEvent()
        if Hub.DataEvent then Hub.DataEvent:FireServer("Charging") end
    end)
    pcall(function()
        local char = LocalPlayer.Character; if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
        local animator = hum:FindFirstChildOfClass("Animator")
        if not animator then animator = Instance.new("Animator"); animator.Parent = hum end
        local anim = Instance.new("Animation")
        anim.AnimationId = CHARGE_ANIM_ID
        local track = animator:LoadAnimation(anim)
        track.Looped = true
        track:Play()
        ChargingState.AnimTrack = track
    end)
end

local function StopCharging()
    if not ChargingState.Active then return end
    ChargingState.Active = false
    pcall(function()
        if ChargingState.AnimTrack then
            ChargingState.AnimTrack:Stop()
            ChargingState.AnimTrack = nil
        end
    end)
    pcall(function()
        Hub.RefreshDataEvent()
        if Hub.DataEvent then Hub.DataEvent:FireServer("StopCharging") end
    end)
end

Hub.StartCharging = StartCharging
Hub.StopCharging = StopCharging
Hub.ChargingState = ChargingState

-- ================================================================
-- BULK SELLER (Direct Remote)
-- ================================================================
local TRINKET_VALUES = {
    ["Silver Enclosed Ring"] = 3, ["Silver Ring"] = 2, ["Silver Bracelet"] = 2,
    ["Gold Enclosed Ring"] = 5, ["Gold Necklace"] = 5, ["Silver Necklace"] = 3,
    ["Gold Bracelet"] = 3, ["Gold Ring"] = 5,
}

local function GetDataFunction()
    if Hub.RefreshDataFunction then Hub.RefreshDataFunction() end
    if not Hub.DataFunction then
        Hub.DataFunction = Hub.ReplicatedStorage:FindFirstChild("Events") and Hub.ReplicatedStorage:FindFirstChild("Events"):FindFirstChild("DataFunction")
    end
    return Hub.DataFunction
end

local function ParseQuantityText(text)
    if not text or text == "" then return 1 end
    local num = text:match("x(%d+)")
    if num then return tonumber(num) or 1 end
    num = text:match("(%d+)")
    if num then return tonumber(num) or 1 end
    return 1
end

local function ScanInventorySlots()
    local slots = {}
    pcall(function()
        local gui = LocalPlayer.PlayerGui
        local clientGui = gui and gui:FindFirstChild("ClientGui")
        local mainframe = clientGui and clientGui:FindFirstChild("Mainframe")
        local loadout = mainframe and mainframe:FindFirstChild("Loadout")
        if not loadout then return end
        -- Scan InvSlot1..105 in InventoryScroll
        local inv = loadout:FindFirstChild("Inventory")
        local scroll = inv and inv:FindFirstChild("InventoryScroll")
        if scroll then
            for i = 1, 105 do
                pcall(function()
                    local slot = scroll:FindFirstChild("InvSlot" .. i)
                    if not slot then return end
                    local slotText = slot:FindFirstChild("SlotText")
                    local itemName = slotText and slotText:IsA("TextLabel") and slotText.Text or ""
                    if itemName == "" then return end
                    local qty = 1
                    pcall(function()
                        local itemNum = slot:FindFirstChild("ItemNumber")
                        local numLabel = itemNum and itemNum:FindFirstChild("Number")
                        if numLabel and numLabel:IsA("TextLabel") and numLabel.Text ~= "" then qty = ParseQuantityText(numLabel.Text) end
                    end)
                    table.insert(slots, { name = itemName, quantity = qty })
                end)
            end
        end
        -- Scan Slot1..11 (equipped/quick slots)
        for j = 1, 11 do
            pcall(function()
                local slot = loadout:FindFirstChild("Slot" .. j)
                if not slot then return end
                local slotText = slot:FindFirstChild("SlotText")
                local itemName = slotText and slotText:IsA("TextLabel") and slotText.Text or ""
                if itemName == "" then return end
                local qty = 1
                pcall(function()
                    local itemNum = slot:FindFirstChild("ItemNumber")
                    local numLabel = itemNum and itemNum:FindFirstChild("Number")
                    if numLabel and numLabel:IsA("TextLabel") and numLabel.Text ~= "" then qty = ParseQuantityText(numLabel.Text) end
                end)
                table.insert(slots, { name = itemName, quantity = qty })
            end)
        end
    end)
    return slots
end

local function CalculateGemBulkValue()
    local total = 0
    local slots = ScanInventorySlots()
    for _, slot in ipairs(slots) do
        if slot.name:find("Gem") then total = total + (10 * slot.quantity) end
    end
    return total
end

local function CalculateTrinketBulkValue()
    local total = 0
    local slots = ScanInventorySlots()
    for _, slot in ipairs(slots) do
        local val = TRINKET_VALUES[slot.name]
        if val then total = total + (val * slot.quantity) end
    end
    return total
end

Hub.ScanInventorySlots = ScanInventorySlots
Hub.CalculateGemBulkValue = CalculateGemBulkValue
Hub.CalculateTrinketBulkValue = CalculateTrinketBulkValue

local function BulkSellTrinkets()
    local ok, err = pcall(function()
        local df = GetDataFunction()
        if not df then error("DataFunction not found") end
        local total = CalculateTrinketBulkValue()
        if total <= 0 then Notify("No sellable trinkets found in inventory", 2); return end
        df:InvokeServer("SellingBulk", total, "Trinket")
    end)
    if ok then Notify("Bulk sold Trinkets!", 2) else Notify("Sell failed: " .. tostring(err), 3) end
end

local function BulkSellGems()
    local ok, err = pcall(function()
        local df = GetDataFunction()
        if not df then error("DataFunction not found") end
        local total = CalculateGemBulkValue()
        if total <= 0 then Notify("No gems found in inventory", 2); return end
        df:InvokeServer("SellingBulk", total, "Gem")
    end)
    if ok then Notify("Bulk sold Gems (value: " .. tostring(CalculateGemBulkValue()) .. ")", 2) else Notify("Sell failed: " .. tostring(err), 3) end
end

local function BulkSellFruits()
    local ok, err = pcall(function()
        local df = GetDataFunction()
        if not df then error("DataFunction not found") end
        local fishTarget = nil
        pcall(function() fishTarget = workspace:GetChildren()[68] and workspace:GetChildren()[68]:FindFirstChild("HumanoidRootPart") end)
        df:InvokeServer("SellingBulk", 0, "Fruit", "Fish", fishTarget)
    end)
    if ok then Notify("Bulk sold all Fruits!", 2) else Notify("Sell failed: " .. tostring(err), 3) end
end

Hub.BulkSellTrinkets = BulkSellTrinkets
Hub.BulkSellGems = BulkSellGems
Hub.BulkSellFruits = BulkSellFruits

-- ================================================================
-- PLAYER SAFETY / CONTESTED BOSS HELPERS
-- ================================================================
local SAFE_PLAYER_RADIUS = 300
local SAFE_VERTICAL_TOLERANCE = 120
local SECRET_SPOT = Vector3.new(-4458.5, 660.7, -4895.2)

local function GetCharacterRoot(character)
    if not character then return nil end
    return character:FindFirstChild("HumanoidRootPart")
        or character:FindFirstChild("UpperTorso")
        or character:FindFirstChild("Torso")
        or character:FindFirstChild("Head")
end

local function IsCharacterAlive(character)
    if not character or not character.Parent then
        return false
    end

    local hum = character:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then
        return false
    end

    local root = GetCharacterRoot(character)
    if not root then
        return false
    end

    return true, hum, root
end

local function IsPlayerValidForSafetyScan(player)
    if not player or player == LocalPlayer then
        return false
    end

    local char = player.Character
    local alive, hum, root = IsCharacterAlive(char)
    if not alive then
        return false
    end

    if math.abs(root.Position.X) > 1e6 or math.abs(root.Position.Y) > 1e6 or math.abs(root.Position.Z) > 1e6 then
        return false
    end

    return true, char, hum, root
end

local function GetBossRootSafe(model)
    if not model or not model.Parent then
        return nil
    end

    return model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChild("UpperTorso")
        or model:FindFirstChild("Torso")
        or model:FindFirstChild("Head")
        or model:FindFirstChildWhichIsA("BasePart")
end

local function GetPlayersNearPosition(position, radius, verticalTolerance)
    local nearby = {}
    radius = radius or SAFE_PLAYER_RADIUS
    verticalTolerance = verticalTolerance or SAFE_VERTICAL_TOLERANCE

    for _, player in ipairs(Players:GetPlayers()) do
        local valid, _, _, root = IsPlayerValidForSafetyScan(player)
        if valid and root then
            local horizontal = Vector3.new(root.Position.X, 0, root.Position.Z)
            local center = Vector3.new(position.X, 0, position.Z)
            local horizontalDist = (horizontal - center).Magnitude
            local verticalDist = math.abs(root.Position.Y - position.Y)

            if horizontalDist <= radius and verticalDist <= verticalTolerance then
                table.insert(nearby, {
                    Player = player,
                    Root = root,
                    HorizontalDistance = horizontalDist,
                    VerticalDistance = verticalDist,
                    Distance = (root.Position - position).Magnitude,
                })
            end
        end
    end

    table.sort(nearby, function(a, b)
        return a.Distance < b.Distance
    end)

    return nearby
end

local function IsBossContested(model, radius)
    local bossRoot = GetBossRootSafe(model)
    if not bossRoot then
        return false, {}
    end

    local nearby = GetPlayersNearPosition(bossRoot.Position, radius or SAFE_PLAYER_RADIUS, SAFE_VERTICAL_TOLERANCE)
    return #nearby > 0, nearby
end

local function ArePlayersNearMe(radius)
    local char = LocalPlayer.Character
    local alive, _, root = IsCharacterAlive(char)
    if not alive or not root then
        return false, {}
    end

    local nearby = GetPlayersNearPosition(root.Position, radius or SAFE_PLAYER_RADIUS, SAFE_VERTICAL_TOLERANCE)
    return #nearby > 0, nearby
end

local function IsActivelyAutoFarming()
    if Hub.AdvancedBossLoopFarm and Hub.AdvancedBossLoopFarm.Enabled then
        return true
    end

    if Hub.BossFarm and Hub.BossFarm.Enabled and Hub.BossFarm.Target and Hub.BossFarm.Target.Parent and Hub.BossFarm.Target.Health > 0 then
        return true
    end

    if Hub.MissionSystem and Hub.MissionSystem.AutoEnabled and Hub.MissionSystem.ActiveMission then
        return true
    end

    return false
end

Hub.IsActivelyAutoFarming = IsActivelyAutoFarming

local PlayerFarmSafety = {
    Enabled = true,
    Hiding = false,
    SavedStates = nil,
    LastNotify = 0,
    LastDangerAt = 0,
    ResumeDelay = 3,
    Thread = nil,
}

local function PauseUnsafeFarms()
    local saved = {}

    if Hub.BossFarm and Hub.BossFarm.Enabled then
        saved.BossFarm = true
        pcall(function()
            Hub.StopBossFarm()
        end)
    end

    if Hub.MissionSystem and Hub.MissionSystem.AutoEnabled then
        saved.AutoMission = true
        pcall(function()
            Hub.StopAutoMission()
        end)
    end

    return saved
end

local function ResumeUnsafeFarms(saved)
    saved = saved or {}

    if saved.BossFarm and Hub.BossFarm and Hub.BossFarm.SelectedBoss and Hub.BossFarm.SelectedBoss ~= "" then
        pcall(function()
            Hub.BossFarm.Enabled = true
            Hub.StartBossFarm()
        end)
    end

    if saved.AutoMission and Hub.MissionSystem then
        pcall(function()
            Hub.StartAutoMission()
        end)
    end
end

Hub.PauseFarms = PauseUnsafeFarms
Hub.ResumeFarms = ResumeUnsafeFarms

local function HandleNearbyPlayerDanger()
    if not PlayerFarmSafety.Enabled then
        return
    end

    if not (Hub.IsActivelyAutoFarming and Hub.IsActivelyAutoFarming()) then
        if PlayerFarmSafety.Hiding and tick() - PlayerFarmSafety.LastDangerAt >= PlayerFarmSafety.ResumeDelay then
            PlayerFarmSafety.Hiding = false
            ResumeUnsafeFarms(PlayerFarmSafety.SavedStates)
            PlayerFarmSafety.SavedStates = nil
        end
        return
    end

    local danger, nearby = ArePlayersNearMe(SAFE_PLAYER_RADIUS)

    if danger then
        PlayerFarmSafety.LastDangerAt = tick()

        if not PlayerFarmSafety.Hiding then
            PlayerFarmSafety.Hiding = true
            PlayerFarmSafety.SavedStates = PauseUnsafeFarms()

            pcall(function()
                TeleportTo(SECRET_SPOT)
            end)

            if tick() - PlayerFarmSafety.LastNotify > 2 then
                PlayerFarmSafety.LastNotify = tick()
                Notify("Players are nearby...", 3)
            end
        end

        return
    end

    if PlayerFarmSafety.Hiding and tick() - PlayerFarmSafety.LastDangerAt >= PlayerFarmSafety.ResumeDelay then
        PlayerFarmSafety.Hiding = false
        ResumeUnsafeFarms(PlayerFarmSafety.SavedStates)
        PlayerFarmSafety.SavedStates = nil
    end
end

local function StartPlayerFarmSafety()
    if PlayerFarmSafety.Thread then pcall(task.cancel, PlayerFarmSafety.Thread) end
    PlayerFarmSafety.Thread = task.spawn(function()
        while true do
            if IsActivelyAutoFarming() then
                HandleNearbyPlayerDanger()
            elseif PlayerFarmSafety.Hiding then
                PlayerFarmSafety.Hiding = false
                if PlayerFarmSafety.SavedPosition then
                    TeleportTo(PlayerFarmSafety.SavedPosition)
                    PlayerFarmSafety.SavedPosition = nil
                end
                ResumeUnsafeFarms(PlayerFarmSafety.SavedStates or {})
                PlayerFarmSafety.SavedStates = {}
            end
            task.wait(0.5)
        end
    end)
end

Hub.PlayerFarmSafety = PlayerFarmSafety
Hub.StartPlayerFarmSafety = StartPlayerFarmSafety

-- ================================================================
-- BOSS FARM
local function PlayerSafetyCheck()
    local char = LocalPlayer.Character; if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid"); if not hum or hum.Health <= 0 then return false end
    return true
end
Hub.PlayerSafetyCheck = PlayerSafetyCheck
local function AutoUseSkill(skillName)
    local remote = ReplicatedStorage:FindFirstChild("UseSkill")
    if not remote then Notify("No skill remote found!", 2); return end
    pcall(function() remote:FireServer(skillName) end)
    Notify("Auto-used skill: " .. tostring(skillName), 2)
end
Hub.AutoUseSkill = AutoUseSkill
local function BuyRamen()
    local ramenShop = workspace:FindFirstChild("RamenShop")
    if not ramenShop then Notify("No ramen shop found!", 2); return end
    local remote = ReplicatedStorage:FindFirstChild("BuyRamen")
    if not remote then Notify("No ramen remote found!", 2); return end
    pcall(function() remote:FireServer() end)
    Notify("Bought ramen!", 2)
end
Hub.BuyRamen = BuyRamen
-- ================================================================
local trinketNames = {
    "Gold Bracelet", "Gold Ring", "Silver Ring", "Silver Bracelet", "Silver Necklace", "Gold Necklace",
    "Gold Enclosed Ring", "Silver Enclosed Ring", "Ring Schematics", "Ring Of The Neoncat",
    "Ring Of Resistance", "Ring Of Nourishment", "Ring Of Favor", "Ring Of Remedy", "Ring Of Vitality",
    "Ring Of Infusion", "Bloodbite Ring", "Ring Of Beauty", "Ring Of Dexterity", "Ring Of A Helping Hand",
    "Aqua Gem", "Flame Gem", "Spark Gem", "Black Flame Gem", "Ground Gem", "Ice Gem", "Wind Gem",
    "Poison Gem", "Extraction Spoon", "Scalpel", "Chakra Heart", "Fruit Of Forgetfulness",
    "Progression Soul", "Memory Soul", "Summoning Scroll", "Life Up Fruit", "Mastery Scroll",
    "Trait Scroll", "Kusanagi Schematics", "Raijin Schematics", "Staff Schematics",
    "Samehada Schematics", "Gunbai Schematics",
}
local TrinketSet = {}; for _, n in ipairs(trinketNames) do TrinketSet[n] = true end

local KNOWN_WEAPONS = {
    "Onyx Resanagi", "Golden Resanagi", "Silver Resanagi",
    "Onyx Zabunagi", "Golden Zabunagi", "Silver Zabunagi",
    "Onyx Asumai",
}
local KNOWN_WEAPON_SET = {}; for _, w in ipairs(KNOWN_WEAPONS) do KNOWN_WEAPON_SET[w] = true end

local WEAPON_HEIGHT_BOOSTS = {
    ["Onyx Asumai"] = -3,
    ["Fist"] = -2,
}
local AdvancedBossLoopFarm = {
    Enabled = false,
    Thread = nil,
    SelectedBosses = {
        ["Wooden Golem"] = false,
        ["Hyuga Boss"] = false,
        ["Lava Snake"] = false,
        ["Haku Boss"] = false,
        ["Barbarit The Rose"] = false,
        ["Manda"] = false,
        ["Tairock"] = false,
        ["The Barbarian"] = false,
        ["The Ringed Samurai"] = false,
    },
    HopAfterLoop = false,
    HopOnChakraSenseUsers = false,
    PersistPath = "JitlerHub/AdvancedBossLoop.json",
    ResumePending = false,
}

Hub.AdvancedBossLoopFarm = AdvancedBossLoopFarm

local function SaveAdvancedBossLoopState()
    if not writefile or not isfolder or not makefolder then return end
    pcall(function()
        if not isfolder("JitlerHub") then makefolder("JitlerHub") end
        writefile(AdvancedBossLoopFarm.PersistPath, Hub.HttpService:JSONEncode({
            Enabled = AdvancedBossLoopFarm.Enabled,
        }))
    end)
end

local function LoadAdvancedBossLoopState()
    if not readfile or not isfile then return end
    pcall(function()
        if isfile(AdvancedBossLoopFarm.PersistPath) then
            local raw = readfile(AdvancedBossLoopFarm.PersistPath)
            local decoded = Hub.HttpService:JSONDecode(raw)
            if type(decoded) == "table" then
                AdvancedBossLoopFarm.Enabled = decoded.Enabled == true
            end
        end
    end)
end

local function RunLoadedInSequence()
    -- Avoid remote invocation; simply press the in-game "Continue" button if it exists.
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    local continueBtn = playerGui and playerGui:FindFirstChild("ClientGui")
        and playerGui.ClientGui:FindFirstChild("MenuScreen")
        and playerGui.ClientGui.MenuScreen:FindFirstChild("Menu")
        and playerGui.ClientGui.MenuScreen.Menu:FindFirstChild("Continue")

    if continueBtn and continueBtn:IsA("GuiButton") then
        pcall(function()
            continueBtn:Activate()
        end)
        return true
    end

    -- Fallback to previous method if the button isn't present
    if Hub.RefreshDataFunction then Hub.RefreshDataFunction() end
    if not Hub.DataFunction then return false end

    pcall(function()
        local args = { [1] = "AmIModerator" }
        Hub.DataFunction:InvokeServer(unpack(args))
    end)

    task.wait(1)

    pcall(function()
        local args = { [1] = "LoadedIn" }
        Hub.DataFunction:InvokeServer(unpack(args))
    end)

    return true
end

Hub.RunLoadedInSequence = RunLoadedInSequence

local function GetSelectedBossLoopList()
    local list = {}
    for bossName, enabled in pairs(AdvancedBossLoopFarm.SelectedBosses) do
        if enabled then
            table.insert(list, bossName)
        end
    end
    table.sort(list, function(a, b) return a < b end)
    return list
end

local function TriggerBossSpawnIfNeeded(bossName)
    if bossName == "Lava Snake" then
        TeleportTo(Vector3.new(-547.6, -541.7, -1281.8))
        task.wait(2)
        return
    end

    if bossName == "The Ringed Samurai" then
        TeleportTo(Vector3.new(1418.9, -474.4, -595.8))
        task.wait(2)
        return
    end
end

local FindBoss -- forward-declared to avoid nil call when used early

local function WaitForBossSpawnOrSkip(bossName, timeout)
    timeout = timeout or 16
    TriggerBossSpawnIfNeeded(bossName)

    local start = tick()
    repeat
        local hum, model = FindBoss(bossName)
        if hum and model then
            return hum, model
        end
        task.wait(1)
    until tick() - start >= timeout

    return nil, nil
end

local function StopAdvancedBossLoop()
    AdvancedBossLoopFarm.Enabled = false
    SaveAdvancedBossLoopState()
    if AdvancedBossLoopFarm.Thread then pcall(task.cancel, AdvancedBossLoopFarm.Thread); AdvancedBossLoopFarm.Thread = nil end
end

local function StartAdvancedBossLoop()
    if AdvancedBossLoopFarm.Thread then pcall(task.cancel, AdvancedBossLoopFarm.Thread) end
    AdvancedBossLoopFarm.Enabled = true
    SaveAdvancedBossLoopState()

    AdvancedBossLoopFarm.Thread = task.spawn(function()
        if Hub.RunLoadedInSequence then pcall(Hub.RunLoadedInSequence) end
        task.wait(1.5)

        while AdvancedBossLoopFarm.Enabled do
            local loopList = GetSelectedBossLoopList()
            if #loopList == 0 then
                Notify("No bosses selected for Advanced Auto Farm.", 3)
                StopAdvancedBossLoop()
                break
            end

            for _, bossName in ipairs(loopList) do
                if not AdvancedBossLoopFarm.Enabled then break end

                local chakraCount = Hub.GetActiveChakraCount and Hub.GetActiveChakraCount() or 0
                if AdvancedBossLoopFarm.HopOnChakraSenseUsers and chakraCount > 0 then
                    Notify("Chakra Sense users present. Hopping...", 3)
                    if Hub.DoServerHop then
                        Hub.DoServerHop()
                    else
                        Notify("Server hop helper missing.", 3)
                    end
                    return
                end

                local hum, model = WaitForBossSpawnOrSkip(bossName, 16)
                if not hum or not model then
                    Notify(bossName .. " unavailable, skipping...", 2)
                    continue
                end

                local contested = IsBossContested(model, 300)
                if contested then
                    Notify("Players are nearby...", 3)
                    continue
                end

                BossFarm.SelectedBoss = bossName
                BossFarm.Enabled = true
                StartBossFarm()

                while AdvancedBossLoopFarm.Enabled and BossFarm.Enabled and BossFarm.Target and BossFarm.Target.Parent and BossFarm.Target.Health > 0 do
                    local chakraCountInner = Hub.GetActiveChakraCount and Hub.GetActiveChakraCount() or 0
                    if AdvancedBossLoopFarm.HopOnChakraSenseUsers and chakraCountInner > 0 then
                        StopBossFarm()
                        Notify("Chakra Sense users present. Hopping...", 3)
                        if Hub.DoServerHop then
                            Hub.DoServerHop()
                        else
                            Notify("Server hop helper missing.", 3)
                        end
                        return
                    end
                    task.wait(0.5)
                end

                task.wait(1)
            end

            if AdvancedBossLoopFarm.Enabled and AdvancedBossLoopFarm.HopAfterLoop then
                Notify("Boss loop complete. Hopping...", 3)
                if Hub.DoServerHop then
                    Hub.DoServerHop()
                else
                    Notify("Server hop helper missing.", 3)
                end
                return
            end

            task.wait(2)
        end
    end)
end

Hub.StartAdvancedBossLoop = StartAdvancedBossLoop
Hub.StopAdvancedBossLoop = StopAdvancedBossLoop
Hub.AdvancedBossLoop = StartAdvancedBossLoop

LoadAdvancedBossLoopState()

task.spawn(function()
    task.wait(6)
    if AdvancedBossLoopFarm.Enabled then
        StartAdvancedBossLoop()
    end
end)

local function ScanHotbarForWeapon()
    local found = nil
    pcall(function()
        local gui = LocalPlayer.PlayerGui
        local clientGui = gui and gui:FindFirstChild("ClientGui")
        local mainframe = clientGui and clientGui:FindFirstChild("Mainframe")
        local loadout = mainframe and mainframe:FindFirstChild("Loadout")
        if not loadout then return end
        for j = 1, 11 do
            local slot = loadout:FindFirstChild("Slot" .. j)
            if not slot then continue end
            local slotText = slot:FindFirstChild("SlotText")
            local itemName = slotText and slotText:IsA("TextLabel") and slotText.Text or ""
            if itemName ~= "" and KNOWN_WEAPON_SET[itemName] then
                found = itemName; return
            end
        end
    end)
    return found or "Fist"
end

Hub.ScanHotbarForWeapon = ScanHotbarForWeapon
Hub.WEAPON_HEIGHT_BOOSTS = WEAPON_HEIGHT_BOOSTS

local BossFarm = {
    Enabled = false, Target = nil, TargetName = "", SelectedBoss = "Wooden Golem",
    WeaponName = "Onyx Resanagi", HeightOffset = 50, AttackDelay = 0.12, WeaponHeightBoost = 0,
    Thread = nil, AnchorConn = nil,
    HyugaHeightBoost = 0, HyugaAnimConnection = nil, HyugaInVoid = false, HyugaVoidConn = nil,
    LavaSnakeHeightBoost = 0, LavaSnakeAnimConnection = nil,
    MandaHeightBoost = 0, MandaAnimConnection = nil,
    RingedSamuraiHeightBoost = 0, RingedSamuraiAnimConnection = nil,
    HakuAnimConnection = nil, HakuSafeSpot = false, HakuSafeSpotEndTime = 0, AutoLootOnKill = false,
    KnockedThread = nil,
}

local BossConfigs = {
    ["Wooden Golem"] = { height = 16 },
    ["Hyuga Boss"] = { height = 10.75 },
    ["Lava Snake"] = { height = 38, triggerSpawn = true },
    ["Haku Boss"] = { height = 10.75 },
    ["Barbarit The Rose"] = { height = 14 },
    ["Manda"] = { height = 38, triggerSpawn = true },
    ["Tairock"] = { height = 10.75, triggerSpawn = true },
    ["The Barbarian"] = { height = 14 },
    ["The Ringed Samurai"] = {
        height = 14,
        triggerSpawn = true,
        triggerPos = Vector3.new(1418.9, -474.4, -595.8),
    },
}
local BossLootSpots = {
    ["Hyuga Boss"] = Vector3.new(-663.8, -359.9, -728.9), ["Wooden Golem"] = Vector3.new(-4716.2, 344.1, -2932.0),
    ["Haku Boss"] = Vector3.new(-3788.1, -238.5, -9723.9), ["Lava Snake"] = Vector3.new(-546.7, -546.9, -1461.6),
    ["Barbarit The Rose"] = Vector3.zero, ["Manda"] = Vector3.zero, ["Tairock"] = Vector3.zero,
}

local HYUGA_VOID_SAFE_SPOT = Vector3.new(-700.8, -334.3, -780.8)
local function IsInHyugaVoidZone(pos) return pos.X >= -826.4 and pos.X <= -524.0 and pos.Y >= -454.8 and pos.Y <= -450.8 and pos.Z >= -927.1 and pos.Z <= -621.1 end

local function GetBossRoot(model) return model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head") or model:FindFirstChild("Torso") or model:FindFirstChildWhichIsA("BasePart") end

FindBoss = function(bossName)
    for _, folder in ipairs({ "NPCs", "Mobs", "Enemies", workspace }) do
        local sf = folder == workspace and folder or workspace:FindFirstChild(folder); if not sf then continue end
        for _, model in ipairs(sf:GetChildren()) do if model:IsA("Model") and model.Name == bossName then local hum = model:FindFirstChildOfClass("Humanoid"); if hum and hum.Health > 0 then return hum, model end end end
    end
    return nil, nil
end

local function CollectBossLoot(bossName)
    local lootSpot = BossLootSpots[bossName]; if not lootSpot then return end
    local char = LocalPlayer.Character; if not char then return end; local root = char:FindFirstChild("HumanoidRootPart"); if not root then return end
    root.CFrame = CFrame.new(lootSpot); task.wait(5)
    char = LocalPlayer.Character; if not char then return end; root = char:FindFirstChild("HumanoidRootPart"); if not root then return end; root.CFrame = CFrame.new(lootSpot)
    Hub.RefreshDataEvent()
    local items = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if (obj:IsA("Model") or obj:IsA("BasePart")) and TrinketSet[obj.Name] then
            local pos = obj:IsA("BasePart") and obj.Position or (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")) and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")).Position
            if pos and (lootSpot - pos).Magnitude <= 200 then
                local idVal = obj:FindFirstChild("ID"); if not idVal then for _, d in ipairs(obj:GetDescendants()) do if d.Name == "ID" and d:IsA("NumberValue") then idVal = d; break end end end
                if idVal then table.insert(items, { obj = obj, pos = pos, id = idVal.Value, dist = (lootSpot - pos).Magnitude }) end
            end
        end
    end
    table.sort(items, function(a, b) return a.dist < b.dist end)
    for _, entry in ipairs(items) do
        if not entry.obj.Parent then continue end; char = LocalPlayer.Character; if not char then break end; root = char:FindFirstChild("HumanoidRootPart"); if not root then break end
        root.CFrame = CFrame.new(entry.pos + Vector3.new(0, 3, 0)); task.wait(0.3)
        if Hub.DataEvent then local e = tick() + 1.5; while tick() < e do if not entry.obj.Parent then break end; pcall(function() Hub.DataEvent:FireServer("PickUp", entry.id) end); task.wait(0.05) end end; task.wait(0.2)
    end; Notify("Boss loot collection complete!", 2)
end

local function MonitorHyugaVoid(bossModel)
    if BossFarm.HyugaVoidConn then task.cancel(BossFarm.HyugaVoidConn); BossFarm.HyugaVoidConn = nil end; BossFarm.HyugaInVoid = false
    if not bossModel then return end; local bossRoot = bossModel:FindFirstChild("HumanoidRootPart"); if not bossRoot then return end
    BossFarm.HyugaVoidConn = task.spawn(function() while BossFarm.Enabled do local inVoid = IsInHyugaVoidZone(bossRoot.Position); if inVoid and not BossFarm.HyugaInVoid then BossFarm.HyugaInVoid = true elseif not inVoid and BossFarm.HyugaInVoid then BossFarm.HyugaInVoid = false end; task.wait(0.5) end; BossFarm.HyugaInVoid = false end)
end

local function MonitorHyugaBossAnimations(bossModel)
    if BossFarm.HyugaAnimConnection then BossFarm.HyugaAnimConnection:Disconnect(); BossFarm.HyugaAnimConnection = nil end
    if not bossModel then return end; local hum = bossModel:FindFirstChildOfClass("Humanoid"); if not hum then return end; local animator = hum:FindFirstChildOfClass("Animator"); if not animator then return end
    local dangerAnims = { ["8699113073"] = true, ["8580099842"] = true }
    BossFarm.HyugaAnimConnection = animator.AnimationPlayed:Connect(function(track) if not BossFarm.Enabled then return end; local assetId = track.Animation.AnimationId:match("rbxassetid://(%d+)") or track.Animation.AnimationId; if dangerAnims[assetId] then BossFarm.HyugaHeightBoost = 20; task.spawn(function() while track and track.IsPlaying and BossFarm.Enabled do task.wait(0.1) end; task.wait(0.5); BossFarm.HyugaHeightBoost = 0 end) end end)
end

local function MonitorLavaSnakeAnimations(bossModel)
    if BossFarm.LavaSnakeAnimConnection then BossFarm.LavaSnakeAnimConnection:Disconnect(); BossFarm.LavaSnakeAnimConnection = nil end
    if not bossModel then return end; local hum = bossModel:FindFirstChildOfClass("Humanoid"); if not hum then return end; local animator = hum:FindFirstChildOfClass("Animator"); if not animator then return end
    BossFarm.LavaSnakeAnimConnection = animator.AnimationPlayed:Connect(function(track) if not BossFarm.Enabled then return end; local assetId = track.Animation.AnimationId:match("rbxassetid://(%d+)") or track.Animation.AnimationId; if assetId == "9954909571" then BossFarm.LavaSnakeHeightBoost = 10; task.spawn(function() while track and track.IsPlaying and BossFarm.Enabled do task.wait(0.1) end; task.wait(0.5); BossFarm.LavaSnakeHeightBoost = 0 end) end end)
end

local function MonitorMandaAnimations(bossModel)
    if BossFarm.MandaAnimConnection then BossFarm.MandaAnimConnection:Disconnect(); BossFarm.MandaAnimConnection = nil end
    if not bossModel then return end; local hum = bossModel:FindFirstChildOfClass("Humanoid"); if not hum then return end; local animator = hum:FindFirstChildOfClass("Animator"); if not animator then return end
    BossFarm.MandaAnimConnection = animator.AnimationPlayed:Connect(function(track) if not BossFarm.Enabled then return end; local assetId = track.Animation.AnimationId:match("rbxassetid://(%d+)") or track.Animation.AnimationId; if assetId == "9954909571" then BossFarm.MandaHeightBoost = 15; task.spawn(function() while track and track.IsPlaying and BossFarm.Enabled do task.wait(0.1) end; task.wait(0.5); BossFarm.MandaHeightBoost = 0 end) end end)
end

local function MonitorRingedSamuraiAnimations(model)
    if BossFarm.RingedSamuraiAnimConnection then
        BossFarm.RingedSamuraiAnimConnection:Disconnect()
        BossFarm.RingedSamuraiAnimConnection = nil
    end

    local hum = model and model:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then return end

    BossFarm.RingedSamuraiAnimConnection = animator.AnimationPlayed:Connect(function(track)
        if not BossFarm.Enabled then return end
        local anim = track and track.Animation
        local assetId = anim and (anim.AnimationId:match("rbxassetid://(%d+)") or anim.AnimationId)
        if assetId == "137738911755203" then
            BossFarm.RingedSamuraiHeightBoost = -100
            task.spawn(function()
                while track and track.IsPlaying and BossFarm.Enabled do
                    task.wait(0.1)
                end
                task.wait(0.35)
                BossFarm.RingedSamuraiHeightBoost = 0
            end)
        end
    end)
end

local function MonitorHakuBossIceDragon()
    if BossFarm.HakuAnimConnection then BossFarm.HakuAnimConnection:Disconnect(); BossFarm.HakuAnimConnection = nil end
    local debris = workspace:FindFirstChild("Debris"); if not debris then local conn; conn = workspace.ChildAdded:Connect(function(c) if c.Name == "Debris" then conn:Disconnect(); MonitorHakuBossIceDragon() end end); return end
    BossFarm.HakuAnimConnection = debris.ChildAdded:Connect(function(child) if not BossFarm.Enabled then return end; local dur = child.Name == "IceDragonHead" and 4 or (child:IsA("Beam") and child.Name == "Beam121") and 1 or nil; if dur then local char = LocalPlayer.Character; if char and char:FindFirstChild("HumanoidRootPart") then char.HumanoidRootPart.CFrame = CFrame.new(-2969.2, 1832.9, -9610.4); BossFarm.HakuSafeSpot = true; BossFarm.HakuSafeSpotEndTime = tick() + dur end end end)
end

local function WaitForBeingGripped(model, timeout)
    timeout = timeout or 6
    local start = tick()

    while tick() - start <= timeout do
        local bg = model and model.Parent and model:FindFirstChild("BeingGripped", true)
        local gripped = false
        pcall(function()
            if bg and (bg.Value == true or bg.Value == "ON" or bg.Value == 1) then
                gripped = true
            end
        end)
        if gripped then
            return true
        end
        task.wait(0.15)
    end

    return false
end

local function RetryGripUntilBeingGripped(model, maxAttempts)
    maxAttempts = maxAttempts or 12
    local bossRoot = GetBossRoot(model)
    if not bossRoot then return false end

    for _ = 1, maxAttempts do
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            root.CFrame = CFrame.new(bossRoot.Position)
        end

        task.wait(0.08)

        if Hub.DataEvent then
            pcall(function() Hub.DataEvent:FireServer("Grip") end)
        end

        if WaitForBeingGripped(model, 0.6) then
            return true
        end
    end

    return false
end

Hub.RetryGripUntilBeingGripped = RetryGripUntilBeingGripped

local function MonitorBossKnocked(model)
    if BossFarm.KnockedThread then pcall(task.cancel, BossFarm.KnockedThread); BossFarm.KnockedThread = nil end
    if not model then return end
    local settings = model:FindFirstChild("Settings"); if not settings then return end
    local knocked = settings:FindFirstChild("Knocked"); if not knocked then return end
    BossFarm.KnockedThread = task.spawn(function()
        while BossFarm.Enabled and model and model.Parent do
            local isKnocked = false
            pcall(function()
                if knocked.Value == true or (type(knocked.Value) == "string" and knocked.Value:upper() == "ON") or (type(knocked.Value) == "number" and knocked.Value ~= 0) then
                    isKnocked = true
                end
            end)
            if isKnocked then
                Notify("Mob knocked! Gripping...", 2)
                if BossFarm.AnchorConn then BossFarm.AnchorConn:Disconnect(); BossFarm.AnchorConn = nil end
                if BossFarm.Thread then pcall(task.cancel, BossFarm.Thread); BossFarm.Thread = nil end
                StopCharging()

                local success = RetryGripUntilBeingGripped(model, 12)
                if success then
                    Notify("Grip confirmed!", 2)
                else
                    Notify("Grip retry timed out.", 2)
                end

                task.wait(0.5)
                StopBossFarm()
                return
            end
            task.wait(0.2)
        end
    end)
end

local function StartBossFarm()
    if BossFarm.AnchorConn then BossFarm.AnchorConn:Disconnect() end
    if BossFarm.Thread then pcall(task.cancel, BossFarm.Thread) end

    local config = BossConfigs[BossFarm.SelectedBoss]
    if not config then
        Notify("Unknown boss config: " .. tostring(BossFarm.SelectedBoss), 3)
        BossFarm.Enabled = false
        return
    end

    if config.triggerSpawn and config.triggerPos then
        TeleportTo(config.triggerPos)
        task.wait(2)
    elseif BossFarm.SelectedBoss == "Lava Snake" then
        TeleportTo(Vector3.new(-547.6, -541.7, -1281.8))
        task.wait(2)
    end

    local hum, model
    if config.triggerSpawn then
        for attempt = 1, 10 do
            hum, model = FindBoss(BossFarm.SelectedBoss)
            if hum and model then break end
            Notify("Waiting for " .. BossFarm.SelectedBoss .. " to spawn... (" .. attempt .. "/10)", 2)
            if config.triggerPos then
                TeleportTo(config.triggerPos)
            end
            task.wait(2)
        end
    else
        hum, model = FindBoss(BossFarm.SelectedBoss)
    end

    if not hum or not model then
        Notify(BossFarm.SelectedBoss .. " not spawned!", 3)
        BossFarm.Enabled = false
        return
    end

    local contested = IsBossContested(model, 300)
    if contested then
        Notify("Players are nearby...", 3)
        BossFarm.Enabled = false
        return
    end

    BossFarm.Target = hum
    BossFarm.TargetName = model.Name
    BossFarm.HeightOffset = config.height or BossFarm.HeightOffset

    if BossFarm.TargetName == "Hyuga Boss" then
        MonitorHyugaBossAnimations(model)
        MonitorHyugaVoid(model)
        task.spawn(function()
            BossFarm.HyugaHeightBoost = -2
            task.wait(5)
            if BossFarm.HyugaHeightBoost == -2 then BossFarm.HyugaHeightBoost = 0 end
        end)
    end
    if BossFarm.TargetName == "Lava Snake" then MonitorLavaSnakeAnimations(model) end
    if BossFarm.TargetName == "Manda" then MonitorMandaAnimations(model) end
    if BossFarm.TargetName == "Haku Boss" then MonitorHakuBossIceDragon() end
    if BossFarm.TargetName == "The Ringed Samurai" then MonitorRingedSamuraiAnimations(model) end

    MonitorBossKnocked(model)

    local detectedWeapon = ScanHotbarForWeapon()
    if detectedWeapon then
        BossFarm.WeaponName = detectedWeapon
        Notify("Auto-detected weapon: " .. detectedWeapon, 2)
    end

    BossFarm.WeaponHeightBoost = WEAPON_HEIGHT_BOOSTS[BossFarm.WeaponName] or 0
    if Hub.DataEvent and BossFarm.WeaponName ~= "" then
        pcall(function() Hub.DataEvent:FireServer("Item", "Selected", BossFarm.WeaponName) end)
    end

    task.wait(0.5)
    StartCharging()
    Notify("Farming: " .. BossFarm.TargetName, 3)

    BossFarm.AnchorConn = RunService.Heartbeat:Connect(function()
        pcall(function()
            if not BossFarm.Enabled then return end
            local h = BossFarm.Target
            if not h or not h.Parent or h.Health <= 0 then
                local deadName = BossFarm.TargetName
                BossFarm.Enabled = false
                StopCharging()
                if BossFarm.AnchorConn then BossFarm.AnchorConn:Disconnect(); BossFarm.AnchorConn = nil end
                if BossFarm.Thread then pcall(task.cancel, BossFarm.Thread); BossFarm.Thread = nil end
                if BossFarm.AutoLootOnKill then
                    task.spawn(function() pcall(CollectBossLoot, deadName) end)
                end
                return
            end

            local bossRoot = GetBossRoot(h.Parent)
            if not bossRoot then return end

            local char = LocalPlayer.Character
            if not char then return end
            local root = char:FindFirstChild("HumanoidRootPart")
            if not root then return end

            if BossFarm.HakuSafeSpot and tick() >= BossFarm.HakuSafeSpotEndTime then
                BossFarm.HakuSafeSpot = false
            end

            if BossFarm.HyugaInVoid then
                root.CFrame = CFrame.new(HYUGA_VOID_SAFE_SPOT)
            elseif BossFarm.HakuSafeSpot then
                root.CFrame = CFrame.new(-2969.2, 1832.9, -9610.4)
            else
                root.CFrame = CFrame.lookAt(
                    bossRoot.Position + Vector3.new(
                        0,
                        BossFarm.HeightOffset
                            + BossFarm.HyugaHeightBoost
                            + BossFarm.LavaSnakeHeightBoost
                            + BossFarm.MandaHeightBoost
                            + BossFarm.RingedSamuraiHeightBoost
                            + BossFarm.WeaponHeightBoost,
                        0
                    ),
                    bossRoot.Position
                )
            end
        end)
    end)

    BossFarm.Thread = task.spawn(function()
        while BossFarm.Enabled do
            if PlayerFarmSafety.Hiding then task.wait(0.2); continue end
            if not BossFarm.HyugaInVoid and BossFarm.Target and BossFarm.Target.Parent and BossFarm.Target.Health > 0 then
                if Hub.AutoBlock and Hub.AutoBlock.CurrentlyBlocking then task.wait(0.05); continue end
                local br = GetBossRoot(BossFarm.Target.Parent)
                if br then
                    if AutoUseSelectedSkills then
                        AutoUseSelectedSkills(br.Position)
                    end
                    Hub.RefreshDataEvent()
                    if Hub.DataEvent then
                        pcall(function() Hub.DataEvent:FireServer("Dash", "Sub", br.Position) end)
                        task.wait(0.05)
                        pcall(function() Hub.DataEvent:FireServer("CheckMeleeHit", nil, "NormalAttack", false) end)
                    else
                        -- Fallback: simulate a click when remote is missing
                        pcall(function()
                            local pos = Hub.UserInputService and Hub.UserInputService:GetMouseLocation()
                            if pos and Hub.VirtualInput then
                                Hub.VirtualInput:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 0)
                                Hub.VirtualInput:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 0)
                            end
                        end)
                    end
                end
            end
            task.wait(BossFarm.AttackDelay)
        end
    end)
end

local function StopBossFarm()
    StopCharging()
    BossFarm.Enabled = false; BossFarm.HyugaHeightBoost = 0; BossFarm.HyugaInVoid = false; BossFarm.HakuSafeSpot = false; BossFarm.LavaSnakeHeightBoost = 0; BossFarm.MandaHeightBoost = 0; BossFarm.WeaponHeightBoost = 0
    if BossFarm.HyugaVoidConn then task.cancel(BossFarm.HyugaVoidConn); BossFarm.HyugaVoidConn = nil end
    if BossFarm.HyugaAnimConnection then BossFarm.HyugaAnimConnection:Disconnect(); BossFarm.HyugaAnimConnection = nil end
    if BossFarm.HakuAnimConnection then BossFarm.HakuAnimConnection:Disconnect(); BossFarm.HakuAnimConnection = nil end
    if BossFarm.LavaSnakeAnimConnection then BossFarm.LavaSnakeAnimConnection:Disconnect(); BossFarm.LavaSnakeAnimConnection = nil end
    if BossFarm.MandaAnimConnection then BossFarm.MandaAnimConnection:Disconnect(); BossFarm.MandaAnimConnection = nil end
    BossFarm.RingedSamuraiHeightBoost = 0
    if BossFarm.RingedSamuraiAnimConnection then BossFarm.RingedSamuraiAnimConnection:Disconnect(); BossFarm.RingedSamuraiAnimConnection = nil end
    if BossFarm.KnockedThread then pcall(task.cancel, BossFarm.KnockedThread); BossFarm.KnockedThread = nil end
    if BossFarm.AnchorConn then BossFarm.AnchorConn:Disconnect(); BossFarm.AnchorConn = nil end
    if BossFarm.Thread then pcall(task.cancel, BossFarm.Thread); BossFarm.Thread = nil end
end

Hub.BossFarm = BossFarm
Hub.StartBossFarm = StartBossFarm
Hub.StopBossFarm = StopBossFarm

-- ================================================================
-- AUTO MODE FARM
-- ================================================================
local AutoEye = { Enabled = false, Thread = nil, TargetPos = Vector3.new(-2883.2, 652.6, -5448.9), SelectedItem = "Sharingan [Stage 1]" }
local function isOutOfForcefield(character) return character and not character:FindFirstChild("ForceField") end

local function autoEyeLoop()
    while AutoEye.Enabled do
        local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local root = char:WaitForChild("HumanoidRootPart", 5) or char:WaitForChild("Head", 5); if not root then task.wait(0.3); continue end
        -- Scan inventory to check if selected mode is actually owned
        local found = false
        local slots = ScanInventorySlots()
        for _, slot in ipairs(slots) do
            if slot.name == AutoEye.SelectedItem then found = true; break end
        end
        if not found then Notify("Mode not found in inventory: " .. AutoEye.SelectedItem, 3); task.wait(3); continue end
        if not isOutOfForcefield(char) then while char and not isOutOfForcefield(char) and AutoEye.Enabled do if root and root.Parent then root.CFrame = CFrame.new(AutoEye.TargetPos) end; task.wait(0.05) end end
        if root and root.Parent and isOutOfForcefield(char) then
            root.CFrame = CFrame.new(AutoEye.TargetPos); task.wait(0.2)
            if Hub.DataEvent then pcall(function() Hub.DataEvent:FireServer("Item", "Selected", AutoEye.SelectedItem) end) end; task.wait(0.3)
            if Hub.DataFunction then pcall(function() Hub.DataFunction:InvokeServer("Awaken", AutoEye.SelectedItem) end); task.wait(0.5) end
            if char and char:FindFirstChild("Humanoid") then char.Humanoid.Health = 0; task.wait(0.1); char:BreakJoints() end
        else task.wait(0.3) end; task.wait(0.2)
    end
end

Hub.AutoEye = AutoEye
Hub.autoEyeLoop = autoEyeLoop

-- ================================================================
-- AUTO GRIP FARM
local AutoGripFarm = { Enabled = false, Thread = nil, RetryCount = 0, MaxRetries = 3 }

local function StartAutoGripFarm()
    AutoGripFarm.Enabled = true
    if AutoGripFarm.Thread then pcall(task.cancel, AutoGripFarm.Thread) end
    AutoGripFarm.Thread = task.spawn(function()
        while AutoGripFarm.Enabled do
            -- Try grip logic
            local success = false
            for i = 1, AutoGripFarm.MaxRetries do
                -- Replace with actual grip attempt
                success = Hub.AttemptGrip and Hub.AttemptGrip()
                if success then break end
                task.wait(0.5)
            end
            task.wait(2)
        end
    end)
end

local function StopAutoGripFarm()
    AutoGripFarm.Enabled = false
    if AutoGripFarm.Thread then pcall(task.cancel, AutoGripFarm.Thread); AutoGripFarm.Thread = nil end
end

Hub.AutoGripFarm = AutoGripFarm
Hub.StartAutoGripFarm = StartAutoGripFarm
Hub.StopAutoGripFarm = StopAutoGripFarm
-- ================================================================
local AutoGripFarm = { AltEnabled = false, MainEnabled = false, AltThread = nil, MainThread = nil, TargetPos = Vector3.new(-4458.5, 660.7, -4895.2), LocationCheckRadius = 50, PlayerDetectRadius = 20, GripWaitTime = 4 }

local function autoGripAltLoop()
    while AutoGripFarm.AltEnabled do
        local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local root = char:WaitForChild("HumanoidRootPart", 5); if not root then task.wait(0.3); continue end
        if not isOutOfForcefield(char) then while char and not isOutOfForcefield(char) and AutoGripFarm.AltEnabled do if root and root.Parent then root.CFrame = CFrame.new(AutoGripFarm.TargetPos) end; task.wait(0.05) end end
        if root and root.Parent and isOutOfForcefield(char) then
            root.CFrame = CFrame.new(AutoGripFarm.TargetPos); task.wait(0.2)
            if (root.Position - AutoGripFarm.TargetPos).Magnitude <= AutoGripFarm.LocationCheckRadius and Hub.DataEvent then
                pcall(function() Hub.DataEvent:FireServer("TakeDamage", 999) end); task.wait(2)
                local h = char:FindFirstChild("Humanoid"); if h and h.Health <= 0 then task.wait(5); if char:FindFirstChild("Humanoid") then char.Humanoid.Health = 0; task.wait(0.1); char:BreakJoints() end end
            end
        end; task.wait(0.3)
    end
end

local function autoGripMainLoop()
    while AutoGripFarm.MainEnabled do
        local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local root = char:WaitForChild("HumanoidRootPart", 5); if not root then task.wait(0.3); continue end
        root.CFrame = CFrame.new(AutoGripFarm.TargetPos); task.wait(0.3)
        local target, shortest = nil, AutoGripFarm.PlayerDetectRadius
        for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer and p.Character then local tr = p.Character:FindFirstChild("HumanoidRootPart"); if tr then local d = (root.Position - tr.Position).Magnitude; if d <= shortest then shortest = d; target = p end end end end
        if target and target.Character then local tr = target.Character:FindFirstChild("HumanoidRootPart"); if tr then root.CFrame = CFrame.new(tr.Position); task.wait(0.1); if Hub.DataEvent then pcall(function() Hub.DataEvent:FireServer("Grip") end) end; task.wait(AutoGripFarm.GripWaitTime) end
        else task.wait(1) end; task.wait(0.2)
    end
end

Hub.AutoGripFarm = AutoGripFarm
Hub.autoGripAltLoop = autoGripAltLoop
Hub.autoGripMainLoop = autoGripMainLoop

-- ================================================================
-- AUTO TRINKET + TRINKET ESP
-- ================================================================
local TrinketColors = {
    ["Gold Bracelet"] = Color3.fromRGB(255, 215, 0), ["Gold Ring"] = Color3.fromRGB(255, 215, 0), ["Gold Necklace"] = Color3.fromRGB(255, 215, 0), ["Gold Enclosed Ring"] = Color3.fromRGB(255, 215, 0),
    ["Silver Ring"] = Color3.fromRGB(192, 192, 192), ["Silver Bracelet"] = Color3.fromRGB(192, 192, 192), ["Silver Necklace"] = Color3.fromRGB(192, 192, 192), ["Silver Enclosed Ring"] = Color3.fromRGB(192, 192, 192),
    ["Ring Schematics"] = Color3.fromRGB(0, 255, 255), ["Kusanagi Schematics"] = Color3.fromRGB(0, 255, 255), ["Raijin Schematics"] = Color3.fromRGB(0, 255, 255), ["Staff Schematics"] = Color3.fromRGB(0, 255, 255), ["Samehada Schematics"] = Color3.fromRGB(0, 255, 255), ["Gunbai Schematics"] = Color3.fromRGB(0, 255, 255),
    ["Ring Of The Neoncat"] = Color3.fromRGB(170, 0, 255), ["Ring Of Resistance"] = Color3.fromRGB(170, 0, 255), ["Ring Of Nourishment"] = Color3.fromRGB(170, 0, 255), ["Ring Of Favor"] = Color3.fromRGB(170, 0, 255), ["Ring Of Remedy"] = Color3.fromRGB(170, 0, 255), ["Ring Of Vitality"] = Color3.fromRGB(170, 0, 255), ["Ring Of Infusion"] = Color3.fromRGB(170, 0, 255), ["Ring Of Dexterity"] = Color3.fromRGB(170, 0, 255), ["Ring Of A Helping Hand"] = Color3.fromRGB(170, 0, 255),
    ["Bloodbite Ring"] = Color3.fromRGB(255, 50, 50), ["Ring Of Beauty"] = Color3.fromRGB(255, 105, 180),
    ["Aqua Gem"] = Color3.fromRGB(0, 150, 255), ["Flame Gem"] = Color3.fromRGB(255, 80, 0), ["Spark Gem"] = Color3.fromRGB(255, 255, 0), ["Black Flame Gem"] = Color3.fromRGB(80, 0, 80), ["Ground Gem"] = Color3.fromRGB(139, 90, 43), ["Ice Gem"] = Color3.fromRGB(135, 206, 250), ["Wind Gem"] = Color3.fromRGB(144, 238, 144), ["Poison Gem"] = Color3.fromRGB(0, 200, 0),
    ["Extraction Spoon"] = Color3.fromRGB(255, 165, 0), ["Scalpel"] = Color3.fromRGB(255, 165, 0),
    ["Chakra Heart"] = Color3.fromRGB(255, 0, 100), ["Fruit Of Forgetfulness"] = Color3.fromRGB(255, 100, 255), ["Progression Soul"] = Color3.fromRGB(0, 255, 150), ["Memory Soul"] = Color3.fromRGB(100, 200, 255), ["Summoning Scroll"] = Color3.fromRGB(255, 255, 100), ["Life Up Fruit"] = Color3.fromRGB(50, 255, 50), ["Mastery Scroll"] = Color3.fromRGB(255, 200, 50), ["Trait Scroll"] = Color3.fromRGB(255, 150, 50),
}
local DEFAULT_TRINKET_COLOR = Color3.fromRGB(255, 255, 255)
local LOOT_FOLDER_NAMES = { "Drops", "Debris", "Loot", "Items", "DroppedItems", "Effects" }

local AutoTrinket = { Enabled = false, ScanInterval = 5, ScanRadius = 200, TeleportToTrinket = true, PickupOffset = 3, Processed = {}, Queue = {}, Queued = {}, WorkerThread = nil, ScanThread = nil, FolderConns = {}, WorkspaceConn = nil }
local TrinketESP = { Enabled = false, ScanThread = nil, FolderConns = {}, WorkspaceConn = nil, TrackedObjects = {} }

local function GetTrinketId(obj) local idVal = obj:FindFirstChild("ID"); if idVal and idVal:IsA("NumberValue") then return idVal.Value end; for _, d in ipairs(obj:GetChildren()) do if d.Name == "ID" and d:IsA("NumberValue") then return d.Value end end; return nil end
local function GetTrinketPosition(obj) if obj:IsA("BasePart") then return obj.Position end; if obj:IsA("Model") then if obj.PrimaryPart then return obj.PrimaryPart.Position end; local c = obj:FindFirstChildWhichIsA("BasePart"); if c then return c.Position end; local ok, p = pcall(function() return obj:GetPivot().Position end); if ok then return p end end; return nil end

local function EnqueueTrinket(obj)
    if not AutoTrinket.Enabled or not obj or not obj.Parent then return end
    if not (obj:IsA("Model") or obj:IsA("BasePart")) or not TrinketSet[obj.Name] then return end
    local id = GetTrinketId(obj); if not id or AutoTrinket.Processed[id] or AutoTrinket.Queued[id] then return end
    AutoTrinket.Queued[id] = true; table.insert(AutoTrinket.Queue, { obj = obj, id = id })
end

local function TrinketWorker()
    while AutoTrinket.Enabled do
        if #AutoTrinket.Queue == 0 then task.wait(0.2); continue end
        local entry = table.remove(AutoTrinket.Queue, 1)
        pcall(function()
            local obj, id = entry.obj, entry.id
            if not obj or not obj.Parent or AutoTrinket.Processed[id] then AutoTrinket.Queued[id] = nil; return end
            local pos = GetTrinketPosition(obj); if not pos then AutoTrinket.Queued[id] = nil; return end
            local char = LocalPlayer.Character; if not char then table.insert(AutoTrinket.Queue, entry); task.wait(0.5); return end
            local root = char:FindFirstChild("HumanoidRootPart"); if not root then table.insert(AutoTrinket.Queue, entry); task.wait(0.5); return end
            if not AutoTrinket.TeleportToTrinket and (root.Position - pos).Magnitude > AutoTrinket.ScanRadius then AutoTrinket.Queued[id] = nil; return end
            if AutoTrinket.TeleportToTrinket then root.CFrame = CFrame.new(pos + Vector3.new(0, AutoTrinket.PickupOffset, 0)); task.wait(0.15) end
            if obj.Parent and Hub.DataEvent then
                local spamEnd = tick() + 0.8; while tick() < spamEnd do if not obj.Parent then break end; pcall(function() Hub.DataEvent:FireServer("PickUp", id) end); task.wait(0.05) end
                AutoTrinket.Processed[id] = true; Notify("Picked up: " .. obj.Name, 1)
            end; AutoTrinket.Queued[id] = nil
        end); task.wait(0.3)
    end
end

local function ScanTrinketFolders()
    if not AutoTrinket.Enabled then return end
    for _, obj in ipairs(workspace:GetChildren()) do if TrinketSet[obj.Name] then EnqueueTrinket(obj) end end
    for _, fn in ipairs(LOOT_FOLDER_NAMES) do local f = workspace:FindFirstChild(fn); if f then for _, obj in ipairs(f:GetChildren()) do if TrinketSet[obj.Name] then EnqueueTrinket(obj) end end end end
end

local function SetupTrinketListeners()
    for _, c in ipairs(AutoTrinket.FolderConns) do c:Disconnect() end; AutoTrinket.FolderConns = {}
    if AutoTrinket.WorkspaceConn then AutoTrinket.WorkspaceConn:Disconnect(); AutoTrinket.WorkspaceConn = nil end
    AutoTrinket.WorkspaceConn = workspace.ChildAdded:Connect(function(child) if TrinketSet[child.Name] then task.delay(0.05, function() EnqueueTrinket(child) end) end; for _, name in ipairs(LOOT_FOLDER_NAMES) do if child.Name == name then table.insert(AutoTrinket.FolderConns, child.ChildAdded:Connect(function(obj) if TrinketSet[obj.Name] then task.delay(0.05, function() EnqueueTrinket(obj) end) end end)); break end end end)
    for _, fn in ipairs(LOOT_FOLDER_NAMES) do local f = workspace:FindFirstChild(fn); if f then table.insert(AutoTrinket.FolderConns, f.ChildAdded:Connect(function(c2) if TrinketSet[c2.Name] then task.delay(0.05, function() EnqueueTrinket(c2) end) end end)) end end
end

local function StartAutoTrinket()
    AutoTrinket.Queue = {}; AutoTrinket.Queued = {}; AutoTrinket.Processed = {}; SetupTrinketListeners(); task.spawn(ScanTrinketFolders)
    if AutoTrinket.WorkerThread then pcall(task.cancel, AutoTrinket.WorkerThread) end; AutoTrinket.WorkerThread = task.spawn(TrinketWorker)
    if AutoTrinket.ScanThread then pcall(task.cancel, AutoTrinket.ScanThread) end; AutoTrinket.ScanThread = task.spawn(function() while AutoTrinket.Enabled do task.wait(AutoTrinket.ScanInterval); if AutoTrinket.Enabled then task.spawn(ScanTrinketFolders) end end end)
end

local function StopAutoTrinket()
    AutoTrinket.Enabled = false
    if AutoTrinket.WorkerThread then pcall(task.cancel, AutoTrinket.WorkerThread); AutoTrinket.WorkerThread = nil end
    if AutoTrinket.ScanThread then pcall(task.cancel, AutoTrinket.ScanThread); AutoTrinket.ScanThread = nil end
    for _, c in ipairs(AutoTrinket.FolderConns) do c:Disconnect() end; AutoTrinket.FolderConns = {}
    if AutoTrinket.WorkspaceConn then AutoTrinket.WorkspaceConn:Disconnect(); AutoTrinket.WorkspaceConn = nil end
    AutoTrinket.Queue = {}; AutoTrinket.Queued = {}; AutoTrinket.Processed = {}
end

Hub.AutoTrinket = AutoTrinket
Hub.StartAutoTrinket = StartAutoTrinket
Hub.StopAutoTrinket = StopAutoTrinket

-- Trinket ESP
local function CreateTrinketESP(obj)
    if not TrinketESP.Enabled or not obj or not obj.Parent or not TrinketSet[obj.Name] or TrinketESP.TrackedObjects[obj] then return end
    local color = TrinketColors[obj.Name] or DEFAULT_TRINKET_COLOR
    local bb = Instance.new("BillboardGui"); bb.Name = "TrinketESP"; bb.AlwaysOnTop = true; bb.Size = UDim2.new(0, 200, 0, 50); bb.StudsOffset = Vector3.new(0, 3, 0); bb.LightInfluence = 0
    local tl = Instance.new("TextLabel"); tl.Size = UDim2.new(1, 0, 1, 0); tl.BackgroundTransparency = 1; tl.Text = obj.Name; tl.TextColor3 = color; tl.TextStrokeTransparency = 0; tl.TextStrokeColor3 = Color3.new(0, 0, 0); tl.Font = Enum.Font.GothamBold; tl.TextScaled = true; tl.Parent = bb
    local hl = Instance.new("Highlight"); hl.Name = "TrinketHL"; hl.FillColor = color; hl.OutlineColor = color; hl.FillTransparency = 0.7; hl.OutlineTransparency = 0
    local tp = obj:IsA("BasePart") and obj or obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart"))
    if tp then bb.Adornee = tp; bb.Parent = tp; hl.Parent = obj else bb:Destroy(); hl:Destroy(); return end
    TrinketESP.TrackedObjects[obj] = { billboard = bb, highlight = hl }
    local conn; conn = obj.AncestryChanged:Connect(function(_, parent) if not parent then pcall(function() bb:Destroy() end); pcall(function() hl:Destroy() end); TrinketESP.TrackedObjects[obj] = nil; conn:Disconnect() end end)
end

local function RemoveAllTrinketESP() for _, data in pairs(TrinketESP.TrackedObjects) do pcall(function() data.billboard:Destroy() end); pcall(function() data.highlight:Destroy() end) end; TrinketESP.TrackedObjects = {} end

local function ScanForTrinketESP()
    if not TrinketESP.Enabled then return end
    for _, obj in ipairs(workspace:GetChildren()) do if TrinketSet[obj.Name] then CreateTrinketESP(obj) end end
    for _, fn in ipairs(LOOT_FOLDER_NAMES) do local f = workspace:FindFirstChild(fn); if f then for _, obj in ipairs(f:GetChildren()) do if TrinketSet[obj.Name] then CreateTrinketESP(obj) end end end end
end

local function SetupESPListeners()
    for _, c in ipairs(TrinketESP.FolderConns) do c:Disconnect() end; TrinketESP.FolderConns = {}
    if TrinketESP.WorkspaceConn then TrinketESP.WorkspaceConn:Disconnect(); TrinketESP.WorkspaceConn = nil end
    TrinketESP.WorkspaceConn = workspace.ChildAdded:Connect(function(child) if TrinketSet[child.Name] then task.delay(0.1, function() CreateTrinketESP(child) end) end end)
    for _, fn in ipairs(LOOT_FOLDER_NAMES) do local f = workspace:FindFirstChild(fn); if f then table.insert(TrinketESP.FolderConns, f.ChildAdded:Connect(function(c2) if TrinketSet[c2.Name] then task.delay(0.1, function() CreateTrinketESP(c2) end) end end)) end end
end

local function StartTrinketESP() SetupESPListeners(); task.spawn(ScanForTrinketESP); if TrinketESP.ScanThread then pcall(task.cancel, TrinketESP.ScanThread) end; TrinketESP.ScanThread = task.spawn(function() while TrinketESP.Enabled do task.wait(10); if TrinketESP.Enabled then task.spawn(ScanForTrinketESP) end end end) end
local function StopTrinketESP() TrinketESP.Enabled = false; if TrinketESP.ScanThread then pcall(task.cancel, TrinketESP.ScanThread); TrinketESP.ScanThread = nil end; for _, c in ipairs(TrinketESP.FolderConns) do c:Disconnect() end; TrinketESP.FolderConns = {}; if TrinketESP.WorkspaceConn then TrinketESP.WorkspaceConn:Disconnect(); TrinketESP.WorkspaceConn = nil end; RemoveAllTrinketESP() end

Hub.TrinketESP = TrinketESP
Hub.StartTrinketESP = StartTrinketESP
Hub.StopTrinketESP = StopTrinketESP

-- ================================================================
-- SERVER HOP
-- ================================================================
local function ParseServers()
    local servers = {}
    pcall(function()
        local sf = ReplicatedStorage:FindFirstChild("Servers"); if not sf then return end
        for _, ch in ipairs(sf:GetChildren()) do local val = tostring(ch.Value); local jobId, count = val:match("^(%S+)%s+(%d+)$"); if jobId and count then table.insert(servers, { name = ch.Name, jobId = jobId, count = tonumber(count) }) end end
    end)
    return servers
end

local function DoServerHop(mode)
    local servers = ParseServers(); if #servers == 0 then Notify("No servers found", 3); return end
    local currentJobId = game.JobId; local filtered = {}
    for _, s in ipairs(servers) do if s.jobId ~= currentJobId then table.insert(filtered, s) end end
    if #filtered == 0 then Notify("No other servers available", 3); return end
    local chosen
    if mode == "random" then chosen = filtered[math.random(#filtered)]
    else table.sort(filtered, function(a, b) return a.count < b.count end); chosen = filtered[1] end
    Notify(Format("Hopping to %s (%d players)", chosen.name, chosen.count), 3)
    if Hub.DataEvent then pcall(function() Hub.DataEvent:FireServer("ServerTeleport", chosen.jobId, 14) end) end
end

Hub.DoServerHop = DoServerHop

-- ================================================================
-- CHAKRA SENSE TRACKER
-- ================================================================
local ChakraTracker = { ActiveUsers = {}, SenseOwners = {}, Tracks = {}, Connections = {}, PendingStops = {}, SkillID = "9864206537", DrawingObjects = {} }

local function InitChakraDisplay()
    local bg = Drawing.new("Square"); bg.Filled = true; bg.Color = Color3.fromRGB(10, 10, 20); bg.Transparency = 0.85; bg.Visible = true; bg.ZIndex = 10
    local border = Drawing.new("Square"); border.Filled = false; border.Color = Color3.fromRGB(120, 80, 200); border.Transparency = 0.9; border.Thickness = 1; border.Visible = true; border.ZIndex = 10
    local headerTxt = Drawing.new("Text"); headerTxt.Center = true; headerTxt.Outline = true; headerTxt.OutlineColor = Color3.new(0, 0, 0); headerTxt.Color = Color3.fromRGB(180, 130, 255); headerTxt.Size = 15; headerTxt.Visible = true; headerTxt.ZIndex = 11
    local activeTxt = Drawing.new("Text"); activeTxt.Center = true; activeTxt.Outline = true; activeTxt.OutlineColor = Color3.new(0, 0, 0); activeTxt.Color = Color3.fromRGB(255, 100, 100); activeTxt.Size = 13; activeTxt.Visible = false; activeTxt.ZIndex = 11
    ChakraTracker.DrawingObjects = { bg = bg, border = border, header = headerTxt, active = activeTxt }
end
InitChakraDisplay()

local function UpdateChakraDisplay()
    local objs = ChakraTracker.DrawingObjects; if not objs.bg then return end
    local ownerCount = 0; for _ in pairs(ChakraTracker.SenseOwners) do ownerCount = ownerCount + 1 end
    local activeNames = {}; for name in pairs(ChakraTracker.SenseOwners) do if ChakraTracker.ActiveUsers[name] then table.insert(activeNames, name) end end
    local vps = Camera.ViewportSize; local panelW = 300; local lineH = 18; local lines = 1 + (#activeNames > 0 and 1 or 0); local panelH = 10 + lines * lineH
    local px = vps.X / 2 - panelW / 2; local py = 4
    objs.bg.Position = Vector2.new(px, py); objs.bg.Size = Vector2.new(panelW, panelH)
    objs.border.Position = Vector2.new(px, py); objs.border.Size = Vector2.new(panelW, panelH)
    objs.header.Position = Vector2.new(vps.X / 2, py + 5); objs.header.Text = Format("Chakra Sense  |  %d Owners  |  %d Active", ownerCount, #activeNames)
    if #activeNames > 0 then objs.active.Position = Vector2.new(vps.X / 2, py + 5 + lineH); objs.active.Text = table.concat(activeNames, ", "); objs.active.Visible = true
    else objs.active.Visible = false end
end

local function ScanSenseOwners()
    ChakraTracker.SenseOwners = {}
    pcall(function() local cooldowns = ReplicatedStorage:FindFirstChild("Cooldowns"); if not cooldowns then return end; for _, pf in ipairs(cooldowns:GetChildren()) do if pf:FindFirstChild("Chakra Sense") then ChakraTracker.SenseOwners[pf.Name] = true end end end)
    UpdateChakraDisplay()
end
task.spawn(function() while true do ScanSenseOwners(); task.wait(15) end end)

local function StopChakraTracking(player) if ChakraTracker.ActiveUsers[player.Name] then ChakraTracker.ActiveUsers[player.Name] = nil; ChakraTracker.Tracks[player.Name] = nil; UpdateChakraDisplay() end end

local function MonitorChakraPlayer(player)
    if player == LocalPlayer then return end
    local function onCharacterAdded(character)
        task.wait(0.5); local hum = character:FindFirstChildOfClass("Humanoid"); if not hum then return end; local animator = hum:FindFirstChildOfClass("Animator"); if not animator then return end
        if ChakraTracker.Connections[player] then for _, conn in ipairs(ChakraTracker.Connections[player]) do conn:Disconnect() end end; ChakraTracker.Connections[player] = {}
        local function onAnimPlayed(track)
            local assetId = track.Animation.AnimationId:match("rbxassetid://(%d+)"); if assetId ~= ChakraTracker.SkillID then return end
            if ChakraTracker.PendingStops[player.Name] then ChakraTracker.PendingStops[player.Name] = nil end
            if ChakraTracker.ActiveUsers[player.Name] then ChakraTracker.Tracks[player.Name] = track; return end
            ChakraTracker.ActiveUsers[player.Name] = true; ChakraTracker.Tracks[player.Name] = track; UpdateChakraDisplay()
            local hbConn; hbConn = RunService.Heartbeat:Connect(function()
                if not track or not track.IsPlaying then
                    if ChakraTracker.ActiveUsers[player.Name] and not ChakraTracker.PendingStops[player.Name] then ChakraTracker.PendingStops[player.Name] = tick() end
                    if ChakraTracker.PendingStops[player.Name] and (tick() - ChakraTracker.PendingStops[player.Name]) > 1 then ChakraTracker.PendingStops[player.Name] = nil; StopChakraTracking(player); hbConn:Disconnect() end
                else ChakraTracker.PendingStops[player.Name] = nil end
            end); table.insert(ChakraTracker.Connections[player], hbConn)
        end
        local playedConn = animator.AnimationPlayed:Connect(onAnimPlayed); table.insert(ChakraTracker.Connections[player], playedConn)
        for _, t in ipairs(animator:GetPlayingAnimationTracks()) do onAnimPlayed(t) end
    end
    player.CharacterAdded:Connect(onCharacterAdded); if player.Character then onCharacterAdded(player.Character) end
end
for _, p in ipairs(Players:GetPlayers()) do MonitorChakraPlayer(p) end
Players.PlayerAdded:Connect(function(player) MonitorChakraPlayer(player); task.delay(2, ScanSenseOwners) end)
Players.PlayerRemoving:Connect(function(player) if ChakraTracker.Connections[player] then for _, conn in ipairs(ChakraTracker.Connections[player]) do conn:Disconnect() end; ChakraTracker.Connections[player] = nil end; if ChakraTracker.ActiveUsers[player.Name] then StopChakraTracking(player) end; task.delay(1, ScanSenseOwners) end)

Hub.ChakraTracker = ChakraTracker

-- ================================================================
-- CHAKRA SENSE SAFETY (Pause farms when someone uses Chakra Sense)
-- ================================================================
local SECRET_SPOT = Vector3.new(-4458.5, 660.7, -4895.2)
local ChakraSafety = {
    Enabled = false,
    Hiding = false,
    Thread = nil,
    SavedPosition = nil,
    SavedStates = {},
    CheckInterval = 1,
}

local function GetActiveChakraCount()
    local count = 0
    for name in pairs(ChakraTracker.ActiveUsers) do
        -- Only count if player OWNS Chakra Sense AND is playing the animation
        if name ~= LocalPlayer.Name and ChakraTracker.SenseOwners[name] then count = count + 1 end
    end
    return count
end

local function IsSafeFarmContextActive()
    return IsActivelyAutoFarming()
end

local function PauseFarms()
    local saved = {}
    -- Save mission target info for reattach
    if Hub.MissionSystem and Hub.MissionSystem.ActiveMission and Hub.MissionSystem.CurrentTarget then
        saved.MissionTarget = Hub.MissionSystem.CurrentTarget
        saved.MissionHeightOffset = Hub.MissionSystem.CurrentHeightOffset
        saved.MissionAttackDelay = Hub.MissionSystem.CurrentAttackDelay
        saved.MissionName = Hub.MissionSystem.ActiveMission
        -- Stop the farm loop but keep ActiveMission set so WaitForMissionResult doesn't break
        if Hub.MissionSystem.AnchorConn then Hub.MissionSystem.AnchorConn:Disconnect(); Hub.MissionSystem.AnchorConn = nil end
        if Hub.MissionSystem.AttackThread then pcall(task.cancel, Hub.MissionSystem.AttackThread); Hub.MissionSystem.AttackThread = nil end
    end
    -- BossFarm
    if Hub.BossFarm and Hub.BossFarm.Enabled then saved.BossFarm = true; Hub.BossFarm.Enabled = false; Hub.StopBossFarm() end
    -- AutoEye
    if Hub.AutoEye and Hub.AutoEye.Enabled then saved.AutoEye = true; Hub.AutoEye.Enabled = false; if Hub.AutoEye.Thread then pcall(task.cancel, Hub.AutoEye.Thread); Hub.AutoEye.Thread = nil end end
    -- AutoGripFarm Alt
    if Hub.AutoGripFarm and Hub.AutoGripFarm.AltEnabled then saved.GripAlt = true; Hub.AutoGripFarm.AltEnabled = false; if Hub.AutoGripFarm.AltThread then pcall(task.cancel, Hub.AutoGripFarm.AltThread); Hub.AutoGripFarm.AltThread = nil end end
    -- AutoGripFarm Main
    if Hub.AutoGripFarm and Hub.AutoGripFarm.MainEnabled then saved.GripMain = true; Hub.AutoGripFarm.MainEnabled = false; if Hub.AutoGripFarm.MainThread then pcall(task.cancel, Hub.AutoGripFarm.MainThread); Hub.AutoGripFarm.MainThread = nil end end
    -- AutoTrinket
    if Hub.AutoTrinket and Hub.AutoTrinket.Enabled then saved.AutoTrinket = true; Hub.AutoTrinket.Enabled = false; Hub.StopAutoTrinket() end
    -- AutoMission (only stop if no active mission target - otherwise we handle it above)
    if Hub.MissionSystem and Hub.MissionSystem.AutoEnabled and not saved.MissionTarget then saved.AutoMission = true; Hub.StopAutoMission() end
    return saved
end

local function ResumeFarms(saved)
    if not saved then return end
    -- Reattach to mission mob if it's still alive
    if saved.MissionTarget and Hub.MissionSystem then
        local target = saved.MissionTarget
        local hum = target.humanoid
        if hum and hum.Parent and hum.Health > 0 then
            Hub.MissionSystem.ActiveMission = saved.MissionName
            Hub.MissionSystem.CurrentTarget = target
            Hub.MissionSystem.CurrentHeightOffset = saved.MissionHeightOffset
            Hub.MissionSystem.CurrentAttackDelay = saved.MissionAttackDelay
            -- Restart the farm loop on this mob
            local RunService = Hub.RunService
            local model = target.model
            local heightOffset = saved.MissionHeightOffset or 10
            local attackDelay = saved.MissionAttackDelay or 0.12
            Hub.MissionSystem.AnchorConn = RunService.Heartbeat:Connect(function()
                pcall(function()
                    if not Hub.MissionSystem.ActiveMission then return end
                    if not hum or not hum.Parent or hum.Health <= 0 then return end
                    local bossRoot = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head") or model:FindFirstChildWhichIsA("BasePart"); if not bossRoot then return end
                    local char = LocalPlayer.Character; if not char then return end; local root = char:FindFirstChild("HumanoidRootPart"); if not root then return end
                    root.CFrame = CFrame.lookAt(bossRoot.Position + Vector3.new(0, heightOffset, 0), bossRoot.Position)
                end)
            end)
            Hub.MissionSystem.AttackThread = task.spawn(function()
                while Hub.MissionSystem.ActiveMission and hum and hum.Parent and hum.Health > 0 do
                    if Hub.ChakraSafety and Hub.ChakraSafety.Hiding then task.wait(0.5); continue end
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
            Notify("Reattached to " .. (model.Name or "mob") .. "!", 2)
        end
    end
    if saved.BossFarm and Hub.BossFarm then Hub.BossFarm.Enabled = true; Hub.StartBossFarm() end
    if saved.AutoEye and Hub.AutoEye then Hub.AutoEye.Enabled = true; Hub.AutoEye.Thread = task.spawn(Hub.autoEyeLoop) end
    if saved.GripAlt and Hub.AutoGripFarm then Hub.AutoGripFarm.AltEnabled = true; Hub.AutoGripFarm.AltThread = task.spawn(Hub.autoGripAltLoop) end
    if saved.GripMain and Hub.AutoGripFarm then Hub.AutoGripFarm.MainEnabled = true; Hub.AutoGripFarm.MainThread = task.spawn(Hub.autoGripMainLoop) end
    if saved.AutoTrinket and Hub.AutoTrinket then Hub.AutoTrinket.Enabled = true; Hub.StartAutoTrinket() end
    if saved.AutoMission and not saved.MissionTarget then Hub.StartAutoMission() end
end

Hub.PauseFarms = PauseFarms
Hub.ResumeFarms = ResumeFarms

local function ChakraSafetyLoop()
    while ChakraSafety.Enabled do
        local activeCount = GetActiveChakraCount()
        local contextActive = IsSafeFarmContextActive()
        if activeCount > 0 and not ChakraSafety.Hiding and contextActive then
            -- Someone activated Chakra Sense - flee
            ChakraSafety.Hiding = true
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then ChakraSafety.SavedPosition = root.Position end
            ChakraSafety.SavedStates = PauseFarms()
            TeleportTo(SECRET_SPOT)
            Notify("Chakra Sense detected! Hiding at Secret Spot...", 4)
        elseif activeCount == 0 and ChakraSafety.Hiding then
            -- All clear - resume
            ChakraSafety.Hiding = false
            if ChakraSafety.SavedPosition then
                TeleportTo(ChakraSafety.SavedPosition)
                ChakraSafety.SavedPosition = nil
            end
            ResumeFarms(ChakraSafety.SavedStates)
            ChakraSafety.SavedStates = {}
            Notify("Chakra Sense clear! Resuming farms.", 3)
        end
        task.wait(ChakraSafety.CheckInterval)
    end
end

local function StartChakraSafety()
    if ChakraSafety.Thread then pcall(task.cancel, ChakraSafety.Thread) end
    ChakraSafety.Thread = task.spawn(ChakraSafetyLoop)
end

local function StopChakraSafety()
    if ChakraSafety.Thread then pcall(task.cancel, ChakraSafety.Thread); ChakraSafety.Thread = nil end
    if ChakraSafety.Hiding then
        ChakraSafety.Hiding = false
        if ChakraSafety.SavedPosition then TeleportTo(ChakraSafety.SavedPosition); ChakraSafety.SavedPosition = nil end
        ResumeFarms(ChakraSafety.SavedStates); ChakraSafety.SavedStates = {}
    end
end

Hub.ChakraSafety = ChakraSafety
Hub.StartChakraSafety = StartChakraSafety
Hub.StopChakraSafety = StopChakraSafety

-- ================================================================
-- BUY ITEMS (Direct Remote)
-- ================================================================
local BuyItemsData = {
    { Name = "Onyx Resanagi", Price = 60, Workspace = "Onyx Resanagi3", Amount = 1 },
    { Name = "Golden Resanagi", Price = 40, Workspace = "Golden Resanagi1", Amount = 1 },
    { Name = "Silver Resanagi", Price = 25, Workspace = "Silver Resanagi3", Amount = 1 },
    { Name = "Silver Zabunagi", Price = 50, Workspace = "Silver Zabunagi", Amount = 1 },
    { Name = "Golden Zabunagi", Price = 70, Workspace = "Silver Zabunagi", Amount = 1 },
    { Name = "Onyx Zabunagi", Price = 90, Workspace = "Onyx Zabunagi", Amount = 1 },
    { Name = "Onyx Asumai", Price = 70, Workspace = "Onyx Asumai", Amount = 1 },
    { Name = "Ramen", Price = 40, WorkspaceIndex = 2168, Amount = 1, AllowedAmounts = {1, 5} },
}

local BuyItemsLookup = {}
local BuyItemNames = {}
for _, item in ipairs(BuyItemsData) do
    BuyItemsLookup[item.Name] = item
    table.insert(BuyItemNames, item.Name)
end

Hub.SelectedBuyItem = BuyItemNames[1]
Hub.RamenBuyAmount = 1

local function ResolveBuyTarget(item)
    if item.Workspace then
        return workspace:FindFirstChild(item.Workspace)
    end
    if item.WorkspaceIndex then
        local children = workspace:GetChildren()
        return children[item.WorkspaceIndex] and (children[item.WorkspaceIndex]:FindFirstChild("HumanoidRootPart") or children[item.WorkspaceIndex])
    end
    return nil
end

local function BuySelectedItem()
    local item = BuyItemsLookup[Hub.SelectedBuyItem]
    if not item then Notify("No item selected!", 2); return end

    local amount = item.Name == "Ramen" and (Hub.RamenBuyAmount or 1) or (item.Amount or 1)
    local wsObj = ResolveBuyTarget(item)
    if not wsObj then Notify("Shop target not found for '" .. item.Name .. "'!", 3); return end

    local ok, err = pcall(function()
        Hub.RefreshDataFunction()
        if not Hub.DataFunction then error("DataFunction missing") end
        Hub.DataFunction:InvokeServer("Pay", item.Price, item.Name, amount, wsObj)
    end)

    if ok then
        Notify("Bought: " .. item.Name .. " x" .. tostring(amount), 2)
    else
        Notify("Buy failed: " .. tostring(err), 3)
    end
end

Hub.BuyItemsData = BuyItemsData
Hub.BuyItemNames = BuyItemNames
Hub.BuySelectedItem = BuySelectedItem

task.spawn(function()
    task.wait(2)
    if Hub.StartPlayerFarmSafety then
        Hub.StartPlayerFarmSafety()
    end
end)
