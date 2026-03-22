-- Jitler Hub v2.1 - Multi-Module Loader
local JitlerUI = loadstring(game:HttpGet('https://raw.githubusercontent.com/MosIsOG/JitlerUI/refs/heads/main/JitlerUI.lua'))()
pcall(function() loadstring(game:HttpGet("https://raw.githubusercontent.com/MosIsOG/playground/refs/heads/main/chakra_sense.lua"))() end)

local cloneref = cloneref or function(o) return o end
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local HttpService = cloneref(game:GetService("HttpService"))
local TweenService = cloneref(game:GetService("TweenService"))
local VirtualInput = game:GetService("VirtualInputManager")

local EventsFolder = ReplicatedStorage:FindFirstChild("Events")
local DataEvent = EventsFolder and EventsFolder:FindFirstChild("DataEvent")
local DataFunction = EventsFolder and EventsFolder:FindFirstChild("DataFunction")

shared.JitlerHub = {
    JitlerUI = JitlerUI, cloneref = cloneref,
    Players = Players, RunService = RunService, UserInputService = UserInputService,
    ReplicatedStorage = ReplicatedStorage, Lighting = Lighting,
    LocalPlayer = LocalPlayer, Camera = Camera,
    HttpService = HttpService, TweenService = TweenService, VirtualInput = VirtualInput,
    EventsFolder = EventsFolder, DataEvent = DataEvent, DataFunction = DataFunction,
    ESPTextColor = Color3.fromRGB(255, 255, 255),
    FullBrightLevel = 2, FullBrightEnabled = false,
}
local Hub = shared.JitlerHub

function Hub.RefreshDataEvent()
    if not Hub.DataEvent then
        Hub.EventsFolder = ReplicatedStorage:FindFirstChild("Events")
        Hub.DataEvent = Hub.EventsFolder and Hub.EventsFolder:FindFirstChild("DataEvent")
    end
    return Hub.DataEvent
end

function Hub.RefreshDataFunction()
    if not Hub.DataFunction then
        Hub.EventsFolder = ReplicatedStorage:FindFirstChild("Events")
        Hub.DataFunction = Hub.EventsFolder and Hub.EventsFolder:FindFirstChild("DataFunction")
    end
    return Hub.DataFunction
end

function Hub.Notify(msg, dur)
    JitlerUI:Notify({Title="Jitler Hub", Content=tostring(msg), Duration=dur or 3})
end

function Hub.Format(f, ...) return string.format(f, ...) end

function Hub.PressE()
    pcall(function() VirtualInput:SendKeyEvent(true, Enum.KeyCode.E, false, game); task.wait(0.15); VirtualInput:SendKeyEvent(false, Enum.KeyCode.E, false, game) end)
end

function Hub.TeleportTo(pos)
    local char = LocalPlayer.Character; if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head"); if root then root.CFrame = CFrame.new(pos) end
end

local BASE = 'https://raw.githubusercontent.com/MosIsOG/JitlerHub/refs/heads/master/modules/'

local function LoadModule(modName)
    local ok, err = pcall(function()
        loadstring(game:HttpGet(BASE .. modName))()
    end)
    if not ok then
        Hub.Notify("Jitler Hub: failed to load module " .. modName .. " (" .. tostring(err) .. ")", 5)
    end
end

local placeId = game.PlaceId
local fullModules = { 'esp.lua', 'combat.lua', 'movement.lua', 'farming.lua', 'missions.lua', 'ui.lua' }
local baseModules = { 'esp.lua', 'movement.lua', 'ui.lua' }

if placeId == 5571328985 then
    for _, mod in ipairs(fullModules) do
        LoadModule(mod)
    end
    Hub.Notify("Jitler Hub: full support loaded for place " .. placeId, 3)
elseif placeId == 10154506972 then
    for _, mod in ipairs(baseModules) do
        LoadModule(mod)
    end
    Hub.Notify("Jitler Hub: base support loaded for place " .. placeId, 3)
else
    for _, mod in ipairs(fullModules) do
        LoadModule(mod)
    end
    Hub.Notify("Jitler Hub: default full support loaded for place " .. placeId, 3)
end
