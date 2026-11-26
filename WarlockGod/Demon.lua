local _, ns = ...
local L = ns.L

-- Your demon: a reminder when you have none out (a click summons the one you use), one for Soul
-- Link when you know it and it isn't on, and a call to heal the demon when its health drops
local SUMMONS = {
	imp = 688, voidwalker = 697, succubus = 712, incubus = 713, felhunter = 691,
}
-- When you haven't summoned one yet: the last you learned (Felhunter at 30, Succubus and Incubus
-- at 20, Voidwalker at 10, the Imp at 1)
local SUMMON_ORDER = { "felhunter", "succubus", "incubus", "voidwalker", "imp" }
ns.SUMMONS, ns.SUMMON_ORDER = SUMMONS, { "imp", "voidwalker", "succubus", "incubus", "felhunter" }
-- Demonic Sacrifice: a demon given up for one of these, for two hours. Then you want no demon
local SACRIFICE_BUFFS = { 18789, 18790, 18791, 18792 } -- Burning Shadow, Fel Stamina, Touch of Fire, Fel Energy
-- Forever's Demonic Pact talent keeps the sacrifice's buff when you summon another demon: then you
-- want both
local DEMONIC_PACT = 425464
local SOUL_LINK = 19028
local SOUL_LINK_BUFF = 25228
local HEALTH_FUNNEL = 755

local db
local known = {}
local summonNames = {} -- spell name -> demon
local sacrificeNames = {}
local soulLinkNames = {}
-- From your buffs when the game shows them: true / false, nil before the addon has seen them
local sacrificed, linked
local frames = {}

local function Learn()
	wipe(summonNames)
	wipe(sacrificeNames)
	wipe(soulLinkNames)
	for key, id in pairs(SUMMONS) do
		known[key] = ns.Knows({ id })
		local name = ns.SpellName(id)
		if name then summonNames[name] = key end
	end
	for _, id in ipairs(SACRIFICE_BUFFS) do
		local name = ns.SpellName(id)
		if name then sacrificeNames[name] = true end
	end
	for _, id in ipairs({ SOUL_LINK, SOUL_LINK_BUFF }) do
		local name = ns.SpellName(id)
		if name then soulLinkNames[name] = true end
	end
	known.soulLink = ns.Knows({ SOUL_LINK })
	known.pact = ns.Knows({ DEMONIC_PACT })
end

local function Scan()
	local buffs = ns.ReadBuffs()
	if not buffs then return end
	sacrificed, linked = false, false
	for name in pairs(buffs) do
		if sacrificeNames[name] then sacrificed = true end
		if soulLinkNames[name] then linked = true end
	end
end

-- A demon of yours out, and alive
local function HasDemon()
	local exists, dead = UnitExists("pet"), UnitIsDead("pet")
	if ns.IsSecret(exists) then return true end
	if ns.IsSecret(dead) then dead = false end
	return exists and not dead
end
ns.HasDemon = HasDemon

-- The demon to summon: the one you chose, the last one you summoned, or the last you learned
local function WantedDemon()
	if db.choice ~= "auto" and known[db.choice] then return db.choice end
	local last = ns.db.lastDemon
	if last and known[last] then return last end
	for _, key in ipairs(SUMMON_ORDER) do
		if known[key] then return key end
	end
end
ns.WantedDemon = function() return WantedDemon() end

local function Mounted()
	local mounted = IsMounted and IsMounted()
	if ns.IsSecret(mounted) then return false end
	return mounted
end

local current = {}

local function DemonState()
	local want = WantedDemon()
	if not want or HasDemon() or (sacrificed and not known.pact) or Mounted() then return end
	local id = SUMMONS[want]
	return { icon = ns.SpellIcon(id), grey = true, spell = ns.SpellName(id), hint = L.CLICK_SUMMON }
end

local function SoulLinkState()
	if not known.soulLink or linked ~= false or not HasDemon() or InCombatLockdown() then return end
	return { icon = ns.SpellIcon(SOUL_LINK), grey = true, spell = ns.SpellName(SOUL_LINK) }
end

local STATES = {
	{ key = "demon", order = 10, get = DemonState, on = function() return db.missing end },
	{ key = "soulLink", order = 20, get = SoulLinkState, on = function() return db.soulLink end },
}
local SAMPLES = {
	demon = function() return { icon = ns.SpellIcon(SUMMONS.voidwalker), grey = true } end,
	soulLink = function() return { icon = ns.SpellIcon(SOUL_LINK), grey = true } end,
}

function ns.UpdateDemon()
	local warlock = ns.IsWarlock() and not ns.Dead()
	for _, s in ipairs(STATES) do
		local r
		if ns.unlocked then
			r = ns.IsWarlock() and s.on() and SAMPLES[s.key]()
		elseif warlock and s.on() then
			r = s.get()
		end
		current[s.key] = r or nil
		if r then ns.ShowReminder(frames[s.key], r.icon, r.grey, r.text) else frames[s.key]:Hide() end
	end
	if ns.SyncReminders then ns.SyncReminders() end
	ns.UpdateDemonHealth()
end

local function Action(key)
	return function()
		local r = current[key]
		if r and r.spell then return { spell = r.spell, hint = r.hint } end
	end
end

local function Tooltip(key)
	return function(tip)
		local r = current[key]
		if r and r.spell then tip:AddLine(r.spell, 1, 1, 1) end
		if key == "demon" then tip:AddLine(L.DEMON_MISSING, 0.8, 0.8, 0.8, true) end
	end
end

for _, s in ipairs(STATES) do
	local frame = CreateFrame("Frame", "WarlockGodReminder" .. s.key, UIParent)
	ns.StyleReminder(frame)
	frames[s.key] = frame
	ns.AddReminder(s.key, s.order, frame, Action(s.key), Tooltip(s.key))
end

-- HEAL YOUR DEMON! over the middle of the screen when its health drops. Forever hides the demon's
-- health from addons, but lets them hand it on to the game: its percentage through a curve
-- becomes the warning's opacity (1 under the line, 0 from it up) and the number in its text,
-- without the addon ever reading it (as HunterGod does for the pet)
local hurt
local underLine, lineAt, toHundred
local function HealthCurves()
	if not (C_CurveUtil and C_CurveUtil.CreateCurve and UnitHealthPercent) then return end
	local line = db.healthPct / 100
	if lineAt ~= line then
		underLine = underLine or C_CurveUtil.CreateCurve()
		if underLine.ClearPoints then underLine:ClearPoints() end
		if Enum and Enum.LuaCurveType then underLine:SetType(Enum.LuaCurveType.Linear) end
		-- A sheer drop at the line, so nothing in between
		underLine:AddPoint(0, 1)
		underLine:AddPoint(max(line - 0.001, 0.0005), 1)
		underLine:AddPoint(line, 0)
		underLine:AddPoint(1, 0)
		lineAt = line
	end
	if not toHundred then
		toHundred = C_CurveUtil.CreateCurve()
		if Enum and Enum.LuaCurveType then toHundred:SetType(Enum.LuaCurveType.Linear) end
		toHundred:AddPoint(0, 0)
		toHundred:AddPoint(1, 100)
	end
	return underLine, toHundred
end

local function Blink(frame, on)
	if on then
		if not frame:IsShown() then
			frame:Show()
			frame.blink:Play()
		end
	elseif frame:IsShown() then
		frame.blink:Stop()
		frame:Hide()
	end
end

-- Its width from a sample on a font string of its own: once the real one has shown a hidden
-- number, its size may be hidden too
local function SizeHurt()
	ns.FancyFont(hurt.text, 24, "THICKOUTLINE")
	ns.FancyFont(hurt.measure, 24, "THICKOUTLINE")
	hurt.measure:SetText(format(L.DEMON_HEALTH, 100))
	hurt:SetWidth((hurt.measure:GetStringWidth() or 200) + 44)
end

function ns.UpdateDemonHealth()
	if not hurt or not db then return end
	local percent, hidden
	if ns.unlocked and db.health and ns.IsWarlock() then
		percent = 25
	elseif db.health and ns.IsWarlock() and HasDemon() then
		local health, maxHealth = UnitHealth("pet"), UnitHealthMax("pet")
		if ns.IsSecret(health) or ns.IsSecret(maxHealth) then
			hidden = HealthCurves() ~= nil
		elseif maxHealth and maxHealth > 0 then
			percent = floor(health / maxHealth * 100 + 0.5)
			if percent >= db.healthPct then percent = nil end
		end
	end
	SizeHurt()
	if hidden then
		-- Always there and blinking, seen only while the demon is under the line
		local line, hundred = HealthCurves()
		hurt:SetAlpha(UnitHealthPercent("pet", false, line))
		hurt.text:SetFormattedText(L.DEMON_HEALTH, UnitHealthPercent("pet", false, hundred))
		Blink(hurt, true)
		return
	end
	hurt:SetAlpha(1)
	if percent then hurt.text:SetText(format(L.DEMON_HEALTH, percent)) end
	Blink(hurt, percent ~= nil)
end

hurt = CreateFrame("Frame", "WarlockGodDemonHealth", UIParent)
hurt:SetSize(220, 36)
hurt:Hide()
-- What blinks goes on a frame inside: the outer one may take its opacity from the demon's health
hurt.body = CreateFrame("Frame", nil, hurt)
hurt.body:SetAllPoints()
hurt.icon = hurt.body:CreateTexture(nil, "ARTWORK")
hurt.icon:SetSize(32, 32)
hurt.icon:SetPoint("LEFT")
hurt.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
hurt.text = hurt.body:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
hurt.text:SetPoint("LEFT", hurt.icon, "RIGHT", 8, 0)
hurt.text:SetTextColor(0.75, 0.45, 1)
hurt.measure = hurt:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
hurt.measure:Hide()
hurt.body.blink = hurt.body:CreateAnimationGroup()
hurt.body.blink:SetLooping("BOUNCE")
local fade = hurt.body.blink:CreateAnimation("Alpha")
fade:SetFromAlpha(1)
fade:SetToAlpha(0.45)
fade:SetDuration(0.6)
hurt.blink = hurt.body.blink

-- For the tests
function ns.DemonState()
	return { frames = frames, current = current, hurt = hurt, sacrificed = sacrificed, linked = linked }
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, unit, _, spellID)
	if event == "PLAYER_LOGIN" then
		db = ns.db.demon
		Learn()
		Scan()
		hurt.icon:SetTexture(ns.SpellIcon(HEALTH_FUNNEL))
		ns.Movable(hurt, "demonHealth", { "CENTER", "CENTER", 0, 30 }, L.DEMON_HEALTH_NAME)
		table.insert(ns.refreshers, ns.UpdateDemon)
		self:RegisterUnitEvent("UNIT_AURA", "player")
		self:RegisterUnitEvent("UNIT_PET", "player")
		self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
		self:RegisterUnitEvent("UNIT_HEALTH", "pet")
		self:RegisterUnitEvent("UNIT_MAXHEALTH", "pet")
		self:RegisterEvent("SPELLS_CHANGED")
		self:RegisterEvent("PLAYER_REGEN_DISABLED")
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		self:RegisterEvent("PLAYER_DEAD")
		self:RegisterEvent("PLAYER_ALIVE")
		self:RegisterEvent("PLAYER_UNGHOST")
		pcall(self.RegisterEvent, self, "PLAYER_MOUNT_DISPLAY_CHANGED")
		pcall(self.RegisterEvent, self, "PET_BAR_UPDATE")
		-- Mounting and a demon that dies don't always say so: a look every second as well
		C_Timer.NewTicker(1, ns.UpdateDemon)
	elseif event == "UNIT_AURA" or event == "PLAYER_REGEN_ENABLED" then
		Scan()
	elseif event == "SPELLS_CHANGED" then
		Learn()
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		if unit ~= "player" or not spellID or ns.IsSecret(spellID) then return end
		local key = summonNames[ns.SpellName(spellID) or ""]
		if not key then return end
		ns.db.lastDemon = key
	elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
		ns.UpdateDemonHealth()
		return
	end
	ns.UpdateDemon()
end)
