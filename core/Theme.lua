-- =============================================================================
-- Epithet — Theme
-- Palette, quality colours and skinning helpers, centralising all visual tokens
-- so the addon matches the design spec. Lifted from design/Core/Theme.lua.
-- =============================================================================
local _, ns = ...

local Theme = {}
ns.Theme = Theme

local WHITE = "Interface\\Buttons\\WHITE8X8"

-- hex "e8c873" -> {r,g,b,a,hex} in 0..1
local function C(hex, a)
    return {
        r = tonumber(hex:sub(1, 2), 16) / 255,
        g = tonumber(hex:sub(3, 4), 16) / 255,
        b = tonumber(hex:sub(5, 6), 16) / 255,
        a = a or 1,
        hex = hex,
    }
end

-- ---- surfaces (warm dark "parchment & gold") --------------------------
Theme.col = {
    ink       = C("0c0a06"),
    bg0       = C("120e09"),
    bg1       = C("1a140c"),
    panel     = C("1c1610"),
    panel2    = C("15100a"),
    inset     = C("0d0a06"),
    parch     = C("251d11"),
    gold      = C("e8c873"),
    goldBright= C("f6e2a6"),
    goldDim   = C("b9923f"),
    goldDeep  = C("7c5e26"),
    bronze    = C("8a6c34"),
    line      = C("b8985c", 0.22),
    lineSoft  = C("b8985c", 0.12),
    text      = C("e7dcc4"),
    muted     = C("9c8c6c"),
    faint     = C("6b6049"),
    locked    = C("5d5443"),
    warn      = C("d98a52"),
}

-- ---- rarity = WoW item quality (true pip colour + on-dark text) -------
Theme.quality = {
    [1] = { label = "Common",    pip = C("ffffff"), text = C("f1ede2") },
    [2] = { label = "Uncommon",  pip = C("1eff00"), text = C("5fe24a") },
    [3] = { label = "Rare",      pip = C("0070dd"), text = C("4ea3ff") },
    [4] = { label = "Epic",      pip = C("a335ee"), text = C("c98bff") },
    [5] = { label = "Legendary", pip = C("ff8000"), text = C("ffa334") },
}

-- |cffRRGGBB....|r colour wrap for FontString rich text
function Theme.Wrap(hex, s)
    return "|cff" .. hex .. tostring(s) .. "|r"
end

-- ---- fonts: native TTFs that approximate the Cinzel/Marcellus pairing --
-- MORPHEUS = WoW's serif (quest titles) -> title-in-context & names
-- FRIZQT__ = WoW's body face -> labels, caps headings, body
function Theme.Serif(parent, size, col)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont("Fonts\\MORPHEUS.TTF", size or 16, "")
    if col then fs:SetTextColor(col.r, col.g, col.b, col.a or 1) end
    return fs
end

function Theme.Sans(parent, size, col)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont("Fonts\\FRIZQT__.TTF", size or 12, "")
    if col then fs:SetTextColor(col.r, col.g, col.b, col.a or 1) end
    return fs
end

-- caps "display" label (caller uppercases text before setting)
function Theme.Disp(parent, size, col)
    local fs = Theme.Sans(parent, size or 11, col or Theme.col.gold)
    fs:SetSpacing(2)
    return fs
end

-- ---- solid colour texture (pips, accents, fills) ----------------------
function Theme.Tex(parent, col, layer)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetColorTexture(col.r, col.g, col.b, col.a or 1)
    return t
end

-- ---- a flat tinted panel with a 1px hairline border -------------------
function Theme.Panel(parent, bg, border, borderA)
    local fr = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    fr:SetBackdrop({
        bgFile = WHITE, edgeFile = WHITE, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    bg = bg or Theme.col.panel
    fr:SetBackdropColor(bg.r, bg.g, bg.b, bg.a or 1)
    border = border or Theme.col.line
    fr:SetBackdropBorderColor(border.r, border.g, border.b, borderA or border.a or 1)
    return fr
end

-- small gold diamond (rotated square) — the window corner ornament
function Theme.Diamond(parent, size, col)
    local t = Theme.Tex(parent, col or Theme.col.gold, "OVERLAY")
    t:SetSize(size or 10, size or 10)
    t:SetRotation(math.rad(45))
    return t
end
