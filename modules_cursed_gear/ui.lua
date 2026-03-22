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
    Name = "Jitler Hub v2.0.0 - Cursed Gear",
    Icon = "rbxassetid://124980045936567",
    LoadingTitle = "Jitler Hub",
    LoadingSubtitle = "Loading modules...",
    ConfigurationSaving = { Enabled = true, FolderName = "JitlerHub", FileName = "Default" },
    SettingsIcon = "rbxassetid://7734053495",
})

local available = Hub.AvailableModules or { ESP = true, Combat = true, Movement = true, Farming = true, Missions = true, UI = true }
local MainTab = Window:CreateTab({ Name = "Main", Icon = "rbxassetid://11347112400" })
local ESPTab = available.ESP and Window:CreateTab({ Name = "ESP", Icon = "rbxassetid://6523858394" })
local AutoFarmTab = available.Farming and Window:CreateTab({ Name = "AutoFarm", Icon = "rbxassetid://130840043704422" })
local TeleportTab = Window:CreateTab({ Name = "Teleports", Icon = "rbxassetid://139799091866771" })

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
-- FOOTER
-- ================================================================
Notify("Jitler Hub v2.0.0 - Cursed Gear loaded!", 3)
print("=== Jitler Hub v2.0.0 - Cursed Gear Loaded ===")
