if EXIT_LOADED then
    print("WARNING: exit.lua has already been loaded.")
    return
else
    print("INFO: Loading exit.lua")
    EXIT_LOADED = true
end

require("scripts/utils")

Exit = {}
Exit.__index = Exit

function Exit.New(name, icon_path)
    local self = setmetatable({}, Exit)
    debugPrint("Creating Exit " .. name)
    self.Name = name
    -- To be set in Entrance.New
    self.Entrance = nil
    self.Index = nil

    -- The location which holds this exit's logic.
    self.ExitLogicPath = "@Exit Logic/" .. name

    if ENTRANCE_RANDO_ENABLED then
        self.IconPath = icon_path
    end

    return self
end

if ENTRANCE_RANDO_ENABLED then
    function Exit:IsSelected()
        return Exit.SelectedExit == self
    end

    function Exit.Select(exit, prevent_currently_selected_item_icon_update)
        local currently_selected = Exit.SelectedEntrance

        Entrance.SelectedEntrance = entrance

        -- Update the item icons for the exits.
        if currently_selected and not prevent_currently_selected_item_icon_update then
            -- Update the icon to show that it is no longer selected.
            currently_selected:UpdateExitItemIconMods()
        end

        if exit then
            -- Update the icon to show that it is selected.
            exit:UpdateExitItemIconMods()
        end
    end

    function Exit:GetItem()
        return Tracker:FindObjectForCode(self.Name)
    end

    function Exit:UpdateExitItemIconMods(item)
        item = item or self:GetItem()
        local icon_mods = self:GetItemIconMods()
        debugPrint("Updating %s icon mods to %s", self.Name, icon_mods)
        if item.IconMods ~= icon_mods then
            item.IconMods = icon_mods
        end
    end

    function Exit:UpdateExitItemNameAndOverlayText(item)
        item = item or self:GetItem()
        local entrance = self.Entrance
        local new_name
        local new_text_overlay
        if entrance then
            new_name = entrance.Name .. " -> " .. self.Name
            new_text_overlay = "from " .. entrance.Name
        else
            new_name = self.Name .. " (to assign, click an entrance and then the exit)"
            new_text_overlay = ""
        end
        if item.Name ~= new_name then
            item.Name = new_name
            item:SetOverlay(new_text_overlay)
        end
    end

    function Exit:GetItemIconMods()
        local entrance = self.Entrance

        -- Grey out to indicate that is has been assigned.
        if entrance then
            -- Add a selection highlight to indicate that it is selected.
            if self:IsSelected() then
                return "@disabled,overlay|images/entrances/selection_highlight.png"
            else
                return "@disabled"
            end
        else
            if self:IsSelected() then
                return "overlay|images/entrances/selection_highlight.png"
            else
                return "none"
            end
        end
    end

    function Exit:UpdateItem(item)
        item = item or self:GetItem()
        self:UpdateExitItemIconMods(item)
        self:UpdateExitItemNameAndOverlayText(item)
    end

    function Exit:UpdateLocationSection()
        debugPrint("%s: Updating section", self.Name)
        exit_location_section = Tracker:FindObjectForCode(self.ExitLogicPath .. "/Entered                                                                          ")
        if self.Entrance then
            -- Clear the section
            exit_location_section.AvailableChestCount = exit_location_section.AvailableChestCount - 1
        else
            -- Reset the section
            exit_location_section.AvailableChestCount = exit_location_section.ChestCount
        end
    end
end

EXITS = {
    -- TODO: New images for exits that show a small screenshot of what is visible from the exit. Currently, these are
    -- the same images as used by the entrances.
    Exit.New("Dragon Roost Cavern", "images/entrances/entrance_dungeon_drc.png"),
    Exit.New("Forbidden Woods", "images/entrances/entrance_dungeon_fw.png"),
    Exit.New("Tower of the Gods", "images/entrances/entrance_dungeon_totg.png"),
    Exit.New("Earth Temple", "images/entrances/entrance_headstone.png"),
    Exit.New("Wind Temple", "images/entrances/entrance_dungeon_wt.png"),
    Exit.New("Forbidden Woods Miniboss Arena", "images/items/smallkey.png"),
    Exit.New("Tower of the Gods Miniboss Arena", "images/items/smallkey.png"),
    Exit.New("Earth Temple Miniboss Arena", "images/items/smallkey.png"),
    Exit.New("Wind Temple Miniboss Arena", "images/items/smallkey.png"),
    Exit.New("Master Sword Chamber", "images/entrances/entrance_mastersword.png"),
    Exit.New("Gohma Boss Arena", "images/items/bigkey2.png"),
    Exit.New("Kalle Demos Boss Arena", "images/items/bigkey2.png"),
    Exit.New("Gohdan Boss Arena", "images/items/bigkey2.png"),
    Exit.New("Helmaroc King Boss Arena", "images/entrances/entrance_ff.png"),
    Exit.New("Jalhalla Boss Arena", "images/items/bigkey2.png"),
    Exit.New("Molgera Boss Arena", "images/items/bigkey2.png"),
    Exit.New("Savage Labyrinth", "images/entrances/entrance_headstone.png"),
    Exit.New("Dragon Roost Island Secret Cave", "images/entrances/entrance_rock.png"),
    Exit.New("Fire Mountain Secret Cave", "images/entrances/entrance_fire_mountain.png"),
    Exit.New("Ice Ring Isle Secret Cave", "images/entrances/entrance_ice_ring_isle.png"),
    Exit.New("Cabana Labyrinth", "images/entrances/entrance_cabana.png"),
    Exit.New("Needle Rock Isle Secret Cave", "images/entrances/entrance_needle_rock_isle.png"),
    Exit.New("Angular Isles Secret Cave", "images/entrances/entrance_hole.png"),
    Exit.New("Boating Course Secret Cave", "images/entrances/entrance_hole.png"),
    Exit.New("Stone Watcher Island Secret Cave", "images/entrances/entrance_headstone.png"),
    Exit.New("Overlook Island Secret Cave", "images/entrances/entrance_hole.png"),
    Exit.New("Bird's Peak Rock Secret Cave", "images/entrances/entrance_bird's_peak.png"),
    Exit.New("Pawprint Isle Chuchu Cave", "images/entrances/entrance_pawprint_isle_chuchu.png"),
    Exit.New("Pawprint Isle Wizzrobe Cave", "images/entrances/entrance_hole.png"),
    Exit.New("Diamond Steppe Island Warp Maze Cave", "images/entrances/entrance_hole.png"),
    Exit.New("Bomb Island Secret Cave", "images/entrances/entrance_rock.png"),
    Exit.New("Rock Spire Isle Secret Cave", "images/entrances/entrance_rock.png"),
    Exit.New("Shark Island Secret Cave", "images/entrances/entrance_fire_hole.png"),
    Exit.New("Cliff Plateau Isles Secret Cave", "images/entrances/entrance_hole.png"),
    Exit.New("Horseshoe Island Secret Cave", "images/entrances/entrance_hole.png"),
    Exit.New("Star Island Secret Cave", "images/entrances/entrance_rock.png"),
    Exit.New("Ice Ring Isle Inner Cave", "images/entrances/entrance_ice_ring_inner.png"),
    Exit.New("Cliff Plateau Isles Inner Cave", "images/entrances/entrance_cliff_plateau_inner.png"),
    Exit.New("Outset Fairy Fountain", "images/entrances/entrance_rock.png"),
    Exit.New("Thorned Fairy Fountain", "images/entrances/entrance_hammer.png"),
    Exit.New("Eastern Fairy Fountain", "images/entrances/entrance_rock.png"),
    Exit.New("Western Fairy Fountain", "images/entrances/entrance_hammer.png"),
    Exit.New("Southern Fairy Fountain", "images/entrances/entrance_fairy_wood.png"),
    Exit.New("Northern Fairy Fountain", "images/entrances/entrance_fairy_fountain.png"),
}

EXITS_BY_NAME = {}
for idx, exit in ipairs(EXITS) do
    EXITS_BY_NAME[exit.Name] = exit
    exit.Index = idx
end

return Exit