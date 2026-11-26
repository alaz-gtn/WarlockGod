local _, ns = ...
local L = ns.L

-- A small reminder beside the chat when you aren't Well Fed: in Forever cooked food also gives +5%
-- XP from kills for 15 minutes. A click on it opens the list of your XP food, and a click on one
-- eats it. Under it, the reagents you're running low on (Reagents.lua). As MageGod's, in the
-- warlock's colours
local WELL_FED = 19705
local ROW, ROW_GAP = 22, 2
local ACCENT = ns.ACCENT
local TEXT = { 0.86, 0.85, 1 }
local ThinFont = ns.ThinFont

local inCombat = false
-- Well Fed in lower case: what the game calls it, and the English and your language's words in
-- case Forever names the buff otherwise
local fedWords = { "well fed" }
local fed -- true / false, or nil while the addon hasn't seen your buffs yet
local xpFood = {} -- by item: true / false
local foodStock = {} -- { id, count }, in the order of your bags

local function Learn()
	local name = ns.SpellName(WELL_FED)
	fedWords = { "well fed", strlower(L.WELL_FED) }
	if name then fedWords[#fedWords + 1] = strlower(name) end
end

local function IsFedName(name)
	if type(name) ~= "string" then return false end
	local low = strlower(name)
	for _, word in ipairs(fedWords) do
		if low == word then return true end
	end
	return false
end

local function Scan()
	local buffs = ns.ReadBuffs()
	if not buffs then return end
	fed = false
	for name in pairs(buffs) do
		if IsFedName(name) then fed = true end
	end
end

-- The XP food in your bags: food whose tooltip promises Well Fed. Each item is looked at once its
-- tooltip has loaded
local function IsXPFood(id, bag, slot)
	if xpFood[id] ~= nil then return xpFood[id] end
	local getInfo = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
	local classID, subclassID = select(6, getInfo(id))
	-- Food & Drink only
	if classID ~= 0 or subclassID ~= 5 then
		xpFood[id] = false
		return false
	end
	if not (C_TooltipInfo and C_TooltipInfo.GetBagItem) then return false end
	local data = C_TooltipInfo.GetBagItem(bag, slot)
	if type(data) ~= "table" or type(data.lines) ~= "table" then return false end
	local use = strlower(ITEM_SPELL_TRIGGER_ONUSE or "Use:")
	local loaded = false
	for _, line in ipairs(data.lines) do
		local text = line.leftText
		if type(text) == "string" and not ns.IsSecret(text) then
			local low = strlower(text)
			for _, word in ipairs(fedWords) do
				if low:find(word, 1, true) then
					xpFood[id] = true
					return true
				end
			end
			-- What eating it does, written out: the game has its text
			if low:sub(1, #use) == use and #low > #use + 8 then loaded = true end
		end
	end
	-- Read before the game had loaded what it does: looked at again next time, not written off
	if loaded then xpFood[id] = false end
	return false
end

local function ScanFood()
	wipe(foodStock)
	if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo) then return end
	local byID = {}
	for bag = 0, NUM_BAG_SLOTS or 4 do
		for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			local id = type(info) == "table" and info.itemID
			if id and not ns.IsSecret(id) and IsXPFood(id, bag, slot) then
				local entry = byID[id]
				if not entry then
					entry = { id = id, count = 0 }
					byID[id] = entry
					foodStock[#foodStock + 1] = entry
				end
				local count = info.stackCount
				entry.count = entry.count + (type(count) == "number" and not ns.IsSecret(count) and count or 1)
			end
		end
	end
end

-- A dark row with a stripe of the warlock's colour on its left, the icon in a thin frame
local function Dress(b)
	b.back = b:CreateTexture(nil, "BACKGROUND")
	b.back:SetAllPoints()
	b.back:SetColorTexture(0.04, 0.03, 0.08, 0.85)
	b.stripe = b:CreateTexture(nil, "BORDER")
	b.stripe:SetPoint("TOPLEFT")
	b.stripe:SetPoint("BOTTOMLEFT")
	b.stripe:SetWidth(2)
	b.stripe:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetPoint("LEFT", 6, 0)
	b.icon:SetSize(ROW - 6, ROW - 6)
	b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b.edge = b:CreateTexture(nil, "BORDER")
	b.edge:SetPoint("TOPLEFT", b.icon, -1, 1)
	b.edge:SetPoint("BOTTOMRIGHT", b.icon, 1, -1)
	b.edge:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.9)
	b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	b.text:SetPoint("LEFT", b.icon, "RIGHT", 7, 0)
	b.text:SetShadowOffset(1, -1)
	b.text:SetShadowColor(0, 0, 0, 1)
	b.text:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
end

-- The list beside the row; a click on one eats it. Its buttons are the game's protected ones, so
-- it only changes out of combat
local menu = CreateFrame("Frame", "WarlockGodFoodMenu", UIParent)
menu:SetSize(120, ROW)
menu:Hide()
local menuRows = {}

local function MenuRow_OnEnter(self)
	if not self.itemID then return end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	if GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.itemID) end
	GameTooltip:AddLine(L.CLICK_EAT, 0.6, 0.6, 1)
	GameTooltip:Show()
end

local function MenuRow(i)
	local b = menuRows[i]
	if b then return b end
	b = CreateFrame("Button", "WarlockGodFoodMenu" .. i, menu, "SecureActionButtonTemplate")
	b:RegisterForClicks("AnyUp", "AnyDown")
	Dress(b)
	b:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
	b:SetScript("OnEnter", MenuRow_OnEnter)
	b:SetScript("OnLeave", GameTooltip_Hide)
	-- Once you've picked one the list goes (the game has eaten it by then)
	b:HookScript("OnClick", function(self, _, down)
		if not down and self.itemID and not InCombatLockdown() then menu:Hide() end
	end)
	menuRows[i] = b
	return b
end

local function FillMenu()
	local list = {}
	for _, f in ipairs(foodStock) do
		list[#list + 1] = { id = f.id, text = format("%s  x%d", ns.ItemName(f.id) or "?", f.count), icon = ns.ItemIcon(f.id) }
	end
	if #list == 0 then list[1] = { text = L.NO_XP_FOOD, icon = ns.SpellIcon(WELL_FED) } end
	local width = 120
	for i, r in ipairs(list) do
		local b = MenuRow(i)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", 0, -(i - 1) * (ROW + ROW_GAP))
		b:SetHeight(ROW)
		ThinFont(b.text, 13)
		b.text:SetText(r.text)
		b.icon:SetTexture(r.icon)
		b.icon:SetDesaturated(r.id == nil)
		b.itemID = r.id
		local use = r.id and ("item:" .. r.id) or nil
		if b:GetAttribute("type") ~= (use and "item" or nil) then b:SetAttribute("type", use and "item" or nil) end
		if b:GetAttribute("item") ~= use then b:SetAttribute("item", use) end
		width = max(width, b.text:GetStringWidth() + ROW + 24)
		b:Show()
	end
	for i = 1, #list do menuRows[i]:SetWidth(width) end
	for i = #list + 1, #menuRows do menuRows[i]:Hide() end
	menu:SetSize(width, #list * (ROW + ROW_GAP) - ROW_GAP)
end

-- The small list beside the chat: the food reminder first, then the reagents you're running low on.
-- Plain frames (they cast nothing), so they can come and go any time
local list = CreateFrame("Frame", "WarlockGodFood", UIParent)
list:SetSize(150, ROW)
list:Hide()
local ready = false -- placed: Reagents.lua may ask for an update before this file's login
-- Until you move it, beside the chat, out of the way
function list:placeDefault()
	if not ChatFrame1 then return false end
	self:ClearAllPoints()
	self:SetPoint("LEFT", ChatFrame1, "RIGHT", 25, 0)
	return true
end

local row = CreateFrame("Button", "WarlockGodFoodRow", list)
row:SetSize(150, ROW)
row:Hide()
Dress(row)
row:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
row:RegisterForClicks("LeftButtonUp")

local function ToggleMenu()
	if InCombatLockdown() then return end
	if menu:IsShown() then
		menu:Hide()
		return
	end
	ScanFood()
	FillMenu()
	menu:ClearAllPoints()
	menu:SetPoint("TOPLEFT", row, "TOPRIGHT", 4, 0)
	menu:Show()
end
ns.ToggleFoodMenu = ToggleMenu
row:SetScript("OnClick", ToggleMenu)
row:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:AddLine(L.CLICK_FOOD, 0.6, 0.6, 1)
	GameTooltip:Show()
end)
row:SetScript("OnLeave", GameTooltip_Hide)

-- A reagent running low: its icon, how many are left, and in its tooltip what it's for
local reagentRows = {}
local function Reagent_OnEnter(self)
	if not self.item then return end
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	if GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.item) end
	if self.uses then GameTooltip:AddLine(self.uses, 0.6, 0.6, 1) end
	GameTooltip:Show()
end

local function ReagentRow(i)
	local r = reagentRows[i]
	if r then return r end
	r = CreateFrame("Frame", nil, list)
	r:SetHeight(ROW)
	Dress(r)
	r:EnableMouse(true)
	r:SetScript("OnEnter", Reagent_OnEnter)
	r:SetScript("OnLeave", GameTooltip_Hide)
	reagentRows[i] = r
	return r
end

local function Missing()
	if not ns.db.food.enabled or not ns.IsWarlock() or inCombat or ns.Dead() then return false end
	local maxLevel = GetMaxPlayerLevel and GetMaxPlayerLevel() or 60
	if UnitLevel("player") >= maxLevel then return false end
	return fed == false
end

-- The reagents to show: out of combat, and not the Soul Shards while the shard count says it already
local function LowReagents()
	if ns.unlocked then
		if not ns.db.reagents.enabled then return {} end
		local name = ns.ItemName(5565) or "Infernal Stone"
		return { { item = 5565, count = 0, name = name, text = format(ns.REAGENT_TEXT.NONE, name) } }
	end
	if not ns.ReagentReminders or not ns.IsWarlock() or inCombat or ns.Dead() then return {} end
	local out = {}
	for _, r in ipairs(ns.ReagentReminders()) do
		if not (r.item == ns.SHARD and ns.db.shards.enabled) then out[#out + 1] = r end
	end
	return out
end

-- Your gear wearing out and your bags filling up (Repair.lua, the family's), under the reagents
local function RepairRows()
	if ns.unlocked then
		if not ns.db.repair.enabled then return {} end
		return { { key = "repair", icon = "Interface\\Icons\\Trade_BlackSmithing", text = format(ns.REPAIR_TEXT.WORN, 18) } }
	end
	if not ns.RepairReminders or inCombat or ns.Dead() then return {} end
	return ns.RepairReminders()
end

function ns.UpdateFood()
	if not ready then return end
	local food = ns.unlocked and ns.db.food.enabled or not ns.unlocked and Missing()
	local reagents = LowReagents()
	-- The repair and bag rows follow the reagents', each with its own picture
	for _, r in ipairs(RepairRows()) do reagents[#reagents + 1] = { icon = r.icon, text = r.text, count = 1 } end
	local width, y = 120, 0
	local shown = {}
	if food then
		row.icon:SetTexture(ns.SpellIcon(WELL_FED))
		row.icon:SetDesaturated(true)
		ThinFont(row.text, 13)
		row.text:SetText(L.FOOD_MISSING)
		shown[#shown + 1] = row
		row:Show()
	else
		row:Hide()
		if not InCombatLockdown() then menu:Hide() end
	end
	for i, r in ipairs(reagents) do
		local f = ReagentRow(i)
		f.item, f.uses = r.item, r.uses
		f.icon:SetTexture(r.icon or ns.ItemIcon(r.item))
		f.icon:SetDesaturated(r.count == 0)
		ThinFont(f.text, 13)
		f.text:SetText(r.text)
		-- None left: in a warmer colour
		if r.count == 0 then f.text:SetTextColor(1, 0.55, 0.55) else f.text:SetTextColor(TEXT[1], TEXT[2], TEXT[3]) end
		shown[#shown + 1] = f
		f:Show()
	end
	for i = #reagents + 1, #reagentRows do reagentRows[i]:Hide() end
	-- One under the other, all as long as the longest, so they stack as one block
	for _, f in ipairs(shown) do width = max(width, (f.text:GetStringWidth() or 0) + ROW + 24) end
	for _, f in ipairs(shown) do
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", 0, -y)
		f:SetWidth(width)
		y = y + ROW + ROW_GAP
	end
	list:SetSize(width, max(y - ROW_GAP, ROW))
	list:SetShown(#shown > 0)
end
-- Reagents.lua and Repair.lua say when your bags, spells or gear may have changed what to show
ns.ReagentsChanged = ns.UpdateFood
ns.RepairChanged = ns.UpdateFood

-- /warlockgod bufos: your XP food, after a fresh look at what it took for not giving XP
function ns.FoodReport()
	for id, yes in pairs(xpFood) do
		if not yes then xpFood[id] = nil end
	end
	ScanFood()
	local stock = {}
	for _, f in ipairs(foodStock) do
		stock[#stock + 1] = format("%s x%d", ns.ItemName(f.id) or ("item " .. f.id), f.count)
	end
	ns.Print(format(L.FOOD_STOCK, #stock > 0 and table.concat(stock, ", ") or L.BUFF_NONE))
end

-- For the tests
function ns.FoodState() return { list = list, row = row, menu = menu, menuRows = menuRows, reagentRows = reagentRows, fed = fed } end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		Learn()
		Scan()
		ScanFood()
		ns.Movable(list, "food", { "CENTER", "CENTER", 0, 125 }, L.FOOD_NAME)
		ready = true
		table.insert(ns.refreshers, ns.UpdateFood)
		self:RegisterUnitEvent("UNIT_AURA", "player")
		self:RegisterEvent("PLAYER_REGEN_DISABLED")
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		self:RegisterEvent("BAG_UPDATE_DELAYED")
		self:RegisterEvent("PLAYER_LEVEL_UP")
		self:RegisterEvent("PLAYER_DEAD")
		self:RegisterEvent("PLAYER_ALIVE")
		self:RegisterEvent("PLAYER_UNGHOST")
	elseif event == "UNIT_AURA" or event == "PLAYER_REGEN_ENABLED" then
		if event == "PLAYER_REGEN_ENABLED" then inCombat = false end
		Scan()
	elseif event == "PLAYER_REGEN_DISABLED" then
		inCombat = true
		-- Before the game locks its buttons for the fight
		menu:Hide()
	elseif event == "BAG_UPDATE_DELAYED" then
		ScanFood()
		if menu:IsShown() and not InCombatLockdown() then FillMenu() end
	end
	ns.UpdateFood()
end)
