local schedStack = {};
local ScheduleFrame = CreateFrame("Frame", "LootFilterScheduleFrame");
local Schedule = nil; -- Handle to scheduler coroutine

function LootFilter.schedule(delay, func, ...)
	if type(func) ~= "function" and type(func) ~= "string" then
		error("LootFilter.schedule: expected function or string as 2nd parameter, recieved `" .. type(func) .. "`");
	end
	table.insert(schedStack, {Time = (GetTime() + delay), Func = func, Args = {...}});
	table.sort(schedStack, function(a, b) -- Ensure the stack is properly sorted
		return a.Time < b.Time;
		end);
end

function LootFilter.isScheduled(func)
	if type(func) ~= "function" and type(func) ~= "string" then
		return false;
	end
	for _, event in ipairs(schedStack) do
		if event.Func == func then
			return true;
		end
	end
	return false;
end

local function Scheduler(errorHandler)
	local addon = LootFilter;
	local StartTime, MaxTime = 0, .005;
	local function Yield(force)
		if force or (GetTime() - StartTime) > MaxTime then
			coroutine.yield();
		end
	end
	local stack = schedStack;
	local event = nil;
	local function RunEvent(fn, args)
		local ok = xpcall(fn, errorHandler, unpack(args));
		return ok;
	end

	Yield(true); -- Force a yield after setting up the scheduler
	while true do
		StartTime = GetTime();
		stack = schedStack; -- Make sure we have the correct stack
		if table.getn(stack) > 0 then
			event = stack[1];
			if event.Time <= StartTime then
				if type(event.Func) == "function" then
					RunEvent(event.Func, event.Args);
				elseif type(event.Func) == "string" and type(addon[event.Func]) == "function" then
					RunEvent(addon[event.Func], event.Args);
				end
				table.remove(stack, 1);
				Yield();
			else
				Yield(true);
			end
		else
			Yield(true);
		end
	end
end

function OnUpdate(...)
	if not Schedule or coroutine.status(Schedule) == "dead" then
		Schedule = coroutine.create(Scheduler);
	end
	local ok, err = coroutine.resume(Schedule, geterrorhandler());
	if not ok and err then
		geterrorhandler()(err);
		Schedule = nil;
	end
end

ScheduleFrame:SetScript("OnUpdate", OnUpdate);
