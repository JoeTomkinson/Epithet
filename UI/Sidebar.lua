-- =============================================================================
-- Epithet — Filter Sidebar (left column)
-- Search, status segments, rarity / type / expansion facets, reset.
-- Uses relative anchoring throughout; expansion list is scrollable so the
-- column never overflows. "Reset all filters" is pinned to the bottom.
-- =============================================================================
local _, ns = ...
local L = ns.L
local T = ns.Theme

-- Localize Lua stdlib
local next, pairs, ipairs = next, pairs, ipairs
local wipe = wipe

local Sidebar = {}
ns.Sidebar = Sidebar

local col = T and T.col or {}
local GOLD        = col.gold     or { r = 0.91, g = 0.78, b = 0.45 }
local GOLD_DIM    = col.goldDim  or { r = 0.73, g = 0.57, b = 0.25 }
local DARK_TEXT   = col.ink      or { r = 0.08, g = 0.06, b = 0.03 }
local COUNT_COL   = col.faint    or { r = 0.55, g = 0.50, b = 0.40 }
local INSET_COL   = col.inset    or { r = 0.05, g = 0.04, b = 0.02 }
local MUTED       = col.muted    or { r = 0.61, g = 0.55, b = 0.42 }

local PAD_X = 14

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local function CreateHeading(parent, text, anchorFrame, yGap)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    fs:SetText(text)
    fs:SetTextColor(GOLD_DIM.r, GOLD_DIM.g, GOLD_DIM.b)
    if anchorFrame then
        fs:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, -(yGap or 10))
    else
        fs:SetPoint("TOPLEFT", PAD_X, -(yGap or 14))
    end
    return fs
end

-- ---------------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------------
function Sidebar:Init(sidebar)
    if self.sidebar then return end
    self.sidebar = sidebar
    self.checkboxes = {}   -- list of { box, count, facet, key }
    self.statusButtons = {}

    local db = ns.Epithet.db.profile

    -- ----- Search box ------------------------------------------------------
    local search = CreateFrame("EditBox", nil, sidebar, "SearchBoxTemplate")
    search:SetSize(206, 22)
    search:SetPoint("TOPLEFT", PAD_X, -14)
    search:SetPoint("TOPRIGHT", -PAD_X, -14)
    if search.Instructions then
        search.Instructions:SetText(L["SEARCH_PLACEHOLDER"])
    end
    search:SetAutoFocus(false)
    search:SetScript("OnTextChanged", function(box, userInput)
        if SearchBoxTemplate_OnTextChanged then SearchBoxTemplate_OnTextChanged(box) end
        local text = box:GetText() or ""
        if userInput or text == "" then
            db.filters.search = text
            ns.MainFrame:RefreshList()
        end
    end)
    search:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
    self.searchBox = search

    -- ----- Status segments -------------------------------------------------
    local statusHeading = CreateHeading(sidebar, L["STATUS"], search, 12)
    self.statusHeading = statusHeading

    local statusRow = CreateFrame("Frame", nil, sidebar)
    statusRow:SetPoint("TOPLEFT", statusHeading, "BOTTOMLEFT", 0, -6)
    statusRow:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", -PAD_X, 0)
    statusRow:SetHeight(24)

    local segDefs = {
        { value = "all",      label = L["STATUS_ALL"] },
        { value = "earned",   label = L["STATUS_EARNED"] },
        { value = "unearned", label = L["STATUS_UNEARNED"] },
    }
    local segWidth = 64
    for i, def in ipairs(segDefs) do
        local btn = self:CreateStatusSegment(statusRow, def.label, def.value)
        btn:SetWidth(segWidth)
        btn:SetPoint("LEFT", (i - 1) * (segWidth + 4), 0)
        self.statusButtons[def.value] = btn
    end

    -- ----- Rarity facet ----------------------------------------------------
    local rarityHeading = CreateHeading(sidebar, L["RARITY_TIER"], statusRow, 14)
    local rarityDefs = {
        { key = 5, label = L["LEGENDARY"] },
        { key = 4, label = L["EPIC"] },
        { key = 3, label = L["RARE"] },
        { key = 2, label = L["UNCOMMON"] },
        { key = 1, label = L["COMMON"] },
    }
    local lastAnchor = rarityHeading
    for i, def in ipairs(rarityDefs) do
        local colour = ns.QUALITY_COLOURS[def.key]
        local box = self:CreateFilterCheckbox(sidebar, def.label, "rarity", def.key,
            lastAnchor, i == 1 and 4 or 0, colour and colour.text, false, colour and colour.pip)
        lastAnchor = box.box
    end

    -- ----- Type facet ------------------------------------------------------
    local typeHeading = CreateHeading(sidebar, L["TYPE"], lastAnchor, 12)
    local typeDefs = {
        { key = "prefix", label = L["PREFIX"] },
        { key = "suffix", label = L["SUFFIX"] },
    }
    lastAnchor = typeHeading
    for i, def in ipairs(typeDefs) do
        local box = self:CreateFilterCheckbox(sidebar, def.label, "type", def.key,
            lastAnchor, i == 1 and 4 or 0, nil)
        lastAnchor = box.box
    end

    -- ----- Additional filters (scrollable, modern minimal scrollbar) -----
    local addFiltersHeading = CreateHeading(sidebar, L["ADDITIONAL_FILTERS"], lastAnchor, 12)
    self.expHeading = addFiltersHeading

    -- Scrollable container for expansion + category + kind + faction
    local scrollBox = CreateFrame("Frame", nil, sidebar, "WowScrollBox")
    scrollBox:SetPoint("TOPLEFT", addFiltersHeading, "BOTTOMLEFT", 0, -6)
    scrollBox:SetPoint("RIGHT", sidebar, "RIGHT", -PAD_X - 14, 0)
    scrollBox:SetPoint("BOTTOM", sidebar, "BOTTOM", 0, 40)

    local scrollBar = CreateFrame("EventFrame", nil, sidebar, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 4, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 4, 0)

    local child = CreateFrame("Frame", nil, scrollBox)
    child.scrollable = true
    child:SetPoint("TOPLEFT")
    child:SetPoint("TOPRIGHT")

    local view = CreateScrollBoxLinearView()
    view:SetPanExtent(24)
    ScrollUtil.InitScrollBoxWithScrollBar(scrollBox, scrollBar, view)

    self.expScrollBox = scrollBox
    self.expChild = child

    -- ----- Expansion facet (inside scroll) --------------------------------
    local expHeading = child:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    expHeading:SetText(L["EXPANSION"])
    expHeading:SetTextColor(GOLD_DIM.r, GOLD_DIM.g, GOLD_DIM.b)
    expHeading:SetPoint("TOPLEFT", 0, -2)

    local expAnchor = expHeading
    local rowH = 24
    for i, key in ipairs(ns.EXPANSION_ORDER) do
        local label = ns.EXPANSION_LABELS[key] or key
        local box = self:CreateFilterCheckbox(child, label, "exp", key,
            expAnchor, i == 1 and 4 or 0, nil, true)
        expAnchor = box.box
    end

    -- ----- Category facet --------------------------------------------------
    local catHeading = child:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    catHeading:SetText(L["CATEGORY"] or "Category")
    catHeading:SetTextColor(GOLD_DIM.r, GOLD_DIM.g, GOLD_DIM.b)
    catHeading:SetPoint("TOPLEFT", expAnchor, "BOTTOMLEFT", 0, -12)
    local catDefs = {
        "Achievement", "Campaign", "Exploration", "Holiday",
        "Profession", "PvP", "Quest", "Raid", "Reputation",
    }
    local catAnchor = catHeading
    for i, key in ipairs(catDefs) do
        local box = self:CreateFilterCheckbox(child, key, "cat", key,
            catAnchor, i == 1 and 4 or 0, nil, true)
        catAnchor = box.box
    end

    -- ----- Kind facet ------------------------------------------------------
    local kindHeading = child:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    kindHeading:SetText(L["KIND"] or "Source Kind")
    kindHeading:SetTextColor(GOLD_DIM.r, GOLD_DIM.g, GOLD_DIM.b)
    kindHeading:SetPoint("TOPLEFT", catAnchor, "BOTTOMLEFT", 0, -12)
    local kindDefs = {
        "Achievement", "Feat of Strength", "Quest", "Reputation",
    }
    local kindAnchor = kindHeading
    for i, key in ipairs(kindDefs) do
        local box = self:CreateFilterCheckbox(child, key, "kind", key,
            kindAnchor, i == 1 and 4 or 0, nil, true)
        kindAnchor = box.box
    end

    -- ----- Faction facet ---------------------------------------------------
    local factionHeading = child:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    factionHeading:SetText(L["FACTION"] or "Faction")
    factionHeading:SetTextColor(GOLD_DIM.r, GOLD_DIM.g, GOLD_DIM.b)
    factionHeading:SetPoint("TOPLEFT", kindAnchor, "BOTTOMLEFT", 0, -12)
    local factionDefs = {
        { key = "Alliance", label = L["FACTION_ALLIANCE"] or "Alliance" },
        { key = "Horde",    label = L["FACTION_HORDE"] or "Horde" },
        { key = "Both",     label = L["FACTION_BOTH"] or "Both Factions" },
    }
    local factionAnchor = factionHeading
    for i, def in ipairs(factionDefs) do
        local box = self:CreateFilterCheckbox(child, def.label, "faction", def.key,
            factionAnchor, i == 1 and 4 or 0, nil, true)
        factionAnchor = box.box
    end

    -- ----- Availability hide toggles ---------------------------------------
    local availHeading = child:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    availHeading:SetText(L["AVAILABILITY"] or "Availability")
    availHeading:SetTextColor(GOLD_DIM.r, GOLD_DIM.g, GOLD_DIM.b)
    availHeading:SetPoint("TOPLEFT", factionAnchor, "BOTTOMLEFT", 0, -12)

    local hideUnobtBox = CreateFrame("CheckButton", nil, child, "UICheckButtonTemplate")
    hideUnobtBox:SetSize(20, 20)
    hideUnobtBox:SetPoint("TOPLEFT", availHeading, "BOTTOMLEFT", 0, -4)
    local hideUnobtText = hideUnobtBox:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    hideUnobtText:SetPoint("LEFT", hideUnobtBox, "RIGHT", 2, 0)
    hideUnobtText:SetText(L["HIDE_UNOBTAINABLE"] or "Hide unobtainable")
    hideUnobtBox:SetChecked(db.filters.hideUnobtainable or false)
    hideUnobtBox:SetScript("OnClick", function(self_)
        db.filters.hideUnobtainable = self_:GetChecked() and true or false
        ns.MainFrame:RefreshList()
    end)
    self.hideUnobtBox = hideUnobtBox

    local hideTimeSensBox = CreateFrame("CheckButton", nil, child, "UICheckButtonTemplate")
    hideTimeSensBox:SetSize(20, 20)
    hideTimeSensBox:SetPoint("TOPLEFT", hideUnobtBox, "BOTTOMLEFT", 0, 0)
    local hideTimeSensText = hideTimeSensBox:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    hideTimeSensText:SetPoint("LEFT", hideTimeSensBox, "RIGHT", 2, 0)
    hideTimeSensText:SetText(L["HIDE_TIME_SENSITIVE"] or "Hide time-sensitive")
    hideTimeSensBox:SetChecked(db.filters.hideTimeSensitive or false)
    hideTimeSensBox:SetScript("OnClick", function(self_)
        db.filters.hideTimeSensitive = self_:GetChecked() and true or false
        ns.MainFrame:RefreshList()
    end)
    self.hideTimeSensBox = hideTimeSensBox

    -- Calculate total scroll child height
    local totalSections = #ns.EXPANSION_ORDER + #catDefs + #kindDefs + #factionDefs + 2
    local headingsHeight = 4 * 16  -- 4 additional headings (cat, kind, faction, availability) with spacing
    child:SetHeight(totalSections * rowH + headingsHeight + 36)
    scrollBox:FullUpdate(ScrollBoxConstants.UpdateImmediately)

    -- ----- Reset link (pinned to bottom) ----------------------------------
    local reset = CreateFrame("Button", nil, sidebar)
    reset:SetSize(206, 24)
    reset:SetPoint("BOTTOMLEFT", PAD_X, 10)
    reset:SetPoint("BOTTOMRIGHT", -PAD_X, 10)
    local resetIcon = reset:CreateTexture(nil, "ARTWORK")
    resetIcon:SetTexture("Interface\\AddOns\\Epithet\\icons\\ui\\epithet-ui-reset-16")
    resetIcon:SetSize(12, 12)
    resetIcon:SetPoint("LEFT", 0, 0)
    resetIcon:SetVertexColor(GOLD_DIM.r, GOLD_DIM.g, GOLD_DIM.b)
    reset.icon = resetIcon
    local resetText = reset:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    resetText:SetPoint("LEFT", resetIcon, "RIGHT", 6, 0)
    resetText:SetText(L["RESET_ALL_FILTERS"])
    resetText:SetTextColor(GOLD_DIM.r, GOLD_DIM.g, GOLD_DIM.b)
    reset.text = resetText
    reset:SetScript("OnEnter", function()
        resetText:SetTextColor(GOLD.r, GOLD.g, GOLD.b)
        resetIcon:SetVertexColor(GOLD.r, GOLD.g, GOLD.b)
    end)
    reset:SetScript("OnLeave", function()
        resetText:SetTextColor(GOLD_DIM.r, GOLD_DIM.g, GOLD_DIM.b)
        resetIcon:SetVertexColor(GOLD_DIM.r, GOLD_DIM.g, GOLD_DIM.b)
    end)
    reset:SetScript("OnClick", function()
        ns.Filters:Reset(db.filters)
        if self.searchBox then self.searchBox:SetText("") end
        ns.MainFrame:RefreshList()
        self:Refresh()
    end)
    self.resetButton = reset
end

-- ---------------------------------------------------------------------------
-- Status segment button (gold fill when active, dark text)
-- ---------------------------------------------------------------------------
function Sidebar:CreateStatusSegment(parent, label, value)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetHeight(22)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    btn.bg = bg

    local border = btn:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(GOLD_DIM.r, GOLD_DIM.g, GOLD_DIM.b, 0.5)
    btn.border = border

    local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("CENTER")
    text:SetText(label)
    btn.text = text

    btn:SetScript("OnClick", function()
        ns.Epithet.db.profile.filters.status = value
        ns.MainFrame:RefreshList()
        self:UpdateStatusButtons()
    end)

    return btn
end

function Sidebar:UpdateStatusButtons()
    local active = ns.Epithet.db.profile.filters.status or "all"
    for value, btn in pairs(self.statusButtons) do
        if value == active then
            btn.bg:SetColorTexture(GOLD.r, GOLD.g, GOLD.b, 1.0)
            btn.text:SetTextColor(DARK_TEXT.r, DARK_TEXT.g, DARK_TEXT.b)
        else
            btn.bg:SetColorTexture(0.12, 0.10, 0.06, 0.6)
            btn.text:SetTextColor(GOLD.r, GOLD.g, GOLD.b)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Filter checkbox with trailing count
-- ---------------------------------------------------------------------------
function Sidebar:CreateFilterCheckbox(parent, label, facet, key, anchorFrame, yGap, labelColour, inScroll, pipColour)
    local box = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    box:SetSize(20, 20)
    if anchorFrame then
        box:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, -(yGap or 0))
    else
        box:SetPoint("TOPLEFT", inScroll and 0 or PAD_X, -(yGap or 0))
    end

    -- Optional coloured pip dot (for rarity facet)
    local labelAnchor = box
    local labelOffset = 2
    if pipColour then
        local pip = box:CreateTexture(nil, "ARTWORK")
        pip:SetSize(9, 9)
        pip:SetTexture("Interface\\COMMON\\Indicator-Gray")
        pip:SetVertexColor(pipColour.r, pipColour.g, pipColour.b, 1.0)
        pip:SetPoint("LEFT", box, "RIGHT", 4, 0)
        labelAnchor = pip
        labelOffset = 5
    end

    local text = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    text:SetPoint("LEFT", labelAnchor, "RIGHT", labelOffset, 0)
    text:SetText(label)
    if labelColour then
        text:SetTextColor(labelColour.r, labelColour.g, labelColour.b)
    end

    local count = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    if inScroll then
        count:SetPoint("RIGHT", parent, "RIGHT", -4, 0)
        count:SetPoint("TOP", box, "TOP", 0, -3)
    else
        count:SetPoint("RIGHT", self.sidebar, "RIGHT", -PAD_X, 0)
        count:SetPoint("TOP", box, "TOP", 0, -3)
    end
    count:SetTextColor(COUNT_COL.r, COUNT_COL.g, COUNT_COL.b)

    box:SetScript("OnClick", function(self_)
        local db = ns.Epithet.db.profile
        if not db.filters[facet] then db.filters[facet] = {} end
        local facetTable = db.filters[facet]
        if self_:GetChecked() then
            facetTable[key] = true
        else
            facetTable[key] = nil
        end
        ns.MainFrame:RefreshList()
    end)

    local entry = { box = box, count = count, facet = facet, key = key }
    self.checkboxes[#self.checkboxes + 1] = entry
    return entry
end

-- ---------------------------------------------------------------------------
-- Refresh (sync checked state + counts)
-- ---------------------------------------------------------------------------
function Sidebar:Refresh()
    if not self.sidebar then return end

    local db = ns.Epithet.db.profile
    local counts = ns.Filters:ComputeCounts(ns.TitleData.records or {})

    self:UpdateStatusButtons()

    for _, entry in ipairs(self.checkboxes) do
        local facetTable = db.filters[entry.facet] or {}
        entry.box:SetChecked(facetTable[entry.key] and true or false)

        local n = 0
        if entry.facet == "rarity" then
            n = counts.rarity[entry.key] or 0
        elseif entry.facet == "type" then
            n = counts.type[entry.key] or 0
        elseif entry.facet == "exp" then
            n = counts.exp[entry.key] or 0
        elseif entry.facet == "cat" then
            n = counts.cat[entry.key] or 0
        elseif entry.facet == "kind" then
            n = counts.kind[entry.key] or 0
        elseif entry.facet == "faction" then
            n = counts.faction[entry.key] or 0
        end
        entry.count:SetText(tostring(n))
    end

    -- Sync availability hide toggles
    if self.hideUnobtBox then
        self.hideUnobtBox:SetChecked(db.filters.hideUnobtainable or false)
    end
    if self.hideTimeSensBox then
        self.hideTimeSensBox:SetChecked(db.filters.hideTimeSensitive or false)
    end
end
