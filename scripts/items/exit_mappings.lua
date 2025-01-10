if EXIT_MAPPINGS_LOADED then
    print("WARNING: exit_mappings.lua has already been loaded")
    return
else
    print("INFO: Loading exit_mappings.lua")
    EXIT_MAPPINGS_LOADED = true
end

require("scripts/objects/entrance")
require("scripts/objects/exit")
require("scripts/logic/entrances")

if not ENTRANCE_RANDO_ENABLED then
    -- Do not create any items if entrance rando is not enabled.
    return false
end

-- Create a new entrance lua item. These are the main items that store the information on the current assignments of
-- exits to entrances.
function create_entrance_lua_item(idx, entrance)
    local mapping_item = ScriptHost:CreateLuaItem()

    if not mapping_item.ItemState then
        mapping_item.ItemState = {}
    end

    mapping_item.LoadFunc = function (self, data)
        debugPrint("Reading exit mapping for '%s' during load", entrance.name)
        -- "entrance_idx" is not saved/loaded.
        if data == nil then
            print("Error: Data to read for exit mapping " .. self.Name .. " was nil")
            -- The entrance's default exit_idx will be used.
            return
        end

        local loaded_exit_idx = data.exit_idx
        local old_idx = self.ItemState.exit_idx
        if loaded_exit_idx and loaded_exit_idx ~= old_idx then
            self.ItemState.exit_idx = loaded_exit_idx
            -- Assign the exit to the entrance if it is not vanilla.
            debugPrint("Assigning non vanilla exit for '%s'", entrance.name)
            entrance:Assign(EXITS[loaded_exit_idx], true, true)
        else
            debugPrint("Updating for vanilla exit for '%s'", entrance.name)
            entrance:UpdateItemIcon(self)
            entrance:UpdateItemName(item)
            --entrance:UpdateLocationSection()
        end
    end

    mapping_item.SaveFunc = function (self)
        --print("Saving exit mapping data")
        -- "entrance_idx" is not saved/loaded.
        return { exit_idx = self.ItemState.exit_idx }
    end

    mapping_item.ItemState.entrance_idx = idx

    local loaded_idx = mapping_item.ItemState.exit_idx

    if not loaded_idx then
        -- Start unassigned.
        mapping_item.ItemState.exit_idx = 0
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
        local entrance = ENTRANCES[self.ItemState.entrance_idx]
        local exit = entrance.exit
        if exit then
            -- Unassign the exit that is assigned to this entrance.
            entrance:Unassign()
        else
            -- Select the entrance.
            Entrance.Select(entrance)

            -- Swap to exits tab so the user can pick the exit to assign.
            Tracker:UiHint("ActivateTab", "Select Exit")
        end
    end

    if loaded_idx and loaded_idx ~= idx then
        -- Assign the exit to the entrance if it is not vanilla.
        entrance:Assign(EXITS[loaded_idx], true, true)
    end

    -- TODO: If an exit has been assigned to an exit mapping, can we make the exit location appear as checkable?
    --       This way, we can tell apart locations we can/cannot access and which of those have been assigned
end

-- Create a new exit lua item. These are the placeholder items that users click on to assign a specific exit after
-- clicking on an exit mapping lua item.
function create_exit_lua_item(idx, exit)
    local exit_item = ScriptHost:CreateLuaItem()

    if not exit_item.ItemState then
        exit_item.ItemState = {}
    end

    local exit_name = exit.Name

    exit_item.Name = exit_name
    exit_item.Icon = ImageReference:FromPackRelativePath("images/items/exits/" .. exit_name .. ".png")

    local codeFunc = function(self, code)
        return code == exit_name
    end
    exit_item.CanProvideCodeFunc = codeFunc
    exit_item.ProvidesCodeFunc = codeFunc
    exit_item.OnLeftClickFunc = function(self)
        local selected_entrance = Entrance.SelectedEntrance
        if selected_entrance then
            if exit.Entrance then
                -- Can't pick an exit that has already been assigned
                return
            end

            -- Don't update the icon for `selected_entrance` because the Assign() call will do so too.
            Entrance.Select(nil, true)
            selected_entrance:Assign(exit)

            -- Switch back to the assignment tab.
            Tracker:UiHint("ActivateTab", "Assignment")
        end
    end

    exit_item.ItemState.exit_idx = idx
end

-- Lua item creation and initialization
PAUSE_ENTRANCE_UPDATES = true
for idx, entrance in ipairs(ENTRANCES) do
    create_entrance_lua_item(idx, entrance)
    create_exit_lua_item(idx, entrance.vanilla_exit)
    -- Unassign each entrance. Prevent logic and section updates. The sections won't exist yet.
    entrance:Unassign(PAUSE_ENTRANCE_UPDATES, false, true)
end
PAUSE_ENTRANCE_UPDATES = false

update_entrances(true)

return true