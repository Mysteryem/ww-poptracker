if UTILS_LOADED then
    return
else
    UTILS_LOADED = true
end

function has_value(t, val)
    for i, v in ipairs(t) do
        if v == val then return 1 end
    end
    return 0
end

function has(item, amount)
    local count = Tracker:ProviderCountForCode(item)
    amount = tonumber(amount)
    if not amount then
        return count > 0
    else
        return count >= amount
    end
end

function progCount(code)
    return Tracker:FindObjectForCode(code).CurrentStage
end

-- from https://stackoverflow.com/questions/9168058/how-to-dump-a-table-to-console
-- dumps a table in a readable string
function dump_table(o, depth)
    if depth == nil then
        depth = 0
    end
    if type(o) == 'table' then
        local tabs = ('\t'):rep(depth)
        local tabs2 = ('\t'):rep(depth + 1)
        local s = '{\n'
        for k, v in pairs(o) do
            if type(k) ~= 'number' then
                k = '"' .. k .. '"'
            end
            s = s .. tabs2 .. '[' .. k .. '] = ' .. dump_table(v, depth + 1) .. ',\n'
        end
        return s .. tabs .. '}'
    else
        return tostring(o)
    end
end

function forceLogicUpdate()
    local update = Tracker:FindObjectForCode("update")
    -- If this function is called too early, the item won't exist yet.
    if update then
        --print("Forced update!")
        update.Active = not update.Active
    end
end

local function pauseLogicUpdatesFinished(duration)
    print("Finished sleeping for " .. duration .. " seconds")
    Tracker.BulkUpdate = false
    forceLogicUpdate()
end

-- When specified, finishedCallback(duration, ...) is called after the timer is finished. The duration argument is
-- likely to be greater than the requested timer duration because the timer only updates each frame.
local function startFrameTimer(name, duration, finishedCallback, ...)
    -- Can't access the varargs from within frameCallback, so pack them into a local table and unpack in frameCallback.
    local arg = {...}

    local clock = os.clock
    local start_time = clock()
    local end_time = start_time + duration

    local function frameCallback(_seconds_since_last_frame)
        local current_time = clock()
        print(current_time)
        if current_time > end_time then
            ScriptHost:RemoveOnFrameHandler(name)
            if finishedCallback then
                finishedCallback(current_time - start_time, table.unpack(arg))
            end
        end
    end

    ScriptHost:AddOnFrameHandler(name, frameCallback)
end

-- Disable tracker logic updates and then wait `seconds` before re-enabling tracker logic updates.
-- If a function is provided, it is run after disabling tracker logic updates and the wait only starts after the
-- function has finished executing.
-- The timer internally uses a Frame Handler, so will only check the time each frame.
-- Note: The next frame after running init.lua or after connecting to Archipelago can take quite a while.
function pauseLogicUpdates(name, seconds, func, ...)
    Tracker.BulkUpdate = true
    if func then
        -- Perform a protected call to ensure that `Tracker.BulkUpdate` gets set back to `false` if something goes
        -- wrong.
        local ok, err = pcall(func, ...)

        if not ok then
            Tracker.BulkUpdate = false
            print("Error:\n"..tostring(err))
            return
        end
    end
    startFrameTimer(name, seconds, pauseLogicUpdatesFinished)
end