local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Config = {
    MovementMode = "WalkSpeed",
    WalkSpeed = 50,
    BVSpeed = 50,
    WalkSpeedEnabled = true,
    JumpPowerEnabled = true,
    GravityEnabled = true,
    JumpPower = 50,
    Gravity = 196.2,
    DisableRagdoll = false,
    Noclip = false,
    InfJump = false,
    Invis_Enabled = false,
    Invis_Transparency = 0.75,
    TouchFling = false,
    FlingPower = 9e9,
    Hitbox = false,
    HitboxSize = 10,
    HitboxVisible = false,
    TeleportEnabled = false,
    TeleportDistance = 10,
    TeleportTo = Vector3.new(0, 50, 0),
    ESP_Enabled = false,
    SeatTeleportPos = Vector3.new(5e5, 5e5, 5e5),
    Spin_Enabled = false,
    Spin_Speed = 50,
    AimbotEnabled = false,
    AimbotSmoothness = 0.15,
    AimbotTargetPart = "Head",
    AimbotFieldOfView = 150
}

local AimbotHolding = false
local GuiVisible = true
local ActiveDropdown = nil
local updateInvis = nil
local ragdollConnection = nil
local flingThread = nil
local espConnection = nil
local teleportConnection = nil
local spinConnection = nil
local currentBodyVelocity = nil

local Defaults = {
    WalkSpeed = 16,
    JumpPower = 50,
    Gravity = 196.2
}

local function GetClosestPlayerToCursor()
    local Target, ShortestDistance = nil, Config.AimbotFieldOfView
    local MousePos = UserInputService:GetMouseLocation()
    
    for _, Player in pairs(Players:GetPlayers()) do
        if Player == LocalPlayer then continue end
        local Character = Player.Character
        if not Character then continue end
        local TargetPart = Character:FindFirstChild(Config.AimbotTargetPart)
        if not TargetPart then continue end
        local Humanoid = Character:FindFirstChildOfClass("Humanoid")
        if not Humanoid or Humanoid.Health <= 0 then continue end
        local ScreenPos, OnScreen = Camera:WorldToViewportPoint(TargetPart.Position)
        if not OnScreen then continue end
        local Distance = (Vector2.new(MousePos.X, MousePos.Y) - Vector2.new(ScreenPos.X, ScreenPos.Y)).Magnitude
        if Distance < ShortestDistance then
            Target = Player
            ShortestDistance = Distance
        end
    end
    return Target
end

local function GetClosestPlayerToCharacter()
    local Target, ShortestDistance = nil, math.huge
    local Character = LocalPlayer.Character
    local Root = Character and Character:FindFirstChild("HumanoidRootPart")
    if not Root then return nil end
    
    for _, Player in pairs(Players:GetPlayers()) do
        if Player == LocalPlayer then continue end
        local TargetCharacter = Player.Character
        if not TargetCharacter then continue end
        local TargetRoot = TargetCharacter:FindFirstChild("HumanoidRootPart")
        if not TargetRoot then continue end
        local Humanoid = TargetCharacter:FindFirstChildOfClass("Humanoid")
        if not Humanoid or Humanoid.Health <= 0 then continue end
        local Distance = (Root.Position - TargetRoot.Position).Magnitude
        if Distance < ShortestDistance then
            Target = Player
            ShortestDistance = Distance
        end
    end
    return Target
end

local function GetBestTarget()
    local TargetByCursor = GetClosestPlayerToCursor()
    if TargetByCursor then return TargetByCursor end
    return GetClosestPlayerToCharacter()
end

local function CloseAllDropdowns()
    if ActiveDropdown then
        ActiveDropdown.Visible = false
        ActiveDropdown = nil
    end
end

local function ApplyWalkSpeed()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChild("Humanoid")
    if hum and Config.MovementMode == "WalkSpeed" then
        hum.WalkSpeed = Config.WalkSpeedEnabled and Config.WalkSpeed or Defaults.WalkSpeed
    end
end

local function ApplyJumpPower()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChild("Humanoid")
    if hum then
        hum.JumpPower = Config.JumpPowerEnabled and Config.JumpPower or Defaults.JumpPower
    end
end

local function ApplyGravity()
    workspace.Gravity = Config.GravityEnabled and Config.Gravity or Defaults.Gravity
end

local function ApplyBodyVelocity()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")
    if not (hrp and hum) then return end
    
    if not currentBodyVelocity or currentBodyVelocity.Parent ~= hrp then
        local existing = hrp:FindFirstChild("MoveBV")
        if existing then existing:Destroy() end
        currentBodyVelocity = Instance.new("BodyVelocity")
        currentBodyVelocity.Name = "MoveBV"
        currentBodyVelocity.MaxForce = Vector3.new(1e6, 0, 1e6)
        currentBodyVelocity.Parent = hrp
    end
    
    if Config.MovementMode == "BodyVelocity" and Config.WalkSpeedEnabled then
        hum.WalkSpeed = 16
        local moveDirection = hum.MoveDirection
        if moveDirection.Magnitude > 0 then
            currentBodyVelocity.MaxForce = Vector3.new(1e6, 0, 1e6)
            currentBodyVelocity.Velocity = moveDirection * Config.BVSpeed
        else
            currentBodyVelocity.MaxForce = Vector3.new(1e6, 0, 1e6)
            currentBodyVelocity.Velocity = Vector3.zero
            if hrp.Velocity.Magnitude < 1 then
                hrp.Velocity = Vector3.zero
            end
        end
    else
        currentBodyVelocity.MaxForce = Vector3.zero
        currentBodyVelocity.Velocity = Vector3.zero
    end
end

local function createDivider(parent)
    local divider = Instance.new("Frame", parent)
    divider.Size = UDim2.new(1, 0, 0, 1)
    divider.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    divider.BorderSizePixel = 0
    return divider
end

local function createWindow(title, sizeX, sizeY, startX, startY)
    local sidebarWidth = 100
    local contentOffset = sidebarWidth + 10
    
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = title .. "GUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    ScreenGui.DisplayOrder = 1
    ScreenGui.Parent = game:GetService("CoreGui")
    
    local Main = Instance.new("Frame", ScreenGui)
    Main.Size = UDim2.new(0, sizeX, 0, sizeY)
    Main.Position = UDim2.new(0, startX, 0, startY)
    Main.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    Main.Active = true
    Main.Draggable = true
    Main.BorderSizePixel = 1
    Main.BorderColor3 = Color3.fromRGB(40, 40, 40)
    Main.ClipsDescendants = false
    
    local mainCorner = Instance.new("UICorner", Main)
    mainCorner.CornerRadius = UDim.new(0, 6)
    
    local titleBar = Instance.new("Frame", Main)
    titleBar.Size = UDim2.new(1, 0, 0, 32)
    titleBar.Position = UDim2.new(0, 0, 0, 0)
    titleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    titleBar.BorderSizePixel = 0
    titleBar.ZIndex = 2
    
    local titleCorner = Instance.new("UICorner", titleBar)
    titleCorner.CornerRadius = UDim.new(0, 6)
    
    local titleLabel = Instance.new("TextLabel", titleBar)
    titleLabel.Size = UDim2.new(1, -80, 1, 0)
    titleLabel.Position = UDim2.new(0, 10, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    titleLabel.Font = Enum.Font.SourceSansBold
    titleLabel.TextSize = 16
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.ZIndex = 2
    
    local buttonFrame = Instance.new("Frame", titleBar)
    buttonFrame.Size = UDim2.new(0, 70, 1, 0)
    buttonFrame.Position = UDim2.new(1, -70, 0, 0)
    buttonFrame.BackgroundTransparency = 1
    buttonFrame.ZIndex = 2
    
    local minimizeBtn = Instance.new("TextButton", buttonFrame)
    minimizeBtn.Size = UDim2.new(0, 32, 0, 24)
    minimizeBtn.Position = UDim2.new(0, 0, 0.5, -12)
    minimizeBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    minimizeBtn.Text = "─"
    minimizeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    minimizeBtn.Font = Enum.Font.SourceSansBold
    minimizeBtn.TextSize = 20
    minimizeBtn.BorderSizePixel = 0
    minimizeBtn.ZIndex = 2
    
    local minCorner = Instance.new("UICorner", minimizeBtn)
    minCorner.CornerRadius = UDim.new(0, 4)
    
    local closeBtn = Instance.new("TextButton", buttonFrame)
    closeBtn.Size = UDim2.new(0, 32, 0, 24)
    closeBtn.Position = UDim2.new(1, -32, 0.5, -12)
    closeBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    closeBtn.Font = Enum.Font.SourceSansBold
    closeBtn.TextSize = 16
    closeBtn.BorderSizePixel = 0
    closeBtn.ZIndex = 2
    
    local closeCorner = Instance.new("UICorner", closeBtn)
    closeCorner.CornerRadius = UDim.new(0, 4)
    
    local mainContainer = Instance.new("Frame", Main)
    mainContainer.Size = UDim2.new(1, 0, 1, -42)
    mainContainer.Position = UDim2.new(0, 0, 0, 37)
    mainContainer.BackgroundTransparency = 1
    mainContainer.ClipsDescendants = true
    
    local sidebar = Instance.new("Frame", mainContainer)
    sidebar.Size = UDim2.new(0, sidebarWidth, 1, 0)
    sidebar.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    sidebar.BorderSizePixel = 0
    
    local sidebarCorner = Instance.new("UICorner", sidebar)
    sidebarCorner.CornerRadius = UDim.new(0, 6)
    
    local sidebarLayout = Instance.new("UIListLayout", sidebar)
    sidebarLayout.Padding = UDim.new(0, 4)
    sidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
    
    local contentArea = Instance.new("ScrollingFrame", mainContainer)
    contentArea.Size = UDim2.new(1, -contentOffset, 1, 0)
    contentArea.Position = UDim2.new(0, contentOffset, 0, 0)
    contentArea.BackgroundTransparency = 1
    contentArea.ScrollBarThickness = 4
    contentArea.CanvasSize = UDim2.new(0, 0, 0, 0)
    contentArea.AutomaticCanvasSize = Enum.AutomaticSize.Y
    contentArea.BorderSizePixel = 0
    
    local contentLayout = Instance.new("UIListLayout", contentArea)
    contentLayout.Padding = UDim.new(0, 6)
    contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
    
    local minimized = false
    local originalSize = Main.Size
    
    minimizeBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        if minimized then
            mainContainer.Visible = false
            Main.Size = UDim2.new(0, sizeX, 0, 32)
        else
            mainContainer.Visible = true
            Main.Size = originalSize
        end
    end)
    
    closeBtn.MouseButton1Click:Connect(function()
        Main.Visible = false
    end)
    
    return Main, sidebar, contentArea, contentLayout, ScreenGui
end

local function createSidebarButton(parent, name)
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(1, -8, 0, 34)
    btn.Position = UDim2.new(0, 4, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 13
    btn.BorderSizePixel = 0
    btn.ZIndex = 2
    
    local btnCorner = Instance.new("UICorner", btn)
    btnCorner.CornerRadius = UDim.new(0, 4)
    
    btn.MouseEnter:Connect(function() btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40) end)
    btn.MouseLeave:Connect(function() btn.BackgroundColor3 = Color3.fromRGB(25, 25, 25) end)
    
    return btn
end

local function createContentSection(parent, title)
    local section = Instance.new("Frame", parent)
    section.Size = UDim2.new(1, 0, 0, 0)
    section.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    section.AutomaticSize = Enum.AutomaticSize.Y
    section.BorderSizePixel = 1
    section.BorderColor3 = Color3.fromRGB(35, 35, 35)
    section.ClipsDescendants = false
    section.Visible = false
    
    local sectionCorner = Instance.new("UICorner", section)
    sectionCorner.CornerRadius = UDim.new(0, 6)
    
    local header = Instance.new("TextLabel", section)
    header.Size = UDim2.new(1, 0, 0, 26)
    header.Position = UDim2.new(0, 0, 0, 0)
    header.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    header.Text = title
    header.TextColor3 = Color3.fromRGB(220, 220, 220)
    header.Font = Enum.Font.SourceSansBold
    header.TextSize = 13
    header.TextXAlignment = Enum.TextXAlignment.Center
    header.BorderSizePixel = 0
    header.ZIndex = 2
    
    local headerCorner = Instance.new("UICorner", header)
    headerCorner.CornerRadius = UDim.new(0, 6)
    
    local content = Instance.new("Frame", section)
    content.Size = UDim2.new(1, -10, 0, 0)
    content.Position = UDim2.new(0, 5, 0, 28)
    content.BackgroundTransparency = 1
    content.AutomaticSize = Enum.AutomaticSize.Y
    content.ClipsDescendants = false
    
    local list = Instance.new("UIListLayout", content)
    list.Padding = UDim.new(0, 4)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    
    return section, content
end

local function createToggle(parent, name, prop, callback)
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(1, 0, 0, 28)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.BorderSizePixel = 0
    btn.ZIndex = 2
    
    local btnCorner = Instance.new("UICorner", btn)
    btnCorner.CornerRadius = UDim.new(0, 4)
    
    local label = Instance.new("TextLabel", btn)
    label.Size = UDim2.new(0.65, -5, 1, 0)
    label.Position = UDim2.new(0, 8, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.Font = Enum.Font.SourceSans
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 2
    
    local track = Instance.new("Frame", btn)
    track.Size = UDim2.new(0, 28, 0, 14)
    track.Position = UDim2.new(1, -38, 0.5, -7)
    track.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    track.BorderSizePixel = 0
    track.ZIndex = 2
    
    local trackCorner = Instance.new("UICorner", track)
    trackCorner.CornerRadius = UDim.new(1, 0)
    
    local thumb = Instance.new("Frame", track)
    thumb.Size = UDim2.new(0, 12, 0, 12)
    thumb.Position = Config[prop] and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
    thumb.BackgroundColor3 = Config[prop] and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(100, 100, 100)
    thumb.BorderSizePixel = 0
    thumb.ZIndex = 3
    
    local thumbCorner = Instance.new("UICorner", thumb)
    thumbCorner.CornerRadius = UDim.new(1, 0)
    
    local function updateUI()
        local targetPos = Config[prop] and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
        local tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
        local posTween = TweenService:Create(thumb, tweenInfo, {Position = targetPos})
        local colorTween = TweenService:Create(thumb, tweenInfo, {BackgroundColor3 = Config[prop] and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(100, 100, 100)})
        posTween:Play()
        colorTween:Play()
    end
    
    btn.MouseButton1Click:Connect(function()
        Config[prop] = not Config[prop]
        updateUI()
        if callback then callback(Config[prop]) end
    end)
    
    return btn, updateUI
end

local function createDropdown(parent, name, prop, options)
    local frame = Instance.new("Frame", parent)
    frame.Size = UDim2.new(1, 0, 0, 28)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BorderSizePixel = 0
    frame.ClipsDescendants = false
    frame.ZIndex = 10
    
    local frameCorner = Instance.new("UICorner", frame)
    frameCorner.CornerRadius = UDim.new(0, 4)
    
    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(0.4, -5, 1, 0)
    label.Position = UDim2.new(0, 8, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.Font = Enum.Font.SourceSans
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 10
    
    local dropdownBtn = Instance.new("TextButton", frame)
    dropdownBtn.Size = UDim2.new(0.55, -15, 1, -6)
    dropdownBtn.Position = UDim2.new(0.42, 5, 0, 3)
    dropdownBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    dropdownBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
    dropdownBtn.Font = Enum.Font.SourceSans
    dropdownBtn.TextSize = 12
    dropdownBtn.Text = Config[prop]
    dropdownBtn.BorderSizePixel = 0
    dropdownBtn.ZIndex = 10
    
    local dropdownCorner = Instance.new("UICorner", dropdownBtn)
    dropdownCorner.CornerRadius = UDim.new(0, 4)
    
    local menu = Instance.new("Frame", frame)
    menu.Size = UDim2.new(0.55, -15, 0, #options * 24)
    menu.Position = UDim2.new(0.42, 5, 1, 3)
    menu.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    menu.Visible = false
    menu.ZIndex = 100
    menu.BorderSizePixel = 1
    menu.BorderColor3 = Color3.fromRGB(60, 60, 60)
    menu.ClipsDescendants = false
    
    local menuCorner = Instance.new("UICorner", menu)
    menuCorner.CornerRadius = UDim.new(0, 4)
    
    local menuList = Instance.new("UIListLayout", menu)
    menuList.Padding = UDim.new(0, 1)
    menuList.SortOrder = Enum.SortOrder.LayoutOrder
    
    for _, option in ipairs(options) do
        local btn = Instance.new("TextButton", menu)
        btn.Size = UDim2.new(1, -6, 0, 24)
        btn.Position = UDim2.new(0, 3, 0, 0)
        btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        btn.Text = option
        btn.TextColor3 = Color3.fromRGB(220, 220, 220)
        btn.Font = Enum.Font.SourceSans
        btn.TextSize = 12
        btn.ZIndex = 101
        btn.BorderSizePixel = 0
        
        local btnCorner = Instance.new("UICorner", btn)
        btnCorner.CornerRadius = UDim.new(0, 3)
        
        btn.MouseEnter:Connect(function() btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60) end)
        btn.MouseLeave:Connect(function() btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45) end)
        btn.MouseButton1Click:Connect(function()
            Config[prop] = option
            dropdownBtn.Text = option
            CloseAllDropdowns()
        end)
    end
    
    dropdownBtn.MouseButton1Click:Connect(function()
        if ActiveDropdown == menu then
            CloseAllDropdowns()
        else
            CloseAllDropdowns()
            menu.Visible = true
            ActiveDropdown = menu
        end
    end)
    
    return frame
end

local function createSlider(parent, name, prop, min, max, suffix, decimal)
    decimal = decimal or 0
    local format = decimal > 0 and ("%." .. decimal .. "f") or "%.0f"
    local frame = Instance.new("Frame", parent)
    frame.Size = UDim2.new(1, 0, 0, 34)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BorderSizePixel = 0
    frame.ZIndex = 2
    
    local frameCorner = Instance.new("UICorner", frame)
    frameCorner.CornerRadius = UDim.new(0, 4)
    
    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(0, 90, 1, 0)
    label.Position = UDim2.new(0, 8, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.Font = Enum.Font.SourceSans
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 2
    
    local valueBox = Instance.new("TextBox", frame)
    valueBox.Size = UDim2.new(0, 55, 1, -6)
    valueBox.Position = UDim2.new(1, -60, 0, 3)
    valueBox.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    valueBox.TextColor3 = Color3.fromRGB(220, 220, 220)
    valueBox.Font = Enum.Font.SourceSans
    valueBox.TextSize = 12
    valueBox.Text = string.format(format, Config[prop]) .. suffix
    valueBox.TextXAlignment = Enum.TextXAlignment.Center
    valueBox.BorderSizePixel = 0
    valueBox.ZIndex = 2
    
    local valueCorner = Instance.new("UICorner", valueBox)
    valueCorner.CornerRadius = UDim.new(0, 4)
    
    local slider = Instance.new("Frame", frame)
    slider.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    slider.BorderSizePixel = 0
    slider.ZIndex = 2
    
    local sliderCorner = Instance.new("UICorner", slider)
    sliderCorner.CornerRadius = UDim.new(1, 0)
    
    local fill = Instance.new("Frame", slider)
    fill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    fill.BorderSizePixel = 0
    fill.ZIndex = 2
    
    local fillCorner = Instance.new("UICorner", fill)
    fillCorner.CornerRadius = UDim.new(1, 0)
    
    local knob = Instance.new("TextButton", slider)
    knob.Size = UDim2.new(0, 12, 0, 12)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.Text = ""
    knob.BorderSizePixel = 0
    knob.ZIndex = 3
    
    local knobCorner = Instance.new("UICorner", knob)
    knobCorner.CornerRadius = UDim.new(1, 0)
    
    local dragging = false
    
    local function updateLayout()
        local labelWidth = label.AbsoluteSize.X
        local valueWidth = valueBox.AbsoluteSize.X
        local availableWidth = frame.AbsoluteSize.X - labelWidth - valueWidth - 20
        if availableWidth > 20 then
            slider.Size = UDim2.new(0, availableWidth, 0, 4)
            slider.Position = UDim2.new(0, labelWidth + 10, 0.5, -2)
        end
    end
    
    local function updateValue(value, fromBox)
        local newValue = math.clamp(value, min, max)
        Config[prop] = newValue
        if not fromBox then
            valueBox.Text = string.format(format, newValue) .. suffix
        end
        local percent = (newValue - min) / (max - min)
        fill.Size = UDim2.new(percent, 0, 1, 0)
        knob.Position = UDim2.new(percent, -6, 0.5, -6)
    end
    
    knob.MouseButton1Down:Connect(function()
        dragging = true
        knob.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
            knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local mousePos = input.Position.X
            local sliderPos = slider.AbsolutePosition.X
            local sliderWidth = slider.AbsoluteSize.X
            if sliderWidth > 0 then
                local percent = math.clamp((mousePos - sliderPos) / sliderWidth, 0, 1)
                updateValue(min + (max - min) * percent, false)
            end
        end
    end)
    
    valueBox.FocusLost:Connect(function()
        local text = valueBox.Text:gsub(suffix, "")
        local num = tonumber(text)
        if num then
            updateValue(num, true)
        else
            valueBox.Text = string.format(format, Config[prop]) .. suffix
        end
    end)
    
    frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateLayout)
    label:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateLayout)
    valueBox:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateLayout)
    task.defer(updateLayout)
    updateValue(Config[prop], false)
    
    return frame
end

local function createSliderWithInputAndToggle(parent, name, prop, enabledProp, min, max, suffix, decimal)
    decimal = decimal or 0
    local format = decimal > 0 and ("%." .. decimal .. "f") or "%.0f"
    local frame = Instance.new("Frame", parent)
    frame.Size = UDim2.new(1, 0, 0, 34)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BorderSizePixel = 0
    frame.ZIndex = 2
    
    local frameCorner = Instance.new("UICorner", frame)
    frameCorner.CornerRadius = UDim.new(0, 4)
    
    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(0, 90, 1, 0)
    label.Position = UDim2.new(0, 8, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.Font = Enum.Font.SourceSans
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 2
    
    local toggleBtn = Instance.new("TextButton", frame)
    toggleBtn.Size = UDim2.new(0, 28, 0, 28)
    toggleBtn.Position = UDim2.new(1, -33, 0, 3)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    toggleBtn.Text = ""
    toggleBtn.AutoButtonColor = false
    toggleBtn.BorderSizePixel = 0
    toggleBtn.ZIndex = 2
    
    local toggleCorner = Instance.new("UICorner", toggleBtn)
    toggleCorner.CornerRadius = UDim.new(0, 4)
    
    local track = Instance.new("Frame", toggleBtn)
    track.Size = UDim2.new(0, 28, 0, 14)
    track.Position = UDim2.new(0, 0, 0.5, -7)
    track.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    track.BorderSizePixel = 0
    track.ZIndex = 2
    
    local trackCorner = Instance.new("UICorner", track)
    trackCorner.CornerRadius = UDim.new(1, 0)
    
    local thumb = Instance.new("Frame", track)
    thumb.Size = UDim2.new(0, 12, 0, 12)
    thumb.Position = Config[enabledProp] and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
    thumb.BackgroundColor3 = Config[enabledProp] and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(100, 100, 100)
    thumb.BorderSizePixel = 0
    thumb.ZIndex = 3
    
    local thumbCorner = Instance.new("UICorner", thumb)
    thumbCorner.CornerRadius = UDim.new(1, 0)
    
    local valueBox = Instance.new("TextBox", frame)
    valueBox.Size = UDim2.new(0, 55, 1, -6)
    valueBox.Position = UDim2.new(1, -94, 0, 3)
    valueBox.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    valueBox.TextColor3 = Color3.fromRGB(220, 220, 220)
    valueBox.Font = Enum.Font.SourceSans
    valueBox.TextSize = 12
    valueBox.Text = string.format(format, Config[prop]) .. suffix
    valueBox.TextXAlignment = Enum.TextXAlignment.Center
    valueBox.BorderSizePixel = 0
    valueBox.ZIndex = 2
    
    local valueCorner = Instance.new("UICorner", valueBox)
    valueCorner.CornerRadius = UDim.new(0, 4)
    
    local slider = Instance.new("Frame", frame)
    slider.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    slider.BorderSizePixel = 0
    slider.ZIndex = 2
    
    local sliderCorner = Instance.new("UICorner", slider)
    sliderCorner.CornerRadius = UDim.new(1, 0)
    
    local fill = Instance.new("Frame", slider)
    fill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    fill.BorderSizePixel = 0
    fill.ZIndex = 2
    
    local fillCorner = Instance.new("UICorner", fill)
    fillCorner.CornerRadius = UDim.new(1, 0)
    
    local knob = Instance.new("TextButton", slider)
    knob.Size = UDim2.new(0, 12, 0, 12)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.Text = ""
    knob.BorderSizePixel = 0
    knob.ZIndex = 3
    
    local knobCorner = Instance.new("UICorner", knob)
    knobCorner.CornerRadius = UDim.new(1, 0)
    
    local dragging = false
    
    local function updateLayout()
        local labelWidth = label.AbsoluteSize.X
        local valueWidth = valueBox.AbsoluteSize.X
        local toggleWidth = toggleBtn.AbsoluteSize.X
        local availableWidth = frame.AbsoluteSize.X - labelWidth - valueWidth - toggleWidth - 25
        if availableWidth > 20 then
            slider.Size = UDim2.new(0, availableWidth, 0, 4)
            slider.Position = UDim2.new(0, labelWidth + 10, 0.5, -2)
        end
    end
    
    local function updateValue(value, fromBox)
        local newValue = math.clamp(value, min, max)
        Config[prop] = newValue
        if not fromBox then
            valueBox.Text = string.format(format, newValue) .. suffix
        end
        local percent = (newValue - min) / (max - min)
        fill.Size = UDim2.new(percent, 0, 1, 0)
        knob.Position = UDim2.new(percent, -6, 0.5, -6)
        
        if Config[enabledProp] then
            if enabledProp == "JumpPowerEnabled" then
                ApplyJumpPower()
            elseif enabledProp == "GravityEnabled" then
                ApplyGravity()
            end
        end
    end
    
    local function updateToggleUI()
        local targetPos = Config[enabledProp] and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
        local tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
        local posTween = TweenService:Create(thumb, tweenInfo, {Position = targetPos})
        local colorTween = TweenService:Create(thumb, tweenInfo, {BackgroundColor3 = Config[enabledProp] and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(100, 100, 100)})
        posTween:Play()
        colorTween:Play()
        
        if enabledProp == "JumpPowerEnabled" then
            ApplyJumpPower()
        elseif enabledProp == "GravityEnabled" then
            ApplyGravity()
        end
    end
    
    toggleBtn.MouseButton1Click:Connect(function()
        Config[enabledProp] = not Config[enabledProp]
        updateToggleUI()
    end)
    
    knob.MouseButton1Down:Connect(function()
        dragging = true
        knob.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
            knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement and Config[enabledProp] then
            local mousePos = input.Position.X
            local sliderPos = slider.AbsolutePosition.X
            local sliderWidth = slider.AbsoluteSize.X
            if sliderWidth > 0 then
                local percent = math.clamp((mousePos - sliderPos) / sliderWidth, 0, 1)
                updateValue(min + (max - min) * percent, false)
            end
        end
    end)
    
    valueBox.FocusLost:Connect(function()
        local text = valueBox.Text:gsub(suffix, "")
        local num = tonumber(text)
        if num then
            updateValue(num, true)
        else
            valueBox.Text = string.format(format, Config[prop]) .. suffix
        end
    end)
    
    frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateLayout)
    label:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateLayout)
    valueBox:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateLayout)
    toggleBtn:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateLayout)
    task.defer(updateLayout)
    updateValue(Config[prop], false)
    
    return frame
end

local function createSpeedControl(parent)
    local modeFrame = Instance.new("Frame", parent)
    modeFrame.Size = UDim2.new(1, 0, 0, 34)
    modeFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    modeFrame.BorderSizePixel = 0
    modeFrame.ZIndex = 2
    
    local modeCorner = Instance.new("UICorner", modeFrame)
    modeCorner.CornerRadius = UDim.new(0, 4)
    
    local modeLabel = Instance.new("TextLabel", modeFrame)
    modeLabel.Size = UDim2.new(0, 90, 1, 0)
    modeLabel.Position = UDim2.new(0, 8, 0, 0)
    modeLabel.BackgroundTransparency = 1
    modeLabel.Text = "Mode"
    modeLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    modeLabel.Font = Enum.Font.SourceSans
    modeLabel.TextSize = 13
    modeLabel.TextXAlignment = Enum.TextXAlignment.Left
    modeLabel.ZIndex = 2
    
    local selectorFrame = Instance.new("Frame", modeFrame)
    selectorFrame.Size = UDim2.new(0, 170, 0, 28)
    selectorFrame.Position = UDim2.new(1, -178, 0.5, -14)
    selectorFrame.BackgroundTransparency = 1
    selectorFrame.ZIndex = 2
    
    local leftArrow = Instance.new("TextButton", selectorFrame)
    leftArrow.Size = UDim2.new(0, 28, 1, 0)
    leftArrow.Position = UDim2.new(0, 0, 0, 0)
    leftArrow.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    leftArrow.Text = "<"
    leftArrow.TextColor3 = Color3.fromRGB(220, 220, 220)
    leftArrow.Font = Enum.Font.SourceSansBold
    leftArrow.TextSize = 14
    leftArrow.BorderSizePixel = 0
    leftArrow.ZIndex = 2
    
    local leftCorner = Instance.new("UICorner", leftArrow)
    leftCorner.CornerRadius = UDim.new(0, 4)
    
    local modeText = Instance.new("TextLabel", selectorFrame)
    modeText.Size = UDim2.new(0, 110, 1, 0)
    modeText.Position = UDim2.new(0, 30, 0, 0)
    modeText.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    modeText.Text = Config.MovementMode
    modeText.TextColor3 = Color3.fromRGB(220, 220, 220)
    modeText.Font = Enum.Font.SourceSansBold
    modeText.TextSize = 12
    modeText.BorderSizePixel = 0
    modeText.ZIndex = 2
    
    local modeCorner2 = Instance.new("UICorner", modeText)
    modeCorner2.CornerRadius = UDim.new(0, 4)
    
    local rightArrow = Instance.new("TextButton", selectorFrame)
    rightArrow.Size = UDim2.new(0, 28, 1, 0)
    rightArrow.Position = UDim2.new(1, -28, 0, 0)
    rightArrow.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    rightArrow.Text = ">"
    rightArrow.TextColor3 = Color3.fromRGB(220, 220, 220)
    rightArrow.Font = Enum.Font.SourceSansBold
    rightArrow.TextSize = 14
    rightArrow.BorderSizePixel = 0
    rightArrow.ZIndex = 2
    
    local rightCorner = Instance.new("UICorner", rightArrow)
    rightCorner.CornerRadius = UDim.new(0, 4)
    
    local speedFrame = Instance.new("Frame", parent)
    speedFrame.Size = UDim2.new(1, 0, 0, 34)
    speedFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    speedFrame.BorderSizePixel = 0
    speedFrame.ZIndex = 2
    
    local speedCorner = Instance.new("UICorner", speedFrame)
    speedCorner.CornerRadius = UDim.new(0, 4)
    
    local speedLabel = Instance.new("TextLabel", speedFrame)
    speedLabel.Size = UDim2.new(0, 90, 1, 0)
    speedLabel.Position = UDim2.new(0, 8, 0, 0)
    speedLabel.BackgroundTransparency = 1
    speedLabel.Text = "Speed"
    speedLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    speedLabel.Font = Enum.Font.SourceSans
    speedLabel.TextSize = 13
    speedLabel.TextXAlignment = Enum.TextXAlignment.Left
    speedLabel.ZIndex = 2
    
    local speedToggleBtn = Instance.new("TextButton", speedFrame)
    speedToggleBtn.Size = UDim2.new(0, 28, 0, 28)
    speedToggleBtn.Position = UDim2.new(1, -33, 0, 3)
    speedToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    speedToggleBtn.Text = ""
    speedToggleBtn.AutoButtonColor = false
    speedToggleBtn.BorderSizePixel = 0
    speedToggleBtn.ZIndex = 2
    
    local speedToggleCorner = Instance.new("UICorner", speedToggleBtn)
    speedToggleCorner.CornerRadius = UDim.new(0, 4)
    
    local speedTrack = Instance.new("Frame", speedToggleBtn)
    speedTrack.Size = UDim2.new(0, 28, 0, 14)
    speedTrack.Position = UDim2.new(0, 0, 0.5, -7)
    speedTrack.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    speedTrack.BorderSizePixel = 0
    speedTrack.ZIndex = 2
    
    local speedTrackCorner = Instance.new("UICorner", speedTrack)
    speedTrackCorner.CornerRadius = UDim.new(1, 0)
    
    local speedThumb = Instance.new("Frame", speedTrack)
    speedThumb.Size = UDim2.new(0, 12, 0, 12)
    speedThumb.Position = Config.WalkSpeedEnabled and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
    speedThumb.BackgroundColor3 = Config.WalkSpeedEnabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(100, 100, 100)
    speedThumb.BorderSizePixel = 0
    speedThumb.ZIndex = 3
    
    local speedThumbCorner = Instance.new("UICorner", speedThumb)
    speedThumbCorner.CornerRadius = UDim.new(1, 0)
    
    local speedValueBox = Instance.new("TextBox", speedFrame)
    speedValueBox.Size = UDim2.new(0, 55, 1, -6)
    speedValueBox.Position = UDim2.new(1, -94, 0, 3)
    speedValueBox.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    speedValueBox.TextColor3 = Color3.fromRGB(220, 220, 220)
    speedValueBox.Font = Enum.Font.SourceSans
    speedValueBox.TextSize = 12
    speedValueBox.Text = tostring(Config.WalkSpeed)
    speedValueBox.TextXAlignment = Enum.TextXAlignment.Center
    speedValueBox.BorderSizePixel = 0
    speedValueBox.ZIndex = 2
    
    local speedValueCorner = Instance.new("UICorner", speedValueBox)
    speedValueCorner.CornerRadius = UDim.new(0, 4)
    
    local speedSlider = Instance.new("Frame", speedFrame)
    speedSlider.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    speedSlider.BorderSizePixel = 0
    speedSlider.ZIndex = 2
    
    local speedSliderCorner = Instance.new("UICorner", speedSlider)
    speedSliderCorner.CornerRadius = UDim.new(1, 0)
    
    local speedFill = Instance.new("Frame", speedSlider)
    speedFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    speedFill.BorderSizePixel = 0
    speedFill.ZIndex = 2
    
    local speedFillCorner = Instance.new("UICorner", speedFill)
    speedFillCorner.CornerRadius = UDim.new(1, 0)
    
    local speedKnob = Instance.new("TextButton", speedSlider)
    speedKnob.Size = UDim2.new(0, 12, 0, 12)
    speedKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    speedKnob.Text = ""
    speedKnob.BorderSizePixel = 0
    speedKnob.ZIndex = 3
    
    local speedKnobCorner = Instance.new("UICorner", speedKnob)
    speedKnobCorner.CornerRadius = UDim.new(1, 0)
    
    local dragging = false
    
    local function updateSpeedLayout()
        local labelWidth = speedLabel.AbsoluteSize.X
        local valueWidth = speedValueBox.AbsoluteSize.X
        local toggleWidth = speedToggleBtn.AbsoluteSize.X
        local availableWidth = speedFrame.AbsoluteSize.X - labelWidth - valueWidth - toggleWidth - 25
        if availableWidth > 20 then
            speedSlider.Size = UDim2.new(0, availableWidth, 0, 4)
            speedSlider.Position = UDim2.new(0, labelWidth + 10, 0.5, -2)
        end
    end
    
    local function updateSpeedUI(value, fromBox)
        local newValue = math.clamp(value, 0, 500)
        if Config.MovementMode == "WalkSpeed" then
            Config.WalkSpeed = newValue
            if not fromBox then
                speedValueBox.Text = string.format("%.0f", newValue)
            end
            if Config.WalkSpeedEnabled then
                ApplyWalkSpeed()
            end
        else
            Config.BVSpeed = newValue
            if not fromBox then
                speedValueBox.Text = string.format("%.0f", newValue)
            end
            if Config.WalkSpeedEnabled then
                ApplyBodyVelocity()
            end
        end
        local percent = newValue / 500
        speedFill.Size = UDim2.new(percent, 0, 1, 0)
        speedKnob.Position = UDim2.new(percent, -6, 0.5, -6)
    end
    
    local function updateSpeedToggleUI()
        local targetPos = Config.WalkSpeedEnabled and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
        local tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
        local posTween = TweenService:Create(speedThumb, tweenInfo, {Position = targetPos})
        local colorTween = TweenService:Create(speedThumb, tweenInfo, {BackgroundColor3 = Config.WalkSpeedEnabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(100, 100, 100)})
        posTween:Play()
        colorTween:Play()
        
        if Config.MovementMode == "WalkSpeed" then
            ApplyWalkSpeed()
        else
            ApplyBodyVelocity()
        end
    end
    
    local function updateModeDisplay()
        modeText.Text = Config.MovementMode
        if Config.MovementMode == "WalkSpeed" then
            speedValueBox.Text = string.format("%.0f", Config.WalkSpeed)
            local percent = Config.WalkSpeed / 500
            speedFill.Size = UDim2.new(percent, 0, 1, 0)
            speedKnob.Position = UDim2.new(percent, -6, 0.5, -6)
            ApplyWalkSpeed()
            ApplyBodyVelocity()
        else
            speedValueBox.Text = string.format("%.0f", Config.BVSpeed)
            local percent = Config.BVSpeed / 500
            speedFill.Size = UDim2.new(percent, 0, 1, 0)
            speedKnob.Position = UDim2.new(percent, -6, 0.5, -6)
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChild("Humanoid")
            if hum then
                hum.WalkSpeed = Defaults.WalkSpeed
            end
            ApplyBodyVelocity()
        end
    end
    
    leftArrow.MouseButton1Click:Connect(function()
        Config.MovementMode = Config.MovementMode == "WalkSpeed" and "BodyVelocity" or "WalkSpeed"
        updateModeDisplay()
    end)
    rightArrow.MouseButton1Click:Connect(function()
        Config.MovementMode = Config.MovementMode == "WalkSpeed" and "BodyVelocity" or "WalkSpeed"
        updateModeDisplay()
    end)
    
    speedToggleBtn.MouseButton1Click:Connect(function()
        Config.WalkSpeedEnabled = not Config.WalkSpeedEnabled
        updateSpeedToggleUI()
    end)
    
    speedKnob.MouseButton1Down:Connect(function()
        dragging = true
        speedKnob.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
            speedKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement and Config.WalkSpeedEnabled then
            local mousePos = input.Position.X
            local sliderPos = speedSlider.AbsolutePosition.X
            local sliderWidth = speedSlider.AbsoluteSize.X
            if sliderWidth > 0 then
                local percent = math.clamp((mousePos - sliderPos) / sliderWidth, 0, 1)
                updateSpeedUI(percent * 500, false)
            end
        end
    end)
    
    speedValueBox.FocusLost:Connect(function()
        local num = tonumber(speedValueBox.Text)
        if num then
            updateSpeedUI(num, true)
        else
            if Config.MovementMode == "WalkSpeed" then
                speedValueBox.Text = string.format("%.0f", Config.WalkSpeed)
            else
                speedValueBox.Text = string.format("%.0f", Config.BVSpeed)
            end
        end
    end)
    
    speedFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateSpeedLayout)
    speedLabel:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateSpeedLayout)
    speedValueBox:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateSpeedLayout)
    speedToggleBtn:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateSpeedLayout)
    task.defer(updateSpeedLayout)
    updateModeDisplay()
    updateSpeedToggleUI()
    
    return modeFrame, speedFrame
end

local function createCoordinateInput(parent, name, prop)
    local frame = Instance.new("Frame", parent)
    frame.Size = UDim2.new(1, 0, 0, 28)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BorderSizePixel = 0
    frame.ZIndex = 2
    
    local frameCorner = Instance.new("UICorner", frame)
    frameCorner.CornerRadius = UDim.new(0, 4)
    
    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(0.35, -5, 1, 0)
    label.Position = UDim2.new(0, 8, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.Font = Enum.Font.SourceSans
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 2
    
    local box = Instance.new("TextBox", frame)
    box.Size = UDim2.new(0.42, -15, 1, -6)
    box.Position = UDim2.new(0.37, 5, 0, 3)
    box.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    box.TextColor3 = Color3.fromRGB(220, 220, 220)
    box.Font = Enum.Font.SourceSans
    box.TextSize = 12
    box.Text = ""
    box.PlaceholderText = string.format("%.0f,%.0f,%.0f", Config[prop].X, Config[prop].Y, Config[prop].Z)
    box.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
    box.ClearTextOnFocus = true
    box.BorderSizePixel = 0
    box.ZIndex = 2
    
    local boxCorner = Instance.new("UICorner", box)
    boxCorner.CornerRadius = UDim.new(0, 4)
    
    local teleportBtn = Instance.new("TextButton", frame)
    teleportBtn.Size = UDim2.new(0, 45, 0, 22)
    teleportBtn.Position = UDim2.new(1, -52, 0.5, -11)
    teleportBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    teleportBtn.Text = "go"
    teleportBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
    teleportBtn.Font = Enum.Font.SourceSansBold
    teleportBtn.TextSize = 12
    teleportBtn.BorderSizePixel = 0
    teleportBtn.ZIndex = 2
    
    local btnCorner = Instance.new("UICorner", teleportBtn)
    btnCorner.CornerRadius = UDim.new(0, 4)
    
    teleportBtn.MouseEnter:Connect(function() teleportBtn.BackgroundColor3 = Color3.fromRGB(65, 65, 65) end)
    teleportBtn.MouseLeave:Connect(function() teleportBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50) end)
    teleportBtn.MouseButton1Click:Connect(function()
        teleportBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        task.wait(0.1)
        teleportBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then root.CFrame = CFrame.new(Config[prop]) end
    end)
    
    box.FocusLost:Connect(function()
        if box.Text == "" then
            box.PlaceholderText = string.format("%.0f,%.0f,%.0f", Config[prop].X, Config[prop].Y, Config[prop].Z)
            return
        end
        local x, y, z = box.Text:match("([%-%d%.]+)[, ]+([%-%d%.]+)[, ]+([%-%d%.]+)")
        if x and y and z then
            Config[prop] = Vector3.new(tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0)
            box.Text = ""
            box.PlaceholderText = string.format("%.0f,%.0f,%.0f", Config[prop].X, Config[prop].Y, Config[prop].Z)
        else
            box.Text = ""
            box.PlaceholderText = string.format("%.0f,%.0f,%.0f", Config[prop].X, Config[prop].Y, Config[prop].Z)
        end
    end)
    
    return frame
end

local function toggleRagdoll(state)
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChild("Humanoid")
    if not (char and hum) then return end
    if state then
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        if not ragdollConnection then
            ragdollConnection = hum.StateChanged:Connect(function(_, newState)
                if newState == Enum.HumanoidStateType.FallingDown or newState == Enum.HumanoidStateType.Ragdoll then
                    hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                end
            end)
        end
    else
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
        if ragdollConnection then
            ragdollConnection:Disconnect()
            ragdollConnection = nil
        end
    end
end

local function toggleTouchFling(state)
    if state then
        if not ReplicatedStorage:FindFirstChild("juisdfj0i32i0eidsuf0iok") then
            local detection = Instance.new("Decal")
            detection.Name = "juisdfj0i32i0eidsuf0iok"
            detection.Parent = ReplicatedStorage
        end
        local function flingLoop()
            while Config.TouchFling do
                local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local vel = hrp.Velocity
                    hrp.Velocity = vel * Config.FlingPower + Vector3.new(0, Config.FlingPower, 0)
                    RunService.RenderStepped:Wait()
                    hrp.Velocity = vel
                    RunService.Stepped:Wait()
                    hrp.Velocity = vel + Vector3.new(0, 0.1, 0)
                end
                RunService.Heartbeat:Wait()
            end
        end
        if flingThread then coroutine.close(flingThread) end
        flingThread = coroutine.create(flingLoop)
        coroutine.resume(flingThread)
    else
        if flingThread then
            coroutine.close(flingThread)
            flingThread = nil
        end
    end
end

local function toggleInvis(state)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not (char and hrp) then return end
    if state then
        for _, v in pairs(char:GetDescendants()) do 
            if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then 
                v.Transparency = Config.Invis_Transparency
            end 
        end
        local savedPos = hrp.CFrame
        char:MoveTo(Config.SeatTeleportPos)
        task.wait(0.1)
        local seat = Instance.new('Seat', workspace)
        seat.Name = "InvisChair"
        seat.Transparency = 1
        seat.Position = Config.SeatTeleportPos
        local weld = Instance.new("Weld", seat)
        weld.Part0 = seat
        weld.Part1 = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
        task.wait()
        seat.CFrame = savedPos
    else
        for _, v in pairs(char:GetDescendants()) do 
            if v:IsA("BasePart") then 
                v.Transparency = 0
            end 
        end
        local chair = workspace:FindFirstChild("InvisChair")
        if chair then chair:Destroy() end
    end
    if updateInvis then updateInvis() end
end

local function toggleESP(state)
    if state then
        if espConnection then espConnection:Disconnect() end
        espConnection = RunService.RenderStepped:Connect(function()
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character and not player.Character:FindFirstChild("GetReal") then
                    local highlight = Instance.new("Highlight")
                    highlight.RobloxLocked = true
                    highlight.Name = "GetReal"
                    highlight.Adornee = player.Character
                    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    highlight.FillColor = Color3.new(1, 1, 1)
                    highlight.OutlineColor = Color3.new(1, 1, 1)
                    highlight.OutlineTransparency = 0.2
                    highlight.Parent = player.Character
                end
            end
        end)
    else
        if espConnection then 
            espConnection:Disconnect()
            espConnection = nil
        end
        for _, player in ipairs(Players:GetPlayers()) do
            local highlight = player.Character and player.Character:FindFirstChild("GetReal")
            if highlight then highlight:Destroy() end
        end
    end
end

local function toggleSpin(state)
    if state then
        if spinConnection then spinConnection:Disconnect() end
        spinConnection = RunService.RenderStepped:Connect(function()
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(Config.Spin_Speed), 0)
            end
        end)
    else
        if spinConnection then 
            spinConnection:Disconnect()
            spinConnection = nil
        end
    end
end

local function resetHitboxes()
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local head = p.Character:FindFirstChild("Head")
            if head then
                head.Size = Vector3.new(1.2, 1.2, 1.2)
                head.Transparency = 0
                head.CanCollide = true
                local face = head:FindFirstChild("Face")
                if face then face.Transparency = 0 end
                for _, child in pairs(head:GetChildren()) do
                    if child:IsA("Decal") or child:IsA("Texture") then
                        child.Transparency = 0
                    end
                end
            end
        end
    end
end

local function teleportPlayers()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not (char and root) then return end
    local offsetPosition = root.Position + (root.CFrame.LookVector * Config.TeleportDistance)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local tRoot = player.Character:FindFirstChild("HumanoidRootPart")
            if tRoot then 
                tRoot.CFrame = CFrame.new(offsetPosition)
                tRoot.Velocity = Vector3.zero
            end
        end
    end
end

UserInputService.InputBegan:Connect(function(Input, Processed)
    if not Processed then
        if Input.UserInputType == Enum.UserInputType.MouseButton2 then
            AimbotHolding = true
        elseif Input.UserInputType == Enum.UserInputType.MouseButton1 then
            CloseAllDropdowns()
        end
    end
end)

UserInputService.InputEnded:Connect(function(Input)
    if Input.UserInputType == Enum.UserInputType.MouseButton2 then
        AimbotHolding = false
    end
end)

RunService.RenderStepped:Connect(function()
    if Config.AimbotEnabled and AimbotHolding then
        local Target = GetBestTarget()
        if Target then
            local Character = Target.Character
            if Character then
                local TargetPart = Character:FindFirstChild(Config.AimbotTargetPart)
                if TargetPart then
                    local TargetPosition = TargetPart.Position
                    local LookAt = CFrame.new(Camera.CFrame.Position, TargetPosition)
                    Camera.CFrame = Camera.CFrame:Lerp(LookAt, Config.AimbotSmoothness)
                end
            end
        end
    end
end)

local mainFrame, sidebar, contentArea, contentLayout, screenGui = createWindow("SysHack.GUI", 520, 580, 50, 50)

local sections = {}

local function addSection(sectionName)
    local btn = createSidebarButton(sidebar, sectionName)
    local section, content = createContentSection(contentArea, sectionName)
    sections[sectionName] = {section = section, content = content, button = btn}
    
    btn.MouseButton1Click:Connect(function()
        for _, data in pairs(sections) do
            data.section.Visible = false
            data.button.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        end
        section.Visible = true
        btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    end)
    
    return content
end

local characterSection = addSection("Character")
local combatSection = addSection("Combat")
local visualSection = addSection("Visual")
local teleportSection = addSection("Teleport")

local modeFrame, speedFrame = createSpeedControl(characterSection)
modeFrame.Parent = characterSection
speedFrame.Parent = characterSection

createDivider(characterSection)
createSliderWithInputAndToggle(characterSection, "Jump Power", "JumpPower", "JumpPowerEnabled", 0, 250, "", 0)
createDivider(characterSection)
createSliderWithInputAndToggle(characterSection, "Gravity", "Gravity", "GravityEnabled", 0, 500, "", 1)
createDivider(characterSection)
createToggle(characterSection, "No Ragdoll", "DisableRagdoll", toggleRagdoll)
createToggle(characterSection, "Noclip", "Noclip")
createToggle(characterSection, "Inf Jump", "InfJump")
local invisToggle, invisUpdate = createToggle(characterSection, "Invis", "Invis_Enabled", toggleInvis)
updateInvis = invisUpdate
createToggle(characterSection, "Touch Fling", "TouchFling", toggleTouchFling)
createSlider(characterSection, "Fling Power", "FlingPower", 0, 9e9, "", 0)
createToggle(characterSection, "Spin", "Spin_Enabled", toggleSpin)
createSlider(characterSection, "Spin Speed", "Spin_Speed", 0, 360, "", 0)

createToggle(combatSection, "Aimbot", "AimbotEnabled")
createSlider(combatSection, "Smoothness", "AimbotSmoothness", 0, 1, "", 2)
createDropdown(combatSection, "Target Part", "AimbotTargetPart", {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso"})
createSlider(combatSection, "FOV", "AimbotFieldOfView", 50, 500, "", 0)
createToggle(combatSection, "Hitbox", "Hitbox")
createSlider(combatSection, "Hitbox Size", "HitboxSize", 1, 500, "", 0)
createToggle(combatSection, "Hitbox Visible", "HitboxVisible")

createToggle(visualSection, "ESP", "ESP_Enabled", toggleESP)

createToggle(teleportSection, "Teleport Players", "TeleportEnabled", function(state)
    if state then
        if teleportConnection then teleportConnection:Disconnect() end
        teleportConnection = RunService.Heartbeat:Connect(teleportPlayers)
    else
        if teleportConnection then 
            teleportConnection:Disconnect()
            teleportConnection = nil
        end
    end
end)
createSlider(teleportSection, "Push Distance", "TeleportDistance", 1, 100, "", 0)
createCoordinateInput(teleportSection, "Self Teleport", "TeleportTo")

for _, data in pairs(sections) do
    data.section.Visible = false
end

sections["Character"].section.Visible = true
sections["Character"].button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)

RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")
    if not (char and hrp and hum) then return end
    
    ApplyJumpPower()
    ApplyGravity()
    
    if Config.MovementMode == "BodyVelocity" and Config.WalkSpeedEnabled then
        hum.WalkSpeed = 16
        local moveDirection = hum.MoveDirection
        if not currentBodyVelocity or currentBodyVelocity.Parent ~= hrp then
            local existing = hrp:FindFirstChild("MoveBV")
            if existing then existing:Destroy() end
            currentBodyVelocity = Instance.new("BodyVelocity")
            currentBodyVelocity.Name = "MoveBV"
            currentBodyVelocity.MaxForce = Vector3.new(1e6, 0, 1e6)
            currentBodyVelocity.Parent = hrp
        end
        if moveDirection.Magnitude > 0 then
            currentBodyVelocity.MaxForce = Vector3.new(1e6, 0, 1e6)
            currentBodyVelocity.Velocity = moveDirection * Config.BVSpeed
        else
            currentBodyVelocity.MaxForce = Vector3.new(1e6, 0, 1e6)
            currentBodyVelocity.Velocity = Vector3.zero
            if hrp.Velocity.Magnitude < 1 then
                hrp.Velocity = Vector3.zero
            end
        end
    else
        if currentBodyVelocity then
            currentBodyVelocity.MaxForce = Vector3.zero
            currentBodyVelocity.Velocity = Vector3.zero
        end
        if Config.MovementMode == "WalkSpeed" then
            ApplyWalkSpeed()
        else
            hum.WalkSpeed = Defaults.WalkSpeed
        end
    end
    
    if Config.Noclip then
        for _, v in pairs(char:GetDescendants()) do
            if v:IsA("BasePart") then
                v.CanCollide = false
            end
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if Config.Hitbox then
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local head = p.Character:FindFirstChild("Head")
                if head then
                    head.Size = Vector3.one * Config.HitboxSize
                    head.Transparency = Config.HitboxVisible and 0.5 or 1
                    head.CanCollide = false
                    local face = head:FindFirstChild("Face")
                    if face then face.Transparency = Config.HitboxVisible and 0.5 or 1 end
                    for _, child in pairs(head:GetChildren()) do
                        if child:IsA("Decal") or child:IsA("Texture") then
                            child.Transparency = Config.HitboxVisible and 0.5 or 1
                        end
                    end
                end
            end
        end
    else
        resetHitboxes()
    end
end)

UserInputService.JumpRequest:Connect(function()
    if Config.InfJump then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChild("Humanoid")
        if hum and hum:GetState() ~= Enum.HumanoidStateType.Jumping then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

UserInputService.InputBegan:Connect(function(i, g)
    if g then return end
    if i.KeyCode == Enum.KeyCode.Z then
        Config.Invis_Enabled = not Config.Invis_Enabled
        toggleInvis(Config.Invis_Enabled)
    elseif i.KeyCode == Enum.KeyCode.Insert then
        GuiVisible = not GuiVisible
        mainFrame.Visible = GuiVisible
    end
end)

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(character)
        task.wait(0.5)
        if not Config.Hitbox then
            local head = character:FindFirstChild("Head")
            if head then
                head.Size = Vector3.new(1.2, 1.2, 1.2)
                head.Transparency = 0
                head.CanCollide = true
                local face = head:FindFirstChild("Face")
                if face then face.Transparency = 0 end
                for _, child in pairs(head:GetChildren()) do
                    if child:IsA("Decal") or child:IsA("Texture") then
                        child.Transparency = 0
                    end
                end
            end
        end
        if Config.DisableRagdoll then
            task.wait(0.1)
            toggleRagdoll(true)
        end
        if Config.Spin_Enabled then
            if spinConnection then spinConnection:Disconnect() end
            toggleSpin(true)
        end
    end)
end)

LocalPlayer.CharacterAdded:Connect(function(character)
    task.wait(0.5)
    currentBodyVelocity = nil
    if Config.Spin_Enabled then
        if spinConnection then spinConnection:Disconnect() end
        toggleSpin(true)
    end
    if Config.Invis_Enabled then
        toggleInvis(true)
    end
end)

mainFrame.Visible = true
