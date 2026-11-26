local _, ns = ...
local L = ns.L

-- A swing timer for your wand (Shoot): HunterGod's Auto Shot bar on its own, with the wand's icon
-- on a tag at its left. Forever tells addons when each shot goes and how long the next one takes
-- (PLAYER_SWING, the ranged type), so no combat log is needed. Should it not report the wand, the
-- bar runs from Shoot starting and stopping (START_AUTOREPEAT_SPELL) at your wand's speed. Flat, it
-- starts dim and lights up as the shot comes, and flashes when it goes. It shows while you shoot
-- and a moment after, grey when your target is out of reach
local RANGED = 2 -- Enum.PlayerSwingType.Ranged
local SLOT = 18 -- the ranged slot: your wand
local SHOOT = 5019
local LINGER = 2 -- seconds the bar stays once the last shot is done
local FLASH = 0.18 -- the flash as a shot goes
local SAMPLE_SPEED = 1.6 -- for the sample, when the game doesn't say how fast your wand is
local TEST_SECONDS = 6
local DEFAULT_POINT = { "CENTER", "CENTER", 0, -118 } -- under the shield bar
local THIN_FONT = "Fonts\\ARIALN.TTF"

local db, bar
local swing -- the shot on its way: { start, duration, guessed }
local shooting = false -- Shoot is on
local reported = false -- the game sent a ranged PLAYER_SWING since Shoot began
local inRange -- whether the target is in your wand's reach; nil when nothing says
local lastRangeCheck
local sampleUntil = 0
local wasSampling = false

local function HasWand()
	return GetInventoryItemID("player", SLOT) ~= nil
end

local function Sampling()
	return ns.unlocked or GetTime() < sampleUntil
end

-- How long a shot of your wand takes
local function Speed()
	local speed = UnitRangedDamage and UnitRangedDamage("player")
	if type(speed) ~= "number" or ns.IsSecret(speed) or speed <= 0 then return SAMPLE_SPEED end
	return speed
end

-- Your target within your wand's reach: the game's swing check, else Shoot's own range
local function CheckRange()
	inRange = nil
	if C_SwingTimer and C_SwingTimer.IsTargetWithinSwingRange then
		local ok, within = pcall(C_SwingTimer.IsTargetWithinSwingRange, RANGED)
		if ok and type(within) == "boolean" and not ns.IsSecret(within) then
			inRange = within
			return
		end
	end
	if not UnitExists("target") then return end
	local name = ns.SpellName(SHOOT)
	local check = C_Spell and C_Spell.IsSpellInRange or IsSpellInRange
	local v = name and check and check(name, "target")
	if ns.IsSecret(v) then return end
	if v == true or v == 1 then inRange = true elseif v == false or v == 0 then inRange = false end
end

function ns.StyleWand()
	if not bar then return end
	local px = ns.OnePixel(bar)
	local w, h = db.width, db.height
	local tagWidth = db.icon and h + 3 or 0
	bar:SetSize(tagWidth + w, h)
	bar.tag:ClearAllPoints()
	bar.tag:SetPoint("TOPLEFT")
	bar.tag:SetSize(h, h)
	bar.tag:SetShown(db.icon)
	bar.tagEdge:SetShown(db.icon)
	bar.tagEdge:ClearAllPoints()
	bar.tagEdge:SetPoint("TOPLEFT", bar.tag, -px, px)
	bar.tagEdge:SetPoint("BOTTOMRIGHT", bar.tag, px, -px)
	bar.tag:SetTexture(GetInventoryItemTexture and GetInventoryItemTexture("player", SLOT) or ns.SpellIcon(SHOOT))
	bar.back:ClearAllPoints()
	bar.back:SetPoint("TOPRIGHT")
	bar.back:SetSize(w, h)
	bar.edge:ClearAllPoints()
	bar.edge:SetPoint("TOPLEFT", bar.back, -px, px)
	bar.edge:SetPoint("BOTTOMRIGHT", bar.back, px, -px)
	bar.shine:SetHeight(px)
	ns.UseFont(bar.time, THIN_FONT, max(floor(h * 0.85), 9), "")
	bar.time:SetShadowOffset(1, -1)
	bar.time:SetShadowColor(0, 0, 0, 1)
	bar.time:SetTextColor(1, 1, 1)
	bar.time:SetShown(db.time)
	ns.UpdateWand()
end

-- Paints the bar at this moment: how far the shot has come, lit up as it nears the end
local function Paint(now)
	local w = db.width
	local p, left = 1, 0
	if swing and swing.duration > 0 then
		p = min(max((now - swing.start) / swing.duration, 0), 1)
		left = max(swing.start + swing.duration - now, 0)
	end
	local c = db.color
	local r, g, b = c.r, c.g, c.b
	local away = inRange == false and not Sampling()
	if away then r, g, b = 0.5, 0.5, 0.48 end
	local k = 0.45 + 0.55 * p * p
	bar.fill:SetColorTexture(r * k, g * k, b * k, 1)
	bar.fill:SetWidth(max(w * p, 0.01))
	bar.fill:SetShown(p > 0)
	bar.shine:SetShown(p > 0)
	bar:SetAlpha(away and 0.55 or 1)
	local since = swing and now - swing.start or FLASH
	bar.flash:SetAlpha(since < FLASH and 0.55 * (1 - since / FLASH) or 0)
	bar.time:SetText(left > 0 and format("%.1f", left) or "")
	bar.away = away
end

function ns.UpdateWand()
	if not bar then return end
	local now = GetTime()
	local sampling = Sampling()
	-- The sample's shots aren't yours: they go with it
	if wasSampling and not sampling then swing = nil end
	wasSampling = sampling
	local on = db.enabled and ns.IsWarlock()
	if sampling then
		on = on and (ns.unlocked or HasWand())
		if on and (not swing or now >= swing.start + swing.duration) then
			swing = { start = now, duration = Speed() }
		end
	else
		-- Your reach, looked at again now and then while the bar may show
		if swing and now - (lastRangeCheck or 0) >= 0.2 then
			lastRangeCheck = now
			CheckRange()
		end
		-- Shoot on and the game silent about the wand: the next shot follows the last one
		if shooting and not reported and swing and now >= swing.start + swing.duration then
			swing = { start = swing.start + swing.duration, duration = Speed(), guessed = true }
		end
		on = on and HasWand() and swing ~= nil and (shooting or now < swing.start + swing.duration + LINGER)
	end
	if on then
		Paint(now)
		bar:Show()
	else
		bar:Hide()
	end
end

-- A shot just went: the next one comes in this long
local function Shot(duration, swingType)
	if ns.IsSecret(duration) or ns.IsSecret(swingType) or swingType ~= RANGED then return end
	if type(duration) ~= "number" or duration <= 0 or duration ~= duration or duration == math.huge then return end
	reported = true
	swing = { start = GetTime(), duration = duration }
	ns.UpdateWand()
end
ns.WandSwing = Shot -- for the tests

-- /warlockgod wand, and the options' button: the bar shooting for a few seconds
function ns.TestWand()
	sampleUntil = GetTime() + TEST_SECONDS
	swing = nil
	ns.UpdateWand()
	C_Timer.After(TEST_SECONDS + 0.1, function()
		swing = nil
		ns.UpdateWand()
	end)
end
ns.commands.wand = ns.TestWand
ns.commands.varita = ns.TestWand

-- For the tests
function ns.WandState()
	return { bar = bar, swing = swing, shooting = shooting, inRange = inRange }
end

local events = CreateFrame("Frame")
-- Events this client may not have: registering one it doesn't know would stop the file here
local function Listen(event)
	pcall(events.RegisterEvent, events, event)
end

events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, ...)
	if event == "PLAYER_LOGIN" then
		self:UnregisterEvent("PLAYER_LOGIN")
		db = ns.db.wand
		bar = CreateFrame("Frame", "WarlockGodWand", UIParent)
		bar:SetFrameStrata("MEDIUM")
		bar.tagEdge = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
		bar.tagEdge:SetColorTexture(0, 0, 0, 1)
		bar.tag = bar:CreateTexture(nil, "ARTWORK")
		bar.tag:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		bar.edge = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
		bar.edge:SetColorTexture(0, 0, 0, 1)
		bar.back = bar:CreateTexture(nil, "BACKGROUND")
		bar.back:SetColorTexture(0.04, 0.03, 0.08, 0.85)
		bar.fill = bar:CreateTexture(nil, "BORDER")
		bar.fill:SetPoint("TOPLEFT", bar.back)
		bar.fill:SetPoint("BOTTOMLEFT", bar.back)
		-- A thread of light along the top of what's filled
		bar.shine = bar:CreateTexture(nil, "ARTWORK")
		bar.shine:SetColorTexture(1, 1, 1, 0.14)
		bar.shine:SetPoint("TOPLEFT", bar.fill)
		bar.shine:SetPoint("TOPRIGHT", bar.fill)
		bar.flash = bar:CreateTexture(nil, "OVERLAY")
		bar.flash:SetColorTexture(1, 1, 1, 1)
		bar.flash:SetAllPoints(bar.back)
		bar.flash:SetAlpha(0)
		bar.time = bar:CreateFontString(nil, "OVERLAY")
		bar.time:SetPoint("RIGHT", bar.back, "RIGHT", -4, 0)
		bar:SetScript("OnUpdate", function()
			if Sampling() or swing then ns.UpdateWand() end
		end)
		bar:Hide()
		ns.Movable(bar, "wand", DEFAULT_POINT, L.WAND_NAME)
		table.insert(ns.refreshers, ns.StyleWand)
		Listen("PLAYER_SWING")
		Listen("PLAYER_SWING_RANGE_UPDATE")
		Listen("START_AUTOREPEAT_SPELL")
		Listen("STOP_AUTOREPEAT_SPELL")
		Listen("PLAYER_TARGET_CHANGED")
		Listen("PLAYER_EQUIPMENT_CHANGED")
		Listen("UI_SCALE_CHANGED")
		Listen("DISPLAY_SIZE_CHANGED")
		if C_SwingTimer and C_SwingTimer.EnableRangeCheck then pcall(C_SwingTimer.EnableRangeCheck, RANGED, true) end
		ns.StyleWand()
	elseif event == "PLAYER_SWING" then
		Shot(...)
	elseif event == "START_AUTOREPEAT_SPELL" then
		shooting, reported = true, false
		CheckRange()
		-- Until the game says, the first shot goes now
		if not swing or GetTime() >= swing.start + swing.duration then
			swing = { start = GetTime(), duration = Speed(), guessed = true }
		end
		ns.UpdateWand()
	elseif event == "STOP_AUTOREPEAT_SPELL" then
		shooting = false
		ns.UpdateWand()
	elseif event == "PLAYER_SWING_RANGE_UPDATE" then
		local swingType, within, checks = ...
		if ns.IsSecret(swingType) or ns.IsSecret(within) or ns.IsSecret(checks) or swingType ~= RANGED then return end
		if checks then inRange = within and true or false else inRange = nil end
		ns.UpdateWand()
	elseif event == "PLAYER_TARGET_CHANGED" then
		CheckRange()
		ns.UpdateWand()
	elseif event == "PLAYER_EQUIPMENT_CHANGED" then
		-- Another wand: its icon, and no shot left from the one before
		if not HasWand() then swing = nil end
		ns.StyleWand()
	elseif event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
		ns.StyleWand()
	end
end)
