-- Pet Age Hub - Light Minimalist Design
print('Loading MK Hub Light...')

repeat task.wait() until game:IsLoaded()
repeat task.wait() until game:GetService("Players").LocalPlayer
repeat task.wait() until game:GetService("Players").LocalPlayer.Backpack

local Services = setmetatable({}, {
    __index = function(self, Ind)
        local Success, Result = pcall(function()
            return cloneref(game:GetService(Ind) :: any)
        end)
        if Success and Result then
            rawset(self, Ind, Result)
            return Result
        end
        return nil
    end
})

local ReplicatedStorage = Services.ReplicatedStorage
local Players = Services.Players
local Player = Players.LocalPlayer

-- Safe loading with error handling
local DataService, PetsData, GiftPetRemote, FavoriteRemote, UnlockSlotFromPet, PetsService, TradeService, InventoryEnums

pcall(function()
    DataService = require(ReplicatedStorage.Modules.DataService):GetData()
    PetsData = DataService.PetsData
end)

pcall(function()
    GiftPetRemote = ReplicatedStorage.GameEvents.PetGiftingService
    FavoriteRemote = ReplicatedStorage.GameEvents.Favorite_Item
    UnlockSlotFromPet = ReplicatedStorage.GameEvents.UnlockSlotFromPet
    PetsService = ReplicatedStorage.GameEvents.PetsService
    TradeService = ReplicatedStorage.GameEvents:FindFirstChild("TradeService") or ReplicatedStorage.GameEvents:FindFirstChild("Trading")
    InventoryEnums = require(ReplicatedStorage.Data.EnumRegistry.InventoryServiceEnums)
end)

-- Configuration
getgenv().Config = {
    MAIN = {},  
    LIST_CLONE = {},
    LIST_PET = {},  
    EQUIP_PETS = {}, 
    AMOUNT = 8,  
    MIN_AGE = 60, 
    MAX_AGE = 74, 
    EXTRA_PET_SLOT = 8,
    EXTRA_EGG_SLOT = 8,
    AUTO_ACCEPT_TRADE = true,
    AUTO_TRADE = false,
    TRADE_AMOUNT = 5,
    AUTO_UPGRADE_PET_SLOT = true,
    AUTO_UPGRADE_EGG_SLOT = true
}

local Config = getgenv().Config
local cloneSent = {}
local isRunning = false
local tradeQueue = {}
local pendingTrades = {}
local tradeAccepted = {}

-- Core Functions
function waitUntilDone(item)
    for _ = 1, 200 do
        if not item.Parent then return true end
        task.wait(0.05)
    end
    return nil
end

Player.Idled:Connect(function()
    game:GetService("VirtualUser"):CaptureController()
    game:GetService("VirtualUser"):ClickButton2(Vector2.new())
end)

function PrintDebug(...)
    print(string.format('[MK HUB] %s', tostring(...)))
end

function DetectPlayersInServer()
    local players = {}
    for _, player in Players:GetPlayers() do
        if player ~= Player and player.Name ~= Player.Name then
            table.insert(players, player)
        end
    end
    return players
end

function StartTradeWithPlayer(targetPlayer)
    if not GiftPetRemote or not targetPlayer then 
        PrintDebug('GiftPetRemote or targetPlayer not found')
        return 
    end
    
    if not PetsData or not PetsData.PetInventory then
        PrintDebug('PetsData not loaded')
        return
    end
    
    PrintDebug('Starting gift to: ' .. targetPlayer.Name)
    
    local count = 0
    Player.Character.Humanoid:UnequipTools()
    
    for _, pet in Player.Backpack:GetChildren() do
        if count >= Config.TRADE_AMOUNT then break end
        
        if pet:GetAttribute('PET_UUID') then
            local petUUID = pet:GetAttribute('PET_UUID')
            if petUUID and PetsData.PetInventory.Data[petUUID] then
                local PetData = PetsData.PetInventory.Data[petUUID]
                local petAge = PetData.PetData.Level
                
                if petAge >= Config.MIN_AGE and petAge <= Config.MAX_AGE then
                    PrintDebug('Found suitable pet: ' .. PetData.PetType .. ' Age: ' .. petAge)
                    
                    if InventoryEnums and pet:GetAttribute(InventoryEnums['Favorite']) then
                        FavoriteRemote:FireServer(pet)
                        task.wait(0.05)
                    end
                    
                    Player.Character.Humanoid:UnequipTools()
                    pet.Parent = Player.Character
                    task.wait(0.1)
                    
                    GiftPetRemote:FireServer("GivePet", targetPlayer)
                    
                    if waitUntilDone(pet) then
                        count = count + 1
                        PrintDebug('Gift Success - ' .. count .. '/' .. Config.TRADE_AMOUNT)
                        
                        -- Wait for gift acceptance before continuing
                        local giftTimeout = 0
                        while giftTimeout < 10 do
                            task.wait(0.5)
                            giftTimeout = giftTimeout + 0.5
                            -- Check if we should continue (simplified check)
                            if giftTimeout >= 5 then break end
                        end
                    else
                        PrintDebug('Gift failed')
                    end
                end
            end
        end
    end
    
    -- Mark trade as completed
    pendingTrades[targetPlayer.Name] = nil
    tradeAccepted[targetPlayer.Name] = true
    PrintDebug('Finished gifting to ' .. targetPlayer.Name .. ' - Total: ' .. count)
end

function AddPetsToTrade()
    if not PetsData or not TradeService then return 0 end
    
    local count = 0
    local listPetAge = ListPetAge()
    
    for _, petData in ipairs(listPetAge) do
        if count >= Config.TRADE_AMOUNT then break end
        
        if petData.AGE >= Config.MIN_AGE and petData.AGE <= Config.MAX_AGE then
            pcall(function()
                TradeService:FireServer("AddPet", petData.UUID)
                PrintDebug('Added pet to trade - Age: ' .. petData.AGE)
                count = count + 1
            end)
        end
    end
    
    return count
end

function ListSlots()
    if not PetsData then return {PetEquippedSlots = 3, EggSlots = 3, PurchasedEquipSlots = 3, PurchasedEggSlots = 3} end
    
    local currentPetSlots = 3
    local currentEggSlots = 3
    local purchasedPetSlots = 0
    local purchasedEggSlots = 0
    
    pcall(function()
        if PetsData.MutableStats then
            currentPetSlots = PetsData.MutableStats.MaxEquippedPets or 3
            currentEggSlots = PetsData.MutableStats.MaxEggsInFarm or 3
        end
        
        purchasedPetSlots = math.max(0, currentPetSlots - 3)
        purchasedEggSlots = math.max(0, currentEggSlots - 3)
        
        if PetsData.PurchasedEquipSlots then
            purchasedPetSlots = PetsData.PurchasedEquipSlots
        end
        if PetsData.PurchasedEggSlots then
            purchasedEggSlots = PetsData.PurchasedEggSlots
        end
        
        PrintDebug('Slots Info - Pet: ' .. currentPetSlots .. ' (Purchased: ' .. purchasedPetSlots .. '), Egg: ' .. currentEggSlots .. ' (Purchased: ' .. purchasedEggSlots .. ')')
    end)
    
    return {
        ["PetEquippedSlots"] = currentPetSlots,
        ["EggSlots"] = currentEggSlots,
        ["PurchasedEquipSlots"] = currentPetSlots,
        ["PurchasedEggSlots"] = currentEggSlots
    }
end

function AgeCanUpgrade(purchasedCount)
    local listAge = {20, 30, 45, 60, 75}
    return listAge[purchasedCount + 1] or 0
end

function ListPetAge()
    if not PetsData then return {} end
    local listPets = {}
    local listUUID = {}

    pcall(function()
        for uuid, petData in PetsData.PetInventory.Data do
            local petAge = petData.PetData.Level
            listPets[uuid] = petAge
        end

        for uuid, _ in listPets do
            table.insert(listUUID, uuid)
        end

        table.sort(listUUID, function(a, b)
            return listPets[a] > listPets[b]
        end)
    end)

    local cache = {}
    for i, v in listUUID do
        table.insert(cache, {UUID = v, AGE = listPets[v]})
    end

    return cache
end

function CountPetsAge60Plus()
    local count = 0
    local listPetAge = ListPetAge()
    
    for _, petData in ipairs(listPetAge) do
        if petData.AGE >= 60 then
            count = count + 1
        end
    end
    
    return count
end

function UpgradePetSlot()
    if not UnlockSlotFromPet or not Config.AUTO_UPGRADE_PET_SLOT then return end
    
    local listPetAge = ListPetAge()
    local slots = ListSlots()
    
    for i, v in listPetAge do
        if v.AGE >= 60 and slots.PurchasedEquipSlots < Config.EXTRA_PET_SLOT then
            PrintDebug('Fast Upgrading Pet Slot: ' .. (slots.PurchasedEquipSlots + 1) .. '/' .. Config.EXTRA_PET_SLOT .. ' (Age: ' .. v.AGE .. ')')
            pcall(function()
                UnlockSlotFromPet:FireServer(v.UUID, "Pet")
            end)
            task.wait(0.1)
            slots = ListSlots()
        end
    end
end

function UpgradeEggSlot()
    if not UnlockSlotFromPet or not Config.AUTO_UPGRADE_EGG_SLOT then return end
    
    local listPetAge = ListPetAge()
    local slots = ListSlots()
    
    for i, v in listPetAge do
        if v.AGE >= 60 and slots.PurchasedEggSlots < Config.EXTRA_EGG_SLOT then
            PrintDebug('Fast Upgrading Egg Slot: ' .. (slots.PurchasedEggSlots + 1) .. '/' .. Config.EXTRA_EGG_SLOT .. ' (Age: ' .. v.AGE .. ')')
            pcall(function()
                UnlockSlotFromPet:FireServer(v.UUID, "Egg")
            end)
            task.wait(0.1)
            slots = ListSlots()
        end
    end
end

-- Light Minimalist GUI
local ScreenGui = Instance.new("ScreenGui")
local MainFrame = Instance.new("Frame")
local HeaderFrame = Instance.new("Frame")
local Title = Instance.new("TextLabel")
local StartButton = Instance.new("TextButton")
local StopButton = Instance.new("TextButton")
local TradeToggle = Instance.new("TextButton")
local StatusLabel = Instance.new("TextLabel")
local ConfigFrame = Instance.new("Frame")
local AmountLabel = Instance.new("TextLabel")
local AmountBox = Instance.new("TextBox")
local MinAgeLabel = Instance.new("TextLabel")
local MinAgeBox = Instance.new("TextBox")
local MaxAgeLabel = Instance.new("TextLabel")
local MaxAgeBox = Instance.new("TextBox")
local PetSlotLabel = Instance.new("TextLabel")
local PetSlotBox = Instance.new("TextBox")
local EggSlotLabel = Instance.new("TextLabel")
local EggSlotBox = Instance.new("TextBox")
local TradeAmountLabel = Instance.new("TextLabel")
local TradeAmountBox = Instance.new("TextBox")
local PetSlotToggle = Instance.new("TextButton")
local EggSlotToggle = Instance.new("TextButton")
local PetCountLabel = Instance.new("TextLabel")
local InfoLabel = Instance.new("TextLabel")
local CloseButton = Instance.new("TextButton")

-- Light GUI Properties
ScreenGui.Name = "MKHubLight"
ScreenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.ResetOnSpawn = false

-- Light Main Frame
MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(250, 250, 250)
MainFrame.BorderSizePixel = 1
MainFrame.BorderColor3 = Color3.fromRGB(220, 220, 220)
MainFrame.Position = UDim2.new(0.5, -200, 0.5, -180)
MainFrame.Size = UDim2.new(0, 400, 0, 360)
MainFrame.Active = true
MainFrame.Draggable = true

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = MainFrame

-- Light Header Frame
HeaderFrame.Name = "HeaderFrame"
HeaderFrame.Parent = MainFrame
HeaderFrame.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
HeaderFrame.BorderSizePixel = 0
HeaderFrame.Size = UDim2.new(1, 0, 0, 40)

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 8)
HeaderCorner.Parent = HeaderFrame

-- Bold Title
Title.Name = "Title"
Title.Parent = HeaderFrame
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0, 12, 0, 0)
Title.Size = UDim2.new(0, 300, 0, 40)
Title.Font = Enum.Font.GothamBold
Title.Text = "MK Hub - Auto Trade & Upgrade"
Title.TextColor3 = Color3.fromRGB(30, 30, 30)
Title.TextSize = 18
Title.TextXAlignment = Enum.TextXAlignment.Left

-- Hide Button
local HideButton = Instance.new("TextButton")
HideButton.Name = "HideButton"
HideButton.Parent = HeaderFrame
HideButton.BackgroundColor3 = Color3.fromRGB(255, 193, 7)
HideButton.BorderSizePixel = 0
HideButton.Position = UDim2.new(1, -65, 0, 8)
HideButton.Size = UDim2.new(0, 24, 0, 24)
HideButton.Font = Enum.Font.SourceSansBold
HideButton.Text = "_"
HideButton.TextColor3 = Color3.fromRGB(255, 255, 255)
HideButton.TextSize = 16

local HideCorner = Instance.new("UICorner")
HideCorner.CornerRadius = UDim.new(0, 12)
HideCorner.Parent = HideButton

-- Light Close Button
CloseButton.Name = "CloseButton"
CloseButton.Parent = HeaderFrame
CloseButton.BackgroundColor3 = Color3.fromRGB(255, 95, 95)
CloseButton.BorderSizePixel = 0
CloseButton.Position = UDim2.new(1, -35, 0, 8)
CloseButton.Size = UDim2.new(0, 24, 0, 24)
CloseButton.Font = Enum.Font.SourceSansBold
CloseButton.Text = "×"
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.TextSize = 16

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 12)
CloseCorner.Parent = CloseButton

-- Light Control Buttons
StartButton.Name = "StartButton"
StartButton.Parent = MainFrame
StartButton.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
StartButton.BorderSizePixel = 0
StartButton.Position = UDim2.new(0, 12, 0, 52)
StartButton.Size = UDim2.new(0, 80, 0, 32)
StartButton.Font = Enum.Font.SourceSansBold
StartButton.Text = "START"
StartButton.TextColor3 = Color3.fromRGB(255, 255, 255)
StartButton.TextSize = 14

local StartCorner = Instance.new("UICorner")
StartCorner.CornerRadius = UDim.new(0, 6)
StartCorner.Parent = StartButton

StopButton.Name = "StopButton"
StopButton.Parent = MainFrame
StopButton.BackgroundColor3 = Color3.fromRGB(244, 67, 54)
StopButton.BorderSizePixel = 0
StopButton.Position = UDim2.new(0, 100, 0, 52)
StopButton.Size = UDim2.new(0, 80, 0, 32)
StopButton.Font = Enum.Font.SourceSansBold
StopButton.Text = "STOP"
StopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
StopButton.TextSize = 14

local StopCorner = Instance.new("UICorner")
StopCorner.CornerRadius = UDim.new(0, 6)
StopCorner.Parent = StopButton

TradeToggle.Name = "TradeToggle"
TradeToggle.Parent = MainFrame
TradeToggle.BackgroundColor3 = Config.AUTO_TRADE and Color3.fromRGB(33, 150, 243) or Color3.fromRGB(158, 158, 158)
TradeToggle.BorderSizePixel = 0
TradeToggle.Position = UDim2.new(0, 188, 0, 52)
TradeToggle.Size = UDim2.new(0, 70, 0, 32)
TradeToggle.Font = Enum.Font.SourceSansBold
TradeToggle.Text = Config.AUTO_TRADE and "TRADE ON" or "TRADE OFF"
TradeToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
TradeToggle.TextSize = 12

local TradeCorner = Instance.new("UICorner")
TradeCorner.CornerRadius = UDim.new(0, 6)
TradeCorner.Parent = TradeToggle

StatusLabel.Name = "StatusLabel"
StatusLabel.Parent = MainFrame
StatusLabel.BackgroundColor3 = Color3.fromRGB(230, 230, 230)
StatusLabel.BorderSizePixel = 0
-- Players Button
local PlayersButton = Instance.new("TextButton")
PlayersButton.Name = "PlayersButton"
PlayersButton.Parent = MainFrame
PlayersButton.BackgroundColor3 = Color3.fromRGB(156, 39, 176)
PlayersButton.BorderSizePixel = 0
PlayersButton.Position = UDim2.new(0, 266, 0, 52)
PlayersButton.Size = UDim2.new(0, 60, 0, 32)
PlayersButton.Font = Enum.Font.SourceSansBold
PlayersButton.Text = "PLAYERS"
PlayersButton.TextColor3 = Color3.fromRGB(255, 255, 255)
PlayersButton.TextSize = 10

local PlayersCorner = Instance.new("UICorner")
PlayersCorner.CornerRadius = UDim.new(0, 6)
PlayersCorner.Parent = PlayersButton

StatusLabel.Position = UDim2.new(0, 334, 0, 52)
StatusLabel.Size = UDim2.new(0, 54, 0, 32)
StatusLabel.Font = Enum.Font.SourceSansBold
StatusLabel.Text = "STOPPED"
StatusLabel.TextColor3 = Color3.fromRGB(244, 67, 54)
StatusLabel.TextSize = 12
StatusLabel.TextXAlignment = Enum.TextXAlignment.Center

local StatusCorner = Instance.new("UICorner")
StatusCorner.CornerRadius = UDim.new(0, 6)
StatusCorner.Parent = StatusLabel

-- Players List Frame
local PlayersFrame = Instance.new("ScrollingFrame")
PlayersFrame.Name = "PlayersFrame"
PlayersFrame.Parent = MainFrame
PlayersFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
PlayersFrame.BorderSizePixel = 1
PlayersFrame.BorderColor3 = Color3.fromRGB(200, 200, 200)
PlayersFrame.Position = UDim2.new(0, 12, 0, 96)
PlayersFrame.Size = UDim2.new(0, 376, 0, 160)
PlayersFrame.ScrollBarThickness = 6
PlayersFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
PlayersFrame.Visible = false

local PlayersFrameCorner = Instance.new("UICorner")
PlayersFrameCorner.CornerRadius = UDim.new(0, 6)
PlayersFrameCorner.Parent = PlayersFrame

local PlayersLayout = Instance.new("UIListLayout")
PlayersLayout.Parent = PlayersFrame
PlayersLayout.SortOrder = Enum.SortOrder.LayoutOrder
PlayersLayout.Padding = UDim.new(0, 2)

-- Light Config Frame
ConfigFrame.Name = "ConfigFrame"
ConfigFrame.Parent = MainFrame
ConfigFrame.BackgroundColor3 = Color3.fromRGB(245, 245, 245)
ConfigFrame.BorderSizePixel = 1
ConfigFrame.BorderColor3 = Color3.fromRGB(220, 220, 220)
ConfigFrame.Position = UDim2.new(0, 12, 0, 96)
ConfigFrame.Size = UDim2.new(0, 376, 0, 160)

local ConfigCorner = Instance.new("UICorner")
ConfigCorner.CornerRadius = UDim.new(0, 6)
ConfigCorner.Parent = ConfigFrame

-- Bold Input Fields
AmountLabel.Parent = ConfigFrame
AmountLabel.BackgroundTransparency = 1
AmountLabel.Position = UDim2.new(0, 12, 0, 8)
AmountLabel.Size = UDim2.new(0, 60, 0, 16)
AmountLabel.Font = Enum.Font.GothamBold
AmountLabel.Text = "Amount"
AmountLabel.TextColor3 = Color3.fromRGB(50, 50, 50)
AmountLabel.TextSize = 12
AmountLabel.TextXAlignment = Enum.TextXAlignment.Left

AmountBox.Parent = ConfigFrame
AmountBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
AmountBox.BorderSizePixel = 1
AmountBox.BorderColor3 = Color3.fromRGB(200, 200, 200)
AmountBox.Position = UDim2.new(0, 12, 0, 24)
AmountBox.Size = UDim2.new(0, 70, 0, 28)
AmountBox.Font = Enum.Font.GothamBold
AmountBox.Text = tostring(Config.AMOUNT)
AmountBox.TextColor3 = Color3.fromRGB(30, 30, 30)
AmountBox.TextSize = 14

local AmountCorner = Instance.new("UICorner")
AmountCorner.CornerRadius = UDim.new(0, 4)
AmountCorner.Parent = AmountBox

MinAgeLabel.Parent = ConfigFrame
MinAgeLabel.BackgroundTransparency = 1
MinAgeLabel.Position = UDim2.new(0, 94, 0, 8)
MinAgeLabel.Size = UDim2.new(0, 60, 0, 16)
MinAgeLabel.Font = Enum.Font.GothamBold
MinAgeLabel.Text = "Min Age"
MinAgeLabel.TextColor3 = Color3.fromRGB(50, 50, 50)
MinAgeLabel.TextSize = 12
MinAgeLabel.TextXAlignment = Enum.TextXAlignment.Left

MinAgeBox.Parent = ConfigFrame
MinAgeBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
MinAgeBox.BorderSizePixel = 1
MinAgeBox.BorderColor3 = Color3.fromRGB(200, 200, 200)
MinAgeBox.Position = UDim2.new(0, 94, 0, 24)
MinAgeBox.Size = UDim2.new(0, 70, 0, 28)
MinAgeBox.Font = Enum.Font.GothamBold
MinAgeBox.Text = tostring(Config.MIN_AGE)
MinAgeBox.TextColor3 = Color3.fromRGB(30, 30, 30)
MinAgeBox.TextSize = 14

local MinAgeCorner = Instance.new("UICorner")
MinAgeCorner.CornerRadius = UDim.new(0, 4)
MinAgeCorner.Parent = MinAgeBox

MaxAgeLabel.Parent = ConfigFrame
MaxAgeLabel.BackgroundTransparency = 1
MaxAgeLabel.Position = UDim2.new(0, 176, 0, 8)
MaxAgeLabel.Size = UDim2.new(0, 60, 0, 16)
MaxAgeLabel.Font = Enum.Font.GothamBold
MaxAgeLabel.Text = "Max Age"
MaxAgeLabel.TextColor3 = Color3.fromRGB(50, 50, 50)
MaxAgeLabel.TextSize = 12
MaxAgeLabel.TextXAlignment = Enum.TextXAlignment.Left

MaxAgeBox.Parent = ConfigFrame
MaxAgeBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
MaxAgeBox.BorderSizePixel = 1
MaxAgeBox.BorderColor3 = Color3.fromRGB(200, 200, 200)
MaxAgeBox.Position = UDim2.new(0, 176, 0, 24)
MaxAgeBox.Size = UDim2.new(0, 70, 0, 28)
MaxAgeBox.Font = Enum.Font.GothamBold
MaxAgeBox.Text = tostring(Config.MAX_AGE)
MaxAgeBox.TextColor3 = Color3.fromRGB(30, 30, 30)
MaxAgeBox.TextSize = 14

local MaxAgeCorner = Instance.new("UICorner")
MaxAgeCorner.CornerRadius = UDim.new(0, 4)
MaxAgeCorner.Parent = MaxAgeBox

PetSlotLabel.Parent = ConfigFrame
PetSlotLabel.BackgroundTransparency = 1
PetSlotLabel.Position = UDim2.new(0, 258, 0, 8)
PetSlotLabel.Size = UDim2.new(0, 70, 0, 16)
PetSlotLabel.Font = Enum.Font.GothamBold
PetSlotLabel.Text = "Pet Slots"
PetSlotLabel.TextColor3 = Color3.fromRGB(50, 50, 50)
PetSlotLabel.TextSize = 12
PetSlotLabel.TextXAlignment = Enum.TextXAlignment.Left

PetSlotBox.Parent = ConfigFrame
PetSlotBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
PetSlotBox.BorderSizePixel = 1
PetSlotBox.BorderColor3 = Color3.fromRGB(200, 200, 200)
PetSlotBox.Position = UDim2.new(0, 258, 0, 24)
PetSlotBox.Size = UDim2.new(0, 70, 0, 28)
PetSlotBox.Font = Enum.Font.GothamBold
PetSlotBox.Text = tostring(Config.EXTRA_PET_SLOT)
PetSlotBox.TextColor3 = Color3.fromRGB(30, 30, 30)
PetSlotBox.TextSize = 14

local PetSlotCorner = Instance.new("UICorner")
PetSlotCorner.CornerRadius = UDim.new(0, 4)
PetSlotCorner.Parent = PetSlotBox

EggSlotLabel.Parent = ConfigFrame
EggSlotLabel.BackgroundTransparency = 1
EggSlotLabel.Position = UDim2.new(0, 12, 0, 64)
EggSlotLabel.Size = UDim2.new(0, 70, 0, 16)
EggSlotLabel.Font = Enum.Font.GothamBold
EggSlotLabel.Text = "Egg Slots"
EggSlotLabel.TextColor3 = Color3.fromRGB(50, 50, 50)
EggSlotLabel.TextSize = 12
EggSlotLabel.TextXAlignment = Enum.TextXAlignment.Left

EggSlotBox.Parent = ConfigFrame
EggSlotBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
EggSlotBox.BorderSizePixel = 1
EggSlotBox.BorderColor3 = Color3.fromRGB(200, 200, 200)
EggSlotBox.Position = UDim2.new(0, 12, 0, 80)
EggSlotBox.Size = UDim2.new(0, 70, 0, 28)
EggSlotBox.Font = Enum.Font.GothamBold
EggSlotBox.Text = tostring(Config.EXTRA_EGG_SLOT)
EggSlotBox.TextColor3 = Color3.fromRGB(30, 30, 30)
EggSlotBox.TextSize = 14

local EggSlotCorner = Instance.new("UICorner")
EggSlotCorner.CornerRadius = UDim.new(0, 4)
EggSlotCorner.Parent = EggSlotBox

TradeAmountLabel.Parent = ConfigFrame
TradeAmountLabel.BackgroundTransparency = 1
TradeAmountLabel.Position = UDim2.new(0, 94, 0, 64)
TradeAmountLabel.Size = UDim2.new(0, 80, 0, 16)
TradeAmountLabel.Font = Enum.Font.GothamBold
TradeAmountLabel.Text = "Trade Amount"
TradeAmountLabel.TextColor3 = Color3.fromRGB(50, 50, 50)
TradeAmountLabel.TextSize = 12
TradeAmountLabel.TextXAlignment = Enum.TextXAlignment.Left

TradeAmountBox.Parent = ConfigFrame
TradeAmountBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
TradeAmountBox.BorderSizePixel = 1
TradeAmountBox.BorderColor3 = Color3.fromRGB(200, 200, 200)
TradeAmountBox.Position = UDim2.new(0, 94, 0, 80)
TradeAmountBox.Size = UDim2.new(0, 70, 0, 28)
TradeAmountBox.Font = Enum.Font.GothamBold
TradeAmountBox.Text = tostring(Config.TRADE_AMOUNT)
TradeAmountBox.TextColor3 = Color3.fromRGB(30, 30, 30)
TradeAmountBox.TextSize = 14

local TradeAmountCorner = Instance.new("UICorner")
TradeAmountCorner.CornerRadius = UDim.new(0, 4)
TradeAmountCorner.Parent = TradeAmountBox

PetSlotToggle.Name = "PetSlotToggle"
PetSlotToggle.Parent = ConfigFrame
PetSlotToggle.BackgroundColor3 = Config.AUTO_UPGRADE_PET_SLOT and Color3.fromRGB(76, 175, 80) or Color3.fromRGB(158, 158, 158)
PetSlotToggle.BorderSizePixel = 0
PetSlotToggle.Position = UDim2.new(0, 176, 0, 80)
PetSlotToggle.Size = UDim2.new(0, 70, 0, 28)
PetSlotToggle.Font = Enum.Font.SourceSansBold
PetSlotToggle.Text = Config.AUTO_UPGRADE_PET_SLOT and "PET ON" or "PET OFF"
PetSlotToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
PetSlotToggle.TextSize = 11

local PetSlotCorner = Instance.new("UICorner")
PetSlotCorner.CornerRadius = UDim.new(0, 4)
PetSlotCorner.Parent = PetSlotToggle

EggSlotToggle.Name = "EggSlotToggle"
EggSlotToggle.Parent = ConfigFrame
EggSlotToggle.BackgroundColor3 = Config.AUTO_UPGRADE_EGG_SLOT and Color3.fromRGB(76, 175, 80) or Color3.fromRGB(158, 158, 158)
EggSlotToggle.BorderSizePixel = 0
EggSlotToggle.Position = UDim2.new(0, 258, 0, 80)
EggSlotToggle.Size = UDim2.new(0, 70, 0, 28)
EggSlotToggle.Font = Enum.Font.SourceSansBold
EggSlotToggle.Text = Config.AUTO_UPGRADE_EGG_SLOT and "EGG ON" or "EGG OFF"
EggSlotToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
EggSlotToggle.TextSize = 11

local EggSlotCorner = Instance.new("UICorner")
EggSlotCorner.CornerRadius = UDim.new(0, 4)
EggSlotCorner.Parent = EggSlotToggle

-- Extra Large Pet Count Label
PetCountLabel.Name = "PetCountLabel"
PetCountLabel.Parent = ConfigFrame
PetCountLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
PetCountLabel.BorderSizePixel = 1
PetCountLabel.BorderColor3 = Color3.fromRGB(200, 200, 200)
PetCountLabel.Position = UDim2.new(0, 12, 0, 120)
PetCountLabel.Size = UDim2.new(0, 316, 0, 32)
PetCountLabel.Font = Enum.Font.GothamBold
PetCountLabel.Text = "Pets 60+: " .. CountPetsAge60Plus() .. " | Pet Slots: " .. ListSlots().PurchasedEquipSlots .. "/" .. Config.EXTRA_PET_SLOT .. " | Egg Slots: " .. ListSlots().PurchasedEggSlots .. "/" .. Config.EXTRA_EGG_SLOT
PetCountLabel.TextColor3 = Color3.fromRGB(20, 20, 20)
PetCountLabel.TextSize = 14
PetCountLabel.TextXAlignment = Enum.TextXAlignment.Center
PetCountLabel.TextWrapped = true

local PetCountCorner = Instance.new("UICorner")
PetCountCorner.CornerRadius = UDim.new(0, 4)
PetCountCorner.Parent = PetCountLabel

-- Bold Info Label
InfoLabel.Name = "InfoLabel"
InfoLabel.Parent = MainFrame
InfoLabel.BackgroundColor3 = Color3.fromRGB(245, 245, 245)
InfoLabel.BorderSizePixel = 1
InfoLabel.BorderColor3 = Color3.fromRGB(220, 220, 220)
InfoLabel.Position = UDim2.new(0, 12, 0, 268)
InfoLabel.Size = UDim2.new(0, 376, 0, 80)
InfoLabel.Font = Enum.Font.GothamBold
InfoLabel.Text = "Player: " .. Player.Name .. " | Server Players: " .. #DetectPlayersInServer() .. " detected\nLight Mode: ENABLED - Clean & Simple Interface\nStatus: Ready to start automation"
InfoLabel.TextColor3 = Color3.fromRGB(40, 40, 40)
InfoLabel.TextSize = 12
InfoLabel.TextXAlignment = Enum.TextXAlignment.Left
InfoLabel.TextYAlignment = Enum.TextYAlignment.Top

local InfoCorner = Instance.new("UICorner")
InfoCorner.CornerRadius = UDim.new(0, 6)
InfoCorner.Parent = InfoLabel

-- Button Functions
function UpdateConfig()
    if AmountBox then
        Config.AMOUNT = tonumber(AmountBox.Text) or Config.AMOUNT
        Config.MIN_AGE = tonumber(MinAgeBox.Text) or Config.MIN_AGE
        Config.MAX_AGE = tonumber(MaxAgeBox.Text) or Config.MAX_AGE
        Config.EXTRA_PET_SLOT = tonumber(PetSlotBox.Text) or Config.EXTRA_PET_SLOT
        Config.EXTRA_EGG_SLOT = tonumber(EggSlotBox.Text) or Config.EXTRA_EGG_SLOT
        Config.TRADE_AMOUNT = tonumber(TradeAmountBox.Text) or Config.TRADE_AMOUNT
    end
    
    local serverCount = #DetectPlayersInServer()
    local petCount = CountPetsAge60Plus()
    local slots = ListSlots()
    
    if InfoLabel then
        InfoLabel.Text = "Player: " .. Player.Name .. " | Server Players: " .. serverCount .. " detected\nLight Mode: ENABLED - Clean & Simple Interface\nStatus: " .. (isRunning and "Running automation" or "Ready to start automation")
    end
    
    if PetCountLabel then
        PetCountLabel.Text = "Pets 60+: " .. petCount .. " | Pet Slots: " .. slots.PurchasedEquipSlots .. "/" .. Config.EXTRA_PET_SLOT .. " | Egg Slots: " .. slots.PurchasedEggSlots .. "/" .. Config.EXTRA_EGG_SLOT
    end
end

function StartScript()
    if isRunning then return end
    isRunning = true
    UpdateConfig()
    StatusLabel.Text = "RUNNING"
    StatusLabel.TextColor3 = Color3.fromRGB(76, 175, 80)
    PrintDebug("MK Hub Light Started!")
    
    spawn(function()
        -- Auto Accept Gift
        if GiftPetRemote then
            pcall(function()
                ReplicatedStorage.GameEvents.GiftPet.OnClientEvent:Connect(function(uuid, petInfo, gifter)
                    PrintDebug(string.format('Accepting %s From %s...', petInfo, gifter))
                    ReplicatedStorage.GameEvents.AcceptPetGift:FireServer(true, uuid)
                end)
            end)
        end
        
        -- Auto Accept Trade
        if Config.AUTO_ACCEPT_TRADE and TradeService then
            pcall(function()
                local tradeRequest = ReplicatedStorage.GameEvents:FindFirstChild("TradeRequest")
                if tradeRequest then
                    tradeRequest.OnClientEvent:Connect(function(trader)
                        PrintDebug('Auto accepting trade from: ' .. trader.Name)
                        pcall(function()
                            TradeService:FireServer("AcceptRequest", trader)
                            task.wait(0.2)
                            
                            local petsAdded = AddPetsToTrade()
                            task.wait(0.3)
                            
                            TradeService:FireServer("AcceptTrade")
                            PrintDebug('Auto accepted trade with ' .. petsAdded .. ' pets')
                        end)
                    end)
                end
            end)
        end
        
        -- Trade Status Monitor
        if TradeService then
            pcall(function()
                local tradeCompleted = ReplicatedStorage.GameEvents:FindFirstChild("TradeCompleted")
                if tradeCompleted then
                    tradeCompleted.OnClientEvent:Connect(function(success, trader)
                        if success and trader then
                            tradeAccepted[trader.Name] = true
                            pendingTrades[trader.Name] = nil
                            PrintDebug('Trade completed with: ' .. trader.Name)
                        end
                    end)
                end
            end)
        end
        
        -- Auto Trade with Server Players
        spawn(function()
            task.wait(3)
            
            while isRunning do
                if Config.AUTO_TRADE then
                    local serverPlayers = DetectPlayersInServer()
                    PrintDebug('Found ' .. #serverPlayers .. ' players in server')
                    
                    if #serverPlayers > 0 then
                        local petCount = CountPetsAge60Plus()
                        PrintDebug('Available pets age 60+: ' .. petCount)
                        
                        if petCount > 0 then
                            for _, targetPlayer in ipairs(serverPlayers) do
                                local playerName = targetPlayer.Name
                                local canTrade = not table.find(tradeQueue, playerName) and 
                                               not pendingTrades[playerName] and 
                                               (not tradeAccepted[playerName] or tradeAccepted[playerName] == true)
                                               
                                if canTrade and isRunning then
                                    table.insert(tradeQueue, playerName)
                                    pendingTrades[playerName] = true
                                    tradeAccepted[playerName] = false
                                    PrintDebug('Added to gift queue: ' .. playerName)
                                    
                                    task.wait(0.5)
                                    StartTradeWithPlayer(targetPlayer)
                                    
                                    -- Wait for trade completion or timeout
                                    local timeout = 0
                                    while pendingTrades[playerName] and timeout < 30 and isRunning do
                                        task.wait(1)
                                        timeout = timeout + 1
                                    end
                                    
                                    if timeout >= 30 then
                                        PrintDebug('Trade timeout with: ' .. playerName)
                                        pendingTrades[playerName] = nil
                                    end
                                    
                                    task.wait(2)
                                end
                            end
                        else
                            PrintDebug('No suitable pets to gift')
                        end
                    else
                        PrintDebug('No other players found in server')
                    end
                end
                task.wait(8)
            end
        end)

        -- Instant Upgrade on Start
        spawn(function()
            task.wait(1)
            if Config.AUTO_UPGRADE_PET_SLOT then
                UpgradePetSlot()
            end
            if Config.AUTO_UPGRADE_EGG_SLOT then
                UpgradeEggSlot()
            end
        end)
        
        -- Main Loop
        while isRunning do
            pcall(function()
                local petCount = CountPetsAge60Plus()
                if petCount > 0 then
                    if Config.AUTO_UPGRADE_PET_SLOT then
                        UpgradePetSlot()
                    end
                    if Config.AUTO_UPGRADE_EGG_SLOT then
                        UpgradeEggSlot()
                    end
                end
                UpdateConfig()
            end)
            task.wait(1)
        end
    end)
end

function StopScript()
    isRunning = false
    tradeQueue = {}
    pendingTrades = {}
    tradeAccepted = {}
    StatusLabel.Text = "STOPPED"
    StatusLabel.TextColor3 = Color3.fromRGB(244, 67, 54)
    PrintDebug("MK Hub Stopped!")
end

-- Button Events
StartButton.MouseButton1Click:Connect(StartScript)
StopButton.MouseButton1Click:Connect(StopScript)
-- Players List Functions
function UpdatePlayersList()
    for _, child in PlayersFrame:GetChildren() do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    local players = DetectPlayersInServer()
    for i, player in ipairs(players) do
        local playerButton = Instance.new("TextButton")
        playerButton.Name = player.Name
        playerButton.Parent = PlayersFrame
        playerButton.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
        playerButton.BorderSizePixel = 1
        playerButton.BorderColor3 = Color3.fromRGB(200, 200, 200)
        playerButton.Size = UDim2.new(1, -12, 0, 28)
        playerButton.Font = Enum.Font.GothamBold
        playerButton.Text = player.Name
        playerButton.TextColor3 = Color3.fromRGB(50, 50, 50)
        playerButton.TextSize = 12
        playerButton.LayoutOrder = i
        
        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 4)
        buttonCorner.Parent = playerButton
        
        playerButton.MouseButton1Click:Connect(function()
            StartTradeWithPlayer(player)
            PlayersFrame.Visible = false
            ConfigFrame.Visible = true
        end)
        
        playerButton.MouseEnter:Connect(function()
            playerButton.BackgroundColor3 = Color3.fromRGB(33, 150, 243)
            playerButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        end)
        
        playerButton.MouseLeave:Connect(function()
            playerButton.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
            playerButton.TextColor3 = Color3.fromRGB(50, 50, 50)
        end)
    end
    
    PlayersFrame.CanvasSize = UDim2.new(0, 0, 0, #players * 30)
end

-- Players Button Click
PlayersButton.MouseButton1Click:Connect(function()
    if PlayersFrame.Visible then
        PlayersFrame.Visible = false
        ConfigFrame.Visible = true
        PlayersButton.Text = "PLAYERS"
    else
        UpdatePlayersList()
        PlayersFrame.Visible = true
        ConfigFrame.Visible = false
        PlayersButton.Text = "CONFIG"
    end
end)

-- Hide/Show functionality
HideButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

CloseButton.MouseButton1Click:Connect(function()
    StopScript()
    ScreenGui:Destroy()
end)

-- Keyboard shortcut to toggle visibility
game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.Insert then
        MainFrame.Visible = not MainFrame.Visible
    end
end)

TradeToggle.MouseButton1Click:Connect(function()
    Config.AUTO_TRADE = not Config.AUTO_TRADE
    TradeToggle.BackgroundColor3 = Config.AUTO_TRADE and Color3.fromRGB(33, 150, 243) or Color3.fromRGB(158, 158, 158)
    TradeToggle.Text = Config.AUTO_TRADE and "TRADE ON" or "TRADE OFF"
    UpdateConfig()
end)

PetSlotToggle.MouseButton1Click:Connect(function()
    Config.AUTO_UPGRADE_PET_SLOT = not Config.AUTO_UPGRADE_PET_SLOT
    PetSlotToggle.BackgroundColor3 = Config.AUTO_UPGRADE_PET_SLOT and Color3.fromRGB(76, 175, 80) or Color3.fromRGB(158, 158, 158)
    PetSlotToggle.Text = Config.AUTO_UPGRADE_PET_SLOT and "PET ON" or "PET OFF"
    UpdateConfig()
end)

EggSlotToggle.MouseButton1Click:Connect(function()
    Config.AUTO_UPGRADE_EGG_SLOT = not Config.AUTO_UPGRADE_EGG_SLOT
    EggSlotToggle.BackgroundColor3 = Config.AUTO_UPGRADE_EGG_SLOT and Color3.fromRGB(76, 175, 80) or Color3.fromRGB(158, 158, 158)
    EggSlotToggle.Text = Config.AUTO_UPGRADE_EGG_SLOT and "EGG ON" or "EGG OFF"
    UpdateConfig()
end)

-- Input validation
AmountBox.FocusLost:Connect(function()
    local num = tonumber(AmountBox.Text)
    if not num or num < 1 or num > 50 then
        AmountBox.Text = tostring(Config.AMOUNT)
    end
end)

MinAgeBox.FocusLost:Connect(function()
    local num = tonumber(MinAgeBox.Text)
    if not num or num < 1 or num > 100 then
        MinAgeBox.Text = tostring(Config.MIN_AGE)
    end
end)

MaxAgeBox.FocusLost:Connect(function()
    local num = tonumber(MaxAgeBox.Text)
    if not num or num < 1 or num > 100 then
        MaxAgeBox.Text = tostring(Config.MAX_AGE)
    end
end)

PetSlotBox.FocusLost:Connect(function()
    local num = tonumber(PetSlotBox.Text)
    if not num or num < 1 or num > 20 then
        PetSlotBox.Text = tostring(Config.EXTRA_PET_SLOT)
    end
end)

EggSlotBox.FocusLost:Connect(function()
    local num = tonumber(EggSlotBox.Text)
    if not num or num < 1 or num > 20 then
        EggSlotBox.Text = tostring(Config.EXTRA_EGG_SLOT)
    end
end)

TradeAmountBox.FocusLost:Connect(function()
    local num = tonumber(TradeAmountBox.Text)
    if not num or num < 1 or num > 20 then
        TradeAmountBox.Text = tostring(Config.TRADE_AMOUNT)
    end
end)

PrintDebug("MK Hub Light Edition loaded successfully!")
