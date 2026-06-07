-- =============================================================================
-- Epithet — Title Data Layer
-- Enumerates live titles, merges with bundled DB, provides unified records.
-- =============================================================================
local _, ns = ...

-- Bridge global EpithetData (set by data/TitlesDB.lua) into the addon namespace
ns.EpithetData = EpithetData

-- Localize WoW APIs (called 700+ times in Scan loop)
local GetTitleName   = GetTitleName
local IsTitleKnown   = IsTitleKnown
local GetCurrentTitle = GetCurrentTitle
local GetNumTitles   = GetNumTitles
local UnitName       = UnitName
local GetNormalizedRealmName = GetNormalizedRealmName
local GetAchievementInfo     = GetAchievementInfo

-- Localize Lua stdlib
local pairs, ipairs  = pairs, ipairs
local format         = string.format
local strlower       = strlower

local TitleData = {}
ns.TitleData = TitleData

-- ---------------------------------------------------------------------------
-- Rarity / quality colours (pip hex = true item colour; text = on-dark variant)
-- ---------------------------------------------------------------------------
ns.QUALITY_COLOURS = {
    [1] = { pip = { r = 1.00, g = 1.00, b = 1.00 }, text = { r = 0.95, g = 0.93, b = 0.89 } }, -- Common
    [2] = { pip = { r = 0.12, g = 1.00, b = 0.00 }, text = { r = 0.37, g = 0.89, b = 0.29 } }, -- Uncommon
    [3] = { pip = { r = 0.00, g = 0.44, b = 0.87 }, text = { r = 0.31, g = 0.64, b = 1.00 } }, -- Rare
    [4] = { pip = { r = 0.64, g = 0.21, b = 0.93 }, text = { r = 0.79, g = 0.55, b = 1.00 } }, -- Epic
    [5] = { pip = { r = 1.00, g = 0.50, b = 0.00 }, text = { r = 1.00, g = 0.64, b = 0.20 } }, -- Legendary
}

ns.QUALITY_NAMES = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

ns.EXPANSION_ORDER = {
    "classic", "tbc", "wrath", "cata", "mop", "wod",
    "legion", "bfa", "sl", "df", "tww", "mid",
}

ns.EXPANSION_LABELS = ns.EpithetData and ns.EpithetData.expansionLabels or {
    classic = "Classic",
    tbc     = "The Burning Crusade",
    wrath   = "Wrath of the Lich King",
    cata    = "Cataclysm",
    mop     = "Mists of Pandaria",
    wod     = "Warlords of Draenor",
    legion  = "Legion",
    bfa     = "Battle for Azeroth",
    sl      = "Shadowlands",
    df      = "Dragonflight",
    tww     = "The War Within",
    mid     = "Midnight",
}

-- Build expansion index for sort ordering
ns.EXPANSION_INDEX = {}
for i, key in ipairs(ns.EXPANSION_ORDER) do
    ns.EXPANSION_INDEX[key] = i
end

-- ---------------------------------------------------------------------------
-- Classify a raw title string into text + type (prefix/suffix)
-- ---------------------------------------------------------------------------
local function ClassifyTitle(raw)
    if not raw then return nil, nil end

    -- Modern (12.0.x) GetTitleName returns a "%s" name placeholder, e.g.
    --   "Private %s"        -> prefix
    --   "%s the Explorer"   -> suffix
    --   "%s, Lord Admiral"  -> suffix
    -- Detect by where the placeholder sits and strip it + padding/punctuation.
    if raw:find("%%s") then
        local before = raw:match("^(.-)%%s")
        local after  = raw:match("%%s(.*)$")
        before = before or ""
        after  = after or ""
        if before:match("%S") then
            -- text precedes the name -> prefix ("Private %s")
            return "prefix", (before:gsub("%s+$", ""))
        else
            -- name precedes the text -> suffix ("%s the Explorer" / "%s, Jenkins")
            return "suffix", (after:gsub("^[%s,]+", ""))
        end
    end

    -- Legacy/whitespace form fallback.
    if raw:match("^%s") or raw:match("^,") then
        -- Leading space or comma → suffix
        return "suffix", (raw:gsub("^[%s,]+", ""))
    else
        -- Trailing space → prefix
        return "prefix", (raw:gsub("%s+$", ""))
    end
end

-- ---------------------------------------------------------------------------
-- Get earned date from achievement info (if available)
-- ---------------------------------------------------------------------------
local function GetEarnedDate(sourceID)
    if not sourceID or not GetAchievementInfo then return nil end
    local _, _, _, completed, month, day, year = GetAchievementInfo(sourceID)
    if completed and day and month and year and year > 0 then
        -- Format as "dd Month yyyy" (UK format)
        local months = {
            "January", "February", "March", "April", "May", "June",
            "July", "August", "September", "October", "November", "December",
        }
        return format("%d %s %d", day, months[month] or "?", 2000 + year)
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Full scan: enumerate all titles, merge with bundled DB
-- ---------------------------------------------------------------------------
function TitleData:Scan()
    local records = {}
    local earnedCount = 0
    local totalCount = 0
    local earnedObtainableCount = 0
    local totalObtainableCount = 0
    local currentTitleID = GetCurrentTitle and GetCurrentTitle() or 0
    local playerName = UnitName and UnitName("player") or "Player"

    local maxID = GetNumTitles and GetNumTitles() or 0

    for titleID = 1, maxID do
        local raw = GetTitleName and GetTitleName(titleID) or nil
        if raw then
            local titleType, text = ClassifyTitle(raw)
            if text and text ~= "" then
                totalCount = totalCount + 1
                local earned = IsTitleKnown and IsTitleKnown(titleID) or false
                local isActive = (titleID == currentTitleID)

                -- Lookup in bundled DB by normalised text
                local key = strlower(text)
                local static = ns.EpithetData and ns.EpithetData.titles and ns.EpithetData.titles[key]

                local record = {
                    titleID   = titleID,
                    text      = text,
                    -- Prefer the bundled DB's authoritative type; fall back to
                    -- the live classification for titles not in the DB.
                    type      = (static and static.type) or titleType,
                    earned    = earned,
                    isActive  = isActive,
                    -- Bundled fields (may be nil)
                    q         = static and static.q or nil,
                    exp       = static and static.exp or nil,
                    cat       = static and static.cat or nil,
                    src       = static and static.src or nil,
                    kind      = static and static.kind or nil,
                    link      = static and static.link or nil,
                    sourceID  = static and static.sourceID or nil,
                    rarity    = static and static.rarity or nil,
                    obtainable = static and static.obtainable or nil,
                    obtainability_reason = static and static.obtainability_reason or nil,
                    faction   = static and static.faction or nil,
                    date      = nil, -- populated below
                }

                -- Try to get earned date from achievement
                if earned and record.sourceID then
                    record.date = GetEarnedDate(record.sourceID)
                end

                if earned then
                    earnedCount = earnedCount + 1
                end

                -- Track obtainable-only pool
                local obt = record.obtainable
                if obt ~= "no" and obt ~= "feat" then
                    totalObtainableCount = totalObtainableCount + 1
                    if earned then
                        earnedObtainableCount = earnedObtainableCount + 1
                    end
                end

                records[#records + 1] = record
            end
        end
    end

    self.records = records
    self.earnedCount = earnedCount
    self.totalCount = totalCount
    self.earnedObtainableCount = earnedObtainableCount
    self.totalObtainableCount = totalObtainableCount
    self.currentTitleID = currentTitleID
    self.playerName = playerName
    self.playerRealm = GetNormalizedRealmName and GetNormalizedRealmName() or "Unknown"

    return records
end

-- ---------------------------------------------------------------------------
-- Refresh active title state without full rescan
-- ---------------------------------------------------------------------------
function TitleData:RefreshActiveState()
    local currentTitleID = GetCurrentTitle and GetCurrentTitle() or 0
    self.currentTitleID = currentTitleID
    if self.records then
        for _, record in ipairs(self.records) do
            record.isActive = (record.titleID == currentTitleID)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Get record by titleID
-- ---------------------------------------------------------------------------
function TitleData:GetRecord(titleID)
    if not self.records then return nil end
    for _, record in ipairs(self.records) do
        if record.titleID == titleID then
            return record
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Render title in context: "the Insane Aelynne" or "Aelynne, Lord Admiral"
-- ---------------------------------------------------------------------------
function TitleData:RenderTitleInContext(record, name)
    name = name or self.playerName or "Player"
    if record.type == "prefix" then
        return record.text .. " " .. name
    else
        return name .. ", " .. record.text
    end
end

-- ---------------------------------------------------------------------------
-- Open the linked achievement (mirrors design/Core/TitleData.lua ns.OpenSource)
-- ---------------------------------------------------------------------------
function TitleData:OpenSource(record)
    if not (record and record.sourceID) then return end
    if not AchievementFrame then
        if UIParentLoadAddOn then UIParentLoadAddOn("Blizzard_AchievementUI") end
    end
    if OpenAchievementFrameToAchievement then
        OpenAchievementFrameToAchievement(record.sourceID)
    elseif AchievementFrame_SelectAchievement then
        ShowUIPanel(AchievementFrame)
        AchievementFrame_SelectAchievement(record.sourceID)
    end
end
