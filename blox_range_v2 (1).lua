-- Blox Range v2.3 [PART 1/2] | Godmode & Fixed ESP
local newcclosure = newcclosure or function(f) return f end
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LP = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local G = (getgenv and getgenv()) or _G
if G.BR_CLEANUP then pcall(G.BR_CLEANUP) end
G.BR_S = G.BR_S or {}
local S = G.BR_S

local CFG = {
    GodMode = false, -- FITUR BARU
    ESP = false, Chams = true, Names = false, Health = false, Lines = true,
    Aim = false, Part = "Head", FOV = 150, Smooth = 0.35, WallCheck = true, ShowFOV = true,
    Magic = false, MagicFOV = 600, MagicLead = true, BulletSpeed = 500,
    Track = false, OneShot = false, TrackSpeed = 700, TrackKillRadius = 8,
    TeleKill = false, TeleAny = false, TeleHeight = 4, TeleDelay = 0.1,
    TeamCheck = false 
}
local BASE_FOV = math.rad(80)

S.spy = false
S.magicOn = false
S.magicTarget = nil
S.trackBullets = {}
S.recentParts = {}
S.trackWindow = 0
S.oneShotWindow = 0
S.trackTargetPart = nil
S.trackTargetHum = nil
S.humanoidRef = nil
S.desired = {}
S.internalWrite = false
S.teleTarget = nil
S.teleNext = 0

local function isEnemy(p)
    if p == LP then return false end
    if CFG.TeleAny then return true end
    if CFG.TeamCheck then
        if LP.Team and p.Team then return LP.Team ~= p.Team end
        return LP.TeamColor ~= p.TeamColor
    end
    return true
end

local function alive(char)
    local h = char and char:FindFirstChildOfClass("Humanoid")
    return h ~= nil and h.Health > 0, h
end

local function getAimPart(char)
    if CFG.Part == "Head" then return char:FindFirstChild("Head") end
    return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
end

local function visible(part, char)
    if not CFG.WallCheck then return true end
    local pr = RaycastParams.new()
    pr.FilterType = Enum.RaycastFilterType.Exclude
    pr.FilterDescendantsInstances = { LP.Character, char, Camera }
    pr.IgnoreWater = true
    local o = Camera.CFrame.Position
    return Workspace:Raycast(o, part.Position - o, pr) == nil
end

local function maxAngle(px)
    local f = (Camera.ViewportSize.Y / 2) / math.tan(BASE_FOV / 2)
    return math.atan(px / f)
end

local function getTarget(px, unlim)
    local cf = Camera.CFrame
    local pos, look = cf.Position, cf.LookVector
    local lim = not unlim and maxAngle(px) or nil
    local best, bs
    for _, p in ipairs(Players:GetPlayers()) do
        if isEnemy(p) then
            local ch = p.Character
            if ch then
                local pt = getAimPart(ch)
                local ok = alive(ch)
                if pt and ok then
                    local v = pt.Position - pos
                    local m = v.Magnitude
                    if m > 0.1 and (not unlim or m <= px) then
                        local ang = math.acos(math.clamp(look:Dot(v / m), -1, 1))
                        local pass = lim == nil or ang <= lim
                        if unlim then pass = ang <= math.rad(80) end
                        if pass and (not bs or ang < bs) and visible(pt, ch) then
                            best, bs = pt, ang
                        end
                    end
                end
            end
        end
    end
    return best
end

local function getNearestEnemyHead()
    local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local myPos = myRoot and myRoot.Position or Camera.CFrame.Position
    local best, bd
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and isEnemy(p) then
            local ch = p.Character
            local h = ch and ch:FindFirstChildOfClass("Humanoid")
            if h and h.Health > 0 then
                local head = ch:FindFirstChild("Head") or ch:FindFirstChild("HumanoidRootPart")
                if head then
                    local d = (myPos - head.Position).Magnitude
                    if not bd or d < bd then
                        best = ch
                        bd = d
                    end
                end
            end
        end
    end
    return best
end

local function leadPosition(part, origin)
    if not CFG.MagicLead then return part.Position end
    local ok, vel = pcall(function() return part.AssemblyLinearVelocity end)
    if not ok or not vel or vel.Magnitude < 0.5 then return part.Position end
    local d = (part.Position - origin).Magnitude
    local sp = math.max(CFG.BulletSpeed, 50)
    return part.Position + vel * (d / sp)
end

local function trackHum()
    local ch = LP.Character
    S.humanoidRef = ch and ch:FindFirstChildOfClass("Humanoid") or nil
end

local function applyHumanoid()
    local hum = S.humanoidRef
    if not hum or not hum.Parent then return end
    S.internalWrite = true
    if S.desired.MaxHealth then pcall(function() hum.MaxHealth = S.desired.MaxHealth end) end
    if S.desired.Health then
        if S.desired.Health > hum.MaxHealth then pcall(function() hum.MaxHealth = S.desired.Health end) end
        pcall(function() hum.Health = S.desired.Health end)
    end
    if S.desired.UseJumpPower ~= nil then pcall(function() hum.UseJumpPower = S.desired.UseJumpPower end) end
    for k, v in pairs(S.desired) do
        if k ~= "Health" and k ~= "MaxHealth" and k ~= "UseJumpPower" then
            pcall(function() hum[k] = v end)
        end
    end
    S.internalWrite = false
end

local gui = Instance.new("ScreenGui")
gui.Name = "BR_Gui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
local okp = pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not okp or not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end

local holder = Instance.new("Folder", gui)
holder.Name = "ESP"

local fovCircle = Instance.new("Frame", gui)
fovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
fovCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
fovCircle.BackgroundTransparency = 1
fovCircle.Size = UDim2.new(0, CFG.FOV * 2, 0, CFG.FOV * 2)
Instance.new("UICorner", fovCircle).CornerRadius = UDim.new(1, 0)
local fs = Instance.new("UIStroke", fovCircle)
fs.Color = Color3.new(1, 1, 1)
fs.Thickness = 1.5
fs.Transparency = 0.4

local main = Instance.new("Frame", gui)
main.Size = UDim2.new(0, 250, 0, 520)
main.Position = UDim2.new(0, 60, 0, 60)
main.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
main.BorderSizePixel = 0
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", main)
title.Size = UDim2.new(1, -40, 0, 28)
title.Position = UDim2.new(0, 8, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Blox Range v2.3"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left

local mini = Instance.new("TextButton", main)
mini.Size = UDim2.new(0, 28, 0, 22)
mini.Position = UDim2.new(1, -32, 0, 3)
mini.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
mini.Text = "-"
mini.TextColor3 = Color3.new(1, 1, 1)
mini.Font = Enum.Font.GothamBold
mini.TextSize = 16
Instance.new("UICorner", mini).CornerRadius = UDim.new(0, 6)

local body = Instance.new("ScrollingFrame", main)
body.Position = UDim2.new(0, 6, 0, 30)
body.Size = UDim2.new(1, -12, 1, -36)
body.BackgroundTransparency = 1
body.BorderSizePixel = 0
body.ScrollBarThickness = 3
body.AutomaticCanvasSize = Enum.AutomaticSize.Y
body.CanvasSize = UDim2.new(0, 0, 0, 0)
Instance.new("UIListLayout", body).Padding = UDim.new(0, 5)

local minimized = false
mini.MouseButton1Click:Connect(function()
    minimized = not minimized
    body.Visible = not minimized
    main.Size = minimized and UDim2.new(0, 250, 0, 28) or UDim2.new(0, 250, 0, 520)
    mini.Text = minimized and "+" or "-"
end)

local dragging, dragStart, startPos
title.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = i.Position
        startPos = main.Position
        i.Changed:Connect(function()
            if i.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)

local dragConn = UIS.InputChanged:Connect(function(i)
    if dragging and (i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement) then
        local d = i.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)

local OFFC, ONC = Color3.fromRGB(45, 45, 55), Color3.fromRGB(40, 120, 60)

local function makeBtn(text, cb)
    local b = Instance.new("TextButton", body)
    b.Size = UDim2.new(1, -4, 0, 30)
    b.BackgroundColor3 = OFFC
    b.Text = text
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.Gotham
    b.TextSize = 13
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseButton1Click:Connect(function() cb(b) end)
    return b
end

local function makeToggle(text, key, onChange)
    local function paint(b)
        b.Text = text .. ": " .. (CFG[key] and "ON" or "OFF")
        b.BackgroundColor3 = CFG[key] and ONC or OFFC
    end
    local b = makeBtn(text, function(btn)
        CFG[key] = not CFG[key]
        paint(btn)
        if onChange then onChange(CFG[key]) end
    end)
    paint(b)
    return b
end

local function makeStepper(getText, step)
    local row = Instance.new("Frame", body)
    row.Size = UDim2.new(1, -4, 0, 30)
    row.BackgroundTransparency = 1
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, -90, 1, 0)
    lbl.Position = UDim2.new(0, 45, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.new(1, 1, 1)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.Text = getText()
    
    local function small(txt, x, dir)
        local b = Instance.new("TextButton", row)
        b.Size = UDim2.new(0, 40, 1, 0)
        b.Position = UDim2.new(x, x == 0 and 0 or -40, 0, 0)
        b.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
        b.Text = txt
        b.TextColor3 = Color3.new(1, 1, 1)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 16
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        b.MouseButton1Click:Connect(function()
            step(dir)
            lbl.Text = getText()
        end)
    end
    small("-", 0, -1)
    small("+", 1, 1)
end

local function header(text)
    local l = Instance.new("TextLabel", body)
    l.Size = UDim2.new(1, -4, 0, 18)
    l.BackgroundTransparency = 1
    l.Text = "— " .. text .. " —"
    l.TextColor3 = Color3.fromRGB(150, 150, 170)
    l.Font = Enum.Font.GothamBold
    l.TextSize = 11
end

local logBox
local logLines = {}
local function log(s)
    logLines[#logLines + 1] = tostring(s)
    if logBox then logBox.Text = table.concat(logLines, "\n") end
end

header("MISC")
makeToggle("Godmode (Self)", "GodMode") -- FITUR BARU

header("HUMANOID")
local humProps = {"WalkSpeed", "JumpPower", "JumpHeight", "HipHeight", "Health", "MaxHealth"}
local humBoxes = {}
for _, name in ipairs(humProps) do
    local row = Instance.new("Frame", body)
    row.Size = UDim2.new(1, -4, 0, 26)
    row.BackgroundTransparency = 1
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(0, 95, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    
    local box = Instance.new("TextBox", row)
    box.Position = UDim2.new(0, 100, 0, 1)
    box.Size = UDim2.new(1, -100, 1, -2)
    box.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    box.TextColor3 = Color3.new(1, 1, 1)
    box.Font = Enum.Font.Gotham
    box.TextSize = 12
    box.ClearTextOnFocus = false
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)
    humBoxes[name] = box
    
    box.FocusLost:Connect(function(enter)
        if not enter then return end
        local n = tonumber(box.Text)
        if not n then return end
        if name == "JumpPower" then
            S.desired.JumpPower = n
            S.desired.JumpHeight = nil
            S.desired.UseJumpPower = true
        elseif name == "JumpHeight" then
            S.desired.JumpHeight = n
            S.desired.JumpPower = nil
            S.desired.UseJumpPower = false
        else
            S.desired[name] = n
        end
        applyHumanoid()
    end)
end

makeBtn("Reset Humanoid", function()
    S.desired = {}
    for _, b in pairs(humBoxes) do if not b:IsFocused() then b.Text = "" end end
end)

header("ESP")
makeToggle("ESP Enemy", "ESP")
makeToggle("Chams (Highlight)", "Chams")
makeToggle("Line", "Lines")
makeToggle("Nama + Jarak", "Names")
makeToggle("Health", "Health")
makeToggle("Team Check", "TeamCheck")

header("AIMBOT")
makeToggle("Aimbot", "Aim")
makeBtn("Target: Head", function(b)
    CFG.Part = (CFG.Part == "Head") and "Body" or "Head"
    b.Text = "Target: " .. CFG.Part
end)
makeToggle("Wall Check", "WallCheck")
makeStepper(function() return "FOV: " .. CFG.FOV end, function(d) CFG.FOV = math.clamp(CFG.FOV + d * 20, 30, 800) end)
makeStepper(function() return "Speed: " .. string.format("%.2f", CFG.Smooth) end, function(d) CFG.Smooth = math.clamp(math.floor((CFG.Smooth + d * 0.05) * 100 + 0.5) / 100, 0.05, 1) end)
makeToggle("FOV Circle", "ShowFOV", function(v) fovCircle.Visible = v end)

header("MAGIC & 1SK")
makeToggle("Magic Bullet", "Magic")
makeStepper(function() return "Magic FOV: " .. CFG.MagicFOV end, function(d) CFG.MagicFOV = math.clamp(CFG.MagicFOV + d * 50, 50, 3000) end)
makeToggle("Lead Compensation", "MagicLead")
makeStepper(function() return "Bullet Speed: " .. CFG.BulletSpeed end, function(d) CFG.BulletSpeed = math.clamp(CFG.BulletSpeed + d * 50, 100, 2000) end)
makeToggle("Bullet Track", "Track")
makeToggle("1 Shot 1 Kill", "OneShot")
makeStepper(function() return "Track Speed: " .. CFG.TrackSpeed end, function(d) CFG.TrackSpeed = math.clamp(CFG.TrackSpeed + d * 50, 100, 3000) end)

header("TELEPORT KILL")
makeToggle("Teleport to Head", "TeleKill")
makeToggle("Target All Players", "TeleAny")
makeStepper(function() return "Height: " .. CFG.TeleHeight end, function(d) CFG.TeleHeight = math.clamp(CFG.TeleHeight + d, 1, 20) end)
makeStepper(function() return "Delay: " .. string.format("%.2f", CFG.TeleDelay) end, function(d) CFG.TeleDelay = math.clamp(math.floor((CFG.TeleDelay + d * 0.05) * 100 + 0.5) / 100, 0.05, 1) end)

header("SPY / DEBUG")
makeBtn("Spy Fire Remote: OFF", function(b)
    S.spy = not S.spy
    b.Text = "Spy: " .. (S.spy and "ON" or "OFF")
    b.BackgroundColor3 = S.spy and ONC or OFFC
end)
logBox = Instance.new("TextBox", body)
logBox.Size = UDim2.new(1, -4, 0, 100)
logBox.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
logBox.TextColor3 = Color3.fromRGB(180, 255, 180)
logBox.Font = Enum.Font.Code
logBox.TextSize = 11
logBox.TextXAlignment = Enum.TextXAlignment.Left
logBox.TextYAlignment = Enum.TextYAlignment.Top
logBox.MultiLine = true
logBox.ClearTextOnFocus = false
logBox.TextWrapped = true
logBox.Text = "Log..."
Instance.new("UICorner", logBox).CornerRadius = UDim.new(0, 6)
makeBtn("Copy Log", function() if setclipboard then setclipboard(table.concat(logLines, "\n")) log("(copied)") end end)

local esp = {}
-- Blox Range v2.3 [PART 2/2]

local function updateESP()
    local vp = Camera.ViewportSize
    local from = Vector2.new(vp.X / 2, vp.Y)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            local e = esp[p]
            if not e then
                local hl = Instance.new("Highlight")
                hl.FillColor = Color3.fromRGB(255, 40, 40)
                hl.OutlineColor = Color3.new(1, 1, 1)
                hl.FillTransparency = 0.45
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hl.Parent = holder
                
                local bb = Instance.new("BillboardGui")
                bb.AlwaysOnTop = true
                bb.Size = UDim2.new(0, 150, 0, 22)
                bb.StudsOffset = Vector3.new(0, 3.2, 0)
                bb.Parent = holder
                
                local lb = Instance.new("TextLabel", bb)
                lb.Size = UDim2.new(1, 0, 1, 0)
                lb.BackgroundTransparency = 1
                lb.TextColor3 = Color3.new(1, 1, 1)
                lb.TextStrokeTransparency = 0.2
                lb.Font = Enum.Font.GothamBold
                lb.TextSize = 12
                
                local ln = Instance.new("Frame")
                ln.AnchorPoint = Vector2.new(0.5, 0.5)
                ln.BorderSizePixel = 0
                ln.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
                ln.Parent = holder
                
                e = {hl = hl, bb = bb, lb = lb, ln = ln}
                esp[p] = e
            end
            
            local ch = p.Character
            local hum = ch and ch:FindFirstChildOfClass("Humanoid")
            local root = ch and (ch:FindFirstChild("HumanoidRootPart") or ch:FindFirstChild("Head"))
            
            if ch and root and hum and hum.Health > 0 and isEnemy(p) and CFG.ESP then
                if e.hl.Adornee ~= ch then e.hl.Adornee = ch end
                if e.bb.Adornee ~= root then e.bb.Adornee = root end
                e.hl.Enabled = CFG.Chams
                
                local parts = {}
                if CFG.Names then parts[#parts + 1] = string.format("%s [%d]", p.Name, (Camera.CFrame.Position - root.Position).Magnitude) end
                if CFG.Health then parts[#parts + 1] = math.floor(hum.Health) .. "HP" end
                e.bb.Enabled = #parts > 0
                e.lb.Text = table.concat(parts, " ")
                
                local sp = Camera:WorldToViewportPoint(root.Position)
                if CFG.Lines and sp.Z > 0 then
                    local to = Vector2.new(sp.X, sp.Y)
                    local d = to - from
                    e.ln.Visible = true
                    e.ln.Position = UDim2.fromOffset((from.X + to.X) / 2, (from.Y + to.Y) / 2)
                    e.ln.Size = UDim2.fromOffset(d.Magnitude, 2)
                    e.ln.Rotation = math.deg(math.atan2(d.Y, d.X))
                else
                    e.ln.Visible = false
                end
            else
                e.hl.Enabled = false
                e.bb.Enabled = false
                e.ln.Visible = false
            end
        end
    end
end

local fireNames = {FireRifle = true, FirePistol = true, FireSniper = true, FireLMG = true, FireRocket = true}

S.rewrite = function(args, tgt, origin)
    local tpos = leadPosition(tgt, origin)
    local dir = (tpos - origin).Unit
    local function fix(v, depth)
        local t = typeof(v)
        if t == "Vector3" then
            if v.Magnitude > 0.9 and v.Magnitude < 1.1 then return dir
            elseif (v - origin).Magnitude > 15 then return tpos end
            return v
        elseif t == "CFrame" then
            if (v.Position - origin).Magnitude > 15 then return CFrame.new(tpos) end
            return CFrame.lookAt(v.Position, v.Position + dir)
        elseif t == "table" and depth < 2 then
            local n = {}
            for k, x in pairs(v) do n[k] = fix(x, depth + 1) end
            return n
        end
        return v
    end
    local out = {}
    for i = 1, args.n do out[i] = fix(args[i], 0) end
    return out
end

S.spyFn = function(name, args)
    local t = {}
    for i = 1, args.n do t[i] = tostring(args[i]) end
    log(name .. "(" .. table.concat(t, ", ") .. ")")
end

local function noteRecent(inst)
    local part = inst:IsA("BasePart") and inst or (inst:IsA("Model") and inst.PrimaryPart)
    if part then S.recentParts[#S.recentParts + 1] = {part = part, time = tick()} end
end
Workspace.DescendantAdded:Connect(noteRecent)

local function beginTracking(part)
    if not part then return end
    S.trackTargetPart = part
    S.trackTargetHum = part.Parent and part.Parent:FindFirstChildOfClass("Humanoid")
    S.trackWindow = tick() + 1.5
    S.oneShotWindow = tick() + 3.0
end

if not S.hooked and hookmetamethod and getnamecallmethod then
    S.hooked = true
    local old
    old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local m = getnamecallmethod()
        if m == "FireServer" and typeof(self) == "Instance" then
            local args = table.pack(...)
            if S.spy and S.spyFn then S.spyFn(self.Name, args) end
            
            local tgt = S.magicOn and S.magicTarget
            if tgt and tgt.Parent and S.camPos and S.rewrite and (fireNames[self.Name] or CFG.Magic) then
                local okr, newArgs = pcall(S.rewrite, args, tgt, S.camPos)
                if okr then
                    if setnamecallmethod then setnamecallmethod(m) end
                    local r = old(self, table.unpack(newArgs, 1, args.n))
                    if CFG.Track or CFG.OneShot then beginTracking(tgt) end
                    return r
                end
            end
            
            if (CFG.Track or CFG.OneShot) and not tgt then
                local nearest = getNearestEnemyHead()
                if nearest then beginTracking(nearest:FindFirstChild("Head") or nearest:FindFirstChild("HumanoidRootPart")) end
            end
            
            if setnamecallmethod then setnamecallmethod(m) end
            return old(self, ...)
        end
        return old(self, ...)
    end))
end

-- PERBAIKAN HOOK: Godmode + 1SK + Humanoid
if hookmetamethod and not S.oneshotHooked then
    S.oneshotHooked = true
    local old
    old = hookmetamethod(game, "__newindex", newcclosure(function(self, key, value)
        -- 1 Shot 1 Kill (Musuh)
        if CFG.OneShot and S.trackTargetHum == self and key == "Health" then
            if typeof(value) == "number" and value > 0 and tick() < (S.oneShotWindow or 0) then
                return old(self, key, 0)
            end
        end
        
        -- Godmode (Diri Sendiri)
        if CFG.GodMode and S.humanoidRef == self and key == "Health" then
            if typeof(value) == "number" and value < S.humanoidRef.MaxHealth then
                return old(self, key, S.humanoidRef.MaxHealth)
            end
        end
        
        -- Humanoid Monitor (Diri Sendiri)
        if not S.internalWrite and S.humanoidRef == self and S.desired[key] ~= nil then
            if not (key == "Health" and typeof(value) == "number" and value <= 0) then
                return old(self, key, S.desired[key])
            end
        end
        
        return old(self, key, value)
    end))
end

RunService.Heartbeat:Connect(function()
    local hum = S.humanoidRef
    if hum and hum.Parent then
        if next(S.desired) then applyHumanoid() end
        for name, box in pairs(humBoxes) do
            if not box:IsFocused() then
                local v = hum[name]
                if v ~= nil then box.Text = tostring(math.floor(v * 100) / 100) end
            end
        end
    end
    
    if #S.trackBullets > 0 then
        local now = tick()
        for i = #S.trackBullets, 1, -1 do
            local tb = S.trackBullets[i]
            local part, target = tb.part, tb.target
            if not (part and part.Parent and target and target.Parent and (now - tb.created) < 5) then
                table.remove(S.trackBullets, i)
            else
                local lead = leadPosition(target, part.Position)
                local delta = lead - part.Position
                if delta.Magnitude < CFG.TrackKillRadius then
                    if CFG.OneShot and S.trackTargetHum and S.trackTargetHum.Health > 0 then
                        pcall(function() S.trackTargetHum.Health = 0 end)
                    end
                    table.remove(S.trackBullets, i)
                else
                    local step = math.min(delta.Magnitude, tb.speed * 0.0167)
                    pcall(function()
                        part.CFrame = CFrame.lookAt(part.Position + delta.Unit * step, lead)
                        part.AssemblyLinearVelocity = delta.Unit * tb.speed
                    end)
                end
            end
        end
    end
    
    if CFG.TeleKill then
        local myChar = LP.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
        if not (myChar and myRoot and myHum and myHum.Health > 0) then S.teleTarget = nil return end
        
        local tgt = S.teleTarget
        local tgtValid = false
        if tgt and tgt.Parent then
            local h = tgt:FindFirstChildOfClass("Humanoid")
            local head = tgt:FindFirstChild("Head")
            if h and h.Health > 0 and head then tgtValid = true end
        end
        
        if not tgtValid then S.teleTarget = getNearestEnemyHead() end
        
        if S.teleTarget and tick() >= (S.teleNext or 0) then
            local head = S.teleTarget:FindFirstChild("Head")
            if head then
                local dest = CFrame.new(head.Position + Vector3.new(0, CFG.TeleHeight, 0))
                local ok = pcall(function() myChar:PivotTo(dest) end)
                if not ok then pcall(function() myRoot.CFrame = dest end) end
                S.teleNext = tick() + CFG.TeleDelay
            end
        end
    else
        S.teleTarget = nil
    end
end)

RunService:BindToRenderStep("BR_Main", 10000, function()
    Camera = Workspace.CurrentCamera
    if not Camera then return end
    S.camPos = Camera.CFrame.Position
    
    local curFov = math.rad(math.clamp(Camera.FieldOfView, 1, 120))
    local r = CFG.FOV * math.tan(BASE_FOV / 2) / math.tan(curFov / 2)
    fovCircle.Size = UDim2.new(0, r * 2, 0, r * 2)
    
    if CFG.Aim then
        local t = getTarget(CFG.FOV)
        if t then Camera.CFrame = Camera.CFrame:Lerp(CFrame.lookAt(S.camPos, t.Position), CFG.Smooth) end
    end
    
    S.magicOn = CFG.Magic
    S.magicTarget = CFG.Magic and getTarget(CFG.MagicFOV, true) or nil
    
    updateESP()
end)

LP.CharacterAdded:Connect(function()
    S.desired = {}
    S.humanoidRef = nil
    S.teleTarget = nil
    task.wait(0.3)
    trackHum()
    for _, b in pairs(humBoxes) do
        if not b:IsFocused() then b.Text = "" end
    end
end)
trackHum()

G.BR_CLEANUP = function()
    S.magicOn, S.spy = false, false
    S.trackBullets = {}
    S.recentParts = {}
    pcall(function() RunService:UnbindFromRenderStep("BR_Main") end)
    dragConn:Disconnect()
    gui:Destroy()
end
log("v2.3 loaded. Godmode Added.")
