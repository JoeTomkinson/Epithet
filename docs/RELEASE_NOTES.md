# Release Notes

---

## [1.1.0] - 2026-06-09

### Added

- **Favourites** — Mark any earned title as a favourite using the new star button in the detail panel. Favourited titles are pinned to the top of the Collected group in "Collected First" sort mode and display with a star prefix in the title list. A new "Favourites Only" filter in the sidebar lets you view just your starred titles.
- **About modal** — A new info button in the title bar opens an about overlay showing addon and author information.
- **Rarity info popup** — A `?` button in the rarity card opens a small popup explaining how rarity percentages are estimated.
- **Faction badges on list rows** — Alliance and Horde faction badges now appear as small overlay icons on the rarity gem in the title list, matching the tint scheme used in the detail panel (gold for Alliance, red for Horde).
- **Dev scripts** — Added `link-release.ps1`, `link-ptr.ps1`, `unlink-release.ps1`, and `unlink-ptr.ps1` PowerShell scripts for symlinking dist packages into WoW for independent local testing before a CurseForge push.

### Changed

- **Faction icons** — Replaced the old placeholder faction icons (which carried attribution requirements) with new custom cutout versions. Alliance is tinted gold; Horde is tinted red.
- **Title list meta row** — Each row in the title list now shows a third line with expansion and category (e.g. "The War Within · PvP Rank"), making it easier to scan the list without opening the detail panel.
- **Source card descriptions** — The detail panel source card now shows richer contextual descriptions for achievement-, quest-, and item-sourced titles, and the obtainability reason is displayed below the unobtainable/feat-of-strength banner when present.
- **Sort: favourites bubble up** — Within the earned group in "Collected First" sort mode, favourited titles are sorted above non-favourited ones.

---

## [1.0.0] [1.0.1] - Initial Release

### Added

- Initial project setup and structure
