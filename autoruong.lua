local LocalPlayer = game:GetService("Players").LocalPlayer
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

-- =======================================================
-- 1. NHẬN DIỆN SEA CHUẨN (FIXED)
-- =======================================================
local PlaceId = game.PlaceId
local MaxChests = 40 

-- Kiểm tra chính xác ID để set MaxChests
if PlaceId == 7449423635 then
    MaxChests = 80 -- Sea 3
elseif PlaceId == 4442272183 then
    MaxChests = 60 -- Sea 2
elseif PlaceId == 2753915549 then
    MaxChests = 40 -- Sea 1
else
    MaxChests = 50 -- Mặc định nếu ID khác
end

local ChestsCollected = 0
local CollectedRecords = {}
local IsHopping = false
local FarmingConnection = nil

-- =======================================================
-- 2. GUI ZERO MANAGER
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
StatusLabel.Text = "Status: " .. ChestsCollected .. " / " .. MaxChests
StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
StatusLabel.Font = Enum.Font.GothamSemibold
StatusLabel.TextSize = 20
StatusLabel.Parent = MainFrame

-- =======================================================
-- 3. HÀM HỖ TRỢ & LOGIC GỐC
-- =======================================================
local function HopServer()
    if IsHopping then return end
    IsHopping = true
    StatusLabel.Text = "Status: Hopping..."
    StatusLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
    
    pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. tostring(PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100"
        local data = HttpService:JSONDecode(game:HttpGet(url))
        if data and data.data then
            for _, server in pairs(data.data) do
                if server.id ~= game.JobId and server.playing < (server.maxPlayers - 1) then
                    TeleportService:TeleportToPlaceInstance(PlaceId, server.id, LocalPlayer)
                    return
                end
            end
        end
    end)
    task.wait(5)
    IsHopping = false
end

local function getCharacter()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    char:WaitForChild("HumanoidRootPart", 5)
    char:WaitForChild("LowerTorso", 5)
    return char
end

local function DistanceFromPlrSort(ObjectList)
    local char = getCharacter()
    if not char:FindFirstChild("LowerTorso") then return end
    local RootPos = char.LowerTorso.Position
    
    table.sort(ObjectList, function(ChestA, ChestB)
        return (RootPos - ChestA.Position).Magnitude < (RootPos - ChestB.Position).Magnitude
    end)
end

local UncheckedChests, FirstRun = {}, true
local function getChestsSorted()
    if FirstRun then
        FirstRun = false
        for _, Object in pairs(game:GetDescendants()) do
            if Object.Name:find("Chest") and Object:IsA("BasePart") then
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
    
    pcall(function() DistanceFromPlrSort(Chests) end)
    return Chests
end

local function toggleNoclip(Toggle)
    local char = LocalPlayer.Character
    if not char then return end
    for _, v in pairs(char:GetChildren()) do
        if v:IsA("BasePart") then
            v.CanCollide = not Toggle
        end
    end
end

local function Teleport(Goal)
    local char = getCharacter()
    if char and char:FindFirstChild("HumanoidRootPart") then
        toggleNoclip(true)
        char.HumanoidRootPart.CFrame = Goal + Vector3.new(0, 3, 0)
        -- Tắt noclip sau một khoảng ngắn để tránh kẹt sàn
        task.delay(0.1, function() toggleNoclip(false) end)
    end
end

-- =======================================================
-- 4. VÒNG LẶP FARM CHÍNH
-- =======================================================
local function startFarm()
    -- Hủy loop cũ nếu có để tránh chạy đè khi reset
    if FarmingConnection then FarmingConnection = false end
    FarmingConnection = true
    
    task.spawn(function()
        while FarmingConnection and task.wait() do
            if IsHopping then break end
            
            local Chests = getChestsSorted()
            if #Chests > 0 then
                local currentChest = Chests[1]
                
                -- Logic đếm và cập nhật UI
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
                task.wait(0.08) -- Tốc độ nhặt
            else
                HopServer()
                break
            end
        end
    end)
end

-- =======================================================
-- 5. KHỞI CHẠY & TỰ ĐỘNG CHỌN TEAM
-- =======================================================
task.spawn(function()
    local rs = game:GetService("ReplicatedStorage")
    while task.wait(5) do
        pcall(function()
            rs.Remotes.CommF_:InvokeServer("SetTeam", "Marines")
        end)
    end
end)

-- Xử lý khi nhân vật Reset/Spawn lại
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    startFarm()
end)

-- Chạy lần đầu
startFarm()
