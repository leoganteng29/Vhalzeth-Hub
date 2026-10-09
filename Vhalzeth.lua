local out = {}
table.insert(out, "=== WORKSPACE CHILDREN ===")
for _,v in ipairs(workspace:GetChildren()) do
    table.insert(out, v.ClassName .. " | " .. v.Name)
end

table.insert(out, "=== REPLICATEDSTORAGE ===")
for _,v in ipairs(game:GetService("ReplicatedStorage"):GetChildren()) do
    table.insert(out, v.ClassName .. " | " .. v.Name)
end

table.insert(out, "=== AREA/EZONE SCAN ===")
for _,v in ipairs(workspace:GetDescendants()) do
    local n = v.Name:lower()
    if n:find("forest") or n:find("lake") or n:find("desert") or n:find("jungle")
    or n:find("snow") or n:find("volcano") or n:find("abyss") or n:find("cosmic")
    or n:find("cherry") or n:find("titan") or n:find("angel") or n:find("enchanted")
    or n:find("prehistoric") or n:find("area") or n:find("zone") then
        table.insert(out, v.ClassName .. " | " .. v:GetFullName())
    end
end

table.insert(out, "=== EGG SAMPLE ===")
local c = 0
for _,v in ipairs(workspace:GetDescendants()) do
    if v.Name:lower():find("egg") and c < 20 then
        table.insert(out, v.ClassName .. " | " .. v:GetFullName())
        c = c + 1
    end
end

local final = table.concat(out, "\n")
print(final)
setclipboard(final)
warn("[Vhalzeth] Hasil scan sudah di-copy ke clipboard!")
