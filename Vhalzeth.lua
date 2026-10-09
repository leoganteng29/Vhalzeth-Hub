local rs = game:GetService("ReplicatedStorage")
local out = {}

table.insert(out, "=== REMOTE PATHS ===")
for _, v in ipairs(rs:GetDescendants()) do
    if (v:IsA("RemoteEvent") or v:IsA("RemoteFunction")) and v.Name:lower():find("egg") then
        table.insert(out, v.ClassName .. " | " .. v:GetFullName())
    end
end

table.insert(out, "=== NAMECALL HOOK TEST ===")
local mt = getrawmetatable(game)
local oldNC = mt.__namecall
local method = getnamecallmethod
setreadonly(mt, false)
mt.__namecall = newcclosure(function(self, ...)
    local m = method()
    if (m == "FireServer" or m == "InvokeServer") and typeof(self) == "Instance" then
        local n = self:GetFullName()
        if n:lower():find("egg") or n:lower():find("carry") or n:lower():find("guard") then
            warn("[EGG-REMOTE] " .. n .. " | " .. m .. " | " .. tostring(...))
        end
    end
    return oldNC(self, ...)
end)
setreadonly(mt, true)

print(table.concat(out, "\n"))
if setclipboard then setclipboard(table.concat(out, "\n")) end
game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "HOOK AKTIF",
    Text = "Sekarang ambil egg manual 1x, lihat console",
    Duration = 8
})
