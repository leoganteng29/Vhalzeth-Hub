local out = {}

table.insert(out, "=== AREA LIST ===")
local g = workspace:FindFirstChild("World")
g = g and g:FindFirstChild("Areas")
g = g and g:FindFirstChild("GuardAreas")
if g then
    for _, area in ipairs(g:GetChildren()) do
        table.insert(out, area.Name)
    end
end

table.insert(out, "=== EGG SLOT SAMPLE (5) ===")
local aes = workspace:FindFirstChild("AreaEggSlotsClient")
if aes then
    local c = 0
    for _, slot in ipairs(aes:GetChildren()) do
        if c < 5 then
            table.insert(out, "SLOT: " .. slot.Name)
            for _, d in ipairs(slot:GetDescendants()) do
                if d:IsA("NumberValue") or d:IsA("IntValue") or d:IsA("StringValue") then
                    table.insert(out, "  " .. d.ClassName .. " " .. d.Name .. " = " .. tostring(d.Value))
                end
                if d:IsA("BasePart") then
                    for _, attr in ipairs(d:GetAttributes()) do
                        table.insert(out, "  @" .. d.Name .. "." .. attr .. " = " .. tostring(d:GetAttribute(attr)))
                    end
                end
            end
            c = c + 1
        end
    end
end

table.insert(out, "=== RS.DATA ===")
local data = game:GetService("ReplicatedStorage"):FindFirstChild("Data")
if data then
    for _, v in ipairs(data:GetChildren()) do
        table.insert(out, v.ClassName .. " | " .. v.Name)
    end
end

table.insert(out, "=== RS.CLIENT ===")
local client = game:GetService("ReplicatedStorage"):FindFirstChild("Client")
if client then
    for _, v in ipairs(client:GetChildren()) do
        table.insert(out, v.ClassName .. " | " .. v.Name)
    end
end

table.insert(out, "=== RS.SHARED ===")
local shared_ = game:GetService("ReplicatedStorage"):FindFirstChild("Shared")
if shared_ then
    for _, v in ipairs(shared_:GetChildren()) do
        table.insert(out, v.ClassName .. " | " .. v.Name)
    end
end

table.insert(out, "=== NEST SAMPLE ===")
if g then
    local c = 0
    for _, area in ipairs(g:GetChildren()) do
        if c < 2 then
            local nests = area:FindFirstChild("Nests")
            if nests then
                table.insert(out, "AREA: " .. area.Name)
                for _, nest in ipairs(nests:GetChildren()) do
                    table.insert(out, "  NEST: " .. nest.Name .. " | " .. nest.ClassName)
                    for _, d in ipairs(nest:GetDescendants()) do
                        if d:IsA("NumberValue") or d:IsA("IntValue") or d:IsA("StringValue") then
                            table.insert(out, "    " .. d.ClassName .. " " .. d.Name .. " = " .. tostring(d.Value))
                        end
                    end
                end
            end
            c = c + 1
        end
    end
end

local final = table.concat(out, "\n")
print(final)
if setclipboard then
    setclipboard(final)
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "SCAN OK",
        Text = "Hasil sudah di-copy ke clipboard!",
        Duration = 5
    })
else
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "SCAN OK",
        Text = "Cek console - " .. #final .. " karakter",
        Duration = 5
    })
end
