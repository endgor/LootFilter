function LootFilter.print(value)
	if (value == nil) then
		value = "";
	end;
	DEFAULT_CHAT_FRAME:AddMessage("Loot Filter - " .. value, 1.0, 1.0, 1.0);
end;

function LootFilter.debug(value)
	if LootFilter.REALMPLAYER == "" or not LootFilterVars[LootFilter.REALMPLAYER].debug then
		return;
	end
	if (value == nil) then
		value = "";
	end;
	DEFAULT_CHAT_FRAME:AddMessage("Loot Filter - DEBUG: " .. value, 1.0, 1.0, 1.0);
end;

function LootFilter.varCount()
	local n = 0;
	for k in pairs(LootFilterVars) do
		if k:find("%s -") ~= nil then
			n = n + 1;
		end
	end
	return n;
end

function LootFilter.trim(name)
	return string.gsub(name, "LootFilter", "");
end;

function LootFilter.stripComment(searchName)
	local comment = "";
	local commentPos = string.find(searchName, ";", 1, true);
	if (commentPos ~= nil) and (commentPos > 0) then -- comment found
		comment = string.sub(searchName, commentPos);
		searchName = string.sub(searchName, 0, commentPos - 1);
		searchName = strtrim(searchName);
	end;
	return searchName, comment;
end;

function LootFilter.SanitizeName(name)
	if (name == nil) then
		return "";
	end;

	local linkedName = string.match(name, "|h%[(.-)%]|h");
	if (linkedName ~= nil) then
		name = linkedName;
	end;

	name = string.gsub(name, "|c%x%x%x%x%x%x%x%x", "");
	name = string.gsub(name, "|r", "");
	name = strtrim(name);
	name = string.lower(name);
	return name;
end;

function LootFilter.normalizeNameFilterEntry(entry)
	if (entry == nil) then
		return "";
	end;

	local value = strtrim(entry);
	if (value == "") then
		return "";
	end;

	local searchName, comment = LootFilter.stripComment(value);
	local prefix = "";

	if (string.find(searchName, "##", 1, true) == 1) then
		prefix = "##";
		searchName = string.sub(searchName, 3);
	elseif (string.find(searchName, "#", 1, true) == 1) then
		prefix = "#";
		searchName = string.sub(searchName, 2);
	end;

	searchName = strtrim(searchName);
	local linkedName = string.match(searchName, "|h%[(.-)%]|h");
	if (linkedName ~= nil) then
		searchName = linkedName;
	end;

	searchName = string.gsub(searchName, "|c%x%x%x%x%x%x%x%x", "");
	searchName = string.gsub(searchName, "|r", "");
	searchName = strtrim(searchName);
	if (searchName == "") then
		return "";
	end;

	local normalized = prefix .. searchName;
	if (comment ~= nil) and (comment ~= "") then
		normalized = normalized .. " " .. comment;
	end;

	return normalized;
end;

function LootFilter.normalizeNameFilterList(list)
	if (list == nil) then
		return false;
	end;

	local normalized = {};
	local changed = false;
	for _, value in ipairs(list) do
		local normalizedValue = LootFilter.normalizeNameFilterEntry(value);
		if (normalizedValue ~= "") then
			table.insert(normalized, normalizedValue);
		end;
		if (normalizedValue ~= value) then
			changed = true;
		end;
	end;

	if (changed) or (table.getn(normalized) ~= table.getn(list)) then
		while (table.getn(list) > 0) do
			table.remove(list);
		end;
		for _, value in ipairs(normalized) do
			table.insert(list, value);
		end;
		return true;
	end;

	return false;
end;

function LootFilter.normalizeConfiguredNameFilters()
	local keepChanged = false;
	local deleteChanged = false;

	if (LootFilterVars[LootFilter.REALMPLAYER].keepList ~= nil) then
		keepChanged = LootFilter.normalizeNameFilterList(LootFilterVars[LootFilter.REALMPLAYER].keepList["names"]);
	end;
	if (LootFilterVars[LootFilter.REALMPLAYER].deleteList ~= nil) then
		deleteChanged = LootFilter.normalizeNameFilterList(LootFilterVars[LootFilter.REALMPLAYER].deleteList["names"]);
	end;

	return keepChanged or deleteChanged;
end;


function LootFilter.sendAddonMessage(value, channel)
	if (channel == 1) then
		local guild = GetGuildInfo("player");
		if (guild ~= nil) then
			SendAddonMessage("LootFilter", value, "GUILD", "");
		end;
	elseif (channel == 2) then
		if (LootFilter.versionUpdate == true) then
			SendAddonMessage("LootFilter", value, "RAID", "");
		end;
	end;
end;

function LootFilter.toggleWindow()
	if (not LootFilterOptions:IsShown()) then
		LootFilterOptions:Show();
	else
		LootFilterOptions:Hide();
	end;
end;

function LootFilter.command(cmd)
	local args = {};
	local i = 1;
	for w in string.gmatch(cmd, "%w+") do
		args[i] = w;
		i = i + 1;
	end;

	if (table.getn(args) == 0) then
		LootFilter.toggleWindow();
	elseif (args[1] == "lootbot" or args[1] == "bot") then
		LootFilterVars[LootFilter.REALMPLAYER].lootbotmode = not LootFilterVars[LootFilter.REALMPLAYER].lootbotmode;
		if LootFilterVars[LootFilter.REALMPLAYER].lootbotmode then
			LootFilter.takeBagSnapshot(); -- Take fresh snapshot when enabling
			LootFilter.print("|cff00ff00Loot Bot Mode ENABLED|r - Items added to bags will be filtered automatically.");
		else
			LootFilter.print("|cffff0000Loot Bot Mode DISABLED|r - Only items from loot windows will be filtered.");
		end
	elseif (args[1] == "silence") then
		LootFilterVars[LootFilter.REALMPLAYER].silent = not LootFilterVars[LootFilter.REALMPLAYER].silent;
		if LootFilterVars[LootFilter.REALMPLAYER].silent then
			LootFilter.print("|cff00ff00Silence Mode ENABLED|r - Filter messages will be suppressed.");
		else
			LootFilter.print("|cffff0000Silence Mode DISABLED|r - Filter messages will be shown.");
		end
	elseif (args[1] == "debug") then
		LootFilterVars[LootFilter.REALMPLAYER].debug = not LootFilterVars[LootFilter.REALMPLAYER].debug;
		if LootFilterVars[LootFilter.REALMPLAYER].debug then
			LootFilter.print("|cff00ff00Debug Mode ENABLED|r - Diagnostic output will appear in chat.");
		else
			LootFilter.print("|cffff0000Debug Mode DISABLED|r");
		end
	elseif (args[1] == "status") then
		LootFilter.print("Loot Bot Mode: " ..
		(LootFilterVars[LootFilter.REALMPLAYER].lootbotmode and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r"));
		LootFilter.print("Silence Mode: " ..
		(LootFilterVars[LootFilter.REALMPLAYER].silent and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r"));
		LootFilter.print("Filtering: " ..
		(LootFilterVars[LootFilter.REALMPLAYER].enabled and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r"));
		LootFilter.print("Debug Mode: " ..
		(LootFilterVars[LootFilter.REALMPLAYER].debug and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r"));
		LootFilter.print("GetSellValue API: " ..
		(GetSellValue and "|cff00ff00AVAILABLE|r" or "|cffff0000NOT AVAILABLE|r"));
	elseif (args[1] == "help") then
		LootFilter.print("Commands:");
		LootFilter.print("  /lf - Toggle options window");
		LootFilter.print(
		"  /lf lootbot - Toggle loot bot mode (auto-filters items added to bags, e.g. from Scavenger companion)");
		LootFilter.print("  /lf silence - Toggle silence mode (suppress filter chat messages)");
		LootFilter.print("  /lf debug - Toggle debug mode (diagnostic output in chat)");
		LootFilter.print("  /lf status - Show current status");
		LootFilter.print("  /lf help - Show this help");
	end;
end;

function LootFilter.constructCleanList()
	LootFilter.cleanList = {};
	local z = 1;
	local slots = 0;
	for j = 0, 4, 1 do
		if (LootFilterVars[LootFilter.REALMPLAYER].openbag[j]) then
			local x = GetContainerNumSlots(j);
			for i = 1, x, 1 do
				local item = LootFilter.getBasicItemInfo(GetContainerItemLink(j, i));
				if (item ~= nil) then
					item["bag"] = j;
					item["slot"] = i;
					item["amount"] = LootFilter.getStackSizeOfItem(item);
					LootFilter.ensureItemValue(item); -- re-resolve value in case GetItemInfo was not ready earlier

					local action = LootFilter.evaluateItem(item);

					if (action == "keep") then
						-- skip item, don't add to clean list
					elseif (action == "delete") then
						item["value"] = item["value"] - 10000000; -- priority delete: sort to bottom
						LootFilter.cleanList[z] = item;
						z = z + 1;
					else
						-- No match: skip (only explicitly delete-flagged items are candidates)
					end;
				else
					slots = slots + 1;
				end;
			end;
		end;
	end;
	return slots;
end;

function LootFilter.calculateCleanListValue()
	local totalValue = 0;
	local x = table.getn(LootFilter.cleanList);
	for j = 1, x, 1 do
		local itemValue = tonumber(LootFilter.cleanList[j]["value"]) or 0;
		local itemAmount = tonumber(LootFilter.cleanList[j]["amount"]) or 1;
		if (itemValue < 0) then
			totalValue = totalValue + (itemValue + 10000000) * itemAmount;
		else
			totalValue = totalValue + itemValue * itemAmount;
		end;
	end;
	return totalValue;
end;

function LootFilter.deepCopy(orig)
	if type(orig) ~= "table" then
		return orig;
	end
	local copy = {};
	for k, v in pairs(orig) do
		copy[k] = LootFilter.deepCopy(v);
	end
	return copy;
end

function LootFilter.copySettings()
	local realmPlayer = UIDropDownMenu_GetText(LootFilterSelectDropDown);
	LootFilterVars[LootFilter.REALMPLAYER] = LootFilter.deepCopy(LootFilterVars[realmPlayer]);
	LootFilter.getNames();
	LootFilter.getNamesDelete();
	LootFilter.getItemValue();
	LootFilter.refreshUI();
	LootFilterEditBoxTitleCopy5:Hide();
	LootFilterEditBoxTitleCopy4:Show();
	return;
end;

function LootFilter.deleteSettings()
	local realmPlayer = UIDropDownMenu_GetText(LootFilterSelectDropDown);
	if (realmPlayer ~= LootFilter.REALMPLAYER) then
		LootFilter.deleteTable(LootFilterVars[realmPlayer]);
		LootFilterVars[realmPlayer] = nil;
		UIDropDownMenu_SetSelectedValue(LootFilterSelectDropDown, nil);
		UIDropDownMenu_Initialize(LootFilterSelectDropDown, LootFilter.SelectDropDown_Initialize);
		LootFilterEditBoxTitleCopy4:Hide();
		LootFilterEditBoxTitleCopy5:Show();
		LootFilter.initCopyTab();
	end;
end

function LootFilter.round(num, idp)
	local mult = 10 ^ (idp or 0)
	return math.floor(num * mult + 0.5) / mult
end;

function LootFilter.sessionReset()
	LootFilterVars[LootFilter.REALMPLAYER].session = {};
	LootFilterVars[LootFilter.REALMPLAYER].session["itemValue"] = 0;
	LootFilterVars[LootFilter.REALMPLAYER].session["itemCount"] = 0;
	LootFilterVars[LootFilter.REALMPLAYER].session["start"] = time();
	LootFilterVars[LootFilter.REALMPLAYER].session["end"] = time();
end;

function LootFilter.sessionAdd(item)
	LootFilter.ensureItemValue(item); -- re-resolve value in case GetItemInfo was not ready at loot time
	LootFilterVars[LootFilter.REALMPLAYER].session["itemValue"] = LootFilterVars[LootFilter.REALMPLAYER].session
	["itemValue"] + item["value"];
	LootFilterVars[LootFilter.REALMPLAYER].session["itemCount"] = LootFilterVars[LootFilter.REALMPLAYER].session
	["itemCount"] + 1;
end;

function LootFilter.sessionUpdateValues()
	if (not GetSellValue) then
		return;
	end;
	local value = LootFilterVars[LootFilter.REALMPLAYER].session["itemValue"];
	LootFilterTextSessionValueInfo:SetText(LootFilter.Locale.LocText["LTSessionInfo"]);
	LootFilterTextSessionItemTotal:SetText(LootFilter.Locale.LocText["LTSessionItemTotal"] ..
	": " .. LootFilterVars[LootFilter.REALMPLAYER].session["itemCount"]);
	LootFilterTextSessionValueTotal:SetText(LootFilter.Locale.LocText["LTSessionTotal"] ..
	": " ..
	string.format("|c00FFFF66 %2dg", math.floor(value / 10000)) ..
	string.format("|c00C0C0C0 %2ds", math.floor(value % 10000 / 100)) ..
	string.format("|c00CC9900 %2dc", value % 100));
	local average;
	if (value ~= nil) and (value ~= 0) then
		average = LootFilter.round(value / LootFilterVars[LootFilter.REALMPLAYER].session["itemCount"]);
	else
		average = 0;
	end;
	LootFilterTextSessionValueAverage:SetText(LootFilter.Locale.LocText["LTSessionAverage"] ..
	": " ..
	string.format("|c00FFFF66 %2dg", math.floor(average / 10000)) ..
	string.format("|c00C0C0C0 %2ds", math.floor(average % 10000 / 100)) ..
	string.format("|c00CC9900 %2dc", average % 100));
	if (LootFilterVars[LootFilter.REALMPLAYER].session["end"] == nil) then
		LootFilterVars[LootFilter.REALMPLAYER].session["end"] = LootFilterVars[LootFilter.REALMPLAYER].session["start"];
	end;
	local time = LootFilterVars[LootFilter.REALMPLAYER].session["end"] -
	LootFilterVars[LootFilter.REALMPLAYER].session["start"];
	if (time ~= 0) then
		local hours = time / 3600;
		if (value ~= nil) and (value ~= 0) then
			if (hours ~= 0) then
				value = LootFilter.round(value / hours);
			end;
		else
			value = 0;
		end;
	else
		value = 0;
	end;
	LootFilterTextSessionValueHour:SetText(LootFilter.Locale.LocText["LTSessionValueHour"] ..
	": " ..
	string.format("|c00FFFF66 %2dg", math.floor(value / 10000)) ..
	string.format("|c00C0C0C0 %2ds", math.floor(value % 10000 / 100)) ..
	string.format("|c00CC9900 %2dc", value % 100));
end;

function LootFilter.deleteTable(t)
	for k, v in pairs(t) do
		if type(v) == "table" then
			LootFilter.deleteTable(t[k]);
		end
		t[k] = nil;
	end
end
