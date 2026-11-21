-- Blox Range | Enemy ESP + Aimbot (Head/Body) + Dump | Delta (Android)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LP = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- cleanup old run
if getgenv and getgenv().BR_CLEANUP then pcall(getgenv().BR_CLEANUP) end

local CFG = {
	ESP = false,
	Aim = false,
	Part = "Head", -- "Head" or "Body"
	FOV = 150,
	Smooth = 0.35, -- 1 = instant snap, lower = smoother
	WallCheck = true,
	ShowFOV = true,
}

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
fovStroke.Color = Color3.fromRGB(255, 255, 255)
fovStroke.Thickness = 1.5
fovStroke.Transparency = 0.4

local main = Instance.new("Frame", gui)
main.Size = UDim2.new(0, 230, 0, 270)
main.Position = UDim2.new(0, 60, 0, 60)
main.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
main.BorderSizePixel = 0
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", main)
title.Size = UDim2.new(1, -40, 0, 28)
title.Position = UDim2.new(0, 8, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Blox Range"
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
local layout = Instance.new("UIListLayout", body)
layout.Padding = UDim.new(0, 5)

local minimized = false
mini.MouseButton1Click:Connect(function()
	minimized = not minimized
	body.Visible = not minimized
	main.Size = minimized and UDim2.new(0, 230, 0, 28) or UDim2.new(0, 230, 0, 270)
	mini.Text = minimized and "+" or "-"
end)

-- drag
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

local function makeBtn(text, cb)
	local b = Instance.new("TextButton", body)
	b.Size = UDim2.new(1, -4, 0, 30)
	b.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
	b.Text = text
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.Gotham
	b.TextSize = 13
	b.AutoButtonColor = true
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	b.MouseButton1Click:Connect(function() cb(b) end)
	return b
end

local function onOff(v) return v and "ON" or "OFF" end

local espBtn = makeBtn("ESP Enemy: OFF", function(b)
	CFG.ESP = not CFG.ESP
	b.Text = "ESP Enemy: " .. onOff(CFG.ESP)
	b.BackgroundColor3 = CFG.ESP and Color3.fromRGB(40, 120, 60) or Color3.fromRGB(45, 45, 55)
end)

local aimBtn = makeBtn("Aimbot: OFF", function(b)
	CFG.Aim = not CFG.Aim
	b.Text = "Aimbot: " .. onOff(CFG.Aim)
	b.BackgroundColor3 = CFG.Aim and Color3.fromRGB(40, 120, 60) or Color3.fromRGB(45, 45, 55)
end)

makeBtn("Target: Head", function(b)
	CFG.Part = (CFG.Part == "Head") and "Body" or "Head"
	b.Text = "Target: " .. CFG.Part
end)

local wallBtn = makeBtn("Wall Check: ON", function(b)
	CFG.WallCheck = not CFG.WallCheck
	b.Text = "Wall Check: " .. onOff(CFG.WallCheck)
end)

local fovLbl
local function fovRow()
	local row = Instance.new("Frame", body)
	row.Size = UDim2.new(1, -4, 0, 30)
	row.BackgroundTransparency = 1
	local function small(txt, x, cb)
		local b = Instance.new("TextButton", row)
		b.Size = UDim2.new(0, 40, 1, 0)
		b.Position = UDim2.new(x, x == 0 and 0 or -40, 0, 0)
		b.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
		b.Text = txt
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Font = Enum.Font.GothamBold
		b.TextSize = 16
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
		b.MouseButton1Click:Connect(cb)
	end
	fovLbl = Instance.new("TextLabel", row)
	fovLbl.Size = UDim2.new(1, -90, 1, 0)
	fovLbl.Position = UDim2.new(0, 45, 0, 0)
	fovLbl.BackgroundTransparency = 1
	fovLbl.TextColor3 = Color3.new(1, 1, 1)
	fovLbl.Font = Enum.Font.Gotham
	fovLbl.TextSize = 13
	fovLbl.Text = "FOV: " .. CFG.FOV
	local function setFov(d)
		CFG.FOV = math.clamp(CFG.FOV + d, 30, 600)
		fovLbl.Text = "FOV: " .. CFG.FOV
		fovCircle.Size = UDim2.new(0, CFG.FOV * 2, 0, CFG.FOV * 2)
	end
	small("-", 0, function() setFov(-20) end)
	small("+", 1, function() setFov(20) end)
end
fovRow()

local smLbl
local function smoothRow()
	local row = Instance.new("Frame", body)
	row.Size = UDim2.new(1, -4, 0, 30)
	row.BackgroundTransparency = 1
	local function small(txt, x, cb)
		local b = Instance.new("TextButton", row)
		b.Size = UDim2.new(0, 40, 1, 0)
		b.Position = UDim2.new(x, x == 0 and 0 or -40, 0, 0)
		b.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
		b.Text = txt
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Font = Enum.Font.GothamBold
		b.TextSize = 16
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
		b.MouseButton1Click:Connect(cb)
	end
	smLbl = Instance.new("TextLabel", row)
	smLbl.Size = UDim2.new(1, -90, 1, 0)
	smLbl.Position = UDim2.new(0, 45, 0, 0)
	smLbl.BackgroundTransparency = 1
	smLbl.TextColor3 = Color3.new(1, 1, 1)
	smLbl.Font = Enum.Font.Gotham
	smLbl.TextSize = 13
	smLbl.Text = "Speed: " .. string.format("%.2f", CFG.Smooth)
	local function setSm(d)
		CFG.Smooth = math.clamp(math.floor((CFG.Smooth + d) * 100 + 0.5) / 100, 0.05, 1)
		smLbl.Text = "Speed: " .. string.format("%.2f", CFG.Smooth)
	end
	small("-", 0, function() setSm(-0.05) end)
	small("+", 1, function() setSm(0.05) end)
end
smoothRow()

makeBtn("FOV Circle: ON", function(b)
	CFG.ShowFOV = not CFG.ShowFOV
	b.Text = "FOV Circle: " .. onOff(CFG.ShowFOV)
	fovCircle.Visible = CFG.ShowFOV
end)

----------------------------------------------------------------
-- Log / Dump
----------------------------------------------------------------
local logBox = Instance.new("TextBox", body)
logBox.Size = UDim2.new(1, -4, 0, 90)
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

local logLines = {}
local function log(s)
	logLines[#logLines + 1] = tostring(s)
	logBox.Text = table.concat(logLines, "\n")
	print("[BR] " .. tostring(s))
end

local function listNames(inst, max)
	local t = {}
	for i, c in ipairs(inst:GetChildren()) do
		if i > max then t[#t + 1] = "..." break end
		t[#t + 1] = c.Name .. "(" .. c.ClassName .. ")"
	end
	return table.concat(t, ", ")
end

local function dump()
	logLines = {}
	log("PlaceId: " .. game.PlaceId)
	log("Me: " .. LP.Name .. " | Team: " .. tostring(LP.Team) .. " | TeamColor: " .. tostring(LP.TeamColor) .. " | Neutral: " .. tostring(LP.Neutral))
	local teams = game:GetService("Teams"):GetChildren()
	local tn = {}
	for _, t in ipairs(teams) do tn[#tn + 1] = t.Name end
	log("Teams: " .. (#tn > 0 and table.concat(tn, ", ") or "none"))
	log("Camera: " .. tostring(Camera.CameraType) .. " | FOV " .. tostring(Camera.FieldOfView))
	log("--- Players ---")
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		log(p.Name .. " | team=" .. tostring(p.Team) .. " | color=" .. tostring(p.TeamColor) .. " | enemy=" .. tostring(p ~= LP and (function()
			return isEnemyDump and isEnemyDump(p)
		end)()) .. " | hp=" .. tostring(h and math.floor(h.Health) or "nochar"))
	end
	if LP.Character then
		log("--- My Character ---")
		log(listNames(LP.Character, 40))
	end
	log("--- Workspace ---")
	log(listNames(Workspace, 50))
	local rs = game:GetService("ReplicatedStorage")
	log("--- ReplicatedStorage ---")
	log(listNames(rs, 40))
	log("--- Remotes (first 40) ---")
	local n = 0
	for _, d in ipairs(rs:GetDescendants()) do
		if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
			n = n + 1
			if n > 40 then break end
			log(d.ClassName:sub(1, 7) .. ": " .. d:GetFullName())
		end
	end
	log("Dump done.")
end

makeBtn("Dump", dump)
makeBtn("Copy Log", function()
	if setclipboard then
		setclipboard(table.concat(logLines, "\n"))
		log("(copied)")
	else
		log("setclipboard not available, select text in the box manually")
	end
end)

----------------------------------------------------------------
-- Logic
----------------------------------------------------------------
local function isEnemy(p)
	if p == LP then return false end
	if p.Team and LP.Team then return p.Team ~= LP.Team end
	if p.Neutral or LP.Neutral then return true end
	return p.TeamColor ~= LP.TeamColor
end
isEnemyDump = isEnemy

local function getAimPart(char)
	if CFG.Part == "Head" then
		return char:FindFirstChild("Head")
	end
	return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
end

local function alive(char)
	local h = char and char:FindFirstChildOfClass("Humanoid")
	return h and h.Health > 0, h
end

-- ESP
local esp = {}
local function clearESP(p)
	local e = esp[p]
	if e then
		if e.hl then e.hl:Destroy() end
		if e.bb then e.bb:Destroy() end
		esp[p] = nil
	end
end

local function updateESP()
	for _, p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		local ok, hum = alive(char)
		local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head"))
		if CFG.ESP and p ~= LP and isEnemy(p) and ok and root then
			local e = esp[p]
			if not e or e.char ~= char or not e.hl.Parent then
				clearESP(p)
				local hl = Instance.new("Highlight")
				hl.FillColor = Color3.fromRGB(255, 50, 50)
				hl.OutlineColor = Color3.fromRGB(255, 255, 255)
				hl.FillTransparency = 0.6
				hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				hl.Adornee = char
				hl.Parent = holder
				local bb = Instance.new("BillboardGui")
				bb.Adornee = root
				bb.AlwaysOnTop = true
				bb.Size = UDim2.new(0, 140, 0, 28)
				bb.StudsOffset = Vector3.new(0, 3.2, 0)
				bb.Parent = holder
				local lb = Instance.new("TextLabel", bb)
				lb.Size = UDim2.new(1, 0, 1, 0)
				lb.BackgroundTransparency = 1
				lb.TextColor3 = Color3.fromRGB(255, 90, 90)
				lb.TextStrokeTransparency = 0.3
				lb.Font = Enum.Font.GothamBold
				lb.TextSize = 12
				e = { hl = hl, bb = bb, lb = lb, char = char }
				esp[p] = e
			end
			local d = (Camera.CFrame.Position - root.Position).Magnitude
			e.lb.Text = string.format("%s [%d] %dHP", p.Name, d, hum.Health)
		else
			clearESP(p)
		end
	end
end

-- Aimbot
local function visible(part, char)
	if not CFG.WallCheck then return true end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { LP.Character, char, Camera }
	params.IgnoreWater = true
	local origin = Camera.CFrame.Position
	local hit = Workspace:Raycast(origin, part.Position - origin, params)
	return hit == nil
end

local function getTarget()
	local center = Camera.ViewportSize / 2
	local best, bestDist
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP and isEnemy(p) then
			local char = p.Character
			local ok = alive(char)
			local part = ok and getAimPart(char)
			if part then
				local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
				if onScreen then
					local dist = (Vector2.new(sp.X, sp.Y) - center).Magnitude
					if dist <= CFG.FOV and (not bestDist or dist < bestDist) and visible(part, char) then
						best, bestDist = part, dist
					end
				end
			end
		end
	end
	return best
end

RunService:BindToRenderStep("BR_Aim", Enum.RenderPriority.Camera.Value + 1, function()
	Camera = Workspace.CurrentCamera
	if not CFG.Aim then return end
	local target = getTarget()
	if target then
		local pos = Camera.CFrame.Position
		Camera.CFrame = Camera.CFrame:Lerp(CFrame.lookAt(pos, target.Position), CFG.Smooth)
	end
end)

local espConn = RunService.Heartbeat:Connect(updateESP)
local rmConn = Players.PlayerRemoving:Connect(clearESP)

if getgenv then
	getgenv().BR_CLEANUP = function()
		pcall(function() RunService:UnbindFromRenderStep("BR_Aim") end)
		espConn:Disconnect()
		rmConn:Disconnect()
		dragConn:Disconnect()
		gui:Destroy()
	end
end

log("Loaded. Tap Dump first and send me the log.")
