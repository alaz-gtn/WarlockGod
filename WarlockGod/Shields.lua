local _, ns = ...
local L = ns.L

-- What's left of any shield on you, each in its own colour: your Shadow Ward, the shield your
-- Voidwalker's Sacrifice gives you, a priest's Power Word: Shield, a protection potion, and the
-- rest of the family's (a mage's barriers and wards), as MageGod's bar. Forever hides how much a
-- shield absorbs, but lets the addon hand it to a bar and its text, which the game fills in itself.
-- The bar starts full at what the shield absorbs as it goes on, and goes when it ends. The game
-- only gives the total of every shield on you: with two at once the bar shows both, in the colour
-- of the last one
local SHIELDS = {
	{ key = "ward", ids = { 6229, 11739, 11740, 28610 }, seconds = 30 }, -- Shadow Ward: Shadow damage only
	-- The Voidwalker casts it: its own spell, the shield on you
	{ key = "sacrifice", ids = { 7812, 19438, 19440, 19441, 19442, 19443 }, seconds = 30 },
	-- MageGod's table, the same for every class: a mage's, a priest's and the potions
	{ key = "barrier", ids = { 11426, 13031, 13032, 13033 }, seconds = 60 }, -- Ice Barrier
	{ key = "manaShield", ids = { 1463, 8494, 8495, 10191, 10192, 10193 }, seconds = 60 },
	{ key = "fireWard", ids = { 543, 8457, 8458, 10223, 10225 }, seconds = 30 },
	{ key = "frostWard", ids = { 6143, 8461, 8462, 10177, 28609 }, seconds = 30 },
	-- Cast on you by a priest: the bar only sees it when the game lets it read your shields
	{ key = "powerWord", ids = { 17, 592, 600, 3747, 6065, 6066, 10898, 10899, 10900, 10901 }, seconds = 30 },
	-- The protection potions, two minutes each: by their numbers only, as other buffs share their
	-- names (a priest's Shadow Protection)
	{ key = "fire", ids = { 7233, 17543 }, seconds = 120, potion = true },
	{ key = "frost", ids = { 7239, 17544 }, seconds = 120, potion = true },
	{ key = "nature", ids = { 7254, 17546 }, seconds = 120, potion = true },
	{ key = "shadow", ids = { 7242, 17548 }, seconds = 120, potion = true },
	{ key = "arcane", ids = { 17549 }, seconds = 120, potion = true },
	{ key = "holy", ids = { 7245, 17545 }, seconds = 120, potion = true },
}
ns.SHIELDS = SHIELDS
local SHADOW_WARD = 6229
local BARRIER_TIME = 30 -- a shield the addon can't tell: half a minute until the game says otherwise
local shieldById, shieldByName = {}, {}
for _, shield in ipairs(SHIELDS) do
	for _, id in ipairs(shield.ids) do shieldById[id] = shield end
end
local ThinFont = ns.ThinFont
local barrier
local barrierEnds = 0 -- GetTime() when the shield runs out
local barrierFull -- what it absorbed at the start: may be hidden
local current -- the shield the bar shows: its colour

local function Absorbs()
	return UnitGetTotalAbsorbs and UnitGetTotalAbsorbs("player")
end

local function Learn()
	wipe(shieldByName)
	for _, shield in ipairs(SHIELDS) do
		local name = not shield.potion and ns.SpellName(shield.ids[1])
		if name then shieldByName[name] = shield end
	end
end

-- Its colour: Shadow Ward's is the bar's own, the others each their own (the potions their school's)
local function ShieldColor(shield)
	local o = ns.db.barrier
	return shield and shield.key ~= "ward" and o.colors[shield.key] or o.color
end

local function Paint()
	local c = ShieldColor(current)
	barrier.status:SetStatusBarColor(c.r, c.g, c.b)
end

-- How long the shield has left, from your buffs when the game shows them
local function Left(name)
	if ns.AurasHidden() or not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return end
	for i = 1, 40 do
		local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
		if not aura or ns.IsSecret(aura) or ns.IsSecret(aura.name) then return end
		if aura.name == name then
			local expires = aura.expirationTime
			if type(expires) == "number" and not ns.IsSecret(expires) and expires > 0 then return expires - GetTime() end
			return
		end
	end
end

local function Start(id, name, shield)
	local amount = Absorbs()
	if not ns.IsSecret(amount) and amount == nil then return end
	current = shield
	barrierFull = amount
	barrierEnds = GetTime() + (Left(name) or shield.seconds)
	barrier.icon:SetTexture(ns.SpellIcon(id))
	barrier.status:SetMinMaxValues(0, amount)
	Paint()
	ns.UpdateBarrier()
end

-- A shield cast (by you or your Voidwalker) or a potion drunk: the bar starts a moment later, once
-- the game has put it on you
local function Cast(spellID)
	local name = ns.SpellName(spellID)
	local shield = shieldById[spellID] or name and shieldByName[name]
	if not shield or shield.potion and not ns.db.barrier.potions then return end
	C_Timer.After(0.2, function() Start(spellID, name, shield) end)
end

-- A shield the addon didn't see go on (a priest's): which one, when the game shows your buffs.
-- false: only a potion you chose to leave out
local function Identify()
	if ns.AurasHidden() or not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return end
	for i = 1, 40 do
		local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
		if not aura or ns.IsSecret(aura) or ns.IsSecret(aura.name) or ns.IsSecret(aura.spellId) then return end
		local shield = shieldById[aura.spellId] or shieldByName[aura.name]
		if shield and shield.potion and not ns.db.barrier.potions then return false end
		if shield then
			current = shield
			barrier.icon:SetTexture(ns.SpellIcon(aura.spellId or shield.ids[1]))
			local expires = aura.expirationTime
			if type(expires) == "number" and not ns.IsSecret(expires) and expires > 0 then
				barrierEnds = expires
			end
			Paint()
			return shield
		end
	end
end

function ns.StyleBarrier()
	local o = ns.db.barrier
	barrier:SetSize(o.width, o.height)
	local px = ns.OnePixel(barrier)
	barrier.edge:ClearAllPoints()
	barrier.edge:SetPoint("TOPLEFT", -px, px)
	barrier.edge:SetPoint("BOTTOMRIGHT", px, -px)
	-- The shield's icon on its own square tag against the bar's left end: their black edges one
	-- line between them
	barrier.tag:SetSize(o.height, o.height)
	barrier.tag:ClearAllPoints()
	barrier.tag:SetPoint("RIGHT", barrier, "LEFT", -px, 0)
	barrier.tagEdge:ClearAllPoints()
	barrier.tagEdge:SetPoint("TOPLEFT", -px, px)
	barrier.tagEdge:SetPoint("BOTTOMRIGHT", px, -px)
	barrier.tag:SetShown(o.icon)
	Paint()
	local size = max(floor(o.height * 0.9), 10)
	ThinFont(barrier.text, size)
	ThinFont(barrier.time, size)
end

function ns.UpdateBarrier()
	local o = ns.db.barrier
	if ns.unlocked then
		-- A sample to drag and size
		barrier.status:SetMinMaxValues(0, 811)
		barrier.status:SetValue(600)
		barrier.text:SetText(o.text and "600" or "")
		barrier.time:SetText(o.time and "22" or "")
		barrier:SetShown(o.enabled and ns.IsWarlock())
		return
	end
	local now = GetTime()
	local amount = Absorbs()
	-- A hidden value can't even be compared with nil: ask first
	local hidden = ns.IsSecret(amount)
	local on = o.enabled and ns.IsWarlock() and (hidden or amount ~= nil) and now < barrierEnds
	-- When the game lets the addon read it: gone at nothing, and a shield it didn't see go on
	-- (a priest's) shows too
	if not hidden and amount ~= nil then
		if amount <= 0 then
			on, barrierEnds = false, 0
		elseif o.enabled and ns.IsWarlock() then
			if now >= barrierEnds then
				current = nil
				if Identify() == false then
					barrier:Hide()
					return
				end
				-- The time its buff gives, else half a minute
				if barrierEnds <= now then barrierEnds = now + BARRIER_TIME end
				barrierFull = amount
				barrier.status:SetMinMaxValues(0, amount)
				Paint()
			elseif not ns.IsSecret(barrierFull) and barrierFull and amount > barrierFull then
				barrierFull = amount
				barrier.status:SetMinMaxValues(0, amount)
			end
			on = true
		end
	end
	if not on then
		barrier:Hide()
		return
	end
	barrier.status:SetValue(amount)
	if o.text then barrier.text:SetFormattedText("%d", amount) else barrier.text:SetText("") end
	-- A potion's two minutes as 2:00, the rest in seconds
	local left = ceil(barrierEnds - now)
	barrier.time:SetText(o.time and (left >= 100 and ns.Clock(left) or format("%d", left)) or "")
	barrier:Show()
end

barrier = CreateFrame("Frame", "WarlockGodBarrier", UIParent)
barrier:SetSize(160, 14)
barrier:Hide()
-- Flat and square: a plain fill on a dark back, a black edge one screen pixel thin, and thin
-- letters with a shadow
barrier.edge = barrier:CreateTexture(nil, "BACKGROUND", nil, -1)
barrier.edge:SetColorTexture(0, 0, 0, 1)
barrier.status = CreateFrame("StatusBar", nil, barrier)
barrier.status:SetAllPoints()
barrier.status:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
local back = barrier.status:CreateTexture(nil, "BACKGROUND")
back:SetAllPoints()
back:SetColorTexture(0.04, 0.03, 0.08, 0.8)
barrier.text = barrier.status:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
barrier.text:SetPoint("CENTER")
barrier.time = barrier.status:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
barrier.time:SetPoint("RIGHT", -3, 0)
barrier.time:SetTextColor(0.88, 0.85, 1)
for _, text in ipairs({ barrier.text, barrier.time }) do
	text:SetShadowOffset(1, -1)
	text:SetShadowColor(0, 0, 0, 1)
end
barrier.tag = CreateFrame("Frame", nil, barrier)
barrier.tagEdge = barrier.tag:CreateTexture(nil, "BACKGROUND", nil, -1)
barrier.tagEdge:SetColorTexture(0, 0, 0, 1)
barrier.icon = barrier.tag:CreateTexture(nil, "ARTWORK")
barrier.icon:SetAllPoints()
barrier.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

-- For the tests
function ns.BarrierState() return { bar = barrier, current = current and current.key } end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, unit, _, spellID)
	if event == "PLAYER_LOGIN" then
		Learn()
		barrier.icon:SetTexture(ns.SpellIcon(SHADOW_WARD))
		ns.StyleBarrier()
		ns.Movable(barrier, "barrier", { "CENTER", "CENTER", 0, -95 }, L.BARRIER_NAME)
		table.insert(ns.refreshers, function() ns.StyleBarrier() ns.UpdateBarrier() end)
		-- Yours and your demon's: the Voidwalker casts Sacrifice
		self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "pet")
		self:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", "player")
		self:RegisterUnitEvent("UNIT_AURA", "player")
		self:RegisterEvent("SPELLS_CHANGED")
		pcall(self.RegisterEvent, self, "UI_SCALE_CHANGED")
		pcall(self.RegisterEvent, self, "DISPLAY_SIZE_CHANGED")
		-- The seconds left tick on their own
		local since = 0
		self:SetScript("OnUpdate", function(_, dt)
			since = since + dt
			if since < 0.25 then return end
			since = 0
			ns.UpdateBarrier()
		end)
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		if (unit ~= "player" and unit ~= "pet") or not spellID or ns.IsSecret(spellID) then return end
		Cast(spellID)
		return
	elseif event == "SPELLS_CHANGED" then
		Learn()
	elseif event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
		-- A screen pixel is another size now
		ns.StyleBarrier()
		return
	end
	ns.UpdateBarrier()
end)
