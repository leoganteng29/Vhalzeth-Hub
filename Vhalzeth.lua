print("=== AREA NAMES ===")
local areasFolder = workspace:FindFirstChild("World")
areasFolder = areasFolder and areasFolder:FindFirstChild("Areas")
local guardAreas = areasFolder and areasFolder:FindFirstChild("GuardAreas")
if guardAreas then
    for _, area in ipairs(guardAreas:GetChildren()) do
        print("AREA:", area.Name, "| Class:", area.ClassName)
        local nests = area:FindFirstChild("Nests")
        if nests then
            for _, nest in ipairs(nests:GetChildren()) do
                if nest.Name:lower():find("nest") then
                    print("  NEST:", nest:GetFullName())
                    for _, child in ipairs(nest:GetDescendants()) do
                        if child:IsA("NumberValue") or child:IsA("IntValue") or child:IsA("StringValue") then
                            print("    VALUE:", child.ClassName, child.Name, "=", child.Value)
                        end
                        if child:IsA("BasePart") and (child.Name:lower():find("egg") or child.Name:lower():find("value")) then
                            print("    PART:", child.Name)
                            for _, a in ipairs(child:GetAttributes()) do
                                print("      ATTR:", a, "=", child:GetAttribute(a))
                            end
                        end
                    end
                end
            end
        end
        break
    end
end

print("=== EGG SLOTS SAMPLE ===")
local aes = workspace:FindFirstChild("AreaEggSlotsClient")
if aes then
    local c = 0
    for _, slot in ipairs(aes:GetChildren()) do
        if c < 10 then
            print("SLOT:", slot.Name)
            for _, d in ipairs(slot:GetDescendants()) do
                if d:IsA("NumberValue") or d:IsA("IntValue") or d:IsA("StringValue") then
                    print("  VAL:", d.ClassName, d.Name, "=", d.Value)
                end
                if d:IsA("BasePart") then
                    for _, a in ipairs(d:GetAttributes()) do
                        print("  ATTR:", d.Name, a, "=", d:GetAttribute(a))
                    end
                end
            end
            c = c + 1
        end
    end
end

print("=== REPLICATEDSTORAGE DATA ===")
local dataFolder = game:GetService("ReplicatedStorage"):FindFirstChild("Data")
if dataFolder then
    for _, v in ipairs(dataFolder:GetChildren()) do
        print("DATA:", v.ClassName, v.Name)
        for _, c in ipairs(v:GetChildren()) do
            if c:IsA("ModuleScript") or c:IsA("StringValue") or c:IsA("Folder") then
                print("  -", c.ClassName, c.Name)
            end
        end
    end
end
