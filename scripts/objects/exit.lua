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

function Exit.New(name)
    local self = setmetatable({}, Exit)
    debugPrint("Creating Exit " .. name)
    self.Name = name
    -- To be set in Entrance.New
    self.Entrance = nil
    self.Index = nil

    if ENTRANCE_RANDO_ENABLED then
        self.Icon = "images/items/exits/" .. name .. ".png"
        self.IconImageReference = ImageReference:FromPackRelativePath(self.Icon)
        self.EntranceOverlay = "images/items/entrances/exits/" .. name .. ".png"
    end

    return self
end

if ENTRANCE_RANDO_ENABLED then

    function Exit:GetItem()
        return Tracker:FindObjectForCode(self.Name)
    end

    function Exit:UpdateItem(item)
        item = item or self:GetItem()
        local entrance = self.Entrance
        local new_name
        local new_icon_mods
        if entrance then
            new_name = entrance.Name .. " -> " .. self.Name
            -- Grey out the image to indicate that is has been assigned.
            new_icon_mods = "@disabled"
        else
            new_name = self.Name
            new_icon_mods = "none"
        end

        if item.Name ~= new_name then
            item.Name = new_name
        end
        if item.IconMods ~= new_icon_mods then
            item.IconMods = new_icon_mods
        end
    end
end

EXITS = {
    Exit.New("Dragon Roost Cavern"),
    Exit.New("Forbidden Woods"),
    Exit.New("Tower of the Gods"),
    Exit.New("Earth Temple"),
    Exit.New("Wind Temple"),
    Exit.New("Forbidden Woods Miniboss Arena"),
    Exit.New("Tower of the Gods Miniboss Arena"),
    Exit.New("Earth Temple Miniboss Arena"),
    Exit.New("Wind Temple Miniboss Arena"),
    Exit.New("Master Sword Chamber"),
    Exit.New("Gohma Boss Arena"),
    Exit.New("Kalle Demos Boss Arena"),
    Exit.New("Gohdan Boss Arena"),
    Exit.New("Helmaroc King Boss Arena"),
    Exit.New("Jalhalla Boss Arena"),
    Exit.New("Molgera Boss Arena"),
    Exit.New("Savage Labyrinth"),
    Exit.New("Dragon Roost Island Secret Cave"),
    Exit.New("Fire Mountain Secret Cave"),
    Exit.New("Ice Ring Isle Secret Cave"),
    Exit.New("Cabana Labyrinth"),
    Exit.New("Needle Rock Isle Secret Cave"),
    Exit.New("Angular Isles Secret Cave"),
    Exit.New("Boating Course Secret Cave"),
    Exit.New("Stone Watcher Island Secret Cave"),
    Exit.New("Overlook Island Secret Cave"),
    Exit.New("Bird's Peak Rock Secret Cave"),
    Exit.New("Pawprint Isle Chuchu Cave"),
    Exit.New("Pawprint Isle Wizzrobe Cave"),
    Exit.New("Diamond Steppe Island Warp Maze Cave"),
    Exit.New("Bomb Island Secret Cave"),
    Exit.New("Rock Spire Isle Secret Cave"),
    Exit.New("Shark Island Secret Cave"),
    Exit.New("Cliff Plateau Isles Secret Cave"),
    Exit.New("Horseshoe Island Secret Cave"),
    Exit.New("Star Island Secret Cave"),
    Exit.New("Ice Ring Isle Inner Cave"),
    Exit.New("Cliff Plateau Isles Inner Cave"),
    Exit.New("Outset Fairy Fountain"),
    Exit.New("Thorned Fairy Fountain"),
    Exit.New("Eastern Fairy Fountain"),
    Exit.New("Western Fairy Fountain"),
    Exit.New("Southern Fairy Fountain"),
    Exit.New("Northern Fairy Fountain"),
}

EXITS_BY_NAME = {}
for idx, exit in ipairs(EXITS) do
    EXITS_BY_NAME[exit.Name] = exit
    exit.Index = idx
end

return Exit