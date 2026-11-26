local _, ns = ...
local L = ns.L

-- The icon reminders above your character (demon, armor, stones) share one look and one place:
-- side by side, always centred on one point whatever how many show, and dragged together. A click
-- casts a spell, uses an item or runs a macro. The game doesn't let addons show, hide or move a
-- button that casts during a fight, so the icons are plain frames that come and go any time, and
-- the click is a secure button laid on top of them out of combat only (as HunterGod's row)
local SIZE, GAP = 40, 10
local DEFAULT_POINT = { "CENTER", "CENTER", 0, 260 } -- above your character, clear of it

local members = {} -- left to right: { key, order, frame, action, tooltip, x, click }
local fighting = false -- from the start of a fight: other modules' updates mustn't bring a button back
local group = CreateFrame("Frame", "WarlockGodReminders", UIParent)
group:SetSize(SIZE, SIZE)
ns.REMINDER_SIZE = SIZE

local styled = {}

-- A black line one pixel wide around the outside: four strips, the top and bottom ones a pixel
-- longer each way to close the corners. One UI unit is less than a pixel at most UI scales, and
-- the game drew it on some sides and not others
local function Edges(frame)
	local px = ns.OnePixel(frame)
	local top, bottom, left, right = unpack(frame.lines)
	top:ClearAllPoints()
	top:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", -px, 0)
	top:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", px, 0)
	top:SetHeight(px)
	bottom:ClearAllPoints()
	bottom:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", -px, 0)
	bottom:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", px, 0)
	bottom:SetHeight(px)
	left:ClearAllPoints()
	left:SetPoint("TOPRIGHT", frame, "TOPLEFT", 0, 0)
	left:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 0, 0)
	left:SetWidth(px)
	right:ClearAllPoints()
	right:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, 0)
	right:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 0, 0)
	right:SetWidth(px)
end

-- The same size and the same thin black edge for every icon, and the time left under it
function ns.StyleReminder(frame)
	frame:SetSize(SIZE, SIZE)
	frame.lines = {}
	for i = 1, 4 do
		frame.lines[i] = frame:CreateTexture(nil, "BORDER")
		frame.lines[i]:SetColorTexture(0, 0, 0, 1)
	end
	frame.icon = frame:CreateTexture(nil, "ARTWORK")
	frame.icon:SetAllPoints()
	frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	frame.text:SetPoint("TOP", frame, "BOTTOM", 0, -3)
	frame.text:SetTextColor(0.85, 0.82, 1)
	Edges(frame)
	styled[#styled + 1] = frame
end

-- What the icon shows: its picture, grey while it's missing, and a time or a word under it
function ns.ShowReminder(frame, icon, grey, text)
	frame.icon:SetTexture(icon)
	frame.icon:SetDesaturated(grey and true or false)
	frame.text:SetText(text or "")
	frame:Show()
end

local function Overlay_OnEnter(self)
	local m = self.member
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	if m.tooltip then m.tooltip(GameTooltip) end
	GameTooltip:AddLine(self.hint or L.CLICK_CAST, 0.6, 0.6, 1)
	GameTooltip:Show()
end

-- What a click does: { spell = name } on you (or on unit), { item = "item:123" }, { macro = text }
local ATTRIBUTES = { "spell", "item", "macrotext", "unit" }
local function SetAction(click, action)
	local kind = action.macro and "macro" or action.item and "item" or "spell"
	local wanted = {
		spell = kind == "spell" and action.spell or nil,
		item = kind == "item" and action.item or nil,
		macrotext = action.macro,
		-- A buff of yours goes on you, not on your target; a group buff on whoever lacks it
		unit = action.unit or (kind == "spell" and "player" or nil),
	}
	if click:GetAttribute("type1") ~= kind then click:SetAttribute("type1", kind) end
	for _, key in ipairs(ATTRIBUTES) do
		if click:GetAttribute(key) ~= wanted[key] then click:SetAttribute(key, wanted[key]) end
	end
	click.hint = action.hint
end

-- The secure buttons follow the icons, out of combat
local function Sync()
	if fighting or InCombatLockdown() then return end
	for _, m in ipairs(members) do
		local click = m.click
		local action = m.frame:IsShown() and not ns.unlocked and ns.db.buffs.click and m.action()
		if action then
			local x = m.x or 0
			if click.x ~= x then
				click:ClearAllPoints()
				click:SetPoint("CENTER", group, "CENTER", x, 0)
				click.x = x
			end
			SetAction(click, action)
			click:Show()
		else
			click:Hide()
		end
	end
end
ns.SyncReminders = Sync

-- Side by side, centred on the group's point
function ns.LayoutReminders()
	local shown = {}
	for _, m in ipairs(members) do
		if m.frame:IsShown() then shown[#shown + 1] = m end
	end
	local total = #shown * SIZE + max(#shown - 1, 0) * GAP
	local x = (SIZE - total) / 2
	for _, m in ipairs(shown) do
		if m.x ~= x then
			m.frame:ClearAllPoints()
			m.frame:SetPoint("CENTER", group, "CENTER", x, 0)
			m.x = x
		end
		x = x + SIZE + GAP
	end
	group:SetSize(max(total, SIZE), SIZE)
	Sync()
end

-- A reminder joins the row at its place (order, small first). action: what a click does while
-- it shows (nil for nothing); tooltip: lines above the click's
function ns.AddReminder(key, order, frame, action, tooltip)
	local m = { key = key, order = order, frame = frame, action = action or function() end, tooltip = tooltip }
	local click = CreateFrame("Button", "WarlockGodReminderClick" .. key, UIParent, "SecureActionButtonTemplate")
	click:SetSize(SIZE, SIZE)
	click:SetFrameStrata(frame:GetFrameStrata() or "MEDIUM")
	click:SetFrameLevel((frame:GetFrameLevel() or 1) + 5)
	click:RegisterForClicks("AnyUp", "AnyDown")
	click:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	click:SetScript("OnEnter", Overlay_OnEnter)
	click:SetScript("OnLeave", GameTooltip_Hide)
	click:Hide()
	click.member = m
	m.click = click
	members[#members + 1] = m
	table.sort(members, function(a, b) return a.order < b.order end)
	frame:SetParent(group)
	frame:Hide()
	frame:HookScript("OnShow", ns.LayoutReminders)
	frame:HookScript("OnHide", ns.LayoutReminders)
	return m
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
-- The screen's pixel changes with the UI scale and the window's size
pcall(events.RegisterEvent, events, "UI_SCALE_CHANGED")
pcall(events.RegisterEvent, events, "DISPLAY_SIZE_CHANGED")
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" or event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
		if event == "PLAYER_LOGIN" then ns.Movable(group, "reminders", DEFAULT_POINT, L.REMINDERS_NAME) end
		for _, frame in ipairs(styled) do Edges(frame) end
	elseif event == "PLAYER_REGEN_DISABLED" then
		-- The last moment the game lets them go: no hidden button left to click in the fight
		fighting = true
		for _, m in ipairs(members) do m.click:Hide() end
		return
	elseif event == "PLAYER_REGEN_ENABLED" then
		fighting = false
	end
	ns.LayoutReminders()
end)

-- For the tests
ns.RemindersState = function() return group, members end
