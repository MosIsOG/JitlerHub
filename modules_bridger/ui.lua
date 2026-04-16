-- Ensure 'shared' is defined for environments where it may be missing
if not shared then shared = {} end

-- Jitler Hub - UI Module (Bridger)
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
    Name = "Jitler Hub v2.0.0 - Bridger",
    Icon = "rbxassetid://124980045936567",
    LoadingTitle = "Jitler Hub",
    LoadingSubtitle = "Loading modules...",
    ConfigurationSaving = { Enabled = true, FolderName = "JitlerHub", FileName = "Bridger" },
    SettingsIcon = "rbxassetid://7734053495",
})

local available = Hub.AvailableModules or { ESP = true, Movement = true, UI = true }
local MainTab = Window:CreateTab({ Name = "Main", Icon = "rbxassetid://11347112400", Section = "Main" })
local ESPTab = available.ESP and Window:CreateTab({ Name = "ESP", Icon = "rbxassetid://6523858394", Section = "Main" })
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

MLeft:CreateToggleWithKeybind({ Name = "Fly", Description = "Fly freely in any direction", CurrentValue = false, Flag = "Fly", Callback = function(v) Hub.FlySystem.Enabled = v; if v then Hub.StartFlying() else Hub.StopFlying() end end }, { CurrentKeybind = "Y", Flag = "FlyKey" })
MLeft:CreateSlider({ Name = "Fly Speed", Range = { 10, 300 }, Increment = 5, Suffix = "", CurrentValue = 50, Flag = "FlySpeed", Callback = function(v) Hub.FlySystem.Speed = v end })

MLeft:CreateToggleWithKeybind({ Name = "Infinite Jump", CurrentValue = false, Flag = "InfJump", Callback = function(v) _G.InfiniteJump = v end }, { CurrentKeybind = "Period", Flag = "InfJumpKey" })

MLeft:CreateToggleWithKeybind({ Name = "Noclip", Description = "Walk through walls", CurrentValue = false, Flag = "Noclip", Callback = function(v) _G.Noclip = v end }, { CurrentKeybind = "N", Flag = "NoclipKey" })


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


QRight:CreateSection("Utility")

QRight:CreateButton({ Name = "Reset Character", Callback = function() local char = LocalPlayer.Character; if char and char:FindFirstChild("Humanoid") then char.Humanoid.Health = 0; task.wait(1); char:BreakJoints() end end })
QRight:CreateButton({ Name = "Random Server Hop", Callback = function() Hub.DoServerHop("random") end })
QRight:CreateButton({ Name = "Low Player Server", Callback = function() Hub.DoServerHop("min") end })

end

-- ================================================================
-- FOOTER
-- ================================================================
Notify("Jitler Hub v2.0.0 - Bridger loaded!", 3)
print("=== Jitler Hub v2.0.0 - Bridger Loaded ===")
