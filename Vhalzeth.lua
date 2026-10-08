local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local HttpService       = game:GetService("HttpService")
local TeleportService   = game:GetService("TeleportService")
local StarterGui        = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

local Config = {
    AutoSteal            = false,
    AutoStealDelay       = 0.3,
    AutoTreadmill        = false,
    AutoUpgradeTreadmill = false,
    AntiTrap             = false,
    AntiHit              = false,
    AntiRagdoll          = false,
    InstantSteal         = false,
    TeleportToEgg        = false,
    AutoPlaceEgg         = false,
    AutoHatch            = false,
    EggESP               = false,
    InfJump              = false,
    FlySpeed             = 60,
    Fly                  = false,
}

local State = {
    Connections   = {},
    ESPObjects    = {},
    FlyBV         = nil,
    AutoStealConn = nil,
    CurrentEgg    = nil,
}

local function safeCall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then warn("[Vhalzeth Hub] " .. tostring(err)) end
    return ok
end

local function track(conn)
    table.insert(State.Connections, conn)
end

local function getCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getHRP()
    local char = getCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local char = getCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getEggs()
    local eggs = {}
    local parents = {
        workspace:FindFirstChild("Eggs"),
        workspace:FindFirstChild("EggFolder"),
        workspace:FindFirstChild("Nests"),
        workspace,
    }
    for _, parent in ipairs(parents) do
        if parent then
            for _, obj in ipairs(parent:GetDescendants()) do
                if obj:IsA("BasePart") and (obj.Name:lower():find("egg") or obj.Name:lower():find("nest")) then
                    table.insert(eggs, obj)
                end
            end
        end
    end
    return eggs
end

local function getTreadmill()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name:lower():find("treadmill") and (obj:IsA("BasePart") or obj:IsA("Model")) then
            return obj
        end
    end
    return nil
end

local function getNearestEgg()
    local hrp = getHRP()
    if not hrp then return nil end
    local nearest, nearestDist = nil, math.huge
    for _, egg in ipairs(getEggs()) do
        local pos
        if egg:IsA("BasePart") then
            pos = egg.Position
        elseif egg:IsA("Model") then
            local primary = egg.PrimaryPart or egg:FindFirstChildWhichIsA("BasePart")
            if primary then pos = primary.Position end
        end
        if pos then
            local dist = (pos - hrp.Position).Magnitude
            if dist < nearestDist then
                nearestDist = dist
                nearest = egg
            end
        end
    end
    return nearest
end

local function applyAntiTrap()
    if not Config.AntiTrap then return end
    local char = getCharacter()
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
            part.CanTouch = false
            part.CanQuery = false
        end
    end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and (obj.Name:lower():find("trap") or obj.Name:lower():find("hitbox")) then
            obj.CanTouch = false
            obj.CanCollide = false
        end
    end
end

local function applyAntiHit()
    if not Config.AntiHit then return end
    local hum = getHumanoid()
    if hum then
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
    end
end

local function applyAntiRagdoll()
    if not Config.AntiRagdoll then return end
    local hum = getHumanoid()
    if hum then
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
end

local function startAutoTreadmill()
    if State.TreadmillConn then return end
    State.TreadmillConn = RunService.Heartbeat:Connect(function()
        if not Config.AutoTreadmill then return end
        local hrp = getHRP()
        if not hrp then return end
        local treadmill = getTreadmill()
        if not treadmill then return end
        local targetPos
        if treadmill:IsA("BasePart") then
            targetPos = treadmill.Position
        elseif treadmill:IsA("Model") then
            local primary = treadmill.PrimaryPart or treadmill:FindFirstChildWhichIsA("BasePart")
            if primary then targetPos = primary.Position end
        end
        if targetPos and (hrp.Position - targetPos).Magnitude > 10 then
            hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 5, 0))
        end
    end)
end

local function stealEgg(targetEgg)
    local hrp = getHRP()
    if not hrp or not targetEgg then return end
    local eggPos
    if targetEgg:IsA("BasePart") then
        eggPos = targetEgg.Position
    elseif targetEgg:IsA("Model") then
        local primary = targetEgg.PrimaryPart or targetEgg:FindFirstChildWhichIsA("BasePart")
        if primary then eggPos = primary.Position end
    end
    if eggPos then
        hrp.CFrame = CFrame.new(eggPos + Vector3.new(0, 3, 0))
        task.wait(0.1)
        local prompt = targetEgg:FindFirstChildOfClass("ProximityPrompt")
        if prompt then fireproximityprompt(prompt) end
    end
end

local function startAutoSteal()
    if State.AutoStealConn then return end
    State.AutoStealConn = task.spawn(function()
        while task.wait(Config.AutoStealDelay) do
            if Config.AutoSteal then
                local egg = getNearestEgg()
                if egg then safeCall(stealEgg, egg) end
            end
        end
    end)
end

local function startInstantSteal()
    if State.StealConn then return end
    State.StealConn = RunService.Heartbeat:Connect(function()
        if not Config.InstantSteal and not Config.TeleportToEgg then return end
        local egg = getNearestEgg()
        if egg then
            State.CurrentEgg = egg
            stealEgg(egg)
            if Config.InstantSteal then
                for _, e in ipairs(getEggs()) do stealEgg(e) end
            end
        end
    end)
end

local function startAutoPlace()
    if State.PlaceConn then return end
    State.PlaceConn = RunService.Heartbeat:Connect(function()
        if not Config.AutoPlaceEgg then return end
        local char = getCharacter()
        if not char then return end
        for _, obj in ipairs(char:GetChildren()) do
            if obj:IsA("Tool") or obj.Name:lower():find("egg") then
                for _, prompt in ipairs(workspace:GetDescendants()) do
                    if prompt:IsA("ProximityPrompt") and prompt.ActionText:lower():find("place") then
                        fireproximityprompt(prompt)
                    end
                end
            end
        end
    end)
end

local function startAutoHatch()
    if State.HatchConn then return end
    State.HatchConn = RunService.Heartbeat:Connect(function()
        if not Config.AutoHatch then return end
        for _, prompt in ipairs(workspace:GetDescendants()) do
            if prompt:IsA("ProximityPrompt") and prompt.ActionText:lower():find("hatch") then
                fireproximityprompt(prompt)
            end
        end
    end)
end

local function startEggESP()
    if State.ESPConn then return end
    State.ESPConn = RunService.RenderStepped:Connect(function()
        for _, obj in ipairs(State.ESPObjects) do pcall(function() obj:Remove() end) end
        State.ESPObjects = {}
        if not Config.EggESP then return end
        for _, egg in ipairs(getEggs()) do
            local pos
            if egg:IsA("BasePart") then
                pos = egg.Position
            elseif egg:IsA("Model") then
                local primary = egg.PrimaryPart or egg:FindFirstChildWhichIsA("BasePart")
                if primary then pos = primary.Position end
            end
            if pos then
                local screenPos, onScreen = Camera:WorldToViewportPoint(pos)
                if onScreen then
                    local text = Drawing.new("Text")
                    text.Text = egg.Name
                    text.Size = 14
                    text.Center = true
                    text.Outline = true
                    text.Color = Color3.fromRGB(255, 220, 100)
                    text.Position = Vector2.new(screenPos.X, screenPos.Y)
                    text.Visible = true
                    table.insert(State.ESPObjects, text)
                end
            end
        end
    end)
end

local function setupInfJump()
    if State.JumpConn then return end
    State.JumpConn = UserInputService.JumpRequest:Connect(function()
        if not Config.InfJump then return end
        local hum = getHumanoid()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end)
end

local function setupFly()
    if State.FlyConn then State.FlyConn:Disconnect() end
    if not Config.Fly then
        if State.FlyBV then State.FlyBV:Destroy(); State.FlyBV = nil end
        return
    end
    local hrp = getHRP()
    if not hrp then return end
    local bv = Instance.new("BodyVelocity")
    bv.Name = "VhalzethFly"
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.Velocity = Vector3.zero
    bv.Parent = hrp
    State.FlyBV = bv
    State.FlyConn = RunService.RenderStepped:Connect(function()
        if not Config.Fly or not State.FlyBV or not State.FlyBV.Parent then return end
        local dir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.new(0, 1, 0) end
        State.FlyBV.Velocity = dir.Magnitude > 0 and dir.Unit * Config.FlySpeed or Vector3.zero
    end)
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VhalzethHubUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = (gethui and gethui()) or LocalPlayer:WaitForChild("PlayerGui")

local Main = Instance.new("Frame")
Main.Size = UDim2.fromOffset(420, 460)
Main.Position = UDim2.new(0.5, -210, 0.5, -230)
Main.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = Main

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(120, 90, 200)
stroke.Thickness = 1
stroke.Transparency = 0.3
stroke.Parent = Main

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 36)
TopBar.BackgroundColor3 = Color3.fromRGB(28, 22, 42)
TopBar.BorderSizePixel = 0
TopBar.Parent = Main

local topCorner = Instance.new("UICorner")
topCorner.CornerRadius = UDim.new(0, 10)
topCorner.Parent = TopBar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -50, 1, 0)
Title.Position = UDim2.fromOffset(12, 0)
Title.BackgroundTransparency = 1
Title.Text = "Vhalzeth Hub  •  Steal An Egg"
Title.TextColor3 = Color3.fromRGB(230, 220, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.fromOffset(28, 28)
CloseBtn.Position = UDim2.new(1, -34, 0, 4)
CloseBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
CloseBtn.Text = "×"
CloseBtn.TextColor3 = Color3.fromRGB(255, 200, 200)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 16
CloseBtn.BorderSizePixel = 0
CloseBtn.Parent = TopBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = CloseBtn

CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui.Enabled = false
end)

local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1, -16, 1, -50)
Scroll.Position = UDim2.fromOffset(8, 44)
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 4
Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.Parent = Main

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = Scroll

local function createToggle(text, default, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 34)
    row.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
    row.BorderSizePixel = 0
    row.Parent = Scroll
    local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 6); rc.Parent = row
    local rs = Instance.new("UIStroke"); rs.Color = Color3.fromRGB(70, 60, 100); rs.Thickness = 1; rs.Transparency = 0.5; rs.Parent = row

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -110, 1, 0)
    label.Position = UDim2.fromOffset(12, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(210, 210, 225)
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local on = default or false
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(72, 22)
    btn.Position = UDim2.new(1, -84, 0.5, -11)
    btn.BackgroundColor3 = on and Color3.fromRGB(90, 70, 160) or Color3.fromRGB(60, 60, 70)
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
        btn.BackgroundColor3 = on and Color3.fromRGB(90, 70, 160) or Color3.fromRGB(60, 60, 70)
        if callback then safeCall(callback, on) end
    end)
    return btn
end

local function createButton(text, callback)
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
    local bs = Instance.new("UIStroke"); bs.Color = Color3.fromRGB(90, 75, 140); bs.Thickness = 1; bs.Transparency = 0.5; bs.Parent = btn

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(60, 50, 90)}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(40, 34, 58)}):Play()
    end)
    btn.MouseButton1Click:Connect(function()
        if callback then safeCall(callback) end
    end)
    return btn
end

createToggle("Auto Steal", false, function(on)
    Config.AutoSteal = on
    if on then startAutoSteal() end
end)

createButton("Instant Steal All Eggs", function()
    Config.InstantSteal = true
    for _, egg in ipairs(getEggs()) do stealEgg(egg) end
    task.wait(0.5)
    Config.InstantSteal = false
end)

createButton("Teleport ke Egg Terdekat", function()
    local egg = getNearestEgg()
    if egg then stealEgg(egg) end
end)

createToggle("Auto Treadmill", false, function(on)
    Config.AutoTreadmill = on
    if on then startAutoTreadmill() end
end)

createToggle("Auto Upgrade Treadmill", false, function(on)
    Config.AutoUpgradeTreadmill = on
end)

createToggle("Anti Trap", false, function(on)
    Config.AntiTrap = on
    if on then track(RunService.Heartbeat:Connect(applyAntiTrap)) end
end)

createToggle("Anti Hit", false, function(on)
    Config.AntiHit = on
    if on then track(RunService.Heartbeat:Connect(applyAntiHit)) end
end)

createToggle("Anti Ragdoll", false, function(on)
    Config.AntiRagdoll = on
    if on then track(RunService.Heartbeat:Connect(applyAntiRagdoll)) end
end)

createToggle("Egg ESP", false, function(on)
    Config.EggESP = on
    if on then startEggESP() end
end)

createToggle("Auto Place Egg", false, function(on)
    Config.AutoPlaceEgg = on
    if on then startAutoPlace() end
end)

createToggle("Auto Hatch", false, function(on)
    Config.AutoHatch = on
    if on then startAutoHatch() end
end)

createToggle("Infinite Jump", false, function(on)
    Config.InfJump = on
    if on then setupInfJump() end
end)

createButton("Server Hop (Low Player)", function()
    local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
    local ok, res = pcall(function() return game:HttpGet(url) end)
    if not ok then return end
    local data = HttpService:JSONDecode(res)
    for _, s in ipairs(data.data or {}) do
        if s.id ~= game.JobId and s.playing <= 1 then
            TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
            return
        end
    end
end)

startAutoSteal()
startInstantSteal()
startAutoPlace()
startAutoHatch()
startEggESP()

track(LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if Config.AntiTrap then applyAntiTrap() end
    if Config.AntiHit then applyAntiHit() end
end))

safeCall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "Vhalzeth Hub",
        Text = "Hub siap digunakan.",
        Duration = 4
    })
end)
