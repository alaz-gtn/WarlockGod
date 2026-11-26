local _, ns = ...
local L = ns.L

-- Your effects on your target, each a small icon in a thin black frame with its seconds, in a row
-- beside the target's nameplate: Corruption, Immolate, your Bane, your Curse, Siphon Life, your
-- Fear, Banish, Howl or Death Coil, and the talents' Shadow Vulnerability and Demonic Brand.
-- Forever keeps a target's auras from addons in combat, so the game draws them itself, as
-- ForeverAuras does: an aura container on "target" with a group of your own debuffs
-- (HARMFUL|PLAYER) among the spells you know; the game lays the icons out in a row, puts each
-- one's picture in and counts its time down
local GROUPS = {
	{ key = "corruption", spells = { 172, 6222, 6223, 7648, 11671, 11672, 25311 } },
	{ key = "immolate", spells = { 348, 707, 1094, 2941, 11665, 11667, 11668, 25309 } },
	-- One Bane per warlock on a target: Agony, Doom or Havoc
	{ key = "banes", spells = { 980, 1014, 6217, 11711, 11712, 11713, 603, 1225228 } },
	-- One Curse per warlock on a target: the Elements, Weakness, Recklessness, Tongues, Exhaustion
	{ key = "curses", spells = { 440892, 1311676, 1311677, 1311680, 702, 1108, 6205, 7646, 11707, 11708,
		704, 7658, 7659, 11717, 1714, 11719, 18223 } },
	{ key = "siphonLife", spells = { 18265, 18879, 18880, 18881 } },
	-- Fear, Banish, Howl of Terror, Death Coil
	{ key = "control", spells = { 5782, 6213, 6215, 710, 18647, 5484, 17928, 6789, 17925, 17926 } },
	-- From talents: what your Shadow Bolt crits leave, and your demon's brand
	{ key = "vulnerability", spells = { 17794 }, talent = { 17793 } },
	{ key = "brand", spells = { 1293696 }, talent = { 1293695 } },
}
ns.DEBUFF_GROUPS = GROUPS
local GROUP = "WarlockGodDots"
local MAX = 8
local GAP = 3
local DEFAULT_POINT = { "CENTER", "CENTER", 0, -235 } -- with no nameplate to sit by
local SAMPLE = { 172, 348, 980 } -- Corruption, Immolate, Bane of Agony

local db
local holder, container, sample
local watching -- the spells the container watches now, as a list, to tell a change
local pending -- something to do once the fight is over
local plate -- the nameplate it sits by
local styled = {} -- the buttons the game made, to fit them to your settings

-- The spells to watch: every rank of the ones you know, for the groups you have on
local function Spells()
	local spells, ids = {}, {}
	for _, g in ipairs(GROUPS) do
		if db.spells[g.key] then
			local known = g.talent and ns.Knows(g.talent)
			if not g.talent then
				-- Any of the group's spells you know brings in its ranks
				local byName = {}
				for _, id in ipairs(g.spells) do
					local name = ns.SpellName(id)
					if name and byName[name] == nil then byName[name] = ns.Knows({ id }) end
				end
				for _, id in ipairs(g.spells) do
					local name = ns.SpellName(id)
					if name and byName[name] and not spells[id] then
						spells[id] = true
						ids[#ids + 1] = id
					end
				end
			elseif known then
				for _, id in ipairs(g.spells) do
					spells[id] = true
					ids[#ids + 1] = id
				end
			end
		end
	end
	table.sort(ids)
	return spells, table.concat(ids, ",")
end

-- One of the game's buttons: a thin black frame, the icon the game puts in, and the seconds it
-- counts down
local function Style(button)
	button:EnableMouse(false)
	button.edge = button:CreateTexture(nil, "BACKGROUND")
	button.edge:SetAllPoints(button)
	button.edge:SetColorTexture(0, 0, 0, 1)
	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	pcall(button.SetIcon, button, button.icon)
	local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
	cooldown:SetAllPoints(button.icon)
	cooldown:SetDrawEdge(false)
	cooldown:SetDrawBling(false)
	cooldown:SetHideCountdownNumbers(false)
	if cooldown.SetUseAuraDisplayTime then cooldown:SetUseAuraDisplayTime(true) end
	if cooldown.SetMinimumCountdownDuration then cooldown:SetMinimumCountdownDuration(0) end
	pcall(button.SetDurationCooldown, button, cooldown)
	button.numbers = cooldown.GetCountdownFontString and cooldown:GetCountdownFontString()
	styled[#styled + 1] = button
	if db then
		local px = ns.OnePixel(button)
		button.icon:ClearAllPoints()
		button.icon:SetPoint("TOPLEFT", px, -px)
		button.icon:SetPoint("BOTTOMRIGHT", -px, px)
		if button.numbers then
			ns.UseFont(button.numbers, ns.FONTS[ns.db.range.font], max(floor(db.size * 0.5), 9), "OUTLINE")
			button.numbers:SetTextColor(1, 1, 1)
		end
	end
end

-- Their size and the space between them, which the game uses to lay them out
local function Layout()
	if not container then return end
	pcall(container.SetAuraGroupLayout, container, GROUP,
		{ elementWidth = db.size, elementHeight = db.size, elementSpacing = GAP })
	holder:SetSize(MAX * db.size + (MAX - 1) * GAP, db.size)
end

-- Beside the target's nameplate health bar, or where you put it
local function TargetPlate()
	if db.anchor ~= "plate" or ns.unlocked or not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return end
	local p = C_NamePlate.GetNamePlateForUnit("target")
	if p and not (p.IsForbidden and p:IsForbidden()) then return p end
end

local function Place()
	if not holder then return end
	-- A frame the game protects can't be moved in combat: it waits for the end of the fight
	if InCombatLockdown() and holder:IsProtected() then
		pending = true
		return
	end
	local newPlate = TargetPlate()
	if newPlate then
		if plate ~= newPlate or not holder.onPlate then
			holder:ClearAllPoints()
			local bar = ns.PlateBar and ns.PlateBar(newPlate) or newPlate
			holder:SetPoint("LEFT", bar, "RIGHT", 4, 0)
			holder.onPlate = true
		end
	elseif holder.onPlate or plate ~= nil or not holder:GetPoint() then
		holder.onPlate = false
		ns.PlaceFrame(holder)
	end
	plate = newPlate
end

-- Built out of combat. The spells you know change what it watches; a container that refuses is
-- left alone
local function Build()
	if InCombatLockdown() then
		pending = true
		return
	end
	if not (ns.IsWarlock() and CustomAuraContainerAuraProcessingPolicy and C_UnitAuras) then return end
	local spells, list = Spells()
	if container then
		if list ~= watching then
			pcall(container.SetAuraGroupCandidateFilters, container, GROUP, { includeSpellIDs = spells })
			watching = list
		end
		return
	end
	local ok, made = pcall(CreateFrame, "AuraContainer", nil, holder, "CustomAuraContainerTemplate")
	if not ok or not made then return end
	made:SetAllPoints(holder)
	made:SetEnabled(false)
	made:SetAuraProcessingPolicy(CustomAuraContainerAuraProcessingPolicy.None)
	-- Only yours; a client that doesn't know the player filter gets every one of these spells
	local options = { maxFrameCount = MAX, candidateFilters = { includeSpellIDs = spells }, initializeFrame = Style }
	if not pcall(made.AddAuraGroup, made, GROUP, "HARMFUL|PLAYER", options)
		and not pcall(made.AddAuraGroup, made, GROUP, "HARMFUL", options) then
		return
	end
	-- A row growing to the right from the left end
	if AnchorUtil and AnchorUtil.FlowLayoutAxis then
		pcall(made.SetFlowLayoutAxis, made, AnchorUtil.FlowLayoutAxis.Horizontal)
		pcall(made.SetFlowLayoutAnchorPoint, made, "LEFT")
		pcall(made.SetFlowLayoutGrowthDirection, made, AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Down)
	end
	container, watching = made, list
	Layout()
	made:SetUnit("target")
	made:SetEnabled(true)
end

function ns.StyleDebuffs()
	if not holder then return end
	local on = db.enabled and ns.IsWarlock()
	-- The sample: a few of your effects, still, to drag and size
	sample:SetShown(ns.unlocked and on)
	for i, icon in ipairs(sample.icons) do
		icon.box:SetSize(db.size, db.size)
		icon.box:ClearAllPoints()
		icon.box:SetPoint("LEFT", sample, "LEFT", (i - 1) * (db.size + GAP), 0)
		icon.text:SetText(({ "14", "9", "21" })[i])
		ns.UseFont(icon.text, ns.FONTS[ns.db.range.font], max(floor(db.size * 0.5), 9), "OUTLINE")
	end
	if InCombatLockdown() then
		pending = true
		return
	end
	Build()
	Layout()
	for _, button in ipairs(styled) do
		if button.numbers then
			ns.UseFont(button.numbers, ns.FONTS[ns.db.range.font], max(floor(db.size * 0.5), 9), "OUTLINE")
		end
	end
	holder:SetShown(on)
	Place()
end

-- For the tests
function ns.DebuffsState()
	return { holder = holder, container = container, sample = sample, watching = watching, styled = styled }
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, unit)
	if event == "PLAYER_LOGIN" then
		self:UnregisterEvent("PLAYER_LOGIN")
		db = ns.db.dots
		holder = CreateFrame("Frame", "WarlockGodDots", UIParent)
		holder:SetSize(MAX * db.size + (MAX - 1) * GAP, db.size)
		sample = CreateFrame("Frame", nil, holder)
		sample:SetAllPoints(holder)
		sample:Hide()
		sample.icons = {}
		for i, id in ipairs(SAMPLE) do
			local box = CreateFrame("Frame", nil, sample)
			local edge = box:CreateTexture(nil, "BACKGROUND")
			edge:SetAllPoints(box)
			edge:SetColorTexture(0, 0, 0, 1)
			local icon = box:CreateTexture(nil, "ARTWORK")
			icon:SetPoint("TOPLEFT", 1, -1)
			icon:SetPoint("BOTTOMRIGHT", -1, 1)
			icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			icon:SetTexture(ns.SpellIcon(id))
			local text = box:CreateFontString(nil, "OVERLAY")
			text:SetPoint("CENTER")
			sample.icons[i] = { box = box, text = text }
		end
		ns.Movable(holder, "dots", DEFAULT_POINT, L.DOTS_NAME)
		table.insert(ns.refreshers, ns.StyleDebuffs)
		self:RegisterEvent("PLAYER_TARGET_CHANGED")
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		self:RegisterEvent("SPELLS_CHANGED")
		pcall(self.RegisterEvent, self, "NAME_PLATE_UNIT_ADDED")
		pcall(self.RegisterEvent, self, "NAME_PLATE_UNIT_REMOVED")
		pcall(self.RegisterEvent, self, "CHARACTER_POINTS_CHANGED")
		ns.StyleDebuffs()
	elseif event == "PLAYER_REGEN_ENABLED" then
		if pending then
			pending = nil
			ns.StyleDebuffs()
		end
	elseif event == "SPELLS_CHANGED" or event == "CHARACTER_POINTS_CHANGED" then
		Build()
	else
		-- A new target, or a nameplate coming or going: only the target's matters. A secret can't
		-- be tested with and/or: asked first, and then it's placed again to be safe
		if event == "NAME_PLATE_UNIT_ADDED" or event == "NAME_PLATE_UNIT_REMOVED" then
			if not unit or ns.IsSecret(unit) or not UnitIsUnit then return end
			local same = UnitIsUnit(unit, "target")
			if not ns.IsSecret(same) and not same then return end
		end
		Place()
	end
end)
