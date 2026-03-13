-- Jitler Hub v2.0 - JitlerUI + Unnamed ESP Core
-- Complete rewrite: reorganized tabs, fixed NoFall, Bulk Seller, Mob ESP, Visual Features

local JitlerUI = loadstring(game:HttpGet('https://raw.githubusercontent.com/MosIsOG/JitlerUI/refs/heads/main/JitlerUI.lua'))()
pcall(function() loadstring(game:HttpGet("https://raw.githubusercontent.com/MosIsOG/playground/refs/heads/main/chakra_sense.lua"))() end)

-- Services
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

-- Shared remotes
local EventsFolder = ReplicatedStorage:FindFirstChild("Events")
local DataEvent = EventsFolder and EventsFolder:FindFirstChild("DataEvent")
local DataFunction = EventsFolder and EventsFolder:FindFirstChild("DataFunction")

local function RefreshDataEvent()
    if not DataEvent then
        EventsFolder = ReplicatedStorage:FindFirstChild("Events")
        DataEvent = EventsFolder and EventsFolder:FindFirstChild("DataEvent")
    end
    return DataEvent
end

local function Notify(msg, dur)
    JitlerUI:Notify({Title="Jitler Hub", Content=tostring(msg), Duration=dur or 3})
end

local function Format(f, ...) return string.format(f, ...) end

-- ================================================================
-- ESP CORE (Unnamed ESP adapted)
-- ================================================================
assert(Drawing, "exploit not supported")

local V2New = Vector2.new
local V3New = Vector3.new
local WTVP = Camera.WorldToViewportPoint
local WorldToViewport = function(...) return WTVP(Camera, ...) end
local Menu = {}
local LastRefresh = 0
local OIndex = 0
local LineBox = {}
local IgnoreList = {}
local EnemyColor = Color3.new(1, 0, 0)
local TeamColor = Color3.new(0, 1, 0)
local TracerPosition = V2New(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y - 135)
local Connections = { Active = {} }
local Mouse = pcall(function() return LocalPlayer:GetMouse() end) and LocalPlayer:GetMouse() or nil
local Terrain = workspace:FindFirstChild("Terrain")
local QUAD_SUPPORTED_EXPLOIT = pcall(function() Drawing.new("Quad"):Remove() end)

-- Clean up stale Drawing objects
if shared.InstanceData then
    for _, v in pairs(shared.InstanceData) do
        if v.Instances then
            for _, obj in pairs(v.Instances) do
                pcall(function()
                    if typeof(obj) == "table" and obj.SetVisible then obj:SetVisible(false); obj:Remove()
                    elseif typeof(obj) == "userdata" or (typeof(obj) == "table" and obj.Remove) then
                        pcall(function() obj.Visible = false end); pcall(function() obj:Remove() end)
                    end
                end)
            end
        end
    end
end
if shared.MenuDrawingData and shared.MenuDrawingData.Instances then
    for _, inst in pairs(shared.MenuDrawingData.Instances) do pcall(function() inst.Visible = false; inst:Remove() end) end
end

shared.MenuDrawingData = { Instances = {} }
shared.InstanceData = {}
shared.RSName = shared.RSName or ("UnnamedESP_by_ic3-" .. HttpService:GenerateGUID(false))
local GetDataName = shared.RSName .. "-GetData"
local UpdateName = shared.RSName .. "-Update"

local function Set(t, i, v) t[i] = v end
local function GetCharacter(Player) return Player.Character end

local RenderList = { Instances = {} }
function RenderList:AddOrUpdateInstance(Instance, Obj2Draw, Text, Color)
    RenderList.Instances[Instance] = { ParentInstance = Instance, Instance = Obj2Draw, Text = Text, Color = Color }
    return RenderList.Instances[Instance]
end

-- Options system
local Options = setmetatable({}, {
    __call = function(t, ...)
        local args = {...}; OIndex = OIndex + 1
        rawset(t, args[1], setmetatable({
            Name = args[1], Text = args[2], Value = args[3], DefaultValue = args[3], AllArgs = args, Index = OIndex,
        }, {
            __call = function(t2, v)
                if typeof(t2.Value) == "function" then t2.Value()
                elseif typeof(t2.Value) ~= "EnumItem" then
                    rawset(t2, "Value", v ~= nil and v or not t2.Value)
                end
            end,
        }))
    end,
})

-- ESP Options
Options("Enabled", "ESP Enabled", true)
Options("ShowTeam", "Show Team", true)
Options("ShowTeamColor", "Show Team Color", false)
Options("ShowName", "Show Names", true)
Options("ShowDistance", "Show Distance", true)
Options("ShowHealth", "Show Health", true)
Options("ShowBoxes", "Show Boxes", false)
Options("ShowTracers", "Show Tracers", false)
Options("ShowDot", "Show Head Dot", false)
Options("VisCheck", "Visibility Check", false)
Options("Crosshair", "Crosshair", false)
Options("TextOutline", "Text Outline", true)
Options("TextSize", "Text Size", 14, 10, 24)
Options("MaxDistance", "Max Distance", 2500, 100, 25000)
Options("RefreshRate", "Refresh Rate (ms)", 5, 1, 200)
Options("YOffset", "Y Offset", 0, -200, 200)
Options("ShowCustomHealthbar", "Show Healthbars", true)
Options("HealthbarWidth", "Healthbar Width", 40, 30, 100)
Options("HealthbarHeight", "Healthbar Height", 2, 2, 10)
Options("HealthbarOffset", "Healthbar Offset", 30, 30, 100)
Options("MenuOpen", nil, false)

-- Custom Healthbar
local HealthbarObjects = {}
local function CreateHealthbar(player)
    if player == LocalPlayer then return end
    if HealthbarObjects[player] then
        pcall(function() if HealthbarObjects[player].Background then HealthbarObjects[player].Background:Remove() end; if HealthbarObjects[player].Fill then HealthbarObjects[player].Fill:Remove() end end)
    end
    local hb = { Background = Drawing.new("Square"), Fill = Drawing.new("Square") }
    hb.Background.Filled = true; hb.Background.Color = Color3.fromRGB(30, 30, 30); hb.Background.Transparency = 0.5; hb.Background.Visible = false
    hb.Fill.Filled = true; hb.Fill.Visible = false
    HealthbarObjects[player] = hb
    return hb
end

-- Drawing helpers
function GetTableData(t)
    if typeof(t) ~= "table" then return end
    return setmetatable(t, { __call = function(t2, func) if typeof(func) ~= "function" then return end; for i, v in pairs(t2) do pcall(func, i, v) end end })
end

function NewDrawing(InstanceName)
    local inst = Drawing.new(InstanceName)
    return function(Properties) for i, v in pairs(Properties) do pcall(Set, inst, i, v) end; return inst end
end

function Menu:AddMenuInstance(Name, DrawingType, Properties)
    local inst = shared.MenuDrawingData.Instances[Name]
    if inst then for i, v in pairs(Properties) do pcall(Set, inst, i, v) end
    else inst = NewDrawing(DrawingType)(Properties) end
    shared.MenuDrawingData.Instances[Name] = inst; return inst
end
function Menu:GetInstance(Name) return shared.MenuDrawingData.Instances[Name] end

-- LineBox
function LineBox:Create(Properties)
    local Box = { Visible = true }
    local Props = { Transparency = 1, Thickness = 3, Visible = true }
    if QUAD_SUPPORTED_EXPLOIT then Box.Quad = NewDrawing("Quad")(Props)
    else Box.TopLeft = NewDrawing("Line")(Props); Box.TopRight = NewDrawing("Line")(Props); Box.BottomLeft = NewDrawing("Line")(Props); Box.BottomRight = NewDrawing("Line")(Props) end

    function Box:Update(CF, Size, Color)
        if not CF or not Size then return end
        local TLPos, V1 = WorldToViewport((CF * CFrame.new(Size.X, Size.Y, 0)).Position)
        local TRPos, V2 = WorldToViewport((CF * CFrame.new(-Size.X, Size.Y, 0)).Position)
        local BLPos, V3 = WorldToViewport((CF * CFrame.new(Size.X, -Size.Y, 0)).Position)
        local BRPos, V4 = WorldToViewport((CF * CFrame.new(-Size.X, -Size.Y, 0)).Position)
        if QUAD_SUPPORTED_EXPLOIT then
            if V1 and V2 and V3 and V4 then Box.Quad.Visible = true; Box.Quad.Color = Color; Box.Quad.PointA = V2New(TLPos.X, TLPos.Y); Box.Quad.PointB = V2New(TRPos.X, TRPos.Y); Box.Quad.PointC = V2New(BRPos.X, BRPos.Y); Box.Quad.PointD = V2New(BLPos.X, BLPos.Y)
            else Box.Quad.Visible = false end
        else
            V1 = TLPos.Z > 0; V2 = TRPos.Z > 0; V3 = BLPos.Z > 0; V4 = BRPos.Z > 0
            if V1 then Box.TopLeft.Visible = true; Box.TopLeft.Color = Color; Box.TopLeft.From = V2New(TLPos.X, TLPos.Y); Box.TopLeft.To = V2New(TRPos.X, TRPos.Y) else Box.TopLeft.Visible = false end
            if V2 then Box.TopRight.Visible = true; Box.TopRight.Color = Color; Box.TopRight.From = V2New(TRPos.X, TRPos.Y); Box.TopRight.To = V2New(BRPos.X, BRPos.Y) else Box.TopRight.Visible = false end
            if V3 then Box.BottomLeft.Visible = true; Box.BottomLeft.Color = Color; Box.BottomLeft.From = V2New(BLPos.X, BLPos.Y); Box.BottomLeft.To = V2New(TLPos.X, TLPos.Y) else Box.BottomLeft.Visible = false end
            if V4 then Box.BottomRight.Visible = true; Box.BottomRight.Color = Color; Box.BottomRight.From = V2New(BRPos.X, BRPos.Y); Box.BottomRight.To = V2New(BLPos.X, BLPos.Y) else Box.BottomRight.Visible = false end
        end
    end
    function Box:SetVisible(bool)
        if self.Quad then self.Quad.Visible = bool
        elseif self.TopLeft then self.TopLeft.Visible = bool; self.TopRight.Visible = bool; self.BottomLeft.Visible = bool; self.BottomRight.Visible = bool end
    end
    function Box:Remove()
        self:SetVisible(false)
        if self.Quad then Box.Quad:Remove()
        elseif self.TopLeft then self.TopLeft:Remove(); self.TopRight:Remove(); self.BottomLeft:Remove(); self.BottomRight:Remove() end
    end
    return Box
end

function Connections:Listen(Connection, Function) local c = Connection:Connect(Function); table.insert(self.Active, c); return c end
function Connections:DisconnectAll() for _, c in pairs(self.Active) do if c.Connected then c:Disconnect() end end; self.Active = {} end

local function CameraCon()
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        TracerPosition = V2New(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y - 135)
    end)
end
CameraCon()

local LastRayIgnoreUpdate, RayIgnoreList = 0, {}
local function CheckRay(Instance, Distance, Position, Unit)
    if Distance > 999 then return false end
    local Model = Instance
    if Instance.ClassName == "Player" then Model = GetCharacter(Instance) end
    if not Model then Model = Instance.Parent; if Model.Parent == workspace then Model = Instance end end
    if not Model then return false end
    if tick() - LastRayIgnoreUpdate > 3 then
        LastRayIgnoreUpdate = tick(); table.clear(RayIgnoreList)
        table.insert(RayIgnoreList, LocalPlayer.Character); table.insert(RayIgnoreList, Camera)
        if Mouse and Mouse.TargetFilter then table.insert(RayIgnoreList, Mouse.TargetFilter) end
        while #IgnoreList > 64 do table.remove(IgnoreList, 1) end
        for _, v in pairs(IgnoreList) do table.insert(RayIgnoreList, v) end
    end
    local Hit = workspace:FindPartOnRayWithIgnoreList(Ray.new(Position, Unit * Distance), RayIgnoreList)
    if Hit and not Hit:IsDescendantOf(Model) then
        if Hit.Transparency >= 0.3 or not Hit.CanCollide and Hit.ClassName ~= Terrain then table.insert(IgnoreList, Hit) end
        return false
    end
    return true
end

local function CheckTeam(Player)
    if Player.Neutral and LocalPlayer.Neutral then return true end
    return Player.TeamColor == LocalPlayer.TeamColor
end

local function CheckPlayer(Player, Character)
    if not Options.Enabled.Value then return false, 0 end
    if Player == LocalPlayer or not Character then return false, 0 end
    if not Options.ShowTeam.Value and CheckTeam(Player) then return false, 0 end
    local Head = Character:FindFirstChild("Head"); if not Head then return false, 0 end
    local Distance = (Camera.CFrame.Position - Head.Position).Magnitude
    if Options.VisCheck.Value and not CheckRay(Player, Distance, Camera.CFrame.Position, (Head.Position - Camera.CFrame.Position).unit) then return false, 0 end
    if Distance > Options.MaxDistance.Value then return false, 0 end
    return true, Distance
end

local function CheckDistance(Instance)
    if not Options.Enabled.Value or not Instance then return false, 0 end
    local Distance = (Camera.CFrame.Position - Instance.Position).Magnitude
    if Options.VisCheck.Value and not CheckRay(Instance, Distance, Camera.CFrame.Position, (Instance.Position - Camera.CFrame.Position).unit) then return false, 0 end
    if Distance > Options.MaxDistance.Value then return false, 0 end
    return true, Distance
end

-- ESP text color (user-configurable)
local ESPTextColor = Color3.fromRGB(255, 255, 255)

-- Main ESP render
local function UpdatePlayerData()
    if (tick() - LastRefresh) <= (Options.RefreshRate.Value / 1000) then return end
    LastRefresh = tick()

    -- RenderList instances
    for _, v in pairs(RenderList.Instances) do
        pcall(function()
            if v.Instance and v.Instance.Parent and v.Instance:IsA("BasePart") then
                local Data = shared.InstanceData[v.Instance:GetDebugId()] or { Instances = {}, DontDelete = true }
                Data.Instance = v.Instance
                Data.Instances.OutlineTracer = Data.Instances.OutlineTracer or NewDrawing("Line")({ Transparency = 0.75, Thickness = 5, Color = Color3.new(0.1, 0.1, 0.1) })
                Data.Instances.Tracer = Data.Instances.Tracer or NewDrawing("Line")({ Transparency = 1, Thickness = 2 })
                Data.Instances.NameTag = Data.Instances.NameTag or NewDrawing("Text")({ Size = Options.TextSize.Value, Center = true, Outline = Options.TextOutline.Value, Visible = true })
                Data.Instances.DistanceTag = Data.Instances.DistanceTag or NewDrawing("Text")({ Size = Options.TextSize.Value - 1, Center = true, Outline = Options.TextOutline.Value, Visible = true })
                local NameTag, DistanceTag = Data.Instances.NameTag, Data.Instances.DistanceTag
                local Tracer, OutlineTracer = Data.Instances.Tracer, Data.Instances.OutlineTracer
                local Pass, Distance = CheckDistance(v.Instance)
                if Pass then
                    local ScreenPosition = WorldToViewport(v.Instance.Position)
                    local OPos = Camera.CFrame:pointToObjectSpace(v.Instance.Position)
                    if ScreenPosition.Z < 0 then local AT = math.atan2(OPos.Y, OPos.X) + math.pi; OPos = CFrame.Angles(0, 0, AT):vectorToWorldSpace(CFrame.Angles(0, math.rad(89.9), 0):vectorToWorldSpace(V3New(0, 0, -1))) end
                    local Position = WorldToViewport(Camera.CFrame:pointToWorldSpace(OPos))
                    if Options.ShowTracers.Value then Tracer.Visible = true; Tracer.Transparency = math.clamp(Distance / 200, 0.45, 0.8); Tracer.From = TracerPosition; Tracer.To = V2New(Position.X, Position.Y); Tracer.Color = v.Color; OutlineTracer.Visible = true; OutlineTracer.Transparency = Tracer.Transparency - 0.1; OutlineTracer.From = Tracer.From; OutlineTracer.To = Tracer.To
                    else Tracer.Visible = false; OutlineTracer.Visible = false end
                    if ScreenPosition.Z > 0 then
                        if Options.ShowName.Value then LocalPlayer.NameDisplayDistance = 0; NameTag.Visible = true; NameTag.Text = v.Text; NameTag.Size = Options.TextSize.Value; NameTag.Outline = Options.TextOutline.Value; NameTag.Position = V2New(ScreenPosition.X, ScreenPosition.Y); NameTag.Color = v.Color
                        else LocalPlayer.NameDisplayDistance = 100; NameTag.Visible = false end
                        if Options.ShowDistance.Value then DistanceTag.Visible = true; DistanceTag.Size = Options.TextSize.Value - 1; DistanceTag.Color = Color3.new(1, 1, 1); DistanceTag.Text = Format("[%d] ", Distance); DistanceTag.Position = V2New(ScreenPosition.X, ScreenPosition.Y) + V2New(0, NameTag.TextBounds.Y)
                        else DistanceTag.Visible = false end
                    else NameTag.Visible = false; DistanceTag.Visible = false end
                else NameTag.Visible = false; DistanceTag.Visible = false; Tracer.Visible = false; OutlineTracer.Visible = false end
                shared.InstanceData[v.Instance:GetDebugId()] = Data
            end
        end)
    end

    -- Player ESP
    for _, v in pairs(Players:GetPlayers()) do
        pcall(function()
            local Data = shared.InstanceData[v.Name] or { Instances = {} }
            Data.Instances.Box = Data.Instances.Box or LineBox:Create({ Thickness = 4 })
            Data.Instances.OutlineTracer = Data.Instances.OutlineTracer or NewDrawing("Line")({ Transparency = 1, Thickness = 3, Color = Color3.new(0.1, 0.1, 0.1) })
            Data.Instances.Tracer = Data.Instances.Tracer or NewDrawing("Line")({ Transparency = 1, Thickness = 1 })
            Data.Instances.HeadDot = Data.Instances.HeadDot or NewDrawing("Circle")({ Filled = true, NumSides = 30 })
            Data.Instances.NameTag = Data.Instances.NameTag or NewDrawing("Text")({ Size = Options.TextSize.Value, Center = true, Outline = Options.TextOutline.Value, OutlineOpacity = 1, Visible = true })
            Data.Instances.DistanceHealthTag = Data.Instances.DistanceHealthTag or NewDrawing("Text")({ Size = Options.TextSize.Value - 1, Center = true, Outline = Options.TextOutline.Value, OutlineOpacity = 1, Visible = true })

            local NameTag = Data.Instances.NameTag
            local DistanceTag = Data.Instances.DistanceHealthTag
            local Tracer = Data.Instances.Tracer
            local OutlineTracer = Data.Instances.OutlineTracer
            local HeadDot = Data.Instances.HeadDot
            local Box = Data.Instances.Box
            local Character = GetCharacter(v)
            local Pass, Distance = CheckPlayer(v, Character)

            if Pass and Character then
                local Humanoid = Character:FindFirstChildOfClass("Humanoid")
                local Head = Character:FindFirstChild("Head")
                local HRP = Character:FindFirstChild("HumanoidRootPart")
                local Dead = Humanoid and Humanoid:GetState().Name == "Dead"

                if Head and HRP and not Dead then
                    local ScreenPosition, Vis = WorldToViewport(Head.Position)
                    local Color = CheckTeam(v) and TeamColor or EnemyColor
                    Color = Options.ShowTeamColor.Value and v.TeamColor.Color or Color
                    local OPos = Camera.CFrame:pointToObjectSpace(Head.Position)
                    if ScreenPosition.Z < 0 then local AT = math.atan2(OPos.Y, OPos.X) + math.pi; OPos = CFrame.Angles(0, 0, AT):vectorToWorldSpace(CFrame.Angles(0, math.rad(89.9), 0):vectorToWorldSpace(V3New(0, 0, -1))) end
                    local Position = WorldToViewport(Camera.CFrame:pointToWorldSpace(OPos))

                    if Options.ShowTracers.Value then
                        if TracerPosition.X >= Camera.ViewportSize.X or TracerPosition.Y >= Camera.ViewportSize.Y or TracerPosition.X < 0 or TracerPosition.Y < 0 then TracerPosition = V2New(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y - 135) end
                        Tracer.Visible = true; Tracer.Transparency = math.clamp(1 - Distance / 200, 0.25, 0.75); Tracer.From = TracerPosition; Tracer.To = V2New(Position.X, Position.Y); Tracer.Color = Color
                        OutlineTracer.From = Tracer.From; OutlineTracer.To = Tracer.To; OutlineTracer.Transparency = Tracer.Transparency - 0.15; OutlineTracer.Visible = true
                    else Tracer.Visible = false; OutlineTracer.Visible = false end

                    if ScreenPosition.Z > 0 then
                        local ScreenPositionUpper = WorldToViewport((HRP:GetRenderCFrame() * CFrame.new(0, Head.Size.Y + HRP.Size.Y + Options.YOffset.Value / 25, 0)).Position)
                        local Scale = Head.Size.Y / 2

                        if Options.ShowName.Value then
                            NameTag.Visible = true; NameTag.Text = v.Name; NameTag.Size = Options.TextSize.Value; NameTag.Outline = Options.TextOutline.Value
                            NameTag.Position = V2New(ScreenPositionUpper.X, ScreenPositionUpper.Y) - V2New(0, NameTag.TextBounds.Y)
                            NameTag.Color = ESPTextColor; NameTag.OutlineColor = Color3.new(0.05, 0.05, 0.05); NameTag.Transparency = 0.85
                        else NameTag.Visible = false end

                        if Options.ShowDistance.Value or Options.ShowHealth.Value then
                            DistanceTag.Visible = true; DistanceTag.Size = Options.TextSize.Value - 1; DistanceTag.Outline = Options.TextOutline.Value
                            DistanceTag.Color = ESPTextColor; DistanceTag.Transparency = 0.85
                            local Str = ""
                            if Options.ShowDistance.Value then Str = Str .. Format("[%d] ", Distance) end
                            if Options.ShowHealth.Value and typeof(Humanoid) == "Instance" then Str = Str .. Format("[%d/%d] [%s%%]", Humanoid.Health, Humanoid.MaxHealth, math.floor(Humanoid.Health / Humanoid.MaxHealth * 100)) end
                            DistanceTag.Text = Str; DistanceTag.OutlineColor = Color3.new(0.05, 0.05, 0.05)
                            DistanceTag.Position = NameTag.Visible and NameTag.Position + V2New(0, NameTag.TextBounds.Y) or V2New(ScreenPositionUpper.X, ScreenPositionUpper.Y)
                        else DistanceTag.Visible = false end

                        if Options.ShowDot.Value and Vis then
                            local Top = WorldToViewport((Head.CFrame * CFrame.new(0, Scale, 0)).Position)
                            local Bottom = WorldToViewport((Head.CFrame * CFrame.new(0, -Scale, 0)).Position)
                            HeadDot.Visible = true; HeadDot.Color = Color; HeadDot.Position = V2New(ScreenPosition.X, ScreenPosition.Y); HeadDot.Radius = math.abs((Top - Bottom).Y)
                        else HeadDot.Visible = false end

                        if Options.ShowBoxes.Value and Vis and HRP then Box:Update(HRP.CFrame, V3New(2, 3, 1) * (Scale * 2), Color) else Box:SetVisible(false) end
                    else NameTag.Visible = false; DistanceTag.Visible = false; HeadDot.Visible = false; Box:SetVisible(false) end
                else NameTag.Visible = false; DistanceTag.Visible = false; HeadDot.Visible = false; Tracer.Visible = false; OutlineTracer.Visible = false; Box:SetVisible(false) end
            else NameTag.Visible = false; DistanceTag.Visible = false; HeadDot.Visible = false; Tracer.Visible = false; OutlineTracer.Visible = false; Box:SetVisible(false) end
            shared.InstanceData[v.Name] = Data
        end)
    end
end

-- Healthbar update
local LastInvalidCheck = 0
local function UpdateHealthbars()
    if not Options.Enabled.Value or not Options.ShowCustomHealthbar.Value then
        for _, hb in pairs(HealthbarObjects) do if hb.Background then hb.Background.Visible = false end; if hb.Fill then hb.Fill.Visible = false end end; return
    end
    for player, hb in pairs(HealthbarObjects) do
        if not player or not player.Character then if hb.Background then hb.Background.Visible = false end; if hb.Fill then hb.Fill.Visible = false end; continue end
        local character = player.Character; local humanoid = character:FindFirstChild("Humanoid"); local head = character:FindFirstChild("Head")
        if not (humanoid and head and humanoid.Health > 0) then if hb.Background then hb.Background.Visible = false end; if hb.Fill then hb.Fill.Visible = false end; continue end
        local headPos, onScreen = Camera:WorldToViewportPoint(head.Position)
        if onScreen then
            local hp = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
            local bW, bH = Options.HealthbarWidth.Value, Options.HealthbarHeight.Value
            local bX, bY = headPos.X - bW / 2, headPos.Y - Options.HealthbarOffset.Value
            hb.Background.Visible = true; hb.Background.Size = Vector2.new(bW, bH); hb.Background.Position = Vector2.new(bX, bY)
            hb.Fill.Visible = true; hb.Fill.Size = Vector2.new(bW * hp, bH); hb.Fill.Position = Vector2.new(bX, bY)
            hb.Fill.Color = hp > 0.6 and Color3.fromRGB(0, 255, 0) or hp > 0.3 and Color3.fromRGB(255, 255, 0) or Color3.fromRGB(255, 0, 0)
        else hb.Background.Visible = false; hb.Fill.Visible = false end
    end
end

local function Update()
    if tick() - LastInvalidCheck > 0.3 then
        LastInvalidCheck = tick()
        if Camera.Parent ~= workspace then Camera = workspace.CurrentCamera; CameraCon(); WTVP = Camera.WorldToViewportPoint end
        for i, v in pairs(shared.InstanceData) do
            if not Players:FindFirstChild(tostring(i)) then
                if not v.DontDelete then GetTableData(v.Instances)(function(idx, obj) obj.Visible = false; obj:Remove(); v.Instances[idx] = nil end); shared.InstanceData[i] = nil
                elseif not v.Instance or not v.Instance.Parent then GetTableData(v.Instances)(function(idx, obj) obj.Visible = false; obj:Remove(); v.Instances[idx] = nil end); shared.InstanceData[i] = nil end
            end
        end
    end
    local CX, CY = Menu:GetInstance("CrosshairX"), Menu:GetInstance("CrosshairY")
    if Options.Crosshair.Value then
        if not CX then Menu:AddMenuInstance("CrosshairX", "Line", { Visible = false }); Menu:AddMenuInstance("CrosshairY", "Line", { Visible = false }); CX = Menu:GetInstance("CrosshairX"); CY = Menu:GetInstance("CrosshairY") end
        CX.Visible = true; CY.Visible = true
        CX.To = V2New(Camera.ViewportSize.X / 2 - 8, Camera.ViewportSize.Y / 2); CX.From = V2New(Camera.ViewportSize.X / 2 + 8, Camera.ViewportSize.Y / 2)
        CY.To = V2New(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2 - 8); CY.From = V2New(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2 + 8)
    else if CX then CX.Visible = false end; if CY then CY.Visible = false end end
    UpdateHealthbars()
end

-- Init healthbars + render bindings
for _, player in ipairs(Players:GetPlayers()) do if player ~= LocalPlayer then CreateHealthbar(player) end end
Players.PlayerAdded:Connect(function(player) if player ~= LocalPlayer then task.wait(0.5); CreateHealthbar(player); player.CharacterAdded:Connect(function() task.wait(0.5); CreateHealthbar(player) end) end end)
Players.PlayerRemoving:Connect(function(player) local hb = HealthbarObjects[player]; if hb then pcall(function() if hb.Background then hb.Background:Remove() end; if hb.Fill then hb.Fill:Remove() end end); HealthbarObjects[player] = nil end end)

RunService:UnbindFromRenderStep(GetDataName); RunService:UnbindFromRenderStep(UpdateName)
RunService:BindToRenderStep(GetDataName, 300, UpdatePlayerData); RunService:BindToRenderStep(UpdateName, 199, Update)

-- ================================================================
-- PLAYER HIGHLIGHT SYSTEM
-- ================================================================
local PlayerHighlight = {
    Enabled = false, Objects = {},
    FillColor = Color3.fromRGB(130, 100, 210), FillTransparency = 0.7,
    OutlineColor = Color3.fromRGB(255, 255, 255), OutlineTransparency = 0,
    MaxDistance = 2500, Connection = nil,
}

local function UpdatePlayerHighlights()
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local char = player.Character
        if not char then
            if PlayerHighlight.Objects[player] then pcall(function() PlayerHighlight.Objects[player]:Destroy() end); PlayerHighlight.Objects[player] = nil end
            continue
        end
        local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
        local inRange = root and (Camera.CFrame.Position - root.Position).Magnitude <= PlayerHighlight.MaxDistance
        if PlayerHighlight.Enabled and inRange then
            local hl = PlayerHighlight.Objects[player]
            if not hl or hl.Parent ~= char then
                if hl then pcall(function() hl:Destroy() end) end
                hl = Instance.new("Highlight"); hl.Name = "JitlerHL"; hl.Parent = char
                PlayerHighlight.Objects[player] = hl
            end
            hl.FillColor = PlayerHighlight.FillColor; hl.FillTransparency = PlayerHighlight.FillTransparency
            hl.OutlineColor = PlayerHighlight.OutlineColor; hl.OutlineTransparency = PlayerHighlight.OutlineTransparency
        else
            if PlayerHighlight.Objects[player] then pcall(function() PlayerHighlight.Objects[player]:Destroy() end); PlayerHighlight.Objects[player] = nil end
        end
    end
end

local function StartPlayerHighlight()
    if PlayerHighlight.Connection then PlayerHighlight.Connection:Disconnect() end
    PlayerHighlight.Connection = RunService.Heartbeat:Connect(UpdatePlayerHighlights)
end

local function StopPlayerHighlight()
    PlayerHighlight.Enabled = false
    if PlayerHighlight.Connection then PlayerHighlight.Connection:Disconnect(); PlayerHighlight.Connection = nil end
    for _, hl in pairs(PlayerHighlight.Objects) do pcall(function() hl:Destroy() end) end
    PlayerHighlight.Objects = {}
end

-- ================================================================
-- MOB ESP SYSTEM (Drawing-based, replaces Boss Detection)
-- ================================================================
local MobESP = { Enabled = false, MaxDistance = 500, TextSize = 14, ScanInterval = 2, TrackedMobs = {}, ScanThread = nil, RenderConn = nil }
local MOB_FOLDERS = { "NPCs", "Mobs", "Enemies" }

local function ScanMobs()
    if not MobESP.Enabled then return end
    local lc = LocalPlayer.Character; if not lc then return end
    local lr = lc:FindFirstChild("HumanoidRootPart") or lc:FindFirstChild("Head"); if not lr then return end
    local pp = lr.Position; local seen = {}

    local function tryTrack(model)
        if not model:IsA("Model") or seen[model] or model == lc then return end
        seen[model] = true
        local isPlayer = false
        for _, p in ipairs(Players:GetPlayers()) do if p.Character == model then isPlayer = true; break end end
        if isPlayer then return end
        local hum = model:FindFirstChildOfClass("Humanoid"); if not hum or hum.Health <= 0 then return end
        local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head") or model:FindFirstChildWhichIsA("BasePart"); if not root then return end
        if (pp - root.Position).Magnitude > MobESP.MaxDistance then return end
        if not MobESP.TrackedMobs[model] then
            local txt = Drawing.new("Text"); txt.Center = true; txt.Outline = true; txt.OutlineColor = Color3.new(0, 0, 0)
            txt.Color = Color3.fromRGB(255, 150, 50); txt.Size = MobESP.TextSize; txt.Visible = false
            MobESP.TrackedMobs[model] = { text = txt, humanoid = hum }
        end
    end

    for _, fn in ipairs(MOB_FOLDERS) do local folder = workspace:FindFirstChild(fn); if folder then for _, m in ipairs(folder:GetChildren()) do tryTrack(m) end end end
    for _, m in ipairs(workspace:GetChildren()) do tryTrack(m) end
end

local function RenderMobESP()
    if not MobESP.Enabled then for _, data in pairs(MobESP.TrackedMobs) do data.text.Visible = false end; return end
    local lc = LocalPlayer.Character; local lr = lc and (lc:FindFirstChild("HumanoidRootPart") or lc:FindFirstChild("Head"))
    for model, data in pairs(MobESP.TrackedMobs) do
        if not model or not model.Parent or not data.humanoid or not data.humanoid.Parent or data.humanoid.Health <= 0 then
            data.text.Visible = false; pcall(function() data.text:Remove() end); MobESP.TrackedMobs[model] = nil; continue
        end
        local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head") or model:FindFirstChildWhichIsA("BasePart")
        if not root or not lr then data.text.Visible = false; continue end
        local dist = (lr.Position - root.Position).Magnitude
        if dist > MobESP.MaxDistance then data.text.Visible = false; continue end
        local pos, onScreen = Camera:WorldToViewportPoint(root.Position + Vector3.new(0, 3, 0))
        if not onScreen then data.text.Visible = false; continue end
        data.text.Position = Vector2.new(pos.X, pos.Y); data.text.Size = MobESP.TextSize
        data.text.Text = Format("%s [%d/%d] [%d studs]", model.Name, math.floor(data.humanoid.Health), math.floor(data.humanoid.MaxHealth), math.floor(dist))
        data.text.Visible = true
    end
end

local function StartMobESP()
    if MobESP.ScanThread then pcall(task.cancel, MobESP.ScanThread) end
    MobESP.ScanThread = task.spawn(function() while MobESP.Enabled do ScanMobs(); task.wait(MobESP.ScanInterval) end end)
    if MobESP.RenderConn then MobESP.RenderConn:Disconnect() end
    MobESP.RenderConn = RunService.RenderStepped:Connect(RenderMobESP)
end

local function StopMobESP()
    MobESP.Enabled = false
    if MobESP.ScanThread then pcall(task.cancel, MobESP.ScanThread); MobESP.ScanThread = nil end
    if MobESP.RenderConn then MobESP.RenderConn:Disconnect(); MobESP.RenderConn = nil end
    for _, data in pairs(MobESP.TrackedMobs) do pcall(function() data.text.Visible = false; data.text:Remove() end) end
    MobESP.TrackedMobs = {}
end

-- ================================================================
-- NO FALL DAMAGE (FIXED - blocks ALL TakeDamage via namecall)
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

-- ================================================================
-- M1 SPAM
-- ================================================================
local M1Spam = { Enabled = false, Holding = false, Delay = 0.1, Thread = nil }
UserInputService.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then M1Spam.Holding = true end end)
UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then M1Spam.Holding = false end end)
local function StartSpam() if M1Spam.Thread then pcall(task.cancel, M1Spam.Thread) end; M1Spam.Thread = task.spawn(function() while M1Spam.Enabled do if M1Spam.Holding then pcall(function() local pos = UserInputService:GetMouseLocation(); VirtualInput:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 0) end) end; task.wait(M1Spam.Delay) end end) end
local function StopSpam() M1Spam.Holding = false; if M1Spam.Thread then pcall(task.cancel, M1Spam.Thread); M1Spam.Thread = nil end end

-- ================================================================
-- REMOTE ATTACK SPAM
-- ================================================================
local RemoteAttackSpam = { Enabled = false, Delay = 0.12, Thread = nil }
local function StartRemoteAttack() if RemoteAttackSpam.Thread then pcall(task.cancel, RemoteAttackSpam.Thread) end; RemoteAttackSpam.Thread = task.spawn(function() while RemoteAttackSpam.Enabled do if DataEvent then pcall(function() DataEvent:FireServer("CheckMeleeHit", nil, "NormalAttack", false) end) end; task.wait(RemoteAttackSpam.Delay) end end) end
local function StopRemoteAttack() RemoteAttackSpam.Enabled = false; if RemoteAttackSpam.Thread then pcall(task.cancel, RemoteAttackSpam.Thread); RemoteAttackSpam.Thread = nil end end

-- ================================================================
-- VOID & LAVA PROTECTION
-- ================================================================
local KillBrickProtection = { Enabled = false }
local function ToggleVoidLava(enabled)
    KillBrickProtection.Enabled = enabled; local count = 0
    for _, obj in ipairs(workspace:GetDescendants()) do
        if (obj.Name == "Void" or obj.Name == "Lava") and obj.ClassName == "Part" then pcall(function() obj.CanTouch = not enabled; count = count + 1 end) end
    end
    Notify(enabled and ("Anti Void/Lava ON (" .. count .. " parts)") or ("Anti Void/Lava OFF (" .. count .. " parts)"), 2)
end

-- ================================================================
-- NOCLIP + INFINITE JUMP
-- ================================================================
_G.Noclip = false
_G.InfiniteJump = false
RunService.Stepped:Connect(function() if _G.Noclip and LocalPlayer.Character then for _, p in ipairs(LocalPlayer.Character:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end end end)
UserInputService.JumpRequest:Connect(function() if _G.InfiniteJump then local c = LocalPlayer.Character; if c then local h = c:FindFirstChild("Humanoid"); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end end end end)

-- ================================================================
-- WALKSPEED MULTIPLIER
-- ================================================================
local WalkspeedMultiplier = { Enabled = false, Multiplier = 1.0, BaseSpeed = nil, Connection = nil }
local function EnableWalkspeed()
    local char = LocalPlayer.Character; if not char then return end; local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
    WalkspeedMultiplier.BaseSpeed = hum.WalkSpeed; hum.WalkSpeed = WalkspeedMultiplier.BaseSpeed * WalkspeedMultiplier.Multiplier
    if WalkspeedMultiplier.Connection then WalkspeedMultiplier.Connection:Disconnect() end
    WalkspeedMultiplier.Connection = RunService.RenderStepped:Connect(function()
        if not WalkspeedMultiplier.Enabled then return end; local c = LocalPlayer.Character; if not c then return end; local h = c:FindFirstChildOfClass("Humanoid"); if not h then return end
        local expected = WalkspeedMultiplier.BaseSpeed * WalkspeedMultiplier.Multiplier
        if math.abs(h.WalkSpeed - expected) > 0.5 then WalkspeedMultiplier.BaseSpeed = h.WalkSpeed; expected = WalkspeedMultiplier.BaseSpeed * WalkspeedMultiplier.Multiplier end
        h.WalkSpeed = expected
    end)
end
local function DisableWalkspeed()
    if WalkspeedMultiplier.Connection then WalkspeedMultiplier.Connection:Disconnect(); WalkspeedMultiplier.Connection = nil end
    if WalkspeedMultiplier.BaseSpeed then local char = LocalPlayer.Character; if char then local hum = char:FindFirstChildOfClass("Humanoid"); if hum then hum.WalkSpeed = WalkspeedMultiplier.BaseSpeed end end end
    WalkspeedMultiplier.BaseSpeed = nil
end
LocalPlayer.CharacterAdded:Connect(function() if WalkspeedMultiplier.Enabled then task.wait(0.3); EnableWalkspeed() end end)

-- ================================================================
-- FLY SYSTEM
-- ================================================================
local FlyStates = { "Climbing", "FallingDown", "Flying", "Freefall", "GettingUp", "Jumping", "Landed", "Ragdoll", "Running", "Seated", "Swimming" }
local FlySystem = { Enabled = false, Speed = 50, Connection = nil, Keys = { W = false, A = false, S = false, D = false, Space = false, Shift = false } }
local FlyKeyMap = { [Enum.KeyCode.W] = "W", [Enum.KeyCode.A] = "A", [Enum.KeyCode.S] = "S", [Enum.KeyCode.D] = "D", [Enum.KeyCode.Space] = "Space", [Enum.KeyCode.LeftShift] = "Shift", [Enum.KeyCode.RightShift] = "Shift" }
UserInputService.InputBegan:Connect(function(input, gp) if gp then return end; local k = FlyKeyMap[input.KeyCode]; if k then FlySystem.Keys[k] = true end end)
UserInputService.InputEnded:Connect(function(input) local k = FlyKeyMap[input.KeyCode]; if k then FlySystem.Keys[k] = false end end)

local function StartFlying()
    local char = LocalPlayer.Character; if not char then return end; local root = char:FindFirstChild("HumanoidRootPart"); if not root then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid"); if not humanoid then return end
    for _, s in ipairs(FlyStates) do humanoid:SetStateEnabled(Enum.HumanoidStateType[s], false) end
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    if FlySystem.Connection then FlySystem.Connection:Disconnect() end
    FlySystem.Connection = RunService.Heartbeat:Connect(function(dt)
        if not FlySystem.Enabled then return end; local c = LocalPlayer.Character; if not c then return end; local r = c:FindFirstChild("HumanoidRootPart"); if not r then return end
        local h = c:FindFirstChildOfClass("Humanoid"); if h and h:GetState() ~= Enum.HumanoidStateType.Physics then h:ChangeState(Enum.HumanoidStateType.Physics) end
        local cam = workspace.CurrentCamera; local spd = FlySystem.Speed * dt; local mv = Vector3.zero
        if FlySystem.Keys.W then mv = mv + cam.CFrame.LookVector * spd end; if FlySystem.Keys.S then mv = mv - cam.CFrame.LookVector * spd end
        if FlySystem.Keys.A then mv = mv - cam.CFrame.RightVector * spd end; if FlySystem.Keys.D then mv = mv + cam.CFrame.RightVector * spd end
        if FlySystem.Keys.Space then mv = mv + Vector3.new(0, spd, 0) end; if FlySystem.Keys.Shift then mv = mv - Vector3.new(0, spd, 0) end
        r.CFrame = r.CFrame + mv; r.Velocity = Vector3.zero; r.RotVelocity = Vector3.zero
    end)
end

local function StopFlying()
    if FlySystem.Connection then FlySystem.Connection:Disconnect(); FlySystem.Connection = nil end
    local char = LocalPlayer.Character; if char then local h = char:FindFirstChildOfClass("Humanoid"); if h then for _, s in ipairs(FlyStates) do h:SetStateEnabled(Enum.HumanoidStateType[s], true) end; h:ChangeState(Enum.HumanoidStateType.Freefall) end end
end
LocalPlayer.CharacterAdded:Connect(function() if FlySystem.Enabled then task.wait(0.5); StartFlying() end end)

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
local function Block() if DataFunction then pcall(function() DataFunction:InvokeServer("Block") end) end end
local function Unblock() if DataFunction then pcall(function() DataFunction:InvokeServer("EndBlock") end) end end
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
    local conn = animator.AnimationPlayed:Connect(function(track)
        if not AutoBlock.Enabled then return end; local assetId = track.Animation.AnimationId:match("rbxassetid://(%d+)") or track.Animation.AnimationId
        for _, rule in ipairs(BlockRules) do
            if assetId == rule.animID then
                if rule.continuous then StartContinuousBlock(model, track, rule)
                else if rule.distance then local d = GetDistToEntity(model); if not d or d > rule.distance then return end end; ScheduleBlock(model.Name or "entity", rule.delay or 0.3) end; return
            end
        end
    end)
    AutoBlock.MonitoredEntities[model] = { conn }
    for _, t in ipairs(animator:GetPlayingAnimationTracks()) do conn:Fire(t) end
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
local function StartAutoBlock() if AutoBlock.ScanThread then pcall(task.cancel, AutoBlock.ScanThread) end; AutoBlock.ScanThread = task.spawn(function() while AutoBlock.Enabled do ScanForEntities(); task.wait(1) end end) end
local function StopAutoBlock()
    if AutoBlock.ScanThread then pcall(task.cancel, AutoBlock.ScanThread); AutoBlock.ScanThread = nil end
    for _, conns in pairs(AutoBlock.MonitoredEntities) do for _, c in ipairs(conns) do if typeof(c) == "RBXScriptConnection" then c:Disconnect() end end end
    AutoBlock.MonitoredEntities = {}; AutoBlock.ContinuousMonitors = {}; Unblock()
end

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
local NoRainConn = nil
local FullBrightEnabled = false
local FullBrightLevel = 2

local function ToggleNoFog(enabled)
    NoFogEnabled = enabled
    if enabled then OrigFogEnd = Lighting.FogEnd; Lighting.FogEnd = 1000000
    else Lighting.FogEnd = OrigFogEnd end
end

local function ToggleNoRain(enabled)
    NoRainEnabled = enabled
    if enabled then
        if NoRainConn then NoRainConn:Disconnect() end
        pcall(function()
            for _, v in ipairs(Lighting:GetDescendants()) do if v:IsA("ParticleEmitter") then v.Enabled = false end end
            local terrain = workspace:FindFirstChild("Terrain")
            if terrain then for _, v in ipairs(terrain:GetDescendants()) do if v:IsA("ParticleEmitter") then v.Enabled = false end end end
        end)
        NoRainConn = Lighting.DescendantAdded:Connect(function(child) if child:IsA("ParticleEmitter") then child.Enabled = false end end)
    else
        if NoRainConn then NoRainConn:Disconnect(); NoRainConn = nil end
        pcall(function() for _, v in ipairs(Lighting:GetDescendants()) do if v:IsA("ParticleEmitter") then v.Enabled = true end end end)
    end
end

local function ToggleFullBright(enabled, level)
    FullBrightEnabled = enabled; level = level or FullBrightLevel
    if enabled then
        Lighting.Brightness = level; Lighting.Ambient = Color3.fromRGB(178, 178, 178); Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178); Lighting.GlobalShadows = false
    else
        Lighting.Brightness = OrigBrightness; Lighting.Ambient = OrigAmbient; Lighting.OutdoorAmbient = OrigOutdoorAmbient; Lighting.GlobalShadows = OrigGlobalShadows
    end
end

-- ================================================================
-- BULK SELLER
-- ================================================================
local MERCHANT_POS = Vector3.new(-2875.2, -134.4, -4763.4)

local function PressE()
    pcall(function() VirtualInput:SendKeyEvent(true, Enum.KeyCode.E, false, game); task.wait(0.15); VirtualInput:SendKeyEvent(false, Enum.KeyCode.E, false, game) end)
end
local function Press3()
    pcall(function() VirtualInput:SendKeyEvent(true, Enum.KeyCode.Three, false, game); task.wait(0.15); VirtualInput:SendKeyEvent(false, Enum.KeyCode.Three, false, game) end)
end
local function TeleportTo(pos)
    local char = LocalPlayer.Character; if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head"); if root then root.CFrame = CFrame.new(pos) end
end

local function BulkSellTrinkets()
    TeleportTo(MERCHANT_POS); task.wait(1.5)
    PressE(); task.wait(1) -- interact
    PressE(); task.wait(0.5) -- first choice
    PressE(); task.wait(0.5) -- select Trinkets
    PressE(); task.wait(0.5) -- confirm sell
    Notify("Bulk sold all Trinkets!", 2)
end

local function BulkSellGems()
    TeleportTo(MERCHANT_POS); task.wait(1.5)
    PressE(); task.wait(1) -- interact
    PressE(); task.wait(0.5) -- first choice
    -- Click on Gems option (Dialog3_Option2)
    pcall(function()
        local dialog = LocalPlayer.PlayerGui:FindFirstChild("ClientGui")
        if dialog then dialog = dialog:FindFirstChild("Mainframe") end
        if dialog then dialog = dialog:FindFirstChild("Loadout") end
        if dialog then dialog = dialog:FindFirstChild("Dialog") end
        if dialog then
            local gemsOption = dialog:FindFirstChild("Dialog3_Option2")
            if gemsOption then
                if typeof(fireclick) == "function" then fireclick(gemsOption)
                elseif typeof(firesignal) == "function" then firesignal(gemsOption.MouseButton1Click)
                end
            end
        end
    end)
    task.wait(0.5)
    PressE(); task.wait(0.5) -- confirm sell
    Notify("Bulk sold all Gems!", 2)
end

local function BulkSellFruits()
    TeleportTo(MERCHANT_POS); task.wait(1.5)
    -- Find Food Merchant
    local foodMerchant = workspace:FindFirstChild("Food Merchant")
    if foodMerchant then
        local pos
        pcall(function()
            local part = foodMerchant:FindFirstChild("HumanoidRootPart") or foodMerchant:FindFirstChildWhichIsA("BasePart")
            if part then pos = part.Position + Vector3.new(0, 0, 3) end
        end)
        if pos then TeleportTo(pos); task.wait(0.5) end
    end
    PressE(); task.wait(1) -- interact
    Press3(); task.wait(0.5) -- press 3
    Press3(); task.wait(0.5) -- press 3 again
    Notify("Bulk sold all Fruits!", 2)
end

-- ================================================================
-- BOSS FARM
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

local BossFarm = {
    Enabled = false, Target = nil, TargetName = "", SelectedBoss = "Wooden Golem",
    WeaponName = "Onyx Resanagi", HeightOffset = 50, AttackDelay = 0.12,
    Thread = nil, AnchorConn = nil,
    HyugaHeightBoost = 0, HyugaAnimConnection = nil, HyugaInVoid = false, HyugaVoidConn = nil,
    LavaSnakeHeightBoost = 0, LavaSnakeAnimConnection = nil,
    HakuAnimConnection = nil, HakuSafeSpot = false, HakuSafeSpotEndTime = 0, AutoLootOnKill = false,
}

local BossConfigs = {
    ["Wooden Golem"] = { height = 16 }, ["Hyuga Boss"] = { height = 10.75 }, ["Lava Snake"] = { height = 38 },
    ["Haku Boss"] = { height = 10.75 }, ["Barbarit The Rose"] = { height = 12 }, ["Manda"] = { height = 38 },
}
local BossLootSpots = {
    ["Hyuga Boss"] = Vector3.new(-663.8, -359.9, -728.9), ["Wooden Golem"] = Vector3.new(-4716.2, 344.1, -2932.0),
    ["Haku Boss"] = Vector3.new(-3788.1, -238.5, -9723.9), ["Lava Snake"] = Vector3.new(-546.7, -546.9, -1461.6),
    ["Barbarit The Rose"] = Vector3.zero, ["Manda"] = Vector3.zero,
}

local HYUGA_VOID_SAFE_SPOT = Vector3.new(-700.8, -334.3, -780.8)
local function IsInHyugaVoidZone(pos) return pos.X >= -826.4 and pos.X <= -524.0 and pos.Y >= -454.8 and pos.Y <= -450.8 and pos.Z >= -927.1 and pos.Z <= -621.1 end

local function GetBossRoot(model) return model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head") or model:FindFirstChild("Torso") or model:FindFirstChildWhichIsA("BasePart") end

local function FindBoss(bossName)
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
    RefreshDataEvent()
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
        if DataEvent then local e = tick() + 1.5; while tick() < e do if not entry.obj.Parent then break end; pcall(function() DataEvent:FireServer("PickUp", entry.id) end); task.wait(0.05) end end; task.wait(0.2)
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
local function MonitorHakuBossIceDragon()
    if BossFarm.HakuAnimConnection then BossFarm.HakuAnimConnection:Disconnect(); BossFarm.HakuAnimConnection = nil end
    local debris = workspace:FindFirstChild("Debris"); if not debris then local conn; conn = workspace.ChildAdded:Connect(function(c) if c.Name == "Debris" then conn:Disconnect(); MonitorHakuBossIceDragon() end end); return end
    BossFarm.HakuAnimConnection = debris.ChildAdded:Connect(function(child) if not BossFarm.Enabled then return end; local dur = child.Name == "IceDragonHead" and 4 or (child:IsA("Beam") and child.Name == "Beam121") and 1 or nil; if dur then local char = LocalPlayer.Character; if char and char:FindFirstChild("HumanoidRootPart") then char.HumanoidRootPart.CFrame = CFrame.new(-2969.2, 1832.9, -9610.4); BossFarm.HakuSafeSpot = true; BossFarm.HakuSafeSpotEndTime = tick() + dur end end end)
end

local function StartBossFarm()
    if BossFarm.AnchorConn then BossFarm.AnchorConn:Disconnect() end; if BossFarm.Thread then pcall(task.cancel, BossFarm.Thread) end
    local config = BossConfigs[BossFarm.SelectedBoss]; local hum, model = FindBoss(BossFarm.SelectedBoss)
    if not hum or not model then Notify(BossFarm.SelectedBoss .. " not spawned!", 3); BossFarm.Enabled = false; return end
    BossFarm.Target = hum; BossFarm.TargetName = model.Name; if config then BossFarm.HeightOffset = config.height end
    if BossFarm.TargetName == "Hyuga Boss" then MonitorHyugaBossAnimations(model); MonitorHyugaVoid(model); task.spawn(function() BossFarm.HyugaHeightBoost = -2; task.wait(5); if BossFarm.HyugaHeightBoost == -2 then BossFarm.HyugaHeightBoost = 0 end end) end
    if BossFarm.TargetName == "Lava Snake" then MonitorLavaSnakeAnimations(model) end
    if BossFarm.TargetName == "Haku Boss" then MonitorHakuBossIceDragon() end
    if DataEvent and BossFarm.WeaponName ~= "" then pcall(function() DataEvent:FireServer("Item", "Selected", BossFarm.WeaponName) end) end
    task.wait(0.5); Notify("Farming: " .. BossFarm.TargetName, 3)

    BossFarm.AnchorConn = RunService.Heartbeat:Connect(function()
        pcall(function()
            if not BossFarm.Enabled then return end; local h = BossFarm.Target
            if not h or not h.Parent or h.Health <= 0 then
                local deadName = BossFarm.TargetName; BossFarm.Enabled = false
                if BossFarm.AnchorConn then BossFarm.AnchorConn:Disconnect(); BossFarm.AnchorConn = nil end
                if BossFarm.Thread then pcall(task.cancel, BossFarm.Thread); BossFarm.Thread = nil end
                if BossFarm.AutoLootOnKill then task.spawn(function() pcall(CollectBossLoot, deadName) end) end; return
            end
            local bossRoot = GetBossRoot(h.Parent); if not bossRoot then return end
            local char = LocalPlayer.Character; if not char then return end; local root = char:FindFirstChild("HumanoidRootPart"); if not root then return end
            if BossFarm.HakuSafeSpot and tick() >= BossFarm.HakuSafeSpotEndTime then BossFarm.HakuSafeSpot = false end
            if BossFarm.HyugaInVoid then root.CFrame = CFrame.new(HYUGA_VOID_SAFE_SPOT)
            elseif BossFarm.HakuSafeSpot then root.CFrame = CFrame.new(-2969.2, 1832.9, -9610.4)
            else root.CFrame = CFrame.lookAt(bossRoot.Position + Vector3.new(0, BossFarm.HeightOffset + BossFarm.HyugaHeightBoost + BossFarm.LavaSnakeHeightBoost, 0), bossRoot.Position) end
        end)
    end)

    BossFarm.Thread = task.spawn(function()
        while BossFarm.Enabled do
            if not BossFarm.HyugaInVoid and BossFarm.Target and BossFarm.Target.Parent and BossFarm.Target.Health > 0 then
                if DataEvent then pcall(function() local br = GetBossRoot(BossFarm.Target.Parent); if br then DataEvent:FireServer("Dash", "Sub", br.Position) end end); task.wait(0.05); pcall(function() DataEvent:FireServer("CheckMeleeHit", nil, "NormalAttack", false) end) end
            end; task.wait(BossFarm.AttackDelay)
        end
    end)
end

local function StopBossFarm()
    BossFarm.Enabled = false; BossFarm.HyugaHeightBoost = 0; BossFarm.HyugaInVoid = false; BossFarm.HakuSafeSpot = false; BossFarm.LavaSnakeHeightBoost = 0
    if BossFarm.HyugaVoidConn then task.cancel(BossFarm.HyugaVoidConn); BossFarm.HyugaVoidConn = nil end
    if BossFarm.HyugaAnimConnection then BossFarm.HyugaAnimConnection:Disconnect(); BossFarm.HyugaAnimConnection = nil end
    if BossFarm.HakuAnimConnection then BossFarm.HakuAnimConnection:Disconnect(); BossFarm.HakuAnimConnection = nil end
    if BossFarm.LavaSnakeAnimConnection then BossFarm.LavaSnakeAnimConnection:Disconnect(); BossFarm.LavaSnakeAnimConnection = nil end
    if BossFarm.AnchorConn then BossFarm.AnchorConn:Disconnect(); BossFarm.AnchorConn = nil end
    if BossFarm.Thread then pcall(task.cancel, BossFarm.Thread); BossFarm.Thread = nil end
end

-- ================================================================
-- AUTO EYE FARM
-- ================================================================
local AutoEye = { Enabled = false, Thread = nil, TargetPos = Vector3.new(-2883.2, 652.6, -5448.9), SelectedItem = "Sharingan [Stage 1]" }
local function isOutOfForcefield(character) return character and not character:FindFirstChild("ForceField") end

local function autoEyeLoop()
    while AutoEye.Enabled do
        local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local root = char:WaitForChild("HumanoidRootPart", 5) or char:WaitForChild("Head", 5); if not root then task.wait(0.3); continue end
        if not isOutOfForcefield(char) then while char and not isOutOfForcefield(char) and AutoEye.Enabled do if root and root.Parent then root.CFrame = CFrame.new(AutoEye.TargetPos) end; task.wait(0.05) end end
        if root and root.Parent and isOutOfForcefield(char) then
            root.CFrame = CFrame.new(AutoEye.TargetPos); task.wait(0.2)
            if DataEvent then pcall(function() DataEvent:FireServer("Item", "Selected", AutoEye.SelectedItem) end) end; task.wait(0.3)
            if DataFunction then pcall(function() DataFunction:InvokeServer("Awaken", AutoEye.SelectedItem) end); task.wait(0.5) end
            if char and char:FindFirstChild("Humanoid") then char.Humanoid.Health = 0; task.wait(0.1); char:BreakJoints() end
        else task.wait(0.3) end; task.wait(0.2)
    end
end

-- ================================================================
-- AUTO GRIP FARM
-- ================================================================
local AutoGripFarm = { AltEnabled = false, MainEnabled = false, AltThread = nil, MainThread = nil, TargetPos = Vector3.new(-4458.5, 660.7, -4895.2), LocationCheckRadius = 50, PlayerDetectRadius = 20, GripWaitTime = 4 }

local function autoGripAltLoop()
    while AutoGripFarm.AltEnabled do
        local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local root = char:WaitForChild("HumanoidRootPart", 5); if not root then task.wait(0.3); continue end
        if not isOutOfForcefield(char) then while char and not isOutOfForcefield(char) and AutoGripFarm.AltEnabled do if root and root.Parent then root.CFrame = CFrame.new(AutoGripFarm.TargetPos) end; task.wait(0.05) end end
        if root and root.Parent and isOutOfForcefield(char) then
            root.CFrame = CFrame.new(AutoGripFarm.TargetPos); task.wait(0.2)
            if (root.Position - AutoGripFarm.TargetPos).Magnitude <= AutoGripFarm.LocationCheckRadius and DataEvent then
                pcall(function() DataEvent:FireServer("TakeDamage", 999) end); task.wait(2)
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
        if target and target.Character then local tr = target.Character:FindFirstChild("HumanoidRootPart"); if tr then root.CFrame = CFrame.new(tr.Position); task.wait(0.1); if DataEvent then pcall(function() DataEvent:FireServer("Grip") end) end; task.wait(AutoGripFarm.GripWaitTime) end
        else task.wait(1) end; task.wait(0.2)
    end
end

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
            if obj.Parent and DataEvent then
                local spamEnd = tick() + 0.8; while tick() < spamEnd do if not obj.Parent then break end; pcall(function() DataEvent:FireServer("PickUp", id) end); task.wait(0.05) end
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
    if DataEvent then pcall(function() DataEvent:FireServer("ServerTeleport", chosen.jobId, 14) end) end
end

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
    local activeNames = {}; for name in pairs(ChakraTracker.ActiveUsers) do table.insert(activeNames, name) end
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

-- ================================================================
-- UI CREATION
-- ================================================================
local Window = JitlerUI:CreateWindow({
    Name = "Jitler Hub v2.0",
    Icon = "rbxassetid://124980045936567",
    LoadingTitle = "Jitler Hub",
    LoadingSubtitle = "Loading modules...",
    ConfigurationSaving = { Enabled = true, FolderName = "JitlerHub", FileName = "Config" },
    SettingsIcon = "rbxassetid://7734068557",
})

-- Tabs
local ESPTab = Window:CreateTab({ Name = "ESP", Icon = "rbxassetid://6523858394" })
local MainTab = Window:CreateTab({ Name = "Main", Icon = "rbxassetid://7734053495" })
local AutoFarmTab = Window:CreateTab({ Name = "AutoFarm", Icon = "rbxassetid://130840043704422" })

-- Main Sub-Tabs
local SubMain = MainTab:CreateSubTab("Main")
local SubQOL = MainTab:CreateSubTab("Quality Of Life")
local SubInfo = MainTab:CreateSubTab("Information View")

-- ================================================================
-- ESP TAB (two-column layout)
-- ================================================================
do
local ESPLeft, ESPRight = ESPTab:CreateDualPane()

-- Left column: Player ESP
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

ESPLeft:CreateColorPicker({ Name = "Text Color", Default = Color3.fromRGB(255, 255, 255), Flag = "ESPTextColor", Callback = function(c) ESPTextColor = c end })

ESPLeft:CreateToggle({ Name = "Show Tracers", CurrentValue = false, Flag = "ESPTracers", Callback = function(v) Options.ShowTracers(v) end })
ESPLeft:CreateToggle({ Name = "Show Boxes", CurrentValue = false, Flag = "ESPBoxes", Callback = function(v) Options.ShowBoxes(v) end })
ESPLeft:CreateToggle({ Name = "Crosshair", CurrentValue = false, Flag = "ESPCrosshair", Callback = function(v) Options.Crosshair(v) end })

-- Right column: Highlight + Healthbar + Mob
ESPRight:CreateSection("Player Highlight")

ESPRight:CreateToggle({ Name = "Enable Highlight", Description = "Glow outline on players", CurrentValue = false, Flag = "PlayerHL", Callback = function(v) PlayerHighlight.Enabled = v; if v then StartPlayerHighlight() else StopPlayerHighlight() end end })
ESPRight:CreateSlider({ Name = "Fill Transparency", Range = { 0, 1 }, Increment = 0.05, Suffix = "", CurrentValue = 0.7, Flag = "HLFillTrans", Callback = function(v) PlayerHighlight.FillTransparency = v end })
ESPRight:CreateColorPicker({ Name = "Highlight Color", Default = Color3.fromRGB(130, 100, 210), Flag = "HLFillColor", Callback = function(c) PlayerHighlight.FillColor = c end })
ESPRight:CreateSlider({ Name = "Outline Transparency", Range = { 0, 1 }, Increment = 0.05, Suffix = "", CurrentValue = 0, Flag = "HLOutlineTrans", Callback = function(v) PlayerHighlight.OutlineTransparency = v end })
ESPRight:CreateSlider({ Name = "HL Max Distance", Range = { 100, 5000 }, Increment = 50, Suffix = " studs", CurrentValue = 2500, Flag = "HLMaxDist", Callback = function(v) PlayerHighlight.MaxDistance = v end })

ESPRight:CreateSection("Healthbar ESP")

ESPRight:CreateToggle({ Name = "Enable Healthbars", CurrentValue = true, Flag = "ShowHealthbars", Callback = function(v) Options.ShowCustomHealthbar(v) end })
ESPRight:CreateSlider({ Name = "Bar Width", Range = { 30, 100 }, Increment = 1, Suffix = "px", CurrentValue = 40, Flag = "HBWidth", Callback = function(v) Options.HealthbarWidth(v) end })
ESPRight:CreateSlider({ Name = "Bar Height", Range = { 2, 10 }, Increment = 1, Suffix = "px", CurrentValue = 2, Flag = "HBHeight", Callback = function(v) Options.HealthbarHeight(v) end })
ESPRight:CreateSlider({ Name = "Bar Offset", Range = { 30, 100 }, Increment = 1, Suffix = "px", CurrentValue = 30, Flag = "HBOffset", Callback = function(v) Options.HealthbarOffset(v) end })

ESPRight:CreateSection("Mob ESP")

ESPRight:CreateToggle({ Name = "Enable Mob ESP", Description = "Show mob names & health", CurrentValue = false, Flag = "MobESP", Callback = function(v) MobESP.Enabled = v; if v then StartMobESP() else StopMobESP() end end })
ESPRight:CreateSlider({ Name = "Mob Max Distance", Range = { 100, 2000 }, Increment = 50, Suffix = " studs", CurrentValue = 500, Flag = "MobMaxDist", Callback = function(v) MobESP.MaxDistance = v end })
ESPRight:CreateSlider({ Name = "Mob Text Size", Range = { 8, 24 }, Increment = 1, Suffix = "px", CurrentValue = 14, Flag = "MobTextSize", Callback = function(v) MobESP.TextSize = v end })
end -- ESP TAB

-- ================================================================
-- MAIN TAB  >  Sub-Tab: Main (two-column)
-- ================================================================
do
local MLeft, MRight = SubMain:CreateDualPane()

-- Left: Movement
MLeft:CreateSection("Movement")

MLeft:CreateToggleWithKeybind({ Name = "Walkspeed Multiplier", Description = "Multiply base walk speed", CurrentValue = false, Flag = "WalkspeedMult", Callback = function(v) WalkspeedMultiplier.Enabled = v; if v then EnableWalkspeed() else DisableWalkspeed() end end }, { CurrentKeybind = "X", Flag = "WalkspeedKey" })
MLeft:CreateSlider({ Name = "Speed Multiplier", Range = { 0.1, 25 }, Increment = 0.1, Suffix = "x", CurrentValue = 1.0, Flag = "SpeedMult", Callback = function(v)
    WalkspeedMultiplier.Multiplier = v
    if WalkspeedMultiplier.Enabled and WalkspeedMultiplier.BaseSpeed then local c = LocalPlayer.Character; if c then local h = c:FindFirstChildOfClass("Humanoid"); if h then h.WalkSpeed = WalkspeedMultiplier.BaseSpeed * v end end end
end })

MLeft:CreateToggleWithKeybind({ Name = "Fly", Description = "Fly freely in any direction", CurrentValue = false, Flag = "Fly", Callback = function(v) FlySystem.Enabled = v; if v then StartFlying() else StopFlying() end end }, { CurrentKeybind = "Y", Flag = "FlyKey" })
MLeft:CreateSlider({ Name = "Fly Speed", Range = { 10, 300 }, Increment = 5, Suffix = "", CurrentValue = 50, Flag = "FlySpeed", Callback = function(v) FlySystem.Speed = v end })

MLeft:CreateToggleWithKeybind({ Name = "Infinite Jump", CurrentValue = false, Flag = "InfJump", Callback = function(v) _G.InfiniteJump = v end }, { CurrentKeybind = "Period", Flag = "InfJumpKey" })

MLeft:CreateToggleWithKeybind({ Name = "Noclip", Description = "Walk through walls", CurrentValue = false, Flag = "Noclip", Callback = function(v) _G.Noclip = v end }, { CurrentKeybind = "N", Flag = "NoclipKey" })

-- Right: Combat + Protection
MRight:CreateSection("Combat")

MRight:CreateToggleWithKeybind({ Name = "M1 Spam", Description = "Auto-click at set interval", CurrentValue = false, Flag = "M1Spam", Callback = function(v) M1Spam.Enabled = v; if v then StartSpam() else StopSpam() end end }, { CurrentKeybind = "L", Flag = "M1SpamKey" })
MRight:CreateSlider({ Name = "Click Delay", Range = { 0.02, 0.5 }, Increment = 0.01, Suffix = "s", CurrentValue = 0.1, Flag = "M1Delay", Callback = function(v) M1Spam.Delay = v end })

MRight:CreateToggleWithKeybind({ Name = "Remote Attack Spam", Description = "Fire remote attack", CurrentValue = false, Flag = "RemoteAttack", Callback = function(v) RemoteAttackSpam.Enabled = v; if v then StartRemoteAttack() else StopRemoteAttack() end end }, { CurrentKeybind = "K", Flag = "RemoteAttackKey" })

MRight:CreateSection("Protection")

MRight:CreateToggleWithKeybind({ Name = "No Fall Damage", Description = "Prevent all fall damage", CurrentValue = false, Flag = "NoFall", Callback = function(v) NoFall.Enabled = v end }, { CurrentKeybind = "F7", Flag = "NoFallKey" })

MRight:CreateToggleWithKeybind({ Name = "Anti Void/Lava", Description = "Block void and lava kills", CurrentValue = false, Flag = "AntiVoidLava", Callback = function(v) ToggleVoidLava(v) end }, { CurrentKeybind = "V", Flag = "AntiVoidLavaKey" })
end -- SubMain

-- ================================================================
-- MAIN TAB  >  Sub-Tab: Quality Of Life (two-column)
-- ================================================================
do
local QLeft, QRight = SubQOL:CreateDualPane()

-- Left: Visual Features
QLeft:CreateSection("Visual Features")

QLeft:CreateSlider({ Name = "Time of Day", Range = { 0, 24 }, Increment = 0.5, Suffix = "h", CurrentValue = Lighting.ClockTime, Flag = "TimeOfDay", Callback = function(v) pcall(function() Lighting.ClockTime = v end) end })
QLeft:CreateToggle({ Name = "No Fog", CurrentValue = false, Flag = "NoFog", Callback = function(v) ToggleNoFog(v) end })
QLeft:CreateToggle({ Name = "No Rain", CurrentValue = false, Flag = "NoRain", Callback = function(v) ToggleNoRain(v) end })
QLeft:CreateToggle({ Name = "Full Bright", CurrentValue = false, Flag = "FullBright", Callback = function(v) ToggleFullBright(v, FullBrightLevel) end })
QLeft:CreateSlider({ Name = "Brightness Level", Range = { 0.5, 5 }, Increment = 0.1, Suffix = "", CurrentValue = 2, Flag = "BrightnessLvl", Callback = function(v) FullBrightLevel = v; if FullBrightEnabled then ToggleFullBright(true, v) end end })

-- Right: Combat Assist + Utility
QRight:CreateSection("Combat Assist")

QRight:CreateToggleWithKeybind({ Name = "Auto Perfect Block", Description = "Auto time perfect blocks", CurrentValue = false, Flag = "AutoBlock", Callback = function(v) AutoBlock.Enabled = v; if v then StartAutoBlock() else StopAutoBlock() end end }, { CurrentKeybind = "U", Flag = "AutoBlockKey" })

QRight:CreateToggleWithKeybind({ Name = "Back Attach", Description = "TP behind nearest player", CurrentValue = false, Flag = "BackAttach", Callback = function(v) BackAttach.Enabled = v; if v then StartBackAttach() else StopBackAttach() end end }, { CurrentKeybind = "B", Flag = "BackAttachKey" })

QRight:CreateSection("Utility")

QRight:CreateButton({ Name = "Reset Character", Callback = function() local char = LocalPlayer.Character; if char and char:FindFirstChild("Humanoid") then char.Humanoid.Health = 0; task.wait(1); char:BreakJoints() end end })
QRight:CreateButton({ Name = "Random Server Hop", Callback = function() DoServerHop("random") end })
QRight:CreateButton({ Name = "Low Player Server", Callback = function() DoServerHop("min") end })
end -- SubQOL

-- ================================================================
-- MAIN TAB  >  Sub-Tab: Information View
-- ================================================================
do

-- ----- Current Position -----
SubInfo:CreateSection("Current Position")

local CoordLabel = SubInfo:CreateLabel("X: 0, Y: 0, Z: 0")
RunService.RenderStepped:Connect(function()
    local char = LocalPlayer.Character
    if char then local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head"); if root then CoordLabel:Set(Format("X: %.1f, Y: %.1f, Z: %.1f", root.Position.X, root.Position.Y, root.Position.Z)) else CoordLabel:Set("No character") end
    else CoordLabel:Set("No character") end
end)

SubInfo:CreateButton({ Name = "Copy Position as Vector3", Callback = function()
    local char = LocalPlayer.Character; if not char then return end; local root = char:FindFirstChild("HumanoidRootPart"); if root then local p = root.Position; setclipboard(Format("Vector3.new(%.1f, %.1f, %.1f)", p.X, p.Y, p.Z)); Notify("Copied!", 2) end
end })

-- ----- Quick Teleports -----
SubInfo:CreateSection("Quick Teleports")
local TeleportLocations = {
    { Name = "Wood Boss", Pos = Vector3.new(-4708.4, 336.9, -2986.2) }, { Name = "Sorythia Village", Pos = Vector3.new(-113.2, 50.9, -283.8) },
    { Name = "Lava Snake", Pos = Vector3.new(-547.6, -541.7, -1281.8) }, { Name = "Biyo Bay", Pos = Vector3.new(-598.9, -178.6, -464.3) },
    { Name = "Snow Village", Pos = Vector3.new(-2916.3, -46.0, -4907.3) }, { Name = "Snap Trainer", Pos = Vector3.new(337.2, 131.4, -1967.2) },
    { Name = "Durana", Pos = Vector3.new(1851.0, -125.5, 1065.2) }, { Name = "Secret Spot", Pos = Vector3.new(-4458.5, 660.7, -4895.2) },
    { Name = "Hyuga Boss", Pos = Vector3.new(-693.7, -359.9, -765.7) }, { Name = "Haku Boss", Pos = Vector3.new(-3838.2, -231.4, -9657.0) },
    { Name = "Merchant", Pos = Vector3.new(-2875.2, -134.4, -4763.4) },
}
for _, loc in ipairs(TeleportLocations) do
    SubInfo:CreateButton({ Name = loc.Name, Callback = function() TeleportTo(loc.Pos); Notify("TP: " .. loc.Name, 2) end })
end

-- ----- Mission Markers -----
SubInfo:CreateSection("Mission Markers")
local MissionMarkers = { FoundMarkers = {} }

local function IsMissionMarkerActive(mm)
    local active = false
    pcall(function() for _, c in ipairs(mm:GetChildren()) do local ok, val = pcall(function() return c.AlwaysOnTop end); if ok and val == true then active = true; break end end end)
    return active
end

local function ScanMissionMarkers()
    MissionMarkers.FoundMarkers = {}
    local debris = workspace:FindFirstChild("Debris"); if not debris then return end
    local ml = debris:FindFirstChild("Mission Locations"); if not ml then return end
    for _, lf in ipairs(ml:GetChildren()) do
        local spawners = lf:FindFirstChild("Spawners"); if not spawners then continue end
        for i, spawner in ipairs(spawners:GetChildren()) do
            local mm = spawner:FindFirstChild("MissionMarker"); if not mm or not IsMissionMarkerActive(mm) then continue end
            local pos; pcall(function() pos = mm:IsA("BasePart") and mm.Position or mm:IsA("Model") and mm:GetPivot().Position or mm:IsA("Attachment") and mm.WorldPosition end)
            if not pos then pcall(function() pos = (mm:FindFirstChildWhichIsA("BasePart", true) or spawner:FindFirstChildWhichIsA("BasePart", true)).Position end) end
            if pos then table.insert(MissionMarkers.FoundMarkers, { name = Format("%s #%d", lf.Name, i), pos = pos }) end
        end
    end
    Notify("Found " .. #MissionMarkers.FoundMarkers .. " markers", 2)
end

SubInfo:CreateButton({ Name = "TP to Nearest Mission", Callback = function()
    ScanMissionMarkers(); if #MissionMarkers.FoundMarkers == 0 then return end
    local char = LocalPlayer.Character; if not char then return end; local root = char:FindFirstChild("HumanoidRootPart"); if not root then return end
    local pp = root.Position; local nearest, minD = nil, math.huge
    for _, m in ipairs(MissionMarkers.FoundMarkers) do local d = (pp - m.pos).Magnitude; if d < minD then minD = d; nearest = m end end
    if nearest then TeleportTo(nearest.pos); Notify(nearest.name .. " (" .. math.floor(minD) .. " studs)", 2) end
end })

-- ----- Chakra Point Collector -----
SubInfo:CreateSection("Chakra Point Collector")
local ChakraCollector = { Running = false, Thread = nil, Delay = 1.5 }

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

SubInfo:CreateToggle({ Name = "Auto Collect Chakra", CurrentValue = false, Flag = "ChakraCollect", Callback = function(v) ChakraCollector.Running = v; if v then if ChakraCollector.Thread then task.cancel(ChakraCollector.Thread) end; ChakraCollector.Thread = task.spawn(CollectChakraPoints) else if ChakraCollector.Thread then task.cancel(ChakraCollector.Thread); ChakraCollector.Thread = nil end end end })
SubInfo:CreateSlider({ Name = "Wait per Point", Range = { 0.5, 5 }, Increment = 0.1, Suffix = "s", CurrentValue = 1.5, Flag = "ChakraDelay", Callback = function(v) ChakraCollector.Delay = v end })

-- ----- Rift Collector -----
SubInfo:CreateSection("Rift Collector")
local RiftCollector = { Running = false, Thread = nil, Delay = 1.5 }

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

SubInfo:CreateToggle({ Name = "Auto Collect Rifts", CurrentValue = false, Flag = "RiftCollect", Callback = function(v) RiftCollector.Running = v; if v then if RiftCollector.Thread then task.cancel(RiftCollector.Thread) end; RiftCollector.Thread = task.spawn(CollectRifts) else if RiftCollector.Thread then task.cancel(RiftCollector.Thread); RiftCollector.Thread = nil end end end })
SubInfo:CreateSlider({ Name = "Wait per Rift", Range = { 0.5, 5 }, Increment = 0.1, Suffix = "s", CurrentValue = 1.5, Flag = "RiftDelay", Callback = function(v) RiftCollector.Delay = v end })
end -- SubInfo

-- ================================================================
-- AUTOFARM TAB (two-column)
-- ================================================================
do
local AFLeft, AFRight = AutoFarmTab:CreateDualPane()

-- Left: Boss Farm + Eye Farm
AFLeft:CreateSection("Boss Farm")

AFLeft:CreateInput({ Name = "Weapon Name", PlaceholderText = "Onyx Resanagi", Callback = function(v) BossFarm.WeaponName = v end })
AFLeft:CreateDropdown({ Name = "Select Boss", Options = { "Wooden Golem", "Hyuga Boss", "Lava Snake", "Haku Boss", "Barbarit The Rose", "Manda" }, CurrentOption = "Wooden Golem", Flag = "BossSelect", Callback = function(v) BossFarm.SelectedBoss = type(v) == "table" and v[1] or v end })
AFLeft:CreateToggleWithKeybind({ Name = "Start Farm", Description = "Auto-attack selected boss", CurrentValue = false, Flag = "BossFarm", Callback = function(v) BossFarm.Enabled = v; if v then StartBossFarm() else StopBossFarm() end end }, { CurrentKeybind = "G", Flag = "BossFarmKey" })
AFLeft:CreateSlider({ Name = "Attack Delay", Range = { 0.02, 0.5 }, Increment = 0.01, Suffix = "s", CurrentValue = 0.12, Flag = "BFAttackDelay", Callback = function(v) BossFarm.AttackDelay = v end })
AFLeft:CreateToggle({ Name = "Auto Loot On Kill", CurrentValue = false, Flag = "BossAutoLoot", Callback = function(v) BossFarm.AutoLootOnKill = v end })

AFLeft:CreateSection("Auto Eye Farm")

AFLeft:CreateDropdown({ Name = "Select Eye", Options = { "Sharingan [Stage 1]", "Sharingan [Stage 2]", "Sharingan [Stage 3]", "Byakugan [Stage 1]", "Byakugan [Stage 2]", "Byakugan [Stage 3]", "Byakugan [Stage 4]" }, CurrentOption = "Sharingan [Stage 1]", Flag = "EyeSelect", Callback = function(v) AutoEye.SelectedItem = type(v) == "table" and v[1] or v end })
AFLeft:CreateToggle({ Name = "Enable Auto Eye", CurrentValue = false, Flag = "AutoEye", Callback = function(v) AutoEye.Enabled = v; if v then if AutoEye.Thread then task.cancel(AutoEye.Thread) end; AutoEye.Thread = task.spawn(autoEyeLoop) else if AutoEye.Thread then task.cancel(AutoEye.Thread); AutoEye.Thread = nil end end end })

-- Right: Grip Farm + Trinket + Merchant
AFRight:CreateSection("Auto Grip Farm")

AFRight:CreateToggle({ Name = "Grip Alt Mode", CurrentValue = false, Flag = "GripAlt", Callback = function(v) AutoGripFarm.AltEnabled = v; if v then if AutoGripFarm.AltThread then task.cancel(AutoGripFarm.AltThread) end; AutoGripFarm.AltThread = task.spawn(autoGripAltLoop) else if AutoGripFarm.AltThread then task.cancel(AutoGripFarm.AltThread); AutoGripFarm.AltThread = nil end end end })
AFRight:CreateToggle({ Name = "Grip Main Mode", CurrentValue = false, Flag = "GripMain", Callback = function(v) AutoGripFarm.MainEnabled = v; if v then if AutoGripFarm.MainThread then task.cancel(AutoGripFarm.MainThread) end; AutoGripFarm.MainThread = task.spawn(autoGripMainLoop) else if AutoGripFarm.MainThread then task.cancel(AutoGripFarm.MainThread); AutoGripFarm.MainThread = nil end end end })

AFRight:CreateSection("Auto Trinket Pickup")

AFRight:CreateToggle({ Name = "Enable Auto Trinket", CurrentValue = false, Flag = "AutoTrinket", Callback = function(v) AutoTrinket.Enabled = v; if v then StartAutoTrinket() else StopAutoTrinket() end end })
AFRight:CreateSlider({ Name = "Scan Interval", Range = { 1, 30 }, Increment = 1, Suffix = "s", CurrentValue = 5, Flag = "TrinketScanInt", Callback = function(v) AutoTrinket.ScanInterval = v end })
AFRight:CreateSlider({ Name = "Scan Radius", Range = { 20, 500 }, Increment = 10, Suffix = " studs", CurrentValue = 200, Flag = "TrinketRadius", Callback = function(v) AutoTrinket.ScanRadius = v end })
AFRight:CreateToggle({ Name = "Teleport to Trinket", CurrentValue = true, Flag = "TrinketTP", Callback = function(v) AutoTrinket.TeleportToTrinket = v end })
AFRight:CreateToggle({ Name = "Trinket ESP", CurrentValue = false, Flag = "TrinketESP", Callback = function(v) TrinketESP.Enabled = v; if v then StartTrinketESP() else StopTrinketESP() end end })

AFRight:CreateSection("Merchant Sales")

AFRight:CreateParagraph({ Title = "Merchant Location", Content = "Teleports to merchant at (-2875, -134, -4763).\nInteracts automatically with dialog choices." })
AFRight:CreateButton({ Name = "Bulk Sell All Trinkets", Callback = function() task.spawn(BulkSellTrinkets) end })
AFRight:CreateButton({ Name = "Bulk Sell All Gems", Callback = function() task.spawn(BulkSellGems) end })

AFRight:CreateSection("Food Merchant Sales")

AFRight:CreateParagraph({ Title = "Food Merchant", Content = "Teleports to Food Merchant.\nPresses '3' twice to sell all fruits." })
AFRight:CreateButton({ Name = "Bulk Sell All Fruits", Callback = function() task.spawn(BulkSellFruits) end })
end -- AutoFarm

-- ================================================================
-- FOOTER
-- ================================================================
Notify("Jitler Hub v2.0 loaded!", 3)
print("=== Jitler Hub v2.0 Loaded ===")