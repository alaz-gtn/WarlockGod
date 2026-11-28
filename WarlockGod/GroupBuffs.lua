local _, ns = ...

-- In a group, the buffs of yours someone is missing: Arcane Intellect, Power Word: Fortitude,
-- Shadow Protection, Divine Spirit, Mark of the Wild. Out of combat only (that's when buffs are
-- given, and when the game shows other players' buffs to addons). Only those you can buff now count:
-- in range, alive and online (a party member in another city isn't nagged about). Each one says
-- how many lack it, and a click casts it on the first of them; the next click, on the next.
-- Looked at again every couple of seconds while you're in a group, as people come and go.
-- Its group version counts too (Arcane Brilliance, the prayers, Gift of the Wild). You yourself
-- are left out: each addon reminds you of your own buffs already.
-- The same file in every ...God addon: each one shows ns.GroupBuffReminders() in its own row and
-- sets ns.GroupBuffsChanged to hear when that may have changed. The paladin's blessings are left
-- to PaladinGod, which chooses them by class
local GROUP_BUFFS = {
	MAGE = {
		{ key = "intellect", cast = { 1459, 1460, 1461, 10156, 10157 }, also = { 23028 }, mana = true }, -- Arcane Intellect, Brilliance
	},
	PRIEST = {
		{ key = "fortitude", cast = { 1243, 1244, 1245, 2791, 10937, 10938 }, also = { 21562, 21564 } }, -- Prayer of Fortitude
		{ key = "shadow", cast = { 976, 10957, 10958 }, also = { 27683 } }, -- Shadow Protection, its prayer
		{ key = "spirit", cast = { 14752, 14818, 14819, 27841 }, also = { 27681 }, mana = true }, -- Divine Spirit (talent), its prayer
	},
	DRUID = {
		{ key = "mark", cast = { 1126, 5232, 6756, 5234, 8907, 9884, 9885 }, also = { 21849, 21850 } }, -- Mark, Gift of the Wild
	},
}
ns.GROUP_BUFFS = GROUP_BUFFS

local T = {
	MISSING = "%s: %d missing",
	CLICK = "Click: cast it on %s",
}
if GetLocale() == "esES" or GetLocale() == "esMX" then
	T.MISSING = "%s: faltan %d"
	T.CLICK = "Clic: lanzárselo a %s"
end
ns.GROUP_BUFF_TEXT = T

-- Classes with no mana: Intellect and Spirit do nothing for them, so they aren't counted
local NO_MANA = { WARRIOR = true, ROGUE = true }

local cache

local function IsSecret(value)
	return issecretvalue and issecretvalue(value) or false
end

local function SpellName(id)
	if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
	return (GetSpellInfo(id))
end

local function SpellIcon(id)
	if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
	return GetSpellTexture and GetSpellTexture(id)
end

local function Knows(ids)
	for _, id in ipairs(ids) do
		local known
		if IsPlayerSpell then known = IsPlayerSpell(id) elseif IsSpellKnown then known = IsSpellKnown(id) end
		if known and not IsSecret(known) then return true end
	end
	local name = SpellName(ids[1])
	if name and C_Spell and C_Spell.GetSpellInfo then
		local info = C_Spell.GetSpellInfo(name)
		return type(info) == "table" and not IsSecret(info)
	end
	return false
end

-- Your group, without you: party1-4, or raid1-40
local function Members()
	local list = {}
	if IsInRaid and IsInRaid() then
		for i = 1, 40 do
			local unit = "raid" .. i
			if UnitExists(unit) and not UnitIsUnit(unit, "player") then list[#list + 1] = unit end
		end
	elseif IsInGroup and IsInGroup() then
		for i = 1, 4 do
			local unit = "party" .. i
			if UnitExists(unit) then list[#list + 1] = unit end
		end
	end
	return list
end

-- One of their buffs, or nil when the game hides it. Asking for a hidden one is an error in
-- Forever, not a secret answer: it's asked first, and the call is wrapped in case it doesn't say
local function AuraAt(unit, i)
	if C_Secrets then
		if C_Secrets.ShouldAurasBeSecret then
			local ok, hidden = pcall(C_Secrets.ShouldAurasBeSecret)
			if not ok or hidden then return nil, true end
		end
		if C_Secrets.ShouldUnitAuraIndexBeSecret then
			local ok, hidden = pcall(C_Secrets.ShouldUnitAuraIndexBeSecret, unit, i, "HELPFUL")
			if not ok or hidden then return nil, true end
		end
	end
	local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL")
	if not ok then return nil, true end
	return aura
end

-- The names of their buffs, or nil when the game hides them (they're in a fight, say)
local function BuffNames(unit)
	if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return end
	local fighting = UnitAffectingCombat and UnitAffectingCombat(unit)
	if fighting then return end -- a secret answer counts as yes
	local names = {}
	for i = 1, 40 do
		local aura, hidden = AuraAt(unit, i)
		if hidden then return end
		if not aura then break end
		if IsSecret(aura) or IsSecret(aura.name) then return end
		names[aura.name] = true
	end
	return names
end

local function Reachable(unit, spell)
	-- Far away (another zone, out of sight): the game says so before any range check
	local visible = not UnitIsVisible or UnitIsVisible(unit)
	if not IsSecret(visible) and not visible then return false end
	local dead = UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit)
	if dead and not IsSecret(dead) then return false end
	local online = not UnitIsConnected or UnitIsConnected(unit)
	if IsSecret(online) or not online then return false end
	if C_Spell and C_Spell.IsSpellInRange then
		local inRange = C_Spell.IsSpellInRange(spell, unit)
		if IsSecret(inRange) then return true end
		return inRange ~= false
	end
	return true
end

local function Work()
	local list = {}
	local db = ns.db and ns.db.groupBuffs
	local _, class = UnitClass("player")
	local own = GROUP_BUFFS[class]
	local fighting = InCombatLockdown and InCombatLockdown()
	if not (db and db.enabled and own) or fighting then return list end
	local members = Members()
	if #members == 0 then return list end
	for _, b in ipairs(own) do
		if Knows(b.cast) then
			local spell = SpellName(b.cast[1])
			local accepted = {}
			for _, id in ipairs(b.cast) do accepted[SpellName(id) or ""] = true end
			for _, id in ipairs(b.also) do accepted[SpellName(id) or ""] = true end
			local missing, first = 0, nil
			for _, unit in ipairs(members) do
				local _, unitClass = UnitClass(unit)
				local useless = b.mana and not IsSecret(unitClass) and NO_MANA[unitClass]
				local names = not useless and Reachable(unit, spell) and BuffNames(unit)
				if names then
					local has = false
					for name in pairs(accepted) do
						if names[name] then has = true break end
					end
					if not has then
						missing = missing + 1
						first = first or unit
					end
				end
			end
			if missing > 0 then
				list[#list + 1] = { key = b.key, spell = spell, icon = SpellIcon(b.cast[1]), count = missing, unit = first,
					text = format(T.MISSING, spell or b.key, missing),
					click = first and format(T.CLICK, UnitName and UnitName(first) or first) or nil }
			end
		end
	end
	return list
end

-- Your group's missing buffs, among those in range: { key, spell, icon, count, unit (the first), text, click }
function ns.GroupBuffReminders()
	if not cache then cache = Work() end
	return cache
end

function ns.RefreshGroupBuffs()
	cache = nil
	if ns.db and ns.GroupBuffsChanged then ns.GroupBuffsChanged() end
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "GROUP_ROSTER_UPDATE", "SPELLS_CHANGED", "PLAYER_REGEN_ENABLED",
	"PLAYER_REGEN_DISABLED", "UNIT_AURA", "UNIT_CONNECTION" }) do
	pcall(events.RegisterEvent, events, event) -- an event the game doesn't have would stop the file
end
-- In a group and out of combat, a look every couple of seconds: people walk in and out of range,
-- and the game says nothing when they do. Only a change is passed on
local SWEEP = 2
local sweeper = CreateFrame("Frame")
sweeper:Hide()
local waited = 0
local function Signature(list)
	local parts = {}
	for _, r in ipairs(list) do parts[#parts + 1] = r.key .. r.count .. tostring(r.unit) end
	return table.concat(parts, ",")
end
sweeper:SetScript("OnUpdate", function(_, elapsed)
	waited = waited + elapsed
	if waited < SWEEP then return end
	waited = 0
	local before = Signature(ns.GroupBuffReminders())
	cache = nil
	if Signature(ns.GroupBuffReminders()) ~= before and ns.db and ns.GroupBuffsChanged then ns.GroupBuffsChanged() end
end)
ns.GroupBuffSweeper = sweeper -- for the tests
local function Sweep()
	local grouped = IsInGroup and IsInGroup()
	local fighting = InCombatLockdown and InCombatLockdown()
	local _, class = UnitClass("player")
	sweeper:SetShown(grouped and not fighting and GROUP_BUFFS[class] ~= nil and true or false)
end

events:SetScript("OnEvent", function(_, event, unit)
	-- Only your group's buffs matter here
	if (event == "UNIT_AURA" or event == "UNIT_CONNECTION") and type(unit) == "string"
		and not (unit:find("^party") or unit:find("^raid")) then return end
	ns.RefreshGroupBuffs()
	Sweep()
end)
