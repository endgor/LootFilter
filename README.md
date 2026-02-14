LOOT FILTER - PROJECT EBONHOLD - WoW WotLK 3.3.5a
=====================================
> **IMPORTANT:** If you get errors after updating this addon, it may be because
> old saved variables are in an outdated format. To fix this, delete (or move as
> a backup) `LootFilter.lua` and `LootFilter.lua.bak` from:
> `<WoW directory>\WTF\Account\<account ID>\<realm>\<character>\SavedVariables\`

A rewrite of the classic LootFilter addon, now compatible with the Scavenger companion (works fine without it too).

Automatically filter, delete, or sell looted items based on quality, type, value, or name patterns.


INSTALLATION
------------
Place the addon folder in your WoW AddOns directory. The folder **must** be
named `LootFilter`:

  `<WoW directory>\Interface\AddOns\LootFilter\`

Vendor prices work out of the box — no extra price addon required.


COMMANDS
--------
  **/lf**              Open/close options window
  **/lf lootbot**      Toggle loot bot mode
  **/lf silence**      Toggle silence mode (suppress chat messages)
  **/lf debug**        Toggle debug logging
  **/lf status**       Show addon status
  **/lf help**         Show commands

QUICK START
-----------
1. Type `/lf` to open options
2. Enable "Loot Filter" on the General tab
3. Use tabs to configure filters:
   - **Quality**: Filter by rarity (Grey through Legendary)
   - **Type**: Filter by item type and subtype (Armor, Weapon, etc.)
   - **Name**: Keep/delete specific items by name pattern
   - **Value**: Filter by vendor price thresholds
   - **Clean**: Sell or delete filtered items at a glance
   - **Copy**: Copy settings between characters
4. For each quality/type filter choose: Default / Keep / Delete


FILTER PRIORITY
---------------
Filters are evaluated in this order — first match wins:

  1. **Keep Names** — always kept
  2. **Delete Names** — always deleted
  3. **Keep Properties** — quality, type, or value rules that keep
  4. **Delete Properties** — quality, type, or value rules that delete
  5. **No Match** — kept by default

Name filters always beat property filters. So you can set broad rules
like "delete all Grey items" and still keep a specific grey item by name.


GENERAL TAB
-----------
The General tab has the master enable toggle plus settings for:

- **Scavenger Loot Filter** — Loot bot mode for auto-looting companions
  (see Loot Bot Mode below)
- **Loot Caching** — Auto-delete lowest-value items when bags get full
- **Confirm item delete** — Require confirmation before destroying items
- **Notification toggles** — Control which chat messages appear
  (delete, keep, no match, container open, new version)
- **Vendor behavior** — Auto-open at vendor, auto-sell filtered items
- **Bag selection** — Choose which bags (Backpack, Bag 1–4) are filtered


QUALITY & TYPE FILTERING
------------------------
**Quality tab:** Set each rarity tier (Poor through Legendary, plus
Heirloom and Quest) to Default / Keep / Delete.

**Type tab:** Pick an item type from the dropdown (Armor, Weapon,
Consumable, Gem, Recipe, Trade Goods, etc.) then set each subtype to
Default / Keep / Delete.

Quest items are automatically kept when looted — see Quest Auto-Keep below.


NAME PATTERNS
-------------
The Name tab has two text boxes: one for **keep**, one for **delete**.
Enter one pattern per line.

| Syntax | Meaning | Example |
|--------|---------|---------|
| `Item Name` | Exact match (case-insensitive) | `Silk Cloth` |
| `*text` | Ends with | `*Ore` |
| `text*` | Starts with | `Rugged*` |
| `*text*` | Contains | `*Leather*` |
| `#pattern` | Lua regex on item name | `#^Heavy.*Leather$` |
| `##pattern` | Lua regex on tooltip text | `##Soulbound` |

Add comments with a semicolon: `Rugged Leather ; for crafting`

The default keep list includes `Hearthstone` so it is never filtered.


VALUE FILTERING
---------------
Set gold thresholds on the Value tab:

- **Keep items worth more than X gold** (e.g. `0.5` = 50 silver)
- **Delete items worth less than X gold** (e.g. `0.1` = 10 silver)

A dropdown controls how value is calculated: per single item, per current
stack, or per max stack size (default).

On the General tab you can also enable:
- **Auctioneer market prices** — Use market value instead of vendor price
  (requires AucAdvanced addon)
- **Keep items with no (known) value** — Prevent filtering items with no
  price data

The **free bag slots** field sets how many slots to keep open when loot
caching is enabled.


CLEAN TAB
---------
Shows all bag items that match a delete rule.

- At a vendor the button says **Sell Items** — at all other times it says
  **Delete Items**
- **Shift-click** any item in the list to quick-add it to your keep list
- Session stats at the bottom track items filtered, total value, and
  value per hour


LOOT BOT MODE
--------------
Toggle with `/lf lootbot` or the General tab checkbox.

Normally the addon only filters items you loot through a loot window.
Loot bot mode also monitors your bags for items that appear without one —
designed for the Scavenger companion, but works with any source.

When enabled, a bag snapshot is taken. New items are detected and filtered
automatically. Monitoring pauses while loot, vendor, mail, trade, or
auction windows are open to avoid false positives.

Toggle it on when using a companion and off when you are done.


SILENCE MODE
------------
`/lf silence` — Suppresses all filter chat messages. The addon keeps
filtering, it just does so quietly.


COPY SETTINGS
-------------
The Copy tab lets you copy a character's entire configuration to your
current character, or delete another character's saved settings.


QUEST AUTO-KEEP
---------------
Quest items are automatically added to your keep list when looted. If a
quest item also matches a delete rule, the delete rule wins and the
auto-keep entry is removed.


LOCALIZATION
------------
Available in English, German, Spanish, French, Simplified Chinese, and
Traditional Chinese. Selected automatically based on your WoW client locale.


CREDITS
-------
Original addon by Meter: https://warperia.com/addon-wotlk/loot-filter/
