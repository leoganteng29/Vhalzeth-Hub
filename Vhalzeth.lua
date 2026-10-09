local text = "SCAN:\n"
local w = workspace:FindFirstChild("World")
local a = w and w:FindFirstChild("Areas")
local g = a and a:FindFirstChild("GuardAreas")
if g then
    text = text .. "Area: "
    for _, area in ipairs(g:GetChildren()) do
        text = text .. area.Name .. ", "
    end
    text = text .. "\n"
end
local aes = workspace:FindFirstChild("AreaEggSlotsClient")
if aes then
    local c = 0
    for _, slot in ipairs(aes:GetChildren()) do
        if c < 3 then
            text = text .. "Egg: " .. slot.Name .. "\n"
            c = c + 1
        end
    end
end
local rs = game:GetService("ReplicatedStorage")
local client = rs:FindFirstChild("Client")
if client then
    text = text .. "Client: "
    for _, v in ipairs(client:GetChildren()) do
        text = text .. v.Name .. ", "
    end
end

print(text)
game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "Scan Hasil",
    Text = string.sub(text, 1, 200),
    Duration = 15
})
