if ENTRANCE_LOADED then
    print("WARNING: entrance.lua has already been loaded.")
    return
else
    print("INFO: Loading entrance.lua")
    ENTRANCE_LOADED = true
end

require("scripts/objects/exit")
require("scripts/utils")

-- Entrances may by set by the user such that they form loops that make access to some areas impossible. All of the
-- entrances/exits in the loop will be considered impossible.
-- Without entrance randomization, all exits will be vanilla, so no exits will be impossible.
logically_impossible_exits = {}
logically_impossible_entrances = {}

Entrance = {}
Entrance.__index = Entrance

function Entrance.New(name, vanilla_exit_name, entrance_type, icon_path, parent_exit_name, short_name)
    local self = setmetatable({}, Entrance)
    debugPrint("Creating Entrance %s", name)
    -- The name of this entrance.
    self.Name = name

    local vanilla_exit = EXITS_BY_NAME[vanilla_exit_name]
    if not vanilla_exit then
        local known_exits = ""
        for k, v in pairs(EXITS_BY_NAME) do
            known_exits = known_exits .. k .. ", "
        end
        error("No exit exists with the name '" .. tostring(vanilla_exit_name) .. "'. Known exits: " .. known_exits)
    end

    -- Set `self` as the entrance to the Exit.
    if vanilla_exit.Entrance then
        error("'" .. vanilla_exit.Name .. "' is already assigned to " .. vanilla_exit.Entrance.Name)
    end
    debugPrint("Assigned %s as the entrance used by exit %s", self.Name, vanilla_exit.Name)
    vanilla_exit.Entrance = self

    -- The vanilla exit, stored here for simpler lookup.
    self.VanillaExit = vanilla_exit
    -- The exit that has been assigned to this entrance. Always starts off as vanilla and won't change if Entrance
    -- Randomization is not enabled.
    self.Exit = vanilla_exit
    -- There are no entrances accessible from multiple different exits, so a single parent_exit is all that is needed.
    -- Is always accessible when not set, indicating that its parent exit name would be "The Great Sea".
    if parent_exit_name then
        local parent_exit = EXITS_BY_NAME[parent_exit_name]

        if not parent_exit then
            local known_exits = ""
            for k, v in pairs(EXITS_BY_NAME) do
                known_exits = known_exits .. k .. ", "
            end
            error("No exit exists with the name '" .. tostring(parent_exit_name) .. "'. Known exits: " .. known_exits)
        end

        self.ParentExit = parent_exit
    end
    -- The location which holds this entrance's logic.
    self.EntranceLogicPath = "@Entrance Logic/" .. name
    -- The type of the entrance: "dungeon", "miniboss", "boss", "secret_cave", "inner", "fairy".
    -- ER is enabled/disabled according to these categories, so this makes it easier to assign an entire category to
    -- their vanilla exits when connecting to Archipelago.
    self.EntranceType = entrance_type

    -- The icons and short name are only needed when ER is enabled because the lua items that display the icons and use
    -- the short names in overlay text over those icons, only exist when ER is enabled.
    if ENTRANCE_RANDO_ENABLED then
        self.IconPath = icon_path
        -- Default to the same short name as the vanilla exit.
        self.ShortName = short_name or vanilla_exit.ShortName
    end

    return self
end

function Entrance:GetAccessibility()
    -- The logic for each entrance is defined on a JSON location specific to that entrance. Because the logic is defined
    -- on the location and not the section within the location, there is no concern about the returned
    -- `AccessibilityLevel` being `AccessibilityLevel.Cleared`.
    -- Storing the logic on JSON locations *might* make the logic more resilient to infinite recursion issues because
    -- PopTracker normally handles infinite recursion in JSON rules, but it is unclear if this is the case.
    local location = Tracker:FindObjectForCode(self.EntranceLogicPath)
    return location.AccessibilityLevel
end

-- Most of the Entrance methods/functions are only defined when ER is enabled because they are not needed otherwise.
if ENTRANCE_RANDO_ENABLED then

    -- Recursive helper function used when updating entrance logic.
    -- Determine if an exit is possible to reach based on its Entrance and its Entrance's parent_exit.
    --
    -- Specific to The Wind Waker Entrance Randomization, ER cannot form loops, the user, however, can assign entrances
    -- such that they do form loops. Detecting these loops allows for a faster return when determining if an exit is
    -- accessible, but the logic appears to work without causing infinite recursion even when detecting loops is
    -- disabled and a loop is deliberately created.
    local function is_exit_possible(exit, checked_set)
        local exit_name = exit.Name

        if logically_impossible_exits[exit_name] then
            -- This exit has already been found to be impossible.
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
        local parent_exit = entrance.ParentExit
        if parent_exit == nil then
            -- The Great Sea is always accessible.
            debugPrint("%s is reachable due to its entrance's parent_exit being The Great Sea (nil)", exit_name)
            return true
        else
            return is_exit_possible(parent_exit, checked_set)
        end
    end

    -- Update which exits are impossible to reach, and then update logic.
    -- Call this after updating entrances, either individually or in bulk.
    --
    -- Impossible exits cause their entrances to have a red overlay and `logically_impossible_exits` functions as a
    -- logic short-circuit if a player makes the entrances form an impossible loop. This should be slightly faster than
    -- letting PopTracker recursively check for accessibility of looped entrances, but is not necessary for an entrance
    -- rando implementation.
    --
    -- Wind Waker's entrance randomization is quite simple compared to most games because there is only a single exit
    -- into each area, other than The Great Sea. For more complex entrance-rando, checking for impossible exits can
    -- probably be skipped, and then this function could be replaced with calling `forceLogicUpdate()` directly.
    function Entrance.UpdateEntranceLogic()
        if not ENTRANCE_RANDO_ENABLED then
            return
        end

        debugPrint("### Updating entrances logic ###")

        -- Check for impossible exits.
        -- This notably marks vanilla boss/miniboss entrances with randomized dungeon entrances because the vanilla
        -- entrances within the dungeons will be assigned to before the exits into the dungeons will be assigned.
        -- Get the exits that were previously logically impossible, so that some updates can be reduced to only those
        -- which have changed.
        local previously_impossible_exits = logically_impossible_exits
        local previously_impossible_entrances = logically_impossible_entrances
        -- Reset the global lookup tables.
        logically_impossible_exits = {}
        logically_impossible_entrances = {}
        debugPrint("Checking for and marking impossible exits")
        for _, exit in ipairs(EXITS) do
            -- An exit without an Entrance is obviously impossible, so we only check exits with an Entrance.
            local entrance = exit.Entrance
            if entrance and not is_exit_possible(exit) then
                debugPrint("Exit '%s' is impossible to reach", exit.Name)
                logically_impossible_exits[exit.Name] = true
                logically_impossible_entrances[entrance.Name] = true
            end
        end

        -- Visibly mark impossible exits
        if EXIT_MAPPINGS_FULLY_LOADED then
            for _, entrance in ipairs(ENTRANCES) do
                -- First process the current exit of this entrance.
                local exit = entrance.Exit
                local new_overlay_background
                if exit then
                    local exit_name = exit.Name
                    if logically_impossible_exits[exit_name] then
                        if not previously_impossible_exits[exit_name] then
                            debugPrint("Marked %s as impossible because its exit %s cannot be reached", entrance.Name, exit.Name)
                            -- Display a red background to signify that the entrance is impossible.
                            new_overlay_background = "#AAEE0000"
                        end
                    else
                        if previously_impossible_exits[exit_name] then
                            -- The exit was previously marked as impossible, but it is now possible, so clear the
                            -- overlay background.
                            new_overlay_background = "#00000000"
                        end
                    end

                    if new_overlay_background then
                        -- Update the background color of the exit's text overlay.
                        exit:GetItem():SetOverlayBackground(new_overlay_background)
                    end
                elseif previously_impossible_entrances[entrance.Name] then
                    -- The entrance was previously marked as impossible, but it is now possible, so clear the overlay
                    -- background.
                    new_overlay_background = "#00000000"
                end

                if new_overlay_background then
                    -- Update the background color of the entrance's text overlay.
                    entrance:GetItem():SetOverlayBackground(new_overlay_background)
                end

                -- Finally, if the vanilla exit is not assigned to an entrance, also process it, because there is not
                -- another entrance that will process it.
                local vanilla_exit = entrance.VanillaExit
                -- Ensure that every unassigned exit loses its red background if it was previously impossible.
                if vanilla_exit.Entrance == nil and previously_impossible_exits[vanilla_exit.Name] then
                    vanilla_exit:GetItem():SetOverlayBackground("#00000000")
                end
            end
        end

        -- Force logic to update because the result of lua functions that check exit accessibility may now give
        -- different results.
        -- If there is no need to care about whether an entrance's assignment is impossible, then an ER implementation
        -- can likely replace this entire `Entrance.UpdateEntranceLogic` function with just the `forceLogicUpdate()`
        -- call.
        forceLogicUpdate()
    end

    -- Return whether this Entrance is the currently selected entrance, i.e. the most recent unassigned entrance that
    -- the user clicked on.
    -- This is used when determining what icon mods should be shown over the Entrance's icon, allowing a selection
    -- highlight overlay to be shown on this Entrance's icon.
    function Entrance:IsSelected()
        return Entrance.SelectedEntrance == self
    end

    -- Select an Entrance. This is a function, not a method, because `nil` can be passed as the `entrance` to deselect
    -- whatever is the currently selected Entrance.
    -- If a dedicated `Entrance.Deselect()` function was added, this `Entrance.Select()` could be replaced with an
    -- `Entrance:Select()` method.
    -- Passing `true` as the second argument will suppress updating the icon of the currently selected Entrance.
    function Entrance.Select(entrance, prevent_currently_selected_item_icon_update)
        local currently_selected = Entrance.SelectedEntrance

        Entrance.SelectedEntrance = entrance

        -- Update the item icons for the entrances.
        if currently_selected and not prevent_currently_selected_item_icon_update then
            -- Update the icon to show that it is no longer selected.
            currently_selected:UpdateEntranceItemIconMods()
        end

        if entrance then
            -- Update the icon to show that it is selected.
            entrance:UpdateEntranceItemIconMods()
        end
    end

    -- Unassign an Entrance from its currently assigned exit.
    -- Arguments can be provided to suppress logic updates, suppress item updates and/or suppress section updates.
    function Entrance:Unassign(prevent_logic_update, prevent_item_updates, prevent_section_update)
        local current_exit = self.Exit
        if current_exit then
            -- Sanity check
            local current_exit_entrance = current_exit.Entrance
            if current_exit_entrance then
                if current_exit_entrance ~= self then
                    print(string.format("ERROR: While unassigning %s from %s, %s thought it was assigned to %s", current_exit.Name, self.Name, current_exit.Name, current_exit_entrance.Name))
                end
            else
                print(string.format("ERROR: While unassigning %s from %s, %s thought it was not assigned", current_exit.Name, self.Name, current_exit.Name))
            end

            -- Unassign from both.
            current_exit.Entrance = nil
            self.Exit = nil

            if not prevent_item_updates then
                self:UpdateItem()
                current_exit:UpdateItem()
                -- TODO: Rename LabelItem to TableItem or TextItem or TableTextItem
                self:UpdateLabelItem()
                current_exit:UpdateLabelItem()
            end

            if not prevent_logic_update then
                Entrance.UpdateEntranceLogic()
            end

            if not prevent_section_update then
                -- Reset the section
                self:UpdateLocationSection()
                current_exit:UpdateLocationSection()
            end
            debugPrint("%s: Unassigned %s", self.Name, current_exit.Name)
        else
            debugPrint("%s: Already has no assignment to unassign", self.Name)
        end
    end

    -- Unassign the Exits from all Entrances.
    -- Arguments can be provided to suppress logic updates, suppress item updates and/or suppress section updates.
    function Entrance.UnassignAll(prevent_logic_updates, prevent_item_updates, prevent_section_update)
        -- Unassign in bulk, not causing logic updates until all exits have been unassigned from entrances.
        for _, entrance in ipairs(ENTRANCES) do
            entrance:Unassign(true, prevent_item_updates, prevent_section_update)
        end
        if not prevent_logic_updates then
            Entrance.UpdateEntranceLogic()
        end
    end

    -- Assign an Exit to this Entrance. Passing `nil` as the Exit to assign unassigns the current Exit like
    -- `Entrance:Unassign()`.
    -- Replacing an already assigned Exit is only allowed when the `replace` argument is `true`.
    -- Logic updates are suppressed when the `prevent_logic_update` argument is `true`.
    --
    -- Returns whether the assignment was successful.
    function Entrance:Assign(new_exit, replace, prevent_logic_update)

        if new_exit then
            debugPrint("%s: Assigning exit %s", self.Name, new_exit.Name)
        else
            debugPrint("%s: Assigning exit nil", self.Name)
        end

        local current_exit = self.Exit
        if new_exit == current_exit then
            -- Nothing to do.
            debugPrint("%s: Already assigned", self.Name)
            return true
        end

        if new_exit == nil then
            self:Unassign(prevent_logic_update)
            -- Always succeeds.
            debugPrint("%s: Unassigned", self.Name)
            return true
        end

        local new_exit_current_entrance = new_exit.Entrance

        if new_exit_current_entrance then
            if not replace then
                print(string.format("ERROR: %s is already assigned to %s and cannot be assigned to %s", new_exit.Name, new_exit_current_entrance.Name, self.Name))
                return false
            else
                -- Unassign new_exit from its current Entrance and vice versa.
                -- Never update logic for this because either `prevent_logic_update` is `false` or we will update logic once
                -- `new_exit` has been assigned to `self`.
                -- Never update the exit item for this because we'll do that after assigning it to `self`.
                new_exit_current_entrance:Unassign(true, true)
            end
        end

        -- Finally assign the exit.
        self.Exit = new_exit
        new_exit.Entrance = self

        -- Update the new exit's section.
        new_exit:UpdateLocationSection()

        if current_exit ~= nil then
            -- The entrance's section is already cleared, so only update the current exit.
            current_exit:UpdateLocationSection()
            current_exit:UpdateItem()
            current_exit:UpdateLabelItem()
        else
            -- current_exit is nil, so the entrance's section was not cleared before, but should be cleared now that an
            -- exit has been assigned.
            self:UpdateLocationSection()
        end

        -- Update the items for the entrance and exit.
        self:UpdateItem()
        new_exit:UpdateItem()

        -- Update the items for the entrance and exit labels.
        self:UpdateLabelItem()
        new_exit:UpdateLabelItem()

        if not prevent_logic_update then
            Entrance.UpdateEntranceLogic()
        end

        debugPrint("%s: Assigned %s", self.Name, new_exit.Name)
        return true
    end

    -- Get the icon mods that should be used with the Entrance's item icon, determined by the current state of the
    -- Entrance.
    function Entrance:GetItemIconMods()
        local exit = self.Exit
        local exit_overlay

        if self:IsSelected() then
            if exit then
                -- Should not normally happen because an entrance with an exit assigned is unassigned when clicked on.
                return "@disabled,overlay|images/entrances/selection_highlight.png"
            else
                return "overlay|images/entrances/selection_highlight.png"
            end
        else
            if exit then
                -- Grey out when an exit is assigned
                return "@disabled"
            else
                return "none"
            end
        end
    end

    -- Get the item object for this Entrance.
    function Entrance:GetItem()
        return Tracker:FindObjectForCode(self.Name)
    end

    -- Update the Entrance's item's icon mods according to the current state of the Entrance.
    -- If the item object has already been retrieved, it can be passed as an argument to this method to skip retrieving
    -- the item object again.
    function Entrance:UpdateEntranceItemIconMods(item)
        item = item or self:GetItem()
        local icon_mods = self:GetItemIconMods()
        debugPrint("Updating %s icon mods to %s", self.Name, icon_mods)
        if item.IconMods ~= icon_mods then
            item.IconMods = icon_mods
        end
    end

    -- Update the index stored in the Entrance's item's `.ItemState`. The `.ItemState` is the data written to the
    -- tracker's auto-save state or any manually exported states. When the `.ItemState` for an Entrance's item is loaded
    -- when opening the tracker or when importing a state, the index set in the `.ItemState` determines the Exit that
    -- should be assigned to the Entrance, allowing for users to close and re-open the tracker without losing Entrance
    -- assignments.
    -- If the item object has already been retrieved, it can be passed as an argument to this method to skip retrieving
    -- the item object again.
    function Entrance:UpdateEntranceItemExitIndex(item)
        item = item or self:GetItem()
        item.ItemState.exit_idx = self:GetExitIndex()
    end

    -- Update the name of the Entrance item and its overlay text according to the current state of the Entrance.
    -- If the item object has already been retrieved, it can be passed as an argument to this method to skip retrieving
    -- the item object again.
    function Entrance:UpdateEntranceItemNameAndOverlayText(item)
        item = item or self:GetItem()
        local exit = self.Exit
        local new_name
        local new_text_overlay
        if exit then
            new_name = self.Name .. " -> " .. exit.Name
            new_text_overlay = "to " .. exit.ShortName
        else
            new_name = "Click to assign an exit to " .. self.Name
            new_text_overlay = ""
        end
        if item.Name ~= new_name then
            item.Name = new_name
            item:SetOverlay(new_text_overlay)
        end
    end

    function Entrance:UpdateItem(item)
        item = item or self:GetItem()
        self:UpdateEntranceItemIconMods(item)
        self:UpdateEntranceItemExitIndex(item)
        self:UpdateEntranceItemNameAndOverlayText(item)
    end

    function Entrance:GetLabelItem()
        return Tracker:FindObjectForCode("Label for " .. self.Name)
    end

    function Entrance:GetLabelPlaceholderItem()
        return Tracker:FindObjectForCode("Label placeholder for " .. self.Name)
    end

    function Entrance:InitializeLabels()
        -- The label on the left that shows the entrance name.
        local label_placeholder = self:GetLabelPlaceholderItem()
        label_placeholder:SetOverlayAlign("right")
        label_placeholder:SetOverlay(self.ShortName)
        label_placeholder:SetOverlayColor("#FFFFFFFF")

        -- The label on the right that shows the assigned exit.
        local label = self:GetLabelItem()
        label:SetOverlayAlign("left")
        label:SetOverlayColor("#FFAAAAAA")
    end

    function Entrance:UpdateLabelItem()
        local item = self:GetLabelItem()
        if item == nil then
            debugPrint("Could not get label item for entrance %s", self.Name)
            return
        end
        local exit = self.Exit
        local new_text_overlay
        if exit then
            new_text_overlay = exit.ShortName
            item:SetOverlayBackground("#00000000")
        else
            new_text_overlay = "                                                 "
            item:SetOverlayBackground("#FF222222")
        end
        item:SetOverlay(new_text_overlay)
    end

    function Entrance:UpdateLocationSection()
        debugPrint("%s: Updating section", self.Name)
        local entrance_location_section = Tracker:FindObjectForCode(self.EntranceLogicPath .. "/Can Enter")
        if self.Exit then
            -- Clear the section
            entrance_location_section.AvailableChestCount = entrance_location_section.AvailableChestCount - 1
        else
            -- Reset the section
            entrance_location_section.AvailableChestCount = entrance_location_section.ChestCount
        end
    end

    function Entrance:GetExitIndex()
        local exit = self.Exit
        if exit then
            return exit.Index
        else
            return 0
        end
    end
end


-- Each entrance starts with its vanilla exit.
ENTRANCES = {
    Entrance.New("Dungeon Entrance on Dragon Roost Island", "Dragon Roost Cavern", "dungeon", "images/entrances/entrance_dungeon_drc.png"),
    Entrance.New("Dungeon Entrance in Forest Haven Sector", "Forbidden Woods", "dungeon", "images/entrances/entrance_dungeon_fw.png"),
    Entrance.New("Dungeon Entrance in Tower of the Gods Sector", "Tower of the Gods", "dungeon", "images/entrances/entrance_dungeon_totg.png"),
    Entrance.New("Dungeon Entrance on Headstone Island", "Earth Temple", "dungeon", "images/entrances/entrance_headstone.png"),
    Entrance.New("Dungeon Entrance on Gale Isle", "Wind Temple", "dungeon", "images/entrances/entrance_dungeon_wt.png"),
    Entrance.New("Miniboss Entrance in Forbidden Woods", "Forbidden Woods Miniboss Arena", "miniboss", "images/items/smallkey.png", "Forbidden Woods", "FW Miniboss Door"),
    Entrance.New("Miniboss Entrance in Tower of the Gods", "Tower of the Gods Miniboss Arena", "miniboss", "images/items/smallkey.png", "Tower of the Gods", "TotG Miniboss Door"),
    Entrance.New("Miniboss Entrance in Earth Temple", "Earth Temple Miniboss Arena", "miniboss", "images/items/smallkey.png", "Earth Temple", "ET Miniboss Door"),
    Entrance.New("Miniboss Entrance in Wind Temple", "Wind Temple Miniboss Arena", "miniboss", "images/items/smallkey.png", "Wind Temple", "WT Miniboss Door"),
    Entrance.New("Miniboss Entrance in Hyrule Castle", "Master Sword Chamber", "miniboss", "images/entrances/entrance_mastersword.png"),
    Entrance.New("Boss Entrance in Dragon Roost Cavern", "Gohma Boss Arena", "boss", "images/items/bigkey2.png", "Dragon Roost Cavern", "DRC Boss Door"),
    Entrance.New("Boss Entrance in Forbidden Woods", "Kalle Demos Boss Arena", "boss", "images/items/bigkey2.png", "Forbidden Woods", "FW Boss Door"),
    Entrance.New("Boss Entrance in Tower of the Gods", "Gohdan Boss Arena", "boss", "images/items/bigkey2.png", "Tower of the Gods", "TotG Boss Door"),
    Entrance.New("Boss Entrance in Forsaken Fortress", "Helmaroc King Boss Arena", "boss", "images/entrances/entrance_ff.png", _NIL_PARENT_EXIT, "FF Boss Door"),
    Entrance.New("Boss Entrance in Earth Temple", "Jalhalla Boss Arena", "boss", "images/items/bigkey2.png", "Earth Temple", "ET Boss Door"),
    Entrance.New("Boss Entrance in Wind Temple", "Molgera Boss Arena", "boss", "images/items/bigkey2.png", "Wind Temple", "WT Boss Door"),
    Entrance.New("Secret Cave Entrance on Outset Island", "Savage Labyrinth", "secret_cave", "images/entrances/entrance_headstone.png"),
    Entrance.New("Secret Cave Entrance on Dragon Roost Island", "Dragon Roost Island Secret Cave", "secret_cave", "images/entrances/entrance_rock.png"),
    Entrance.New("Secret Cave Entrance on Fire Mountain", "Fire Mountain Secret Cave", "secret_cave", "images/entrances/entrance_fire_mountain.png"),
    Entrance.New("Secret Cave Entrance on Ice Ring Isle", "Ice Ring Isle Secret Cave", "secret_cave", "images/entrances/entrance_ice_ring_isle.png"),
    Entrance.New("Secret Cave Entrance on Private Oasis", "Cabana Labyrinth", "secret_cave", "images/entrances/entrance_cabana.png"),
    Entrance.New("Secret Cave Entrance on Needle Rock Isle", "Needle Rock Isle Secret Cave", "secret_cave", "images/entrances/entrance_needle_rock_isle.png"),
    Entrance.New("Secret Cave Entrance on Angular Isles", "Angular Isles Secret Cave", "secret_cave", "images/entrances/entrance_hole.png"),
    Entrance.New("Secret Cave Entrance on Boating Course", "Boating Course Secret Cave", "secret_cave", "images/entrances/entrance_hole.png"),
    Entrance.New("Secret Cave Entrance on Stone Watcher Island", "Stone Watcher Island Secret Cave", "secret_cave", "images/entrances/entrance_headstone.png"),
    Entrance.New("Secret Cave Entrance on Overlook Island", "Overlook Island Secret Cave", "secret_cave", "images/entrances/entrance_hole.png"),
    Entrance.New("Secret Cave Entrance on Bird's Peak Rock", "Bird's Peak Rock Secret Cave", "secret_cave", "images/entrances/entrance_bird's_peak.png"),
    Entrance.New("Secret Cave Entrance on Pawprint Isle", "Pawprint Isle Chuchu Cave", "secret_cave", "images/entrances/entrance_pawprint_isle_chuchu.png", _NIL_PARENT_EXIT, "Pawprint Isle Cave"),
    Entrance.New("Secret Cave Entrance on Pawprint Isle Side Isle", "Pawprint Isle Wizzrobe Cave", "secret_cave", "images/entrances/entrance_hole.png", _NIL_PARENT_EXIT, "Pawprint Isle Side Isle Cave"),
    Entrance.New("Secret Cave Entrance on Diamond Steppe Island", "Diamond Steppe Island Warp Maze Cave", "secret_cave", "images/entrances/entrance_hole.png"),
    Entrance.New("Secret Cave Entrance on Bomb Island", "Bomb Island Secret Cave", "secret_cave", "images/entrances/entrance_rock.png"),
    Entrance.New("Secret Cave Entrance on Rock Spire Isle", "Rock Spire Isle Secret Cave", "secret_cave", "images/entrances/entrance_rock.png"),
    Entrance.New("Secret Cave Entrance on Shark Island", "Shark Island Secret Cave", "secret_cave", "images/entrances/entrance_fire_hole.png"),
    Entrance.New("Secret Cave Entrance on Cliff Plateau Isles", "Cliff Plateau Isles Secret Cave", "secret_cave", "images/entrances/entrance_hole.png"),
    Entrance.New("Secret Cave Entrance on Horseshoe Island", "Horseshoe Island Secret Cave", "secret_cave", "images/entrances/entrance_hole.png"),
    Entrance.New("Secret Cave Entrance on Star Island", "Star Island Secret Cave", "secret_cave", "images/entrances/entrance_rock.png"),
    Entrance.New("Inner Entrance in Ice Ring Isle Secret Cave", "Ice Ring Isle Inner Cave", "inner", "images/entrances/entrance_ice_ring_inner.png", "Ice Ring Isle Secret Cave"),
    Entrance.New("Inner Entrance in Cliff Plateau Isles Secret Cave", "Cliff Plateau Isles Inner Cave", "inner", "images/entrances/entrance_cliff_plateau_inner.png", "Cliff Plateau Isles Secret Cave", "Cliff Plateau Isles Inner Entrance"),
    Entrance.New("Fairy Fountain Entrance on Outset Island", "Outset Fairy Fountain", "fairy", "images/entrances/entrance_rock.png"),
    Entrance.New("Fairy Fountain Entrance on Thorned Fairy Island", "Thorned Fairy Fountain", "fairy", "images/entrances/entrance_hammer.png"),
    Entrance.New("Fairy Fountain Entrance on Eastern Fairy Island", "Eastern Fairy Fountain", "fairy", "images/entrances/entrance_rock.png"),
    Entrance.New("Fairy Fountain Entrance on Western Fairy Island", "Western Fairy Fountain", "fairy", "images/entrances/entrance_hammer.png"),
    Entrance.New("Fairy Fountain Entrance on Southern Fairy Island", "Southern Fairy Fountain", "fairy", "images/entrances/entrance_fairy_wood.png"),
    Entrance.New("Fairy Fountain Entrance on Northern Fairy Island", "Northern Fairy Fountain", "fairy", "images/entrances/entrance_fairy_fountain.png"),
}

ENTRANCE_BY_NAME = {}
ENTRANCE_TYPE_TO_ENTRANCES = {
    dungeon={},
    miniboss={},
    boss={},
    secret_cave={},
    inner={},
    fairy={},
}
for _, entrance in ipairs(ENTRANCES) do
    ENTRANCE_BY_NAME[entrance.Name] = entrance
    table.insert(ENTRANCE_TYPE_TO_ENTRANCES[entrance.EntranceType], entrance)
end


return Entrance