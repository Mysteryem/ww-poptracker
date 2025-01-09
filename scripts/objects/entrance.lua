if ENTRANCE_LOADED then
    print("WARNING: entrance.lua has already been loaded.")
    return
else
    print("INFO: Loading entrance.lua")
    ENTRANCE_LOADED = true
end

require("scripts/objects/exit")

Entrance = {}
Entrance.__index = Entrance

function Entrance.New(name, vanilla_exit_name, entrance_type, parent_exit_name)
    local self = setmetatable({}, Entrance)
    print("Creating Entrance " .. name)
    -- The name of this entrance.
    self.name = name

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
        error("'" .. vanilla_exit.Name .. "' is already assigned to " .. vanilla_exit.Entrance.name)
    end
    print("Assigned " .. self.name .. " as the entrance used by exit " .. vanilla_exit.Name)
    vanilla_exit.Entrance = self

    -- The vanilla exit, stored here for simpler lookup.
    self.vanilla_exit = vanilla_exit
    -- The exit that has been assigned to this entrance. Always starts off as vanilla and won't change if Entrance
    -- Randomization is not enabled.
    self.exit = vanilla_exit
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

        self.parent_exit_name = parent_exit_name
    end
    -- The location which holds this entrance's logic, or `nil` if the entrance is always accessible.
    self.entrance_logic = "@Entrance Logic/" .. name
    -- The type of the entrance: "dungeon", "miniboss", "boss", "secret_cave", "inner", "fairy"
    self.entrance_type = entrance_type

    if ENTRANCE_RANDO_ENABLED then
        self.Icon = "images/items/entrances/" .. self.name .. ".png"
    end

    return self
end

function Entrance:GetAccessibility()
    if not self.entrance_logic then
        return AccessibilityLevel.Normal
    end
    local location = Tracker:FindObjectForCode(self.entrance_logic)
    return location.AccessibilityLevel
end

if ENTRANCE_RANDO_ENABLED then
    function Entrance:IsSelected()
        return Entrance.SelectedEntrance == self
    end

    function Entrance.Select(entrance, prevent_currently_selected_item_icon_update)
        local currently_selected = Entrance.SelectedEntrance

        Entrance.SelectedEntrance = entrance

        -- Update the item icons for the entrances.
        if currently_selected and not prevent_currently_selected_item_icon_update then
            -- Update the icon to show that it is no longer selected.
            currently_selected:UpdateItemIcon()
        end

        if entrance then
            -- Update the icon to show that it is selected.
            entrance:UpdateItemIcon()
        end
    end

    function Entrance:Unassign(prevent_logic_update, prevent_item_updates, prevent_section_update)
        local current_exit = self.exit
        if current_exit then
            -- Safety check
            local current_exit_entrance = current_exit.Entrance
            if current_exit_entrance then
                if current_exit_entrance ~= self then
                    print(string.format("ERROR: While unassigning %s from %s, %s thought it was assigned to %s", current_exit.Name, self.name, current_exit.Name, current_exit_entrance.name))
                end
            else
                print(string.format("ERROR: While unassigning %s from %s, %s thought it was not assigned", current_exit.Name, self.name, current_exit.Name))
            end

            -- Unassign from both.
            current_exit.Entrance = nil
            self.exit = nil

            if not prevent_item_updates then
                self:UpdateItem()
                current_exit:UpdateItem()
            end

            if not prevent_logic_update then
                update_entrances()
            end

            if not prevent_section_update then
                -- Reset the section
                self:UpdateLocationSection()
            end
            print(string.format("%s: Unassigned %s", self.name, current_exit.Name))
        else
            print(string.format("%s: Already has no assignment to unassign", self.name))
        end
    end

    function Entrance:Assign(new_exit, replace, prevent_logic_update)

        if new_exit then
            print(string.format("%s: Assigning exit %s", self.name, new_exit.Name))
        else
            print(string.format("%s: Assigning exit nil", self.name))
        end

        local current_exit = self.exit
        if new_exit == current_exit then
            -- Nothing to do.
            print(string.format("%s: Already assigned", self.name))
            return true
        end

        if new_exit == nil then
            self:Unassign(prevent_logic_update)
            -- Always succeeds.
            print(string.format("%s: Unassigned", self.name))
            return true
        end

        local new_exit_current_entrance = new_exit.Entrance

        if new_exit_current_entrance then
            if not replace then
                print(string.format("ERROR: %s is already assigned to %s and cannot be assigned to %s", new_exit.Name, new_exit_current_entrance.name, self.name))
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
        self.exit = new_exit
        new_exit.Entrance = self

        -- new_exit is not nil, so the section needs updating if current_exit is nil.
        if not current_exit then
            self:UpdateLocationSection()
        end

        -- Update the items for the entrance and exit.
        self:UpdateItem()
        new_exit:UpdateItem()

        if not prevent_logic_update then
            update_entrances()
        end

        print(string.format("%s: Assigned %s", self.name, new_exit.Name))
    end

    function Entrance:GetItemIconPath()
        local entrance_icon = self.Icon
        local exit = self.exit
        local exit_overlay
        if exit then
            exit_overlay = exit.EntranceOverlay
        else
            exit_overlay = "images/items/entrances/exits/Unknown.png"
        end

        if self:IsSelected() then
            return string.format("%s:overlay|%s,overlay|images/items/entrances/active_overlay.png", entrance_icon, exit_overlay)
        else
            return string.format("%s:overlay|%s", entrance_icon, exit_overlay)
        end
    end

    function Entrance:GetItem()
        return Tracker:FindObjectForCode(self.name)
    end

    function Entrance:UpdateItemIcon(item)
        item = item or self:GetItem()
        local path = self:GetItemIconPath()
        print("Updating " .. self.name .. " icon to ".. path)
        item.Icon = ImageReference:FromPackRelativePath(path)
    end

    function Entrance:UpdateIconIndex(item)
        item = item or self:GetItem()
        item.ItemState.exit_idx = self:GetExitIndex()
    end

    function Entrance:UpdateItemName(item)
        item = item or self:GetItem()
        local exit = self.exit
        if exit then
            item.Name = self.name .. " -> " .. exit.Name
        else
            item.Name = "Click to assign " .. self.name
        end
    end

    function Entrance:UpdateItem(item)
        item = item or self:GetItem()
        self:UpdateItemIcon(item)
        self:UpdateIconIndex(item)
        self:UpdateItemName(item)
    end

    function Entrance:UpdateLocationSection()
        print(string.format("%s: Updating section", self.name))
        entrance_location_section = Tracker:FindObjectForCode(self.entrance_logic .. "/Can Enter")
        if self.exit then
            -- Clear the section
            entrance_location_section.AvailableChestCount = entrance_location_section.AvailableChestCount - 1
        else
            -- Reset the section
            entrance_location_section.AvailableChestCount = entrance_location_section.ChestCount
        end
    end

    function Entrance:GetExitIndex()
        local exit = self.exit
        if exit then
            return exit.Index
        else
            return 0
        end
    end
end


-- Each entrance starts with its vanilla exit.
ENTRANCES = {
    Entrance.New("Dungeon Entrance on Dragon Roost Island", "Dragon Roost Cavern", "dungeon"),
    Entrance.New("Dungeon Entrance in Forest Haven Sector", "Forbidden Woods", "dungeon"),
    Entrance.New("Dungeon Entrance in Tower of the Gods Sector", "Tower of the Gods", "dungeon"),
    Entrance.New("Dungeon Entrance on Headstone Island", "Earth Temple", "dungeon"),
    Entrance.New("Dungeon Entrance on Gale Isle", "Wind Temple", "dungeon"),
    Entrance.New("Miniboss Entrance in Forbidden Woods", "Forbidden Woods Miniboss Arena", "miniboss", "Forbidden Woods"),
    Entrance.New("Miniboss Entrance in Tower of the Gods", "Tower of the Gods Miniboss Arena", "miniboss", "Tower of the Gods"),
    Entrance.New("Miniboss Entrance in Earth Temple", "Earth Temple Miniboss Arena", "miniboss", "Earth Temple"),
    Entrance.New("Miniboss Entrance in Wind Temple", "Wind Temple Miniboss Arena", "miniboss", "Wind Temple"),
    Entrance.New("Miniboss Entrance in Hyrule Castle", "Master Sword Chamber", "miniboss"),
    Entrance.New("Boss Entrance in Dragon Roost Cavern", "Gohma Boss Arena", "boss", "Dragon Roost Cavern"),
    Entrance.New("Boss Entrance in Forbidden Woods", "Kalle Demos Boss Arena", "boss", "Forbidden Woods"),
    Entrance.New("Boss Entrance in Tower of the Gods", "Gohdan Boss Arena", "boss", "Tower of the Gods"),
    Entrance.New("Boss Entrance in Forsaken Fortress", "Helmaroc King Boss Arena", "boss"),
    Entrance.New("Boss Entrance in Earth Temple", "Jalhalla Boss Arena", "boss", "Earth Temple"),
    Entrance.New("Boss Entrance in Wind Temple", "Molgera Boss Arena", "boss", "Wind Temple"),
    Entrance.New("Secret Cave Entrance on Outset Island", "Savage Labyrinth", "secret_cave"),
    Entrance.New("Secret Cave Entrance on Dragon Roost Island", "Dragon Roost Island Secret Cave", "secret_cave"),
    Entrance.New("Secret Cave Entrance on Fire Mountain", "Fire Mountain Secret Cave", "secret_cave"),
    Entrance.New("Secret Cave Entrance on Ice Ring Isle", "Ice Ring Isle Secret Cave", "secret_cave"),
    Entrance.New("Secret Cave Entrance on Private Oasis", "Cabana Labyrinth", "secret_cave"),
    Entrance.New("Secret Cave Entrance on Needle Rock Isle", "Needle Rock Isle Secret Cave", "secret_cave"),
    Entrance.New("Secret Cave Entrance on Angular Isles", "Angular Isles Secret Cave", "secret_cave"),
    Entrance.New("Secret Cave Entrance on Boating Course", "Boating Course Secret Cave", "secret_cave"),
    Entrance.New("Secret Cave Entrance on Stone Watcher Island", "Stone Watcher Island Secret Cave", "secret_cave"),
    Entrance.New("Secret Cave Entrance on Overlook Island", "Overlook Island Secret Cave", "secret_cave"),
    Entrance.New("Secret Cave Entrance on Bird's Peak Rock", "Bird's Peak Rock Secret Cave", "secret_cave"),
    Entrance.New("Secret Cave Entrance on Pawprint Isle", "Pawprint Isle Chuchu Cave", "secret_cave"),
    Entrance.New("Secret Cave Entrance on Pawprint Isle Side Isle", "Pawprint Isle Wizzrobe Cave", "secret_cave"),
    Entrance.New("Secret Cave Entrance on Diamond Steppe Island", "Diamond Steppe Island Warp Maze Cave", "secret_cave"),
    Entrance.New("Secret Cave Entrance on Bomb Island", "Bomb Island Secret Cave", "secret_cave"),
    Entrance.New("Secret Cave Entrance on Rock Spire Isle", "Rock Spire Isle Secret Cave", "secret_cave"),
    Entrance.New("Secret Cave Entrance on Shark Island", "Shark Island Secret Cave", "secret_cave"),
    Entrance.New("Secret Cave Entrance on Cliff Plateau Isles", "Cliff Plateau Isles Secret Cave", "secret_cave"),
    Entrance.New("Secret Cave Entrance on Horseshoe Island", "Horseshoe Island Secret Cave", "secret_cave"),
    Entrance.New("Secret Cave Entrance on Star Island", "Star Island Secret Cave", "secret_cave"),
    Entrance.New("Inner Entrance in Ice Ring Isle Secret Cave", "Ice Ring Isle Inner Cave", "inner", "Ice Ring Isle Secret Cave"),
    Entrance.New("Inner Entrance in Cliff Plateau Isles Secret Cave", "Cliff Plateau Isles Inner Cave", "inner", "Cliff Plateau Isles Secret Cave"),
    Entrance.New("Fairy Fountain Entrance on Outset Island", "Outset Fairy Fountain", "fairy"),
    Entrance.New("Fairy Fountain Entrance on Thorned Fairy Island", "Thorned Fairy Fountain", "fairy"),
    Entrance.New("Fairy Fountain Entrance on Eastern Fairy Island", "Eastern Fairy Fountain", "fairy"),
    Entrance.New("Fairy Fountain Entrance on Western Fairy Island", "Western Fairy Fountain", "fairy"),
    Entrance.New("Fairy Fountain Entrance on Southern Fairy Island", "Southern Fairy Fountain", "fairy"),
    Entrance.New("Fairy Fountain Entrance on Northern Fairy Island", "Northern Fairy Fountain", "fairy"),
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
    ENTRANCE_BY_NAME[entrance.name] = entrance
    table.insert(ENTRANCE_TYPE_TO_ENTRANCES[entrance.entrance_type], entrance)
end


return Entrance