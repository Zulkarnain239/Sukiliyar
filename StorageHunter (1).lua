--[==[
==============================================================================
 STORAGE HUNTER TOOLKIT  v1.0   (Roblox Luau, client-side executor script)
 File: StorageHunter.lua      Loader: StorageHunter_Loader.lua
==============================================================================

 FOR ANY AI READING THIS FILE (read this first)
 ----------------------------------------------
 The user plays the Roblox game "Storage Hunter" on ANDROID with the DELTA
 executor. This script runs CLIENT-SIDE only and cannot change server data.
 It was written WITHOUT access to the game's internals, so it detects things
 heuristically and ships with a Probe that dumps the real game structure.
 Do NOT invent instance paths. Ask the user for the Probe output instead.

 USER'S GOALS
   1. ESP for valuable ITEMS only (value >= CONFIG.ESP_MIN_VALUE, about $5,000).
      NEVER players/NPCs (anything inside a model with a Humanoid is skipped).
   2. Lucky Drink: the user wanted it to never expire and wanted a custom Lucky %.
      TESTED AND PROVEN IMPOSSIBLE CLIENT-SIDE: the server owns the buff timer and
      the Luck value (player attributes such as ActiveLuckDrinkExpireAt_N are
      server-set; the HUD only displays them). Freezing the HUD changed nothing
      real. So this file has a DRINK WATCH instead: it reads the real expiry and
      warns the user before the drink runs out so they can drink again.
      Do not add fake/visual-only Luck features; the user explicitly does not
      want a "ghost" effect.
   3. Buttons: Copy Log, Copy Probe, Copy AI Handoff (the "Copy Code" request:
      it bundles context + config + log + probe + this file's source).

 HOW IT WORKS
   ESP        : every CONFIG.ESP_SCAN_INTERVAL seconds, scans Workspace for
                Models / Parts with a value-like attribute or ValueObject (names
                in CONFIG.ESP_VALUE_NAMES). Only items with value >= ESP_MIN_VALUE
                are kept (ESP_REQUIRE_VALUE = true). Nearest ESP_MAX_ITEMS get a
                BillboardGui label, nearest ESP_HIGHLIGHT_MAX also a Highlight.
   DRINK WATCH: reads the player's ActiveLuckDrinkExpireAt_* attributes (epoch
                timestamps set by the server). Falls back to the HUD drink timers
                (PlayerGui.CurrencyHud.HudContainer.DrinkTimers.*.Time, text m:ss).
                Shows time left in the panel and notifies at CONFIG.DRINK_WARN_SECONDS
                and when it expires.
   PROBE      : dumps leaderstats, attributes, tools, remotes, Lucky-related
                objects, GUI timer texts, ProximityPrompts, Workspace overview,
                ESP candidates, drink watch readings.

 KNOWN LIMITS
   - Client-side only. Server values (Luck %, buff timers, prices) cannot be
     changed from here. Do not suggest remote spoofing; the user was told no.
   - ESP guesses what an "item" looks like from value attributes. If valuable
     items do not show, ask for the Probe ESP section and tune CONFIG.

 WHAT TO ASK THE USER FOR
   Tap "Copy Probe" while standing near items (and with a drink active), then
   paste the text. Tap "Copy Log" for scan results and errors.

 FILE LAYOUT
   CONFIG -> AI_CONTEXT -> utilities -> ESP -> DRINK WATCH -> PROBE -> UI -> loops
==============================================================================
]==]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local LocalPlayer = Players.LocalPlayer

-- Re-run safe: remove a previous instance first
local genv = (getgenv and getgenv()) or _G
if genv.__SH_TOOLKIT and genv.__SH_TOOLKIT.Destroy then
	pcall(genv.__SH_TOOLKIT.Destroy)
end

------------------------------------------------------------------------------
-- CONFIG  (edit these; all keyword lists are lowercase, matched as substrings)
------------------------------------------------------------------------------
local CONFIG = {
	-- ESP
	ESP_ENABLED = true,
	ESP_REQUIRE_VALUE = true,  -- true: only show items that have a numeric value >= ESP_MIN_VALUE
	ESP_MIN_VALUE = 5000,      -- hide cheaper items (furniture, junk)
	ESP_HIGH_VALUE = 25000,    -- values >= this are drawn gold
	ESP_NAME_KEYWORDS = { "treasure", "loot", "valuable", "gem", "gold", "diamond", "jewel", "relic", "artifact", "antique", "collectible", "legendary", "mythic", "epic", "rare" },
	ESP_IGNORE_NAMES = { "baseplate", "spawn", "wall", "floor", "roof", "road", "fence", "tree", "grass", "terrain", "garage", "shop", "furniture", "lamp" },
	ESP_VALUE_NAMES = { "value", "price", "worth", "cost", "sell" },
	ESP_RARITY_NAMES = { "rarity", "tier", "grade" },
	ESP_MAX_ITEMS = 30,        -- max labels (nearest first); lower = less clutter
	ESP_HIGHLIGHT_MAX = 15,    -- Roblox only renders ~31 highlights at once
	ESP_MAX_DISTANCE = 600,    -- studs
	ESP_SCAN_INTERVAL = 6,     -- seconds between workspace scans

	-- Drink watch
	DRINK_WARN_SECONDS = 30,   -- warn when the Lucky Drink has this many seconds left
	LUCKY_WORDS = { "lucky", "luck", "potion", "drink", "buff", "boost" },

	-- Clipboard
	MAX_COPY_CHARS = 120000,
}

local AI_CONTEXT = [==[
CONTEXT FOR AI ASSISTANT
- Game: Roblox "Storage Hunter" (Pemburu Penyimpanan). Platform: Android. Executor: Delta (Luau, client-side only).
- Script: StorageHunter.lua (ESP for valuable items + Drink Watch + Probe + copy buttons).
- User goals: ESP for valuable ITEMS only (about $5,000 and up), never players. Copy Log / Copy Probe / Copy Code buttons,
  delivered as .lua files, readable by another AI.
- Lucky Drink: user wanted it to never expire and wanted a custom Lucky %. Tested: freezing the HUD timer did nothing,
  the server owns the buff and the Luck value. Client-side cannot fix this. Drink Watch (warn before expiry) replaces it.
  Do not build visual-only fake Luck features; the user does not want them, and do not suggest remote spoofing.
- To help with ESP: read the PROBE section below (ESP CANDIDATES, WORKSPACE TOP-LEVEL, PROXIMITY PROMPTS) and tune
  CONFIG.ESP_* . Never invent instance paths not shown in the probe.
]==]

------------------------------------------------------------------------------
-- STATE / UTILITIES
------------------------------------------------------------------------------
local alive = true
local connections = {}
local function track(c) table.insert(connections, c) return c end

local gui, statusLabel, drinkLabel
local espFolder = Instance.new("Folder")
espFolder.Name = "SH_ESP"

local LOG = {}
local function log(msg)
	local line = string.format("[%s] %s", os.date("%H:%M:%S"), tostring(msg))
	table.insert(LOG, line)
	if #LOG > 400 then table.remove(LOG, 1) end
	if statusLabel then statusLabel.Text = tostring(msg) end
end

local function hasAny(str, list)
	str = string.lower(tostring(str))
	for _, kw in ipairs(list) do
		if string.find(str, kw, 1, true) then return true end
	end
	return false
end

local function fmt(n)
	local s = tostring(math.floor(n + 0.5))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return out
end

local function serverNow()
	local ok, t = pcall(function() return workspace:GetServerTimeNow() end)
	if ok and type(t) == "number" then return t end
	return os.time()
end

local function isOurs(inst)
	return (gui and inst:IsDescendantOf(gui)) or inst:IsDescendantOf(espFolder)
end

local function copyText(txt)
	local fn = setclipboard or toclipboard or (syn and syn.write_clipboard)
	if not fn then return false, "no clipboard function in this executor" end
	local ok, err = pcall(fn, txt)
	return ok, err
end

local function copyOut(text, label)
	if #text > CONFIG.MAX_COPY_CHARS then
		text = string.sub(text, 1, CONFIG.MAX_COPY_CHARS) .. "\n...[truncated]"
	end
	local ok, err = copyText(text)
	if ok then
		log(label .. " copied (" .. #text .. " chars)")
		return
	end
	-- fallback: write to the executor workspace folder
	local fname = "StorageHunter_" .. string.gsub(label, "%s", "_") .. ".txt"
	if writefile then
		local ok2 = pcall(writefile, fname, text)
		if ok2 then
			log(label .. ": clipboard failed, saved to workspace file " .. fname)
			return
		end
	end
	log(label .. " FAILED: " .. tostring(err))
end

------------------------------------------------------------------------------
-- ESP  (items only, never players)
------------------------------------------------------------------------------
local ESP = { enabled = CONFIG.ESP_ENABLED, entries = {}, lastFound = {} }

local function getPart(inst)
	if inst:IsA("BasePart") then return inst end
	if inst:IsA("Model") then
		return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function myOrigin()
	local c = LocalPlayer.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	if r then return r.Position end
	local cam = workspace.CurrentCamera
	return cam and cam.CFrame.Position or Vector3.zero
end

local function inCharacter(d)
	if d:IsA("Model") and d:FindFirstChildOfClass("Humanoid") then return true end
	local a = d:FindFirstAncestorOfClass("Model")
	while a do
		if a:FindFirstChildOfClass("Humanoid") then return true end
		a = a:FindFirstAncestorOfClass("Model")
	end
	return false
end

-- Looks for a numeric "value" and a string "rarity" on the inst, its ValueObjects,
-- and (for Models) its primary/first part.
local function readInfo(inst)
	local value, rarity
	local function fromAttrs(o)
		for k, v in pairs(o:GetAttributes()) do
			if value == nil and type(v) == "number" and hasAny(k, CONFIG.ESP_VALUE_NAMES) then value = v end
			if rarity == nil and type(v) == "string" and hasAny(k, CONFIG.ESP_RARITY_NAMES) then rarity = v end
		end
	end
	local function fromChildren(o)
		for _, c in ipairs(o:GetChildren()) do
			if c:IsA("NumberValue") or c:IsA("IntValue") then
				if value == nil and hasAny(c.Name, CONFIG.ESP_VALUE_NAMES) then value = c.Value end
			elseif c:IsA("StringValue") then
				if rarity == nil and hasAny(c.Name, CONFIG.ESP_RARITY_NAMES) then rarity = c.Value end
			end
		end
	end
	fromAttrs(inst)
	fromChildren(inst)
	if inst:IsA("Model") and (value == nil or rarity == nil) then
		local p = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart")
		if p then fromAttrs(p) fromChildren(p) end
	end
	return value, rarity
end

-- returns ok(boolean), value, rarity
local function evalItem(inst)
	local lname = string.lower(inst.Name)
	if hasAny(lname, CONFIG.ESP_IGNORE_NAMES) then return false end
	local value, rarity = readInfo(inst)
	if value ~= nil then
		if value < CONFIG.ESP_MIN_VALUE then return false end
		return true, value, rarity
	end
	if CONFIG.ESP_REQUIRE_VALUE then return false end
	if rarity ~= nil or hasAny(lname, CONFIG.ESP_NAME_KEYWORDS) then return true, nil, rarity end
	return false
end

local function colorFor(e)
	local r = string.lower(e.rarity or "")
	if string.find(r, "mythic", 1, true) or string.find(r, "legend", 1, true) then return Color3.fromRGB(255, 150, 0) end
	if string.find(r, "epic", 1, true) then return Color3.fromRGB(190, 90, 255) end
	if string.find(r, "rare", 1, true) then return Color3.fromRGB(70, 150, 255) end
	if e.value and e.value >= CONFIG.ESP_HIGH_VALUE then return Color3.fromRGB(255, 215, 0) end
	return Color3.fromRGB(90, 255, 120)
end

local function createVisual(e)
	local bb = Instance.new("BillboardGui")
	bb.Name = "SH_BB"
	bb.AlwaysOnTop = true
	bb.Size = UDim2.fromOffset(160, 34)
	bb.StudsOffset = Vector3.new(0, 2, 0)
	bb.MaxDistance = CONFIG.ESP_MAX_DISTANCE
	bb.Adornee = e.part
	bb.Enabled = false
	bb.Parent = espFolder

	local tl = Instance.new("TextLabel")
	tl.BackgroundTransparency = 1
	tl.Size = UDim2.fromScale(1, 1)
	tl.Font = Enum.Font.GothamBold
	tl.TextSize = 14
	tl.TextWrapped = true
	tl.TextStrokeTransparency = 0.3
	tl.Text = e.name
	tl.Parent = bb

	local hl = Instance.new("Highlight")
	hl.Name = "SH_HL"
	hl.FillTransparency = 0.6
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Adornee = e.inst
	hl.Enabled = false
	hl.Parent = espFolder

	e.bb, e.label, e.hl = bb, tl, hl
end

local function destroyEntry(e)
	if e.bb then pcall(function() e.bb:Destroy() end) end
	if e.hl then pcall(function() e.hl:Destroy() end) end
end

local function countEntries()
	local n = 0
	for _ in pairs(ESP.entries) do n += 1 end
	return n
end

local function scanOnce()
	local found = {}
	local n = 0
	local origin = myOrigin()
	for _, d in ipairs(workspace:GetDescendants()) do
		n += 1
		if n % 1000 == 0 then task.wait() end
		if not alive then return end
		local parent = d.Parent
		if parent
			and (d:IsA("Model") or (d:IsA("BasePart") and not d:IsA("Terrain") and not parent:IsA("Model")))
			and not isOurs(d)
		then
			local isItem, value, rarity = evalItem(d)
			if isItem then
				if not inCharacter(d) then
					local part = getPart(d)
					if part then
						table.insert(found, {
							inst = d, part = part, value = value, rarity = rarity,
							dist = (part.Position - origin).Magnitude,
						})
					end
				end
			end
		end
	end

	table.sort(found, function(a, b) return a.dist < b.dist end)
	local keep = {}
	for i = 1, math.min(#found, CONFIG.ESP_MAX_ITEMS) do
		local f = found[i]
		keep[f.inst] = true
		local e = ESP.entries[f.inst]
		if not e then
			e = { inst = f.inst, name = f.inst.Name }
			e.part = f.part
			ESP.entries[f.inst] = e
			createVisual(e)
		end
		e.part, e.value, e.rarity = f.part, f.value, f.rarity
		e.bb.Adornee = f.part
	end
	for inst, e in pairs(ESP.entries) do
		if not keep[inst] then
			destroyEntry(e)
			ESP.entries[inst] = nil
		end
	end
	ESP.lastFound = found
	log(string.format("ESP scan: %d match(es), tracking %d", #found, countEntries()))
end

local function refreshESP()
	local list = {}
	local origin = myOrigin()
	for _, e in pairs(ESP.entries) do
		if e.part and e.part.Parent then
			e.dist = (e.part.Position - origin).Magnitude
			table.insert(list, e)
		end
	end
	table.sort(list, function(a, b) return a.dist < b.dist end)
	for i, e in ipairs(list) do
		local show = ESP.enabled and e.dist <= CONFIG.ESP_MAX_DISTANCE
		local col = colorFor(e)
		e.bb.Enabled = show
		e.label.TextColor3 = col
		e.label.Text = e.name
			.. (e.value and (" $" .. fmt(e.value)) or "")
			.. (e.rarity and (" <" .. tostring(e.rarity) .. ">") or "")
			.. "\n[" .. math.floor(e.dist) .. "m]"
		e.hl.FillColor = col
		e.hl.OutlineColor = col
		e.hl.Enabled = show and i <= CONFIG.ESP_HIGHLIGHT_MAX
	end
end

------------------------------------------------------------------------------
-- DRINK WATCH  (reads the REAL server timer, warns before the Lucky Drink ends)
------------------------------------------------------------------------------
local Drink = { enabled = true, active = false, warned = false }

local function fmtTime(sec)
	sec = math.max(0, math.floor(sec))
	return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

-- returns seconds remaining, source description
local function readRemaining()
	local best, src = 0, "none"
	local now = serverNow()
	for k, v in pairs(LocalPlayer:GetAttributes()) do
		if type(v) == "number" then
			local lk = string.lower(k)
			if string.find(lk, "luckdrink", 1, true) and string.find(lk, "expire", 1, true) then
				local t = v
				if t > 1e12 then t = t / 1000 end
				if t > now and (t - now) > best then
					best, src = t - now, "attr " .. k
				end
			end
		end
	end
	if best > 0 then return best, src end

	-- fallback: the HUD drink timers (text like "3:42")
	local ok, res = pcall(function()
		local pg = LocalPlayer:FindFirstChild("PlayerGui")
		local hud = pg and pg:FindFirstChild("CurrencyHud")
		local cont = hud and hud:FindFirstChild("HudContainer")
		local timers = cont and cont:FindFirstChild("DrinkTimers")
		local top = 0
		if timers then
			for _, t in ipairs(timers:GetChildren()) do
				local lbl = t:FindFirstChild("Time")
				if lbl and lbl:IsA("TextLabel") then
					local m, sec = string.match(lbl.Text, "^(%d+):(%d%d)$")
					if m then top = math.max(top, tonumber(m) * 60 + tonumber(sec)) end
				end
			end
		end
		return top
	end)
	if ok and res and res > 0 then return res, "HUD DrinkTimers" end
	return 0, src
end

local function notify(text)
	log(text)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", { Title = "Lucky Drink", Text = text, Duration = 6 })
	end)
end

function Drink.tick()
	if not drinkLabel then return end
	if not Drink.enabled then
		drinkLabel.Text = "Drink watch: off"
		return
	end
	local rem = readRemaining()
	if rem > 0 then
		Drink.active = true
		drinkLabel.Text = "Drink: " .. fmtTime(rem) .. " left"
		if rem <= CONFIG.DRINK_WARN_SECONDS and not Drink.warned then
			Drink.warned = true
			notify("Drink ends in " .. fmtTime(rem) .. ", drink again!")
		elseif rem > CONFIG.DRINK_WARN_SECONDS + 5 then
			Drink.warned = false
		end
	else
		drinkLabel.Text = "Drink: none active"
		if Drink.active then
			Drink.active = false
			Drink.warned = false
			notify("Drink expired!")
		end
	end
end

------------------------------------------------------------------------------
-- PROBE  (dumps the real game structure so an AI can tune this script)
------------------------------------------------------------------------------
local function probe()
	local P = {}
	local function add(s) table.insert(P, s) end
	local function section(t) add("") add("=== " .. t .. " ===") end
	local function attrString(o)
		local parts = {}
		for k, v in pairs(o:GetAttributes()) do
			table.insert(parts, k .. "=" .. tostring(v))
			if #parts >= 12 then break end
		end
		return #parts > 0 and (" {" .. table.concat(parts, ", ") .. "}") or ""
	end
	local function valStr(o)
		if o:IsA("ValueBase") then return " Value=" .. tostring(o.Value) end
		return ""
	end

	section("GAME")
	local exName = "unknown"
	if identifyexecutor then pcall(function() exName = tostring((identifyexecutor())) end) end
	add("executor: " .. exName)
	add("PlaceId: " .. tostring(game.PlaceId) .. "  GameId: " .. tostring(game.GameId))
	pcall(function()
		local info = MarketplaceService:GetProductInfo(game.PlaceId)
		add("name: " .. tostring(info.Name))
	end)
	add("players in server: " .. #Players:GetPlayers())

	section("PLAYER (children, leaderstats, attributes, tools)")
	add("player attrs:" .. attrString(LocalPlayer))
	for _, ch in ipairs(LocalPlayer:GetChildren()) do
		add("  Player child: " .. ch.Name .. " (" .. ch.ClassName .. ")" .. valStr(ch) .. attrString(ch))
	end
	local ls = LocalPlayer:FindFirstChild("leaderstats")
	if ls then
		for _, v in ipairs(ls:GetChildren()) do
			add("  leaderstats." .. v.Name .. " (" .. v.ClassName .. ")" .. valStr(v))
		end
	else
		add("  no leaderstats folder")
	end
	local function listTools(container, label)
		if not container then return end
		for _, t in ipairs(container:GetChildren()) do
			if t:IsA("Tool") then add("  " .. label .. ": " .. t.Name .. attrString(t)) end
		end
	end
	listTools(LocalPlayer:FindFirstChild("Backpack"), "Backpack tool")
	listTools(LocalPlayer.Character, "Equipped tool")

	section("LUCKY / BUFF RELATED OBJECTS (name or attribute matches)")
	local hits, n = 0, 0
	local function luckyScan(root)
		for _, d in ipairs(root:GetDescendants()) do
			n += 1
			if n % 2000 == 0 then task.wait() end
			if hits >= 70 then return end
			if not isOurs(d) then
				local match = hasAny(d.Name, CONFIG.LUCKY_WORDS)
				if not match then
					for k in pairs(d:GetAttributes()) do
						if hasAny(k, CONFIG.LUCKY_WORDS) then match = true break end
					end
				end
				if match then
					hits += 1
					add("  " .. d:GetFullName() .. " (" .. d.ClassName .. ")" .. valStr(d) .. attrString(d))
				end
			end
		end
	end
	luckyScan(LocalPlayer)
	luckyScan(ReplicatedStorage)
	luckyScan(workspace)
	if hits >= 70 then add("  (truncated at 70)") end

	section("GUI TEXTS (lucky words or timer-like text)")
	local pg = LocalPlayer:FindFirstChild("PlayerGui")
	local tcount = 0
	if pg then
		for _, d in ipairs(pg:GetDescendants()) do
			if (d:IsA("TextLabel") or d:IsA("TextButton")) and not isOurs(d) then
				local txt = d.Text or ""
				if txt ~= "" and (hasAny(txt, CONFIG.LUCKY_WORDS) or string.match(txt, "%d+:%d%d")) then
					tcount += 1
					if tcount > 40 then add("  (truncated at 40)") break end
					add(string.format("  %s  visible=%s  text=%q", d:GetFullName(), tostring(d.Visible), string.sub(txt, 1, 60)))
				end
			end
		end
	end

	section("REMOTES (ReplicatedStorage)")
	local rc = 0
	for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
		if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("BindableEvent") then
			rc += 1
			if rc <= 200 then add("  " .. d.ClassName .. "  " .. d:GetFullName()) end
		end
	end
	add("  total: " .. rc)

	section("WORKSPACE TOP-LEVEL")
	for i, c in ipairs(workspace:GetChildren()) do
		if i > 80 then add("  (truncated)") break end
		if c ~= workspace.Terrain and c ~= workspace.CurrentCamera then
			add(string.format("  %s (%s) children=%d", c.Name, c.ClassName, #c:GetChildren()))
		end
	end

	section("PROXIMITY PROMPTS (ActionText | ObjectText | parent name)")
	local groups, order, pn = {}, {}, 0
	for _, d in ipairs(workspace:GetDescendants()) do
		pn += 1
		if pn % 2000 == 0 then task.wait() end
		if d:IsA("ProximityPrompt") then
			local key = d.ActionText .. " | " .. d.ObjectText .. " | " .. (d.Parent and d.Parent.Name or "?")
			if not groups[key] then groups[key] = 0 table.insert(order, key) end
			groups[key] += 1
		end
	end
	table.sort(order, function(a, b) return groups[a] > groups[b] end)
	for i = 1, math.min(#order, 25) do add("  x" .. groups[order[i]] .. "  " .. order[i]) end

	section("ESP CANDIDATES (nearest first)")
	if #ESP.lastFound == 0 then pcall(scanOnce) end
	add("esp enabled: " .. tostring(ESP.enabled) .. " | tracked: " .. countEntries())
	for i = 1, math.min(#ESP.lastFound, 60) do
		local f = ESP.lastFound[i]
		add(string.format("  %s (%s) value=%s rarity=%s dist=%d%s",
			f.inst:GetFullName(), f.inst.ClassName, tostring(f.value), tostring(f.rarity),
			math.floor(f.dist), attrString(f.inst)))
	end

	section("DRINK WATCH")
	local rem, src = readRemaining()
	add("remaining: " .. tostring(rem) .. "s  source: " .. tostring(src))
	for k, v in pairs(LocalPlayer:GetAttributes()) do
		if hasAny(k, { "luck", "drink", "boost", "expire" }) then
			add("  player attr " .. k .. "=" .. tostring(v))
		end
	end

	return table.concat(P, "\n")
end

local function configDump()
	local keys = {}
	for k in pairs(CONFIG) do table.insert(keys, k) end
	table.sort(keys)
	local out = {}
	for _, k in ipairs(keys) do
		local v = CONFIG[k]
		table.insert(out, k .. " = " .. (type(v) == "table" and table.concat(v, ",") or tostring(v)))
	end
	return table.concat(out, "\n")
end

local function buildHandoff()
	local parts = { AI_CONTEXT, "", "=== CONFIG IN USE ===", configDump(), "", "=== LOG (last 60 lines) ===" }
	for i = math.max(1, #LOG - 59), #LOG do table.insert(parts, LOG[i]) end
	table.insert(parts, "")
	table.insert(parts, "=== PROBE ===")
	table.insert(parts, probe())
	if readfile then
		local ok, src = pcall(readfile, "StorageHunter.lua")
		if ok and type(src) == "string" then
			table.insert(parts, "")
			table.insert(parts, "=== SCRIPT SOURCE (StorageHunter.lua) ===")
			table.insert(parts, src)
		end
	end
	return table.concat(parts, "\n")
end

------------------------------------------------------------------------------
-- UI  (small draggable panel, 2-column buttons, mobile friendly)
------------------------------------------------------------------------------
local function destroyAll()
	alive = false
	for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
	for _, e in pairs(ESP.entries) do destroyEntry(e) end
	pcall(function() espFolder:Destroy() end)
	pcall(function() gui:Destroy() end)
	genv.__SH_TOOLKIT = nil
end
genv.__SH_TOOLKIT = { Destroy = destroyAll }

gui = Instance.new("ScreenGui")
gui.Name = "SHToolkit"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999

local function mount(obj)
	local ok = pcall(function() obj.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
	if not ok or not obj.Parent then
		obj.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end
end
mount(gui)
mount(espFolder)

local FULL_H, MIN_H = 214, 30
local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(230, FULL_H)
frame.Position = UDim2.new(0, 12, 0.2, 0)
frame.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
frame.BorderSizePixel = 0
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundColor3 = Color3.fromRGB(40, 40, 52)
title.BorderSizePixel = 0
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextColor3 = Color3.new(1, 1, 1)
title.Text = "  Storage Hunter"
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 8)

local function smallBtn(text, xOffset)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(26, 22)
	b.Position = UDim2.new(1, xOffset, 0, 4)
	b.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 14
	b.Text = text
	b.Parent = title
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
	return b
end
local closeBtn = smallBtn("X", -30)
local minBtn = smallBtn("-", -60)

local body = Instance.new("Frame")
body.Position = UDim2.fromOffset(0, 34)
body.Size = UDim2.new(1, 0, 0, 114)
body.BackgroundTransparency = 1
body.Parent = frame
local pad = Instance.new("UIPadding", body)
pad.PaddingLeft = UDim.new(0, 4)
pad.PaddingRight = UDim.new(0, 4)
local grid = Instance.new("UIGridLayout", body)
grid.CellSize = UDim2.fromOffset(108, 34)
grid.CellPadding = UDim2.fromOffset(6, 6)
grid.SortOrder = Enum.SortOrder.LayoutOrder

drinkLabel = Instance.new("TextLabel")
drinkLabel.Position = UDim2.new(0, 6, 0, 152)
drinkLabel.Size = UDim2.new(1, -12, 0, 20)
drinkLabel.BackgroundTransparency = 1
drinkLabel.Font = Enum.Font.GothamBold
drinkLabel.TextSize = 13
drinkLabel.TextColor3 = Color3.fromRGB(120, 230, 140)
drinkLabel.TextXAlignment = Enum.TextXAlignment.Left
drinkLabel.Text = "Drink: ..."
drinkLabel.Parent = frame

statusLabel = Instance.new("TextLabel")
statusLabel.Position = UDim2.new(0, 6, 0, 174)
statusLabel.Size = UDim2.new(1, -12, 0, 36)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 12
statusLabel.TextColor3 = Color3.fromRGB(190, 190, 200)
statusLabel.TextWrapped = true
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.Text = "Ready."
statusLabel.Parent = frame

local order = 0
local function makeButton(text, callback)
	order += 1
	local b = Instance.new("TextButton")
	b.LayoutOrder = order
	b.BackgroundColor3 = Color3.fromRGB(48, 48, 62)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 13
	b.TextWrapped = true
	b.Text = text
	b.Parent = body
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	track(b.MouseButton1Click:Connect(function()
		local ok, err = pcall(callback)
		if not ok then log("Button error: " .. tostring(err)) end
	end))
	return b
end

local function paintToggle(btn, label, on)
	btn.Text = label .. (on and ": ON" or ": OFF")
	btn.BackgroundColor3 = on and Color3.fromRGB(40, 120, 70) or Color3.fromRGB(48, 48, 62)
end

local espBtn, drinkBtn
espBtn = makeButton("ESP", function()
	ESP.enabled = not ESP.enabled
	paintToggle(espBtn, "ESP", ESP.enabled)
	refreshESP()
	log("ESP " .. (ESP.enabled and "on" or "off"))
end)
drinkBtn = makeButton("Drink Watch", function()
	Drink.enabled = not Drink.enabled
	paintToggle(drinkBtn, "Drink Watch", Drink.enabled)
	log("Drink watch " .. (Drink.enabled and "on" or "off"))
end)

makeButton("Copy Log", function()
	copyOut(table.concat(LOG, "\n"), "Log")
end)
makeButton("Copy Probe", function()
	task.spawn(function()
		log("Probing, please wait...")
		local ok, res = pcall(probe)
		if ok then copyOut(res, "Probe") else log("Probe error: " .. tostring(res)) end
	end)
end)
makeButton("Copy AI Handoff", function()
	task.spawn(function()
		log("Building handoff, please wait...")
		local ok, res = pcall(buildHandoff)
		if ok then copyOut(res, "Handoff") else log("Handoff error: " .. tostring(res)) end
	end)
end)

paintToggle(espBtn, "ESP", ESP.enabled)
paintToggle(drinkBtn, "Drink Watch", Drink.enabled)

-- minimize / close
local minimized = false
track(minBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	body.Visible = not minimized
	statusLabel.Visible = not minimized
	drinkLabel.Visible = not minimized
	frame.Size = UDim2.fromOffset(230, minimized and MIN_H or FULL_H)
end))
track(closeBtn.MouseButton1Click:Connect(destroyAll))

-- dragging (touch + mouse)
local dragging, dragStart, startPos
track(title.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input.Position
		startPos = frame.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then dragging = false end
		end)
	end
end))
track(UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
		local d = input.Position - dragStart
		frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
	end
end))

------------------------------------------------------------------------------
-- LOOPS
------------------------------------------------------------------------------
task.spawn(function()
	while alive do
		if ESP.enabled then
			local ok, err = pcall(scanOnce)
			if not ok then log("ESP scan error: " .. tostring(err)) end
		end
		local waited = 0
		while alive and waited < CONFIG.ESP_SCAN_INTERVAL do
			task.wait(0.5)
			waited += 0.5
		end
	end
end)

local espAcc = 0
track(RunService.Heartbeat:Connect(function(dt)
	espAcc += dt
	if espAcc < 0.25 then return end
	espAcc = 0
	pcall(refreshESP)
end))

local drinkAcc = 0
track(RunService.Heartbeat:Connect(function(dt)
	drinkAcc += dt
	if drinkAcc < 0.5 then return end
	drinkAcc = 0
	pcall(Drink.tick)
end))

log("Storage Hunter toolkit loaded.")
