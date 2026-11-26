local addonName, ns = ...
local L = ns.L

-- The warlock's class colour, #8788EE
ns.ACCENT = { 0.53, 0.53, 0.93 }

-- Settings: whatever is missing from the saved ones is filled in from here
local defaults = {
	buffs = {
		enabled = true,
		armor = true, -- Demon Skin, then Demon Armor
		warnMinutes = 2, -- the reminder shows this long before a buff ends
		combat = false, -- in a fight the armor and stone reminders would only get in the way
		click = true, -- clicking a reminder casts it, out of combat
	},
	-- Healthstone, Soulstone, and Forever's Firestone and Spellstone, which now imbue your weapon
	stones = {
		healthstone = true,
		soulstone = true,
		soulstoneUse = true, -- also when you carry one ready to use
		weapon = true,
		weaponChoice = "auto", -- auto (the last one you used) | spellstone | firestone
	},
	lastWeaponStone = nil, -- spellstone | firestone
	shards = {
		enabled = true,
		always = true, -- the count always there, not only when you're short or carry too many
		low = 3, -- fewer than this: red
		max = 20, -- more than this: orange
	},
	food = { enabled = true },
	demon = {
		missing = true,
		choice = "auto", -- auto (the last one you summoned) | imp | voidwalker | succubus | incubus | felhunter
		soulLink = true,
		health = true,
		healthPct = 35, -- warn under this much of the demon's health
	},
	lastDemon = nil, -- the last demon you summoned: imp | voidwalker | ...
	-- At the class trainer: when the talent reset price drops. The trainer options seen to lead to the reset
	respec = { enabled = true, options = {} },
	-- Shadow flames on both sides of you while Shadow Trance is up, and icons for Forever's other procs
	-- What's left of any shield on you (your Shadow Ward, your Voidwalker's Sacrifice, a priest's, a
	-- protection potion...), on a bar you size to sit over the game's own
	barrier = {
		enabled = true, width = 160, height = 14, text = true, time = true,
		icon = true, -- the shield's icon on a tag at its left end
		color = { r = 0.62, g = 0.4, b = 1 }, -- Shadow Ward's, and a shield the addon can't tell
		-- Each other shield in its own colour; the protection potions in their school's
		colors = {
			sacrifice = { r = 0.42, g = 0.3, b = 0.78 }, -- the Voidwalker's
			barrier = { r = 0.52, g = 0.78, b = 0.92 }, -- a mage's, as MageGod's
			manaShield = { r = 0.6, g = 0.5, b = 1 },
			fireWard = { r = 1, g = 0.5, b = 0.15 },
			frostWard = { r = 0.75, g = 0.95, b = 1 },
			powerWord = { r = 1, g = 0.92, b = 0.6 }, -- a priest's Power Word: Shield
			fire = { r = 1, g = 0.42, b = 0.1 },
			frost = { r = 0.45, g = 0.75, b = 1 },
			nature = { r = 0.4, g = 0.85, b = 0.3 },
			shadow = { r = 0.62, g = 0.38, b = 0.85 },
			arcane = { r = 0.85, g = 0.55, b = 1 },
			holy = { r = 1, g = 0.85, b = 0.35 },
		},
		potions = true, -- the protection potions too: each absorbs a school's damage for 2 minutes
	},
	-- Your big cooldowns back: their icon big in the middle, fading fast (as MageGod's Blink)
	pulse = {
		enabled = true, size = 64, alpha = 90,
		color = { r = 0.6, g = 0.4, b = 1 }, -- the shine behind it
		spells = {
			deathCoil = true, howl = true, felDomination = true, amplifyCurse = true, inferno = true,
			ritualOfDoom = true, soulstone = true,
			soulFire = false, baneOfDoom = false, shadowWard = false, -- short: they'd come too often
		},
	},
	-- Your effects on your target, beside its nameplate
	dots = {
		enabled = true, size = 22,
		anchor = "plate", -- plate | free
		spells = {
			corruption = true, immolate = true, banes = true, curses = true, siphonLife = true,
			control = true, vulnerability = true, brand = true,
		},
	},
	-- INTERRUPT! while your target casts and your Felhunter's Spell Lock is ready
	interrupt = { enabled = true },
	-- Your wand's swing timer (Shoot): HunterGod's Auto Shot bar on its own
	wand = {
		enabled = true, width = 180, height = 14, time = true, icon = true,
		color = { r = 0.6, g = 0.5, b = 1 },
	},
	-- Your buffs someone in your group lacks (GroupBuffs.lua: a warlock has none, the file is the family's)
	groupBuffs = { enabled = true },
	-- Gear under this % and bags with this many free slots or fewer, beside the chat (Repair.lua)
	repair = { enabled = true, low = 25, bags = 2 },
	-- Reagents running low, beside the chat with the food reminder (Reagents.lua)
	reagents = { enabled = true },
	-- Herbalism or Mining without its tracking on, out in the world (Gathering.lua)
	gather = { enabled = true },
	-- Small and faint by default, as HunterGod's since 1.5.1: the family's line
	procs = {
		size = 40, -- %: around your character, not over half the screen
		gap = 140, -- from the middle to each side
		alpha = 60, -- the burst as it comes, %
		calm = 20, -- the flames while it lasts: faint, %
		timer = true, -- the seconds it has left, under it
		timerSize = 20,
		-- Each one shows only if your build has its talent
		trance = { enabled = true, color = { r = 0.55, g = 0.36, b = 1 } }, -- shadow flames
		harvest = { enabled = true, color = { r = 0.45, g = 0.82, b = 1 } }, -- pale souls
		decimation = { enabled = true, color = { r = 0.45, g = 1, b = 0.25 } }, -- fel fire
		shadow = { enabled = true, color = { r = 0.62, g = 0.35, b = 1 } }, -- Shadow and Flame: Shadow
		flame = { enabled = true, color = { r = 1, g = 0.5, b = 0.15 } }, -- and Flame
		learned = {}, -- other spells the addon saw by a proc's name
		ignored = {}, -- ones it saw always on: a passive, not the proc
	},
	range = {
		enabled = true,
		spell = "auto", -- auto (the last one you cast) | shadowbolt | immolate | corruption
		lastSpell = nil,
		threat = true,
		threatPct = 90, -- warn from this % of the threat of whoever has the aggro
		onlyCombat = false,
		style = "text", -- text | icon | both
		anchor = "plate", -- plate | free
		plateSide = "top", -- top | bottom | left | right
		plateGap = 2,
		units = "yards", -- yards | meters
		display = "number", -- number | bracket
		font = "fredoka", -- fredoka | changa | game
		showState = false,
		farGlow = true, -- glowing in the last 5 yards of your reach
		textSize = 26,
		colors = {
			melee = { r = 1, g = 0.2, b = 0.2 },
			drain = { r = 1, g = 0.82, b = 0 },
			ranged = { r = 0.3, g = 1, b = 0.3 },
			far = { r = 0.7, g = 0.62, b = 1 },
			out = { r = 0.6, g = 0.6, b = 0.6 },
		},
	},
	minimapButton = { hide = false, angle = 200 },
	positions = {},
}

local function Fill(saved, default)
	for k, v in pairs(default) do
		if saved[k] == nil then
			saved[k] = type(v) == "table" and Fill({}, v) or v
		elseif type(v) == "table" and type(saved[k]) == "table" then
			Fill(saved[k], v)
		end
	end
	return saved
end

function ns.Print(msg)
	print(L.PREFIX .. msg)
end

-- Fonts as shared font objects, one per file, size and outline, applied with SetFontObject.
-- Each text loading the font file itself (SetFont on the FontString) left some texts undrawn in
-- Forever: FarmGod's tabs, 23 Nov 2026, had their text, shown, at full alpha and with a width,
-- and nothing on screen. The game's font goes in first, so a font that can't load still shows
local fontObjects, fontCount = {}, 0
function ns.UseFont(fontString, file, size, flags)
	local gameFont = GameFontNormal:GetFont()
	file, flags = file or gameFont, flags or ""
	local key = file .. "|" .. size .. "|" .. flags
	local font = fontObjects[key]
	if not font then
		fontCount = fontCount + 1
		font = CreateFont("WarlockGodFont" .. fontCount)
		font:SetFont(gameFont, size, flags)
		font:SetFont(file, size, flags)
		fontObjects[key] = font
	end
	-- The font object brings its own colour and shadow: the text keeps the ones it had
	local r, g, b, a = fontString:GetTextColor()
	local sx, sy = fontString:GetShadowOffset()
	local sr, sg, sb, sa = fontString:GetShadowColor()
	fontString:SetFontObject(font)
	if r then fontString:SetTextColor(r, g, b, a) end
	if sx then fontString:SetShadowOffset(sx, sy) end
	if sr then fontString:SetShadowColor(sr, sg, sb, sa) end
end

-- Forever hides some values from addons during combat
function ns.IsSecret(value)
	return issecretvalue and issecretvalue(value) or false
end

function ns.IsWarlock()
	return select(2, UnitClass("player")) == "WARLOCK"
end

function ns.SpellName(id)
	if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
	return (GetSpellInfo(id))
end

function ns.SpellIcon(id)
	if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
	return GetSpellTexture(id)
end

function ns.ItemIcon(item)
	return C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(item) or GetItemIcon and GetItemIcon(item)
end

function ns.ItemName(item)
	return C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(item) or GetItemInfo and (GetItemInfo(item))
end

-- How many you carry; nil when the game hides it
function ns.ItemCount(item)
	local count = C_Item and C_Item.GetItemCount and C_Item.GetItemCount(item) or GetItemCount and GetItemCount(item)
	if ns.IsSecret(count) then return nil end
	return count or 0
end

-- Do you know any of these ranks? Forever may give a spell other ids: then the spellbook
-- answers for its name
function ns.Knows(ids)
	for _, id in ipairs(ids) do
		local known
		if IsPlayerSpell then known = IsPlayerSpell(id) elseif IsSpellKnown then known = IsSpellKnown(id) end
		if known and not ns.IsSecret(known) then return true end
	end
	local name = ns.SpellName(ids[1])
	if name and C_Spell and C_Spell.GetSpellInfo then
		local info = C_Spell.GetSpellInfo(name)
		return type(info) == "table" and not ns.IsSecret(info)
	end
	return false
end

function ns.AurasHidden()
	return C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() or false
end

-- Your buffs by name: { [name] = { ends = GetTime() or math.huge, duration, id } }, or nil when the
-- game hides them (in combat, in Forever)
function ns.ReadBuffs()
	if ns.AurasHidden() or not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return end
	local found = {}
	for i = 1, 40 do
		local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
		if not aura then break end
		if ns.IsSecret(aura) or ns.IsSecret(aura.name) or ns.IsSecret(aura.expirationTime) then return end
		if not found[aura.name] then
			local expires, duration = aura.expirationTime, aura.duration
			found[aura.name] = {
				ends = type(expires) == "number" and expires > 0 and expires or math.huge,
				duration = type(duration) == "number" and not ns.IsSecret(duration) and duration or 0,
				id = aura.spellId,
			}
		end
	end
	return found
end

function ns.Dead()
	local dead = UnitIsDeadOrGhost("player")
	if ns.IsSecret(dead) then return false end
	return dead or (UnitOnTaxi and UnitOnTaxi("player")) or false
end

-- "1:20" or "1:02:03"
function ns.Clock(seconds)
	seconds = floor(seconds)
	if seconds >= 3600 then
		return format("%d:%02d:%02d", floor(seconds / 3600), floor(seconds % 3600 / 60), seconds % 60)
	end
	return format("%d:%02d", floor(seconds / 60), seconds % 60)
end

-- The addon's round font over the game's one, in case it can't load (a new file needs the
-- game restarted)
ns.FONTS = {
	fredoka = "Interface\\AddOns\\WarlockGod\\media\\FredokaOne-Regular.ttf",
	changa = "Interface\\AddOns\\WarlockGod\\media\\Changa-Bold.ttf",
}
function ns.FancyFont(fontString, size, flags)
	ns.UseFont(fontString, ns.FONTS[ns.db.range.font], size, flags)
end

-- The thin letters of the small rows: the game's narrow Arial, over its usual font in case it
-- isn't there
local THIN_FONT = "Fonts\\ARIALN.TTF"
function ns.ThinFont(fontString, size)
	fontString:SetFont(GameFontNormal:GetFont(), size, "")
	fontString:SetFont(THIN_FONT, size, "")
end

-- One pixel of the screen in a frame's own units: an edge one UI unit wide comes out blurry, or
-- not at all, depending on your UI scale
function ns.OnePixel(frame)
	if not (PixelUtil and PixelUtil.GetPixelToUIUnitFactor) then return 1 end
	local scale = frame:GetEffectiveScale()
	if ns.IsSecret(scale) or not scale or scale <= 0 then return 1 end
	return PixelUtil.GetPixelToUIUnitFactor() / scale
end

-- Each module adds the function that redraws it; the options call them all
ns.refreshers = {}
function ns.RefreshAll()
	for _, refresh in ipairs(ns.refreshers) do
		refresh()
	end
end

-- Displays the player can drag around while they are unlocked
ns.movers = {}
ns.unlocked = false

function ns.PlaceFrame(frame)
	local p = ns.db.positions[frame.moverKey]
	-- Some displays sit next to something of the game's until you move them
	if not p and frame.placeDefault and frame:placeDefault() then return end
	p = p or frame.defaultPoint
	frame:ClearAllPoints()
	frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
end

-- While unlocked each display gets a box on top of it, big enough to grab
local function SizeHandle(frame)
	local w, h = frame:GetWidth() or 0, frame:GetHeight() or 0
	if ns.IsSecret(w) or ns.IsSecret(h) then w, h = 0, 0 end
	frame.mover:SetSize(max(w + 16, 140), max(h + 16, 44))
end

function ns.Movable(frame, key, defaultPoint, label)
	frame.moverKey = key
	frame.defaultPoint = defaultPoint
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	local handle = CreateFrame("Frame", nil, frame)
	handle:SetPoint("CENTER")
	handle:SetFrameLevel(frame:GetFrameLevel() + 20)
	handle:EnableMouse(true)
	handle:RegisterForDrag("LeftButton")
	handle:SetScript("OnDragStart", function()
		if not InCombatLockdown() then frame:StartMoving() end
	end)
	handle:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		local point, _, relPoint, x, y = frame:GetPoint()
		if x and not ns.IsSecret(x) then
			ns.db.positions[key] = { point, relPoint, x, y }
		end
	end)
	local box = handle:CreateTexture(nil, "BACKGROUND")
	box:SetAllPoints()
	box:SetColorTexture(ns.ACCENT[1], ns.ACCENT[2], ns.ACCENT[3], 0.35)
	local name = handle:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	name:SetPoint("CENTER")
	name:SetText(label)
	handle:Hide()
	frame.mover = handle
	ns.movers[key] = frame
	ns.PlaceFrame(frame)
end

function ns.SetUnlocked(on)
	if InCombatLockdown() then
		ns.Print(L.NOT_IN_COMBAT)
		return
	end
	ns.unlocked = on
	if not on then
		for _, frame in pairs(ns.movers) do ns.PlaceFrame(frame) end
	end
	ns.RefreshAll() -- while unlocked the displays show a sample, so the boxes fit them
	for _, frame in pairs(ns.movers) do
		SizeHandle(frame)
		frame.mover:SetShown(on)
	end
	ns.Print(on and L.UNLOCKED or L.LOCKED)
end

-- Slash command words: each module adds its own
ns.commands = {}

local function Help()
	for _, line in ipairs(L.HELP) do
		print(line)
	end
end

ns.commands.unlock = function() ns.SetUnlocked(true) end
ns.commands.desbloquear = ns.commands.unlock
ns.commands.lock = function() ns.SetUnlocked(false) end
ns.commands.bloquear = ns.commands.lock
ns.commands.help = Help
ns.commands.ayuda = Help

SLASH_WARLOCKGOD1 = "/warlockgod"
SLASH_WARLOCKGOD2 = "/brujo"
SlashCmdList.WARLOCKGOD = function(msg)
	local word = strlower(strtrim(msg or ""))
	if word == "" then
		if ns.ToggleOptions then ns.ToggleOptions() end
		return
	end
	local command = ns.commands[word]
	if command then
		command(word)
	else
		Help()
	end
end

-- Settings saved by an older version, brought up to date
local SETTINGS_VERSION = 2
function ns.MigrateSettings(saved, fresh)
	-- The first 0.1.0 tried in the game saved bigger and stronger flames: the family's smaller ones
	-- now, unless you had changed them
	if not fresh and (saved.version or 1) < 2 and type(saved.procs) == "table" then
		local procs, new = saved.procs, defaults.procs
		if procs.size == 60 then procs.size = new.size end
		if procs.gap == 150 then procs.gap = new.gap end
		if procs.alpha == 85 then procs.alpha = new.alpha end
		if procs.calm == 30 then procs.calm = new.calm end
		if procs.timerSize == 22 then procs.timerSize = new.timerSize end
	end
	saved.version = SETTINGS_VERSION
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, name)
	if name ~= addonName then return end
	local fresh = WarlockGodDB == nil
	WarlockGodDB = Fill(WarlockGodDB or {}, defaults)
	ns.db = WarlockGodDB
	ns.MigrateSettings(WarlockGodDB, fresh)
	self:UnregisterEvent("ADDON_LOADED")
end)
