NOTE: Version restarted from 1.0 due to extensive custom changes for Project Ebonhold.

v1.0.7:
Added manual name filter priority override - manual keep/delete name entries now take precedence over all quality/type/value filters.
Restructured filter priority chain: Keep Names -> Delete Names -> Keep Properties -> Delete Properties -> No Match.
Applied the same priority chain to constructCleanList so clean/sell/caching paths are consistent with loot processing.
All existing name matching patterns (#, ##, exact) remain fully supported.

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