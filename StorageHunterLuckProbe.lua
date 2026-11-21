--[==[
==============================================================================
 STORAGE HUNTER - LUCK PROBE  v1.0   (diagnostic only, Roblox Luau / Delta)
==============================================================================
 PURPOSE
   Answers one question with evidence instead of guessing: does the Lucky
   Drink timer, or the Luck percentage, have ANY surface the client can
   actually influence, or is it 100% server-authoritative?

   This script does NOT attempt to cheat anything. It:
     1. Writes a test value to each known Luck-expiry attribute, waits, and
        rereads it, to see if the server stomps it back (= no hole) or lets
        it stick (= worth investigating further).
     2. Hooks outgoing calls on remotes that plausibly touch Luck/Drink/Grading
        so you can see, in the Log, exactly what the client sends and what the
        server replies, when you actually drink a potion or grade/auction an
        item. This is passive observation of your own traffic, nothing is
        changed or blocked.
     3. Lists any ReplicatedStorage ModuleScript with "luck" in its name, so
        we know if roll logic is even reachable from the client.

   IMPORTANT: if this probe finds a real server-side hole (the server trusts
   a client-sent value), that does NOT mean you should exploit it. Doing so
   would be cheating the game's economy against other players and I will not
   help build that part. This tool only tells you whether one exists.

 HOW TO USE
   1. Run this file (needs hookfunction/hookmetamethod; most Delta builds on
      Android support this, but some don't - the script will tell you).
   2. Tap "Run Write Test" once (not while a drink is active ideally, so it
      doesn't interfere with a real timer).
   3. Tap "Start Remote Log", then go drink a Lucky Drink / grade an item /
      open an auction in-game for ~15-20 seconds.
   4. Tap "Copy Report" and send it back.
==============================================================================
]==]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local genv = (getgenv and getgenv()) or _G
if genv.__SH_LUCKPROBE and genv.__SH_LUCKPROBE.Destroy then
	pcall(genv.__SH_LUCKPROBE.Destroy)
end

local CONFIG = {
	ATTR_HINTS = { "luckdrink", "luckboost", "activeluck", "luckexpire" },
	REMOTE_PATH_HINTS = { "grading", "collections", "luck", "drink", "boost", "cauldron", "carnival" },
	WRITE_TEST_WAIT = 4, -- seconds between write and reread
	MAX_LOG_LINES = 300,
}

local LOG = {}
local function log(msg)
	local line = string.format("[%s] %s", os.date("%H:%M:%S"), tostring(msg))
	table.insert(LOG, line)
	if #LOG > CONFIG.MAX_LOG_LINES then table.remove(LOG, 1) end
	if statusLabel then statusLabel.Text = tostring(msg) end
end

local function hasAny(s, list)
	s = string.lower(tostring(s))
	for _, kw in ipairs(list) do
		if string.find(s, kw, 1, true) then return true end
	end
	return false
end

------------------------------------------------------------------------------
-- 1) WRITE-PERSISTENCE TEST on Luck expiry attributes
------------------------------------------------------------------------------
local function writeTest()
	log("Write test: scanning player attributes...")
	local targets = {}
	for k, v in pairs(LocalPlayer:GetAttributes()) do
		if type(v) == "number" and hasAny(k, CONFIG.ATTR_HINTS) then
			table.insert(targets, { key = k, original = v })
		end
	end
	if #targets == 0 then
		log("Write test: no Luck-expiry attributes found on LocalPlayer right now.")
		return
	end
	local fakeVal
	for _, t in ipairs(targets) do
		fakeVal = os.time() + 999999 -- obviously-fake far-future expiry
		local ok, err = pcall(function() LocalPlayer:SetAttribute(t.key, fakeVal) end)
		t.wrote = ok
		if not ok then log("Write test: couldn't even set " .. t.key .. " locally: " .. tostring(err)) end
	end
	log(string.format("Write test: wrote fake value to %d attribute(s), waiting %ds...", #targets, CONFIG.WRITE_TEST_WAIT))
	task.wait(CONFIG.WRITE_TEST_WAIT)
	for _, t in ipairs(targets) do
		local now = LocalPlayer:GetAttribute(t.key)
		if now == fakeVal then
			log(string.format("RESULT %s: value STUCK at our fake number (%s). Client write was not overwritten in %ds -> worth a longer soak test, but this alone doesn't prove the server reads this copy.", t.key, tostring(now), CONFIG.WRITE_TEST_WAIT))
		elseif now == t.original then
			log(string.format("RESULT %s: value RESET to original (%s) by the server/replication -> this attribute is server-owned, no hole here.", t.key, tostring(t.original)))
		else
			log(string.format("RESULT %s: value is now %s (neither our fake nor the original) -> server is actively ticking it, server-owned.", t.key, tostring(now)))
		end
	end
end

------------------------------------------------------------------------------
-- 2) REMOTE TRAFFIC LOGGER (passive - logs calls, changes nothing)
------------------------------------------------------------------------------
local RemoteLog = { active = false, hooked = {} }

local function remoteMatches(inst)
	return hasAny(inst:GetFullName(), CONFIG.REMOTE_PATH_HINTS)
end

local function describeArgs(...)
	local parts = {}
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		local t = typeof(v)
		if t == "string" or t == "number" or t == "boolean" or t == "nil" then
			table.insert(parts, tostring(v))
		elseif t == "table" then
			local ok, j = pcall(function()
				local n = 0
				for _ in pairs(v) do n += 1 end
				return "{table, " .. n .. " entries}"
			end)
			table.insert(parts, ok and j or "{table}")
		else
			table.insert(parts, "<" .. t .. ">")
		end
	end
	return table.concat(parts, ", ")
end

local canHook = (hookfunction ~= nil) and (hookmetamethod ~= nil or getrawmetatable ~= nil)

function RemoteLog.start()
	if RemoteLog.active then log("Remote log already running") return end
	if not canHook then
		log("This executor doesn't expose hookfunction/hookmetamethod - cannot observe remote traffic this way. (Delta on Android usually has these; if not, report that.)")
		return
	end
	local count = 0
	for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
		if (d:IsA("RemoteEvent") or d:IsA("RemoteFunction")) and remoteMatches(d) then
			local full = d:GetFullName()
			if d:IsA("RemoteEvent") then
				local orig
				local ok = pcall(function()
					orig = hookfunction(d.FireServer, function(self, ...)
						log("FireServer  " .. full .. "  args=(" .. describeArgs(...) .. ")")
						return orig(self, ...)
					end)
				end)
				if ok then count += 1; table.insert(RemoteLog.hooked, { inst = d, kind = "FireServer", orig = orig }) end
			else
				local orig
				local ok = pcall(function()
					orig = hookfunction(d.InvokeServer, function(self, ...)
						log("InvokeServer " .. full .. "  args=(" .. describeArgs(...) .. ")")
						local result = { orig(self, ...) }
						log("  -> reply: " .. describeArgs(table.unpack(result)))
						return table.unpack(result)
					end)
				end)
				if ok then count += 1; table.insert(RemoteLog.hooked, { inst = d, kind = "InvokeServer", orig = orig }) end
			end
		end
	end
	RemoteLog.active = true
	log(string.format("Remote log started on %d remote(s). Now go drink / grade / auction in-game.", count))
end

function RemoteLog.stop()
	-- Note: most executors don't offer a clean unhook; this just marks it inactive
	-- and stops narrating. Restoring originals isn't guaranteed to be supported.
	RemoteLog.active = false
	log("Remote log marked stopped (hooks may remain installed until this script is removed/re-executed).")
end

------------------------------------------------------------------------------
-- 3) MODULE SCAN
------------------------------------------------------------------------------
local function moduleScan()
	local hits = {}
	for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
		if d:IsA("ModuleScript") and hasAny(d.Name, { "luck" }) then
			table.insert(hits, d:GetFullName())
		end
	end
	log(string.format("Module scan: %d ModuleScript(s) with 'luck' in the name under ReplicatedStorage.", #hits))
	for _, h in ipairs(hits) do log("  " .. h) end
	return hits
end

------------------------------------------------------------------------------
-- REPORT
------------------------------------------------------------------------------
local function buildReport()
	local lines = {
		"=== STORAGE HUNTER LUCK PROBE REPORT ===",
		"canHook (hookfunction/hookmetamethod available): " .. tostring(canHook),
		"",
		"--- FULL LOG ---",
	}
	for _, l in ipairs(LOG) do table.insert(lines, l) end
	return table.concat(lines, "\n")
end

local function copyText(txt)
	local fn = setclipboard or toclipboard or (syn and syn.write_clipboard)
	if not fn then
		if writefile then
			pcall(writefile, "StorageHunter_LuckProbeReport.txt", txt)
			log("No clipboard function; saved to StorageHunter_LuckProbeReport.txt instead")
		else
			log("No clipboard function and no writefile available")
		end
		return
	end
	local ok, err = pcall(fn, txt)
	log(ok and ("Report copied (" .. #txt .. " chars)") or ("Copy failed: " .. tostring(err)))
end

------------------------------------------------------------------------------
-- MINIMAL UI
------------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "SHLuckProbe"
gui.ResetOnSpawn = false
local ok = pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not ok or not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(220, 210)
frame.Position = UDim2.new(0, 12, 0.45, 0)
frame.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 26)
title.BackgroundColor3 = Color3.fromRGB(40, 40, 52)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextColor3 = Color3.new(1, 1, 1)
title.Text = "  Luck Probe (diagnostic)"
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 8)

statusLabel = Instance.new("TextLabel")
statusLabel.Position = UDim2.new(0, 6, 0, 150)
statusLabel.Size = UDim2.new(1, -12, 0, 54)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 11
statusLabel.TextWrapped = true
statusLabel.TextColor3 = Color3.fromRGB(190, 190, 200)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.Text = "Ready. Run tests in order (see file header)."
statusLabel.Parent = frame

local body = Instance.new("Frame")
body.Position = UDim2.fromOffset(0, 30)
body.Size = UDim2.new(1, 0, 0, 116)
body.BackgroundTransparency = 1
body.Parent = frame
local grid = Instance.new("UIGridLayout", body)
grid.CellSize = UDim2.fromOffset(100, 34)
grid.CellPadding = UDim2.fromOffset(6, 6)
local padf = Instance.new("UIPadding", body)
padf.PaddingLeft = UDim.new(0, 6)

local function btn(text, cb)
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = Color3.fromRGB(48, 48, 62)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 12
	b.TextWrapped = true
	b.Text = text
	b.Parent = body
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	b.MouseButton1Click:Connect(function()
		task.spawn(function()
			local ok2, err = pcall(cb)
			if not ok2 then log("Error: " .. tostring(err)) end
		end)
	end)
end

btn("Write Test", writeTest)
btn("Start Remote Log", RemoteLog.start)
btn("Stop Remote Log", RemoteLog.stop)
btn("Module Scan", moduleScan)
btn("Copy Report", function() copyText(buildReport()) end)
btn("Close", function()
	pcall(function() gui:Destroy() end)
	genv.__SH_LUCKPROBE = nil
end)

genv.__SH_LUCKPROBE = { Destroy = function() pcall(function() gui:Destroy() end) end }
log("Luck Probe loaded.")
