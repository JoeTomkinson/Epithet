-- =============================================================================
-- Epithet — Main Frame Controller
-- Window lifecycle, header band, bottom bar, position persistence.
-- =============================================================================
local _, ns = ...
local L = ns.L
local T = ns.Theme

-- Localize WoW APIs & Lua stdlib
local UnitName = UnitName
local GetNormalizedRealmName = GetNormalizedRealmName
local SetPortraitTexture     = SetPortraitTexture
local CreateFrame = CreateFrame
local format  = string.format
local floor   = math.floor
local tinsert = tinsert

local MainFrame = {}
ns.MainFrame = MainFrame

local RARITY_GEMS = {
    "Interface\\AddOns\\Epithet\\icons\\rarity\\epithet-rarity-1-common-32",
    "Interface\\AddOns\\Epithet\\icons\\rarity\\epithet-rarity-2-uncommon-32",
    "Interface\\AddOns\\Epithet\\icons\\rarity\\epithet-rarity-3-rare-32",
    "Interface\\AddOns\\Epithet\\icons\\rarity\\epithet-rarity-4-epic-32",
    "Interface\\AddOns\\Epithet\\icons\\rarity\\epithet-rarity-5-legendary-32",
}

local frame = nil  -- reference to EpithetMainFrame

-- ---------------------------------------------------------------------------
-- Initialise (called once, sets up the frame the first time it's needed)
-- ---------------------------------------------------------------------------

-- Backdrop definition for the custom dark frame
local EPITHET_BACKDROP = {
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = nil,
    tile     = false,
    tileEdge = false,
    tileSize = 0,
    edgeSize = 0,
    insets   = { left = 0, right = 0, top = 0, bottom = 0 },
}

function MainFrame:Init()
    if frame then return end
    frame = EpithetMainFrame
    if not frame then return end

    -- Apply custom dark background via BackdropTemplate
    if frame.SetBackdrop then
        frame:SetBackdrop(EPITHET_BACKDROP)
    end
    frame:SetBackdropColor(0.07, 0.05, 0.03, 0.97)

    -- Set custom title bar text
    if frame.TitleBar and frame.TitleBar.Title then
        frame.TitleBar.Title:SetText("|cffe8c767EPITHET|r |cffb0a284THE TITLE SHOWCASE|r")
    end

    -- Add to special frames for ESC-close
    tinsert(UISpecialFrames, "EpithetMainFrame")

    -- Expose SavePosition on the frame widget for XML script access
    frame.SavePosition = function() MainFrame:SavePosition() end

    -- Restore position
    self:RestorePosition()

    -- Set up header
    self:InitHeader()

    -- Set up bottom bar
    self:InitBottomBar()

    -- Reskin inset panels to match custom dark chrome
    self:SkinInsetPanel(frame.Sidebar)
    self:SkinInsetPanel(frame.ListContainer)
    self:SkinInsetPanel(frame.Detail)

    -- Set up sub-panels
    ns.Sidebar:Init(frame.Sidebar)
    ns.TitleList:Init(frame.ListContainer)
    ns.Detail:Init(frame.Detail)
end

-- ---------------------------------------------------------------------------
-- Toggle / Show / Hide
-- ---------------------------------------------------------------------------
function MainFrame:Toggle()
    self:Init()
    if not frame then return end
    if frame:IsShown() then
        frame:Hide()
    else
        self:Show()
    end
end

function MainFrame:Show()
    self:Init()
    if not frame then return end

    -- Scan fresh data
    ns.TitleData:Scan()

    -- Show the frame first so refresh guards pass
    frame:Show()

    -- Update displays
    self:RefreshHeader()
    ns.Sidebar:Refresh()
    self:RefreshList()

    -- Select the equipped title or first row
    self:SelectDefault()
end

function MainFrame:IsShown()
    return frame and frame:IsShown()
end

-- ---------------------------------------------------------------------------
-- Full refresh (called on data change while window is open)
-- ---------------------------------------------------------------------------
function MainFrame:FullRefresh()
    if not frame or not frame:IsShown() then return end
    self:RefreshHeader()
    ns.Sidebar:Refresh()
    self:RefreshList()
end

-- ---------------------------------------------------------------------------
-- Refresh just the list (called on filter/sort change)
-- ---------------------------------------------------------------------------
function MainFrame:RefreshList()
    if not frame or not frame:IsShown() then return end
    ns.TitleList:Refresh()
end

-- ---------------------------------------------------------------------------
-- Header band
-- ---------------------------------------------------------------------------
function MainFrame:InitHeader()
    local header = frame.Header
    if not header then return end

    -- Portrait ring: subtle gold circle behind the portrait
    if header.PortraitRing then
        header.PortraitRing:SetTexture("Interface\\COMMON\\Indicator-Gray")
        header.PortraitRing:SetVertexColor(0.49, 0.37, 0.15, 0.5)
    end

    -- Portrait: set to player model portrait
    if header.Portrait then
        SetPortraitTexture(header.Portrait, "player")
    end

    header.PlayerName:SetText("")
    header.PlayerRealm:SetText("")
    header.EarnedLabel:SetText(L["TITLES_EARNED"])
    header.EarnedCount:SetText("")
    header.ProgressBar:SetMinMaxValues(0, 100)
    header.ProgressBar:SetValue(0)

    -- Obtainable-only toggle (icon to the right of earned label)
    local TOGGLE_OFF = "Interface\\AddOns\\Epithet\\icons\\ui\\epithet-ui-toggle-off-32"
    local TOGGLE_ON  = "Interface\\AddOns\\Epithet\\icons\\ui\\epithet-ui-toggle-on-32"

    -- Shift earned label left to make room for toggle
    header.EarnedLabel:ClearAllPoints()
    header.EarnedLabel:SetPoint("TOPRIGHT", header, "TOPRIGHT", -30, -8)

    -- Ensure count row shares the same right edge as the toggle
    header.EarnedCount:ClearAllPoints()
    header.EarnedCount:SetPoint("TOPRIGHT", header, "TOPRIGHT", -8, -22)

    local toggle = CreateFrame("Button", nil, header)
    toggle:SetSize(18, 18)
    toggle:SetPoint("LEFT", header.EarnedLabel, "RIGHT", 4, 0)

    local icon = toggle:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(TOGGLE_OFF)
    icon:SetVertexColor(0.73, 0.57, 0.25, 1.0)
    toggle.icon = icon
    toggle.TOGGLE_ON = TOGGLE_ON
    toggle.TOGGLE_OFF = TOGGLE_OFF

    toggle:SetScript("OnClick", function()
        local db = ns.Epithet.db.profile
        db.obtainableOnly = not db.obtainableOnly
        MainFrame:RefreshHeader()
    end)
    toggle:SetScript("OnEnter", function(self_)
        GameTooltip:SetOwner(self_, "ANCHOR_BOTTOMLEFT")
        local mode = ns.Epithet.db.profile.obtainableOnly
        GameTooltip:SetText(mode and L["TOGGLE_ALL_TITLES"] or L["TOGGLE_OBTAINABLE_ONLY"], 1, 1, 1)
        GameTooltip:Show()
    end)
    toggle:SetScript("OnLeave", function() GameTooltip:Hide() end)
    header.ObtainToggle = toggle
end

function MainFrame:RefreshHeader()
    local header = frame.Header
    if not header then return end

    local name = ns.TitleData.playerName or UnitName("player") or "Player"
    local realm = ns.TitleData.playerRealm or GetNormalizedRealmName() or ""

    -- Build display name with current title applied
    local currentTitleID = ns.TitleData.currentTitleID or 0
    if currentTitleID > 0 and ns.TitleData.records then
        local activeRecord = ns.TitleData:GetRecord(currentTitleID)
        if activeRecord and activeRecord.text then
            if activeRecord.type == "suffix" then
                name = name .. ", " .. activeRecord.text
            else
                name = activeRecord.text .. " " .. name
            end
        end
    end

    local obtOnly = ns.Epithet.db.profile.obtainableOnly
    local earned, total
    if obtOnly then
        earned = ns.TitleData.earnedObtainableCount or 0
        total  = ns.TitleData.totalObtainableCount or 0
    else
        earned = ns.TitleData.earnedCount or 0
        total  = ns.TitleData.totalCount or 0
    end
    local pct = total > 0 and floor((earned / total) * 100) or 0

    -- Refresh portrait in case of character change
    if header.Portrait then
        SetPortraitTexture(header.Portrait, "player")
    end

    header.PlayerName:SetText(name)
    header.PlayerRealm:SetText(realm)

    -- Update label to reflect mode
    header.EarnedLabel:SetText(obtOnly and L["TITLES_EARNED_OBTAINABLE"] or L["TITLES_EARNED"])

    if T then
        local col = T.col
        header.PlayerName:SetTextColor(col.goldBright.r, col.goldBright.g, col.goldBright.b)
        header.PlayerRealm:SetTextColor(col.muted.r, col.muted.g, col.muted.b)
        header.EarnedCount:SetText(
            T.Wrap(col.goldBright.hex, earned) .. "  / " .. total .. "   " .. T.Wrap(col.goldDim.hex, pct .. "%")
        )
    else
        header.EarnedCount:SetText(format("|cffe8c873%d|r / %d    |cffb9923f%d%%|r", earned, total, pct))
    end

    header.ProgressBar:SetMinMaxValues(0, total)
    header.ProgressBar:SetValue(earned)

    -- Update toggle icon
    if header.ObtainToggle then
        if obtOnly then
            header.ObtainToggle.icon:SetTexture(header.ObtainToggle.TOGGLE_ON)
        else
            header.ObtainToggle.icon:SetTexture(header.ObtainToggle.TOGGLE_OFF)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Bottom bar (rarity legend + version)
-- ---------------------------------------------------------------------------
function MainFrame:InitBottomBar()
    local bar = frame.BottomBar
    if not bar then return end

    bar.RarityLabel:SetText(L["RARITY"])
    if T then
        bar.RarityLabel:SetTextColor(T.col.gold.r, T.col.gold.g, T.col.gold.b)
    end

    -- Create rarity legend pips + labels (round dots, labels on OVERLAY so a
    -- pip never draws over a label; vertically centered to the bar).
    local prevAnchor = bar.RarityLabel
    local qualityData = T and T.quality or nil

    for i = 1, 5 do
        local q = qualityData and qualityData[i]
        local pipCol = q and q.pip or ns.QUALITY_COLOURS[i].pip
        local txtCol = q and q.text or ns.QUALITY_COLOURS[i].text
        local name   = q and q.label or ns.QUALITY_NAMES[i]

        -- Gem (rarity icon, tinted)
        local pip = bar:CreateTexture(nil, "ARTWORK")
        pip:SetTexture(RARITY_GEMS[i])
        pip:SetVertexColor(pipCol.r, pipCol.g, pipCol.b, 1.0)
        pip:SetSize(9, 9)
        pip:SetPoint("LEFT", prevAnchor, "RIGHT", i == 1 and 12 or 11, 0)

        -- Label
        local label = bar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        label:SetText(name)
        label:SetTextColor(txtCol.r, txtCol.g, txtCol.b)
        label:SetPoint("LEFT", pip, "RIGHT", 7, 0)

        prevAnchor = label
    end

    -- Version info (two rows)
    local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local addonVersion = (getMeta and getMeta("Epithet", "Version")) or "1.0.0"
    local dbVersion = ns.EpithetData and ns.EpithetData.version or "?"
    local rawDate = ns.EpithetData and ns.EpithetData.date or nil
    local dbDate
    if rawDate and rawDate:match("^%d%d%d%d%-%d%d%-%d%d$") then
        local y, m, d = rawDate:match("^(%d+)-(%d+)-(%d+)$")
        dbDate = format("%s/%s/%s", d, m, y)
    else
        dbDate = rawDate or "unknown"
    end
    local gameInterface = select(4, GetBuildInfo()) or "?"
    -- Format as X.X.X from the integer (e.g. 120001 -> 12.0.1)
    if type(gameInterface) == "number" then
        local major = floor(gameInterface / 10000)
        local minor = floor((gameInterface % 10000) / 100)
        local patch = gameInterface % 100
        gameInterface = format("%d.%d.%d", major, minor, patch)
    end

    -- Row 1: Epithet version (left) | TitlesDB version (right)
    bar.Version:SetText("Epithet v" .. addonVersion .. "  \194\183  TitlesDB v" .. dbVersion)
    -- Row 2: Game target (left) | TitlesDB date (right)
    bar.Version2:SetText("Interface " .. gameInterface .. "  \194\183  Updated " .. dbDate)
    if T then
        bar.Version:SetTextColor(T.col.faint.r, T.col.faint.g, T.col.faint.b)
        bar.Version2:SetTextColor(T.col.faint.r, T.col.faint.g, T.col.faint.b)
    end

    -- Source kind icon legend (right of rarity pips)
    local SOURCE_LEGEND = {
        { icon = "Interface\\AddOns\\Epithet\\icons\\category\\epithet-cat-achievement-16", label = "Achievement" },
        { icon = "Interface\\AddOns\\Epithet\\icons\\category\\epithet-cat-quest-16",       label = "Quest" },
        { icon = "Interface\\AddOns\\Epithet\\icons\\category\\epithet-cat-reputation-16",  label = "Reputation" },
        { icon = "Interface\\AddOns\\Epithet\\icons\\category\\epithet-cat-pvp-16",         label = "PvP" },
        { icon = "Interface\\AddOns\\Epithet\\icons\\category\\epithet-cat-feat-16",        label = "Feat" },
        { icon = "Interface\\AddOns\\Epithet\\icons\\category\\epithet-cat-exploration-16", label = "Exploration" },
        { icon = "Interface\\AddOns\\Epithet\\icons\\category\\epithet-cat-raid-16",        label = "Raid" },
    }

    local sourceLabel = bar:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    sourceLabel:SetText(L["SOURCE_LEGEND"] or "SOURCE")
    sourceLabel:SetPoint("LEFT", prevAnchor, "RIGHT", 24, 0)
    if T then
        sourceLabel:SetTextColor(T.col.gold.r, T.col.gold.g, T.col.gold.b)
    end

    local srcPrev = sourceLabel
    local goldCol = T and T.col.gold or { r = 0.91, g = 0.78, b = 0.45 }
    local parchCol = T and T.col.panel or { r = 0.11, g = 0.08, b = 0.04 }

    -- Shared hover popup (circular-ish with gold border, parchment bg, large icon)
    local popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    popup:SetSize(48, 48)
    popup:SetFrameStrata("TOOLTIP")
    popup:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 2,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    popup:SetBackdropColor(parchCol.r, parchCol.g, parchCol.b, 0.95)
    popup:SetBackdropBorderColor(goldCol.r, goldCol.g, goldCol.b, 1.0)
    popup:Hide()

    -- Circular mask overlay (rounded corners via texture)
    local popupIcon = popup:CreateTexture(nil, "ARTWORK")
    popupIcon:SetSize(32, 32)
    popupIcon:SetPoint("CENTER")
    popup.icon = popupIcon

    -- Label pill above the popup (background + border frame)
    local pill = CreateFrame("Frame", nil, popup, "BackdropTemplate")
    pill:SetFrameStrata("TOOLTIP")
    pill:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    pill:SetBackdropColor(parchCol.r, parchCol.g, parchCol.b, 0.95)
    pill:SetBackdropBorderColor(goldCol.r, goldCol.g, goldCol.b, 0.7)
    pill:SetPoint("BOTTOM", popup, "TOP", 0, 6)

    local popupLabel = pill:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    popupLabel:SetPoint("CENTER", pill, "CENTER", 0, 0)
    popupLabel:SetTextColor(goldCol.r, goldCol.g, goldCol.b)
    popup.label = popupLabel
    popup.pill = pill

    self.sourceIconPopup = popup

    for i, def in ipairs(SOURCE_LEGEND) do
        -- Wrap icon + label in an invisible button for mouse events
        local btn = CreateFrame("Button", nil, bar)
        btn:SetHeight(12)
        btn:SetPoint("LEFT", srcPrev, "RIGHT", i == 1 and 12 or 10, 0)

        local ico = btn:CreateTexture(nil, "ARTWORK")
        ico:SetSize(12, 12)
        ico:SetPoint("LEFT", 0, 0)
        ico:SetTexture(def.icon)
        ico:SetVertexColor(goldCol.r, goldCol.g, goldCol.b, 1.0)

        local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        lbl:SetText(def.label)
        if T then
            lbl:SetTextColor(T.col.muted.r, T.col.muted.g, T.col.muted.b)
        end
        lbl:SetPoint("LEFT", ico, "RIGHT", 4, 0)

        -- Size button to cover both icon and label
        btn:SetScript("OnShow", function(self_)
            local w = 12 + 4 + (lbl:GetStringWidth() or 30)
            self_:SetWidth(w)
        end)
        local initWidth = 12 + 4 + (lbl:GetStringWidth() or 30)
        btn:SetWidth(initWidth)

        -- The 32px version for the popup
        local icon32 = def.icon:gsub("%-16$", "-32")

        btn:SetScript("OnEnter", function(self_)
            popupIcon:SetTexture(icon32)
            popupIcon:SetVertexColor(goldCol.r, goldCol.g, goldCol.b, 1.0)
            popupLabel:SetText(def.label)
            -- Size the pill to fit the label text + padding
            local textWidth = popupLabel:GetStringWidth() or 40
            pill:SetSize(textWidth + 16, 18)
            popup:ClearAllPoints()
            popup:SetPoint("BOTTOM", self_, "TOP", 0, 24)
            popup:Show()
        end)
        btn:SetScript("OnLeave", function()
            popup:Hide()
        end)

        srcPrev = btn
    end
end

-- ---------------------------------------------------------------------------
-- Reskin an InsetFrameTemplate3 panel to custom dark parchment look
-- ---------------------------------------------------------------------------
function MainFrame:SkinInsetPanel(panel)
    if not panel then return end
    -- Suppress the default inset border/bg textures if present
    if panel.NineSlice then panel.NineSlice:Hide() end
    if panel.Bg then panel.Bg:Hide() end

    -- Custom background
    if not panel.EpithetBG then
        local bg = panel:CreateTexture(nil, "BACKGROUND", nil, -8)
        bg:SetAllPoints()
        bg:SetColorTexture(0.05, 0.04, 0.02, 0.85)
        panel.EpithetBG = bg
    end

    -- Subtle hairline border (1px, faint gold)
    if not panel.EpithetBorder then
        local c = T and T.col.line or { r = 0.72, g = 0.60, b = 0.36, a = 0.22 }
        local t = panel:CreateTexture(nil, "BORDER")
        t:SetPoint("TOPLEFT", -1, 1); t:SetPoint("TOPRIGHT", 1, 1); t:SetHeight(1)
        t:SetColorTexture(c.r, c.g, c.b, c.a or 0.22)
        local b = panel:CreateTexture(nil, "BORDER")
        b:SetPoint("BOTTOMLEFT", -1, -1); b:SetPoint("BOTTOMRIGHT", 1, -1); b:SetHeight(1)
        b:SetColorTexture(c.r, c.g, c.b, c.a or 0.22)
        local l = panel:CreateTexture(nil, "BORDER")
        l:SetPoint("TOPLEFT", -1, 0); l:SetPoint("BOTTOMLEFT", -1, 0); l:SetWidth(1)
        l:SetColorTexture(c.r, c.g, c.b, c.a or 0.22)
        local r = panel:CreateTexture(nil, "BORDER")
        r:SetPoint("TOPRIGHT", 1, 0); r:SetPoint("BOTTOMRIGHT", 1, 0); r:SetWidth(1)
        r:SetColorTexture(c.r, c.g, c.b, c.a or 0.22)
        panel.EpithetBorder = { t, b, l, r }
    end
end

-- ---------------------------------------------------------------------------
-- Position persistence
-- ---------------------------------------------------------------------------
function MainFrame:SavePosition()
    if not frame then return end
    local point, _, relPoint, x, y = frame:GetPoint(1)
    ns.Epithet.db.profile.framePoint = { point, relPoint, x, y }
end

function MainFrame:RestorePosition()
    if not frame then return end
    local saved = ns.Epithet.db.profile.framePoint
    if saved then
        frame:ClearAllPoints()
        frame:SetPoint(saved[1], UIParent, saved[2], saved[3], saved[4])
    end

    local scale = ns.Epithet.db.profile.scale or 1.0
    frame:SetScale(scale)
end

-- ---------------------------------------------------------------------------
-- Default selection (equipped title or first row)
-- ---------------------------------------------------------------------------
function MainFrame:SelectDefault()
    local currentID = ns.TitleData.currentTitleID
    if currentID and currentID > 0 then
        local record = ns.TitleData:GetRecord(currentID)
        if record then
            ns.TitleList:SetSelection(record)
            return
        end
    end
    -- Fall back to first row
    ns.TitleList:SelectFirst()
end

-- ---------------------------------------------------------------------------
-- Selection / hover state (shared between list and detail)
-- ---------------------------------------------------------------------------
MainFrame.selectedRecord = nil
MainFrame.hoveredRecord = nil

function MainFrame:SetSelection(record)
    self.selectedRecord = record
    ns.Detail:Refresh()
end

function MainFrame:SetHover(record)
    self.hoveredRecord = record
    ns.Detail:Refresh()
end

function MainFrame:ClearHover()
    self.hoveredRecord = nil
    ns.Detail:Refresh()
end

function MainFrame:GetDetailRecord()
    return self.hoveredRecord or self.selectedRecord
end
