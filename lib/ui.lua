-- ---------------------------------------------------------------------------
-- ui.lua  -  Loot Filter UI (sidebar navigation, programmatic layout)
-- ---------------------------------------------------------------------------

-- WoW 3.3.5a quality colours
local QUALITY_COLORS = {
	[0]  = { r = 0.62, g = 0.62, b = 0.62 }, -- Poor (Grey)
	[1]  = { r = 1.00, g = 1.00, b = 1.00 }, -- Common (White)
	[2]  = { r = 0.12, g = 1.00, b = 0.00 }, -- Uncommon (Green)
	[3]  = { r = 0.00, g = 0.44, b = 0.87 }, -- Rare (Blue)
	[4]  = { r = 0.64, g = 0.21, b = 0.93 }, -- Epic (Purple)
	[5]  = { r = 1.00, g = 0.50, b = 0.00 }, -- Legendary (Orange)
	[6]  = { r = 0.90, g = 0.80, b = 0.50 }, -- Artifact (Red)
	[7]  = { r = 0.00, g = 0.80, b = 1.00 }, -- Heirloom (Cyan)
	[-1] = { r = 1.00, g = 1.00, b = 0.00 }, -- Quest (Yellow)
}

local QUALITY_ORDER = {
	{ key = "QUaGrey",   val = 0,  name = "Poor",      short = "Grey" },
	{ key = "QUbWhite",  val = 1,  name = "Common",    short = "White" },
	{ key = "QUcGreen",  val = 2,  name = "Uncommon",  short = "Green" },
	{ key = "QUdBlue",   val = 3,  name = "Rare",      short = "Blue" },
	{ key = "QUePurple", val = 4,  name = "Epic",      short = "Purple" },
	{ key = "QUfOrange", val = 5,  name = "Legendary", short = "Orange" },
	{ key = "QUgRed",    val = 6,  name = "Artifact",  short = "Red" },
	{ key = "QUhTan",    val = 7,  name = "Heirloom",  short = "Tan" },
	{ key = "QUhQuest",  val = -1, name = "Quest",     short = "Quest" },
}

local PAGES = { "Filters", "Names", "Values", "Cleanup", "Settings" }

local sidebarButtons = {}
local pageFrames = {}

-- -------------------------------------------------------------------------
-- Helpers
-- -------------------------------------------------------------------------

local function createPanel(parent, name, w, h)
	local f = CreateFrame("Frame", name, parent)
	f:SetWidth(w)
	f:SetHeight(h)
	f:SetBackdrop({
		bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	f:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
	f:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.9)
	return f
end

local function createSectionHeader(parent, text, xOff, yOff)
	local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	fs:SetPoint("TOPLEFT", parent, "TOPLEFT", xOff or 0, yOff or 0)
	fs:SetText(text)
	fs:SetTextColor(1, 0.82, 0)
	local line = parent:CreateTexture(nil, "ARTWORK")
	line:SetHeight(1)
	line:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -2)
	line:SetPoint("RIGHT", parent, "RIGHT", -10, 0)
	line:SetTexture(1, 1, 1, 0.15)
	return fs, line
end

local function createCheckOption(parent, frameName, x, y)
	local f = CreateFrame("Frame", frameName, parent, "LootFilterOptionTemplate2")
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	f:Show()
	return f
end

local function safeHide()
	LootFilterOptions:Hide()
	LootFilter.hasFocus = 0
end

-- -------------------------------------------------------------------------
-- Tri-state logic (Neutral / Keep / Delete)
-- -------------------------------------------------------------------------

local function getTriState(key)
	if LootFilter.REALMPLAYER == "" or LootFilterVars[LootFilter.REALMPLAYER] == nil then
		return "neutral"
	end
	if LootFilterVars[LootFilter.REALMPLAYER].keepList[key] ~= nil then
		return "keep"
	elseif LootFilterVars[LootFilter.REALMPLAYER].deleteList[key] ~= nil then
		return "delete"
	end
	return "neutral"
end

local function setTriState(key, state, isQuality)
	if LootFilter.REALMPLAYER == "" or LootFilterVars[LootFilter.REALMPLAYER] == nil then return end
	LootFilterVars[LootFilter.REALMPLAYER].keepList[key] = nil
	LootFilterVars[LootFilter.REALMPLAYER].deleteList[key] = nil
	if state == "keep" then
		if isQuality then
			LootFilterVars[LootFilter.REALMPLAYER].keepList[key] = LootFilter.Locale.qualities[key]
		else
			LootFilterVars[LootFilter.REALMPLAYER].keepList[key] = LootFilter.Locale.radioButtonsText[key]
		end
	elseif state == "delete" then
		if isQuality then
			LootFilterVars[LootFilter.REALMPLAYER].deleteList[key] = LootFilter.Locale.qualities[key]
		else
			LootFilterVars[LootFilter.REALMPLAYER].deleteList[key] = LootFilter.Locale.radioButtonsText[key]
		end
	end
end

local function cycleTriState(key, isQuality)
	local cur = getTriState(key)
	local nxt
	if cur == "neutral" then nxt = "keep"
	elseif cur == "keep" then nxt = "delete"
	else nxt = "neutral" end
	setTriState(key, nxt, isQuality)
	return nxt
end

-- -------------------------------------------------------------------------
-- Quality chips
-- -------------------------------------------------------------------------

local qualityChips = {}

local function updateChipVisual(chip)
	local state = getTriState(chip.qualKey)
	local c = QUALITY_COLORS[chip.qualVal] or QUALITY_COLORS[0]

	if state == "keep" then
		chip.stateText:SetText("KEEP")
		chip.stateText:SetTextColor(0.2, 1.0, 0.2)
		chip:SetBackdropBorderColor(0.2, 0.9, 0.2, 1)
	elseif state == "delete" then
		chip.stateText:SetText("DELETE")
		chip.stateText:SetTextColor(1.0, 0.2, 0.2)
		chip:SetBackdropBorderColor(0.9, 0.2, 0.2, 1)
	else
		chip.stateText:SetText("--")
		chip.stateText:SetTextColor(0.5, 0.5, 0.5)
		chip:SetBackdropBorderColor(c.r * 0.5, c.g * 0.5, c.b * 0.5, 0.6)
	end
end

local function createQualityChip(parent, qi, x, y)
	local chip = CreateFrame("Frame", "LootFilterQChip" .. qi.key, parent)
	chip:SetWidth(60)
	chip:SetHeight(42)
	chip:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	chip:EnableMouse(true)

	chip:SetBackdrop({
		bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 12,
		insets = { left = 2, right = 2, top = 2, bottom = 2 },
	})

	local c = QUALITY_COLORS[qi.val] or QUALITY_COLORS[0]
	chip:SetBackdropColor(c.r * 0.25, c.g * 0.25, c.b * 0.25, 0.9)

	local nameText = chip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	nameText:SetPoint("TOP", chip, "TOP", 0, -5)
	nameText:SetText(qi.short)
	nameText:SetTextColor(c.r, c.g, c.b)

	local stateText = chip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	stateText:SetPoint("BOTTOM", chip, "BOTTOM", 0, 5)
	stateText:SetText("--")
	stateText:SetTextColor(0.5, 0.5, 0.5)
	chip.stateText = stateText

	chip.qualKey = qi.key
	chip.qualVal = qi.val

	chip:SetScript("OnMouseUp", function()
		cycleTriState(qi.key, true)
		updateChipVisual(chip)
	end)
	chip:SetScript("OnEnter", function()
		LootFilter.showTooltip(chip, "LToolTip13")
	end)
	chip:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- Do NOT call updateChipVisual here - SavedVars may not be loaded yet.
	-- It will be called from initQualityTab() after ADDON_LOADED.

	qualityChips[qi.key] = chip
	return chip
end

-- -------------------------------------------------------------------------
-- Item type tree
-- -------------------------------------------------------------------------

local typeRows = {}
local typeScrollChild
local expandedTypes = {}

local function updateTypeRowVisual(row)
	local state = getTriState(row.typeKey)
	if state == "keep" then
		row.stateLabel:SetText("|cff33ff33KEEP|r")
	elseif state == "delete" then
		row.stateLabel:SetText("|cffff3333DEL|r")
	else
		row.stateLabel:SetText("|cff888888--|r")
	end
end

local function layoutTypeRows()
	local y = 0
	for _, row in ipairs(typeRows) do
		if row.isSubtype then
			if expandedTypes[row.parentType] then
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", typeScrollChild, "TOPLEFT", 24, -y)
				row:Show()
				y = y + 18
			else
				row:Hide()
			end
		else
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", typeScrollChild, "TOPLEFT", 0, -y)
			row:Show()
			y = y + 20
		end
	end
	typeScrollChild:SetHeight(math.max(y, 1))
end

local function createTypeHeaderRow(parent, typeName, displayName)
	local row = CreateFrame("Frame", nil, parent)
	row:SetWidth(520)
	row:SetHeight(20)
	row:EnableMouse(true)
	row.isSubtype = false
	row.typeName = typeName

	local arrow = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	arrow:SetPoint("LEFT", row, "LEFT", 2, 0)
	arrow:SetText(">")
	arrow:SetTextColor(0.8, 0.8, 0.8)
	row.arrow = arrow

	local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetPoint("LEFT", row, "LEFT", 16, 0)
	label:SetText(displayName)
	label:SetTextColor(1, 0.82, 0)

	local hl = row:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetTexture(1, 1, 1, 0.04)

	row:SetScript("OnMouseUp", function()
		expandedTypes[typeName] = not expandedTypes[typeName]
		arrow:SetText(expandedTypes[typeName] and "v" or ">")
		layoutTypeRows()
	end)

	return row
end

local function createTypeSubRow(parent, key, displayName, parentTypeName)
	local row = CreateFrame("Frame", nil, parent)
	row:SetWidth(520)
	row:SetHeight(18)
	row:EnableMouse(true)
	row.isSubtype = true
	row.parentType = parentTypeName
	row.typeKey = key

	-- Hidden DKD frame so backend matching code can find it by name
	local hidden = CreateFrame("Frame", "LootFilter" .. key, parent, "LootFilterDKDOptionsTemplate")
	hidden:Hide()

	local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	label:SetPoint("LEFT", row, "LEFT", 4, 0)
	label:SetText(displayName)

	local stateLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	stateLabel:SetPoint("RIGHT", row, "RIGHT", -20, 0)
	stateLabel:SetText("|cff888888--|r")
	row.stateLabel = stateLabel

	local hl = row:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetTexture(1, 1, 1, 0.03)

	row:SetScript("OnMouseUp", function()
		cycleTriState(key, false)
		updateTypeRowVisual(row)
	end)
	row:SetScript("OnEnter", function()
		LootFilter.showTooltip(row, "LToolTip13")
	end)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- Do NOT call updateTypeRowVisual here - deferred to initTypeTab()

	return row
end

-- -------------------------------------------------------------------------
-- Sidebar
-- -------------------------------------------------------------------------

local function createSidebar(parent)
	local sidebar = createPanel(parent, "LootFilterSidebar", 120, 420)
	sidebar:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -38)
	sidebar:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
	sidebar:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

	-- Icon
	local icon = sidebar:CreateTexture(nil, "ARTWORK")
	icon:SetTexture("Interface\\AddOns\\LootFilter\\Images\\LFbutton")
	icon:SetWidth(24)
	icon:SetHeight(24)
	icon:SetPoint("TOP", sidebar, "TOP", 0, -8)

	-- Nav buttons
	local startY = -40
	for i, pageName in ipairs(PAGES) do
		local btn = CreateFrame("Button", "LootFilterNav" .. pageName, sidebar, "GameMenuButtonTemplate")
		btn:SetWidth(104)
		btn:SetHeight(22)
		btn:SetPoint("TOP", sidebar, "TOP", 0, startY - (i - 1) * 26)
		btn:SetText(pageName)

		-- Active indicator bar
		local indicator = btn:CreateTexture(nil, "OVERLAY")
		indicator:SetWidth(3)
		indicator:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
		indicator:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
		indicator:SetTexture(1, 0.82, 0, 1)
		indicator:Hide()
		btn.indicator = indicator

		btn:SetScript("OnClick", function()
			LootFilter.navigateTo(pageName)
		end)

		sidebarButtons[pageName] = btn
	end

	-- Close button at bottom
	local closeBtn = CreateFrame("Button", "LootFilterCloseBottom", sidebar, "GameMenuButtonTemplate")
	closeBtn:SetWidth(104)
	closeBtn:SetHeight(22)
	closeBtn:SetPoint("BOTTOM", sidebar, "BOTTOM", 0, 8)
	closeBtn:SetText(LFINT_BTN_CLOSE or "Close")
	closeBtn:SetScript("OnClick", function()
		if LootFilter.REALMPLAYER ~= "" and LootFilterVars[LootFilter.REALMPLAYER] then
			LootFilter.setNames()
			LootFilter.setNamesDelete()
			LootFilter.setItemValue()
		end
		safeHide()
	end)

	return sidebar
end

-- -------------------------------------------------------------------------
-- Page: Filters
-- -------------------------------------------------------------------------

local function createFiltersPage(parent)
	local page = CreateFrame("Frame", "LootFilterPageFilters", parent)
	page:SetAllPoints()

	local qHeader = createSectionHeader(page, "Item Quality", 10, -10)

	local helpText = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	helpText:SetPoint("TOPLEFT", qHeader, "BOTTOMLEFT", 0, -4)
	helpText:SetText("Click to cycle: -- (neutral) > KEEP > DELETE")
	helpText:SetTextColor(0.6, 0.6, 0.6)

	local chipStartY = -42
	for i, qi in ipairs(QUALITY_ORDER) do
		local col = (i - 1) % 5
		local row = math.floor((i - 1) / 5)
		createQualityChip(page, qi, 10 + col * 66, chipStartY - row * 48)
	end

	local tHeader = createSectionHeader(page, "Item Types", 10, -148)

	local helpText2 = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	helpText2:SetPoint("TOPLEFT", tHeader, "BOTTOMLEFT", 0, -4)
	helpText2:SetText("Click type to expand. Click subtype to cycle state.")
	helpText2:SetTextColor(0.6, 0.6, 0.6)

	local typePanel = createPanel(page, "LootFilterTypePanel", 555, 230)
	typePanel:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -184)

	local typeScroll = CreateFrame("ScrollFrame", "LootFilterTypeScroll", typePanel, "UIPanelScrollFrameTemplate")
	typeScroll:SetPoint("TOPLEFT", typePanel, "TOPLEFT", 6, -6)
	typeScroll:SetPoint("BOTTOMRIGHT", typePanel, "BOTTOMRIGHT", -26, 6)

	typeScrollChild = CreateFrame("Frame", "LootFilterTypeScrollChild", typeScroll)
	typeScrollChild:SetWidth(520)
	typeScrollChild:SetHeight(1)
	typeScroll:SetScrollChild(typeScrollChild)

	-- Hidden type dropdown (referenced by dropdown init code)
	local hiddenDropdown = CreateFrame("Button", "LootFilterSelectDropDownType", page, "UIDropDownMenuTemplate")
	hiddenDropdown:Hide()

	return page
end

-- -------------------------------------------------------------------------
-- Page: Names
-- -------------------------------------------------------------------------

local function createNamesPage(parent)
	local page = CreateFrame("Frame", "LootFilterPageNames", parent)
	page:SetAllPoints()
	page:Hide()

	local header = createSectionHeader(page, "Name Filters", 10, -10)

	local helpText = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	helpText:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
	helpText:SetText("Enter one name per line. Shift-click items in bags to add them.")
	helpText:SetTextColor(0.6, 0.6, 0.6)

	-- Keep column
	local keepHeader = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	keepHeader:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -40)
	keepHeader:SetText("|cff33ff33Items to KEEP|r")

	local keepPanel = createPanel(page, "LootFilterNameKeepPanel", 265, 340)
	keepPanel:SetPoint("TOPLEFT", page, "TOPLEFT", 10, -56)
	keepPanel:SetBackdropBorderColor(0.2, 0.7, 0.2, 0.8)

	local keepScroll = CreateFrame("ScrollFrame", "LootFilterScrollFrame1", keepPanel, "UIPanelScrollFrameTemplate")
	keepScroll:SetPoint("TOPLEFT", keepPanel, "TOPLEFT", 8, -6)
	keepScroll:SetPoint("BOTTOMRIGHT", keepPanel, "BOTTOMRIGHT", -26, 6)

	local keepChild = CreateFrame("Frame", "LootFilterScrollChildFrame1", keepScroll)
	keepChild:SetWidth(230)
	keepChild:SetHeight(340)
	keepScroll:SetScrollChild(keepChild)

	local keepEdit = CreateFrame("EditBox", "LootFilterEditBox1", keepChild)
	keepEdit:SetWidth(230)
	keepEdit:SetHeight(340)
	keepEdit:SetPoint("TOPLEFT")
	keepEdit:SetMultiLine(true)
	keepEdit:SetAutoFocus(false)
	keepEdit:SetMaxLetters(7500)
	keepEdit:SetFontObject(ChatFontNormal)
	keepEdit:SetScript("OnShow", function() LootFilter.getNames() end)
	keepEdit:SetScript("OnTextChanged", function()
		local scrollBar = getglobal("LootFilterScrollFrame1ScrollBar")
		keepScroll:UpdateScrollChildRect()
		local mn, mx = scrollBar:GetMinMaxValues()
		if mx > 0 and (keepEdit.max ~= mx) then
			keepEdit.max = mx
			scrollBar:SetValue(mx)
		end
	end)
	keepEdit:SetScript("OnEscapePressed", function() LootFilter.updateFocus(1, false) end)
	keepEdit:SetScript("OnEditFocusGained", function() LootFilter.updateFocus(1, true) end)
	keepEdit:SetScript("OnEditFocusLost", function() LootFilter.setNames() end)
	keepEdit:SetScript("OnEnter", function() LootFilter.showTooltip(keepEdit, "LToolTip5") end)
	keepEdit:SetScript("OnLeave", function() GameTooltip:Hide() end)
	keepChild:SetScript("OnMouseUp", function() keepEdit:SetFocus() end)
	keepChild:EnableMouse(true)

	-- Delete column
	local delHeader = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	delHeader:SetPoint("TOPLEFT", page, "TOPLEFT", 292, -40)
	delHeader:SetText("|cffff3333Items to DELETE|r")

	local delPanel = createPanel(page, "LootFilterNameDelPanel", 265, 340)
	delPanel:SetPoint("TOPLEFT", page, "TOPLEFT", 286, -56)
	delPanel:SetBackdropBorderColor(0.7, 0.2, 0.2, 0.8)

	local delScroll = CreateFrame("ScrollFrame", "LootFilterScrollFrame2", delPanel, "UIPanelScrollFrameTemplate")
	delScroll:SetPoint("TOPLEFT", delPanel, "TOPLEFT", 8, -6)
	delScroll:SetPoint("BOTTOMRIGHT", delPanel, "BOTTOMRIGHT", -26, 6)

	local delChild = CreateFrame("Frame", "LootFilterScrollChildFrame2", delScroll)
	delChild:SetWidth(230)
	delChild:SetHeight(340)
	delScroll:SetScrollChild(delChild)

	local delEdit = CreateFrame("EditBox", "LootFilterEditBox2", delChild)
	delEdit:SetWidth(230)
	delEdit:SetHeight(340)
	delEdit:SetPoint("TOPLEFT")
	delEdit:SetMultiLine(true)
	delEdit:SetAutoFocus(false)
	delEdit:SetMaxLetters(7500)
	delEdit:SetFontObject(ChatFontNormal)
	delEdit:SetScript("OnShow", function() LootFilter.getNamesDelete() end)
	delEdit:SetScript("OnTextChanged", function()
		local scrollBar = getglobal("LootFilterScrollFrame2ScrollBar")
		delScroll:UpdateScrollChildRect()
		local mn, mx = scrollBar:GetMinMaxValues()
		if mx > 0 and (delEdit.max ~= mx) then
			delEdit.max = mx
			scrollBar:SetValue(mx)
		end
	end)
	delEdit:SetScript("OnEscapePressed", function() LootFilter.updateFocus(2, false) end)
	delEdit:SetScript("OnEditFocusGained", function() LootFilter.updateFocus(2, true) end)
	delEdit:SetScript("OnEditFocusLost", function() LootFilter.setNamesDelete() end)
	delEdit:SetScript("OnEnter", function() LootFilter.showTooltip(delEdit, "LToolTip6") end)
	delEdit:SetScript("OnLeave", function() GameTooltip:Hide() end)
	delChild:SetScript("OnMouseUp", function() delEdit:SetFocus() end)
	delChild:EnableMouse(true)

	-- Pattern help
	local patternHelp = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	patternHelp:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 10, 6)
	patternHelp:SetWidth(550)
	patternHelp:SetJustifyH("LEFT")
	patternHelp:SetText("|cffaaaaaaExact:|r Hearthstone   |cffaaaaaa*:|r *Beast*   |cffaaaaaa#:|r #pattern   |cffaaaaaa##:|r ##tooltip   |cffaaaaaaComment:|r name ; note|r")
	patternHelp:SetTextColor(0.5, 0.5, 0.5)

	return page
end

-- -------------------------------------------------------------------------
-- Page: Values
-- -------------------------------------------------------------------------

local function createValueEditBox(parent, name, x, y, w)
	local bg = createPanel(parent, name .. "BG", w + 10, 25)
	bg:SetPoint("TOPLEFT", parent, "TOPLEFT", x - 5, y + 2)

	local eb = CreateFrame("EditBox", name, parent)
	eb:SetWidth(w)
	eb:SetHeight(20)
	eb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	eb:SetAutoFocus(false)
	eb:SetMaxLetters(5)
	eb:SetFontObject(ChatFontNormal)
	eb:SetScript("OnEscapePressed", function() eb:ClearFocus() end)
	eb:SetScript("OnEditFocusLost", function() LootFilter.setItemValue() end)
	eb:SetScript("OnShow", function() LootFilter.getItemValue() end)

	return eb, bg
end

local function createValuesPage(parent)
	local page = CreateFrame("Frame", "LootFilterPageValues", parent)
	page:SetAllPoints()
	page:Hide()

	-- Need-addon message (shown when no GetSellValue)
	local needAddon = page:CreateFontString("LootFilterNeedAddon", "OVERLAY", "GameFontNormal")
	needAddon:SetPoint("TOPLEFT", page, "TOPLEFT", 10, -50)
	needAddon:SetWidth(540)
	needAddon:SetJustifyH("LEFT")
	needAddon:SetJustifyV("TOP")
	needAddon:SetText(LFINT_TXT_INFORMANTNEED)

	-- Section header
	createSectionHeader(page, "Value Thresholds", 10, -10)

	-- Caching
	local cachingOpt = createCheckOption(page, "LootFilterOPCaching", 10, -36)
	cachingOpt:Hide()

	local freeSlotsLabel = page:CreateFontString("LootFilterFreeSlotsText", "OVERLAY", "GameFontNormal")
	freeSlotsLabel:SetPoint("TOPLEFT", page, "TOPLEFT", 250, -36)
	freeSlotsLabel:SetText(LFINT_TXT_NUMFREEBAGSLOTS)
	freeSlotsLabel:Hide()

	local freeSlots, freeSlotsBG = createValueEditBox(page, "LootFilterEditBox5", 450, -36, 40)
	freeSlots:Hide()
	freeSlotsBG:Hide()
	LootFilterTextBackground5 = freeSlotsBG

	-- Delete threshold
	local delValOpt = createCheckOption(page, "LootFilterOPValDelete", 10, -68)
	delValOpt:Hide()

	local delVal, delValBG = createValueEditBox(page, "LootFilterEditBox3", 250, -68, 40)
	delVal:Hide()
	delValBG:Hide()
	LootFilterTextBackground3 = delValBG
	delVal:SetScript("OnEnter", function() LootFilter.showTooltip(delVal, "LToolTip7") end)
	delVal:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- Keep threshold
	local keepValOpt = createCheckOption(page, "LootFilterOPValKeep", 10, -96)
	keepValOpt:Hide()

	local keepVal, keepValBG = createValueEditBox(page, "LootFilterEditBox4", 250, -96, 40)
	keepVal:Hide()
	keepValBG:Hide()
	LootFilterTextBackground4 = keepValBG
	keepVal:SetScript("OnEnter", function() LootFilter.showTooltip(keepVal, "LToolTip8") end)
	keepVal:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- No-value option
	local noValOpt = createCheckOption(page, "LootFilterOPNoValue", 10, -124)
	noValOpt:Hide()

	-- Calculate method
	local calcLabel = page:CreateFontString("LootFilterSizeToCalculate", "OVERLAY", "GameFontNormal")
	calcLabel:SetPoint("TOPLEFT", page, "TOPLEFT", 10, -154)
	calcLabel:SetText(LFINT_TXT_SIZETOCALCULATE)
	calcLabel:Hide()

	local calcDrop = CreateFrame("Button", "LootFilterSelectDropDownCalculate", page, "UIDropDownMenuTemplate")
	calcDrop:SetPoint("TOPLEFT", page, "TOPLEFT", 190, -148)
	calcDrop:Hide()

	-- Market value
	local marketOpt = createCheckOption(page, "LootFilterOPMarketValue", 10, -180)
	marketOpt:Hide()

	-- Session statistics
	createSectionHeader(page, "Session Statistics", 10, -210)

	local resetBtn = CreateFrame("Button", "LootFilterButtonReset", page, "GameMenuButtonTemplate")
	resetBtn:SetWidth(70)
	resetBtn:SetHeight(20)
	resetBtn:SetPoint("TOPLEFT", page, "TOPLEFT", 180, -210)
	resetBtn:SetText(LFINT_BTN_RESET or "Reset")
	resetBtn:SetScript("OnClick", function()
		LootFilter.sessionReset()
		LootFilter.sessionUpdateValues()
	end)
	resetBtn:Hide()

	local infoY = -234
	local si = page:CreateFontString("LootFilterTextSessionValueInfo", "OVERLAY", "GameFontNormal")
	si:SetPoint("TOPLEFT", page, "TOPLEFT", 14, infoY)
	local sit = page:CreateFontString("LootFilterTextSessionItemTotal", "OVERLAY", "GameFontNormal")
	sit:SetPoint("TOPLEFT", page, "TOPLEFT", 14, infoY - 16)
	local svt = page:CreateFontString("LootFilterTextSessionValueTotal", "OVERLAY", "GameFontNormal")
	svt:SetPoint("TOPLEFT", page, "TOPLEFT", 14, infoY - 32)
	local sva = page:CreateFontString("LootFilterTextSessionValueAverage", "OVERLAY", "GameFontNormal")
	sva:SetPoint("TOPLEFT", page, "TOPLEFT", 14, infoY - 48)
	local svh = page:CreateFontString("LootFilterTextSessionValueHour", "OVERLAY", "GameFontNormal")
	svh:SetPoint("TOPLEFT", page, "TOPLEFT", 14, infoY - 64)

	page:SetScript("OnShow", function() LootFilter.sessionUpdateValues() end)

	return page
end

-- -------------------------------------------------------------------------
-- Page: Cleanup
-- -------------------------------------------------------------------------

local CLEAN_LINES = 19

local function createCleanupPage(parent)
	local page = CreateFrame("Frame", "LootFilterPageCleanup", parent)
	page:SetAllPoints()
	page:Hide()

	createSectionHeader(page, "Bag Cleanup", 10, -10)

	local helpText = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	helpText:SetPoint("TOPLEFT", page, "TOPLEFT", 10, -28)
	helpText:SetText("Items that don't match any keep rules. Shift-click to add to keep list.")
	helpText:SetTextColor(0.6, 0.6, 0.6)

	-- Action buttons
	local deleteBtn = CreateFrame("Button", "LootFilterButtonDeleteItems", page, "GameMenuButtonTemplate")
	deleteBtn:SetWidth(140)
	deleteBtn:SetHeight(22)
	deleteBtn:SetPoint("TOPLEFT", page, "TOPLEFT", 10, -44)
	deleteBtn:SetText(LFINT_BTN_DELETEITEMS)

	local confirmBtn = CreateFrame("Button", "LootFilterButtonIWantTo", page, "GameMenuButtonTemplate")
	confirmBtn:SetWidth(140)
	confirmBtn:SetHeight(22)
	confirmBtn:SetPoint("LEFT", deleteBtn, "RIGHT", 8, 0)
	confirmBtn:SetText(LFINT_BTN_YESSURE)
	confirmBtn:Disable()

	deleteBtn:SetScript("OnClick", function() LootFilter.iWantTo() end)
	confirmBtn:SetScript("OnClick", function()
		if LootFilterButtonDeleteItems:GetText() == LootFilter.Locale.LocText["LTDeleteItems"] then
			LootFilter.sellQueue = 1
			LootFilter.deleteItems(GetTime() + LootFilter.LOOT_TIMEOUT, true)
		else
			LootFilter.sellQueue = 1
			LootFilter.deleteItems(GetTime() + LootFilter.LOOT_TIMEOUT, false)
		end
	end)

	-- Vendor options
	createCheckOption(page, "LootFilterOPOpenVendor", 320, -44)
	createCheckOption(page, "LootFilterOPAutoSell", 320, -60)

	-- Clean list
	local cleanPanel = createPanel(page, "LootFilterTextBackgroundClean", 555, 300)
	cleanPanel:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -80)

	local cleanScroll = CreateFrame("ScrollFrame", "LootFilterScrollFrameClean", cleanPanel, "FauxScrollFrameTemplate")
	cleanScroll:SetPoint("TOPLEFT", cleanPanel, "TOPLEFT", 8, -6)
	cleanScroll:SetPoint("BOTTOMRIGHT", cleanPanel, "BOTTOMRIGHT", -26, 6)

	for i = 1, CLEAN_LINES do
		local yOff = -((i - 1) * 16)
		local fs = cleanScroll:CreateFontString("cleanLine" .. i, "OVERLAY", "GameFontNormal")
		fs:SetPoint("TOPLEFT", cleanScroll, "TOPLEFT", 2, yOff - 2)
		fs:SetText("")

		local hitFrame = CreateFrame("Frame", "FrameCleanLine" .. i, cleanScroll, "LootFilterLineTemplate")
		hitFrame:SetPoint("TOPLEFT", cleanScroll, "TOPLEFT", 0, yOff - 2)
	end

	cleanScroll:SetScript("OnVerticalScroll", function()
		FauxScrollFrame_OnVerticalScroll(cleanScroll, cleanScroll:GetVerticalScroll(), 16, LootFilter.CleanScrollBar_Update)
	end)
	cleanScroll:SetScript("OnEnter", function() LootFilter.showTooltip(cleanScroll, "LToolTip10") end)
	cleanScroll:SetScript("OnLeave", function() GameTooltip:Hide() end)

	cleanPanel:SetScript("OnShow", function()
		LootFilter.initClean()
		LootFilter.processCleaning()
	end)

	local totalVal = page:CreateFontString("LootFilterTextCleanTotalValue", "OVERLAY", "GameFontNormal")
	totalVal:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 14, 6)

	page:SetScript("OnShow", function()
		LootFilter.constructCleanList()
	end)

	-- Global alias for events.lua
	LootFilterFrameClean = page

	return page
end

-- -------------------------------------------------------------------------
-- Page: Settings
-- -------------------------------------------------------------------------

local function createSettingsPage(parent)
	local page = CreateFrame("Frame", "LootFilterPageSettings", parent)
	page:SetAllPoints()
	page:Hide()

	-- General
	createSectionHeader(page, "General", 10, -10)
	createCheckOption(page, "LootFilterOPEnable", 14, -32)
	createCheckOption(page, "LootFilterOPLootBot", 14, -50)
	createCheckOption(page, "LootFilterOPTooltips", 14, -68)
	createCheckOption(page, "LootFilterOPConfirmDelete", 14, -86)

	-- Notifications
	createSectionHeader(page, "Notifications", 10, -112)
	createCheckOption(page, "LootFilterOPNotifyDelete", 14, -134)
	createCheckOption(page, "LootFilterOPNotifyKeep", 270, -134)
	createCheckOption(page, "LootFilterOPNotifyNoMatch", 14, -152)
	createCheckOption(page, "LootFilterOPNotifyOpen", 270, -152)
	createCheckOption(page, "LootFilterOPNotifyNew", 14, -170)

	-- Bags
	createSectionHeader(page, "Monitored Bags", 10, -196)

	local helpBags = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	helpBags:SetPoint("TOPLEFT", page, "TOPLEFT", 10, -214)
	helpBags:SetText("Select which bags Loot Filter should scan.")
	helpBags:SetTextColor(0.6, 0.6, 0.6)

	createCheckOption(page, "LootFilterOPBag0", 14, -232)
	createCheckOption(page, "LootFilterOPBag1", 120, -232)
	createCheckOption(page, "LootFilterOPBag2", 200, -232)
	createCheckOption(page, "LootFilterOPBag3", 280, -232)
	createCheckOption(page, "LootFilterOPBag4", 360, -232)

	-- Character copy
	createSectionHeader(page, "Character Settings", 10, -260)

	local copyLabel = page:CreateFontString("LootFilterEditBoxTitleCopy3", "OVERLAY", "GameFontNormal")
	copyLabel:SetPoint("TOPLEFT", page, "TOPLEFT", 14, -282)
	copyLabel:SetText(LFINT_TXT_SELECTCHARCOPY)

	local copyDrop = CreateFrame("Button", "LootFilterSelectDropDown", page, "UIDropDownMenuTemplate")
	copyDrop:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -298)

	local copyBtn = CreateFrame("Button", "LootFilterButtonRealCopy", page, "GameMenuButtonTemplate")
	copyBtn:SetWidth(110)
	copyBtn:SetHeight(22)
	copyBtn:SetPoint("TOPLEFT", page, "TOPLEFT", 350, -302)
	copyBtn:SetText(LFINT_BTN_COPYSETTINGS)
	copyBtn:SetScript("OnClick", function() LootFilter.copySettings() end)
	copyBtn:SetScript("OnShow", function()
		if LootFilterEditBoxTitleCopy4 then LootFilterEditBoxTitleCopy4:Hide() end
		if LootFilterEditBoxTitleCopy5 then LootFilterEditBoxTitleCopy5:Hide() end
	end)

	local delSettingsBtn = CreateFrame("Button", "LootFilterButtonRealDelete", page, "GameMenuButtonTemplate")
	delSettingsBtn:SetWidth(110)
	delSettingsBtn:SetHeight(22)
	delSettingsBtn:SetPoint("TOPLEFT", copyBtn, "BOTTOMLEFT", 0, -4)
	delSettingsBtn:SetText(LFINT_BTN_DELETESETTINGS)
	delSettingsBtn:SetScript("OnClick", function() LootFilter.deleteSettings() end)
	delSettingsBtn:SetScript("OnShow", function()
		if LootFilterEditBoxTitleCopy4 then LootFilterEditBoxTitleCopy4:Hide() end
		if LootFilterEditBoxTitleCopy5 then LootFilterEditBoxTitleCopy5:Hide() end
	end)

	local copySuccess = page:CreateFontString("LootFilterEditBoxTitleCopy4", "OVERLAY", "GameFontNormal")
	copySuccess:SetPoint("TOPLEFT", page, "TOPLEFT", 14, -344)
	copySuccess:SetText(LFINT_TXT_COPYSUCCESS)
	copySuccess:Hide()

	local delSuccess = page:CreateFontString("LootFilterEditBoxTitleCopy5", "OVERLAY", "GameFontNormal")
	delSuccess:SetPoint("TOPLEFT", page, "TOPLEFT", 14, -344)
	delSuccess:SetText(LFINT_TXT_DELETESUCCESS)
	delSuccess:Hide()

	return page
end

-- -------------------------------------------------------------------------
-- Navigation
-- -------------------------------------------------------------------------

function LootFilter.navigateTo(pageName)
	-- Save any pending text edits
	if LootFilter.REALMPLAYER ~= "" and LootFilterVars[LootFilter.REALMPLAYER] then
		LootFilter.setNames()
		LootFilter.setNamesDelete()
	end

	-- Hide all pages, deselect all nav buttons
	for _, name in ipairs(PAGES) do
		if pageFrames[name] then pageFrames[name]:Hide() end
		if sidebarButtons[name] then
			sidebarButtons[name]:UnlockHighlight()
			if sidebarButtons[name].indicator then
				sidebarButtons[name].indicator:Hide()
			end
		end
	end

	-- Show selected page
	if pageFrames[pageName] then pageFrames[pageName]:Show() end
	if sidebarButtons[pageName] then
		sidebarButtons[pageName]:LockHighlight()
		if sidebarButtons[pageName].indicator then
			sidebarButtons[pageName].indicator:Show()
		end
	end

	-- Page-specific actions
	if pageName == "Values" then
		LootFilter.checkDependencies()
	elseif pageName == "Settings" then
		LootFilter.initCopyTab()
	end

	LootFilter.currentPage = pageName
end

-- Backward compat: events.lua calls selectButton(LootFilterButtonClean, LootFilterFrameClean)
function LootFilter.selectButton(button, frame)
	if frame == LootFilterFrameClean then
		LootFilter.navigateTo("Cleanup")
	else
		LootFilter.navigateTo("Filters")
	end
end

-- -------------------------------------------------------------------------
-- Build UI (called once from LootFilter.xml OnLoad)
-- -------------------------------------------------------------------------

function LootFilter.buildUI()
	local main = LootFilterOptions

	-- Close X button at top-right
	local closeX = CreateFrame("Button", "LootFilterCloseX", main, "UIPanelCloseButton")
	closeX:SetPoint("TOPRIGHT", main, "TOPRIGHT", -4, -4)
	closeX:SetScript("OnClick", function()
		if LootFilter.REALMPLAYER ~= "" and LootFilterVars[LootFilter.REALMPLAYER] then
			LootFilter.setNames()
			LootFilter.setNamesDelete()
			LootFilter.setItemValue()
		end
		safeHide()
	end)

	-- Content area (right of sidebar)
	local content = CreateFrame("Frame", "LootFilterContent", main)
	content:SetPoint("TOPLEFT", main, "TOPLEFT", 144, -38)
	content:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -16, 16)

	-- Sidebar
	createSidebar(main)

	-- Pages (NO data access during creation - just frame structure)
	pageFrames["Filters"]  = createFiltersPage(content)
	pageFrames["Names"]    = createNamesPage(content)
	pageFrames["Values"]   = createValuesPage(content)
	pageFrames["Cleanup"]  = createCleanupPage(content)
	pageFrames["Settings"] = createSettingsPage(content)

	-- Global aliases for backward compat
	LootFilterFrameGeneral = pageFrames["Settings"]
	LootFilterButtonClean = sidebarButtons["Cleanup"]
	LootFilterButtonGeneral = sidebarButtons["Settings"]

	-- Set title
	LootFilter.setTitle()

	-- Do NOT call navigateTo here - REALMPLAYER is not set yet.
	-- It will be called from ADDON_LOADED in events.lua.
end

-- -------------------------------------------------------------------------
-- Init functions (called from ADDON_LOADED after SavedVariables are ready)
-- -------------------------------------------------------------------------

function LootFilter.initQualityTab()
	for _, qi in ipairs(QUALITY_ORDER) do
		local chip = qualityChips[qi.key]
		if chip then
			updateChipVisual(chip)
		end
	end
end

function LootFilter.initTypeTab()
	typeRows = {}

	for _, typeName in LootFilter.sortedPairs(LootFilter.Locale.types) do
		local headerRow = createTypeHeaderRow(typeScrollChild, typeName, typeName)
		table.insert(typeRows, headerRow)

		-- Hidden parent frame for backend compat
		local hiddenParent = CreateFrame("Frame", "LootFilterDKDType" .. typeName, LootFilterPageFilters)
		hiddenParent:Hide()

		for key, displayName in LootFilter.sortedPairs(LootFilter.Locale.radioButtonsText) do
			if string.match(key, "^TY" .. typeName) then
				local subRow = createTypeSubRow(typeScrollChild, key, displayName, typeName)
				table.insert(typeRows, subRow)
				-- Now safe to update visual since SavedVars are loaded
				updateTypeRowVisual(subRow)
			end
		end
	end

	layoutTypeRows()
end

-- -------------------------------------------------------------------------
-- Original UI functions (backward compat with other files)
-- -------------------------------------------------------------------------

function LootFilter.getNames()
	if LootFilter.REALMPLAYER == "" or not LootFilterVars[LootFilter.REALMPLAYER] then return end
	local result = ""
	table.sort(LootFilterVars[LootFilter.REALMPLAYER].keepList["names"])
	for key, value in ipairs(LootFilterVars[LootFilter.REALMPLAYER].keepList["names"]) do
		result = result .. value .. "\n"
	end
	LootFilterEditBox1:SetText(result)
end

function LootFilter.getNamesDelete()
	if LootFilter.REALMPLAYER == "" or not LootFilterVars[LootFilter.REALMPLAYER] then return end
	local result = ""
	table.sort(LootFilterVars[LootFilter.REALMPLAYER].deleteList["names"])
	for key, value in ipairs(LootFilterVars[LootFilter.REALMPLAYER].deleteList["names"]) do
		result = result .. value .. "\n"
	end
	LootFilterEditBox2:SetText(result)
end

function LootFilter.setNames()
	if LootFilter.REALMPLAYER == "" or not LootFilterVars[LootFilter.REALMPLAYER] then return end
	LootFilterVars[LootFilter.REALMPLAYER].keepList["names"] = {}
	local result = LootFilterEditBox1:GetText() .. "\n"
	if result ~= nil then
		for w in string.gmatch(result, "[^\n]+\n") do
			w = string.gsub(w, "\n", "")
			w = LootFilter.normalizeNameFilterEntry(w)
			if w ~= "" then
				table.insert(LootFilterVars[LootFilter.REALMPLAYER].keepList["names"], w)
			end
		end
	end
end

function LootFilter.setNamesDelete()
	if LootFilter.REALMPLAYER == "" or not LootFilterVars[LootFilter.REALMPLAYER] then return end
	LootFilterVars[LootFilter.REALMPLAYER].deleteList["names"] = {}
	local result = LootFilterEditBox2:GetText() .. "\n"
	if result ~= nil then
		for w in string.gmatch(result, "[^\n]+\n") do
			w = string.gsub(w, "\n", "")
			w = LootFilter.normalizeNameFilterEntry(w)
			if w ~= "" then
				table.insert(LootFilterVars[LootFilter.REALMPLAYER].deleteList["names"], w)
			end
		end
	end
end

function LootFilter.showTooltip(area, text)
	if LootFilter.REALMPLAYER == "" or not LootFilterVars[LootFilter.REALMPLAYER] then return end
	if LootFilterVars[LootFilter.REALMPLAYER].tooltips then
		GameTooltip:SetOwner(LootFilterOptions, "ANCHOR_TOPRIGHT")
		GameTooltip:SetText(LootFilter.Locale.LocTooltip[text], 1, 1, 1, 0.75, 1)
		GameTooltip:Show()
	end
end

function LootFilter.setRadioButtonsValue(button)
	local name = LootFilter.trim(button:GetParent():GetName())
	if LootFilter.REALMPLAYER == "" or not LootFilterVars[LootFilter.REALMPLAYER] then return end
	if LootFilterVars[LootFilter.REALMPLAYER].keepList[name] ~= nil then
		LootFilterVars[LootFilter.REALMPLAYER].keepList[name] = nil
	end
	if LootFilterVars[LootFilter.REALMPLAYER].deleteList[name] ~= nil then
		LootFilterVars[LootFilter.REALMPLAYER].deleteList[name] = nil
	end

	local children = { this:GetParent():GetChildren() }
	local i = 0
	for _, child in ipairs(children) do
		if child ~= button then
			child:SetChecked(false)
		else
			button:SetChecked(true)
			if i == 1 then
				if string.match(name, "^QU") then
					LootFilterVars[LootFilter.REALMPLAYER].keepList[name] = LootFilter.Locale.qualities[name]
				elseif string.match(name, "^TY") then
					LootFilterVars[LootFilter.REALMPLAYER].keepList[name] = LootFilter.Locale.radioButtonsText[name]
				else
					LootFilterVars[LootFilter.REALMPLAYER].keepList[name] = true
				end
			elseif i == 2 then
				if string.match(name, "^QU") then
					LootFilterVars[LootFilter.REALMPLAYER].deleteList[name] = LootFilter.Locale.qualities[name]
				elseif string.match(name, "^TY") then
					LootFilterVars[LootFilter.REALMPLAYER].deleteList[name] = LootFilter.Locale.radioButtonsText[name]
				else
					LootFilterVars[LootFilter.REALMPLAYER].deleteList[name] = true
				end
			end
		end
		i = i + 1
	end
end

function LootFilter.getRadioButtonsValue(button)
	if LootFilter.REALMPLAYER == "" or not LootFilterVars[LootFilter.REALMPLAYER] then return end
	local name = LootFilter.trim(button:GetName())
	local fontString = getglobal(button:GetName() .. "_Text")
	local radioButton = getglobal(button:GetName() .. "_Default")

	getglobal(button:GetName() .. "_Default"):SetChecked(false)
	getglobal(button:GetName() .. "_Keep"):SetChecked(false)
	getglobal(button:GetName() .. "_Delete"):SetChecked(false)
	fontString:SetText(LootFilter.Locale.radioButtonsText[name])
	if LootFilterVars[LootFilter.REALMPLAYER].keepList[name] ~= nil then
		radioButton = getglobal(button:GetName() .. "_Keep")
	elseif LootFilterVars[LootFilter.REALMPLAYER].deleteList[name] ~= nil then
		radioButton = getglobal(button:GetName() .. "_Delete")
	end
	radioButton:SetChecked(true)
end

function LootFilter.setRadioButtonValue(button)
	local name = LootFilter.trim(button:GetParent():GetName())
	if LootFilter.REALMPLAYER == "" or not LootFilterVars[LootFilter.REALMPLAYER] then return end
	local checked = false
	if button:GetChecked() then
		checked = true
	end

	if name == "OPEnable" then
		LootFilterVars[LootFilter.REALMPLAYER].enabled = checked
	elseif name == "OPLootBot" then
		LootFilterVars[LootFilter.REALMPLAYER].lootbotmode = checked
		if checked then
			LootFilter.takeBagSnapshot()
			LootFilter.print("|cff00ff00Loot Bot Mode ENABLED|r - Items added to bags will be filtered automatically.")
		else
			LootFilter.print("|cffff0000Loot Bot Mode DISABLED|r - Only items from loot windows will be filtered.")
		end
	elseif name == "OPCaching" then
		LootFilterVars[LootFilter.REALMPLAYER].caching = checked
		if checked then
			LootFilterEditBox5:Show()
			if LootFilterTextBackground5 then LootFilterTextBackground5:Show() end
			LootFilterFreeSlotsText:Show()
		else
			LootFilterEditBox5:Hide()
			if LootFilterTextBackground5 then LootFilterTextBackground5:Hide() end
			LootFilterFreeSlotsText:Hide()
		end
	elseif name == "OPNoValue" then
		LootFilterVars[LootFilter.REALMPLAYER].novalue = checked
	elseif name == "OPMarketValue" then
		LootFilterVars[LootFilter.REALMPLAYER].marketvalue = checked
	elseif name == "OPTooltips" then
		LootFilterVars[LootFilter.REALMPLAYER].tooltips = checked
	elseif name == "OPNotifyDelete" then
		LootFilterVars[LootFilter.REALMPLAYER].notifydelete = checked
	elseif name == "OPNotifyKeep" then
		LootFilterVars[LootFilter.REALMPLAYER].notifykeep = checked
	elseif name == "OPNotifyNoMatch" then
		LootFilterVars[LootFilter.REALMPLAYER].notifynomatch = checked
	elseif name == "OPNotifyOpen" then
		LootFilterVars[LootFilter.REALMPLAYER].notifyopen = checked
	elseif name == "OPNotifyNew" then
		LootFilterVars[LootFilter.REALMPLAYER].notifynew = checked
	elseif name == "OPValKeep" then
		LootFilterVars[LootFilter.REALMPLAYER].keepList["VAOn"] = checked
	elseif name == "OPValDelete" then
		LootFilterVars[LootFilter.REALMPLAYER].deleteList["VAOn"] = checked
	elseif name == "OPOpenVendor" then
		LootFilterVars[LootFilter.REALMPLAYER].openvendor = checked
	elseif name == "OPAutoSell" then
		LootFilterVars[LootFilter.REALMPLAYER].autosell = checked
	elseif name == "OPBag0" then
		LootFilterVars[LootFilter.REALMPLAYER].openbag[0] = checked
	elseif name == "OPBag1" then
		LootFilterVars[LootFilter.REALMPLAYER].openbag[1] = checked
	elseif name == "OPBag2" then
		LootFilterVars[LootFilter.REALMPLAYER].openbag[2] = checked
	elseif name == "OPBag3" then
		LootFilterVars[LootFilter.REALMPLAYER].openbag[3] = checked
	elseif name == "OPBag4" then
		LootFilterVars[LootFilter.REALMPLAYER].openbag[4] = checked
	elseif name == "OPConfirmDelete" then
		LootFilterVars[LootFilter.REALMPLAYER].confirmdel = checked
	end
end

function LootFilter.getRadioButtonValue(button)
	if LootFilter.REALMPLAYER == "" or not LootFilterVars[LootFilter.REALMPLAYER] then return end
	local name = LootFilter.trim(button:GetName())
	local fontString = getglobal(button:GetName() .. "_Text")
	local radioButton = getglobal(button:GetName() .. "_Button")
	fontString:SetText(LootFilter.Locale.radioButtonsText[name])
	if name == "OPEnable" then
		radioButton:SetChecked(LootFilterVars[LootFilter.REALMPLAYER].enabled)
	elseif name == "OPLootBot" then
		radioButton:SetChecked(LootFilterVars[LootFilter.REALMPLAYER].lootbotmode)
	elseif name == "OPCaching" then
		radioButton:SetChecked(LootFilterVars[LootFilter.REALMPLAYER].caching)
	elseif name == "OPNoValue" then
		radioButton:SetChecked(LootFilterVars[LootFilter.REALMPLAYER].novalue)
	elseif name == "OPMarketValue" then
		radioButton:SetChecked(LootFilterVars[LootFilter.REALMPLAYER].marketvalue)
	elseif name == "OPTooltips" then
		radioButton:SetChecked(LootFilterVars[LootFilter.REALMPLAYER].tooltips)
	elseif name == "OPNotifyDelete" then
		radioButton:SetChecked(LootFilterVars[LootFilter.REALMPLAYER].notifydelete)
	elseif name == "OPNotifyKeep" then
		radioButton:SetChecked(LootFilterVars[LootFilter.REALMPLAYER].notifykeep)
	elseif name == "OPNotifyOpen" then
		radioButton:SetChecked(LootFilterVars[LootFilter.REALMPLAYER].notifyopen)
	elseif name == "OPNotifyNew" then
		radioButton:SetChecked(LootFilterVars[LootFilter.REALMPLAYER].notifynew)
	elseif name == "OPNotifyNoMatch" then
		radioButton:SetChecked(LootFilterVars[LootFilter.REALMPLAYER].notifynomatch)
	elseif name == "OPValKeep" then
		radioButton:SetChecked(LootFilterVars[LootFilter.REALMPLAYER].keepList["VAOn"])
	elseif name == "OPValDelete" then
		radioButton:SetChecked(LootFilterVars[LootFilter.REALMPLAYER].deleteList["VAOn"])
	elseif name == "OPOpenVendor" then
		radioButton:SetChecked(LootFilterVars[LootFilter.REALMPLAYER].openvendor)
	elseif name == "OPAutoSell" then
		radioButton:SetChecked(LootFilterVars[LootFilter.REALMPLAYER].autosell)
	elseif name == "OPBag0" then
		radioButton:SetChecked(LootFilterVars[LootFilter.REALMPLAYER].openbag[0])
	elseif name == "OPBag1" then
		radioButton:SetChecked(LootFilterVars[LootFilter.REALMPLAYER].openbag[1])
	elseif name == "OPBag2" then
		radioButton:SetChecked(LootFilterVars[LootFilter.REALMPLAYER].openbag[2])
	elseif name == "OPBag3" then
		radioButton:SetChecked(LootFilterVars[LootFilter.REALMPLAYER].openbag[3])
	elseif name == "OPBag4" then
		radioButton:SetChecked(LootFilterVars[LootFilter.REALMPLAYER].openbag[4])
	elseif name == "OPConfirmDelete" then
		radioButton:SetChecked(LootFilterVars[LootFilter.REALMPLAYER].confirmdel)
	end
end

function LootFilter.setItemValue()
	if LootFilter.REALMPLAYER == "" or not LootFilterVars[LootFilter.REALMPLAYER] then return end
	local value = tonumber(LootFilterEditBox3:GetText())
	if value == nil then value = 0 end
	LootFilterVars[LootFilter.REALMPLAYER].deleteList["VAValue"] = value

	value = tonumber(LootFilterEditBox4:GetText())
	if value == nil then value = 0 end
	LootFilterVars[LootFilter.REALMPLAYER].keepList["VAValue"] = value

	value = tonumber(LootFilterEditBox5:GetText())
	if value == nil then value = 0 end
	LootFilterVars[LootFilter.REALMPLAYER].freebagslots = value
end

function LootFilter.getItemValue()
	if LootFilter.REALMPLAYER == "" or not LootFilterVars[LootFilter.REALMPLAYER] then return end
	local value = ""
	if LootFilterVars[LootFilter.REALMPLAYER].deleteList["VAValue"] ~= nil and LootFilterVars[LootFilter.REALMPLAYER].deleteList["VAValue"] ~= "" then
		value = LootFilterVars[LootFilter.REALMPLAYER].deleteList["VAValue"]
	else
		value = "0"
	end
	LootFilterEditBox3:SetText(value)

	value = ""
	if LootFilterVars[LootFilter.REALMPLAYER].keepList["VAValue"] ~= nil and LootFilterVars[LootFilter.REALMPLAYER].keepList["VAValue"] ~= "" then
		value = LootFilterVars[LootFilter.REALMPLAYER].keepList["VAValue"]
	else
		value = "0"
	end
	LootFilterEditBox4:SetText(value)

	value = ""
	if LootFilterVars[LootFilter.REALMPLAYER].freebagslots ~= nil and LootFilterVars[LootFilter.REALMPLAYER].freebagslots ~= "" then
		value = LootFilterVars[LootFilter.REALMPLAYER].freebagslots
	else
		value = "0"
	end
	LootFilterEditBox5:SetText(value)
end

function LootFilter.updateFocus(num, value)
	if value then
		this:SetFocus()
		LootFilter.hasFocus = num
	else
		this:ClearFocus()
		LootFilter.hasFocus = 0
	end
end

function LootFilter.iWantTo()
	LootFilterButtonIWantTo:Enable()
end

function LootFilter.initClean()
	LootFilterButtonDeleteItems:Enable()
	LootFilterButtonIWantTo:Disable()
	for line = 1, CLEAN_LINES do
		local cleanLine = getglobal("cleanLine" .. line)
		cleanLine:SetText("")
		cleanLine:Hide()
	end
	FauxScrollFrame_SetOffset(LootFilterScrollFrameClean, 0)
end

function LootFilter.setTitle()
	LootFilterFrameTitleText:SetText("Loot Filter v" .. LootFilter.VERSION)
end

function LootFilter.CleanScrollBar_Update()
	local numitems = table.getn(LootFilter.cleanList)
	if numitems < 20 then
		numitems = 20
	end
	FauxScrollFrame_Update(LootFilterScrollFrameClean, numitems, CLEAN_LINES, 16)
	for line = 1, CLEAN_LINES do
		local lineplusoffset = line + FauxScrollFrame_GetOffset(LootFilterScrollFrameClean)
		local cleanLine = getglobal("cleanLine" .. line)
		if lineplusoffset <= table.getn(LootFilter.cleanList) then
			cleanLine:SetText(LootFilter.cleanList[lineplusoffset]["link"])
			cleanLine:Show()
		else
			cleanLine:Hide()
		end
	end
end

function LootFilter.SelectDropDown_OnClick()
	UIDropDownMenu_SetSelectedValue(this.owner, this.value)
end

function LootFilter.SelectDropDown_Initialize()
	local i = 1
	for key, value in LootFilter.sortedPairs(LootFilterVars) do
		if key ~= LootFilter.REALMPLAYER and key:find("%s -") ~= nil then
			local info = UIDropDownMenu_CreateInfo()
			info.text = key
			info.value = i
			info.func = LootFilter.SelectDropDown_OnClick
			info.owner = this:GetParent()
			info.checked = nil
			info.icon = nil
			UIDropDownMenu_AddButton(info, level)

			if UIDropDownMenu_GetSelectedValue(LootFilterSelectDropDown) == nil then
				UIDropDownMenu_SetSelectedID(LootFilterSelectDropDown, i)
				UIDropDownMenu_SetSelectedValue(LootFilterSelectDropDown, i)
				UIDropDownMenu_SetText(LootFilterSelectDropDown, key)
			end
			i = i + 1
		end
	end
end

function LootFilter.SelectDropDownType_OnClick()
	UIDropDownMenu_SetSelectedValue(this.owner, this.value)
	LootFilter.hideTypeTabs()
	local f = getglobal("LootFilterDKDType" .. UIDropDownMenu_GetText(LootFilterSelectDropDownType))
	if f then f:Show() end
end

function LootFilter.SelectDropDownType_Initialize()
	local i = 1
	for key, value in LootFilter.sortedPairs(LootFilter.Locale.types) do
		local info = UIDropDownMenu_CreateInfo()
		info.text = value
		info.value = i
		info.func = LootFilter.SelectDropDownType_OnClick
		info.owner = this:GetParent()
		info.checked = nil
		info.icon = nil
		UIDropDownMenu_AddButton(info, level)

		if UIDropDownMenu_GetSelectedValue(LootFilterSelectDropDownType) == nil then
			UIDropDownMenu_SetSelectedID(LootFilterSelectDropDownType, i)
			UIDropDownMenu_SetSelectedValue(LootFilterSelectDropDownType, i)
			UIDropDownMenu_SetText(LootFilterSelectDropDownType, value)
			local f = getglobal("LootFilterDKDType" .. value)
			if f ~= nil then f:Show() end
		end
		i = i + 1
	end
end

function LootFilter.SelectDropDownCalculate_OnClick()
	UIDropDownMenu_SetSelectedValue(this.owner, this.value)
	LootFilterVars[LootFilter.REALMPLAYER].calculate = this.value
end

function LootFilter.SelectDropDownCalculate_Initialize()
	local i = 1
	local text = {}
	text[1] = LFINT_TXT_SIZETOCALCULATE_TEXT1
	text[2] = LFINT_TXT_SIZETOCALCULATE_TEXT2
	text[3] = LFINT_TXT_SIZETOCALCULATE_TEXT3
	for key, value in LootFilter.sortedPairs(text) do
		local info = UIDropDownMenu_CreateInfo()
		info.text = value
		info.value = i
		info.func = LootFilter.SelectDropDownCalculate_OnClick
		info.owner = this:GetParent()
		info.checked = nil
		info.icon = nil
		UIDropDownMenu_AddButton(info, level)

		if LootFilterVars[LootFilter.REALMPLAYER].calculate == i then
			UIDropDownMenu_SetSelectedID(LootFilterSelectDropDownCalculate, i)
			UIDropDownMenu_SetSelectedValue(LootFilterSelectDropDownCalculate, i)
			UIDropDownMenu_SetText(LootFilterSelectDropDownCalculate, value)
		end
		i = i + 1
	end
end

function LootFilter.checkDependencies()
	if LootFilter.REALMPLAYER == "" or LootFilterVars[LootFilter.REALMPLAYER] == nil then return end
	if GetSellValue ~= nil then
		LootFilterOPCaching:Show()
		if LootFilterVars[LootFilter.REALMPLAYER].caching then
			LootFilterEditBox5:Show()
			if LootFilterTextBackground5 then LootFilterTextBackground5:Show() end
			LootFilterFreeSlotsText:Show()
		end
		LootFilterOPValKeep:Show()
		LootFilterOPValDelete:Show()
		LootFilterEditBox3:Show()
		LootFilterEditBox4:Show()
		if LootFilterTextBackground3 then LootFilterTextBackground3:Show() end
		if LootFilterTextBackground4 then LootFilterTextBackground4:Show() end
		LootFilterOPNoValue:Show()
		LootFilterSelectDropDownCalculate:Show()
		LootFilterSizeToCalculate:Show()
		LootFilterButtonReset:Show()
		LootFilterNeedAddon:Hide()
		if (AucAdvanced) and (AucAdvanced.API) and (AucAdvanced.API.GetMarketValue) then
			LootFilterOPMarketValue:Show()
			LootFilter.marketValue = true
		end
	end
end

function LootFilter.hideTypeTabs()
	for key, typeName in pairs(LootFilter.Locale.types) do
		local f = getglobal("LootFilterDKDType" .. typeName)
		if f then f:Hide() end
	end
end

function LootFilter.sortedPairs(t, comparator)
	local sortedKeys = {}
	table.foreach(t, function(k, v) table.insert(sortedKeys, k) end)
	table.sort(sortedKeys, comparator)
	local i = 0
	local function _f(_s, _v)
		i = i + 1
		local k = sortedKeys[i]
		if k then return k, t[k] end
	end
	return _f, nil, nil
end

function LootFilter.initCopyTab()
	if LootFilter.varCount() <= 1 then
		LootFilterButtonRealCopy:Hide()
		LootFilterSelectDropDown:Hide()
		LootFilterButtonRealDelete:Hide()
		LootFilterEditBoxTitleCopy3:SetText(LootFilter.Locale.LocText["LTNoOtherCharacterToCopySettings"])
		LootFilterEditBoxTitleCopy4:Hide()
		LootFilterEditBoxTitleCopy5:Hide()
	else
		LootFilterButtonRealCopy:Show()
		LootFilterSelectDropDown:Show()
		LootFilterButtonRealDelete:Show()
		LootFilterEditBoxTitleCopy3:SetText(LFINT_TXT_SELECTCHARCOPY)
	end
end
