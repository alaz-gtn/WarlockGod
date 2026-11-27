"""Loads the addon against a mocked WoW API (LuaJIT = Lua 5.1) and checks its behaviour.

Usage: python -I test_addon.py <WarlockGod folder> [enUS|esES]
Needs: pip install lupa
"""
import re
import sys
from pathlib import Path

from lupa.luajit21 import LuaRuntime

ADDON = Path(sys.argv[1])
LOCALE = sys.argv[2] if len(sys.argv) > 2 else "enUS"
lua = LuaRuntime(unpack_returned_tuples=True)

printed = []
lua.globals().py_print = lambda *a: printed.append(" ".join(str(x) for x in a))
lua.globals().LOCALE = LOCALE

MOCK = r'''
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring((select(i, ...))) end py_print(table.concat(t, " ")) end
format = string.format; strlower = string.lower; strupper = string.upper; max = math.max; min = math.min; abs = math.abs; floor = math.floor; ceil = math.ceil
strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
GetLocale = function() return LOCALE end
-- A value the game hides from addons
SECRET = {}
-- A hidden value that still carries what it hides, for the game's own setters to use
function Hidden(v) return { hidden = v } end
local function Unwrap(v) if type(v) == "table" and v.hidden ~= nil then return v.hidden end return v end
issecretvalue = function(v) return v == SECRET or (type(v) == "table" and v.hidden ~= nil) end

SPELLS = {
  [687] = "Demon Skin", [696] = "Demon Skin",
  [706] = "Demon Armor", [1086] = "Demon Armor", [11733] = "Demon Armor", [11734] = "Demon Armor", [11735] = "Demon Armor",
  [6201] = "Create Healthstone", [6202] = "Create Healthstone", [5699] = "Create Healthstone", [11729] = "Create Healthstone", [11730] = "Create Healthstone",
  [693] = "Create Soulstone", [20752] = "Create Soulstone", [20755] = "Create Soulstone", [20756] = "Create Soulstone", [20757] = "Create Soulstone",
  [6366] = "Create Firestone", [17951] = "Create Firestone", [17952] = "Create Firestone", [17953] = "Create Firestone",
  [2362] = "Create Spellstone", [17727] = "Create Spellstone", [17728] = "Create Spellstone",
  [758] = "Firestone", [17945] = "Firestone", [17947] = "Firestone", [17949] = "Firestone",
  [1237152] = "Spellstone", [1237156] = "Spellstone", [1237159] = "Spellstone",
  [688] = "Summon Imp", [697] = "Summon Voidwalker", [712] = "Summon Succubus", [713] = "Summon Incubus", [691] = "Summon Felhunter",
  [18789] = "Burning Shadow", [18790] = "Fel Stamina", [18791] = "Touch of Fire", [18792] = "Fel Energy",
  [425464] = "Demonic Pact", [19028] = "Soul Link", [25228] = "Soul Link", [755] = "Health Funnel",
  [686] = "Shadow Bolt", [348] = "Immolate", [172] = "Corruption", [689] = "Drain Life", [5782] = "Fear",
  [17941] = "Shadow Trance", [440873] = "Decimation", [1242853] = "Soul Harvest", [427714] = "Backdraft",
  [19705] = "Well Fed",
  [18094] = "Nightfall", [440870] = "Decimation", [437032] = "Soul Harvest", [427713] = "Backdraft",
  [2383] = "Find Herbs", [2580] = "Find Minerals",
  [1293816] = "Shadow", [426311] = "Flame", [426316] = "Shadow and Flame", [1293817] = "Conflagrate", [17877] = "Shadowburn",
  [5697] = "Unending Breath", [5019] = "Shoot", [1122] = "Inferno", [18540] = "Ritual of Doom", [1225503] = "Reagent Economy", [11426] = "Ice Barrier",
  [6229] = "Shadow Ward", [11739] = "Shadow Ward", [7812] = "Sacrifice", [19438] = "Sacrifice", [17543] = "Fire Protection",
}
for name, ids in pairs({
  ["Corruption"] = { 172, 6222, 6223, 7648, 11671, 11672, 25311 },
  ["Immolate"] = { 348, 707, 1094, 2941, 11665, 11667, 11668, 25309 },
  ["Bane of Agony"] = { 980, 1014, 6217, 11711, 11712, 11713 }, ["Bane of Doom"] = { 603 }, ["Bane of Havoc"] = { 1225228 },
  ["Curse of Weakness"] = { 702, 1108, 6205, 7646, 11707, 11708 }, ["Siphon Life"] = { 18265, 18879, 18880, 18881 },
  ["Fear"] = { 5782, 6213, 6215 }, ["Banish"] = { 710, 18647 }, ["Howl of Terror"] = { 5484, 17928 },
  ["Death Coil"] = { 6789, 17925, 17926 }, ["Shadow Vulnerability"] = { 17794 }, ["Improved Shadow Bolt"] = { 17793 },
  ["Demonic Brand"] = { 1293695, 1293696 }, ["Amplify Curse"] = { 18288 }, ["Fel Domination"] = { 18708 },
  ["Soulstone Resurrection"] = { 20707, 20762 }, ["Spell Lock"] = { 19244, 19647 },
}) do for _, id in ipairs(ids) do SPELLS[id] = name end end
-- Spell cooldowns, by spell: what C_Spell.GetSpellCooldown hands over
COOLDOWNS = {}
-- Pet spells your demon knows; your target's cast and channel
IsSpellKnown = function(id, pet) if pet then return G.petSpells[id] or false end return G.known[id] or false end
UnitCastingInfo = function() local c = G.cast if c then return c[1], "", 1, 0, 1000, false, 1, c[2], 133 end end
UnitChannelInfo = function() local c = G.channel if c then return c[1], "", 1, 0, 1000, false, c[2], 5143 end end
-- Your gear's durability by slot { now, max }, a merchant that repairs, free bag slots by bag
GetInventoryItemDurability = function(slot) local d = G.durability[slot] if d then return d[1], d[2] end end
CanMerchantRepair = function() return G.canRepair end
-- Your group: party1-4 that exist, and their buffs by unit
IsInRaid = function() return false end
UnitName = function(u) return u end
UnitIsConnected = function() return true end
UnitIsUnit = function(a, b) return a == b or (a == "nameplate1" and b == "target") end
-- How far each spell reaches
REACH = { Shoot = 30, ["Shadow Bolt"] = 30, Immolate = 30, Corruption = 30, ["Drain Life"] = 20, Fear = 20 }
ITEM_NAMES = { [6265] = "Soul Shard", [5512] = "Minor Healthstone", [5509] = "Healthstone", [5232] = "Minor Soulstone",
  [16892] = "Lesser Soulstone", [5522] = "Spellstone", [13699] = "Firestone", [1254] = "Lesser Firestone",
  [5565] = "Infernal Stone", [16583] = "Demonic Figurine" }

-- Game state the tests change
G = { class = "WARLOCK", level = 20, known = {}, auras = {}, auraTimes = {}, secret = false, combat = false,
      now = 100, timers = {}, target = nil, dist = 27, secretRange = false, uncached = {}, items = {},
      group = false, threat = nil, plate = nil, speed = {}, cursor = { 0, 100 }, dead = false, bags = {},
      epoch = 1000000, mainHand = 900, weaponEnchant = false, enchantMs = 0, itemCooldowns = {},
      pet = false, petDead = false, petHealth = 100, petHealthMax = 100, secretPetHealth = false, mounted = false,
      tipsLoading = false }
G.petSpells = {}
G.durability, G.freeSlots, G.party, G.partyAuras = {}, {}, {}, {}
PixelUtil = { GetPixelToUIUnitFactor = function() return 0.5 end }
C_CurveUtil = { CreateCurve = function()
  local c = { points = {} }
  function c:SetType() end
  function c:ClearPoints() self.points = {} end
  function c:AddPoint(x, y) table.insert(self.points, { x, y }) end
  return c
end }
local function EvalCurve(c, x)
  local p = c.points
  if x <= p[1][1] then return p[1][2] end
  for i = 2, #p do if x <= p[i][1] then local a, b = p[i - 1], p[i] return a[2] + (b[2] - a[2]) * (x - a[1]) / (b[1] - a[1]) end end
  return p[#p][2]
end
-- The demon's health: hidden in combat in Forever, but the game hands it on through a curve
UnitHealth = function(u) if u == "pet" and G.secretPetHealth then return SECRET end return G.petHealth end
UnitHealthMax = function(u) if u == "pet" and G.secretPetHealth then return SECRET end return G.petHealthMax end
UnitHealthPercent = function(_, _, curve)
  local share = G.petHealth / G.petHealthMax
  local v = curve and EvalCurve(curve, share) or share
  if G.secretPetHealth then return Hidden(v) end
  return v
end
time = function() return G.epoch end
GetInventoryItemID = function(_, slot) if slot == 16 then return G.mainHand elseif slot == 18 then return G.wand end end
GetInventoryItemTexture = function(_, slot) local id = GetInventoryItemID("player", slot) return id and id * 10 end
UnitRangedDamage = function() return G.wandSpeed end
GetWeaponEnchantInfo = function() return G.weaponEnchant, G.enchantMs end
NUM_BAG_SLOTS = 4
FOODS = { [700] = "Roast Raptor", [701] = "Freshly Baked Bread" }
ITEM_SPELL_TRIGGER_ONUSE = "Use:"
FOOD_TIPS = {
  [700] = "Use: Restores 1392 health over 27 sec. If you spend at least 10 seconds eating you will become well fed and gain 12 Stamina and Spirit for 15 min.",
  [701] = "Use: Restores 552 health over 24 sec. Must remain seated while eating.",
}
C_Container = {
  GetContainerNumSlots = function(bag) return G.bags[bag] and #G.bags[bag] or 0 end,
  GetContainerItemInfo = function(bag, slot) local it = G.bags[bag] and G.bags[bag][slot] if it then return { itemID = it[1], stackCount = it[2] } end end,
  GetContainerNumFreeSlots = function(bag) return G.freeSlots[bag] or 4, 0 end,
  GetItemCooldown = function(item) local cd = G.itemCooldowns[item] if cd then return cd[1], cd[2], 1 end return 0, 0, 1 end,
}
C_TooltipInfo = { GetBagItem = function(bag, slot)
  local it = G.bags[bag] and G.bags[bag][slot]
  if not it then return end
  if G.tipsLoading then return { lines = { { leftText = FOODS[it[1]] } } } end
  return { lines = { { leftText = FOODS[it[1]] }, { leftText = FOOD_TIPS[it[1]] } } }
end }

UnitClass = function() return "Class", G.class end
UnitLevel = function() return G.level end
GetMaxPlayerLevel = function() return 60 end
UnitRace = function() return "Human", "Human" end
GetTime = function() return G.now end
IsPlayerSpell = function(id) return G.known[id] or false end
local function KnownByName(name) for id in pairs(G.known) do if G.known[id] and SPELLS[id] == name then return true end end end
PASSIVE = {}
C_Spell = {
  GetSpellName = function(id) return SPELLS[id] end,
  IsSpellPassive = function(id) return PASSIVE[id] or false end,
  GetSpellTexture = function(id) return id end,
  GetSpellInfo = function(name) if KnownByName(name) then return { name = name, maxRange = REACH[name] } end end,
  GetSpellCooldown = function(id) return COOLDOWNS[id] end,
  GetSpellCooldownDuration = function(id)
    local cd = COOLDOWNS[id]
    return { IsZero = function() if cd and cd.secretZero then return SECRET end return not (cd and cd.isActive and not cd.gcd) end }
  end,
  IsSpellInRange = function(spell)
    if G.secretRange then return SECRET end
    if REACH[spell] and KnownByName(spell) then return G.dist <= REACH[spell] end
  end,
}
C_UnitAuras = { GetAuraDataByIndex = function(unit, i)
  if unit ~= "player" then local a = G.partyAuras[unit] and G.partyAuras[unit][i] if a then return { name = a } end return end
  if G.secret then return SECRET end
  local name = G.auras[i] if not name then return end
  local t = G.auraTimes[name]
  return { name = name, expirationTime = t and t[1] or 0, duration = t and t[2] or 0, spellId = t and t[3] } end }
C_Secrets = { ShouldAurasBeSecret = function() return G.secret end }
C_NamePlate = { GetNamePlateForUnit = function() return G.plate end }
UnitExists = function(u) if u == "target" then return G.target ~= nil end if u == "pet" then return G.pet end
  local n = u:match("^party(%d)$") if n then return G.party[tonumber(n)] or false end return true end
UnitCanAttack = function() return G.target and G.target.hostile end
UnitIsDead = function(u) if u == "pet" then return G.petDead end return false end
UnitIsDeadOrGhost = function() return G.dead end
UnitOnTaxi = function() return G.taxi end
IsMounted = function() return G.mounted end
UnitAffectingCombat = function() return G.combat end
InCombatLockdown = function() return G.combat end
CheckInteractDistance = function(_, i) if G.secretRange then return SECRET end return G.dist <= (i == 3 and 8 or 28) end
GetUnitSpeed = function(u) return G.speed[u] or 0 end
IsInGroup = function() return G.group end
UnitGetTotalAbsorbs = function() return G.absorb end
UnitDetailedThreatSituation = function() if G.threat then return G.threat[1], G.threat[2], G.threat[3], G.threat[4] end end
C_Item = {
  GetItemInfo = function(id) if ITEM_YARDS[id] then return "range item" end end,
  IsItemDataCachedByID = function(id) return not G.uncached[id] end,
  IsItemInRange = function(id)
    if G.secretRange then return SECRET end
    if G.uncached[id] or not ITEM_YARDS[id] then return nil end
    return G.dist <= ITEM_YARDS[id]
  end,
  RequestLoadItemDataByID = function() end,
  GetItemCount = function(id) return G.items[id] or 0 end,
  GetItemNameByID = function(id) return FOODS[id] or ITEM_NAMES[id] or "item " .. id end,
  GetItemIconByID = function(id) return id * 10 end,
  GetItemInfoInstant = function(id) if FOODS[id] then return id, "t", "s", "", 0, 0, 5 end return id, "t", "s", "", 0, 15, 0 end,
}
ITEM_YARDS = {}
function BuildItemYards(ns) for _, step in ipairs(ns.RANGE_ITEMS) do for _, id in ipairs(step[2]) do ITEM_YARDS[id] = step[1] end end end
C_Timer = { After = function(t, f) table.insert(G.timers, f) end, NewTicker = function(_, f) TICKERS = TICKERS or {} table.insert(TICKERS, f) return { Cancel = function() end } end }
function RunTimers() local t = G.timers G.timers = {} for _, f in ipairs(t) do f() end end
GetCursorPosition = function() return G.cursor[1], G.cursor[2] end
-- Inside a dungeon or out in the world, and the minimap's tracking list: { name, spellID, active }
-- A vendor's goods
MERCHANT = {}
GetMerchantNumItems = function() return #MERCHANT end
GetMerchantItemID = function(i) return MERCHANT[i] end
IsInInstance = function() return G.instance, G.instance and "party" or "none" end
G.tracking = {}
C_Minimap = {
  GetNumTrackingTypes = function() return #G.tracking end,
  GetTrackingInfo = function(i) return G.tracking[i] end,
}

-- Frames and textures: the methods the tests look at keep their state, the rest do nothing
local function Texture() local t = { shown = true } setmetatable(t, { __index = function(_, k) return function(self, ...)
  if k == "SetShown" then self.shown = (...) and true or false
  elseif k == "Hide" then self.shown = false elseif k == "Show" then self.shown = true
  elseif k == "IsShown" then return self.shown
  elseif k == "SetTexture" then self.tex = ... elseif k == "SetDesaturated" then self.desat = ...
  elseif k == "SetColorTexture" or k == "SetTextColor" or k == "SetVertexColor" then self.color = { ... }
  elseif k == "SetText" then
    -- As in the game: a text with no font can't be written
    if rawget(self, "isFont") and not rawget(self, "font") then error("FontString:SetText(): Font not set", 2) end
    self.text = ...
  elseif k == "GetStringWidth" then return #tostring(self.text or "") * 6
  elseif k == "SetFormattedText" then
    if rawget(self, "isFont") and not rawget(self, "font") then error("FontString:SetFormattedText(): Font not set", 2) end
    local args = { ... }
    for i = 2, #args do if issecretvalue(args[i]) then self.hiddenText = true end args[i] = Unwrap(args[i]) end
    self.text = format(unpack(args))
  elseif k == "SetFont" then self.font = { ... }
  elseif k == "SetFontObject" then local o = ... self.fontObject = o self.font = o and o.font self.color = nil
  elseif k == "GetTextColor" then if rawget(self, "color") then return unpack(self.color) end
  elseif k == "SetPoint" then self.points = rawget(self, "points") or {} table.insert(self.points, { ... })
  elseif k == "ClearAllPoints" then self.points = {}
  elseif k == "SetSize" then self.size = { ... }
  elseif k == "SetAlpha" then self.alpha = ...
  elseif k == "GetText" then return self.text
  elseif k == "CreateAnimationGroup" then return CreateFrame("Frame") end
end end }) return t end
NAMED = {}
-- Secure frames, and what an addon tried to do to them in a fight
SECURE, BLOCKED = {}, {}
function Protected(frame)
  for _, s in ipairs(SECURE) do
    local p = s
    while p do
      if rawequal(p, frame) then return true end
      p = rawget(p, "parent")
    end
  end
  return false
end

function CreateFrame(kind, name, parent, template)
  local f = { scripts = {}, events = {}, kind = kind, parent = parent, template = template, shown = true, attrs = {}, width = 100 }
  setmetatable(f, { __index = function(_, k)
    if k:match("^Create") then return function() return CreateFrame("Frame") end end
    if k:match("^%u") then return function() end end
  end })
  function f:SetScript(n, fn) self.scripts[n] = fn end
  function f:GetScript(n) return self.scripts[n] end
  function f:RegisterEvent(e) self.events[e] = true end
  function f:RegisterUnitEvent(e) self.events[e] = true end
  function f:UnregisterEvent(e) self.events[e] = nil end
  function f:CreateTexture() return Texture() end
  -- With a template it has a font; without one it has none until it's given one
  function f:CreateFontString(_, _, template) local t = Texture() t.isFont = true if template then t.font = { template } end return t end
  function f:SetAlpha(a) self.alpha = Unwrap(a) self.hiddenAlpha = issecretvalue(a) end
  -- The game sets it from a boolean it may keep from the addon: yes when true, no when false
  function f:SetAlphaFromBoolean(b, yes, no) if Unwrap(b) then self.alpha = yes else self.alpha = no end end
  -- Showing and hiding run the hooks, as the game's OnShow and OnHide do
  local function Became(self, on)
    local was = self.shown
    self.shown = on and true or false
    if was ~= self.shown and self.hooks then
      local hook = self.hooks[self.shown and "OnShow" or "OnHide"]
      if hook then hook(self) end
    end
  end
  function f:SetShown(v) Became(self, v) end
  function f:Hide() Became(self, false) end function f:Show() Became(self, true) end
  function f:IsShown() return self.shown end
  function f:IsVisible() return self.shown end
  function f:SetChecked(v) self.checked = v and true or false end
  function f:GetChecked() return self.checked end
  function f:GetFrameLevel() return 1 end
  function f:GetParent() return self.parent end
  function f:SetParent(p) self.parent = p end
  function f:SetPoint(...) self.point = { ... } end
  function f:GetPoint() local p = self.point return p[1], p[2], p[3], p[4], p[5] end
  function f:SetSize(w, h) self.width, self.height = w, h end
  function f:SetWidth(w) self.width = w end
  function f:SetHeight(h) self.height = h end
  function f:HookScript(n, fn) self.hooks = self.hooks or {} self.hooks[n] = fn end
  function f:GetWidth() return self.width end
  function f:GetHeight() return self.height end
  function f:GetCenter() return 0, 0 end
  function f:GetEffectiveScale() return 1 end
  function f:SetText(t) self.text = t end
  function f:GetText() return self.text end
  function f:SetStatusBarColor(...) self.barColor = { ... } end
  function f:SetValue(v) self.value = Unwrap(v) self.hiddenValue = issecretvalue(v) end
  function f:SetMinMaxValues(a, b) self.minmax = { Unwrap(a), Unwrap(b) } end
  function f:SetAttribute(k, v) self.attrs[k] = v end
  function f:GetAttribute(k) return self.attrs[k] end
  function f:SetScale(s) self.scale = s end
  function f:Play() self.playing = true end
  function f:Stop() self.playing = false end
  -- Forever's aura container: one slot, whose button the addon dresses; the game plays what it's given
  if kind == "AuraContainer" then
    function f:SetEnabled(v) self.enabled = v end
    function f:SetUnit(u) self.unit = u end
    function f:AddAuraSlot(key, filter, options)
      self.slot = { key = key, filter = filter, options = options }
      local button = CreateFrame("Button", nil, self)
      button.shownAnims, button.assignedAnims = {}, {}
      function button:AddAuraShownAnimation(g) table.insert(self.shownAnims, g) end
      function button:AddAuraAssignedAnimation(g) table.insert(self.assignedAnims, g) end
      function button:SetDurationText(text, opts) self.durationText = { text = text, options = opts } end
      self.button = button
      options.initializeFrame(button)
    end
    function f:AddAuraGroup(key, filter, options)
      if G.refuseFilter == filter then error("bad filter") end
      self.group = { key = key, filter = filter, options = options }
      local button = CreateFrame("Button", nil, self)
      function button:SetIcon(t) self.iconTexture = t end
      function button:SetDurationCooldown(c) self.cooldown = c end
      self.groupButton = button
      options.initializeFrame(button)
    end
    function f:SetAuraGroupCandidateFilters(key, filters) self.group.options.candidateFilters = filters end
    function f:SetAuraGroupLayout(key, layout) self.layout = layout end
  end
  FRAMES = FRAMES or {} table.insert(FRAMES, f)
  if name then NAMED[name] = f end
  -- As in the game: in a fight a secure button, and any frame holding one, can't be shown, hidden,
  -- moved or changed by an addon (the game blocks it). Recorded in BLOCKED, the tests fail on it
  if type(template) == "string" and template:find("Secure") then SECURE[#SECURE + 1] = f end
  for _, method in ipairs({ "Show", "Hide", "SetShown", "SetAttribute", "SetPoint", "ClearAllPoints", "SetParent", "SetSize" }) do
    local orig = rawget(f, method)
    if orig then
      f[method] = function(self, ...)
        if InCombatLockdown() and not ENTERING_COMBAT and Protected(self) then
          local info = debug.getinfo(2, "Sl")
          if info and info.source:sub(1, 1) == "@" then
            BLOCKED[#BLOCKED + 1] = info.source:sub(2) .. ":" .. tostring(info.currentline) .. " " .. method .. " on " .. tostring(name or "a secure frame")
          end
        end
        return orig(self, ...)
      end
    end
  end
  return f
end
-- Font objects: one per name, the last font set on it counts
FONT_OBJECTS = {}
function CreateFont(name)
  local f = { name = name }
  function f:SetFont(...) self.font = { ... } end
  function f:GetFont() return unpack(self.font) end
  FONT_OBJECTS[name] = f
  return f
end
UIParent = CreateFrame("Frame")
Minimap = CreateFrame("Frame")
ChatFrame1 = CreateFrame("Frame")
Minimap.width = 140
GameFontNormal = { GetFont = function() return "font" end }
UISpecialFrames = {}
CustomAuraContainerAuraProcessingPolicy = { None = 0 }
Enum = { NumericRuleFormatRounding = { Up = 2 } }
C_StringUtil = { CreateNumericRuleFormatter = function()
  return { SetBreakpoints = function(self, rules) self.rules = rules end }
end }
ColorPickerFrame = { SetupColorPickerAndShow = function(self, info) COLOR_INFO = info end, GetColorRGB = function() return 0, 0, 1 end }
SOUNDKIT = { IG_MAINMENU_OPTION_CHECKBOX_ON = 1 }
PlaySound = function() end
TOOLTIP = {}
GameTooltip = { SetOwner = function() TOOLTIP = {} end, AddLine = function(_, s) table.insert(TOOLTIP, s) end, Show = function() end,
  SetItemByID = function(_, id) table.insert(TOOLTIP, "item " .. id) end }
GameTooltip_Hide = function() end
SlashCmdList = {}
-- Talent reset: the trainer's options, the game's price dialog, the gold and the server's clock
GOSSIP_OPTIONS = {}
C_GossipInfo = { GetOptions = function() return GOSSIP_OPTIONS end, SelectOption = function() end }
GossipFrame = CreateFrame("Frame")
POPUPS = {}
StaticPopup_FindVisible = function(which) return POPUPS[which] end
GetMoney = function() return G.money or 0 end
GetServerTime = function() return G.server or 0 end
date = os.date
ConfirmTalentWipe = function() end
hooksecurefunc = function(a, b, c)
  local t, key, fn = _G, a, b
  if type(a) == "table" then t, key, fn = a, b, c end
  local orig = t[key]
  t[key] = function(...) local r = { orig(...) } fn(...) return unpack(r) end
end

function Same(a, b) return rawequal(a, b) end
function Fire(event, ...) for _, f in ipairs(FRAMES) do if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end end end
function Tick() for _, f in ipairs(TICKERS or {}) do f() end end
'''
lua.execute(MOCK)

MOCK_GUARDS = '''
-- PLAYER_REGEN_DISABLED is the last moment the game lets an addon change its secure buttons
ENTERING_COMBAT = false
local fire = Fire
Fire = function(event, ...)
  ENTERING_COMBAT = event == "PLAYER_REGEN_DISABLED"
  fire(event, ...)
  ENTERING_COMBAT = false
end
-- Globals an addon file leaves behind: only its own name's, SLASH_ and BINDING_ are fine
LEAKS = {}
setmetatable(_G, { __newindex = function(t, k, v)
  local info = debug.getinfo(2, "Sl")
  if info and info.source:sub(1, 1) == "@" and type(k) == "string" and not k:find("^WarlockGod")
    and not k:find("^SLASH_") and not k:find("^BINDING_") then
    LEAKS[#LEAKS + 1] = info.source:sub(2) .. ":" .. tostring(info.currentline) .. " " .. k
  end
  rawset(t, k, v)
end })
'''
lua.execute(MOCK_GUARDS)

load = lua.eval('function(src, name) return assert(loadstring(src, "@" .. name)) end')
ns = lua.table()
toc = Path(ADDON, "WarlockGod.toc").read_text(encoding="utf-8")
for fname in re.findall(r"^(\w+\.lua)$", toc, re.M):
    load(Path(ADDON, fname).read_text(encoding="utf-8"), fname)("WarlockGod", ns)

G = lua.globals()
S = G.G  # the game state
G.BuildItemYards(ns)
L = ns.L
es = LOCALE in ("esES", "esMX")
fails = []


def check(cond, msg):
    print(("OK   " if cond else "FAIL ") + msg)
    if not cond:
        fails.append(msg)


def slash(arg):
    printed.clear()
    G.SlashCmdList.WARLOCKGOD(arg)
    return list(printed)


def know(*ids, on=True):
    for i in ids:
        S.known[i] = on
    G.Fire("SPELLS_CHANGED")


def auras(**times):
    """auras(name=(seconds left, duration[, spell id])) puts those buffs on you"""
    S.auras = lua.table(*[n.replace("_", " ") for n in times])
    S.auraTimes = lua.table()
    for n, (left, *rest) in times.items():
        S.auraTimes[n.replace("_", " ")] = lua.table(S.now + left if left else 0, *rest)
    G.Fire("UNIT_AURA", "player")


def items(**counts):
    """items(i6265=3) sets what you carry"""
    S["items"] = lua.table()
    for k, v in counts.items():
        S["items"][int(k[1:])] = v
    G.Fire("BAG_UPDATE_DELAYED")


group, members = ns.RemindersState()


def row():
    """The reminders showing, left to right: (key, icon, grey, text)"""
    shown = [m for m in members.values() if m.frame.shown]
    shown.sort(key=lambda m: m.x if m.x is not None else 0)
    return [(m.key, m.frame.icon.tex, bool(m.frame.icon.desat), m.frame.text.text or "") for m in shown]


def keys():
    return [r[0] for r in row()]


def click(key):
    """What a click on that reminder does: (type, spell or macro or item, unit), or None"""
    m = next(m for m in members.values() if m.key == key)
    c = m.click
    if not c.shown:
        return None
    return (c.attrs["type1"], c.attrs["spell"] or c.attrs["macrotext"] or c.attrs["item"], c.attrs["unit"])


# ---------------------------------------------------------------- Login: a level 20 warlock
S.known = lua.table()
for i in (687, 706, 688, 697, 6201, 686, 348, 172, 689, 5782):
    S.known[i] = True
G.Fire("ADDON_LOADED", "WarlockGod")
G.Fire("PLAYER_LOGIN")
db = G.WarlockGodDB
check(db.buffs.enabled and db.range.enabled and db.demon.missing and db.shards.enabled, "settings filled in from the defaults")
auras()
check(keys() == ["demon", "armor"], f"no demon and no armor: both, the demon first: {row()}")
check(row()[0][1] == 697 and row()[0][2] and row()[1][1] == 706 and row()[1][2],
      f"Voidwalker (the last one learned) and Demon Armor (not Skin), grey: {row()}")
check(click("demon") == ("spell", "Summon Voidwalker", "player") and click("armor") == ("spell", "Demon Armor", "player"),
      f"a click summons it or casts it: {click('demon')}, {click('armor')}")
xs = [m.x for m in members.values() if m.frame.shown]
check(sorted(xs) == [-25, 25], f"centred on the row's point: {sorted(xs)}")
out = slash("")
check(G.NAMED["WarlockGodOptions"] is not None and G.NAMED["WarlockGodOptions"].shown, "/warlockgod opens the options")
slash("")

# ---------------------------------------------------------------- Armor
auras(Demon_Armor=(1700, 1800))
check(keys() == ["demon"], f"Demon Armor on: only the demon left: {keys()}")
S.now = S.now + 1620  # 80 s left
auras(Demon_Armor=(80, 1800))
check(row()[1] == ("armor", 706, False, "1:20") and click("armor")[1] == "Demon Armor",
      f"its last 2 minutes: in colour with its time, a click casts it again: {row()}")
auras(Demon_Skin=(1700, 1800))
check(keys() == ["demon"], "an old Demon Skin counts too")
# In combat Forever hides your buffs; what you cast keeps the count
auras()
S.combat = True
G.Fire("PLAYER_REGEN_DISABLED")
check(keys() == ["demon"] and click("demon") is None, f"in a fight: no armor reminder, and no button to click: {keys()}")
S.secret = True
G.Fire("UNIT_AURA", "player")
db.buffs.combat = True
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 706)
check(ns.BuffsState().armorEnds == S.now + 1800 and keys() == ["demon"], "Demon Armor cast in a fight: taken as on for half an hour")
db.buffs.combat = False
S.secret = False
S.combat = False
G.Fire("PLAYER_REGEN_ENABLED")
check(keys() == ["demon", "armor"] and click("armor") is not None, f"the fight over: your buffs say it isn't on: {keys()}")
auras(Demon_Armor=(1800, 1800))

# ---------------------------------------------------------------- The demon
S.pet = True
G.Fire("UNIT_PET", "player")
check(keys() == [], f"a demon out: nothing to remind: {keys()}")
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 688)
check(db.lastDemon == "imp", "the Imp summoned: remembered")
S.pet = False
G.Fire("UNIT_PET", "player")
check(row()[0][1] == 688 and click("demon")[1] == "Summon Imp", f"gone: the reminder summons the Imp now: {row()}")
S.mounted = True
G.Tick()
check(keys() == [], "mounted: no reminder")
S.mounted = False
G.Tick()
db.demon.choice = "voidwalker"
ns.UpdateDemon()
check(click("demon")[1] == "Summon Voidwalker", "the Voidwalker chosen in the options")
db.demon.choice = "felhunter"
ns.UpdateDemon()
check(click("demon")[1] == "Summon Imp", "a demon you don't know yet: the last one summoned")
db.demon.choice = "auto"
S.combat = True
G.Fire("PLAYER_REGEN_DISABLED")
S.pet, S.petDead = True, True
G.Tick()
check(keys() == ["demon"] and click("demon") is None, "the demon died in a fight: the reminder shows, without its button")
S.combat, S.petDead, S.pet = False, False, False
G.Fire("PLAYER_REGEN_ENABLED")
# Demonic Sacrifice: its buff instead of a demon
auras(Demon_Armor=(1800, 1800), Burning_Shadow=(7000, 7200))
check(keys() == [], "Demonic Sacrifice's buff on: no demon wanted")
know(425464)
check(keys() == ["demon"], "with Demonic Pact you want both")
know(425464, on=False)
auras(Demon_Armor=(1800, 1800))
# Soul Link
know(19028)
S.pet = True
G.Fire("UNIT_PET", "player")
check(keys() == ["soulLink"] and click("soulLink") == ("spell", "Soul Link", "player"), f"Soul Link known and not on: {keys()}")
auras(Demon_Armor=(1800, 1800), Soul_Link=(0, 0))
check(keys() == [], "on: nothing")
db.demon.soulLink = False
auras(Demon_Armor=(1800, 1800))
check(keys() == [], "the option off: nothing")
db.demon.soulLink = True
auras(Demon_Armor=(1800, 1800), Soul_Link=(0, 0))

# ---------------------------------------------------------------- Soul shards
counter = ns.BuffsState().counter
items(i6265=0)
check(counter.shown and counter.text.text == 0 and counter.mood == "low", f"no shards: 0, red: {counter.text.text}")
items(i6265=5)
check(counter.text.text == 5 and counter.mood == "fine", "five: fine")
items(i6265=25)
check(counter.mood == "many", "25: orange, over your 20")
db.shards.always = False
items(i6265=5)
check(not counter.shown, "only when short or too many: hidden at five")
items(i6265=1)
check(counter.shown and counter.mood == "low", "and back at one")
db.shards.always = True

# ---------------------------------------------------------------- Healthstone and soulstone
items(i6265=3)
check(keys() == ["healthstone"] and row()[0][1] == 55090 and click("healthstone") == ("spell", "Create Healthstone", "player"),
      f"Create Healthstone known, none in your bags: a click makes one: {row()}")
items(i6265=3, i5512=1)
check(keys() == [], "a Minor Healthstone in your bags: nothing")
items(i6265=0)
check(keys() == [], "no shards: no reminder to make one")
know(693)
items(i6265=2, i5512=1)
check(keys() == ["soulstone"] and click("soulstone")[1] == "Create Soulstone", f"Create Soulstone: make one: {keys()}")
items(i6265=2, i5512=1, i5232=1)
check(row() == [("soulstone", 52320, False, L.SOULSTONE_READY)]
      and click("soulstone") == ("macro", "/use [@target,help,nodead][@player] item:5232", None),
      f"one in your bags, ready: a click uses it on your friendly target or on you: {row()}")
S.itemCooldowns[5232] = lua.table(S.now - 60, 1800)
ns.UpdateBuffs()
check(keys() == [], "used in the last half hour: nothing")
S.itemCooldowns[5232] = lua.table(S.now - 1900, 1800)
ns.UpdateBuffs()
check(keys() == ["soulstone"], "the half hour over: ready again")
db.stones.soulstoneUse = False
ns.UpdateBuffs()
check(keys() == [], "only to make it: nothing while you carry one")
db.stones.soulstoneUse = True
items(i6265=2, i5512=1)

# ---------------------------------------------------------------- Firestone and Spellstone on the weapon
know(2362, 6366)
items(i6265=2, i5512=1, i5232=1)
check(keys() == ["weapon", "soulstone"] and row()[0][1] == 2362 and row()[0][2]
      and click("weapon") == ("spell", "Create Spellstone", "player"),
      f"no stone on your weapon and none in your bags: make the Spellstone: {row()}")
items(i6265=2, i5512=1, i5232=1, i5522=1)
check(row()[0] == ("weapon", 55220, True, "") and click("weapon") == ("macro", "/use item:5522\n/use 16", None),
      f"a Spellstone in your bags: a click puts it on your main hand: {row()[0]}")
S.weaponEnchant, S.enchantMs = True, 3000000
ns.UpdateBuffs()
check(keys() == ["soulstone"], "on your weapon: nothing")
S.enchantMs = 90000
ns.UpdateBuffs()
check(row()[0] == ("weapon", 55220, False, "1:30"), f"its last 2 minutes: in colour, with its time: {row()[0]}")
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 758)
G.RunTimers()
check(db.lastWeaponStone == "firestone" and click("weapon")[1] == "Create Firestone",
      "a Firestone used: that's the one it wants now (none in your bags: make it)")
db.stones.weaponChoice = "spellstone"
ns.UpdateBuffs()
check(click("weapon")[1] == "/use item:5522\n/use 16", "the Spellstone chosen in the options")
db.stones.weaponChoice = "auto"
items(i6265=0, i5512=1, i5232=1)
check(row()[0][0] == "weapon" and click("weapon") is None, "running out with no stone and no shard: its time, nothing to click")
S.weaponEnchant = False
S.mainHand = None
items(i6265=2, i5512=1, i5232=1)
check("weapon" not in keys(), "no weapon in your hand: nothing")
S.mainHand = 900
S.weaponEnchant, S.enchantMs = True, 3000000
S.itemCooldowns[5232] = lua.table(S.now, 1800)
ns.UpdateBuffs()
check(keys() == [], "all done: nothing")
out = slash("bufos" if es else "buffs")
check(len(out) == 3 and str(L.STONE_HAVE % ("Minor Healthstone", 1)) in out[0] and "2." in out[0],
      f"/warlockgod buffs: what it sees: {out}")

# ---------------------------------------------------------------- Herbalism or Mining: their tracking
def tracking(*rows):
    S.tracking = lua.table(*[lua.table(name=n, spellID=i, active=a) for n, i, a in rows])
    G.Fire("MINIMAP_UPDATE_TRACKING")


know(2383)
tracking(("Find Herbs", 2383, False))
check(keys() == ["gather"] and row()[0][1] == 2383 and click("gather") == ("spell", "Find Herbs", "player"),
      f"a herbalist without Find Herbs on, out in the world: a click puts it on: {row()}")
tracking(("Find Herbs", 2383, True))
check(keys() == [], "on: nothing")
know(2580)
tracking(("Find Herbs", 2383, False), ("Find Minerals", 2580, True))
check(keys() == [], "both professions: either one counts")
tracking(("Find Herbs", 2383, False), ("Find Minerals", 2580, False))
check(click("gather")[1] == "Find Minerals", "neither: the one you had on last")
S.instance = True
G.Fire("PLAYER_ENTERING_WORLD")
check(keys() == [], "in a dungeon: nothing")
S.instance = False
S.taxi = True
G.Fire("ZONE_CHANGED_NEW_AREA")
check(keys() == [], "on a flight: nothing")
S.taxi = False
db.gather.enabled = False
G.Fire("MINIMAP_UPDATE_TRACKING")
check(keys() == [], "the option off: nothing")
db.gather.enabled = True
tracking(("Find Herbs", 2383, False), ("Find Minerals", 2580, True))

# ---------------------------------------------------------------- Food
fs = ns.FoodState()
food = fs.row
check(food.shown and food.text.text == L.FOOD_MISSING, "not Well Fed: the small food reminder")
check(fs.list.shown and fs.list.point[1] == "LEFT" and G.Same(fs.list.point[2], G.ChatFrame1), "beside the chat until you move it")
S.bags = lua.table()
S.bags[0] = lua.table(lua.table(700, 3), lua.table(701, 5))
G.Fire("BAG_UPDATE_DELAYED")
food.scripts.OnClick(food)
menu = fs.menu
rows = [r for r in fs.menuRows.values() if r.shown]
check(menu.shown and len(rows) == 1 and rows[0].attrs["item"] == "item:700" and "Roast Raptor" in rows[0].text.text,
      "a click lists your XP food (not the bread): a click eats it")
food.scripts.OnClick(food)
auras(Demon_Armor=(1800, 1800), Soul_Link=(0, 0), Well_Fed=(800, 900))
check(not food.shown and not menu.shown, "Well Fed: gone")
auras(Demon_Armor=(1800, 1800), Soul_Link=(0, 0))
S.level = 60
G.Fire("PLAYER_LEVEL_UP")
check(not food.shown, "at the top level there's no XP to gain")
S.level = 20
auras(Demon_Armor=(1800, 1800), Soul_Link=(0, 0), Well_Fed=(800, 900))

# ---------------------------------------------------------------- Reagents running low, under the food one
def reagent_rows():
    if not fs.list.shown:
        return []
    return [(r.icon.tex, r.text.text) for r in fs.reagentRows.values() if r.shown]


auras(Demon_Armor=(1800, 1800), Soul_Link=(0, 0), Well_Fed=(800, 900))
items(i6265=2, i5512=1, i5232=1)
check(reagent_rows() == [], "Soul Shards running low: the shard count says it, not this list")
db.shards.enabled = False
items(i6265=2, i5512=1, i5232=1)
check(reagent_rows() == [(62650, ns.REAGENT_TEXT.LOW % ("Soul Shard", 2))],
      f"with the count off, here: {reagent_rows()}")
db.shards.enabled = True
know(1122)
items(i6265=2, i5512=1, i5232=1)
rows = reagent_rows()
check(rows == [(55650, ns.REAGENT_TEXT.NONE % "Infernal Stone")], f"Inferno learned and no Infernal Stone: {rows}")
rrow = [r for r in fs.reagentRows.values() if r.shown][0]
check(rrow.icon.desat and "Inferno" in rrow.uses, "grey with none left, and its tooltip says what it's for")
check(fs.list.shown and not food.shown, "the food one isn't there (Well Fed): the list is the reagents")
G.MERCHANT = lua.table(4500, 5565)
printed.clear()
G.Fire("MERCHANT_SHOW")
check(any(ns.REAGENT_TEXT.VENDOR % ("Infernal Stone", 0) in line for line in printed), f"a vendor that sells it says so: {printed}")
G.MERCHANT = lua.table()
know(1225503)
items(i6265=2, i5512=1, i5232=1)
check(reagent_rows() == [], "with Reagent Economy the vendor ones go")
know(1225503, on=False)
S.combat = True
G.Fire("PLAYER_REGEN_DISABLED")
check(reagent_rows() == [], "in combat: nothing")
S.combat = False
G.Fire("PLAYER_REGEN_ENABLED")
check(len(reagent_rows()) == 1, "back after the fight")
auras(Demon_Armor=(1800, 1800), Soul_Link=(0, 0))
check(food.shown and reagent_rows() and [r for r in fs.reagentRows.values() if r.shown][0].point[3] == -24,
      "with the food one too: the reagent under it")
auras(Demon_Armor=(1800, 1800), Soul_Link=(0, 0), Well_Fed=(800, 900))
db.reagents.enabled = False
ns.RefreshReagents()
check(reagent_rows() == [] and not fs.list.shown, "the option off: nothing")
db.reagents.enabled = True
items(i6265=2, i5512=1, i5232=1, i5565=1)
check(reagent_rows() == [], "one Infernal Stone: enough")

# ---------------------------------------------------------------- Gear and bags (Repair.lua), under the reagents
REPAIR = r"Interface\Icons\Trade_BlackSmithing"
S.durability[16] = lua.table(10, 100)
S.durability[1] = lua.table(40, 50)
G.Fire("UPDATE_INVENTORY_DURABILITY")
check(reagent_rows() == [(REPAIR, ns.REPAIR_TEXT.WORN % 10)], f"your weapon at 10%: beside the chat, under the rest: {reagent_rows()}")
S.canRepair = True
printed.clear()
G.MERCHANT = lua.table()
G.Fire("MERCHANT_SHOW")
check(any(ns.REPAIR_TEXT.VENDOR % 10 in line for line in printed), f"a vendor that repairs: it says how worn your gear is: {printed}")
S.durability[16] = lua.table(95, 100)
G.Fire("UPDATE_INVENTORY_DURABILITY")
check(reagent_rows() == [], "repaired: gone")
for bag in range(5):
    S.freeSlots[bag] = 0
G.Fire("BAG_UPDATE_DELAYED")
check(reagent_rows() == [(r"Interface\Icons\INV_Misc_Bag_08", ns.REPAIR_TEXT.BAGS_FULL)], f"no free slots: bags full: {reagent_rows()}")
S.combat = True
G.Fire("PLAYER_REGEN_DISABLED")
check(reagent_rows() == [], "in combat: nothing")
S.combat = False
G.Fire("PLAYER_REGEN_ENABLED")
db.repair.bags = 0
S.freeSlots[0] = 1
ns.RefreshRepair()
check(reagent_rows() == [], "one free and your line at none: nothing")
db.repair.enabled = False
S.freeSlots[0] = 0
ns.RefreshRepair()
check(reagent_rows() == [], "the option off: nothing")
db.repair.enabled = True
db.repair.bags = 2
S.freeSlots = lua.table()
S.durability = lua.table()
ns.RefreshRepair()

# ---------------------------------------------------------------- Your buffs someone in your group lacks (GroupBuffs.lua)
check(ns.GROUP_BUFFS.WARLOCK is None, "a warlock has no group buff to give: the family's list has none")
# To see the wiring work, a made-up one for the warlock: Unending Breath
ns.GROUP_BUFFS.WARLOCK = lua.table(lua.table(key="breath", cast=lua.table(5697), also=lua.table()))
know(5697)
S.group = True
S.party = lua.table(True, True)
S.partyAuras = lua.table()
S.partyAuras["party2"] = lua.table("Unending Breath")
G.Fire("GROUP_ROSTER_UPDATE")
check(keys() == ["group1"] and row()[0][1] == 5697 and row()[0][3] == "1", f"one of two lacks it: its icon, with how many: {row()}")
check(click("group1") == ("spell", "Unending Breath", "party1"), f"a click casts it on them: {click('group1')}")
S.partyAuras["party1"] = lua.table("Unending Breath")
G.Fire("UNIT_AURA", "party1")
check(keys() == [], "they have it now: gone")
S.partyAuras["party1"] = lua.table()
S.combat = True
G.Fire("PLAYER_REGEN_DISABLED")
check(keys() == [], "in combat: nothing")
S.combat = False
G.Fire("PLAYER_REGEN_ENABLED")
db.groupBuffs.enabled = False
ns.RefreshGroupBuffs()
check(keys() == [], "the option off: nothing")
db.groupBuffs.enabled = True
ns.GROUP_BUFFS.WARLOCK = None
S.group = False
S.party = lua.table()
ns.RefreshGroupBuffs()
check(keys() == [], "back to the real list: nothing for a warlock")

# ---------------------------------------------------------------- The demon's health
hurt = ns.DemonState().hurt
S.petHealth = 30
G.Fire("UNIT_HEALTH", "pet")
check(hurt.shown and hurt.text.text == L.DEMON_HEALTH % 30 and hurt.icon.tex == 755, f"30%: heal it, with Health Funnel: {hurt.text.text}")
S.petHealth = 80
G.Fire("UNIT_HEALTH", "pet")
check(not hurt.shown, "80%: fine")
S.secretPetHealth = True
S.petHealth = 20
G.Fire("UNIT_HEALTH", "pet")
check(hurt.shown and hurt.hiddenAlpha and hurt.alpha == 1 and hurt.text.hiddenText and hurt.text.text == L.DEMON_HEALTH % 20,
      "hidden in combat: the game gives the warning its opacity and its number")
S.petHealth = 90
G.Fire("UNIT_HEALTH", "pet")
check(hurt.shown and hurt.alpha == 0, "and at 90% the curve makes it see-through")
S.secretPetHealth = False
S.pet = False
G.Fire("UNIT_PET", "player")
check(not hurt.shown, "no demon: nothing")
S.pet = True
S.petHealth = 100
G.Fire("UNIT_PET", "player")

# ---------------------------------------------------------------- Range
rng = G.NAMED["WarlockGodRange"]
S.target = lua.table(hostile=True)
yd = L.YARDS
db.range.display = "bracket"


def range_at(dist):
    S.dist = dist
    ns.UpdateRange()
    return f"{rng.text.text} {rng.unit.text}" if rng.shown else None


def colour():
    return tuple(round(c, 2) for c in rng.text.color.values())[:3]


check(range_at(3) == f"0-5 {yd}" and colour() == (1, 0.2, 0.2), f"3 yd: on you, red ({rng.text.text})")
check(range_at(12) == f"10-15 {yd}" and colour() == (1, 0.82, 0), f"12 yd: Drain Life reaches, yellow ({rng.text.text})")
check(range_at(22) == f"20-25 {yd}" and colour() == (0.3, 1, 0.3) and not rng.glow.shown, f"22 yd: Shadow Bolt range, green ({rng.text.text})")
check(range_at(27) == f"25-28 {yd}" and colour() == (0.7, 0.62, 1) and rng.glow.shown,
      f"27 yd: the last 5 yards of Shadow Bolt's 30, glowing ({rng.text.text})")
check(range_at(33) == f"30-35 {yd}" and colour() == (0.6, 0.6, 0.6), f"33 yd: out of range, grey ({rng.text.text})")
G.REACH["Drain Life"] = 24  # Grim Reach
check(range_at(22) == f"20-24 {yd}" and colour() == (1, 0.82, 0), f"Grim Reach: Drain Life to 24 yards ({rng.text.text})")
G.REACH["Drain Life"] = 20
know(689, 5782, on=False)
check(range_at(18) == f"15-20 {yd}" and colour() == (1, 0.82, 0), "no drain learned yet: the 20 yard step stands in")
know(689, 5782)
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 348)
check(db.range.lastSpell == "immolate", "Immolate cast: the range follows it")
S.secretRange = True
check(range_at(20) is None, "the game hides the range: nothing shown")
S.secretRange = False
db.range.display = "number"
check(range_at(22) is not None and rng.text.text.isdigit(), f"one number: {rng.text.text}")
out = slash("rango" if es else "range")
check(len(out) == 2 and "Immolate" in out[0], f"/warlockgod range: {out}")
out = slash("meters")
check(db.range.units == "meters" and range_at(22) is not None and rng.unit.text == L.METERS, "metres")
slash("yards")

# ---------------------------------------------------------------- Aggro
thr = G.NAMED["WarlockGodThreat"]
S.pet = False
S.threat = lua.table(False, 1, 95, 95)
ns.UpdateThreat()
check(not thr.shown, "solo without a demon: you always have the aggro, nothing to say")
S.pet = True
ns.UpdateThreat()
check(thr.shown and thr.text.text == L.THREAT % 95, f"with your demon tanking, at 95%: {thr.text.text}")
S.threat = lua.table(False, 1, 80, 80)
ns.UpdateThreat()
check(not thr.shown, "80%: below the 90% line")
S.threat = lua.table(True, 3, 100, 130)
ns.UpdateThreat()
check(thr.shown and thr.text.text == L.THREAT_PULLED, "you pulled it")
S.threat = lua.table(G.SECRET, G.SECRET, G.SECRET, G.SECRET)
ns.UpdateThreat()
check(not thr.shown, "hidden threat: nothing")
S.threat = None

# ---------------------------------------------------------------- Procs: one drawing each, for the build that has it
MEDIA = "Interface\\AddOns\\WarlockGod\\media\\"
PROCS = (("trance", 17941), ("harvest", 1242853), ("decimation", 440873), ("shadow", 1293816), ("flame", 426311))


def watched(b):
    return sorted(b.slot.options.candidateFilters.includeSpellIDs.keys())


def showing():
    return [k for k, _ in PROCS if ns.ProcsState(k).holder.shown]


for key, spell in PROCS:
    st = ns.ProcsState(key)
    check(st.container is not None and st.container.slot.filter == "HELPFUL" and st.container.unit == "player"
          and st.container.enabled and watched(st.container) == [spell], f"{key}: its own aura container on your buffs, watching {spell}")
check(showing() == [], f"no talents yet: none of them shows: {showing()}")
know(18094, 440870, 437032)  # Nightfall, Decimation and Soul Harvest
check(showing() == ["trance", "harvest", "decimation"], f"Nightfall, Soul Harvest and Decimation learned: those three: {showing()}")
know(426316)
check(showing() == ["trance", "harvest", "decimation"], "Shadow and Flame without Conflagrate or Shadowburn: nothing to trigger it")
know(1293817)
check(showing() == ["trance", "harvest", "decimation", "shadow"], "with Conflagrate: its Shadow half")
know(17877)
check(showing() == ["trance", "harvest", "decimation", "shadow", "flame"], "with Shadowburn: its Flame half too")
know(18094, on=False)
check("trance" not in showing(), "Nightfall unlearned: no flames")
know(18094)

tr = ns.ProcsState("trance")
dressed = tr.dressed
button = tr.container.button
check(len(button.shownAnims) == 3 and len(button.assignedAnims) == 3 and dressed.ready,
      "Shadow Trance: the game takes the calm flames and breath to loop, and the burst for when it comes")
files = [e[1].tex for e in dressed.tinted.values()]
check(files.count(MEDIA + "flame_glow") == 4 and files.count(MEDIA + "flame_core") == 4, f"two columns of shadow flames: {files}")
check(dressed.calm.alpha == 0.2 and dressed.strike.alpha == 0.6, "small and faint by default, as HunterGod: the burst at 60%, the calm at 20%")
check(tr.place.point[1] == "CENTER" and tr.place.point[5] == -20 and tr.holder.scale == 0.4, "around you, at 40%")
timer = button.durationText
rules = timer and timer.options and timer.options.textFormatter.rules
check(timer is not None and G.Same(timer.text, dressed.timer) and rules[2].format == "%d", "the game writes the seconds left")
colors = [tuple(round(c, 2) for c in e[1].color.values()) for e in dressed.tinted.values()]
check(colors[1] == (0.55, 0.36, 1.0) and colors[2][2] == 1.0 and colors[2][0] > 0.8, f"purple, the cores nearly white: {colors[:3]}")


def drawing(key):
    d = ns.ProcsState(key).dressed
    return d, {e[1].tex for e in d.tinted.values()}, [(e[1].points[1][4], e[1].points[1][5]) for e in d.placed.values()]


d, files, spots = drawing("harvest")
check(MEDIA + "wisps_glow" in files and MEDIA + "wisps_core" in files and all(x == 0 for x, _ in spots),
      "Soul Harvest: souls rising behind you, in the middle")
d, files, spots = drawing("decimation")
check(MEDIA + "ring_glow" in files and (0, -150) in spots, f"Decimation: a ring of fel fire at your feet: {spots[:3]}")
check(tuple(round(c, 2) for c in d.tinted[2][1].color.values()) == (0.45, 1, 0.25), "fel green")
d, files, spots = drawing("shadow")
check(MEDIA + "ember_glow" in files and all(s == (-70, 120) for s in spots), f"Shadow: an ember over your left shoulder: {spots[:2]}")
d, files, spots = drawing("flame")
check(all(s == (70, 120) for s in spots) and tuple(round(c, 2) for c in d.tinted[2][1].color.values()) == (1, 0.5, 0.15),
      "Flame: an orange one over your right shoulder")
check(all(ns.ProcsState(k).container.button.durationText is not None for k, _ in PROCS), "each with its seconds")

for saved, fresh, want in ((dict(size=60, alpha=85), False, (40, 60)), (dict(size=80, alpha=85), False, (80, 60)),
                           (dict(size=60, alpha=85, v=2), False, (60, 85)), (dict(size=60, alpha=85), True, (60, 85))):
    old = lua.table(procs=lua.table(size=saved["size"], alpha=saved["alpha"]), version=saved.get("v"))
    ns.MigrateSettings(old, fresh)
    check((old.procs.size, old.procs.alpha) == want and old.version == 2, f"settings from the first 0.1.0 {saved}: {want}")

auras(Demon_Armor=(1800, 1800), Soul_Link=(0, 0), Well_Fed=(800, 900), Shadow_Trance=(8, 10, 999001), Shadow=(15, 20, 999005))
check(999001 in watched(ns.ProcsState("trance").container) and db.procs.learned[999001] == "trance",
      "a Shadow Trance with another number: learned and watched")
check(db.procs.learned[999005] is None and watched(ns.ProcsState("shadow").container) == [1293816],
      "but not a \"Shadow\" with another number: other spells share that name")
S.combat = True
auras(Demon_Armor=(1800, 1800), Decimation=(8, 10, 999002))
check(999002 not in watched(ns.ProcsState("decimation").container), "in combat it waits")
S.combat = False
G.Fire("PLAYER_REGEN_ENABLED")
check(999002 in watched(ns.ProcsState("decimation").container), "and builds it when the fight is over")
auras(Demon_Armor=(1800, 1800), Soul_Link=(0, 0), Well_Fed=(800, 900))
out = slash("procs")
tr = ns.ProcsState("trance")
check(tr.spot.shown and all(ns.ProcsState(k).sampleFrame.shown for k, _ in PROCS) and tr.sample.assigned[1].playing,
      "/warlockgod procs shows every sample, playing")
check(len(out) == 5 and "17941, 999001" in out[0], f"and says what each watches: {out}")
know(17877, on=False)
out = slash("procs")
check(out[4] == L.PREFIX + L.PROCS_NO_TALENT % ("Shadow and Flame: Flame", "Shadowburn"), f"and which talent your build lacks: {out[4]}")
know(17877)
S.now = S.now + 6
G.RunTimers()
check(not tr.spot.shown, "a few seconds later they're gone")
db.procs.decimation.enabled = False
ns.StyleProcs()
check("decimation" not in showing() and "harvest" in showing(), "one switched off: only that one")
db.procs.decimation.enabled = True
ns.StyleProcs()

# ---------------------------------------------------------------- Shields: Shadow Ward, Sacrifice and the potions
bs = ns.BarrierState()
bar = bs.bar
status = next(f for f in G.FRAMES.values() if f.kind == "StatusBar" and G.Same(f.parent, bar))
S.absorb = 0
ns.UpdateBarrier()
check(not bar.shown, "no shield: no bar")
S.absorb = 290
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 6229)
G.RunTimers()
check(bar.shown and list(status.minmax.values()) == [0, 290] and bar.text.text == "290" and bar.time.text == "30"
      and bar.icon.tex == 6229, f"Shadow Ward: a full bar with what it absorbs and its half minute ({bar.text.text}, {bar.time.text})")
check(tuple(round(c, 2) for c in status.barColor.values()) == (0.62, 0.4, 1), "in its purple")
S.absorb = 100
S.now = S.now + 10
G.Fire("UNIT_ABSORB_AMOUNT_CHANGED", "player")
check(bar.text.text == "100" and bar.time.text == "20", "hits taken: 100 left, 20 s")
S.absorb = 0
G.Fire("UNIT_ABSORB_AMOUNT_CHANGED", "player")
check(not bar.shown, "broken: the bar goes")
S.absorb = 529
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "pet", "cast", 19438)
G.RunTimers()
check(bar.shown and bar.icon.tex == 19438 and tuple(round(c, 2) for c in status.barColor.values()) == (0.42, 0.3, 0.78),
      "your Voidwalker's Sacrifice: its shield on you, in its colour")
S.absorb = 0
G.Fire("UNIT_ABSORB_AMOUNT_CHANGED", "player")
S.absorb = 1200
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 17543)
G.RunTimers()
check(bar.shown and bar.time.text == "2:00" and tuple(round(c, 2) for c in status.barColor.values()) == (1, 0.42, 0.1),
      f"a Greater Fire Protection Potion: two minutes, in orange ({bar.time.text})")
S.absorb = 0
G.Fire("UNIT_ABSORB_AMOUNT_CHANGED", "player")
db.barrier.potions = False
S.absorb = 1200
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 17543)
G.RunTimers()
check(not bar.shown, "potions left out: nothing")
db.barrier.potions = True
# In combat Forever hides how much it absorbs: the game fills the bar in itself
S.absorb = G.Hidden(470)
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 11739)
G.RunTimers()
check(bar.shown and status.hiddenValue and bar.text.hiddenText, "hidden in combat: the game fills the bar and its number")
S.absorb = 0
S.now = S.now + 40
G.Fire("UNIT_ABSORB_AMOUNT_CHANGED", "player")
check(not bar.shown, "gone")
# Another class's shield (a mage's Ice Barrier, as the game shows your buffs): it shows too, in its colour
S.absorb = 500
auras(Demon_Armor=(1800, 1800), Soul_Link=(0, 0), Well_Fed=(800, 900), Ice_Barrier=(50, 60, 11426))
G.Fire("UNIT_ABSORB_AMOUNT_CHANGED", "player")
check(bar.shown and bar.icon.tex == 11426 and tuple(round(c, 2) for c in status.barColor.values()) == (0.52, 0.78, 0.92)
      and bar.time.text == "50", f"a shield you didn't cast: the bar knows it from your buffs ({bar.time.text})")
S.absorb = 0
G.Fire("UNIT_ABSORB_AMOUNT_CHANGED", "player")
auras(Demon_Armor=(1800, 1800), Soul_Link=(0, 0), Well_Fed=(800, 900))

# ---------------------------------------------------------------- The wand's swing timer
wst = ns.WandState()
wb = wst.bar
S.target = None
S.wand, S.wandSpeed = 950, 1.5
G.Fire("PLAYER_EQUIPMENT_CHANGED")
check(not wb.shown and wb.tag.tex == 9500, "a wand in your ranged slot, not shooting: no bar yet; its icon ready")
G.Fire("PLAYER_SWING", 2.6, 0)
check(not wb.shown, "a main hand swing: not the wand's")
G.Fire("PLAYER_SWING", G.SECRET, 2)
check(not wb.shown, "a hidden duration: left alone")
t0 = S.now
G.Fire("PLAYER_SWING", 1.6, 2)
check(wb.shown and ns.WandState().swing.duration == 1.6 and wb.flash.alpha == 0.55, "a wand shot: the bar starts, with a flash")
S.now = t0 + 0.8
ns.UpdateWand()
k = 0.45 + 0.55 * 0.25
fill = tuple(wb.fill.color.values())[:3]
check(wb.time.text == "0.8" and wb.flash.alpha == 0 and all(abs(a - c * k) < 1e-6 for a, c in zip(fill, (0.6, 0.5, 1))),
      f"halfway: dim, lighting up as the shot comes, its seconds ({wb.time.text}, {fill})")
S.now = t0 + 1.6 + 1.9
ns.UpdateWand()
check(wb.shown and wb.time.text == "", "the shot done: it stays a moment")
S.now = t0 + 1.6 + 2.1
ns.UpdateWand()
check(not wb.shown, "two seconds later it goes")
# Should the game not report the wand: Shoot on and off, at the wand's speed
t0 = S.now
G.Fire("START_AUTOREPEAT_SPELL")
st = ns.WandState()
check(wb.shown and st.shooting and st.swing.duration == 1.5, "Shoot on without a word from the game: the bar runs at your wand's speed")
S.now = t0 + 1.6
ns.UpdateWand()
check(ns.WandState().swing.start == t0 + 1.5, "and the next shot follows the last")
G.Fire("PLAYER_SWING", 1.7, 2)
S.now = S.now + 1.6
ns.UpdateWand()
check(ns.WandState().swing.duration == 1.7, "once the game reports it, its numbers count")
G.Fire("STOP_AUTOREPEAT_SPELL")
S.now = S.now + 4
ns.UpdateWand()
check(not wb.shown, "Shoot off: gone after its moment")
# Out of reach: grey
know(5019)
S.target = lua.table(hostile=True)
S.dist = 35
G.Fire("START_AUTOREPEAT_SPELL")
check(wb.shown and wb.away and wb.alpha == 0.55, "your target out of your wand's reach: grey")
S.dist = 20
S.now = S.now + 0.3
ns.UpdateWand()
check(not wb.away and wb.alpha == 1, "in reach again")
G.Fire("PLAYER_SWING_RANGE_UPDATE", 2, False, True)
check(wb.away, "the game's own range check counts too")
G.Fire("PLAYER_SWING_RANGE_UPDATE", 2, True, True)
G.Fire("STOP_AUTOREPEAT_SPELL")
S.now = S.now + 4
ns.UpdateWand()
db.wand.enabled = False
G.Fire("PLAYER_SWING", 1.6, 2)
check(not wb.shown, "the option off: nothing")
db.wand.enabled = True
S.wand = None
G.Fire("PLAYER_EQUIPMENT_CHANGED")
G.Fire("PLAYER_SWING", 1.6, 2)
check(not wb.shown, "no wand: nothing")
S.wand = 950
G.Fire("PLAYER_EQUIPMENT_CHANGED")
slash("varita" if es else "wand")
check(wb.shown, "/warlockgod wand shows it shooting")
S.now = S.now + 7
G.RunTimers()
check(not wb.shown, "and a few seconds later it's gone")
S.target = None

# ---------------------------------------------------------------- Big cooldowns back: a pulse
pst = ns.PulseState("deathCoil")
pplace, part, poller = pst.place, pst.art, pst.poller
check(pst.known is None, "Death Coil not learned: not watched")
know(6789)
check(ns.PulseState("deathCoil").known == 6789, "learned: watched")


def tick(seconds=0.2):
    S.now = S.now + seconds
    poller.scripts.OnUpdate(poller, seconds)
    pplace.scripts.OnUpdate(pplace)


G.COOLDOWNS[6789] = lua.table(isActive=True, duration=120)
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 6789)
check(ns.PulseState("deathCoil").own and poller.shown and not pplace.shown, "cast: cooling down, watched closely")
tick(60)
G.COOLDOWNS[6789] = lua.table(isActive=False, duration=0)
tick()
check(pplace.shown and part.icon.tex == 6789, "back: Death Coil's icon in the middle")
tick(1.2)
check(not pplace.shown, "and gone in about a second")
# The global cooldown from another spell isn't Death Coil coming back
G.COOLDOWNS[6789] = lua.table(isActive=True, duration=1.5)
G.Fire("SPELL_UPDATE_COOLDOWN")
tick(1)
G.COOLDOWNS[6789] = lua.table(isActive=False, duration=0)
tick()
check(not pplace.shown, "the global cooldown: no pulse")
# In combat the duration is hidden, but not whether it runs
G.COOLDOWNS[6789] = lua.table(isActive=True, duration=G.SECRET, isOnGCD=G.SECRET)
G.Fire("SPELL_UPDATE_COOLDOWN")
tick(5)
G.COOLDOWNS[6789] = lua.table(isActive=False, duration=G.SECRET, isOnGCD=G.SECRET)
tick()
check(pplace.shown, "with the time hidden, it still knows it was its own (it ran longer than a global cooldown)")
tick(1.2)
# Two back at once: one after the other
know(5484)
G.COOLDOWNS[6789] = lua.table(isActive=True, duration=120)
G.COOLDOWNS[5484] = lua.table(isActive=True, duration=40)
G.Fire("SPELL_UPDATE_COOLDOWN")
tick(50)
G.COOLDOWNS[6789] = lua.table(isActive=False, duration=0)
G.COOLDOWNS[5484] = lua.table(isActive=False, duration=0)
tick()
check(pplace.shown and part.icon.tex == 6789 and len(list(ns.PulseState().queue.values())) == 1, "two at once: Death Coil now, Howl waiting")
tick(1.2)
check(pplace.shown and part.icon.tex == 5484, "then Howl of Terror")
tick(1.2)
db.pulse.spells.howl = False
G.COOLDOWNS[5484] = lua.table(isActive=True, duration=40)
G.Fire("SPELL_UPDATE_COOLDOWN")
tick(50)
G.COOLDOWNS[5484] = lua.table(isActive=False, duration=0)
tick()
check(not pplace.shown, "Howl switched off: nothing")
db.pulse.spells.howl = True
# The Soulstone: the stone's own half hour
know(693)
S.itemCooldowns[5232] = lua.table(S.now, 1800)
G.Fire("BAG_UPDATE_COOLDOWN")
tick(1800)
S.itemCooldowns[5232] = lua.table(0, 0)
tick()
check(pplace.shown and part.icon.tex == 52320, "the Soulstone ready again: its icon")
tick(1.2)
S.itemCooldowns = lua.table()
out = slash("pulso" if es else "cooldowns")
check(pplace.shown, "/warlockgod cooldowns shows it")
tick(1.2)

# ---------------------------------------------------------------- Your effects on your target
ds = ns.DebuffsState()
dbox, dholder = ds.container, ds.holder


def watching():
    return sorted(dbox.group.options.candidateFilters.includeSpellIDs.keys())


check(dbox is not None and dbox.unit == "target" and dbox.enabled and dbox.group.filter == "HARMFUL|PLAYER"
      and dbox.group.options.maxFrameCount == 8, "an aura container on your target: a row of your own debuffs")
w = watching()
check(172 in w and 25311 in w and 348 in w and 5782 in w and 6789 in w and 980 not in w and 17794 not in w,
      f"every rank of the spells you know (Corruption, Immolate, Fear, Death Coil), not the others: {w[:6]}...")
know(980)
w = watching()
check(980 in w and 11713 in w and 603 not in w, "Bane of Agony learned: its ranks too, not Bane of Doom")
know(17793)
check(17794 in watching(), "Improved Shadow Bolt: its Shadow Vulnerability")
button = dbox.groupButton
check(button.iconTexture is not None and button.cooldown is not None, "the game puts each one's icon in and counts its time down")
check(dbox.layout.elementWidth == 22 and dbox.layout.elementSpacing == 3, "small icons, in a row")
db.dots.spells.corruption = False
ns.StyleDebuffs()
check(172 not in watching(), "Corruption switched off: left out")
db.dots.spells.corruption = True
ns.StyleDebuffs()
# Beside the target's nameplate
hp = G.CreateFrame("Frame")
S.plate = lua.table(UnitFrame=lua.table(healthBar=hp))
S.target = lua.table(hostile=True)
G.Fire("PLAYER_TARGET_CHANGED")
check(dholder.point[1] == "LEFT" and G.Same(dholder.point[2], hp) and dholder.point[3] == "RIGHT", "right of the target's health bar")
S.plate = None
G.Fire("PLAYER_TARGET_CHANGED")
check(dholder.point[1] == "CENTER" and G.Same(dholder.point[2], G.UIParent), "no nameplate: where you put it")
db.dots.anchor = "free"
S.plate = lua.table(UnitFrame=lua.table(healthBar=hp))
G.Fire("PLAYER_TARGET_CHANGED")
check(G.Same(dholder.point[2], G.UIParent), "or always there, if you want")
db.dots.anchor = "plate"
db.dots.size = 30
ns.StyleDebuffs()
check(dbox.layout.elementWidth == 30, "their size is yours")
db.dots.size = 22
ns.StyleDebuffs()
db.dots.enabled = False
ns.StyleDebuffs()
check(not dholder.shown, "switched off: hidden")
db.dots.enabled = True
ns.StyleDebuffs()
S.plate = None
S.target = None

# ---------------------------------------------------------------- Interrupt: the Felhunter's Spell Lock
ist = ns.InterruptState()
iframe = ist.frame
S.pet = True
S.target = lua.table(hostile=True)
S.cast = lua.table("Fireball", False)
G.Fire("UNIT_SPELLCAST_START", "target")
check(not iframe.shown, "a demon without Spell Lock: nothing")
S.petSpells[19244] = True
G.Fire("PET_BAR_UPDATE")
check(ns.InterruptState().lock.id == 19244 and iframe.shown and iframe.inner.alpha == 1 and iframe.icon.tex == 19244
      and iframe.width == 30 and iframe.glow.playing, "a Felhunter that knows Spell Lock, the target casting: its icon, small, glowing")
G.COOLDOWNS[19244] = lua.table(isActive=True, duration=G.SECRET)
G.Fire("SPELL_UPDATE_COOLDOWN")
check(not iframe.shown, "Spell Lock cooling down: nothing")
G.COOLDOWNS[19244] = lua.table(isActive=False, duration=0)
G.Fire("SPELL_UPDATE_COOLDOWN")
check(iframe.shown, "ready again")
S.cast = lua.table("Fireball", True)
G.Fire("UNIT_SPELLCAST_START", "target")
check(not iframe.shown, "a cast you can't stop: nothing")
# In a fight the game may hide whether it can be stopped: it shows or hides the icon itself
S.cast = lua.table(G.SECRET, G.Hidden(True))
G.Fire("UNIT_SPELLCAST_START", "target")
check(iframe.shown and iframe.inner.alpha == 0, "a hidden cast that can't be stopped (Throw Bone): the game keeps the icon unseen")
S.cast = lua.table(G.SECRET, G.Hidden(False))
G.Fire("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "target")
check(iframe.shown and iframe.inner.alpha == 1, "one that can: seen")
S.cast = lua.table(G.SECRET, G.Hidden(True))
G.Fire("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "target")
check(iframe.inner.alpha == 0, "the cast turning unstoppable: hidden again")
S.cast = lua.table("Fireball", False)
G.Fire("UNIT_SPELLCAST_INTERRUPTIBLE", "target")
check(iframe.shown and iframe.inner.alpha == 1, "and stoppable again: seen")
S.cast = None
S.channel = lua.table("Arcane Missiles", False)
G.Fire("UNIT_SPELLCAST_CHANNEL_START", "target")
check(iframe.shown, "a channel too")
S.channel = None
G.Fire("UNIT_SPELLCAST_CHANNEL_STOP", "target")
check(not iframe.shown, "nothing cast: gone")
S.cast = lua.table("Fireball", False)
S.plate = lua.table(UnitFrame=lua.table(healthBar=hp))
G.Fire("PLAYER_TARGET_CHANGED")
check(iframe.shown and iframe.point[1] == "RIGHT" and G.Same(iframe.point[2], hp) and iframe.point[3] == "LEFT",
      "left of the target's health bar")
S.target = lua.table(hostile=False)
G.Fire("PLAYER_TARGET_CHANGED")
check(not iframe.shown, "a friendly target: nothing")
S.target = lua.table(hostile=True)
db.interrupt.enabled = False
ns.UpdateInterrupt()
check(not iframe.shown, "the option off: nothing")
db.interrupt.enabled = True
S.pet = False
G.Fire("UNIT_PET", "player")
check(not iframe.shown and ns.InterruptState().lock is None, "no demon out: nothing")
S.cast = None
S.plate = None
S.target = None
G.Fire("PLAYER_TARGET_CHANGED")
# Half an hour went by in these: the armor on again, the Soulstone cooling down
auras(Demon_Armor=(1800, 1800), Soul_Link=(0, 0), Well_Fed=(800, 900))
S.itemCooldowns[5232] = lua.table(S.now, 1800)
ns.UpdateBuffs()

# ---------------------------------------------------------------- Moving the displays
S.pet = True
ns.SetUnlocked(True)
check(keys() == ["demon", "soulLink", "armor", "weapon", "healthstone", "soulstone", "gather"], f"unlocked: a sample of each reminder: {keys()}")
tr = ns.ProcsState("trance")
check(tr.spot.shown and all(ns.ProcsState(k).sampleFrame.shown for k, _ in PROCS), "and of the procs your build has")
check(pplace.shown and ns.DebuffsState().sample.shown and iframe.shown, "the cooldown pulse, your effects on the target and INTERRUPT! too")
check(food.shown and rng.shown and thr.shown and hurt.shown and counter.shown and bar.shown and wb.shown and len(reagent_rows()) == 2,
      "and of everything else, a reagent and a repair too")
check(all(m.click.shown is False for m in members.values()), "the click buttons stay out of the way")
check(all(f.mover.shown for f in ns.movers.values()), "each with its handle")
ns.SetUnlocked(False)
check(keys() == [] and not food.shown and not thr.shown and not hurt.shown and not bar.shown, f"locked: back to what's real: {keys()}")
S.combat = True
out = slash("unlock")
check(not ns.unlocked and out[0] == L.PREFIX + L.NOT_IN_COMBAT, "not in combat")
S.combat = False

# ---------------------------------------------------------------- Options
ns.ToggleOptions()
win, pages = ns.OptionsWindow()
page = {p.key: p for p in pages.values()}
check(set(page.keys()) == {"buffs", "demon", "range", "procs", "wand", "cooldowns", "target", "threat"}, f"pages: {list(page.keys())}")
ns.ShowOptionsPage("buffs")
controls = {c.setting: c for c in page["buffs"].controls.values()}
weapon = controls[L.OPT_WEAPON_CHOICE]
check(weapon.text == L.WEAPON_AUTO, f"weapon stone choice: {weapon.text}")
weapon.scripts.OnClick(weapon)
check(db.stones.weaponChoice == "spellstone" and weapon.text == "Spellstone", f"next: {weapon.text}")
weapon.scripts.OnClick(weapon)
weapon.scripts.OnClick(weapon)
check(db.stones.weaponChoice == "auto", "and round again")
low = controls[L.OPT_SHARDS_LOW]
low.scripts.OnValueChanged(low, 6)
check(db.shards.low == 6 and counter.mood == "low", "the shard line is yours: under 6, red")
low.scripts.OnValueChanged(low, 3)
use = controls[L.OPT_SOULSTONE_USE]
use.checked = False
use.scripts.OnClick(use)
check(not db.stones.soulstoneUse, "the switches work")
use.checked = True
use.scripts.OnClick(use)
check(controls[L.OPT_HEALTHSTONE] is not None and controls[L.OPT_FOOD_ON] is not None and controls[L.OPT_RESPEC] is not None
      and controls[L.OPT_GATHER % ("Find Herbs", "Find Minerals")] is not None and controls[L.OPT_REAGENTS] is not None
      and controls[L.OPT_REPAIR] is not None and controls[L.OPT_REPAIR_LOW] is not None and controls[L.OPT_GROUP_BUFFS] is not None,
      "healthstone, gathering, food and the trainer's note are there")
check(controls[L.OPT_BARRIER % ("Shadow Ward", "Sacrifice")] is not None and controls[L.OPT_BARRIER_POTIONS] is not None
      and controls[L.OPT_BARRIER_COLOR % "Sacrifice"] is not None, "and the shield bar's")
ns.ShowOptionsPage("demon")
dcontrols = {c.setting: c for c in page["demon"].controls.values()}
choice = dcontrols[L.OPT_DEMON_CHOICE]
choice.scripts.OnClick(choice)
check(db.demon.choice == "imp" and choice.text == "Summon Imp", f"which demon: {choice.text}")
db.demon.choice = "auto"
check(dcontrols[L.OPT_DEMON_HEALTH_PCT] is not None and dcontrols[L.OPT_SOUL_LINK % "Soul Link"] is not None,
      "the health line and Soul Link")
ns.ShowOptionsPage("range")
rcontrols = {c.setting: c for c in page["range"].controls.values()}
spell = rcontrols[L.OPT_RANGE_SPELL]
spell.scripts.OnClick(spell)
check(db.range.spell == "shadowbolt" and spell.text == "Shadow Bolt", f"range spell: {spell.text}")
db.range.spell = "auto"
check(all(L.RANGE[s] in rcontrols for s in ("melee", "drain", "ranged", "far", "out")), "a preview sample for each state")
ns.ShowOptionsPage("procs")
pcontrols = {c.setting: c for c in page["procs"].controls.values()}
size = pcontrols[L.OPT_PROCS_SIZE]
size.scripts.OnValueChanged(size, 100)
check(db.procs.size == 100 and ns.ProcsState("trance").holder.scale == 1 and ns.ProcsState("trance").spot.shown,
      "the size of them all, shown a moment")
size.scripts.OnValueChanged(size, 40)
name = ns.ProcName("decimation")
switch = pcontrols[L.OPT_PROC["decimation"] % name]
switch.checked = False
switch.scripts.OnClick(switch)
check(not db.procs.decimation.enabled and "decimation" not in showing(), "each proc has its switch")
switch.checked = True
switch.scripts.OnClick(switch)
color = pcontrols[L.OPT_PROC_COLOR % ns.ProcName("trance")]
color.scripts.OnClick(color)
G.COLOR_INFO.swatchFunc()
check(tuple(ns.ProcsState("trance").dressed.tinted[2][1].color.values()) == (0, 0, 1), "and its colour")
G.COLOR_INFO.cancelFunc()
check(all(pcontrols.get(L.OPT_PROC[k] % ns.ProcName(k)) is not None and pcontrols.get(L.OPT_PROC_COLOR % ns.ProcName(k)) is not None
          for k, _ in PROCS), "all five, with the Shadow and Flame halves named as such")
check(pcontrols[L.OPT_PROCS_ALPHA] is not None and pcontrols[L.OPT_PROCS_TEST] is not None, "their strength, and a button to try them")
ns.ShowOptionsPage("wand")
wcontrols = {c.setting: c for c in page["wand"].controls.values()}
wsw = wcontrols[L.OPT_WAND]
wsw.checked = False
wsw.scripts.OnClick(wsw)
check(not db.wand.enabled, "the wand bar's switch")
wsw.checked = True
wsw.scripts.OnClick(wsw)
wwidth = wcontrols[L.OPT_BARRIER_WIDTH]
wwidth.scripts.OnValueChanged(wwidth, 220)
check(db.wand.width == 220 and wb.width == 220 + 17, f"its width ({wb.width}), with the wand's icon beside it")
wwidth.scripts.OnValueChanged(wwidth, 180)
check(wcontrols[L.OPT_WAND_COLOR] is not None and wcontrols[L.OPT_WAND_TEST] is not None, "its colour and a button to try it")
ns.ShowOptionsPage("cooldowns")
ccontrols = {c.setting: c for c in page["cooldowns"].controls.values()}
dc = ccontrols["Death Coil"]
dc.checked = False
dc.scripts.OnClick(dc)
check(not db.pulse.spells.deathCoil and ccontrols[L.PULSE_SOULSTONE] is not None and ccontrols["Inferno"] is not None,
      "a switch for each cooldown, the Soulstone's too")
dc.checked = True
dc.scripts.OnClick(dc)
ns.ShowOptionsPage("target")
tcontrols = {c.setting: c for c in page["target"].controls.values()}
cur = tcontrols[L.DOT_CURSES]
cur.checked = False
cur.scripts.OnClick(cur)
check(not db.dots.spells.curses and tcontrols["Corruption"] is not None and tcontrols[L.OPT_DOTS_SIZE] is not None,
      "a switch for each group of your effects, and their size")
cur.checked = True
cur.scripts.OnClick(cur)
check(tcontrols[L.OPT_INTERRUPT % "Spell Lock"] is not None, "and the interrupt's")
ns.ShowOptionsPage("threat")
check(any(c.setting == L.OPT_THREAT for c in page["threat"].controls.values()), "the aggro page")
win.Hide(win)
S.now = S.now + 10
G.RunTimers()

# ---------------------------------------------------------------- Not a warlock
S["class"] = "MAGE"
auras()
S.pet = False
ns.RefreshAll()
S.absorb = 300
ns.UpdateBarrier()
S.pet, S.target, S.cast = True, lua.table(hostile=True), lua.table("Fireball", False)
G.Fire("UNIT_SPELLCAST_START", "target")
G.Fire("PLAYER_SWING", 1.6, 2)
check(not iframe.shown and not ns.DebuffsState().holder.shown, "no interrupt warning nor target effects either")
S.pet, S.target, S.cast = False, None, None
check(keys() == [] and not food.shown and range_at(22) is None and not counter.shown and not bar.shown and not wb.shown,
      "a mage sees none of it")
S.absorb = 0
S["class"] = "WARLOCK"

out = slash("help")
check(len(out) == len(list(L.HELP.values())), "help lists the commands")
slash("boton" if es else "button")
check(db.minimapButton.hide and not G.NAMED["WarlockGodMinimapButton"].shown, "the minimap button can be hidden")
slash("button")
check(G.SLASH_WARLOCKGOD2 == "/brujo", "/brujo too")

# ---------------------------------------------------------------- Talent reset price at the trainer
rs = ns.RespecState()
rnote, recs = rs.note, rs.records
DAY = 86400
T0 = 1795600000
S.server, S.money = T0, 500000
popup = G.CreateFrame("Frame")
TRAINER = lua.eval('{ { gossipOptionID = 101, name = "I am here for training." }, { gossipOptionID = 102, name = "I wish to unlearn my class or legacy talents." } }')
G.GOSSIP_OPTIONS = TRAINER
G.Fire("GOSSIP_SHOW")
check(rnote.shown and G.Same(rnote.anchor, G.GossipFrame), "your class trainer: a note under its window")
check((L.RESPEC_UNKNOWN % "WarlockGod") in rnote.body.text, "no reset written down yet: it says so")
G.Fire("GOSSIP_CLOSED")
G.C_GossipInfo.SelectOption(102)
G.POPUPS.CONFIRM_TALENT_WIPE = popup
G.Fire("CONFIRM_TALENT_WIPE", 10000, 0)
G.RunTimers()
check(rnote.shown and G.Same(rnote.anchor, popup), "the price dialog: the note under it")
G.ConfirmTalentWipe()
S.money = 490000
G.Fire("PLAYER_MONEY")
check(recs["0"].reset == T0 and recs["0"].paid == 10000, "paid: the reset written down, with its price")
S.server = T0 + DAY
G.Fire("GOSSIP_SHOW")
check((L.RESPEC_NOW_ABOUT % "5 g") in rnote.body.text, f"a day on: about 5 g: {rnote.body.text}")
G.Fire("GOSSIP_CLOSED")
S["class"] = "HUNTER"
G.Fire("GOSSIP_SHOW")
check(not rnote.shown, "another class: not this addon's trainer")
S["class"] = "WARLOCK"


# ---------------------------------------------------------------- Another class: nothing on screen
# Every ...God addon loads for every class. A fresh login as a mage, with every reason to remind
# something (no food buff, two free bag slots, worn gear, a reagent run out, a group that lacks a
# buff, a herbalist with no tracking on, a demon hurt, a shield, a target casting, a wand shooting):
# WarlockGod draws nothing, says nothing in the chat, and has nothing to move. Only its minimap
# button and its options
def fresh_login(cls):
    """A new game with the addon, logged in as cls with every reason to remind something"""
    game = LuaRuntime(unpack_returned_tuples=True)
    game.globals().py_print = lambda *a: printed.append(" ".join(str(x) for x in a))
    game.globals().LOCALE = LOCALE
    game.globals().CLS = cls
    game.execute(MOCK)
    game.execute(MOCK_GUARDS)
    game.execute('''
    SPELLS[1459] = "Arcane Intellect"
    SPELLS[3561] = "Teleport: Stormwind"
    ITEM_NAMES[17031] = "Rune of Teleportation"
    G.class = CLS
    for _, id in ipairs({ 1459, 3561, 2383, 686, 687, 706, 688, 697, 6201, 693, 2362, 5019, 18094 }) do G.known[id] = true end
    G.durability[16] = { 5, 100 }
    G.freeSlots = { [0] = 2, [1] = 0, [2] = 0, [3] = 0, [4] = 0 }
    G.group, G.party = true, { true }
    G.tracking = { { name = "Find Herbs", spellID = 2383, active = false } }
    G.pet, G.petHealth = true, 10
    G.petSpells[19244] = true
    G.absorb = 500
    G.target, G.dist = { hostile = true }, 22
    G.cast = { "Fireball", false }
    G.wand = 950
    G.items[6265] = 0
    G.canRepair = true
    MERCHANT = { 17031 }
    function VisibleFrames()
      local out = {}
      for name, f in pairs(NAMED) do
        local p, seen = f, true
        while p do
          if not rawget(p, "shown") then seen = false break end
          p = rawget(p, "parent")
        end
        if seen and not name:find("Minimap") and not name:find("Options") then out[#out + 1] = name end
      end
      table.sort(out)
      return out
    end
    ''')
    gns = game.table()
    gload = game.eval('function(src, name) return assert(loadstring(src, "@" .. name)) end')
    for fname in re.findall(r"^(\w+\.lua)$", toc, re.M):
        gload(Path(ADDON, fname).read_text(encoding="utf-8"), fname)("WarlockGod", gns)
    M = game.globals()
    printed.clear()
    M.Fire("ADDON_LOADED", "WarlockGod")
    M.Fire("PLAYER_LOGIN")
    for ev in ("SPELLS_CHANGED", "BAG_UPDATE_DELAYED", "GROUP_ROSTER_UPDATE", "UPDATE_INVENTORY_DURABILITY",
               "MINIMAP_UPDATE_TRACKING", "PLAYER_REGEN_ENABLED", "PLAYER_TARGET_CHANGED", "PET_BAR_UPDATE",
               "MERCHANT_SHOW"):
        M.Fire(ev)
    M.Fire("UNIT_AURA", "player")
    M.Fire("UNIT_PET", "player")
    M.Fire("UNIT_HEALTH", "pet")
    M.Fire("UNIT_SPELLCAST_START", "target")
    M.Fire("START_AUTOREPEAT_SPELL")
    M.Fire("PLAYER_SWING", 1.6, 2)
    M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 6229)
    # At the class trainer, asking for the talent reset
    M.GOSSIP_OPTIONS = game.eval('{ { gossipOptionID = 102, name = "I wish to unlearn my talents." } }')
    M.Fire("GOSSIP_SHOW")
    M.POPUPS.CONFIRM_TALENT_WIPE = M.CreateFrame("Frame")
    M.Fire("CONFIRM_TALENT_WIPE", 10000, 0)
    M.RunTimers()
    M.Tick()
    gns.RefreshAll()
    return M, gns


# Checked first as a warlock: the same login does remind it of things, so the mage's is a real test
printed.clear()
W, wns = fresh_login("WARLOCK")
wshown = set(W.VisibleFrames().values())
check({"WarlockGodFood", "WarlockGodReminders", "WarlockGodShards", "WarlockGodDemonHealth", "WarlockGodRange",
       "WarlockGodBarrier", "WarlockGodWand", "WarlockGodInterrupt", "WarlockGodRespec"} <= wshown,
      f"as a warlock that login shows its reminders, bars and warnings: {sorted(wshown)}")
wrows = [r.text.text for r in wns.FoodState().reagentRows.values() if r.shown]
check(ns.REPAIR_TEXT.WORN % 5 in wrows and ns.REPAIR_TEXT.BAGS % 2 in wrows, f"the worn gear and the bags among them: {wrows}")
check(any(ns.REPAIR_TEXT.VENDOR % 5 in line for line in printed), f"and the repair vendor's line in the chat: {printed[:2]}")
printed.clear()
M, mns = fresh_login("MAGE")
shown = list(M.VisibleFrames().values())
check(not shown, f"a mage logged in: nothing of WarlockGod's on screen: {shown}")
check(M.NAMED["WarlockGodMinimapButton"].shown, "only its minimap button")
check(not printed, f"and nothing in the chat (a vendor, a repair...): {printed}")
mmembers = mns.RemindersState()[1]
check(all(not m.click.shown for m in mmembers.values()), "no button to click either")
# Moving the displays: nothing to move
printed.clear()
mns.SetUnlocked(True)
check(not mns.unlocked and printed == [mns.L.PREFIX + mns.L.OTHER_CLASS], f"Move displays: it says there's nothing to move: {printed}")
shown = list(M.VisibleFrames().values())
check(not shown, f"and shows nothing: {shown}")
# Even if the addon were unlocked anyway: no sample of anything
mns.unlocked = True
mns.RefreshAll()
for f in M.FRAMES.values():
    if f.scripts.OnUpdate:
        f.scripts.OnUpdate(f, 0.3)
shown = list(M.VisibleFrames().values())
check(not shown, f"unlocked anyway: still nothing: {shown}")
icons = [m.key for m in mmembers.values() if m.frame.shown]
check(not icons, f"not even a reminder icon under its hidden row: {icons}")
mns.unlocked = False
mns.RefreshAll()
# What you ask still gets its answer
out = []
printed.clear()
M.SlashCmdList.WARLOCKGOD("bufos" if es else "buffs")
check(len(printed) >= 1, f"a command you type still answers in the chat: {printed[:1]}")
blocked = sorted(set(M.BLOCKED.values()))
check(not blocked, f"the mage's login touched nothing secure in a fight: {blocked}")
leaks = sorted(set(M.LEAKS.values()))
check(not leaks, f"nor left globals behind: {leaks}")

print()
blocked = sorted(set(G.BLOCKED.values()))
# ---------------------------------------------------------------- At a merchant: repair and buy reagents (shared files)
# (ClassGods/test_vendor_block.py: the same block in every ...God harness)
lua.execute('''
G.bought = {}
G.prices = {}
GetMerchantNumItems = function() return #G.merchant end
GetMerchantItemID = function(i) return G.merchant[i] end
GetMerchantItemInfo = function(i) local id = G.merchant[i] return "item " .. id, 0, G.prices[id] or 100, 1, -1, true end
GetMerchantItemMaxStack = function() return 20 end
BuyMerchantItem = function(i, n)
  local id = G.merchant[i]
  table.insert(G.bought, n)
  G.items[id] = (G.items[id] or 0) + n
  G.money = G.money - (G.prices[id] or 100) * n
end
GetMoney = function() return G.money or 0 end
GetRepairAllCost = function() return G.repairCost or 0, (G.repairCost or 0) > 0 end
RepairAllItems = function() G.repaired = (G.repaired or 0) + 1 G.money = G.money - G.repairCost G.repairCost = 0 end
CanMerchantRepair = function() return G.repairs end
GetCoinTextureString = nil
''')
if S["items"] is None:
    S["items"] = lua.table()
S.merchant = lua.table()
VT = ns.REPAIR_TEXT
me = {"HunterGod": "HUNTER", "MageGod": "MAGE", "WarriorGod": "WARRIOR", "PaladinGod": "PALADIN", "RogueGod": "ROGUE",
      "PriestGod": "PRIEST", "ShamanGod": "SHAMAN", "WarlockGod": "WARLOCK", "DruidGod": "DRUID"}[Path(ADDON).resolve().name]
S["class"] = me
other = "PRIEST" if me != "PRIEST" else "MAGE"
check(db.repair.auto is False and VT.OPT_AUTO, "repairing at a merchant: an option, off by default")
S.repairs, S.repairCost, S.money, S.repaired = True, 12345, 100000, 0
printed.clear()
G.Fire("MERCHANT_SHOW")
check(S.repaired == 0, "off: it doesn't repair")
db.repair.auto = True
printed.clear()
G.Fire("MERCHANT_SHOW")
check(S.repaired == 1 and S.money == 100000 - 12345 and len(printed) == 1 and VT.REPAIRED % "1g 23s 45c" in printed[0],
      f"on: it repairs everything and says what it cost: {list(printed)}")
printed.clear()
G.Fire("MERCHANT_SHOW")
check(S.repaired == 1, "nothing worn: it doesn't repair again")
S.repairCost, S.money = 50000, 1000
printed.clear()
G.Fire("MERCHANT_SHOW")
check(S.repaired == 1 and len(printed) == 1 and VT.SHORT % "5g 0s 0c" in printed[0],
      f"not enough money: says so and doesn't repair: {list(printed)}")
S.money = 100000
S.repairs = False
printed.clear()
G.Fire("MERCHANT_SHOW")
check(S.repaired == 1 and not printed, "a merchant who doesn't repair: nothing")
S.repairs = True
S["class"] = other
printed.clear()
G.Fire("MERCHANT_SHOW")
check(S.repaired == 1 and not printed, "another class: this addon doesn't repair (that class's own does)")
S["class"] = me
S.repairs, S.repairCost = False, 0
db.repair.auto = False

own = ns.REAGENTS[me] if ns.REAGENTS else None
r = None
if own:
    for i in range(1, len(own) + 1):
        if own[i].vendor and own[i].stock and G.C_Spell.GetSpellName(own[i].spells[1]):
            r = own[i]
            break
if r:
    RT2 = ns.REAGENT_TEXT
    check(db.reagents.buy is False and RT2.OPT_BUY, "buying reagents: an option, off by default")
    # Only its spell known: a better rank would take over
    for i in range(1, len(own) + 1):
        for j in range(1, len(own[i].spells) + 1):
            S.known[own[i].spells[j]] = None
    know(r.spells[1])
    G.Fire("SPELLS_CHANGED")
    S["items"][r.item] = 2
    S.merchant = lua.table(159, r.item)
    S.money = 1000000
    printed.clear()
    G.Fire("MERCHANT_SHOW")
    check(len(S.bought) == 0, "off: it doesn't buy")
    db.reagents.buy = True
    printed.clear()
    G.Fire("MERCHANT_SHOW")
    want = r.stock - 2
    check(S["items"][r.item] == r.stock and sum(S.bought[i] for i in range(1, len(S.bought) + 1)) == want
          and all(S.bought[i] <= 20 for i in range(1, len(S.bought) + 1)),
          f"on: it buys up to {r.stock}, at most a stack at a time: {S['items'][r.item]}")
    money = f"{want * 100 // 10000}g {want * 100 // 100 % 100}s 0c"
    check(len(printed) == 1 and RT2.BOUGHT.split("%d")[0] in printed[0] and money in printed[0],
          f"and says what it bought and spent: {list(printed)}")
    bought = len(S.bought)
    printed.clear()
    G.Fire("MERCHANT_SHOW")
    check(len(S.bought) == bought and not printed, "enough already: nothing")
    S["items"][r.item] = 0
    S.money = 250
    printed.clear()
    G.Fire("MERCHANT_SHOW")
    check(S["items"][r.item] == 2, f"only what the money pays for: {S['items'][r.item]}")
    S.money = 0
    S["items"][r.item] = 0
    printed.clear()
    G.Fire("MERCHANT_SHOW")
    check(S["items"][r.item] == 0 and len(printed) == 1 and RT2.SHORT.split("%s")[0] in printed[0],
          f"no money: says so: {list(printed)}")
    S.money = 1000000
    S["class"] = other
    printed.clear()
    G.Fire("MERCHANT_SHOW")
    check(S["items"][r.item] == 0, "another class: this addon doesn't buy")
    S["class"] = me
    db.reagents.enabled = False
    G.Fire("MERCHANT_SHOW")
    check(S["items"][r.item] == r.stock, "it buys with the low reagent reminder off too")
    db.reagents.enabled = True
    db.reagents.buy = False
    know(r.spells[1], on=False)
    G.Fire("SPELLS_CHANGED")
    S["items"][r.item] = 0
    S.merchant = lua.table()
    G.Fire("BAG_UPDATE_DELAYED")

check(not blocked, f"nothing secure touched in a fight (the game blocks it): {blocked}")
leaks = sorted(set(G.LEAKS.values()))
check(not leaks, f"no globals left behind: {leaks}")

print("FAILURES:" if fails else f"All good ({LOCALE}).", fails if fails else "")
sys.exit(1 if fails else 0)
