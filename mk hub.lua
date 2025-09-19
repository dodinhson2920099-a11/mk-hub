print('Exec')
repeat task.wait() until game:IsLoaded()
repeat task.wait() until game.Players.LocalPlayer.Character
repeat task.wait()
until game.Players.LocalPlayer:GetAttribute("DataFullyLoaded") and game.Players.LocalPlayer:GetAttribute("Finished_Loading")

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

local ReplicatedStorage: ReplicatedStorage = Services.ReplicatedStorage
local Http: HttpService = Services.HttpService
local Players: Players = Services.Players
local Player = Players.LocalPlayer

local FavoriteRemote: RemoteEvent = ReplicatedStorage.GameEvents.Favorite_Item
local PetsService: RemoteEvent = ReplicatedStorage.GameEvents.PetsService
local SellPet_RE: RemoteEvent = ReplicatedStorage.GameEvents.SellPet_RE
local PetEggService: RemoteEvent = ReplicatedStorage.GameEvents.PetEggService

local PetList = require(ReplicatedStorage.Data.PetRegistry).PetList
local DataService = require(ReplicatedStorage.Modules.DataService):GetData()
local PetsData = DataService.PetsData
local PetMutationMachine = DataService.PetMutationMachine
local TypeEnums = require(ReplicatedStorage.Data.EnumRegistry.ItemTypeEnums)
local InventoryEnums = require(ReplicatedStorage.Data.EnumRegistry.InventoryServiceEnums)
local PetMutationEnums = require(ReplicatedStorage.Data.PetRegistry.PetMutationRegistry).EnumToPetMutation

-- Force config override
getgenv().Config = {
    PLACE_EGGS = {"Common Egg"},
    EQUIP_PETS = {["Ostrich"] = 8},
    LOCK_PET_AGE = 60
}

local Config = getgenv().Config

-- Cooldown tracking
local lastEquipTime = 0
local EQUIP_COOLDOWN = 5 -- 5 seconds cooldown

-- Stats tracking
local Stats = {
    EggsPlaced = 0,
    PetsEquipped = 0,
    PetsLocked = 0,
    PetsSold = 0,
    SoldPets = {} -- Track sold pets by name
}

-- Create GUI
local ScreenGui = Instance.new("ScreenGui")
local BlackOverlay = Instance.new("Frame")
local MainFrame = Instance.new("Frame")
local Title = Instance.new("TextLabel")
local StatsFrame = Instance.new("Frame")

ScreenGui.Name = "PetAgeHub"
ScreenGui.Parent = Player.PlayerGui
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true

-- Clean Blue Background
BlackOverlay.Name = "Background"
BlackOverlay.Parent = ScreenGui
BlackOverlay.BackgroundColor3 = Color3.fromRGB(240, 248, 255)
BlackOverlay.BackgroundTransparency = 0
BlackOverlay.BorderSizePixel = 0
BlackOverlay.Position = UDim2.new(0, 0, 0, 0)
BlackOverlay.Size = UDim2.new(1, 0, 1, 0)
BlackOverlay.ZIndex = 1

-- Main Frame (Responsive)
MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundTransparency = 1
MainFrame.BorderSizePixel = 0
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.Size = UDim2.new(0.8, 0, 0.6, 0)
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.ZIndex = 10

-- Title (Responsive)
Title.Name = "Title"
Title.Parent = MainFrame
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0, 0, 0, 0)
Title.Size = UDim2.new(1, 0, 0.15, 0)
Title.Font = Enum.Font.GothamBold
Title.Text = "MK HUB"
Title.TextColor3 = Color3.fromRGB(0, 0, 0)
Title.TextScaled = true
Title.TextXAlignment = Enum.TextXAlignment.Center
Title.ZIndex = 11

-- Stats Frame (Responsive)
StatsFrame.Name = "StatsFrame"
StatsFrame.Parent = MainFrame
StatsFrame.BackgroundTransparency = 1
StatsFrame.Position = UDim2.new(0, 0, 0.2, 0)
StatsFrame.Size = UDim2.new(1, 0, 0.8, 0)
StatsFrame.ZIndex = 11

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0.03, 0)
layout.Parent = StatsFrame

-- Create responsive text labels
local function createStatLabel(name, text, order)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.Parent = StatsFrame
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 0.16, 0)
    label.LayoutOrder = order
    label.Font = Enum.Font.GothamBold
    label.Text = text
    label.TextColor3 = Color3.fromRGB(0, 0, 0)
    label.TextScaled = true
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.ZIndex = 11
    
    -- Add text size constraints
    local textSizeConstraint = Instance.new("UITextSizeConstraint")
    textSizeConstraint.MaxTextSize = 32
    textSizeConstraint.MinTextSize = 16
    textSizeConstraint.Parent = label
    
    return label
end

local EggLabel = createStatLabel("EggLabel", "🥚 EGGS: 0", 1)
local PetLabel = createStatLabel("PetLabel", "🐕 EQUIPPED: 0", 2)
local LockLabel = createStatLabel("LockLabel", "🔒 LOCKED: 0", 3)
local Age60Label = createStatLabel("Age60Label", "🔥 AGE 60+: 0", 4)
local Age75Label = createStatLabel("Age75Label", "⭐ AGE 75+: 0", 5)
local SellLabel = createStatLabel("SellLabel", "💰 SOLD: 0", 6)

local module = {}

-- Update function
local function updateStats()
    local placedEggs = module.GetPlacedEggs and module.GetPlacedEggs() or {}
    local lockedPets = module.GetLockedPets and module.GetLockedPets() or {}
    
    -- Format placed eggs display
    local eggText = "🥚 EGGS PLACED: "
    local totalEggs = 0
    local eggDetails = {}
    
    for eggName, count in pairs(placedEggs) do
        totalEggs = totalEggs + count
        table.insert(eggDetails, eggName .. "(" .. count .. ")")
    end
    
    if #eggDetails > 0 then
        eggText = eggText .. totalEggs .. " [" .. table.concat(eggDetails, ", ") .. "]"
    else
        eggText = eggText .. "0"
    end
    
    -- Format locked pets display
    local totalLocked = 0
    
    for petName, count in pairs(lockedPets) do
        totalLocked = totalLocked + count
    end
    
    -- Get real-time equipped pets
    local equippedPets = module.PetEquippedData and module.PetEquippedData() or {}
    local equippedCount = #equippedPets
    local equippedDetails = {}
    local equippedByName = {}
    
    for _, petData in pairs(equippedPets) do
        equippedByName[petData.Name] = (equippedByName[petData.Name] or 0) + 1
    end
    
    for petName, count in pairs(equippedByName) do
        table.insert(equippedDetails, petName .. "(" .. count .. ")")
    end
    
    EggLabel.Text = "🥚 EGGS: " .. (totalEggs > 0 and totalEggs .. " [" .. table.concat(eggDetails, ", ") .. "]" or "0")
    PetLabel.Text = "🐕 EQUIPPED: " .. (equippedCount > 0 and equippedCount .. " [" .. table.concat(equippedDetails, ", ") .. "]" or "0")
    LockLabel.Text = "🔒 LOCKED: " .. totalLocked
    -- Format sold pets display
    local soldDetails = {}
    local totalSold = 0
    
    for petName, count in pairs(Stats.SoldPets) do
        totalSold = totalSold + count
        table.insert(soldDetails, petName .. "(" .. count .. ")")
    end
    
    SellLabel.Text = "💰 SOLD: " .. (totalSold > 0 and totalSold .. " [" .. table.concat(soldDetails, ", ") .. "]" or "0")
    
    -- Get pets by age
    local age60Pets = module.GetPetsByAge and module.GetPetsByAge(60) or {}
    local age75Pets = module.GetPetsByAge and module.GetPetsByAge(75) or {}
    
    -- Format age 60+ pets display
    local total60 = 0
    
    for petName, count in pairs(age60Pets) do
        total60 = total60 + count
    end
    
    -- Format age 75+ pets display
    local total75 = 0
    
    for petName, count in pairs(age75Pets) do
        total75 = total75 + count
    end
    
    Age60Label.Text = "🔥 AGE 60+: " .. total60
    Age75Label.Text = "⭐ AGE 75+: " .. total75
end

function module.PrintDebug(...)
    print(string.format('[DEBUG] %s', tostring(...)))
end

function module.UnEquip()
    Player.Character.Humanoid:UnequipTools()
end

function module.CountVarbTable(table)
    local count = 0
    if table then
        for i, v in table do
            count = count + 1
        end
    end
    return count
end

function module.PetData(PET_UUID)
    local PetData = PetsData.PetInventory.Data[PET_UUID]
    if PetData and PetData.PetData then
        local PetInfo = PetList[PetData.PetType]
        return {
            ["Name"] = PetData.PetType,
            ["DisplayName"] = PetData.PetData.Name,
            ["UUID"] = PET_UUID,
            ["EggType"] = PetData.PetData.HatchedFrom,
            ["Rarity"] = PetInfo and PetInfo.Rarity or "Unknown",
            ["AssetId"] = PetInfo and PetInfo.Icon or 0,
            ["Weight"] = PetData.PetData.BaseWeight or 0,
            ["Age"] = PetData.PetData.Level or 0,
            ["AgeProgress"] = PetData.PetData.LevelProgress or 0,
            ["Mutation"] = PetData.PetData.MutationType and PetMutationEnums[PetData.PetData.MutationType] or nil,
            ["Hunger"] = PetData.PetData.Hunger or 0,
            ["Boosts"] = PetData.PetData.Boosts or {},
            ["Ability"] = PetData.PetAbility,
            ["Equipped"] = table.find(PetsData.EquippedPets, PET_UUID) and true or false
        }
    end
    return nil
end

function module.ListPets()
    local listPet = {}
    for i, pet in Player.Backpack:GetChildren() do
        if pet:GetAttribute('PET_UUID') then
            table.insert(listPet, pet)
        end
    end
    return listPet
end

function module.PetEquippedData()
    local listPet = {}
    for i, v in PetsData.EquippedPets do
        local petData = module.PetData(v)
        if petData then
            table.insert(listPet, petData)
        end
    end
    return listPet
end

function module.FindPetEquipped(petName)
    local listPet = {}
    for i, petData in module.PetEquippedData() do
        if petData.Name == petName then
            table.insert(listPet, petData)
        end
    end
    return listPet
end

function module.ListSlots()
    local dataSlot = PetsData.MutableStats
    return {
        ["PetSlots"] = dataSlot.MaxPetsInInventory,
        ["PetEquippedSlots"] = dataSlot.MaxEquippedPets,
        ["EggSlots"] = dataSlot.MaxEggsInFarm,
        ["PurchasedPetSlots"] = PetsData.PurchasedPetInventorySlots,
        ["PurchasedEquipSlots"] = PetsData.PurchasedEquipSlots,
        ["PurchasedEggSlots"] = PetsData.PurchasedEggSlots
    }
end

function module.GetLockedPets()
    local lockedPets = {}
    for uuid, petData in PetsData.PetInventory.Data do
        for i, pet in Player.Backpack:GetChildren() do
            if pet:GetAttribute('PET_UUID') == uuid and pet:GetAttribute(InventoryEnums['Favorite']) then
                local petInfo = module.PetData(uuid)
                if petInfo then
                    lockedPets[petInfo.Name] = (lockedPets[petInfo.Name] or 0) + 1
                end
            end
        end
    end
    return lockedPets
end

function module.GetPetsByAge(minAge)
    local agePets = {}
    for uuid, petData in PetsData.PetInventory.Data do
        for i, pet in Player.Backpack:GetChildren() do
            if pet:GetAttribute('PET_UUID') == uuid then
                local petInfo = module.PetData(uuid)
                if petInfo and petInfo.Age >= minAge then
                    agePets[petInfo.Name] = (agePets[petInfo.Name] or 0) + 1
                end
            end
        end
    end
    return agePets
end

function module.GetPlacedEggs()
    local placedEggs = {}
    local success, result = pcall(function()
        local garden = currentGarden
        if not garden then
            for i, farm in workspace.Farm:GetChildren() do
                if farm.Important and farm.Important.Data and farm.Important.Data.Owner and farm.Important.Data.Owner.Value == Player.Name then
                    garden = farm
                    break
                end
            end
        end
        
        if garden and garden.Important and garden.Important.Objects_Physical then
            for i, v in garden.Important.Objects_Physical:GetChildren() do
                if v.Name == 'PetEgg' then
                    local eggName = v:GetAttribute('EggName') or "Unknown"
                    placedEggs[eggName] = (placedEggs[eggName] or 0) + 1
                end
            end
        end
    end)
    return placedEggs
end

function module.SellPet(petData)
    module.PrintDebug('Selling Pet: ' .. petData['Name'] .. ' [' .. petData['UUID'] .. ']')
    Stats.PetsSold = Stats.PetsSold + 1
    Stats.SoldPets[petData.Name] = (Stats.SoldPets[petData.Name] or 0) + 1
    updateStats()
    SellPet_RE:FireServer()
end

function module.LockPet(instance, petData)
    if not instance:GetAttribute(InventoryEnums['Favorite']) then
        module.PrintDebug(string.format('Lock [Favorite] Pet: %s', petData.Name))
        FavoriteRemote:FireServer(instance)
    end
end

function module.UnLockPet(instance, petData)
    if instance:GetAttribute(InventoryEnums['Favorite']) then
        module.PrintDebug(string.format('Detect Pet Locked -> UnLocking...: %s', petData.Name))
        FavoriteRemote:FireServer(instance)
    end
end

function module.EquipPet(petData)
    module.PrintDebug('Equip Pet: ' .. petData['Name'] .. ' [' .. petData['UUID'] .. ']')
    PetsService:FireServer("EquipPet", petData['UUID'], CFrame.new())
end

function module.UnEquipPet(petData)
    module.PrintDebug('UnEquip Pet: ' .. petData['Name'] .. ' [' .. petData['UUID'] .. ']')
    PetsService:FireServer("UnequipPet", petData['UUID'])
end

function module.BuyEggShop()
    for i, v in DataService.PetEggStock.Stocks do
        if v.Stock > 0 then
            if table.find({"Rainbow Lollipop", "Pet Name Reroller", "Pet Lead"}, v.EggName) then
                continue
            end
                
            if true then
                local count = 0
                module.PrintDebug(string.format('Buying %s...', v.EggName))
                repeat task.wait(0.1)
                    ReplicatedStorage.GameEvents.BuyPetEgg:FireServer(v.EggName)
                    count = count + 1
                until v.Stock == 0 or count >= 3
            end
        end
    end
end

local currentGarden, posSpawn, posLeft, posRight, posUnknown
for i, farm in workspace.Farm:GetChildren() do
    if farm.Important.Data.Owner.Value == Player.Name then
        currentGarden = farm
        posSpawn = farm.Spawn_Point.CFrame * CFrame.new(0, -2, 0)
        for i, v in farm.Important.Plant_Locations:GetChildren() do
            if v:GetAttribute('Side') == 'Left' then
                posLeft = v.Position
            elseif v:GetAttribute('Side') == 'Right' then
                posRight = v.Position
            else
                posUnknown = v.Position
            end
        end

        if posUnknown then
            if posLeft then
                posRight = posUnknown
            elseif posRight then
                posLeft = posUnknown
            end
        end
    else
        farm:Destroy()
    end
end

if not currentGarden or not posSpawn or not posLeft or not posRight then
    game:Shutdown()
end

function module.CountEgg()
    local count = 0
    for i, v in currentGarden.Important.Objects_Physical:GetChildren() do
        if v.Name == 'PetEgg' then
            count = count + 1
        end
    end
    return count
end

-- Check and sell pets immediately
function module.CheckAndSellPets()
    local listPet = module.ListPets()
    for i, pet in listPet do
        local petData = module.PetData(pet:GetAttribute('PET_UUID'))
        if petData and petData.Age and Config.LOCK_PET_AGE then
            local isLocked = pet:GetAttribute(InventoryEnums['Favorite'])
            
            -- Only sell pets that are:
            -- 1. Under 60 age (newly hatched)
            -- 2. Weight under 10kg (not valuable pets)
            -- 3. Not locked
            if petData.Age < Config.LOCK_PET_AGE and petData.Weight < 10 and not isLocked then
                module.UnLockPet(pet, petData)
                module.UnEquip()
                pet.Parent = Player.Character
                module.SellPet(petData)
                task.wait(0.05)
            end
        end
    end
end

-- Check and place eggs immediately
function module.CheckAndPlaceEggs()
    if Config.PLACE_EGGS and module.CountEgg() < module.ListSlots().EggSlots then
        for i, eggName in Config.PLACE_EGGS do
            if module.CountEgg() >= module.ListSlots().EggSlots then
                break
            end
            
            module.UnEquip()
            for i, v in Player.Backpack:GetChildren() do
                if string.find(v.Name, eggName) then
                    module.UnEquip()
                    v.Parent = Player.Character
                    task.wait()
                    local count = 0
                    while task.wait(0.05) do 
                        count = count + 1
                        if not v.Parent or module.CountEgg() >= module.ListSlots().EggSlots or count > 30 then
                            break
                        end

                        module.PrintDebug('Quick Place Egg: ' .. eggName)
                        PetEggService:FireServer("CreateEgg", posLeft + Vector3.new(math.random(-10, 10), 1, math.random(-10, 10)))
                    end
                    break
                end
            end
        end
    end
end

function module.HatchEgg()
    local hatched = false
    for i, v in currentGarden.Important.Objects_Physical:GetChildren() do
        local eggName = v:GetAttribute('EggName')
        if eggName and v:GetAttribute('TimeToHatch') == 0 then
            module.PrintDebug('Hatch Pet: ' .. eggName .. ' [' .. v:GetAttribute('OBJECT_UUID') .. ']')
            PetEggService:FireServer("HatchPet", v)
            hatched = true
        end
    end
    
    -- Place eggs and sell pets immediately after hatching
    if hatched then
        task.wait(0.1)
        module.CheckAndSellPets()
        module.CheckAndPlaceEggs()
    end
end

-- Real-time update loop
spawn(function()
    while task.wait(1) do
        updateStats()
    end
end)



while task.wait(1) do
    module.BuyEggShop()

    -- Check equip pets with cooldown
    local currentTime = tick()
    if Config.EQUIP_PETS and module.CountVarbTable(Config.EQUIP_PETS) > 0 and (currentTime - lastEquipTime) >= EQUIP_COOLDOWN then
        local currentEquipped = #PetsData.EquippedPets
        local maxSlots = module.ListSlots().PetEquippedSlots
        
        if currentEquipped < maxSlots then
            local needsEquip = false
            
            -- Check if we need to equip any pets
            for petName, maxCount in Config.EQUIP_PETS do
                local currentCount = #module.FindPetEquipped(petName)
                if currentCount < maxCount then
                    needsEquip = true
                    break
                end
            end
            
            if needsEquip then
                module.PrintDebug('Equipping pets... (' .. currentEquipped .. '/' .. maxSlots .. ')')
                
                for i, pet in module.ListPets() do
                    if #PetsData.EquippedPets >= maxSlots then
                        break
                    end

                    local petData = module.PetData(pet:GetAttribute('PET_UUID'))
                    if not petData or not Config.EQUIP_PETS[petData.Name] then
                        continue
                    end

                    local currentCount = #module.FindPetEquipped(petData.Name)
                    local maxCount = Config.EQUIP_PETS[petData.Name]
                    
                    if currentCount < maxCount then
                        module.EquipPet(petData)
                        task.wait(0.2)
                        break -- Only equip one pet per cycle
                    end
                end
                
                lastEquipTime = currentTime
            end
        end
    end

    module.HatchEgg()

    -- Use new methods for immediate actions
    module.CheckAndPlaceEggs()
    module.CheckAndSellPets()
    
    -- Lock pets that reach age requirement and sell unwanted pets
    local listPet = module.ListPets()
    for i, pet in listPet do
        local petData = module.PetData(pet:GetAttribute('PET_UUID'))
        if petData and petData.Age and Config.LOCK_PET_AGE and type(petData.Age) == "number" and type(Config.LOCK_PET_AGE) == "number" then
            local isLocked = pet:GetAttribute(InventoryEnums['Favorite'])
            
            if petData.Age >= Config.LOCK_PET_AGE then
                -- Lock pets that reach age requirement
                module.LockPet(pet, petData)
            elseif petData.Age < Config.LOCK_PET_AGE and petData.Weight < 10 and not isLocked then
                -- Sell pets that are newly hatched, low weight, and not locked
                module.UnLockPet(pet, petData)
                module.UnEquip()
                pet.Parent = Player.Character
                module.SellPet(petData)
                task.wait(0.05)
            end
        end
    end
end
