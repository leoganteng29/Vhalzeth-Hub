local out = {}
local rs = game:GetService("ReplicatedStorage")

table.insert(out, "=== AREA PROGRESSION ===")
local ok1, areas = pcall(function() return require(rs.Data.Areas) end)
if ok1 and areas and areas.GetProgressionOrder then
    local ok2, order = pcall(function() return areas.GetProgressionOrder() end)
    if ok2 and type(order) == "table" then
        for i, a in ipairs(order) do
            table.insert(out, i .. ". " .. tostring(a))
        end
    end
end

table.insert(out, "=== RARITY LIST ===")
local ok3, rar = pcall(function() return require(rs.Data.Rarity) end)
if ok3 and rar and rar.Rarities then
    if type(rar.Rarities) == "table" then
        for k, v in pairs(rar.Rarities) do
            table.insert(out, tostring(k) .. " = " .. tostring(v))
        end
    end
end

table.insert(out, "=== EGGSTATE CARRY TEST ===")
local ok4, state = pcall(function() return require(rs.Client.EggState) end)
if ok4 and state then
    for k, v in pairs(state) do
        table.insert(out, tostring(k) .. " | " .. typeof(v))
    end
end

table.insert(out, "=== REMOTES.EGGWORLD ===")
local ok5, rem = pcall(function() return require(rs.Shared.Remotes) end)
if ok5 and rem then
    if rem.EggWorld then
        for k, v in pairs(rem.EggWorld) do
            table.insert(out, "EggWorld." .. tostring(k) .. " | " .. typeof(v))
        end
    end
    if rem.EggCapture then
        for k, v in pairs(rem.EggCapture) do
            table.insert(out, "EggCapture." .. tostring(k) .. " | " .. typeof(v))
        end
    end
    if rem.GuardPatrol then
        for k, v in pairs(rem.GuardPatrol) do
            table.insert(out, "GuardPatrol." .. tostring(k) .. " | " .. typeof(v))
        end
    end
end

-- Cari RemoteEvent di ReplicatedStorage secara global
table.insert(out, "=== ALL REMOTEEVENTS ===")
local c = 0
for _, v in ipairs(rs:GetDescendants()) do
    if (v:IsA("RemoteEvent") or v:IsA("RemoteFunction")) and c < 40 then
        table.insert(out, v.ClassName .. " | " .. v:GetFullName())
        c = c + 1
    end
end

local final = table.concat(out, "\n")
print(final)
if setclipboard then setclipboard(final) end
game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "SCAN FINAL",
    Text = setclipboard and "Hasil sudah di-copy!" or "Cek console",
    Duration = 5
})
