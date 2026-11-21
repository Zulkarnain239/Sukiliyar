-- Blox Range v2 | ESP (toggles + line) | Aimbot (scope fix) | Magic Bullet | Dump/Spy | Delta Android

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
S.spy, S.magicOn, S.magicTarget = false, false, nil

local CFG = {
	ESP = false, Chams = true, Names = false, Health = false, Lines = true,
	Aim = false, Part = "Head", FOV = 150, Smooth = 0.35, WallCheck = true, ShowFOV = true,
	Magic = false, MagicFOV = 300,
}
local BASE_FOV = math.rad(80)

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
local function isEnemy(p)
	if p == LP then return false end
	if LP.Team then
		-- pemain tanpa tim (lobby) bukan musuh
		return p.Team ~= nil and p.Team ~= LP.Team
	end
	if p.Team then return true end
	return p.TeamColor ~= LP.TeamColor
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
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { LP.Character, char, Camera }
	params.IgnoreWater = true
	local origin = Camera.CFrame.Position
	return Workspace:Raycast(origin, part.Position - origin, params) == nil
end

-- FOV dihitung dalam SUDUT (bukan pixel) supaya tetap bekerja saat scope/zoom
local function maxAngle(px)
	local focal = (Camera.ViewportSize.Y / 2) / math.tan(BASE_FOV / 2)
	return math.atan(px / focal)
end

local function getTarget(px)
	local cf = Camera.CFrame
	local pos, look = cf.Position, cf.LookVector
	local lim = maxAngle(px)
	local best, bestAng
	for _, p in ipairs(Players:GetPlayers()) do
		if isEnemy(p) then
			local char = p.Character
			if alive(char) then
				local part = getAimPart(char)
				if part then
					local v = part.Position - pos
					local m = v.Magnitude
					if m > 0.1 then
						local ang = math.acos(math.clamp(look:Dot(v / m), -1, 1))
						if ang <= lim and (not bestAng or ang < bestAng) and visible(part, char) then
							best, bestAng = part, ang
						end
					end
				end
			end
		end
	end
	return best
end

----------------------------------------------------------------
-- GUI
----------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "BR_Gui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
local okParent = pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not okParent or not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end

local holder = Instance.new("Folder", gui)
holder.Name = "ESP"

local fovCircle = Instance.new("Frame", gui)
fovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
fovCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
fovCircle.BackgroundTransparency = 1
fovCircle.Size = UDim2.new(0, CFG.FOV * 2, 0, CFG.FOV * 2)
Instance.new("UICorner", fovCircle).CornerRadius = UDim.new(1, 0)
local fovStroke = Instance.new("UIStroke", fovCircle)
fovStroke.Color = Color3.new(1, 1, 1)
fovStroke.Thickness = 1.5
fovStroke.Transparency = 0.4

local main = Instance.new("Frame", gui)
main.Size = UDim2.new(0, 240, 0, 290)
main.Position = UDim2.new(0, 60, 0, 60)
main.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
main.BorderSizePixel = 0
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", main)
title.Size = UDim2.new(1, -40, 0, 28)
title.Position = UDim2.new(0, 8, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Blox Range v2"
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
	main.Size = minimized and UDim2.new(0, 240, 0, 28) or UDim2.new(0, 240, 0, 290)
	mini.Text = minimized and "+" or "-"
end)

local dragging, dragStart, startPos
title.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging, dragStart, startPos = true, i.Position, main.Position
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

----------------------------------------------------------------
-- Log
----------------------------------------------------------------
local logBox -- dibuat di bawah
local logLines = {}
local function log(s)
	logLines[#logLines + 1] = tostring(s)
	if logBox then logBox.Text = table.concat(logLines, "\n") end
end

local function listNames(inst, max)
	local t = {}
	for i, c in ipairs(inst:GetChildren()) do
		if i > max then t[#t + 1] = "..." break end
		t[#t + 1] = c.Name .. "(" .. c.ClassName .. ")"
	end
	return table.concat(t, ", ")
end

----------------------------------------------------------------
-- Menu
----------------------------------------------------------------
header("ESP")
makeToggle("ESP Enemy", "ESP")
makeToggle("Chams (Highlight)", "Chams")
makeToggle("Line", "Lines")
makeToggle("Nama + Jarak", "Names")
makeToggle("Health", "Health")

header("AIMBOT")
makeToggle("Aimbot", "Aim")
makeBtn("Target: Head", function(b)
	CFG.Part = (CFG.Part == "Head") and "Body" or "Head"
	b.Text = "Target: " .. CFG.Part
end)
makeToggle("Wall Check", "WallCheck")
makeStepper(function() return "FOV: " .. CFG.FOV end, function(d)
	CFG.FOV = math.clamp(CFG.FOV + d * 20, 30, 800)
end)
makeStepper(function() return "Speed: " .. string.format("%.2f", CFG.Smooth) end, function(d)
	CFG.Smooth = math.clamp(math.floor((CFG.Smooth + d * 0.05) * 100 + 0.5) / 100, 0.05, 1)
end)
makeToggle("FOV Circle", "ShowFOV", function(v) fovCircle.Visible = v end)

header("MAGIC BULLET")
makeToggle("Magic Bullet", "Magic")
makeStepper(function() return "Magic FOV: " .. CFG.MagicFOV end, function(d)
	CFG.MagicFOV = math.clamp(CFG.MagicFOV + d * 50, 50, 2000)
end)
makeBtn("Spy Fire Remote: OFF", function(b)
	S.spy = not S.spy
	b.Text = "Spy Fire Remote: " .. (S.spy and "ON" or "OFF")
	b.BackgroundColor3 = S.spy and ONC or OFFC
	if S.spy then log("Spy ON: tembak senjata, argumen FireServer akan dicatat.") end
end)

header("DEBUG")
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

makeBtn("Dump", function()
	logLines = {}
	log("Me: " .. LP.Name .. " | Team: " .. tostring(LP.Team))
	log("Camera: " .. tostring(Camera.CameraType) .. " | FOV " .. tostring(Camera.FieldOfView))
	for _, p in ipairs(Players:GetPlayers()) do
		local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		log(p.Name .. " | " .. tostring(p.Team) .. " | enemy=" .. tostring(isEnemy(p)) .. " | hp=" .. tostring(h and math.floor(h.Health) or "-"))
	end
	log("Dump done.")
end)

makeBtn("Probe Camera (3 dtk)", function()
	logLines = {}
	log("Scope sekarang! Probe jalan 3 detik lagi...")
	task.delay(3, function()
		logLines = {}
		local c = Workspace.CurrentCamera
		log("CamType: " .. tostring(c.CameraType) .. " | FOV " .. string.format("%.1f", c.FieldOfView))
		log("Subject: " .. tostring(c.CameraSubject))
		log("Same cam obj: " .. tostring(c == Camera))
		local ps = LP:FindFirstChild("PlayerScripts")
		log("PlayerScripts: " .. (ps and listNames(ps, 30) or "none"))
		log("PlayerGui: " .. listNames(LP.PlayerGui, 40))
		local tool = LP.Character and LP.Character:FindFirstChildOfClass("Tool")
		log("Tool: " .. tostring(tool))
		if tool then
			for k, v in pairs(tool:GetAttributes()) do log("  attr " .. k .. "=" .. tostring(v)) end
			log("  children: " .. listNames(tool, 20))
		end
		if LP.Character then
			for k, v in pairs(LP.Character:GetAttributes()) do log("  charattr " .. k .. "=" .. tostring(v)) end
		end
		log("Probe done.")
	end)
end)

makeBtn("Copy Log", function()
	if setclipboard then
		setclipboard(table.concat(logLines, "\n"))
		log("(copied)")
	else
		log("setclipboard tidak ada, select teks manual")
	end
end)

----------------------------------------------------------------
-- ESP (jalan di render step supaya line mulus)
----------------------------------------------------------------
local esp = {}
local function clearESP(p)
	local e = esp[p]
	if e then
		for _, k in ipairs({ "hl", "bb", "ln" }) do
			if e[k] then e[k]:Destroy() end
		end
		esp[p] = nil
	end
end

local function updateESP()
	local vp = Camera.ViewportSize
	local from = Vector2.new(vp.X / 2, vp.Y)
	for _, p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		local ok, hum = alive(char)
		local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head"))
		if CFG.ESP and isEnemy(p) and ok and root then
			local e = esp[p]
			if not e or e.char ~= char or not e.hl.Parent then
				clearESP(p)
				local hl = Instance.new("Highlight")
				hl.FillColor = Color3.fromRGB(255, 40, 40)
				hl.OutlineColor = Color3.new(1, 1, 1)
				hl.FillTransparency = 0.45
				hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				hl.Adornee = char
				hl.Parent = holder

				local bb = Instance.new("BillboardGui")
				bb.Adornee = root
				bb.AlwaysOnTop = true
				bb.Size = UDim2.new(0, 150, 0, 22)
				bb.StudsOffset = Vector3.new(0, 3.2, 0)
				bb.Parent = holder
				local lb = Instance.new("TextLabel", bb)
				lb.Size = UDim2.new(1, 0, 1, 0)
				lb.BackgroundTransparency = 1
				lb.TextColor3 = Color3.fromRGB(255, 255, 255)
				lb.TextStrokeTransparency = 0.2
				lb.Font = Enum.Font.GothamBold
				lb.TextSize = 12

				local ln = Instance.new("Frame")
				ln.AnchorPoint = Vector2.new(0.5, 0.5)
				ln.BorderSizePixel = 0
				ln.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
				ln.Parent = holder

				e = { hl = hl, bb = bb, lb = lb, ln = ln, char = char }
				esp[p] = e
			end

			e.hl.Enabled = CFG.Chams

			local parts = {}
			if CFG.Names then
				parts[#parts + 1] = string.format("%s [%d]", p.Name, (Camera.CFrame.Position - root.Position).Magnitude)
			end
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
			clearESP(p)
		end
	end
end

----------------------------------------------------------------
-- Magic Bullet: hook FireServer + ubah argumen ke arah target
----------------------------------------------------------------
local fireNames = { FireRifle = true, FirePistol = true, FireSniper = true, FireLMG = true, FireRocket = true }

S.rewrite = function(args, tgt, origin)
	local tpos = tgt.Position
	local dir = (tpos - origin).Unit
	local function fix(v, depth)
		local t = typeof(v)
		if t == "Vector3" then
			if v.Magnitude > 0.9 and v.Magnitude < 1.1 then
				return dir -- arah tembak
			elseif (v - origin).Magnitude > 15 then
				return tpos -- posisi kena
			end
			return v -- origin/muzzle
		elseif t == "CFrame" then
			if (v.Position - origin).Magnitude > 15 then
				return CFrame.new(tpos)
			end
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

local spyCount = {}
local function fmt(v, d)
	local t = typeof(v)
	if t == "Vector3" then
		return string.format("V3(%.1f,%.1f,%.1f)", v.X, v.Y, v.Z)
	elseif t == "CFrame" then
		local p = v.Position
		return string.format("CF(%.1f,%.1f,%.1f)", p.X, p.Y, p.Z)
	elseif t == "Instance" then
		return "Inst:" .. v.ClassName .. ":" .. v.Name
	elseif t == "table" then
		if d >= 2 then return "{...}" end
		local s = {}
		for k, x in pairs(v) do
			s[#s + 1] = tostring(k) .. "=" .. fmt(x, d + 1)
			if #s >= 8 then break end
		end
		return "{" .. table.concat(s, ",") .. "}"
	end
	return t .. ":" .. tostring(v)
end

S.spyFn = function(name, args)
	spyCount[name] = (spyCount[name] or 0) + 1
	if spyCount[name] > 6 then return end
	task.defer(function()
		local t = {}
		for i = 1, args.n do t[i] = fmt(args[i], 0) end
		log(name .. "(" .. table.concat(t, ", ") .. ")")
	end)
end

if not S.hooked and hookmetamethod and getnamecallmethod then
	S.hooked = true
	local old
	old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
		local m = getnamecallmethod()
		if m == "FireServer" and typeof(self) == "Instance" and fireNames[self.Name] then
			local args = table.pack(...)
			if S.spy and S.spyFn then S.spyFn(self.Name, args) end
			local tgt = S.magicOn and S.magicTarget
			if tgt and tgt.Parent and S.camPos and S.rewrite then
				local okr, newArgs = pcall(S.rewrite, args, tgt, S.camPos)
				if okr then
					if setnamecallmethod then setnamecallmethod(m) end
					return old(self, table.unpack(newArgs, 1, args.n))
				end
			end
			if setnamecallmethod then setnamecallmethod(m) end
			return old(self, ...)
		end
		return old(self, ...)
	end))
elseif not S.hooked then
	log("Executor tidak support hookmetamethod: Magic Bullet tidak bisa jalan.")
end

----------------------------------------------------------------
-- Main loop (prioritas tinggi supaya jalan SETELAH kamera game, termasuk saat scope)
----------------------------------------------------------------
RunService:BindToRenderStep("BR_Main", 10000, function()
	Camera = Workspace.CurrentCamera
	if not Camera then return end
	S.camPos = Camera.CFrame.Position

	-- lingkaran FOV ikut zoom
	local curFov = math.rad(math.clamp(Camera.FieldOfView, 1, 120))
	local r = CFG.FOV * math.tan(BASE_FOV / 2) / math.tan(curFov / 2)
	fovCircle.Size = UDim2.new(0, r * 2, 0, r * 2)

	if CFG.Aim then
		local t = getTarget(CFG.FOV)
		if t then
			Camera.CFrame = Camera.CFrame:Lerp(CFrame.lookAt(S.camPos, t.Position), CFG.Smooth)
		end
	end

	S.magicOn = CFG.Magic
	S.magicTarget = CFG.Magic and getTarget(CFG.MagicFOV) or nil

	updateESP()
end)

local rmConn = Players.PlayerRemoving:Connect(clearESP)

G.BR_CLEANUP = function()
	S.magicOn, S.spy, S.magicTarget = false, false, nil
	pcall(function() RunService:UnbindFromRenderStep("BR_Main") end)
	rmConn:Disconnect()
	dragConn:Disconnect()
	gui:Destroy()
end

log("v2 loaded. Tap Probe Camera lalu scope untuk debug.")
