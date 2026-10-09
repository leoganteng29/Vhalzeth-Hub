local out = {}

table.insert(out, "=== DATA.AREAS ===")
local areasMod = game:GetService("ReplicatedStorage"):FindFirstChild("Data")
areasMod = areasMod and areasMod:FindFirstChild("Areas")
if areasMod then
    local ok, result = pcall(function() return require(areasMod) end)
    if ok and type(result) == "table" then
        local c = 0
        for k, v in pairs(result) do
            if c < 20 then
                table.insert(out, tostring(k) .. " = " .. tostring(typeof(v)))
                c = c + 1
            end
        end
    else
        table.insert(out, "Error: " .. tostring(result))
    end
end

table.insert(out, "=== DATA.RARITY ===")
local rarMod = game:GetService("ReplicatedStorage"):FindFirstChild("Data")
rarMod = rarMod and rarMod:FindFirstChild("Rarity")
if rarMod then
    local ok, result = pcall(function() return require(rarMod) end)
    if ok and type(result) == "table" then
        local c = 0
        for k, v in pairs(result) do
            if c < 20 then
                table.insert(out, tostring(k) .. " = " .. tostring(typeof(v)))
                c = c + 1
            end
        end
    else
        table.insert(out, "Error: " .. tostring(result))
    end
end

table.insert(out, "=== SHARED.EGGS ===")
local eggsF = game:GetService("ReplicatedStorage"):FindFirstChild("Shared")
eggsF = eggsF and eggsF:FindFirstChild("Eggs")
if eggsF then
    for _, v in ipairs(eggsF:GetChildren()) do
        table.insert(out, v.ClassName .. " | " .. v.Name)
    end
end

table.insert(out, "=== SHARED.REMOTES ===")
local remMod = game:GetService("ReplicatedStorage"):FindFirstChild("Shared")
remMod = remMod and remMod:FindFirstChild("Remotes")
if remMod then
    local ok, result = pcall(function() return require(remMod) end)
    if ok and type(result) == "table" then
        local c = 0
        for k, v in pairs(result) do
            if c < 30 then
                table.insert(out, tostring(k) .. " = " .. tostring(typeof(v)))
                c = c + 1
            end
        end
    else
        table.insert(out, "Error: " .. tostring(result))
    end
end

table.insert(out, "=== CLIENT.EGGSTATE ===")
local eggState = game:GetService("ReplicatedStorage"):FindFirstChild("Client")
eggState = eggState and eggState:FindFirstChild("EggState")
if eggState then
    local ok, result = pcall(function() return require(eggState) end)
    if ok and type(result) == "table" then
        local c = 0
        for k, v in pairs(result) do
            if c < 20 then
                table.insert(out, tostring(k) .. " = " .. tostring(typeof(v)))
                c = c + 1
            end
        end
    else
        table.insert(out, "Error: " .. tostring(result))
    end
end

local final = table.concat(out, "\n")
print(final)
if setclipboard then
    setclipboard(final)
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "SCAN MODULE",
        Text = "Hasil sudah di-copy ke clipboard!",
        Duration = 5
    })
end
