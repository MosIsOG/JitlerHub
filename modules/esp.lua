-- Jitler Hub - ESP Module (Player ESP, Highlights, Mob ESP)
local Hub = shared.JitlerHub
local Players = Hub.Players
local RunService = Hub.RunService
local LocalPlayer = Hub.LocalPlayer
local Camera = Hub.Camera
local HttpService = Hub.HttpService
local Format = Hub.Format

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

Hub.Options = Options

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
                            NameTag.Color = Hub.ESPTextColor; NameTag.OutlineColor = Color3.new(0.05, 0.05, 0.05); NameTag.Transparency = 0.85
                        else NameTag.Visible = false end

                        if Options.ShowDistance.Value or Options.ShowHealth.Value then
                            DistanceTag.Visible = true; DistanceTag.Size = Options.TextSize.Value - 1; DistanceTag.Outline = Options.TextOutline.Value
                            DistanceTag.Color = Hub.ESPTextColor; DistanceTag.Transparency = 0.85
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

Hub.PlayerHighlight = PlayerHighlight
Hub.StartPlayerHighlight = StartPlayerHighlight
Hub.StopPlayerHighlight = StopPlayerHighlight

-- ================================================================
-- MOB ESP SYSTEM
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
        -- Skip Dialog NPCs and WorldBosses (handled by their own ESP systems)
        if IsDialogNPC(model) then return end
        if BossESP.Enabled and IsWorldBoss(model) then return end
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

Hub.MobESP = MobESP
Hub.StartMobESP = StartMobESP
Hub.StopMobESP = StopMobESP

-- ================================================================
-- NPC ESP SYSTEM (Dialog NPCs only)
-- ================================================================
local NPCESP = { Enabled = false, MaxDistance = 500, TextSize = 14, ScanInterval = 3, TrackedNPCs = {}, ScanThread = nil, RenderConn = nil }

local function IsDialogNPC(model)
    local npcVal = model:FindFirstChild("NPC")
    if not npcVal or not npcVal:IsA("StringValue") then return false end
    return npcVal.Value == "Dialog"
end

local function IsCombatMob(model)
    local npcVal = model:FindFirstChild("NPC")
    if not npcVal or not npcVal:IsA("StringValue") then return false end
    return npcVal.Value == "Combat"
end

local function IsWorldBoss(model)
    if not IsCombatMob(model) then return false end
    return model:FindFirstChild("WorldBoss") ~= nil
end

local function ScanNPCs()
    if not NPCESP.Enabled then return end
    local lc = LocalPlayer.Character; if not lc then return end
    local lr = lc:FindFirstChild("HumanoidRootPart") or lc:FindFirstChild("Head"); if not lr then return end
    local pp = lr.Position; local seen = {}

    local function tryTrack(model)
        if not model:IsA("Model") or seen[model] or model == lc then return end
        seen[model] = true
        if not IsDialogNPC(model) then return end
        local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head") or model:FindFirstChildWhichIsA("BasePart"); if not root then return end
        if (pp - root.Position).Magnitude > NPCESP.MaxDistance then return end
        if not NPCESP.TrackedNPCs[model] then
            local txt = Drawing.new("Text"); txt.Center = true; txt.Outline = true; txt.OutlineColor = Color3.new(0, 0, 0)
            txt.Color = Color3.fromRGB(0, 255, 100); txt.Size = NPCESP.TextSize; txt.Visible = false
            NPCESP.TrackedNPCs[model] = { text = txt }
        end
    end

    for _, fn in ipairs({"NPCs", "Mobs", "Enemies"}) do local folder = workspace:FindFirstChild(fn); if folder then for _, m in ipairs(folder:GetChildren()) do tryTrack(m) end end end
    for _, m in ipairs(workspace:GetChildren()) do tryTrack(m) end
end

local function RenderNPCESP()
    if not NPCESP.Enabled then for _, data in pairs(NPCESP.TrackedNPCs) do data.text.Visible = false end; return end
    local lc = LocalPlayer.Character; local lr = lc and (lc:FindFirstChild("HumanoidRootPart") or lc:FindFirstChild("Head"))
    for model, data in pairs(NPCESP.TrackedNPCs) do
        if not model or not model.Parent then
            data.text.Visible = false; pcall(function() data.text:Remove() end); NPCESP.TrackedNPCs[model] = nil; continue
        end
        local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head") or model:FindFirstChildWhichIsA("BasePart")
        if not root or not lr then data.text.Visible = false; continue end
        local dist = (lr.Position - root.Position).Magnitude
        if dist > NPCESP.MaxDistance then data.text.Visible = false; continue end
        local pos, onScreen = Camera:WorldToViewportPoint(root.Position + Vector3.new(0, 3, 0))
        if not onScreen then data.text.Visible = false; continue end
        data.text.Position = Vector2.new(pos.X, pos.Y); data.text.Size = NPCESP.TextSize
        data.text.Text = Format("%s [%d studs]", model.Name, math.floor(dist))
        data.text.Color = Color3.fromRGB(0, 255, 100)
        data.text.Visible = true
    end
end

local function StartNPCESP()
    if NPCESP.ScanThread then pcall(task.cancel, NPCESP.ScanThread) end
    NPCESP.ScanThread = task.spawn(function() while NPCESP.Enabled do ScanNPCs(); task.wait(NPCESP.ScanInterval) end end)
    if NPCESP.RenderConn then NPCESP.RenderConn:Disconnect() end
    NPCESP.RenderConn = RunService.RenderStepped:Connect(RenderNPCESP)
end

local function StopNPCESP()
    NPCESP.Enabled = false
    if NPCESP.ScanThread then pcall(task.cancel, NPCESP.ScanThread); NPCESP.ScanThread = nil end
    if NPCESP.RenderConn then NPCESP.RenderConn:Disconnect(); NPCESP.RenderConn = nil end
    for _, data in pairs(NPCESP.TrackedNPCs) do pcall(function() data.text.Visible = false; data.text:Remove() end) end
    NPCESP.TrackedNPCs = {}
end

Hub.NPCESP = NPCESP
Hub.StartNPCESP = StartNPCESP
Hub.StopNPCESP = StopNPCESP

-- ================================================================
-- WORLD BOSS ESP SYSTEM (distance-based transition)
-- ================================================================
local BossESP = { Enabled = false, MaxDistance = 2000, TransitionDist = 500, TextSize = 14, ScanInterval = 2, TrackedBosses = {}, ScanThread = nil, RenderConn = nil }

local function ScanWorldBosses()
    if not BossESP.Enabled then return end
    local lc = LocalPlayer.Character; if not lc then return end
    local lr = lc:FindFirstChild("HumanoidRootPart") or lc:FindFirstChild("Head"); if not lr then return end
    local pp = lr.Position; local seen = {}

    local function tryTrack(model)
        if not model:IsA("Model") or seen[model] or model == lc then return end
        seen[model] = true
        if not IsWorldBoss(model) then return end
        local hum = model:FindFirstChildOfClass("Humanoid"); if not hum or hum.Health <= 0 then return end
        local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head") or model:FindFirstChildWhichIsA("BasePart"); if not root then return end
        if (pp - root.Position).Magnitude > BossESP.MaxDistance then return end
        if not BossESP.TrackedBosses[model] then
            -- Long-range text (mob ESP style, purple)
            local farTxt = Drawing.new("Text"); farTxt.Center = true; farTxt.Outline = true; farTxt.OutlineColor = Color3.new(0, 0, 0)
            farTxt.Color = Color3.fromRGB(180, 100, 255); farTxt.Size = BossESP.TextSize; farTxt.Visible = false
            -- Close-range boss panel drawings (bg + name + hp bar + hp text)
            local panelBg = Drawing.new("Square"); panelBg.Filled = true; panelBg.Color = Color3.fromRGB(15, 5, 30); panelBg.Transparency = 0.85; panelBg.Visible = false; panelBg.ZIndex = 20
            local panelBorder = Drawing.new("Square"); panelBorder.Filled = false; panelBorder.Color = Color3.fromRGB(150, 80, 255); panelBorder.Thickness = 2; panelBorder.Transparency = 0.9; panelBorder.Visible = false; panelBorder.ZIndex = 20
            local nameTxt = Drawing.new("Text"); nameTxt.Center = true; nameTxt.Outline = true; nameTxt.OutlineColor = Color3.new(0, 0, 0)
            nameTxt.Color = Color3.fromRGB(220, 160, 255); nameTxt.Size = BossESP.TextSize + 2; nameTxt.Visible = false; nameTxt.ZIndex = 21
            local hpBarBg = Drawing.new("Square"); hpBarBg.Filled = true; hpBarBg.Color = Color3.fromRGB(40, 20, 60); hpBarBg.Transparency = 0.9; hpBarBg.Visible = false; hpBarBg.ZIndex = 21
            local hpBarFill = Drawing.new("Square"); hpBarFill.Filled = true; hpBarFill.Color = Color3.fromRGB(180, 80, 255); hpBarFill.Transparency = 1; hpBarFill.Visible = false; hpBarFill.ZIndex = 21
            local hpTxt = Drawing.new("Text"); hpTxt.Center = true; hpTxt.Outline = true; hpTxt.OutlineColor = Color3.new(0, 0, 0)
            hpTxt.Color = Color3.fromRGB(255, 255, 255); hpTxt.Size = BossESP.TextSize; hpTxt.Visible = false; hpTxt.ZIndex = 22
            BossESP.TrackedBosses[model] = { humanoid = hum, farText = farTxt, panelBg = panelBg, panelBorder = panelBorder, nameTxt = nameTxt, hpBarBg = hpBarBg, hpBarFill = hpBarFill, hpTxt = hpTxt }
        end
    end

    for _, fn in ipairs({"NPCs", "Mobs", "Enemies"}) do local folder = workspace:FindFirstChild(fn); if folder then for _, m in ipairs(folder:GetChildren()) do tryTrack(m) end end end
    for _, m in ipairs(workspace:GetChildren()) do tryTrack(m) end
end

local function HideBossData(data)
    data.farText.Visible = false; data.panelBg.Visible = false; data.panelBorder.Visible = false
    data.nameTxt.Visible = false; data.hpBarBg.Visible = false; data.hpBarFill.Visible = false; data.hpTxt.Visible = false
end

local function RemoveBossData(data)
    pcall(function() data.farText:Remove() end); pcall(function() data.panelBg:Remove() end); pcall(function() data.panelBorder:Remove() end)
    pcall(function() data.nameTxt:Remove() end); pcall(function() data.hpBarBg:Remove() end); pcall(function() data.hpBarFill:Remove() end); pcall(function() data.hpTxt:Remove() end)
end

local function RenderBossESP()
    if not BossESP.Enabled then for _, data in pairs(BossESP.TrackedBosses) do HideBossData(data) end; return end
    local lc = LocalPlayer.Character; local lr = lc and (lc:FindFirstChild("HumanoidRootPart") or lc:FindFirstChild("Head"))
    for model, data in pairs(BossESP.TrackedBosses) do
        if not model or not model.Parent or not data.humanoid or not data.humanoid.Parent or data.humanoid.Health <= 0 then
            HideBossData(data); RemoveBossData(data); BossESP.TrackedBosses[model] = nil; continue
        end
        local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head") or model:FindFirstChildWhichIsA("BasePart")
        if not root or not lr then HideBossData(data); continue end
        local dist = (lr.Position - root.Position).Magnitude
        if dist > BossESP.MaxDistance then HideBossData(data); continue end
        local hum = data.humanoid
        local hp = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
        local pos, onScreen = Camera:WorldToViewportPoint(root.Position + Vector3.new(0, 5, 0))
        if not onScreen then HideBossData(data); continue end

        if dist > BossESP.TransitionDist then
            -- Long-range: mob-style purple text
            data.farText.Position = Vector2.new(pos.X, pos.Y); data.farText.Size = BossESP.TextSize
            data.farText.Text = Format("%s [%d/%d] [%d studs]", model.Name, math.floor(hum.Health), math.floor(hum.MaxHealth), math.floor(dist))
            data.farText.Visible = true
            data.panelBg.Visible = false; data.panelBorder.Visible = false; data.nameTxt.Visible = false
            data.hpBarBg.Visible = false; data.hpBarFill.Visible = false; data.hpTxt.Visible = false
        else
            -- Close-range: boss HP panel
            data.farText.Visible = false
            local pW, pH = 220, 50
            local px, py = pos.X - pW / 2, pos.Y - pH - 10
            data.panelBg.Position = Vector2.new(px, py); data.panelBg.Size = Vector2.new(pW, pH); data.panelBg.Visible = true
            data.panelBorder.Position = Vector2.new(px, py); data.panelBorder.Size = Vector2.new(pW, pH); data.panelBorder.Visible = true
            data.nameTxt.Position = Vector2.new(pos.X, py + 4); data.nameTxt.Size = BossESP.TextSize + 2
            data.nameTxt.Text = model.Name; data.nameTxt.Visible = true
            local barX, barY, barW, barH = px + 10, py + 24, pW - 20, 8
            data.hpBarBg.Position = Vector2.new(barX, barY); data.hpBarBg.Size = Vector2.new(barW, barH); data.hpBarBg.Visible = true
            data.hpBarFill.Position = Vector2.new(barX, barY); data.hpBarFill.Size = Vector2.new(barW * hp, barH)
            data.hpBarFill.Color = hp > 0.6 and Color3.fromRGB(150, 80, 255) or hp > 0.3 and Color3.fromRGB(200, 120, 255) or Color3.fromRGB(255, 80, 120)
            data.hpBarFill.Visible = true
            data.hpTxt.Position = Vector2.new(pos.X, barY + barH + 2); data.hpTxt.Size = BossESP.TextSize - 1
            data.hpTxt.Text = Format("%d / %d  (%d%%)", math.floor(hum.Health), math.floor(hum.MaxHealth), math.floor(hp * 100))
            data.hpTxt.Visible = true
        end
    end
end

local function StartBossESP()
    if BossESP.ScanThread then pcall(task.cancel, BossESP.ScanThread) end
    BossESP.ScanThread = task.spawn(function() while BossESP.Enabled do ScanWorldBosses(); task.wait(BossESP.ScanInterval) end end)
    if BossESP.RenderConn then BossESP.RenderConn:Disconnect() end
    BossESP.RenderConn = RunService.RenderStepped:Connect(RenderBossESP)
end

local function StopBossESP()
    BossESP.Enabled = false
    if BossESP.ScanThread then pcall(task.cancel, BossESP.ScanThread); BossESP.ScanThread = nil end
    if BossESP.RenderConn then BossESP.RenderConn:Disconnect(); BossESP.RenderConn = nil end
    for _, data in pairs(BossESP.TrackedBosses) do HideBossData(data); RemoveBossData(data) end
    BossESP.TrackedBosses = {}
end

Hub.BossESP = BossESP
Hub.StartBossESP = StartBossESP
Hub.StopBossESP = StopBossESP
