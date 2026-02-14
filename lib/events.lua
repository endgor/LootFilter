local function collectBagState()
	local state = {
		slots = {},
		totals = {},
	};
	if LootFilter.REALMPLAYER == "" or not LootFilterVars[LootFilter.REALMPLAYER] or not LootFilterVars[LootFilter.REALMPLAYER].openbag then
		return state;
	end

	for bag = 0, 4 do
		if LootFilterVars[LootFilter.REALMPLAYER].openbag[bag] then
			local numSlots = GetContainerNumSlots(bag);
			for slot = 1, numSlots do
				local link = GetContainerItemLink(bag, slot);
				if link then
					local key = bag .. ":" .. slot;
					local id = LootFilter.getIdOfItem(link);
					local rawCount = select(2, GetContainerItemInfo(bag, slot));
					local count = (rawCount and rawCount > 0) and rawCount or 1;
					state.slots[key] = {
						link = link,
						id = id,
						count = count,
						bag = bag,
						slot = slot,
					};
					if id and id > 0 then
						state.totals[id] = (state.totals[id] or 0) + count;
					end
				end
			end
		end
	end
	return state;
end

function LootFilter.takeBagSnapshot()
	LootFilter.bagSnapshot = collectBagState();
end

function LootFilter.findNewItemsInBags()
	local newItems = {};
	local oldState = LootFilter.bagSnapshot or { slots = {}, totals = {} };
	local currentState = collectBagState();

	for id, currentTotal in pairs(currentState.totals) do
		local oldTotal = oldState.totals[id] or 0;
		local delta = currentTotal - oldTotal;
		if delta > 0 then
			local candidates = {};
			for key, slotState in pairs(currentState.slots) do
				if slotState.id == id then
					local oldSlot = oldState.slots[key];
					local oldCount = 0;
					if oldSlot and oldSlot.id == id then
						oldCount = oldSlot.count or 0;
					end
					local increase = slotState.count - oldCount;
					if increase > 0 then
						table.insert(candidates, { slot = slotState, increase = increase });
					end
				end
			end

			table.sort(candidates, function(a, b)
				if a.slot.bag ~= b.slot.bag then
					return a.slot.bag < b.slot.bag;
				end
				return a.slot.slot < b.slot.slot;
			end);

			for _, candidate in ipairs(candidates) do
				if delta <= 0 then
					break;
				end
				local addCount = math.min(delta, candidate.increase);
				local item = LootFilter.getBasicItemInfo(candidate.slot.link);
				if item then
					item["bag"] = candidate.slot.bag;
					item["slot"] = candidate.slot.slot;
					item["amount"] = candidate.slot.count;
					item["deleteCount"] = addCount;
					table.insert(newItems, item);
				end
				delta = delta - addCount;
			end

			if delta > 0 then
				for _, candidate in ipairs(candidates) do
					local item = LootFilter.getBasicItemInfo(candidate.slot.link);
					if item then
						item["bag"] = candidate.slot.bag;
						item["slot"] = candidate.slot.slot;
						item["amount"] = candidate.slot.count;
						item["deleteCount"] = delta;
						table.insert(newItems, item);
						delta = 0;
						break;
					end
				end
			end
		end
	end

	return newItems, currentState;
end

function LootFilter.processBagUpdate()
	if not LootFilterVars[LootFilter.REALMPLAYER].lootbotmode then
		LootFilter.bagUpdatePending = false;
		return;
	end
	if not LootFilterVars[LootFilter.REALMPLAYER].enabled then
		LootFilter.bagUpdatePending = false;
		return;
	end
	if LootFilter.lootWindowOpen then
		LootFilter.bagUpdatePending = false;
		return;
	end
	if not LootFilter.lootbotPrimed then
		LootFilter.takeBagSnapshot();
		LootFilter.lootbotPrimed = true;
		LootFilter.bagUpdatePending = false;
		return;
	end

	local newItems, currentState = LootFilter.findNewItemsInBags();
	LootFilter.debug("|cff44ff44[LOOTBOT]|r BAG_UPDATE detected " .. tostring(table.getn(newItems)) .. " new item(s)");

	for _, item in ipairs(newItems) do
		LootFilter.debug("|cff44ff44[LOOTBOT]|r New item: " .. tostring(item["name"]) .. " (id=" .. tostring(item["id"]) .. ") bag=" .. tostring(item["bag"]) .. " slot=" .. tostring(item["slot"]));
		table.insert(LootFilterVars[LootFilter.REALMPLAYER].itemStack, item);

		if GetSellValue then
			LootFilter.sessionAdd(item);
			LootFilterVars[LootFilter.REALMPLAYER].session["end"] = time();
			LootFilter.sessionUpdateValues();
		end
	end

	LootFilter.bagSnapshot = currentState;

	if table.getn(LootFilterVars[LootFilter.REALMPLAYER].itemStack) > 0 then
		LootFilter.LOOT_MAXTIME = GetTime() + LootFilter.LOOT_TIMEOUT;
		if LootFilterVars[LootFilter.REALMPLAYER].caching then
			LootFilterVars[LootFilter.REALMPLAYER].itemStack = {};
			if not LootFilter.isScheduled(LootFilter.processCaching) then
				LootFilter.schedule(LootFilter.LOOT_PARSE_DELAY, LootFilter.processCaching);
			end
		else
			if not LootFilter.isScheduled(LootFilter.processItemStack) then
				LootFilter.schedule(LootFilter.LOOT_PARSE_DELAY, LootFilter.processItemStack);
			end
		end
	end

	LootFilter.bagUpdatePending = false;
end

function LootFilter.OnEvent()
	if (event == "BAG_UPDATE") then
		if LootFilterVars[LootFilter.REALMPLAYER] and LootFilterVars[LootFilter.REALMPLAYER].lootbotmode and LootFilterVars[LootFilter.REALMPLAYER].enabled then
			-- Skip BAG_UPDATE while a loot window is open; LOOT_OPENED handles those items
			if LootFilter.lootWindowOpen then
				return;
			end
			-- Safety: prime from the first real bag state and skip processing to avoid mass false positives on login/reload.
			if not LootFilter.lootbotPrimed then
				LootFilter.takeBagSnapshot();
				LootFilter.lootbotPrimed = true;
				LootFilter.debug("|cff44ff44[LOOTBOT]|r Primed bag snapshot, skipping first BAG_UPDATE processing");
				return;
			end
			-- Debounce: only schedule one update even if multiple bags change
			if not LootFilter.bagUpdatePending then
				LootFilter.bagUpdatePending = true;
				LootFilter.schedule(LootFilter.BAG_UPDATE_DELAY, LootFilter.processBagUpdate);
			end
		end
		return;
	end

	if (event == "RAID_ROSTER_UPDATE") then
		if (LootFilter.versionUpdate == false) then
			LootFilter.versionUpdate = true;
			LootFilter.schedule(60, LootFilter.sendAddonMessage, "VERSION:"..LootFilter.newVersion, 2);
		end;
		return;
	end;

	if LootFilter.REALMPLAYER == "" or not LootFilterVars[LootFilter.REALMPLAYER] then
		if event == "ADDON_LOADED" and arg1 == "LootFilter" then
			-- Allow ADDON_LOADED to proceed (it does the initialization)
		else
			return;
		end
	end

	if (event == "CHAT_MSG_ADDON") then
		if (arg1 == "LootFilter") then
			local name = string.match(arg2, "(%a+):");
			local version = string.match(arg2, ":(.*)");
			if (name == "VERSION") then
				if (((arg3 == "RAID") or (arg3 == "PARTY")) and (LootFilter.versionUpdate == true)) then
					LootFilter.versionUpdate = false;
				end;
				if (tonumber(version) ~= nil) and (tonumber(LootFilter.newVersion) ~= nil) then
					if (tonumber(version) > tonumber(LootFilter.newVersion)) then
						LootFilter.newVersion = version;
						if (LootFilterVars[LootFilter.REALMPLAYER].notifynew) then
							LootFilter.print(LootFilter.Locale.LocText["LTNewVersion1"].." ("..version..") "..LootFilter.Locale.LocText["LTNewVersion2"]);
						end;
					end;
				end;
			end;
		end;
		return;
	end;

	if (event == "UNIT_SPELLCAST_START") then
		LootFilter.spellCast = true;
	end;
	if (event == "UNIT_SPELLCAST_STOP") then
		LootFilter.spellCast = false;
	end;

	if (event == "UI_INFO_MESSAGE") then
		local questDeleteEnabled = false;
		for key, value in pairs(LootFilterVars[LootFilter.REALMPLAYER].deleteList) do
			if (string.match(key, "^QU")) and (tonumber(value) == -1) then
				questDeleteEnabled = true;
				break;
			end;
		end;
		if (not questDeleteEnabled) then
			if (string.find(arg1, "slain: ") ~= nil) and (string.find(arg1, "slain: ") > 0) then
				return;
			end;
			local itemName = gsub(arg1,"(.*): %s*([-%d]+)%s*/%s*([-%d]+)%s*$","%1",1);
			if (itemName ~= arg1) then
				local item = {};
				item["name"] = itemName;
				for index, name in pairs(LootFilterVars[LootFilter.REALMPLAYER].keepList["names"]) do
					if (LootFilter.matchItemNames(item, name)) then
						return;
					end;
				end;

				for index, item in pairs(LootFilterVars[LootFilter.REALMPLAYER].itemStack) do
					local name = item["name"];
					if (string.lower(name) == string.lower(itemName)) then
						table.remove(LootFilterVars[LootFilter.REALMPLAYER].itemStack, index);
						if (LootFilterVars[LootFilter.REALMPLAYER].notifykeep) then
							LootFilter.print(item["link"].." "..LootFilter.Locale.LocText["LTKept"]..": "..LootFilter.Locale.LocText["LTQuestItem"]);
						end;
						local _, _, _, _, _, itemType, itemSubType = GetItemInfo(item["id"]);
						local questTypeText = string.lower(tostring(LootFilter.Locale.LocText["LTQuest"] or ""));
						if (string.lower(tostring(itemType or "")) ~= questTypeText) and (string.lower(tostring(itemSubType or "")) ~= questTypeText) then
							table.insert(LootFilterVars[LootFilter.REALMPLAYER].keepList["names"], itemName.."  ; "..LootFilter.Locale.LocText["LTAddedCosQuest"]);
						end;
						return;
					end;
				end;
			end;
		end;
	end;
	
	if (event == "LOOT_OPENED") and (LootFilterVars[LootFilter.REALMPLAYER].enabled) then
		LootFilter.lootWindowOpen = true;
		-- Always snapshot before looting so we can resolve exact bag deltas at LOOT_CLOSED.
		LootFilter.takeBagSnapshot();
		local numitems= GetNumLootItems();
		for i = 1, numitems, 1 do
			if (not LootSlotIsCoin(i)) then
				local icon, name, quantity, quality= GetLootSlotInfo(i);
				if (icon ~= nil) then
						local item = LootFilter.getBasicItemInfo(GetLootSlotLink(i));
					if (item ~= nil) then
						LootFilter.debug("|cff44ff44[LOOT]|r Loot window item: " .. tostring(item["name"]) .. " (id=" .. tostring(item["id"]) .. ") " .. tostring(item["link"]));
						if (GetSellValue) then -- record the value of this item
							LootFilter.sessionAdd(item);
							LootFilterVars[LootFilter.REALMPLAYER].session["end"] = time();
							LootFilter.sessionUpdateValues();
						end;
					end;
				end;
			end;
		end;
	end;

	if (event == "LOOT_CLOSED") and (LootFilterVars[LootFilter.REALMPLAYER].enabled) then
		LootFilter.lootWindowOpen = false;
		local newItems, currentState = LootFilter.findNewItemsInBags();
		for _, item in ipairs(newItems) do
			table.insert(LootFilterVars[LootFilter.REALMPLAYER].itemStack, item);
		end
		LootFilter.bagSnapshot = currentState;

		LootFilter.LOOT_MAXTIME = GetTime() + LootFilter.LOOT_TIMEOUT;
		LootFilter.itemOpen = false;
		if (LootFilterVars[LootFilter.REALMPLAYER].caching) then
			LootFilterVars[LootFilter.REALMPLAYER].itemStack = {};
			if not LootFilter.isScheduled(LootFilter.processCaching) then
				LootFilter.schedule(LootFilter.LOOT_PARSE_DELAY, LootFilter.processCaching);
			end
		else
			if not LootFilter.isScheduled(LootFilter.processItemStack) then
				LootFilter.schedule(LootFilter.LOOT_PARSE_DELAY, LootFilter.processItemStack);
			end
		end;
	end;

	if (event == "ITEM_LOCK_CHANGED") then
		if (LootFilter.hasFocus > 0) then
			itemName= LootFilter.findItemWithLock();
			if (itemName ~= nil) and (itemName ~= "") then
				if (LootFilter.hasFocus == 1) then
					LootFilterEditBox1:SetText(LootFilterEditBox1:GetText()..itemName.."\n");
				elseif (LootFilter.hasFocus == 2) then
					LootFilterEditBox2:SetText(LootFilterEditBox2:GetText()..itemName.."\n");
				end;
			end;
		end;
	end;

	if (event == "MERCHANT_CLOSED") then
		LootFilterButtonDeleteItems:SetText(LootFilter.Locale.LocText["LTDeleteItems"]);
	end;

	if (event == "MERCHANT_SHOW") then
		LootFilterButtonDeleteItems:SetText(LootFilter.Locale.LocText["LTSellItems"]);
		LootFilter.processCleaning();
		if (table.getn(LootFilter.cleanList) > 0) then
			if (LootFilterVars[LootFilter.REALMPLAYER].openvendor) then
				LootFilterOptions:Show();
			end;
			if (LootFilterVars[LootFilter.REALMPLAYER].autosell) then
				LootFilter.iWantTo();
				LootFilter.sellQueue = 1;
				LootFilter.deleteItems(GetTime() + LootFilter.LOOT_TIMEOUT, false);
			end;			
			LootFilter.selectButton(LootFilterButtonClean, LootFilterFrameClean); 
		end;
	end;

	if (event == "ADDON_LOADED") then

		if (arg1 == "LootFilter") then
			
			LootFilter.REALMPLAYER= GetCVar("realmName") .. " - " ..UnitName("player");
			if (LootFilterVars[LootFilter.REALMPLAYER] == nil) then
				LootFilterVars[LootFilter.REALMPLAYER]= {};
			end;
			if (LootFilterVars[LootFilter.REALMPLAYER].openList == nil) then
				LootFilterVars[LootFilter.REALMPLAYER].openList= {};
			end;
			if (LootFilterVars[LootFilter.REALMPLAYER].keepList == nil) then
				LootFilterVars[LootFilter.REALMPLAYER].keepList= {};
			end;
			if (LootFilterVars[LootFilter.REALMPLAYER].keepList["names"] == nil) then
				LootFilterVars[LootFilter.REALMPLAYER].keepList["names"] = {
					"Hearthstone",
				};
			end;
			if (LootFilterVars[LootFilter.REALMPLAYER].deleteList == nil) then
				LootFilterVars[LootFilter.REALMPLAYER].deleteList= {};
			end;
			if (LootFilterVars[LootFilter.REALMPLAYER].deleteList["names"] == nil) then
				LootFilterVars[LootFilter.REALMPLAYER].deleteList["names"] = {};
			end;
			if (LootFilterVars[LootFilter.REALMPLAYER].itemStack == nil) then
				LootFilterVars[LootFilter.REALMPLAYER].itemStack= {};
			end;
			if (LootFilterVars[LootFilter.REALMPLAYER].enabled == nil) then
				LootFilterVars[LootFilter.REALMPLAYER].enabled= true;
			end;
			if (LootFilterVars[LootFilter.REALMPLAYER].debug == nil) then
				LootFilterVars[LootFilter.REALMPLAYER].debug = false;
			end;
			if (LootFilterVars[LootFilter.REALMPLAYER].tooltips == nil) then
				LootFilterVars[LootFilter.REALMPLAYER].tooltips= true;
			end;
			if (LootFilterVars[LootFilter.REALMPLAYER].notifydelete == nil) then
				LootFilterVars[LootFilter.REALMPLAYER].notifydelete= true;
			end;
			if (LootFilterVars[LootFilter.REALMPLAYER].notifykeep == nil) then
				LootFilterVars[LootFilter.REALMPLAYER].notifykeep= true;
			end;
			if (LootFilterVars[LootFilter.REALMPLAYER].notifynomatch == nil) then
				LootFilterVars[LootFilter.REALMPLAYER].notifynomatch= true;
			end;
			if (LootFilterVars[LootFilter.REALMPLAYER].notifyopen == nil) then
				LootFilterVars[LootFilter.REALMPLAYER].notifyopen= true;
			end;
			if (LootFilterVars[LootFilter.REALMPLAYER].notifynew == nil) then
				LootFilterVars[LootFilter.REALMPLAYER].notifynew= true;
			end;
			if (LootFilterVars[LootFilter.REALMPLAYER].caching == nil) then
				LootFilterVars[LootFilter.REALMPLAYER].caching= false;
			end;
			if (LootFilterVars[LootFilter.REALMPLAYER].novalue == nil) then
				LootFilterVars[LootFilter.REALMPLAYER].novalue= false;
			end;
			if (LootFilterVars[LootFilter.REALMPLAYER].marketvalue == nil) then
				LootFilterVars[LootFilter.REALMPLAYER].marketvalue= false;
			end;			
			if (LootFilterVars[LootFilter.REALMPLAYER].calculate == nil) then
				LootFilterVars[LootFilter.REALMPLAYER].calculate= 3;
			end;							
			if (LootFilterVars[LootFilter.REALMPLAYER].freebagslots == nil) then
				LootFilterVars[LootFilter.REALMPLAYER].freebagslots= 5;
			end;
			if (LootFilterVars[LootFilter.REALMPLAYER].openvendor == nil) then
				LootFilterVars[LootFilter.REALMPLAYER].openvendor= true;
			end;
			if (LootFilterVars[LootFilter.REALMPLAYER].autosell == nil) then
				LootFilterVars[LootFilter.REALMPLAYER].autosell= false;
			end;			
			if (LootFilterVars[LootFilter.REALMPLAYER].openbag == nil) then
				LootFilterVars[LootFilter.REALMPLAYER].openbag= {};
			end;
			if (LootFilterVars[LootFilter.REALMPLAYER].openbag[0] == nil) then
				LootFilterVars[LootFilter.REALMPLAYER].openbag[0]= true;
			end;
			if (LootFilterVars[LootFilter.REALMPLAYER].openbag[1] == nil) then
				LootFilterVars[LootFilter.REALMPLAYER].openbag[1]= true;
			end;
			if (LootFilterVars[LootFilter.REALMPLAYER].openbag[2] == nil) then
				LootFilterVars[LootFilter.REALMPLAYER].openbag[2]= true;
			end;
			if (LootFilterVars[LootFilter.REALMPLAYER].openbag[3] == nil) then
				LootFilterVars[LootFilter.REALMPLAYER].openbag[3]= true;
			end;
			if (LootFilterVars[LootFilter.REALMPLAYER].openbag[4] == nil) then
				LootFilterVars[LootFilter.REALMPLAYER].openbag[4]= true;
			end;
			if (LootFilterVars[LootFilter.REALMPLAYER].confirmdel == nil) then
				LootFilterVars[LootFilter.REALMPLAYER].confirmdel= false;
			end
			if (LootFilterVars[LootFilter.REALMPLAYER].session == nil) then
				LootFilter.sessionReset();
			end;
			if (LootFilterVars[LootFilter.REALMPLAYER].lootbotmode == nil) then
				LootFilterVars[LootFilter.REALMPLAYER].lootbotmode = false;
			end;

			LootFilter.takeBagSnapshot();
			LootFilter.lootbotPrimed = false;

			LootFilterButtonGeneral:LockHighlight();
			LootFilter.setTitle();
			LootFilter.getNames();
			LootFilter.getNamesDelete();
			LootFilter.getItemValue();
			LootFilter.versionUpdate = false;

			LootFilter.initCopyTab();
			
			LootFilter.initTypeTab();
			LootFilter.initQualityTab();			
			UIDropDownMenu_Initialize(LootFilterSelectDropDownType, LootFilter.SelectDropDownType_Initialize);
			UIDropDownMenu_Initialize(LootFilterSelectDropDownCalculate, LootFilter.SelectDropDownCalculate_Initialize);
			LootFilter.SelectDropDown_Initialize();
			
			
			-- The following was added because GetSellValue is not always available when addons load
			-- GetItemPriceTooltip (uses Ace2) for example loads its GetSellValue when it is enable (after it has been loaded...) 
			LootFilter.schedule(2, LootFilter.checkDependencies);
		end;
	
		LootFilter.checkDependencies();
	
	end;
end;



function LootFilter.OnLoad()
	SLASH_LOOTFILTER1= "/lootfilter";
	SLASH_LOOTFILTER2= "/lf";
	SLASH_LOOTFILTER3= "/lfr";
	SlashCmdList["LOOTFILTER"] = LootFilter.command;

	this:RegisterEvent("LOOT_OPENED");
	this:RegisterEvent("LOOT_CLOSED");
	this:RegisterEvent("ADDON_LOADED");
	this:RegisterEvent("ITEM_LOCK_CHANGED");
	this:RegisterEvent("UI_INFO_MESSAGE");
	this:RegisterEvent("UNIT_SPELLCAST_START");
	this:RegisterEvent("UNIT_SPELLCAST_STOP");
	this:RegisterEvent("MERCHANT_CLOSED");
	this:RegisterEvent("MERCHANT_SHOW");
	this:RegisterEvent("CHAT_MSG_ADDON");
	this:RegisterEvent("RAID_ROSTER_UPDATE");
	this:RegisterEvent("VARIABLES_LOADED");
	this:RegisterEvent("BAG_UPDATE");
	LootFilter.newVersion = LootFilter.VERSION;
	LootFilter.schedule(5, LootFilter.sendAddonMessage, "VERSION:"..LootFilter.newVersion, 1);
end;
