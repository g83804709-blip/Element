local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

local Config = {
    AttackRange = 6,
    TeleportOffset = 4,
    AttackCooldown = 0.15,
    RefreshRate = 0.25,
    MoveDuration = 0.08,
    AttackKey = Enum.KeyCode.E,
    MaxTeleportDistance = 60,
}

local State = {
    Enabled = false,
    LastAttack = 0,
    LastRefresh = 0,
    LastMove = 0,
    Target = nil,
    OriginalPosition = nil,
}

local function getCharacter()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") or not char:FindFirstChild("Humanoid") then
        return nil, nil, nil
    end
    return char, char.HumanoidRootPart, char.Humanoid
end

local function isAlive(character)
    if not character then return false end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end
    return humanoid.Health > 0
end

local function getHealth(character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        return humanoid.Health
    end
    return math.huge
end

local function findLowestHealthPlayer()
    local lowestPlayer = nil
    local lowestHealth = math.huge
    local myChar = LocalPlayer.Character

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            if char and char ~= myChar and isAlive(char) then
                local health = getHealth(char)
                if health < lowestHealth then
                    lowestHealth = health
                    lowestPlayer = player
                end
            end
        end
    end

    return lowestPlayer, lowestHealth
end

local function getSafePosition(targetPos, myPos)
    local direction = (myPos - targetPos)
    if direction.Magnitude < 0.1 then
        direction = Vector3.new(0, 0, 1)
    else
        direction = direction.Unit
    end

    local newPos = targetPos + (direction * Config.TeleportOffset)

    local rayOrigin = targetPos + Vector3.new(0, 3, 0)
    local rayDirection = (newPos - rayOrigin)
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = { LocalPlayer.Character }

    local result = workspace:Raycast(rayOrigin, rayDirection, rayParams)
    if result then
        newPos = result.Position + result.Normal * 2
    end

    return newPos
end

local function moveToTarget(targetPlayer)
    local myChar, myRoot = getCharacter()
    if not myChar or not myRoot then return end

    local targetChar = targetPlayer.Character
    if not targetChar then return end

    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end

    local targetPos = targetRoot.Position
    local myPos = myRoot.Position
    local distance = (myPos - targetPos).Magnitude

    if distance > Config.MaxTeleportDistance then
        return
    end

    if tick() - State.LastMove < Config.MoveDuration then return end
    State.LastMove = tick()

    local newPos = getSafePosition(targetPos, myPos)
    local lookAt = CFrame.new(newPos, Vector3.new(targetPos.X, newPos.Y, targetPos.Z))

    local tweenInfo = TweenInfo.new(
        Config.MoveDuration,
        Enum.EasingStyle.Linear,
        Enum.EasingDirection.Out
    )

    local tween = TweenService:Create(myRoot, tweenInfo, {
        CFrame = lookAt
    })
    tween:Play()

    myRoot.Velocity = Vector3.new(0, 0, 0)
end

local function attackTarget()
    local myChar, myRoot, myHumanoid = getCharacter()
    if not myChar or not myRoot or not myHumanoid then return end

    local targetPlayer = State.Target
    if not targetPlayer then return end

    local targetChar = targetPlayer.Character
    if not targetChar or not isAlive(targetChar) then return end

    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end

    local distance = (myRoot.Position - targetRoot.Position).Magnitude
    if distance > Config.AttackRange then return end

    if tick() - State.LastAttack < Config.AttackCooldown then return end

    local tool = myChar:FindFirstChildOfClass("Tool")
    if tool then
        pcall(function()
            tool:Activate()
        end)
    end

    State.LastAttack = tick()
end

local function onRenderStep()
    if not State.Enabled then return end

    local now = tick()
    if now - State.LastRefresh >= Config.RefreshRate then
        State.LastRefresh = now
        local targetPlayer = findLowestHealthPlayer()
        State.Target = targetPlayer
    end

    if State.Target and isAlive(State.Target.Character) then
        moveToTarget(State.Target)
        attackTarget()
    end
end

local function createMenu()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AutoFarmGui"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 220, 0, 130)
    mainFrame.Position = UDim2.new(0, 20, 0.3, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = mainFrame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(80, 120, 255)
    stroke.Thickness = 1.5
    stroke.Parent = mainFrame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 32)
    title.BackgroundColor3 = Color3.fromRGB(40, 60, 140)
    title.BorderSizePixel = 0
    title.Text = "AUTO TELEPORT ATTACK"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextScaled = false
    title.TextSize = 14
    title.Font = Enum.Font.GothamBold
    title.Parent = mainFrame

    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = title

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -20, 0, 24)
    statusLabel.Position = UDim2.new(0, 10, 0, 42)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Status: OFF"
    statusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
    statusLabel.TextSize = 13
    statusLabel.Font = Enum.Font.GothamMedium
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = mainFrame

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(1, -20, 0, 36)
    toggleBtn.Position = UDim2.new(0, 10, 0, 80)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 90)
    toggleBtn.BorderSizePixel = 0
    toggleBtn.Text = "AKTIFKAN"
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.TextSize = 14
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.Parent = mainFrame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = toggleBtn

    toggleBtn.MouseButton1Click:Connect(function()
        State.Enabled = not State.Enabled
        if State.Enabled then
            toggleBtn.Text = "NONAKTIFKAN"
            toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
            statusLabel.Text = "Status: ON"
            statusLabel.TextColor3 = Color3.fromRGB(80, 255, 120)
        else
            toggleBtn.Text = "AKTIFKAN"
            toggleBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 90)
            statusLabel.Text = "Status: OFF"
            statusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
            State.Target = nil
        end
    end)

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.RightShift then
            mainFrame.Visible = not mainFrame.Visible
        end
    end)
end

createMenu()
RunService.RenderStepped:Connect(onRenderStep)a
