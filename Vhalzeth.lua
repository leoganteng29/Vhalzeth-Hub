local out = {}

local function dump(mod, label)
    table.insert(out, "=== " .. label .. " ===")
    if not mod then
        table.insert(out, "NOT FOUND")
        return
    end
    local ok, result = pcall(function() return require(mod) end)
    if not ok then
        table.insert(out, "ERROR: " .. tostring(result))
        return
    end
    if type(result) ~= "table" then
        table.insert(out, "TYPE: " .. type(result) .. " | VALUE: " .. tostring(result))
        return
    end
    local c = 0
    for k, v in pairs(result) do
        if c < 25 then
            local vs = type(v) == "table" and ("{table, " .. #v .. " items}") or tostring(v)
            table.insert(out, "  " .. tostring(k) .. " = " .. vs)
            c = c + 1
        end
    end
    table.insert(out, "TOTAL KEYS: " .. tostring((function() local n=0 for _ in pairs(result) do n=n+1 end return n end)()))
end

local rs = game:GetService("ReplicatedStorage")
dump(rs.Data.Areas, "DATA.AREAS")
dump(rs.Data.Rarity, "DATA.RARITY")
dump(rs.Data.Currency, "DATA.CURRENCY")
dump(rs.Shared.Remotes, "SHARED.REMOTES")
dump(rs.Client.EggState, "CLIENT.EGGSTATE")

-- Sample egg di Shared.Eggs
table.insert(out, "=== SHARED.EGGS CONTENT ===")
local eggsF = rs.Shared:FindFirstChild("Eggs")
if eggsF then
    local c = 0
    for _, v in ipairs(eggsF:GetChildren()) do
        if c < 15 then
            table.insert(out, "  " .. v.ClassName .. " | " .. v.Name)
            if v:IsA("ModuleScript") then
                local ok2, r2 = pcall(function() return require(v) end)
                if ok2 and type(r2) == "table" then
                    local c2 = 0
                    for k2, v2 in pairs(r2) do
                        if c2 < 6 then
                            table.insert(out, "    " .. tostring(k2) .. " = " .. (type(v2) == "table" and "{" .. #v2 .. "}" or tostring(v2)))
                            c2 = c2 + 1
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
if setclipboard then setclipboard(final) end
game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "SCAN MODULE",
    Text = setclipboard and "Hasil sudah di-copy!" or "Cek console",
    Duration = 5
})
