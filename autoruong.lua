local LocalPlayer = game:GetService("Players").LocalPlayer
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local Locations = workspace:FindFirstChild("_WorldOrigin") and workspace._WorldOrigin:FindFirstChild("Locations")

-- =======================================================
-- 1. NHẬN DIỆN SEA CHUẨN (FIXED)
-- =======================================================
local PlaceId = game.PlaceId
local MaxChests = 40 

-- Kiểm tra ID chính xác cho từng Sea
if PlaceId == 7449423635 then
    MaxChests = 80 -- Sea 3
elseif PlaceId == 4442272183 then
    MaxChests = 60 -- Sea 2
elseif PlaceId == 2753915549 then
    MaxChests = 40 -- Sea 1
end

local ChestsCollected = 0
local CollectedRecords = {}
local IsHopping = false

-- =======================================================
-- 2. GUI ZERO MANAGER (MÀU VÀNG & XANH)
-- =======================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ZeroManagerGUI"
ScreenGui.Parent = (gethui and gethui()) or CoreGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 300, 0, 100)
MainFrame.Position = UDim2.new(0.5, -150, 0, 20)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MainFrame.BorderSizePixel = 2
MainFrame.BorderColor3 = Color3.fromRGB(255, 255, 0)
MainFrame.Parent = ScreenGui

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, 0, 0.5, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "Zero Manager"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 28
TitleLabel.Parent = MainFrame

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, 0, 0.5, 0)
StatusLabel.Position = UDim2.new(0, 0, 0.5, 0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Status: 0 / " .. MaxChests
StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
StatusLabel.Font = Enum.Font.GothamSemibold
StatusLabel.TextSize = 20
StatusLabel.Parent = MainFrame

-- =======================================================
-- 3. HÀM HOP SERVER (TÌM SERVER TRỐNG)
-- =======================================================
local function HopServer()
    if IsHopping then return end
    IsHopping = true
    StatusLabel.Text = "Status: hop sever"
    StatusLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
    
    task.spawn(function()
        while task.wait(2) do
            pcall(function()
                local url = "https://games.roblox.com/v1/games/" .. tostring(PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100"
                local result = game:HttpGet(url)
                local data = HttpService:JSONDecode(result)
                if data and data.data then
                    for _, server in pairs(data.data) do
                        if server.id ~= game.JobId and server.playing < (server.maxPlayers - 1) then
                            TeleportService:TeleportToPlaceInstance(PlaceId, server.id, LocalPlayer)
                        end
                    end
                end
            end)
        end
    end)
end

-- =======================================================
-- 4. GIỮ NGUYÊN LOGIC GỐC CỦA BẠN
-- =======================================================
local function getCharacter()
    if not LocalPlayer.Character then
        LocalPlayer.CharacterAdded:Wait()
    end
    LocalPlayer.Character:WaitForChild("HumanoidRootPart")
    return LocalPlayer.Character
end

local function DistanceFromPlrSort(ObjectList: table)
    local RootPart = getCharacter().LowerTorso
    table.sort(ObjectList, function(ChestA, ChestB)
        local RootPos = RootPart.Position
        local DistanceA = (RootPos - ChestA.Position).Magnitude
        local DistanceB = (RootPos - ChestB.Position).Magnitude
        return DistanceA < DistanceB
    end)
end

local UncheckedChests, FirstRun = {}, true
local function getChestsSorted()
    if FirstRun then
        FirstRun = false
        for _, Object in pairs(game:GetDescendants()) do
            if Object.Name:find("Chest") and Object.ClassName == "Part" then
                table.insert(UncheckedChests, Object)
            end
        end
    end
    local Chests = {}
    for _, Chest in pairs(UncheckedChests) do
        if Chest:FindFirstChild("TouchInterest") then
            table.insert(Chests, Chest)
        end
    end
    DistanceFromPlrSort(Chests)
    return Chests
end

local function toggleNoclip(Toggle: boolean)
    for _, v in pairs(getCharacter():GetChildren()) do
        if v:IsA("BasePart") then
            v.CanCollide = not Toggle
        end
    end
end

local function Teleport(Goal: CFrame)
    local RootPart = getCharacter().HumanoidRootPart
    toggleNoclip(true)
    RootPart.CFrame = Goal + Vector3.new(0, 3, 0)
    toggleNoclip(false)
end

local function startFarm()
    task.spawn(function()
        while task.wait() do
            if IsHopping then return end
            
            local Chests = getChestsSorted()
            if #Chests > 0 then
                local currentChest = Chests[1]
                
                -- LOGIC ĐẾM TỨC THÌ: Đánh dấu rương ngay khi chuẩn bị Teleport tới
                if not CollectedRecords[currentChest] then
                    CollectedRecords[currentChest] = true
                    ChestsCollected = ChestsCollected + 1
                    StatusLabel.Text = "Status: " .. ChestsCollected .. " / " .. MaxChests
                    
                    if ChestsCollected >= MaxChests then
                        HopServer()
                        break
                    end
                end

                Teleport(currentChest.CFrame)
                task.wait(0.05) -- Tốc độ nhặt cực nhanh
            else
                HopServer()
                break
            end
        end
    end)
end

-- Team Marines Auto
task.spawn(function()
    local rs = game:GetService("ReplicatedStorage")
    while task.wait(5) do
        pcall(function()
            rs.Remotes.CommF_:InvokeServer("SetTeam","Marines")
        end)
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1) 
    startFarm()
end)

startFarm()
