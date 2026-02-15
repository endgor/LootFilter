function LootFilter.processItemStack()
	if LootFilter.inDialog then
		LootFilter.schedule(LootFilter.SCHEDULE_INTERVAL, LootFilter.processItemStack);
		return;
	end
	if (table.getn(LootFilterVars[LootFilter.REALMPLAYER].itemStack) == 0) then
		if LootFilterVars[LootFilter.REALMPLAYER].caching then
			LootFilter.schedule(LootFilter.LOOT_PARSE_DELAY, LootFilter.processCaching);
		else
			LootFilter.filterScheduled = false;
		end
		return;
	end;

	if (GetTime() > LootFilter.LOOT_MAXTIME) then
		LootFilterVars[LootFilter.REALMPLAYER].itemStack = {};
		LootFilter.filterScheduled = false;
		return;
	end;

	local item = LootFilterVars[LootFilter.REALMPLAYER].itemStack[1];
	LootFilter.debug("|cffffffcc[PROCESS]|r Processing item: " ..
		tostring(item["name"]) .. " (id=" .. tostring(item["id"]) .. ") " .. tostring(item["link"]));

	item = LootFilter.findItemInBags(item);
	LootFilter.debug("|cffffffcc[PROCESS]|r findItemInBags result: bag=" ..
		tostring(item["bag"]) .. " slot=" .. tostring(item["slot"]));

	if (item["bag"] ~= -1) then
		item["amount"] = LootFilter.getStackSizeOfItem(item);
		LootFilter.ensureItemValue(item);
		LootFilter.refreshItemInfoFromBag(item);
		LootFilter.AddQuestItemToKeepList(item);
		LootFilter.removeAutoQuestKeepsForDeleteOverride(item);
		local action, reason = LootFilter.evaluateItem(item);
		LootFilter.debug("|cffffffcc[PROCESS]|r evaluateItem => " ..
			tostring(action) .. ": " .. tostring(reason));

		if (action == "delete") then
			if (LootFilter.deleteItemFromBag(item)) then
				LootFilter.debug("|cffffffcc[PROCESS]|r deleteItemFromBag => |cff00ff00SUCCESS|r");
				if (LootFilterVars[LootFilter.REALMPLAYER].notifydelete) and (not LootFilterVars[LootFilter.REALMPLAYER].silent) then
					LootFilter.print(item["link"] ..
						" " .. LootFilter.Locale.LocText["LTWasDeleted"] .. ": " .. reason);
				end;
				table.remove(LootFilterVars[LootFilter.REALMPLAYER].itemStack, 1);
			else
				LootFilter.debug(
					"|cffffffcc[PROCESS]|r deleteItemFromBag => |cffff0000FAILED|r, cycling item to back of stack");
				if (table.getn(LootFilterVars[LootFilter.REALMPLAYER].itemStack) > 1) then
					table.insert(LootFilterVars[LootFilter.REALMPLAYER].itemStack, item);
					table.remove(LootFilterVars[LootFilter.REALMPLAYER].itemStack, 1);
				end;
			end;
		elseif (action == "keep") then
			if (LootFilterVars[LootFilter.REALMPLAYER].notifykeep) and (not LootFilterVars[LootFilter.REALMPLAYER].silent) then
				LootFilter.print(item["link"] .. " " .. LootFilter.Locale.LocText["LTKept"] .. ": " .. reason);
			end;
			table.remove(LootFilterVars[LootFilter.REALMPLAYER].itemStack, 1);
		else
			-- No matching criteria
			if (LootFilterVars[LootFilter.REALMPLAYER].notifynomatch) and (not LootFilterVars[LootFilter.REALMPLAYER].silent) then
				LootFilter.print(item["link"] ..
					" " ..
					LootFilter.Locale.LocText["LTKept"] ..
					": " .. LootFilter.Locale.LocText["LTNoMatchingCriteria"]);
			end;
			table.remove(LootFilterVars[LootFilter.REALMPLAYER].itemStack, 1);
		end;
	else
		LootFilter.debug("|cffffffcc[PROCESS]|r Item not found in bags, removing from queue: " .. tostring(item["name"]));
		table.remove(LootFilterVars[LootFilter.REALMPLAYER].itemStack, 1);
	end;
	LootFilter.schedule(LootFilter.SCHEDULE_INTERVAL, LootFilter.processItemStack);
end;
