function LootFilter.matchProperties(key, value, item)
	local reason = "";
	_, _, item["rarity"], _, _, item["type"], item["subType"], _ = GetItemInfo(item["id"]);

	if (string.match(key, "^QU")) then
		LootFilter.debug("|cff00ffff[MATCH]|r Quality check: key=" ..
		tostring(key) .. " ruleValue=" .. tostring(value) .. " itemRarity=" .. tostring(item["rarity"]));
		if (item["rarity"] == value) then
			reason = LootFilter.Locale.LocText["LTQualMatched"] .. " (" .. value .. ")";
		elseif (value == -1) then
			if item["type"] and (string.lower(item["type"]) == string.lower(LootFilter.Locale.LocText["LTQuest"])) then
				reason = LootFilter.Locale.LocText["LTQuestItem"];
			end;
		end;
	elseif (string.match(key, "^TY")) then
		if item["type"] and item["subType"] and (string.match(key, "^TY" .. item["type"])) and (item["subType"] == value) then
			reason = LootFilter.Locale.LocText["LTTypeMatched"] .. " (" .. value .. ")";
		end;
	end;
	return reason;
end;

function LootFilter.matchQuality(item)
	for key, value in pairs(LootFilterVars[LootFilter.REALMPLAYER].keepList) do
		if string.match(key, "^QU") then
			local reason = LootFilter.matchProperties(key, value, item);
			if reason ~= "" then
				return "keep", reason;
			end
		end
	end
	for key, value in pairs(LootFilterVars[LootFilter.REALMPLAYER].deleteList) do
		if string.match(key, "^QU") then
			local reason = LootFilter.matchProperties(key, value, item);
			if reason ~= "" then
				return "delete", reason;
			end
		end
	end
	return nil, nil;
end

function LootFilter.matchType(item)
	for key, value in pairs(LootFilterVars[LootFilter.REALMPLAYER].keepList) do
		if string.match(key, "^TY") then
			local reason = LootFilter.matchProperties(key, value, item);
			if reason ~= "" then
				return "keep", reason;
			end
		end
	end
	for key, value in pairs(LootFilterVars[LootFilter.REALMPLAYER].deleteList) do
		if string.match(key, "^TY") then
			local reason = LootFilter.matchProperties(key, value, item);
			if reason ~= "" then
				return "delete", reason;
			end
		end
	end
	return nil, nil;
end

function LootFilter.matchValue(item)
	if not GetSellValue then
		return nil, nil;
	end
	if not LootFilterVars[LootFilter.REALMPLAYER].deleteList["VAOn"] then
		return nil, nil;
	end
	-- Don't delete items with no known value if novalue protection is on
	if LootFilterVars[LootFilter.REALMPLAYER].novalue and (item["value"] == nil or item["value"] <= 0) then
		return nil, nil;
	end
	local calculatedValue;
	local itemValue = tonumber(item["value"]) or 0;
	if itemValue <= 0 then
		calculatedValue = 0;
	elseif LootFilterVars[LootFilter.REALMPLAYER].calculate == 1 then
		calculatedValue = itemValue;
	elseif LootFilterVars[LootFilter.REALMPLAYER].calculate == 2 then
		calculatedValue = itemValue * (tonumber(item["amount"]) or 1);
	else
		calculatedValue = itemValue * (tonumber(item["stack"]) or 1);
	end
	local threshold = tonumber(LootFilterVars[LootFilter.REALMPLAYER].deleteList["VAValue"]) * 10000;
	if calculatedValue < threshold then
		return "delete", LootFilter.Locale.LocText["LTValueNotHighEnough"] .. " (" .. calculatedValue / 10000 .. ")";
	end
	return nil, nil;
end

-- Evaluate an item against all filter rules.
--
-- Priority chain:
--   1. Keep Names  (highest - explicit name always wins)
--   2. Delete Names
--   3. Item Type / Quality  (order swappable via qualityfirst setting; default: Type before Quality)
--   4. Value       (catch-all delete, only if no type/quality rule fired)
--   5. No match    (kept by default)
--
-- Returns: action ("keep", "delete", or nil), reason string
function LootFilter.evaluateItem(item)
	_, _, item["rarity"], _, _, item["type"], item["subType"], _ = GetItemInfo(item["id"]);

	-- Step 1: Names (highest priority)
	local reason = LootFilter.matchKeepNames(item);
	if reason ~= "" then
		return "keep", reason;
	end
	reason = LootFilter.matchDeleteNames(item);
	if reason ~= "" then
		return "delete", reason;
	end

	-- Step 2 & 3: Item Type vs Quality — order controlled by the qualityfirst setting
	if LootFilterVars[LootFilter.REALMPLAYER].qualityfirst then
		-- Quality first: broad quality rules are checked before specific type rules
		local qualAction, qualReason = LootFilter.matchQuality(item);
		if qualAction ~= nil then
			return qualAction, qualReason;
		end
		local typeAction, typeReason = LootFilter.matchType(item);
		if typeAction ~= nil then
			return typeAction, typeReason;
		end
	else
		-- Default: Item Type first (more specific rule wins outright)
		local typeAction, typeReason = LootFilter.matchType(item);
		if typeAction ~= nil then
			return typeAction, typeReason;
		end
		local qualAction, qualReason = LootFilter.matchQuality(item);
		if qualAction ~= nil then
			return qualAction, qualReason;
		end
	end

	-- Step 4: Value (catch-all delete — only if no type/quality rule matched)
	local valAction, valReason = LootFilter.matchValue(item);
	if valAction then
		return valAction, valReason;
	end

	return nil, nil;
end

function LootFilter.matchKeepNames(item)
	local reason = "";
	if (LootFilterVars[LootFilter.REALMPLAYER].keepList["names"] ~= nil) then
		for _, name in pairs(LootFilterVars[LootFilter.REALMPLAYER].keepList["names"]) do
			local nameMatched = LootFilter.matchItemNames(item, name);
			LootFilter.debug("|cff00ffff[KEEP-NAMES]|r \"" ..
			tostring(name) ..
			"\" vs \"" .. tostring(item["name"]) .. "\" => " .. (nameMatched and "|cff00ff00MATCHED|r" or "no match"));
			if (nameMatched) then
				reason = LootFilter.Locale.LocText["LTNameMatched"] .. " (" .. name .. ")";
				break;
			end;
		end;
	end;
	return reason;
end;

function LootFilter.matchDeleteNames(item)
	local reason = "";
	if (LootFilterVars[LootFilter.REALMPLAYER].deleteList["names"] ~= nil) then
		for _, name in pairs(LootFilterVars[LootFilter.REALMPLAYER].deleteList["names"]) do
			local nameMatched = LootFilter.matchItemNames(item, name);
			LootFilter.debug("|cff00ffff[DELETE-NAMES]|r \"" ..
			tostring(name) ..
			"\" vs \"" .. tostring(item["name"]) .. "\" => " .. (nameMatched and "|cff00ff00MATCHED|r" or "no match"));
			if (nameMatched) then
				reason = LootFilter.Locale.LocText["LTNameMatched"] .. " (" .. name .. ")";
				break;
			end;
		end;
	end;
	return reason;
end;

function LootFilter.findItemInBags(item)
	local x;
	local containerItem = {};

	-- If item already has a known bag/slot, verify it's still there by ID
	if item["bag"] and item["bag"] >= 0 and item["slot"] and item["slot"] >= 0 then
		local link = GetContainerItemLink(item["bag"], item["slot"]);
		if link then
			local id = LootFilter.getIdOfItem(link);
			if id == item["id"] then
				LootFilter.debug("|cff00ffff[FIND]|r Verified \"" ..
					tostring(item["name"]) .. "\" at known bag=" .. item["bag"] .. " slot=" .. item["slot"]);
				return item;
			end
		end
	end

	-- Fall back: search by item ID
	item["bag"] = -1;
	item["slot"] = -1;
	item["count"] = 0;

	for j = 0, 4, 1 do
		if (LootFilterVars[LootFilter.REALMPLAYER].openbag[j]) then
			x = GetContainerNumSlots(j);
			for i = 1, x, 1 do
				containerItem["link"] = GetContainerItemLink(j, i);
				if (containerItem["link"] ~= nil) then
					containerItem["id"] = LootFilter.getIdOfItem(containerItem["link"]);
					if containerItem["id"] == item["id"] then
						item["bag"] = j;
						item["slot"] = i;
						LootFilter.debug("|cff00ffff[FIND]|r Found \"" ..
							tostring(item["name"]) .. "\" by ID in bag=" .. j .. " slot=" .. i);
						return item;
					end;
				end;
			end;
		end;
	end;

	-- Last resort: search by name
	for j = 0, 4, 1 do
		if (LootFilterVars[LootFilter.REALMPLAYER].openbag[j]) then
			x = GetContainerNumSlots(j);
			for i = 1, x, 1 do
				containerItem["link"] = GetContainerItemLink(j, i);
				if (containerItem["link"] ~= nil) then
					containerItem["name"] = LootFilter.getNameOfItem(containerItem["link"]);
					if (LootFilter.matchItemNames(item, containerItem["name"])) then
						item["bag"] = j;
						item["slot"] = i;
						LootFilter.debug("|cff00ffff[FIND]|r Found \"" ..
							tostring(item["name"]) .. "\" by name in bag=" .. j .. " slot=" .. i);
						return item;
					end;
				end;
			end;
		end;
	end;

	LootFilter.debug("|cff00ffff[FIND]|r \"" .. tostring(item["name"]) .. "\" NOT found in any bag");
	return item;
end;

local QUALITY_BY_NAME = {
	["poor"] = 0, ["grey"] = 0, ["gray"] = 0,
	["common"] = 1, ["white"] = 1,
	["uncommon"] = 2, ["green"] = 2,
	["rare"] = 3, ["blue"] = 3,
	["epic"] = 4, ["purple"] = 4,
	["legendary"] = 5, ["orange"] = 5,
};

function LootFilter.wildcardToPattern(wildcard)
	local escaped = string.gsub(wildcard, "([%(%)%.%%%+%-%?%[%]%^%$])", "%%%1");
	escaped = string.gsub(escaped, "%*", "(.*)");
	return "^" .. escaped .. "$";
end;

function LootFilter.matchItemNames(item, searchName)
	if (item["name"] == nil) or (searchName == nil) then
		return false;
	end;

	local comment;
	searchName, comment = LootFilter.stripComment(searchName);

	-- Parse optional quality qualifier [qualityname] at end of pattern.
	-- When present the rule only fires if item quality >= the named threshold.
	-- Example: *Cloak* [uncommon]  →  only matches uncommon or better cloaks.
	local qualName = string.match(searchName, "%[(%a+)%]%s*$");
	if qualName then
		local qualMin = QUALITY_BY_NAME[string.lower(qualName)];
		if qualMin ~= nil and (item["rarity"] == nil or item["rarity"] < qualMin) then
			return false;
		end
		searchName = LootFilter.trim(string.gsub(searchName, "%s*%[" .. qualName .. "%]%s*$", ""));
	end

	if (string.find(searchName, "*", 1, true) ~= nil) and (string.find(searchName, "#", 1, true) ~= 1) then
		local pattern = string.lower(LootFilter.wildcardToPattern(searchName));
		local ok, result = pcall(string.find, string.lower(item["name"]), pattern);
		if (not ok) then
			LootFilter.debug("Bad wildcard pattern: " .. tostring(searchName));
			return false;
		end;
		if (result) then
			return true;
		end;
		return false;
	elseif (string.find(searchName, "##", 1, true) == 1) then
		if (item["info"] ~= nil) then
			local pattern = string.lower(string.sub(searchName, 3));
			local ok, result = pcall(string.find, string.lower(item["info"]), pattern);
			if (not ok) then
				LootFilter.debug("Bad pattern in ##: " .. tostring(pattern));
				return false;
			end;
			if (result) then
				return true;
			end;
		end;
	elseif (string.find(searchName, "#", 1, true) == 1) then
		local pattern = string.lower(string.sub(searchName, 2));
		local ok, result = pcall(string.find, string.lower(item["name"]), pattern);
		if (not ok) then
			LootFilter.debug("Bad pattern in #: " .. tostring(pattern));
			return false;
		end;
		if (result) then
			return true;
		end;
	elseif (string.lower(item["name"]) == string.lower(searchName)) then
		return true;
	elseif (LootFilter.SanitizeName(item["name"]) == LootFilter.SanitizeName(searchName)) then
		return true;
	end;
	return false;
end;
