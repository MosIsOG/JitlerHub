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
loadstring(game:HttpGet(BASE .. 'esp.lua'))()
loadstring(game:HttpGet(BASE .. 'combat.lua'))()
loadstring(game:HttpGet(BASE .. 'movement.lua'))()
loadstring(game:HttpGet(BASE .. 'farming.lua'))()
loadstring(game:HttpGet(BASE .. 'missions.lua'))()
loadstring(game:HttpGet(BASE .. 'ui.lua'))()
