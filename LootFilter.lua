LootFilterVars = {
	silent = false,
};


LootFilter = {
	VERSION = GetAddOnMetadata("LootFilter", "X-Version"),
	LOOT_TIMEOUT = 30,
	LOOT_PARSE_DELAY = 0.5,
	LOOT_MAXTIME = 0,
	SCHEDULE_INTERVAL = 0.5,
	SELL_INTERVAL = 0.3,
	SELL_TIMEOUT = 30,
	SELL_ITEM_TIMEOUT = 10,
	SELL_QUEUE = 5,
	REALMPLAYER = "",

	filterScheduled = false,
	hasFocus = 0,
	cleanList = {},
	marketValue = false,

	-- Loot bot compatibility: track bag contents to detect new items
	bagSnapshot = {},
	bagUpdatePending = false,
	lootWindowOpen = false,
	autoSellActive = false,
	BAG_UPDATE_DELAY = 2.0, -- Delay before processing bag updates (allows multiple items to arrive)
};
