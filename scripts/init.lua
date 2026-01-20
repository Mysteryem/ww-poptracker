-- Globals
ENTRANCE_RANDO_ENABLED = Tracker.ActiveVariantUID == "variant_entrance_rando"

-- Utils.
require("scripts/utils")

-- Logic
require("scripts/logic/logic")
print("Logic scripts loaded")

-- ER items
if ENTRANCE_RANDO_ENABLED then
    -- Table items
    Tracker:AddItems("items/er_tables/entrance_labels.json")
    Tracker:AddItems("items/er_tables/exit_labels.json")
    Tracker:AddItems("items/er_tables/shared.json")
    -- Lua Items
    require("scripts/items/exit_mappings")
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
Tracker:AddLocations("locations/salvage_overview.json")

-- Layout
Tracker:AddLayouts("layouts/items.json")
Tracker:AddLayouts("layouts/items_variant.json") -- itemgrid layouts that change depending on the active variant.
Tracker:AddLayouts("layouts/entrances.json")
Tracker:AddLayouts("layouts/er_tables/dungeon_entrances.json")
Tracker:AddLayouts("layouts/er_tables/secret_cave_entrances.json")
Tracker:AddLayouts("layouts/er_tables/inner_and_fairy_entrances.json")
Tracker:AddLayouts("layouts/er_tables/dungeon_exits.json")
Tracker:AddLayouts("layouts/er_tables/secret_cave_exits.json")
Tracker:AddLayouts("layouts/er_tables/inner_and_fairy_exits.json")
Tracker:AddLayouts("layouts/tracker.json")
Tracker:AddLayouts("layouts/broadcast.json")
Tracker:AddLayouts("layouts/settings.json")

-- AutoTracking for Poptracker
require("scripts/autotracking")
print("Autotracking script loaded")

if ENTRANCE_RANDO_ENABLED then
    require("scripts/objects/entrance")
end
