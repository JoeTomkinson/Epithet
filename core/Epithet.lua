-- =============================================================================
-- Epithet — Addon Core
-- Initialisation, slash commands, minimap button, event wiring, persistence.
-- =============================================================================
local ADDON_NAME, ns = ...

local Epithet = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME)
ns.Epithet = Epithet

-- ---------------------------------------------------------------------------
-- Saved variable defaults
-- ---------------------------------------------------------------------------
local DB_DEFAULTS = {
    profile = {
        filters = {
            search   = "",
            status   = "all",
            rarity   = {},
            type     = {},
            exp      = {},
            cat      = {},
            kind     = {},
            faction  = {},
            hideUnobtainable   = false,
            hideTimeSensitive  = false,
        },
        sort = "collectedFirst",  -- "collectedFirst" | "expansion" | "alphabetical" | "quality" | "category"
        obtainableOnly = false,   -- toggle: show earned % against obtainable pool only
        framePoint = nil,         -- {point, relPoint, x, y}
        scale = 1.0,
        minimap = { hide = false },
    },
}

-- ---------------------------------------------------------------------------
-- Print helper
-- ---------------------------------------------------------------------------
local function Print(msg)
    print("|cffe8c873Epithet:|r " .. msg)
end
ns.Print = Print

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------
function Epithet:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("EpithetDB", DB_DEFAULTS, true)

    -- Sanitise saved filters: search is ephemeral (don't persist across sessions)
    -- and ensure new facet tables exist for profiles saved before they were added.
    local f = self.db.profile.filters
    f.search = ""
    f.cat = f.cat or {}
    f.kind = f.kind or {}
    f.faction = f.faction or {}

    -- Slash commands
    SLASH_EPITHET1 = "/epithet"
    SLASH_EPITHET2 = "/titles"
    SlashCmdList["EPITHET"] = function(input)
        self:HandleSlash(input)
    end

    -- Minimap button
    self:SetupMinimapButton()
end

function Epithet:OnEnable()
    -- Register events via a lightweight frame
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        if self[event] then
            self[event](self, ...)
        end
    end)
    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.eventFrame:RegisterEvent("ACHIEVEMENT_EARNED")
    self.eventFrame:RegisterEvent("UNIT_NAME_UPDATE")
end

-- ---------------------------------------------------------------------------
-- Event handlers
-- ---------------------------------------------------------------------------
function Epithet:PLAYER_ENTERING_WORLD()
    ns.TitleData:Scan()
    if ns.MainFrame and ns.MainFrame:IsShown() then
        ns.MainFrame:FullRefresh()
    end
end

function Epithet:ACHIEVEMENT_EARNED()
    -- A new title may have unlocked
    ns.TitleData:Scan()
    if ns.MainFrame and ns.MainFrame:IsShown() then
        ns.MainFrame:FullRefresh()
    end
end

function Epithet:UNIT_NAME_UPDATE(unit)
    if unit == "player" then
        ns.TitleData:RefreshActiveState()
        if ns.MainFrame and ns.MainFrame:IsShown() then
            ns.MainFrame:FullRefresh()
        end
    end
end

-- ---------------------------------------------------------------------------
-- Slash command handler
-- ---------------------------------------------------------------------------
function Epithet:HandleSlash(input)
    local cmd = input and input:trim():lower() or ""
    if cmd == "minimap" then
        local hide = not self.db.profile.minimap.hide
        self.db.profile.minimap.hide = hide
        local LDBIcon = LibStub("LibDBIcon-1.0", true)
        if LDBIcon then
            if hide then
                LDBIcon:Hide("Epithet")
                Print(ns.L["MINIMAP_HIDDEN"])
            else
                LDBIcon:Show("Epithet")
                Print(ns.L["MINIMAP_SHOWN"])
            end
        end
        return
    elseif cmd == "scan" then
        ns.TitleData:Scan()
        Print("Title scan complete: " .. (ns.TitleData.earnedCount or 0) .. " / " .. (ns.TitleData.totalCount or 0))
        return
    elseif cmd == "debug" then
        -- Dump the raw GetTitleName format + classified type for the first
        -- known titles, to verify prefix/suffix detection in this client.
        local shown = 0
        for id = 1, (GetNumTitles and GetNumTitles() or 0) do
            local raw = GetTitleName and GetTitleName(id)
            if raw and raw ~= "" then
                local rec = ns.TitleData.GetRecord and ns.TitleData:GetRecord(id)
                local t = rec and rec.type or "?"
                Print(string.format("|cffe8c873[%d]|r '%s'  ->  %s", id, raw:gsub("|", "||"), t))
                shown = shown + 1
                if shown >= 25 then break end
            end
        end
        Print("Showed " .. shown .. " raw titles. (Run /epithet scan first if empty.)")
        return
    end

    -- Default: toggle window
    if ns.MainFrame then
        ns.MainFrame:Toggle()
    end
end

-- ---------------------------------------------------------------------------
-- Minimap button (LibDataBroker + LibDBIcon)
-- ---------------------------------------------------------------------------
function Epithet:SetupMinimapButton()
    local LDB = LibStub("LibDataBroker-1.1", true)
    local LDBIcon = LibStub("LibDBIcon-1.0", true)
    if not LDB or not LDBIcon then return end

    local L = ns.L
    local launcher = LDB:NewDataObject("Epithet", {
        type = "launcher",
        text = "Epithet",
        icon = "Interface\\AddOns\\Epithet\\icons\\logo\\epithet-wax-seal-red-minimap-32",
        OnClick = function(_, button)
            if button == "LeftButton" then
                if ns.MainFrame then
                    ns.MainFrame:Toggle()
                end
            elseif button == "RightButton" then
                self.db.profile.minimap.hide = true
                LDBIcon:Hide("Epithet")
                Print(L["MINIMAP_HIDDEN"])
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine(L["MINIMAP_TOOLTIP_TITLE"], 1, 1, 1)
            tooltip:AddLine(L["MINIMAP_TOOLTIP_LEFT"], 0.7, 0.7, 0.7)
            tooltip:AddLine(L["MINIMAP_TOOLTIP_RIGHT"], 0.7, 0.7, 0.7)
            if ns.TitleData.earnedCount and ns.TitleData.totalCount then
                tooltip:AddLine(string.format("Collected: %d / %d",
                    ns.TitleData.earnedCount, ns.TitleData.totalCount), 0.5, 0.8, 0.5)
            end
        end,
    })

    LDBIcon:Register("Epithet", launcher, self.db.profile.minimap)
end
