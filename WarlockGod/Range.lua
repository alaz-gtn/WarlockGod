local _, ns = ...
local L = ns.L

-- The state comes from the range steps and your spells: within 5 yards it's on you, Drain Life
-- (or Fear, before you learn it) says whether your drains reach it, about 20 yards, and your main
-- spell whether you can hit it from where you are, about 30. Grim Reach and Destructive Reach
-- make them longer: the game's answer already counts them
local SPELLS = { shadowbolt = 686, immolate = 348, corruption = 172 }
local SPELL_ORDER = { "shadowbolt", "immolate", "corruption" }
local DRAINS = { 689, 5782 } -- Drain Life, Fear
ns.RANGE_SPELLS, ns.RANGE_SPELL_ORDER = SPELLS, SPELL_ORDER
local MELEE, DRAIN, REACH = 5, 20, 30
local YARD = 0.9144

-- Items whose use range measures the distance to an enemy, by yards. From the
-- Classic lists of LibRangeCheck-3.0 (MIT); several per step in case one isn't cached.
ns.RANGE_ITEMS = {
	{ 5, { 8149, 15826, 16308, 17117, 22259, 22432 } },
	{ 10, { 9606, 9618, 9619, 9620, 9621, 10699, 17626, 17689 } },
	{ 15, { 4559 } },
	{ 20, { 1191, 2012, 4388, 10645, 13892, 17757, 18209, 22048 } },
	{ 25, { 13289 } },
	{ 30, { 835, 1404, 1434, 4479, 4480, 4481, 4941, 5079, 9328, 17202, 20084, 21038 } },
	{ 35, { 1399, 1402, 18904, 1258, 8688 } },
	{ 40, { 4945, 8348 } },
	{ 100, { 5418, 17162, 23715, 23718, 23719, 23721, 23722 } },
}
-- Interact distances in yards on Forever (as GoodRange measures them): 3 is the close
-- one, 4 the long one; Tauren and Undead are a little shorter
local INTERACT = { [3] = 8, [4] = 28 }
local INTERACT_RACE = { Tauren = { [3] = 6, [4] = 25 }, Scourge = { [3] = 7, [4] = 27 } }

local db, frame, plate
-- Where the range and the aggro warning go when they aren't on the target's nameplate. You
-- drag these spots, never anchored to a nameplate: in Forever one that was can't be dragged
local rangeSpot = CreateFrame("Frame", "WarlockGodRangeSpot", UIParent)
rangeSpot:SetSize(80, 30)
local threatSpot = CreateFrame("Frame", "WarlockGodThreatSpot", UIParent)
threatSpot:SetSize(120, 20)
local elapsed = 0
local names = {} -- your spells by name: the game answers for the rank you know
local byName = {}
local known = {}
local drainName -- the drain that measures the middle distance, the first of DRAINS you know
local steps = {} -- { yards, item or interact }, ascending
local stepsMissing = false

-- true / false, or nil when the game doesn't say
local function Answer(v)
	if ns.IsSecret(v) then return nil end
	if v == true or v == 1 then return true end
	if v == false or v == 0 then return false end
end

local function InRange(spell, unit)
	if not spell then return end
	if C_Spell and C_Spell.IsSpellInRange then
		return Answer(C_Spell.IsSpellInRange(spell, unit))
	end
	return Answer(IsSpellInRange(spell, unit))
end

-- Only items the game has loaded give real answers
local function ItemReady(id)
	local getInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
	if C_Item and C_Item.IsItemDataCachedByID and not C_Item.IsItemDataCachedByID(id) then return false end
	return getInfo(id) ~= nil
end

local function BuildSteps()
	wipe(steps)
	stepsMissing = false
	for _, step in ipairs(ns.RANGE_ITEMS) do
		local found
		for _, id in ipairs(step[2]) do
			if ItemReady(id) then
				found = id
				break
			end
			if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
		end
		if found then
			steps[#steps + 1] = { step[1], item = found }
		else
			stepsMissing = true
		end
	end
	local race = select(2, UnitRace("player"))
	for index, yards in pairs(INTERACT_RACE[race] or INTERACT) do
		steps[#steps + 1] = { yards, interact = index }
	end
	table.sort(steps, function(a, b) return a[1] < b[1] end)
	-- Items that weren't loaded yet are tried again in a while
	if stepsMissing then C_Timer.After(5, BuildSteps) end
end

local function CheckStep(step, unit)
	if step.item then
		local check = C_Item and C_Item.IsItemInRange or IsItemInRange
		return Answer(check(step.item, unit))
	end
	return Answer(CheckInteractDistance(unit, step.interact))
end

local function LearnNames()
	wipe(byName)
	for key, id in pairs(SPELLS) do
		names[key] = ns.SpellName(id)
		if names[key] then byName[names[key]] = key end
		known[key] = ns.Knows({ id })
	end
	drainName = nil
	for _, id in ipairs(DRAINS) do
		if ns.Knows({ id }) then
			drainName = ns.SpellName(id)
			break
		end
	end
end

-- The spell that measures the range: the one you chose, or the last of them you cast, or the
-- first you know
function ns.RangeSpell()
	local pick = db.spell == "auto" and db.lastSpell or db.spell
	if pick and known[pick] then return pick end
	for _, key in ipairs(SPELL_ORDER) do
		if known[key] then return key end
	end
	return "shadowbolt"
end

-- How far a spell reaches (talents add to it)
local function MaxRange(name, fallback)
	local info = name and C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(name)
	local reach = type(info) == "table" and info.maxRange
	if type(reach) == "number" and not ns.IsSecret(reach) and reach > MELEE then return reach end
	return fallback
end

local function Reach()
	return MaxRange(names[ns.RangeSpell()], REACH)
end

local function DrainReach()
	return MaxRange(drainName, DRAIN)
end

local function StepAt(field, value)
	for _, step in ipairs(steps) do
		if step[field] == value then return step end
	end
end

local function Within(yards, unit)
	local step = StepAt(1, yards)
	return step and CheckStep(step, unit)
end

-- melee | drain | ranged | out, or nil when the game doesn't say
function ns.RangeState(unit)
	local five = Within(MELEE, unit)
	if five then return "melee" end
	-- Your drain says whether it reaches; without one learned, the 20 yard step
	local drain = InRange(drainName, unit)
	if drain == nil then drain = Within(DRAIN, unit) end
	if drain then return "drain" end
	local hit = InRange(names[ns.RangeSpell()], unit)
	if hit then return "ranged" end
	if hit == false then return "out" end
	-- The spell doesn't answer: the steps within its reach do
	local reach, unknown = Reach(), true
	for _, step in ipairs(steps) do
		if step[1] > reach then break end
		local v = CheckStep(step, unit)
		if v then return "ranged" end
		if v ~= nil then unknown = false end
	end
	if unknown and five == nil and drain == nil then return nil end
	return "out"
end

-- The distance to the unit in yards for its state: low, high (high is nil past the last step)
function ns.RangeDistance(unit, state)
	local reach, drain = Reach(), DrainReach()
	local low, high
	if state == "melee" then
		return 0, MELEE
	elseif state == "drain" then
		low, high = MELEE, drain
	elseif state == "ranged" then
		low, high = min(drain, reach), reach
	else
		low = reach
	end
	for _, step in ipairs(steps) do
		local yards = step[1]
		if yards > low and (not high or yards < high) then
			local v = CheckStep(step, unit)
			if v then
				high = yards
				break
			elseif v == false then
				low = yards
			end
		end
	end
	return low, high
end

-- Where the last five yards of your reach begin, at the nearest range step
local function FarEdge()
	local reach = Reach()
	local wanted, edge = reach - 5, nil
	for _, step in ipairs(steps) do
		local yards = step[1]
		if yards < reach and (not edge or math.abs(yards - wanted) < math.abs(edge - wanted)) then edge = yards end
	end
	return edge or wanted
end

-- /warlockgod rango: what each check says about your target
local function RangeReport()
	if not UnitExists("target") then
		ns.Print(L.RANGE_NO_TARGET)
		return
	end
	local function Say(v)
		if v == nil then return "?" end
		return v and L.RANGE_YES or L.RANGE_NO
	end
	local state = ns.RangeState("target")
	local low, high = ns.RangeDistance("target", state)
	local spell = names[ns.RangeSpell()]
	ns.Print(format(L.RANGE_REPORT, state and L.RANGE[state] or "?", low, high or 0, spell or "?", Reach(),
		Say(InRange(spell, "target"))))
	local parts = {}
	for _, step in ipairs(steps) do
		parts[#parts + 1] = format("%d:%s", step[1], Say(CheckStep(step, "target")))
	end
	ns.Print(L.RANGE_STEPS .. table.concat(parts, "  ") .. (stepsMissing and ("  " .. L.RANGE_LOADING) or ""))
end
ns.commands.range = RangeReport
ns.commands.rango = RangeReport

-- One number from the range steps. Each time the target crosses a step, its distance is
-- known exactly; between crossings it keeps moving at the rate of the last two, and holds
-- still while neither of you moves. (The same idea as GoodRange's estimate.)
local estimate = {}
local RATE_WINDOW = 10 -- s; an older crossing is too stale to give a rate

local function Moving()
	local mine, theirs = GetUnitSpeed("player"), GetUnitSpeed("target")
	if mine == nil or theirs == nil or ns.IsSecret(mine) or ns.IsSecret(theirs) then return true end
	return mine > 0 or theirs > 0
end

function ns.EstimateDistance(now, low, high)
	local e = estimate
	if not high then
		wipe(e) -- past the last step there is nothing to measure
		return nil
	end
	if e.low and (low ~= e.low or high ~= e.high) then
		-- Which step was crossed: the near edge of the new range going away, its far edge coming closer
		local edge
		if low >= e.high then
			edge = low
		elseif high <= e.low then
			edge = high
		end
		if edge then
			if e.edge and e.edge ~= edge and now - e.edgeT < RATE_WINDOW then
				e.rate = (edge - e.edge) / (now - e.edgeT)
			else
				e.rate = nil
			end
			e.edge, e.edgeT = edge, now
			e.value = edge
		else
			wipe(e) -- the steps themselves changed: start again
		end
	end
	if not e.value then
		e.value = (low + high) / 2
	elseif e.rate and e.valueT and Moving() then
		e.value = e.value + e.rate * (now - e.valueT)
	end
	e.low, e.high, e.valueT = low, high, now
	e.value = min(max(e.value, low), high)
	return e.value
end

local function TargetPlate()
	if db.anchor ~= "plate" or ns.unlocked or not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return end
	return C_NamePlate.GetNamePlateForUnit("target")
end

-- Beside the plate's health bar, not its wider click area
local function PlateBar(p)
	local unitFrame = p.UnitFrame
	local bar = unitFrame and (unitFrame.healthBar
		or unitFrame.HealthBarsContainer and unitFrame.HealthBarsContainer.healthBar)
	return bar or p
end
ns.PlateBar = PlateBar -- the target's effects and the interrupt warning sit by it too

-- On the target's nameplate: above or under it, or beside its health bar
local PLATE_SIDES = {
	top = { "BOTTOM", "TOP", 0, 1 },
	bottom = { "TOP", "BOTTOM", 0, -1 },
	left = { "RIGHT", "LEFT", -1, 0 },
	right = { "LEFT", "RIGHT", 1, 0 },
}

local function Anchor(newPlate)
	plate = newPlate
	frame.placed = newPlate and (db.plateSide .. db.plateGap) -- placed again when these change
	frame:ClearAllPoints()
	if plate then
		local side = PLATE_SIDES[db.plateSide] or PLATE_SIDES.top
		local to = side[3] ~= 0 and PlateBar(plate) or plate
		frame:SetPoint(side[1], to, side[2], side[3] * db.plateGap, side[4] * db.plateGap)
	else
		frame:SetPoint("CENTER", rangeSpot)
	end
end

-- The number on the display: the estimate, or the range between two checks
function ns.RangeNumber(low, high, value)
	local scale = db.units == "meters" and YARD or 1
	if db.display == "number" and value then
		return tostring(floor(value * scale + 0.5))
	elseif high then
		return format("%d-%d", floor(low * scale + 0.5), floor(high * scale + 0.5))
	end
	return format("%d+", floor(low * scale + 0.5))
end

local function Show(state, low, high, value)
	local c = db.colors[state]
	frame.text:SetText(ns.RangeNumber(low, high, value))
	frame.unit:SetText(db.units == "meters" and L.METERS or L.YARDS)
	frame.state:SetText(db.showState and L.RANGE[state] or "")
	for _, part in ipairs({ frame.text, frame.unit, frame.state }) do
		part:SetTextColor(c.r, c.g, c.b)
	end
	frame.icon:SetColorTexture(c.r, c.g, c.b)
	local text, icon = db.style ~= "icon", db.style ~= "text"
	local width = (icon and db.textSize * 0.7 or 0) + (icon and text and 6 or 0)
		+ (text and frame.text:GetStringWidth() + 3 + frame.unit:GetStringWidth() or 0)
	frame:SetSize(max(width, 16), db.textSize + 4)
	-- At the edge of your reach a soft light breathes behind it
	local far = state == "far"
	frame.glow:SetShown(far and frame.glowReady)
	if far then
		frame.glow:SetVertexColor(c.r, c.g, c.b)
		frame.glow:SetSize(max(width, 16) + db.textSize * 2, db.textSize * 2.4)
		if not frame.pulse:IsPlaying() then frame.pulse:Play() end
	else
		frame.pulse:Stop()
	end
	frame:Show()
end

function ns.StyleRange()
	local text, icon = db.style ~= "icon", db.style ~= "text"
	local gameFont = GameFontNormal:GetFont()
	local unitSize, stateSize = max(floor(db.textSize * 0.5), 8), max(floor(db.textSize * 0.45), 8)
	-- A thick black outline keeps the number readable on any ground
	local font = ns.FONTS[db.font] or gameFont
	ns.UseFont(frame.text, font, db.textSize, "THICKOUTLINE")
	ns.UseFont(frame.unit, font, unitSize, "OUTLINE")
	ns.UseFont(frame.state, font, stateSize, "OUTLINE")
	frame.icon:SetSize(db.textSize * 0.7, db.textSize * 0.7)
	frame.text:SetShown(text)
	frame.unit:SetShown(text)
	frame.state:SetShown(text)
	frame.icon:SetShown(icon)
	frame.iconBorder:SetShown(icon)
	frame.icon:ClearAllPoints()
	frame.text:ClearAllPoints()
	if icon then
		frame.icon:SetPoint("LEFT", 1, 0)
		frame.text:SetPoint("LEFT", frame.icon, "RIGHT", 6, 0)
	else
		frame.text:SetPoint("LEFT", 0, 0)
	end
	frame.unit:ClearAllPoints()
	frame.unit:SetPoint("BOTTOMLEFT", frame.text, "BOTTOMRIGHT", 3, db.textSize * 0.08)
	frame.state:ClearAllPoints()
	frame.state:SetPoint("TOP", frame, "BOTTOM", 0, -1)
	if ns.StyleThreat then ns.StyleThreat() end
end

function ns.UpdateRange()
	if not db.enabled or not ns.IsWarlock() then
		frame:Hide()
		return
	end
	local newPlate = TargetPlate()
	if newPlate ~= plate or (plate and frame.placed ~= db.plateSide .. db.plateGap) then Anchor(newPlate) end
	if ns.unlocked then
		Show("ranged", 20, 25, 22) -- a sample to drag around
		return
	end
	local hostile, dead = UnitCanAttack("player", "target"), UnitIsDead("target")
	if ns.IsSecret(hostile) then hostile = true end
	if ns.IsSecret(dead) then dead = false end
	if not UnitExists("target") or not hostile or dead or (db.onlyCombat and not UnitAffectingCombat("player")) then
		frame:Hide()
		return
	end
	local state = ns.RangeState("target")
	if not state then
		frame:Hide()
		return
	end
	local low, high = ns.RangeDistance("target", state)
	local shown = state
	-- The last five yards of your reach, where you want to stand
	if state == "ranged" and db.farGlow and low >= FarEdge() then shown = "far" end
	Show(shown, low, high, ns.EstimateDistance(GetTime(), low, high))
end

local function UnitsCommand(word)
	db.units = (word == "yards" or word == "yardas") and "yards" or "meters"
	ns.UpdateRange()
	ns.Print(format(L.UNITS_SET, strlower(L.UNITS[db.units])))
end
for _, word in ipairs({ "meters", "metres", "metros", "yards", "yardas" }) do
	ns.commands[word] = UnitsCommand
end

frame = CreateFrame("Frame", "WarlockGodRange", UIParent)
frame:SetSize(80, 18)
frame:Hide()
frame.iconBorder = frame:CreateTexture(nil, "BORDER")
frame.icon = frame:CreateTexture(nil, "ARTWORK")
frame.iconBorder:SetPoint("TOPLEFT", frame.icon, -1, 1)
frame.iconBorder:SetPoint("BOTTOMRIGHT", frame.icon, 1, -1)
frame.iconBorder:SetColorTexture(0, 0, 0, 0.9)
frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
frame.unit = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
frame.state = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
-- A soft oval of our own. A new file needs the game restarted: until then the game can't
-- find it, and there's no glow rather than a box
ns.GLOW = "Interface\\AddOns\\WarlockGod\\media\\glow.tga"
frame.glow = frame:CreateTexture(nil, "BACKGROUND")
frame.glowReady = frame.glow:SetTexture(ns.GLOW) ~= false
frame.glow:SetBlendMode("ADD")
frame.glow:SetPoint("CENTER")
frame.glow:Hide()
frame.pulse = frame.glow:CreateAnimationGroup()
frame.pulse:SetLooping("BOUNCE")
local glowFade = frame.pulse:CreateAnimation("Alpha")
glowFade:SetFromAlpha(0.35)
glowFade:SetToAlpha(0.85)
glowFade:SetDuration(0.9)

-- Your threat on the target, under its nameplate, before you pull it off the tank or your demon
local threat = CreateFrame("Frame", "WarlockGodThreat", UIParent)
threat:SetSize(120, 20)
threat:Hide()
threat.text = threat:CreateFontString(nil, "OVERLAY", "GameFontNormal")
threat.text:SetPoint("CENTER")
threat.blink = threat:CreateAnimationGroup()
threat.blink:SetLooping("BOUNCE")
local threatFade = threat.blink:CreateAnimation("Alpha")
threatFade:SetFromAlpha(1)
threatFade:SetToAlpha(0.3)
threatFade:SetDuration(0.35)

function ns.StyleThreat()
	ns.UseFont(threat.text, ns.FONTS[db.font], 16, "THICKOUTLINE")
end

-- Do you have the target's aggro, and your threat as the game's tooltip shows it: next to the
-- threat of whoever has the aggro, rounded
local function ThreatOnTarget()
	local ok, tanking, _, _, raw = pcall(UnitDetailedThreatSituation, "player", "target")
	if not ok or ns.IsSecret(tanking) or ns.IsSecret(raw) then return end
	return tanking, type(raw) == "number" and floor(raw + 0.5) or nil
end

function ns.UpdateThreat()
	local text, pulled
	if db.threat and ns.IsWarlock() then
		if ns.unlocked then
			text = format(L.THREAT, 95)
		elseif UnitExists("target") and (IsInGroup() or ns.HasDemon()) then
			-- Solo without a demon you always have the aggro: nothing to warn about then
			local tanking, percent = ThreatOnTarget()
			if tanking then
				text, pulled = L.THREAT_PULLED, true
			elseif percent and percent >= db.threatPct then
				text = format(L.THREAT, percent)
			end
		end
	end
	if not text then
		threat.blink:Stop()
		threat:Hide()
		threat.anchor = nil -- placed again when it shows
		return
	end
	-- Placed only when where it hangs changes: placing it on every update undid a drag
	local targetPlate = not ns.unlocked and C_NamePlate and C_NamePlate.GetNamePlateForUnit
		and C_NamePlate.GetNamePlateForUnit("target")
	-- With the range under the nameplate, the warning goes under the range (and its state)
	local under = targetPlate and db.enabled and db.anchor == "plate" and db.plateSide == "bottom"
		and -(2 + (db.showState and max(floor(db.textSize * 0.45), 8) + 1 or 0))
	local anchor = under and ("under" .. under) or targetPlate or "free"
	if threat.anchor ~= anchor then
		threat.anchor = anchor
		threat:ClearAllPoints()
		if under then
			threat:SetPoint("TOP", frame, "BOTTOM", 0, under)
		elseif targetPlate then
			threat:SetPoint("TOP", targetPlate, "BOTTOM", 0, -2)
		else
			threat:SetPoint("CENTER", threatSpot)
		end
	end
	threat.text:SetText(text)
	if pulled then
		threat.text:SetTextColor(1, 0.15, 0.15)
		if not threat.blink:IsPlaying() then threat.blink:Play() end
	else
		threat.text:SetTextColor(1, 0.55, 0.1)
		threat.blink:Stop()
	end
	threat:SetWidth(threat.text:GetStringWidth() + 8)
	threat:Show()
end

-- A small driver that keeps running while the display is hidden
local driver = CreateFrame("Frame")
driver:RegisterEvent("PLAYER_LOGIN")
driver:SetScript("OnEvent", function(self, event, unit, _, spellID)
	if event == "SPELLS_CHANGED" then
		LearnNames()
		return
	elseif event == "PLAYER_TARGET_CHANGED" then
		wipe(estimate) -- a new target starts a new estimate
		return
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		-- The range follows the last of your main spells you cast
		if unit ~= "player" or not spellID or ns.IsSecret(spellID) then return end
		local key = byName[ns.SpellName(spellID) or ""]
		if key then db.lastSpell = key end
		return
	end
	db = ns.db.range
	LearnNames()
	BuildSteps()
	self:RegisterEvent("SPELLS_CHANGED")
	self:RegisterEvent("PLAYER_TARGET_CHANGED")
	self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
	ns.Movable(rangeSpot, "range", { "CENTER", "CENTER", 0, -140 }, L.TAB_RANGE)
	ns.Movable(threatSpot, "threat", { "CENTER", "CENTER", 0, -200 }, L.THREAT_NAME) -- clear of the range's box
	Anchor(nil)
	ns.StyleRange()
	table.insert(ns.refreshers, function()
		Anchor(TargetPlate())
		ns.StyleRange()
		ns.UpdateRange()
		ns.UpdateThreat()
	end)
	local threatElapsed = 0
	driver:SetScript("OnUpdate", function(_, dt)
		elapsed = elapsed + dt
		threatElapsed = threatElapsed + dt
		if threatElapsed >= 0.2 then
			threatElapsed = 0
			ns.UpdateThreat()
		end
		if elapsed < 0.05 then return end
		elapsed = 0
		ns.UpdateRange()
	end)
end)
