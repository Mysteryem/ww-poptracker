if ENTRANCES_LOADED then
    print("WARNING: entrances.lua has already been loaded")
    return
else
    print("INFO: Loading entrances.lua")
    ENTRANCES_LOADED = true
end

require("scripts/objects/entrance")
require("scripts/utils")

-- Entrances may by set by the user such that they form loops that make access to some areas impossible. All of the
-- exits in the loop will be considered impossible.
logically_impossible_exits = {}

local function is_exit_possible(exit, checked_set)
    local exit_name = exit.Name

    if logically_impossible_exits[exit_name] then
        -- This exit has already been found to be impossible.
        -- This should not normally happen because left/right click to cycle through exits skips already assigned exits.
        debugPrint("%s is unreachable from a previous check", exit_name)
        return false
    end

    -- Prevent infinite loops by keeping a set of the exit names checked so far.
    if not checked_set then
        checked_set = {}
    end
    if checked_set[exit_name] then
        -- Already checked this exit, so we've got a loop.
        debugPrint("%s is unreachable due to a loop", exit_name)
        return false
    end
    checked_set[exit_name] = true

    -- Get the entrance object that leads to this exit
    local entrance = exit.Entrance
    if not entrance then
        -- No entrance is currently mapped to this exit, so the exit is considered unreachable.
        debugPrint("%s is unreachable due to not being assigned to an entrance", exit_name)
        return false
    end

    -- Check if the parent exit that leads to this entrance is possible
    local parent_exit = entrance.parent_exit
    if parent_exit == nil then
        -- The Great Sea is always accessible.
        debugPrint("%s is reachable due to its entrance's parent_exit being The Great Sea (nil)", exit_name)
        return true
    else
        return is_exit_possible(parent_exit, checked_set)
    end
end

PAUSE_ENTRANCE_UPDATES = false

function update_entrances()
    if PAUSE_ENTRANCE_UPDATES or not ENTRANCE_RANDO_ENABLED then
        return
    end

    debugPrint("### Updating entrances logic ###")

    -- Check for unreachable exits.
    -- Reset the global lookup table.
    logically_impossible_exits = {}
    debugPrint("Checking for and marking impossible exits")
    for _, entrance in ipairs(ENTRANCES) do
        local exit = entrance.exit
        if exit and not is_exit_possible(exit) then
            debugPrint("Exit '%s' is impossible to reach", exit.Name)
            logically_impossible_exits[exit.Name] = true
        end
    end

    -- Visibly mark impossible exits
    if EXIT_MAPPINGS_LOADED then
        for _, entrance in ipairs(ENTRANCES) do
            local exit = entrance.exit
            local lua_item = entrance:GetItem()
            -- It's possible we could be trying to update before all the items have been created in exit_mappings.lua.
            if lua_item then
                -- TODO: Also find the placeholder items and change their overlay colour too
                local new_icon_mods
                if exit and logically_impossible_exits[exit.Name] then
                    -- TODO: Red overlay or something else that stands out more to indicate that the exit is impossible to
                    --       reach (or invalid due to being duplicated).
                    debugPrint("Marked %s as impossible because its exit %s cannot be reached", entrance.name, exit.Name)
                    new_icon_mods = "@disabled"
                else
                    new_icon_mods = "none"
                end
                if lua_item.IconMods ~= new_icon_mods then
                    lua_item.IconMods = new_icon_mods
                end
            end
        end
    end

    -- Force logic to update because the result of lua functions that check exit accessibility may now give different
    -- results.
    forceLogicUpdate()
end