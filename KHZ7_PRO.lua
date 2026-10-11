
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

-- =========================================================================
--  دالة تحديد الحاوية الآمنة لضمان ظهور الواجهة على كل المحاقن
-- =========================================================================
local function getContainerUI()
    local success, hui = pcall(function() return gethui() end)
    if success and hui and typeof(hui) == "Instance" then return hui end
    
    local successCore, core = pcall(function() return game:GetService("CoreGui") end)
    if successCore and core then return core end
    
    return player:WaitForChild("PlayerGui", 5) or player.PlayerGui
end

-- =========================================================================
--  1. إعدادات السكربتات والحركة
-- =========================================================================
local Settings = {
    Enabled = false,
    FastPassEnabled = false,
    ClickTPEnabled = false,
    MapBounds = { Xmin = -45, Xmax = 45, Zmin = -45, Zmax = 45 },
    AutoPass = true,
}

local MoveSettings = {
    FlySpeed = 50,
    WalkSpeed = 50,
    JumpPower = 100,
    
    ZinoxFlyActive = false,
    ZinoxFlyFreeze = false,
    ZinoxSpeedActive = false,
    KenzoSpeedActive = false,
    KenzoJumpActive = false
}

-- =========================================================================
--  2. نظام الحفظ التلقائي (JSON Auto-Save V6.5)
-- =========================================================================
local SAVE_FILE_NAME = "KHZ_Hub_V6_5_Config.json"

local UIConfig = {
    MainColorR = 15, MainColorG = 18, MainColorB = 28, Alpha = 0.05,
    ButtonHeight = 40, FloatBtnSize = 55,
    MenuLocked = false, FloatLocked = false,
    
    GhostActive = false, LayDownActive = false, BombActive = false, FastBombActive = false, ClickTPActive = false,
    ZinoxFlyActive = false, ZinoxSpeedActive = false, KenzoSpeedActive = false, KenzoJumpActive = false,
    BackFallActive = false,
    
    FlySpeedVal = 50, WalkSpeedVal = 50, JumpPowerVal = 100,
    
    ShowGhostBtn = false, ShowLayDownBtn = false, ShowBombBtn = false, ShowFastBombBtn = false, ShowClickTPBtn = false,
    ShowFlyBtn = false, ShowZinoxSpeedBtn = false, ShowKenzoSpeedBtn = false, ShowKenzoJumpBtn = false,
    ShowDisableAllBtn = false, ShowBackFallBtn = false,
    
    Positions = {},
    Keybinds = {
        Ghost = "None",
        LayDown = "None",
        Bomb = "None",
        FastBomb = "None",
        ClickTP = "None",
        ZinoxFly = "None",
        ZinoxSpeed = "None",
        KenzoSpeed = "None",
        KenzoJump = "None",
        BackFall = "None",
        DisableAll = "None"
    }
}

local function posToTable(udim2)
    return {XS = udim2.X.Scale, XO = udim2.X.Offset, YS = udim2.Y.Scale, YO = udim2.Y.Offset}
end

local function tableToPos(tbl, default)
    if not tbl then return default end
    return UDim2.new(tbl.XS or default.X.Scale, tbl.XO or default.X.Offset, tbl.YS or default.Y.Scale, tbl.YO or default.Y.Offset)
end

local function saveConfiguration()
    pcall(function()
        if writefile then writefile(SAVE_FILE_NAME, HttpService:JSONEncode(UIConfig)) end
    end)
end

local function loadConfiguration()
    pcall(function()
        if isfile and readfile and isfile(SAVE_FILE_NAME) then
            local decoded = HttpService:JSONDecode(readfile(SAVE_FILE_NAME))
            if type(decoded) == "table" then
                for k, v in pairs(decoded) do
                    if k == "Positions" and type(v) == "table" then
                        for posKey, posVal in pairs(v) do UIConfig.Positions[posKey] = posVal end
                    elseif k == "Keybinds" and type(v) == "table" then
                        for kbKey, kbVal in pairs(v) do UIConfig.Keybinds[kbKey] = kbVal end
                    else 
                        UIConfig[k] = v 
                    end
                end
            end
        end
    end)
end
loadConfiguration()

MoveSettings.FlySpeed = UIConfig.FlySpeedVal or 50
MoveSettings.WalkSpeed = UIConfig.WalkSpeedVal or 50
MoveSettings.JumpPower = UIConfig.JumpPowerVal or 100

-- Declarations
local updateAllButtonTexts
local toggleGhostLogic, toggleLayDownLogic, toggleBombState, toggleFastBombState, toggleClickTPState
local toggleZinoxFly, toggleZinoxSpeed, toggleKenzoSpeed, toggleKenzoJump, toggleBackFallLogic

-- =========================================================================
--  3. محرك إعطاء وتمرير القنبلة التلقائي
-- =========================================================================
local isProcessing, isPassing, loopConnection = false, false, nil

local function autoDetectBounds()
    local minX, maxX = -45, 45
    local minZ, maxZ = -45, 45

    pcall(function()
        local count = 0
        for _, part in ipairs(Workspace:GetChildren()) do
            if part:IsA("BasePart") and part.CanCollide and part.Size.Magnitude > 10 then
                local pos = part.Position
                minX = math.min(minX, pos.X - part.Size.X/2)
                maxX = math.max(maxX, pos.X + part.Size.X/2)
                minZ = math.min(minZ, pos.Z - part.Size.Z/2)
                maxZ = math.max(maxZ, pos.Z + part.Size.Z/2)
                count = count + 1
                if count > 80 then break end
            end
        end
    end)

    Settings.MapBounds.Xmin = minX + 4
    Settings.MapBounds.Xmax = maxX - 4
    Settings.MapBounds.Zmin = minZ + 4
    Settings.MapBounds.Zmax = maxZ - 4
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function updateCharFilter(char)
    if char then rayParams.FilterDescendantsInstances = {char} end
end
updateCharFilter(player.Character)
player.CharacterAdded:Connect(updateCharFilter)

local function clampToBounds(pos)
    local b = Settings.MapBounds
    return Vector3.new(math.clamp(pos.X, b.Xmin + 3, b.Xmax - 3), pos.Y, math.clamp(pos.Z, b.Zmin + 3, b.Zmax - 3))
end

local function isTeammate(otherPlayer)
    if not otherPlayer then return false end
    if player.Team and otherPlayer.Team then return player.Team == otherPlayer.Team end
    if player.TeamColor and otherPlayer.TeamColor and player.Team ~= nil then return player.TeamColor == otherPlayer.TeamColor end
    return false
end

local function hasLineOfSight(origin, targetPos, targetChar)
    local dir = targetPos - origin
    if dir.Magnitude < 0.5 then return true end
    local lineRayParams = RaycastParams.new()
    lineRayParams.FilterType = Enum.RaycastFilterType.Exclude
    lineRayParams.FilterDescendantsInstances = {player.Character, targetChar}
    lineRayParams.IgnoreWater = true
    return Workspace:Raycast(origin + Vector3.new(0, 2, 0), dir, lineRayParams) == nil
end

local function findBombInCharacter(char)
    if not char then return nil end
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then
            local name = child.Name:lower()
            if name:match("bomb") or name:match("c4") or name:match("explosive") or name:match("time") then return child end
        end
    end
    return nil
end

local function isPlayerHoldingBomb()
    local char = player.Character
    if char and findBombInCharacter(char) then return true end
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                local name = tool.Name:lower()
                if name:match("bomb") or name:match("c4") or name:match("explosive") or name:match("time") then return true end
            end
        end
    end
    return false
end

local function handlePlayerHasBomb()
    if not Settings.AutoPass or isPassing then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local closest, closestDistSq = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and not isTeammate(p) and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local pRoot = p.Character.HumanoidRootPart
            if hasLineOfSight(hrp.Position, pRoot.Position, p.Character) then
                local offset = pRoot.Position - hrp.Position
                local distSq = offset:Dot(offset)
                if distSq < closestDistSq then closestDistSq = distSq; closest = p end
            end
        end
    end

    if closest and closest.Character and closest.Character:FindFirstChild("HumanoidRootPart") then
        isPassing = true
        local originalCFrame = hrp.CFrame
        local targetRoot = closest.Character.HumanoidRootPart
        local startTime = os.clock()
        
        while isPlayerHoldingBomb() and (os.clock() - startTime < 3.5) and (Settings.Enabled or Settings.FastPassEnabled) do
            if not targetRoot or not targetRoot.Parent then break end
            hrp.CFrame = CFrame.new(clampToBounds(targetRoot.Position))
            
            if Settings.FastPassEnabled then
                task.wait(0)
            else
                task.wait()
            end
        end
        if originalCFrame then hrp.CFrame = CFrame.new(clampToBounds(originalCFrame.Position)) end
        isPassing = false
    end
end

local function mainLoop()
    if (not Settings.Enabled and not Settings.FastPassEnabled) or isProcessing then return end
    isProcessing = true
    if isPlayerHoldingBomb() then handlePlayerHasBomb() end
    isProcessing = false
end

local function startBombScript()
    if loopConnection then loopConnection:Disconnect() end
    loopConnection = RunService.Heartbeat:Connect(mainLoop)
    Settings.Enabled = true
end

local function stopBombScript()
    if not Settings.FastPassEnabled and loopConnection then 
        loopConnection:Disconnect(); loopConnection = nil 
    end
    Settings.Enabled = false; isProcessing = false; isPassing = false
end

toggleBombState = function(state)
    local targetState = (state ~= nil) and state or not Settings.Enabled
    if targetState then startBombScript() else stopBombScript() end
    UIConfig.BombActive = Settings.Enabled
    saveConfiguration()
end

toggleFastBombState = function(state)
    local targetState = (state ~= nil) and state or not Settings.FastPassEnabled
    Settings.FastPassEnabled = targetState
    if targetState then
        if loopConnection then loopConnection:Disconnect() end
        loopConnection = RunService.Heartbeat:Connect(mainLoop)
    elseif not Settings.Enabled and loopConnection then
        loopConnection:Disconnect(); loopConnection = nil
    end
    UIConfig.FastBombActive = Settings.FastPassEnabled
    saveConfiguration()
end

autoDetectBounds()

-- =========================================================================
--  4. ميزة الانتقال بالنقر (Click Teleport)
-- =========================================================================
toggleClickTPState = function(state)
    Settings.ClickTPEnabled = (state ~= nil) and state or not Settings.ClickTPEnabled
    UIConfig.ClickTPActive = Settings.ClickTPEnabled
    saveConfiguration()
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or not Settings.ClickTPEnabled then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        local char = player.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        local mousePos = UserInputService:GetMouseLocation()
        local unitRay = camera:ViewportPointToRay(mousePos.X, mousePos.Y)

        local tpRayParams = RaycastParams.new()
        tpRayParams.FilterType = Enum.RaycastFilterType.Exclude
        tpRayParams.FilterDescendantsInstances = {char}
        tpRayParams.IgnoreWater = true

        local result = Workspace:Raycast(unitRay.Origin, unitRay.Direction * 2000, tpRayParams)
        if result then
            local camToHit = result.Position - camera.CFrame.Position
            if camToHit:Dot(camera.CFrame.LookVector) > 0 then
                local finalPos = clampToBounds(result.Position + Vector3.new(0, 3, 0))
                hrp.CFrame = CFrame.new(finalPos)
            end
        end
    end
end)

-- =========================================================================
--  5. ميزات FE Ghost & Lay Down
-- =========================================================================
local isFeGhostActive, ghostModel, realAnchoredState = false, nil, false
local ghostLoopConn, jumpConn = nil, nil
local FAR_POS = Vector3.new(0, 500000, 0)

toggleGhostLogic = function(state)
    pcall(function()
        local char = player.Character
        if not char then return end
        local hrp, hum = char:FindFirstChild("HumanoidRootPart"), char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return end

        local targetState = (state ~= nil) and state or not isFeGhostActive
        if targetState and not isFeGhostActive then
            isFeGhostActive = true; char.Archivable = true
            ghostModel = char:Clone(); ghostModel.Name = player.Name .. "_Ghost"
            for _, part in ipairs(ghostModel:GetDescendants()) do
                if part:IsA("BasePart") then part.Transparency = 0.5; part.CanCollide = true
                elseif part:IsA("LocalScript") or part:IsA("Script") then part:Destroy() end
            end
            ghostModel.Parent = Workspace
            ghostModel:SetPrimaryPartCFrame(hrp.CFrame)
            local ghostHum = ghostModel:FindFirstChildOfClass("Humanoid")
            if ghostHum then camera.CameraSubject = ghostHum end

            realAnchoredState = hrp.Anchored
            hrp.CFrame = CFrame.new(FAR_POS); hrp.Anchored = true

            ghostLoopConn = RunService.RenderStepped:Connect(function()
                if isFeGhostActive and ghostModel and ghostModel:FindFirstChildOfClass("Humanoid") then
                    local currentGhostHum = ghostModel:FindFirstChildOfClass("Humanoid")
                    if hum and currentGhostHum then currentGhostHum:Move(hum.MoveVector, true) end
                    if hrp then hrp.CFrame = CFrame.new(FAR_POS); hrp.Velocity = Vector3.zero end
                end
            end)
            jumpConn = UserInputService.JumpRequest:Connect(function()
                if isFeGhostActive and ghostModel then
                    local gHum = ghostModel:FindFirstChildOfClass("Humanoid")
                    if gHum then gHum.Jump = true end
                end
            end)
        elseif not targetState and isFeGhostActive then
            isFeGhostActive = false
            if ghostLoopConn then ghostLoopConn:Disconnect(); ghostLoopConn = nil end
            if jumpConn then jumpConn:Disconnect(); jumpConn = nil end
            if ghostModel and ghostModel:FindFirstChild("HumanoidRootPart") then
                local ghostCFrame = ghostModel.HumanoidRootPart.CFrame
                hrp.Anchored = realAnchoredState; hrp.CFrame = ghostCFrame
                if hum then camera.CameraSubject = hum end
                ghostModel:Destroy(); ghostModel = nil
            else
                hrp.Anchored = realAnchoredState
                if hum then camera.CameraSubject = hum end
            end
        end
        UIConfig.GhostActive = isFeGhostActive
        saveConfiguration()
    end)
end

local isLyingDown, layDownConn = false, nil
toggleLayDownLogic = function(state)
    local char = player.Character
    if not char then return end
    local hum, hrp = char:FindFirstChildOfClass("Humanoid"), char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end

    local targetState = (state ~= nil) and state or not isLyingDown
    isLyingDown = targetState
    UIConfig.LayDownActive = isLyingDown
    saveConfiguration()

    if isLyingDown then
        hum.AutoRotate = false
        hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
        hum:ChangeState(Enum.HumanoidStateType.Physics)
        hum.PlatformStand = true
        hrp.CFrame = hrp.CFrame * CFrame.Angles(math.rad(-90), 0, 0)

        if layDownConn then layDownConn:Disconnect() end
        layDownConn = RunService.Heartbeat:Connect(function()
            if isLyingDown and hum and hrp and hum.Parent then
                local moveDir = hum.MoveDirection
                if moveDir.Magnitude > 0 then
                    hrp.AssemblyLinearVelocity = Vector3.new(moveDir.X * hum.WalkSpeed, hrp.AssemblyLinearVelocity.Y, moveDir.Z * hum.WalkSpeed)
                end
            end
        end)
    else
        if layDownConn then layDownConn:Disconnect(); layDownConn = nil end
        hum.PlatformStand = false; hum.AutoRotate = true
        hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
end

-- =========================================================================
--  6. الميزة الجديدة: الاختفاء + الاستلقاء ثم العودة والانحناء للخلف للسقوط
-- =========================================================================
local isBackFallActive, backFallConn = false, nil

toggleBackFallLogic = function(state)
    local targetState = (state ~= nil) and state or not isBackFallActive
    isBackFallActive = targetState
    UIConfig.BackFallActive = isBackFallActive
    saveConfiguration()

    if isBackFallActive then
        task.spawn(function()
            -- Step 1: تفعيل ميزة الاختفاء وميزة الاستلقاء في نفس الوقت
            if not isFeGhostActive then toggleGhostLogic(true) end
            if not isLyingDown then toggleLayDownLogic(true) end

            task.wait(0.4)

            -- Step 2: إرجاع اللاعب من الاختفاء مع بقاء الاستلقاء مفعل
            if isFeGhostActive then toggleGhostLogic(false) end
            if not isLyingDown then toggleLayDownLogic(true) end

            -- Step 3: جعل اللاعب ينحني إلى الخلف تدريجياً حتى يسقط بالكامل
            if backFallConn then backFallConn:Disconnect() end
            local currentAngle = -90
            backFallConn = RunService.Heartbeat:Connect(function(dt)
                if not isBackFallActive then return end
                local char = player.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                    local hrp = char.HumanoidRootPart
                    currentAngle = math.max(-180, currentAngle - (80 * dt))
                    hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(math.rad(currentAngle), 0, 0)
                end
            end)
        end)
    else
        if backFallConn then backFallConn:Disconnect(); backFallConn = nil end
        if isLyingDown then toggleLayDownLogic(false) end
        if isFeGhostActive then toggleGhostLogic(false) end
    end
    if updateAllButtonTexts then updateAllButtonTexts() end
end

-- =========================================================================
--  7. محركات الحركة المنفصلة
-- =========================================================================
local flyPlatform = Instance.new("Part")
flyPlatform.Size = Vector3.new(4, 0.5, 4)
flyPlatform.Transparency = 1; flyPlatform.Anchored = true; flyPlatform.CanCollide = true
flyPlatform.Name = "ZinoxFlyPlatform"; flyPlatform.Parent = Workspace

local flyPosition = nil
toggleZinoxFly = function(state)
    MoveSettings.ZinoxFlyActive = (state ~= nil) and state or not MoveSettings.ZinoxFlyActive
    UIConfig.ZinoxFlyActive = MoveSettings.ZinoxFlyActive
    saveConfiguration()

    if MoveSettings.ZinoxFlyActive then
        local char = player.Character
        if char and char:FindFirstChild("HumanoidRootPart") then flyPosition = char.HumanoidRootPart.Position end
    else
        flyPlatform.CFrame = CFrame.new(0, -10000, 0)
        flyPosition = nil
        if player.Character and player.Character:FindFirstChild("Humanoid") then
            player.Character.Humanoid.PlatformStand = false
        end
    end
end

toggleZinoxSpeed = function(state)
    MoveSettings.ZinoxSpeedActive = (state ~= nil) and state or not MoveSettings.ZinoxSpeedActive
    UIConfig.ZinoxSpeedActive = MoveSettings.ZinoxSpeedActive
    saveConfiguration()
end

toggleKenzoSpeed = function(state)
    MoveSettings.KenzoSpeedActive = (state ~= nil) and state or not MoveSettings.KenzoSpeedActive
    UIConfig.KenzoSpeedActive = MoveSettings.KenzoSpeedActive
    saveConfiguration()
end

local jumpBoostConn = nil
toggleKenzoJump = function(state)
    MoveSettings.KenzoJumpActive = (state ~= nil) and state or not MoveSettings.KenzoJumpActive
    UIConfig.KenzoJumpActive = MoveSettings.KenzoJumpActive
    saveConfiguration()

    if jumpBoostConn then jumpBoostConn:Disconnect(); jumpBoostConn = nil end

    if MoveSettings.KenzoJumpActive then
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            jumpBoostConn = hum.Jumping:Connect(function()
                if MoveSettings.KenzoJumpActive then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        hrp.Velocity = Vector3.new(hrp.Velocity.X, MoveSettings.JumpPower, hrp.Velocity.Z)
                    end
                end
            end)
        end
    end
end

-- =========================================================================
--  دالة إقفال كل المميزات الشغالة (Panic Switch)
-- =========================================================================
local function disableAllFeatures()
    if isFeGhostActive then toggleGhostLogic(false) end
    if isLyingDown then toggleLayDownLogic(false) end
    if Settings.Enabled then toggleBombState(false) end
    if Settings.FastPassEnabled then toggleFastBombState(false) end
    if Settings.ClickTPEnabled then toggleClickTPState(false) end
    if MoveSettings.ZinoxFlyActive then toggleZinoxFly(false) end
    if MoveSettings.ZinoxSpeedActive then toggleZinoxSpeed(false) end
    if MoveSettings.KenzoSpeedActive then toggleKenzoSpeed(false) end
    if MoveSettings.KenzoJumpActive then toggleKenzoJump(false) end
    if isBackFallActive then toggleBackFallLogic(false) end
    if updateAllButtonTexts then updateAllButtonTexts() end
end

RunService.RenderStepped:Connect(function(dt)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    if MoveSettings.ZinoxFlyActive then
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        hum.PlatformStand = MoveSettings.ZinoxFlyFreeze

        if not flyPosition then flyPosition = hrp.Position end
        local moveDir = hum.MoveDirection
        local camCFrame = camera.CFrame

        if moveDir.Magnitude > 0 then
            local flatLook = Vector3.new(camCFrame.LookVector.X, 0, camCFrame.LookVector.Z)
            flatLook = flatLook.Magnitude > 0 and flatLook.Unit or Vector3.new(0, 0, -1)
            local flatRight = Vector3.new(camCFrame.RightVector.X, 0, camCFrame.RightVector.Z)
            flatRight = flatRight.Magnitude > 0 and flatRight.Unit or Vector3.new(1, 0, 0)

            local forwardInput = moveDir:Dot(flatLook)
            local rightInput = moveDir:Dot(flatRight)
            local flyDir = (camCFrame.LookVector * forwardInput) + (camCFrame.RightVector * rightInput)

            if flyDir.Magnitude > 0 then
                flyDir = flyDir.Unit
                flyPosition = flyPosition + (flyDir * MoveSettings.FlySpeed * dt)
            end
        end

        local yawLook = Vector3.new(camCFrame.LookVector.X, 0, camCFrame.LookVector.Z)
        if yawLook.Magnitude > 0 then hrp.CFrame = CFrame.new(flyPosition, flyPosition + yawLook)
        else hrp.CFrame = CFrame.new(flyPosition) end
        flyPlatform.CFrame = CFrame.new(flyPosition - Vector3.new(0, 2.3, 0))

    elseif MoveSettings.ZinoxSpeedActive then
        local moveDir = hum.MoveDirection
        if moveDir.Magnitude > 0 then
            hrp.CFrame = hrp.CFrame + (moveDir * MoveSettings.WalkSpeed * dt)
        end
    end

    if MoveSettings.KenzoSpeedActive and not MoveSettings.ZinoxFlyActive then
        local moveDir = hum.MoveDirection
        if moveDir.Magnitude > 0.1 then
            hrp.Velocity = Vector3.new(moveDir.X * MoveSettings.WalkSpeed, hrp.Velocity.Y, moveDir.Z * MoveSettings.WalkSpeed)
        end
    end
end)

-- =========================================================================
--  8. إنشاء الواجهة والزر العائم (GUI Setup - KHZ HUB V6.5)
-- =========================================================================

local container = getContainerUI()
if container:FindFirstChild("ZinoxKenzoIntegratedUI") then
    container["ZinoxKenzoIntegratedUI"]:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ZinoxKenzoIntegratedUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 99999999
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Enabled = true
ScreenGui.Parent = container

local ColorableFrames = {}
local FloatingButtonsList = {}

local function applyTheme()
    local mainColor = Color3.fromRGB(UIConfig.MainColorR, UIConfig.MainColorG, UIConfig.MainColorB)
    for _, frame in ipairs(ColorableFrames) do
        if frame then
            frame.BackgroundColor3 = mainColor
            frame.BackgroundTransparency = UIConfig.Alpha
        end
    end
end

-- مظهر KHZ7 PRO: خلفيات داكنة وحدود نيون ثابتة بدون اتصالات RenderStepped لكل زر.
local function addAnimatedRedBlueStripes(guiObject)
    guiObject.BackgroundColor3 = Color3.fromRGB(19, 23, 34)
    guiObject.BackgroundTransparency = 0

    local gradient = guiObject:FindFirstChildOfClass("UIGradient")
    if not gradient then
        gradient = Instance.new("UIGradient")
        gradient.Parent = guiObject
    end
    gradient.Rotation = 90
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(25, 31, 46)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(13, 16, 25))
    })

    local stroke = guiObject:FindFirstChildOfClass("UIStroke")
    if stroke then
        stroke.Thickness = (guiObject.Name == "MainFloatBtn") and 2.5 or 1.2
        stroke.Color = (guiObject.Name == "MainFloatBtn") and Color3.fromRGB(255, 61, 93) or Color3.fromRGB(57, 132, 255)
        stroke.Transparency = 0.08
    end
end

local function makeDraggable(guiObject, posConfigKey, isLockedCheck)
    local dragging, dragStart, startPos, dragInput
    guiObject.InputBegan:Connect(function(input)
        if isLockedCheck and isLockedCheck() then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = guiObject.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if posConfigKey then
                        UIConfig.Positions[posConfigKey] = posToTable(guiObject.Position)
                        saveConfiguration()
                    end
                end
            end)
        end
    end)
    guiObject.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            if isLockedCheck and isLockedCheck() then dragging = false return end
            local delta = input.Position - dragStart
            guiObject.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local function createStyledButton(parent, textStr)
    local btn = Instance.new("TextButton")
    btn.Name = "KHZProButton"
    btn.Size = UDim2.new(1, 0, 0, UIConfig.ButtonHeight)
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.BackgroundColor3 = Color3.fromRGB(20, 25, 37)
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke", btn)
    stroke.Thickness = 1
    stroke.Color = Color3.fromRGB(54, 67, 91)
    stroke.Transparency = 0.12
    addAnimatedRedBlueStripes(btn)

    local accent = Instance.new("Frame")
    accent.Name = "AccentBar"
    accent.Size = UDim2.new(0, 3, 0.58, 0)
    accent.Position = UDim2.new(0, 7, 0.21, 0)
    accent.BackgroundColor3 = Color3.fromRGB(54, 143, 255)
    accent.BorderSizePixel = 0
    accent.ZIndex = 2
    accent.Parent = btn
    Instance.new("UICorner", accent).CornerRadius = UDim.new(1, 0)

    local txtLabel = Instance.new("TextLabel")
    txtLabel.Name = "BtnText"
    txtLabel.Size = UDim2.new(1, -22, 1, 0)
    txtLabel.Position = UDim2.new(0, 16, 0, 0)
    txtLabel.BackgroundTransparency = 1
    txtLabel.Text = textStr
    txtLabel.TextColor3 = Color3.fromRGB(231, 237, 248)
    txtLabel.TextStrokeTransparency = 1
    txtLabel.TextSize = 11
    txtLabel.TextWrapped = true
    txtLabel.Font = Enum.Font.GothamMedium
    txtLabel.ZIndex = 10
    txtLabel.Parent = btn

    btn.MouseEnter:Connect(function()
        btn.BackgroundColor3 = Color3.fromRGB(30, 39, 57)
        local st = btn:FindFirstChildOfClass("UIStroke")
        if st then st.Color = Color3.fromRGB(65, 151, 255) end
        accent.BackgroundColor3 = Color3.fromRGB(255, 65, 103)
    end)
    btn.MouseLeave:Connect(function()
        btn.BackgroundColor3 = Color3.fromRGB(20, 25, 37)
        local st = btn:FindFirstChildOfClass("UIStroke")
        if st then st.Color = Color3.fromRGB(54, 67, 91) end
        accent.BackgroundColor3 = Color3.fromRGB(54, 143, 255)
    end)
    return btn, txtLabel
end

local function updateFloatingButtonsSize(newSize)
    UIConfig.FloatBtnSize = newSize
    for _, btn in ipairs(FloatingButtonsList) do
        if btn and btn.Parent and btn.Name ~= "MainFloatBtn" then
            btn.Size = UDim2.new(0, newSize, 0, newSize)
            local txtLabel = btn:FindFirstChild("FloatText")
            if txtLabel then txtLabel.TextSize = math.clamp(math.floor(newSize * 0.22), 5, 16) end
        end
    end
end

local function createCircularFloatBtn(name, emojiIcon, titleStr, defaultPos, fixedSize)
    local initialSize = fixedSize or UIConfig.FloatBtnSize
    local savedPos = tableToPos(UIConfig.Positions[name], defaultPos)

    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(0, initialSize, 0, initialSize)
    btn.Position = savedPos
    btn.Text = ""
    btn.ZIndex = 100
    btn.Visible = true
    btn.Parent = ScreenGui

    Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
    local stroke = Instance.new("UIStroke", btn)
    stroke.Thickness = (name == "MainFloatBtn") and 2.5 or 1.6
    stroke.Color = (name == "MainFloatBtn") and Color3.fromRGB(255, 61, 93) or Color3.fromRGB(65, 145, 255)
    stroke.Transparency = 0.05
    addAnimatedRedBlueStripes(btn)

    local txtLabel = Instance.new("TextLabel", btn)
    txtLabel.Name = "FloatText"
    txtLabel.Size = UDim2.new(1, 0, 1, 0)
    txtLabel.BackgroundTransparency = 1
    txtLabel.Text = emojiIcon .. "\n" .. titleStr
    txtLabel.TextColor3 = Color3.fromRGB(245, 248, 255)
    txtLabel.TextStrokeTransparency = 1
    txtLabel.TextSize = math.clamp(math.floor(initialSize * 0.22), 7, 14)
    txtLabel.Font = Enum.Font.GothamBold
    txtLabel.ZIndex = 101

    makeDraggable(btn, name, function() return UIConfig.FloatLocked end)
    table.insert(FloatingButtonsList, btn)
    return btn, txtLabel
end

-- الزر العائم الرئيسي (⚙ القائمة)
local MainFloatBtn = createCircularFloatBtn("MainFloatBtn", "⚙", "القائمة", UDim2.new(0.05, 0, 0.25, 0), 60)

-- نافذة القائمة الرئيسية (KHZ HUB V6.5)
local MenuFrame = Instance.new("Frame")
MenuFrame.Name = "MenuFrame"
MenuFrame.Size = UDim2.new(0, 350, 0, 430)
MenuFrame.Position = tableToPos(UIConfig.Positions.Menu, UDim2.new(0.5, -175, 0.2, 0))
MenuFrame.BackgroundColor3 = Color3.fromRGB(UIConfig.MainColorR, UIConfig.MainColorG, UIConfig.MainColorB)
MenuFrame.Visible = false
MenuFrame.ZIndex = 50
MenuFrame.Parent = ScreenGui

-- ضبط أبعاد النافذة تلقائيًا على الهاتف والكمبيوتر مع مراعاة حجم الشاشة.
local function updateMenuForViewport()
    local activeCamera = Workspace.CurrentCamera
    if not activeCamera then return end
    local viewport = activeCamera.ViewportSize
    local width = math.max(260, math.min(390, viewport.X - 24))
    local height = math.max(320, math.min(500, viewport.Y - 24))
    MenuFrame.Size = UDim2.fromOffset(width, height)
    if not UIConfig.Positions.Menu then
        MenuFrame.Position = UDim2.new(0.5, -width / 2, 0.5, -height / 2)
    end
end
updateMenuForViewport()
if Workspace.CurrentCamera then
    Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateMenuForViewport)
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    if Workspace.CurrentCamera then
        Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateMenuForViewport)
        updateMenuForViewport()
    end
end)

Instance.new("UICorner", MenuFrame).CornerRadius = UDim.new(0, 16)
local MenuStroke = Instance.new("UIStroke", MenuFrame)
MenuStroke.Thickness = 1.5
MenuStroke.Color = Color3.fromRGB(72, 119, 190)
MenuStroke.Transparency = 0.05

table.insert(ColorableFrames, MenuFrame)
makeDraggable(MenuFrame, "Menu", function() return UIConfig.MenuLocked end)

MainFloatBtn.MouseButton1Click:Connect(function()
    MenuFrame.Visible = not MenuFrame.Visible
end)

-- الشريط العلوي مع إظهار رقم الإصدار 6.5
local TopBar = Instance.new("Frame", MenuFrame)
TopBar.Size = UDim2.new(1, 0, 0, 42)
TopBar.BackgroundColor3 = Color3.fromRGB(15, 19, 29)
TopBar.BackgroundTransparency = 0
TopBar.BorderSizePixel = 0
Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 16)

local TitleLabel = Instance.new("TextLabel", TopBar)
TitleLabel.Size = UDim2.new(1, -110, 1, 0)
TitleLabel.Position = UDim2.new(0.03, 0, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "⚡ KHZ7  /  PRO"
TitleLabel.TextColor3 = Color3.fromRGB(245, 248, 255)
TitleLabel.TextSize = 14; TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left

local HeaderAccent = Instance.new("Frame", TopBar)
HeaderAccent.Name = "HeaderAccent"
HeaderAccent.Size = UDim2.new(0, 56, 0, 3)
HeaderAccent.Position = UDim2.new(0.03, 0, 1, -3)
HeaderAccent.BackgroundColor3 = Color3.fromRGB(255, 61, 93)
HeaderAccent.BorderSizePixel = 0
Instance.new("UICorner", HeaderAccent).CornerRadius = UDim.new(1, 0)

local CloseBtn = Instance.new("TextButton", TopBar)
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -32, 0.15, 0)
CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 43, 68)
CloseBtn.Text = "X"; CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.AutoButtonColor = false
CloseBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 8)
CloseBtn.MouseButton1Click:Connect(function() MenuFrame.Visible = false end)

local LockMenuBtn = Instance.new("TextButton", TopBar)
LockMenuBtn.Size = UDim2.new(0, 28, 0, 28)
LockMenuBtn.Position = UDim2.new(1, -64, 0.15, 0)
LockMenuBtn.BackgroundColor3 = UIConfig.MenuLocked and Color3.fromRGB(180, 43, 68) or Color3.fromRGB(33, 115, 93)
LockMenuBtn.Text = UIConfig.MenuLocked and "🔒" or "🔓"
LockMenuBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
Instance.new("UICorner", LockMenuBtn).CornerRadius = UDim.new(0, 8)
LockMenuBtn.MouseButton1Click:Connect(function()
    UIConfig.MenuLocked = not UIConfig.MenuLocked
    LockMenuBtn.Text = UIConfig.MenuLocked and "🔒" or "🔓"
    LockMenuBtn.BackgroundColor3 = UIConfig.MenuLocked and Color3.fromRGB(180, 43, 68) or Color3.fromRGB(33, 115, 93)
    saveConfiguration()
end)

local LockFloatBtn = Instance.new("TextButton", TopBar)
LockFloatBtn.Size = UDim2.new(0, 28, 0, 28)
LockFloatBtn.Position = UDim2.new(1, -96, 0.15, 0)
LockFloatBtn.BackgroundColor3 = UIConfig.FloatLocked and Color3.fromRGB(180, 43, 68) or Color3.fromRGB(33, 115, 93)
LockFloatBtn.Text = UIConfig.FloatLocked and "📌" or "📍"
LockFloatBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
Instance.new("UICorner", LockFloatBtn).CornerRadius = UDim.new(0, 8)
LockFloatBtn.MouseButton1Click:Connect(function()
    UIConfig.FloatLocked = not UIConfig.FloatLocked
    LockFloatBtn.Text = UIConfig.FloatLocked and "📌" or "📍"
    LockFloatBtn.BackgroundColor3 = UIConfig.FloatLocked and Color3.fromRGB(180, 43, 68) or Color3.fromRGB(33, 115, 93)
    saveConfiguration()
end)

-- شريط التبويبات (TabBar)
local TabBar = Instance.new("Frame", MenuFrame)
TabBar.Size = UDim2.new(0.94, 0, 0, 36)
TabBar.Position = UDim2.new(0.03, 0, 0.10, 0)
TabBar.BackgroundColor3 = Color3.fromRGB(13, 17, 27)
TabBar.BorderSizePixel = 0
Instance.new("UICorner", TabBar).CornerRadius = UDim.new(0, 11)
local TabBarStroke = Instance.new("UIStroke", TabBar)
TabBarStroke.Color = Color3.fromRGB(42, 53, 74)
TabBarStroke.Thickness = 1

local TabListLayout = Instance.new("UIListLayout", TabBar)
TabListLayout.FillDirection = Enum.FillDirection.Horizontal
TabListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
TabListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
TabListLayout.Padding = UDim.new(0, 2)

local PagesContainer = Instance.new("Frame", MenuFrame)
PagesContainer.Size = UDim2.new(0.94, 0, 0.75, 0)
PagesContainer.Position = UDim2.new(0.03, 0, 0.21, 0)
PagesContainer.BackgroundTransparency = 1

local function createTabPage()
    local page = Instance.new("ScrollingFrame", PagesContainer)
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.ScrollBarThickness = 3
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.Visible = false
    
    local layout = Instance.new("UIListLayout", page)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 6)
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
    end)
    return page
end

local Tab1Page = createTabPage() -- المميزات
local Tab2Page = createTabPage() -- الحركة والطيران
local Tab3Page = createTabPage() -- الأزرار العائمة
local Tab4Page = createTabPage() -- تخصيص الكيبورد
local Tab5Page = createTabPage() -- التصميم والإعدادات
Tab1Page.Visible = true

local tabsList = {}
local function createTabBtn(textStr, targetPage)
    local btn, txtLabel = createStyledButton(TabBar, textStr)
    btn.Size = UDim2.new(0.19, 0, 0.85, 0)
    btn.BackgroundColor3 = Color3.fromRGB(20, 25, 37)
    txtLabel.TextSize = 8
    txtLabel.TextWrapped = true

    local tabData = {Btn = btn, Page = targetPage, Label = txtLabel}
    table.insert(tabsList, tabData)
    local function refreshTabStyles()
        for _, item in ipairs(tabsList) do
            local active = item.Page.Visible
            item.Btn.BackgroundColor3 = active and Color3.fromRGB(37, 62, 99) or Color3.fromRGB(20, 25, 37)
            local st = item.Btn:FindFirstChildOfClass("UIStroke")
            if st then st.Color = active and Color3.fromRGB(67, 151, 255) or Color3.fromRGB(54, 67, 91) end
            item.Label.TextColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 190, 208)
        end
    end
    btn.MouseButton1Click:Connect(function()
        for _, item in ipairs(tabsList) do item.Page.Visible = false end
        targetPage.Visible = true
        refreshTabStyles()
    end)
    refreshTabStyles()
    return btn
end

createTabBtn("المميزات", Tab1Page)
createTabBtn("الحركة", Tab2Page)
createTabBtn("الأزرار", Tab3Page)
createTabBtn("الكيبورد", Tab4Page)
createTabBtn("الإعدادات", Tab5Page)

-- =========================================================================
--  محتوى التبويبات
-- =========================================================================

-- Tab 1: المميزات
local FeatureGhostBtn, GhostBtnTxt = createStyledButton(Tab1Page, " ميزة الاختفاء FE Ghost [ معطل ]")
local FeatureLayDownBtn, LayDownBtnTxt = createStyledButton(Tab1Page, " ميزة الاستلقاء والزحف [ معطل ]")
local FeatureBackFallBtn, BackFallBtnTxt = createStyledButton(Tab1Page, " ميزة الانحناء والسقوط للوراء [ معطل ]")
local FeatureBombBtn, BombBtnTxt = createStyledButton(Tab1Page, " ميزة إعطاء القنبلة العادية [ معطل ]")
local FeatureFastBombBtn, FastBombBtnTxt = createStyledButton(Tab1Page, " ميزة التمرير الأسرع للقنبلة [ معطل ]")
local FeatureClickTPBtn, ClickTPBtnTxt = createStyledButton(Tab1Page, " الانتقال بالنقر على الشاشة [ معطل ]")
local FeatureDisableAllBtn, DisableAllBtnTxt = createStyledButton(Tab1Page, " إقفال جميع المميزات")

-- Tab 2: الحركة والطيران
local function createInputRow(parent, labelText, defaultValue, callback)
    local frame = Instance.new("Frame", parent)
    frame.Size = UDim2.new(1, 0, 0, 34)
    frame.BackgroundColor3 = Color3.fromRGB(19, 24, 36)
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(0.65, 0, 1, 0)
    label.Position = UDim2.new(0.03, 0, 0, 0)
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = Enum.Font.GothamBold; label.TextSize = 11
    label.BackgroundTransparency = 1; label.TextXAlignment = Enum.TextXAlignment.Left

    local input = Instance.new("TextBox", frame)
    input.Size = UDim2.new(0.28, 0, 0.7, 0)
    input.Position = UDim2.new(0.68, 0, 0.15, 0)
    input.Text = tostring(defaultValue)
    input.TextColor3 = Color3.fromRGB(255, 255, 255)
    input.BackgroundColor3 = Color3.fromRGB(31, 40, 58)
    input.Font = Enum.Font.GothamBold; input.TextSize = 12
    Instance.new("UICorner", input).CornerRadius = UDim.new(0, 6)

    input.FocusLost:Connect(function()
        local val = tonumber(input.Text)
        if val and val >= 0 then callback(val) end
    end)
    return frame
end

createInputRow(Tab2Page, " سرعة الطيران (Fly Speed):", MoveSettings.FlySpeed, function(v)
    MoveSettings.FlySpeed = v; UIConfig.FlySpeedVal = v; saveConfiguration()
end)

createInputRow(Tab2Page, " سرعة المشي (Walk Speed):", MoveSettings.WalkSpeed, function(v)
    MoveSettings.WalkSpeed = v; UIConfig.WalkSpeedVal = v; saveConfiguration()
end)

createInputRow(Tab2Page, " قوة القفز (Jump Power):", MoveSettings.JumpPower, function(v)
    MoveSettings.JumpPower = v; UIConfig.JumpPowerVal = v; saveConfiguration()
end)

local ZinoxFlyBtn, ZinoxFlyTxt = createStyledButton(Tab2Page, "✈️ طيران ZINOX Fly Engine [ معطل ]")
local FreezePoseBtn, FreezePoseTxt = createStyledButton(Tab2Page, "🧊 تثبيت وضعية الطيران [ معطل ]")
local ZinoxSpeedBtn, ZinoxSpeedTxt = createStyledButton(Tab2Page, "⚡ سرعة ZINOX (CFrame Speed) [ معطل ]")
local KenzoSpeedBtn, KenzoSpeedTxt = createStyledButton(Tab2Page, "🏃 سرعة KENZO (Physics Speed) [ معطل ]")
local KenzoJumpBtn, KenzoJumpTxt = createStyledButton(Tab2Page, "🦘 قفز KENZO (Jump Boost) [ معطل ]")

-- Tab 3: التحكم في الأزرار العائمة
local ShowAllFloatsBtn = createStyledButton(Tab3Page, "👁️ إظهار كل الأزرار العائمة")
local HideAllFloatsBtn = createStyledButton(Tab3Page, "🙈 إخفاء كل الأزرار العائمة")

local GhostFloatBtn, GhostFloatTxt
local LayDownFloatBtn, LayDownFloatTxt
local BackFallFloatBtn, BackFallFloatTxt
local BombFloatBtn, BombFloatTxt
local FastBombFloatBtn, FastBombFloatTxt
local ClickTPFloatBtn, ClickTPFloatTxt
local FlyFloatBtn, FlyFloatTxt
local ZinoxSpeedFloatBtn, ZinoxSpeedFloatTxt
local KenzoSpeedFloatBtn, KenzoSpeedFloatTxt
local KenzoJumpFloatBtn, KenzoJumpFloatTxt
local DisableAllFloatBtn, DisableAllFloatTxt

local FloatGhostToggle = createStyledButton(Tab3Page, "🔘 زر عائم: الاختفاء")
local FloatLayDownToggle = createStyledButton(Tab3Page, "🔘 زر عائم: الاستلقاء")
local FloatBackFallToggle = createStyledButton(Tab3Page, "🔘 زر عائم: الانحناء والسقوط")
local FloatBombToggle = createStyledButton(Tab3Page, "🔘 زر عائم: إعطاء القنبلة العادي")
local FloatFastBombToggle = createStyledButton(Tab3Page, "🔘 زر عائم: التمرير الأسرع")
local FloatClickTPToggle = createStyledButton(Tab3Page, "🔘 زر عائم: الانتقال بالنقر")
local FloatFlyToggle = createStyledButton(Tab3Page, "🔘 زر عائم: طيران ZINOX")
local FloatZinoxSpeedToggle = createStyledButton(Tab3Page, "🔘 زر عائم: سرعة CFrame")
local FloatKenzoSpeedToggle = createStyledButton(Tab3Page, "🔘 زر عائم: سرعة الفيزياء")
local FloatKenzoJumpToggle = createStyledButton(Tab3Page, "🔘 زر عائم: قفز KENZO")
local FloatDisableAllToggle = createStyledButton(Tab3Page, "🛑 زر عائم: إقفال كل المميزات")

-- دالة تحديث كافة نصوص الأزرار الموحدة
updateAllButtonTexts = function()
    if GhostBtnTxt then GhostBtnTxt.Text = isFeGhostActive and "👻 ميزة الاختفاء FE Ghost [ مفعل 🟢 ]" or "👻 ميزة الاختفاء FE Ghost [ معطل ]" end
    if LayDownBtnTxt then LayDownBtnTxt.Text = isLyingDown and "🛌 ميزة الاستلقاء والزحف [ مفعل 🟢 ]" or "🛌 ميزة الاستلقاء والزحف [ معطل ]" end
    if BackFallBtnTxt then BackFallBtnTxt.Text = isBackFallActive and "🌀 ميزة الانحناء والسقوط [ مفعل 🟢 ]" or "🌀 ميزة الانحناء والسقوط للوراء [ معطل ]" end
    if BombBtnTxt then BombBtnTxt.Text = Settings.Enabled and "💣 ميزة إعطاء القنبلة العادية [ مفعل 🟢 ]" or "💣 ميزة إعطاء القنبلة العادية [ معطل ]" end
    if FastBombBtnTxt then FastBombBtnTxt.Text = Settings.FastPassEnabled and "⚡ ميزة التمرير الأسرع للقنبلة [ مفعل 🟢 ]" or "⚡ ميزة التمرير الأسرع للقنبلة [ معطل ]" end
    if ClickTPBtnTxt then ClickTPBtnTxt.Text = Settings.ClickTPEnabled and "📍 الانتقال بالنقر على الشاشة [ مفعل 🟢 ]" or "📍 الانتقال بالنقر على الشاشة [ معطل ]" end
    
    if ZinoxFlyTxt then ZinoxFlyTxt.Text = MoveSettings.ZinoxFlyActive and "✈️ طيران ZINOX Fly Engine [ مفعل 🟢 ]" or "✈️ طيران ZINOX Fly Engine [ معطل ]" end
    if FreezePoseTxt then FreezePoseTxt.Text = MoveSettings.ZinoxFlyFreeze and "🧊 تثبيت وضعية الطيران [ مفعل 🟢 ]" or "🧊 تثبيت وضعية الطيران [ معطل ]" end
    if ZinoxSpeedTxt then ZinoxSpeedTxt.Text = MoveSettings.ZinoxSpeedActive and "⚡ سرعة ZINOX (CFrame Speed) [ مفعل 🟢 ]" or "⚡ سرعة ZINOX (CFrame Speed) [ معطل ]" end
    if KenzoSpeedTxt then KenzoSpeedTxt.Text = MoveSettings.KenzoSpeedActive and "🏃 سرعة KENZO (Physics Speed) [ مفعل 🟢 ]" or "🏃 سرعة KENZO (Physics Speed) [ معطل ]" end
    if KenzoJumpTxt then KenzoJumpTxt.Text = MoveSettings.KenzoJumpActive and "🦘 قفز KENZO (Jump Boost) [ مفعل 🟢 ]" or "🦘 قفز KENZO (Jump Boost) [ معطل ]" end

    if GhostFloatTxt then GhostFloatTxt.Text = isFeGhostActive and "👻\nمفعل" or "👻\nالاختفاء" end
    if LayDownFloatTxt then LayDownFloatTxt.Text = isLyingDown and "🛌\nمفعل" or "🛌\nالاستلقاء" end
    if BackFallFloatTxt then BackFallFloatTxt.Text = isBackFallActive and "🌀\nمفعل" or "🌀\nالسقوط" end
    if BombFloatTxt then BombFloatTxt.Text = Settings.Enabled and "💣\nمفعل" or "💣\nالقنبلة" end
    if FastBombFloatTxt then FastBombFloatTxt.Text = Settings.FastPassEnabled and "⚡\nمفعل" or "⚡\nأسرع" end
    if ClickTPFloatTxt then ClickTPFloatTxt.Text = Settings.ClickTPEnabled and "📍\nمفعل" or "📍\nانتقال" end
    if FlyFloatTxt then FlyFloatTxt.Text = MoveSettings.ZinoxFlyActive and "✈️\nمفعل" or "✈️\nطيران" end
    if ZinoxSpeedFloatTxt then ZinoxSpeedFloatTxt.Text = MoveSettings.ZinoxSpeedActive and "⚡\nمفعل" or "⚡\nCFrame" end
    if KenzoSpeedFloatTxt then KenzoSpeedFloatTxt.Text = MoveSettings.KenzoSpeedActive and "🏃\nمفعل" or "🏃\nPhysics" end
    if KenzoJumpFloatTxt then KenzoJumpFloatTxt.Text = MoveSettings.KenzoJumpActive and "🦘\nمفعل" or "🦘\nJump" end
end

-- ربط أحداث الضغط على الأزرار الأساسية
FeatureGhostBtn.MouseButton1Click:Connect(function() toggleGhostLogic(); updateAllButtonTexts() end)
FeatureLayDownBtn.MouseButton1Click:Connect(function() toggleLayDownLogic(); updateAllButtonTexts() end)
FeatureBackFallBtn.MouseButton1Click:Connect(function() toggleBackFallLogic(); updateAllButtonTexts() end)
FeatureBombBtn.MouseButton1Click:Connect(function() toggleBombState(); updateAllButtonTexts() end)
FeatureFastBombBtn.MouseButton1Click:Connect(function() toggleFastBombState(); updateAllButtonTexts() end)
FeatureClickTPBtn.MouseButton1Click:Connect(function() toggleClickTPState(); updateAllButtonTexts() end)
FeatureDisableAllBtn.MouseButton1Click:Connect(disableAllFeatures)

ZinoxFlyBtn.MouseButton1Click:Connect(function() toggleZinoxFly(); updateAllButtonTexts() end)
FreezePoseBtn.MouseButton1Click:Connect(function() MoveSettings.ZinoxFlyFreeze = not MoveSettings.ZinoxFlyFreeze; updateAllButtonTexts() end)
ZinoxSpeedBtn.MouseButton1Click:Connect(function() toggleZinoxSpeed(); updateAllButtonTexts() end)
KenzoSpeedBtn.MouseButton1Click:Connect(function() toggleKenzoSpeed(); updateAllButtonTexts() end)
KenzoJumpBtn.MouseButton1Click:Connect(function() toggleKenzoJump(); updateAllButtonTexts() end)

-- أحداث الأزرار العائمة
FloatGhostToggle.MouseButton1Click:Connect(function()
    if not GhostFloatBtn then
        GhostFloatBtn, GhostFloatTxt = createCircularFloatBtn("GhostFloatBtn", "👻", "الاختفاء", UDim2.new(0.85, 0, 0.12, 0))
        GhostFloatBtn.MouseButton1Click:Connect(function() toggleGhostLogic(); updateAllButtonTexts() end)
    end
    GhostFloatBtn.Visible = not GhostFloatBtn.Visible
    UIConfig.ShowGhostBtn = GhostFloatBtn.Visible; saveConfiguration()
end)

FloatLayDownToggle.MouseButton1Click:Connect(function()
    if not LayDownFloatBtn then
        LayDownFloatBtn, LayDownFloatTxt = createCircularFloatBtn("LayDownFloatBtn", "🛌", "الاستلقاء", UDim2.new(0.85, 0, 0.20, 0))
        LayDownFloatBtn.MouseButton1Click:Connect(function() toggleLayDownLogic(); updateAllButtonTexts() end)
    end
    LayDownFloatBtn.Visible = not LayDownFloatBtn.Visible
    UIConfig.ShowLayDownBtn = LayDownFloatBtn.Visible; saveConfiguration()
end)

FloatBackFallToggle.MouseButton1Click:Connect(function()
    if not BackFallFloatBtn then
        BackFallFloatBtn, BackFallFloatTxt = createCircularFloatBtn("BackFallFloatBtn", "🌀", "السقوط", UDim2.new(0.85, 0, 0.28, 0))
        BackFallFloatBtn.MouseButton1Click:Connect(function() toggleBackFallLogic(); updateAllButtonTexts() end)
    end
    BackFallFloatBtn.Visible = not BackFallFloatBtn.Visible
    UIConfig.ShowBackFallBtn = BackFallFloatBtn.Visible; saveConfiguration()
end)

FloatBombToggle.MouseButton1Click:Connect(function()
    if not BombFloatBtn then
        BombFloatBtn, BombFloatTxt = createCircularFloatBtn("BombFloatBtn", "💣", "القنبلة", UDim2.new(0.85, 0, 0.36, 0))
        BombFloatBtn.MouseButton1Click:Connect(function() toggleBombState(); updateAllButtonTexts() end)
    end
    BombFloatBtn.Visible = not BombFloatBtn.Visible
    UIConfig.ShowBombBtn = BombFloatBtn.Visible; saveConfiguration()
end)

FloatFastBombToggle.MouseButton1Click:Connect(function()
    if not FastBombFloatBtn then
        FastBombFloatBtn, FastBombFloatTxt = createCircularFloatBtn("FastBombFloatBtn", "⚡", "أسرع", UDim2.new(0.85, 0, 0.44, 0))
        FastBombFloatBtn.MouseButton1Click:Connect(function() toggleFastBombState(); updateAllButtonTexts() end)
    end
    FastBombFloatBtn.Visible = not FastBombFloatBtn.Visible
    UIConfig.ShowFastBombBtn = FastBombFloatBtn.Visible; saveConfiguration()
end)

FloatClickTPToggle.MouseButton1Click:Connect(function()
    if not ClickTPFloatBtn then
        ClickTPFloatBtn, ClickTPFloatTxt = createCircularFloatBtn("ClickTPFloatBtn", "📍", "انتقال", UDim2.new(0.85, 0, 0.52, 0))
        ClickTPFloatBtn.MouseButton1Click:Connect(function() toggleClickTPState(); updateAllButtonTexts() end)
    end
    ClickTPFloatBtn.Visible = not ClickTPFloatBtn.Visible
    UIConfig.ShowClickTPBtn = ClickTPFloatBtn.Visible; saveConfiguration()
end)

FloatFlyToggle.MouseButton1Click:Connect(function()
    if not FlyFloatBtn then
        FlyFloatBtn, FlyFloatTxt = createCircularFloatBtn("FlyFloatBtn", "✈", "طيران", UDim2.new(0.85, 0, 0.60, 0))
        FlyFloatBtn.MouseButton1Click:Connect(function() toggleZinoxFly(); updateAllButtonTexts() end)
    end
    FlyFloatBtn.Visible = not FlyFloatBtn.Visible
    UIConfig.ShowFlyBtn = FlyFloatBtn.Visible; saveConfiguration()
end)

FloatZinoxSpeedToggle.MouseButton1Click:Connect(function()
    if not ZinoxSpeedFloatBtn then
        ZinoxSpeedFloatBtn, ZinoxSpeedFloatTxt = createCircularFloatBtn("ZinoxSpeedFloatBtn", "⚡", "CFrame", UDim2.new(0.85, 0, 0.68, 0))
        ZinoxSpeedFloatBtn.MouseButton1Click:Connect(function() toggleZinoxSpeed(); updateAllButtonTexts() end)
    end
    ZinoxSpeedFloatBtn.Visible = not ZinoxSpeedFloatBtn.Visible
    UIConfig.ShowZinoxSpeedBtn = ZinoxSpeedFloatBtn.Visible; saveConfiguration()
end)

FloatKenzoSpeedToggle.MouseButton1Click:Connect(function()
    if not KenzoSpeedFloatBtn then
        KenzoSpeedFloatBtn, KenzoSpeedFloatTxt = createCircularFloatBtn("KenzoSpeedFloatBtn", "🏃", "Physics", UDim2.new(0.85, 0, 0.76, 0))
        KenzoSpeedFloatBtn.MouseButton1Click:Connect(function() toggleKenzoSpeed(); updateAllButtonTexts() end)
    end
    KenzoSpeedFloatBtn.Visible = not KenzoSpeedFloatBtn.Visible
    UIConfig.ShowKenzoSpeedBtn = KenzoSpeedFloatBtn.Visible; saveConfiguration()
end)

FloatKenzoJumpToggle.MouseButton1Click:Connect(function()
    if not KenzoJumpFloatBtn then
        KenzoJumpFloatBtn, KenzoJumpFloatTxt = createCircularFloatBtn("KenzoJumpFloatBtn", "🦘", "Jump", UDim2.new(0.85, 0, 0.84, 0))
        KenzoJumpFloatBtn.MouseButton1Click:Connect(function() toggleKenzoJump(); updateAllButtonTexts() end)
    end
    KenzoJumpFloatBtn.Visible = not KenzoJumpFloatBtn.Visible
    UIConfig.ShowKenzoJumpBtn = KenzoJumpFloatBtn.Visible; saveConfiguration()
end)

FloatDisableAllToggle.MouseButton1Click:Connect(function()
    if not DisableAllFloatBtn then
        DisableAllFloatBtn, DisableAllFloatTxt = createCircularFloatBtn("DisableAllFloatBtn", "🛑", "إقفال", UDim2.new(0.85, 0, 0.92, 0))
        DisableAllFloatBtn.MouseButton1Click:Connect(disableAllFeatures)
    end
    DisableAllFloatBtn.Visible = not DisableAllFloatBtn.Visible
    UIConfig.ShowDisableAllBtn = DisableAllFloatBtn.Visible; saveConfiguration()
end)

-- إنشاء الأزرار العائمة عند الحاجة، مع ربط كل زر بوظيفته الأصلية.
local function ensureFloatButton(key)
    if key == "Ghost" and not GhostFloatBtn then
        GhostFloatBtn, GhostFloatTxt = createCircularFloatBtn("GhostFloatBtn", "👻", "الاختفاء", UDim2.new(0.85, 0, 0.12, 0))
        GhostFloatBtn.MouseButton1Click:Connect(function() toggleGhostLogic(); updateAllButtonTexts() end)
    elseif key == "LayDown" and not LayDownFloatBtn then
        LayDownFloatBtn, LayDownFloatTxt = createCircularFloatBtn("LayDownFloatBtn", "🛌", "الاستلقاء", UDim2.new(0.85, 0, 0.20, 0))
        LayDownFloatBtn.MouseButton1Click:Connect(function() toggleLayDownLogic(); updateAllButtonTexts() end)
    elseif key == "BackFall" and not BackFallFloatBtn then
        BackFallFloatBtn, BackFallFloatTxt = createCircularFloatBtn("BackFallFloatBtn", "🌀", "السقوط", UDim2.new(0.85, 0, 0.28, 0))
        BackFallFloatBtn.MouseButton1Click:Connect(function() toggleBackFallLogic(); updateAllButtonTexts() end)
    elseif key == "Bomb" and not BombFloatBtn then
        BombFloatBtn, BombFloatTxt = createCircularFloatBtn("BombFloatBtn", "💣", "القنبلة", UDim2.new(0.85, 0, 0.36, 0))
        BombFloatBtn.MouseButton1Click:Connect(function() toggleBombState(); updateAllButtonTexts() end)
    elseif key == "FastBomb" and not FastBombFloatBtn then
        FastBombFloatBtn, FastBombFloatTxt = createCircularFloatBtn("FastBombFloatBtn", "⚡", "أسرع", UDim2.new(0.85, 0, 0.44, 0))
        FastBombFloatBtn.MouseButton1Click:Connect(function() toggleFastBombState(); updateAllButtonTexts() end)
    elseif key == "ClickTP" and not ClickTPFloatBtn then
        ClickTPFloatBtn, ClickTPFloatTxt = createCircularFloatBtn("ClickTPFloatBtn", "📍", "انتقال", UDim2.new(0.85, 0, 0.52, 0))
        ClickTPFloatBtn.MouseButton1Click:Connect(function() toggleClickTPState(); updateAllButtonTexts() end)
    elseif key == "Fly" and not FlyFloatBtn then
        FlyFloatBtn, FlyFloatTxt = createCircularFloatBtn("FlyFloatBtn", "✈", "طيران", UDim2.new(0.85, 0, 0.60, 0))
        FlyFloatBtn.MouseButton1Click:Connect(function() toggleZinoxFly(); updateAllButtonTexts() end)
    elseif key == "ZinoxSpeed" and not ZinoxSpeedFloatBtn then
        ZinoxSpeedFloatBtn, ZinoxSpeedFloatTxt = createCircularFloatBtn("ZinoxSpeedFloatBtn", "⚡", "CFrame", UDim2.new(0.85, 0, 0.68, 0))
        ZinoxSpeedFloatBtn.MouseButton1Click:Connect(function() toggleZinoxSpeed(); updateAllButtonTexts() end)
    elseif key == "KenzoSpeed" and not KenzoSpeedFloatBtn then
        KenzoSpeedFloatBtn, KenzoSpeedFloatTxt = createCircularFloatBtn("KenzoSpeedFloatBtn", "🏃", "Physics", UDim2.new(0.85, 0, 0.76, 0))
        KenzoSpeedFloatBtn.MouseButton1Click:Connect(function() toggleKenzoSpeed(); updateAllButtonTexts() end)
    elseif key == "KenzoJump" and not KenzoJumpFloatBtn then
        KenzoJumpFloatBtn, KenzoJumpFloatTxt = createCircularFloatBtn("KenzoJumpFloatBtn", "🦘", "Jump", UDim2.new(0.85, 0, 0.84, 0))
        KenzoJumpFloatBtn.MouseButton1Click:Connect(function() toggleKenzoJump(); updateAllButtonTexts() end)
    elseif key == "DisableAll" and not DisableAllFloatBtn then
        DisableAllFloatBtn, DisableAllFloatTxt = createCircularFloatBtn("DisableAllFloatBtn", "🛑", "إقفال", UDim2.new(0.85, 0, 0.92, 0))
        DisableAllFloatBtn.MouseButton1Click:Connect(disableAllFeatures)
    end
    local map = {
        Ghost = GhostFloatBtn, LayDown = LayDownFloatBtn, BackFall = BackFallFloatBtn,
        Bomb = BombFloatBtn, FastBomb = FastBombFloatBtn, ClickTP = ClickTPFloatBtn,
        Fly = FlyFloatBtn, ZinoxSpeed = ZinoxSpeedFloatBtn, KenzoSpeed = KenzoSpeedFloatBtn,
        KenzoJump = KenzoJumpFloatBtn, DisableAll = DisableAllFloatBtn
    }
    return map[key]
end

local function setAllFloatButtonsVisible(visible)
    local keys = {"Ghost", "LayDown", "BackFall", "Bomb", "FastBomb", "ClickTP", "Fly", "ZinoxSpeed", "KenzoSpeed", "KenzoJump", "DisableAll"}
    for _, key in ipairs(keys) do
        local button = ensureFloatButton(key)
        if button then button.Visible = visible end
    end
    UIConfig.ShowGhostBtn, UIConfig.ShowLayDownBtn, UIConfig.ShowBackFallBtn = visible, visible, visible
    UIConfig.ShowBombBtn, UIConfig.ShowFastBombBtn, UIConfig.ShowClickTPBtn = visible, visible, visible
    UIConfig.ShowFlyBtn, UIConfig.ShowZinoxSpeedBtn, UIConfig.ShowKenzoSpeedBtn = visible, visible, visible
    UIConfig.ShowKenzoJumpBtn, UIConfig.ShowDisableAllBtn = visible, visible
    saveConfiguration()
end

-- وظيفة إظهار وإخفاء جميع الأزرار العائمة
ShowAllFloatsBtn.MouseButton1Click:Connect(function()
    setAllFloatButtonsVisible(true)
end)

HideAllFloatsBtn.MouseButton1Click:Connect(function()
    setAllFloatButtonsVisible(false)
end)

-- =========================================================================
--  Tab 4: تخصيص أزرار البيسي (PC Keybinds System)
-- =========================================================================
local currentlyBindingKey = nil

local function triggerFeatureByName(featureKey)
    if featureKey == "Ghost" then toggleGhostLogic()
    elseif featureKey == "LayDown" then toggleLayDownLogic()
    elseif featureKey == "BackFall" then toggleBackFallLogic()
    elseif featureKey == "Bomb" then toggleBombState()
    elseif featureKey == "FastBomb" then toggleFastBombState()
    elseif featureKey == "ClickTP" then toggleClickTPState()
    elseif featureKey == "ZinoxFly" then toggleZinoxFly()
    elseif featureKey == "ZinoxSpeed" then toggleZinoxSpeed()
    elseif featureKey == "KenzoSpeed" then toggleKenzoSpeed()
    elseif featureKey == "KenzoJump" then toggleKenzoJump()
    elseif featureKey == "DisableAll" then disableAllFeatures()
    end
    updateAllButtonTexts()
end

local function createKeybindRow(parent, featureTitle, featureKey)
    local rowFrame = Instance.new("Frame", parent)
    rowFrame.Size = UDim2.new(1, 0, 0, UIConfig.ButtonHeight)
    rowFrame.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
    Instance.new("UICorner", rowFrame).CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke", rowFrame)
    stroke.Thickness = 1.5; stroke.Color = Color3.fromRGB(255, 255, 255)
    addAnimatedRedBlueStripes(rowFrame)

    local label = Instance.new("TextLabel", rowFrame)
    label.Size = UDim2.new(0.60, 0, 1, 0)
    label.Position = UDim2.new(0.03, 0, 0, 0)
    label.Text = featureTitle
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = Enum.Font.GothamBold; label.TextSize = 11
    label.BackgroundTransparency = 1; label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextStrokeTransparency = 0; label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

    local bindBtn, bindBtnTxt = createStyledButton(rowFrame, "")
    bindBtn.Size = UDim2.new(0.32, 0, 0.8, 0)
    bindBtn.Position = UDim2.new(0.65, 0, 0.1, 0)

    local function updateDisplay()
        local keyVal = UIConfig.Keybinds[featureKey] or "None"
        bindBtnTxt.Text = "[ " .. tostring(keyVal) .. " ]"
    end
    updateDisplay()

    bindBtn.MouseButton1Click:Connect(function()
        if currentlyBindingKey then return end
        currentlyBindingKey = featureKey
        bindBtnTxt.Text = "...اضغط زر"

        local conn
        conn = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Keyboard then
                if input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Delete or input.KeyCode == Enum.KeyCode.Escape then
                    UIConfig.Keybinds[featureKey] = "None"
                else
                    UIConfig.Keybinds[featureKey] = input.KeyCode.Name
                end
                saveConfiguration()
                updateDisplay()
                currentlyBindingKey = nil
                conn:Disconnect()
            end
        end)
    end)
end

-- إضافة الخيارات داخل تبويب الكيبورد
createKeybindRow(Tab4Page, "👻 زر الاختفاء FE Ghost:", "Ghost")
createKeybindRow(Tab4Page, "🛌 زر الاستلقاء والزحف:", "LayDown")
createKeybindRow(Tab4Page, "🌀 زر الانحناء والسقوط:", "BackFall")
createKeybindRow(Tab4Page, "💣 زر إعطاء القنبلة العادي:", "Bomb")
createKeybindRow(Tab4Page, "⚡ زر التمرير الأسرع للقنبلة:", "FastBomb")
createKeybindRow(Tab4Page, "📍 زر الانتقال بالنقر:", "ClickTP")
createKeybindRow(Tab4Page, "✈️ زر طيران ZINOX Fly:", "ZinoxFly")
createKeybindRow(Tab4Page, "⚡ زر سرعة CFrame Speed:", "ZinoxSpeed")
createKeybindRow(Tab4Page, "🏃 زر سرعة Physics Speed:", "KenzoSpeed")
createKeybindRow(Tab4Page, "🦘 زر قفز KENZO Jump:", "KenzoJump")
createKeybindRow(Tab4Page, "🛑 زر إقفال كافة المميزات:", "DisableAll")

-- الاستماع لضغطات الكيبورد العالمية
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or currentlyBindingKey then return end
    if input.UserInputType == Enum.UserInputType.Keyboard then
        local pressedKey = input.KeyCode
        if pressedKey == Enum.KeyCode.Unknown then return end

        for featName, boundKey in pairs(UIConfig.Keybinds) do
            if boundKey and boundKey ~= "None" and boundKey == pressedKey.Name then
                triggerFeatureByName(featName)
            end
        end
    end
end)

-- =========================================================================
--  Tab 5: التصميم والإعدادات
-- =========================================================================
local SliderTitle = Instance.new("TextLabel", Tab5Page)
SliderTitle.Size = UDim2.new(1, 0, 0, 18)
SliderTitle.BackgroundTransparency = 1
SliderTitle.Text = "📏 حجم الأزرار الفرعية: (" .. tostring(UIConfig.FloatBtnSize) .. ")"
SliderTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
SliderTitle.TextSize = 11; SliderTitle.Font = Enum.Font.GothamBold

local SliderFrame = Instance.new("Frame", Tab5Page)
SliderFrame.Size = UDim2.new(1, 0, 0, 26)
SliderFrame.BackgroundTransparency = 1

local SliderTrack = Instance.new("Frame", SliderFrame)
SliderTrack.Size = UDim2.new(1, 0, 0, 8)
SliderTrack.Position = UDim2.new(0, 0, 0.35, 0)
SliderTrack.BackgroundColor3 = Color3.fromRGB(34, 43, 62)
Instance.new("UICorner", SliderTrack).CornerRadius = UDim.new(1, 0)

local initialPercent = (UIConfig.FloatBtnSize - 5) / (100 - 5)
local SliderFill = Instance.new("Frame", SliderTrack)
SliderFill.Size = UDim2.new(initialPercent, 0, 1, 0)
SliderFill.BackgroundColor3 = Color3.fromRGB(255, 61, 93)
Instance.new("UICorner", SliderFill).CornerRadius = UDim.new(1, 0)

local SliderKnob = Instance.new("TextButton", SliderTrack)
SliderKnob.Size = UDim2.new(0, 16, 0, 16)
SliderKnob.Position = UDim2.new(initialPercent, -8, 0.5, -8)
SliderKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255); SliderKnob.Text = ""
Instance.new("UICorner", SliderKnob).CornerRadius = UDim.new(1, 0)

local isDraggingSlider = false
local function updateSlider(input)
    local sliderWidth = SliderTrack.AbsoluteSize.X
    local relativeX = math.clamp(input.Position.X - SliderTrack.AbsolutePosition.X, 0, sliderWidth)
    local percentage = relativeX / sliderWidth
    local calculatedValue = math.floor(5 + (percentage * (100 - 5)))

    SliderFill.Size = UDim2.new(percentage, 0, 1, 0)
    SliderKnob.Position = UDim2.new(percentage, -8, 0.5, -8)
    SliderTitle.Text = "📏 حجم الأزرار الفرعية: (" .. tostring(calculatedValue) .. ")"
    updateFloatingButtonsSize(calculatedValue)
end

SliderKnob.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then isDraggingSlider = true end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if isDraggingSlider then isDraggingSlider = false; saveConfiguration() end
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if isDraggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then updateSlider(input) end
end)

local ARGBTitle = Instance.new("TextLabel", Tab5Page)
ARGBTitle.Size = UDim2.new(1, 0, 0, 18)
ARGBTitle.BackgroundTransparency = 1
ARGBTitle.Text = "🎨 إدخال لون ARGB لخلفية القائمة:"
ARGBTitle.TextColor3 = Color3.fromRGB(220, 220, 230)
ARGBTitle.TextSize = 11; ARGBTitle.Font = Enum.Font.GothamBold

local ColorInputsFrame = Instance.new("Frame", Tab5Page)
ColorInputsFrame.Size = UDim2.new(1, 0, 0, 32)
ColorInputsFrame.BackgroundTransparency = 1

local function createARGBInput(placeholder, pos, defaultVal)
    local box = Instance.new("TextBox", ColorInputsFrame)
    box.Size = UDim2.new(0.22, 0, 1, 0); box.Position = pos
    box.BackgroundColor3 = Color3.fromRGB(28, 36, 52)
    box.Text = tostring(defaultVal); box.PlaceholderText = placeholder
    box.TextColor3 = Color3.fromRGB(255, 255, 255); box.TextSize = 11; box.Font = Enum.Font.GothamBold
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 8)
    return box
end

local RBox = createARGBInput("R", UDim2.new(0, 0, 0, 0), UIConfig.MainColorR)
local GBox = createARGBInput("G", UDim2.new(0.26, 0, 0, 0), UIConfig.MainColorG)
local BBox = createARGBInput("B", UDim2.new(0.52, 0, 0, 0), UIConfig.MainColorB)
local ABox = createARGBInput("A", UDim2.new(0.78, 0, 0, 0), UIConfig.Alpha)

local ApplyColorBtn = createStyledButton(Tab5Page, "💾 تطبيق وحفظ الألوان")
ApplyColorBtn.MouseButton1Click:Connect(function()
    UIConfig.MainColorR = math.clamp(tonumber(RBox.Text) or 15, 0, 255)
    UIConfig.MainColorG = math.clamp(tonumber(GBox.Text) or 18, 0, 255)
    UIConfig.MainColorB = math.clamp(tonumber(BBox.Text) or 28, 0, 255)
    UIConfig.Alpha = math.clamp(tonumber(ABox.Text) or 0.05, 0, 1)
    applyTheme()
    saveConfiguration()
end)

-- =========================================================================
--  9. استعادة الحالات المفعلة عند التشغيل
-- =========================================================================
updateFloatingButtonsSize(UIConfig.FloatBtnSize)

if UIConfig.GhostActive then toggleGhostLogic(true) end
if UIConfig.LayDownActive then toggleLayDownLogic(true) end
if UIConfig.BackFallActive then toggleBackFallLogic(true) end
if UIConfig.BombActive then toggleBombState(true) end
if UIConfig.FastBombActive then toggleFastBombState(true) end
if UIConfig.ClickTPActive then toggleClickTPState(true) end
if UIConfig.ZinoxFlyActive then toggleZinoxFly(true) end
if UIConfig.ZinoxSpeedActive then toggleZinoxSpeed(true) end
if UIConfig.KenzoSpeedActive then toggleKenzoSpeed(true) end
if UIConfig.KenzoJumpActive then toggleKenzoJump(true) end

local restoreFloatConfig = {
    {"Ghost", UIConfig.ShowGhostBtn}, {"LayDown", UIConfig.ShowLayDownBtn},
    {"BackFall", UIConfig.ShowBackFallBtn}, {"Bomb", UIConfig.ShowBombBtn},
    {"FastBomb", UIConfig.ShowFastBombBtn}, {"ClickTP", UIConfig.ShowClickTPBtn},
    {"Fly", UIConfig.ShowFlyBtn}, {"ZinoxSpeed", UIConfig.ShowZinoxSpeedBtn},
    {"KenzoSpeed", UIConfig.ShowKenzoSpeedBtn}, {"KenzoJump", UIConfig.ShowKenzoJumpBtn},
    {"DisableAll", UIConfig.ShowDisableAllBtn}
}
for _, item in ipairs(restoreFloatConfig) do
    if item[2] then
        local button = ensureFloatButton(item[1])
        if button then button.Visible = true end
    end
end

updateAllButtonTexts()

player.CharacterAdded:Connect(function()
    task.wait(0.5)
    pcall(function()
        if isFeGhostActive then
            isFeGhostActive = false
            if ghostLoopConn then ghostLoopConn:Disconnect() end
            if jumpConn then jumpConn:Disconnect() end
            if ghostModel then ghostModel:Destroy() end
            camera.CameraSubject = player.Character:WaitForChild("Humanoid", 5)
        end
        if isLyingDown then isLyingDown = false; if layDownConn then layDownConn:Disconnect() end end
        if isBackFallActive then isBackFallActive = false; if backFallConn then backFallConn:Disconnect() end end
        if Settings.Enabled then stopBombScript() end
        if MoveSettings.KenzoJumpActive then toggleKenzoJump(true) end
        updateAllButtonTexts()
    end)
end)

applyTheme()
print("✅ تم تشغيل واجهة KHZ7 PRO الجديدة بنجاح!")
