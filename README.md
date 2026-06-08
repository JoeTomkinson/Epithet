# Epithet

A lightweight World of Warcraft addon that lets you browse every player title, see how each is earned and how rare it is, and track the ones you're still missing.

## Features

- **Full title catalogue** - enumerates all titles via the client API, joined with a curated static database containing source info, expansion, and rarity.
- **Rarity tiers** - colour-coded Common → Legendary, displayed in standard WoW item-quality colours.
- **Collection tracking** - earned vs unearned at a glance, with a collected count.
- **Filters** - by expansion, status (earned/unearned), rarity, prefix/suffix, and free-text search.
- **Set title** - "Set as Title" button wired to a hardware event (required by the protected `SetCurrentTitle` API).
- **Slash command** - `/epithet` toggles the browser window.

## Project Structure

```txt
Epithet/
├── Epithet.toc              # Addon manifest (Interface 120001)
├── data/
│   └── Titles.lua           # Generated static title database
├── core/
│   ├── Core.lua             # Enumeration, scanning, data join logic
│   └── UI.lua               # AceGUI-based browser frame
├── libs/                    # Embedded Ace3 libraries (see below)
├── LICENSE
└── README.md
```

## API Research (Warcraft Wiki - confirmed 12.0.1 mainline)

| Function                   | Signature                                   | Notes                                                               |
| -------------------------- | ------------------------------------------- | ------------------------------------------------------------------- |
| `GetNumTitles()`           | `numTitles = GetNumTitles()`                | Returns the **highest** title ID (sparse - gaps exist)              |
| `GetTitleName(titleId)`    | `name, playerTitle = GetTitleName(titleId)` | Trailing space in `name` → prefix; otherwise suffix                 |
| `IsTitleKnown(titleId)`    | `isKnown = IsTitleKnown(titleId)`           | Boolean - the character has earned it                               |
| `GetCurrentTitle()`        | `currentTitle = GetCurrentTitle()`          | Returns active title ID (0 = none)                                  |
| `SetCurrentTitle(titleId)` | `SetCurrentTitle(titleId)`                  | **Protected** - must originate from a hardware event (button click) |

The API exposes **only** the title list and known/unknown state. It does **not** provide rarity or source - hence the static data table.

## Rarity Heuristic

Since no authoritative rarity feed exists, rarity is derived from acquisition category:

| Tier | Label     | Criteria                                                                            |
| ---- | --------- | ----------------------------------------------------------------------------------- |
| 5    | Legendary | Seasonal PvP Glad/R1/Hero, Grand Marshal/High Warlord, Scarab Lord                  |
| 4    | Epic      | Removed/unobtainable, Challenge Mode Gold, Hall of Fame, Cutting Edge, "the Insane" |
| 3    | Rare      | Multi-patch meta-achievements (Loremaster, Glory metas), M+ score titles            |
| 2    | Uncommon  | Single achievements, holiday metas, campaign completion, exploration                |
| 1    | Common    | Baseline rep grinds, low PvP ranks, trivial quest rewards                           |

Override any title by adding its ID to `RARITY_OVERRIDES` in `tools/generate-titles.js`.

## Dependencies

- **Ace3** (AceAddon-3.0, AceDB-3.0, AceGUI-3.0, AceConsole-3.0, AceEvent-3.0) - BSD licensed.
- All dependencies are OSI-approved.

### Installing Ace3 libs

Download from [CurseForge](https://www.curseforge.com/wow/addons/ace3) or use [BigWigsMods/packager](https://github.com/BigWigsMods/packager). Place in `libs/`:

```txt
libs/
├── LibStub/
├── CallbackHandler-1.0/
├── AceAddon-3.0/
├── AceDB-3.0/
├── AceConsole-3.0/
├── AceGUI-3.0/
└── AceEvent-3.0/
```

## Usage In-Game

1. Install the addon to `Interface/AddOns/Epithet/`.
2. `/epithet` - opens the title browser.
3. `/epithet scan` - forces a title rescan.

## Licence

Apache-2.0 license - see [LICENSE](LICENSE).
