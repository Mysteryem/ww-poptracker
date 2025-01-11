-- Globals
ENTRANCE_RANDO_ENABLED = Tracker.ActiveVariantUID == "variant_entrance_rando"

-- Utils.
require("scripts/utils")

-- Pause logic updates until the next frame, so that auto-save state can load without causing updates and so that
-- entrance rando luaitems can be created and set up without causing update.
pauseLogicUntilNextFrame("tracker post-init")

-- Logic
require("scripts/logic/logic")
print("Logic scripts loaded")

-- Lua Items
-- The base variant does not have entrance rando, so these items and their global functions are not needed and loading
-- exit_mappings.lua will return `false`.
if require("scripts/items/exit_mappings") then
    print("Exit mapping lua items loaded")
end

-- Items
Tracker:AddItems("items/items.json")
Tracker:AddItems("items/settings.json")
Tracker:AddItems("items/internal.json")

-- Maps
Tracker:AddMaps("maps/maps.json")

-- Logic Locations
Tracker:AddLocations("locations/logic/general_logic.json")
Tracker:AddLocations("locations/logic/exits.json")
Tracker:AddLocations("locations/logic/macros.json")
Tracker:AddLocations("locations/logic/entrances.json")

-- Locations
Tracker:AddLocations("locations/ff.json")
Tracker:AddLocations("locations/wt.json")
Tracker:AddLocations("locations/drc.json")
Tracker:AddLocations("locations/totg.json")
Tracker:AddLocations("locations/fw.json")
Tracker:AddLocations("locations/et.json")
Tracker:AddLocations("locations/locations.json")
Tracker:AddLocations("locations/salvage.json")

-- Layout
Tracker:AddLayouts("layouts/items.json")
Tracker:AddLayouts("layouts/entrance_items.json")
Tracker:AddLayouts("layouts/items_variant.json") -- itemgrid layouts that change depending on the active variant.
Tracker:AddLayouts("layouts/entrances.json")
Tracker:AddLayouts("layouts/tracker.json")
Tracker:AddLayouts("layouts/broadcast.json")
Tracker:AddLayouts("layouts/settings.json")

-- AutoTracking for Poptracker
require("scripts/autotracking")
print("Autotracking script loaded")

if ENTRANCE_RANDO_ENABLED then
    require("scripts/objects/entrance")
    -- If there is no autosave state, then there are no calls to load exit assignments, so we schedule an update
    -- ourselves.
    local function update_entrances_after_load()
        print("Updating entrances after load")
        -- todo: with the logic being paused for a frame at the start, that forces a logic update, but then
        -- UpdateEntranceLogic() forces an update again afterwards.
        Entrance.UpdateEntranceLogic()
        print("Updated entrances after load")
    end
    runNextFrame("Delayed entrance logic update", update_entrances_after_load)
end
