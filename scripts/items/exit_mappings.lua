if EXIT_MAPPINGS_LOADED then
    print("WARNING: exit_mappings.lua has already been loaded")
    return
else
    print("INFO: Loading exit_mappings.lua")
    EXIT_MAPPINGS_LOADED = true
end

require("scripts/utils")
require("scripts/objects/entrance")
require("scripts/objects/exit")

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
        debugPrint("Reading exit mapping for '%s' during load", entrance.Name)
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
            debugPrint("Assigning non vanilla exit for '%s'", entrance.Name)
            entrance:Assign(EXITS[loaded_exit_idx], true, true)
        else
            debugPrint("Updating for vanilla exit for '%s'", entrance.Name)
            entrance:UpdateEntranceItemIconMods(self)
            entrance:UpdateEntranceItemNameAndOverlayText(item)
            --entrance:UpdateLocationSection()
        end
    end

    mapping_item.SaveFunc = function (self)
        --print("Saving exit mapping data")
        -- "entrance_idx" is not saved/loaded.
        return { exit_idx = self.ItemState.exit_idx }
    end

    -- The entrance_idx identifies which Entrance object in ENTRANCES this lua item represents.
    mapping_item.ItemState.entrance_idx = idx

    local loaded_idx = mapping_item.ItemState.exit_idx

    if not loaded_idx then
        -- Start unassigned.
        mapping_item.ItemState.exit_idx = 0
    end

    local entrance_name = entrance.Name
    mapping_item.Name = entrance_name

    mapping_item.CanProvideCodeFunc = function(self, code)
        return code == entrance_name
    end
    mapping_item.ProvidesCodeFunc = function(self, code)
        -- Note: Must return bool/int. Returning `nil` or a table is not allowed.
        --       Returning int 0/1 should be slightly faster.
        if code == entrance_name and entrance.Exit then
            -- Provide code when assigned.
            return 1
        else
            return 0
        end
    end

    -- Select the mapping for assignment, or deselect it if it is selected.
    mapping_item.OnLeftClickFunc = function(self)
        local exit = entrance.Exit

        if exit ~= nil then
            -- Already assigned. Use right click to unassign.
            return
        end

        if entrance:IsSelected() then
            -- Deselect the entrance if it was selected.
            Entrance.Select(nil)
        else
            local selected_exit = Exit.SelectedExit
            if selected_exit then
                -- Assign the selected exit to this entrance.

                -- Dont' update the icon for `selected_exit` because the Assign() call will do so too.
                Exit.Select(nil, true)
                entrance:Assign(selected_exit)

                -- The user selected an exit first, so switch back to the exits tab.
                Tracker:UiHint("ActivateTab", "Exits")
            else
                -- Select the entrance.
                Entrance.Select(entrance)

                -- Swap to exits tab so the user can pick the exit to assign.
                Tracker:UiHint("ActivateTab", "Exits")
            end
        end
    end

    -- Unassign the exit from this entrance, or deselect this entrance if it is selected.
    mapping_item.OnRightClickFunc = function(self)
        local exit = entrance.Exit
        if exit then
            -- Unassign the exit that is assigned to this entrance.
            entrance:Unassign()
        elseif entrance:IsSelected() then
            -- Deselect the entrance if it was selected.
            Entrance.Select(nil)
        end
    end

    if loaded_idx and loaded_idx ~= idx then
        -- Assign the exit to the entrance if it is not vanilla.
        entrance:Assign(EXITS[loaded_idx], true, true)
    end

    mapping_item:SetOverlayAlign("left")
    -- Looks to be about the same size as section text.
    mapping_item:SetOverlayFontSize(10)

    mapping_item.Icon = ImageReference:FromPackRelativePath(entrance.IconPath)

    -- Initialize this entrance's static json items displayed in a table that use overlay text to display which exit
    -- each entrance leads to.
    entrance:InitializeLabels()
end

-- Create a new exit lua item. These are the placeholder items that users click on to assign a specific exit after
-- clicking on an entrance lua item. Exit lua items are effectively static, their index never changes and is neither
-- loaded nor saved to auto-save/exported state.
-- Clicking on an exit lua item first and then
function create_exit_lua_item(idx, exit)
    local exit_item = ScriptHost:CreateLuaItem()

    if not exit_item.ItemState then
        exit_item.ItemState = {}
    end

    local exit_name = exit.Name

    exit_item.Name = exit_name
    exit_item.Icon = ImageReference:FromPackRelativePath(exit.IconPath)

    exit_item.CanProvideCodeFunc = function(self, code)
        return code == exit_name
    end
    exit_item.ProvidesCodeFunc = function(self, code)
        -- Note: Must return bool/int. Returning `nil` or a table is not allowed.
        --       Returning 0/1 should be slightly faster.
        if code == exit_name and exit.Entrance then
            -- Provide code when assigned.
            return 1
        else
            return 0
        end
    end
    exit_item.OnLeftClickFunc = function(self)
        local entrance = exit.Entrance

        if entrance ~= nil then
            -- Already assigned. Use right click to unassign.
            return
        end

        if exit:IsSelected() then
            -- Deselect the exit if it was selected.
            Exit.Select(nil)
        else
            local selected_entrance = Entrance.SelectedEntrance
            if selected_entrance then
                -- Assign this exit to the selected entrance.

                -- Don't update the icon for `selected_entrance` because the Assign() call will do so too.
                Entrance.Select(nil, true)
                selected_entrance:Assign(exit)

                -- Switch back to the Entrances tab.
                Tracker:UiHint("ActivateTab", "Entrances")
            else
                -- Select the exit.
                Exit.Select(exit)

                -- Swap to the entrances tab to the user can pick the entrance to assign to.
                Tracker:UiHint("ActivateTab", "Entrances")
            end
        end
    end

    exit_item.OnRightClickFunc = function(self)
        local entrance = exit.Entrance
        if entrance then
            -- Unassign this exit from its entrance.
            entrance:Unassign()
        elseif exit:IsSelected() then
            -- Deselect the exit if it was selected.
            Exit.Select(nil)
        end
    end

    exit_item.ItemState.exit_idx = idx

    exit_item:SetOverlayAlign("left")
    -- Looks to be about the same size as section text.
    exit_item:SetOverlayFontSize(10)

    exit:InitializeLabels()
end

local function createItemsAndUnassignAllExits()
    -- Lua item creation and initialization
    for idx, entrance in ipairs(ENTRANCES) do
        create_entrance_lua_item(idx, entrance)
        create_exit_lua_item(idx, entrance.VanillaExit)
    end

    -- Unassign each entrance. Prevent section updates because the sections won't exist yet.
    Entrance.UnassignAll(false, false, true)
end


createItemsAndUnassignAllExits()

-- Can be used to check if LuaItems are guaranteed to exist yet.
EXIT_MAPPINGS_FULLY_LOADED = true

return true