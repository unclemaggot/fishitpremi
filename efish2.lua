-- Load Rayfield
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

-- ======= GLOBAL SETUP =======
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local net = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_net@0.2.0"):WaitForChild("net")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local workspace = game:GetService("Workspace")

-- Prevent AFK + enable XP bar
pcall(function()
    local XPBar = LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("XP")
    if XPBar then XPBar.Enabled = true end
end)
if LocalPlayer and LocalPlayer.Idled then
    pcall(function()
        for i,v in next, getconnections(LocalPlayer.Idled) do
            pcall(function() v:Disable() end)
        end
    end)
    pcall(function()
        LocalPlayer.Idled:Connect(function()
            pcall(function()
                local vu = game:GetService("VirtualUser")
                vu:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                task.wait(1)
                vu:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
            end)
        end)
    end)
end

-- Auto-reconnect / teleport on kick
local PlaceId = game.PlaceId
task.spawn(function()
    while task.wait(5) do
        if not Players.LocalPlayer or not Players.LocalPlayer:IsDescendantOf(game) then
            pcall(function() TeleportService:Teleport(PlaceId) end)
        end
    end
end)
Players.LocalPlayer.OnTeleport:Connect(function(state)
    if state == Enum.TeleportState.Failed then
        pcall(function() TeleportService:Teleport(PlaceId) end)
    end
end)

-- Animations / utilities
local successAnim, RodIdleAnimModule, RodReelAnimModule, RodShakeAnimModule = pcall(function()
    return ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Animations"):WaitForChild("FishingRodReelIdle"),
           ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Animations"):WaitForChild("FishingRodReelIdle"),
           ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Animations"):WaitForChild("EasyFishReelStart"),
           ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Animations"):WaitForChild("CastFromFullChargePosition1Hand")
end)
-- Some games may not have these modules accessible in all environments; wrap safely
local character = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
local humanoid = character:FindFirstChild("Humanoid") or character:WaitForChild("Humanoid")
local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
local RodShake, RodIdle, RodReel = nil, nil, nil
pcall(function()
    if RodShakeAnimModule then RodShake = animator:LoadAnimation(RodShakeAnimModule) end
    if RodIdleAnimModule then RodIdle = animator:LoadAnimation(RodIdleAnimModule) end
    if RodReelAnimModule then RodReel = animator:LoadAnimation(RodReelAnimModule) end
end)

-- Net remotes used
local okNet, remoteIndex = pcall(function() return ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_net@0.2.0"):WaitForChild("net") end)
local rodRemote, miniGameRemote, finishRemote, REEquipItem, RFSellItem = nil, nil, nil, nil, nil
if okNet and remoteIndex then
    pcall(function()
        rodRemote = remoteIndex:WaitForChild("RF/ChargeFishingRod")
        miniGameRemote = remoteIndex:WaitForChild("RF/RequestFishingMinigameStarted")
        finishRemote = remoteIndex:WaitForChild("RE/FishingCompleted")
        REEquipItem = remoteIndex:FindFirstChild("RE/EquipItem")
        RFSellItem = remoteIndex:FindFirstChild("RF/SellItem")
    end)
end

-- Notification wrappers (Rayfield)
local function NotifySuccess(title, message, duration)
    Rayfield:Notify({Title = title or "Success", Content = message or "", Duration = duration or 4})
end
local function NotifyError(title, message, duration)
    Rayfield:Notify({Title = title or "Error", Content = message or "", Duration = duration or 4})
end
local function NotifyInfo(title, message, duration)
    Rayfield:Notify({Title = title or "Info", Content = message or "", Duration = duration or 4})
end
local function NotifyWarning(title, message, duration)
    Rayfield:Notify({Title = title or "Warning", Content = message or "", Duration = duration or 4})
end

-- ======= RAYFIELD WINDOW SETUP (no config saving) =======
local Window = Rayfield:CreateWindow({
    Title = "e-Fishery",
    LoadingTitle = "e-Fishery",
    LoadingSubtitle = "by Zee",
    KeySystem = false,
})

-- create tabs + sections (same tab structure requested)
local HOME = Window:CreateTab("Developer Info")
local ALL = Window:CreateTab("All Menu Here")
local AutoFishTab = ALL:CreateSection("Auto Fish")
local AutoFavTab = ALL:CreateSection("Auto Favorite")
local AutoFarmTab = ALL:CreateSection("Auto Farm")
local TradeTab = ALL:CreateSection("Trade")
local PlayerTab = ALL:CreateSection("Player")
local UtilsTab = ALL:CreateSection("Utility")
local FishNotifTab = ALL:CreateSection("Fish Notification")
local SettingsTab = ALL:CreateSection("Settings")

-- Confirmation small UI to replace previous popup (keeps behavior parity)
local confirmed = false
HOME:AddLabel("Please click 'Next' below to continue (important notice).")
HOME:AddButton({
    Name = "Next",
    Callback = function()
        confirmed = true
        NotifySuccess("Confirmed", "Thanks for confirming. All features loaded.", 4)
    end
})
repeat task.wait() until confirmed

-- ======= AUTO FISH V1 =======
local FuncAutoFish = {
    REReplicateTextEffect = (okNet and remoteIndex and remoteIndex:FindFirstChild("RE/ReplicateTextEffect")) or nil,
    autofish = false,
    perfectCast = true,
    customDelay = 1,
    fishingActive = false,
    delayInitialized = false,
}
local fastRods = { ["Ares Rod"]=true, ["Angler Rod"]=true, ["Ghostfinn Rod"]=true }
local mediumRods = { ["Astral Rod"]=true, ["Chrome Rod"]=true, ["Steampunk Rod"]=true }
local veryLowRods = { ["Lucky Rod"]=true, ["Midnight Rod"]=true, ["Demascus Rod"]=true, ["Grass Rod"]=true, ["Luck Rod"]=true, ["Carbon Rod"]=true, ["Lava Rod"]=true, ["Starter Rod"]=true }

local function getValidRodName()
    local player = Players.LocalPlayer
    local display = player.PlayerGui and player.PlayerGui:FindFirstChild("Backpack") and player.PlayerGui.Backpack:FindFirstChild("Display")
    if not display then return nil end
    for _, tile in ipairs(display:GetChildren()) do
        local ok, itemNamePath = pcall(function() return tile.Inner.Tags.ItemName end)
        if ok and itemNamePath and itemNamePath:IsA("TextLabel") then
            local name = itemNamePath.Text
            if veryLowRods[name] or fastRods[name] or mediumRods[name] then return name end
        end
    end
    return nil
end

local function updateDelayBasedOnRod(showNotify)
    if FuncAutoFish.delayInitialized then return end
    local rodName = getValidRodName()
    if rodName then
        if fastRods[rodName] then FuncAutoFish.customDelay = math.random(100,120)/100
        elseif mediumRods[rodName] then FuncAutoFish.customDelay = math.random(140,200)/100
        elseif veryLowRods[rodName] then FuncAutoFish.customDelay = math.random(300,500)/100
        else FuncAutoFish.customDelay = 10 end
        FuncAutoFish.delayInitialized = true
        if showNotify and FuncAutoFish.autofish then NotifySuccess("Rod Detected", string.format("Detected Rod: %s | Delay: %.2fs", rodName, FuncAutoFish.customDelay)) end
    else
        FuncAutoFish.customDelay = 10
        FuncAutoFish.delayInitialized = true
        if showNotify and FuncAutoFish.autofish then NotifyWarning("Rod Detection Failed", "No valid rod found in list. Default delay 10s applied.") end
    end
end

local function setupRodWatcher()
    local player = Players.LocalPlayer
    local display = player.PlayerGui and player.PlayerGui:FindFirstChild("Backpack") and player.PlayerGui.Backpack:FindFirstChild("Display")
    if not display then return end
    display.ChildAdded:Connect(function() task.wait(0.05) if not FuncAutoFish.delayInitialized then updateDelayBasedOnRod(true) end end)
end
setupRodWatcher()

-- Fish threshold detection (v1)
local obtainedFishUUIDs = {}
local obtainedLimit = 30
local RemoteV2 = (okNet and remoteIndex and remoteIndex:FindFirstChild("RE/ObtainedNewFishNotification")) or nil
if RemoteV2 then
    RemoteV2.OnClientEvent:Connect(function(_, _, data)
        if data and data.InventoryItem and data.InventoryItem.UUID then
            table.insert(obtainedFishUUIDs, data.InventoryItem.UUID)
        end
    end)
end
local function sellItems()
    if #obtainedFishUUIDs > 0 and okNet and remoteIndex and remoteIndex:FindFirstChild("RF/SellAllItems") then
        local sellRemote = remoteIndex:FindFirstChild("RF/SellAllItems")
        pcall(function() sellRemote:InvokeServer() end)
    end
    obtainedFishUUIDs = {}
end
local function monitorFishThreshold()
    task.spawn(function()
        while FuncAutoFish.autofish do
            if #obtainedFishUUIDs >= obtainedLimit then
                NotifyInfo("Fish Threshold Reached", "Selling all fishes...")
                sellItems()
                obtainedFishUUIDs = {}
                task.wait(0.5)
            end
            task.wait(0.3)
        end
    end)
end

-- Hook for text effect to auto finish minigame (original logic)
if FuncAutoFish.REReplicateTextEffect then
    FuncAutoFish.REReplicateTextEffect.OnClientEvent:Connect(function(data)
        if FuncAutoFish.autofish and FuncAutoFish.fishingActive and data and data.TextData and data.TextData.EffectType == "Exclaim" then
            local myHead = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("Head")
            if myHead and data.Container == myHead then
                task.spawn(function()
                    for i = 1,3 do
                        task.wait(0.1)
                        pcall(function() if finishRemote then finishRemote:FireServer() end end)
                    end
                end)
            end
        end
    end)
end

-- Start/Stop auto fish v1
function StartAutoFish()
    FuncAutoFish.autofish = true
    updateDelayBasedOnRod(true)
    monitorFishThreshold()
    task.spawn(function()
        while FuncAutoFish.autofish do
            pcall(function()
                FuncAutoFish.fishingActive = true
                local equipRemote = (okNet and remoteIndex and remoteIndex:FindFirstChild("RE/EquipToolFromHotbar")) or nil
                if equipRemote then equipRemote:FireServer(1) end
                task.wait(0.1)
                local chargeRemote = (okNet and remoteIndex and remoteIndex:FindFirstChild("RF/ChargeFishingRod")) or nil
                if chargeRemote then pcall(function() chargeRemote:InvokeServer(workspace:GetServerTimeNow()) end) end
                task.wait(0.5)
                local timestamp = workspace:GetServerTimeNow()
                if RodShake and type(RodShake.Play) == "function" then pcall(function() RodShake:Play() end) end
                if rodRemote then pcall(function() rodRemote:InvokeServer(timestamp) end) end
                local baseX, baseY = -0.7499996423721313, 0.991067629351885
                local x,y
                if FuncAutoFish.perfectCast then
                    x = baseX + (math.random(-500,500) / 10000000)
                    y = baseY + (math.random(-500,500) / 10000000)
                else
                    x = math.random(-1000,1000)/1000
                    y = math.random(0,1000)/1000
                end
                if RodIdle and type(RodIdle.Play) == "function" then pcall(function() RodIdle:Play() end) end
                if miniGameRemote then pcall(function() miniGameRemote:InvokeServer(x,y) end) end
                task.wait(FuncAutoFish.customDelay)
                FuncAutoFish.fishingActive = false
            end)
            task.wait(0.1)
        end
    end)
end
function StopAutoFish()
    FuncAutoFish.autofish = false
    FuncAutoFish.fishingActive = false
    FuncAutoFish.delayInitialized = false
end

-- ======= AUTO FISH V2 =======
local FuncAutoFishV2 = {
    REReplicateTextEffectV2 = (okNet and remoteIndex and remoteIndex:FindFirstChild("RE/ReplicateTextEffect")) or nil,
    autofishV2 = false,
    perfectCastV2 = true,
    fishingActiveV2 = false,
    delayInitializedV2 = false
}
local RodDelaysV2 = {
    ["Ares Rod"] = {custom = 1.12, bypass = 1.45},
    ["Angler Rod"] = {custom = 1.12, bypass = 1.45},
    ["Ghostfinn Rod"] = {custom = 1.12, bypass = 1.45},
    ["Astral Rod"] = {custom = 1.9, bypass = 1.45},
    ["Chrome Rod"] = {custom = 2.3, bypass = 2},
    ["Steampunk Rod"] = {custom = 2.5, bypass = 2.3},
    ["Lucky Rod"] = {custom = 3.5, bypass = 3.6},
    ["Midnight Rod"] = {custom = 3.3, bypass = 3.4},
    ["Demascus Rod"] = {custom = 3.9, bypass = 3.8},
    ["Grass Rod"] = {custom = 3.8, bypass = 3.9},
    ["Luck Rod"] = {custom = 4.2, bypass = 4.1},
    ["Carbon Rod"] = {custom = 4, bypass = 3.8},
    ["Lava Rod"] = {custom = 4.2, bypass = 4.1},
    ["Starter Rod"] = {custom = 4.3, bypass = 4.2},
}
local customDelayV2 = 1
local BypassDelayV2 = 0.5

local function getValidRodNameV2()
    local player = Players.LocalPlayer
    local display = player.PlayerGui and player.PlayerGui:FindFirstChild("Backpack") and player.PlayerGui.Backpack:FindFirstChild("Display")
    if not display then return nil end
    for _, tile in ipairs(display:GetChildren()) do
        local ok, itemNamePath = pcall(function() return tile.Inner.Tags.ItemName end)
        if ok and itemNamePath and itemNamePath:IsA("TextLabel") then
            local name = itemNamePath.Text
            if RodDelaysV2[name] then return name end
        end
    end
    return nil
end
local function updateDelayBasedOnRodV2(showNotify)
    if FuncAutoFishV2.delayInitializedV2 then return end
    local rodName = getValidRodNameV2()
    if rodName and RodDelaysV2[rodName] then
        customDelayV2 = RodDelaysV2[rodName].custom
        BypassDelayV2 = RodDelaysV2[rodName].bypass
        FuncAutoFishV2.delayInitializedV2 = true
        if showNotify and FuncAutoFishV2.autofishV2 then
            NotifySuccess("Rod Detected (V2)", string.format("Detected Rod: %s | Delay: %.2fs | Bypass: %.2fs", rodName, customDelayV2, BypassDelayV2))
        end
    else
        customDelayV2 = 10
        BypassDelayV2 = 1
        FuncAutoFishV2.delayInitializedV2 = true
        if showNotify and FuncAutoFishV2.autofishV2 then NotifyWarning("Rod Detection Failed (V2)", "No valid rod found. Default delay applied.") end
    end
end

-- FISH THRESHOLD V2
local obtainedFishUUIDsV2 = {}
local obtainedLimitV2 = 30
if RemoteV2 then
    RemoteV2.OnClientEvent:Connect(function(_, _, data)
        if data and data.InventoryItem and data.InventoryItem.UUID then table.insert(obtainedFishUUIDsV2, data.InventoryItem.UUID) end
    end)
end
local function sellItemsV2()
    if #obtainedFishUUIDsV2 > 0 and okNet and remoteIndex and remoteIndex:FindFirstChild("RF/SellAllItems") then
        local sellRemote = remoteIndex:FindFirstChild("RF/SellAllItems")
        pcall(function() sellRemote:InvokeServer() end)
    end
    obtainedFishUUIDsV2 = {}
end
local function monitorFishThresholdV2()
    task.spawn(function()
        while FuncAutoFishV2.autofishV2 do
            if #obtainedFishUUIDsV2 >= obtainedLimitV2 then
                NotifyInfo("Fish Threshold Reached (V2)", "Selling all fishes...")
                sellItemsV2()
                obtainedFishUUIDsV2 = {}
                task.wait(0.5)
            end
            task.wait(0.3)
        end
    end)
end

if FuncAutoFishV2.REReplicateTextEffectV2 then
    FuncAutoFishV2.REReplicateTextEffectV2.OnClientEvent:Connect(function(data)
        if FuncAutoFishV2.autofishV2 and FuncAutoFishV2.fishingActiveV2 and data and data.TextData and data.TextData.EffectType == "Exclaim" then
            local myHead = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("Head")
            if myHead and data.Container == myHead then
                task.spawn(function()
                    for i = 1, 3 do
                        task.wait(BypassDelayV2)
                        pcall(function() if finishRemote then finishRemote:FireServer() end end)
                    end
                end)
            end
        end
    end)
end

function StartAutoFishV2()
    FuncAutoFishV2.autofishV2 = true
    updateDelayBasedOnRodV2(true)
    monitorFishThresholdV2()
    task.spawn(function()
        while FuncAutoFishV2.autofishV2 do
            pcall(function()
                FuncAutoFishV2.fishingActiveV2 = true
                local equipRemote = (okNet and remoteIndex and remoteIndex:FindFirstChild("RE/EquipToolFromHotbar")) or nil
                if equipRemote then equipRemote:FireServer(1) end
                task.wait(0.1)
                local chargeRemote = (okNet and remoteIndex and remoteIndex:FindFirstChild("RF/ChargeFishingRod")) or nil
                if chargeRemote then pcall(function() chargeRemote:InvokeServer(workspace:GetServerTimeNow()) end) end
                task.wait(0.5)
                local timestamp = workspace:GetServerTimeNow()
                if RodShake and type(RodShake.Play) == "function" then pcall(function() RodShake:Play() end) end
                if rodRemote then pcall(function() rodRemote:InvokeServer(timestamp) end) end
                local baseX, baseY = -0.7499996423721313, 1
                local x,y
                if FuncAutoFishV2.perfectCastV2 then
                    x = baseX + (math.random(-500,500) / 10000000)
                    y = baseY + (math.random(-500,500) / 10000000)
                else
                    x = math.random(-1000,1000)/1000
                    y = math.random(0,1000)/1000
                end
                if RodIdle and type(RodIdle.Play) == "function" then pcall(function() RodIdle:Play() end) end
                if miniGameRemote then pcall(function() miniGameRemote:InvokeServer(x,y) end) end
                task.wait(customDelayV2)
                FuncAutoFishV2.fishingActiveV2 = false
            end)
            task.wait(0.1)
        end
    end)
end
function StopAutoFishV2()
    FuncAutoFishV2.autofishV2 = false
    FuncAutoFishV2.fishingActiveV2 = false
    FuncAutoFishV2.delayInitializedV2 = false
    pcall(function() if RodIdle then RodIdle:Stop() end; if RodShake then RodShake:Stop() end; if RodReel then RodReel:Stop() end end)
end

-- ======= Auto Sell Mythic (hook) =======
local autoSellMythic = false
local oldFireServer = nil
if hookmetamethod then
    oldFireServer = hookmetamethod(game, "__namecall", function(self, ...)
        local args = {...}
        local method = getnamecallmethod()
        if autoSellMythic and method == "FireServer" and self == REEquipItem and typeof(args[1]) == "string" and args[2] == "Fishes" then
            local uuid = args[1]
            task.delay(1, function()
                pcall(function()
                    if RFSellItem then
                        local res = RFSellItem:InvokeServer(uuid)
                        if res then NotifySuccess("AutoSellMythic", "Items Sold!!") else NotifyError("AutoSellMythic", "Failed to sell item!!") end
                    end
                end)
            end)
        end
        return oldFireServer(self, ...)
    end)
end

-- ======= Sell / Enchant / Utility functions =======
local function sellAllFishes()
    local charFolder = workspace:FindFirstChild("Characters")
    local char = charFolder and charFolder:FindFirstChild(LocalPlayer.Name)
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then NotifyError("Character Not Found", "HRP not found."); return end
    local sellRemote = (okNet and remoteIndex and remoteIndex:FindFirstChild("RF/SellAllItems")) or nil
    task.spawn(function()
        NotifyInfo("Selling...", "I'm going to sell all the fish, please wait...", 3)
        task.wait(1)
        local success, err = pcall(function() if sellRemote then sellRemote:InvokeServer() end end)
        if success then NotifySuccess("Sold!", "All the fish were sold successfully.", 3)
        else NotifyError("Sell Failed", tostring(err)) end
    end)
end

local function autoEnchantRod()
    local ENCHANT_POSITION = Vector3.new(3231, -1303, 1402)
    local char = workspace:WaitForChild("Characters",5):FindFirstChild(LocalPlayer.Name)
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then NotifyError("Auto Enchant Rod", "Failed to get character HRP."); return end
    NotifyInfo("Preparing Enchant...", "Please manually place Enchant Stone into slot 5 before we begin...", 5)
    task.wait(3)
    local PlayerGui = Players.LocalPlayer.PlayerGui
    local slot5 = PlayerGui and PlayerGui.Backpack and PlayerGui.Backpack.Display and PlayerGui.Backpack.Display:GetChildren()[10]
    local itemName = slot5 and slot5:FindFirstChild("Inner") and slot5.Inner:FindFirstChild("Tags") and slot5.Inner.Tags:FindFirstChild("ItemName")
    if not itemName or not itemName.Text:lower():find("enchant") then NotifyError("Auto Enchant Rod", "Slot 5 does not contain an Enchant Stone."); return end
    NotifyInfo("Enchanting...", "Enchant process started. Wait until the enchantment is complete", 7)
    local originalPosition = hrp.Position
    task.wait(1)
    hrp.CFrame = CFrame.new(ENCHANT_POSITION + Vector3.new(0,5,0))
    task.wait(1.2)
    local equipRod = (okNet and remoteIndex and remoteIndex:FindFirstChild("RE/EquipToolFromHotbar")) or nil
    local activateEnchant = (okNet and remoteIndex and remoteIndex:FindFirstChild("RE/ActivateEnchantingAltar")) or nil
    pcall(function()
        if equipRod then equipRod:FireServer(5) end
        task.wait(0.5)
        if activateEnchant then activateEnchant:FireServer() end
        task.wait(7)
        NotifySuccess("Enchant", "Successfully Enchanted!", 3)
    end)
    task.wait(0.9)
    hrp.CFrame = CFrame.new(originalPosition + Vector3.new(0,3,0))
end

-- ======= AUTO FAVORITE =======
local GlobalFav = {
    REObtainedNewFishNotification = (okNet and remoteIndex and remoteIndex:FindFirstChild("RE/ObtainedNewFishNotification")) or nil,
    REFavoriteItem = (okNet and remoteIndex and remoteIndex:FindFirstChild("RE/FavoriteItem")) or nil,
    FishIdToName = {},
    FishNameToId = {},
    FishNames = {},
    Variants = {},
    SelectedFishIds = {},
    SelectedVariants = {},
    AutoFavoriteEnabled = false
}
-- Load fish names
if ReplicatedStorage:FindFirstChild("Items") then
    for _, item in pairs(ReplicatedStorage.Items:GetChildren()) do
        local ok, data = pcall(function() return require(item) end)
        if ok and data and data.Data and data.Data.Type == "Fishes" then
            local id = data.Data.Id
            local name = data.Data.Name
            GlobalFav.FishIdToName[id] = name
            GlobalFav.FishNameToId[name] = id
            table.insert(GlobalFav.FishNames, name)
        end
    end
end
-- Load variants
if ReplicatedStorage:FindFirstChild("Variants") then
    for _, variantModule in pairs(ReplicatedStorage.Variants:GetChildren()) do
        local ok, variantData = pcall(function() return require(variantModule) end)
        if ok and variantData and variantData.Data and variantData.Data.Name then
            local name = variantData.Data.Name
            GlobalFav.Variants[name] = name
        end
    end
end

if GlobalFav.REObtainedNewFishNotification then
    GlobalFav.REObtainedNewFishNotification.OnClientEvent:Connect(function(itemId, _, data)
        if not GlobalFav.AutoFavoriteEnabled then return end
        local uuid = data.InventoryItem and data.InventoryItem.UUID
        local fishName = GlobalFav.FishIdToName[itemId] or "Unknown"
        local variantId = data.InventoryItem.Metadata and data.InventoryItem.Metadata.VariantId
        if not uuid then return end
        local matchByName = GlobalFav.SelectedFishIds[itemId]
        local matchByVariant = variantId and GlobalFav.SelectedVariants[variantId]
        local shouldFavorite = false
        if matchByName and matchByVariant then shouldFavorite = true
        elseif matchByName and not next(GlobalFav.SelectedVariants) then shouldFavorite = true
        elseif matchByVariant and not matchByName then shouldFavorite = true end
        if shouldFavorite then
            pcall(function() if GlobalFav.REFavoriteItem then GlobalFav.REFavoriteItem:FireServer(uuid) end end)
            local msg = "Favorited " .. fishName
            if matchByVariant then msg = msg .. " (" .. (GlobalFav.Variants[variantId] or variantId) .. " Variant)" end
            NotifySuccess("Auto Favorite", msg .. "!")
        end
    end)
end

-- ======= AUTO FARM (Float platform, event TP) =======
local floatPlatform = nil
local function floatingPlat(enabled)
    if enabled then
        local charFolder = workspace:FindFirstChild("Characters")
        local char = charFolder and charFolder:FindFirstChild(LocalPlayer.Name)
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        floatPlatform = Instance.new("Part")
        floatPlatform.Anchored = true
        floatPlatform.Size = Vector3.new(10,1,10)
        floatPlatform.Transparency = 1
        floatPlatform.CanCollide = true
        floatPlatform.Name = "FloatPlatform"
        floatPlatform.Parent = workspace
        task.spawn(function()
            while floatPlatform and floatPlatform.Parent do
                pcall(function() floatPlatform.Position = hrp.Position - Vector3.new(0,3.5,0) end)
                task.wait(0.1)
            end
        end)
        NotifySuccess("Float Enabled", "This feature has been successfully activated!")
    else
        if floatPlatform then floatPlatform:Destroy(); floatPlatform = nil end
        NotifyWarning("Float Disabled", "Feature disabled")
    end
end

local knownEvents = {}
local function updateKnownEvents()
    knownEvents = {}
    local props = workspace:FindFirstChild("Props")
    if props then
        for _, child in ipairs(props:GetChildren()) do
            if child:IsA("Model") and child.PrimaryPart then
                knownEvents[child.Name:lower()] = child
            end
        end
    end
end
local function monitorEvents()
    local props = workspace:FindFirstChild("Props")
    if not props then
        workspace.ChildAdded:Connect(function(child)
            if child.Name == "Props" then task.wait(0.3); monitorEvents() end
        end)
        return
    end
    props.ChildAdded:Connect(function() task.wait(0.3); updateKnownEvents() end)
    props.ChildRemoved:Connect(function() task.wait(0.3); updateKnownEvents() end)
    updateKnownEvents()
end
monitorEvents()

local autoTPEvent = false
local savedCFrame = nil
local monitoringTP = false
local alreadyTeleported = false
local teleportTime = nil
local eventTarget = nil

local function saveOriginalPosition()
    local char = workspace:FindFirstChild("Characters"):FindFirstChild(LocalPlayer.Name)
    if char and char:FindFirstChild("HumanoidRootPart") then savedCFrame = char.HumanoidRootPart.CFrame end
end
local function returnToOriginalPosition()
    if savedCFrame then
        local char = workspace:FindFirstChild("Characters"):FindFirstChild(LocalPlayer.Name)
        if char and char:FindFirstChild("HumanoidRootPart") then char.HumanoidRootPart.CFrame = savedCFrame end
    end
end
local function teleportTo(position)
    local char = workspace:FindFirstChild("Characters"):FindFirstChild(LocalPlayer.Name)
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CFrame = CFrame.new(position + Vector3.new(0,20,0)) end
    end
end

local function monitorAutoTP()
    if monitoringTP then return end
    monitoringTP = true
    task.spawn(function()
        while true do
            if autoTPEvent then
                if not alreadyTeleported then
                    updateKnownEvents()
                    for _, eventModel in pairs(knownEvents) do
                        saveOriginalPosition()
                        teleportTo(eventModel:GetPivot().Position)
                        if floatPlatform then floatingPlat(true) end
                        alreadyTeleported = true
                        teleportTime = tick()
                        eventTarget = eventModel.Name
                        NotifyInfo("Event Farm", "Teleported to: " .. tostring(eventModel.Name))
                        break
                    end
                else
                    if eventTarget and (not workspace:FindFirstChild("Props") or not workspace.Props:FindFirstChild(eventTarget)) then
                        -- event ended
                        returnToOriginalPosition()
                        alreadyTeleported = false
                        eventTarget = nil
                        NotifySuccess("Event Farm", "Returned to original position.")
                    end
                end
            end
            task.wait(1)
        end
    end)
end
monitorAutoTP()

-- ======= UI ELEMENTS: AutoFish tab =======
AutoFishTab:AddInput({
    Name = "Bypass Delay",
    PlaceholderText = "Example: 1",
    RemoveTextAfterFocusLost = false,
    Callback = function(value)
        local number = tonumber(value)
        if number then
            BypassDelayV2 = number
            NotifySuccess("Bypass Delay", "Bypass Delay set to " .. tostring(number))
        else NotifyError("Invalid Input", "Failed to convert input to number.") end
    end
})

AutoFishTab:AddInput({
    Name = "Fish Threshold",
    PlaceholderText = "Example: 1500",
    Callback = function(value)
        local number = tonumber(value)
        if number then
            obtainedLimit = number
            obtainedLimitV2 = number
            NotifySuccess("Threshold Set", "Fish threshold set to " .. tostring(number))
        else NotifyError("Invalid Input", "Failed to convert input to number.") end
    end
})

AutoFishTab:AddToggle({
    Name = "Auto Fish V2",
    CurrentValue = false,
    Flag = "AutoFishV2Flag",
    Callback = function(val)
        if val then StartAutoFishV2() else StopAutoFishV2() end
    end
})

AutoFishTab:AddToggle({
    Name = "Auto Fish (Custom Delay)",
    CurrentValue = false,
    Flag = "AutoFishCustomFlag",
    Callback = function(val)
        if val then StartAutoFish() else StopAutoFish() end
    end
})

AutoFishTab:AddToggle({
    Name = "Auto Perfect Cast",
    CurrentValue = true,
    Callback = function(val) FuncAutoFish.perfectCast = val; FuncAutoFishV2.perfectCastV2 = val end
})

AutoFishTab:AddToggle({
    Name = "Auto Sell Mythic",
    CurrentValue = false,
    Callback = function(state)
        autoSellMythic = state
        if state then NotifySuccess("AutoSellMythic", "Status: ON") else NotifyWarning("AutoSellMythic", "Status: OFF") end
    end
})

AutoFishTab:AddButton({
    Name = "Sell All Fishes",
    Callback = function() sellAllFishes() end
})

AutoFishTab:AddButton({
    Name = "Auto Enchant Rod",
    Callback = function() autoEnchantRod() end
})

-- ======= UI ELEMENTS: AutoFavorite tab =======
AutoFavTab:AddToggle({
    Name = "Enable Auto Favorite",
    CurrentValue = false,
    Callback = function(state)
        GlobalFav.AutoFavoriteEnabled = state
        if state then NotifySuccess("Auto Favorite", "Auto Favorite feature enabled") else NotifyWarning("Auto Favorite", "Auto Favorite feature disabled") end
    end
})

AutoFavTab:AddLabel("Auto Favorite Fishes (multi-select below)")
AutoFavTab:AddDropdown({
    Name = "Auto Favorite Fishes",
    Options = GlobalFav.FishNames,
    MultiSelect = true,
    Callback = function(selectedNames)
        GlobalFav.SelectedFishIds = {}
        for _, name in ipairs(selectedNames) do
            local id = GlobalFav.FishNameToId[name]
            if id then GlobalFav.SelectedFishIds[id] = true end
        end
        NotifyInfo("Auto Favorite", "Favoriting active for fish: " .. tostring(HttpService:JSONEncode(selectedNames)))
    end
})
AutoFavTab:AddDropdown({
    Name = "Auto Favorite Variants",
    Options = (function() local arr = {} for k,_ in pairs(GlobalFav.Variants) do table.insert(arr, k) end return arr end)(),
    MultiSelect = true,
    Callback = function(selectedVariants)
        GlobalFav.SelectedVariants = {}
        for _, vName in ipairs(selectedVariants) do
            for vId, name in pairs(GlobalFav.Variants) do
                if name == vName then GlobalFav.SelectedVariants[vId] = true end
            end
        end
        NotifyInfo("Auto Favorite", "Favoriting active for variants: " .. tostring(HttpService:JSONEncode(selectedVariants)))
    end
})

-- ======= UI Elements: AutoFarm / Utilities =======
AutoFarmTab:AddToggle({
    Name = "Floating Platform",
    CurrentValue = false,
    Callback = function(state) floatingPlat(state) end
})

AutoFarmTab:AddToggle({
    Name = "Auto TP to Events",
    CurrentValue = false,
    Callback = function(state) autoTPEvent = state if state then monitorAutoTP() end end
})

AutoFarmTab:AddButton({
    Name = "Return To Saved Position",
    Callback = function() returnToOriginalPosition() end
})

-- ======= Settings Tab (misc) =======
SettingsTab:AddButton({
    Name = "Sell All Fishes (manual)",
    Callback = function() sellAllFishes() end
})
SettingsTab:AddButton({
    Name = "Enable/Disable Float Platform (toggle)",
    Callback = function()
        if floatPlatform then floatingPlat(false) else floatingPlat(true) end
    end
})
SettingsTab:AddButton({
    Name = "Re-Run Rod Detection Now",
    Callback = function()
        FuncAutoFish.delayInitialized = false
        FuncAutoFishV2.delayInitializedV2 = false
        updateDelayBasedOnRod(true)
        updateDelayBasedOnRodV2(true)
    end
})

-- Small developer info on HOME tab
HOME:AddLabel("Developer Info")
HOME:AddParagraph("Discord: Join the community for updates and support.")

-- Final loaded notify
NotifySuccess("e-Fishery", "All Features Loaded!", 4)

-- End of script
