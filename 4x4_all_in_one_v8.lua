-- 4x4 MENU - all parts in one file (Parts 1, 2, 3A, 3B, 4, 6, 7)
do
-- ===== PART 1 (run this FIRST) =====
local LOGO_ID = ""  -- optional "rbxassetid://123456789"
local lp = game:GetService("Players").LocalPlayer
local UIS = game:GetService("UserInputService")
local RepStore = game:GetService("ReplicatedStorage")
local G = getgenv()
G.T4 = G.T4 or {}
local S = G.T4
for k, v in pairs({NoDmg = true, Fuel = false, Roll = true, RollLim = 50, Ghost = true, Ray = false,
    GRange = 45, Slope = true, MinSpd = 8, Stab = true, Spd = false, SpdMax = 50, Tow = false, TowSpd = 6}) do
    if S[k] == nil then S[k] = v end
end
G.NoDmg = S.NoDmg
for _, k in ipairs({"GhostConn", "MainConn", "RollConn", "AssistConn"}) do
    if G[k] then pcall(function() G[k]:Disconnect() end) G[k] = nil end
end
if S.conn then pcall(function() S.conn:Disconnect() end) end
for _, t in ipairs({G.GhostChanged or {}, S.gch or {}}) do
    for p, o in pairs(t) do if p.Parent then p.CanCollide = o[1] p.CanQuery = o[2] end end
end
G.GhostChanged = nil
S.gch, S.fl, S.ta = {}, nil, 0

-- shared table between part 1 and part 2
local X = {mode = 2, MIN = 8, tagCount = 0, lastPart = nil, lastMat = "none", tags = {}, lines = {}, hookMsg = "hook: active"}
G.T4X = X

local car
for _, m in ipairs(workspace:GetDescendants()) do
    if m:IsA("Model") and m.Name:find("^OffroadCar_") and m.Name:find(lp.Name, 1, true) then car = m break end
end
if not car then warn("car not found") return end
local root, best = nil, -1
for _, d in ipairs(car:GetDescendants()) do
    if d:IsA("BasePart") and d.Mass > best then root, best = d, d.Mass end
end
X.car, X.root = car, root

-- ===== hook: no damage + fuel lock =====
local function clean(st)
    if type(st) ~= "table" then return end
    local s = rawget(st, "Sys")
    if type(s) == "table" then
        s.Level = 0 s.Power = 1 s.MisfireLeft = 0
        if s.StallLeft ~= nil then s.StallLeft = 0 end
    end
    if rawget(st, "HitWrecked") ~= nil then st.HitWrecked = false end
    if rawget(st, "EngineState") == "Wrecked" then st.EngineState = "Off" end
end
local okh, errh = pcall(function()
    local gauge = require(RepStore.OffroadCar.DamageGauge)
    if S.hooked ~= gauge then
        S.hooked = gauge
        local orig
        orig = hookfunction(gauge.Step, function(a, b, ...)
            if S.NoDmg then clean(a) clean(b) end
            if type(a) == "table" and type(rawget(a, "Fuel")) == "number" then
                S.fs = a
                if S.Fuel then
                    if not S.fl or a.Fuel > S.fl then S.fl = a.Fuel end
                    a.Fuel = S.fl
                end
            end
            return orig(a, b, ...)
        end)
    end
end)
if not okh then X.hookMsg = "hook FAILED: " .. tostring(errh) end

-- ===== UI helpers =====
local ok0, parent = pcall(function() return gethui() end)
if not ok0 or not parent then parent = lp:WaitForChild("PlayerGui") end
for _, g in ipairs(parent:GetChildren()) do
    if g.Name == "LogGui" or g.Name == "BoostGui" or g.Name == "AssistGui" or g.Name == "NoDmgGui" or g.Name == "GhostGui" then g:Destroy() end
end
local gui = Instance.new("ScreenGui")
gui.Name = "BoostGui" gui.ResetOnSpawn = false gui.Parent = parent

local BLUE, GREY = Color3.fromRGB(0, 120, 255), Color3.fromRGB(50, 54, 70)
local ON, OFF = Color3.fromRGB(30, 140, 60), Color3.fromRGB(160, 50, 50)
local function corner(o, r) local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, r) c.Parent = o end
local function btn(par, x, y, w, text, col)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, w, 0, 30) b.Position = UDim2.new(0, x, 0, y)
    b.BackgroundColor3 = col or BLUE b.TextColor3 = Color3.new(1, 1, 1)
    b.TextSize = 11 b.Text = text b.Parent = par corner(b, 6)
    return b
end
local function lbl(par, x, y, w, h, text)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0, w, 0, h) l.Position = UDim2.new(0, x, 0, y)
    l.BackgroundTransparency = 1 l.TextColor3 = Color3.fromRGB(190, 255, 190)
    l.TextSize = 10 l.TextWrapped = true l.Text = text
    l.TextXAlignment = Enum.TextXAlignment.Left l.TextYAlignment = Enum.TextYAlignment.Top
    l.Parent = par
    return l
end
local function tog(par, x, y, w, key, name, cb)
    local b = btn(par, x, y, w, "")
    local function p() b.Text = name .. (S[key] and ": ON" or ": OFF") b.BackgroundColor3 = S[key] and ON or OFF end
    p()
    b.MouseButton1Click:Connect(function() S[key] = not S[key] p() if cb then cb(S[key]) end end)
end
local function step(par, y, key, name, lo, hi, st)
    local l = btn(par, 6, y, 112, "", GREY)
    local function p() l.Text = name .. " " .. S[key] end
    p()
    btn(par, 122, y, 72, "-").MouseButton1Click:Connect(function() S[key] = math.max(lo, S[key] - st) p() end)
    btn(par, 198, y, 72, "+").MouseButton1Click:Connect(function() S[key] = math.min(hi, S[key] + st) p() end)
end
local function makeDraggable(handle, target, onTap)
    local dragging, startIn, startPos, moved = false, nil, nil, 0
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging, moved = true, 0
            startIn, startPos = input.Position, target.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if onTap and moved < 8 then onTap() end
                end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local d = input.Position - startIn
            moved = math.max(moved, d.Magnitude)
            target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

-- icon + window
local icon = Instance.new("Frame")
icon.Size = UDim2.new(0, 40, 0, 40) icon.Position = UDim2.new(0, 12, 0.5, -20)
icon.BackgroundColor3 = BLUE icon.BackgroundTransparency = 0.3 icon.Active = true icon.Parent = gui
corner(icon, 20)
local iconTxt = Instance.new("TextLabel")
iconTxt.Size = UDim2.new(1, 0, 1, 0) iconTxt.BackgroundTransparency = 1 iconTxt.Text = "4x4"
iconTxt.TextColor3 = Color3.new(1, 1, 1) iconTxt.TextSize = 13 iconTxt.Font = Enum.Font.GothamBold iconTxt.Parent = icon
if LOGO_ID ~= "" then
    iconTxt.Visible = false
    local img = Instance.new("ImageLabel")
    img.Size = UDim2.new(1, -6, 1, -6) img.Position = UDim2.new(0, 3, 0, 3)
    img.BackgroundTransparency = 1 img.Image = LOGO_ID img.Parent = icon
    corner(img, 20)
end
local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 280, 0, 230) panel.Position = UDim2.new(0, 64, 0, 40)
panel.BackgroundColor3 = Color3.fromRGB(25, 27, 35) panel.BackgroundTransparency = 0.1
panel.Visible = false panel.Parent = gui
corner(panel, 10)
local title = Instance.new("Frame")
title.Size = UDim2.new(1, 0, 0, 28) title.BackgroundColor3 = Color3.fromRGB(40, 44, 58) title.Active = true title.Parent = panel
corner(title, 10)
local tl = lbl(title, 10, 0, 220, 28, "4x4 MENU  (drag here)")
tl.TextSize = 12 tl.TextColor3 = Color3.new(1, 1, 1) tl.Font = Enum.Font.GothamBold tl.TextYAlignment = Enum.TextYAlignment.Center
makeDraggable(icon, icon, function() panel.Visible = not panel.Visible end)
makeDraggable(title, panel, nil)
local xb = btn(title, 252, 0, 28, "X", Color3.fromRGB(200, 50, 50))
xb.MouseButton1Click:Connect(function() panel.Visible = false end)

local P, T = {}, {}
local TABS = {{"mud", "MUD"}, {"safe", "SAFE"}, {"ghost", "GHOST"}, {"drive", "DRIVE"}, {"tow", "TOW"}}
local function show(n)
    for k, f in pairs(P) do f.Visible = (k == n) end
    for k, b in pairs(T) do b.BackgroundColor3 = (k == n) and BLUE or GREY end
end
for i, t in ipairs(TABS) do
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 170) f.Position = UDim2.new(0, 0, 0, 56) f.BackgroundTransparency = 1
    f.Visible = false f.Parent = panel
    P[t[1]] = f
    local b = btn(panel, 4 + (i - 1) * 55, 31, 53, t[2], GREY)
    b.Size = UDim2.new(0, 53, 0, 22) b.TextSize = 10 b.Font = Enum.Font.GothamBold
    T[t[1]] = b
    b.MouseButton1Click:Connect(function() show(t[1]) end)
end
show("mud")

-- ===== MUD page =====
local pm = P.mud
local hud = lbl(pm, 6, 0, 268, 44, "")
local mb = btn(pm, 6, 48, 86, "")
local minus = btn(pm, 98, 48, 86, "MIN -")
local plus = btn(pm, 190, 48, 84, "MIN +")
local tagb = btn(pm, 6, 82, 86, "TAG MUD")
local clrb = btn(pm, 98, 82, 86, "RESET TAGS")
local colb = btn(pm, 190, 82, 84, "COLOR: ON")
local cb = btn(pm, 6, 116, 268, "COPY LOG")
local MODES = {"OFF", "MUD ONLY", "ALWAYS"}
mb.Text = MODES[X.mode]
mb.MouseButton1Click:Connect(function() X.mode = X.mode % 3 + 1 mb.Text = MODES[X.mode] end)
minus.MouseButton1Click:Connect(function() X.MIN = math.max(2, X.MIN - 2) end)
plus.MouseButton1Click:Connect(function() X.MIN = math.min(30, X.MIN + 2) end)
local SEED_LO, SEED_HI = Vector3.new(0.43, 0.265, 0.16), Vector3.new(0.515, 0.34, 0.22)
local lo, hi, useColor = SEED_LO, SEED_HI, true
colb.MouseButton1Click:Connect(function() useColor = not useColor colb.Text = useColor and "COLOR: ON" or "COLOR: OFF" end)
local function colorMud(part)
    if not useColor then return false end
    local c = part.Color
    return c.R >= lo.X and c.R <= hi.X and c.G >= lo.Y and c.G <= hi.Y and c.B >= lo.Z and c.B <= hi.Z
        and part:FindFirstAncestor("Ground") ~= nil
end
local lines = X.lines
cb.MouseButton1Click:Connect(function() pcall(function() setclipboard(table.concat(lines, "\n")) end) end)
tagb.MouseButton1Click:Connect(function()
    if X.lastPart and X.lastMat ~= "Water" then
        if not X.tags[X.lastPart] then X.tagCount = X.tagCount + 1 end
        X.tags[X.lastPart] = true
        local c = X.lastPart.Color
        lo = Vector3.new(math.min(lo.X, c.R - 0.015), math.min(lo.Y, c.G - 0.015), math.min(lo.Z, c.B - 0.015))
        hi = Vector3.new(math.max(hi.X, c.R + 0.015), math.max(hi.Y, c.G + 0.015), math.max(hi.Z, c.B + 0.015))
        table.insert(lines, "TAG " .. X.lastPart:GetFullName() .. " col " .. string.format("%.3f,%.3f,%.3f", c.R, c.G, c.B))
    end
end)
clrb.MouseButton1Click:Connect(function() X.tags, X.tagCount = {}, 0 lo, hi = SEED_LO, SEED_HI end)

-- ===== SAFE page =====
local ps = P.safe
tog(ps, 6, 4, 130, "NoDmg", "NO DAMAGE", function(v) G.NoDmg = v end)
tog(ps, 144, 4, 130, "Fuel", "FUEL LOCK", function() S.fl = nil end)
tog(ps, 6, 38, 86, "Roll", "ROLL")
local limB = btn(ps, 98, 38, 86, "LIM " .. S.RollLim, GREY)
limB.MouseButton1Click:Connect(function() S.RollLim = S.RollLim >= 80 and 40 or S.RollLim + 10 limB.Text = "LIM " .. S.RollLim end)
local flipB = btn(ps, 190, 38, 84, "FLIP", Color3.fromRGB(200, 120, 0))
flipB.MouseButton1Click:Connect(function()
    local pc = car:GetPivot()
    local look = Vector3.new(pc.LookVector.X, 0, pc.LookVector.Z)
    if look.Magnitude < 0.2 then look = Vector3.new(pc.RightVector.X, 0, pc.RightVector.Z) end
    if look.Magnitude < 0.01 then look = Vector3.new(0, 0, -1) end
    local p = pc.Position + Vector3.new(0, 4, 0)
    car:PivotTo(CFrame.lookAt(p, p + look.Unit))
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
end)
local fuelL = lbl(ps, 6, 76, 268, 30, "")
lbl(ps, 6, 108, 268, 58, "FUEL LOCK freezes the tank at the level it has when you switch it ON. Switch OFF and it drains normally from there. ON again locks at the new level. Turn it on BEFORE the tank is empty (refuel first if it already is).")

-- ===== GHOST page =====
local pg = P.ghost
local function restoreG()
    for p, o in pairs(S.gch) do if p.Parent then p.CanCollide = o[1] p.CanQuery = o[2] end S.gch[p] = nil end
end
tog(pg, 6, 4, 130, "Ghost", "GHOST", function(v) if not v then restoreG() end end)
tog(pg, 144, 4, 130, "Ray", "RAY")
step(pg, 38, "GRange", "RANGE", 15, 120, 10)
btn(pg, 6, 72, 268, "PROBE (copy nearby parts)").MouseButton1Click:Connect(function()
    local o, p2 = {}, OverlapParams.new()
    p2.FilterType = Enum.RaycastFilterType.Exclude
    p2.FilterDescendantsInstances = {car}
    for i, p in ipairs(workspace:GetPartBoundsInRadius(root.Position, 14, p2)) do
        if i > 30 then break end
        o[#o + 1] = string.format("%s | %s | cc=%s cq=%s | size=%s", p.ClassName,
            p:GetFullName():gsub("^Workspace%.", ""), tostring(p.CanCollide), tostring(p.CanQuery), tostring(p.Size))
    end
    pcall(function() setclipboard(table.concat(o, "\n")) end)
end)
lbl(pg, 6, 108, 268, 40, "Rocks and logs near you become non-solid. Ground tiles stay solid. RAY also hides them from the wheels.")

-- ===== DRIVE page =====
local pd = P.drive
tog(pd, 6, 4, 130, "Slope", "SLOPE")
tog(pd, 144, 4, 130, "Stab", "STABILIZE")
step(pd, 38, "MinSpd", "MIN", 2, 40, 2)
tog(pd, 6, 72, 130, "Spd", "SPEED SET")
step(pd, 106, "SpdMax", "MAX km/h", 20, 60, 5)
local infoD = lbl(pd, 6, 140, 268, 28, "")

-- ===== TOW page =====
local pt = P.tow
tog(pt, 6, 4, 130, "Tow", "TOW", function() S.ta = 0 end)
step(pt, 38, "TowSpd", "TOW km/h", 2, 30, 2)
lbl(pt, 6, 72, 268, 64, "Smooth tow: pulls with a force that ramps up slowly until the truck reaches the TOW speed, then holds it. Hold GAS (or HOLD cruise) while towing. Mud boost is paused while TOW is ON.")
local infoT = lbl(pt, 6, 140, 268, 28, "")

-- hand everything to part 2
X.gui, X.panel, X.P = gui, panel, P
X.hud, X.fuelL, X.infoD, X.infoT = hud, fuelL, infoD, infoT
X.MODES, X.colorMud = MODES, colorMud
print("Part 1 loaded - now run Part 2")

end
do
-- ===== PART 2 (run this AFTER part 1) =====
local G = getgenv()
local X = G.T4X
if not X or not X.car then warn("Run Part 1 first") return end
local S = G.T4
local lp = game:GetService("Players").LocalPlayer
local RS = game:GetService("RunService")
local car, root, gui, panel, P = X.car, X.root, X.gui, X.panel, X.P
local hud, fuelL, infoD, infoT = X.hud, X.fuelL, X.infoD, X.infoT
local MODES, colorMud, lines = X.MODES, X.colorMud, X.lines

if S.conn then pcall(function() S.conn:Disconnect() end) end

local function short(i)
    local p = i.Parent
    local s = i.Name
    if p then s = s .. "<" .. p.Name end
    if p and p.Parent then s = s .. "<" .. p.Parent.Name end
    return s
end
local function pos(o)
    if not o then return nil end
    if o:IsA("BasePart") then return o.Position end
    if o:IsA("Model") then return o:GetPivot().Position end
    if o:IsA("Attachment") then return o.WorldPosition end
end
local function wheelForward()
    local ch = car:FindFirstChild("Chassis")
    if not ch then return nil end
    local fl, fr = pos(ch:FindFirstChild("WheelFL")), pos(ch:FindFirstChild("WheelFR"))
    local rl, rr = pos(ch:FindFirstChild("WheelRL")), pos(ch:FindFirstChild("WheelRR"))
    if not (fl and fr and rl and rr) then return nil end
    local d = (fl + fr) / 2 - (rl + rr) / 2
    if d.Magnitude < 0.5 then return nil end
    return d.Unit
end
local function hudRead()
    local h, kmh = false, nil
    for _, d in ipairs(lp.PlayerGui.OffroadHud:GetDescendants()) do
        if d:IsA("TextLabel") and d.Visible then
            local t = d.Text
            if t:match("^HOLD%s*%d+") then h = true end
            if not kmh and t:match("^%d+$") and d:FindFirstAncestor("Speed") and d:FindFirstAncestor("Gearbox") then kmh = tonumber(t) end
        end
    end
    return h, kmh
end

-- ===== main loop =====
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude
rp.FilterDescendantsInstances = {car}
rp.IgnoreWater = false
local op = OverlapParams.new()
op.FilterType = Enum.RaycastFilterType.Exclude
op.FilterDescendantsInstances = {car}
local AX = {Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1)}
local votes = {0, 0, 0, 0}
local ref, acc, gacc, calT, holdFlag, info = 0, 0, 0, 0, false, "-"
local skipG = setmetatable({}, {__mode = "k"})  -- parts already checked and not ghostable (perf cache)

S.conn = RS.Heartbeat:Connect(function(dt)
    if not car.Parent or not gui.Parent then return end
    local mode, MIN, tags = X.mode, X.MIN, X.tags
    local v = root.AssemblyLinearVelocity
    local h = Vector3.new(v.X, 0, v.Z)
    local spd = h.Magnitude
    local gear = car:GetAttribute("Gear") or 1
    local gas = car:GetAttribute("Gas") or 0
    local braking = car:GetAttribute("Brake") == true
    local mass = root.AssemblyMass
    local sc = S.scale or 1
    local g = workspace.Gravity

    -- learn forward axis
    if spd > 6 and gear > 0 then
        local lv = root.CFrame:VectorToObjectSpace(h.Unit)
        local bi, bd = 1, -2
        for i, a in ipairs(AX) do
            local d = lv:Dot(a)
            if d > bd then bi, bd = i, d end
        end
        if bd > 0.9 then votes[bi] = votes[bi] + 1 end
    end
    local fi, fv = 1, -1
    for i, c in ipairs(votes) do if c > fv then fi, fv = i, c end end
    local haveFwd = fv >= 5
    local dirW = Vector3.new(0, 0, 0)
    if haveFwd then
        local d = root.CFrame:VectorToWorldSpace(AX[fi])
        d = Vector3.new(d.X, 0, d.Z)
        if d.Magnitude > 0.1 then dirW = d.Unit if gear < 0 then dirW = -dirW end end
    end
    local along = (dirW.Magnitude > 0) and h:Dot(dirW) or spd

    -- ground check
    local mat, inMud, gname, colTxt = "none", false, "-", "-"
    local hit = workspace:Raycast(root.Position + Vector3.new(0, 3, 0), Vector3.new(0, -25, 0), rp)
    if hit then
        local part = hit.Instance
        mat = tostring(hit.Material):gsub("Enum%.Material%.", "")
        gname = short(part)
        local c = part.Color
        colTxt = string.format("%.2f,%.2f,%.2f", c.R, c.G, c.B)
        X.lastPart, X.lastMat = part, mat
        inMud = hit.Material == Enum.Material.Mud or hit.Material == Enum.Material.Water
            or part:FindFirstAncestor("MudRuts") ~= nil or tags[part] == true or colorMud(part)
    end
    local grounded = hit ~= nil and hit.Distance < 8

    -- mud boost (paused while towing)
    local hold = mode ~= 1 and not braking and gear ~= 0 and not S.Tow and (mode == 3 or inMud)
    local pushed = false
    if hold then
        if spd >= ref then ref = spd end
        local target = inMud and math.max(ref, MIN) or ref
        if along < target - 0.3 then
            if not inMud and spd < ref * 0.25 then
                ref = spd
            else
                local dir = dirW
                if dir.Magnitude == 0 and spd > 3 then dir = h.Unit end
                if dir.Magnitude > 0 then
                    root:ApplyImpulse(dir * mass * math.min(target - along, 2))
                    pushed = true
                end
            end
        end
    else
        ref = spd
    end

    -- HUD read + speed calibration (km/h per stud/s)
    calT = calT - dt
    if calT <= 0 then
        calT = 0.4
        local okr, hf, kmh = pcall(hudRead)
        if okr then holdFlag = hf end
        if okr and kmh and kmh >= 5 and spd > 8 then
            local r = math.clamp(kmh / spd, 0.3, 5)
            S.scale = S.cal and (S.scale * 0.8 + r * 0.2) or r
            S.cal = true
        end
    end

    -- fuel keep-alive
    if S.Fuel and S.fs and S.fl and S.fs.Fuel < S.fl then S.fs.Fuel = S.fl end

    -- slope / tow / speed set
    local fwd = wheelForward()
    local drive = not braking and gear ~= 0 and (gas > 0.05 or holdFlag)
    local st = "idle"
    if fwd and drive and not pushed then
        local d3 = gear < 0 and -fwd or fwd
        local al = v:Dot(d3)
        local uphill = math.max(0, g * d3.Y)
        if S.Tow then
            local tgtKmh = S.Spd and math.min(S.SpdMax, 60) or S.TowSpd
            local vt = tgtKmh / sc
            if al < vt - 0.4 then S.ta = math.min(S.ta + 35 * dt, g * 2.5)
            elseif al > vt + 0.3 then S.ta = math.max(S.ta - 90 * dt, 0) end
            local a = math.min(S.ta + uphill * 1.05, g * 2.5)
            root:ApplyImpulse(d3 * mass * a * dt)
            if al > vt + 1.5 then root:ApplyImpulse(-d3 * mass * math.min((al - vt) * 4, 40) * dt) end
            st = string.format("TOW a=%.0f  %.0f/%d km/h", S.ta, al * sc, tgtKmh)
        else
            S.ta = 0
            if S.Slope and al < S.MinSpd - 0.3 then
                local accel = math.min(uphill * 1.15 + (S.MinSpd - al) * 8, g * 1.5)
                root:ApplyImpulse(d3 * mass * accel * dt)
                st = string.format("SLOPE a=%.0f", accel)
            end
        end
    else
        S.ta = 0
    end
    if S.Spd and not S.Tow and gear > 0 then
        local vmax = math.min(S.SpdMax, 60) / sc
        if spd > vmax + 0.3 then
            root:ApplyImpulse(-h.Unit * mass * math.min((spd - vmax) * 3, 60) * dt)
            st = "LIMIT " .. S.SpdMax
        elseif fwd and drive and grounded and spd > 2 then
            local al = v:Dot(fwd)
            if al < vmax - 0.5 then
                -- strong push toward the set speed, ignores the gear limit
                local accel = math.min((vmax - al) * 4 + 15, 90)
                root:ApplyImpulse(fwd * mass * accel * dt)
                st = string.format("BOOST to %d (a=%.0f)", S.SpdMax, accel)
            else
                st = "AT SPEED " .. S.SpdMax
            end
        end
    end

    -- stabilizer (grip + downforce + damping)
    if S.Stab and fwd and grounded and spd > 10 then
        local up = root.CFrame.UpVector
        local right = fwd:Cross(up)
        if right.Magnitude > 0.1 then
            right = right.Unit
            root:ApplyImpulse(-right * v:Dot(right) * mass * math.min(1, 3 * dt))
        end
        local w = root.AssemblyAngularVelocity
        local wy = up * w:Dot(up)
        local steer = math.abs(car:GetAttribute("Steer") or 0)
        w = w - (w - wy) * math.min(1, 1.2 * dt)
        if steer < 0.15 then w = w - wy * math.min(1, 3 * dt) end
        root.AssemblyAngularVelocity = w
        root:ApplyImpulse(-up * mass * 0.008 * spd * spd * dt)
    end

    -- anti-roll
    if S.Roll then
        local up = root.CFrame.UpVector
        local ang = math.deg(math.acos(math.clamp(up.Y, -1, 1)))
        if ang > S.RollLim then
            local axis = up:Cross(Vector3.yAxis)
            if axis.Magnitude < 1e-3 then axis = root.CFrame.LookVector end
            axis = axis.Unit
            local w = root.AssemblyAngularVelocity
            w = w - axis * w:Dot(axis) * math.min(1, 5 * dt) + axis * (math.rad(ang - S.RollLim) * 20 * dt)
            root.AssemblyAngularVelocity = w
        end
    end

    -- ghost rocks
    gacc = gacc + dt
    if S.Ghost and gacc >= 0.2 then
        gacc = 0
        local budget = 120  -- max new parts examined per pass (spreads the cost over frames)
        for _, p in ipairs(workspace:GetPartBoundsInRadius(root.Position, S.GRange, op)) do
            if not S.gch[p] and not skipG[p] and p.CanCollide and budget > 0 and not p:IsA("Terrain") then
                budget = budget - 1
                local a, okp = p.Parent, true
                while a and a ~= workspace do
                    if a.Name == "Ground" or a.Name:find("^OffroadCar_") or game.Players:GetPlayerFromCharacter(a) then okp = false break end
                    a = a.Parent
                end
                if okp then S.gch[p] = {p.CanCollide, p.CanQuery} p.CanCollide = false else skipG[p] = true end
            end
            if S.Ray and S.gch[p] then p.CanQuery = false end
        end
    end

    -- UI text
    if panel.Visible then
        if P.mud.Visible then
            hud.Text = string.format("%s | spd %.1f  min %d | fwd:%s | tags %d\n%s | mud:%s | brake:%s\n%s  col %s",
                MODES[mode], spd, MIN, tostring(haveFwd), X.tagCount, mat, tostring(inMud), tostring(braking), gname, colTxt)
        elseif P.safe.Visible then
            fuelL.Text = X.hookMsg .. "\nfuel: " .. (S.fs and string.format("%.2f", S.fs.Fuel) or "n/a")
                .. (S.Fuel and S.fl and string.format("   (locked at %.2f)", S.fl) or "")
        elseif P.drive.Visible then
            infoD.Text = string.format("%.0f km/h | cal %.2f | %s", spd * sc, sc, st)
        elseif P.tow.Visible then
            infoT.Text = string.format("%.0f km/h | cal %.2f | %s", spd * sc, sc, st)
        end
    end
    acc = acc + dt
    if acc >= 0.5 then
        acc = 0
        table.insert(lines, string.format("spd %.1f al %.1f tgt %.1f %s hold:%s mud:%s | %s | col %s",
            spd, along, ref, mat, tostring(hold), tostring(inMud), gname, colTxt))
        if #lines > 300 then table.remove(lines, 1) end
    end
end)
print("Part 2 loaded")

end
do
-- ===== PART 3A v2: PHASE + ENGINE LOGIC (run AFTER part 1 and part 2, BEFORE part 3B) =====
-- TREES  : trees / trunks / bushes become non-solid near you
-- CARS   : other players' cars become non-solid (OFF / TOWED ONLY / ALL NEARBY)
-- RESET  : button that sets the engine damage back to zero
-- Client-side only: only YOU stop colliding. Others see nothing different.

local G = getgenv()
local X = G.T4X
local function note(t)
    warn(t)
    pcall(function() game:GetService("StarterGui"):SetCore("SendNotification", {Title = "Part 3", Text = t, Duration = 8}) end)
end
if not X or not X.car then note("3A: Part 1/2 not loaded (T4X missing) - run them first") return end
local S = G.T4

local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local RepStore = game:GetService("ReplicatedStorage")
local lp = Players.LocalPlayer
local car, root = X.car, X.root

local VER = 5
G.T4P = G.T4P or {}
local Q = G.T4P
for k, v in pairs({Trees = true, Shape = true, Cars = 3, Range = 60, FadeCars = true, FadeMe = false, Ray = true, GhostAttr = false}) do
    if Q[k] == nil then Q[k] = v end
end
if Q.ver ~= VER then Q.ver = VER Q.Cars = 3 end   -- every new version starts in ALL NEARBY

-- ===== clean up a previous run =====
for _, k in ipairs({"conn", "stepConn", "addConn"}) do
    if Q[k] then pcall(function() Q[k]:Disconnect() end) Q[k] = nil end
end
if Q.restoreAll then pcall(Q.restoreAll) Q.restoreAll = nil end

-- ===== state =====
local treeSaved = {}   -- part -> {CanCollide, CanQuery}
local carSaved = {}    -- key (model or part) -> { part -> {CanCollide, CanQuery} }
local flat = {}        -- parts forced non-solid every physics step
local towSeen, towHow = {}, {}
local fadeApplied = 0
local holders = {}
local treeSkip = setmetatable({}, {__mode = "k"})  -- part -> shape-mode it was checked under (perf cache)

local function inMine(p) return p:IsDescendantOf(car) end
local function isCarModel(m) return m:IsA("Model") and m.Name:find("^OffroadCar_") ~= nil end
local function addHolder(m) if m.Parent then holders[m.Parent] = true end end
for _, d in ipairs(workspace:GetDescendants()) do
    if isCarModel(d) then addHolder(d) end
end
addHolder(car)
Q.addConn = workspace.DescendantAdded:Connect(function(d)
    if d:IsA("Model") and isCarModel(d) then addHolder(d) end
end)

local function otherCars()
    local list = {}
    for h in pairs(holders) do
        if h.Parent then
            for _, m in ipairs(h:GetChildren()) do
                if m ~= car and isCarModel(m) then list[#list + 1] = m end
            end
        else
            holders[h] = nil
        end
    end
    return list
end

local function carOf(inst)
    while inst and inst ~= workspace do
        if inst:IsA("Model") and inst.Name:find("^OffroadCar_") then return inst end
        inst = inst.Parent
    end
    return nil
end

-- a "key" is either a car Model or the assembly root part of a car
local function keyFor(p)
    local m = carOf(p)
    if m then return m end
    if p:IsA("BasePart") and not p.Anchored then return p.AssemblyRootPart end
    return nil
end
local function keyPos(key)
    if key:IsA("Model") then return key:GetPivot().Position end
    return key.Position
end
local function keyParts(key)
    local list = {}
    if key:IsA("Model") then
        for _, d in ipairs(key:GetDescendants()) do
            if d:IsA("BasePart") and not inMine(d) then list[#list + 1] = d end
        end
    else
        local ok, conn = pcall(function() return key:GetConnectedParts(true) end)
        if ok and conn then
            for _, d in ipairs(conn) do
                if not inMine(d) and not d.Anchored then list[#list + 1] = d end
            end
        end
        if not inMine(key) then list[#list + 1] = key end
    end
    return list
end

-- find every other car: by name, by seat, AND by physics (heavy unanchored assembly near me)
local sticky = {}   -- assembly roots we already identified (they vanish from spatial queries once CanQuery=false)
local scanOp = OverlapParams.new()
scanOp.FilterType = Enum.RaycastFilterType.Exclude
local function findTargets()
    local targets, nName, nSeat, nMass = {}, 0, 0, 0
    local cars = otherCars()
    for _, m in ipairs(cars) do targets[m] = true nName = nName + 1 end
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= lp and pl.Character then
            local hum = pl.Character:FindFirstChildOfClass("Humanoid")
            local seat = hum and hum.SeatPart
            if seat and not inMine(seat) then
                local k = carOf(seat) or seat.AssemblyRootPart
                if k and not targets[k] then targets[k] = true nSeat = nSeat + 1 end
            end
        end
    end
    -- physics scan
    scanOp.FilterDescendantsInstances = {car}
    local okq, parts = pcall(function()
        return workspace:GetPartBoundsInRadius(root.Position, math.max(Q.Range, 60), scanOp)
    end)
    if okq and parts then
        for _, p in ipairs(parts) do
            if not p.Anchored and not inMine(p) then
                local r = p.AssemblyRootPart
                if r and r ~= root and not r:IsDescendantOf(car) and r.AssemblyMass >= (Q.MinMass or 250) then
                    local m = carOf(r) or r:FindFirstAncestorOfClass("Model")
                    local isChar = m and m:FindFirstChildOfClass("Humanoid")
                    if m and not isChar then
                        -- climb to the whole car model (wheels are separate assemblies!)
                        while m.Parent and m.Parent:IsA("Model") and m.Parent ~= car
                            and m.Parent:GetExtentsSize().Magnitude < 70 do
                            m = m.Parent
                        end
                        if not m:IsDescendantOf(car) and not sticky[m] and m:GetExtentsSize().Magnitude < 90 then sticky[m] = true end
                    elseif not m and not sticky[r] then
                        sticky[r] = true
                    end
                end
            end
        end
    end
    for k in pairs(sticky) do
        if not k.Parent or (keyPos(k) - root.Position).Magnitude > math.max(Q.Range, 60) * 1.4 then
            sticky[k] = nil
        elseif not targets[k] then
            targets[k] = true nMass = nMass + 1
        end
    end
    return targets, cars, nName, nSeat, nMass
end

-- ===== restore helpers =====
local function restoreTrees()
    for p, o in pairs(treeSaved) do
        if p.Parent then p.CanCollide = o[1] p.CanQuery = o[2] end
        treeSaved[p] = nil
    end
end
local function restoreKey(key)
    local saved = carSaved[key]
    if saved then
        for p, o in pairs(saved) do
            if p.Parent then
                p.CanCollide = o[1] p.CanQuery = o[2] p.LocalTransparencyModifier = 0
                if o[3] then pcall(function() p.CollisionGroup = o[3] end) end
            end
        end
        carSaved[key] = nil
    end
end
local function setMeFade(v)
    for _, d in ipairs(car:GetDescendants()) do
        if d:IsA("BasePart") then d.LocalTransparencyModifier = v end
    end
    fadeApplied = v
end
local function restoreAll()
    restoreTrees()
    for k in pairs(carSaved) do restoreKey(k) end
    flat = {}
    pcall(setMeFade, 0)
    if Q.gaOrig ~= nil then pcall(function() car:SetAttribute("Ghost", Q.gaOrig) end) Q.gaOrig = nil end
end
Q.restoreAll = restoreAll

-- ===== tree detection =====
local KEYS = {"tree", "trunk", "palm", "bush", "stump", "log", "fern", "foliage", "branch", "plant", "bamboo", "reed"}
local function isTree(p)
    local a, depth = p, 0
    while a and a ~= workspace and depth < 8 do
        local n = a.Name:lower()
        for _, k in ipairs(KEYS) do
            if n:find(k, 1, true) then return true end
        end
        a = a.Parent
        depth = depth + 1
    end
    if Q.Shape and p.Anchored then
        local s = p.Size
        local w = math.max(s.X, s.Z)
        if s.Y >= 6 and s.Y >= w * 0.9 and math.abs(p.CFrame.UpVector.Y) > 0.8 then
            return true
        end
    end
    return false
end

-- ===== tow detection =====
local function mark(key, how)
    if key and key ~= car then towSeen[key] = os.clock() towHow[key] = how end
end
local function attrTow(model)
    for name, val in pairs(model:GetAttributes()) do
        if name:lower():find("tow") and val then return true end
    end
    return false
end
local function scanModel(model)
    for _, d in ipairs(model:GetDescendants()) do
        local p0, p1
        if d:IsA("Constraint") then
            p0 = d.Attachment0 and d.Attachment0.Parent
            p1 = d.Attachment1 and d.Attachment1.Parent
        elseif d:IsA("WeldConstraint") or d:IsA("JointInstance") then
            p0, p1 = d.Part0, d.Part1
        end
        if p0 and p1 and p0:IsA("BasePart") and p1:IsA("BasePart") then
            local m0, m1 = inMine(p0), inMine(p1)
            if m0 ~= m1 then
                local other = m0 and p1 or p0
                mark(keyFor(other), "constraint")
            end
        end
    end
end
local function scanTow(targets)
    local ok, conn = pcall(function() return root:GetConnectedParts(true) end)
    if ok and conn then
        for _, p in ipairs(conn) do
            if not inMine(p) then mark(keyFor(p), "joint") end
        end
    end
    scanModel(car)
    local nearest, nd = nil, 45
    for key in pairs(targets) do
        local dist = (keyPos(key) - root.Position).Magnitude
        if key:IsA("Model") then
            if dist < 120 then scanModel(key) end
            if dist < 45 and attrTow(key) then mark(key, "attr") end
        end
        if dist < nd then nearest, nd = key, dist end
    end
    if nearest and attrTow(car) then mark(nearest, "attr-me") end
end

-- ===== pick a collision group that does NOT collide with my car =====
Q.ghostGroup = nil
Q.groupInfo = "no group"
pcall(function()
    local PS = game:GetService("PhysicsService")
    local mine = root.CollisionGroup
    local best
    for _, g in ipairs(PS:GetRegisteredCollisionGroups()) do
        local okc, coll = pcall(function() return PS:CollisionGroupsAreCollidable(g.name, mine) end)
        if okc and not coll then
            local nm = g.name:lower()
            if not best or nm:find("ghost") or nm:find("nocollide") or nm:find("none") then best = g.name end
        end
    end
    Q.ghostGroup = best
    Q.groupInfo = best and ("group:" .. best) or ("no free group (mine=" .. tostring(mine) .. ")")
end)

-- ===== force non-solid every physics step (beats the game re-enabling it) =====
local okS, stepSignal = pcall(function() return RS.PreSimulation end)
if not okS or not stepSignal then stepSignal = RS.Stepped end
Q.stepConn = stepSignal:Connect(function()
    for p in pairs(flat) do
        if p.Parent then
            if p.CanCollide then p.CanCollide = false end
            if Q.ghostGroup and p.CollisionGroup ~= Q.ghostGroup then p.CollisionGroup = Q.ghostGroup end
            if Q.Ray and p.CanQuery then p.CanQuery = false end
        end
    end
end)

-- ===== main loop (5x per second) =====
local op = OverlapParams.new()
op.FilterType = Enum.RaycastFilterType.Exclude
local acc, scanAcc, pruneAcc = 0.1, 0, 0   -- 0.1 start offset so this doesn't run on the same frame as Part 2's scan

Q.conn = RS.Heartbeat:Connect(function(dt)
    if not car.Parent then return end
    acc = acc + dt
    if acc < 0.2 then return end
    local step = acc
    acc = 0
    local now = os.clock()
    local targets, cars, nName, nSeat, nMass = findTargets()

    if Q.Cars == 2 then
        scanAcc = scanAcc + step
        if scanAcc >= 0.6 then scanAcc = 0 pcall(scanTow, targets) end
    end

    local ghost = {}
    if Q.Cars == 3 then
        for key in pairs(targets) do
            if (keyPos(key) - root.Position).Magnitude <= Q.Range then ghost[key] = true end
        end
    elseif Q.Cars == 2 then
        for key, t in pairs(towSeen) do
            if now - t < 1.2 and key.Parent then ghost[key] = true end
        end
    end

    for key in pairs(ghost) do
        local saved = carSaved[key]
        if not saved then saved = {} carSaved[key] = saved end
        for _, p in ipairs(keyParts(key)) do
            if not saved[p] then saved[p] = {p.CanCollide, p.CanQuery, p.CollisionGroup} end
            p.CanCollide = false
            if Q.ghostGroup then pcall(function() p.CollisionGroup = Q.ghostGroup end) end
            if Q.Ray then p.CanQuery = false else p.CanQuery = saved[p][2] end
            p.LocalTransparencyModifier = Q.FadeCars and 0.6 or 0
        end
    end
    for key in pairs(carSaved) do
        if not ghost[key] or not key.Parent then restoreKey(key) end   -- untowed / out of range -> normal
    end
    local nf = {}
    for key in pairs(ghost) do
        local saved = carSaved[key]
        if saved then for p in pairs(saved) do nf[p] = true end end
    end
    flat = nf

    -- trees
    if Q.Trees then
        local filter = {car}
        for _, m in ipairs(cars) do filter[#filter + 1] = m end
        op.FilterDescendantsInstances = filter
        local shapeKey = Q.Shape and 2 or 1
        local budget = 150  -- max new parts examined per pass (spreads the cost over frames)
        for _, p in ipairs(workspace:GetPartBoundsInRadius(root.Position, Q.Range, op)) do
            if treeSaved[p] == nil and treeSkip[p] ~= shapeKey and p.CanCollide and p ~= X.lastPart and not flat[p] and budget > 0 then
                budget = budget - 1
                local mdl = p:FindFirstAncestorOfClass("Model")
                local isChar = mdl and mdl:FindFirstChildOfClass("Humanoid")
                if not isChar and isTree(p) then
                    treeSaved[p] = {p.CanCollide, p.CanQuery}
                    p.CanCollide = false
                else
                    treeSkip[p] = shapeKey
                end
            end
        end
        pruneAcc = pruneAcc + step
        if pruneAcc >= 1 then
            pruneAcc = 0
            for p, o in pairs(treeSaved) do
                if not p.Parent then
                    treeSaved[p] = nil
                elseif (p.Position - root.Position).Magnitude > Q.Range * 1.5 then
                    p.CanCollide = o[1] p.CanQuery = o[2]
                    treeSaved[p] = nil
                end
            end
        end
    end

    -- the game's own "Ghost" attribute on my car (button: GHOST ATTR)
    if Q.GhostAttr then
        if Q.gaOrig == nil then Q.gaOrig = car:GetAttribute("Ghost") or false end
        if car:GetAttribute("Ghost") ~= true then pcall(function() car:SetAttribute("Ghost", true) end) end
    elseif Q.gaOrig ~= nil then
        pcall(function() car:SetAttribute("Ghost", Q.gaOrig) end) Q.gaOrig = nil
    end

    local fv = Q.FadeMe and 0.6 or 0
    if fv ~= fadeApplied then setMeFade(fv) end

    if Q.statusLbl and Q.panel.Visible then
        local nT, nG = 0, 0
        for _ in pairs(treeSaved) do nT = nT + 1 end
        for _ in pairs(ghost) do nG = nG + 1 end
        Q.statusLbl.Text = string.format("trees non-solid: %d | my mass: %d\ncars: %d name + %d seat + %d physics | non-solid now: %d\n%s",
            nT, root.AssemblyMass, nName, nSeat, nMass, nG, Q.groupInfo)
    end
end)

-- ===== ENGINE DAMAGE RESET =====
local DMG = {"damage", "dmg", "wear", "hurt", "wreck", "broken", "stress", "accum", "overheat", "crash", "dent"}
local function nameHas(n, list)
    n = n:lower()
    for _, k in ipairs(list) do if n:find(k, 1, true) then return true end end
    return false
end
local function resetTable(t, depth)
    local n = 0
    for k, v in pairs(t) do
        if type(k) == "string" then
            local tv = type(v)
            if k == "Sys" and tv == "table" then
                v.Level = 0 v.Power = 1 v.MisfireLeft = 0
                if v.StallLeft ~= nil then v.StallLeft = 0 end
                n = n + 1
            elseif tv == "number" and nameHas(k, DMG) then t[k] = 0 n = n + 1
            elseif tv == "boolean" and nameHas(k, DMG) then t[k] = false n = n + 1
            elseif tv == "string" and k == "EngineState" and v == "Wrecked" then t[k] = "Off" n = n + 1
            elseif tv == "table" and depth < 2 and k ~= "Sys" then
                local ok, c = pcall(resetTable, v, depth + 1)
                if ok then n = n + c end
            end
        end
    end
    return n
end
local function stateTables()
    local out, seen = {}, {}
    local function add(t) if type(t) == "table" and not seen[t] then seen[t] = true out[#out + 1] = t end end
    add(S.fs)
    local ok, gc = pcall(getgc, true)
    if ok and gc then
        for _, t in ipairs(gc) do
            pcall(function()
                if type(t) == "table" and rawget(t, "Sys") ~= nil
                    and (rawget(t, "EngineState") ~= nil or rawget(t, "Fuel") ~= nil or rawget(t, "HitWrecked") ~= nil) then
                    add(t)
                end
            end)
        end
    end
    return out
end
local function resetEngine()
    local tabs = stateTables()
    local changed = 0
    for _, t in ipairs(tabs) do
        local ok, c = pcall(resetTable, t, 0)
        if ok then changed = changed + c end
    end
    -- attributes on the car (in case the HUD reads them)
    for k, v in pairs(car:GetAttributes()) do
        if nameHas(k, DMG) then
            if type(v) == "number" then car:SetAttribute(k, 0) changed = changed + 1
            elseif type(v) == "boolean" then car:SetAttribute(k, false) changed = changed + 1 end
        elseif k == "EngineState" and v == "Wrecked" then
            car:SetAttribute(k, "Off") changed = changed + 1
        end
    end
    return changed, #tabs
end
local function dumpTable(out, t, indent, depth)
    local n = 0
    for k, v in pairs(t) do
        n = n + 1
        if n > 40 then out[#out + 1] = indent .. "..." break end
        local tv = type(v)
        if tv == "table" then
            out[#out + 1] = indent .. tostring(k) .. " = {table}"
            if depth < 2 then dumpTable(out, v, indent .. "  ", depth + 1) end
        elseif tv == "number" or tv == "boolean" or tv == "string" then
            out[#out + 1] = indent .. tostring(k) .. " = " .. tostring(v)
        else
            out[#out + 1] = indent .. tostring(k) .. " : " .. tv
        end
    end
end

-- ===== share functions with Part 3B (the UI) =====
Q.fn = {
    restoreTrees = restoreTrees,
    inMine = inMine,
    findTargets = findTargets,
    keyPos = keyPos,
    resetEngine = resetEngine,
    stateTables = stateTables,
    dumpTable = dumpTable,
}
note("3A loaded OK - now run Part 3B")

end
do
-- ===== PART 3B v2: PHASE + ENGINE UI (run AFTER part 3A) =====
local G = getgenv()
local X = G.T4X
local Q = G.T4P
local function note(t)
    warn(t)
    pcall(function() game:GetService("StarterGui"):SetCore("SendNotification", {Title = "Part 3", Text = t, Duration = 8}) end)
end
if not X or not X.car then note("3B: Part 1/2 not loaded (T4X missing) - run them first") return end
if not Q or not Q.fn then note("3B: Part 3A did not finish - run 3A first and check for errors") return end
note("3B: loading UI...")

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RepStore = game:GetService("ReplicatedStorage")
local lp = Players.LocalPlayer
local car, root = X.car, X.root

local restoreTrees = Q.fn.restoreTrees
local inMine = Q.fn.inMine
local findTargets = Q.fn.findTargets
local keyPos = Q.fn.keyPos
local resetEngine = Q.fn.resetEngine
local stateTables = Q.fn.stateTables
local dumpTable = Q.fn.dumpTable

-- ===== UI =====
local ok0, parent = pcall(function() return gethui() end)
if not ok0 or not parent then parent = lp:WaitForChild("PlayerGui") end
for _, g in ipairs(parent:GetChildren()) do if g.Name == "PhaseGui" then g:Destroy() end end
local gui = Instance.new("ScreenGui")
gui.Name = "PhaseGui" gui.ResetOnSpawn = false gui.Parent = parent

local BLUE, GREY = Color3.fromRGB(0, 120, 255), Color3.fromRGB(50, 54, 70)
local ON, OFF = Color3.fromRGB(30, 140, 60), Color3.fromRGB(160, 50, 50)
local function corner(o, r) local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, r) c.Parent = o end
local function btn(par, x, y, w, text, col)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, w, 0, 30) b.Position = UDim2.new(0, x, 0, y)
    b.BackgroundColor3 = col or BLUE b.TextColor3 = Color3.new(1, 1, 1)
    b.TextSize = 11 b.Text = text b.Parent = par corner(b, 6)
    return b
end
local function lbl(par, x, y, w, h, text)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0, w, 0, h) l.Position = UDim2.new(0, x, 0, y)
    l.BackgroundTransparency = 1 l.TextColor3 = Color3.fromRGB(190, 255, 190)
    l.TextSize = 10 l.TextWrapped = true l.Text = text
    l.TextXAlignment = Enum.TextXAlignment.Left l.TextYAlignment = Enum.TextYAlignment.Top
    l.Parent = par
    return l
end
local function tog(par, x, y, w, key, name, cb)
    local b = btn(par, x, y, w, "")
    local function p() b.Text = name .. (Q[key] and ": ON" or ": OFF") b.BackgroundColor3 = Q[key] and ON or OFF end
    p()
    b.MouseButton1Click:Connect(function() Q[key] = not Q[key] p() if cb then cb(Q[key]) end end)
end
local function makeDraggable(handle, target, onTap)
    local dragging, startIn, startPos, moved = false, nil, nil, 0
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging, moved = true, 0
            startIn, startPos = input.Position, target.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if onTap and moved < 8 then onTap() end
                end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local d = input.Position - startIn
            moved = math.max(moved, d.Magnitude)
            target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

local icon = Instance.new("Frame")
icon.Size = UDim2.new(0, 40, 0, 40) icon.Position = UDim2.new(0, 12, 0.5, 30)
icon.BackgroundColor3 = Color3.fromRGB(130, 60, 200) icon.BackgroundTransparency = 0.3 icon.Active = true icon.Parent = gui
corner(icon, 20)
local iconTxt = Instance.new("TextLabel")
iconTxt.Size = UDim2.new(1, 0, 1, 0) iconTxt.BackgroundTransparency = 1 iconTxt.Text = "PH"
iconTxt.TextColor3 = Color3.new(1, 1, 1) iconTxt.TextSize = 13 iconTxt.Font = Enum.Font.GothamBold iconTxt.Parent = icon

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 280, 0, 346) panel.Position = UDim2.new(0, 64, 0, 90)
panel.BackgroundColor3 = Color3.fromRGB(25, 27, 35) panel.BackgroundTransparency = 0.1
panel.Visible = false panel.Parent = gui
corner(panel, 10)
Q.panel = panel

local title = Instance.new("Frame")
title.Size = UDim2.new(1, 0, 0, 28) title.BackgroundColor3 = Color3.fromRGB(40, 44, 58) title.Active = true title.Parent = panel
corner(title, 10)
local tl = lbl(title, 10, 0, 220, 28, "PHASE + ENGINE  (drag here)")
tl.TextSize = 12 tl.TextColor3 = Color3.new(1, 1, 1) tl.Font = Enum.Font.GothamBold tl.TextYAlignment = Enum.TextYAlignment.Center
makeDraggable(icon, icon, function() panel.Visible = not panel.Visible end)
makeDraggable(title, panel, nil)
local xb = btn(title, 252, 0, 28, "X", Color3.fromRGB(200, 50, 50))
xb.MouseButton1Click:Connect(function() panel.Visible = false end)

tog(panel, 6, 34, 130, "Trees", "TREES", function(v) if not v then restoreTrees() end end)
tog(panel, 144, 34, 130, "Shape", "TRUNK SHAPE")

local CARMODES = {"CARS: OFF", "CARS: TOWED ONLY", "CARS: ALL NEARBY"}
local carb = btn(panel, 6, 68, 268, CARMODES[Q.Cars], GREY)
local function paintCar() carb.Text = CARMODES[Q.Cars] carb.BackgroundColor3 = Q.Cars == 1 and OFF or ON end
paintCar()
carb.MouseButton1Click:Connect(function() Q.Cars = Q.Cars % 3 + 1 paintCar() end)

local rl = btn(panel, 6, 102, 112, "", GREY)
local function rp() rl.Text = "RANGE " .. Q.Range end
rp()
btn(panel, 122, 102, 72, "-").MouseButton1Click:Connect(function() Q.Range = math.max(20, Q.Range - 10) rp() end)
btn(panel, 198, 102, 72, "+").MouseButton1Click:Connect(function() Q.Range = math.min(150, Q.Range + 10) rp() end)

tog(panel, 6, 136, 130, "FadeCars", "FADE CARS")
tog(panel, 144, 136, 130, "FadeMe", "FADE ME")
tog(panel, 6, 170, 130, "Ray", "WHEELS IGNORE")

btn(panel, 144, 170, 130, "PROBE TOW (copy)", Color3.fromRGB(200, 120, 0)).MouseButton1Click:Connect(function()
    local out = {"== MY CAR ATTRIBUTES =="}
    for k, v in pairs(car:GetAttributes()) do out[#out + 1] = k .. " = " .. tostring(v) end
    out[#out + 1] = "== CONSTRAINTS / JOINTS WITH ONE END OUTSIDE MY CAR =="
    for _, d in ipairs(car:GetDescendants()) do
        local a, b
        if d:IsA("Constraint") then
            a = d.Attachment0 and d.Attachment0.Parent
            b = d.Attachment1 and d.Attachment1.Parent
        elseif d:IsA("WeldConstraint") or d:IsA("JointInstance") then
            a, b = d.Part0, d.Part1
        end
        if d:IsA("Constraint") or d:IsA("WeldConstraint") or d:IsA("JointInstance") then
            if not (a and b and inMine(a) and inMine(b)) then
                out[#out + 1] = string.format("%s %s | %s -> %s", d.ClassName, d.Name,
                    a and a:GetFullName() or "nil", b and b:GetFullName() or "nil")
            end
        end
    end
    out[#out + 1] = "== OTHER CARS FOUND =="
    local targets = findTargets()
    for key in pairs(targets) do
        local dist = (keyPos(key) - root.Position).Magnitude
        out[#out + 1] = string.format("%s %s dist %.0f", key.ClassName, key:GetFullName(), dist)
        if key:IsA("Model") then
            for k, v in pairs(key:GetAttributes()) do out[#out + 1] = "   " .. k .. " = " .. tostring(v) end
        end
    end
    out[#out + 1] = "== COLLISION GROUPS =="
    pcall(function()
        local PS = game:GetService("PhysicsService")
        out[#out + 1] = "my root group = " .. tostring(root.CollisionGroup)
        for k in pairs(targets) do
            local pt = k:IsA("Model") and (k.PrimaryPart or k:FindFirstChildWhichIsA("BasePart", true)) or k
            if pt then out[#out + 1] = "other car part group = " .. tostring(pt.CollisionGroup) end
        end
        for _, g in ipairs(PS:GetRegisteredCollisionGroups()) do
            out[#out + 1] = string.format("%s | vs mine collidable=%s | vs Default=%s", g.name,
                tostring(PS:CollisionGroupsAreCollidable(g.name, root.CollisionGroup)),
                tostring(PS:CollisionGroupsAreCollidable(g.name, "Default")))
        end
    end)
    out[#out + 1] = "== PLAYERS SEATED =="
    for _, pl in ipairs(Players:GetPlayers()) do
        local hum = pl.Character and pl.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum.SeatPart then out[#out + 1] = pl.Name .. " in " .. hum.SeatPart:GetFullName() end
    end
    out[#out + 1] = "== TOW-LIKE OBJECTS IN WORKSPACE =="
    local n = 0
    for _, d in ipairs(workspace:GetDescendants()) do
        local nm = d.Name:lower()
        if nm:find("tow") or nm:find("hitch") or nm:find("winch") or nm:find("rope") or nm:find("tether") or nm:find("cable") or nm:find("strap") then
            out[#out + 1] = d.ClassName .. " | " .. d:GetFullName():gsub("^Workspace%.", "")
            n = n + 1
            if n >= 40 then break end
        end
    end
    pcall(function() setclipboard(table.concat(out, "\n")) end)
end)

-- engine row
local resetB = btn(panel, 6, 206, 190, "RESET ENGINE DAMAGE", Color3.fromRGB(200, 50, 50))
local RESET_TXT = "RESET ENGINE DAMAGE"
resetB.MouseButton1Click:Connect(function()
    local ok, n, t = pcall(resetEngine)
    if ok and n > 0 then
        resetB.Text = "RESET OK (" .. n .. " fields)"
    elseif ok then
        resetB.Text = "NOTHING FOUND - tap DUMP"
    else
        resetB.Text = "RESET ERROR"
    end
    task.delay(1.8, function() resetB.Text = RESET_TXT end)
end)
btn(panel, 202, 206, 72, "DUMP (copy)", GREY).MouseButton1Click:Connect(function()
    local out = {"== DamageGauge module =="}
    local okm, mod = pcall(function() return require(RepStore.OffroadCar.DamageGauge) end)
    if okm and type(mod) == "table" then
        for k, v in pairs(mod) do out[#out + 1] = tostring(k) .. " : " .. type(v) end
    else
        out[#out + 1] = "require failed"
    end
    local tabs = stateTables()
    out[#out + 1] = "== STATE TABLES FOUND: " .. #tabs .. " =="
    for i, t in ipairs(tabs) do
        out[#out + 1] = "-- table " .. i
        dumpTable(out, t, "  ", 0)
    end
    out[#out + 1] = "== CAR ATTRIBUTES =="
    for k, v in pairs(car:GetAttributes()) do out[#out + 1] = k .. " = " .. tostring(v) end
    pcall(function() setclipboard(table.concat(out, "\n")) end)
end)

tog(panel, 6, 242, 268, "GhostAttr", "GHOST ATTR (game's own)")
Q.statusLbl = lbl(panel, 6, 278, 268, 66, "")
print("Part 3B v2 loaded - tap the purple PH button")

end
do
-- ===== PART 4: SMOOTH TERRAIN + HANDLING (run AFTER part 1, 2, 3A, 3B) =====
-- STEP LIFT : looks ahead of the car, lifts it over steps / ridges / bumps before the wheels hit them
-- NO STOP   : if a bump suddenly kills your speed while you are on the gas, gives the speed back
-- GRIP      : extra sideways grip (0 = off)
-- YAW LIMIT : stops the car spinning too fast at speed
-- AIR LEVEL : keeps the car level while airborne so it lands on its wheels
-- Client-side only. Does not touch Parts 1-3B.

local G = getgenv()
local X = G.T4X
local function note(t)
    warn(t)
    pcall(function() game:GetService("StarterGui"):SetCore("SendNotification", {Title = "Part 4", Text = t, Duration = 6}) end)
end
if not X or not X.car then note("Part 4: run Part 1 first") return end

local RS = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local lp = game:GetService("Players").LocalPlayer
local car, root = X.car, X.root

G.T4M = G.T4M or {}
local M = G.T4M
for k, v in pairs({Lift = false, NoStop = false, StepMax = 4, Grip = 2, YawLim = true, Air = true}) do
    if M[k] == nil then M[k] = v end
end
if M.conn then pcall(function() M.conn:Disconnect() end) M.conn = nil end

-- ===== helpers =====
local function pos(o)
    if not o then return nil end
    if o:IsA("BasePart") then return o.Position end
    if o:IsA("Model") then return o:GetPivot().Position end
    if o:IsA("Attachment") then return o.WorldPosition end
end
local function wheelForward()
    local ch = car:FindFirstChild("Chassis")
    if not ch then return nil end
    local fl, fr = pos(ch:FindFirstChild("WheelFL")), pos(ch:FindFirstChild("WheelFR"))
    local rl, rr = pos(ch:FindFirstChild("WheelRL")), pos(ch:FindFirstChild("WheelRR"))
    if not (fl and fr and rl and rr) then return nil end
    local d = (fl + fr) / 2 - (rl + rr) / 2
    if d.Magnitude < 0.5 then return nil end
    return d.Unit
end
local function isCarOrChar(p)
    local a = p
    while a and a ~= workspace do
        if a:IsA("Model") and (a.Name:find("^OffroadCar_") or a:FindFirstChildOfClass("Humanoid")) then return true end
        a = a.Parent
    end
    return false
end

-- ray straight down from (x, top, z); skips non-solid parts, cars and players
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude
rp.IgnoreWater = true
local function ground(x, z, top)
    local filter = {car}
    rp.FilterDescendantsInstances = filter
    local origin = Vector3.new(x, top, z)
    for _ = 1, 4 do
        local h = workspace:Raycast(origin, Vector3.new(0, -70, 0), rp)
        if not h then return nil end
        local p = h.Instance
        if p.CanCollide and not isCarOrChar(p) then return h.Position.Y, h.Normal end
        filter[#filter + 1] = p
        rp.FilterDescendantsInstances = filter
    end
    return nil
end

-- ===== main loop =====
local prevV = root.AssemblyLinearVelocity
local stepT, nStop, excessDbg, airDbg = 0, 0, 0, false

M.conn = RS.Heartbeat:Connect(function(dt)
    if not car.Parent then return end
    dt = math.min(dt, 0.1)
    local v = root.AssemblyLinearVelocity
    local h = Vector3.new(v.X, 0, v.Z)
    local spd = h.Magnitude
    local gear = car:GetAttribute("Gear") or 1
    local gas = car:GetAttribute("Gas") or 0
    local braking = car:GetAttribute("Brake") == true
    local mass = root.AssemblyMass
    local rpos = root.Position
    local driving = gas > 0.05 and not braking and gear ~= 0

    -- travel direction (flat)
    local d = wheelForward()
    if d then
        d = Vector3.new(d.X, 0, d.Z)
        if d.Magnitude < 0.1 then d = nil else d = d.Unit if gear < 0 then d = -d end end
    end
    if not d and spd > 2 then d = h.Unit end

    -- ground under the car
    local yHere, nHere = ground(rpos.X, rpos.Z, rpos.Y + 3)
    local airborne = (yHere == nil) or (rpos.Y - yHere > 6)
    airDbg = airborne

    -- STEP LIFT
    stepT = math.max(0, stepT - dt)
    excessDbg = 0
    if M.Lift and d and yHere and nHere and not airborne and (driving or spd > 3) then
        local dist = math.clamp(7 + spd * 0.15, 7, 14)
        local yA = ground(rpos.X + d.X * dist, rpos.Z + d.Z * dist, rpos.Y + 3 + M.StepMax)
        if yA then
            local sl = -(nHere.X * d.X + nHere.Z * d.Z) / math.max(nHere.Y, 0.3)   -- slope we are already on
            local excess = (yA - yHere) - math.clamp(sl, -1, 1) * dist              -- rise beyond that slope = a step
            excessDbg = excess
            if excess > 0.4 and excess <= M.StepMax then
                local sp = math.max(spd, driving and 6 or 0)
                local vyReq = math.min(excess * sp / dist * 1.3, 25)
                if v.Y < vyReq then
                    root:ApplyImpulse(Vector3.yAxis * mass * (vyReq - v.Y) * math.min(1, 12 * dt))
                end
                stepT = 0.5
            end
        end
    end

    -- NO STOP (give back speed lost to a bump while on the gas)
    local ph = Vector3.new(prevV.X, 0, prevV.Z)
    if M.NoStop and driving and ph.Magnitude > 5 then
        local pd = ph.Unit
        local loss = ph:Dot(pd) - h:Dot(pd)
        if loss > 1.2 and (stepT > 0 or v.Y - prevV.Y > 1) then
            root:ApplyImpulse(pd * mass * math.min(loss * 0.8, 12))
            nStop = nStop + 1
        end
    end
    prevV = v

    -- handling (on the ground, moving)
    if d and yHere and not airborne and spd > 6 then
        if M.Grip > 0 then
            local side = Vector3.new(-d.Z, 0, d.X)
            local lat = v:Dot(side)
            root:ApplyImpulse(-side * lat * mass * math.min(1, M.Grip * 1.5 * dt))
        end
        if M.YawLim then
            local up = root.CFrame.UpVector
            local w = root.AssemblyAngularVelocity
            local wy = w:Dot(up)
            local lim = math.clamp(3.5 - spd * 0.05, 1.0, 3.5)
            if math.abs(wy) > lim then
                local over = wy - lim * (wy > 0 and 1 or -1)
                root.AssemblyAngularVelocity = w - up * over * math.min(1, 6 * dt)
            end
        end
    end

    -- AIR LEVEL
    if M.Air and airborne then
        local up = root.CFrame.UpVector
        local w = root.AssemblyAngularVelocity
        local wy = up * w:Dot(up)
        w = w - (w - wy) * math.min(1, 2 * dt)
        local axis = up:Cross(Vector3.yAxis)
        w = w + axis * (3 * dt)
        root.AssemblyAngularVelocity = w
    end
end)

-- ===== UI =====
local ok0, parent = pcall(function() return gethui() end)
if not ok0 or not parent then parent = lp:WaitForChild("PlayerGui") end
for _, g in ipairs(parent:GetChildren()) do if g.Name == "SmoothGui" then g:Destroy() end end
local gui = Instance.new("ScreenGui")
gui.Name = "SmoothGui" gui.ResetOnSpawn = false gui.Parent = parent

local BLUE, GREY = Color3.fromRGB(0, 120, 255), Color3.fromRGB(50, 54, 70)
local ON, OFF = Color3.fromRGB(30, 140, 60), Color3.fromRGB(160, 50, 50)
local function corner(o, r) local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, r) c.Parent = o end
local function btn(par, x, y, w, text, col)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, w, 0, 30) b.Position = UDim2.new(0, x, 0, y)
    b.BackgroundColor3 = col or BLUE b.TextColor3 = Color3.new(1, 1, 1)
    b.TextSize = 11 b.Text = text b.Parent = par corner(b, 6)
    return b
end
local function lbl(par, x, y, w, h, text)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0, w, 0, h) l.Position = UDim2.new(0, x, 0, y)
    l.BackgroundTransparency = 1 l.TextColor3 = Color3.fromRGB(190, 255, 190)
    l.TextSize = 10 l.TextWrapped = true l.Text = text
    l.TextXAlignment = Enum.TextXAlignment.Left l.TextYAlignment = Enum.TextYAlignment.Top
    l.Parent = par
    return l
end
local function tog(par, x, y, w, key, name)
    local b = btn(par, x, y, w, "")
    local function p() b.Text = name .. (M[key] and ": ON" or ": OFF") b.BackgroundColor3 = M[key] and ON or OFF end
    p()
    b.MouseButton1Click:Connect(function() M[key] = not M[key] p() end)
end
local function step(par, y, key, name, lo, hi, st)
    local l = btn(par, 6, y, 112, "", GREY)
    local function p() l.Text = name .. " " .. M[key] end
    p()
    btn(par, 122, y, 72, "-").MouseButton1Click:Connect(function() M[key] = math.max(lo, M[key] - st) p() end)
    btn(par, 198, y, 72, "+").MouseButton1Click:Connect(function() M[key] = math.min(hi, M[key] + st) p() end)
end
local function makeDraggable(handle, target, onTap)
    local dragging, startIn, startPos, moved = false, nil, nil, 0
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging, moved = true, 0
            startIn, startPos = input.Position, target.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if onTap and moved < 8 then onTap() end
                end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local dd = input.Position - startIn
            moved = math.max(moved, dd.Magnitude)
            target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + dd.X, startPos.Y.Scale, startPos.Y.Offset + dd.Y)
        end
    end)
end

local icon = Instance.new("Frame")
icon.Size = UDim2.new(0, 40, 0, 40) icon.Position = UDim2.new(0, 12, 0.5, 80)
icon.BackgroundColor3 = Color3.fromRGB(220, 130, 0) icon.BackgroundTransparency = 0.3 icon.Active = true icon.Parent = gui
corner(icon, 20)
local iconTxt = Instance.new("TextLabel")
iconTxt.Size = UDim2.new(1, 0, 1, 0) iconTxt.BackgroundTransparency = 1 iconTxt.Text = "SM"
iconTxt.TextColor3 = Color3.new(1, 1, 1) iconTxt.TextSize = 13 iconTxt.Font = Enum.Font.GothamBold iconTxt.Parent = icon

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 280, 0, 250) panel.Position = UDim2.new(0, 64, 0, 130)
panel.BackgroundColor3 = Color3.fromRGB(25, 27, 35) panel.BackgroundTransparency = 0.1
panel.Visible = false panel.Parent = gui
corner(panel, 10)
local title = Instance.new("Frame")
title.Size = UDim2.new(1, 0, 0, 28) title.BackgroundColor3 = Color3.fromRGB(40, 44, 58) title.Active = true title.Parent = panel
corner(title, 10)
local tl = lbl(title, 10, 0, 220, 28, "SMOOTH + HANDLING  (drag here)")
tl.TextSize = 12 tl.TextColor3 = Color3.new(1, 1, 1) tl.Font = Enum.Font.GothamBold tl.TextYAlignment = Enum.TextYAlignment.Center
makeDraggable(icon, icon, function() panel.Visible = not panel.Visible end)
makeDraggable(title, panel, nil)
btn(title, 252, 0, 28, "X", Color3.fromRGB(200, 50, 50)).MouseButton1Click:Connect(function() panel.Visible = false end)

tog(panel, 6, 34, 130, "Lift", "STEP LIFT")
tog(panel, 144, 34, 130, "NoStop", "NO STOP")
step(panel, 68, "StepMax", "STEP MAX", 2, 10, 1)
step(panel, 102, "Grip", "GRIP", 0, 5, 1)
tog(panel, 6, 136, 130, "YawLim", "YAW LIMIT")
tog(panel, 144, 136, 130, "Air", "AIR LEVEL")
local status = lbl(panel, 6, 172, 268, 76, "")

task.spawn(function()
    while gui.Parent do
        if panel.Visible then
            status.Text = string.format("step ahead: %.1f | airborne: %s | no-stop saves: %d\nSTEP MAX = tallest step it will lift over.\nGRIP = extra sideways grip. Lower it if the car feels stuck straight, raise it if it slides.", excessDbg, tostring(airDbg), nStop)
        end
        task.wait(0.25)
    end
end)
note("Part 4 loaded - tap the orange SM button")

end
do
-- ===== PART 6: SMOOTH ROAD (run AFTER part 1, 2, 3A, 3B. Replaces Part 5 - do not run Part 5) =====
-- Your ground is made of thousands of thin triangle wedges, so "bumps" are just steep triangles.
-- Ghosting them would leave holes, so instead this:
--   1) measures the real ground height on a grid around the car
--   2) builds an invisible SMOOTHED road (client-side only) from that
--   3) makes the small ground triangles under it non-solid
-- MUD GHOST (on by default): mud / water ground is ghosted the same way, and mud patches outside the ground mesh\n-- are made non-solid, non-queryable and non-touchable, so the game's deep-mud logic can't find them.
-- Safety: a triangle is only ghosted when the smooth road fully covers it; if the car ever has
-- nothing solid under it, everything is restored instantly.

local G = getgenv()
local X = G.T4X
local function note(t)
    warn(t)
    pcall(function() game:GetService("StarterGui"):SetCore("SendNotification", {Title = "Part 6", Text = t, Duration = 6}) end)
end
if not X or not X.car then note("Part 6: run Part 1 first") return end

local RS = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local lp = game:GetService("Players").LocalPlayer
local car, root = X.car, X.root

-- find the ground folder
local groundF = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Ground")
if not groundF then
    for _, d in ipairs(workspace:GetDescendants()) do
        if d.Name == "Ground" and (d:IsA("Folder") or d:IsA("Model")) then groundF = d break end
    end
end
if not groundF then note("Part 6: could not find the Ground folder") return end
local meshF = groundF:FindFirstChild("Mesh") or groundF

G.T4R = G.T4R or {}
local P = G.T4R
for k, v in pairs({On = true, MudToo = true, Smooth = 2, Fill = 3, ver = 0}) do
    if P[k] == nil then P[k] = v end
end
for _, k in ipairs({"conn", "stepConn"}) do
    if P[k] then pcall(function() P[k]:Disconnect() end) P[k] = nil end
end
if P.cleanup then pcall(P.cleanup) P.cleanup = nil end

-- ===== constants =====
local S = 6            -- grid spacing (studs)
local COVER = 60       -- smooth road is built this far around the car
local SAMPLE_R = 84    -- ground heights are measured this far around the car
local KEEP = 76        -- road cells further than this are removed
local GHOST_R = 54     -- ghost triangles that lie fully inside this distance
local UNGHOST_R = 70   -- give triangles back when they get this far
local MAXR = 24        -- only triangles up to this radius are ghosted (big flat ones stay solid)
local THICK = 2

-- ===== state =====
local raw = {}      -- raw[ix][iz] = {y, mud, mat, col, cg} or false
local sm = {}       -- smoothed height cache
local cells = {}    -- cells[ix][iz] = {parts...} or false (skip)
local free = {}     -- spare parts
local gh = {}       -- ghosted part -> {cc, cq, ct, x0, x1, z0, z1, ovl}
local cdec = setmetatable({}, {__mode = "k"})   -- part -> "wedge" / "overlay" / false (cached verdict)
local cellHold = {} -- cellHold[ix][iz] = how many ghosted triangles still need this road cell
local lastMud = P.MudToo
local sampleQ, sampleI, cellQ, cellI, dirtyQ = {}, 1, {}, 1, {}
local decVer = P.ver
local cool, nCells, nGhost, nSkipMud, nSkipBig, safeMsg = 0, 0, 0, 0, 0, "ok"

local folder = Instance.new("Folder")
folder.Name = "SP"
folder.Parent = groundF   -- inside Ground so anything that looks for "Ground" treats it as ground

-- ===== helpers =====
local function isCarOrChar(p)
    local a = p
    while a and a ~= workspace do
        if a:IsA("Model") and (a.Name:find("^OffroadCar_") or a:FindFirstChildOfClass("Humanoid")) then return true end
        a = a.Parent
    end
    return false
end
local MUD_NAMES = {"mud", "bog", "swamp", "puddle", "quicksand"}
local function nameHasMud(n)
    n = n:lower()
    for _, k in ipairs(MUD_NAMES) do if n:find(k, 1, true) then return true end end
    return false
end
local function isMudStrict(p)
    if p.Material == Enum.Material.Mud or p.Material == Enum.Material.Water then return true end
    if p.CollisionGroup == "SoftGround" then return true end
    if p:FindFirstAncestor("MudRuts") then return true end
    if nameHasMud(p.Name) then return true end
    local a, d = p.Parent, 0
    while a and a ~= workspace and d < 4 do
        if nameHasMud(a.Name) then return true end
        a = a.Parent
        d = d + 1
    end
    return false
end
local function isMud(p)
    if isMudStrict(p) then return true end
    if X.tags and X.tags[p] then return true end
    local ok, r = pcall(X.colorMud, p)
    return ok and r == true
end

local function triangle(a, b, c, w1, w2)
    local ab, ac, bc = b - a, c - a, c - b
    local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
    if abd > acd and abd > bcd then
        c, a = a, c
    elseif acd > bcd and acd > abd then
        a, b = b, a
    end
    ab, ac, bc = b - a, c - a, c - b
    local right = ac:Cross(ab).Unit
    local up = bc:Cross(right).Unit
    local back = bc.Unit
    local height = math.max(0.05, math.abs(ab:Dot(up)))
    -- push the plate down by half its thickness so the TOP face sits on the triangle plane
    local off = right * ((right.Y >= 0) and -THICK / 2 or THICK / 2)
    w1.Size = Vector3.new(THICK, height, math.max(0.05, math.abs(ab:Dot(back))))
    w1.CFrame = CFrame.fromMatrix((a + b) / 2 + off, right, up, back)
    w2.Size = Vector3.new(THICK, height, math.max(0.05, math.abs(ac:Dot(back))))
    w2.CFrame = CFrame.fromMatrix((a + c) / 2 + off, -right, up, -back)
end

local function newPart()
    local p = table.remove(free)
    if not p then
        p = Instance.new("WedgePart")
        p.Anchored = true p.CanCollide = true p.CanQuery = true
        p.Transparency = 1 p.CastShadow = false
        p.TopSurface = Enum.SurfaceType.Smooth p.BottomSurface = Enum.SurfaceType.Smooth
    end
    return p
end

local function smoothY(ix, iz)
    local c = sm[ix] and sm[ix][iz]
    if c then return c end
    local n = P.Smooth
    local sum, wsum = 0, 0
    for dx = -n, n do
        local col = raw[ix + dx]
        if col then
            for dz = -n, n do
                local nd = col[iz + dz]
                if nd and (P.MudToo or not nd.mud) then
                    local w = 1 / (1 + dx * dx + dz * dz)
                    sum = sum + nd.y * w
                    wsum = wsum + w
                end
            end
        end
    end
    local r = raw[ix][iz]
    local v = wsum > 0 and sum / wsum or r.y
    v = math.min(v, r.y + P.Fill / 10)     -- road never floats more than FILL above the real ground
    sm[ix] = sm[ix] or {}
    sm[ix][iz] = v
    return v
end

local function shapeCell(ix, iz, cell)
    local n00, n10, n01, n11 = raw[ix][iz], raw[ix + 1][iz], raw[ix][iz + 1], raw[ix + 1][iz + 1]
    local p00 = Vector3.new(ix * S, smoothY(ix, iz), iz * S)
    local p10 = Vector3.new((ix + 1) * S, smoothY(ix + 1, iz), iz * S)
    local p01 = Vector3.new(ix * S, smoothY(ix, iz + 1), (iz + 1) * S)
    local p11 = Vector3.new((ix + 1) * S, smoothY(ix + 1, iz + 1), (iz + 1) * S)
    if math.abs(p00.Y - p11.Y) <= math.abs(p10.Y - p01.Y) then
        triangle(p00, p10, p11, cell[1], cell[2])
        triangle(p00, p11, p01, cell[3], cell[4])
    else
        triangle(p00, p10, p01, cell[1], cell[2])
        triangle(p10, p11, p01, cell[3], cell[4])
    end
    local mudC = n00.mud or n10.mud or n01.mud or n11.mud
    for _, w in ipairs(cell) do
        if mudC then
            -- over mud the road must NOT look like mud to the game or to Part 2
            w.Material = Enum.Material.SmoothPlastic
            w.Color = Color3.fromRGB(180, 150, 110)
            pcall(function() w.CollisionGroup = "Default" end)
        else
            w.Material = n00.mat w.Color = n00.col
            pcall(function() w.CollisionGroup = n00.cg end)
        end
    end
end

local function buildCell(ix, iz)
    local n = {raw[ix][iz], raw[ix + 1][iz], raw[ix][iz + 1], raw[ix + 1][iz + 1]}
    for i = 1, 4 do
        if not n[i] or (n[i].mud and not P.MudToo) then cells[ix] = cells[ix] or {} cells[ix][iz] = false return end
    end
    local cell = {newPart(), newPart(), newPart(), newPart()}
    shapeCell(ix, iz, cell)
    for _, w in ipairs(cell) do w.Parent = folder end
    cells[ix] = cells[ix] or {}
    cells[ix][iz] = cell
    nCells = nCells + 1
end

local function dropCell(ix, iz)
    local c = cells[ix] and cells[ix][iz]
    if c then
        for _, w in ipairs(c) do w.Parent = nil free[#free + 1] = w end
        nCells = nCells - 1
    end
    if cells[ix] then cells[ix][iz] = nil end
end

local function holdRange(x0, x1, z0, z1, d)
    for ix = x0, x1 do
        local col = cellHold[ix]
        if not col then col = {} cellHold[ix] = col end
        for iz = z0, z1 do col[iz] = (col[iz] or 0) + d end
    end
end
local function unghost(p, o)
    if p.Parent then p.CanCollide = o.cc p.CanQuery = o.cq p.CanTouch = o.ct end
    if o.x0 then holdRange(o.x0, o.x1, o.z0, o.z1, -1) end
    gh[p] = nil
end
local function restoreAll()
    for p, o in pairs(gh) do
        if p.Parent then p.CanCollide = o.cc p.CanQuery = o.cq p.CanTouch = o.ct end
        gh[p] = nil
    end
    cellHold = {}
end
local function destroyAll()
    restoreAll()
    for ix, col in pairs(cells) do
        for iz in pairs(col) do dropCell(ix, iz) end
    end
    cells = {}
    nCells = 0
end
P.cleanup = function() restoreAll() destroyAll() folder:Destroy() end

-- ===== keep ghosted triangles non-solid every physics step =====
local okS, sig = pcall(function() return RS.PreSimulation end)
if not okS or not sig then sig = RS.Stepped end
P.stepConn = sig:Connect(function()
    for p in pairs(gh) do
        if p.Parent then
            if p.CanCollide then p.CanCollide = false end
            if p.CanQuery then p.CanQuery = false end
            if p.CanTouch then p.CanTouch = false end
        end
    end
end)

-- ===== sampling rays / ghost query params =====
local rpI = RaycastParams.new()
rpI.FilterType = Enum.RaycastFilterType.Include
rpI.FilterDescendantsInstances = {meshF}
rpI.IgnoreWater = true
local rpAny = RaycastParams.new()
rpAny.FilterType = Enum.RaycastFilterType.Exclude
rpAny.IgnoreWater = true
local op = OverlapParams.new()
op.FilterType = Enum.RaycastFilterType.Exclude

local function sampleNode(ix, iz, topY)
    raw[ix] = raw[ix] or {}
    local h = workspace:Raycast(Vector3.new(ix * S, topY, iz * S), Vector3.new(0, -600, 0), rpI)
    if h then
        local p = h.Instance
        raw[ix][iz] = {y = h.Position.Y, mud = isMud(p), mat = p.Material, col = p.Color, cg = p.CollisionGroup}
    else
        raw[ix][iz] = false
    end
end

local function solidUnder(pos)
    local filter = {car}
    rpAny.FilterDescendantsInstances = filter
    for _ = 1, 3 do
        local h = workspace:Raycast(pos + Vector3.new(0, 3, 0), Vector3.new(0, -70, 0), rpAny)
        if not h then return false end
        local p = h.Instance
        if p.CanCollide and not isCarOrChar(p) then return true end
        filter[#filter + 1] = p
        rpAny.FilterDescendantsInstances = filter
    end
    return false
end

local function supportBelow(skip, x, y, z)
    local filter = {car, skip}
    rpAny.FilterDescendantsInstances = filter
    for _ = 1, 3 do
        local h = workspace:Raycast(Vector3.new(x, y, z), Vector3.new(0, -60, 0), rpAny)
        if not h then return false end
        local p = h.Instance
        if p.CanCollide and not isCarOrChar(p) then return true end
        filter[#filter + 1] = p
        rpAny.FilterDescendantsInstances = filter
    end
    return false
end
local function halfXZ(p)
    local cf, s = p.CFrame, p.Size
    local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
    return (math.abs(r.X) * s.X + math.abs(u.X) * s.Y + math.abs(l.X) * s.Z) / 2,
           (math.abs(r.Z) * s.X + math.abs(u.Z) * s.Y + math.abs(l.Z) * s.Z) / 2
end
local function classify(p)
    local c = cdec[p]
    if c ~= nil then return c end
    c = false
    if p.Anchored and not p:IsA("Terrain") and not isCarOrChar(p) then
        if p:IsDescendantOf(meshF) then
            if isMud(p) then
                if P.MudToo then c = "wedge" end          -- mud triangles: any size
            elseif p.Size.Magnitude / 2 <= MAXR then
                c = "wedge"                                 -- ordinary ground: only the small (bumpy) ones
            end
        elseif P.MudToo and isMudStrict(p) then
            c = "overlay"                                   -- mud patches / volumes that are not part of the ground mesh
        end
    end
    cdec[p] = c
    return c
end

-- ===== main loop =====
local scanAcc, pruneAcc = 0.12, 0

P.conn = RS.Heartbeat:Connect(function(dt)
    if not car.Parent then return end
    local rpos = root.Position
    local cix, ciz = math.floor(rpos.X / S + 0.5), math.floor(rpos.Z / S + 0.5)

    -- setting changed -> reshape existing cells in place (never remove them while triangles are ghosted)
    if P.ver ~= decVer then
        decVer = P.ver
        sm = {}
        cdec = setmetatable({}, {__mode = "k"})
        if lastMud ~= P.MudToo then
            lastMud = P.MudToo
            destroyAll()      -- mud setting changed: give everything back and rebuild the road
        end
        dirtyQ = {}
        for ix, col in pairs(cells) do
            for iz, c in pairs(col) do if c then dirtyQ[#dirtyQ + 1] = {ix, iz} end end
        end
    end
    if not P.On then
        if next(gh) or nCells > 0 then destroyAll() end
        safeMsg = "off"
        return
    end

    -- budgeted work every frame
    local topY = rpos.Y + 150
    local n = 0
    while sampleI <= #sampleQ and n < 30 do
        local s = sampleQ[sampleI]
        sampleI = sampleI + 1
        if not (raw[s[1]] and raw[s[1]][s[2]] ~= nil) then sampleNode(s[1], s[2], topY) end
        n = n + 1
    end
    n = 0
    while cellI <= #cellQ and n < 6 do
        local c = cellQ[cellI]
        cellI = cellI + 1
        if not (cells[c[1]] and cells[c[1]][c[2]] ~= nil) then
            if raw[c[1]] and raw[c[1] + 1] and raw[c[1]][c[2]] ~= nil and raw[c[1]][c[2] + 1] ~= nil
                and raw[c[1] + 1][c[2]] ~= nil and raw[c[1] + 1][c[2] + 1] ~= nil then
                buildCell(c[1], c[2])
            end
        end
        n = n + 1
    end
    n = 0
    while #dirtyQ > 0 and n < 8 do
        local d = table.remove(dirtyQ)
        local c = cells[d[1]] and cells[d[1]][d[2]]
        if c then shapeCell(d[1], d[2], c) end
        n = n + 1
    end

    scanAcc = scanAcc + dt
    if scanAcc < 0.25 then return end
    local step = scanAcc
    scanAcc = 0
    cool = math.max(0, cool - step)

    -- queue missing sample nodes (nearest first)
    sampleQ, sampleI = {}, 1
    local nr = math.ceil(SAMPLE_R / S)
    for ix = cix - nr, cix + nr do
        for iz = ciz - nr, ciz + nr do
            local d2 = (ix - cix) ^ 2 + (iz - ciz) ^ 2
            if d2 <= nr * nr and not (raw[ix] and raw[ix][iz] ~= nil) then
                sampleQ[#sampleQ + 1] = {ix, iz, d2}
            end
        end
    end
    table.sort(sampleQ, function(a, b) return a[3] < b[3] end)
    -- queue missing cells (nearest first)
    cellQ, cellI = {}, 1
    local cr = math.ceil(COVER / S)
    for ix = cix - cr, cix + cr do
        for iz = ciz - cr, ciz + cr do
            local d2 = (ix - cix) ^ 2 + (iz - ciz) ^ 2
            if d2 <= cr * cr and not (cells[ix] and cells[ix][iz] ~= nil) then
                cellQ[#cellQ + 1] = {ix, iz, d2}
            end
        end
    end
    table.sort(cellQ, function(a, b) return a[3] < b[3] end)

    -- remove far cells
    for ix, col in pairs(cells) do
        for iz in pairs(col) do
            local dx, dz = ix * S - rpos.X, iz * S - rpos.Z
            if dx * dx + dz * dz > KEEP * KEEP and not (cellHold[ix] and (cellHold[ix][iz] or 0) > 0) then
                local was = col[iz]
                if was then dropCell(ix, iz) else col[iz] = nil end
            end
        end
    end
    -- forget far height samples (rarely)
    pruneAcc = pruneAcc + step
    if pruneAcc > 4 then
        pruneAcc = 0
        for ix, col in pairs(raw) do
            if math.abs(ix - cix) > 30 then raw[ix] = nil sm[ix] = nil
            else for iz in pairs(col) do if math.abs(iz - ciz) > 30 then col[iz] = nil end end end
        end
    end

    -- safety net: nothing solid under the car -> put everything back
    if not solidUnder(rpos) then
        restoreAll()
        cool = 2.5
        safeMsg = "RESTORED (nothing under car)"
        return
    end
    safeMsg = cool > 0 and "cooldown" or "ok"

    -- give back ghosted parts once I am well away from them
    nGhost = 0
    for p, o in pairs(gh) do
        if not p.Parent then
            if o.x0 then holdRange(o.x0, o.x1, o.z0, o.z1, -1) end
            gh[p] = nil
        else
            local c = p.Position
            local hx, hz = halfXZ(p)
            local ddx = math.max(0, math.abs(c.X - rpos.X) - hx)
            local ddz = math.max(0, math.abs(c.Z - rpos.Z) - hz)
            if math.sqrt(ddx * ddx + ddz * ddz) > (o.ovl and 80 or 36) then
                unghost(p, o)
            else
                nGhost = nGhost + 1
            end
        end
    end

    -- ghost: ground triangles that the smooth road fully covers, and mud patches that have ground under them
    if cool <= 0 then
        op.FilterDescendantsInstances = {car, folder}
        for _, p in ipairs(workspace:GetPartBoundsInRadius(rpos, 66, op)) do
            if not gh[p] then
                local kind = classify(p)
                if kind then
                    local c = p.Position
                    local hx, hz = halfXZ(p)
                    local ddx = math.max(0, math.abs(c.X - rpos.X) - hx)
                    local ddz = math.max(0, math.abs(c.Z - rpos.Z) - hz)
                    local near = math.sqrt(ddx * ddx + ddz * ddz)
                    if kind == "wedge" and p.CanCollide and near <= 30 then
                        local x0, x1 = math.floor((c.X - hx) / S), math.floor((c.X + hx) / S)
                        local z0, z1 = math.floor((c.Z - hz) / S), math.floor((c.Z + hz) / S)
                        local ok = (x1 - x0 + 1) * (z1 - z0 + 1) <= 600
                        if ok then
                            for ix = x0, x1 do
                                local col = cells[ix]
                                if not col then ok = false break end
                                for iz = z0, z1 do
                                    if not col[iz] then ok = false break end
                                end
                                if not ok then break end
                            end
                        end
                        if ok then
                            gh[p] = {cc = p.CanCollide, cq = p.CanQuery, ct = p.CanTouch, x0 = x0, x1 = x1, z0 = z0, z1 = z1}
                            holdRange(x0, x1, z0, z1, 1)
                            p.CanCollide = false
                            p.CanQuery = false
                            p.CanTouch = false
                        end
                    elseif kind == "overlay" and near <= 60 then
                        local ok = true
                        if p.CanCollide then ok = supportBelow(p, c.X, c.Y + p.Size.Y / 2 + 0.5, c.Z) end
                        if ok then
                            gh[p] = {cc = p.CanCollide, cq = p.CanQuery, ct = p.CanTouch, ovl = true}
                            p.CanCollide = false
                            p.CanQuery = false
                            p.CanTouch = false
                        end
                    end
                end
            end
        end
    end
end)

-- ===== UI =====
local ok0, parent = pcall(function() return gethui() end)
if not ok0 or not parent then parent = lp:WaitForChild("PlayerGui") end
for _, g in ipairs(parent:GetChildren()) do if g.Name == "RoadGui" then g:Destroy() end end
local gui = Instance.new("ScreenGui")
gui.Name = "RoadGui" gui.ResetOnSpawn = false gui.IgnoreGuiInset = true gui.Parent = parent

local BLUE, GREY = Color3.fromRGB(0, 120, 255), Color3.fromRGB(50, 54, 70)
local ON, OFF = Color3.fromRGB(30, 140, 60), Color3.fromRGB(160, 50, 50)
local function corner(o, r) local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, r) c.Parent = o end
local function btn(par, x, y, w, text, col)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, w, 0, 30) b.Position = UDim2.new(0, x, 0, y)
    b.BackgroundColor3 = col or BLUE b.TextColor3 = Color3.new(1, 1, 1)
    b.TextSize = 11 b.Text = text b.Parent = par corner(b, 6)
    return b
end
local function lbl(par, x, y, w, h, text)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0, w, 0, h) l.Position = UDim2.new(0, x, 0, y)
    l.BackgroundTransparency = 1 l.TextColor3 = Color3.fromRGB(190, 255, 190)
    l.TextSize = 10 l.TextWrapped = true l.Text = text
    l.TextXAlignment = Enum.TextXAlignment.Left l.TextYAlignment = Enum.TextYAlignment.Top
    l.Parent = par
    return l
end
local function tog(par, x, y, w, key, name)
    local b = btn(par, x, y, w, "")
    local function p() b.Text = name .. (P[key] and ": ON" or ": OFF") b.BackgroundColor3 = P[key] and ON or OFF end
    p()
    b.MouseButton1Click:Connect(function() P[key] = not P[key] P.ver = P.ver + 1 p() end)
end
local function step(par, y, key, name, lo, hi, st)
    local l = btn(par, 6, y, 112, "", GREY)
    local function p() l.Text = name .. " " .. P[key] end
    p()
    btn(par, 122, y, 72, "-").MouseButton1Click:Connect(function() P[key] = math.max(lo, P[key] - st) P.ver = P.ver + 1 p() end)
    btn(par, 198, y, 72, "+").MouseButton1Click:Connect(function() P[key] = math.min(hi, P[key] + st) P.ver = P.ver + 1 p() end)
end
local function makeDraggable(handle, target, onTap)
    local dragging, startIn, startPos, moved = false, nil, nil, 0
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging, moved = true, 0
            startIn, startPos = input.Position, target.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if onTap and moved < 8 then onTap() end
                end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local dd = input.Position - startIn
            moved = math.max(moved, dd.Magnitude)
            target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + dd.X, startPos.Y.Scale, startPos.Y.Offset + dd.Y)
        end
    end)
end

local icon = Instance.new("Frame")
icon.Size = UDim2.new(0, 40, 0, 40) icon.Position = UDim2.new(0, 62, 0.5, -20)
icon.BackgroundColor3 = Color3.fromRGB(0, 150, 160) icon.BackgroundTransparency = 0.3 icon.Active = true icon.Parent = gui
corner(icon, 20)
local iconTxt = Instance.new("TextLabel")
iconTxt.Size = UDim2.new(1, 0, 1, 0) iconTxt.BackgroundTransparency = 1 iconTxt.Text = "SR"
iconTxt.TextColor3 = Color3.new(1, 1, 1) iconTxt.TextSize = 13 iconTxt.Font = Enum.Font.GothamBold iconTxt.Parent = icon

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 280, 0, 334) panel.Position = UDim2.new(0, 112, 0, 60)
panel.BackgroundColor3 = Color3.fromRGB(25, 27, 35) panel.BackgroundTransparency = 0.1
panel.Visible = false panel.Parent = gui
corner(panel, 10)
local title = Instance.new("Frame")
title.Size = UDim2.new(1, 0, 0, 28) title.BackgroundColor3 = Color3.fromRGB(40, 44, 58) title.Active = true title.Parent = panel
corner(title, 10)
local tl = lbl(title, 10, 0, 220, 28, "SMOOTH ROAD  (drag here)")
tl.TextSize = 12 tl.TextColor3 = Color3.new(1, 1, 1) tl.Font = Enum.Font.GothamBold tl.TextYAlignment = Enum.TextYAlignment.Center
makeDraggable(icon, icon, function() panel.Visible = not panel.Visible end)
makeDraggable(title, panel, nil)
btn(title, 252, 0, 28, "X", Color3.fromRGB(200, 50, 50)).MouseButton1Click:Connect(function() panel.Visible = false end)

tog(panel, 6, 34, 268, "On", "SMOOTH ROAD")
tog(panel, 6, 68, 268, "MudToo", "MUD GHOST (all mud)")
step(panel, 102, "Smooth", "SMOOTH", 1, 3, 1)
step(panel, 136, "Fill", "FILL", 0, 15, 1)

local function desc(p)
    local c = p.Color
    return string.format("%s | %s | cc=%s cq=%s ct=%s anch=%s grp=%s mat=%s col=%.2f,%.2f,%.2f size=%s",
        p.ClassName, (p:GetFullName():gsub("^Workspace%.", "")), tostring(p.CanCollide), tostring(p.CanQuery),
        tostring(p.CanTouch), tostring(p.Anchored), tostring(p.CollisionGroup), tostring(p.Material),
        c.R, c.G, c.B, tostring(p.Size))
end
local function mudProbe()
    local out = {"== CAR ATTRIBUTES (tire / mud / status) =="}
    for k, v in pairs(car:GetAttributes()) do
        local lk = k:lower()
        if lk:find("tire") or lk:find("mud") or lk:find("soft") or lk:find("sink") or lk:find("stuck") or lk:find("status") or lk:find("slip") then
            out[#out + 1] = k .. " = " .. tostring(v)
        end
    end
    out[#out + 1] = "== RAYS DOWN: under car and under each wheel =="
    local prp = RaycastParams.new()
    prp.FilterType = Enum.RaycastFilterType.Exclude
    local spots = {{"root", root.Position}}
    local ch = car:FindFirstChild("Chassis")
    if ch then
        for _, n in ipairs({"WheelFL", "WheelFR", "WheelRL", "WheelRR"}) do
            local w = ch:FindFirstChild(n)
            local wp = w and (w:IsA("BasePart") and w.Position or (w:IsA("Attachment") and w.WorldPosition))
            if wp then spots[#spots + 1] = {n, wp} end
        end
    end
    for _, sp in ipairs(spots) do
        out[#out + 1] = "-- " .. sp[1]
        local filter = {car}
        prp.FilterDescendantsInstances = filter
        for _ = 1, 4 do
            local h = workspace:Raycast(sp[2] + Vector3.new(0, 3, 0), Vector3.new(0, -40, 0), prp)
            if not h then break end
            out[#out + 1] = string.format("  y=%.1f hitMat=%s %s", h.Position.Y, tostring(h.Material), desc(h.Instance))
            filter[#filter + 1] = h.Instance
            prp.FilterDescendantsInstances = filter
        end
    end
    out[#out + 1] = "== TERRAIN VOXELS around the car (mud/water inside terrain?) =="
    pcall(function()
        local c = root.Position
        local reg = Region3.new(c - Vector3.new(8, 10, 8), c + Vector3.new(8, 6, 8)):ExpandToGrid(4)
        local mats = workspace.Terrain:ReadVoxels(reg, 4)
        local counts = {}
        for x = 1, mats.Size.X do
            for y = 1, mats.Size.Y do
                for z = 1, mats.Size.Z do
                    local m = tostring(mats[x][y][z])
                    counts[m] = (counts[m] or 0) + 1
                end
            end
        end
        for m, n in pairs(counts) do out[#out + 1] = "  " .. m .. " x" .. n end
    end)
    out[#out + 1] = "== PARTS WITHIN 14 STUDS (verdict) =="
    local o2 = OverlapParams.new()
    o2.FilterType = Enum.RaycastFilterType.Exclude
    o2.FilterDescendantsInstances = {car, folder}
    for i, p in ipairs(workspace:GetPartBoundsInRadius(root.Position, 14, o2)) do
        if i > 30 then break end
        out[#out + 1] = string.format("%s  =>  mud=%s kind=%s ghosted=%s", desc(p), tostring(isMud(p)), tostring(classify(p)), tostring(gh[p] ~= nil))
    end
    out[#out + 1] = "== OBJECTS NAMED mud/rut/soft/bog/swamp/puddle/water (first 25) =="
    local n = 0
    for _, d in ipairs(workspace:GetDescendants()) do
        local nm = d.Name:lower()
        if (nm:find("mud") or nm:find("rut") or nm:find("soft") or nm:find("bog") or nm:find("swamp") or nm:find("puddle") or nm:find("water")) and not d:IsDescendantOf(car) then
            n = n + 1
            if n > 25 then out[#out + 1] = "  ..." break end
            out[#out + 1] = "  " .. d.ClassName .. " | " .. (d:GetFullName():gsub("^Workspace%.", ""))
        end
    end
    out[#out + 1] = string.format("== SETTINGS: mudGhost=%s smooth=%d fill=%d | ghosted now=%d | part2 lastMat=%s", tostring(P.MudToo), P.Smooth, P.Fill, nGhost, tostring(X.lastMat))
    pcall(setclipboard, table.concat(out, "\n"))
end
btn(panel, 6, 170, 268, "MUD PROBE (copy)", Color3.fromRGB(200, 120, 0)).MouseButton1Click:Connect(function() pcall(mudProbe) end)

local status = lbl(panel, 6, 206, 268, 122, "")
task.spawn(function()
    while gui.Parent do
        if panel.Visible then
            status.Text = string.format("road cells: %d | non-solid parts: %d\nqueue: %d samples, %d cells | safety: %s\nSMOOTH = how much bumps are flattened (3 = most).\nFILL = how far (x0.1 stud) the road may float above dips.\nMUD GHOST = mud/water ground and mud patches become non-solid and the game can no longer detect them.",
                nCells, nGhost, math.max(0, #sampleQ - sampleI + 1), math.max(0, #cellQ - cellI + 1), safeMsg)
        end
        task.wait(0.25)
    end
end)
note("Part 6 loaded - wait a few seconds, then tap the teal SR button")

end
do
-- ===== PART 7: TOW LOCK / ANTI-SNAP (run AFTER part 1, 2, 3A, 3B - any order with 4 and 6) =====
-- Three layers, because I can't see how the game decides a rope snaps:
--   GUARD  : physics. Finds the rope/winch link between your truck and the other truck (or an anchor).
--            When the rope is nearly tight it stops you pulling away faster than the other truck follows,
--            so the rope never gets yanked or over-stretched.
--   LIMITS : finds the game's winch/rope/tow modules and multiplies their snap / break / tension numbers by 100
--            (and turns "snap/break" booleans off). Restored when you switch it OFF.
--   BLOCK  : experimental. Stops the game from destroying the rope objects (that is what a snap does)
--            unless you unhook yourself: tap the Winch button in the HUD, or tap RELEASE here (4 seconds).
--            Off by default because it hooks every method call in the game (small FPS cost).
-- WINCH PROBE (copy): hook a tow, then tap it, and send me the text - I can then target the exact snap rule.

local G = getgenv()
local X = G.T4X
local function note(t)
    warn(t)
    pcall(function() game:GetService("StarterGui"):SetCore("SendNotification", {Title = "Part 7", Text = t, Duration = 6}) end)
end
if not X or not X.car then note("Part 7: run Part 1 first") return end

local RS = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local RepStore = game:GetService("ReplicatedStorage")
local lp = game:GetService("Players").LocalPlayer
local car, root = X.car, X.root

G.T4W = G.T4W or {}
local W = G.T4W
for k, v in pairs({Guard = true, Limits = true, Block = true, Flag = true, Soft = 2, allowUntil = 0}) do
    if W[k] == nil then W[k] = v end
end
W.btnHooked = W.btnHooked or setmetatable({}, {__mode = "k"})
W.flagOrig = W.flagOrig or setmetatable({}, {__mode = "k"})
if W.conn then pcall(function() W.conn:Disconnect() end) W.conn = nil end
if W.restoreLimits then pcall(W.restoreLimits) W.restoreLimits = nil end
W.car = car

-- ===== tow link finder =====
local links = {}
local function inMine(p) return p:IsDescendantOf(car) end
local function addLink(d, seen)
    if seen[d] then return end
    local ok, a0, a1 = pcall(function() return d.Attachment0, d.Attachment1 end)
    if not ok then return end
    local p0, p1 = a0 and a0.Parent, a1 and a1.Parent
    if not (p0 and p1 and p0:IsA("BasePart") and p1:IsA("BasePart")) then return end
    local m0, m1 = inMine(p0), inMine(p1)
    if m0 == m1 then return end
    seen[d] = true
    local len
    if d:IsA("RopeConstraint") or d:IsA("RodConstraint") or d:IsA("SpringConstraint") then
        local okl, l = pcall(function() return d.Length end)
        if okl then len = l end
    end
    links[#links + 1] = {inst = d, mine = m0 and a0 or a1, other = m0 and a1 or a0, len = len}
end
local function scanFor(container, seen)
    for _, d in ipairs(container:GetDescendants()) do
        if d:IsA("Constraint") or d:IsA("Beam") then addLink(d, seen) end
    end
end
local lastOther = 0
local function scanLinks()
    links = {}
    local seen = {}
    local wf = workspace:FindFirstChild("WinchRopes")
    if wf then scanFor(wf, seen) end
    scanFor(car, seen)
    if os.clock() - lastOther > 1.5 then
        lastOther = os.clock()
        W.otherCars = {}
        for _, m in ipairs(workspace:GetChildren()) do
            if m:IsA("Model") and m ~= car and m.Name:find("^OffroadCar_") then
                local ok, pv = pcall(function() return m:GetPivot().Position end)
                if ok and (pv - root.Position).Magnitude < 250 then W.otherCars[#W.otherCars + 1] = m end
            end
        end
    end
    for _, m in ipairs(W.otherCars or {}) do
        if m.Parent then scanFor(m, seen) end
    end
end

-- ===== LIMITS: raise snap numbers in winch-like modules =====
local MOD_KEYS = {"winch", "rope", "tow", "strap", "cable", "tether", "hook", "recovery"}
local NUM_KEYS = {"snap", "break", "tension", "strength", "maxforce", "maxpull", "maxload", "yield", "stretch"}
local EXCL = {"time", "cooldown", "count", "speed", "length", "dist", "delay", "rate"}
local function hasAny(s, list)
    s = s:lower()
    for _, k in ipairs(list) do if s:find(k, 1, true) then return true end end
    return false
end
local origVals, applied = {}, setmetatable({}, {__mode = "k"})
local nRaised = 0
local function raiseTable(t, depth, seen)
    if seen[t] or depth > 3 then return end
    seen[t] = true
    for k, v in pairs(t) do
        if type(k) == "string" then
            local lk, tv = k:lower(), type(v)
            if tv == "number" and v > 0 and v < 1e12 and hasAny(lk, NUM_KEYS) and not hasAny(lk, EXCL) then
                local a = applied[t]
                if not a then a = {} applied[t] = a end
                if a[k] == nil or v < a[k] then
                    if a[k] == nil then origVals[#origVals + 1] = {t, k, v} nRaised = nRaised + 1 end
                    t[k] = v * 100
                    a[k] = v * 100
                end
            elseif tv == "boolean" and v == true and (lk:find("snap", 1, true) or lk:find("break", 1, true)) then
                local a = applied[t]
                if not a then a = {} applied[t] = a end
                if a[k] == nil then origVals[#origVals + 1] = {t, k, v} nRaised = nRaised + 1 end
                t[k] = false
                a[k] = 0
            elseif tv == "table" then
                raiseTable(v, depth + 1, seen)
            end
        end
    end
end
local function modulesLike()
    local out = {}
    local function scan(c)
        for _, d in ipairs(c:GetDescendants()) do
            if d:IsA("ModuleScript") and hasAny(d:GetFullName(), MOD_KEYS) then out[#out + 1] = d end
        end
    end
    pcall(scan, RepStore)
    pcall(function() scan(lp:WaitForChild("PlayerScripts", 2)) end)
    return out
end
local function applyLimits(useGc)
    local seen = {}
    for _, m in ipairs(modulesLike()) do
        local ok, mod = pcall(require, m)
        if ok and type(mod) == "table" then raiseTable(mod, 0, seen) end
    end
    if useGc then
        local ok, gc = pcall(getgc, true)
        if ok and gc then
            for _, t in ipairs(gc) do
                pcall(function()
                    if type(t) == "table" and not seen[t] then
                        local snap, rope = false, false
                        for k in pairs(t) do
                            if type(k) == "string" then
                                local lk = k:lower()
                                if lk:find("snap", 1, true) or lk:find("break", 1, true) then snap = true end
                                if hasAny(lk, {"winch", "rope", "strap", "tow"}) then rope = true end
                            end
                        end
                        if snap and rope then raiseTable(t, 0, seen) end
                    end
                end)
            end
        end
    end
end
W.restoreLimits = function()
    for _, o in ipairs(origVals) do pcall(function() o[1][o[2]] = o[3] end) end
    origVals, nRaised = {}, 0
    applied = setmetatable({}, {__mode = "k"})
end

-- ===== BLOCK: stop the game destroying rope objects unless I unhook =====
W.ropeish = function(inst)
    if typeof(inst) ~= "Instance" then return false end
    local c = W.car
    local wf = workspace:FindFirstChild("WinchRopes")
    if wf and (inst == wf or inst:IsDescendantOf(wf)) then return true end
    if inst:IsA("Constraint") or inst:IsA("Beam") then
        local ok, a0, a1 = pcall(function() return inst.Attachment0, inst.Attachment1 end)
        if ok then
            local p0, p1 = a0 and a0.Parent, a1 and a1.Parent
            if (p0 and c and p0:IsDescendantOf(c)) or (p1 and c and p1:IsDescendantOf(c)) then return true end
        end
    end
    return false
end
local function installHook()
    if W.hooked then return true end
    local ok = pcall(function()
        local old
        old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local m = getnamecallmethod()
            if W.Block and os.clock() > W.allowUntil and not checkcaller() then
                if m == "SetAttribute" then
                    -- the game records a snap by writing WinchSnaps / clearing the Winch* and Link* attributes
                    local a1, a2 = ...
                    if type(a1) == "string" and typeof(self) == "Instance" and self.Name:find("^OffroadCar_")
                        and (a1 == "WinchSnaps" or (a2 == nil and (a1:find("^Winch") or a1:find("^Link")))) then
                        W.blocked = (W.blocked or 0) + 1
                        return
                    end
                    pcall(setnamecallmethod, m)
                elseif m == "Destroy" or m == "Remove" or m == "ClearAllChildren" then
                    local isRope = W.ropeish(self)
                    if isRope then
                        W.blocked = (W.blocked or 0) + 1
                        return
                    end
                    pcall(setnamecallmethod, m)   -- our checks above used other methods; restore the real one
                end
            end
            return old(self, ...)
        end))
    end)
    W.hooked = ok
    return ok
end
if W.Block then installHook() end

-- the winch code reads/writes the attribute "WinchSnaps". Rename that string inside the game's own functions
-- so they read an attribute that never exists (= snapping disabled) without stopping the rest of the winch.
local patched, nPatched = {}, 0
local function patchSnapConsts()
    local n = 0
    local okg, gc = pcall(getgc)
    local getc = debug.getconstants or getconstants
    local setc = debug.setconstant or setconstant
    if not okg or not gc or not getc or not setc then return 0 end
    for _, f in ipairs(gc) do
        if n >= 30 then break end
        if type(f) == "function" then
            local isC = false
            pcall(function() isC = iscclosure(f) end)
            if not isC then
                local okc, consts = pcall(getc, f)
                if okc and type(consts) == "table" then
                    for i, c in pairs(consts) do
                        if c == "WinchSnaps" then
                            if pcall(setc, f, i, "WinchSnapsX") then patched[#patched + 1] = {f, i} n = n + 1 end
                        end
                    end
                end
            end
        end
    end
    return n
end
local function unpatchSnapConsts()
    local setc = debug.setconstant or setconstant
    for _, p in ipairs(patched) do pcall(setc, p[1], p[2], "WinchSnaps") end
    patched, nPatched = {}, 0
end
if W.Block then task.spawn(function() nPatched = nPatched + patchSnapConsts() end) end

-- tapping the HUD Winch button = I am unhooking on purpose
local function hookWinchButton()
    pcall(function()
        local hud = lp.PlayerGui:FindFirstChild("OffroadHud")
        if not hud then return end
        for _, d in ipairs(hud:GetDescendants()) do
            if d:IsA("TextLabel") and d.Text == "Winch" then
                local a = d
                while a and a ~= hud do
                    if a:IsA("GuiButton") then
                        if not W.btnHooked[a] then
                            W.btnHooked[a] = true
                            a.Activated:Connect(function() W.allowUntil = os.clock() + 4 end)
                        end
                        break
                    end
                    a = a.Parent
                end
            end
        end
    end)
end
hookWinchButton()

-- ===== main loop =====
local scanAcc, limAcc, btnAcc, flagAcc = 0.3, 0, 0, 0
local tautDbg, sepDbg, noLenDbg = "-", 0, false
if W.Limits then task.spawn(function() pcall(applyLimits, true) end) end

W.conn = RS.Heartbeat:Connect(function(dt)
    if not car.Parent then return end
    dt = math.min(dt, 0.1)
    scanAcc = scanAcc + dt
    if scanAcc >= 0.4 then scanAcc = 0 pcall(scanLinks) end
    limAcc = limAcc + dt
    if limAcc >= 5 then
        limAcc = 0
        if W.Limits then pcall(applyLimits, false) end
    end
    btnAcc = btnAcc + dt
    if btnAcc >= 3 then btnAcc = 0 hookWinchButton() end
    flagAcc = flagAcc + dt
    if W.Flag and flagAcc >= 0.3 then
        -- "WinchSnaps" = 1 on every truck; remove it on my side so any code that reads it sees "no snapping"
        flagAcc = 0
        pcall(function()
            local list = {car}
            for _, m in ipairs(W.otherCars or {}) do list[#list + 1] = m end
            for _, m in ipairs(list) do
                local v = m:GetAttribute("WinchSnaps")
                if v ~= nil then W.flagOrig[m] = v m:SetAttribute("WinchSnaps", nil) end
            end
        end)
    end

    tautDbg, noLenDbg = "no tow", false
    if not W.Guard then return end
    local mass = root.AssemblyMass
    for _, L in ipairs(links) do
        if L.inst.Parent and L.mine.Parent and L.other.Parent then
            local pm, po = L.mine.WorldPosition, L.other.WorldPosition
            local sep = po - pm
            local dist = sep.Magnitude
            if dist > 0.5 then
                local u = sep / dist
                local vm = L.mine.Parent:GetVelocityAtPosition(pm)
                local vo = L.other.Parent:GetVelocityAtPosition(po)
                local sepSpeed = (vo - vm):Dot(u)          -- > 0 : the rope is being stretched
                sepDbg = sepSpeed
                if L.len then
                    local slack = L.len - dist
                    tautDbg = string.format("slack %.1f  stretch-speed %.1f", slack, sepSpeed)
                    if slack < 2 and sepSpeed > W.Soft then
                        root:ApplyImpulse(u * mass * (sepSpeed - W.Soft) * math.min(1, 12 * dt))
                    end
                    if slack < 0 then   -- already over-stretched: ease back toward the other truck
                        root:ApplyImpulse(u * mass * math.min(-slack * 4, 20) * dt)
                    end
                else
                    noLenDbg = true
                    tautDbg = "tow found, rope length unknown"
                end
            end
        end
    end
end)

-- ===== probe =====
local function probe()
    local out = {"== MY CAR: winch/tow/snap attributes =="}
    for k, v in pairs(car:GetAttributes()) do
        if hasAny(k, {"winch", "tow", "snap", "rope", "hook"}) then out[#out + 1] = k .. " = " .. tostring(v) end
    end
    out[#out + 1] = "== WinchRopes folder =="
    local wf = workspace:FindFirstChild("WinchRopes")
    if wf then
        for k, v in pairs(wf:GetAttributes()) do out[#out + 1] = "  [attr] " .. k .. " = " .. tostring(v) end
        local n = 0
        for _, d in ipairs(wf:GetDescendants()) do
            n = n + 1
            if n > 80 then out[#out + 1] = "  ..." break end
            local line = d.ClassName .. " | " .. d:GetFullName():gsub("^Workspace%.", "")
            if d:IsA("Constraint") or d:IsA("Beam") then
                local ok, a0, a1 = pcall(function() return d.Attachment0, d.Attachment1 end)
                if ok then line = line .. " | A0=" .. (a0 and a0.Parent and a0.Parent:GetFullName() or "nil") .. " A1=" .. (a1 and a1.Parent and a1.Parent:GetFullName() or "nil") end
                pcall(function() line = line .. " | Length=" .. tostring(d.Length) end)
                pcall(function() line = line .. " | Enabled=" .. tostring(d.Enabled) end)
            elseif d:IsA("BasePart") then
                line = line .. " | anch=" .. tostring(d.Anchored) .. " size=" .. tostring(d.Size)
            end
            out[#out + 1] = "  " .. line
            for k, v in pairs(d:GetAttributes()) do out[#out + 1] = "      [attr] " .. k .. " = " .. tostring(v) end
        end
    else
        out[#out + 1] = "  (no WinchRopes folder)"
    end
    out[#out + 1] = "== TOW LINKS I DETECT =="
    pcall(scanLinks)
    for _, L in ipairs(links) do
        out[#out + 1] = string.format("%s %s | mine=%s other=%s | len=%s dist=%.1f", L.inst.ClassName, L.inst:GetFullName(),
            L.mine:GetFullName(), L.other:GetFullName(), tostring(L.len), (L.other.WorldPosition - L.mine.WorldPosition).Magnitude)
    end
    out[#out + 1] = "== OTHER CARS: winch/tow/snap attributes =="
    for _, m in ipairs(W.otherCars or {}) do
        out[#out + 1] = m:GetFullName()
        for k, v in pairs(m:GetAttributes()) do
            if hasAny(k, {"winch", "tow", "snap", "rope", "hook"}) then out[#out + 1] = "   " .. k .. " = " .. tostring(v) end
        end
    end
    out[#out + 1] = "== WINCH-LIKE MODULES =="
    for _, m in ipairs(modulesLike()) do
        out[#out + 1] = m:GetFullName()
        local ok, mod = pcall(require, m)
        if ok and type(mod) == "table" then
            local n = 0
            for k, v in pairs(mod) do
                n = n + 1
                if n > 40 then out[#out + 1] = "   ..." break end
                local tv = type(v)
                if tv == "number" or tv == "boolean" or tv == "string" then out[#out + 1] = "   " .. tostring(k) .. " = " .. tostring(v)
                else out[#out + 1] = "   " .. tostring(k) .. " : " .. tv end
            end
        end
    end
    out[#out + 1] = "== FUNCTIONS MENTIONING WINCH/SNAP (getgc) =="
    local okg, gc = pcall(getgc, true)
    if okg and gc then
        local n = 0
        for _, f in ipairs(gc) do
            if type(f) == "function" then
                local okc, consts = pcall(function() return (debug.getconstants or getconstants)(f) end)
                if okc and type(consts) == "table" then
                    local hits = {}
                    for _, c in ipairs(consts) do
                        if type(c) == "string" and hasAny(c, {"winch", "snap", "tension", "rope"}) then hits[#hits + 1] = c end
                    end
                    if #hits > 0 then
                        n = n + 1
                        if n > 25 then out[#out + 1] = "   ..." break end
                        local src, nm = "?", "?"
                        pcall(function() src = debug.info(f, "s") nm = debug.info(f, "n") end)
                        out[#out + 1] = string.format("  %s : %s -> %s", tostring(src), tostring(nm), table.concat(hits, ", "))
                    end
                end
            end
        end
    end
    out[#out + 1] = "== WINCH / LINK ATTRIBUTES (me + other cars) =="
    local function dumpAttrs(m)
        out[#out + 1] = m:GetFullName()
        for k, v in pairs(m:GetAttributes()) do
            if k:find("^Winch") or k:find("^Link") or k:find("^Tow") then out[#out + 1] = "   " .. k .. " = " .. tostring(v) end
        end
    end
    dumpAttrs(car)
    for _, m in ipairs(W.otherCars or {}) do dumpAttrs(m) end
    out[#out + 1] = "== DEEP: functions using WinchLength / LinkPose / WinchSnaps (constants + upvalues) =="
    do
        local getc = debug.getconstants or getconstants
        local getu = debug.getupvalues or getupvalues
        local okg2, gc2 = pcall(getgc)
        local shown = 0
        if okg2 and gc2 and getc then
            for _, f in ipairs(gc2) do
                if shown >= 8 then break end
                if type(f) == "function" then
                    local okc, consts = pcall(getc, f)
                    if okc and type(consts) == "table" then
                        local hit = false
                        for _, c in pairs(consts) do
                            if c == "WinchLength" or c == "LinkPose" or c == "WinchSnaps" or c == "WinchSnapsX" then hit = true break end
                        end
                        if hit then
                            shown = shown + 1
                            local src, nm = "?", "?"
                            pcall(function() src = debug.info(f, "s") nm = debug.info(f, "n") end)
                            out[#out + 1] = string.format("-- fn %s : %s", tostring(src), tostring(nm))
                            local cl = {}
                            for _, c in pairs(consts) do
                                local tc = type(c)
                                if tc == "number" or tc == "string" then cl[#cl + 1] = tostring(c) end
                                if #cl >= 70 then break end
                            end
                            out[#out + 1] = "   consts: " .. table.concat(cl, " | ")
                            if getu then
                                local oku, ups = pcall(getu, f)
                                if oku and type(ups) == "table" then
                                    for k, v in pairs(ups) do
                                        local tv = type(v)
                                        if tv == "number" or tv == "boolean" or tv == "string" then
                                            out[#out + 1] = "   up[" .. tostring(k) .. "] = " .. tostring(v)
                                        elseif tv == "table" then
                                            local parts, c2 = {}, 0
                                            for kk, vv in pairs(v) do
                                                if type(vv) == "number" or type(vv) == "boolean" then
                                                    parts[#parts + 1] = tostring(kk) .. "=" .. tostring(vv)
                                                    c2 = c2 + 1
                                                    if c2 >= 25 then break end
                                                end
                                            end
                                            if #parts > 0 then out[#out + 1] = "   up[" .. tostring(k) .. "] table: " .. table.concat(parts, ", ") end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    out[#out + 1] = string.format("== SETTINGS: guard=%s limits=%s(raised %d) block=%s hooked=%s soft=%s", tostring(W.Guard), tostring(W.Limits), nRaised, tostring(W.Block), tostring(W.hooked), tostring(W.Soft))
    pcall(setclipboard, table.concat(out, "\n"))
end

-- ===== UI =====
local ok0, parent = pcall(function() return gethui() end)
if not ok0 or not parent then parent = lp:WaitForChild("PlayerGui") end
for _, g in ipairs(parent:GetChildren()) do if g.Name == "TowLockGui" then g:Destroy() end end
local gui = Instance.new("ScreenGui")
gui.Name = "TowLockGui" gui.ResetOnSpawn = false gui.IgnoreGuiInset = true gui.Parent = parent

local BLUE, GREY = Color3.fromRGB(0, 120, 255), Color3.fromRGB(50, 54, 70)
local ON, OFF = Color3.fromRGB(30, 140, 60), Color3.fromRGB(160, 50, 50)
local function corner(o, r) local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, r) c.Parent = o end
local function btn(par, x, y, w, text, col)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, w, 0, 30) b.Position = UDim2.new(0, x, 0, y)
    b.BackgroundColor3 = col or BLUE b.TextColor3 = Color3.new(1, 1, 1)
    b.TextSize = 11 b.Text = text b.Parent = par corner(b, 6)
    return b
end
local function lbl(par, x, y, w, h, text)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0, w, 0, h) l.Position = UDim2.new(0, x, 0, y)
    l.BackgroundTransparency = 1 l.TextColor3 = Color3.fromRGB(190, 255, 190)
    l.TextSize = 10 l.TextWrapped = true l.Text = text
    l.TextXAlignment = Enum.TextXAlignment.Left l.TextYAlignment = Enum.TextYAlignment.Top
    l.Parent = par
    return l
end
local function tog(par, x, y, w, key, name, cb)
    local b = btn(par, x, y, w, "")
    local function p() b.Text = name .. (W[key] and ": ON" or ": OFF") b.BackgroundColor3 = W[key] and ON or OFF end
    p()
    b.MouseButton1Click:Connect(function() W[key] = not W[key] p() if cb then cb(W[key]) end end)
end
local function makeDraggable(handle, target, onTap)
    local dragging, startIn, startPos, moved = false, nil, nil, 0
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging, moved = true, 0
            startIn, startPos = input.Position, target.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if onTap and moved < 8 then onTap() end
                end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local dd = input.Position - startIn
            moved = math.max(moved, dd.Magnitude)
            target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + dd.X, startPos.Y.Scale, startPos.Y.Offset + dd.Y)
        end
    end)
end

local icon = Instance.new("Frame")
icon.Size = UDim2.new(0, 40, 0, 40) icon.Position = UDim2.new(0, 62, 0.5, 30)
icon.BackgroundColor3 = Color3.fromRGB(190, 60, 60) icon.BackgroundTransparency = 0.3 icon.Active = true icon.Parent = gui
corner(icon, 20)
local iconTxt = Instance.new("TextLabel")
iconTxt.Size = UDim2.new(1, 0, 1, 0) iconTxt.BackgroundTransparency = 1 iconTxt.Text = "TL"
iconTxt.TextColor3 = Color3.new(1, 1, 1) iconTxt.TextSize = 13 iconTxt.Font = Enum.Font.GothamBold iconTxt.Parent = icon

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 280, 0, 352) panel.Position = UDim2.new(0, 112, 0, 40)
panel.BackgroundColor3 = Color3.fromRGB(25, 27, 35) panel.BackgroundTransparency = 0.1
panel.Visible = true panel.Parent = gui   -- opens by itself so you can see it
corner(panel, 10)
local title = Instance.new("Frame")
title.Size = UDim2.new(1, 0, 0, 28) title.BackgroundColor3 = Color3.fromRGB(40, 44, 58) title.Active = true title.Parent = panel
corner(title, 10)
local tl = lbl(title, 10, 0, 220, 28, "TOW LOCK  (drag here)")
tl.TextSize = 12 tl.TextColor3 = Color3.new(1, 1, 1) tl.Font = Enum.Font.GothamBold tl.TextYAlignment = Enum.TextYAlignment.Center
makeDraggable(icon, icon, function() panel.Visible = not panel.Visible end)
makeDraggable(title, panel, nil)
btn(title, 252, 0, 28, "X", Color3.fromRGB(200, 50, 50)).MouseButton1Click:Connect(function() panel.Visible = false end)

tog(panel, 6, 34, 130, "Guard", "GUARD")
tog(panel, 144, 34, 130, "Limits", "LIMITS", function(v)
    if v then task.spawn(function() pcall(applyLimits, true) end) else pcall(W.restoreLimits) end
end)
tog(panel, 6, 68, 130, "Block", "BLOCK SNAP", function(v)
    if v then
        installHook()
        task.spawn(function() nPatched = nPatched + patchSnapConsts() end)
    else
        unpatchSnapConsts()
    end
end)
btn(panel, 144, 68, 130, "RELEASE (4s)", Color3.fromRGB(200, 120, 0)).MouseButton1Click:Connect(function() W.allowUntil = os.clock() + 4 end)
local softB = btn(panel, 6, 102, 112, "", GREY)
local function sp() softB.Text = "SOFT " .. W.Soft end
sp()
btn(panel, 122, 102, 72, "-").MouseButton1Click:Connect(function() W.Soft = math.max(1, W.Soft - 1) sp() end)
btn(panel, 198, 102, 72, "+").MouseButton1Click:Connect(function() W.Soft = math.min(10, W.Soft + 1) sp() end)
tog(panel, 6, 136, 130, "Flag", "KILL SNAP FLAG", function(v)
    if not v then
        for m, val in pairs(W.flagOrig) do pcall(function() m:SetAttribute("WinchSnaps", val) end) end
    end
end)
btn(panel, 144, 136, 130, "RESCAN CODE", GREY).MouseButton1Click:Connect(function()
    task.spawn(function() nPatched = nPatched + patchSnapConsts() end)
end)
btn(panel, 6, 170, 268, "WINCH PROBE (copy)", Color3.fromRGB(200, 120, 0)).MouseButton1Click:Connect(function() pcall(probe) end)
local status = lbl(panel, 6, 206, 268, 142, "")
task.spawn(function()
    while gui.Parent do
        if panel.Visible then
            status.Text = string.format("physical tow links: %d | %s\nsnap flag cleared: %s | game functions patched: %d\nblock hook: %s | blocked writes/destroys: %d\nunhook window: %s\n\nThis game's winch is a virtual rope driven by car attributes, so the main protection is: KILL SNAP FLAG (removes WinchSnaps on my side), BLOCK SNAP (blocks snap writes, renames WinchSnaps inside the game code). To unhook with BLOCK on: tap the Winch button in the HUD or RELEASE.",
                #links, tautDbg, tostring(W.Flag), nPatched, W.hooked and "ok" or "not installed", W.blocked or 0,
                os.clock() < W.allowUntil and "OPEN (can unhook)" or "closed")
        end
        task.wait(0.25)
    end
end)
note("Part 7 loaded - tap the red TL button")

end
