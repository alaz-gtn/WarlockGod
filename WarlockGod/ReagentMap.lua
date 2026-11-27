local addonName, ns = ...

-- The vendors that sell your reagents, on the world map: only the reagents of the spells you know
-- (none with Reagent Economy), only your faction's vendors. Hover one for what it has of yours and
-- how many you carry; click it for a waypoint. Data in ReagentVendors.lua, from QuestieDB.
-- The same file in every ...God addon that spends reagents: only the addon of your character's
-- class draws them, so with every one of them on there is one pin per vendor
local CLASS_OF = { HunterGod = "HUNTER", MageGod = "MAGE", WarriorGod = "WARRIOR", PaladinGod = "PALADIN",
	RogueGod = "ROGUE", PriestGod = "PRIEST", ShamanGod = "SHAMAN", WarlockGod = "WARLOCK", DruidGod = "DRUID" }
local ROUND_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local SIZE = 16

local T = {
	OPT_MAP = "Show the vendors of my reagents on the world map",
	VENDOR = "Reagent vendor",
	HAVE = "%s: you have %d",
	CLICK = "Click: set a waypoint",
	NO_WAYPOINT = "can't set a waypoint on this map.",
}
if GetLocale() == "esES" or GetLocale() == "esMX" then
	T.OPT_MAP = "Mostrar en el mapa del mundo los vendedores de mis reactivos"
	T.VENDOR = "Vendedor de reactivos"
	T.HAVE = "%s: llevas %d"
	T.CLICK = "Clic: poner un punto de ruta"
	T.NO_WAYPOINT = "no se puede poner un punto de ruta en este mapa."
end
ns.REAGENT_MAP_TEXT = T

local pins = {} -- npc id = its pin
local shown = 0

local function IsSecret(value)
	return issecretvalue and issecretvalue(value) or false
end

local function Pins()
	return LibStub and LibStub("HereBeDragons-Pins-2.0", true)
end

local function Mine()
	local _, class = UnitClass("player")
	return class ~= nil and class == CLASS_OF[addonName]
end

local function OnMySide(v)
	if v.side == "B" then return true end
	local faction = UnitFactionGroup and UnitFactionGroup("player")
	return (faction == "Alliance" and v.side == "A") or (faction == "Horde" and v.side == "H")
end

local function ItemName(item)
	return C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(item) or GetItemInfo and (GetItemInfo(item))
		or ("item " .. item)
end

local function ItemIcon(item)
	return C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(item) or GetItemIcon and GetItemIcon(item)
		or "Interface\\Icons\\INV_Misc_Bag_10"
end

local function Count(item)
	local n = C_Item and C_Item.GetItemCount and C_Item.GetItemCount(item) or GetItemCount and GetItemCount(item)
	if IsSecret(n) then return end
	return n or 0
end

local function ZoneName(m)
	local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(m)
	return info and info.name or ""
end

-- What this vendor has of yours, in the order of Reagents.lua
local function Yours(v, wanted)
	local list = {}
	for _, item in ipairs(v.items) do
		if wanted[item] then list[#list + 1] = item end
	end
	return list
end

local function Pin_OnEnter(self)
	local v = ns.REAGENT_VENDORS[self.id]
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:AddLine(v.name, 1, 1, 1)
	GameTooltip:AddLine(T.VENDOR, 0.67, 0.83, 0.45)
	for _, item in ipairs(self.items or {}) do
		local n = Count(item)
		GameTooltip:AddLine(n and format(T.HAVE, ItemName(item), n) or ItemName(item), 0.8, 0.8, 0.8)
	end
	GameTooltip:AddLine(format("%s  %.1f, %.1f", ZoneName(v.m), v.x, v.y), 0.6, 0.6, 0.6)
	GameTooltip:AddLine(T.CLICK, 0.4, 0.7, 1)
	GameTooltip:Show()
end

local function Pin_OnClick(self)
	local v = ns.REAGENT_VENDORS[self.id]
	if TomTom and TomTom.AddWaypoint then
		TomTom:AddWaypoint(v.m, v.x / 100, v.y / 100, { title = v.name, from = addonName })
	elseif C_Map and C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(v.m) and UiMapPoint then
		C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(v.m, v.x / 100, v.y / 100))
		if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
	elseif ns.Print then
		ns.Print(T.NO_WAYPOINT)
	end
end

-- When the world map lets go of a pin, HereBeDragons hands it to UIParent, hidden: it only
-- belongs on the open world map (seen in HunterGod, a pin floating over the character)
local function Pin_OnShow(self)
	if self:GetParent() == UIParent or not (WorldMapFrame and WorldMapFrame:IsVisible()) then self:Hide() end
end

local function CreatePin(id)
	local pin = CreateFrame("Button")
	pin:SetSize(SIZE, SIZE)
	pin:Hide()
	pin.id = id
	pin.icon = pin:CreateTexture(nil, "ARTWORK")
	pin.icon:SetAllPoints()
	pin.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	-- Item icons cut round, as the game's own map icons (a clamped mask: SetMask draws stripes in Forever)
	if pin.CreateMaskTexture then
		local mask = pin:CreateMaskTexture()
		mask:SetAllPoints(pin.icon)
		mask:SetTexture(ROUND_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		pin.icon:AddMaskTexture(mask)
	end
	pin:SetScript("OnEnter", Pin_OnEnter)
	pin:SetScript("OnLeave", GameTooltip_Hide)
	pin:SetScript("OnClick", Pin_OnClick)
	pin:SetScript("OnShow", Pin_OnShow)
	return pin
end

function ns.RefreshReagentMap()
	local HBDPins = Pins()
	if not (HBDPins and ns.REAGENT_VENDORS) then return end
	HBDPins:RemoveAllWorldMapIcons(addonName)
	shown = 0
	local db = ns.db and ns.db.reagents
	if not (db and db.map ~= false and Mine() and ns.ReagentsYouSpend) then return end
	local wanted = ns.ReagentsYouSpend()
	if not next(wanted) then return end
	local showFlag = HBD_PINS_WORLDMAP_SHOW_PARENT
	for id, v in pairs(ns.REAGENT_VENDORS) do
		local yours = OnMySide(v) and Yours(v, wanted) or {}
		if #yours > 0 then
			local pin = pins[id] or CreatePin(id)
			pins[id] = pin
			pin.items = yours
			pin.icon:SetTexture(ItemIcon(yours[1]))
			HBDPins:AddWorldMapIconMap(addonName, pin, v.m, v.x / 100, v.y / 100, showFlag)
			shown = shown + 1
		end
	end
end

-- For the tests: how many vendors are on the map, and their pins
function ns.ReagentMapState() return { shown = shown, pins = pins } end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "SPELLS_CHANGED" }) do
	pcall(events.RegisterEvent, events, event) -- an event the game doesn't have would stop the file
end
events:SetScript("OnEvent", function() ns.RefreshReagentMap() end)
