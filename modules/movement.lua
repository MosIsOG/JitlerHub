-- Jitler Hub - Movement Module (Void/Lava, Noclip, InfiniteJump, Walkspeed, Fly)
local Hub = shared.JitlerHub
local RunService = Hub.RunService
local UserInputService = Hub.UserInputService
local LocalPlayer = Hub.LocalPlayer
local Notify = Hub.Notify

-- ================================================================
-- VOID & LAVA PROTECTION
-- ================================================================
local function ToggleVoidLava(enabled)
    local count = 0
    for _, obj in ipairs(workspace:GetDescendants()) do
        if (obj.Name == "Void" or obj.Name == "Lava") and obj.ClassName == "Part" then pcall(function() obj.CanTouch = not enabled; count = count + 1 end) end
    end
    Notify(enabled and ("Anti Void/Lava ON (" .. count .. " parts)") or ("Anti Void/Lava OFF (" .. count .. " parts)"), 2)
end

Hub.ToggleVoidLava = ToggleVoidLava

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

Hub.WalkspeedMultiplier = WalkspeedMultiplier
Hub.EnableWalkspeed = EnableWalkspeed
Hub.DisableWalkspeed = DisableWalkspeed

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

Hub.FlySystem = FlySystem
Hub.StartFlying = StartFlying
Hub.StopFlying = StopFlying
