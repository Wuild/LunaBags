# LunaBags Agent Guide

This file is for coding agents working on this addon.

## Project shape

- Addon: `LunaBags` (WoW Classic/Anniversary UI)
- Entry + defaults: `LunaBags.lua`
- Addon file loader: `LunaBags.xml`
- Defaults: `core/configs.lua`
- Shared addon helpers: `core/methods.lua`
- Blizzard frame integration: `core/blizzard.lua`
- Slash commands: `core/commands.lua`
- Runtime event handlers: `core/events.lua`
- Blizzard bag hook layer: `core/hooks.lua`
- Sorting engine: `core/sort.lua`
- Plugin system: `core/plugins.lua`
- Built-in plugins: `plugins/*.lua`
- Persistent bag cache per character: `data/bags.lua`
- OneBag UI + runtime behavior: `ui/onebag.lua` (+ `ui/onebag.xml`)
- OneBank UI: `ui/onebank.lua` (+ `ui/onebank.xml`)
- Options UI (AceConfig): `core/settings.lua`

## Data model

- Saved variables root: `LunaBagsDB`
- Live config: `db.profile.*`
- Character cache: `db.global.characters`
- Character cache keys are `Name-Realm`.
- Bag/slot keys in saved tables may be numeric **or string** after serialization.
  Always support both:
  - `t[k]` and `t[tostring(k)]`

## Core behavior constraints

1. Preserve Blizzard item-button behavior.
   - Use `ContainerFrameItemButtonTemplate`.
   - Do not replace core item click logic unless absolutely necessary.
   - Prefer lock-mode overlays for special interactions.

2. Do not use unsupported script handlers on Classic templates.
   - `OnModifiedClick` can be unavailable on these buttons.
   - Handle modified clicks via `OnClick` path checks if needed.

3. Tooltip augmentation must be post-set.
   - Add custom item-count lines from `GameTooltip:HookScript("OnTooltipSetItem", ...)`.
   - Direct `OnEnter` additions may be overwritten by later tooltip refresh.

4. Sorting safety rules.
   - Respect user-locked slots.
   - Respect temporary runtime item locks (wait, don’t abort).
   - Respect specialty bag family compatibility.
   - Specialty bags are pre-filled first, then normal sort.

5. Character view mode is read-only.
   - If viewing non-current character, disable moving/using/splitting.
   - Render from `data/bags.lua` cache only.

## APIs/patterns to avoid

- Avoid:
  - `SetNormalTexture(nil)` on `UIPanelButtonTemplate` in this client (can error).
  - `EasyMenu` without fallback; some clients lack it.
- Use instead:
  - Dropdown fallback: `UIDropDownMenu_Initialize` + `ToggleDropDownMenu`
  - Safe texture handling with explicit texture paths

## UI layout notes

- OneBag layout is data-driven from `ui/onebag.lua`.
- Window height must be derived from final positioned slot geometry
  (not rough row estimates), because split sections add extra offsets.
- Keyring is currently rendered as a split section in the main window flow.

## Per-character settings currently scoped

- Split bag sections
- Locked slots

Do not reintroduce global fallback reads after migration, or old values will
appear to “override” current behavior.

## Test checklist before finishing

1. Open/close with `B` works.
2. Use item + drag/drop still works.
3. Sort runs to completion without getting stuck.
4. Specialty bag contents stay valid (e.g. ammo/quiver).
5. Lock mode:
   - overlay click toggles lock
   - red cross only in lock mode
6. Character view:
   - switch character shows cached items + money
   - read-only interactions
7. Tooltip:
   - item count per character + bank lines appear reliably
   - money bar tooltip shows total + per character.
