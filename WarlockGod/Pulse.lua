local _, ns = ...
local L = ns.L

-- When one of your big cooldowns is back: its icon big in the middle of the screen, fading fast,
-- as MageGod's Blink. In combat Forever hides how long a cooldown has left, but not whether it is
-- running (C_Spell.GetSpellCooldown(id).isActive): the pulse comes when the spell goes from cooling
-- down to ready, not for the global cooldown. Only the spells you know, each with its own switch.
-- Two back at once play one after the other
local WATCH = {
	{ key = "deathCoil", spells = { 6789, 17925, 17926 } }, -- 2 min
	{ key = "howl", spells = { 5484, 17928 } }, -- Howl of Terror, 40 s
	{ key = "felDomination", spells = { 18708 } }, -- 5 min (talent)
	{ key = "amplifyCurse", spells = { 18288 } }, -- 3 min (talent)
	{ key = "soulFire", spells = { 6353, 17924 } }, -- 1 min (6 s with Decimation)
	{ key = "baneOfDoom", spells = { 603 } }, -- 1 min
	{ key = "shadowWard", spells = { 6229, 11739, 11740, 28610 } }, -- 30 s
	{ key = "inferno", spells = { 1122 } }, -- 1 hour
	{ key = "ritualOfDoom", spells = { 18540 } }, -- 1 hour
	-- The Soulstone's half hour is the stone's, an item's cooldown: when you can use one again
	{ key = "soulstone", items = { 5232, 16892, 16893, 16895, 16896 }, need = { 693, 20752, 20755, 20756, 20757 },
		casts = { 20707, 20762, 20763, 20764, 20765 } },
}
ns.PULSE_WATCH = WATCH
local DEFAULT_POINT = { "CENTER", "CENTER", 0, 80 }
local GCD_MAX = 2.5 -- no global cooldown lasts this long: a longer wait was the spell's own
local POLL = 0.1
-- The pulse: it pops in, holds, and fades while it grows
local POP, HOLD, FADE = 0.12, 0.3, 0.55
local SHINE = 0.5
local STAR = "Interface\\Cooldown\\star4"

local db
local place, art
local playing -- when the pulse started
local queue = {} -- icons waiting for their turn
local byKey = {}
for _, w in ipairs(WATCH) do byKey[w.key] = w end

-- The rank you know, or nil
local function Resolve(w)
	if w.items then
		return ns.Knows(w.need) and w.items[1] or nil
	end
	for _, id in ipairs(w.spells) do
		local known = IsPlayerSpell and IsPlayerSpell(id)
		if known and not ns.IsSecret(known) then return id end
	end
	-- Forever may give it another number: the spellbook answers for its name
	local name = ns.SpellName(w.spells[1])
	local info = name and C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(name)
	if type(info) == "table" and not ns.IsSecret(info) then
		local id = info.spellID
		if id and not ns.IsSecret(id) then return id end
	end
end

local function Icon(w)
	if w.items then return ns.ItemIcon(w.items[1]) end
	return ns.SpellIcon(w.known or w.spells[1])
end

-- Is it cooling down? nil when the game won't say. For a spell, also what the game said
local function Cooling(w)
	if w.items then
		local get = C_Container and C_Container.GetItemCooldown or GetItemCooldown
		if not get then return nil end
		local any = false
		for _, item in ipairs(w.items) do
			local start, duration = get(item)
			if ns.IsSecret(start) or ns.IsSecret(duration) then return nil end
			-- An item's own cooldown is long: the global one never shows on it
			if start and start > 0 and duration and duration > GCD_MAX and start + duration > GetTime() then any = true end
		end
		return any, { duration = any and 60 or 0 }
	end
	local info = C_Spell.GetSpellCooldown(w.known)
	if type(info) ~= "table" or ns.IsSecret(info) then return nil end
	local active = info.isActive
	if active == nil or ns.IsSecret(active) then
		local duration = info.duration
		if duration == nil or ns.IsSecret(duration) then return nil end
		active = duration > 0
	end
	return active and true or false, info
end

-- Is the global cooldown running? nil when the game won't say. While it runs, any spell shows as
-- cooling down: that alone says nothing about its own cooldown (as MageGod 1.5.1)
local GCD_SPELL = 61304
local function GlobalRunning()
	local info = C_Spell.GetSpellCooldown(GCD_SPELL)
	if type(info) ~= "table" or ns.IsSecret(info) then return nil end
	local active = info.isActive
	if active == nil or ns.IsSecret(active) then
		local duration = info.duration
		if duration == nil or ns.IsSecret(duration) then return nil end
		active = duration > 0
	end
	return active and true or false
end

-- Is that its own cooldown and not the global one? nil when the game won't say
local function Own(w, info)
	local duration = info.duration
	if duration and not ns.IsSecret(duration) then return duration > 1.6 end
	local gcd = info.isOnGCD
	if gcd ~= nil and not ns.IsSecret(gcd) then return not gcd end
	if not w.items and C_Spell.GetSpellCooldownDuration then
		local timer = C_Spell.GetSpellCooldownDuration(w.known, true)
		local zero = timer and timer.IsZero and timer:IsZero()
		-- While the global one runs this may count it too: it can't tell then
		if zero ~= nil and not ns.IsSecret(zero) then
			if not zero and GlobalRunning() ~= false then return nil end
			return not zero
		end
	end
end

local function Draw(parent)
	local a = {}
	a.shine = parent:CreateTexture(nil, "BACKGROUND")
	a.shine:SetPoint("CENTER")
	a.shine:SetTexture(STAR)
	a.shine:SetBlendMode("ADD")
	a.shine:SetAlpha(0)
	a.box = CreateFrame("Frame", nil, parent)
	a.box:SetPoint("CENTER")
	a.edge = a.box:CreateTexture(nil, "BACKGROUND")
	a.edge:SetColorTexture(0, 0, 0, 1)
	a.icon = a.box:CreateTexture(nil, "ARTWORK")
	a.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	a.edge:SetAllPoints(a.box)
	return a
end

-- How it looks t seconds in: its alpha, its size, and the shine's
local function Frame(t)
	local alpha, scale
	if t < POP then
		alpha, scale = t / POP, 0.6 + 0.4 * t / POP
	elseif t < POP + HOLD then
		alpha, scale = 1, 1
	else
		local f = min((t - POP - HOLD) / FADE, 1)
		alpha, scale = 1 - f, 1 + 0.3 * f
	end
	local shine = t < SHINE and (1 - t / SHINE) * 0.9 or 0
	return alpha, scale, shine, 0.8 + 1.2 * min(t / SHINE, 1)
end

local function Paint(alpha, scale, shine, shineScale)
	local size = db.size
	art.box:SetAlpha(alpha * db.alpha / 100)
	art.box:SetSize(size * scale, size * scale)
	local px = ns.OnePixel(place)
	art.icon:ClearAllPoints()
	art.icon:SetPoint("TOPLEFT", art.box, "TOPLEFT", px, -px)
	art.icon:SetPoint("BOTTOMRIGHT", art.box, "BOTTOMRIGHT", -px, px)
	art.shine:SetAlpha(shine * db.alpha / 100)
	art.shine:SetSize(size * 1.6 * shineScale, size * 1.6 * shineScale)
end

-- While unlocked it stays up to be dragged
local function Rest()
	if playing then return end
	place:SetSize(db.size, db.size)
	if ns.unlocked and db.enabled and ns.IsWarlock() then
		art.icon:SetTexture(Icon(WATCH[1]))
		place:Show()
		Paint(1, 1, 0, 1)
	else
		place:Hide()
	end
end

local function Start(icon)
	art.icon:SetTexture(icon)
	art.shine:SetVertexColor(db.color.r, db.color.g, db.color.b)
	playing = GetTime()
	place:SetSize(db.size, db.size)
	place:Show()
	Paint(Frame(0))
end

local function Animate()
	local t = GetTime() - playing
	if t >= POP + HOLD + FADE then
		playing = nil
		-- The next one waiting, if any
		local icon = table.remove(queue, 1)
		if icon then Start(icon) else Rest() end
		return
	end
	Paint(Frame(t))
end

-- A cooldown back: its pulse now, or after the one playing
function ns.Pulse(icon)
	if playing then
		queue[#queue + 1] = icon
		return
	end
	Start(icon)
end

function ns.StylePulse()
	if not place then return end
	art.shine:SetVertexColor(db.color.r, db.color.g, db.color.b)
	Rest()
end

-- Checks whether it is back
local function Check(w)
	if not w.known then return end
	local now = GetTime()
	local cooling, info = Cooling(w)
	if cooling == nil then
		w.blind = w.blind or now
		return
	end
	-- After a stretch where the game wouldn't say, what it says now may be old news
	local stale = w.blind and now - w.blind > 1
	w.blind = nil
	if cooling then
		local own = not w.own and Own(w, info)
		if own then w.own, w.real = true, true end
		-- Only the global cooldown, as the game says: its time doesn't count. Spells cast one after
		-- another chain them for longer than any one, and that isn't the spell's own coming back.
		-- In combat it may not say whose it is: while the global one runs, the wait doesn't start
		local global = not w.own and own == nil and GlobalRunning()
		if w.own then
			w.since = w.since or now
			w.real = true
		elseif own == false or global and not w.real then
			w.since = now -- the global one, or maybe: its wait starts afresh
		else
			w.since = w.since or now
			if global == false then w.real = true end -- the global one is over and it still cools down
		end
	elseif w.since then
		if not stale and (w.own or now - w.since > GCD_MAX) and db.enabled and db.spells[w.key] and ns.IsWarlock()
			and not ns.Dead() then
			ns.Pulse(Icon(w))
		end
		w.since, w.own, w.real = nil, false, nil
	elseif w.own and w.castAt and now - w.castAt > 1 then
		w.own, w.real = false, nil -- the cast never showed a cooldown
	end
end

local function Busy()
	for _, w in ipairs(WATCH) do
		if w.since or w.own then return true end
	end
	return false
end

-- Watched often only while one is cooling down, or just cast
local poller = CreateFrame("Frame")
poller:Hide()
local waited = 0
poller:SetScript("OnUpdate", function(self, elapsed)
	waited = waited + elapsed
	if waited < POLL then return end
	waited = 0
	for _, w in ipairs(WATCH) do Check(w) end
	if not Busy() then self:Hide() end
end)

local function Watch()
	for _, w in ipairs(WATCH) do Check(w) end
	if Busy() then poller:Show() end
end

local function Learn()
	for _, w in ipairs(WATCH) do
		w.known = Resolve(w)
		w.names = {}
		for _, id in ipairs(w.casts or w.spells) do
			local name = ns.SpellName(id)
			if name then w.names[name] = true end
		end
	end
end

-- /warlockgod cooldowns: shows the pulse
local function Test()
	if not ns.IsWarlock() then return end
	ns.Pulse(Icon(WATCH[1]))
end
ns.commands.cooldowns = Test
ns.commands.pulso = Test
ns.PulseTest = Test

-- For the tests
function ns.PulseState(key)
	local w = key and byKey[key]
	return { place = place, art = art, queue = queue, poller = poller, known = w and w.known, since = w and w.since,
		own = w and w.own }
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, unit, _, spellID)
	if event == "PLAYER_LOGIN" then
		self:UnregisterEvent("PLAYER_LOGIN") -- built once
		db = ns.db.pulse
		place = CreateFrame("Frame", "WarlockGodPulse", UIParent)
		place:SetFrameStrata("HIGH")
		place:SetSize(db.size, db.size)
		place:Hide()
		art = Draw(place)
		place:SetScript("OnUpdate", function()
			if playing then Animate() end
		end)
		ns.Movable(place, "pulse", DEFAULT_POINT, L.PULSE_NAME)
		table.insert(ns.refreshers, ns.StylePulse)
		Learn()
		self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
		self:RegisterEvent("SPELLS_CHANGED")
		self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
		pcall(self.RegisterEvent, self, "BAG_UPDATE_COOLDOWN")
		ns.StylePulse()
		Watch()
	elseif event == "SPELLS_CHANGED" then
		Learn()
		Watch()
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		if unit ~= "player" or not spellID or ns.IsSecret(spellID) then return end
		local name = ns.SpellName(spellID)
		if not name or ns.IsSecret(name) then return end
		for _, w in ipairs(WATCH) do
			if w.known and w.names[name] then w.own, w.castAt = true, GetTime() end
		end
		Watch()
	else
		Watch()
	end
end)
