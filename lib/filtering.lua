function LootFilter.processItemStack()
	if LootFilter.inDialog then
		return;
	end
	if (table.getn(LootFilterVars[LootFilter.REALMPLAYER].itemStack) == 0) then
		return;
	end;

	if (GetTime() > LootFilter.LOOT_MAXTIME) then
		LootFilterVars[LootFilter.REALMPLAYER].itemStack = {};
		return;
	end;
		
	local item = LootFilterVars[LootFilter.REALMPLAYER].itemStack[1];
	LootFilter.debug("|cffffffcc[PROCESS]|r Processing item: " .. tostring(item["name"]) .. " (id=" .. tostring(item["id"]) .. ") " .. tostring(item["link"]));

	local hasDirectSlot = (item["bag"] ~= nil) and (item["slot"] ~= nil) and (item["bag"] >= 0) and (item["slot"] > 0);
	if hasDirectSlot then
		local link = GetContainerItemLink(item["bag"], item["slot"]);
		if (link ~= nil) then
			local currentId = LootFilter.getIdOfItem(link);
			if (item["id"] ~= nil) and (currentId ~= item["id"]) then
				item = LootFilter.findItemInBags(item);
			end;
		else
			item = LootFilter.findItemInBags(item);
		end;
	else
		item = LootFilter.findItemInBags(item);
	end;
	LootFilter.debug("|cffffffcc[PROCESS]|r findItemInBags result: bag=" .. tostring(item["bag"]) .. " slot=" .. tostring(item["slot"]));

	if (item["bag"] ~= -1) then
		item["amount"] = LootFilter.getStackSizeOfItem(item);
		LootFilter.ensureItemValue(item);
		local _, _, dbgRarity, _, _, dbgType, dbgSubType = GetItemInfo(item["id"]);
		LootFilter.debug("|cffffffcc[PROCESS]|r Item details: amount=" .. tostring(item["amount"]) .. " value=" .. tostring(item["value"]) .. " stack=" .. tostring(item["stack"]) .. " rarity=" .. tostring(dbgRarity) .. " type=" .. tostring(dbgType) .. " subType=" .. tostring(dbgSubType));

		local reason = LootFilter.matchDeleteNameProperties(item);
		LootFilter.debug("|cffffffcc[PROCESS]|r matchDeleteNameProperties => " .. (reason ~= "" and ("|cffff0000DELETE|r: " .. reason) or "no match"));
		local shouldDelete = (reason ~= "");

		if (not shouldDelete) then
			reason = LootFilter.matchKeepProperties(item);
			LootFilter.debug("|cffffffcc[PROCESS]|r matchKeepProperties => " .. (reason ~= "" and ("|cff00ff00KEPT|r: " .. reason) or "no match"));
		end;

		if (not shouldDelete) and (reason == "") then
			reason = LootFilter.matchDeleteProperties(item);
			LootFilter.debug("|cffffffcc[PROCESS]|r matchDeleteProperties => " .. (reason ~= "" and ("|cffff0000DELETE|r: " .. reason) or "no match"));
			shouldDelete = (reason ~= "");
		end;

		if (shouldDelete) then
			if (LootFilter.deleteItemFromBag(item)) then
				LootFilter.debug("|cffffffcc[PROCESS]|r deleteItemFromBag => |cff00ff00SUCCESS|r");
				if (LootFilterVars[LootFilter.REALMPLAYER].notifydelete) then
					LootFilter.print(item["link"].." "..LootFilter.Locale.LocText["LTWasDeleted"]..": "..reason);
					if (LootFilter.questUpdateToggle == 1) then
						LootFilter.lastDeleted = item["name"];
					end;
				end;
				table.remove(LootFilterVars[LootFilter.REALMPLAYER].itemStack, 1);
			else
				LootFilter.debug("|cffffffcc[PROCESS]|r deleteItemFromBag => |cffff0000FAILED|r, cycling item to back of stack");
				if (table.getn(LootFilterVars[LootFilter.REALMPLAYER].itemStack) > 1) then
					table.insert(LootFilterVars[LootFilter.REALMPLAYER].itemStack, item);
					table.remove(LootFilterVars[LootFilter.REALMPLAYER].itemStack, 1);
				end;
			end;
		elseif (reason ~= "") then
			if (LootFilterVars[LootFilter.REALMPLAYER].notifykeep) then
				LootFilter.print(item["link"].." "..LootFilter.Locale.LocText["LTKept"]..": "..reason);
			end;
			table.remove(LootFilterVars[LootFilter.REALMPLAYER].itemStack, 1);
		else
			if (LootFilterVars[LootFilter.REALMPLAYER].notifynomatch) then
				LootFilter.print(item["link"].." "..LootFilter.Locale.LocText["LTKept"]..": "..LootFilter.Locale.LocText["LTNoMatchingCriteria"]);
			end;
			table.remove(LootFilterVars[LootFilter.REALMPLAYER].itemStack, 1);
		end;
	end;
	LootFilter.schedule(LootFilter.SCHEDULE_INTERVAL, LootFilter.processItemStack);	
end;
