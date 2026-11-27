local addonName, ns = ...

-- The reagents your class spends, and a reminder when they run low: runes for teleports and
-- portals, Flash Powder for Vanish, candles, seeds, an Ankh, symbols, Soul Shards... Only for the
-- spells you know, and only the reagent of the rank you cast (the seed of your best Rebirth). Not
-- the ones vendors sell once you have the legacy talent Reagent Economy, which does away with them.
-- A merchant that sells one you're low on says so in the chat, or (an option) you buy up to a
-- handful (stock) of each one you spend, with what it cost in the chat.
-- The same file in every ...God addon: each one shows ns.ReagentReminders() in its own list and
-- sets ns.ReagentsChanged to hear when that may have changed
local ECONOMY = { 1225503, 1262636, 1262638, 1262643, 1262647, 1262650, 1262654, 1262662 } -- Reagent Economy
-- item: the reagent; stock: how many to buy up to; low: a reminder under this many (6: with 5 or fewer); vendor: sold by vendors (Reagent Economy does
-- away with it); spells: what spends it; next: the reagent of a better rank, which takes over
local REAGENTS = {
	MAGE = {
		{ item = 17031, stock = 10, low = 6, vendor = true, spells = { 3561, 3562, 3563, 3565, 3566, 3567 } }, -- Rune of Teleportation
		{ item = 17032, stock = 10, low = 6, vendor = true, spells = { 10059, 11416, 11417, 11418, 11419, 11420 } }, -- Rune of Portals
		{ item = 17020, stock = 20, low = 10, vendor = true, spells = { 23028 } }, -- Arcane Powder: Arcane Brilliance
		{ item = 17056, stock = 20, low = 6, vendor = true, spells = { 130 } }, -- Light Feather: Slow Fall
	},
	ROGUE = {
		{ item = 5140, stock = 20, low = 5, vendor = true, spells = { 1856, 1857 } }, -- Flash Powder: Vanish
		{ item = 5530, low = 3, spells = { 2094 } }, -- Blinding Powder: Blind (you make it)
	},
	PRIEST = {
		{ item = 17028, stock = 20, low = 5, vendor = true, spells = { 21562 }, next = 17029 }, -- Holy Candle: Prayer of Fortitude 1
		{ item = 17029, stock = 20, low = 5, vendor = true, spells = { 21564, 27681, 27683 } }, -- Sacred Candle: the prayers
		{ item = 17056, stock = 20, low = 6, vendor = true, spells = { 1706 } }, -- Light Feather: Levitate
	},
	DRUID = {
		{ item = 17034, stock = 5, low = 2, vendor = true, spells = { 20484 }, next = 17035 }, -- Maple Seed: Rebirth 1
		{ item = 17035, stock = 5, low = 2, vendor = true, spells = { 20739 }, next = 17036 }, -- Stranglethorn Seed
		{ item = 17036, stock = 5, low = 2, vendor = true, spells = { 20742 }, next = 17037 }, -- Ashwood Seed
		{ item = 17037, stock = 5, low = 2, vendor = true, spells = { 20747 }, next = 17038 }, -- Hornbeam Seed
		{ item = 17038, stock = 5, low = 2, vendor = true, spells = { 20748 } }, -- Ironwood Seed: Rebirth 5
		{ item = 17021, stock = 20, low = 5, vendor = true, spells = { 21849 }, next = 17026 }, -- Wild Berries: Gift of the Wild 1
		{ item = 17026, stock = 20, low = 5, vendor = true, spells = { 21850 } }, -- Wild Thornroot: Gift of the Wild 2
	},
	SHAMAN = {
		{ item = 17030, stock = 3, low = 1, vendor = true, spells = { 20608 } }, -- Ankh: Reincarnation
		{ item = 17057, stock = 10, low = 3, vendor = true, spells = { 131 } }, -- Shiny Fish Scales: Water Breathing
		{ item = 17058, stock = 10, low = 3, vendor = true, spells = { 546 } }, -- Fish Oil: Water Walking
	},
	PALADIN = {
		{ item = 17033, stock = 5, low = 1, vendor = true, spells = { 19752 } }, -- Symbol of Divinity: Divine Intervention
		{ item = 21177, stock = 100, low = 20, vendor = true, spells = { 25782, 25890, 25894, 25895, 25898, 25899 } }, -- Symbol of Kings: Greater Blessings
	},
	WARLOCK = {
		-- Soul Shards come from kills, not vendors: Voidwalker, Succubus, Felhunter, Healthstone, Soulstone
		{ item = 6265, low = 3, spells = { 691, 693, 697, 712, 6201 } },
		{ item = 5565, stock = 3, low = 1, vendor = true, spells = { 1122 } }, -- Infernal Stone: Inferno
		{ item = 16583, stock = 3, low = 1, vendor = true, spells = { 18540 } }, -- Demonic Figurine: Ritual of Doom
	},
}
ns.REAGENTS = REAGENTS

local T = {
	LOW = "%s: %d left",
	NONE = "No %s left",
	FOR = "For %s",
	VENDOR = "This vendor sells %s: you have %d.",
	BOUGHT = "Bought %d %s for %s.",
	SHORT = "Not enough money for %s.",
	OPT_BUY = "Buy my reagents at a merchant who sells them",
}
if GetLocale() == "esES" or GetLocale() == "esMX" then
	T.LOW = "%s: te quedan %d"
	T.NONE = "Sin %s"
	T.FOR = "Para %s"
	T.VENDOR = "Este vendedor tiene %s: te quedan %d."
	T.BOUGHT = "Comprados %d %s por %s."
	T.SHORT = "No llevas dinero para %s."
	T.OPT_BUY = "Comprar mis reactivos en el vendedor que los tenga"
end
ns.REAGENT_TEXT = T

-- Each addon only does it on its own class: with all of them on, only one buys
local CLASS_OF = { HunterGod = "HUNTER", MageGod = "MAGE", WarriorGod = "WARRIOR", PaladinGod = "PALADIN",
	RogueGod = "ROGUE", PriestGod = "PRIEST", ShamanGod = "SHAMAN", WarlockGod = "WARLOCK", DruidGod = "DRUID" }

local toBuy -- what a merchant could top up: item = how many
local cache -- what to remind you of, worked out again when your bags or spells change

local function IsSecret(value)
	return issecretvalue and issecretvalue(value) or false
end

local function SpellName(id)
	if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
	return (GetSpellInfo(id))
end

-- Do you know it: by its ID, or by its name in your spellbook if Forever gave it another
local function Knows(id)
	local known
	if IsPlayerSpell then known = IsPlayerSpell(id) elseif IsSpellKnown then known = IsSpellKnown(id) end
	if known and not IsSecret(known) then return true end
	local name = SpellName(id)
	if name and C_Spell and C_Spell.GetSpellInfo then
		local info = C_Spell.GetSpellInfo(name)
		return type(info) == "table" and not IsSecret(info)
	end
	return false
end

-- Do you know this very rank: by its ID only
local function KnowsRank(id)
	local known
	if IsPlayerSpell then known = IsPlayerSpell(id) elseif IsSpellKnown then known = IsSpellKnown(id) end
	return known and not IsSecret(known) or false
end

-- Spell names that more than one reagent of your class answers for: the ranks of one spell (Prayer
-- of Fortitude 1 and 2, Rebirth 1 to 5). The spellbook knows any rank by that name, so for those
-- only the ID says which rank you have
local shared
local function Shared(own)
	if shared then return shared end
	shared = {}
	local first = {}
	for i, r in ipairs(own) do
		for _, id in ipairs(r.spells) do
			local name = SpellName(id)
			if name then
				if first[name] and first[name] ~= i then shared[name] = true end
				first[name] = first[name] or i
			end
		end
	end
	return shared
end

-- The names of the spells you know among these
local function Known(ids, own)
	local names, seen = {}, {}
	local ranked = Shared(own)
	for _, id in ipairs(ids) do
		local name = SpellName(id)
		if name and not seen[name] and (KnowsRank(id) or not ranked[name] and Knows(id)) then
			seen[name] = true
			names[#names + 1] = name
		end
	end
	return names
end

local function HasEconomy()
	for _, id in ipairs(ECONOMY) do
		local known
		if IsPlayerSpell then known = IsPlayerSpell(id) elseif IsSpellKnown then known = IsSpellKnown(id) end
		if known and not IsSecret(known) then return true end
	end
	local name = SpellName(ECONOMY[1])
	if name and C_Spell and C_Spell.GetSpellInfo then
		local info = C_Spell.GetSpellInfo(name)
		if type(info) == "table" and not IsSecret(info) then return true end
	end
	return false
end
ns.HasReagentEconomy = HasEconomy

local function Count(item)
	local count = C_Item and C_Item.GetItemCount and C_Item.GetItemCount(item) or GetItemCount and GetItemCount(item)
	if IsSecret(count) then return end
	return count or 0
end

-- Money as the game writes it, with its coins
local function Money(copper)
	if GetCoinTextureString then return GetCoinTextureString(copper) end
	return format("%dg %ds %dc", floor(copper / 10000), floor(copper / 100) % 100, copper % 100)
end

local function ItemName(item)
	return C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(item) or GetItemInfo and (GetItemInfo(item))
		or ("item " .. item)
end

local function Work()
	local list, short = {}, {} -- short: what a merchant could top up, item = how many
	local db = ns.db and ns.db.reagents
	local _, class = UnitClass("player")
	local own = REAGENTS[class]
	if not (db and (db.enabled or db.buy) and own) then return list, short end
	local economy = HasEconomy()
	local byItem = {}
	for _, r in ipairs(own) do byItem[r.item] = r end
	for _, r in ipairs(own) do
		local uses = (not (r.vendor and economy)) and Known(r.spells, own) or {}
		-- A better rank you know spends another reagent: this one isn't needed any more
		local better = r.next and byItem[r.next]
		if #uses > 0 and not (better and #Known(better.spells, own) > 0) then
			local count = Count(r.item)
			if count and r.vendor and r.stock and count < r.stock then short[r.item] = r.stock - count end
			if count and count < r.low and db.enabled then
				local name = ItemName(r.item)
				list[#list + 1] = { item = r.item, count = count, name = name,
					text = count == 0 and format(T.NONE, name) or format(T.LOW, name, count),
					uses = format(T.FOR, table.concat(uses, ", ", 1, min(#uses, 3)) .. (#uses > 3 and "..." or "")) }
			end
		end
	end
	return list, short
end

-- Your reagents running low: { item, count, name, text, uses }
function ns.ReagentReminders()
	if not cache then cache, toBuy = Work() end
	return cache
end

function ns.RefreshReagents()
	cache, shared = nil, nil -- the names load with the spells
	if ns.db and ns.ReagentsChanged then ns.ReagentsChanged() end
end

-- Buys up to its stock of one reagent from this merchant: what it bought and spent
local function Buy(index, item, want)
	if not (GetMerchantItemInfo and BuyMerchantItem) then return 0, 0 end
	local _, _, price, batch, available = GetMerchantItemInfo(index)
	if IsSecret(price) or type(price) ~= "number" then return 0, 0 end
	batch = type(batch) == "number" and not IsSecret(batch) and batch > 0 and batch or 1
	local each = price / batch
	if type(available) == "number" and not IsSecret(available) and available >= 0 then want = min(want, available * batch) end
	local money = GetMoney and GetMoney()
	if type(money) == "number" and not IsSecret(money) and each > 0 then want = min(want, floor(money / each)) end
	if want <= 0 then return 0, 0 end
	local most = GetMerchantItemMaxStack and GetMerchantItemMaxStack(index)
	most = type(most) == "number" and not IsSecret(most) and most > 0 and most or want
	local left = want
	while left > 0 do
		local n = min(left, most)
		BuyMerchantItem(index, n)
		left = left - n
	end
	return want, floor(each * want + 0.5)
end

local function BuyAll(short)
	local bought = false
	for i = 1, GetMerchantNumItems() or 0 do
		local item = GetMerchantItemID(i)
		local want = item and not IsSecret(item) and short[item]
		if want then
			short[item] = nil
			local got, spent = Buy(i, item, want)
			if got > 0 then
				ns.Print(format(T.BOUGHT, got, ItemName(item), Money(spent)))
			elseif ns.Print then
				ns.Print(format(T.SHORT, ItemName(item)))
			end
			bought = true
		end
	end
	return bought
end

-- A merchant that sells one you're low on: a line in the chat, once per visit; or, with the
-- option, you buy them
local function AtMerchant()
	if not (GetMerchantNumItems and GetMerchantItemID and ns.Print) then return end
	local _, class = UnitClass("player")
	local db = ns.db and ns.db.reagents
	if db and db.buy and class ~= nil and class == CLASS_OF[addonName] then
		ns.ReagentReminders()
		if BuyAll(toBuy) then cache = nil return end
	end
	local low = {}
	for _, r in ipairs(ns.ReagentReminders()) do low[r.item] = r end
	for i = 1, GetMerchantNumItems() or 0 do
		local item = GetMerchantItemID(i)
		local r = item and not IsSecret(item) and low[item]
		if r then
			ns.Print(format(T.VENDOR, r.name, r.count))
			low[item] = nil
		end
	end
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "BAG_UPDATE_DELAYED", "SPELLS_CHANGED", "MERCHANT_SHOW" }) do
	pcall(events.RegisterEvent, events, event) -- an event the game doesn't have would stop the file
end
events:SetScript("OnEvent", function(_, event)
	if event == "MERCHANT_SHOW" then
		cache = nil
		AtMerchant()
		return
	end
	ns.RefreshReagents()
end)
