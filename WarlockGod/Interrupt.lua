local _, ns = ...
local L = ns.L

-- INTERRUPT! beside your target's nameplate while it casts something you can stop and your
-- interrupt is ready. A warlock's is the Felhunter's Spell Lock: so only with a Felhunter out that
-- knows it. Forever lets addons see whether a spell's cooldown is running even in combat; the
-- target's cast may come hidden: then it counts as a cast you can stop, as nothing says otherwise.
-- Spell Lock's reach is the Felhunter's, which the addon can't measure: it doesn't say "in range"
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

-- Is your target casting something you can stop: true, false. A hidden cast counts
local function Casting()
	if not UnitExists("target") then return false end
	local hostile = UnitCanAttack("player", "target")
	if not ns.IsSecret(hostile) and not hostile then return false end
	-- name ... notInterruptible is the 8th for a cast, the 7th for a channel. A hidden value can't
	-- even be compared with nil: asked first
	local name, _, _, _, _, _, _, stop = UnitCastingInfo("target")
	if not ns.IsSecret(name) and name == nil then
		if not UnitChannelInfo then return false end
		local _
		name, _, _, _, _, _, stop = UnitChannelInfo("target")
		if not ns.IsSecret(name) and name == nil then return false end
	end
	if ns.IsSecret(stop) then return true end
	return not stop
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
	local show
	if ns.unlocked then
		show = db.enabled and ns.IsWarlock()
	else
		show = db.enabled and ns.IsWarlock() and not ns.Dead() and lock ~= nil and Casting() and Ready() ~= false
	end
	if show then
		Place()
		frame:Show()
	else
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
		frame:SetSize(SIZE + 120, SIZE)
		frame:SetFrameStrata("HIGH")
		frame.edge = frame:CreateTexture(nil, "BACKGROUND")
		frame.edge:SetPoint("RIGHT")
		frame.edge:SetSize(SIZE, SIZE)
		frame.edge:SetColorTexture(0, 0, 0, 1)
		frame.icon = frame:CreateTexture(nil, "ARTWORK")
		frame.icon:SetPoint("TOPLEFT", frame.edge, 1, -1)
		frame.icon:SetPoint("BOTTOMRIGHT", frame.edge, -1, 1)
		frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		frame.icon:SetTexture(ns.SpellIcon(SPELL_LOCK[2]))
		frame.text = frame:CreateFontString(nil, "OVERLAY")
		frame.text:SetPoint("RIGHT", frame.edge, "LEFT", -6, 0)
		frame.text:SetTextColor(1, 0.4, 0.25)
		ns.FancyFont(frame.text, 18, "THICKOUTLINE")
		frame.text:SetText(L.INTERRUPT)
		frame:Hide()
		ns.Movable(frame, "interrupt", DEFAULT_POINT, L.INTERRUPT_NAME)
		table.insert(ns.refreshers, function()
			frame.placed = nil
			ns.UpdateInterrupt()
		end)
		for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
			"UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP" }) do
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
