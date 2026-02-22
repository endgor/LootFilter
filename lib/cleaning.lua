function LootFilter.processCleaning()
	LootFilterButtonDeleteItems:Disable();
	LootFilterButtonIWantTo:Disable();
	LootFilter.constructCleanList();
	local totalValue = LootFilter.calculateCleanListValue()
	if (totalValue > 0) then
		totalValue = LootFilter.round(totalValue);
		
		LootFilterTextCleanTotalValue:SetText(LootFilter.Locale.LocText["LTTotalValue"]..": "..string.format("|c00FFFF66 %2dg" , math.floor(totalValue / 10000))..string.format("|c00C0C0C0 %2ds" , math.floor(totalValue % 10000 / 100))..string.format("|c00CC9900 %2dc" , totalValue % 100));
	else 
		LootFilterTextCleanTotalValue:SetText(LootFilter.Locale.LocText["LTTotalValue"]..": "..string.format("|c00FFFF66 %2dg" , 0)..string.format("|c00C0C0C0 %2ds" , 0)..string.format("|c00CC9900 %2dc" , 0));
	end;
	table.sort(LootFilter.cleanList, LootFilter.sortByValue);
	if (table.getn(LootFilter.cleanList) > 0) then
		LootFilterButtonDeleteItems:Enable();
		LootFilter.CleanScrollBar_Update();
	else
		local cleanLine = getglobal("cleanLine1");
		cleanLine:SetText(LootFilter.Locale.LocText["LTNoMatchingItems"]);
		LootFilterTextCleanTotalValue:SetText("");
		cleanLine:Show();
	end;	
end;

function LootFilter.showItemTooltip(frame)
	local fontString = getglobal("cleanLine"..string.match(frame:GetName(), "(%d+)"));
	local value = fontString:GetText();
	if (LootFilter.cleanList ~= nil) and (table.getn(LootFilter.cleanList) > 0) and (value ~= nil) and (value ~= "") then
		local item = LootFilter.getBasicItemInfo(value);
		if (item == nil) then return end;

		item = LootFilter.findItemInBags(item);

		if (item["bag"] >= 0) and (item["slot"] >= 0) then
			GameTooltip:SetOwner(frame, "ANCHOR_LEFT");
			GameTooltip:SetBagItem(item["bag"], item["slot"]);
			GameTooltip:Show();
		end;
	end;
end;

function LootFilter.addItemToKeepList(frame)
	local fontString = getglobal("cleanLine"..string.match(frame:GetName(), "(%d+)"));
	local value = fontString:GetText();
	if (value ~= nil) and (value ~= "") then
		if (IsShiftKeyDown()) then
			table.insert(LootFilterVars[LootFilter.REALMPLAYER].keepList["names"], LootFilter.getNameOfItem(value));
			LootFilterEditBox1:SetText(LootFilterEditBox1:GetText()..LootFilter.getNameOfItem(value).."\n");
			LootFilter.initClean();
			LootFilter.processCleaning();
			LootFilter.showItemTooltip(frame);
		end;
	end;
end;

