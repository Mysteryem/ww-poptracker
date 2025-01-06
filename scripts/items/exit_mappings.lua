require("scripts/logic/entrances")
if not ENTRANCE_RANDO_ENABLED then
    return false
end

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
NAME_TO_EXIT_IDX = {}
for idx, name in ipairs(EXITS) do
    NAME_TO_EXIT_IDX[name] = idx
end

NUM_EXITS = #EXITS

_selected_exit_mapping_idx = nil
function set_selected_exit_mapping(new_mapping)
    local new_idx = nil
    if new_mapping then
        new_idx = new_mapping:Get("entrance_idx")
    end

    local old_idx = _selected_exit_mapping_idx
    if old_idx == new_idx then
        -- Nothing to do.
        return
    end
    _selected_exit_mapping_idx = new_idx

    if new_idx then
        update_exit_mapping_icon(new_mapping)
    end

    if old_idx then
        local old_entrance = ENTRANCES[old_idx]
        if old_entrance then
            local old_mapping = Tracker:FindObjectForCode(old_entrance.name)
            update_exit_mapping_icon(old_mapping)
        end
    end
end

function is_selected_exit_mapping(mapping)
    return _selected_exit_mapping_idx and mapping and mapping:Get("entrance_idx") == _selected_exit_mapping_idx
end

function get_selected_exit_mapping()
    if _selected_exit_mapping_idx then
        local entrance = ENTRANCES[_selected_exit_mapping_idx]
        return Tracker:FindObjectForCode(entrance.name)
    else
        return nil
    end
end

function update_exit_mapping_icon(self, entrance_name, exit_name)
    if not entrance_name then
        local entrance_idx = self:Get("entrance_idx")
        local entrance = ENTRANCES[entrance_idx]
        entrance_name = entrance.name
    end

    if not exit_name then
        local exit_idx = self:Get("exit_idx")
        exit_name = EXITS[exit_idx]
    end

    local entrance_icon = "images/items/entrances/" .. entrance_name .. ".png"

    local exit_overlay = "overlay|images/items/entrances/exits/"
    if exit_name then
        exit_overlay = exit_overlay .. exit_name .. ".png"
    else
        exit_overlay = exit_overlay .. "Unknown.png"
    end

    local full_icon_path = entrance_icon .. ":" .. exit_overlay

    if is_selected_exit_mapping(self) then
        -- TODO: Instead of the colour overlay, use a different image to "Unknown.png" that says "Select Exit or Cancel"
        -- Apply an outline to the selected exit mapping
        full_icon_path = full_icon_path .. ",overlay|images/items/entrances/active_overlay.png"
    end
    -- We use .IconMods to mark impossible to reach exits with @disabled, so pre-add the icon mods in the
    -- ImageReference for .Icon instead.
    --print("updating .Icon to: " .. full_icon_path)
    self.Icon = ImageReference:FromPackRelativePath(full_icon_path)
end

-- Update an exit mapping's name, image and exit name after its "exit_idx" has been changed
function exit_mapping_update(self, old_exit_idx)
    local initial_creation = old_exit_idx == nil
    local entrance_idx = self:Get("entrance_idx")
    local entrance = ENTRANCES[entrance_idx]
    local entrance_name = entrance.name
    local exit_idx = self:Get("exit_idx")
    local exit_name = EXITS[exit_idx]

    -- Items are created before locations, so during creation of the exit mappings, the location sections to clear/reset
    -- won't exist yet.
    local entrance_location_section
    if not initial_creation then
        entrance_location_section = Tracker:FindObjectForCode(entrance.entrance_logic .. "/Can Enter")
    end

    -- Update the new exit
    if exit_name then
        --print("Assigning "..exit_name.." to "..entrance_name)
        entrance.exit = exit_name
        self.Name = entrance_name ..  " -> " .. exit_name
        local exit_item = Tracker:FindObjectForCode(exit_name)
        if exit_item then
            exit_item.Name = entrance_name .. " -> " .. exit_name
            -- Exit is assigned, grey it out.
            exit_item.IconMods = "@disabled"
        end
        -- Clear the "Can Enter" chest.
        if entrance_location_section then
            entrance_location_section.AvailableChestCount = entrance_location_section.AvailableChestCount - 1
        end
    else
        --print("Unassiging entrance "..entrance_name)
        entrance.exit = nil
        self.Name = "Click to assign " .. entrance_name
        -- Reset the "Can Enter" chest.
        if entrance_location_section then
            entrance_location_section.AvailableChestCount = entrance_location_section.ChestCount
        end
    end

    -- Update the old exit, if there was an old exit.
    local old_exit_name = EXITS[old_exit_idx or 0]
    if old_exit_name then
        local old_exit_item = Tracker:FindObjectForCode(old_exit_name)
        if old_exit_item then
            old_exit_item.Name = old_exit_name
            -- Exit is no longer assigned, remove the @disabled modifier from its icon.
            old_exit_item.IconMods = "none"
        end
    end

    update_exit_mapping_icon(self, entrance_name, exit_name)
    update_entrances()
end

function exit_mapping_assign(self, new_exit)
    local new_exit_name
    local new_exit_idx
    if type(new_exit) == "number" then
        new_exit_idx = new_exit
        new_exit_name = EXITS[new_exit]
    else
        new_exit_name = new_exit
        if new_exit == nil then
            new_exit_idx = 0
        else
            new_exit_idx = NAME_TO_EXIT_IDX[new_exit] or 0
        end
        if new_exit_idx == 0 and new_exit_name then
            print("No exit found with the name '" .. new_exit_name .. "'")
            new_exit_name = nil
        end
    end

    local entrance = ENTRANCES[self:Get("entrance_idx")]
    if entrance and entrance.exit then
        -- Can't change the exit if the entrance already has an exit assigned.
        if entrance.exit == new_exit_name then
            -- Already assigned
            return true
        else
            return false
        end
    end

    local already_assigned_entrance = exit_to_entrance[new_exit_name]
    if already_assigned_entrance then
        -- Can't assign to an exit that has already been assigned.
        return false
    end

    local old_idx = self:Get("exit_idx")
    if new_exit_idx == old_idx then
        -- No changes needed
        print(self.Name .. "is already assigned to exit_idx" .. tostring(new_exit_idx))
        return true
    end
    self:Set("exit_idx", new_exit_idx)

    exit_mapping_update(self, old_idx)
    return true
end

function exit_mapping_clear(self)
    local entrance = ENTRANCES[self:Get("entrance_idx")]
    if entrance and entrance.exit then
        entrance.exit = nil
    end

    local old_idx = self:Get("exit_idx")
    if old_idx ~= 0 then
        self:Set("exit_idx", 0)
        exit_mapping_update(self, old_idx)
    else
        -- Ensure the section is reset if it was manually cleared by the user.
        local entrance_location_section = Tracker:FindObjectForCode(entrance.entrance_logic .. "/Can Enter")
        if entrance_location_section then
            entrance_location_section.AvailableChestCount = entrance_location_section.ChestCount
        end
    end
end

function clearExitMappings()
    for _, entrance in ipairs(ENTRANCES) do
        local exit_mapping = Tracker:FindObjectForCode(entrance.name)
        exit_mapping_clear(exit_mapping)
    end
end

function create_mapping_lua_item(idx, entrance)
    local mapping_item = ScriptHost:CreateLuaItem()

    if not mapping_item.ItemSate then
        mapping_item.ItemState = {}
    end

    mapping_item.LoadFunc = function (self, data)
        --print("Reading exit mapping during load")
        -- "entrance_idx" is not saved/loaded.
        if data == nil then
            print("Error: Data to read for exit mapping " .. self.Name .. " was nil")
            -- The entrance's default exit_idx will be used.
            return
        end

        local exit_idx = data.exit_idx
        local old_idx = self:Get("exit_idx")
        if exit_idx then
            self:Set("exit_idx", exit_idx)
        end
        exit_mapping_update(self, old_idx)
    end

    mapping_item.SaveFunc = function (self)
        --print("Saving exit mapping data")
        -- "entrance_idx" is not saved/loaded.
        return { exit_idx = self.ItemState.exit_idx }
    end

    mapping_item:Set("entrance_idx", idx)

    if not mapping_item:Get("exit_idx") then
        -- Start unassigned.
        mapping_item:Set("exit_idx", 0)
    end

    local entrance_name = entrance.name
    mapping_item.Name = entrance_name

    local codeFunc = function(self, code)
        return code == entrance_name
    end
    mapping_item.CanProvideCodeFunc = codeFunc
    mapping_item.ProvidesCodeFunc = codeFunc

    -- Select the mapping for assignment or clear the exit mapping if already assigned
    mapping_item.OnLeftClickFunc = function (self)
        local old_idx = self:Get("exit_idx")
        if old_idx ~= 0 then
            -- Clear the mapping
            self:Set("exit_idx", 0)
            exit_mapping_update(self, old_idx)
            return
        else
            if is_selected_exit_mapping(self) then
                -- Cancel the selection of this entrance. There is no real need to do this.
                set_selected_exit_mapping(nil)
            else
                set_selected_exit_mapping(self)
                -- Swap to exits tab so the user can pick the exit to assign.
                Tracker:UiHint("ActivateTab", "Select Exit")
            end
        end
    end
    exit_mapping_update(mapping_item, nil)

    -- TODO: If an exit has been assigned to an exit mapping, can we make the exit location appear as checkable?
    --       This way, we can tell apart locations we can/cannot access and which of those have been assigned
end

function create_exit_lua_item(idx)
    local exit_item = ScriptHost:CreateLuaItem()

    if not exit_item.ItemSate then
        exit_item.ItemState = {}
    end

    local exit_name = EXITS[idx]

    exit_item:Set("display_name", exit_name)

    exit_item.Name = exit_name
    exit_item.Icon = ImageReference:FromPackRelativePath("images/items/exits/" .. exit_name .. ".png")

    codeFunc = function(self, code) return code == exit_name end
    exit_item.CanProvideCodeFunc = codeFunc
    exit_item.ProvidesCodeFunc = codeFunc
    exit_item.OnLeftClickFunc = function(self)
        local selected = get_selected_exit_mapping()
        if selected then
            local already_assigned_entrance = exit_to_entrance[exit_name]
            if already_assigned_entrance then
                -- Can't pick an exit that has already been assigned.
                return
            end

            --selected_exit_mapping = nil
            local old_idx = selected:Get("exit_idx")
            selected:Set("exit_idx", idx)

            set_selected_exit_mapping(nil)
            exit_mapping_update(selected, old_idx)
            Tracker:UiHint("ActivateTab", "Assignment")
        end
    end

    exit_item:Set("exit_idx", idx)
end

PAUSE_ENTRANCE_UPDATES = true
for idx, entrance in ipairs(ENTRANCES) do
   create_mapping_lua_item(idx, entrance)
   create_exit_lua_item(idx)
end
PAUSE_ENTRANCE_UPDATES = false

if ENTRANCE_RANDO_ENABLED then
    update_entrances()
end

return true