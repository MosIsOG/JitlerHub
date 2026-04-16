-- Jitler Hub - UI Module (Window, Tabs, Widgets)
local Hub = shared.JitlerHub
local JitlerUI = Hub.JitlerUI
local Players = Hub.Players
local RunService = Hub.RunService
local LocalPlayer = Hub.LocalPlayer
local Lighting = Hub.Lighting
local Notify = Hub.Notify
local Format = Hub.Format
local TeleportTo = Hub.TeleportTo
local PressE = Hub.PressE

-- ================================================================
-- UI CREATION
-- ================================================================
local Window = JitlerUI:CreateWindow({
    Name = "Jitler Hub v2.3.6",
    Icon = "rbxassetid://124980045936567",
    LoadingTitle = "Jitler Hub",
    LoadingSubtitle = "Loading modules...",
    ConfigurationSaving = { Enabled = true, FolderName = "JitlerHub", FileName = "Default" },
    SettingsIcon = "rbxassetid://7734053495",
})

local available = Hub.AvailableModules or { ESP = true, Combat = true, Movement = true, Farming = true, Missions = true, UI = true }
local MainTab = Window:CreateTab({ Name = "Main", Icon = "rbxassetid://11347112400", Section = "Main" })
local ESPTab = available.ESP and Window:CreateTab({ Name = "ESP", Icon = "rbxassetid://6523858394", Section = "Main" })
local AutoFarmTab = available.Farming and Window:CreateTab({ Name = "AutoFarm", Icon = "rbxassetid://130840043704422", Section = "Farming" })
local TeleportTab = Window:CreateTab({ Name = "Teleports", Icon = "rbxassetid://139799091866771", Section = "Main" })

local SubMain = MainTab:CreateSubTab("Main")
local SubQOL = MainTab:CreateSubTab("Misc")

-- ================================================================
-- ESP TAB
-- ================================================================
if ESPTab then
    do
        local ESPLeft, ESPRight = ESPTab:CreateDualPane()
        local Options = Hub.Options

ESPLeft:CreateSection("Player ESP")

ESPLeft:CreateToggle({ Name = "Enable Player ESP", Description = "Show names, health & distance", CurrentValue = true, Flag = "ESPEnabled", Callback = function(v) Options.Enabled(v) end })

ESPLeft:CreateDropdown({ Name = "Show Information", Options = { "Name, Health, Distance", "Name, Health, Distance, TeamColor" }, CurrentOption = "Name, Health, Distance", Flag = "ESPInfoMode", Callback = function(v)
    local sel = type(v) == "table" and v[1] or v
    Options.ShowName(true); Options.ShowHealth(true); Options.ShowDistance(true)
    if sel == "Name, Health, Distance, TeamColor" then Options.ShowTeamColor(true) else Options.ShowTeamColor(false) end
end })

ESPLeft:CreateSlider({ Name = "Text Size", Range = { 8, 30 }, Increment = 1, Suffix = "px", CurrentValue = 14, Flag = "ESPTextSize", Callback = function(v) Options.TextSize(v) end })
ESPLeft:CreateSlider({ Name = "Y Offset", Range = { -200, 200 }, Increment = 1, Suffix = "", CurrentValue = 0, Flag = "ESPYOffset", Callback = function(v) Options.YOffset(v) end })
ESPLeft:CreateSlider({ Name = "Max Distance", Range = { 100, 10000 }, Increment = 100, Suffix = " studs", CurrentValue = 2500, Flag = "ESPMaxDist", Callback = function(v) Options.MaxDistance(v) end })

ESPLeft:CreateColorPicker({ Name = "Text Color", Default = Color3.fromRGB(255, 255, 255), Flag = "ESPTextColor", Callback = function(c) Hub.ESPTextColor = c end })

ESPLeft:CreateToggle({ Name = "Show Tracers", CurrentValue = false, Flag = "ESPTracers", Callback = function(v) Options.ShowTracers(v) end })
ESPLeft:CreateToggle({ Name = "Show Boxes", CurrentValue = false, Flag = "ESPBoxes", Callback = function(v) Options.ShowBoxes(v) end })
ESPLeft:CreateToggle({ Name = "Crosshair", CurrentValue = false, Flag = "ESPCrosshair", Callback = function(v) Options.Crosshair(v) end })

ESPRight:CreateSection("Player Highlight")

ESPRight:CreateToggle({ Name = "Enable Highlight", Description = "Glow outline on players", CurrentValue = false, Flag = "PlayerHL", Callback = function(v) Hub.PlayerHighlight.Enabled = v; if v then Hub.StartPlayerHighlight() else Hub.StopPlayerHighlight() end end })
ESPRight:CreateSlider({ Name = "Fill Transparency", Range = { 0, 1 }, Increment = 0.05, Suffix = "", CurrentValue = 0.7, Flag = "HLFillTrans", Callback = function(v) Hub.PlayerHighlight.FillTransparency = v end })
ESPRight:CreateColorPicker({ Name = "Highlight Color", Default = Color3.fromRGB(130, 100, 210), Flag = "HLFillColor", Callback = function(c) Hub.PlayerHighlight.FillColor = c end })
ESPRight:CreateSlider({ Name = "Outline Transparency", Range = { 0, 1 }, Increment = 0.05, Suffix = "", CurrentValue = 0, Flag = "HLOutlineTrans", Callback = function(v) Hub.PlayerHighlight.OutlineTransparency = v end })
ESPRight:CreateSlider({ Name = "HL Max Distance", Range = { 100, 5000 }, Increment = 50, Suffix = " studs", CurrentValue = 2500, Flag = "HLMaxDist", Callback = function(v) Hub.PlayerHighlight.MaxDistance = v end })

ESPRight:CreateSection("Healthbar ESP")

ESPRight:CreateToggle({ Name = "Enable Healthbars", CurrentValue = true, Flag = "ShowHealthbars", Callback = function(v) Options.ShowCustomHealthbar(v) end })
ESPRight:CreateSlider({ Name = "Bar Width", Range = { 30, 100 }, Increment = 1, Suffix = "px", CurrentValue = 40, Flag = "HBWidth", Callback = function(v) Options.HealthbarWidth(v) end })
ESPRight:CreateSlider({ Name = "Bar Height", Range = { 2, 10 }, Increment = 1, Suffix = "px", CurrentValue = 2, Flag = "HBHeight", Callback = function(v) Options.HealthbarHeight(v) end })
ESPRight:CreateSlider({ Name = "Bar Offset", Range = { 30, 100 }, Increment = 1, Suffix = "px", CurrentValue = 30, Flag = "HBOffset", Callback = function(v) Options.HealthbarOffset(v) end })

ESPRight:CreateSection("Mob ESP")

ESPRight:CreateToggle({ Name = "Enable Mob ESP", Description = "Show mob names & health", CurrentValue = false, Flag = "MobESP", Callback = function(v) Hub.MobESP.Enabled = v; if v then Hub.StartMobESP() else Hub.StopMobESP() end end })
ESPRight:CreateSlider({ Name = "Mob Max Distance", Range = { 100, 2000 }, Increment = 50, Suffix = " studs", CurrentValue = 500, Flag = "MobMaxDist", Callback = function(v) Hub.MobESP.MaxDistance = v end })
ESPRight:CreateSlider({ Name = "Mob Text Size", Range = { 8, 24 }, Increment = 1, Suffix = "px", CurrentValue = 14, Flag = "MobTextSize", Callback = function(v) Hub.MobESP.TextSize = v end })

ESPRight:CreateSection("Boss ESP")

ESPRight:CreateToggle({ Name = "Enable Boss ESP", Description = "Show WorldBoss HP panel (close) / text (far)", CurrentValue = false, Flag = "BossESP", Callback = function(v) Hub.BossESP.Enabled = v; if v then Hub.StartBossESP() else Hub.StopBossESP() end end })
ESPRight:CreateSlider({ Name = "Boss Max Distance", Range = { 100, 5000 }, Increment = 50, Suffix = " studs", CurrentValue = 2000, Flag = "BossMaxDist", Callback = function(v) Hub.BossESP.MaxDistance = v end })
ESPRight:CreateSlider({ Name = "Boss Panel Distance", Range = { 50, 1000 }, Increment = 25, Suffix = " studs", CurrentValue = 500, Flag = "BossTransDist", Callback = function(v) Hub.BossESP.TransitionDist = v end })
ESPRight:CreateSlider({ Name = "Boss Text Size", Range = { 8, 24 }, Increment = 1, Suffix = "px", CurrentValue = 14, Flag = "BossTextSize", Callback = function(v) Hub.BossESP.TextSize = v end })

ESPRight:CreateSection("Corrupted Point ESP")

ESPRight:CreateToggle({
    Name = "Enable CorruptedPoint ESP",
    Description = "Show CorruptedPoint current health",
    CurrentValue = false,
    Flag = "CorruptedPointESP",
    Callback = function(v)
        Hub.CorruptedPointESP.Enabled = v
        if v then Hub.StartCorruptedPointESP() else Hub.StopCorruptedPointESP() end
    end
})
ESPRight:CreateSlider({
    Name = "CP ESP Text Size",
    Range = { 8, 24 },
    Increment = 1,
    Suffix = "px",
    CurrentValue = 15,
    Flag = "CorruptedPointESPTextSize",
    Callback = function(v) Hub.CorruptedPointESP.TextSize = v end
})
ESPRight:CreateSlider({
    Name = "CP ESP Max Distance",
    Range = { 100, 5000 },
    Increment = 50,
    Suffix = " studs",
    CurrentValue = 3000,
    Flag = "CorruptedPointESPDist",
    Callback = function(v) Hub.CorruptedPointESP.MaxDistance = v end
})

ESPLeft:CreateSection("NPC ESP")

ESPLeft:CreateToggle({ Name = "Enable NPC ESP", Description = "Show dialog NPCs (lime green)", CurrentValue = false, Flag = "NPCESP", Callback = function(v) Hub.NPCESP.Enabled = v; if v then Hub.StartNPCESP() else Hub.StopNPCESP() end end })
ESPLeft:CreateSlider({ Name = "NPC Max Distance", Range = { 100, 2000 }, Increment = 50, Suffix = " studs", CurrentValue = 500, Flag = "NPCMaxDist", Callback = function(v) Hub.NPCESP.MaxDistance = v end })
ESPLeft:CreateSlider({ Name = "NPC Text Size", Range = { 8, 24 }, Increment = 1, Suffix = "px", CurrentValue = 14, Flag = "NPCTextSize", Callback = function(v) Hub.NPCESP.TextSize = v end })
    end
end

-- ================================================================
-- MAIN TAB > Main
-- ================================================================
do
local MLeft, MRight = SubMain:CreateDualPane()

MLeft:CreateSection("Movement")

MLeft:CreateToggleWithKeybind({ Name = "Walkspeed Multiplier", Description = "Multiply base walk speed", CurrentValue = false, Flag = "WalkspeedMult", Callback = function(v) Hub.WalkspeedMultiplier.Enabled = v; if v then Hub.EnableWalkspeed() else Hub.DisableWalkspeed() end end }, { CurrentKeybind = "X", Flag = "WalkspeedKey" })
MLeft:CreateSlider({ Name = "Speed Multiplier", Range = { 0.1, 25 }, Increment = 0.1, Suffix = "x", CurrentValue = 1.0, Flag = "SpeedMult", Callback = function(v)
    Hub.WalkspeedMultiplier.Multiplier = v
    if Hub.WalkspeedMultiplier.Enabled and Hub.WalkspeedMultiplier.BaseSpeed then local c = LocalPlayer.Character; if c then local h = c:FindFirstChildOfClass("Humanoid"); if h then h.WalkSpeed = Hub.WalkspeedMultiplier.BaseSpeed * v end end end
end })

MLeft:CreateSlider({ Name = "BackAttach Offset", Range = { 1, 10 }, Increment = 0.1, Suffix = " studs", CurrentValue = 3, Flag = "BackAttachOffset", Callback = function(v) Hub.BackAttach.Offset = v end })
MLeft:CreateToggle({ Name = "Lava Protection", Description = "Disable Lava/void damage", CurrentValue = false, Flag = "LavaProtection", Callback = function(v) Hub.ToggleVoidLava(v) end })
MLeft:CreateToggleWithKeybind({ Name = "Fly", Description = "Fly freely in any direction", CurrentValue = false, Flag = "Fly", Callback = function(v) Hub.FlySystem.Enabled = v; if v then Hub.StartFlying() else Hub.StopFlying() end end }, { CurrentKeybind = "Y", Flag = "FlyKey" })
MLeft:CreateSlider({ Name = "Fly Speed", Range = { 10, 300 }, Increment = 5, Suffix = "", CurrentValue = 50, Flag = "FlySpeed", Callback = function(v) Hub.FlySystem.Speed = v end })

MLeft:CreateToggleWithKeybind({ Name = "Infinite Jump", CurrentValue = false, Flag = "InfJump", Callback = function(v) _G.InfiniteJump = v end }, { CurrentKeybind = "Period", Flag = "InfJumpKey" })

MLeft:CreateToggleWithKeybind({ Name = "Noclip", Description = "Walk through walls", CurrentValue = false, Flag = "Noclip", Callback = function(v) _G.Noclip = v end }, { CurrentKeybind = "N", Flag = "NoclipKey" })

if available.Combat then
    MRight:CreateSection("Combat")

    MRight:CreateToggleWithKeybind({ Name = "M1 Spam", Description = "Auto-click at set interval", CurrentValue = false, Flag = "M1Spam", Callback = function(v) Hub.M1Spam.Enabled = v; if v then Hub.StartSpam() else Hub.StopSpam() end end }, { CurrentKeybind = "L", Flag = "M1SpamKey" })
    MRight:CreateSlider({ Name = "Click Delay", Range = { 0.02, 0.5 }, Increment = 0.01, Suffix = "s", CurrentValue = 0.1, Flag = "M1Delay", Callback = function(v) Hub.M1Spam.Delay = v end })

    MRight:CreateToggleWithKeybind({ Name = "Remote Attack Spam", Description = "Fire remote attack", CurrentValue = false, Flag = "RemoteAttack", Callback = function(v) Hub.RemoteAttackSpam.Enabled = v; if v then Hub.StartRemoteAttack() else Hub.StopRemoteAttack() end end }, { CurrentKeybind = "K", Flag = "RemoteAttackKey" })

    MRight:CreateToggle({ Name = "NoStun", Description = "Prevents stun from sticking", CurrentValue = false, Flag = "NoStun", Callback = function(v) Hub.NoStun.Enabled = v; if v then Hub.StartNoStun() else Hub.StopNoStun() end end })
end

MRight:CreateSection("Protection")

MRight:CreateToggleWithKeybind({ Name = "No Fall Damage", Description = "Prevent all fall damage", CurrentValue = false, Flag = "NoFall", Callback = function(v) Hub.NoFall.Enabled = v end }, { CurrentKeybind = "F7", Flag = "NoFallKey" })

MRight:CreateToggleWithKeybind({ Name = "Anti Void/Lava", Description = "Block void and lava kills", CurrentValue = false, Flag = "AntiVoidLava", Callback = function(v) Hub.ToggleVoidLava(v) end }, { CurrentKeybind = "V", Flag = "AntiVoidLavaKey" })
end

-- ================================================================
-- MAIN TAB > Misc
-- ================================================================
do
local QLeft, QRight = SubQOL:CreateDualPane()

QLeft:CreateSection("Visual Features")

QLeft:CreateSlider({ Name = "Time of Day", Range = { 0, 24 }, Increment = 0.5, Suffix = "h", CurrentValue = Lighting.ClockTime, Flag = "TimeOfDay", Callback = function(v) pcall(function() Lighting.ClockTime = v end) end })
QLeft:CreateToggle({ Name = "No Fog", CurrentValue = false, Flag = "NoFog", Callback = function(v) Hub.ToggleNoFog(v) end })
QLeft:CreateToggle({ Name = "No Rain", CurrentValue = false, Flag = "NoRain", Callback = function(v) Hub.ToggleNoRain(v) end })
QLeft:CreateToggle({ Name = "Full Bright", CurrentValue = false, Flag = "FullBright", Callback = function(v) Hub.ToggleFullBright(v, Hub.FullBrightLevel) end })
QLeft:CreateSlider({ Name = "Brightness Level", Range = { 0.5, 5 }, Increment = 0.1, Suffix = "", CurrentValue = 2, Flag = "BrightnessLvl", Callback = function(v) Hub.FullBrightLevel = v; if Hub.FullBrightEnabled then Hub.ToggleFullBright(true, v) end end })

QRight:CreateSection("Combat Assist")

QRight:CreateToggleWithKeybind({ Name = "Auto Perfect Block", Description = "Auto time perfect blocks", CurrentValue = false, Flag = "AutoBlock", Callback = function(v) Hub.AutoBlock.Enabled = v; if v then Hub.StartAutoBlock() else Hub.StopAutoBlock() end end }, { CurrentKeybind = "U", Flag = "AutoBlockKey" })

QRight:CreateToggleWithKeybind({ Name = "Back Attach", Description = "TP behind nearest player", CurrentValue = false, Flag = "BackAttach", Callback = function(v) Hub.BackAttach.Enabled = v; if v then Hub.StartBackAttach() else Hub.StopBackAttach() end end }, { CurrentKeybind = "B", Flag = "BackAttachKey" })

QRight:CreateButton({ Name = "Buy Ramen", Description = "Buy ramen from shop", Callback = function() Hub.BuyRamen() end })
QRight:CreateInput({ Name = "Auto Use Skill", Description = "Skill name to auto use", Flag = "AutoSkillName", Callback = function(v) Hub.AutoUseSkill(v) end })

QRight:CreateSection("Utility")

QRight:CreateButton({ Name = "Reset Character", Callback = function() local char = LocalPlayer.Character; if char and char:FindFirstChild("Humanoid") then char.Humanoid.Health = 0; task.wait(1); char:BreakJoints() end end })
QRight:CreateButton({ Name = "Random Server Hop", Callback = function() Hub.DoServerHop("random") end })
QRight:CreateButton({ Name = "Low Player Server", Callback = function() Hub.DoServerHop("min") end })


end

-- ================================================================
-- TELEPORT TAB
-- ================================================================
do
TeleportTab:CreateSection("Current Position")

local CoordLabel = TeleportTab:CreateLabel("X: 0, Y: 0, Z: 0")
RunService.RenderStepped:Connect(function()
    local char = LocalPlayer.Character
    if char then local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head"); if root then CoordLabel:Set(Format("X: %.1f, Y: %.1f, Z: %.1f", root.Position.X, root.Position.Y, root.Position.Z)) else CoordLabel:Set("No character") end
    else CoordLabel:Set("No character") end
end)

TeleportTab:CreateButton({ Name = "Copy Position as Vector3", Callback = function()
    local char = LocalPlayer.Character; if not char then return end; local root = char:FindFirstChild("HumanoidRootPart"); if root then local p = root.Position; setclipboard(Format("Vector3.new(%.1f, %.1f, %.1f)", p.X, p.Y, p.Z)); Notify("Copied!", 2) end
end })

TeleportTab:CreateSection("Quick Teleports")
local TeleportLocations = {
    { Name = "Wood Boss", Pos = Vector3.new(-4708.4, 336.9, -2986.2) }, { Name = "Sorythia Village", Pos = Vector3.new(-113.2, 50.9, -283.8) },
    { Name = "Lava Snake", Pos = Vector3.new(-547.6, -541.7, -1281.8) }, { Name = "Biyo Bay", Pos = Vector3.new(-598.9, -178.6, -464.3) },
    { Name = "Snow Village", Pos = Vector3.new(-2916.3, -46.0, -4907.3) }, { Name = "Snap Trainer", Pos = Vector3.new(337.2, 131.4, -1967.2) },
    { Name = "Durana", Pos = Vector3.new(1851.0, -125.5, 1065.2) }, { Name = "Secret Spot", Pos = Vector3.new(-4458.5, 660.7, -4895.2) },
    { Name = "Hyuga Boss", Pos = Vector3.new(-693.7, -359.9, -765.7) }, { Name = "Haku Boss", Pos = Vector3.new(-3838.2, -231.4, -9657.0) },
    { Name = "Merchant", Pos = Vector3.new(-2875.2, -134.4, -4763.4) },
}
for _, loc in ipairs(TeleportLocations) do
    TeleportTab:CreateButton({ Name = loc.Name, Callback = function() TeleportTo(loc.Pos); Notify("TP: " .. loc.Name, 2) end })
end

TeleportTab:CreateSection("Mission Markers")

TeleportTab:CreateButton({ Name = "TP to Nearest Mission", Callback = function()
    local markers = Hub.ScanMissionMarkersFixed(); if #markers == 0 then return end
    local char = LocalPlayer.Character; if not char then return end; local root = char:FindFirstChild("HumanoidRootPart"); if not root then return end
    local pp = root.Position; local nearest, minD = nil, math.huge
    for _, m in ipairs(markers) do local d = (pp - m.pos).Magnitude; if d < minD then minD = d; nearest = m end end
    if nearest then TeleportTo(nearest.pos); Notify(nearest.name .. " (" .. math.floor(minD) .. " studs)", 2) end
end })
end

-- ================================================================
-- AUTOFARM TAB
-- ================================================================
if AutoFarmTab then
    do
        local AFLeft, AFRight = AutoFarmTab:CreateDualPane()

AFLeft:CreateSection("Boss Farm")

AFLeft:CreateInput({ Name = "Weapon Name", PlaceholderText = "Onyx Resanagi", Callback = function(v) Hub.BossFarm.WeaponName = v end })
AFLeft:CreateDropdown({ Name = "Select Boss", Options = { "Wooden Golem", "Hyuga Boss", "Lava Snake", "Haku Boss", "Barbarit The Rose", "Manda", "Tairock", "The Barbarian", "The Ringed Samurai" }, CurrentOption = "Wooden Golem", Flag = "BossSelect", Callback = function(v) Hub.BossFarm.SelectedBoss = type(v) == "table" and v[1] or v end })
AFLeft:CreateToggleWithKeybind({ Name = "Start Farm", Description = "Auto-attack selected boss", CurrentValue = false, Flag = "BossFarm", Callback = function(v) Hub.BossFarm.Enabled = v; if v then Hub.StartBossFarm() else Hub.StopBossFarm() end end }, { CurrentKeybind = "G", Flag = "BossFarmKey" })
AFLeft:CreateSlider({ Name = "Attack Delay", Range = { 0.02, 0.5 }, Increment = 0.01, Suffix = "s", CurrentValue = 0.12, Flag = "BFAttackDelay", Callback = function(v) Hub.BossFarm.AttackDelay = v end })
AFLeft:CreateToggle({ Name = "Auto Loot On Kill", CurrentValue = false, Flag = "BossAutoLoot", Callback = function(v) Hub.BossFarm.AutoLootOnKill = v end })

AFLeft:CreateSection("Advanced Boss Loop")

AFLeft:CreateDropdown({
    Name = "Loop Bosses",
    Options = {
        "Wooden Golem",
        "Hyuga Boss",
        "Lava Snake",
        "Haku Boss",
        "Barbarit The Rose",
        "Manda",
        "Tairock",
        "The Barbarian",
        "The Ringed Samurai"
    },
    CurrentOption = {},
    MultiSelection = true,
    Flag = "AdvancedBossLoopSelect",
    Callback = function(v)
        for name in pairs(Hub.AdvancedBossLoopFarm.SelectedBosses) do
            Hub.AdvancedBossLoopFarm.SelectedBosses[name] = false
        end

        local selected = type(v) == "table" and v or { v }
        for _, name in ipairs(selected) do
            if Hub.AdvancedBossLoopFarm.SelectedBosses[name] ~= nil then
                Hub.AdvancedBossLoopFarm.SelectedBosses[name] = true
            end
        end
    end
})

AFLeft:CreateToggle({
    Name = "Advanced Auto Farm",
    Description = "Loop selected bosses and keep going across hops",
    CurrentValue = Hub.AdvancedBossLoopFarm.Enabled,
    Flag = "AdvancedBossLoopEnabled",
    Callback = function(v)
        Hub.AdvancedBossLoopFarm.Enabled = v
        if v then
            Hub.StartAdvancedBossLoop()
        else
            Hub.StopAdvancedBossLoop()
        end
    end
})

AFLeft:CreateToggle({
    Name = "Hop After Loop",
    CurrentValue = false,
    Flag = "AdvancedBossHopAfterLoop",
    Callback = function(v)
        Hub.AdvancedBossLoopFarm.HopAfterLoop = v
    end
})

AFLeft:CreateToggle({
    Name = "Hop on Chakra Sense Users",
    CurrentValue = false,
    Flag = "AdvancedBossHopOnChakra",
    Callback = function(v)
        Hub.AdvancedBossLoopFarm.HopOnChakraSenseUsers = v
    end
})

AFLeft:CreateSection("Auto Use Skill")

AFLeft:CreateToggle({
    Name = "Enable Auto Skills",
    Description = "Use selected skills during mission/boss farm",
    CurrentValue = false,
    Flag = "AutoUseSkills",
    Callback = function(v)
        Hub.AutoSkillFarm.Enabled = v
    end
})

AFLeft:CreateDropdown({
    Name = "Select Skills",
    Options = { "Asumai Dance", "Asumai One Two", "Spinning Dash" },
    CurrentOption = { "Asumai Dance", "Asumai One Two", "Spinning Dash" },
    MultiSelection = true,
    Flag = "AutoSkillSelect",
    Callback = function(v)
        Hub.AutoSkillFarm.SelectedSkills = {}
        local selected = type(v) == "table" and v or { v }
        for _, skill in ipairs(selected) do
            Hub.AutoSkillFarm.SelectedSkills[skill] = true
        end
    end
})

AFLeft:CreateSection("Auto Mode Farm")

AFLeft:CreateDropdown({ Name = "Select Mode", Options = { "Sharingan [Stage 1]", "Sharingan [Stage 2]", "Sharingan [Stage 3]", "Byakugan [Stage 1]", "Byakugan [Stage 2]", "Byakugan [Stage 3]", "Byakugan [Stage 4]", "Green Gates", "Hundred Healings", "Sasuke's Rinnegan", "Cloak Of Lightning", "Pain's Rinnegan", "Shisui's Mangekyo", "Madara's Mangekyo", "Sasuke's Mangekyo", "Itachi's Mangekyo", "Ketsuryugan [Stage 1]", "Ketsuryugan [Stage 2]" }, CurrentOption = "Sharingan [Stage 1]", Flag = "ModeSelect", Callback = function(v) Hub.AutoEye.SelectedItem = type(v) == "table" and v[1] or v end })
AFLeft:CreateToggle({ Name = "Enable Auto Mode", CurrentValue = false, Flag = "AutoMode", Callback = function(v) Hub.AutoEye.Enabled = v; if v then if Hub.AutoEye.Thread then task.cancel(Hub.AutoEye.Thread) end; Hub.AutoEye.Thread = task.spawn(Hub.autoEyeLoop) else if Hub.AutoEye.Thread then task.cancel(Hub.AutoEye.Thread); Hub.AutoEye.Thread = nil end end end })

AFLeft:CreateSection("Auto Mission")

local missionDropdownRef
local function RefreshMissionDropdownUI()
    Hub.RefreshMissionBoard()
    local opts = {}
    for _, m in ipairs(Hub.MissionSystem.AvailableMissions) do table.insert(opts, m) end
    if #opts == 0 then opts = {"No missions found"} end
    if missionDropdownRef then pcall(function() missionDropdownRef:SetOptions(opts); missionDropdownRef:SetValue(opts[1]) end) end
    Hub.MissionSystem.SelectedMission = opts[1]
end

missionDropdownRef = AFLeft:CreateDropdown({ Name = "Select Mission", Options = {"Click Refresh"}, CurrentOption = "Click Refresh", Flag = "MissionSelect", Callback = function(v) Hub.MissionSystem.SelectedMission = type(v) == "table" and v[1] or v end })
AFLeft:CreateButton({ Name = "Refresh Missions", Callback = function() task.spawn(RefreshMissionDropdownUI) end })
AFLeft:CreateToggle({ Name = "Auto Mission Farm", CurrentValue = false, Flag = "AutoMission", Callback = function(v) if v then Hub.StartAutoMission() else Hub.StopAutoMission() end end })
AFLeft:CreateButton({ Name = "TP to Mission Marker", Callback = function() task.spawn(Hub.TeleportToNearestMissionMarker) end })

AFLeft:CreateSection("Manual Mission")

local ALL_MISSIONS = { "Defeat a Boss", "Bandit Camp", "Corrupted Point", "Cratos", "Capture Manda", "Defeat a Bandit", "Crate Delivery" }
local manualMission = ALL_MISSIONS[1]

AFLeft:CreateDropdown({ Name = "Select Mission", Options = ALL_MISSIONS, CurrentOption = ALL_MISSIONS[1], Flag = "ManualMissionSelect", Callback = function(v) manualMission = type(v) == "table" and v[1] or v end })
AFLeft:CreateButton({ Name = "Run Mission Once", Callback = function()
    task.spawn(function()
        if not manualMission then Notify("No mission selected!", 2); return end
        Notify("Manual mission: " .. manualMission, 2)
        local assigned = Hub.AssignMission(manualMission)
        if not assigned then
            Notify("Failed to assign mission (may already have one), trying anyway...", 2)
        end
        task.wait(1)
        local result = Hub.ExecuteMissionCase(manualMission)
        if result == "complete" then Notify("Mission complete: " .. manualMission, 3)
        elseif result == "failed" then Notify("Mission failed: " .. manualMission, 3)
        elseif result == "cooldown" then Notify("Mission on cooldown: " .. manualMission, 3)
        else Notify("Mission result: " .. tostring(result), 3) end
    end)
end })

AFRight:CreateSection("Auto Grip Farm")

AFRight:CreateToggle({ Name = "Grip Alt Mode", CurrentValue = false, Flag = "GripAlt", Callback = function(v) Hub.AutoGripFarm.AltEnabled = v; if v then if Hub.AutoGripFarm.AltThread then task.cancel(Hub.AutoGripFarm.AltThread) end; Hub.AutoGripFarm.AltThread = task.spawn(Hub.autoGripAltLoop) else if Hub.AutoGripFarm.AltThread then task.cancel(Hub.AutoGripFarm.AltThread); Hub.AutoGripFarm.AltThread = nil end end end })
AFRight:CreateToggle({ Name = "Grip Main Mode", CurrentValue = false, Flag = "GripMain", Callback = function(v) Hub.AutoGripFarm.MainEnabled = v; if v then if Hub.AutoGripFarm.MainThread then task.cancel(Hub.AutoGripFarm.MainThread) end; Hub.AutoGripFarm.MainThread = task.spawn(Hub.autoGripMainLoop) else if Hub.AutoGripFarm.MainThread then task.cancel(Hub.AutoGripFarm.MainThread); Hub.AutoGripFarm.MainThread = nil end end end })

AFRight:CreateSection("Auto Trinket Pickup")

AFRight:CreateToggle({ Name = "Enable Auto Trinket", CurrentValue = false, Flag = "AutoTrinket", Callback = function(v) Hub.AutoTrinket.Enabled = v; if v then Hub.StartAutoTrinket() else Hub.StopAutoTrinket() end end })
AFRight:CreateSlider({ Name = "Scan Interval", Range = { 1, 30 }, Increment = 1, Suffix = "s", CurrentValue = 5, Flag = "TrinketScanInt", Callback = function(v) Hub.AutoTrinket.ScanInterval = v end })
AFRight:CreateSlider({ Name = "Scan Radius", Range = { 20, 500 }, Increment = 10, Suffix = " studs", CurrentValue = 200, Flag = "TrinketRadius", Callback = function(v) Hub.AutoTrinket.ScanRadius = v end })
AFRight:CreateToggle({ Name = "Teleport to Trinket", CurrentValue = true, Flag = "TrinketTP", Callback = function(v) Hub.AutoTrinket.TeleportToTrinket = v end })
AFRight:CreateToggle({ Name = "Trinket ESP", CurrentValue = false, Flag = "TrinketESP", Callback = function(v) Hub.TrinketESP.Enabled = v; if v then Hub.StartTrinketESP() else Hub.StopTrinketESP() end end })

AFRight:CreateSection("Chakra Point Collector")

local ChakraCollector = { Running = false, Thread = nil, Delay = 1.5 }
Hub.ChakraCollector = ChakraCollector

local function CollectChakraPoints()
    local char = LocalPlayer.Character; if not char then return end; local root = char:FindFirstChild("HumanoidRootPart"); if not root then return end
    local folder = workspace:FindFirstChild("ChakraPoints"); if not folder then Notify("ChakraPoints not found", 3); return end
    for _, point in ipairs(folder:GetChildren()) do
        if not ChakraCollector.Running then return end
        local unlocked = point:FindFirstChild("Unlocked"); if unlocked and (tostring(unlocked.Value):lower() == "on" or unlocked.Value == true) then continue end
        local tp; pcall(function() tp = point:IsA("Model") and point:GetPivot().Position or point:IsA("BasePart") and point.Position or (point.PrimaryPart or point:FindFirstChildWhichIsA("BasePart")).Position end)
        if tp then root.CFrame = CFrame.new(tp + Vector3.new(0, 3, 0)); task.wait(); root.CFrame = CFrame.new(tp + Vector3.new(0, 3, 0)); task.wait(0.5); PressE(); task.wait(ChakraCollector.Delay) end
    end
    ChakraCollector.Running = false; Notify("Chakra collection complete!", 2)
end

AFRight:CreateToggle({ Name = "Auto Collect Chakra", CurrentValue = false, Flag = "ChakraCollect", Callback = function(v) ChakraCollector.Running = v; if v then if ChakraCollector.Thread then task.cancel(ChakraCollector.Thread) end; ChakraCollector.Thread = task.spawn(CollectChakraPoints) else if ChakraCollector.Thread then task.cancel(ChakraCollector.Thread); ChakraCollector.Thread = nil end end end })
AFRight:CreateSlider({ Name = "Wait per Point", Range = { 0.5, 5 }, Increment = 0.1, Suffix = "s", CurrentValue = 1.5, Flag = "ChakraDelay", Callback = function(v) ChakraCollector.Delay = v end })

AFRight:CreateSection("Rift Collector")

local RiftCollector = { Running = false, Thread = nil, Delay = 1.5 }
Hub.RiftCollector = RiftCollector

local function CollectRifts()
    local char = LocalPlayer.Character; if not char then return end; local root = char:FindFirstChild("HumanoidRootPart"); if not root then return end
    local folder = workspace:FindFirstChild("Rifts"); if not folder then Notify("Rifts not found", 3); return end
    for _, rift in ipairs(folder:GetChildren()) do
        if not RiftCollector.Running then return end
        local tp; pcall(function() tp = rift:IsA("Model") and rift:GetPivot().Position or rift:IsA("BasePart") and rift.Position or (rift.PrimaryPart or rift:FindFirstChildWhichIsA("BasePart")).Position end)
        if tp then root.CFrame = CFrame.new(tp); task.wait(0.5); PressE(); task.wait(RiftCollector.Delay) end
    end
    RiftCollector.Running = false; Notify("Rift collection complete!", 2)
end

AFRight:CreateToggle({ Name = "Auto Collect Rifts", CurrentValue = false, Flag = "RiftCollect", Callback = function(v) RiftCollector.Running = v; if v then if RiftCollector.Thread then task.cancel(RiftCollector.Thread) end; RiftCollector.Thread = task.spawn(CollectRifts) else if RiftCollector.Thread then task.cancel(RiftCollector.Thread); RiftCollector.Thread = nil end end end })
AFRight:CreateSlider({ Name = "Wait per Rift", Range = { 0.5, 5 }, Increment = 0.1, Suffix = "s", CurrentValue = 1.5, Flag = "RiftDelay", Callback = function(v) RiftCollector.Delay = v end })

AFRight:CreateSection("Buy Items")

AFRight:CreateDropdown({ Name = "Select Item", Options = Hub.BuyItemNames, CurrentOption = Hub.BuyItemNames[1], Flag = "BuyItemSelect", Callback = function(v) Hub.SelectedBuyItem = type(v) == "table" and v[1] or v end })
AFRight:CreateDropdown({ Name = "Ramen Amount", Options = { "1", "5" }, CurrentOption = "1", Flag = "RamenAmount", Callback = function(v) local selected = type(v) == "table" and v[1] or v; Hub.RamenBuyAmount = tonumber(selected) or 1 end })
AFRight:CreateButton({ Name = "Buy Selected Item", Callback = function() task.spawn(Hub.BuySelectedItem) end })

AFRight:CreateSection("Bulk Sell")

AFRight:CreateButton({ Name = "Sell All Trinkets", Callback = function() task.spawn(Hub.BulkSellTrinkets) end })
AFRight:CreateButton({ Name = "Sell All Gems", Callback = function() task.spawn(Hub.BulkSellGems) end })
AFRight:CreateButton({ Name = "Sell All Fruits", Callback = function() task.spawn(Hub.BulkSellFruits) end })

AFLeft:CreateSection("Chakra Sense Safety")

AFLeft:CreateToggle({ Name = "Enable Chakra Safety", Description = "Hide at Secret Spot when Chakra Sense detected", CurrentValue = false, Flag = "ChakraSafety", Callback = function(v) Hub.ChakraSafety.Enabled = v; if v then Hub.StartChakraSafety() else Hub.StopChakraSafety() end end })
AFLeft:CreateSlider({ Name = "Check Interval", Range = { 0.5, 5 }, Increment = 0.5, Suffix = "s", CurrentValue = 1, Flag = "ChakraSafetyInterval", Callback = function(v) Hub.ChakraSafety.CheckInterval = v end })
    end
end

-- ================================================================
-- FOOTER
-- ================================================================
Notify("Jitler Hub v2.3.6 loaded!", 3)
print("=== Jitler Hub v2.3.6 Loaded ===")
