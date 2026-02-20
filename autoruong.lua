local LocalPlayer = game:GetService("Players").LocalPlayer
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- =======================================================
-- 1. CẤU HÌNH (70 RƯƠNG)
-- =======================================================
local MaxChests = 70 
local ChestsCollected = 0
local CollectedRecords = {}
local IsHopping = false
local StopByItem = false 
local PlaceId = game.PlaceId

-- =======================================================
-- 2. GIAO DIỆN (GUI) - GIỮ STYLE VÀNG
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
-- 3. LOGIC RESET VÀ TEAM
-- =======================================================
local function ResetChar()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("Humanoid") then
        char.Humanoid.Health = 0
    end
end

task.spawn(function()
    while task.wait(3) do
        if StopByItem then break end
        pcall(function()
            if LocalPlayer.Team == nil then
                ReplicatedStorage.Remotes.CommF_:InvokeServer("SetTeam", "Marines")
            end
        end)
    end
end)

-- =======================================================
-- 4. LOGIC NHẶT RƯƠNG TỐC ĐỘ CAO
-- =======================================================
local function GetChests()
    local Chests = {}
    for _, v in pairs(workspace:GetChildren()) do
        if v.Name:find("Chest") and v:IsA("BasePart") and v:FindFirstChild("TouchInterest") then
            table.insert(Chests, v)
        end
    end
    -- Nếu workspace ít rương quá thì quét sâu hơn
    if #Chests < 1 then
        for _, v in pairs(workspace:GetDescendants()) do
            if v.Name:find("Chest") and v:IsA("BasePart") and v:FindFirstChild("TouchInterest") then
                table.insert(Chests, v)
            end
        end
    end
    
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("LowerTorso")
    if root then
        table.sort(Chests, function(a, b)
            return (root.Position - a.Position).Magnitude < (root.Position - b.Position).Magnitude
        end)
    end
    return Chests
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
    task.wait(2)
    IsHopping = false
end

-- =======================================================
-- 5. VÒNG LẶP CHÍNH (START NGAY LẬP TỨC)
-- =======================================================
local function startFarm()
    task.spawn(function()
        while not StopByItem do
            if IsHopping then break end
            
            local Chests = GetChests()
            
            if #Chests > 0 then
                for i = 1, #Chests do
                    if ChestsCollected >= MaxChests or IsHopping or StopByItem then break end
                    
                    local currentChest = Chests[i]
                    if currentChest and currentChest:FindFirstChild("TouchInterest") then
                        local char = LocalPlayer.Character
                        local hrp = char and char:FindFirstChild("HumanoidRootPart")
                        
                        if hrp then
                            -- Teleport cực nhanh
                            hrp.CFrame = currentChest.CFrame
                            
                            -- Giả lập chạm (Speed hack nhặt)
                            if firetouchinterest then
                                firetouchinterest(hrp, currentChest, 0)
                                firetouchinterest(hrp, currentChest, 1)
                            end
                            
                            task.wait(0.05) -- Tốc độ nhặt bàn thờ
                            
                            if not currentChest:FindFirstChild("TouchInterest") then
                                ChestsCollected = ChestsCollected + 1
                            end
                        end
                    end
                end
            else
                -- Không thấy rương thì reset nhân vật hoặc hop
                ResetChar()
                task.wait(1)
                HopServer()
                break
            end
            task.wait()
        end
    end)
end

-- =======================================================
-- 6. KIỂM TRA ITEM VÀ KHỞI CHẠY
-- =======================================================
LocalPlayer.Backpack.ChildAdded:Connect(function(item)
    if item:IsA("Tool") or item:IsA("SpecialItem") then
        local ignore = {"Combat", "Sword", "Gun", "Fruit"}
        local isRare = true
        for _, n in pairs(ignore) do if item.Name:find(n) then isRare = false end end
        
        if isRare then
            StopByItem = true
            SubLabel.Text = "ITEM FOUND: " .. item.Name:upper()
            SubLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
        end
    end
end)

-- Chạy ngay lập tức
if not StopByItem then
    startFarm()
end

-- Reset khi chết để bắt đầu lại vòng lặp
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.3)
    startFarm()
end)
