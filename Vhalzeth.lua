--[[
╭━━━〔 📜 VHALZETH HUB 〕━━━╮

🔥 SCRIPT : loadstring(game:HttpGet("https://raw.githubusercontent.com/leoganteng29/Vhalzeth-Hub/refs/heads/main/Vhalzeth.lua"))()

🗺️ MAP : [STEAL AN EGG]
🔑 KEY : [NO KEY]
⚙️ STATUS : WORKING

📌 FITUR :
• [Auto Steal Per Area]
• [Prioritas Rarity Tertinggi]
• [Filter Area Spesifik]
• [Instant Steal]
• [Auto Balik Base]
• [Anti Hit / Anti Guard]
• [Anti Trap]
• [Egg ESP by Rarity]
• [Fly / Noclip / Speed]

🚀 VHALZETH HUB
╰━━━━━━━━━━━━━━━━━━╯
]]

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local StarterGui        = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

local LOGO_URL = "rbxassetid://120546090415288"

local RARITY_ORDER = {
    "BrainrotGod", "Secret", "Eternal", "Transcendent", "Divine",
    "Cosmic", "Titan", "Mythic", "Prismatic", "Rainbow", "Limited",
    "LightDark", "Legendary", "SuperRare", "Epic", "Rare",
    "Uncommon", "Common"
}

local AREA_LIST = {
    "Forest", "Lake", "Desert", "Jungle", "Snow", "Volcano",
    "Abyss Ocean", "Prehistoric", "Cosmic", "Cherry Blossom",
    "Titan Temple", "Enchanted Forest", "Light Dark"
}

local Config = {
    AutoSteal         = false,
    AutoStealDelay    = 0.2,
    InstantSteal      = false,
    PrioritizeRarity  = true,
    MinRarityIndex    = 15,
    TargetArea        = "Auto",
    OnlyTargetArea    = true,
    ReturnToBase      = true,
    RunSpeed          = 60,
    UseFlyOnMove      = false,
    FlySpeed          = 80,
    Fly               = false,
    AntiTrap          = false,
    AntiHit           = false,
    AntiGuard         = false,
    AntiRagdoll       = false,
    AutoTreadmill     = false,
    EggESP            = false,
    InfJump           = false,
    Noclip            = false,
    WalkSpeed         = 32,
    SpeedHack         = false,
}

local State = {
    EggState      = nil,
    Remotes       = nil,
    EggCache      = {},
    PromptCache   = {},
    ESPObjects    = {},
    FlyBV         = nil,
    LastScan      = 0,
    BaseCFrame    = nil,
    Connections   = {},
}

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
--  INIT MODULES
--=========================================================
local function initModules()
    safeCall(function()
        State.EggState = require(ReplicatedStorage.Client.EggState)
    end)
    safeCall(function()
        State.Remotes = require(ReplicatedStorage.Shared.Remotes)
    end)
end

--=========================================================
--  AREA
--=========================================================
local function getGuardAreasFolder()
    local w = workspace:FindFirstChild("World")
    local a = w and w:FindFirstChild("Areas")
    return a and a:FindFirstChild("GuardAreas")
end

local function getCurrentArea()
    local hrp = getHRP()
    if not hrp then return nil end
    if Config.TargetArea ~= "Auto" then return Config.TargetArea end
    local g = getGuardAreasFolder()
    if not g then return nil end
    local closest, closestDist = nil, math.huge
    for _, area in ipairs(g:GetChildren()) do
        local ok, cf = pcall(function() return area:GetPivot() end)
        if ok and cf then
            local d = (cf.Position - hrp.Position).Magnitude
            if d < closestDist then
                closestDist = d
                closest = area.Name
            end
        end
    end
    return closest
end

--=========================================================
--  RARITY HELPER
--=========================================================
local function getRarityIndex(rarityName)
    for i, r in ipairs(RARITY_ORDER) do
        if r == rarityName then return i end
    end
    return 999
end

local function meetsRarity(rarityName)
    if not Config.PrioritizeRarity then return true end
    return getRarityIndex(rarityName) <= Config.MinRarityIndex
end

--=========================================================
--  EGG CACHE
--=========================================================
local function getEggRecord(eggUid)
    if not State.EggState or not State.EggState.FetchEggRecord then return nil end
    local ok, rec = pcall(function() return State.EggState.FetchEggRecord(eggUid) end)
    if ok then return rec end
    return nil
end

local function getFieldEggs()
    if not State.EggState or not State.EggState.ReadFieldEggs then return {} end
    local ok, list = pcall(function() return State.EggState.ReadFieldEggs() end)
    if ok and type(list) == "table" then return list end
    return {}
end

local function getFieldEgg(uid)
    if not State.EggState or not State.EggState.ReadFieldEgg then return nil end
    local ok, egg = pcall(function() return State.EggState.ReadFieldEgg(uid) end)
    if ok then return egg end
    return nil
end

--=========================================================
--  SCAN EGG DI AREA
--=========================================================
local function scanEggs()
    local now = tick()
    if now - State.LastScan < 1 then return end
    State.LastScan = now

    State.EggCache = {}
    State.PromptCache = {}

    local currentArea = getCurrentArea()
    local fieldEggs = getFieldEggs()

    for _, uid in ipairs(fieldEggs) do
        local egg = getFieldEgg(uid)
        if egg and egg.Area then
            local inArea = (not Config.OnlyTargetArea) or (egg.Area == currentArea)
            if inArea then
                table.insert(State.EggCache, {
                    uid = uid,
                    area = egg.Area,
                    rarity = egg.Rarity or "Common",
                    position = egg.Position,
                    record = egg,
                })
            end
        end
    end

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled then
            table.insert(State.PromptCache, obj)
        end
    end
end

local function getBestEgg()
    local hrp = getHRP()
    if not hrp then return nil end
    local best, bestIdx, bestDist = nil, 999, math.huge
    for _, egg in ipairs(State.EggCache) do
        if meetsRarity(egg.rarity) then
            local idx = getRarityIndex(egg.rarity)
            local pos = egg.position or (egg.record and egg.record.Position)
            local dist = pos and (pos - hrp.Position).Magnitude or math.huge
            if idx < bestIdx or (idx == bestIdx and dist < bestDist) then
                bestIdx = idx
                bestDist = dist
                best = egg
            end
        end
    end
    return best
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
--  RUN
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
        if p:IsA("ProximityPrompt") then fireproximityprompt(p) end
    end)
end

local function findPromptNear(pos, maxDist)
    local best, bestDist = nil, maxDist or 30
    for _, p in ipairs(State.PromptCache) do
        local part = p:IsA("BasePart") and p or p.Parent
        if part and part:IsA("BasePart") then
            local d = (part.Position - pos).Magnitude
            if d < bestDist then
                bestDist = d
                best = p
            end
        end
    end
    return best
end

--=========================================================
--  CARRY EGG (via EggState kalau bisa)
--=========================================================
local function carryEgg(uid)
    if not State.EggState or not State.EggState.CarryFieldEgg then return false end
    local ok = pcall(function() State.EggState.CarryFieldEgg(uid) end)
    return ok
end

local function dropEgg()
    if not State.EggState or not State.EggState.DropFieldEgg then return false end
    local ok = pcall(function() State.EggState.DropFieldEgg() end)
    return ok
end

--=========================================================
--  STEAL LOOP
--=========================================================
local function stealStep()
    scanEggs()
    if not State.BaseCFrame then detectBase() end

    local best = getBestEgg()
    if not best then return end

    local pos = best.position or (best.record and best.record.Position)
    if not pos then return end

    runTo(pos, Config.RunSpeed)
    task.wait(0.1)

    local carried = carryEgg(best.uid)
    if not carried then
        local prompt = findPromptNear(pos, 30)
        if prompt then firePrompt(prompt) end
    end
    task.wait(0.15)

    if Config.ReturnToBase and State.BaseCFrame then
        runTo(State.BaseCFrame.Position, Config.RunSpeed)
        task.wait(0.1)
        dropEgg()
        local placePrompt = findPromptNear(State.BaseCFrame.Position, 30)
        if placePrompt then firePrompt(placePrompt) end
    end
end

local function startAutoSteal()
    if State.StealConn then return end
    State.StealConn = task.spawn(function()
        while task.wait(Config.AutoStealDelay) do
            if Config.AutoSteal then safeCall(stealStep) end
        end
    end)
end

local function startInstantSteal()
    if State.InstConn then return end
    State.InstConn = task.spawn(function()
        while task.wait(0.1) do
            if Config.InstantSteal then
                scanEggs()
                local fieldEggs = getFieldEggs()
                for _, uid in ipairs(fieldEggs) do
                    carryEgg(uid)
                end
            end
        end
    end)
end

--=========================================================
--  ANTI
--=========================================================
local function godLoop()
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
            local guards = workspace:FindFirstChild("_Guards")
            if guards then
                for _, g in ipairs(guards:GetDescendants()) do
                    if g:IsA("Humanoid") then g.Health = 0 end
                    if g:IsA("BasePart") then g.CanTouch = false; g.CanCollide = false end
                end
            end
            local gFolder = getGuardAreasFolder()
            if gFolder then
                for _, area in ipairs(gFolder:GetChildren()) do
                    local guardM = area:FindFirstChild("Guard")
                    if guardM then
                        for _, d in ipairs(guardM:GetDescendants()) do
                            if d:IsA("Humanoid") then d.Health = 0 end
                            if d:IsA("BasePart") then d.CanTouch = false; d.CanCollide = false end
                        end
                    end
                end
            end
            -- Disable GuardPatrol
            if State.Remotes and State.Remotes.GuardPatrol and State.Remotes.GuardPatrol.AskEnabled then
                pcall(function()
                    State.Remotes.GuardPatrol.AskEnabled:FireServer(false)
                end)
            end
        end

        if Config.AntiTrap then
            for _, d in ipairs(char:GetDescendants()) do
                if d:IsA("BasePart") then d.CanCollide = false; d.CanTouch = false end
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
        local renders = workspace:FindFirstChild("__ClientTreadmillRenders")
        if renders then
            for _, obj in ipairs(renders:GetChildren()) do
                local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
                if part and (hrp.Position - part.Position).Magnitude > 8 then
                    local hum = getHum()
                    if hum then hum:MoveTo(part.Position) end
                    return
                end
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
        for _, egg in ipairs(State.EggCache) do
            local pos = egg.position or (egg.record and egg.record.Position)
            if pos then
                local sp, on = Camera:WorldToViewportPoint(pos)
                if on then
                    local idx = getRarityIndex(egg.rarity)
                    local col = idx <= 3 and Color3.fromRGB(255, 60, 60)
                        or idx <= 6 and Color3.fromRGB(255, 160, 60)
                        or idx <= 9 and Color3.fromRGB(255, 220, 80)
                        or Color3.fromRGB(120, 220, 255)
                    local txt = Drawing.new("Text")
                    txt.Text = "[" .. egg.rarity .. "] " .. egg.area
                    txt.Size = 13
                    txt.Center = true
                    txt.Outline = true
                    txt.Color = col
                    txt.Position = Vector2.new(sp.X, sp.Y)
                    txt.Visible = true
                    table.insert(State.ESPObjects, txt)
                end
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
end)

local Main = Instance.new("Frame")
Main.Size = UDim2.fromOffset(480, 560)
Main.Position = UDim2.new(0.5, -240, 0.5, -280)
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
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
    Main.Visible = false; FloatBtn.Visible = true
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
    Main.Visible = false; FloatBtn.Visible = true
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

mkButton("Set Base (Posisi Kamu)", function()
    local hrp = getHRP()
    if hrp then
        State.BaseCFrame = hrp.CFrame
        StarterGui:SetCore("SendNotification", {Title = "Vhalzeth", Text = "Base disimpan.", Duration = 2})
    end
end)

mkButton("Scan Egg di Area Ini", function()
    scanEggs()
    local area = getCurrentArea()
    StarterGui:SetCore("SendNotification", {
        Title = "Vhalzeth",
        Text = "Area: " .. tostring(area) .. " | Egg: " .. #State.EggCache,
        Duration = 4
    })
end)

mkButton("Steal Egg Rarity Tertinggi", function()
    safeCall(stealStep)
end)

mkToggle("Auto Steal (Area Sekarang)", false, function(on) Config.AutoSteal = on; if on then startAutoSteal() end end)
mkToggle("Instant Steal All", false, function(on) Config.InstantSteal = on; if on then startInstantSteal() end end)
mkToggle("Prioritaskan Rarity Tinggi", true, function(on) Config.PrioritizeRarity = on end)
mkToggle("Auto Balik Base", true, function(on) Config.ReturnToBase = on end)
mkToggle("Pakai Fly Saat Bergerak", false, function(on) Config.UseFlyOnMove = on end)
mkToggle("Auto Treadmill", false, function(on) Config.AutoTreadmill = on; if on then startAutoTreadmill() end end)
mkToggle("Anti Hit (God Mode)", false, function(on) Config.AntiHit = on end)
mkToggle("Anti Guard / NPC", false, function(on) Config.AntiGuard = on end)
mkToggle("Anti Trap", false, function(on) Config.AntiTrap = on end)
mkToggle("Anti Ragdoll", false, function(on) Config.AntiRagdoll = on end)
mkToggle("Egg ESP by Rarity", false, function(on) Config.EggESP = on; if on then startESP() end end)
mkToggle("Noclip", false, function(on) Config.Noclip = on end)
mkToggle("Infinite Jump", false, function(on) Config.InfJump = on end)
mkToggle("Speed Hack", false, function(on) Config.SpeedHack = on; applySpeed() end)
mkToggle("Fly", false, function(on) Config.Fly = on; setupFly() end)

--=========================================================
--  STARTUP
--=========================================================
initModules()
godLoop()
startMisc()
scanEggs()
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
        Text = "Loaded. EggState: " .. (State.EggState and "OK" or "FAIL") .. " | Remotes: " .. (State.Remotes and "OK" or "FAIL"),
        Duration = 6
    })
end)
