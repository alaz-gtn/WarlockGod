local _, ns = ...
local L = ns.L

-- Every rank of each spell: the name covers them all, the ids say which you know
local ARMOR = {
	skin = { 687, 696 }, -- Demon Skin
	armor = { 706, 1086, 11733, 11734, 11735 }, -- Demon Armor, from level 20
}
local ARMOR_TIME = 1800 -- both last half an hour until the game says otherwise
-- Conjured stones: the spells that make them (ranks), and the items (worst first, best last).
-- Forever gives some healthstones two more numbers (the Improved Healthstone ones)
local STONES = {
	healthstone = {
		spells = { 6201, 6202, 5699, 11729, 11730 },
		items = { 5512, 19004, 19005, 5511, 19006, 19007, 5509, 19008, 19009, 5510, 19010, 19011, 9421, 19012, 19013 },
	},
	soulstone = { spells = { 693, 20752, 20755, 20756, 20757 }, items = { 5232, 16892, 16893, 16895, 16896 } },
	-- In Forever these two no longer go in your off hand: you use them on your weapon
	firestone = { spells = { 6366, 17951, 17952, 17953 }, items = { 1254, 13699, 13700, 13701 } },
	spellstone = { spells = { 2362, 17727, 17728 }, items = { 5522, 13602, 13603 } },
}
ns.ARMOR_SPELLS, ns.STONES = ARMOR, STONES
-- What using a weapon stone casts (the item's own spell)
local IMBUE_SPELLS = {
	[758] = "firestone", [17945] = "firestone", [17947] = "firestone", [17949] = "firestone",
	[1237152] = "spellstone", [1237156] = "spellstone", [1237159] = "spellstone",
}
local SHARD = 6265
ns.SHARD = SHARD
local MAIN_HAND = INVSLOT_MAINHAND or 16

local db, stones
local known = {}
local armorNames = {} -- buff name -> key
local castNames = {} -- spell name -> what casting it means
-- GetTime() when your armor runs out (math.huge for no end), false when none is on you, nil while
-- the addon hasn't seen your buffs yet
local armorEnds
local armorOn -- skin | armor
local lasts = {} -- by key: how long it lasts, as the game said last time
local inCombat = false
local frames = {}

local function Learn()
	wipe(armorNames)
	wipe(castNames)
	for key, ids in pairs(ARMOR) do
		known[key] = ns.Knows(ids)
		local name = ns.SpellName(ids[1])
		if name then
			armorNames[name] = key
			castNames[name] = { armor = key }
		end
	end
	for key, stone in pairs(STONES) do
		known[key] = ns.Knows(stone.spells)
		local name = ns.SpellName(stone.spells[1])
		if name then castNames[name] = { stone = key } end
	end
	for id, kind in pairs(IMBUE_SPELLS) do
		local name = ns.SpellName(id)
		if name then castNames[name] = { imbue = kind } end
	end
end

-- Reads your armor from your buffs; false when the game hides them (in combat, in Forever). Then
-- what you cast keeps the count
local function Scan()
	local buffs = ns.ReadBuffs()
	if not buffs then return false end
	armorEnds, armorOn = false, nil
	for name, buff in pairs(buffs) do
		local key = armorNames[name]
		if key then
			armorEnds, armorOn = buff.ends, key
			if buff.duration > 0 then lasts[key] = buff.duration end
		end
	end
	return true
end

function ns.Shards()
	return ns.ItemCount(SHARD) or 0
end

-- The best of these you carry, and how many
local function Carried(items)
	for i = #items, 1, -1 do
		local count = ns.ItemCount(items[i])
		if count and count > 0 then return items[i], count end
	end
end
ns.CarriedStone = function(key) return Carried(STONES[key].items) end

-- An item's cooldown is over (when the game hides it, it isn't)
local function Ready(item)
	local get = C_Container and C_Container.GetItemCooldown or GetItemCooldown
	if not get then return true end
	local start, duration = get(item)
	if ns.IsSecret(start) or ns.IsSecret(duration) then return false end
	if not start or start == 0 or not duration or duration <= 1.5 then return true end
	return start + duration <= GetTime()
end

local function SpellOf(key)
	return ns.SpellName(STONES[key].spells[1])
end

-- The armor to remind you of: Demon Armor once you know it
local function WantedArmor()
	if known.armor then return "armor" end
	if known.skin then return "skin" end
end

-- Each reminder: { icon, grey, text, spell or macro or item, hint }, or nil when there's nothing to say
local function ArmorState()
	local want = WantedArmor()
	if not want or armorEnds == nil then return end
	local spell = ns.SpellName(ARMOR[want][1])
	if not armorEnds then return { icon = ns.SpellIcon(ARMOR[want][1]), grey = true, spell = spell } end
	local left = armorEnds - GetTime()
	if left > db.warnMinutes * 60 then return end
	return { icon = ns.SpellIcon(ARMOR[armorOn or want][1]), text = ns.Clock(max(left, 0)), spell = spell }
end

-- The stone for your weapon: the one you chose, or the one you used last, or the Spellstone
local function WeaponKind()
	local pick = stones.weaponChoice == "auto" and ns.db.lastWeaponStone or stones.weaponChoice
	if pick and known[pick] then return pick end
	if known.spellstone then return "spellstone" end
	if known.firestone then return "firestone" end
end
ns.WeaponKind = function() return WeaponKind() end

local function WeaponState()
	local kind = WeaponKind()
	if not kind or not GetInventoryItemID("player", MAIN_HAND) or not GetWeaponEnchantInfo then return end
	local has, expires = GetWeaponEnchantInfo()
	if ns.IsSecret(has) then return end
	local text
	if has then
		if ns.IsSecret(expires) or type(expires) ~= "number" then return end
		local left = expires / 1000
		if left > db.warnMinutes * 60 then return end
		text = ns.Clock(left)
	end
	local item = Carried(STONES[kind].items)
	if item then
		-- If the stone asks which weapon, the second line answers: the one in your hand
		return { icon = ns.ItemIcon(item), grey = not has, text = text, item = item,
			macro = format("/use item:%d\n/use %d", item, MAIN_HAND), hint = L.CLICK_IMBUE }
	end
	local icon = ns.SpellIcon(STONES[kind].spells[1])
	if ns.Shards() > 0 then
		return { icon = icon, grey = not has, text = text, spell = SpellOf(kind), hint = L.CLICK_CREATE }
	end
	-- Nothing to put on it and no shard to make one: only the time left
	if has then return { icon = icon, text = text } end
end

local function HealthstoneState()
	if not known.healthstone or Carried(STONES.healthstone.items) or ns.Shards() < 1 then return end
	return { icon = ns.ItemIcon(5509), grey = true, spell = SpellOf("healthstone"), hint = L.CLICK_CREATE }
end

local function SoulstoneState()
	if not known.soulstone then return end
	local item = Carried(STONES.soulstone.items)
	if not item then
		if ns.Shards() < 1 then return end
		return { icon = ns.ItemIcon(5232), grey = true, spell = SpellOf("soulstone"), hint = L.CLICK_CREATE }
	end
	if not stones.soulstoneUse or not Ready(item) then return end
	-- On your friendly target, or on you
	return { icon = ns.ItemIcon(item), item = item, text = L.SOULSTONE_READY,
		macro = format("/use [@target,help,nodead][@player] item:%d", item), hint = L.CLICK_SOULSTONE }
end

-- Herbalism or Mining without its tracking on, out in the world: the family's Gathering.lua says
-- which one a click puts on
local function GatherState()
	local g = ns.GatherReminder and ns.GatherReminder()
	if g then return { icon = g.icon, grey = true, spell = g.spell } end
end

local STATES = {
	{ key = "armor", order = 30, get = ArmorState, on = function() return db.armor end },
	{ key = "weapon", order = 40, get = WeaponState, on = function() return stones.weapon end },
	{ key = "healthstone", order = 50, get = HealthstoneState, on = function() return stones.healthstone end },
	{ key = "soulstone", order = 60, get = SoulstoneState, on = function() return stones.soulstone end },
	{ key = "gather", order = 70, get = GatherState, on = function() return ns.db.gather.enabled end },
}
local current = {} -- by key: what each one shows now
local GROUP_SLOTS = 3 -- a priest has three group buffs; the family's file can hand over that many

-- Samples to drag around
local SAMPLES = {
	armor = function() return { icon = ns.SpellIcon(ARMOR.armor[1]), grey = true } end,
	weapon = function() return { icon = ns.ItemIcon(STONES.spellstone.items[1]), text = "1:35" } end,
	healthstone = function() return { icon = ns.ItemIcon(5509), grey = true } end,
	soulstone = function() return { icon = ns.ItemIcon(5232), text = L.SOULSTONE_READY } end,
	gather = function() return { icon = ns.SpellIcon(2580), grey = true } end,
}

-- Gathering.lua says when your tracking changes or you go in or out of an instance
function ns.GatherChanged()
	if db then ns.UpdateBuffs() end
end

function ns.UpdateBuffs()
	local warlock = ns.IsWarlock() and not ns.Dead()
	-- In a fight these would only get in the way, unless you want them there too
	local quiet = inCombat and not db.combat
	for _, s in ipairs(STATES) do
		local r
		if ns.unlocked then
			r = db.enabled and s.on() and SAMPLES[s.key]()
		elseif warlock and db.enabled and not quiet and s.on() then
			r = s.get()
		end
		current[s.key] = r or nil
		local frame = frames[s.key]
		if r then
			ns.ShowReminder(frame, r.icon, r.grey, r.text)
		else
			frame:Hide()
		end
	end
	-- Your buffs someone in your group lacks (GroupBuffs.lua, the family's: a warlock has none, the
	-- slots stay empty): an icon with how many, and a click on the first of them in range
	local group = warlock and not ns.unlocked and ns.GroupBuffReminders and ns.GroupBuffReminders() or {}
	for i = 1, GROUP_SLOTS do
		local key, g = "group" .. i, group[i]
		local r = g and { icon = g.icon, text = tostring(g.count), spell = g.unit and g.spell or nil, unit = g.unit,
			hint = g.click, name = g.text }
		current[key] = r
		if r then ns.ShowReminder(frames[key], r.icon, false, r.text) else frames[key]:Hide() end
	end
	if ns.SyncReminders then ns.SyncReminders() end
	if ns.UpdateShards then ns.UpdateShards() end
end

-- GroupBuffs.lua says when your group's buffs may have changed
function ns.GroupBuffsChanged()
	if db then ns.UpdateBuffs() end
end

-- What a click does, as the row wants it
local function Action(key)
	return function()
		local r = current[key]
		if not r or not (r.spell or r.macro) then return end
		return { spell = r.spell, macro = r.macro, hint = r.hint, unit = r.unit }
	end
end

local function Tooltip(key)
	return function(tip)
		local r = current[key]
		if r and r.item and tip.SetItemByID then
			tip:SetItemByID(r.item)
		elseif r and r.name then
			tip:AddLine(r.name, 1, 1, 1)
		elseif r and r.spell then
			tip:AddLine(r.spell, 1, 1, 1)
		end
	end
end

-- Your soul shards: a small count by the reminders, red when you're short, orange when you carry
-- more than you want
local counter = CreateFrame("Frame", "WarlockGodShards", UIParent)
counter:SetSize(60, 26)
counter:Hide()
counter.icon = counter:CreateTexture(nil, "ARTWORK")
counter.icon:SetSize(22, 22)
counter.icon:SetPoint("LEFT", 2, 0)
counter.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
counter.edge = counter:CreateTexture(nil, "BORDER")
counter.edge:SetPoint("TOPLEFT", counter.icon, -1, 1)
counter.edge:SetPoint("BOTTOMRIGHT", counter.icon, 1, -1)
counter.edge:SetColorTexture(0, 0, 0, 1)
counter.text = counter:CreateFontString(nil, "OVERLAY", "GameFontNormal")
counter.text:SetPoint("LEFT", counter.icon, "RIGHT", 6, 0)

local SHARD_COLORS = { low = { 1, 0.25, 0.25 }, many = { 1, 0.6, 0.1 }, fine = { 0.85, 0.82, 1 } }

function ns.UpdateShards()
	local o = ns.db.shards
	if not o.enabled or not ns.IsWarlock() then
		counter:Hide()
		return
	end
	local count = ns.unlocked and o.max + 1 or ns.Shards()
	local mood = count < o.low and "low" or count > o.max and "many" or "fine"
	if not (o.always or mood ~= "fine" or ns.unlocked) or (ns.Dead() and not ns.unlocked) then
		counter:Hide()
		return
	end
	counter.text:SetText(count)
	counter.text:SetTextColor(unpack(SHARD_COLORS[mood]))
	counter.mood = mood
	counter:SetWidth(32 + (counter.text:GetStringWidth() or 12))
	counter:Show()
end

counter:EnableMouse(true)
counter:SetScript("OnEnter", function(self)
	local o = ns.db.shards
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:AddLine(L.SHARDS_NAME, 1, 1, 1)
	GameTooltip:AddLine(format(L.SHARDS_TIP, ns.Shards(), o.low, o.max), 0.8, 0.8, 0.8, true)
	GameTooltip:Show()
end)
counter:SetScript("OnLeave", GameTooltip_Hide)

-- /warlockgod bufos: what the addon sees
local function Describe()
	if armorEnds == nil then return L.BUFF_UNKNOWN end
	if not armorEnds then return L.BUFF_NONE end
	local name = ns.SpellName(ARMOR[armorOn or "armor"][1]) or "?"
	if armorEnds == math.huge then return format(L.BUFF_ON, name) end
	return format(L.BUFF_LEFT, name, ns.Clock(max(armorEnds - GetTime(), 0)))
end

local function StoneText(key)
	if not known[key] then return L.BUFF_NOT_KNOWN end
	local item, count = Carried(STONES[key].items)
	if not item then return L.STONE_NONE end
	return format(L.STONE_HAVE, ns.ItemName(item) or ("item " .. item), count)
end

local function BuffsReport()
	Learn()
	local seen = Scan()
	local weapon = L.BUFF_NOT_KNOWN
	local kind = WeaponKind()
	if kind then
		local has = GetWeaponEnchantInfo and GetWeaponEnchantInfo()
		weapon = format("%s (%s)", SpellOf(kind) or kind, has and L.WEAPON_ON or L.WEAPON_OFF)
	end
	ns.Print(format(L.BUFFS_REPORT, Describe(), StoneText("healthstone"), StoneText("soulstone"), weapon, ns.Shards()))
	if not seen then
		ns.Print(L.BUFFS_HIDDEN)
		return
	end
	local names = {}
	for name in pairs(ns.ReadBuffs()) do names[#names + 1] = name end
	table.sort(names)
	ns.Print(format(L.BUFFS_SEEN, #names > 0 and table.concat(names, ", ") or L.BUFF_NONE))
	if ns.FoodReport then ns.FoodReport() end
end
ns.commands.buffs = BuffsReport
ns.commands.bufos = BuffsReport

local function Cast(spellID)
	local what = castNames[ns.SpellName(spellID) or ""]
	if not what then return end
	if what.imbue then ns.db.lastWeaponStone = what.imbue end
	if what.stone == "firestone" or what.stone == "spellstone" then ns.db.lastWeaponStone = what.stone end
	if what.stone or what.imbue then
		-- The bags and the weapon say so a moment later
		C_Timer.After(0.5, ns.UpdateBuffs)
		return
	end
	-- Out of combat your buffs say it's on; in combat they're hidden: what you cast is taken as on
	if not Scan() then
		armorEnds, armorOn = GetTime() + (lasts[what.armor] or ARMOR_TIME), what.armor
	end
	ns.UpdateBuffs()
end

-- For the tests
function ns.BuffsState()
	return { armorEnds = armorEnds, armorOn = armorOn, frames = frames, current = current, counter = counter }
end

for i = 1, GROUP_SLOTS do
	local key = "group" .. i
	local frame = CreateFrame("Frame", "WarlockGodReminder" .. key, UIParent)
	ns.StyleReminder(frame)
	frames[key] = frame
	ns.AddReminder(key, 80 + i, frame, Action(key), Tooltip(key))
end

for _, s in ipairs(STATES) do
	local frame = CreateFrame("Frame", "WarlockGodReminder" .. s.key, UIParent)
	ns.StyleReminder(frame)
	frames[s.key] = frame
	ns.AddReminder(s.key, s.order, frame, Action(s.key), Tooltip(s.key))
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, unit, _, spellID)
	if event == "PLAYER_LOGIN" then
		db, stones = ns.db.buffs, ns.db.stones
		Learn()
		Scan()
		counter.icon:SetTexture(ns.ItemIcon(SHARD))
		ns.FancyFont(counter.text, 18, "THICKOUTLINE")
		ns.Movable(counter, "shards", { "CENTER", "CENTER", 0, 205 }, L.SHARDS_NAME)
		table.insert(ns.refreshers, ns.UpdateBuffs)
		self:RegisterUnitEvent("UNIT_AURA", "player")
		self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
		self:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
		self:RegisterEvent("PLAYER_REGEN_DISABLED")
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		self:RegisterEvent("SPELLS_CHANGED")
		self:RegisterEvent("BAG_UPDATE_DELAYED")
		self:RegisterEvent("PLAYER_LEVEL_UP")
		self:RegisterEvent("PLAYER_DEAD")
		self:RegisterEvent("PLAYER_UNGHOST")
		self:RegisterEvent("PLAYER_ALIVE")
		-- An event the game doesn't have would stop the rest of the file
		pcall(self.RegisterEvent, self, "BAG_UPDATE_COOLDOWN")
		-- The time left ticks on its own
		local since = 0
		self:SetScript("OnUpdate", function(_, dt)
			since = since + dt
			if since < 0.5 then return end
			since = 0
			ns.UpdateBuffs()
		end)
	elseif event == "UNIT_AURA" then
		Scan()
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		if unit ~= "player" or not spellID or ns.IsSecret(spellID) then return end
		Cast(spellID)
		return
	elseif event == "PLAYER_REGEN_DISABLED" then
		inCombat = true
	elseif event == "PLAYER_REGEN_ENABLED" then
		inCombat = false
		Scan()
	elseif event == "SPELLS_CHANGED" or event == "PLAYER_LEVEL_UP" then
		Learn()
	end
	ns.UpdateBuffs()
end)
