NOTE: Version restarted from 1.0 due to extensive custom changes for Project Ebonhold.

v2.0.2:
- Item Type is now higher priority than Quality.
- Keep Cloth + Delete Common = Cloth is kept, all other Common items deleted.
- Delete Shield + Keep Epic = Shields are deleted, all other Epics kept.

v2.0.1:
Added Miscellaneous > Mount item type to the Filters tab (all locales).

v2.0.0:
Rewrote UI with new tabbed layout, sidebar navigation, and streamlined options.
Replaced quality filter chips with Keep/Del checkbox layout.
Reworked filter evaluation into sequential override chain (Quality -> Type -> Value, last match wins).
Rewrote caching mode to respect filter rules instead of blindly deleting cheapest items.
Caching now only deletes items that match a delete rule; keep and no-match items are never deleted.
Fixed name tab scrollbar jumping unexpectedly when editing.
Fixed silver/copper breakdown display in Clean tab using math.floor instead of string.sub.

v1.0.12:
Guard against accidental cursor item deletion during auto-delete.
Revalidate item link in confirm-delete popup to prevent deleting wrong item after inventory shift.

v1.0.11:
Added Scavenger Loot Filter toggle to General tab UI.
Fixed safety checks for filtering, deletion, and item lookup.
Rescan tooltip from bag slot for accurate bound-state info.
Limit loot bot to only process new items added to bags.

v1.0.10:
Restored silence mode after reverts.
Added silence mode to /lf status and /lf help output.

v1.0.9:
Added /lf silence command to suppress filter chat messages.
Added wildcard (*) pattern matching for item name filters.

v1.0.8:
Fixed confirm-delete dialog callbacks ignoring button clicks.
Fixed copySettings creating shallow reference instead of deep copy.
Fixed 4 global variable leaks polluting the namespace.
Fixed scheduler coroutine never recovering after an error.
Hardened scheduler recovery by dropping failed tasks.
Fixed setItemValue storing string "0" instead of number 0.
Fixed nil crash in sortByValue comparator.
Replaced seterrorhandler with pcall in matchItemNames.
Validated item position before selling at vendor.
Stored item values as copper integers to avoid float precision loss.
Added installation path and saved variables reset instructions to README.

v1.0.7:
Added manual name filter priority override - keep/delete name entries now take precedence over all quality/type/value filters.
Restructured filter priority chain: Keep Names -> Delete Names -> Keep Properties -> Delete Properties -> No Match.
Applied the same priority chain to constructCleanList so clean/sell/caching paths are consistent with loot processing.

v1.0.6:
Fixed infinite loop when item not found in bags.

v1.0.5:
Added Hearthstone to default keep list for new characters.

v1.0.4:
Added Glyph type filtering support.

v1.0.3:
Fixed confirm-delete popup handling and scheduler queue recovery.
Fixed multiple critical bugs found in static review.
Cleaned up codebase and removed unnecessary comments.

v1.0.2:
Added /lf debug command with diagnostic logging.

v1.0.1:
Fixed duplicate item processing when loot bot mode is active.
Fixed scheduler yield logic.
Fixed container slot loops starting at 0 instead of 1.
Fixed global variable leaks across multiple files.
Fixed double removal in deleteItems delete path.
Fixed guild message never sending.
Added REALMPLAYER guard to OnEvent and report functions.
