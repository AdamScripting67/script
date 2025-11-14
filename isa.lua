local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'

local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

local Window = Library:CreateWindow({
    Title = 'Astroid | 0.50 | FISH IT',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2
})

-- Create all requested tabs
local Tabs = {
    Automatic = Window:AddTab('Automatic'),  -- renamed from Auto Fish
    Teleports = Window:AddTab('Teleports'),
    Purchase = Window:AddTab('Purchase'),
    Misc = Window:AddTab('Misc'),
    Configuration = Window:AddTab('Configuration'),
}

-- Automatic tab setup
local AutoGroup = Tabs.Automatic:AddRightGroupbox('Auto Events')

AutoGroup:AddToggle('AutoFishToggle', {
    Text = 'Auto Shark Hunt',
    Default = false,
    Tooltip = 'Automatically does Shark Hunt for you',
    Callback = function(Value)
        print('[Automatic] Enabled:', Value)
    end
})

AutoGroup:AddToggle('AutoFishToggle', {
    Text = 'Auto Megalodon Hunt',
    Default = false,
    Tooltip = 'Automatically does Worm Hunt for you',
    Callback = function(Value)
        print('[Automatic] Enabled:', Value)
    end
})

AutoGroup:AddToggle('AutoFishToggle', {
    Text = 'Auto Worm Hunt',
    Default = false,
    Tooltip = 'Automatically does Worm Hunt for you',
    Callback = function(Value)
        print('[Automatic] Enabled:', Value)
    end
})

local AutoGroup = Tabs.Automatic:AddLeftGroupbox('Auto Fish')

-- Toggle for Auto Fishing
AutoGroup:AddToggle('AutoFishToggle', {
    Text = 'Auto Cast',
    Default = false,
    Tooltip = 'Automatically casts rod for you',
    Callback = function(v)
        local args = {v}
    game:GetService("ReplicatedStorage")
        :WaitForChild("Packages")
        :WaitForChild("_Index")
        :WaitForChild("sleitnick_net@0.2.0")
        :WaitForChild("net")
        :WaitForChild("RF/UpdateAutoFishingState")
        :InvokeServer(unpack(args))
    print("Auto Cast toggled:", v)
end
})

AutoGroup:AddToggle('AutoFishToggle', {
    Text = 'Auto Reel',
    Default = false,
    Tooltip = 'Automatically reels fishes for you',
    Callback = function(Value)
        print('[Automatic] Enabled:', Value)
    end
})

AutoGroup:AddToggle('AutoFishToggle', {
    Text = 'Instant Catch',
    Default = false,
    Tooltip = 'Instantly catches fishes for you',
    Callback = function(Value)
        print('[Automatic] Enabled:', Value)
    end
})

AutoGroup:AddToggle('AutoFishToggle', {
    Text = 'Freeze Player',
    Default = false,
    Tooltip = 'Freezes your character',
    Callback = function(v)
        local player = game.Players.LocalPlayer
    local char = player.Character or player.CharacterAdded:Wait()
    local root = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("Torso")
    local hum = char:FindFirstChildWhichIsA("Humanoid") or char:WaitForChild("Humanoid")
    
    if v then
        root.Anchored = true
        hum.WalkSpeed = 0
        if hum.JumpPower ~= nil then hum.JumpPower = 0 end
        hum.PlatformStand = true
    else
        root.Anchored = false
        hum.WalkSpeed = 16
        if hum.JumpPower ~= nil then hum.JumpPower = 50 end
        hum.PlatformStand = false
    end
end
})

-- Dropdown for Fishing Type
AutoGroup:AddDropdown('FishingType', {
    Values = {'Fast', 'Legit'},
    Default = 1,
    Multi = false,
    Text = 'Fishing Type',
    Tooltip = 'Choose fishing mode',
    Callback = function(Value)
        print('[Automatic] Fishing Type:', Value)
    end
})


local AutoGroup = Tabs.Automatic:AddLeftGroupbox('Auto Enchant') -- or Automatic tab

local enchanting = false

AutoGroup:AddToggle('AutoEnchant', {
    Text = 'Auto Enchant',
    Default = false,
    Tooltip = 'Automatically rolls enchant for the item in hand',
    Callback = function(enabled)
        enchanting = enabled

        if enabled then
            task.spawn(function()
                while enchanting do
                    local RollEnchantRemote = game:GetService("ReplicatedStorage")
                        :WaitForChild("Packages")
                        :WaitForChild("_Index")
                        :WaitForChild("sleitnick_net@0.2.0")
                        :WaitForChild("net")
                        :WaitForChild("RE/RollEnchant")

                    RollEnchantRemote:FireServer()
                    print("Fired Roll Enchant remote!")

                    task.wait(0.5) -- adjust delay for safety
                end
            end)
        end
    end
})

AutoGroup:AddDropdown('EnchantType', {
    Values = {
        "Glistening",
        "Reeler",
        "Xperienced",
        "Gold Digger I",
        "Mutation Hunter I",
        "Mutation Hunter II",
        "Prismatic",
        "Leprechaun I",
        "Leprechaun II",
        "Big Hunter",
        "Cursed",
        "Stormhunter",
        "Stargazer",
        "Empowered"
    },
    Default = 1, -- default selects "Glistening"
    Multi = false, -- only one selection at a time
    Text = 'Select Enchant',
    Tooltip = 'Choose which enchant to roll',
    Callback = function(selected)
        print("Selected Enchant:", selected)
        -- You can store the selected enchant in a variable to use with RollEnchant
        _G.SelectedEnchant = selected
    end
})

AutoGroup:AddButton({
    Text = 'Enchant In Hand',
    Func = function()
        local RollEnchantRemote = game:GetService("ReplicatedStorage")
            :WaitForChild("Packages")
            :WaitForChild("_Index")
            :WaitForChild("sleitnick_net@0.2.0")
            :WaitForChild("net")
            :WaitForChild("RE/RollEnchant")

        RollEnchantRemote:FireServer()
        print("Fired Roll Enchant remote!")
    end,
    Tooltip = 'Click to roll enchant'
})



local AutoGroup = Tabs.Automatic:AddRightGroupbox('Auto Quest')

AutoGroup:AddButton({
    Text = 'Aura Kid Quest',
    Func = function()
        print("hello world")
    end
})

local AutoGroup = Tabs.Automatic:AddLeftGroupbox('Auto Sell')


local sellAllToggle = false

AutoGroup:AddToggle('Auto Sell Fish', {
    Text = 'Auto Sell',
    Default = false,
    Tooltip = 'Automatically sells all items in a loop',
    Callback = function(enabled)
        sellAllToggle = enabled
        if enabled then
            task.spawn(function()
                while sellAllToggle do
                    -- Fire the SellAllItems remote
                    game:GetService("ReplicatedStorage")
                        :WaitForChild("Packages")
                        :WaitForChild("_Index")
                        :WaitForChild("sleitnick_net@0.2.0")
                        :WaitForChild("net")
                        :WaitForChild("RF/SellAllItems")
                        :InvokeServer()

                    task.wait(0.5) -- safe delay
                end
            end)
        end
    end
})

AutoGroup:AddButton({
    Text = 'Sell Inventory',
    Func = function()
        local SellInventoryRemote = game:GetService("ReplicatedStorage")
            :WaitForChild("Packages")
            :WaitForChild("_Index")
            :WaitForChild("sleitnick_net@0.2.0")
            :WaitForChild("net")
            :WaitForChild("RF/SellAllItems")

        SellInventoryRemote:InvokeServer()
        print("Inventory sold!")
    end,
    Tooltip = 'Click to sell all items in your inventory'
})

AutoGroup:AddButton({
    Text = 'Sell Item In Hand',
    Func = function()
        local player = game.Players.LocalPlayer
        local char = player.Character or player.CharacterAdded:Wait()
        local tool = char:FindFirstChildOfClass("Tool")

        if not tool then
            warn("No tool equipped!")
            return
        end

        local uuidObj = tool:FindFirstChild("UUID")
        if not uuidObj or not uuidObj.Value then
            warn("Item has no UUID!")
            return
        end

        local uuid = uuidObj.Value
        local args = { uuid }

        local SellItemRemote = game:GetService("ReplicatedStorage")
            .Packages
            ._Index["sleitnick_net@0.2.0"]
            .net["RF/SellItem"]

        SellItemRemote:InvokeServer(unpack(args))

        print("Sold item with UUID:", uuid)
    end,
    Tooltip = 'Sells the item currently equipped (uses UUID)'
})



-- Teleports tab groupbox
local TeleportsGroup = Tabs.Teleports:AddLeftGroupbox('Teleport Locations')

-- List of islands
local islands = {
    "Fisherman Island",
    "Ancient Jungle",
    "Coral Reefs",
    "Crater Island",
    "Esoteric Depths",
    "Kohana",
    "Kohana Volcano",
    "Lost Isle",
    "Tropical Grove",
    "Weather Machine"
}

-- Dropdown for island teleports
TeleportsGroup:AddDropdown('IslandTeleports', {
    Values = islands,
    Default = 1,
    Multi = false,
    Text = 'Island Teleports',
    Tooltip = 'Select an island to teleport',
    Callback = function(selected)
        local player = game.Players.LocalPlayer
        local char = player.Character or player.CharacterAdded:Wait()
        local root = char:WaitForChild("HumanoidRootPart")

        local islandFolder = workspace:FindFirstChild("!!!! ISLAND LOCATIONS !!!!")
        local island = islandFolder and islandFolder:FindFirstChild(selected)

        if island then
            if island:IsA("Model") and island.PrimaryPart then
                root.CFrame = island.PrimaryPart.CFrame + Vector3.new(0, 5, 0)
            elseif island:IsA("BasePart") then
                root.CFrame = island.CFrame + Vector3.new(0, 5, 0)
            else
                warn("Cannot determine " .. selected .. " position")
            end
            print("Teleported to " .. selected)
        else
            warn(selected .. " not found in workspace")
        end
    end
})


-- Purchase tab groupbox
local PurchaseGroup = Tabs.Purchase:AddLeftGroupbox('Shop & Purchases')

-- Rod IDs
local rods = {
    ["Luck Rod"] = nil,
    ["Carbon Rod"] = 76,
    ["Grass Rod"] = 85,
    ["Demascus Rod"] = 78,
    ["Ice Rod"] = 78
}

-- Dropdown for purchasing rods
PurchaseGroup:AddDropdown('PurchaseRods', {
    Values = {"Luck Rod", "Carbon Rod", "Grass Rod", "Demascus Rod", "Ice Rod"},
    Default = 1,
    Multi = false,
    Text = 'Purchase Rods',
    Tooltip = 'Select a rod to purchase',
    Callback = function(selected)
        if selected == "Luck Rod" then
            print("Purchased Rod Upgrade")
        else
            local id = rods[selected]
            if id then
                local args = {id}
                game:GetService("ReplicatedStorage")
                    :WaitForChild("Packages")
                    :WaitForChild("_Index")
                    :WaitForChild("sleitnick_net@0.2.0")
                    :WaitForChild("net")
                    :WaitForChild("RF/PurchaseFishingRod")
                    :InvokeServer(unpack(args))
                print("Purchased " .. selected)
            else
                warn("No rod ID found for " .. selected)
            end
        end
    end
})

-- Boat IDs
local boats = {
    ["Small Boat"] = 1,
    ["Kayak"] = 2,
    ["Jetski"] = 3,
    ["Highfield Boat"] = 4,
    ["Speed Boat"] = 5,
    ["Fishing Boat"] = 6,
    ["Mini Yacht"] = 7
}

-- Dropdown for purchasing boats
PurchaseGroup:AddDropdown('PurchaseBoats', {
    Values = {"Small Boat", "Kayak", "Jetski", "Highfield Boat", "Speed Boat", "Fishing Boat", "Mini Yacht"},
    Default = 1,
    Multi = false,
    Text = 'Purchase Boats',
    Tooltip = 'Select a boat to purchase',
    Callback = function(selected)
        local boatId = boats[selected]
        if boatId then
            local args = {boatId}
            game:GetService("ReplicatedStorage")
                :WaitForChild("Packages")
                :WaitForChild("_Index")
                :WaitForChild("sleitnick_net@0.2.0")
                :WaitForChild("net")
                :WaitForChild("RF/PurchaseBoat")
                :InvokeServer(unpack(args))
            print("Purchased " .. selected)
        else
            warn("Boat ID not found for " .. selected)
        end
    end
})


-- Misc tab groupbox
local MiscGroup = Tabs.Misc:AddLeftGroupbox('Misc Features')

local RunService = game:GetService("RunService")
local player = game.Players.LocalPlayer

local walkingOnWaterConnection
local walkingOnWaterBP

-- Walk on Water toggle
MiscGroup:AddToggle('WalkOnWater', {
    Text = 'Walk on Water',
    Default = false,
    Tooltip = 'Allows you to walk on water',
    Callback = function(enabled)
        local char = player.Character or player.CharacterAdded:Wait()
        local root = char:WaitForChild("HumanoidRootPart")
        local hum = char:WaitForChild("Humanoid")

        if enabled then
            hum.JumpPower = 0

            walkingOnWaterBP = Instance.new("BodyPosition")
            walkingOnWaterBP.MaxForce = Vector3.new(0, math.huge, 0)
            walkingOnWaterBP.D = 10
            walkingOnWaterBP.P = 1000
            walkingOnWaterBP.Position = root.Position
            walkingOnWaterBP.Parent = root

            walkingOnWaterConnection = RunService.RenderStepped:Connect(function()
                local waterHeight = 5
                if root.Position.Y < waterHeight + 2 then
                    walkingOnWaterBP.Position = Vector3.new(root.Position.X, waterHeight + 2, root.Position.Z)
                end
            end)
        else
            hum.JumpPower = 50

            if walkingOnWaterConnection then
                walkingOnWaterConnection:Disconnect()
                walkingOnWaterConnection = nil
            end
            if walkingOnWaterBP then
                walkingOnWaterBP:Destroy()
                walkingOnWaterBP = nil
            end
        end
    end
})

-- Disable Shadows toggle
local Lighting = game:GetService("Lighting")
local originalShadows = Lighting.GlobalShadows
local originalBrightness = Lighting.Brightness
local originalAmbient = Lighting.Ambient

MiscGroup:AddToggle('DisableShadows', {
    Text = 'Disable Shadows',
    Default = false,
    Tooltip = 'Disables lighting shadows',
    Callback = function(enabled)
        if enabled then
            Lighting.GlobalShadows = false
            print("Shadows disabled")
        else
            Lighting.GlobalShadows = originalShadows
            Lighting.Brightness = originalBrightness
            Lighting.Ambient = originalAmbient
            print("Shadows restored")
        end
    end
})

-- Always Sprint toggle
MiscGroup:AddToggle('AlwaysSprint', {
    Text = 'Always Sprint',
    Default = false,
    Tooltip = 'Keeps you sprinting automatically',
    Callback = function(enabled)
        local args = {enabled}
        game:GetService("ReplicatedStorage")
            :WaitForChild("Packages")
            :WaitForChild("_Index")
            :WaitForChild("sleitnick_net@0.2.0")
            :WaitForChild("net")
            :WaitForChild("RE/ChangeSprintState")
            :FireServer(unpack(args))
        print("Always Sprint toggled:", enabled)
    end
})


-- Configuration tab (saves + menu keybind)
local ConfigGroup = Tabs.Configuration:AddLeftGroupbox('Configuration')
ConfigGroup:AddButton('Unload', function()
    Library:Unload()
end)
ConfigGroup:AddLabel('Menu Keybind'):AddKeyPicker('MenuKeybind', { Default = 'End', NoUI = true, Text = 'Menu Keybind' })

-- Bind menu toggle
Library.ToggleKeybind = Options.MenuKeybind

-- Setup ThemeManager and SaveManager
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'MenuKeybind' })
ThemeManager:SetFolder('MyScriptHub')
SaveManager:SetFolder('MyScriptHub/specific-game')
SaveManager:BuildConfigSection(Tabs.Configuration)
ThemeManager:ApplyToTab(Tabs.Configuration)
SaveManager:LoadAutoloadConfig()

Library:OnUnload(function()
    print('Unloaded!')
    Library.Unloaded = true
end)
