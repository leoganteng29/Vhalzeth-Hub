local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local StarterGui        = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

local LOGO_URL = "rbxassetid://120546090415288"

local Config = {
    AutoSteal       = false,
    AutoStealDelay  = 0.15,
    InstantSteal    = false,
    ReturnToBase    = true,
    PrioritizeHigh  = true,
    ZonePadding     = 15,
    RunSpeed        = 60,
    UseFlyOnMove    = false,
    FlySpeed        = 80,
    Fly             = false,
    AntiTrap        = false,
    AntiHit         = false,
    AntiGuard       = false,
    AntiRagdoll     = false,
    AutoTreadmill   = false,
    EggESP          = false,
    InfJump         = false,
    Noclip          = false,
    WalkSpeed       = 32,
    SpeedHack       = false,
}

local State = {
    EggCache      = {},
    PromptCache   = {},
    ESPObjects    = {},
    FlyBV         = nil,
    LastScan      = 0,
    BaseCFrame    = nil,
    EggValues     = {},
    CurrentZone   = nil,
    Zones         = {},
    Minimized     = false,
    Connections   = {},
}

--=========================================================
--  UTIL
--=========================================================
local function safeCall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then warn("[Vhalzeth] " .. tostring(err)) end
    return ok
end

local function track(conn) table.insert(State.Connections, conn) end
local function getChar() return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait() end
local function getHRP() local c = getChar(); return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum() local c = getChar(); return c and c:FindFirstChildOfClass("Humanoid") end

--=========================================================
--  VALUE
--=========================================================
local function getEggValue(part)
    local val = 0
    for _, child in ipairs(part:GetChildren()) do
        if child:IsA("NumberValue") or child:IsA("IntValue") then
            local n = child.Name:lower()
            if n:find("price") or n:find("value") or n:find("worth") or n:find("cost") then
                val = math.max(val, child.Value)
            end
        end
    end
    for _, attr in ipairs(part:GetAttributes()) do
        if attr:lower():find("price") or attr:lower():find("value") then
            local v = part:GetAttribute(attr)
            if type(v) == "number" then val = math.max(val, v) end
        end
    end
    local num = tonumber(part.Name:match("(%d+)"))
    if num then val = math.max(val, num) end
    return val
end

--=========================================================
--  DETEKSI ZONA OTOMATIS
--=========================================================
local function detectZones()
    State.Zones = {}

    -- Cari zone dari nama folder / model yang mengandung "zone", "area", "region", "map", "biome"
    for _, obj in ipairs(workspace:GetDescendants()) do
        local n = obj.Name:lower()
        if (obj:IsA("Model") or obj:IsA("Folder") or obj:IsA("BasePart")) and
           (n:find("zone") or n:find("area") or n:find("region") or n:find("biome") or n:find("island") or n:find("land")) then
            -- Hitung bounding box
            local minP, maxP
            if obj:IsA("BasePart") then
                local half = obj.Size / 2
                minP = obj.Position - half
                maxP = obj.Position + half
            else
                local ok, cf, size = pcall(function() return obj:GetBoundingBox() end)
                if ok and cf then
                    local half = size / 2
                    minP = cf.Position - half
                    maxP = cf.Position + half
                end
            end
            if minP and maxP then
                table.insert(State.Zones, {
                    name = obj.Name,
                    obj  = obj,
                    min  = minP,
                    max  = maxP,
                })
            end
        end
    end

    -- Fallback: pakai zona grid kalau tidak ada zone object
    if #State.Zones == 0 then
        local size = 200
        for x = -600, 600, size do
            for z = -600, 600, size do
                table.insert(State.Zones, {
                    name = "Grid_" .. x .. "_" .. z,
                    min  = Vector3.new(x, -100, z),
                    max  = Vector3.new(x + size, 500, z + size),
                })
            end
        end
    end
end

local function getZoneOf(pos)
    if not State.Zones or #State.Zones == 0 then return nil end
    for _, z in ipairs(State.Zones) do
        local p = Config.ZonePadding
        if pos.X >= z.min.X - p and pos.X <= z.max.X + p and
           pos.Z >= z.min.Z - p and pos.Z <= z.max.Z + p then
            return z
        end
    end
    return nil
end

local function getCurrentZone()
    local hrp = getHRP()
    if not hrp then return nil end
    return getZoneOf(hrp.Position)
end

--=========================================================
--  SCAN WORLD
--=========================================================
local function computeEggValues()
    State.EggValues = {}
    for _, part in ipairs(State.EggCache) do
        table.insert(State.EggValues, {part = part, value = getEggValue(part), name = part.Name})
    end
    table.sort(State.EggValues, function(a, b) return a.value > b.value end)
end

local function scanWorld()
    local now = tick()
    if now - State.LastScan < 0.8 then return end
    State.LastScan = now
    State.EggCache = {}
    State.PromptCache = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled then
            table.insert(State.PromptCache, obj)
            local parent = obj.Parent
            local part
            if parent and parent:IsA("BasePart") then part = parent
            elseif parent and parent.Parent and parent.Parent:IsA("Model") then
                part = parent.Parent.PrimaryPart or parent.Parent:FindFirstChildWhichIsA("BasePart")
            end
            if part then table.insert(State.EggCache, part) end
        end
        if obj:IsA("ClickDetector") and obj.Parent and obj.Parent:IsA("BasePart") then
            table.insert(State.PromptCache, obj)
            table.insert(State.EggCache, obj.Parent)
        end
    end
    computeEggValues()
end

--=========================================================
--  EGG TERMAHAL DI ZONA SEKARANG
--=========================================================
local function getHighestEggInZone()
    local hrp = getHRP()
    if not hrp then return nil end
    local zone = getCurrentZone()
    if not zone then return nil end

    local best, bestVal, bestDist = nil, -1, math.huge
    for _, entry in ipairs(State.EggValues) do
        local part = entry.part
        if part and part.Parent then
            local pz = getZoneOf(part.Position)
            if pz == zone then
                local dist = (part.Position - hrp.Position).Magnitude
                if entry.value > bestVal or (entry.value == bestVal and dist < bestDist) then
                    bestVal = entry.value
                    bestDist = dist
                    best = entry
                end
            end
        end
    end

    -- Fallback: kalau zone detection gagal, pakai egg terdekat di zona
    if not best then
        for _, entry in ipairs(State.EggValues) do
            local part = entry.part
            if part and part.Parent then
                local pz = getZoneOf(part.Position)
                if pz == zone then
                    local dist = (part.Position - hrp.Position).Magnitude
                    if dist < bestDist then
                        bestDist = dist
                        best = entry
                    end
                end
            end
        end
    end

    if best then
        for _, p in ipairs(State.PromptCache) do
            local pp = p:IsA("BasePart") and p or p.Parent
            if pp == best.part then return p, best end
        end
    end
    return nil
end

--=========================================================
--  BASE
--=========================================================
local function detectBase()
    for _, obj in ipairs(workspace:GetDescendants()) do
        local n = obj.Name:lower()
        if obj:IsA("BasePart") and (n:find("base") or n:find("spawn") or n:find("home") or n:find("plot")) then
            if n:find(LocalPlayer.Name:lower()) or n:find("player") then
                State.BaseCFrame = obj.CFrame + Vector3.new(0, 4, 0); return
            end
            if not State.BaseCFrame then State.BaseCFrame = obj.CFrame + Vector3.new(0, 4, 0) end
        end
    end
    if not State.BaseCFrame then
        local sp = workspace:FindFirstChildOfClass("SpawnLocation")
        if sp then State.BaseCFrame = sp.CFrame + Vector3.new(0, 4, 0) end
    end
end

--=========================================================
--  LARI KE TARGET
--=========================================================
local function runTo(targetPos, speed)
    local hum = getHum()
    local hrp = getHRP()
    if not hum or not hrp or not targetPos then return end
    local oldSpeed = hum.WalkSpeed
    hum.WalkSpeed = speed

    if Config.UseFlyOnMove or Config.Fly then
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        bv.Velocity = (targetPos - hrp.Position).Unit * speed
        bv.Parent = hrp
        local timeout = tick() + ((targetPos - hrp.Position).Magnitude / speed) + 1.5
        while tick() < timeout do
            local h = getHRP()
            if not h then break end
            if (h.Position - targetPos).Magnitude < 4 then break end
            bv.Velocity = (targetPos - h.Position).Unit * speed
            RunService.Heartbeat:Wait()
        end
        bv:Destroy()
    else
        hum:MoveTo(targetPos)
        local timeout = tick() + ((targetPos - hrp.Position).Magnitude / speed) + 2
        while tick() < timeout do
            local h = getHRP()
            if not h then break end
            if (h.Position - targetPos).Magnitude < 4 then break end
            RunService.Heartbeat:Wait()
        end
    end

    hum.WalkSpeed = oldSpeed
end

local function firePrompt(p)
    if not p then return end
    safeCall(function()
        if p:IsA("ProximityPrompt") then fireproximityprompt(p)
        elseif p:IsA("ClickDetector") then fireclickdetector(p) end
    end)
end

--=========================================================
--  STEAL DI ZONA SEKARANG
--=========================================================
local function stealLocalZone()
    scanWorld()
    if not State.BaseCFrame then detectBase() end

    local targetPrompt, entry = getHighestEggInZone()
    if not targetPrompt then return end

    local part = entry.part
    if part and part.Parent then
        runTo(part.Position, Config.RunSpeed)
        task.wait(0.1)
        for _, p in ipairs(State.PromptCache) do
            local pp = p:IsA("BasePart") and p or p.Parent
            if pp == part then firePrompt(p); break end
        end
        task.wait(0.15)
    end

    if Config.ReturnToBase and State.BaseCFrame then
        runTo(State.BaseCFrame.Position, Config.RunSpeed)
        task.wait(0.1)
        for _, p in ipairs(State.PromptCache) do
            local pp = p:IsA("BasePart") and p or p.Parent
            if pp and pp:IsA("BasePart") and State.BaseCFrame then
                if (pp.Position - State.BaseCFrame.Position).Magnitude < 30 then firePrompt(p) end
            end
        end
    end
end

local function startAutoSteal()
    if State.StealConn then return end
    State.StealConn = task.spawn(function()
        while task.wait(Config.AutoStealDelay) do
            if Config.AutoSteal then safeCall(stealLocalZone) end
        end
    end)
end

local function startInstantSteal()
    if State.InstConn then return end
    State.InstConn = task.spawn(function()
        while task.wait(0.05) do
            if Config.InstantSteal then
                scanWorld()
                for _, p in ipairs(State.PromptCache) do firePrompt(p) end
            end
        end
    end)
end

--=========================================================
--  ANTI HIT / GUARD / TRAP
--=========================================================
local function godModeLoop()
    if State.GodConn then return end
    State.GodConn = RunService.Heartbeat:Connect(function()
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        if Config.AntiHit then
            hum.Health = hum.MaxHealth
            hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
        end
        if Config.AntiGuard then
            for _, obj in ipairs(workspace:GetDescendants()) do
                local n = obj.Name:lower()
                if obj:IsA("BasePart") and (n:find("guard") or n:find("npc") or n:find("cop") or n:find("police") or n:find("enemy")) then
                    obj.CanTouch = false; obj.CanCollide = false; obj.Transparency = 0.6
                end
                if obj:IsA("Humanoid") and obj.Parent ~= char then
                    local pn = obj.Parent.Name:lower()
                    if pn:find("guard") or pn:find("npc") or pn:find("cop") or pn:find("police") or pn:find("enemy") then
                        obj.Health = 0
                    end
                end
            end
        end
        if Config.AntiTrap then
            for _, d in ipairs(char:GetDescendants()) do
                if d:IsA("BasePart") then d.CanCollide = false; d.CanTouch = false end
            end
            for _, obj in ipairs(workspace:GetDescendants()) do
                local n = obj.Name:lower()
                if obj:IsA("BasePart") and (n:find("trap") or n:find("kill") or n:find("damage") or n:find("lava") or n:find("spike") or n:find("laser")) then
                    obj.CanTouch = false; obj.CanCollide = false; obj.Transparency = 0.5
                end
            end
        end
        if Config.AntiRagdoll then
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            hum.PlatformStand = false
        end
    end)
end

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
                    local hum = getHum()
                    if hum then hum:MoveTo(obj.Position) end
                end
                break
            end
        end
    end)
end

local function setupFly()
    if State.FlyConn then State.FlyConn:Disconnect() end
    if State.FlyBV then State.FlyBV:Destroy(); State.FlyBV = nil end
    if not Config.Fly then return end
    local hrp = getHRP(); if not hrp then return end
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
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
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then d += Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then d -= Vector3.new(0, 1, 0) end
        State.FlyBV.Velocity = d.Magnitude > 0 and d.Unit * Config.FlySpeed or Vector3.zero
    end)
end

local function startESP()
    if State.ESPConn then return end
    State.ESPConn = RunService.RenderStepped:Connect(function()
        for _, o in ipairs(State.ESPObjects) do pcall(function() o:Remove() end) end
        State.ESPObjects = {}
        if not Config.EggESP then return end
        local zone = getCurrentZone()
        for _, part in ipairs(State.EggCache) do
            local inZone = (not zone) or (getZoneOf(part.Position) == zone)
            local sp, on = Camera:WorldToViewportPoint(part.Position)
            if on then
                local txt = Drawing.new("Text")
                local val = getEggValue(part)
                txt.Text = part.Name .. (val > 0 and " ($" .. val .. ")" or "")
                txt.Size = 13; txt.Center = true; txt.Outline = true
                if inZone then
                    txt.Color = val > 5000 and Color3.fromRGB(255, 80, 80) or (val > 1000 and Color3.fromRGB(255, 200, 80) or Color3.fromRGB(120, 220, 255))
                else
                    txt.Color = Color3.fromRGB(120, 120, 120)
                end
                txt.Position = Vector2.new(sp.X, sp.Y)
                txt.Visible = true
                table.insert(State.ESPObjects, txt)
            end
        end
    end)
end

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
        local char = LocalPlayer.Character; if not char then return end
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end)
end

local function applySpeed()
    local hum = getHum()
    if hum then hum.WalkSpeed = Config.SpeedHack and Config.WalkSpeed or 16 end
end

--=========================================================
--  GUI
--=========================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VhalzethHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = (gethui and gethui()) or LocalPlayer:WaitForChild("PlayerGui")

local FloatBtn = Instance.new("ImageButton")
FloatBtn.Size = UDim2.fromOffset(56, 56)
FloatBtn.Position = UDim2.new(0, 20, 0.5, -28)
FloatBtn.BackgroundColor3 = Color3.fromRGB(25, 20, 40)
FloatBtn.BorderSizePixel = 0
FloatBtn.Image = LOGO_URL
FloatBtn.Visible = false
FloatBtn.Parent = ScreenGui
local fbc = Instance.new("UICorner"); fbc.CornerRadius = UDim.new(0, 28); fbc.Parent = FloatBtn
local fbs = Instance.new("UIStroke"); fbs.Color = Color3.fromRGB(130, 90, 210); fbs.Thickness = 2; fbs.Parent = FloatBtn
FloatBtn.Draggable = true

FloatBtn.MouseButton1Click:Connect(function()
    FloatBtn.Visible = false
    Main.Visible = true
    State.Minimized = false
end)

local Main = Instance.new("Frame")
Main.Size = UDim2.fromOffset(460, 520)
Main.Position = UDim2.new(0.5, -230, 0.5, -260)
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Visible = true
Main.Parent = ScreenGui
local mc = Instance.new("UICorner"); mc.CornerRadius = UDim.new(0, 10); mc.Parent = Main
local ms = Instance.new("UIStroke"); ms.Color = Color3.fromRGB(130, 90, 210); ms.Thickness = 1; ms.Transparency = 0.3; ms.Parent = Main

local Top = Instance.new("Frame")
Top.Size = UDim2.new(1, 0, 0, 60)
Top.BackgroundColor3 = Color3.fromRGB(30, 22, 46)
Top.BorderSizePixel = 0
Top.Parent = Main
local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(0, 10); tc.Parent = Top

local LogoImg = Instance.new("ImageLabel")
LogoImg.Size = UDim2.fromOffset(44, 44)
LogoImg.Position = UDim2.fromOffset(10, 8)
LogoImg.BackgroundColor3 = Color3.fromRGB(45, 35, 65)
LogoImg.BorderSizePixel = 0
LogoImg.Image = LOGO_URL
LogoImg.ScaleType = Enum.ScaleType.Fit
LogoImg.Parent = Top
local lic = Instance.new("UICorner"); lic.CornerRadius = UDim.new(0, 8); lic.Parent = LogoImg
local lis = Instance.new("UIStroke"); lis.Color = Color3.fromRGB(160, 120, 240); lis.Thickness = 1; lis.Parent = LogoImg

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -140, 0, 20)
Title.Position = UDim2.fromOffset(66, 10)
Title.BackgroundTransparency = 1
Title.Text = "Vhalzeth Hub"
Title.TextColor3 = Color3.fromRGB(235, 225, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 15
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Top

local Subtitle = Instance.new("TextLabel")
Subtitle.Size = UDim2.new(1, -140, 0, 16)
Subtitle.Position = UDim2.fromOffset(66, 30)
Subtitle.BackgroundTransparency = 1
Subtitle.Text = "Steal An Egg Edition"
Subtitle.TextColor3 = Color3.fromRGB(170, 150, 210)
Subtitle.Font = Enum.Font.Gotham
Subtitle.TextSize = 11
Subtitle.TextXAlignment = Enum.TextXAlignment.Left
Subtitle.Parent = Top

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.fromOffset(28, 28)
MinBtn.Position = UDim2.new(1, -68, 0, 16)
MinBtn.BackgroundColor3 = Color3.fromRGB(50, 45, 70)
MinBtn.Text = "—"
MinBtn.TextColor3 = Color3.fromRGB(220, 220, 240)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 16
MinBtn.BorderSizePixel = 0
MinBtn.Parent = Top
local mnc = Instance.new("UICorner"); mnc.CornerRadius = UDim.new(0, 6); mnc.Parent = MinBtn
MinBtn.MouseButton1Click:Connect(function()
    Main.Visible = false; FloatBtn.Visible = true; State.Minimized = true
end)

local Close = Instance.new("TextButton")
Close.Size = UDim2.fromOffset(28, 28)
Close.Position = UDim2.new(1, -34, 0, 16)
Close.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
Close.Text = "×"
Close.TextColor3 = Color3.fromRGB(255, 200, 200)
Close.Font = Enum.Font.GothamBold
Close.TextSize = 16
Close.BorderSizePixel = 0
Close.Parent = Top
local ccc = Instance.new("UICorner"); ccc.CornerRadius = UDim.new(0, 6); ccc.Parent = Close
Close.MouseButton1Click:Connect(function()
    Main.Visible = false; FloatBtn.Visible = true; State.Minimized = true
end)

local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1, -16, 1, -76)
Scroll.Position = UDim2.fromOffset(8, 68)
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

mkButton("Set Base Sekarang (posisi kamu)", function()
    local hrp = getHRP()
    if hrp then
        State.BaseCFrame = hrp.CFrame
        StarterGui:SetCore("SendNotification", {Title = "Vhalzeth", Text = "Base disimpan.", Duration = 2})
    end
end)

mkButton("Auto Deteksi Base", function()
    State.BaseCFrame = nil
    detectBase()
end)

mkButton("Scan Zona Sekarang", function()
    detectZones()
    StarterGui:SetCore("SendNotification", {
        Title = "Vhalzeth",
        Text = "Zona terdeteksi: " .. #State.Zones,
        Duration = 2
    })
end)

mkButton("Steal Egg Termahal (Zona Ini)", function()
    safeCall(function()
        scanWorld()
        local p, entry = getHighestEggInZone()
        if p and entry and entry.part and entry.part.Parent then
            runTo(entry.part.Position, Config.RunSpeed)
            task.wait(0.1)
            firePrompt(p)
            if Config.ReturnToBase and State.BaseCFrame then
                task.wait(0.2)
                runTo(State.BaseCFrame.Position, Config.RunSpeed)
            end
        end
    end)
end)

mkButton("Tampilkan Daftar Telur (Console)", function()
    scanWorld()
    print("=== DAFTAR TELUR (MAHAL -> MURAH) ===")
    for i, e in ipairs(State.EggValues) do
        local zone = e.part and getZoneOf(e.part.Position)
        print(i .. ". " .. e.name .. " | Value: " .. e.value .. " | Zona: " .. (zone and zone.name or "?"))
    end
end)

mkToggle("Auto Steal (Zona Sekarang)", false, function(on) Config.AutoSteal = on; if on then startAutoSteal() end end)
mkToggle("Instant Steal All", false, function(on) Config.InstantSteal = on; if on then startInstantSteal() end end)
mkToggle("Prioritaskan Egg Termahal", true, function(on) Config.PrioritizeHigh = on end)
mkToggle("Auto Balik Base Setelah Steal", true, function(on) Config.ReturnToBase = on end)
mkToggle("Pakai Fly Saat Bergerak", false, function(on) Config.UseFlyOnMove = on end)
mkToggle("Auto Treadmill", false, function(on) Config.AutoTreadmill = on; if on then startAutoTreadmill() end end)
mkToggle("Anti Hit (God Mode)", false, function(on) Config.AntiHit = on end)
mkToggle("Anti Guard / NPC", false, function(on) Config.AntiGuard = on end)
mkToggle("Anti Trap", false, function(on) Config.AntiTrap = on end)
mkToggle("Anti Ragdoll", false, function(on) Config.AntiRagdoll = on end)
mkToggle("Egg ESP", false, function(on) Config.EggESP = on; if on then startESP() end end)
mkToggle("Noclip", false, function(on) Config.Noclip = on end)
mkToggle("Infinite Jump", false, function(on) Config.InfJump = on end)
mkToggle("Speed Hack", false, function(on) Config.SpeedHack = on; applySpeed() end)
mkToggle("Fly", false, function(on) Config.Fly = on; setupFly() end)

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

--=========================================================
--  STARTUP
--=========================================================
godModeLoop()
startMisc()
detectZones()
scanWorld()
detectBase()
startAutoSteal()
startInstantSteal()
startESP()

track(LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    applySpeed()
    if Config.Fly then setupFly() end
end))

safeCall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "Vhalzeth Hub",
        Text = "Loaded. Auto Steal cuma di zona sekarang.",
        Duration = 5
    })
end)
