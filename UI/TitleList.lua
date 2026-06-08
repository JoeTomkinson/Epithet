-- =============================================================================
-- Epithet — Title List (centre column)
-- Virtualised ScrollBox list of title rows + group headers.
-- =============================================================================
local _, ns = ...
local L = ns.L
local T = ns.Theme

-- Localize Lua stdlib
local pairs, ipairs = pairs, ipairs
local tconcat = table.concat

local TitleList = {}
ns.TitleList = TitleList

local CHECK_ICON = "Interface\\AddOns\\Epithet\\icons\\ui\\epithet-ui-check-32"
local LOCK_ICON  = "Interface\\AddOns\\Epithet\\icons\\ui\\epithet-ui-lock-32"

-- Unobtainability overlay icons (16px, shown as badge on the row)
local UNOBTAIN_SEALED    = "Interface\\AddOns\\Epithet\\icons\\ui\\epithet-ui-unobtainable-sealed-16"
local UNOBTAIN_HOURGLASS = "Interface\\AddOns\\Epithet\\icons\\ui\\epithet-ui-unobtainable-hourglass-16"

-- Faction overlay icons (32px, downscaled to 20px for clean rendering on rarity gem)
local FACTION_ALLIANCE = "Interface\\AddOns\\Epithet\\icons\\ui\\epithet-faction-alliance-32"
local FACTION_HORDE    = "Interface\\AddOns\\Epithet\\icons\\ui\\epithet-faction-horde-32"

local RARITY_GEMS = {
    "Interface\\AddOns\\Epithet\\icons\\rarity\\epithet-rarity-1-common-64",
    "Interface\\AddOns\\Epithet\\icons\\rarity\\epithet-rarity-2-uncommon-64",
    "Interface\\AddOns\\Epithet\\icons\\rarity\\epithet-rarity-3-rare-64",
    "Interface\\AddOns\\Epithet\\icons\\rarity\\epithet-rarity-4-epic-64",
    "Interface\\AddOns\\Epithet\\icons\\rarity\\epithet-rarity-5-legendary-64",
}

local ROW_HEIGHT    = 64
local HEADER_HEIGHT = 28

-- ---------------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------------
function TitleList:Init(container)
    if self.container then return end
    self.container = container
    self.scrollBox = container.ScrollBox
    self.scrollBar = container.ScrollBar
    self.header    = container.ListHeader

    self:InitHeader()
    self:InitScrollBox()
end

-- ---------------------------------------------------------------------------
-- List header (count + sort button)
-- ---------------------------------------------------------------------------
function TitleList:InitHeader()
    local header = self.header
    if not header then return end

    header.SortButton:SetScript("OnClick", function()
        self:ToggleSort()
    end)

    -- Add sort icon to button
    if not header.SortButton.icon then
        local icon = header.SortButton:CreateTexture(nil, "ARTWORK")
        icon:SetTexture("Interface\\AddOns\\Epithet\\icons\\ui\\epithet-ui-sort-16")
        icon:SetSize(12, 12)
        icon:SetPoint("LEFT", header.SortButton, "LEFT", 4, 0)
        icon:SetVertexColor(0.73, 0.57, 0.25)
        header.SortButton.icon = icon
    end

    self:UpdateHeaderText(0)
end

function TitleList:UpdateHeaderText(count)
    local header = self.header
    if not header then return end

    header.Count:SetText(string.format(L["N_TITLES"], count or 0))

    local sortMode = ns.Epithet.db.profile.sort
    local label
    if sortMode == "expansion" then
        label = L["SORT_BY_EXPANSION"]
    elseif sortMode == "alphabetical" then
        label = L["SORT_ALPHABETICAL"]
    elseif sortMode == "quality" then
        label = L["SORT_BY_QUALITY"]
    elseif sortMode == "category" then
        label = L["SORT_BY_CATEGORY"]
    else
        label = L["SORT_COLLECTED_FIRST"]
    end
    header.SortButton:SetText(label)
end

local SORT_CYCLE = { "collectedFirst", "expansion", "alphabetical", "quality", "category" }

function TitleList:ToggleSort()
    local db = ns.Epithet.db.profile
    local current = db.sort or "collectedFirst"
    local nextIdx = 1
    for i, mode in ipairs(SORT_CYCLE) do
        if mode == current then
            nextIdx = (i % #SORT_CYCLE) + 1
            break
        end
    end
    db.sort = SORT_CYCLE[nextIdx]
    self:Refresh()
end

-- ---------------------------------------------------------------------------
-- ScrollBox setup
-- ---------------------------------------------------------------------------
function TitleList:InitScrollBox()
    local view = CreateScrollBoxListLinearView()

    view:SetElementExtentCalculator(function(_, elementData)
        if elementData.isHeader then
            return HEADER_HEIGHT
        end
        return ROW_HEIGHT
    end)

    view:SetElementFactory(function(factory, elementData)
        if elementData.isHeader then
            factory("EpithetGroupHeaderTemplate", function(frame, data)
                TitleList:InitGroupHeader(frame, data)
            end)
        else
            factory("EpithetTitleRowTemplate", function(frame, data)
                TitleList:InitTitleRow(frame, data)
            end)
        end
    end)

    ScrollUtil.InitScrollBoxListWithScrollBar(self.scrollBox, self.scrollBar, view)
    self.scrollView = view
end

-- ---------------------------------------------------------------------------
-- Refresh (apply filters, rebuild data provider)
-- ---------------------------------------------------------------------------
function TitleList:Refresh()
    if not self.scrollBox then return end

    local db = ns.Epithet.db.profile
    local records = ns.TitleData.records or {}
    local filtered = ns.Filters:Apply(records, db.filters)
    local display = ns.Filters:BuildDisplayList(filtered, db.sort)

    self:UpdateHeaderText(#filtered)

    local dataProvider = CreateDataProvider(display)
    self.scrollBox:SetDataProvider(dataProvider, ScrollBoxConstants.RetainScrollPosition)
end

-- ---------------------------------------------------------------------------
-- Title row initialiser (called each time a row is acquired/recycled)
-- ---------------------------------------------------------------------------
function TitleList:InitTitleRow(row, record)
    row.record = record

    -- Create chip background textures on first use
    if not row.ActiveChipBG then
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetColorTexture(0.91, 0.78, 0.45, 1.0)
        bg:SetPoint("TOPLEFT", row.ActiveChip, "TOPLEFT", -7, 3)
        bg:SetPoint("BOTTOMRIGHT", row.ActiveChip, "BOTTOMRIGHT", 7, -3)
        bg:Hide()
        row.ActiveChipBG = bg
    end
    if not row.TypeTagBG then
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetColorTexture(0.0, 0.0, 0.0, 0.2)
        bg:SetPoint("TOPLEFT", row.TypeTag, "TOPLEFT", -6, 2)
        bg:SetPoint("BOTTOMRIGHT", row.TypeTag, "BOTTOMRIGHT", 4, -2)
        row.TypeTagBG = bg
    end
    if not row.TypeTagBorder then
        local border = row:CreateTexture(nil, "BACKGROUND")
        border:SetColorTexture(0.72, 0.60, 0.36, 0.22)
        border:SetPoint("TOPLEFT", row.TypeTag, "TOPLEFT", -7, 3)
        border:SetPoint("BOTTOMRIGHT", row.TypeTag, "BOTTOMRIGHT", 5, -3)
        row.TypeTagBorder = border
    end

    local quality = record.q and ns.QUALITY_COLOURS[record.q]
    local tq = T and T.quality and T.quality[record.q]
    local playerName = ns.TitleData.playerName or UnitName("player") or "Player"

    -- Rarity gem (full row height, tinted by rarity colour)
    local gemTex = RARITY_GEMS[record.q or 1] or RARITY_GEMS[1]
    row.Pip:SetTexture(gemTex)
    local pipColour = (tq and tq.pip) or (quality and quality.pip) or { r = 0.36, g = 0.33, b = 0.26 }
    if record.earned then
        row.Pip:SetVertexColor(pipColour.r, pipColour.g, pipColour.b, 1.0)
    else
        local lc = T and T.col.locked or pipColour
        row.Pip:SetVertexColor(lc.r, lc.g, lc.b, 0.9)
    end
    row.Pip:Show()

    -- Faction badge (20px icon overlaid bottom-right of rarity gem, tinted faction colour)
    if not row.FactionBadge then
        local badge = row:CreateTexture(nil, "OVERLAY")
        badge:SetSize(20, 20)
        badge:SetPoint("BOTTOMRIGHT", row.Pip, "BOTTOMRIGHT", 4, -4)
        row.FactionBadge = badge
    end
    local faction = record.faction
    if faction == "Alliance" then
        row.FactionBadge:SetTexture(FACTION_ALLIANCE)
        row.FactionBadge:SetVertexColor(0.30, 0.55, 1.0, 1.0)
        row.FactionBadge:Show()
    elseif faction == "Horde" then
        row.FactionBadge:SetTexture(FACTION_HORDE)
        row.FactionBadge:SetVertexColor(0.90, 0.20, 0.20, 1.0)
        row.FactionBadge:Show()
    else
        row.FactionBadge:Hide()
    end

    -- Row 1: Title with player name in context
    if T and tq then
        local col = T.col
        local titleHex = record.earned and tq.text.hex or col.locked.hex
        local nameHex  = record.earned and col.muted.hex or col.locked.hex
        local title    = T.Wrap(titleHex, record.text)
        local name     = T.Wrap(nameHex, playerName)
        if record.type == "suffix" then
            row.TitleText:SetText(name .. ", " .. title)
        else
            row.TitleText:SetText(title .. " " .. name)
        end
        row.TitleText:SetTextColor(1, 1, 1)
    else
        local contextText = ns.TitleData:RenderTitleInContext(record, playerName)
        row.TitleText:SetText(contextText)
        if record.earned then
            local c = quality and quality.text or { r = 0.95, g = 0.93, b = 0.89 }
            row.TitleText:SetTextColor(c.r, c.g, c.b)
        else
            row.TitleText:SetTextColor(0.50, 0.46, 0.36)
        end
    end

    -- Row 2: "Kind: Source" (e.g. "Achievement: Glory of the Raider")
    local kindStr = record.kind or record.cat or ""
    local srcStr  = record.achievement or record.quest or record.source_item or ""
    if kindStr ~= "" and srcStr ~= "" then
        row.SourceText:SetText(kindStr .. ": " .. srcStr)
    elseif srcStr ~= "" then
        row.SourceText:SetText(srcStr)
    elseif kindStr ~= "" then
        row.SourceText:SetText(kindStr)
    else
        row.SourceText:SetText(L["UNKNOWN_SOURCE"] or "Unknown source")
    end

    -- Row 3: Expansion · Category (small muted label)
    if not row.MetaText then
        local meta = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        meta:SetPoint("TOPLEFT", row.SourceText, "BOTTOMLEFT", 0, -2)
        meta:SetPoint("RIGHT", row.TypeTag, "LEFT", -8, 0)
        meta:SetJustifyH("LEFT")
        row.MetaText = meta
    end
    local metaParts = {}
    if record.exp then
        metaParts[#metaParts + 1] = ns.EXPANSION_LABELS[record.exp] or record.exp
    end
    if record.cat then
        metaParts[#metaParts + 1] = record.cat
    end
    if #metaParts > 0 then
        row.MetaText:SetText(tconcat(metaParts, " \194\183 "))
        row.MetaText:Show()
    else
        row.MetaText:SetText("")
        row.MetaText:Hide()
    end

    -- Right column 3: State mark (lock/tick, 32x32 from 64px asset)
    if record.earned then
        row.StateMark:SetTexture(CHECK_ICON)
        if T then
            row.StateMark:SetVertexColor(T.col.gold.r, T.col.gold.g, T.col.gold.b)
        else
            row.StateMark:SetVertexColor(0.91, 0.78, 0.45)
        end
    else
        row.StateMark:SetTexture(LOCK_ICON)
        if T then
            row.StateMark:SetVertexColor(T.col.locked.r, T.col.locked.g, T.col.locked.b)
        else
            row.StateMark:SetVertexColor(0.36, 0.33, 0.26)
        end
    end

    -- Obtainability badge (small 14px icon overlaid bottom-right of state mark)
    if not row.ObtainBadge then
        local badge = row:CreateTexture(nil, "OVERLAY")
        badge:SetSize(14, 14)
        badge:SetPoint("BOTTOMRIGHT", row.StateMark, "BOTTOMRIGHT", 4, -4)
        row.ObtainBadge = badge
    end
    local obt = record.obtainable
    if obt == "no" then
        row.ObtainBadge:SetTexture(UNOBTAIN_SEALED)
        row.ObtainBadge:SetVertexColor(0.85, 0.35, 0.30, 1.0)
        row.ObtainBadge:Show()
    elseif obt == "feat" then
        row.ObtainBadge:SetTexture(UNOBTAIN_HOURGLASS)
        row.ObtainBadge:SetVertexColor(0.90, 0.70, 0.25, 1.0)
        row.ObtainBadge:Show()
    else
        row.ObtainBadge:Hide()
    end

    -- Right column 2: Type tag pill (PREFIX / SUFFIX)
    if record.type == "prefix" then
        row.TypeTag:SetText("PREFIX")
        row.TypeTag:SetTextColor(0.61, 0.55, 0.42)
        row.TypeTagBG:Show()
        row.TypeTagBorder:Show()
    elseif record.type == "suffix" then
        row.TypeTag:SetText("SUFFIX")
        row.TypeTag:SetTextColor(0.61, 0.55, 0.42)
        row.TypeTagBG:Show()
        row.TypeTagBorder:Show()
    else
        row.TypeTag:SetText("")
        row.TypeTagBG:Hide()
        row.TypeTagBorder:Hide()
    end

    -- Right column 1: Active title pill
    if record.isActive then
        row.ActiveChip:Show()
        row.ActiveChipBG:Show()
        row.ActiveBar:Show()
    else
        row.ActiveChip:Hide()
        row.ActiveChipBG:Hide()
        row.ActiveBar:Hide()
    end

    -- Selection highlight (fill + border)
    if record == self.selectedRecord then
        row.Selected:Show()
        row.SelBorderTop:Show()
        row.SelBorderBottom:Show()
        row.SelBorderLeft:Show()
        row.SelBorderRight:Show()
    else
        row.Selected:Hide()
        row.SelBorderTop:Hide()
        row.SelBorderBottom:Hide()
        row.SelBorderLeft:Hide()
        row.SelBorderRight:Hide()
    end
    row.Highlight:Hide()

    -- Handlers
    row.OnRowEnter = function(self_)
        ns.MainFrame:SetHover(record)
    end
    row.OnRowLeave = function(self_)
        ns.MainFrame:ClearHover()
    end
    row.OnRowClick = function(self_)
        TitleList:SetSelection(record)
    end
end

-- ---------------------------------------------------------------------------
-- Group header initialiser
-- ---------------------------------------------------------------------------
function TitleList:InitGroupHeader(header, data)
    header.Label:SetText(string.format("%s \194\183 %d", data.label or "", data.count or 0))
    header.Count:SetText("")
end

-- ---------------------------------------------------------------------------
-- Selection
-- ---------------------------------------------------------------------------
function TitleList:SetSelection(record)
    self.selectedRecord = record
    ns.MainFrame:SetSelection(record)
    self:RefreshSelectionVisuals()
end

function TitleList:RefreshSelectionVisuals()
    if not self.scrollBox then return end
    self.scrollBox:ForEachFrame(function(frame)
        if frame.record then
            if frame.record == self.selectedRecord then
                frame.Selected:Show()
                frame.SelBorderTop:Show()
                frame.SelBorderBottom:Show()
                frame.SelBorderLeft:Show()
                frame.SelBorderRight:Show()
            else
                frame.Selected:Hide()
                frame.SelBorderTop:Hide()
                frame.SelBorderBottom:Hide()
                frame.SelBorderLeft:Hide()
                frame.SelBorderRight:Hide()
            end
        end
    end)
end

function TitleList:SelectFirst()
    local dp = self.scrollBox and self.scrollBox:GetDataProvider()
    if not dp then return end
    for _, elementData in dp:Enumerate() do
        if not elementData.isHeader then
            self:SetSelection(elementData)
            return
        end
    end
end
