local _, ns = ...

-- In a group, the buffs of yours someone is missing: Arcane Intellect, Power Word: Fortitude,
-- Shadow Protection, Divine Spirit, Mark of the Wild. Out of combat only (that's when buffs are
-- given, and when the game shows other players' buffs to addons). Each one says how many lack it,
-- and a click casts it on the first of them who is in range; the next click, on the next.
-- Its group version counts too (Arcane Brilliance, the prayers, Gift of the Wild). You yourself
-- are left out: each addon reminds you of your own buffs already.
-- The same file in every ...God addon: each one shows ns.GroupBuffReminders() in its own row and
-- sets ns.GroupBuffsChanged to hear when that may have changed. The paladin's blessings are left
-- to PaladinGod, which chooses them by class
local GROUP_BUFFS = {
	MAGE = {
		{ key = "intellect", cast = { 1459, 1460, 1461, 10156, 10157 }, also = { 23028 } }, -- Arcane Intellect, Brilliance
	},
	PRIEST = {
		{ key = "fortitude", cast = { 1243, 1244, 1245, 2791, 10937, 10938 }, also = { 21562, 21564 } }, -- Prayer of Fortitude
		{ key = "shadow", cast = { 976, 10957, 10958 }, also = { 27683 } }, -- Shadow Protection, its prayer
		{ key = "spirit", cast = { 14752, 14818, 14819, 27841 }, also = { 27681 } }, -- Divine Spirit (talent), its prayer
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

-- The names of their buffs, or nil when the game hides them
local function BuffNames(unit)
	if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return end
	local names = {}
	for i = 1, 40 do
		local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
		if not aura then break end
		if IsSecret(aura) or IsSecret(aura.name) then return end
		names[aura.name] = true
	end
	return names
end

local function Reachable(unit, spell)
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
				local names = BuffNames(unit)
				if names then
					local has = false
					for name in pairs(accepted) do
						if names[name] then has = true break end
					end
					if not has then
						missing = missing + 1
						if not first and Reachable(unit, spell) then first = unit end
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

-- Your group's missing buffs: { key, spell, icon, count, unit (the first in range, or nil), text, click }
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
events:SetScript("OnEvent", function(_, event, unit)
	-- Only your group's buffs matter here
	if (event == "UNIT_AURA" or event == "UNIT_CONNECTION") and type(unit) == "string"
		and not (unit:find("^party") or unit:find("^raid")) then return end
	ns.RefreshGroupBuffs()
end)
