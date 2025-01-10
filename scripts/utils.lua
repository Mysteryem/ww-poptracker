if UTILS_LOADED then
    print("WARNING: utils.lua has already been loaded.")
    return
else
    print("INFO: Loading utils.lua")
    UTILS_LOADED = true
end

require("scripts/debug")

if DEBUG then
    function debugPrint(format, ...)
        print(string.format("DEBUG: "..format, ...))
    end
else
    function debugPrint(format, ...)
        -- no-op
    end
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

local function pauseLogicUpdatesFinished(name)
    print(name .. ": Re-enabling tracker logic updates")
    Tracker.BulkUpdate = false
    forceLogicUpdate()
end

-- When specified, finishedCallback(...) is called after the timer is finished. The duration argument is
-- likely to be greater than the requested timer duration because the timer only updates each frame.
function runNextFrame(name, func, ...)
    -- Can't access the varargs from within frameCallback, so pack them into a local table and unpack in frameCallback.
    local arg = {...}

    local function frameCallback(_seconds_since_last_frame)
        ScriptHost:RemoveOnFrameHandler(name)
        func(name, table.unpack(arg))
    end

    ScriptHost:AddOnFrameHandler(name, frameCallback)
end

-- Disable tracker logic updates until the next frame and then re-enable tracker logic updates.
function pauseLogicUntilNextFrame(name)
    Tracker.BulkUpdate = true
    runNextFrame(name, pauseLogicUpdatesFinished)
end