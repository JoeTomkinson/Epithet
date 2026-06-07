-- =============================================================================
-- Epithet — Detail Panel (right column)
-- Preview, rarity card (fixed height), source card (fills), action footer.
-- =============================================================================
local _, ns = ...
local L = ns.L
local T = ns.Theme

-- Localize WoW APIs & Lua stdlib
local UnitName = UnitName
local format   = string.format
local tconcat  = table.concat
local wipe     = wipe

local Detail = {}
ns.Detail = Detail

local RARITY_GEMS = {
    "Interface\\AddOns\\Epithet\\icons\\rarity\\epithet-rarity-1-common-32",
    "Interface\\AddOns\\Epithet\\icons\\rarity\\epithet-rarity-2-uncommon-32",
    "Interface\\AddOns\\Epithet\\icons\\rarity\\epithet-rarity-3-rare-32",
    "Interface\\AddOns\\Epithet\\icons\\rarity\\epithet-rarity-4-epic-32",
    "Interface\\AddOns\\Epithet\\icons\\rarity\\epithet-rarity-5-legendary-32",
}

local DOT  = "\194\183"        -- middle dot ·
local STAR = "\226\152\133"    -- star ★

local col  = T and T.col or {}
local GOLD     = col.gold    or { r = 0.91, g = 0.78, b = 0.45 }
local GOLD_DIM = col.goldDim or { r = 0.73, g = 0.57, b = 0.25 }
local MUTED    = col.muted   or { r = 0.61, g = 0.55, b = 0.42 }

local INSET = 16

-- Scratch tables (reused per Refresh to avoid allocation)
local scratchParts = {}

-- Unobtainability icons (16px for detail panel banner)
local UNOBTAIN_SEALED_16    = "Interface\\AddOns\\Epithet\\icons\\ui\\epithet-ui-unobtainable-sealed-16"
local UNOBTAIN_HOURGLASS_16 = "Interface\\AddOns\\Epithet\\icons\\ui\\epithet-ui-unobtainable-hourglass-16"

-- Faction icons (64px for detail panel — sharper at display size)
local FACTION_ALLIANCE_64 = "Interface\\AddOns\\Epithet\\icons\\ui\\epithet-faction-alliance-64"
local FACTION_HORDE_64    = "Interface\\AddOns\\Epithet\\icons\\ui\\epithet-faction-horde-64"

-- Single-letter / glyph sigil per source kind (fallback if texture missing)
local SIGIL_LETTERS = {
    ["Achievement"]      = "A",
    ["Quest"]            = "Q",
    ["Reputation"]       = "R",
    ["PvP Rank"]         = "P",
    ["Feat of Strength"] = STAR,
    ["Item"]             = "I",
    ["Promotion"]        = "G",
}

-- Category icon textures keyed by source kind
local SIGIL_ICONS = {
    ["Achievement"]      = "Interface\\AddOns\\Epithet\\icons\\category\\epithet-cat-achievement-32",
    ["Quest"]            = "Interface\\AddOns\\Epithet\\icons\\category\\epithet-cat-quest-32",
    ["Reputation"]       = "Interface\\AddOns\\Epithet\\icons\\category\\epithet-cat-reputation-32",
    ["PvP Rank"]         = "Interface\\AddOns\\Epithet\\icons\\category\\epithet-cat-pvp-32",
    ["Feat of Strength"] = "Interface\\AddOns\\Epithet\\icons\\category\\epithet-cat-feat-32",
    ["Raid"]             = "Interface\\AddOns\\Epithet\\icons\\category\\epithet-cat-raid-32",
    ["Dungeon"]          = "Interface\\AddOns\\Epithet\\icons\\category\\epithet-cat-dungeon-32",
    ["Exploration"]      = "Interface\\AddOns\\Epithet\\icons\\category\\epithet-cat-exploration-32",
    ["Holiday"]          = "Interface\\AddOns\\Epithet\\icons\\category\\epithet-cat-holiday-32",
    ["Profession"]       = "Interface\\AddOns\\Epithet\\icons\\category\\epithet-cat-profession-32",
    ["Campaign"]         = "Interface\\AddOns\\Epithet\\icons\\category\\epithet-cat-campaign-32",
    ["Outdoor"]          = "Interface\\AddOns\\Epithet\\icons\\category\\epithet-cat-outdoor-32",
}

-- ---------------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------------
function Detail:Init(panel)
    if self.panel then return end
    self.panel = panel

    -- Preview banner
    local banner = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    banner:SetPoint("TOPLEFT", INSET, -16)
    banner:SetTextColor(GOLD_DIM.r, GOLD_DIM.g, GOLD_DIM.b)
    self.previewBanner = banner

    -- Title (big)
    local title = panel:CreateFontString(nil, "ARTWORK", "QuestFont_Huge")
    title:SetPoint("TOPLEFT", banner, "BOTTOMLEFT", 0, -6)
    title:SetPoint("RIGHT", panel, "RIGHT", -INSET, 0)
    title:SetJustifyH("LEFT")
    title:SetTextColor(GOLD.r, GOLD.g, GOLD.b)
    self.titleText = title

    -- Sub-line (type · expansion · rarity)
    local subLine = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    subLine:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subLine:SetPoint("RIGHT", panel, "RIGHT", -INSET, 0)
    subLine:SetJustifyH("LEFT")
    subLine:SetTextColor(MUTED.r, MUTED.g, MUTED.b)
    self.subLine = subLine

    -- Rarity card (fixed height)
    self:InitRarityCard()

    -- Action footer (bottom)
    self:InitActionFooter()

    -- Source card (fills between rarity card and footer)
    self:InitSourceCard()

    -- Empty state
    local empty = panel:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    empty:SetPoint("TOPLEFT", INSET, -120)
    empty:SetPoint("RIGHT", panel, "RIGHT", -INSET, 0)
    empty:SetJustifyH("CENTER")
    empty:SetText(L["NO_SELECTION"])
    empty:Hide()
    self.emptyState = empty
end

-- ---------------------------------------------------------------------------
-- Rarity card
-- ---------------------------------------------------------------------------
function Detail:InitRarityCard()
    local panel = self.panel
    local card = CreateFrame("Frame", nil, panel, "InsetFrameTemplate3")
    card:SetPoint("TOPLEFT", self.subLine, "BOTTOMLEFT", 0, -12)
    card:SetPoint("RIGHT", panel, "RIGHT", -INSET, 0)
    card:SetHeight(170)
    self.rarityCard = card

    -- Gem (16x16 rarity gem icon before quality name)
    local gem = card:CreateTexture(nil, "ARTWORK")
    gem:SetSize(16, 16)
    gem:SetPoint("TOPLEFT", 12, -12)
    self.rarityGem = gem

    local label = card:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("LEFT", gem, "RIGHT", 11, 0)
    self.qualityLabel = label

    -- Faction icon (24px, shown right of quality label for faction-specific titles)
    local factionIcon = card:CreateTexture(nil, "ARTWORK")
    factionIcon:SetSize(24, 24)
    factionIcon:SetPoint("LEFT", label, "RIGHT", 8, 0)
    factionIcon:Hide()
    self.factionIcon = factionIcon

    -- Tier segments (5 bars)
    self.tierSegments = {}
    local segW, segGap = 56, 6
    for i = 1, 5 do
        local seg = card:CreateTexture(nil, "ARTWORK")
        seg:SetSize(segW, 6)
        seg:SetPoint("TOPLEFT", gem, "BOTTOMLEFT", (i - 1) * (segW + segGap), -10)
        self.tierSegments[i] = seg
    end

    local pct = card:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    pct:SetPoint("TOPLEFT", self.tierSegments[1], "BOTTOMLEFT", 0, -10)
    pct:SetPoint("RIGHT", card, "RIGHT", -12, 0)
    pct:SetJustifyH("LEFT")
    self.rarityPct = pct

    local note = card:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", pct, "BOTTOMLEFT", 0, -8)
    note:SetPoint("RIGHT", card, "RIGHT", -12, 0)
    note:SetJustifyH("LEFT")
    note:SetTextColor(MUTED.r, MUTED.g, MUTED.b)
    self.rarityNote = note
end

-- ---------------------------------------------------------------------------
-- Source card (fills available space)
-- ---------------------------------------------------------------------------
function Detail:InitSourceCard()
    local panel = self.panel
    local card = CreateFrame("Frame", nil, panel, "InsetFrameTemplate3")
    card:SetPoint("TOPLEFT", self.rarityCard, "BOTTOMLEFT", 0, -12)
    card:SetPoint("RIGHT", panel, "RIGHT", -INSET, 0)
    card:SetPoint("BOTTOM", self.actionButton, "TOP", 0, 12)
    self.sourceCard = card

    local heading = card:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    heading:SetPoint("TOPLEFT", 12, -12)
    heading:SetText(L["HOW_TO_OBTAIN"])
    heading:SetTextColor(GOLD_DIM.r, GOLD_DIM.g, GOLD_DIM.b)
    self.sourceHeading = heading

    -- Sigil chip
    local sigilBG = card:CreateTexture(nil, "ARTWORK")
    sigilBG:SetSize(34, 34)
    sigilBG:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -10)
    sigilBG:SetColorTexture(0.12, 0.10, 0.06, 0.8)
    self.sigilBG = sigilBG

    local sigil = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    sigil:SetPoint("CENTER", sigilBG, "CENTER")
    sigil:SetTextColor(GOLD.r, GOLD.g, GOLD.b)
    self.sigil = sigil

    -- Category icon overlay (preferred over letter when available)
    local sigilIcon = card:CreateTexture(nil, "OVERLAY")
    sigilIcon:SetSize(24, 24)
    sigilIcon:SetPoint("CENTER", sigilBG, "CENTER")
    sigilIcon:SetVertexColor(GOLD.r, GOLD.g, GOLD.b)
    sigilIcon:Hide()
    self.sigilIcon = sigilIcon

    local kindLabel = card:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    kindLabel:SetPoint("TOPLEFT", sigilBG, "TOPRIGHT", 10, -2)
    kindLabel:SetPoint("RIGHT", card, "RIGHT", -12, 0)
    kindLabel:SetJustifyH("LEFT")
    self.kindLabel = kindLabel

    local sourceLink = CreateFrame("Button", nil, card)
    sourceLink:SetPoint("TOPLEFT", kindLabel, "BOTTOMLEFT", 0, -2)
    sourceLink:SetPoint("RIGHT", card, "RIGHT", -12, 0)
    sourceLink:SetHeight(16)
    local linkText = sourceLink:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    linkText:SetPoint("LEFT")
    linkText:SetPoint("RIGHT")
    linkText:SetJustifyH("LEFT")
    linkText:SetTextColor(GOLD.r, GOLD.g, GOLD.b)
    sourceLink.text = linkText
    sourceLink:SetScript("OnEnter", function() linkText:SetTextColor(1, 0.92, 0.6) end)
    sourceLink:SetScript("OnLeave", function() linkText:SetTextColor(GOLD.r, GOLD.g, GOLD.b) end)
    sourceLink:SetScript("OnClick", function() self:OnSourceLinkClick() end)
    self.sourceLink = sourceLink

    local desc = card:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", sigilBG, "BOTTOMLEFT", 0, -12)
    desc:SetPoint("RIGHT", card, "RIGHT", -12, 0)
    desc:SetJustifyH("LEFT")
    desc:SetTextColor(0.78, 0.74, 0.66)
    desc:SetSpacing(2)
    self.descText = desc

    -- Obtainability banner (icon + label, shown only for unobtainable/feat titles)
    local obtainRow = CreateFrame("Frame", nil, card)
    obtainRow:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -10)
    obtainRow:SetPoint("RIGHT", card, "RIGHT", -12, 0)
    obtainRow:SetHeight(20)
    obtainRow:Hide()
    self.obtainRow = obtainRow

    local obtainIcon = obtainRow:CreateTexture(nil, "ARTWORK")
    obtainIcon:SetSize(16, 16)
    obtainIcon:SetPoint("LEFT", 0, 0)
    self.obtainIcon = obtainIcon

    local obtainLabel = obtainRow:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    obtainLabel:SetPoint("LEFT", obtainIcon, "RIGHT", 6, 0)
    obtainLabel:SetPoint("RIGHT", obtainRow, "RIGHT", 0, 0)
    obtainLabel:SetJustifyH("LEFT")
    self.obtainLabel = obtainLabel

    local obtainReason = card:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    obtainReason:SetPoint("TOPLEFT", obtainRow, "BOTTOMLEFT", 22, -4)
    obtainReason:SetPoint("RIGHT", card, "RIGHT", -12, 0)
    obtainReason:SetJustifyH("LEFT")
    obtainReason:SetTextColor(0.58, 0.52, 0.42)
    obtainReason:SetSpacing(2)
    obtainReason:Hide()
    self.obtainReason = obtainReason

    local meta = card:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    meta:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 12, 12)
    meta:SetPoint("RIGHT", card, "RIGHT", -12, 0)
    meta:SetJustifyH("LEFT")
    self.metaText = meta
end

-- ---------------------------------------------------------------------------
-- Action footer
-- ---------------------------------------------------------------------------
function Detail:InitActionFooter()
    local panel = self.panel

    local note = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    note:SetPoint("BOTTOMLEFT", INSET, 16)
    note:SetPoint("RIGHT", panel, "RIGHT", -INSET, 0)
    note:SetJustifyH("CENTER")
    note:SetTextColor(0.42, 0.38, 0.29)
    self.actionNote = note

    -- Custom gold-bordered dark button
    local button = CreateFrame("Button", nil, panel)
    button:SetHeight(34)
    button:SetPoint("BOTTOMLEFT", note, "TOPLEFT", 0, 9)
    button:SetPoint("RIGHT", panel, "RIGHT", -INSET, 0)

    -- Background (dark gradient approximation)
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.11, 0.08, 0.04, 1.0)
    button.bg = bg

    -- Border (4 edges, gold-deep)
    local borderTop = button:CreateTexture(nil, "BORDER")
    borderTop:SetHeight(1)
    borderTop:SetPoint("TOPLEFT")
    borderTop:SetPoint("TOPRIGHT")
    borderTop:SetColorTexture(0.49, 0.37, 0.15, 1.0)
    local borderBot = button:CreateTexture(nil, "BORDER")
    borderBot:SetHeight(1)
    borderBot:SetPoint("BOTTOMLEFT")
    borderBot:SetPoint("BOTTOMRIGHT")
    borderBot:SetColorTexture(0.49, 0.37, 0.15, 1.0)
    local borderL = button:CreateTexture(nil, "BORDER")
    borderL:SetWidth(1)
    borderL:SetPoint("TOPLEFT")
    borderL:SetPoint("BOTTOMLEFT")
    borderL:SetColorTexture(0.49, 0.37, 0.15, 1.0)
    local borderR = button:CreateTexture(nil, "BORDER")
    borderR:SetWidth(1)
    borderR:SetPoint("TOPRIGHT")
    borderR:SetPoint("BOTTOMRIGHT")
    borderR:SetColorTexture(0.49, 0.37, 0.15, 1.0)
    button.borders = { borderTop, borderBot, borderL, borderR }

    -- Text
    local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER", 8, 0)
    text:SetTextColor(GOLD.r, GOLD.g, GOLD.b)
    button.text = text

    -- Banner mark icon (shown when title is active)
    local tick = button:CreateTexture(nil, "OVERLAY")
    tick:SetSize(34, 34)
    tick:SetPoint("RIGHT", text, "LEFT", -4, 0)
    tick:SetTexture("Interface\\AddOns\\Epithet\\icons\\logo\\epithet-banner-mark-64")
    tick:Hide()
    button.tick = tick

    -- Hover effects
    button:SetScript("OnEnter", function(self_)
        if self_:IsEnabled() then
            self_.bg:SetColorTexture(0.16, 0.12, 0.07, 1.0)
            self_.text:SetTextColor(0.96, 0.89, 0.65)
            for _, b in ipairs(self_.borders) do
                b:SetColorTexture(0.91, 0.78, 0.45, 1.0)
            end
        end
    end)
    button:SetScript("OnLeave", function(self_)
        if self_:IsEnabled() then
            self_.bg:SetColorTexture(0.11, 0.08, 0.04, 1.0)
            self_.text:SetTextColor(GOLD.r, GOLD.g, GOLD.b)
            for _, b in ipairs(self_.borders) do
                b:SetColorTexture(0.49, 0.37, 0.15, 1.0)
            end
        end
    end)
    button:SetScript("OnClick", function() self:OnActionClick() end)

    -- Custom SetText / Enable / Disable
    function button:SetText(t) self.text:SetText(t) end
    function button:SetEnabled(e)
        if e then self:Enable() else self:Disable() end
    end

    self.actionButton = button
end

-- ---------------------------------------------------------------------------
-- Refresh
-- ---------------------------------------------------------------------------
function Detail:Refresh()
    if not self.panel then return end

    local record = ns.MainFrame:GetDetailRecord()
    if not record then
        self:ShowEmpty()
        return
    end
    self:HideEmpty()

    local isHover = (ns.MainFrame.hoveredRecord ~= nil)
    self.previewBanner:SetText(isHover and L["PREVIEW_HOVERING"] or "")

    -- Title in context (colour-wrapped per design spec)
    local name = ns.TitleData.playerName or UnitName("player") or "Player"
    if T and T.quality[record.q] then
        local tq = T.quality[record.q]
        local titleHex = record.earned and tq.text.hex or col.locked.hex
        local nameHex  = record.earned and col.muted.hex or col.locked.hex
        local titleStr = T.Wrap(titleHex, record.text)
        local nameStr  = T.Wrap(nameHex, name)
        if record.type == "suffix" then
            self.titleText:SetText(nameStr .. ", " .. titleStr)
        else
            self.titleText:SetText(titleStr .. " " .. nameStr)
        end
    else
        self.titleText:SetText(ns.TitleData:RenderTitleInContext(record, name))
    end

    -- Sub-line
    wipe(scratchParts)
    scratchParts[#scratchParts + 1] = (record.type == "prefix") and L["PREFIX_TITLE"] or L["SUFFIX_TITLE"]
    if record.exp then
        scratchParts[#scratchParts + 1] = ns.EXPANSION_LABELS[record.exp] or record.exp
    end
    if record.q then
        scratchParts[#scratchParts + 1] = ns.QUALITY_NAMES[record.q]
    end
    self.subLine:SetText(tconcat(scratchParts, " " .. DOT .. " "))

    self:RefreshRarityCard(record)
    self:RefreshSourceCard(record)
    self:RefreshActionButton(record)
end

function Detail:RefreshRarityCard(record)
    local q = record.q or 0
    local tq = T and T.quality[q]
    self.qualityLabel:SetText(q > 0 and (tq and tq.label or ns.QUALITY_NAMES[q]) or "Unranked")
    if q > 0 then
        local c = tq and tq.text or ns.QUALITY_COLOURS[q].text
        self.qualityLabel:SetTextColor(c.r, c.g, c.b)
        local p = tq and tq.pip or ns.QUALITY_COLOURS[q].pip
        self.rarityGem:SetTexture(RARITY_GEMS[q] or RARITY_GEMS[1])
        self.rarityGem:SetVertexColor(p.r, p.g, p.b, 1.0)
        self.rarityGem:Show()
    else
        self.qualityLabel:SetTextColor(MUTED.r, MUTED.g, MUTED.b)
        self.rarityGem:Hide()
    end

    for i = 1, 5 do
        local seg = self.tierSegments[i]
        if i <= q then
            local tqi = T and T.quality[i]
            local c = tqi and tqi.pip or ns.QUALITY_COLOURS[q].pip
            seg:SetColorTexture(c.r, c.g, c.b, 1.0)
        else
            seg:SetColorTexture(0.30, 0.27, 0.21, 0.6)
        end
    end

    if record.rarity then
        if T then
            self.rarityPct:SetText(
                "Held by an estimated " .. T.Wrap(T.col.goldBright.hex, tostring(record.rarity)) .. "% of active characters."
            )
        else
            self.rarityPct:SetText(format(L["HELD_BY_ESTIMATE"], tostring(record.rarity)))
        end
    else
        self.rarityPct:SetText("")
    end

    self.rarityNote:SetText((ns.EpithetData and ns.EpithetData.rarityNote) or L["RARITY_NOTE"])

    -- Faction icon
    local faction = record.faction
    if faction == "Alliance" then
        self.factionIcon:SetTexture(FACTION_ALLIANCE_64)
        self.factionIcon:SetVertexColor(0.30, 0.55, 1.0, 1.0)
        self.factionIcon:Show()
    elseif faction == "Horde" then
        self.factionIcon:SetTexture(FACTION_HORDE_64)
        self.factionIcon:SetVertexColor(0.90, 0.20, 0.20, 1.0)
        self.factionIcon:Show()
    else
        self.factionIcon:Hide()
    end
end

function Detail:RefreshSourceCard(record)
    local kind = record.kind or L["KIND_ACHIEVEMENT"]
    local cat  = record.cat or kind

    -- Prefer category icon; fall back to letter sigil
    local iconPath = SIGIL_ICONS[cat] or SIGIL_ICONS[kind]
    if iconPath then
        self.sigilIcon:SetTexture(iconPath)
        self.sigilIcon:Show()
        self.sigil:SetText("")
    else
        self.sigilIcon:Hide()
        self.sigil:SetText(SIGIL_LETTERS[kind] or "?")
    end
    self.kindLabel:SetText(kind)

    self.sourceLink.text:SetText(record.link or record.src or "")
    if record.sourceID then
        self.sourceLink:Show()
    else
        self.sourceLink:Hide()
    end
    self.descText:SetText((record.src and record.src ~= "") and record.src or L["UNKNOWN_SOURCE"])

    -- Obtainability banner
    local obt = record.obtainable
    if obt == "no" then
        self.obtainIcon:SetTexture(UNOBTAIN_SEALED_16)
        self.obtainIcon:SetVertexColor(0.85, 0.35, 0.30, 1.0)
        self.obtainLabel:SetText(L["NO_LONGER_OBTAINABLE"])
        self.obtainLabel:SetTextColor(0.85, 0.35, 0.30)
        self.obtainRow:Show()
    elseif obt == "feat" then
        self.obtainIcon:SetTexture(UNOBTAIN_HOURGLASS_16)
        self.obtainIcon:SetVertexColor(0.90, 0.70, 0.25, 1.0)
        self.obtainLabel:SetText(L["FEAT_OF_STRENGTH"])
        self.obtainLabel:SetTextColor(0.90, 0.70, 0.25)
        self.obtainRow:Show()
    else
        self.obtainRow:Hide()
    end

    -- Obtainability reason (shown below the banner when present)
    local reason = record.obtainability_reason
    if reason and reason ~= "" and (obt == "no" or obt == "feat") then
        self.obtainReason:SetText(reason)
        self.obtainReason:Show()
    else
        self.obtainReason:SetText("")
        self.obtainReason:Hide()
    end

    -- Meta grid (key-value rows with colour codes from Theme)
    local FAINT = T and ("|cff" .. T.col.faint.hex) or "|cff6b6049"
    local TEXT  = T and ("|cff" .. T.col.text.hex) or "|cffe7dcc4"
    local WARN  = T and ("|cff" .. T.col.warn.hex) or "|cffd98a52"
    local lines = {}

    if record.exp then
        local expLabel = ns.EXPANSION_LABELS[record.exp] or record.exp
        lines[#lines + 1] = FAINT .. "Expansion|r       " .. TEXT .. expLabel .. "|r"
    end
    if record.cat then
        lines[#lines + 1] = ""
        lines[#lines + 1] = FAINT .. "Category|r        " .. TEXT .. record.cat .. "|r"
    end
    if record.obtainable == "no" then
        lines[#lines + 1] = ""
        lines[#lines + 1] = FAINT .. "Availability|r     " .. WARN .. L["NO_LONGER_OBTAINABLE"] .. "|r"
    elseif record.obtainable == "feat" then
        lines[#lines + 1] = ""
        lines[#lines + 1] = FAINT .. "Availability|r     " .. WARN .. L["FEAT_OF_STRENGTH"] .. "|r"
    else
        lines[#lines + 1] = ""
        lines[#lines + 1] = FAINT .. "Availability|r     " .. TEXT .. "Account-wide|r"
    end
    if record.faction then
        lines[#lines + 1] = ""
        lines[#lines + 1] = FAINT .. "Faction|r            " .. TEXT .. record.faction .. "|r"
    end
    if record.earned and record.date then
        local dateHex = T and ("|cff" .. T.quality[5].text.hex) or "|cffffa334"
        lines[#lines + 1] = ""
        lines[#lines + 1] = FAINT .. "Earned|r             " .. dateHex .. string.format(L["EARNED_DATE"], record.date) .. "|r"
    elseif not record.earned then
        local lockHex = T and ("|cff" .. T.col.locked.hex) or "|cff5d5443"
        lines[#lines + 1] = ""
        lines[#lines + 1] = FAINT .. "Status|r              " .. lockHex .. L["NOT_YET_EARNED"] .. "|r"
    end

    self.metaText:SetText(table.concat(lines, "\n"))
end

function Detail:RefreshActionButton(record)
    local btn = self.actionButton
    local goldCol = T and T.col.gold or GOLD
    local inkCol  = T and T.col.ink or { r = 0.05, g = 0.04, b = 0.02 }
    local deepCol = T and T.col.goldDeep or { r = 0.49, g = 0.37, b = 0.15 }

    if record.isActive then
        btn:SetText(L["CURRENT_TITLE"])
        btn:Disable()
        btn.tick:Show()
        -- Active state: gold fill, dark text
        btn.bg:SetColorTexture(goldCol.r, goldCol.g, goldCol.b, 1.0)
        btn.text:SetTextColor(inkCol.r, inkCol.g, inkCol.b)
        for _, b in ipairs(btn.borders) do
            b:SetColorTexture(goldCol.r, goldCol.g, goldCol.b, 1.0)
        end
        self.actionNote:SetText(L["CURRENT_NOTE"])
    elseif record.earned then
        btn:SetText(L["SET_AS_MY_TITLE"])
        btn:Enable()
        btn.tick:Hide()
        -- Normal enabled state
        btn.bg:SetColorTexture(0.11, 0.08, 0.04, 1.0)
        btn.text:SetTextColor(goldCol.r, goldCol.g, goldCol.b)
        for _, b in ipairs(btn.borders) do
            b:SetColorTexture(deepCol.r, deepCol.g, deepCol.b, 1.0)
        end
        self.actionNote:SetText(L["SET_NOTE"])
    else
        btn:SetText(L["LOCKED_BUTTON"])
        btn:Disable()
        btn.tick:Hide()
        -- Disabled/locked state
        btn.bg:SetColorTexture(0.07, 0.05, 0.03, 1.0)
        btn.text:SetTextColor(0.36, 0.33, 0.27)
        for _, b in ipairs(btn.borders) do
            b:SetColorTexture(0.20, 0.16, 0.10, 1.0)
        end
        self.actionNote:SetText(L["LOCKED_NOTE"])
    end
    btn.record = record
end

-- ---------------------------------------------------------------------------
-- Actions
-- ---------------------------------------------------------------------------
function Detail:OnActionClick()
    local record = self.actionButton.record
    if not record or not record.earned or record.isActive then return end
    if SetCurrentTitle and record.titleID then
        SetCurrentTitle(record.titleID)
        ns.TitleData:RefreshActiveState()
        ns.MainFrame:FullRefresh()
        ns.TitleList:RefreshSelectionVisuals()
        self:Refresh()
    end
end

function Detail:OnSourceLinkClick()
    local record = ns.MainFrame:GetDetailRecord()
    if not record then return end
    if not record.sourceID then return end
    if C_AchievementInfo and C_AchievementInfo.IsValidAchievement and not C_AchievementInfo.IsValidAchievement(record.sourceID) then return end
    if not AchievementFrame then
        if UIParentLoadAddOn then UIParentLoadAddOn("Blizzard_AchievementUI") end
    end
    if OpenAchievementFrameToAchievement then
        OpenAchievementFrameToAchievement(record.sourceID)
    end
end

-- ---------------------------------------------------------------------------
-- Empty state
-- ---------------------------------------------------------------------------
function Detail:ShowEmpty()
    self.emptyState:Show()
    self.previewBanner:Hide()
    self.titleText:Hide()
    self.subLine:Hide()
    self.rarityCard:Hide()
    self.sourceCard:Hide()
    self.actionButton:Hide()
    self.actionNote:Hide()
end

function Detail:HideEmpty()
    self.emptyState:Hide()
    self.previewBanner:Show()
    self.titleText:Show()
    self.subLine:Show()
    self.rarityCard:Show()
    self.sourceCard:Show()
    self.actionButton:Show()
    self.actionNote:Show()
end
