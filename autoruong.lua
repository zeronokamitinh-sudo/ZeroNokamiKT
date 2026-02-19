local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local Locations = workspace:FindFirstChild("_WorldOrigin") and workspace._WorldOrigin:FindFirstChild("Locations")

-- ==========================================
-- 1. XÁC ĐỊNH SỐ RƯỢNG THEO SEA (BLOX FRUITS)
-- ==========================================
local PlaceId = game.PlaceId
local MaxChests = 40 -- Mặc định Sea 1
if PlaceId == 4442272183 then
    MaxChests = 60 -- Sea 2
elseif PlaceId == 7449423635 then
    MaxChests = 80 -- Sea 3
end

local ChestsCollected = 0
local CollectedRecords = {}

-- ==========================================
-- 2. TẠO GIAO DIỆN (GUI)
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ZeroManagerGUI"
ScreenGui.ResetOnSpawn = false
-- Dùng gethui() nếu đang dùng executor hỗ trợ để chống phát hiện, nếu không thì để vào CoreGui
ScreenGui.Parent = (gethui and gethui()) or CoreGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 300, 0, 100)
MainFrame.Position = UDim2.new(0.5, -150, 0, 20)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MainFrame.BackgroundTransparency = 0.2
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = MainFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, 0, 0.5, 0)
TitleLabel.Position = UDim2.new(0, 0, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "Zero Manager"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 0) -- Màu Vàng
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextScaled = true
TitleLabel.Parent = MainFrame

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, 0, 0.5, 0)
StatusLabel.Position = UDim2.new(0, 0, 0.5, 0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Status: 0 / " .. MaxChests .. " rương đã nhặt"
StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 0) -- Màu Xanh Lá
StatusLabel.Font = Enum.Font.GothamSemibold
StatusLabel.TextSize = 20
StatusLabel.Parent = MainFrame

-- ==========================================
-- 3. LOGIC HOP SERVER
-- ==========================================
local function HopServer()
    StatusLabel.Text = "Status: Hop server..."
    StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100) -- Đổi màu để dễ chú ý
    
    local url = "https://games.roblox.com/v1/games/" .. tostring(PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100"
    
    local function ExecuteHop()
        local success, result = pcall(function()
            return game:HttpGet(url)
        end)
        
        if success then
            local data = HttpService:JSONDecode(result)
            if data and data.data then
                for _, server in pairs(data.data) do
                    -- Tìm server không phải server hiện tại và chưa full người
                    if type(server) == "table" and server.id ~= game.JobId and server.playing < server.maxPlayers then
                        pcall(function()
                            TeleportService:TeleportToPlaceInstance(PlaceId, server.id, LocalPlayer)
                        end)
                        task.wait(2) -- Đợi 2 giây xem có dịch chuyển thành công không
                    end
                end
            end
        end
    end

    -- Lặp lại việc tìm server cho đến khi thoát hẳn game
    task.spawn(function()
        while task.wait(5) do
            ExecuteHop()
        end
    end)
end

-- ==========================================
-- 4. LOGIC GỐC CỦA BẠN (Đã tích hợp đếm rương)
-- ==========================================
local function getCharacter()
    if not LocalPlayer.Character then
        LocalPlayer.CharacterAdded:Wait()
    end
    LocalPlayer.Character:WaitForChild("HumanoidRootPart")
    return LocalPlayer.Character
end

local function DistanceFromPlrSort(ObjectList)
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

local function toggleNoclip(Toggle)
    for _, v in pairs(getCharacter():GetChildren()) do
        if v:IsA("BasePart") then
            v.CanCollide = not Toggle
        end
    end
end

local function Teleport(Goal)
    local RootPart = getCharacter().HumanoidRootPart
    toggleNoclip(true)
    RootPart.CFrame = Goal + Vector3.new(0, 3, 0)
    toggleNoclip(false)
end

local isHopping = false

local function startFarm()
    task.spawn(function()
        while task.wait() do
            if isHopping then return end
            
            -- Kiểm tra xem đã đủ số lượng rương chưa
            if ChestsCollected >= MaxChests then
                isHopping = true
                HopServer()
                break
            end

            local Chests = getChestsSorted()
            if #Chests > 0 then
                local TargetChest = Chests[1]
                Teleport(TargetChest.CFrame)
                
                -- Xử lý đếm rương
                if TargetChest and TargetChest.Parent then
                    local dist = (getCharacter().HumanoidRootPart.Position - TargetChest.Position).Magnitude
                    if dist < 10 then -- Nếu đứng đủ gần rương
                        task.wait(0.1)
                        -- Nếu rương mất TouchInterest (đã bị nhặt) và chưa được lưu trong record
                        if not TargetChest:FindFirstChild("TouchInterest") and not CollectedRecords[TargetChest] then
                            CollectedRecords[TargetChest] = true
                            ChestsCollected = ChestsCollected + 1
                            StatusLabel.Text = "Status: " .. tostring(ChestsCollected) .. " / " .. tostring(MaxChests) .. " rương đã nhặt"
                        end
                    end
                end
            else
                -- Nếu trên map đã hết sạch rương mà chưa đạt target thì cũng Hop Server
                isHopping = true
                HopServer()
                break
            end
        end
    end)
end

-- Tự động vào team Marines (giữ nguyên logic của bạn)
task.spawn(function()
    local rs = game:GetService("ReplicatedStorage")
    while task.wait(5) do
        pcall(function()
            if rs:FindFirstChild("Remotes") and rs.Remotes:FindFirstChild("CommF_") then
                rs.Remotes.CommF_:InvokeServer("SetTeam","Marines")
            end
        end)
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1) 
    if not isHopping then
        startFarm()
    end
end)

-- Bắt đầu chạy
startFarm()
