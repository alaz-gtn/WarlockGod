local _, ns = ...
local L = ns.L

-- Spell Lock's icon beside your target's nameplate while it casts something you can stop and your
-- interrupt is ready: small, in a thin black edge, with a soft glow (as MageGod's Counterspell). A
-- warlock's interrupt is the Felhunter's Spell Lock: so only with a Felhunter out that knows it.
-- Forever lets addons see whether a spell's cooldown is running even in combat. In a fight it may
-- hide the target's cast, and whether it can be stopped: then the game itself shows or hides the
-- icon (SetAlphaFromBoolean on that secret). Spell Lock's reach is the Felhunter's, which the addon
-- can't measure: it doesn't say "in range"
local SPELL_LOCK = { 19647, 19244 } -- best first
local DEFAULT_POINT = { "CENTER", "CENTER", 0, 120 } -- with no nameplate to sit by
local SIZE = 30
local POLL = 0.1

local db
local frame
local lock -- the Spell Lock your Felhunter knows: { id, slot }
local plate

-- Does your demon know Spell Lock: as a pet spell, or on its action bar
local function FindLock()
	lock = nil
	if not ns.HasDemon or not ns.HasDemon() then return end
	for _, id in ipairs(SPELL_LOCK) do
		local known = IsSpellKnown and IsSpellKnown(id, true)
		if known and not ns.IsSecret(known) then
			lock = { id = id }
			break
		end
	end
	-- Its place on the pet bar, to ask its cooldown there too
	local name = ns.SpellName(SPELL_LOCK[1])
	if GetPetActionInfo and name then
		for slot = 1, NUM_PET_ACTION_SLOTS or 10 do
			local slotName = GetPetActionInfo(slot)
			if slotName and not ns.IsSecret(slotName) and slotName == name then
				lock = lock or { id = SPELL_LOCK[#SPELL_LOCK] }
				lock.slot = slot
				break
			end
		end
	end
end

-- Is it ready: true, false, or nil when the game won't say
local function Ready()
	if not lock then return false end
	if C_Spell and C_Spell.GetSpellCooldown then
		local info = C_Spell.GetSpellCooldown(lock.id)
		if type(info) == "table" and not ns.IsSecret(info) then
			local active = info.isActive
			if active ~= nil and not ns.IsSecret(active) then return not active end
		end
	end
	if lock.slot and GetPetActionCooldown then
		local start, duration = GetPetActionCooldown(lock.slot)
		if not (ns.IsSecret(start) or ns.IsSecret(duration)) and start then
			return start == 0 or not duration or duration <= 1.6 or start + duration <= GetTime()
		end
	end
end

-- Is the target casting? And can it be stopped: true, false, or the game's secret "can't be
-- stopped" (in a fight Forever may hide it; then the game itself shows or hides the icon). A hidden
-- spell still counts as a cast
local function Casting()
	if not UnitExists("target") then return false end
	local hostile = UnitCanAttack("player", "target")
	if not ns.IsSecret(hostile) and not hostile then return false end
	for _, get in ipairs({ UnitCastingInfo, UnitChannelInfo }) do
		if get then
			-- notInterruptible and the cast bar's number sit in different places for the two
			local name, _, _, _, _, _, a, b, _, d, e = get("target")
			local notInterruptible, castBar
			if get == UnitCastingInfo then notInterruptible, castBar = b, d else notInterruptible, castBar = a, e end
			-- A hidden value can't even be compared with nil: asked first
			if ns.IsSecret(name) or name ~= nil or (not ns.IsSecret(castBar) and castBar ~= nil) then
				if ns.IsSecret(notInterruptible) then return true, notInterruptible end
				return true, notInterruptible ~= true
			end
		end
	end
	return false
end

local function TargetPlate()
	if ns.unlocked or not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return end
	local p = C_NamePlate.GetNamePlateForUnit("target")
	if p and not (p.IsForbidden and p:IsForbidden()) then return p end
end

-- Left of the target's health bar, or where you put it
local function Place()
	local newPlate = TargetPlate()
	if newPlate == plate and frame.placed then return end
	plate, frame.placed = newPlate, true
	frame:ClearAllPoints()
	if newPlate then
		frame:SetPoint("RIGHT", ns.PlateBar and ns.PlateBar(newPlate) or newPlate, "LEFT", -6, 0)
	else
		ns.PlaceFrame(frame)
	end
end

function ns.UpdateInterrupt()
	if not frame then return end
	local show, cuttable = false, true
	if ns.unlocked then
		show = db.enabled and ns.IsWarlock()
	elseif db.enabled and ns.IsWarlock() and not ns.Dead() and lock ~= nil then
		local casting
		casting, cuttable = Casting()
		-- A secret can't be compared: only a plain "no" hides it here
		show = casting and (ns.IsSecret(cuttable) or cuttable) and Ready() ~= false
	end
	if show then
		Place()
		-- Whether it can be stopped, as the game says even when it keeps it from the addon: the game
		-- shows or hides the icon itself (the secret is "can't be stopped": true hides it)
		frame.inner:SetAlpha(1)
		if ns.IsSecret(cuttable) then pcall(frame.inner.SetAlphaFromBoolean, frame.inner, cuttable, 0, 1) end
		if not frame:IsShown() then frame.glow:Play() end
		frame:Show()
	else
		frame.glow:Stop()
		frame:Hide()
		frame.placed = nil
	end
end

-- For the tests
function ns.InterruptState() return { frame = frame, lock = lock } end

local poller = CreateFrame("Frame")
poller:Hide()
local waited = 0
poller:SetScript("OnUpdate", function(self, elapsed)
	waited = waited + elapsed
	if waited < POLL then return end
	waited = 0
	ns.UpdateInterrupt()
	-- Watched while the target casts
	if not (frame:IsShown() or (lock and Casting())) then self:Hide() end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		self:UnregisterEvent("PLAYER_LOGIN")
		db = ns.db.interrupt
		frame = CreateFrame("Frame", "WarlockGodInterrupt", UIParent)
		frame:SetSize(SIZE, SIZE)
		frame:SetFrameStrata("HIGH")
		-- What shows, in its own frame: the game may set its see-through for a cast it hides
		frame.inner = CreateFrame("Frame", nil, frame)
		frame.inner:SetAllPoints()
		frame.edge = frame.inner:CreateTexture(nil, "BACKGROUND")
		frame.edge:SetAllPoints()
		frame.edge:SetColorTexture(0, 0, 0, 1)
		frame.icon = frame.inner:CreateTexture(nil, "ARTWORK")
		frame.icon:SetPoint("TOPLEFT", 1, -1)
		frame.icon:SetPoint("BOTTOMRIGHT", -1, 1)
		frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		frame.icon:SetTexture(ns.SpellIcon(SPELL_LOCK[2]))
		-- A soft glow that breathes while you can stop the cast
		frame.glow = frame:CreateAnimationGroup()
		frame.glow:SetLooping("BOUNCE")
		local fade = frame.glow:CreateAnimation("Alpha")
		fade:SetFromAlpha(1)
		fade:SetToAlpha(0.6)
		fade:SetDuration(0.35)
		frame:Hide()
		ns.Movable(frame, "interrupt", DEFAULT_POINT, L.INTERRUPT_NAME)
		table.insert(ns.refreshers, function()
			frame.placed = nil
			ns.UpdateInterrupt()
		end)
		for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
			"UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
			"UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" }) do
			pcall(self.RegisterUnitEvent, self, e, "target")
		end
		-- An event the game doesn't have would stop the rest of the file
		for _, e in ipairs({ "PLAYER_TARGET_CHANGED", "SPELL_UPDATE_COOLDOWN", "PET_BAR_UPDATE",
			"PET_BAR_UPDATE_COOLDOWN", "SPELLS_CHANGED", "NAME_PLATE_UNIT_ADDED" }) do
			pcall(self.RegisterEvent, self, e)
		end
		pcall(self.RegisterUnitEvent, self, "UNIT_PET", "player")
		FindLock()
	elseif event == "PET_BAR_UPDATE" or event == "SPELLS_CHANGED" or event == "UNIT_PET" then
		FindLock()
	elseif event == "PLAYER_TARGET_CHANGED" or event == "NAME_PLATE_UNIT_ADDED" then
		frame.placed = nil
	end
	ns.UpdateInterrupt()
	if lock and Casting() then poller:Show() end
end)
