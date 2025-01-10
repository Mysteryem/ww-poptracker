if LOGIC_LOADED then
    print("WARNING: logic.lua has already been loaded")
    return
else
    print("INFO: Loading logic.lua")
    LOGIC_LOADED = true
end

require("scripts/objects/exit") -- for `EXITS_BY_NAME`
require("scripts/logic/entrances") -- for `logically_impossible_exits`

function exit_accessibility(exit_name)
    if logically_impossible_exits[exit_name] then
        -- Exit is part of an inaccessible loop.
--         print("Cannot access exit " .. exit_name .. " because it is impossible")
        return AccessibilityLevel.None
    end

    -- This shouldn't normally need to be checked, but it is here for completeness.
    if exit_name == "The Great Sea" then
        -- Always accessible
--         print("Can access exit " .. exit_name .. " because it is always accessible")
        return AccessibilityLevel.Normal
    end

    -- Find the entrance in this entrance <-> exit pair.
    local exit = EXITS_BY_NAME[exit_name]
    local entrance = exit.Entrance
    if not entrance then
        -- An exit not assigned to an entrance should be put in `logically_impossible_exits`, so this code should not
        -- normally be run.
        print("ERROR: Cannot evaluate exit accessibility. Missing entrance for exit " .. exit_name)
        -- With no entrance, the best thing to return is that the exit is inaccessible.
        return AccessibilityLevel.None
    else
        -- Return the entrance's accessibility.
        return entrance:GetAccessibility()
    end
end