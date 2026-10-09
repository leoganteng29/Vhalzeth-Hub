local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local StarterGui        = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

local Config = {
    AutoSteal       = false,
    AutoStealDelay  = 0.15,
    InstantSteal    = false,
    AntiTrap        = false,
    AntiHit         = false,
    AntiRagdoll     = false,
    AutoTreadmill   = false,
    EggESP          = false,
    InfJump         = false,
    Noclip          = false,
    WalkSpeed       = 32,
    SpeedHack       = false,
    Fly             = false,
    FlySpeed        = 60,
}

local State = {
    EggCache      = {},
    PromptCache   = {},
    Remotes       = {},
    ESPObjects    = {},
    FlyBV         = nil,
    LastScan      = 0,
    Connections   = {},
}

local function safeCall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then warn("[Vhalzeth] " .. tostring(err)) end
    return ok
end

local function track(conn)
    table.insert(State.Connections, conn)
end

local function getChar()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getHRP()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

-- Scan dinamis: cari apapun yang punya ProximityPrompt, ClickDetector, atau nama egg-like
local function scanWorld()
    local now = tick()
    if now - State.LastScan < 1 then return end
    State.LastScan = now

    State.EggCache = {}
    State.PromptCache = {}

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled then
            table.insert(State.PromptCache, obj)
            local parent = obj.Parent
            if parent and parent:IsA("BasePart") then
                table.insert(State.EggCache, parent)
            elseif parent and parent.Parent and parent.Parent:IsA("Model") then
                local p = parent.Parent.PrimaryPart or parent.Parent:FindFirstChildWhichIsA("BasePart")
                if p then table.insert(State.EggCache, p) end
            end
        end
        if obj:IsA("ClickDetector") and obj.Parent and obj.Parent:IsA("BasePart") then
            table.insert(State.PromptCache, obj)
            table.insert(State.EggCache, obj.Parent)
        end
    end
end

local function getNearestPrompt()
    local hrp = getHRP()
    if not hrp then return nil end
    local best, bestDist = nil, math.huge
    for _, p in ipairs(State.PromptCache) do
        local part = p:IsA("BasePart") and p or p.Parent
        if part and part:IsA("BasePart") then
            local d = (part.Position - hrp.Position).Magnitude
            if d < bestDist then
                bestDist = d
                best = p
            end
        end
    end
    return best, bestDist
end

local function firePrompt(p)
    if not p then return end
    safeCall(function()
        if p:IsA("ProximityPrompt") then
            fireproximityprompt(p)
        elseif p:IsA("ClickDetector") then
            fireclickdetector(p)
        end
    end)
end

local function grabNearest()
    local p = getNearestPrompt()
    if not p then return end
    local hrp = getHRP()
    if not hrp then return end
    local part = p:IsA("BasePart") and p or p.Parent
    if part and part:IsA("BasePart") then
        safeCall(function()
            hrp.CFrame = CFrame.new(part.Position + Vector3.new(0, 2, 0))
        end)
        task.wait(0.05)
        firePrompt(p)
    end
end

local function startAutoSteal()
    if State.StealConn then return end
    State.StealConn = task.spawn(function()
        while task.wait(Config.AutoStealDelay) do
            scanWorld()
            if Config.AutoSteal then
                grabNearest()
            end
        end
    end)
end

local function startInstantSteal()
    if State.InstConn then return end
    State.InstConn = task.spawn(function()
        while task.wait(0.05) do
            if Config.InstantSteal then
                scanWorld()
                for _, p in ipairs(State.PromptCache) do
                    firePrompt(p)
                end
            end
        end
    end)
end

-- Anti Trap/Hit: hapus semua damage source & paksa humanoid sehat
local function antiLoop()
    if State.AntiConn then return end
    State.AntiConn = RunService.Heartbeat:Connect(function()
        local char = LocalPlayer.Character
        if not char then return end

        if Config.AntiTrap then
            for _, d in ipairs(char:GetDescendants()) do
                if d:IsA("BasePart") then
                    d.CanCollide = false
                    d.CanTouch = false
                end
            end
            for _, obj in ipairs(workspace:GetDescendants()) do
                local n = obj.Name:lower()
                if obj:IsA("BasePart") and (n:find("trap") or n:find("kill") or n:find("damage") or n:find("lava") or n:find("spike")) then
                    obj.CanTouch = false
                    obj.CanCollide = false
                    obj.Transparency = 0.5
                end
            end
        end

        if Config.AntiHit then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
                hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
                hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
                if hum.Health < hum.MaxHealth and hum.Health > 0 then
                    hum.Health = hum.MaxHealth
                end
            end
        end

        if Config.AntiRagdoll then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end
    end)
end

-- Auto Treadmill: cari objek bernama treadmill / conveyor / walk
local function startAutoTreadmill()
    if State.TreadConn then return end
    State.TreadConn = RunService.Heartbeat:Connect(function()
        if not Config.AutoTreadmill then return end
        local hrp = getHRP()
        if not hrp then return end
        for _, obj in ipairs(workspace:GetDescendants()) do
            local n = obj.Name:lower()
            if obj:IsA("BasePart") and (n:find("treadmill") or n:find("conveyor") or n:find("walk")) then
                if (hrp.Position - obj.Position).Magnitude > 8 then
                    hrp.CFrame = CFrame.new(obj.Position + Vector3.new(0, 3, 0))
                end
                break
            end
        end
    end)
end

-- ESP
local function startESP()
    if State.ESPConn then return end
    State.ESPConn = RunService.RenderStepped:Connect(function()
        for _, o in ipairs(State.ESPObjects) do pcall(function() o:Remove() end) end
        State.ESPObjects = {}
        if not Config.EggESP then return end

        for _, part in ipairs(State.EggCache) do
            local pos = part.Position
            local sp, on = Camera:WorldToViewportPoint(pos)
            if on then
                local txt = Drawing.new("Text")
                txt.Text = part.Name
                txt.Size = 13
                txt.Center = true
                txt.Outline = true
                txt.Color = Color3.fromRGB(255, 220, 100)
                txt.Position = Vector2.new(sp.X, sp.Y)
                txt.Visible = true
                table.insert(State.ESPObjects, txt)
            end
        end
    end)
end

-- Inf Jump & Noclip
local function startMisc()
    if State.JumpConn then return end
    State.JumpConn = UserInputService.JumpRequest:Connect(function()
        if Config.InfJump then
            local hum = getHum()
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    end)

    State.NoclipConn = RunService.Stepped:Connect(function()
        if not Config.Noclip then return end
        local char = LocalPlayer.Character
        if not char then return end
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end)
end

-- Speed
local function applySpeed()
    local hum = getHum()
    if hum then hum.WalkSpeed = Config.SpeedHack and Config.WalkSpeed or 16 end
end

-- Fly
local function setupFly()
    if State.FlyConn then State.FlyConn:Disconnect() end
    if State.FlyBV then State.FlyBV:Destroy(); State.FlyBV = nil end
    if not Config.Fly then return end
    local hrp = getHRP()
    if not hrp then return end
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e5,1e5,1e5)
    bv.Velocity = Vector3.zero
    bv.Parent = hrp
    State.FlyBV = bv
    State.FlyConn = RunService.RenderStepped:Connect(function()
        if not Config.Fly or not State.FlyBV or not State.FlyBV.Parent then return end
        local d = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then d += Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then d -= Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then d -= Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then d += Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then d += Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then d -= Vector3.new(0,1,0) end
        State.FlyBV.Velocity = d.Magnitude > 0 and d.Unit * Config.FlySpeed or Vector3.zero
    end)
end

--============ GUI ============
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VhalzethHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = (gethui and gethui()) or LocalPlayer:WaitForChild("PlayerGui")

local Main = Instance.new("Frame")
Main.Size = UDim2.fromOffset(430, 480)
Main.Position = UDim2.new(0.5, -215, 0.5, -240)
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui
local mc = Instance.new("UICorner"); mc.CornerRadius = UDim.new(0, 10); mc.Parent = Main
local ms = Instance.new("UIStroke"); ms.Color = Color3.fromRGB(130, 90, 210); ms.Thickness = 1; ms.Transparency = 0.3; ms.Parent = Main

local Top = Instance.new("Frame")
Top.Size = UDim2.new(1, 0, 0, 36)
Top.BackgroundColor3 = Color3.fromRGB(30, 22, 46)
Top.BorderSizePixel = 0
Top.Parent = Main
local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(0, 10); tc.Parent = Top

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -50, 1, 0)
Title.Position = UDim2.fromOffset(12, 0)
Title.BackgroundTransparency = 1
Title.Text = "Vhalzeth Hub  •  Steal An Egg"
Title.TextColor3 = Color3.fromRGB(235, 225, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Top

local Close = Instance.new("TextButton")
Close.Size = UDim2.fromOffset(28, 28)
Close.Position = UDim2.new(1, -34, 0, 4)
Close.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
Close.Text = "×"
Close.TextColor3 = Color3.fromRGB(255, 200, 200)
Close.Font = Enum.Font.GothamBold
Close.TextSize = 16
Close.BorderSizePixel = 0
Close.Parent = Top
local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(0, 6); cc.Parent = Close
Close.MouseButton1Click:Connect(function() ScreenGui.Enabled = false end)

local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1, -16, 1, -50)
Scroll.Position = UDim2.fromOffset(8, 44)
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 4
Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.Parent = Main

local LL = Instance.new("UIListLayout")
LL.Padding = UDim.new(0, 6)
LL.SortOrder = Enum.SortOrder.LayoutOrder
LL.Parent = Scroll

local function mkToggle(text, default, cb)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 34)
    row.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
    row.BorderSizePixel = 0
    row.Parent = Scroll
    local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 6); rc.Parent = row
    local rs = Instance.new("UIStroke"); rs.Color = Color3.fromRGB(75, 60, 110); rs.Thickness = 1; rs.Transparency = 0.5; rs.Parent = row

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -110, 1, 0)
    lbl.Position = UDim2.fromOffset(12, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(215, 215, 230)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local on = default or false
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(72, 22)
    btn.Position = UDim2.new(1, -84, 0.5, -11)
    btn.BackgroundColor3 = on and Color3.fromRGB(95, 70, 170) or Color3.fromRGB(60, 60, 70)
    btn.Text = on and "ON" or "OFF"
    btn.TextColor3 = Color3.fromRGB(240, 240, 240)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.BorderSizePixel = 0
    btn.Parent = row
    local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 5); bc.Parent = btn

    btn.MouseButton1Click:Connect(function()
        on = not on
        btn.Text = on and "ON" or "OFF"
        btn.BackgroundColor3 = on and Color3.fromRGB(95, 70, 170) or Color3.fromRGB(60, 60, 70)
        if cb then safeCall(cb, on) end
    end)
    return btn
end

local function mkButton(text, cb)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 32)
    btn.BackgroundColor3 = Color3.fromRGB(40, 34, 58)
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(220, 220, 235)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 13
    btn.BorderSizePixel = 0
    btn.Parent = Scroll
    local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 6); bc.Parent = btn
    local bs = Instance.new("UIStroke"); bs.Color = Color3.fromRGB(95, 75, 150); bs.Thickness = 1; bs.Transparency = 0.5; bs.Parent = btn
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(62, 50, 95)}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(40, 34, 58)}):Play()
    end)
    btn.MouseButton1Click:Connect(function() if cb then safeCall(cb) end end)
    return btn
end

mkButton("Steal Sekarang (Nearest)", function() scanWorld(); grabNearest() end)

mkToggle("Auto Steal", false, function(on)
    Config.AutoSteal = on
    if on then startAutoSteal() end
end)

mkToggle("Instant Steal All", false, function(on)
    Config.InstantSteal = on
    if on then startInstantSteal() end
end)

mkToggle("Auto Treadmill", false, function(on)
    Config.AutoTreadmill = on
    if on then startAutoTreadmill() end
end)

mkToggle("Anti Trap", false, function(on) Config.AntiTrap = on end)
mkToggle("Anti Hit", false, function(on) Config.AntiHit = on end)
mkToggle("Anti Ragdoll", false, function(on) Config.AntiRagdoll = on end)
mkToggle("Egg ESP", false, function(on)
    Config.EggESP = on
    if on then startESP() end
end)

mkToggle("Noclip", false, function(on) Config.Noclip = on end)
mkToggle("Infinite Jump", false, function(on) Config.InfJump = on end)

mkToggle("Speed Hack", false, function(on)
    Config.SpeedHack = on
    applySpeed()
end)

mkToggle("Fly", false, function(on)
    Config.Fly = on
    setupFly()
end)

mkButton("Serverhop Low Player", function()
    local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
    local ok, res = pcall(function() return game:HttpGet(url) end)
    if not ok then return end
    local data = game:GetService("HttpService"):JSONDecode(res)
    for _, s in ipairs(data.data or {}) do
        if s.id ~= game.JobId and s.playing <= 1 then
            game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
            return
        end
    end
end)

--============ START ============
antiLoop()
startMisc()
scanWorld()
startAutoSteal()
startInstantSteal()
startESP()

track(LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    applySpeed()
end))

safeCall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "Vhalzeth Hub",
        Text = "Loaded. Fitur siap dipakai.",
        Duration = 4
    })
end)
