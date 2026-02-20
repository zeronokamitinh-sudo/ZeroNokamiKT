local LocalPlayer = game:GetService("Players").LocalPlayer
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- =======================================================
-- 1. CẤU HÌNH CỐ ĐỊNH (70 RƯƠNG CHO TẤT CẢ SEA)
-- =======================================================
local MaxChests = 70 
local ChestsCollected = 0
local CollectedRecords = {}
local IsHopping = false
local StopByItem = false 
local PlaceId = game.PlaceId

-- =======================================================
-- 2. GIAO DIỆN (GUI) - GIỮ NGUYÊN STYLE VÀNG
-- =======================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ZeroManagerGUI"
ScreenGui.Parent = (gethui and gethui()) or CoreGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 280, 0, 90)
MainFrame.Position = UDim2.new(0.5, -140, 0, 30)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
MainFrame.BorderSizePixel = 2
MainFrame.BorderColor3 = Color3.fromRGB(255, 255, 0)
MainFrame.Parent = ScreenGui

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, 0, 0.5, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "Zero Manager"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 26
TitleLabel.Parent = MainFrame

local SubLabel = Instance.new("TextLabel")
SubLabel.Size = UDim2.new(1, 0, 0.4, 0)
SubLabel.Position = UDim2.new(0, 0, 0.5, 0)
SubLabel.BackgroundTransparency = 1
SubLabel.Text = "Auto Collect Chest"
SubLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
SubLabel.Font = Enum.Font.GothamSemibold
SubLabel.TextSize = 18
SubLabel.Parent = MainFrame

-- =======================================================
-- 3. LOGIC KIỂM TRA VẬT PHẨM
-- =======================================================
local function OnItemAdded(item)
    if item:IsA("Tool") or item:IsA("SpecialItem") then
        local ignoreList = {"Combat", "Sword", "Gun", "Fruit"}
        for _, name in pairs(ignoreList) do
            if item.Name:find(name) then return end
        end
        StopByItem = true
        SubLabel.Text = "ITEM FOUND: " .. item.Name:upper()
        SubLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
    end
end
LocalPlayer.Backpack.ChildAdded:Connect(OnItemAdded)

-- =======================================================
-- 4. TỐI ƯU HÓA QUÉT RƯƠNG (FIX LỖI GIỰT)
-- =======================================================
local UncheckedChests = {}
local function InitialScan()
    -- Chỉ quét Workspace thay vì toàn bộ game để cực nhanh
    for _, Object in pairs(workspace:GetDescendants()) do
        if Object.Name:find("Chest") and Object:IsA("BasePart") then
            table.insert(UncheckedChests, Object)
        end
    end
end

-- Chạy quét ngay lập tức khi load script
InitialScan()

local function getChestsSorted()
    local Chests = {}
    for _, Chest in pairs(UncheckedChests) do
        if Chest and Chest:FindFirstChild("TouchInterest") then
            table.insert(Chests, Chest)
        end
    end
    
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("LowerTorso")
    if root then
        table.sort(Chests, function(a, b)
            return (root.Position - a.Position).Magnitude < (root.Position - b.Position).Magnitude
        end)
    end
    return Chests
end

-- =======================================================
-- 5. HÀM HỖ TRỢ
-- =======================================================
local function toggleNoclip(Toggle)
    local char = LocalPlayer.Character
    if not char then return end
    for _, v in pairs(char:GetChildren()) do
        if v:IsA("BasePart") then v.CanCollide = not Toggle end
    end
end

local function Teleport(Goal)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        toggleNoclip(true)
        hrp.CFrame = Goal + Vector3.new(0, 3, 0)
        task.delay(0.05, function() toggleNoclip(false) end)
    end
end

local function HopServer()
    if IsHopping or StopByItem then return end
    IsHopping = true
    SubLabel.Text = "Server Hopping..."
    pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. tostring(PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100"
        local data = HttpService:JSONDecode(game:HttpGet(url))
        for _, server in pairs(data.data) do
            if server.id ~= game.JobId and server.playing < (server.maxPlayers - 1) then
                TeleportService:TeleportToPlaceInstance(PlaceId, server.id, LocalPlayer)
                return
            end
        end
    end)
    task.wait(5)
    IsHopping = false
end

-- =======================================================
-- 6. VÒNG LẶP CHÍNH (CHẠY NGAY LẬP TỨC)
-- =======================================================
local function startFarm()
    task.spawn(function()
        -- Không task.wait() ở đây để bắt đầu ngay
        while not StopByItem do
            if IsHopping then break end
            
            local Chests = getChestsSorted()
            
            if #Chests > 0 then
                local currentChest = Chests[1]
                Teleport(currentChest.CFrame)
                
                -- Thời gian chờ tối ưu để nhặt
                task.wait(0.12) 
                
                if not currentChest:FindFirstChild("TouchInterest") then
                    if not CollectedRecords[currentChest] then
                        CollectedRecords[currentChest] = true
                        ChestsCollected = ChestsCollected + 1
                    end
                end

                if ChestsCollected >= MaxChests then
                    HopServer()
                    break
                end
            else
                task.wait(0.5) -- Đợi chút nếu rương chưa kịp xuất hiện trước khi hop
                HopServer()
                break
            end
            task.wait() -- Tránh treo máy
        end
    end)
end

-- =======================================================
-- 7. TỰ ĐỘNG CHỌN TEAM & KHỞI CHẠY
-- =======================================================
task.spawn(function()
    while task.wait(5) do
        if StopByItem then break end
        pcall(function()
            ReplicatedStorage.Remotes.CommF_:InvokeServer("SetTeam", "Marines")
        end)
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5) -- Giảm thời gian chờ xuống tối thiểu
    if not StopByItem then
        startFarm()
    end
end)

-- Bật Farm ngay lập tức khi thực thi script
startFarm()
