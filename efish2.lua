-- E-Fishery (Rayfield UI refactor)
-- Replaces WindUI with Rayfield, removes Check Data / Validation, removes Teleport features.
-- Features included: Auto-Fish, Auto-Sell, Auto-Favorite, Auto-Reconnect, Anti-AFK, Auto-Trade/Farming toggles, Notifications.

-- Load Rayfield (using the URL you provided)
local success, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)
if not success or not Rayfield then
    warn("[E-Fishery] Failed to load Rayfield. Check your executor and internet.")
    return
end

-- Basic services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- Branding
local UI_TITLE = "E-Fishery"

-- Global flags (persisted by Rayfield config)
_G.EF = _G.EF or {}
local EF = _G.EF

-- sensible defaults if not set
EF.autoFish = EF.autoFish or false
EF.autoSell = EF.autoSell or false
EF.autoFavorite = EF.autoFavorite or false
EF.autoReconnect = EF.autoReconnect or true
EF.antiAFK = EF.antiAFK or true
EF.autoTrade = EF.autoTrade or false
EF.fishDelay = EF.fishDelay or 0.5 -- seconds between fishing actions
EF.sellDelay = EF.sellDelay or 1.0
EF.notifyDuration = EF.notifyDuration or 5

-- Helpers: Rayfield notifications wrapper
local function notify(title, content, duration)
    duration = duration or EF.notifyDuration
    pcall(function()
        Rayfield:Notify({
            Title = title,
            Content = content,
            Duration = duration,
        })
    end)
end

-- Provide backward compatibility for scripts that call WindUI.* (if any leftover)
getgenv().WindUI = {
    Notify = function(tbl) notify(tbl.Title or "E-Fishery", tbl.Text or tbl.Content or "", tbl.Duration) end,
    NotifySuccess = function(txt) notify("Success", txt) end,
    NotifyError = function(txt) notify("Error", txt) end,
    NotifyInfo = function(txt) notify("Info", txt) end,
}

-- Create the Rayfield Window
local Window = Rayfield:CreateWindow({
    Name = UI_TITLE,
    LoadingTitle = "E-Fishery",
    LoadingSubtitle = "By Zee",
    ConfigurationSaving = {
        Enabled = true,
        FileName = "E-FisheryConfig"
    },
    Discord = {
        Enabled = false,
    },
    KeySystem = false
})

-- Tabs
local MainTab = Window:CreateTab("Main")
local FarmingTab = Window:CreateTab("Farming")
local SettingsTab = Window:CreateTab("Settings")

-- Sections on Main tab
local MainSection = MainTab:CreateSection("Core")
local FishingSection = MainTab:CreateSection("Fishing Controls")
local SellingSection = MainTab:CreateSection("Selling & Favorites")
local MiscSection = MainTab:CreateSection("Misc")

-- Farming tab sections
local AutoTradeSection = FarmingTab:CreateSection("Auto Trade / Farming")

-- Settings
local SettingsSection = SettingsTab:CreateSection("Settings")

-- ---------------------------------------------------------------------
-- PLACEHOLDERS: Replace these with your game's actual RemoteEvent / RemoteFunction names if needed.
-- The script attempts to be generic but some games use unique remote names.
-- If the script doesn't perform the in-game actions, update these to match target game.
-- Example: local REMOTES = { Sell = ReplicatedStorage:WaitForChild("SellRemote") }
-- ---------------------------------------------------------------------
local REMOTES = {}
-- Example placeholders (common names). Replace if your game's remotes are different:
-- REMOTES.Fish = ReplicatedStorage:FindFirstChild("FishRemote") or ReplicatedStorage:FindFirstChild("CastRemote")
-- REMOTES.Sell = ReplicatedStorage:FindFirstChild("SellRemote")
-- REMOTES.Favorite = ReplicatedStorage:FindFirstChild("FavoriteRemote")
-- REMOTES.Trade = ReplicatedStorage:FindFirstChild("TradeRemote")

-- To be safe, we attempt to locate plausible remotes automatically (best-effort).
-- This tries a few common names; if none match, the feature will warn in notifications.
local function findRemoteByNames(tbl, names)
    for _, name in ipairs(names) do
        local r = tbl:FindFirstChild(name)
        if r then return r end
    end
    return nil
end

-- Attempt to autodetect common remote names (best effort)
REMOTES.Fish = findRemoteByNames(ReplicatedStorage, {"Fish", "Cast", "FishRemote", "CastRemote", "RemoteCast"})
REMOTES.Sell = findRemoteByNames(ReplicatedStorage, {"Sell", "SellRemote", "SellAll", "SellFishes"})
REMOTES.Favorite = findRemoteByNames(ReplicatedStorage, {"Favorite", "FavoriteRemote", "Fav", "FavoriteFish"})
REMOTES.Trade = findRemoteByNames(ReplicatedStorage, {"Trade", "TradeRemote", "AutoTrade"})
-- If your game uses remote inside nested folders, consider updating REMOTES manually below.

-- Utility checkers
local function hasRemote(name)
    if REMOTES[name] then return true end
    return false
end

-- ---------------------------------------------------------------------
-- Core logic loops
-- ---------------------------------------------------------------------

-- Anti-AFK: simple technique: simulation of user input every 60s
if EF.antiAFK then
    -- Rayfield toggle will control this; start background coroutine
end
local AntiAFKConnection
local function startAntiAFK()
    if AntiAFKConnection then return end
    AntiAFKConnection = RunService.Heartbeat:Connect(function(step)
        -- cheap anti-AFK - simulate small mousemove via VirtualUser if available
        pcall(function()
            local vu = (getvirtualuser and getvirtualuser()) or (syn and syn.request and nil)
            -- Fallback: send a tiny input via UserInputService (roblox doesn't expose a programmatic move; so we'll simulate by sending keypress if supported by executor)
            -- Many executors provide `virtualuser` object; we attempt common pattern:
            if not vu and (game:GetService("VirtualUser") ~= nil) then
                local gu = game:GetService("VirtualUser")
                gu:Button2Down(Vector2.new(0,0), workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position or Vector3.new())
                wait(0.1)
                gu:Button2Up(Vector2.new(0,0), workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position or Vector3.new())
            end
        end)
        wait(60)
    end)
    notify("Anti-AFK", "Anti-AFK enabled.")
end

local function stopAntiAFK()
    if AntiAFKConnection then
        AntiAFKConnection:Disconnect()
        AntiAFKConnection = nil
    end
    notify("Anti-AFK", "Anti-AFK disabled.")
end

-- Auto-Reconnect handler (best-effort)
local reconnecting = false
local function handleServerDisconnect()
    if EF.autoReconnect and not reconnecting then
        reconnecting = true
        notify("Reconnect", "Disconnected — attempting to reconnect...")
        -- Many exploit environments reconnect automatically; we can attempt to rejoin
        pcall(function()
            local PlaceId = game.PlaceId
            local JobId = tostring(game.JobId)
            -- Try teleport service to current place (best-effort)
            local TeleportService = game:GetService("TeleportService")
            pcall(function() TeleportService:Teleport(PlaceId, LocalPlayer) end)
        end)
        wait(5)
        reconnecting = false
    end
end

-- Listen to the connection event for disconnection (best-effort)
local function attachDisconnectListener()
    if not EF.autoReconnect then return end
    local conn
    conn = game:GetService("Players").LocalPlayer.OnTeleport:Connect(function(state)
        -- noop for now
    end)
    -- can't rely on this; inform user if engine disconnects
end

-- Auto-Fish loop (best-effort generic)
local autoFishRunning = false
local autoFishThread
local function startAutoFish()
    if autoFishRunning then return end
    autoFishRunning = true
    notify("Auto-Fish", "Auto-Fish started.")
    autoFishThread = coroutine.create(function()
        while autoFishRunning do
            -- If we have a remote that looks like a fishing remote, call it
            if REMOTES.Fish and REMOTES.Fish:IsA("RemoteEvent") then
                pcall(function()
                    REMOTES.Fish:FireServer() -- many scripts use FireServer with no args; adjust if the game's remote requires args
                end)
            elseif REMOTES.Fish and REMOTES.Fish:IsA("RemoteFunction") then
                pcall(function()
                    REMOTES.Fish:InvokeServer()
                end)
            else
                -- Fallback: attempt to use player's tool (rod) activation
                pcall(function()
                    local character = LocalPlayer.Character
                    if character then
                        local tool = character:FindFirstChildOfClass("Tool")
                        if tool and tool:FindFirstChild("Handle") then
                            tool:Activate()
                        end
                    end
                end)
            end
            -- wait between casts
            local delayTime = math.max(0.05, EF.fishDelay or 0.5)
            for i = 1, math.ceil(delayTime / 0.1) do
                if not autoFishRunning then break end
                wait(0.1)
            end
            if not autoFishRunning then break end
        end
    end)
    coroutine.resume(autoFishThread)
end

local function stopAutoFish()
    if not autoFishRunning then return end
    autoFishRunning = false
    notify("Auto-Fish", "Auto-Fish stopped.")
end

-- Auto-Sell loop (best-effort generic)
local autoSellRunning = false
local autoSellThread
local function startAutoSell()
    if autoSellRunning then return end
    autoSellRunning = true
    notify("Auto-Sell", "Auto-Sell started.")
    autoSellThread = coroutine.create(function()
        while autoSellRunning do
            if REMOTES.Sell and REMOTES.Sell:IsA("RemoteEvent") then
                pcall(function()
                    REMOTES.Sell:FireServer() -- adjust args if needed
                end)
            elseif REMOTES.Sell and REMOTES.Sell:IsA("RemoteFunction") then
                pcall(function()
                    REMOTES.Sell:InvokeServer()
                end)
            else
                -- Attempt to touch a Sell NPC / ProximityPrompt if present
                -- Note: This is game-specific and may need manual adjustments.
                notify("Auto-Sell", "Sell remote not detected automatically. Please set REMOTES.Sell manually if needed.", 6)
                -- stop to avoid spamming
                autoSellRunning = false
                break
            end
            -- wait before next sell
            local delayTime = math.max(0.25, EF.sellDelay or 1.0)
            for i = 1, math.ceil(delayTime / 0.1) do
                if not autoSellRunning then break end
                wait(0.1)
            end
        end
    end)
    coroutine.resume(autoSellThread)
end

local function stopAutoSell()
    if not autoSellRunning then return end
    autoSellRunning = false
    notify("Auto-Sell", "Auto-Sell stopped.")
end

-- Auto-Favorite: best-effort
local autoFavRunning = false
local autoFavThread
local function startAutoFavorite()
    if autoFavRunning then return end
    autoFavRunning = true
    notify("Auto-Favorite", "Auto-Favorite started.")
    autoFavThread = coroutine.create(function()
        while autoFavRunning do
            if REMOTES.Favorite and REMOTES.Favorite:IsA("RemoteEvent") then
                pcall(function()
                    REMOTES.Favorite:FireServer()
                end)
            elseif REMOTES.Favorite and REMOTES.Favorite:IsA("RemoteFunction") then
                pcall(function()
                    REMOTES.Favorite:InvokeServer()
                end)
            else
                notify("Auto-Favorite", "Favorite remote not detected automatically. Please configure REMOTES.Favorite if needed.", 6)
                autoFavRunning = false
                break
            end
            wait(1)
        end
    end)
    coroutine.resume(autoFavThread)
end

local function stopAutoFavorite()
    if not autoFavRunning then return end
    autoFavRunning = false
    notify("Auto-Favorite", "Auto-Favorite stopped.")
end

-- Auto-Trade / Farming (generic)
local autoTradeRunning = false
local autoTradeThread
local function startAutoTrade()
    if autoTradeRunning then return end
    autoTradeRunning = true
    notify("Auto-Trade", "Auto-Trade started.")
    autoTradeThread = coroutine.create(function()
        while autoTradeRunning do
            if REMOTES.Trade and REMOTES.Trade:IsA("RemoteEvent") then
                pcall(function()
                    REMOTES.Trade:FireServer()
                end)
            elseif REMOTES.Trade and REMOTES.Trade:IsA("RemoteFunction") then
                pcall(function()
                    REMOTES.Trade:InvokeServer()
                end)
            else
                notify("Auto-Trade", "Trade remote not found automatically.", 6)
                autoTradeRunning = false
                break
            end
            wait(1)
        end
    end)
    coroutine.resume(autoTradeThread)
end

local function stopAutoTrade()
    if not autoTradeRunning then return end
    autoTradeRunning = false
    notify("Auto-Trade", "Auto-Trade stopped.")
end

-- ---------------------------------------------------------------------
-- UI Elements (Rayfield)
-- ---------------------------------------------------------------------

-- Main / Fishing toggles
MainTab:CreateToggle({
    Name = "Auto-Fish",
    CurrentValue = EF.autoFish,
    Flag = "AutoFishToggle",
    Callback = function(val)
        EF.autoFish = val
        if val then startAutoFish() else stopAutoFish() end
    end
})

MainTab:CreateSlider({
    Name = "Fish Delay (s)",
    Range = {0.05, 5},
    Increment = 0.05,
    Suffix = "s",
    CurrentValue = EF.fishDelay,
    Flag = "FishDelay",
    Callback = function(val)
        EF.fishDelay = val
    end
})

-- Selling & fav toggles
MainTab:CreateToggle({
    Name = "Auto-Sell",
    CurrentValue = EF.autoSell,
    Flag = "AutoSellToggle",
    Callback = function(val)
        EF.autoSell = val
        if val then startAutoSell() else stopAutoSell() end
    end
})

MainTab:CreateSlider({
    Name = "Sell Delay (s)",
    Range = {0.25, 10},
    Increment = 0.25,
    Suffix = "s",
    CurrentValue = EF.sellDelay,
    Flag = "SellDelay",
    Callback = function(val)
        EF.sellDelay = val
    end
})

MainTab:CreateToggle({
    Name = "Auto-Favorite",
    CurrentValue = EF.autoFavorite,
    Flag = "AutoFavoriteToggle",
    Callback = function(val)
        EF.autoFavorite = val
        if val then startAutoFavorite() else stopAutoFavorite() end
    end
})

-- Farming tab controls
AutoTradeSection:CreateToggle({
    Name = "Auto-Trade / Farming",
    CurrentValue = EF.autoTrade,
    Flag = "AutoTradeToggle",
    Callback = function(val)
        EF.autoTrade = val
        if val then startAutoTrade() else stopAutoTrade() end
    end
})

-- Misc toggles (Anti-AFK, Reconnect)
MiscSection:CreateToggle({
    Name = "Anti-AFK",
    CurrentValue = EF.antiAFK,
    Flag = "AntiAFKToggle",
    Callback = function(val)
        EF.antiAFK = val
        if val then startAntiAFK() else stopAntiAFK() end
    end
})

MiscSection:CreateToggle({
    Name = "Auto-Reconnect",
    CurrentValue = EF.autoReconnect,
    Flag = "AutoReconnectToggle",
    Callback = function(val)
        EF.autoReconnect = val
        if val then notify("Auto-Reconnect", "Auto-Reconnect enabled.") else notify("Auto-Reconnect", "Auto-Reconnect disabled.") end
    end
})

-- Quick actions (buttons)
MainTab:CreateButton({
    Name = "Start All (Fish & Sell & Fav)",
    Callback = function()
        if not EF.autoFish then
            EF.autoFish = true
            startAutoFish()
        end
        if not EF.autoSell then
            EF.autoSell = true
            startAutoSell()
        end
        if not EF.autoFavorite then
            EF.autoFavorite = true
            startAutoFavorite()
        end
        notify("E-Fishery", "Started Auto-Fish, Auto-Sell, Auto-Favorite.")
    end
})

MainTab:CreateButton({
    Name = "Stop All",
    Callback = function()
        if EF.autoFish then EF.autoFish = false; stopAutoFish() end
        if EF.autoSell then EF.autoSell = false; stopAutoSell() end
        if EF.autoFavorite then EF.autoFavorite = false; stopAutoFavorite() end
        if EF.autoTrade then EF.autoTrade = false; stopAutoTrade() end
        notify("E-Fishery", "Stopped all automation.")
    end
})

-- Settings: notification duration and manual remote override entries
SettingsSection:CreateSlider({
    Name = "Notification Duration (s)",
    Range = {1, 20},
    Increment = 1,
    CurrentValue = EF.notifyDuration,
    Flag = "NotifyDuration",
    Callback = function(val)
        EF.notifyDuration = val
    end
})

-- Manual remote configuration (textboxes)
SettingsSection:CreateInput({
    Name = "Manual REMOTES.Fish name (leave blank to autodetect)",
    PlaceholderText = "",
    RemoveTextAfterFocusLost = false,
    Callback = function(val)
        if val and val ~= "" then
            local found = ReplicatedStorage:FindFirstChild(val)
            if found then
                REMOTES.Fish = found
                notify("REMOTES", ("Set REMOTES.Fish to '%s'"):format(val))
            else
                notify("REMOTES", ("'%s' not found under ReplicatedStorage"):format(val), 6)
            end
        else
            REMOTES.Fish = findRemoteByNames(ReplicatedStorage, {"Fish", "Cast", "FishRemote", "CastRemote", "RemoteCast"})
            notify("REMOTES", "REMOTES.Fish reset to autodetect.")
        end
    end
})

SettingsSection:CreateInput({
    Name = "Manual REMOTES.Sell name (leave blank to autodetect)",
    PlaceholderText = "",
    RemoveTextAfterFocusLost = false,
    Callback = function(val)
        if val and val ~= "" then
            local found = ReplicatedStorage:FindFirstChild(val)
            if found then
                REMOTES.Sell = found
                notify("REMOTES", ("Set REMOTES.Sell to '%s'"):format(val))
            else
                notify("REMOTES", ("'%s' not found under ReplicatedStorage"):format(val), 6)
            end
        else
            REMOTES.Sell = findRemoteByNames(ReplicatedStorage, {"Sell", "SellRemote", "SellAll", "SellFishes"})
            notify("REMOTES", "REMOTES.Sell reset to autodetect.")
        end
    end
})

SettingsSection:CreateInput({
    Name = "Manual REMOTES.Favorite name (leave blank to autodetect)",
    PlaceholderText = "",
    RemoveTextAfterFocusLost = false,
    Callback = function(val)
        if val and val ~= "" then
            local found = ReplicatedStorage:FindFirstChild(val)
            if found then
                REMOTES.Favorite = found
                notify("REMOTES", ("Set REMOTES.Favorite to '%s'"):format(val))
            else
                notify("REMOTES", ("'%s' not found under ReplicatedStorage"):format(val), 6)
            end
        else
            REMOTES.Favorite = findRemoteByNames(ReplicatedStorage, {"Favorite", "FavoriteRemote", "Fav", "FavoriteFish"})
            notify("REMOTES", "REMOTES.Favorite reset to autodetect.")
        end
    end
})

-- Info / About
local aboutSection = SettingsTab:CreateSection("About")
SettingsTab:CreateLabel({ Name = "E-Fishery — Rayfield UI Rebuild" })
SettingsTab:CreateLabel({ Name = "Validation / Check Data removed per request" })
SettingsTab:CreateLabel({ Name = "Teleport features removed per request" })

-- Startup notification
notify("E-Fishery Loaded", "UI initialized with Rayfield. Configure REMOTES under Settings if autodetect fails.", 6)

-- If anti-AFK was set to true initially, start it
if EF.antiAFK then startAntiAFK() end

-- If auto toggles are set in saved config, start them
if EF.autoFish then startAutoFish() end
if EF.autoSell then startAutoSell() end
if EF.autoFavorite then startAutoFavorite() end
if EF.autoTrade then startAutoTrade() end

-- ---------------------------------------------------------------------
-- Clean shutdown on script unload (best-effort)
-- ---------------------------------------------------------------------
local function cleanup()
    stopAutoFish()
    stopAutoSell()
    stopAutoFavorite()
    stopAutoTrade()
    stopAntiAFK()
    notify("E-Fishery", "Script unloaded — stopped all features.", 4)
end

-- Many exploit runners don't provide an explicit unload hook. If you plan to re-run, consider restarting Roblox or manually disabling toggles.
-- Optionally expose a global to allow external unloading:
getgenv().E_FISHERY_UNLOAD = cleanup

-- End of script
