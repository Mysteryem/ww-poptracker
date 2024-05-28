local Entrance = require("objects/entrance")

-- Start with the default entrances
ENTRANCES = {
    Entrance.new("Dungeon Entrance on Dragon Roost Island", nil, "Dragon Roost Cavern"),
    Entrance.new("Dungeon Entrance in Forest Haven Sector", nil, "Forbidden Woods"),
    Entrance.new("Dungeon Entrance in Tower of the Gods Sector", nil, "Tower of the Gods"),
    Entrance.new("Dungeon Entrance on Headstone Island", nil, "Earth Temple"),
    Entrance.new("Dungeon Entrance on Gale Isle", nil, "Wind Temple"),
    Entrance.new("Miniboss Entrance in Forbidden Woods", "Forbidden Woods", "Forbidden Woods Miniboss Arena"),
    Entrance.new("Miniboss Entrance in Tower of the Gods", "Tower of the Gods", "Tower of the Gods Miniboss Arena"),
    Entrance.new("Miniboss Entrance in Earth Temple", "Earth Temple", "Earth Temple Miniboss Arena"),
    Entrance.new("Miniboss Entrance in Wind Temple", "Wind Temple", "Wind Temple Miniboss Arena"),
    Entrance.new("Miniboss Entrance in Hyrule Castle", nil, "Master Sword Chamber"),
    Entrance.new("Boss Entrance in Dragon Roost Cavern", "Dragon Roost Cavern", "Gohma Boss Arena"),
    Entrance.new("Boss Entrance in Forbidden Woods", "Forbidden Woods", "Kalle Demos Boss Arena"),
    Entrance.new("Boss Entrance in Tower of the Gods", "Tower of the Gods", "Gohdan Boss Arena"),
    Entrance.new("Boss Entrance in Forsaken Fortress", nil, "Helmaroc King Boss Arena"),
    Entrance.new("Boss Entrance in Earth Temple", "Earth Temple", "Jalhalla Boss Arena"),
    Entrance.new("Boss Entrance in Wind Temple", "Wind Temple", "Molgera Boss Arena"),
    Entrance.new("Secret Cave Entrance on Outset Island", nil, "Savage Labyrinth"),
    Entrance.new("Secret Cave Entrance on Dragon Roost Island", nil, "Dragon Roost Island Secret Cave"),
    Entrance.new("Secret Cave Entrance on Fire Mountain", nil, "Fire Mountain Secret Cave"),
    Entrance.new("Secret Cave Entrance on Ice Ring Isle", nil, "Ice Ring Isle Secret Cave"),
    Entrance.new("Secret Cave Entrance on Private Oasis", nil, "Cabana Labyrinth"),
    Entrance.new("Secret Cave Entrance on Needle Rock Isle", nil, "Needle Rock Isle Secret Cave"),
    Entrance.new("Secret Cave Entrance on Angular Isles", nil, "Angular Isles Secret Cave"),
    Entrance.new("Secret Cave Entrance on Boating Course", nil, "Boating Course Secret Cave"),
    Entrance.new("Secret Cave Entrance on Stone Watcher Island", nil, "Stone Watcher Island Secret Cave"),
    Entrance.new("Secret Cave Entrance on Overlook Island", nil, "Overlook Island Secret Cave"),
    Entrance.new("Secret Cave Entrance on Bird's Peak Rock", nil, "Bird's Peak Rock Secret Cave"),
    Entrance.new("Secret Cave Entrance on Pawprint Isle", nil, "Pawprint Isle Chuchu Cave"),
    Entrance.new("Secret Cave Entrance on Pawprint Isle Side Isle", nil, "Pawprint Isle Wizzrobe Cave"),
    Entrance.new("Secret Cave Entrance on Diamond Steppe Island", nil, "Diamond Steppe Island Warp Maze Cave"),
    Entrance.new("Secret Cave Entrance on Bomb Island", nil, "Bomb Island Secret Cave"),
    Entrance.new("Secret Cave Entrance on Rock Spire Isle", nil, "Rock Spire Isle Secret Cave"),
    Entrance.new("Secret Cave Entrance on Shark Island", nil, "Shark Island Secret Cave"),
    Entrance.new("Secret Cave Entrance on Cliff Plateau Isles", nil, "Cliff Plateau Isles Secret Cave"),
    Entrance.new("Secret Cave Entrance on Horseshoe Island", nil, "Horseshoe Island Secret Cave"),
    Entrance.new("Secret Cave Entrance on Star Island", nil, "Star Island Secret Cave"),
    Entrance.new("Inner Entrance in Ice Ring Isle Secret Cave", "Ice Ring Isle Secret Cave", "Ice Ring Isle Inner Cave"),
    Entrance.new("Inner Entrance in Cliff Plateau Isles Secret Cave", "Cliff Plateau Isles Secret Cave", "Cliff Plateau Isles Inner Cave"),
    Entrance.new("Fairy Fountain Entrance on Outset Island", nil, "Outset Fairy Fountain"),
    Entrance.new("Fairy Fountain Entrance on Thorned Fairy Island", nil, "Thorned Fairy Fountain"),
    Entrance.new("Fairy Fountain Entrance on Eastern Fairy Island", nil, "Eastern Fairy Fountain"),
    Entrance.new("Fairy Fountain Entrance on Western Fairy Island", nil, "Western Fairy Fountain"),
    Entrance.new("Fairy Fountain Entrance on Southern Fairy Island", nil, "Southern Fairy Fountain"),
    Entrance.new("Fairy Fountain Entrance on Northern Fairy Island", nil, "Northern Fairy Fountain"),
}

ENTRANCE_BY_NAME = {}
-- Exits mapped to entrances located in that exit
ENTRANCE_ACCESSIBILITY = {}
for _, entrance in ipairs(ENTRANCES) do
    ENTRANCE_BY_NAME[entrance.name] = entrance

    local parent_exit = entrance.parent_exit
    local entrances_list = ENTRANCE_ACCESSIBILITY[parent_exit]
    if entrances_list == nil then
        entrances_list = {}
        ENTRANCE_ACCESSIBILITY[parent_exit] = entrances_list
    end
    table.insert(entrances_list, entrance)
end

ENTRANCE_ACCESSIBILITY_REVERSE = {}
for exit, entrances in pairs(ENTRANCE_ACCESSIBILITY) do
    for _, entrance in ipairs(entrances) do
        ENTRANCE_ACCESSIBILITY_REVERSE[entrance] = exit
    end
end

entrance_to_exit = {}
exit_to_entrance = {}
-- Entrances may form loops that make access to some areas impossible. All of these entrances will then be considered
-- impossible.
impossible_entrances = {}
impossible_exits = {}

-- local function is_possible(entrance_name, checked_set)
--     if not checked_set then
--         checked_set = {}
--     end
--     if checked_set[entrance_name] then
--         -- Already checked this entrance, so we've got a loop.
--         return false
--     end
--     checked_set[entrance_name] = true
--
--     local entrance = ENTRANCE_BY_NAME[entrance_name]
--     local parent_exit = entrance.parent_exit
--     if parent_exit == "The Great Sea" then
--         -- The Great Sea is always accessible
--         return true
--     end
--     -- Check if the parent_exit's entrance is possible to access.
--     local parent_entrance = exit_to_entrance[parent_exit]
--     return is_possible(parent_entrance, checked_set)
-- end

local function is_exit_possible(exit_name, checked_set)
    if exit_name == "The Great Sea" then
        -- The Great Sea is always accessible.
        return true
    end
    if impossible_exits[exit_name] then
        -- This exit has already been found to be impossible.
        return false
    end

    if not checked_set then
        checked_set = {}
    end
    if checked_set[exit_name] then
        -- Already checked this exit, so we've got a loop.
        return false
    end
    checked_set[exit_name] = true

    -- Get the name of the entrance that leads to this exit
    local entrance_name = exit_to_entrance[exit_name]
    if not entrance_name then
        -- No entrance is currently mapped to this exit, so the exit is considered unreachable.
        return false
    end
    -- Get the entrance object by its name
    local entrance = ENTRANCE_BY_NAME[entrance_name]
    -- Check if the parent exit that leads to this entrance is possible
    local parent_exit = entrance.parent_exit
    return is_exit_possible(parent_exit, checked_set)
end

PAUSE_ENTRANCE_UPDATES = false

function forceLogicUpdate()
    local update = Tracker:FindObjectForCode("update")
    -- If we call this too early, the item doesn't seem to exist yet
    if update then
        print("Forced update!")
        update.Active = not update.Active
    end
end

function update_entrances()
    if PAUSE_ENTRANCE_UPDATES then
        return
    end
    -- Reset
    entrance_to_exit = {}
    exit_to_entrance = {}
    impossible_exits = {}
    -- Create mappings for entrance -> exit pairs
    for _, entrance in ipairs(ENTRANCES) do
        local exit = entrance.exit
        entrance_to_exit[entrance.name] = exit
        -- exit may be `nil` if it has not been set
        if exit then
            local current_mapped_entrance = exit_to_entrance[exit]
            if current_mapped_entrance then
                impossible_exits[exit] = true
                print("Exit '" .. exit .. "' trying to be mapped from " .. entrance.name .. ", but is already mapped from '" .. current_mapped_entrance .. "'. Marking the exit as impossible.")
            else
                exit_to_entrance[exit] = entrance.name
            end
        end
    end
    -- Check for unreachable exits
    for _, entrance in ipairs(ENTRANCES) do
        local exit_name = entrance.exit
        if not is_exit_possible(entrance.exit) then
            print("Exit '" .. exit_name .. "' is impossible to reach")
            impossible_exits[exit_name] = true
        end
    end
    forceLogicUpdate()
end

update_entrances()