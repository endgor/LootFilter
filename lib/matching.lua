function LootFilter.matchProperties(key, value, item, keep)
	local reason = "";
	local _, _, rarity, _, _, itemType, itemSubType, _ = GetItemInfo(item["id"]);
	if rarity ~= nil then
		item["rarity"] = rarity;
	end
	if itemType ~= nil then
		item["type"] = itemType;
	end
	if itemSubType ~= nil then
		item["subType"] = itemSubType;
	end
	
	if (string.match(key, "^QU")) then
		LootFilter.debug("|cff00ffff[MATCH]|r Quality check: key=" .. tostring(key) .. " ruleValue=" .. tostring(value) .. " itemRarity=" .. tostring(item["rarity"]));
		if (item["rarity"] == value) then
			reason = LootFilter.Locale.LocText["LTQualMatched"].." ("..value..")";
		elseif (value == -1) then
			local questTypeText = string.lower(tostring(LootFilter.Locale.LocText["LTQuest"] or ""));
			if (string.lower(tostring(item["type"] or "")) == questTypeText) then
				reason = LootFilter.Locale.LocText["LTQuestItem"];
			end;
		end;
	elseif (string.match(key, "^TY")) then

		if (item["type"] ~= nil) and (item["subType"] ~= nil) and (string.match(key, "^TY"..item["type"])) and (item["subType"] == value) then
			
			reason = LootFilter.Locale.LocText["LTTypeMatched"].." ("..value..")";
		end;
	elseif (string.match(key, "^VA")) then
		if (GetSellValue) and (LootFilterVars[LootFilter.REALMPLAYER].novalue) and ((item["value"] == nil) or (item["value"] <= 0)) then
			reason = LootFilter.Locale.LocText["LTNoKnownValue"];
		elseif (GetSellValue) then
			local calculatedValue;
			if (LootFilterVars[LootFilter.REALMPLAYER].calculate == 1) then
				calculatedValue = tonumber(item["value"]) or 0;
			elseif (LootFilterVars[LootFilter.REALMPLAYER].calculate == 2) then
				calculatedValue = tonumber((tonumber(item["value"]) or 0) * (tonumber(item["amount"]) or 0)) or 0;
			else
				calculatedValue = tonumber((tonumber(item["value"]) or 0) * (tonumber(item["stack"]) or 1)) or 0;
			end;
			if (keep) and (LootFilterVars[LootFilter.REALMPLAYER].keepList["VAOn"]) then
				local threshold = tonumber(LootFilterVars[LootFilter.REALMPLAYER].keepList["VAValue"]) or 0;
				if (calculatedValue > threshold) then
					reason = LootFilter.Locale.LocText["LTValueHighEnough"].." ("..calculatedValue..")";
				end;
			elseif (not keep) and ((LootFilterVars[LootFilter.REALMPLAYER].deleteList["VAOn"])) then
				local threshold = tonumber(LootFilterVars[LootFilter.REALMPLAYER].deleteList["VAValue"]) or 0;
				if (calculatedValue < threshold) then
					reason= LootFilter.Locale.LocText["LTValueNotHighEnough"].." ("..calculatedValue..")";
				end;					
			end;
		end;
	elseif (key == "names") then
		if (value == nil) then
			return reason;
		end;
		for _, name in pairs(value) do
			local nameMatched = LootFilter.matchItemNames(item, name);
			LootFilter.debug("|cff00ffff[NAMES]|r \"" .. tostring(name) .. "\" vs \"" .. tostring(item["name"]) .. "\" => " .. (nameMatched and "|cff00ff00MATCHED|r" or "no match"));
			if (nameMatched) then
				reason = LootFilter.Locale.LocText["LTNameMatched"].." ("..name..")";
				break;
			end;
		end;
	end;
	return reason;	
end;

function LootFilter.matchKeepProperties(item)
	local reason = "";
	local keepList = LootFilterVars[LootFilter.REALMPLAYER].keepList;

	-- Check explicit keep-name matches first.
	reason = LootFilter.matchProperties("names", keepList["names"], item, true);
	if (reason ~= "") then
		return reason;
	end;

	for key, value in pairs(keepList) do
		if (key ~= "names") then
			reason = LootFilter.matchProperties(key, value, item, true);
			if (reason ~= "") then
				return reason;
			end;
		end;
	end;
	return reason;
end;

function LootFilter.matchDeleteNameProperties(item)
	local deleteList = LootFilterVars[LootFilter.REALMPLAYER].deleteList;
	return LootFilter.matchProperties("names", deleteList["names"], item, false);
end;

function LootFilter.matchDeleteProperties(item)
	local reason = "";
	local deleteList = LootFilterVars[LootFilter.REALMPLAYER].deleteList;

	-- Check explicit delete-name matches first.
	reason = LootFilter.matchDeleteNameProperties(item);
	if (reason ~= "") then
		return reason;
	end;

	for key, value in pairs(deleteList) do
		if (key ~= "names") then
			reason = LootFilter.matchProperties(key, value, item, false);
			if (reason ~= "") then
				return reason;
			end;
		end;
	end;
	return reason;
end;


function LootFilter.findItemInBags(item)
	local x, y;
	local containerItem = {};
	item["bag"] = -1;
	item["slot"] = -1;
	item["count"] = 0;
	local nameToFind = string.lower(tostring(item["name"] or ""));
	
	for j=0 , 4 , 1 do
		if (LootFilterVars[LootFilter.REALMPLAYER].openbag[j]) then
			x = GetContainerNumSlots(j);
			for i=1 , x , 1 do
				containerItem["link"]= GetContainerItemLink(j,i);
				if (containerItem["link"] ~= nil) then
					containerItem["name"] = LootFilter.getNameOfItem(containerItem["link"]);
					containerItem["id"] = LootFilter.getIdOfItem(containerItem["link"]);
					if (containerItem["id"] >= 1) then
						local idMatch = (item["id"] ~= nil) and (item["id"] == containerItem["id"]);
						local nameMatch = (item["id"] == nil) and (nameToFind ~= "") and (string.lower(tostring(containerItem["name"] or "")) == nameToFind);
						if (idMatch or nameMatch) then
							item["bag"] = j;
							item["slot"] = i;
							LootFilter.debug("|cff00ffff[FIND]|r Found \"" .. tostring(item["name"]) .. "\" in bag=" .. j .. " slot=" .. i);
							return item;
						end;
					end;
				end;
			end;
		end;
	end;
	LootFilter.debug("|cff00ffff[FIND]|r \"" .. tostring(item["name"]) .. "\" NOT found in any bag");
	return item;
end;

function LootFilter.matchItemNames(item, searchName)
	if (item["name"] == nil) or (searchName == nil) then
		return false;
	end;
	
	local comment;
	searchName, comment= LootFilter.stripComment(searchName);
	
	if (string.find(searchName, "##", 1, true) == 1) then
		if (item["info"] ~= nil) then
			local ok, found = pcall(string.find, string.lower(item["info"]), string.lower(string.sub(searchName, 3)));
			if (ok) and (found) then
				return true;
			end;
		end;
	elseif (string.find(searchName, "#", 1, true) == 1) then
		local ok, found = pcall(string.find, string.lower(item["name"]), string.lower(string.sub(searchName, 2)));
		if (ok) and (found) then
			return true;
		end;
	elseif (string.lower(item["name"]) == string.lower(searchName)) then
		return true;
	end;
	return false;
end;
