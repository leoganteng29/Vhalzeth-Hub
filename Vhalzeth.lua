local out = {}
for _,v in ipairs(workspace:GetDescendants()) do
    local n = v.Name:lower()
    if n:find("egg") or n:find("treadmill") or n:find("nest") or n:find("steal") or n:find("prompt") then
        table.insert(out, v.ClassName .. " | " .. v:GetFullName())
    end
end
for _,v in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
    local n = v.Name:lower()
    if n:find("egg") or n:find("steal") or n:find("remote") or n:find("event") then
        table.insert(out, "[RS] " .. v.ClassName .. " | " .. v:GetFullName())
    end
end
print(table.concat(out, "\n"))
