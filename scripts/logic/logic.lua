if LOGIC_LOADED then
    print("WARNING: logic.lua has already been loaded")
    return
else
    print("INFO: Loading logic.lua")
    LOGIC_LOADED = true
end

require("scripts/objects/exit") -- for `EXITS_BY_NAME`
require("scripts/objects/entrance") -- for `logically_impossible_exits`

function exit_accessibility(exit_name)
    if logically_impossible_exits[exit_name] then
        -- Exit is part of an inaccessible loop.
--         print("Cannot access exit " .. exit_name .. " because it is impossible")
        return AccessibilityLevel.None
    end

    -- Find the entrance in this entrance <-> exit pair.
    local exit = EXITS_BY_NAME[exit_name]
    local entrance = exit.Entrance
    if not entrance then
        -- With no entrance, the best thing to return is that the exit is inaccessible.
        return AccessibilityLevel.None
    else
        -- Return the entrance's accessibility.
        return entrance:GetAccessibility()
    end
end