-- =============================================================================
-- Epithet — Filter & Sort Engine
-- Provides filtering predicates, sort modes, and sidebar count computation.
-- =============================================================================
local _, ns = ...

-- Localize Lua stdlib
local next, pairs, ipairs = next, pairs, ipairs
local wipe     = wipe
local sort     = table.sort
local strlower = strlower
local strfind  = strfind

local Filters = {}
ns.Filters = Filters

-- ---------------------------------------------------------------------------
-- Default filter state
-- ---------------------------------------------------------------------------
function Filters:GetDefaults()
    return {
        search   = "",
        status   = "all",      -- "all" | "earned" | "unearned"
        rarity   = {},         -- empty = unrestricted; set of tier numbers {[3]=true,[5]=true}
        type     = {},         -- empty = unrestricted; {["prefix"]=true}
        exp      = {},         -- empty = unrestricted; {["wrath"]=true}
        cat      = {},         -- empty = unrestricted; {["PvP"]=true}
        kind     = {},         -- empty = unrestricted; {["Achievement"]=true}
        faction  = {},         -- empty = unrestricted; {["Alliance"]=true}
        hideUnobtainable   = false,
        hideTimeSensitive  = false,
        favouritesOnly     = false,
    }
end

-- ---------------------------------------------------------------------------
-- Check if filters are at default (nothing active)
-- ---------------------------------------------------------------------------
function Filters:IsDefault(filters)
    if filters.search ~= "" then return false end
    if filters.status ~= "all" then return false end
    if next(filters.rarity) then return false end
    if next(filters.type) then return false end
    if next(filters.exp) then return false end
    if filters.cat and next(filters.cat) then return false end
    if filters.kind and next(filters.kind) then return false end
    if filters.faction and next(filters.faction) then return false end
    if filters.hideUnobtainable then return false end
    if filters.hideTimeSensitive then return false end
    if filters.favouritesOnly then return false end
    return true
end

-- ---------------------------------------------------------------------------
-- Reset filters to defaults
-- ---------------------------------------------------------------------------
function Filters:Reset(filters)
    filters.search = ""
    filters.status = "all"
    wipe(filters.rarity)
    wipe(filters.type)
    wipe(filters.exp)
    if filters.cat then wipe(filters.cat) else filters.cat = {} end
    if filters.kind then wipe(filters.kind) else filters.kind = {} end
    if filters.faction then wipe(filters.faction) else filters.faction = {} end
    filters.hideUnobtainable = false
    filters.hideTimeSensitive = false
    filters.favouritesOnly = false
end

-- ---------------------------------------------------------------------------
-- Test a single record against filters (AND across facets, OR within)
-- ---------------------------------------------------------------------------
function Filters:Matches(record, filters)
    -- Favourites only
    if filters.favouritesOnly then
        local favs = ns.Epithet.db and ns.Epithet.db.profile.favourites
        if not favs or not favs[strlower(record.text or "")] then return false end
    end

    -- Status
    if filters.status == "earned" and not record.earned then return false end
    if filters.status == "unearned" and record.earned then return false end

    -- Hide unobtainable
    if filters.hideUnobtainable and record.obtainable == "no" then return false end

    -- Hide time-sensitive / feat of strength
    if filters.hideTimeSensitive and record.obtainable == "feat" then return false end

    -- Rarity (OR within)
    if next(filters.rarity) then
        local q = record.q or 0
        if not filters.rarity[q] then return false end
    end

    -- Type (OR within)
    if next(filters.type) then
        if not filters.type[record.type] then return false end
    end

    -- Expansion (OR within)
    if next(filters.exp) then
        if not filters.exp[record.exp or ""] then return false end
    end

    -- Category (OR within)
    if filters.cat and next(filters.cat) then
        if not filters.cat[record.cat or ""] then return false end
    end

    -- Kind (OR within)
    if filters.kind and next(filters.kind) then
        if not filters.kind[record.kind or ""] then return false end
    end

    -- Faction (OR within; "Both" means show Alliance + Horde specific titles)
    if filters.faction and next(filters.faction) then
        local f = record.faction
        if filters.faction["Both"] then
            -- "Both" selected: show faction-specific titles (Alliance + Horde)
            if not f then
                -- Neutral title — only show if not exclusively "Both"
                if not filters.faction["Alliance"] and not filters.faction["Horde"] then
                    return false
                end
            end
        else
            -- Only specific factions selected
            if f then
                if not filters.faction[f] then return false end
            else
                -- Neutral title, no matching faction filter
                return false
            end
        end
    end

    -- Search (case-insensitive substring over text + sources + link + cat)
    if filters.search and filters.search ~= "" then
        local needle = strlower(filters.search)
        local haystack = (record.text or "") .. " " ..
                         (record.achievement or "") .. " " ..
                         (record.quest or "") .. " " ..
                         (record.source_item or "") .. " " ..
                         (record.link or "") .. " " ..
                         (record.cat or "")
        if not strfind(strlower(haystack), needle, 1, true) then
            return false
        end
    end

    return true
end

-- ---------------------------------------------------------------------------
-- Apply filters to a list of records, return filtered array
-- ---------------------------------------------------------------------------
function Filters:Apply(records, filters)
    local result = {}
    for _, record in ipairs(records) do
        if self:Matches(record, filters) then
            result[#result + 1] = record
        end
    end
    return result
end

-- ---------------------------------------------------------------------------
-- Sort modes
-- ---------------------------------------------------------------------------
local function ExpOrder(exp)
    return ns.EXPANSION_INDEX[exp or ""] or 99
end

local function SortCollectedFirst(a, b)
    -- Earned before locked
    if a.earned ~= b.earned then
        return a.earned
    end
    -- Within earned: favourites first
    if a.earned and b.earned then
        local favs = ns.Epithet.db and ns.Epithet.db.profile.favourites
        if favs then
            local fa = favs[strlower(a.text or "")] or false
            local fb = favs[strlower(b.text or "")] or false
            if fa ~= fb then return fa end
        end
    end
    -- Within group: expansion order
    local ea, eb = ExpOrder(a.exp), ExpOrder(b.exp)
    if ea ~= eb then return ea < eb end
    -- Then rarity descending
    local qa, qb = a.q or 0, b.q or 0
    if qa ~= qb then return qa > qb end
    -- Then alphabetical
    return (a.text or "") < (b.text or "")
end

local function SortByExpansion(a, b)
    local ea, eb = ExpOrder(a.exp), ExpOrder(b.exp)
    if ea ~= eb then return ea < eb end
    local qa, qb = a.q or 0, b.q or 0
    if qa ~= qb then return qa > qb end
    return (a.text or "") < (b.text or "")
end

local function SortAlphabetical(a, b)
    return (a.text or "") < (b.text or "")
end

local function SortByQuality(a, b)
    local qa, qb = a.q or 0, b.q or 0
    if qa ~= qb then return qa > qb end
    return (a.text or "") < (b.text or "")
end

local function SortByCategory(a, b)
    local ca, cb = a.cat or "", b.cat or ""
    if ca ~= cb then return ca < cb end
    return (a.text or "") < (b.text or "")
end

function Filters:Sort(records, mode)
    if mode == "expansion" then
        sort(records, SortByExpansion)
    elseif mode == "alphabetical" then
        sort(records, SortAlphabetical)
    elseif mode == "quality" then
        sort(records, SortByQuality)
    elseif mode == "category" then
        sort(records, SortByCategory)
    else
        sort(records, SortCollectedFirst)
    end
    return records
end

-- ---------------------------------------------------------------------------
-- Compute sidebar counts (against FULL dataset, not filtered)
-- Returns: { rarity={[1]=n,...}, type={prefix=n,...}, exp={classic=n,...},
--            earned=n, unearned=n, total=n }
-- ---------------------------------------------------------------------------
function Filters:ComputeCounts(records)
    local counts = {
        rarity   = { [1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0 },
        type     = { prefix = 0, suffix = 0 },
        exp      = {},
        cat      = {},
        kind     = {},
        faction  = { Alliance = 0, Horde = 0, Both = 0 },
        earned   = 0,
        unearned = 0,
        total    = 0,
    }

    -- Initialise expansion counts
    for _, key in ipairs(ns.EXPANSION_ORDER) do
        counts.exp[key] = 0
    end

    for _, record in ipairs(records) do
        counts.total = counts.total + 1
        if record.earned then
            counts.earned = counts.earned + 1
        else
            counts.unearned = counts.unearned + 1
        end

        local q = record.q or 0
        if q >= 1 and q <= 5 then
            counts.rarity[q] = counts.rarity[q] + 1
        end

        if record.type == "prefix" then
            counts.type.prefix = counts.type.prefix + 1
        elseif record.type == "suffix" then
            counts.type.suffix = counts.type.suffix + 1
        end

        local exp = record.exp or ""
        if counts.exp[exp] then
            counts.exp[exp] = counts.exp[exp] + 1
        end

        -- Category
        local cat = record.cat or ""
        counts.cat[cat] = (counts.cat[cat] or 0) + 1

        -- Kind
        local kind = record.kind or ""
        counts.kind[kind] = (counts.kind[kind] or 0) + 1

        -- Faction
        local f = record.faction
        if f == "Alliance" then
            counts.faction.Alliance = counts.faction.Alliance + 1
        elseif f == "Horde" then
            counts.faction.Horde = counts.faction.Horde + 1
        else
            counts.faction.Both = counts.faction.Both + 1
        end
    end

    return counts
end

-- ---------------------------------------------------------------------------
-- Build display list with group headers (for "Collected first" mode)
-- Returns array of {isHeader=bool, label=string, count=number} or record refs
-- ---------------------------------------------------------------------------
function Filters:BuildDisplayList(records, sortMode)
    local sorted = self:Sort(records, sortMode)

    if sortMode == "expansion" or sortMode == "alphabetical" or sortMode == "quality" then
        -- No group headers in flat modes
        return sorted
    end

    if sortMode == "category" then
        -- Insert group headers per category
        local display = {}
        local currentCat = nil
        local catCounts = {}
        for _, record in ipairs(sorted) do
            local c = record.cat or ""
            catCounts[c] = (catCounts[c] or 0) + 1
        end
        for _, record in ipairs(sorted) do
            local c = record.cat or ""
            if c ~= currentCat then
                currentCat = c
                table.insert(display, {
                    isHeader = true,
                    label = (c ~= "") and c:upper() or "UNCATEGORIZED",
                    count = catCounts[c] or 0,
                })
            end
            table.insert(display, record)
        end
        return display
    end

    -- "Collected first" mode: insert group headers
    local display = {}
    local earnedCount = 0
    local lockedCount = 0
    local inLockedSection = false

    for _, record in ipairs(sorted) do
        if record.earned then
            earnedCount = earnedCount + 1
        else
            lockedCount = lockedCount + 1
        end
    end

    local insertedEarnedHeader = false
    local insertedLockedHeader = false

    for _, record in ipairs(sorted) do
        if record.earned and not insertedEarnedHeader then
            table.insert(display, {
                isHeader = true,
                label = ns.L and ns.L["GROUP_COLLECTED"] or "COLLECTED",
                count = earnedCount,
            })
            insertedEarnedHeader = true
        elseif not record.earned and not insertedLockedHeader then
            table.insert(display, {
                isHeader = true,
                label = ns.L and ns.L["GROUP_NOT_COLLECTED"] or "NOT YET COLLECTED",
                count = lockedCount,
            })
            insertedLockedHeader = true
        end
        table.insert(display, record)
    end

    return display
end
