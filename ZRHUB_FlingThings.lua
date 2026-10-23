-- =============================================
-- ZRHUB Script
-- =============================================

-- Services
local Players        = game:GetService("Players")
local LocalPlayer    = Players.LocalPlayer
local CoreGui        = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui     = game:GetService("StarterGui")
local PS             = game:GetService("Players")
local RS             = game:GetService("ReplicatedStorage")
local R              = game:GetService("RunService")
local RunService     = R
local Workspace      = workspace

-- Player / World references
local Player         = PS.LocalPlayer
local Camera         = Workspace.CurrentCamera
local CE             = RS:WaitForChild("CharacterEvents", 10)
local BeingHeld      = Player:WaitForChild("IsHeld", 10)
local StruggleEvent  = CE and CE:WaitForChild("Struggle")

-- Load external libraries
loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))()

local repo        = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library     = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager  = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options  = Library.Options
local Toggles  = Library.Toggles
Library.ForceCheckbox = false

-- =============================================
-- UI Window & Tabs
-- =============================================

local Window = Library:CreateWindow({
    Title            = "ZR HUB ",
    Footer           = "Fling things and ppl",
    Icon             = "rbxthumb://type=Asset&id=129949624640047&w=150&h=150",
    NotifySide       = "Right",
    ShowCustomCursor = false,
})

local Tabs = {
    Defense       = Window:AddTab("defense",       "shield"),
    Target        = Window:AddTab("target",        "crosshair"),
    Grab          = Window:AddTab("grab",          "hand"),
    Player        = Window:AddTab("player",        "user"),
    Misc          = Window:AddTab("misc",          "layers"),
    Build         = Window:AddTab("build",         "box"),
    Fun           = Window:AddTab("fun",           "smile"),
    Keybinds      = Window:AddTab("keybinds",      "keyboard"),
    Notifications = Window:AddTab("notifications", "bell"),
    Auras         = Window:AddTab("auras",         "sparkles"),
    ["UI Settings"] = Window:AddTab("UI Settings", "settings"),
    Credits       = Window:AddTab("Credits",       "user"),
}

local CreditsBox = Tabs.Credits:AddLeftGroupbox("Credits", "user")
CreditsBox:AddLabel("Made by tung zo1os", true)
CreditsBox:AddButton({
    Text = "Copy Discord Link",
    Func = function()
        pcall(setclipboard, "https://discord.gg/TCuMcKy9j4")
        Library:Notify({ Title = "Copied!", Description = "Discord link copied.", Time = 3 })
    end,
})

-- =============================================
-- Global State Variables
-- =============================================

local blobMasterSwitch = false
local blobFlyActive    = false
local bvInstance       = nil
local bgInstance       = nil
local blobFlySpeed     = 100
local follow           = false
local autoResetEnabled = false

-- =============================================
-- Utility: Notify
-- =============================================

local function notify(title, content, duration)
    Library:Notify({
        Title       = title or "Notification",
        Description = content or "",
        Time        = duration or 5,
    })
end

-- =============================================
-- Startup: Send hub-loaded chat message
-- =============================================

local function sendHubLoadedMessage()
    local msg     = " Owner Version | ZRHUB Script loaded. "
    local success = false

    pcall(function()
        local chatEvents = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
        if chatEvents then
            local sayRequest = chatEvents:FindFirstChild("SayMessageRequest")
            if sayRequest and typeof(sayRequest.FireServer) == "function" then
                sayRequest:FireServer(msg, "All")
                success = true
            end
        end
    end)

    if not success then
        pcall(function()
            StarterGui:SetCore("ChatMakeSystemMessage", {
                Text     = msg,
                Color    = Color3.fromRGB(255, 170, 0),
                Font     = Enum.Font.SourceSansBold,
                FontSize = Enum.FontSize.Size18,
            })
        end)
    end
end

task.spawn(function()
    task.wait(1)
    sendHubLoadedMessage()
end)

-- =============================================
-- Paint Part Management (Anti Paint)
-- =============================================

local paintPartsBackup  = {}
local paintConnections  = {}

local function deleteAllPaintParts()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name == "PaintPlayerPart" then
            local clone = obj:Clone()
            clone.Archivable = true
            paintPartsBackup[obj:GetDebugId()] = { clone = clone, parent = obj.Parent }
            obj:Destroy()
        end
    end
end

local function restorePaintParts()
    for _, data in pairs(paintPartsBackup) do
        if data.clone and data.parent then
            data.clone.Parent = data.parent
        end
    end
    paintPartsBackup = {}
end

local function watchNewPaintParts()
    table.insert(paintConnections, Workspace.DescendantAdded:Connect(function(obj)
        if obj:IsA("BasePart") and obj.Name == "PaintPlayerPart" then
            task.defer(function()
                if obj and obj.Parent then
                    local clone = obj:Clone()
                    clone.Archivable = true
                    paintPartsBackup[obj:GetDebugId()] = { clone = clone, parent = obj.Parent }
                    obj:Destroy()
                end
            end)
        end
    end))
end

local function disconnectWatchers()
    for _, conn in ipairs(paintConnections) do
        if conn.Connected then conn:Disconnect() end
    end
    paintConnections = {}
end

local function setTouchQuery(state)
    local character = Workspace:FindFirstChild(Player.Name)
    if not character then return end
    for _, part in ipairs(character:GetChildren()) do
        if part:IsA("Part") or part:IsA("BasePart") then
            part.CanTouch = state
            part.CanQuery = state
        end
    end
end

-- =============================================
-- Anti-Gucci: Blobman
-- =============================================

local antiGucciConnection
local safePosition
local restoreFrames = 0

local function spawnBlobman()
    pcall(function()
        ReplicatedStorage.MenuToys.SpawnToyRemoteFunction:InvokeServer(
            "CreatureBlobman",
            CFrame.new(0, 5000000, 0),
            Vector3.new(0, 60, 0)
        )
    end)

    local folder = Workspace:WaitForChild(Player.Name .. "SpawnedInToys", 5)
    if folder and folder:FindFirstChild("CreatureBlobman") then
        local blob = folder.CreatureBlobman
        if blob:FindFirstChild("Head") then
            blob.Head.CFrame     = CFrame.new(0, 50000, 0)
            blob.Head.Anchored   = true
        end
        notify("Success", "Blobman Spawned!", 3)
    end
end

local function startAntiGucci()
    local character = Player.Character or Player.CharacterAdded:Wait()
    local humanoid  = character:WaitForChild("Humanoid")
    local rootPart  = character:WaitForChild("HumanoidRootPart")
    safePosition    = rootPart.Position

    local folder    = Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
    local blob      = folder and folder:FindFirstChild("CreatureBlobman")
    local seat      = blob and blob:FindFirstChild("VehicleSeat")

    if not blob then
        spawnBlobman()
        task.wait(1)
        folder = Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
        blob   = folder and folder:FindFirstChild("CreatureBlobman")
        seat   = blob and blob:FindFirstChild("VehicleSeat")
    end

    if seat and seat:IsA("VehicleSeat") then
        rootPart.CFrame = seat.CFrame + Vector3.new(0, 2, 0)
        seat:Sit(humanoid)
    end

    humanoid:GetPropertyChangedSignal("Jump"):Connect(function()
        if humanoid.Jump and humanoid.Sit then
            restoreFrames = 15
            safePosition  = rootPart.Position
        end
    end)

    if antiGucciConnection then antiGucciConnection:Disconnect() end

    antiGucciConnection = R.Heartbeat:Connect(function()
        if not rootPart or not humanoid then return end
        ReplicatedStorage.CharacterEvents.RagdollRemote:FireServer(rootPart, 0)
        if restoreFrames > 0 then
            rootPart.CFrame = CFrame.new(safePosition)
            restoreFrames   = restoreFrames - 1
        end
    end)

    task.spawn(function()
        while humanoid.Sit do task.wait(1) end
        task.wait(0.5)
        rootPart.CFrame = CFrame.new(safePosition)
    end)
end

local function stopAntiGucci()
    if antiGucciConnection then
        antiGucciConnection:Disconnect()
        antiGucciConnection = nil
    end
    local blobFolder = Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
    if blobFolder and blobFolder:FindFirstChild("CreatureBlobman") then
        blobFolder.CreatureBlobman:Destroy()
    end
end

-- =============================================
-- Anti-Gucci: Train
-- =============================================

local antiGucciConnectionTrain
local safePositionTrain
local restoreFramesTrain = 0

local function startAntiGucciTrain()
    local character = Player.Character or Player.CharacterAdded:Wait()
    local humanoid  = character:WaitForChild("Humanoid")
    local rootPart  = character:WaitForChild("HumanoidRootPart")
    safePositionTrain = rootPart.Position

    local tweenedObjects = workspace.Map.AlwaysHereTweenedObjects
    local train  = tweenedObjects and tweenedObjects:FindFirstChild("Train")
    local seat

    if train then
        for _, desc in ipairs(train:GetDescendants()) do
            if desc:IsA("Seat") then
                seat = desc
                break
            end
        end
    end

    if seat then
        rootPart.CFrame = seat.CFrame + Vector3.new(0, 2, 0)
        seat:Sit(humanoid)
    end

    humanoid:GetPropertyChangedSignal("Jump"):Connect(function()
        if humanoid.Jump and humanoid.Sit then
            restoreFramesTrain = 15
            safePositionTrain  = rootPart.Position
        end
    end)

    if antiGucciConnectionTrain then antiGucciConnectionTrain:Disconnect() end

    antiGucciConnectionTrain = R.Heartbeat:Connect(function()
        if not rootPart or not humanoid then return end
        ReplicatedStorage.CharacterEvents.RagdollRemote:FireServer(rootPart, 0)
        if restoreFramesTrain > 0 then
            rootPart.CFrame    = CFrame.new(safePositionTrain)
            restoreFramesTrain = restoreFramesTrain - 1
        end
    end)

    task.spawn(function()
        while humanoid.Sit do task.wait(1) end
        task.wait(0.5)
        rootPart.CFrame = CFrame.new(safePositionTrain)
    end)
end

local function stopAntiGucciTrain()
    if antiGucciConnectionTrain then
        antiGucciConnectionTrain:Disconnect()
        antiGucciConnectionTrain = nil
    end
end

-- =============================================
-- Defense Tab UI
-- =============================================

local DefenseGroup = Tabs.Defense:AddLeftGroupbox("Defense Main")
local DefenseExtra = Tabs.Defense:AddRightGroupbox("Extra Defense")

-- Anti-Grab internals
local antiGrabExplosionConn, antiGrabHeldConn, antiGrabStruggleConn, antiGrabHumConn, antiGrabAnchorConn
local antiGrabRootCF, antiGrabRootPos, antiGrabHardFreeze = nil, nil, false

local function antiGrabUnfreeze(character)
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if rootPart then
        rootPart.Anchored = false
        if rootPart:FindFirstChild("FreezeJoint") then
            rootPart.FreezeJoint:Destroy()
        end
    end
    antiGrabHardFreeze = false
    if antiGrabAnchorConn then
        antiGrabAnchorConn:Disconnect()
        antiGrabAnchorConn = nil
    end
end

local function antiGrabFreezeInPlace(character)
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    antiGrabRootCF    = rootPart.CFrame
    antiGrabRootPos   = rootPart.Position
    antiGrabHardFreeze = true

    if not rootPart:FindFirstChild("FreezeJoint") then
        local alignPos = Instance.new("AlignPosition")
        alignPos.Name             = "FreezeJoint"
        alignPos.Mode             = Enum.PositionAlignmentMode.OneAttachment
        alignPos.MaxForce         = 1e6
        alignPos.MaxVelocity      = 0
        alignPos.Responsiveness   = 200
        local attachment          = Instance.new("Attachment", rootPart)
        alignPos.Attachment0      = attachment
        alignPos.Position         = antiGrabRootPos
        alignPos.Parent           = rootPart
    end

    antiGrabAnchorConn = R.Heartbeat:Connect(function()
        if antiGrabHardFreeze and rootPart then
            rootPart.AssemblyLinearVelocity  = Vector3.zero
            rootPart.AssemblyAngularVelocity = Vector3.zero
            rootPart.CFrame                  = antiGrabRootCF
        end
    end)
end

local function antiGrabReconnect()
    local character = Player.Character or Player.CharacterAdded:Wait()
    local humanoid  = character:WaitForChild("Humanoid")
    local rootPart  = character:WaitForChild("HumanoidRootPart")

    local firePlayerPart = rootPart:FindFirstChild("FirePlayerPart")
    if firePlayerPart then firePlayerPart:Destroy() end

    if antiGrabHumConn then antiGrabHumConn:Disconnect() end

    antiGrabHumConn = humanoid.Changed:Connect(function(property)
        if property == "Sit" and humanoid.Sit then
            if not (humanoid.SeatPart and tostring(humanoid.SeatPart.Parent) == "CreatureBlobman") then
                humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
                humanoid.Sit = false
            end
        end
    end)
end

-- Anti-Grab toggle
local autoStruggleConn = nil

DefenseGroup:AddToggle("AntiGrabObsidian", {
    Text    = "Anti Grab",
    Default = false,
    Callback = function(enabled)
        local RS2 = game:GetService("RunService")
        local RS3 = game:GetService("ReplicatedStorage")
        local lp  = game:GetService("Players").LocalPlayer
        local struggleEvent = RS3:FindFirstChild("CharacterEvents")
            and RS3.CharacterEvents:FindFirstChild("Struggle")

        if enabled then
            if autoStruggleConn then autoStruggleConn:Disconnect() end

            autoStruggleConn = RS2.Heartbeat:Connect(function()
                local character = lp.Character
                if character and character:FindFirstChild("Head") then
                    local head = character.Head
                    if head:FindFirstChild("PartOwner") then
                        task.spawn(function()
                            if struggleEvent then struggleEvent:FireServer(lp) end
                            pcall(function()
                                RS3.GameCorrectionEvents.StopAllVelocity:FireServer()
                            end)
                            for _, part in pairs(character:GetChildren()) do
                                if part:IsA("BasePart") then part.Anchored = true end
                            end
                            local isHeld = lp:FindFirstChild("IsHeld")
                            while isHeld and isHeld.Value do task.wait() end
                            for _, part in pairs(character:GetChildren()) do
                                if part:IsA("BasePart") then part.Anchored = false end
                            end
                        end)
                    end
                end
            end)
        else
            if autoStruggleConn then
                autoStruggleConn:Disconnect()
                autoStruggleConn = nil
            end
            local character = lp.Character
            if character then
                for _, part in pairs(character:GetChildren()) do
                    if part:IsA("BasePart") then part.Anchored = false end
                end
            end
        end
    end,
})

-- Anti-Blobman
local antiBlob1T = false
local function antiBlob1F()
    antiBlob1T = true
    workspace.DescendantAdded:Connect(function(obj)
        if obj.Name == "CreatureBlobman" and antiBlob1T then
            obj.LeftDetector:Destroy()
            obj.RightDetector:Destroy()
        end
    end)
end

DefenseGroup:AddToggle("AntiBlobmanToggle", {
    Text    = "Anti Blobman",
    Default = false,
    Callback = function(on)
        if on then antiBlob1F() else antiBlob1T = false end
    end,
})

-- Anti-Explosion
local antiExplodeT = false
local function antiExplodeF()
    antiExplodeT = true
    local character = Player.Character
    if not character then return end
    local rootPart = character:WaitForChild("HumanoidRootPart")

    workspace.ChildAdded:Connect(function(part)
        if part.Name == "Part" and antiExplodeT then
            local dist = (part.Position - rootPart.Position).Magnitude
            if dist <= 20 then
                rootPart.Anchored = true
                wait(0.01)
                while character["Right Arm"].RagdollLimbPart.CanCollide do
                    wait(0.001)
                end
                rootPart.Anchored = false
            end
        end
    end)
end

DefenseGroup:AddToggle("AntiExplosionToggle", {
    Text    = "Anti Explosion",
    Default = false,
    Callback = function(on)
        if on then antiExplodeF() else antiExplodeT = false end
    end,
})

-- Anti-Burn
local hookBurnConn
local function hookBurn(character)
    local humanoid = character:WaitForChild("Humanoid")
    local rootPart = character:WaitForChild("HumanoidRootPart")
    character.PrimaryPart = rootPart

    if hookBurnConn then hookBurnConn:Disconnect() end

    hookBurnConn = humanoid.FireDebounce.Changed:Connect(function(isBurning)
        if isBurning then
            local savedCFrame = rootPart.CFrame
            local plots = workspace:FindFirstChild("Plots")
            if plots and plots:FindFirstChild("Plot2") then
                local plot2   = plots.Plot2
                local barrier = plot2:FindFirstChild("Barrier")
                local plotBarrier = barrier and barrier:FindFirstChild("PlotBarrier")
                if plotBarrier and plotBarrier:IsA("BasePart") then
                    local safeSpot = plotBarrier.CFrame * CFrame.new(0, 6, 0)
                    character:SetPrimaryPartCFrame(safeSpot)
                    task.wait(0.3)
                    local firePlayerPart = character:FindFirstChild("FirePlayerPart", true)
                    if firePlayerPart then
                        for _, obj in ipairs(firePlayerPart:GetChildren()) do
                            if obj:IsA("Sound") then obj:Stop() end
                            if obj:IsA("Light") or obj:IsA("ParticleEmitter") then obj.Enabled = false end
                        end
                        if firePlayerPart:FindFirstChild("CanBurn") then
                            firePlayerPart.CanBurn.Value = false
                        end
                        if humanoid:FindFirstChild("FireDebounce") then
                            humanoid.FireDebounce.Value = false
                        end
                    end
                    task.wait(0.6)
                    if character and character.PrimaryPart then
                        character:SetPrimaryPartCFrame(savedCFrame)
                    end
                end
            end
        end
    end)
end

DefenseGroup:AddToggle("AntiBurnToggle", {
    Text    = "Anti Burn",
    Default = false,
    Callback = function(on)
        if on then
            hookBurn(Player.Character)
        elseif hookBurnConn then
            hookBurnConn:Disconnect()
        end
    end,
})

-- Anti-Void
local antiVoidConn
local VOID_THRESHOLD = -50
local SAFE_HEIGHT    = 100

DefenseGroup:AddToggle("AntiVoidToggle", {
    Text    = "Anti Void",
    Default = false,
    Callback = function(on)
        if on then
            if antiVoidConn then antiVoidConn:Disconnect() end
            antiVoidConn = R.Heartbeat:Connect(function()
                local character = Player.Character
                if character and character.PrimaryPart then
                    local pos = character.PrimaryPart.Position
                    if pos.Y < VOID_THRESHOLD then
                        character:SetPrimaryPartCFrame(
                            CFrame.new(Vector3.new(pos.X, pos.Y + SAFE_HEIGHT, pos.Z))
                        )
                        character.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
                    end
                end
            end)
        else
            if antiVoidConn then
                antiVoidConn:Disconnect()
                antiVoidConn = nil
            end
        end
    end,
})

-- Anti-Sticky
DefenseGroup:AddToggle("AntiStickyToggle", {
    Text    = "Anti Sticky",
    Default = false,
    Callback = function(enabled)
        local script = Player.PlayerScripts:FindFirstChild("StickyPartsTouchDetection")
        if script then script.Disabled = enabled end
    end,
})

-- Anti-Lag (disable grab-line events)
local createGrabLineCopy, extendGrabLineCopy
local grabEvents = ReplicatedStorage:FindFirstChild("GrabEvents")
if grabEvents then
    local origCreate = grabEvents:FindFirstChild("CreateGrabLine")
    local origExtend = grabEvents:FindFirstChild("ExtendGrabLine")
    if origCreate then createGrabLineCopy = origCreate:Clone() end
    if origExtend then extendGrabLineCopy = origExtend:Clone() end
end

DefenseGroup:AddToggle("AntiLagToggle", {
    Text    = "Anti Lag",
    Default = false,
    Callback = function(enabled)
        if enabled then
            local ge = ReplicatedStorage:FindFirstChild("GrabEvents")
            if ge then
                local createLine = ge:FindFirstChild("CreateGrabLine")
                local extendLine = ge:FindFirstChild("ExtendGrabLine")
                if createLine and createLine:IsA("RemoteEvent") then createLine:Destroy() end
                if extendLine and extendLine:IsA("RemoteEvent") then extendLine:Destroy() end
            end
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("Beam") or obj.Name:lower():find("line") then
                    obj:Destroy()
                end
            end
        else
            local ge = ReplicatedStorage:FindFirstChild("GrabEvents")
            if ge then
                if createGrabLineCopy and not ge:FindFirstChild("CreateGrabLine") then
                    createGrabLineCopy:Clone().Parent = ge
                end
                if extendGrabLineCopy and not ge:FindFirstChild("ExtendGrabLine") then
                    extendGrabLineCopy:Clone().Parent = ge
                end
            end
        end
    end,
})

-- Anti-Paint
DefenseExtra:AddToggle("PaintDeleteToggle", {
    Text    = "Anti Paint",
    Default = false,
    Callback = function(on)
        if on then
            deleteAllPaintParts()
            watchNewPaintParts()
            setTouchQuery(false)
        else
            restorePaintParts()
            disconnectWatchers()
            setTouchQuery(true)
        end
    end,
})

-- Anti-Gucci (Blobman)
local autoGucciActive = false

DefenseExtra:AddToggle("AutoGucciToggle", {
    Text    = "Anti Gucci (Blobman)",
    Default = false,
    Callback = function(enabled)
        autoGucciActive = enabled
        if enabled then
            startAntiGucci()
            notify("system", "auto gucci active", 3)
            task.spawn(function()
                while autoGucciActive do
                    local tf = Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
                    if not (tf and tf:FindFirstChild("CreatureBlobman")) then
                        stopAntiGucci()
                        spawnBlobman()
                        notify("System", "blobman lost", 3)
                        local retries = 0
                        repeat
                            task.wait(0.2)
                            retries = retries + 1
                            tf = Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
                        until (tf and tf:FindFirstChild("CreatureBlobman")) or retries > 25 or not autoGucciActive
                        if autoGucciActive and tf and tf:FindFirstChild("CreatureBlobman") then
                            startAntiGucci()
                            notify("System", "blobman restored.", 3)
                        end
                    end
                    task.wait(0.5)
                end
            end)
        else
            autoGucciActive = false
            stopAntiGucci()
            notify("System", "auto gucci disabled.", 3)
        end
    end,
})

-- Anti-Gucci (Train)
local autoGucciActiveTrain = false

DefenseExtra:AddToggle("AutoGucciToggleTrain", {
    Text    = "Anti Gucci (Train)",
    Default = false,
    Callback = function(enabled)
        autoGucciActiveTrain = enabled
        if enabled then
            startAntiGucciTrain()
            notify("system", "Gucci active", 3)
            task.spawn(function()
                while autoGucciActiveTrain do
                    local tweened = workspace.Map.AlwaysHereTweenedObjects
                    if not (tweened and tweened:FindFirstChild("Train")) then
                        stopAntiGucciTrain()
                        notify("System", "Train lost", 3)
                        local retries = 0
                        repeat
                            task.wait(0.2)
                            retries = retries + 1
                            tweened = workspace.Map.AlwaysHereTweenedObjects
                        until (tweened and tweened:FindFirstChild("Train")) or retries > 25 or not autoGucciActiveTrain
                        if autoGucciActiveTrain and tweened and tweened:FindFirstChild("Train") then
                            startAntiGucciTrain()
                            notify("System", "Train restored.", 3)
                        end
                    end
                    task.wait(0.5)
                end
            end)
        else
            autoGucciActiveTrain = false
            stopAntiGucciTrain()
            notify("System", "Gucci disabled.", 3)
        end
    end,
})

-- =============================================
-- Toy List & Anti-Input-Lag
-- =============================================

local ToyList = {
    ["Coconut"]    = "FoodCoconut",       ["Banana"]    = "FoodBanana",
    ["Fries"]      = "FoodFrenchFries",   ["MeatStick"] = "FoodMeatStick",
    ["Poop"]       = "PoopPile",          ["Donut"]     = "FoodDonut",
    ["Cake"]       = "FoodCakePink",      ["Burger"]    = "FoodHamburger",
    ["Pizza"]      = "FoodPizzaCheese",   ["Hotdog"]    = "FoodHotdog",
    ["Mushroom"]   = "FoodMushroomPoison",["Banjo"]     = "InstrumentGuitarBanjo",
    ["Violin"]     = "InstrumentGuitarViolin",
    ["Ukulele"]    = "InstrumentGuitarUkulele",
    ["Sax"]        = "InstrumentWoodwindSaxophone",
    ["Vuvuzela"]   = "InstrumentBrassVuvuzela",
    ["Bongos"]     = "InstrumentDrumBongos",
    ["Mic"]        = "InstrumentVoiceMicrophone",
    ["Pepperoni"]  = "FoodPizzaPepperoni",["Piano"]     = "InstrumentPianoMelodica",
    ["Bread"]      = "FoodBread",         ["Egg"]       = "FoodDippyEgg",
    ["Mayo"]       = "FoodMayonnaise",    ["WhiteMug"]  = "CupMugWhite",
    ["Ocarina"]    = "InstrumentWoodwindOcarina",
    ["SparklePoop"]= "PoopPileSparkle",   ["BrownMug"]  = "CupMugBrown",
    ["Trumpet"]    = "InstrumentBrassTrumpet",
    ["Snare"]      = "InstrumentDrumSnare",
}

local dropdownValues = {}
for name, _ in pairs(ToyList) do table.insert(dropdownValues, name) end
table.sort(dropdownValues)
local SelectedToy = ToyList[dropdownValues[1]]

DefenseExtra:AddDropdown("AntiInputLagToy", {
    Text    = "Input Lag Item",
    Values  = dropdownValues,
    Default = 1,
    Callback = function(value)
        SelectedToy = ToyList[value]
    end,
})

DefenseExtra:AddToggle("AntiInputLag", {
    Text    = "Anti Input Lag",
    Default = false,
    Callback = function(enabled)
        _G.AntiInputLag = enabled
        if enabled then
            task.spawn(function()
                local p         = Players.LocalPlayer
                local character = p.Character or p.CharacterAdded:Wait()
                local rootPart  = character:WaitForChild("HumanoidRootPart")
                local spawnRemote = ReplicatedStorage:WaitForChild("MenuToys"):WaitForChild("SpawnToyRemoteFunction")

                while _G.AntiInputLag do
                    local toyFolder = Workspace:FindFirstChild(p.Name .. "SpawnedInToys")
                    if not toyFolder then task.wait(0.1) continue end

                    local toy = toyFolder:FindFirstChild(SelectedToy)
                    if not toy then
                        pcall(function()
                            spawnRemote:InvokeServer(SelectedToy, rootPart.CFrame * CFrame.new(0, 5, 0), Vector3.zero)
                        end)
                        local t0 = tick()
                        repeat
                            RunService.Heartbeat:Wait()
                            toyFolder = Workspace:FindFirstChild(p.Name .. "SpawnedInToys")
                            toy = toyFolder and toyFolder:FindFirstChild(SelectedToy)
                        until toy or tick() - t0 > 1 or not _G.AntiInputLag
                    end

                    if toy and toy.Parent then
                        local holdPart = toy:FindFirstChild("HoldPart")
                        if holdPart then
                            local holdingPlayer = holdPart:FindFirstChild("HoldingPlayer")
                            holdingPlayer = holdingPlayer and holdingPlayer.Value
                            if holdingPlayer and holdingPlayer ~= p then
                                pcall(function()
                                    holdPart.DropItemRemoteFunction:InvokeServer(
                                        toy, rootPart.CFrame * CFrame.new(0, 2000, 0), Vector3.zero
                                    )
                                end)
                                toy:Destroy()
                            else
                                pcall(function()
                                    holdPart.HoldItemRemoteFunction:InvokeServer(toy, character)
                                end)
                                task.wait(0.05)
                                pcall(function()
                                    holdPart.DropItemRemoteFunction:InvokeServer(
                                        toy, rootPart.CFrame * CFrame.new(0, 2000, 0), Vector3.zero
                                    )
                                end)
                                task.wait(0.01)
                            end
                        end
                    end

                    RunService.Heartbeat:Wait()
                end
            end)
        end
    end,
})

-- Loop TP
local tpActive = false

DefenseExtra:AddToggle("LoopTP", {
    Text    = "Loop TP",
    Default = false,
    Callback = function(enabled)
        tpActive = enabled
        local character = Player.Character or Player.CharacterAdded:Wait()
        local rootPart  = character:WaitForChild("HumanoidRootPart")
        local humanoid  = character:FindFirstChildOfClass("Humanoid")
        if enabled then
            if humanoid then humanoid.PlatformStand = true end
            task.spawn(function()
                while tpActive and rootPart do
                    rootPart.CFrame = CFrame.new(
                        math.random(-500, 500),
                        math.random(30, 480),
                        math.random(-500, 500)
                    )
                    task.wait(0.03)
                end
            end)
        else
            if humanoid then humanoid.PlatformStand = false end
        end
    end,
})

-- Anti-Kick (Shuriken)
DefenseExtra:AddToggle("ShurikenAntiKick", {
    Text    = "Anti Kick",
    Default = false,
    Callback = function(enabled)
        _G.ShurikenAntiKick = enabled

        local function ClearKunai()
            local p   = game.Players.LocalPlayer
            local inv = workspace:FindFirstChild(p.Name .. "SpawnedInToys")
            local destroyRemote = game.ReplicatedStorage:FindFirstChild("MenuToys")
                and game.ReplicatedStorage.MenuToys:FindFirstChild("DestroyToy")
            if inv and destroyRemote then
                for _, v in pairs(inv:GetChildren()) do
                    if v.Name == "AntiKick" or v.Name == "NinjaShuriken" then
                        pcall(function() destroyRemote:FireServer(v) end)
                    end
                end
            end
        end

        if enabled then
            task.spawn(function()
                local p              = game.Players.LocalPlayer
                local setNetOwner    = ReplicatedStorage:WaitForChild("GrabEvents"):WaitForChild("SetNetworkOwner")
                local stickyEvent    = ReplicatedStorage:WaitForChild("PlayerEvents"):WaitForChild("StickyPartEvent")
                local spawnRemote    = ReplicatedStorage.MenuToys.SpawnToyRemoteFunction
                local destroyRemote  = ReplicatedStorage:WaitForChild("MenuToys"):WaitForChild("DestroyToy")
                local canSpawn       = p:WaitForChild("CanSpawnToy")

                local function getRoot()
                    if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                        return p.Character.HumanoidRootPart
                    end
                    return p.CharacterAdded:Wait():WaitForChild("HumanoidRootPart")
                end

                local function checkForPlot()
                    if not workspace.PlotItems.PlayersInPlots:FindFirstChild(p.Name) then return false end
                    for _, plot in pairs(workspace.Plots:GetChildren()) do
                        local sign   = plot:FindFirstChild("PlotSign")
                        local owners = sign and sign:FindFirstChild("ThisPlotsOwners")
                        if owners then
                            for _, b in pairs(owners:GetChildren()) do
                                if b.Value == p.Name then
                                    local folder = workspace.PlotItems:FindFirstChild(plot.Name)
                                    if folder then return true, folder end
                                end
                            end
                        end
                    end
                    return false
                end

                local function stickKunai(kunai)
                    if not kunai or not kunai:FindFirstChild("StickyPart") then return end
                    local root = getRoot()
                    if not root then return end
                    if kunai:FindFirstChild("SoundPart") then
                        if not kunai.SoundPart:FindFirstChild("PartOwner")
                            or kunai.SoundPart.PartOwner.Value ~= p.Name then
                            setNetOwner:FireServer(kunai.SoundPart, kunai.SoundPart.CFrame)
                        end
                    end
                    local firePlayerPart = root:FindFirstChild("FirePlayerPart")
                        or root:WaitForChild("FirePlayerPart", 5)
                    if firePlayerPart then
                        stickyEvent:FireServer(
                            kunai.StickyPart, firePlayerPart,
                            CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(90), math.rad(90))
                        )
                    end
                    for _, obj in pairs(kunai:GetChildren()) do
                        if obj.Name == "Pyramid" then
                            obj.CanTouch = false obj.CanCollide = false obj.CanQuery = false
                            obj.Transparency = 0
                            if not obj:FindFirstChild("Highlight") then
                                local h = Instance.new("Highlight", obj)
                                h.FillColor = Color3.fromRGB(0, 0, 0)
                            end
                        elseif obj.Name == "Main" then
                            obj.CanTouch = false obj.CanCollide = false obj.CanQuery = false
                            obj.Transparency = 0
                            if not obj:FindFirstChild("Highlight") then
                                local h = Instance.new("Highlight", obj)
                                h.FillColor = Color3.fromRGB(255, 255, 255)
                            end
                        elseif obj:IsA("BasePart") then
                            obj.CanTouch = false obj.CanCollide = false
                            obj.CanQuery = false obj.Transparency = 1
                        end
                    end
                end

                local function spawnToy(toyName)
                    local t = tick()
                    while not canSpawn.Value do
                        if not _G.ShurikenAntiKick or tick() - t > 5 then return nil end
                        task.wait(0.1)
                    end
                    local root = getRoot()
                    if root then
                        task.spawn(function()
                            pcall(function()
                                spawnRemote:InvokeServer(toyName, root.CFrame * CFrame.new(0, 12, 20), Vector3.new(0, 0, 0))
                            end)
                        end)
                    end
                    local inPlot, plotStore = checkForPlot()
                    local inv = workspace:FindFirstChild(p.Name .. "SpawnedInToys")
                    if inPlot and plotStore then
                        return plotStore:WaitForChild(toyName, 2)
                    elseif not workspace.PlotItems.PlayersInPlots:FindFirstChild(p.Name) and inv then
                        return inv:WaitForChild(toyName, 2)
                    end
                    return nil
                end

                -- Main anti-kick loop
                while _G.ShurikenAntiKick do
                    task.wait(0.005)
                    if not p.Character
                        or not p.Character:FindFirstChild("Humanoid")
                        or p.Character.Humanoid.Health <= 0 then continue end

                    local inv   = workspace:FindFirstChild(p.Name .. "SpawnedInToys")
                    local kunai = inv and inv:FindFirstChild("NinjaShuriken")

                    if workspace.PlotItems.PlayersInPlots:FindFirstChild(p.Name) then
                        local inPlot, plotStore = checkForPlot()
                        if inPlot and plotStore and workspace.Plots:FindFirstChild(plotStore.Name) then
                            local sign = workspace.Plots[plotStore.Name]:FindFirstChild("PlotSign")
                            if sign and sign.ThisPlotsOwners.Value.TimeRemainingNum.Value > 89 then
                                kunai = spawnToy("NinjaShuriken")
                                if kunai == nil then continue end
                                kunai.Name = "AntiKick"
                                stickKunai(kunai)
                            end
                        end
                    end

                    if not kunai then
                        if workspace.PlotItems.PlayersInPlots:FindFirstChild(p.Name) then continue end
                        kunai = spawnToy("NinjaShuriken")
                        if kunai == nil then continue end
                        kunai.Name = "AntiKick"
                        if not kunai then continue end
                    end

                    repeat
                        if kunai and kunai:FindFirstChild("StickyPart")
                            and kunai.StickyPart.CanTouch == true then
                            stickKunai(kunai)
                            kunai.Name = "AntiKick"
                        end
                        task.wait(0.3)
                    until not kunai
                        or not _G.ShurikenAntiKick
                        or not kunai:FindFirstChild("StickyPart")
                        or kunai.StickyPart.CanTouch == false
                        or not p.Character
                        or not p.Character:FindFirstChild("HumanoidRootPart")
                        or (p.Character.HumanoidRootPart.Position - kunai.StickyPart.Position).Magnitude >= 20

                    if not kunai
                        or not kunai:FindFirstChild("StickyPart")
                        or not p.Character
                        or not p.Character:FindFirstChild("HumanoidRootPart")
                        or (p.Character.HumanoidRootPart.Position - kunai.StickyPart.Position).Magnitude >= 20 then
                        ClearKunai()
                    end

                    pcall(function()
                        repeat task.wait(0.05)
                        until not _G.ShurikenAntiKick
                            or not p.Character
                            or not p.Character:FindFirstChild("Humanoid")
                            or not kunai
                            or not kunai:FindFirstChild("StickyPart")
                            or not kunai.StickyPart:FindFirstChild("StickyWeld")
                            or not kunai.StickyPart.StickyWeld.Part1

                        if not kunai
                            or not kunai:FindFirstChild("StickyPart")
                            or (p.Character and p.Character:FindFirstChild("Humanoid")
                                and p.Character.Humanoid.Health <= 0)
                            or not kunai["StickyPart"]:FindFirstChild("StickyWeld").Part1 then
                            ClearKunai()
                        end
                    end)
                end
            end)
        else
            _G.ShurikenAntiKick = false
            ClearKunai()
        end
    end,
})

-- =============================================
-- Target Tab
-- =============================================

local TargetGroup    = Tabs.Target:AddLeftGroupbox("Target Interaction")
local BlobGroup      = Tabs.Target:AddRightGroupbox("Blobman Kick")
local WhitelistGroup = Tabs.Target:AddRightGroupbox("whitelist")

local selectedKickPlayer = nil
local kickLoopEnabled    = false

local function getPlayerList()
    local list = {}
    for _, p in ipairs(PS:GetPlayers()) do
        if p ~= Player then
            table.insert(list, p.DisplayName .. " (" .. p.Name .. ")")
        end
    end
    return list
end

local function getPlayerFromSelection(selection)
    if not selection then return nil end
    local username = selection:match("%((.-)%)")
    if username then return PS:FindFirstChild(username) end
    return nil
end

TargetGroup:AddDropdown("KickPlayerDropdown", {
    Values   = getPlayerList(),
    Default  = 1,
    Multi    = false,
    Text     = "select player for kick",
    Callback = function(value)
        selectedKickPlayer = getPlayerFromSelection(value)
    end,
})

TargetGroup:AddButton({
    Text = "refresh player list",
    Func = function()
        Options.KickPlayerDropdown:SetValues(getPlayerList())
        Options.KickPlayerDropdown:SetValue(nil)
        selectedKickPlayer = nil
    end,
})

-- Kick: spam grab
TargetGroup:AddToggle("LoopKickGrabToggle1", {
    Text    = "Kick (spam grab)",
    Default = false,
    Callback = function(on)
        kickLoopEnabled = on
        if not on then return end
        task.spawn(function()
            local GE       = RS:WaitForChild("GrabEvents")
            local mc       = Player.Character
            local mr       = mc and mc:FindFirstChild("HumanoidRootPart")
            if not mr then Toggles.LoopKickGrabToggle1:SetValue(false) return end
            local savedPos = mr.CFrame
            local dropping = false
            local grabTime = 0

            while kickLoopEnabled do
                local target = selectedKickPlayer
                if not target or not target.Parent then break end
                mc = Player.Character
                mr = mc and mc:FindFirstChild("HumanoidRootPart")
                if not mr then break end
                local tc  = target.Character
                local tr  = tc and tc:FindFirstChild("HumanoidRootPart")
                local th  = tc and tc:FindFirstChild("Humanoid")
                if tr and th and th.Health > 0 then
                    tr.AssemblyLinearVelocity  = Vector3.zero
                    tr.AssemblyAngularVelocity = Vector3.zero
                    tr.Velocity                = Vector3.zero
                    if not dropping then
                        mr.CFrame   = tr.CFrame
                        mr.Velocity = Vector3.zero
                        pcall(function()
                            th.PlatformStand = true th.Sit = true
                            GE.SetNetworkOwner:FireServer(tr, mr.CFrame)
                            GE.CreateGrabLine:FireServer(tr, Vector3.zero, tr.Position, false)
                        end)
                        if grabTime == 0 then grabTime = tick() end
                        if tick() - grabTime > 0.35 then dropping = true grabTime = 0 end
                    else
                        mr.CFrame   = savedPos
                        mr.Velocity = Vector3.zero
                        local launchPos = savedPos * CFrame.new(0, 17, 0)
                        tr.CFrame   = launchPos
                        tr.Velocity = Vector3.zero tr.RotVelocity = Vector3.zero
                        pcall(function()
                            th.PlatformStand = true th.Sit = false
                            GE.SetNetworkOwner:FireServer(tr, launchPos)
                            GE.DestroyGrabLine:FireServer(tr)
                            GE.CreateGrabLine:FireServer(tr, Vector3.zero, tr.Position, false)
                        end)
                    end
                else
                    dropping = false grabTime = 0
                end
                RunService.Heartbeat:Wait()
            end

            if mr then mr.CFrame = savedPos mr.Velocity = Vector3.zero end
            kickLoopEnabled = false
            Toggles.LoopKickGrabToggle1:SetValue(false)
        end)
    end,
})

-- Ragdoll Snowball
TargetGroup:AddToggle("RagdollSnowballKick", {
    Text    = "Ragdoll Snowball",
    Default = false,
    Callback = function(on)
        local spawnRemote = RS:WaitForChild("MenuToys"):WaitForChild("SpawnToyRemoteFunction")
        local running     = on
        task.spawn(function()
            while running do
                local target = selectedKickPlayer
                if not target or not target.Parent then RunService.Heartbeat:Wait() continue end
                local tc     = target.Character
                local torso  = tc and (tc:FindFirstChild("UpperTorso") or tc:FindFirstChild("Torso"))
                if not torso then RunService.Heartbeat:Wait() continue end
                pcall(function()
                    spawnRemote:InvokeServer(
                        "BallSnowball",
                        torso.CFrame * CFrame.new(Vector3.new(
                            math.random(-30, 30) / 100,
                            math.random(-30, 30) / 100,
                            math.random(-30, 30) / 100
                        )),
                        Vector3.zero
                    )
                end)
                local folder = Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
                if folder then
                    for _, snowball in pairs(folder:GetChildren()) do
                        if snowball.Name == "BallSnowball" and snowball.Parent then
                            local part = snowball.PrimaryPart or snowball:FindFirstChildWhichIsA("BasePart")
                            if part then
                                part.CFrame = torso.CFrame * CFrame.new(Vector3.new(
                                    math.random(-30, 30) / 100,
                                    math.random(-30, 30) / 100,
                                    math.random(-30, 30) / 100
                                ))
                                part.AssemblyLinearVelocity  = Vector3.zero
                                part.AssemblyAngularVelocity = Vector3.zero
                            end
                        end
                    end
                end
                RunService.Heartbeat:Wait()
            end
        end)
    end,
})

-- Kick: ragdoll grab
TargetGroup:AddToggle("LoopKickGrabToggle2", {
    Text    = "Kick (ragdoll grab)",
    Default = false,
    Callback = function(on)
        kickLoopEnabled = on
        if not on then return end
        task.spawn(function()
            local GE       = RS:WaitForChild("GrabEvents")
            local C        = Player.Character or Player.CharacterAdded:Wait()
            local mr       = C:FindFirstChild("HumanoidRootPart")
            if not mr then Toggles.LoopKickGrabToggle2:SetValue(false) return end
            local savedPos = mr.CFrame
            local dropping = false
            local grabStart = 0

            while kickLoopEnabled do
                local target = selectedKickPlayer
                if not target or not target.Parent then break end
                local tc = target.Character
                local tr = tc and tc:FindFirstChild("HumanoidRootPart")
                local th = tc and tc:FindFirstChild("Humanoid")
                if tr and th and th.Health > 0 then
                    tr.AssemblyLinearVelocity  = Vector3.zero
                    tr.AssemblyAngularVelocity = Vector3.zero
                    tr.Velocity                = Vector3.zero
                    if not dropping then
                        mr.CFrame = tr.CFrame
                        pcall(function()
                            th.PlatformStand = true th.Sit = true
                            GE.SetNetworkOwner:FireServer(tr, mr.CFrame)
                            GE.CreateGrabLine:FireServer(tr, Vector3.zero, tr.Position, false)
                        end)
                        if grabStart == 0 then grabStart = tick() end
                        if tick() - grabStart > 0.15 then
                            dropping = true grabStart = 0 mr.CFrame = savedPos
                        end
                    else
                        local randomCF = CFrame.new(savedPos.Position + Vector3.new(0, 7, 0))
                            * CFrame.Angles(
                                math.rad(math.random(-180, 180)),
                                math.rad(math.random(-180, 180)),
                                math.rad(math.random(-180, 180))
                            )
                        tr.CFrame       = tr.CFrame:Lerp(randomCF, 0.2)
                        tr.Velocity     = Vector3.zero
                        tr.RotVelocity  = Vector3.zero
                        pcall(function()
                            th.PlatformStand = true th.Sit = false
                            GE.SetNetworkOwner:FireServer(tr, tr.CFrame)
                            GE.DestroyGrabLine:FireServer(tr)
                            GE.CreateGrabLine:FireServer(tr, Vector3.zero, tr.Position, false)
                        end)
                    end
                else
                    dropping = false grabStart = 0
                end
                RunService.Heartbeat:Wait()
            end

            if mr then mr.CFrame = savedPos mr.Velocity = Vector3.zero end
            kickLoopEnabled = false
            Toggles.LoopKickGrabToggle2:SetValue(false)
        end)
    end,
})

-- Helper: is player ragdolled?
local function IsRagdolled(humanoid)
    local ragdolled = humanoid and humanoid:FindFirstChild("Ragdolled")
    return ragdolled ~= nil and ragdolled.Value == true
end

-- Grab Troll
TargetGroup:AddToggle("GrabTrollToggle", {
    Text    = "Grab Troll (spam grab)",
    Default = false,
    Callback = function(on)
        kickLoopEnabled = on
        if not on then return end
        task.spawn(function()
            local GE       = RS:WaitForChild("GrabEvents")
            local mc       = Player.Character
            local mr       = mc and mc:FindFirstChild("HumanoidRootPart")
            if not mr then Toggles.GrabTrollToggle:SetValue(false) return end
            local savedPos = mr.CFrame
            local dropping = false
            local grabTime = 0

            while kickLoopEnabled do
                local target = selectedKickPlayer
                if not target or not target.Parent then break end
                mc = Player.Character
                mr = mc and mc:FindFirstChild("HumanoidRootPart")
                if not mr then break end
                local tc = target.Character
                local tr = tc and tc:FindFirstChild("HumanoidRootPart")
                local th = tc and tc:FindFirstChild("Humanoid")
                if tr and th and th.Health > 0 then
                    tr.AssemblyLinearVelocity  = Vector3.zero
                    tr.AssemblyAngularVelocity = Vector3.zero
                    tr.Velocity                = Vector3.zero
                    if not dropping then
                        mr.CFrame   = tr.CFrame
                        mr.Velocity = Vector3.zero
                        pcall(function()
                            th.PlatformStand = true th.Sit = true
                            GE.SetNetworkOwner:FireServer(tr, mr.CFrame)
                            GE.CreateGrabLine:FireServer(tr, Vector3.zero, tr.Position, false)
                        end)
                        if grabTime == 0 then grabTime = tick()
                        elseif tick() - grabTime > 0.35 then dropping = true grabTime = 0 end
                    else
                        if not IsRagdolled(th) then
                            dropping = false grabTime = 0
                            pcall(function() GE.DestroyGrabLine:FireServer(tr) end)
                            RunService.Heartbeat:Wait()
                            continue
                        end
                        mr.CFrame   = savedPos mr.Velocity = Vector3.zero
                        local launchPos = savedPos * CFrame.new(0, 17, 0)
                        tr.CFrame   = launchPos tr.Velocity = Vector3.zero tr.RotVelocity = Vector3.zero
                        pcall(function()
                            th.PlatformStand = true th.Sit = false
                            GE.SetNetworkOwner:FireServer(tr, launchPos)
                            GE.DestroyGrabLine:FireServer(tr)
                            GE.CreateGrabLine:FireServer(tr, Vector3.zero, tr.Position, false)
                        end)
                    end
                else
                    dropping = false grabTime = 0
                end
                RunService.Heartbeat:Wait()
            end

            if mr then mr.CFrame = savedPos mr.Velocity = Vector3.zero end
            kickLoopEnabled = false
            Toggles.GrabTrollToggle:SetValue(false)
        end)
    end,
})

-- Loop Kick (grab + blobman)
TargetGroup:AddToggle("LoopKickToggle", {
    Text    = "Loop Kick (grab + blob)",
    Default = false,
    Callback = function(on)
        kickLoopEnabled = on
        local target    = selectedKickPlayer
        if on and not target then
            if Toggles.LoopKickToggle then Toggles.LoopKickToggle:SetValue(false) end
            return
        end
        local character = Player.Character
        local humanoid  = character and character:FindFirstChild("Humanoid")
        local seat      = humanoid and humanoid.SeatPart
        if on and (not seat or seat.Parent.Name ~= "CreatureBlobman") then
            if Toggles.LoopKickToggle then Toggles.LoopKickToggle:SetValue(false) end
            return
        end
        if not on then kickLoopEnabled = false return end

        task.spawn(function()
            local GE       = RS:WaitForChild("GrabEvents")
            local blob     = seat.Parent
            local blobRoot = blob:FindFirstChild("HumanoidRootPart") or blob.PrimaryPart
            local script   = blob:FindFirstChild("BlobmanSeatAndOwnerScript")
            local CG       = script and script:FindFirstChild("CreatureGrab")
            local CD       = script and script:FindFirstChild("CreatureDrop")
            local RD       = blob:FindFirstChild("RightDetector")
            local RW       = RD and (RD:FindFirstChild("RightWeld") or RD:FindFirstChildWhichIsA("Weld"))
            local savedPos = blobRoot.CFrame
            local tc       = target.Character
            local tr       = tc and tc:FindFirstChild("HumanoidRootPart")

            if tr and blobRoot then
                local grabStart = tick()
                while tick() - grabStart < 0.35 do
                    if not kickLoopEnabled then break end
                    blobRoot.CFrame   = tr.CFrame
                    blobRoot.Velocity = Vector3.zero
                    pcall(function()
                        if CG and RD then CG:FireServer(RD, tr, RW) end
                        GE.CreateGrabLine:FireServer(tr, Vector3.zero, tr.Position, false)
                        GE.SetNetworkOwner:FireServer(tr, blobRoot.CFrame)
                    end)
                    RunService.Heartbeat:Wait()
                end
                blobRoot.CFrame   = savedPos
                blobRoot.Velocity = Vector3.zero
                task.wait(0.05)
            end

            local lastPcall = 0
            while kickLoopEnabled do
                if not target or not target.Parent or not target.Character then break end
                tc = target.Character
                tr = tc and tc:FindFirstChild("HumanoidRootPart")
                local th = tc and tc:FindFirstChild("Humanoid")
                if tr and th and th.Health > 0 and blobRoot then
                    blobRoot.CFrame   = savedPos
                    blobRoot.Velocity = Vector3.zero
                    local launchPos   = savedPos * CFrame.new(0, 23, 0)
                    tr.CFrame         = launchPos tr.Velocity = Vector3.zero tr.RotVelocity = Vector3.zero
                    if tick() - lastPcall > 0.05 then
                        lastPcall = tick()
                        pcall(function()
                            th.PlatformStand = true th.Sit = true
                            GE.SetNetworkOwner:FireServer(tr, launchPos)
                            if RD then
                                local w = RD:FindFirstChild("RightWeld") or RD:FindFirstChildWhichIsA("Weld")
                                if w then CD:FireServer(w) end
                            end
                            GE.DestroyGrabLine:FireServer(tr)
                            if RD then CG:FireServer(RD, tr, RW) end
                            GE.CreateGrabLine:FireServer(tr, Vector3.zero, tr.Position, false)
                        end)
                    end
                else
                    blobRoot.CFrame   = savedPos
                    blobRoot.Velocity = Vector3.zero
                end
                if not kickLoopEnabled then break end
                RunService.Heartbeat:Wait()
            end

            kickLoopEnabled = false
            if Toggles.LoopKickToggle then Toggles.LoopKickToggle:SetValue(false) end
            if blobRoot then blobRoot.CFrame = savedPos blobRoot.Velocity = Vector3.zero end
        end)
    end,
})

-- Dual-Hand Loop Kick
local loopKickDualActive = false

TargetGroup:AddToggle("DualHandLoopKick", {
    Text    = "Loop Kick",
    Default = false,
    Callback = function(on)
        loopKickDualActive = on
        if on then
            if not selectedKickPlayer then
                notify("Error", "Select target first", 3)
                Toggles.DualHandLoopKick:SetValue(false)
                return
            end
            task.spawn(function()
                local lastCharacter  = nil
                local bodyPos = nil

                while loopKickDualActive do
                    local target    = selectedKickPlayer
                    local character = Player.Character
                    local humanoid  = character and character:FindFirstChild("Humanoid")
                    local seat      = humanoid and humanoid.SeatPart

                    if not seat or not target or not target.Parent then
                        task.wait(0.5)
                        continue
                    end

                    local blob = seat.Parent
                    local grabScript = blob:FindFirstChild("BlobmanSeatAndOwnerScript")
                    local grabRemote = grabScript and grabScript:FindFirstChild("CreatureGrab")
                    local dropRemote = grabScript and grabScript:FindFirstChild("CreatureDrop")
                    if not grabRemote or not dropRemote then task.wait(0.5) continue end

                    local LD  = blob:FindFirstChild("LeftDetector")
                    local RD  = blob:FindFirstChild("RightDetector")
                    local LW  = LD and LD:FindFirstChild("LeftWeld")
                    local RW  = RD and RD:FindFirstChild("RightWeld")
                    local root = character:FindFirstChild("HumanoidRootPart")
                    local tc   = target.Character
                    local th   = tc and tc:FindFirstChild("HumanoidRootPart")
                    local tm   = tc and tc:FindFirstChild("Humanoid")

                    if th and tm and tm.Health > 0 then
                        if tc ~= lastCharacter then
                            lastCharacter = tc
                            if bodyPos then bodyPos:Destroy() bodyPos = nil end
                            if root then root.CFrame = th.CFrame * CFrame.new(0, 25, 0) end
                            task.wait(0.2)
                            grabRemote:FireServer(LD, th, LW)
                            task.wait(0.3)
                            dropRemote:FireServer(LW, th)
                            task.wait(0.1)
                            bodyPos          = Instance.new("BodyPosition")
                            bodyPos.Position = Vector3.new(0, 999999, 0)
                            bodyPos.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                            bodyPos.Parent   = th
                            grabRemote:FireServer(LD, th, LW)
                            task.wait(0.2)
                            dropRemote:FireServer(LW, th)
                        end
                        grabRemote:FireServer(LD, th, LW) task.wait()
                        dropRemote:FireServer(LW, th)     task.wait()
                        grabRemote:FireServer(RD, th, RW) task.wait()
                        dropRemote:FireServer(RW, th)     task.wait()
                        grabRemote:FireServer(LD, th, LW)
                        grabRemote:FireServer(RD, th, RW) task.wait()
                        dropRemote:FireServer(LW, th)
                        dropRemote:FireServer(RW, th)     task.wait()
                    else
                        task.wait(0.1)
                    end
                end

                if bodyPos then bodyPos:Destroy() end
            end)
        else
            loopKickDualActive = false
        end
    end,
})

-- Fling
local playerFlingActive = false
local flingBAV          = nil
local originalPos       = nil

TargetGroup:AddToggle("PlayerFlingBtn", {
    Text    = "Fling",
    Default = false,
    Callback = function(on)
        playerFlingActive = on
        if on then
            if not selectedKickPlayer then
                notify("System", "Select target first!", 3)
                Toggles.PlayerFlingBtn:SetValue(false)
                return
            end
            local mc = Player.Character
            local mr = mc and mc:FindFirstChild("HumanoidRootPart")
            if mr then originalPos = mr.CFrame end
            notify("Maestro", "Fling Mode Activated.", 3)

            task.spawn(function()
                while playerFlingActive do
                    local target = selectedKickPlayer
                    local c  = Player.Character
                    local h  = c and c:FindFirstChild("HumanoidRootPart")
                    local hm = c and c:FindFirstChild("Humanoid")
                    if not h or not hm then task.wait(0.5) continue end

                    if target and target.Parent then
                        local tc = target.Character
                        local tr = tc and tc:FindFirstChild("HumanoidRootPart")
                        local tm = tc and tc:FindFirstChild("Humanoid")
                        if tr and tm and tm.Health > 0 then
                            if not flingBAV or flingBAV.Parent ~= h then
                                if flingBAV then flingBAV:Destroy() end
                                flingBAV                = Instance.new("BodyAngularVelocity")
                                flingBAV.Name           = "MaestroSpin"
                                flingBAV.MaxTorque      = Vector3.new(math.huge, math.huge, math.huge)
                                flingBAV.AngularVelocity = Vector3.new(0, 10000, 0)
                                flingBAV.P              = 10000
                                flingBAV.Parent         = h
                            end
                            for _, part in pairs(c:GetDescendants()) do
                                if part:IsA("BasePart") then part.CanCollide = false end
                            end
                            local conn = RunService.Heartbeat:Connect(function()
                                if not playerFlingActive or not tr or not tr.Parent then return end
                                h.CFrame   = tr.CFrame
                                h.Velocity = Vector3.zero
                            end)
                            local startTime = tick()
                            while tick() - startTime < 1.5 do
                                if not playerFlingActive or not tr.Parent then break end
                                task.wait(0.1)
                            end
                            conn:Disconnect()
                        else
                            task.wait(0.2)
                        end
                    else
                        playerFlingActive = false
                        Toggles.PlayerFlingBtn:SetValue(false)
                    end
                    task.wait(0.1)
                end

                if flingBAV then flingBAV:Destroy() flingBAV = nil end
                local c = Player.Character
                if c then
                    for _, part in pairs(c:GetDescendants()) do
                        if part:IsA("BasePart") then part.CanCollide = true end
                    end
                    local h = c:FindFirstChild("HumanoidRootPart")
                    if h then
                        h.RotVelocity = Vector3.zero
                        h.Velocity    = Vector3.zero
                        if originalPos then h.CFrame = originalPos end
                    end
                end
            end)
        else
            playerFlingActive = false
            if flingBAV then flingBAV:Destroy() flingBAV = nil end
            local c = Player.Character
            local h = c and c:FindFirstChild("HumanoidRootPart")
            if h then h.RotVelocity = Vector3.zero h.Velocity = Vector3.zero end
        end
    end,
})

-- Auto-Sit on Blobman (T key)
UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.T and _G.AutoSitBlobT then
        local p    = game.Players.LocalPlayer
        local c    = p.Character
        local h    = c and c:FindFirstChild("HumanoidRootPart")
        local hm   = c and c:FindFirstChild("Humanoid")
        if not h or not hm then return end

        local folderName = p.Name .. "SpawnedInToys"
        local folder     = workspace:FindFirstChild(folderName)
        local blob       = folder and folder:FindFirstChild("CreatureBlobman")

        if not blob then
            task.spawn(function()
                pcall(function()
                    game.ReplicatedStorage.MenuToys.SpawnToyRemoteFunction:InvokeServer(
                        "CreatureBlobman", h.CFrame, Vector3.zero
                    )
                end)
            end)
            if not folder then folder = workspace:WaitForChild(folderName, 5) end
            if folder then blob = folder:WaitForChild("CreatureBlobman", 5) end
        end

        if blob then
            local seat = blob:WaitForChild("VehicleSeat", 5)
            if seat then
                local t = tick()
                repeat
                    if not hm.SeatPart then
                        h.CFrame   = seat.CFrame + Vector3.new(0, 1, 0)
                        h.Velocity = Vector3.zero
                        seat:Sit(hm)
                    end
                    RunService.Heartbeat:Wait()
                until hm.SeatPart == seat or tick() - t > 1.5
            end
        end
    end
end)

-- Blobman Fly toggle (R key)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.R then
        if blobMasterSwitch then
            blobFlyActive = not blobFlyActive
            if not blobFlyActive then
                if bvInstance then bvInstance:Destroy() bvInstance = nil end
                if bgInstance then bgInstance:Destroy() bgInstance = nil end
            end
        end
    end
end)

local function GetBlobRoot()
    local c  = Player.Character
    local hm = c and c:FindFirstChild("Humanoid")
    if hm and hm.SeatPart and hm.SeatPart.Parent
        and hm.SeatPart.Parent.Name == "CreatureBlobman" then
        return hm.SeatPart.Parent:FindFirstChild("HumanoidRootPart")
            or hm.SeatPart.Parent.PrimaryPart
    end
    local folder = workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
    if folder then
        local blob = folder:FindFirstChild("CreatureBlobman")
        if blob then return blob:FindFirstChild("HumanoidRootPart") or blob.PrimaryPart end
    end
    return nil
end

-- Blobman Fly heartbeat
RunService.Heartbeat:Connect(function()
    if not blobFlyActive or not blobMasterSwitch then
        if bvInstance then bvInstance:Destroy() bvInstance = nil end
        if bgInstance then bgInstance:Destroy() bgInstance = nil end
        return
    end
    local root = GetBlobRoot()
    if root then
        if not root:FindFirstChild("BlobFlyVelocity") then
            bvInstance              = Instance.new("BodyVelocity")
            bvInstance.Name         = "BlobFlyVelocity"
            bvInstance.MaxForce     = Vector3.new(math.huge, math.huge, math.huge)
            bvInstance.P            = 10000
            bvInstance.Parent       = root
        else bvInstance = root.BlobFlyVelocity end

        if not root:FindFirstChild("BlobFlyGyro") then
            bgInstance          = Instance.new("BodyGyro")
            bgInstance.Name     = "BlobFlyGyro"
            bgInstance.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            bgInstance.P        = 20000
            bgInstance.D        = 100
            bgInstance.Parent   = root
        else bgInstance = root.BlobFlyGyro end

        local cam = workspace.CurrentCamera
        local dir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W)           then dir = dir + cam.CFrame.LookVector  end
        if UserInputService:IsKeyDown(Enum.KeyCode.S)           then dir = dir - cam.CFrame.LookVector  end
        if UserInputService:IsKeyDown(Enum.KeyCode.A)           then dir = dir - cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D)           then dir = dir + cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space)       then dir = dir + Vector3.new(0, 1, 0)  end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0, 1, 0)  end

        if bvInstance then bvInstance.Velocity = dir * blobFlySpeed end
        if bgInstance then bgInstance.CFrame   = cam.CFrame end
    else
        if bvInstance then bvInstance:Destroy() bvInstance = nil end
        if bgInstance then bgInstance:Destroy() bgInstance = nil end
    end
end)

-- Destroy Target Gucci
local DestroyTargetGucciActive = false

TargetGroup:AddToggle("DestroyTargetGucci", {
    Text    = "Destroy Gucci (sit)",
    Default = false,
    Callback = function(enabled)
        DestroyTargetGucciActive = enabled
        if enabled then
            if not selectedKickPlayer then
                notify("Error", "Error", 3)
                Toggles.DestroyTargetGucci:SetValue(false)
                return
            end
            local c    = Player.Character
            local rt   = c and c:FindFirstChild("HumanoidRootPart")
            if not rt then return end
            local savedCF    = rt.CFrame
            local folderName = selectedKickPlayer.Name .. "SpawnedInToys"
            notify("System", "spawn toy " .. folderName, 3)

            task.spawn(function()
                while DestroyTargetGucciActive do
                    if not selectedKickPlayer or not selectedKickPlayer.Parent then
                        DestroyTargetGucciActive = false
                        Toggles.DestroyTargetGucci:SetValue(false)
                        break
                    end
                    local tf = workspace:FindFirstChild(folderName)
                    if not tf then
                        task.wait(1)
                    else
                        for _, obj in ipairs(tf:GetChildren()) do
                            if not DestroyTargetGucciActive then break end
                            if obj.Name == "CreatureBlobman" then
                                local vehicleSeat = obj:FindFirstChild("VehicleSeat")
                                    or obj:FindFirstChildWhichIsA("VehicleSeat", true)
                                if vehicleSeat then
                                    local mc = Player.Character
                                    local mr = mc and mc:FindFirstChild("HumanoidRootPart")
                                    local mh = mc and mc:FindFirstChild("Humanoid")
                                    if mr and mh and mh.SeatPart ~= vehicleSeat then
                                        local conn = RunService.Stepped:Connect(function()
                                            if mr and vehicleSeat then
                                                mr.CFrame   = vehicleSeat.CFrame
                                                mr.Velocity = Vector3.zero
                                                if obj.PrimaryPart then
                                                    obj.PrimaryPart.Velocity    = Vector3.zero
                                                    obj.PrimaryPart.RotVelocity = Vector3.zero
                                                end
                                            end
                                        end)
                                        local startTime = tick()
                                        while tick() - startTime < 1 do
                                            if not DestroyTargetGucciActive or mh.SeatPart == vehicleSeat then break end
                                            vehicleSeat:Sit(mh)
                                            task.wait()
                                        end
                                        conn:Disconnect()
                                        if mh.SeatPart == vehicleSeat then
                                            task.wait(0.3)
                                            mh.Sit  = false
                                            mh.Jump = true
                                            task.wait(0.05)
                                            mr.CFrame   = savedCF
                                            mr.Velocity = Vector3.zero
                                            notify("Success", "gucci has removed", 1)
                                            task.wait(0.5)
                                        else
                                            mr.CFrame = savedCF
                                        end
                                    end
                                end
                            end
                        end
                    end
                    task.wait(1)
                end
            end)
        else
            DestroyTargetGucciActive = false
            notify("System", "remove Gucci off", 2)
        end
    end,
})

-- Bring target (Blobman)
TargetGroup:AddButton({
    Text = "bring",
    Func = function()
        if not selectedKickPlayer then return end
        local c   = Player.Character
        local hm  = c and c:FindFirstChild("Humanoid")
        local seat = hm and hm.SeatPart
        if not seat or seat.Parent.Name ~= "CreatureBlobman" then return end
        local blob     = seat.Parent
        local blobRoot = blob:FindFirstChild("HumanoidRootPart")
        local script   = blob:FindFirstChild("BlobmanSeatAndOwnerScript")
        if not blobRoot or not script then return end
        local CG = script:FindFirstChild("CreatureGrab")
        local CD = script:FindFirstChild("CreatureDrop")
        local RD = blob:FindFirstChild("RightDetector")
        local RW = RD and RD:FindFirstChild("RightWeld")
        local tc = selectedKickPlayer.Character
        local tr = tc and tc:FindFirstChild("HumanoidRootPart")
        if not tr then return end

        local savedCF      = blobRoot.CFrame
        blobRoot.CFrame    = tr.CFrame
        blobRoot.Velocity  = Vector3.new()
        blobRoot.RotVelocity = Vector3.new()
        task.wait(0.3)
        pcall(function() CG:FireServer(RD, tr, RW) end)
        task.wait(0.5)
        blobRoot.CFrame    = savedCF
        blobRoot.Velocity  = Vector3.new()
        blobRoot.RotVelocity = Vector3.new()
        task.wait(0.05)

        for _ = 1, 12 do
            tr.CFrame       = savedCF * CFrame.new(0, 3, 0)
            tr.Velocity     = Vector3.new()
            tr.RotVelocity  = Vector3.new()
            task.wait(0.03)
        end
        for _ = 1, 8 do
            local weld = RD:FindFirstChild("RightWeld")
            if weld then pcall(function() CD:FireServer(weld) end) end
            task.wait(0.03)
        end
    end,
})

-- Remove Anti Input Lag
local AllowedItems = {
    FoodHamburger=true, FoodCoconut=true, FoodPizzaCheese=true, FoodPizzaPepperoni=true,
    FoodHotdog=true, FoodMushroomPoison=true, FoodBread=true, FoodDippyEgg=true,
    FoodMayonnaise=true, FoodFrenchFries=true, FoodMeatStick=true, FoodDonut=true,
    FoodCakePink=true, InstrumentGuitarBanjo=true, InstrumentGuitarViolin=true,
    InstrumentGuitarUkulele=true, InstrumentWoodwindSaxophone=true, InstrumentWoodwindOcarina=true,
    InstrumentBrassVuvuzelaQwizik=true, InstrumentBrassTrumpet=true, InstrumentDrumBongos=true,
    InstrumentDrumSnare=true, InstrumentPianoMelodica=true, InstrumentVoiceMicrophone=true,
    CupMugWhite=true, CupMugBrown=true, PoopPile=true, PoopPileSparkle=true,
}

local antiAntiLagEnabled = false

TargetGroup:AddToggle("RemoveAntiInputLag", {
    Text    = "Remove Anti Input Lag",
    Default = false,
    Callback = function(on)
        antiAntiLagEnabled = on
        if not on then return end
        task.spawn(function()
            local p    = game.Players.LocalPlayer
            local c    = p.Character
            local h    = c:FindFirstChild("HumanoidRootPart")
            if not h then return end

            local bag = {}
            for _, v in ipairs(workspace:GetDescendants()) do
                if AllowedItems[v.Name] and v:IsA("Model") and v:FindFirstChild("HoldPart") then
                    bag[#bag + 1] = v
                end
            end

            workspace.DescendantAdded:Connect(function(obj)
                if AllowedItems[obj.Name] and obj:IsA("Model") then
                    task.spawn(function()
                        local hp = obj:WaitForChild("HoldPart", 3)
                        if hp then bag[#bag + 1] = obj end
                    end)
                end
            end)

            while antiAntiLagEnabled do
                for i = #bag, 1, -1 do
                    local b = bag[i]
                    if not b or not b.Parent or not b:FindFirstChild("HoldPart") then
                        table.remove(bag, i)
                    else
                        local hp = b.HoldPart
                        pcall(function() hp.HoldItemRemoteFunction:InvokeServer(b, c) end)
                        task.wait()
                        pcall(function()
                            hp.DropItemRemoteFunction:InvokeServer(
                                b, CFrame.new(h.Position + Vector3.new(0, -2000, 0)), Vector3.new(0, 0, 0)
                            )
                        end)
                    end
                end
                task.wait()
            end
        end)
    end,
})

-- Whitelist dropdown
WhitelistGroup:AddDropdown("MultiWhitelist", {
    Values   = getPlayerList(),
    Default  = {},
    Multi    = true,
    Text     = "whitelist people",
})

WhitelistGroup:AddButton({
    Text = "refresh List",
    Func = function() Options.MultiWhitelist:SetValues(getPlayerList()) end,
})

-- Target-joined notifications
local notifyActive     = false
local notifyConnection = nil

WhitelistGroup:AddToggle("JoinedNotifyBtn", {
    Text    = "Target Joined Notify",
    Default = false,
    Callback = function(on)
        notifyActive = on
        if on then
            notify("Radar", "Tracking has enable...", 3)
            if notifyConnection then notifyConnection:Disconnect() end
            notifyConnection = PS.PlayerAdded:Connect(function(newPlayer)
                if not notifyActive then return end
                local detected = false
                local reason   = ""
                local whitelist = Options.MultiWhitelist.Value
                for entry, isOn in pairs(whitelist) do
                    if isOn then
                        local name = entry:match("%((.-)%)")
                        if name == newPlayer.Name then
                            detected = true reason = "[Whitelist]" break
                        end
                    end
                end
                if not detected and Options.KickPlayerDropdown and Options.KickPlayerDropdown.Value then
                    local target = Options.KickPlayerDropdown.Value:match("%((.-)%)")
                    if target and target == newPlayer.Name then
                        detected = true reason = "[Main Target]"
                    end
                end
                if detected then
                    notify("detected", reason .. " detected: " .. newPlayer.Name, 8)
                    local sound = Instance.new("Sound", workspace)
                    sound.SoundId = "rbxassetid://4590662766"
                    sound.Volume  = 2
                    sound:Play()
                    game:GetService("Debris"):AddItem(sound, 3)
                end
            end)
        else
            if notifyConnection then notifyConnection:Disconnect() notifyConnection = nil end
            notify("Radar", "Tracking Disabled", 2)
        end
    end,
})

-- Remove Anti-Kick (targeted)
local antiAntiKickActive = false

TargetGroup:AddToggle("DestroyAntiKickToggle", {
    Text    = "Remove Anti Kick",
    Default = false,
    Callback = function(enabled)
        antiAntiKickActive = enabled
        if enabled then
            task.spawn(function()
                local SN = RS.GrabEvents.SetNetworkOwner
                while antiAntiKickActive do
                    local target = selectedKickPlayer
                    if target then
                        local folder = workspace:FindFirstChild(target.Name .. "SpawnedInToys")
                        if folder then
                            for _, toyName in ipairs({"NinjaKunai", "NinjaShuriken", "AntiKick"}) do
                                local toy = folder:FindFirstChild(toyName)
                                if toy then
                                    local soundPart = toy:FindFirstChild("SoundPart")
                                    if soundPart then
                                        pcall(function() SN:FireServer(soundPart, soundPart.CFrame) end)
                                        if soundPart:FindFirstChild("PartOwner")
                                            and soundPart.PartOwner.Value == Player.Name then
                                            soundPart.CFrame = CFrame.new(0, 1000, 0)
                                        end
                                    end
                                end
                            end
                        end
                    end
                    task.wait(0.1)
                end
            end)
        end
    end,
})

-- =============================================
-- Auras Tab
-- =============================================

local AurasGroup = Tabs.Auras:AddLeftGroupbox("Auras")

local removeAntiKickAuraActive     = false
local removeAntiKickAuraConnection = nil
local removeAntiKickRadius         = 15
local useWhitelistRemoveAntiKick   = true

AurasGroup:AddDropdown("RemoveAntiKickAuraRadiusDropdown", {
    Text     = "Anti Kick Aura Radius",
    Values   = {"10", "12", "14", "16", "18", "20"},
    Default  = "15",
    Callback = function(v) removeAntiKickRadius = tonumber(v) end,
})

AurasGroup:AddToggle("RemoveAntiKickAuraWhitelistToggle", {
    Text     = "Use Whitelist (Friends)",
    Default  = true,
    Callback = function(on) useWhitelistRemoveAntiKick = on end,
})

AurasGroup:AddToggle("RemoveAntiKickAuraToggle", {
    Text    = "Remove Anti Kick Aura",
    Default = false,
    Callback = function(on)
        removeAntiKickAuraActive = on
        if not on then
            if removeAntiKickAuraConnection then
                removeAntiKickAuraConnection:Disconnect()
                removeAntiKickAuraConnection = nil
            end
            return
        end
        task.spawn(function()
            local setNetOwner = RS:WaitForChild("GrabEvents"):WaitForChild("SetNetworkOwner")
            removeAntiKickAuraConnection = RunService.Heartbeat:Connect(function()
                local mc = Player.Character
                local mr = mc and mc:FindFirstChild("HumanoidRootPart")
                if not mr then return end
                for _, target in ipairs(PS:GetPlayers()) do
                    if target ~= Player then
                        local tc = target.Character
                        local tr = tc and tc:FindFirstChild("HumanoidRootPart")
                        if not tr then continue end
                        if useWhitelistRemoveAntiKick and Player:IsFriendsWith(target.UserId) then continue end
                        if (tr.Position - mr.Position).Magnitude <= removeAntiKickRadius then
                            local folder = workspace:FindFirstChild(target.Name .. "SpawnedInToys")
                            if folder then
                                for _, toyName in ipairs({"NinjaKunai", "NinjaShuriken", "AntiKick"}) do
                                    local toy  = folder:FindFirstChild(toyName)
                                    if toy then
                                        local soundPart = toy:FindFirstChild("SoundPart")
                                        if soundPart then
                                            pcall(function() setNetOwner:FireServer(soundPart, soundPart.CFrame) end)
                                            if soundPart:FindFirstChild("PartOwner")
                                                and soundPart.PartOwner.Value == Player.Name then
                                                soundPart.CFrame = CFrame.new(0, 1000, 0)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end)
        end)
    end,
})

-- Dual-Hand Kick Aura
local dualKickAuraEnabled  = false
local dualKickAuraRadius   = 20
local dualKickAuraWhitelist = true
local dualKickAuraConn

AurasGroup:AddDropdown("DualKickAuraRadius", {
    Text     = "Dual Kick Aura Radius",
    Values   = {"10", "20", "30", "40", "50"},
    Default  = "20",
    Callback = function(v) dualKickAuraRadius = tonumber(v) end,
})

AurasGroup:AddToggle("DualKickAuraWhitelist", {
    Text     = "Whitelist Friends",
    Default  = true,
    Callback = function(v) dualKickAuraWhitelist = v end,
})

local function canKick(pl)
    if not dualKickAuraWhitelist then return true end
    return not Player:IsFriendsWith(pl.UserId)
end

AurasGroup:AddToggle("DualHandKickAura", {
    Text    = "Dual Hand Kick Aura",
    Default = false,
    Callback = function(on)
        dualKickAuraEnabled = on
        if dualKickAuraConn then dualKickAuraConn:Disconnect() dualKickAuraConn = nil end
        if not on then return end

        local lastTick = 0
        dualKickAuraConn = RunService.Heartbeat:Connect(function()
            if tick() - lastTick < 0.12 then return end
            lastTick = tick()

            local mc = Player.Character
            local hm = mc and mc:FindFirstChildOfClass("Humanoid")
            local se = hm and hm.SeatPart
            local mr = mc and mc:FindFirstChild("HumanoidRootPart")
            if not (se and mr) then return end

            local blob   = se.Parent
            local script = blob:FindFirstChild("BlobmanSeatAndOwnerScript")
            local CG     = script and script:FindFirstChild("CreatureGrab")
            local CD     = script and script:FindFirstChild("CreatureDrop")
            local LD     = blob:FindFirstChild("LeftDetector")
            local RD     = blob:FindFirstChild("RightDetector")
            local LW     = LD and LD:FindFirstChild("LeftWeld")
            local RW     = RD and RD:FindFirstChild("RightWeld")
            if not (CG and CD and LD and RD and LW and RW) then return end

            for _, pl in ipairs(PS:GetPlayers()) do
                if pl ~= Player and pl.Character and canKick(pl) then
                    local h   = pl.Character:FindFirstChild("HumanoidRootPart")
                    local hm2 = pl.Character:FindFirstChildOfClass("Humanoid")
                    if h and hm2 and hm2.Health > 0
                        and (h.Position - mr.Position).Magnitude <= dualKickAuraRadius then
                        pcall(function()
                            CG:FireServer(LD, h, LW) task.wait(0.04) CD:FireServer(LW, h)
                            CG:FireServer(RD, h, RW) task.wait(0.04) CD:FireServer(RW, h)
                            CG:FireServer(LD, h, LW) CG:FireServer(RD, h, RW)
                            task.wait(0.03) CD:FireServer(LW, h) CD:FireServer(RW, h)
                        end)
                    end
                end
            end
        end)
    end,
})

-- Kick Aura 1-Hand
local kickAura1Enabled   = false
local kickAura1Radius    = 20
local kickAura1Whitelist = true
local kickAura1Conn

AurasGroup:AddDropdown("KickAura1Radius", {
    Text     = "Kick Aura 1 Hand Radius",
    Values   = {"10", "20", "30", "40", "50"},
    Default  = "20",
    Callback = function(v) kickAura1Radius = tonumber(v) end,
})

AurasGroup:AddToggle("KickAura1Whitelist", {
    Text     = "Whitelist Friends",
    Default  = true,
    Callback = function(v) kickAura1Whitelist = v end,
})

AurasGroup:AddToggle("KickAura1Toggle", {
    Text    = "Kick Aura 1 Hand (grab + blob)",
    Default = false,
    Callback = function(on)
        kickAura1Enabled = on
        if kickAura1Conn then kickAura1Conn:Disconnect() kickAura1Conn = nil end
        if not on then return end

        kickAura1Conn = RunService.Heartbeat:Connect(function()
            local c    = Player.Character
            local hm   = c and c:FindFirstChild("Humanoid")
            local seat = hm and hm.SeatPart
            local rt   = c and c:FindFirstChild("HumanoidRootPart")
            if not (seat and rt) then return end

            local blob   = seat.Parent
            local blobRP = blob:FindFirstChild("HumanoidRootPart") or blob.PrimaryPart
            local script = blob:FindFirstChild("BlobmanSeatAndOwnerScript")
            local CG     = script and script:FindFirstChild("CreatureGrab")
            local CD     = script and script:FindFirstChild("CreatureDrop")
            local RD     = blob:FindFirstChild("RightDetector")
            local RW     = RD and (RD:FindFirstChild("RightWeld") or RD:FindFirstChildWhichIsA("Weld"))
            if not (CG and CD and RD and RW and blobRP) then return end

            local lastPcall = 0
            for _, pl in ipairs(PS:GetPlayers()) do
                if pl ~= Player and pl.Character
                    and (not kickAura1Whitelist or not Player:IsFriendsWith(pl.UserId)) then
                    local tr = pl.Character:FindFirstChild("HumanoidRootPart")
                    local th = pl.Character:FindFirstChild("Humanoid")
                    if tr and th and th.Health > 0
                        and (tr.Position - rt.Position).Magnitude <= kickAura1Radius then
                        pcall(function()
                            if tick() - lastPcall > 0.05 then
                                lastPcall = tick()
                                local w = RD:FindFirstChild("RightWeld") or RD:FindFirstChildWhichIsA("Weld")
                                if w then CD:FireServer(w) CG:FireServer(RD, tr, RW) end
                            end
                        end)
                    end
                end
            end
        end)
    end,
})

-- =============================================
-- Fun Tab
-- =============================================

local FanAnimGroup  = Tabs.Fun:AddLeftGroupbox("Animations")
local FanTrollGroup = Tabs.Fun:AddLeftGroupbox("Troll")

local animEnabled       = false
local currentTrack      = nil
local selectedAnimName  = "Crazy"
local selectedAnimKey   = Enum.KeyCode.Q

local Animations = {
    ["Crazy"]    = "rbxassetid://248263260",
    ["Insane"]   = "rbxassetid://35654637",
    ["Collapse"] = "rbxassetid://35154961",
    ["Zombie"]   = "rbxassetid://33796059",
}

local function playAnimation()
    local c  = Player.Character or Player.CharacterAdded:Wait()
    local hm = c:FindFirstChildOfClass("Humanoid")
    if not hm then return end
    local animator = hm:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = hm
    end
    if currentTrack then currentTrack:Stop() currentTrack = nil end
    local anim         = Instance.new("Animation")
    anim.AnimationId   = Animations[selectedAnimName]
    currentTrack       = animator:LoadAnimation(anim)
    currentTrack.Priority = Enum.AnimationPriority.Action
    currentTrack.Looped   = true
    currentTrack:Play()
    task.spawn(function()
        while animEnabled and currentTrack do
            if currentTrack.TimePosition > 0.9 then currentTrack.TimePosition = 0.3 end
            task.wait(0.05)
        end
    end)
end

local function stopAnimation()
    if currentTrack then currentTrack:Stop() currentTrack = nil end
end

FanAnimGroup:AddToggle("AnimToggle", {
    Text    = "Play Animation",
    Default = false,
    Callback = function(on)
        animEnabled = on
        if on then playAnimation() else stopAnimation() end
    end,
})

FanAnimGroup:AddDropdown("AnimSelect", {
    Text     = "Animation",
    Values   = {"Crazy", "Insane", "Collapse", "Zombie"},
    Default  = 1,
    Callback = function(v)
        selectedAnimName = v
        if animEnabled then playAnimation() end
    end,
})

FanAnimGroup:AddDropdown("AnimKeybind", {
    Text     = "Toggle Key",
    Values   = {"Q", "E", "R", "T", "F", "Z", "X", "C"},
    Default  = 1,
    Callback = function(v) selectedAnimKey = Enum.KeyCode[v] end,
})

-- Jerk Off Animation
local playJerkOffActive = false
local jerkOffAnimTrack  = nil
local jerkOffAnimId     = "rbxassetid://168268306"
local jerkKey           = Enum.KeyCode.Q

local function startJerkOff()
    local c  = Player.Character or Player.CharacterAdded:Wait()
    local hm = c:FindFirstChildOfClass("Humanoid")
    if not hm then return end
    local animator = hm:FindFirstChildOfClass("Animator")
    if not animator then animator = Instance.new("Animator") animator.Parent = hm end
    local anim         = Instance.new("Animation")
    anim.AnimationId   = jerkOffAnimId
    jerkOffAnimTrack   = animator:LoadAnimation(anim)
    jerkOffAnimTrack.Priority = Enum.AnimationPriority.Action
    jerkOffAnimTrack:Play()
    task.spawn(function()
        while playJerkOffActive do
            task.wait(0.1)
            if jerkOffAnimTrack and jerkOffAnimTrack.IsPlaying then
                jerkOffAnimTrack.TimePosition = 0.3
            end
        end
    end)
end

local function stopJerkOff()
    if jerkOffAnimTrack then jerkOffAnimTrack:Stop() jerkOffAnimTrack = nil end
end

FanTrollGroup:AddToggle("JerkOffToggle", {
    Text    = "Jerk Off",
    Default = false,
    Callback = function(on)
        playJerkOffActive = on
        if on then startJerkOff() else stopJerkOff() end
    end,
})

FanTrollGroup:AddDropdown("JerkKey", {
    Text     = "Toggle Key",
    Values   = {"Q", "E", "R", "T"},
    Default  = 1,
    Callback = function(v) jerkKey = Enum.KeyCode[v] end,
})

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == jerkKey then
        playJerkOffActive = not playJerkOffActive
        if playJerkOffActive then startJerkOff() else stopJerkOff() end
    end
end)

-- Bang Animation
local playBangActive = false
local bangAnimTrack  = nil
local bangAnimId     = "rbxassetid://148840371"
local bangSpeed      = 10

local function startBang()
    local c  = Player.Character or Player.CharacterAdded:Wait()
    local hm = c:FindFirstChildOfClass("Humanoid")
    if not hm then return end
    local animator = hm:FindFirstChildOfClass("Animator")
    if not animator then animator = Instance.new("Animator") animator.Parent = hm end
    local anim         = Instance.new("Animation")
    anim.AnimationId   = bangAnimId
    bangAnimTrack      = animator:LoadAnimation(anim)
    bangAnimTrack.Priority = Enum.AnimationPriority.Action
    bangAnimTrack:Play()
    bangAnimTrack:AdjustSpeed(bangSpeed)
    task.spawn(function()
        while playBangActive do
            task.wait(0.1)
            if bangAnimTrack and bangAnimTrack.IsPlaying then
                bangAnimTrack.TimePosition = 0.1
            end
        end
    end)
end

local function stopBang()
    if bangAnimTrack then bangAnimTrack:Stop() bangAnimTrack = nil end
end

FanTrollGroup:AddToggle("BangToggle", {
    Text    = "Bang (Slow)",
    Default = false,
    Callback = function(on) playBangActive = on if on then startBang() else stopBang() end end,
})

-- Follow & Stare
FanTrollGroup:AddToggle("FollowStare", {
    Text    = "Follow & Stare",
    Default = false,
    Callback = function(on)
        follow = on
        task.spawn(function()
            while follow do
                local target = PS:GetPlayers()[math.random(#PS:GetPlayers())]
                if target ~= Player and target.Character
                    and target.Character:FindFirstChild("HumanoidRootPart") then
                    local myRoot     = Player.Character.HumanoidRootPart
                    local targetRoot = target.Character.HumanoidRootPart
                    myRoot.CFrame = CFrame.new(
                        targetRoot.Position + targetRoot.CFrame.LookVector * -2,
                        targetRoot.Position
                    )
                end
                task.wait(0.3)
            end
        end)
    end,
})

-- Fake Death
FanTrollGroup:AddToggle("FakeDeathToggle", {
    Text    = "Fake Death",
    Default = false,
    Callback = function(on)
        local c  = Player.Character
        if not c then return end
        local hm = c:FindFirstChildOfClass("Humanoid")
        if not hm then return end
        if on then
            hm:ChangeState(Enum.HumanoidStateType.Physics)
            hm.PlatformStand = true
        else
            hm.PlatformStand = false
            hm:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end,
})

-- Fake Lag
local fakeLagConn

FanTrollGroup:AddToggle("FakeLagToggle", {
    Text    = "Fake Lag",
    Default = false,
    Callback = function(on)
        if fakeLagConn then fakeLagConn:Disconnect() fakeLagConn = nil end
        if not on then return end
        fakeLagConn = RunService.Heartbeat:Connect(function()
            local rt = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if not rt then return end
            if math.random(1, 5) == 1 then
                rt.CFrame = rt.CFrame * CFrame.new(
                    math.random(-2, 2) / 10, 0, math.random(-2, 2) / 10
                )
            end
        end)
    end,
})

-- Stick Shuriken to UFO
FanTrollGroup:AddToggle("UFOShurikenStick", {
    Text    = "Stick Shuriken to UFO",
    Default = false,
    Callback = function(on)
        if not on then return end
        local stickyEvent   = RS:WaitForChild("PlayerEvents"):WaitForChild("StickyPartEvent")
        local spawnRemote   = RS.MenuToys:WaitForChild("SpawnToyRemoteFunction")
        local canSpawn      = Player:WaitForChild("CanSpawnToy")
        local toyFolder     = workspace:WaitForChild(Player.Name .. "SpawnedInToys")
        local UFOs = {
            workspace.Map.AlwaysHereTweenedObjects:FindFirstChild("InnerUFO"),
            workspace.Map.AlwaysHereTweenedObjects:FindFirstChild("OuterUFO"),
        }

        local function getRoot()
            if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
                return Player.Character.HumanoidRootPart
            end
            return Player.CharacterAdded:Wait():WaitForChild("HumanoidRootPart")
        end

        task.spawn(function()
            -- Spawn 12 shurikens
            for _ = 1, 12 do
                local t = tick()
                while not canSpawn.Value do
                    if tick() - t > 5 then break end
                    task.wait(0.1)
                end
                local root = getRoot()
                if root then
                    pcall(function()
                        spawnRemote:InvokeServer("NinjaShuriken", root.CFrame * CFrame.new(0, 10, 15), Vector3.new())
                    end)
                end
                task.wait(0.15)
            end

            task.wait(1)

            -- Attach each shuriken to UFOs
            for _, child in ipairs(toyFolder:GetChildren()) do
                if child.Name == "NinjaShuriken" and child:FindFirstChild("StickyPart") then
                    for _, ufo in ipairs(UFOs) do
                        if ufo and ufo:FindFirstChild("Object")
                            and ufo.Object:FindFirstChild("ObjectModel")
                            and ufo.Object.ObjectModel:FindFirstChild("Body") then
                            stickyEvent:FireServer(child.StickyPart, ufo.Object.ObjectModel.Body, CFrame.new())
                            local followPart = ufo.Object:FindFirstChild("FollowThisPart")
                            if followPart then
                                if followPart:FindFirstChild("AlignOrientation") then
                                    followPart.AlignOrientation.Enabled = false
                                end
                                if followPart:FindFirstChild("AlignPosition") then
                                    followPart.AlignPosition.Enabled = false
                                end
                            end
                        end
                    end
                end
            end
        end)
    end,
})

-- =============================================
-- Blobman: Sit & Keybinds
-- =============================================

local function getNearestBlobman(maxDist)
    local c = Player.Character
    local h = c and c:FindFirstChild("HumanoidRootPart")
    if not h then return end
    local nearest, closest = nil, maxDist or 50
    for _, model in ipairs(workspace:GetDescendants()) do
        if model:IsA("Model") and model.Name == "CreatureBlobman" then
            local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
            if root then
                local dist = (root.Position - h.Position).Magnitude
                if dist < closest then closest = dist nearest = model end
            end
        end
    end
    return nearest
end

local function SitOnBlobman()
    local c  = Player.Character
    if not c then return end
    local hm = c:FindFirstChildOfClass("Humanoid")
    local h  = c:FindFirstChild("HumanoidRootPart")
    if not hm or not h or hm.SeatPart then return end
    local blob = getNearestBlobman(40)
    if not blob then return end
    local seat = blob:FindFirstChildWhichIsA("Seat", true)
        or blob:FindFirstChildWhichIsA("VehicleSeat", true)
    if not seat then return end
    h.CFrame = seat.CFrame * CFrame.new(0, 1.2, -1)
    task.wait(0.05)
    pcall(function() seat:Sit(hm) end)
end

local KeybindsGroup = Tabs.Keybinds:AddLeftGroupbox("Keybinds")
local Mouse         = Player:GetMouse()
local tpEnabled     = true

KeybindsGroup:AddLabel("Blobman"):AddKeyPicker("SitBlobmanKey", {
    Default  = "Z",
    Text     = "Sit on nearest Blobman",
    NoUI     = false,
    Callback = function() SitOnBlobman() end,
})

-- =============================================
-- Kick Sound & Notify
-- =============================================

local function playKickSound()
    local sound          = Instance.new("Sound")
    sound.SoundId        = "rbxassetid://79150789336480"
    sound.Volume         = 5
    sound.PlayOnRemove   = true
    sound.Parent         = game:GetService("SoundService")
    sound:Destroy()
end

local function notifyKick(displayName, username)
    Library:Notify({
        Title       = "ZRHUB Script",
        Description = displayName .. " (" .. username .. ") has been kicked",
        Time        = 6,
    })
end

local function getClosestPlayer(position)
    local closest, closestDist = nil, math.huge
    for _, pl in ipairs(PS:GetPlayers()) do
        if pl ~= Player and pl.Character then
            local h = pl.Character:FindFirstChild("HumanoidRootPart")
            if h then
                local dist = (h.Position - position).Magnitude
                if dist < closestDist then closestDist = dist closest = pl end
            end
        end
    end
    return closest
end

Workspace.ChildAdded:Connect(function(obj)
    if obj.Name == "BlackHoleKick" or obj.Name == "BlackHoleDetected" then
        task.wait(0.05)
        local pos
        if obj:IsA("BasePart") then
            pos = obj.Position
        elseif obj:IsA("Model") and obj.PrimaryPart then
            pos = obj.PrimaryPart.Position
        end
        if not pos then return end
        local pl = getClosestPlayer(pos)
        if not pl then return end
        playKickSound()
        notifyKick(pl.DisplayName, pl.Name)
    end
end)

-- Friend join notification
PS.PlayerAdded:Connect(function(pl)
    if pl:IsFriendsWith(Player.UserId) then
        notify("Notify friend", pl.Name .. " joined", 5)
    end
end)

-- =============================================
-- Grab Tab
-- =============================================

local GrabGroup = Tabs.Grab:AddLeftGroupbox("Grab Customization")
_G.strength     = 750
local strengthConnection

GrabGroup:AddSlider("ThrowPowerSlider", {
    Text     = "Power",
    Default  = 750,
    Min      = 1,
    Max      = 20000,
    Rounding = 0,
    Callback = function(v) _G.strength = v end,
})

GrabGroup:AddToggle("ThrowStrengthToggle", {
    Text    = "Strength",
    Default = false,
    Callback = function(enabled)
        if enabled then
            strengthConnection = workspace.ChildAdded:Connect(function(model)
                if model.Name == "GrabParts" then
                    local targetPart = model.GrabPart.WeldConstraint.Part1
                    if targetPart then
                        local velocity = Instance.new("BodyVelocity", targetPart)
                        model:GetPropertyChangedSignal("Parent"):Connect(function()
                            if not model.Parent then
                                if UserInputService:GetLastInputType() == Enum.UserInputType.MouseButton2 then
                                    velocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                                    velocity.Velocity = workspace.CurrentCamera.CFrame.LookVector * _G.strength
                                    game:GetService("Debris"):AddItem(velocity, 1)
                                else
                                    velocity:Destroy()
                                end
                            end
                        end)
                    end
                end
            end)
        elseif strengthConnection then
            strengthConnection:Disconnect()
        end
    end,
})

-- Kill Grab
local killGrabEnabled = false

local function killGrabFunction()
    workspace.ChildAdded:Connect(function(obj)
        if obj:IsA("Model") and obj.Name == "GrabParts" and killGrabEnabled then
            task.wait(0.05)
            local grabPart = obj:FindFirstChild("GrabPart")
            if grabPart and grabPart:FindFirstChild("WeldConstraint") then
                local part1 = grabPart.WeldConstraint.Part1
                if part1 and part1.Parent and part1.Parent ~= Player.Character then
                    local targetCharacter = part1.Parent
                    local humanoid        = targetCharacter:FindFirstChildOfClass("Humanoid")
                    if humanoid then
                        pcall(function()
                            humanoid.Health = 0
                            targetCharacter:BreakJoints()
                        end)
                    end
                end
            end
        end
    end)
end
killGrabFunction()

GrabGroup:AddToggle("KillGrabToggle", {
    Text     = "Kill Grab",
    Default  = false,
    Callback = function(enabled) killGrabEnabled = enabled end,
})

-- Massless Grab
GrabGroup:AddToggle("MassLessGrabToggle", {
    Text    = "MassLess Grab",
    Default = false,
    Callback = function(enabled)
        _G.MassLessGrab = enabled
        if not enabled then
            if _G.MLConn then _G.MLConn:Disconnect() _G.MLConn = nil end
            return
        end
        if _G.MLConn then _G.MLConn:Disconnect() _G.MLConn = nil end
        _G.MLSense = _G.MLSense or 200
        _G.MLConn  = RunService.Heartbeat:Connect(function()
            if not _G.MassLessGrab then return end
            local grabParts = workspace:FindFirstChild("GrabParts")
            if not grabParts then return end
            local dragPart  = grabParts:FindFirstChild("DragPart")
            if not dragPart then return end
            local ap = dragPart:FindFirstChild("AlignPosition")
            local ao = dragPart:FindFirstChild("AlignOrientation")
            if ap then
                ap.Responsiveness = _G.MLSense
                ap.MaxForce       = math.huge
                ap.MaxVelocity    = math.huge
            end
            if ao then
                ao.Responsiveness = _G.MLSense
                ao.MaxTorque      = math.huge
            end
        end)
    end,
})

-- =============================================
-- Player Tab
-- =============================================

local PlayerView = Tabs.Player:AddLeftGroupbox("View & Movement")
local PlayerESP  = Tabs.Player:AddRightGroupbox("ESP")
local PlayerEnv  = Tabs.Player:AddLeftGroupbox("Environment")
local PlayerPerf = Tabs.Player:AddRightGroupbox("Performance")

-- Third-person toggle
local function enableThirdPerson()
    Player.CameraMode              = Enum.CameraMode.Classic
    Camera.CameraType              = Enum.CameraType.Custom
    Camera.CameraSubject           = Player.Character:WaitForChild("Humanoid")
    Player.CameraMaxZoomDistance   = 16456456546
    Player.CameraMinZoomDistance   = 0.5
end

local function disableThirdPerson()
    Player.CameraMode              = Enum.CameraMode.LockFirstPerson
    Camera.CameraType              = Enum.CameraType.Custom
    Camera.CameraSubject           = Player.Character:WaitForChild("Humanoid")
    Player.CameraMaxZoomDistance   = 0
    Player.CameraMinZoomDistance   = 0
end

PlayerView:AddToggle("ThirdPersonToggle", {
    Text    = "3rd Person View",
    Default = false,
    Callback = function(enabled)
        if enabled then enableThirdPerson() else disableThirdPerson() end
    end,
})

-- Spin
local spinningConnection
local spinSpeed = 5

PlayerView:AddToggle("SpinToggle", {
    Text    = "Spin Character",
    Default = false,
    Callback = function(enabled)
        if enabled then
            spinningConnection = R.Heartbeat:Connect(function()
                local rt = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                if rt then rt.CFrame = rt.CFrame * CFrame.Angles(0, math.rad(spinSpeed), 0) end
            end)
        else
            if spinningConnection then spinningConnection:Disconnect() spinningConnection = nil end
        end
    end,
})

PlayerView:AddSlider("SpinSpeed", {
    Text     = "Spin Speed",
    Default  = 5,
    Min      = 1,
    Max      = 50,
    Rounding = 0,
    Callback = function(v) spinSpeed = v end,
})

-- Infinite Jump
local infJump = false

PlayerView:AddToggle("infJumpToggle", {
    Text     = "Infinite Jump",
    Default  = false,
    Callback = function(enabled) infJump = enabled end,
})

UserInputService.JumpRequest:Connect(function()
    if infJump then
        local c = Player.Character
        if c and c:FindFirstChildOfClass("Humanoid") then
            c:FindFirstChildOfClass("Humanoid"):ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- Box ESP
local espEnabled = false
local espBoxes   = {}
local targetNames = {"partesp", "playercharacterlocationdetector"}

local function IsTarget(obj)
    if not obj:IsA("BasePart") then return false end
    for _, name in ipairs(targetNames) do
        if string.lower(obj.Name) == string.lower(name) then return true end
    end
    return false
end

local function AddBoxESP(obj)
    if espBoxes[obj] then return end
    local box               = Instance.new("BoxHandleAdornment")
    box.Adornee             = obj
    box.AlwaysOnTop         = true
    box.ZIndex              = 5
    box.Color3              = Color3.fromRGB(255, 255, 255)
    box.Transparency        = 0.5
    box.Size                = obj.Size
    box.Parent              = CoreGui
    espBoxes[obj]           = box
    obj.AncestryChanged:Connect(function(_, parent)
        if not parent and espBoxes[obj] then
            espBoxes[obj]:Destroy()
            espBoxes[obj] = nil
        end
    end)
end

local function RemoveAllBoxes()
    for _, box in pairs(espBoxes) do if box then box:Destroy() end end
    espBoxes = {}
end

local function Scan()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if espEnabled and IsTarget(obj) then AddBoxESP(obj) end
    end
end

workspace.DescendantAdded:Connect(function(obj)
    if espEnabled and IsTarget(obj) then AddBoxESP(obj) end
end)

PlayerESP:AddToggle("BoxESPWhite", {
    Text    = "PCLD View",
    Default = false,
    Callback = function(enabled)
        espEnabled = enabled
        if espEnabled then Scan() else RemoveAllBoxes() end
    end,
})

-- Nickname ESP
PlayerESP:AddToggle("NicknameESP", {
    Text    = "Nickname Esp",
    Default = false,
    Callback = function(enabled)
        local function createESP(pl)
            if pl == Player then return end
            if pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") then
                local root = pl.Character.HumanoidRootPart
                if root:FindFirstChild("NameESP") then return end
                local billboard         = Instance.new("BillboardGui")
                billboard.Name          = "NameESP"
                billboard.Adornee       = root
                billboard.Size          = UDim2.new(0, 100, 0, 30)
                billboard.StudsOffset   = Vector3.new(0, 3, 0)
                billboard.AlwaysOnTop   = true
                billboard.Parent        = root
                local label                     = Instance.new("TextLabel")
                label.Size                      = UDim2.new(1, 0, 1, 0)
                label.BackgroundTransparency    = 1
                label.Text                      = pl.Name
                label.TextColor3                = Color3.fromRGB(255, 255, 255)
                label.TextStrokeTransparency    = 0
                label.TextScaled                = true
                label.Parent                    = billboard
            end
        end

        if enabled then
            for _, pl in pairs(PS:GetPlayers()) do
                createESP(pl)
                pl.CharacterAdded:Connect(function() createESP(pl) end)
            end
            PS.PlayerAdded:Connect(function(pl)
                pl.CharacterAdded:Connect(function() createESP(pl) end)
            end)
        else
            for _, pl in pairs(PS:GetPlayers()) do
                if pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") then
                    local root = pl.Character.HumanoidRootPart
                    if root:FindFirstChild("NameESP") then root.NameESP:Destroy() end
                end
            end
        end
    end,
})

-- =============================================
-- Performance Buttons
-- =============================================

local oldProperties = {}

PlayerPerf:AddButton({
    Text = "boost fps",
    Func = function()
        local L = game:GetService("Lighting")
        for _, v in pairs(Workspace:GetDescendants()) do
            if v:IsA("BasePart") then
                if not oldProperties[v] then
                    oldProperties[v] = {
                        Material    = v.Material,
                        Reflectance = v.Reflectance,
                        CastShadow  = v.CastShadow,
                    }
                end
                v.Material    = Enum.Material.Plastic
                v.Reflectance = 0
                v.CastShadow  = false
            elseif v:IsA("ParticleEmitter") or v:IsA("Trail")
                or v:IsA("Smoke") or v:IsA("Fire") then
                if not oldProperties[v] then
                    oldProperties[v] = { Enabled = v.Enabled }
                end
                v.Enabled = false
            end
        end
        if not oldProperties["Lighting"] then
            oldProperties["Lighting"] = {
                GlobalShadows = L.GlobalShadows,
                FogEnd        = L.FogEnd,
                Brightness    = L.Brightness,
            }
        end
        L.GlobalShadows = false
        L.FogEnd        = 100000
        L.Brightness    = 2
    end,
})

PlayerPerf:AddButton({
    Text = "delete boost fps",
    Func = function()
        local L = game:GetService("Lighting")
        for obj, props in pairs(oldProperties) do
            if typeof(obj) == "Instance" and obj.Parent then
                for prop, val in pairs(props) do obj[prop] = val end
            elseif obj == "Lighting" then
                for prop, val in pairs(props) do L[prop] = val end
            end
        end
        oldProperties = {}
    end,
})

-- =============================================
-- Misc Tab
-- =============================================

local MiscGroup = Tabs.Misc:AddLeftGroupbox("Miscellaneous")
local mouse     = Player:GetMouse()

-- Dreamy Night Shader
MiscGroup:AddToggle("DreamyNightShaderToggle", {
    Text    = "Dreamy Night Shader",
    Default = false,
    Callback = function(on)
        local L = game:GetService("Lighting")
        if not _G.DreamyNightEffects then
            local blur   = Instance.new("BlurEffect")
            blur.Size    = 6 blur.Enabled = false blur.Parent = L

            local bloom       = Instance.new("BloomEffect")
            bloom.Intensity   = 1.6 bloom.Size = 90 bloom.Threshold = 1.4
            bloom.Enabled     = false bloom.Parent = L

            local color           = Instance.new("ColorCorrectionEffect")
            color.Brightness      = 0.15 color.Contrast = -0.1 color.Saturation = 0.25
            color.TintColor       = Color3.fromRGB(210, 220, 255)
            color.Enabled         = false color.Parent = L

            local sunRays         = Instance.new("SunRaysEffect")
            sunRays.Intensity     = 0.05 sunRays.Spread = 0.6
            sunRays.Enabled       = false sunRays.Parent = L

            local atmos           = Instance.new("Atmosphere")
            atmos.Density         = 0.45 atmos.Offset = 0.1
            atmos.Color           = Color3.fromRGB(180, 190, 255)
            atmos.Decay           = Color3.fromRGB(120, 130, 180)
            atmos.Glare           = 0.15 atmos.Haze = 3 atmos.Parent = L

            _G.DreamyNightEffects = {blur, bloom, color, sunRays, atmos}
        end

        for _, effect in ipairs(_G.DreamyNightEffects) do effect.Enabled = on end

        if on then
            L.ClockTime                  = 0.5
            L.GlobalShadows              = false
            L.Brightness                 = 2
            L.EnvironmentDiffuseScale    = 0.2
            L.EnvironmentSpecularScale   = 0.1
            L.FogEnd                     = 200000
        end
    end,
})

-- Ignore House Barriers
MiscGroup:AddToggle("NoBarrierCollision", {
    Text    = "Ignore House Barriers",
    Default = false,
    Callback = function(enabled)
        local plots = workspace:FindFirstChild("Plots")
        if not plots then return end
        for _, plot in ipairs(plots:GetChildren()) do
            local barrier = plot:FindFirstChild("Barrier")
            if barrier then
                for _, obj in ipairs(barrier:GetDescendants()) do
                    if obj:IsA("BasePart") then obj.CanCollide = not enabled end
                end
            end
        end
    end,
})

-- Packet Lag
local PacketSpamAmount = 100

MiscGroup:AddSlider("PacketAmountSlider", {
    Text     = "Packet Lag",
    Default  = 100,
    Min      = 10,
    Max      = 5000,
    Rounding = 0,
    Callback = function(v) PacketSpamAmount = v end,
})

MiscGroup:AddToggle("PacketLagToggle", {
    Text    = "Packet Lag",
    Default = false,
    Callback = function(enabled)
        _G.PacketLagActive = enabled
        if enabled then
            task.spawn(function()
                local grabEvent = RS:WaitForChild("GrabEvents"):WaitForChild("ExtendGrabLine")
                while _G.PacketLagActive do
                    pcall(function()
                        grabEvent:FireServer(string.rep("Balls Balls Balls Balls", PacketSpamAmount))
                    end)
                    task.wait()
                end
            end)
        end
    end,
})

-- Auto Reset
MiscGroup:AddToggle("AutoResetToggle", {
    Text    = "Auto Reset",
    Default = false,
    Callback = function(on)
        autoResetEnabled = on
        if not on then return end
        task.spawn(function()
            while autoResetEnabled do
                local c  = Player.Character
                local hm = c and c:FindFirstChild("Humanoid")
                if hm and hm.Health > 0 then hm.Health = 0 end
                task.wait(0.5)
            end
        end)
    end,
})

-- =============================================
-- Triggerbot
-- =============================================

local Triggerbot = {
    Enabled              = false,
    Connection           = nil,
    canGrab              = true,
    maxDistance          = 20,
    preGrabDelay         = 0.00001,
    postGrabDelay        = 0.05,
    lastTarget           = nil,
    lastHitTime          = 0,
    targetMemoryDuration = 0.1,
    checkThrottle        = 0.008,
    lastCheck            = 0,
}

local rayParams            = RaycastParams.new()
rayParams.FilterType       = Enum.RaycastFilterType.Exclude

-- Check if gamepass extends reach
task.spawn(function()
    local success, result = pcall(function()
        return RS.GamepassEvents.CheckForGamepass:InvokeServer(20837132)
    end)
    if success and result then Triggerbot.maxDistance = 29.3 end
end)

if RS:FindFirstChild("GamepassEvents")
    and RS.GamepassEvents:FindFirstChild("FurtherReachBoughtNotifier") then
    RS.GamepassEvents.FurtherReachBoughtNotifier.OnClientEvent:Connect(function()
        Triggerbot.maxDistance = 29.3
    end)
end

function Triggerbot:GetTarget()
    local c = Player.Character
    if not c or not c:FindFirstChild("HumanoidRootPart") then return end
    if Workspace:FindFirstChild("GrabParts") then return end

    local origin    = Camera.CFrame.Position
    local direction = Camera.CFrame.LookVector
    rayParams.FilterDescendantsInstances = {c, Workspace.Terrain}

    local result = Workspace:Raycast(origin, direction * 1000, rayParams)
    if not result then
        local variants = {
            direction,
            (direction + Vector3.new(0, 0.075, 0)).Unit,
            (direction - Vector3.new(0, 0.075, 0)).Unit,
        }
        for _, dir in ipairs(variants) do
            result = Workspace:Raycast(origin, dir * 1000, rayParams)
            if result then break end
        end
    end
    if not result then return end

    local hit   = result.Instance
    local model = hit:FindFirstAncestorOfClass("Model")
    if not model or not model:FindFirstChildOfClass("Humanoid") or model == c then return end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid.Health <= 0 then return end
    local root = model:FindFirstChild("HumanoidRootPart")
    if not root then return end
    if (c.HumanoidRootPart.Position - root.Position).Magnitude > self.maxDistance then return end
    return model
end

function Triggerbot:OnHeartbeat()
    if not self.Enabled or not self.canGrab then return end
    if UserInputService:GetFocusedTextBox() then return end
    if tick() - self.lastCheck < self.checkThrottle then return end
    self.lastCheck = tick()

    local target = self:GetTarget()
    if target then
        self.lastTarget  = target
        self.lastHitTime = tick()
    elseif self.lastTarget and tick() - self.lastHitTime > self.targetMemoryDuration then
        self.lastTarget = nil
    end

    local c    = Player.Character
    local root = self.lastTarget and self.lastTarget:FindFirstChild("HumanoidRootPart")
    if not (self.lastTarget and c and c:FindFirstChild("HumanoidRootPart") and root) then return end
    if (c.HumanoidRootPart.Position - root.Position).Magnitude > self.maxDistance then
        self.lastTarget = nil
        return
    end

    if self.lastTarget then
        self.canGrab = false
        task.spawn(function()
            task.wait(self.preGrabDelay)
            pcall(mouse1press)
            local t0 = tick()
            repeat task.wait(0.02)
            until not Workspace:FindFirstChild("GrabParts") or tick() - t0 > 1.6
            task.wait(self.postGrabDelay)
            self.canGrab    = true
            self.lastTarget = nil
        end)
    end
end

MiscGroup:AddToggle("TriggerbotToggle", {
    Text    = "Trigger Bot",
    Default = false,
    Callback = function(enabled)
        Triggerbot.Enabled = enabled
        if Triggerbot.Enabled and not Triggerbot.Connection then
            Triggerbot.Connection = R.Heartbeat:Connect(function() Triggerbot:OnHeartbeat() end)
        elseif not Triggerbot.Enabled and Triggerbot.Connection then
            Triggerbot.Connection:Disconnect()
            Triggerbot.Connection = nil
        end
    end,
})

-- FOV
MiscGroup:AddSlider("FOVSlider", {
    Text     = "FOV",
    Default  = 90,
    Min      = 1,
    Max      = 120,
    Rounding = 0,
    Suffix   = "°",
    Callback = function(v) Camera.FieldOfView = v end,
})

-- =============================================
-- Build Tab: Heart Sparkler
-- =============================================

local BuildGroup      = Tabs.Build:AddLeftGroupbox("Build")
local heartHighRun    = false
local heartConnection = nil
local heartToy        = nil

BuildGroup:AddToggle("HeartSparklerBuild", {
    Text    = "Heart",
    Default = false,
    Callback = function(enabled)
        heartHighRun = enabled
        if enabled then
            task.spawn(function()
                if not Player.Character then return end
                local h = Player.Character:FindFirstChild("HumanoidRootPart")
                if not h then return end
                pcall(function()
                    RS.MenuToys.SpawnToyRemoteFunction:InvokeServer(
                        "FireworkSparkler", h.CFrame * CFrame.new(0, 50, 0), Vector3.zero
                    )
                end)
                local folder = workspace:WaitForChild(Player.Name .. "SpawnedInToys", 5)
                if not folder then return end
                heartToy = folder:WaitForChild("FireworkSparkler", 5)
                if not heartToy then return end
                local part = heartToy:FindFirstChild("Handle")
                    or heartToy:FindFirstChildWhichIsA("BasePart")
                if not part then return end
                task.wait(0.2)

                for _, v in ipairs(heartToy:GetDescendants()) do
                    if v:IsA("BasePart") then
                        v.Anchored   = false
                        v.CanCollide = false
                        v.Massless   = true
                    end
                end
                part:BreakJoints()

                local bp         = Instance.new("BodyPosition")
                bp.MaxForce      = Vector3.new(math.huge, math.huge, math.huge)
                bp.P             = 20000
                bp.D             = 500
                bp.Parent        = part

                local bg         = Instance.new("BodyGyro")
                bg.MaxTorque     = Vector3.new(math.huge, math.huge, math.huge)
                bg.P             = 3000
                bg.CFrame        = CFrame.new()
                bg.Parent        = part

                local t = 0
                if heartConnection then heartConnection:Disconnect() end
                heartConnection = RunService.Heartbeat:Connect(function(dt)
                    if not heartHighRun or not part or not part.Parent then
                        if heartConnection then heartConnection:Disconnect() end
                        if heartToy then pcall(function() heartToy:Destroy() end) end
                        return
                    end
                    local charRoot = Player.Character
                        and Player.Character:FindFirstChild("HumanoidRootPart")
                    if not charRoot then return end
                    pcall(function() RS.GrabEvents.SetNetworkOwner:FireServer(part, part.CFrame) end)

                    -- Heart parametric equation
                    t = t + (8 * dt)
                    local scale = 1.5
                    local x     = 16 * math.sin(t) ^ 3
                    local y     = 13 * math.cos(t) - 5 * math.cos(2 * t)
                              - 2 * math.cos(3 * t) - math.cos(4 * t)
                    bp.Position = charRoot.CFrame:PointToWorldSpace(
                        Vector3.new(x * scale, (y * scale) + 25, 3)
                    )
                    bg.CFrame = charRoot.CFrame
                end)
            end)
        else
            if heartConnection then heartConnection:Disconnect() heartConnection = nil end
            if heartToy then pcall(function() heartToy:Destroy() end) heartToy = nil end
        end
    end,
})

-- =============================================
-- Keybinds Tab
-- =============================================

KeybindsGroup:AddLabel("Teleport Tool"):AddKeyPicker("TPKeybind", {
    Default  = "X",
    Text     = "Teleport to Mouse",
    NoUI     = false,
    Callback = function()
        if not tpEnabled then return end
        local c = Player.Character
        local h = c and c:FindFirstChild("HumanoidRootPart")
        if not h then return end
        h.CFrame = CFrame.new(Mouse.Hit.Position + Vector3.new(0, 3, 0))
    end,
})

-- =============================================
-- UI Settings Tab
-- =============================================

local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("Menu")

MenuGroup:AddButton("Unload", function() Library:Unload() end)
MenuGroup:AddLabel("Menu Keybind"):AddKeyPicker("MenuKeybind", {
    Default = "RightShift",
    NoUI    = true,
    Text    = "Menu keybind",
})

Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({"MenuKeybind"})

ThemeManager:SetFolder("ZRHUB Script")
SaveManager:SetFolder("ZRHUB Script/Configs")

SaveManager:BuildConfigSection(Tabs["UI Settings"])
ThemeManager:ApplyTheme("Jester")
ThemeManager:ApplyToTab(Tabs["UI Settings"])
