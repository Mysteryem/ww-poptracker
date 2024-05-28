require("scripts/logic/entrances")

EXITS = {
    "Dragon Roost Cavern",
    "Forbidden Woods",
    "Tower of the Gods",
    "Earth Temple",
    "Wind Temple",
    "Forbidden Woods Miniboss Arena",
    "Tower of the Gods Miniboss Arena",
    "Earth Temple Miniboss Arena",
    "Wind Temple Miniboss Arena",
    "Master Sword Chamber",
    "Gohma Boss Arena",
    "Kalle Demos Boss Arena",
    "Gohdan Boss Arena",
    "Helmaroc King Boss Arena",
    "Jalhalla Boss Arena",
    "Molgera Boss Arena",
    "Savage Labyrinth",
    "Dragon Roost Island Secret Cave",
    "Fire Mountain Secret Cave",
    "Ice Ring Isle Secret Cave",
    "Cabana Labyrinth",
    "Needle Rock Isle Secret Cave",
    "Angular Isles Secret Cave",
    "Boating Course Secret Cave",
    "Stone Watcher Island Secret Cave",
    "Overlook Island Secret Cave",
    "Bird's Peak Rock Secret Cave",
    "Pawprint Isle Chuchu Cave",
    "Pawprint Isle Wizzrobe Cave",
    "Diamond Steppe Island Warp Maze Cave",
    "Bomb Island Secret Cave",
    "Rock Spire Isle Secret Cave",
    "Shark Island Secret Cave",
    "Cliff Plateau Isles Secret Cave",
    "Horseshoe Island Secret Cave",
    "Star Island Secret Cave",
    "Ice Ring Isle Inner Cave",
    "Cliff Plateau Isles Inner Cave",
    "Outset Fairy Fountain",
    "Thorned Fairy Fountain",
    "Eastern Fairy Fountain",
    "Western Fairy Fountain",
    "Southern Fairy Fountain",
    "Northern Fairy Fountain"
}

NUM_EXITS = #EXITS

function exit_mapping_update(lua_item)
    local entrance_idx = lua_item:Get("entrance_idx")
    local entrance = ENTRANCES[entrance_idx]
    local exit_idx = lua_item:Get("exit_idx")
    local exit_name = EXITS[exit_idx]
    if exit_name then
        lua_item.Icon = ImageReference:FromPackRelativePath("images/items/exits/" .. exit_name .. ".png")
        entrance.exit = exit_name
        --lua_item.Name = exit_name
    else
        lua_item.Icon = ImageReference:FromPackRelativePath("images/items/exits/Unknown.png")
        entrance.exit = nil
        --lua_item.Name = "Unknown"
    end
    update_entrances()
end

function exit_mapping_save_func(lua_item)
    print("Saving exit mapping data")
    return lua_item.ItemState
end

function exit_mapping_load_func(lua_item, data)
    print("Reading exit mapping during load:")
    for k, v in pairs(data) do
        print("  " .. k .. ": " .. tostring(v))
        lua_item:Set(k, v)
    end
    exit_mapping_update(lua_item)
end

-- Cycle to the next exit
function exit_mapping_left_click(lua_item)
    local exit_idx = lua_item:Get("exit_idx")
    exit_idx = exit_idx + 1
    if exit_idx > NUM_EXITS then
        exit_idx = 0
    end
    lua_item:Set("exit_idx", exit_idx)
    exit_mapping_update(lua_item)
end

-- Cycle to the previous exit
function exit_mapping_right_click(lua_item)
    local exit_idx = lua_item:Get("exit_idx")
    exit_idx = exit_idx - 1
    if exit_idx < 0 then
        exit_idx = NUM_EXITS
    end
    lua_item:Set("exit_idx", exit_idx)
    exit_mapping_update(lua_item)
end

-- Reset back to "Unknown" exit
function exit_mapping_middle_click(lua_item)
    local exit_idx = lua_item:Get("exit_idx")
    if exit_idx == 0 then
        -- No changes
        return
    end
    lua_item:Set("exit_idx", 0)
    exit_mapping_update(lua_item)
end

function create_lua_item(idx, entrance)
    local item = ScriptHost:CreateLuaItem()

    if not item.ItemSate then
        item.ItemState = {}
    end

    item.LoadFunc = exit_mapping_load_func
    item.SaveFunc = exit_mapping_save_func

    item:Set("entrance_idx", idx)

    if not item:Get("exit_idx") then
        item:Set("exit_idx", idx)
    end

    local entrance_name = entrance.name
    item.Name = entrance_name
--
--     item.Icon = ImageReference:FromPackRelativePath("images/items/exits/" .. entrance.exit .. ".png")

    item.CanProvideCodeFunc = function(self, code) return code == entrance_name end
    item.ProvidesCodeFunc = function(self, code) return code == entrance_name end
    item.OnLeftClickFunc = exit_mapping_left_click
    item.OnRightClickFunc = exit_mapping_right_click
    item.OnMiddleClickFunc = exit_mapping_middle_click
    exit_mapping_update(item)
end

PAUSE_ENTRANCE_UPDATES = true
for idx, entrance in ipairs(ENTRANCES) do
   create_lua_item(idx, entrance)
end
PAUSE_ENTRANCE_UPDATES = false
update_entrances()