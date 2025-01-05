require("scripts/autotracking/item_mapping")
require("scripts/autotracking/location_mapping")
require("scripts/logic/entrances")
require("scripts/items/exit_mappings")
require("scripts/utils")

CUR_INDEX = -1
SLOT_DATA = nil
local VISITED_STAGES_FORMAT = "tww_visited_stages_%i"
-- Data storage key
visited_stages_key = nil

local SLOT_DATA_EXIT_TO_ENTRANCE = {}

-- Tracker Tab names and the Stages that should swap to those tabs.
-- Stage names from https://github.com/LagoLunatic/wwrando/blob/master/data/stage_names.txt
local _STAGE_MAPPING = {
    {
        "The Great Sea",
        {
            -- Stages which do not form connections with potentially randomized entrances are not included in this list.
            {"sea"}, -- The Great Sea
            {"Abesso"}, -- Cabana Interior
            {"Adanmae"}, -- Dragon Roost Cavern Entrance
            {"A_mori"}, -- Outset Island Fairy Woods
            -- Caves 06 and 08 are unused.
            {"Cave01", "Bomb Island Secret Cave"},
            {"Cave02", "Star Island Secret Cave"},
            {"Cave03", "Cliff Plateau Isles Secret Cave"},
            {"Cave04", "Rock Spire Isle Secret Cave"},
            {"Cave05", "Horseshoe Island Secret Cave"},
            {"Cave07", "Pawprint Isle Wizzrobe Cave"},
            -- Unsure which is the entrance, so specifying all 3 for now.
            {"Cave09", "Savage Labyrinth"},
            {"Cave10", "Savage Labyrinth"},
            {"Cave11", "Savage Labyrinth"},
            {"Edaichi"}, -- Earth Temple Entrance (the room on Headstone Island before the dungeon)
            {"Ekaze"}, -- Wind Temple Entrance (the room on Gale Isle before the dungeon)
            {"Fairy01", "Northern Fairy Fountain"},
            {"Fairy02", "Eastern Fairy Fountain"},
            {"Fairy03", "Western Fairy Fountain"},
            {"Fairy04", "Outset Fairy Fountain"},
            {"Fairy05", "Thorned Fairy Fountain"},
            {"Fairy06", "Southern Fairy Fountain"},
            {"ITest62", "Ice Ring Isle Inner Cave"},
            {"ITest63", "Shark Island Secret Cave"},
            {"kenroom", "Master Sword Chamber"},
            {"MiniHyo", "Ice Ring Isle Secret Cave"},
            {"MiniKaz", "Fire Mountain Secret Cave"},
            {"SubD42", "Needle Rock Isle Secret Cave"},
            {"SubD43", "Angular Isles Secret Cave"},
            {"SubD71", "Boating Course Secret Cave"},
            -- TF 05 and 07 are unused.
            {"TF_01", "Stone Watcher Island Secret Cave"},
            {"TF_02", "Overlook Island Secret Cave"},
            {"TF_03", "Bird's Peak Rock Secret Cave"},
            {"TF_04", "Cabana Labyrinth"},
            {"TF_06", "Dragon Roost Island Secret Cave"},
            {"TyuTyu", "Pawprint Isle Chuchu Cave"},
            {"WarpD", "Diamond Steppe Island Warp Maze Cave"},
            -- Technically part of the `sea` stage, this is a dummy stage name sent by the AP Client.
            {"CliPlaH", "Cliff Plateau Isles Inner Cave"}, -- The exit onto the highest isle
        }
    },
    {
        "Dragon Roost Cavern",
        {
            {"M_Dra09"}, -- Dragon Roost Cavern Moblin Miniboss Room
            {"M_DragB", "Gohma Boss Arena"},
            {"M_NewD2", "Dragon Roost Cavern"},
        }
    },
    {
        "Forbidden Woods",
        {
            {"kinBOSS", "Kalle Demos Boss Arena"},
            {"kindan", "Forbidden Woods"},
            {"kinMB", "Forbidden Woods Miniboss Arena"},
        }
    },
    {
        "Tower of the Gods",
        {
            {"Siren", "Tower of the Gods"},
            {"SirenB", "Gohdan Boss Arena"},
            {"SirenMB", "Tower of the Gods Miniboss Arena"},
        }
    },
    {
        "Forsaken Fortress",
        {
            -- "M2ganon", -- Forsaken Fortress Ganon's Room (2nd visit)
            {"M2tower", "Helmaroc King Boss Arena"}, -- Forsaken Fortress Tower (2nd visit)
            {"ma2room"}, -- Forsaken Fortress Interior (2nd visit)
            -- "ma3room", -- Forsaken Fortress Interior (3rd visit)
            -- "majroom", -- Forsaken Fortress Interior (1st visit)
            -- "MajyuE", -- Forsaken Fortress Exterior (1st visit)
            -- "Mjtower", -- Forsaken Fortress Tower (1st visit)
        }
    },
    {
        "Earth Temple",
        {
            {"M_Dai", "Earth Temple"},
            {"M_DaiB", "Jalhalla Boss Arena"},
            {"M_DaiMB", "Earth Temple Miniboss Arena"},
        }
    },
    {
        "Wind Temple",
        {
            {"kaze", "Wind Temple"},
            {"kazeB", "Molgera Boss Arena"},
            {"kazeMB", "Wind Temple Miniboss Arena"},
        }
    },
}
local STAGE_NAME_TO_TAB_NAME = {}
local STAGE_NAME_TO_EXIT_NAME = {}
for _, pair in ipairs(_STAGE_MAPPING) do
    local tab_name = pair[1]
    local stage_list = pair[2]
    for _, stage_data in ipairs(stage_list) do
        local stage_name = stage_data[1]
        STAGE_NAME_TO_TAB_NAME[stage_name] = tab_name

        local exit_name = stage_data[2]
        if exit_name then
            STAGE_NAME_TO_EXIT_NAME[stage_name] = exit_name
        end
    end
end
_STAGE_MAPPING = nil

function setNonRandomizedEntrancesFromSlotData(slot_data)
    local vanilla_dungeons = slot_data['randomize_dungeon_entrances'] == 0
    local vanilla_minibosses = slot_data['randomize_miniboss_entrances'] == 0
    local vanilla_bosses = slot_data['randomize_boss_entrances'] == 0
    local vanilla_secret_caves = slot_data['randomize_secret_cave_entrances'] == 0
    local vanilla_secret_cave_inner_entrances = slot_data['randomize_secret_cave_inner_entrances'] == 0
    local vanilla_fairy_fountains = slot_data['randomize_fairy_fountain_entrances'] == 0

    local all_vanilla_entrances = {}
    local add_vanilla_entrances = function(entrance_type)
        for _, entrance in ipairs(ENTRANCE_TYPE_TO_ENTRANCES[entrance_type]) do
            table.insert(all_vanilla_entrances, entrance)
        end
    end

    if vanilla_dungeons then
        add_vanilla_entrances("dungeon")
    end
    if vanilla_minibosses then
        add_vanilla_entrances("miniboss")
    end
    if vanilla_bosses then
        add_vanilla_entrances("boss")
    end
    if vanilla_secret_caves then
        add_vanilla_entrances("secret_cave")
    end
    if vanilla_secret_cave_inner_entrances then
        add_vanilla_entrances("inner")
    end
    if vanilla_fairy_fountains then
        add_vanilla_entrances("fairy")
    end

    -- For the second pass, set all the entrances to their vanilla exit
    local all_set_correctly = true
    for _, entrance in ipairs(all_vanilla_entrances) do
        local exit_mapping = Tracker:FindObjectForCode(entrance.name)
        local set_correctly = exit_mapping_assign(exit_mapping, entrance.vanilla_exit)
        if not set_correctly then
            -- Exit was most likely already assigned to an entrance
            all_set_correctly = false
        end
    end
    if not all_set_correctly then
        print("Some exit mappings could not be set to their vanilla entrances." ..
              " Their vanilla exits are probably already assigned to another entrance.")
    end
end

function onClear(slot_data)
    -- Reset the last activated tab from map tracking.
    _last_activated_tab = ""

    -- autotracking settings from YAML
    local function setFromSlotData(slot_data_key, item_code)
        local v = slot_data[slot_data_key]
        if not v then
            print(string.format("Could not find key '%s' in slot data", slot_data_key))
            return nil
        end

        local obj = Tracker:FindObjectForCode(item_code)
        if not obj then
            print(string.format("Could not find item for code '%s'", item_code))
            return nil
        end

        if obj.Type == 'toggle' then
            local active = v ~= 0
            obj.Active = active
            return active
        elseif obj.Type == 'progressive' then
            obj.CurrentStage = v
            return v
        else
            print(string.format("Unsupported item type '%s' for item '%s'", tostring(obj.Type), item_code))
            return nil
        end
    end

    setFromSlotData('progression_dungeons', 'dungeons')
    setFromSlotData('progression_puzzle_secret_caves', 'puzzlecaves')
    setFromSlotData('progression_island_puzzles', 'islandpuzzles')
    setFromSlotData('progression_combat_secret_caves', 'combat')
    setFromSlotData('progression_savage_labyrinth', 'labyrinth')
    setFromSlotData('progression_great_fairies', 'fairies')
    setFromSlotData('progression_free_gifts', 'gifts')
    setFromSlotData('progression_tingle_chests', 'tinglechests')
    setFromSlotData('progression_short_sidequests', 'shortsq')
    setFromSlotData('progression_long_sidequests', 'longsq')
    setFromSlotData('progression_spoils_trading', 'spoilssq')
    setFromSlotData('progression_expensive_purchases', 'expensive')
    setFromSlotData('progression_misc', 'misc')
    setFromSlotData('progression_battlesquid', 'sploosh')
    setFromSlotData('progression_platforms_rafts', 'lookouts')
    setFromSlotData('progression_submarines', 'submarines')
    setFromSlotData('progression_triforce_charts', 'triforcesalvage')
    setFromSlotData('progression_treasure_charts', 'treasuresalvage')
    setFromSlotData('progression_eye_reef_chests', 'reefs')
    setFromSlotData('progression_mail', 'mail')
    setFromSlotData('progression_big_octos_gunboats', 'octos')
    setFromSlotData('progression_minigames', 'minigames')
    setFromSlotData('progression_dungeon_secrets', 'secretpot')

    setFromSlotData('enable_tuner_logic', 'tunerlogic')
    setFromSlotData('logic_obscurity', 'tww_obscure')
    setFromSlotData('logic_precision', 'tww_precise')
    setFromSlotData('sword_mode', 'tww_sword_mode')
    setFromSlotData('skip_rematch_bosses', 'tww_rematch_bosses_skipped')
    setFromSlotData('swift_sail', 'swift_sail')
    local required_bosses = setFromSlotData('required_bosses', 'required_bosses')

    -- Reset required bosses
    local drc_required = Tracker:FindObjectForCode("required_bosses_drc")
    local fw_required = Tracker:FindObjectForCode("required_bosses_fw")
    local totg_required = Tracker:FindObjectForCode("required_bosses_totg")
    local ff_required = Tracker:FindObjectForCode("required_bosses_ff")
    local et_required = Tracker:FindObjectForCode("required_bosses_et")
    local wt_required = Tracker:FindObjectForCode("required_bosses_wt")
    -- Not required by default
    drc_required.CurrentStage = 0
    fw_required.CurrentStage = 0
    totg_required.CurrentStage = 0
    ff_required.CurrentStage = 0
    et_required.CurrentStage = 0
    wt_required.CurrentStage = 0

    -- Set required bosses
    if required_bosses then
        -- Which bosses are required bosses is not currently provided in slot data, however, the locations for a
        -- non-required boss' dungeon will not be present in the multiworld, so it is possible to check if the locations
        -- within a dungeon exist. The locations picked must only be possible to disable through being a non-required
        -- boss' dungeon (or through dungeons being disabled entirely).
        local check_loc_to_item = {
            [0x238038] = drc_required, -- @Dragon Roost Cavern/First Room
            [0x23804e] = fw_required, -- @Forbidden Woods/First Room
            [0x238061] = totg_required, -- @Tower of the Gods/Chest Behind Bombable Walls
            [0x238072] = ff_required, -- @Forsaken Fortress/Phantom Ganon
            [0x238082] = et_required, -- @Earth Temple/Transparent Chest In Warp Pot Room
            [0x238094] = wt_required, -- @Wind Temple/Chest Between Two Dirt Patches
        }
        local all_locations = {Archipelago.CheckedLocations, Archipelago.MissingLocations}
        for _, locations in ipairs(all_locations) do
            for _, loc_id in ipairs(locations) do
                -- Enable the required boss if a location in their dungeon exists.
                local required_boss_item = check_loc_to_item[loc_id]
                if required_boss_item ~= nil then
                    required_boss_item.CurrentStage = 1
                end
            end
        end
    end

    SLOT_DATA_EXIT_TO_ENTRANCE = {}
    local load_assignments_from_ap = Tracker:FindObjectForCode("setting_load_exit_assignments_from_ap")
    if ENTRANCE_RANDO_ENABLED and load_assignments_from_ap.Active then
        visited_stages_key = string.format(VISITED_STAGES_FORMAT, Archipelago.PlayerNumber)
        -- Only get the value when connecting so that entrances can be automatically assigned for all previously visited
        -- stages. There is no need to receive updates to its value as it changes because the tracker already receives the
        -- current stage name for map switching.
        Archipelago:Get({visited_stages_key})

        PAUSE_ENTRANCE_UPDATES = true
        clearExitMappings()
        setNonRandomizedEntrancesFromSlotData(slot_data)
        local entrances = slot_data["entrances"]
        if entrances then
            --print(dump_table(entrances))
            for entrance, exit in pairs(entrances) do
                SLOT_DATA_EXIT_TO_ENTRANCE[exit] = entrance
            end
        else
            print("'entrances' was not present in slot_data, automatic entrance assignment will not be available")
        end
        PAUSE_ENTRANCE_UPDATES = false
        update_entrances()
    end

    -- junk that was in here from the template
    if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
        print(string.format("called onClear, slot_data:\n%s", dump_table(slot_data)))
    end
    SLOT_DATA = slot_data
    CUR_INDEX = -1
    -- reset locations
    for _, v in pairs(LOCATION_MAPPING) do
        if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
            print(string.format("onClear: clearing location %s", v))
        end
        local obj = Tracker:FindObjectForCode(v)
        if obj then
            obj.AvailableChestCount = obj.ChestCount
        elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
            print(string.format("onClear: could not find object for code %s", v))
        end
    end
    -- reset items
    for _, v in pairs(ITEM_MAPPING) do
        if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
            print(string.format("onClear: clearing item %s", v))
        end
        local obj = Tracker:FindObjectForCode(v)
        if obj then
            local obj_type = obj.Type
            if obj_type == "toggle" then
                obj.Active = false
            elseif obj_type == "progressive" then
                obj.CurrentStage = 0
                obj.Active = false
            elseif obj_type == "consumable" then
                obj.AcquiredCount = 0
            elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
                print(string.format("onClear: unknown item type %s for code %s", obj_type, v))
            end
        elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
            print(string.format("onClear: could not find object for code %s", v))
        end
    end
end

function onClearHandler(slot_data)
    pauseLogicUntilNextFrame("AP onClearHandler")
    onClear(slot_data)
end

function entranceRandoAssignEntranceFromVisitedStage(stage_name)
    local exit_name = STAGE_NAME_TO_EXIT_NAME[stage_name]
    if exit_name then
        local entrance_name = SLOT_DATA_EXIT_TO_ENTRANCE[exit_name]
        if entrance_name then
            local exit_mapping = Tracker:FindObjectForCode(entrance_name)
            if exit_mapping then
                -- Clear the current assignment if it is already assigned.
                exit_mapping_clear(exit_mapping)
                local set_correctly = exit_mapping_assign(exit_mapping, exit_name)
                if not set_correctly then
                    print("Warning: Failed to assign entrance mapping "..entrance_name.." -> "..exit_name..".")
                end
            end
        else
            print("Could not find an entrance_name for "..exit_name)
        end
    else
        print("Could not find an exit_name for "..stage_name)
    end
end

_last_activated_tab = ""
function onMap(stage_name)
    if not stage_name then
        return
    end

    local map_switch_setting = Tracker:FindObjectForCode("setting_map_tracking")
    if map_switch_setting and map_switch_setting.Active then
        local tab_name = STAGE_NAME_TO_TAB_NAME[stage_name]
        if tab_name and tab_name ~= _last_activated_tab then
            local map_switch_dungeons_only_setting = Tracker:FindObjectForCode("setting_map_tracking_dungeons_only")
            if map_switch_dungeons_only_setting then
                if not map_switch_dungeons_only_setting.Active or tab_name ~= "The Great Sea" then
                    Tracker:UiHint("ActivateTab", tab_name)
                end
                -- Always set the last activated tab, so that if the player has the setting on that only switches when
                -- entering a dungeon, enters a dungeon, leaves, and then re-enters, the map will switch to the dungeon
                -- again.
                _last_activated_tab = tab_name
            end
        end
    end

    -- Assign the current stage_name to its entrance as read from slot_data
    if ENTRANCE_RANDO_ENABLED then
        entranceRandoAssignEntranceFromVisitedStage(stage_name)
    end
end

-- called when an item gets collected
function onItem(index, item_id, item_name, player_number)
    if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
        print(string.format("called onItem: %s, %s, %s, %s, %s", index, item_id, item_name, player_number, CUR_INDEX))
    end
    if not AUTOTRACKER_ENABLE_ITEM_TRACKING then
        return
    end
    if index <= CUR_INDEX then
        return
    end
    local is_local = player_number == Archipelago.PlayerNumber
    CUR_INDEX = index;
    local v = ITEM_MAPPING[item_id]
    if not v then
        if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
            print(string.format("onItem: could not find item mapping for id %s", item_id))
        end
        return
    end
    if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
        print(string.format("onItem: code: %s", v))
    end
    local obj = Tracker:FindObjectForCode(v)
    if obj then
        local obj_type = obj.Type
        if obj_type == "toggle" then
            obj.Active = true
        elseif obj_type == "progressive" then
            if obj.Active then
                obj.CurrentStage = obj.CurrentStage + 1
            else
                obj.Active = true
            end
        elseif obj_type == "consumable" then
            obj.AcquiredCount = obj.AcquiredCount + obj.Increment
        elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
            print(string.format("onItem: unknown item type %s for code %s", obj_type, v))
        end
    elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
        print(string.format("onItem: could not find object for code %s", v))
    end
end

-- called when a location gets cleared
function onLocation(location_id, location_name)
    if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
        print(string.format("called onLocation: %s, %s", location_id, location_name))
    end
    if not AUTOTRACKER_ENABLE_LOCATION_TRACKING then
        return
    end
    local v = LOCATION_MAPPING[location_id]
    if not v then
        if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
            print(string.format("onLocation: could not find location mapping for id %s", location_id))
        end
        return
    end
    local obj = Tracker:FindObjectForCode(v)
    if obj then
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
        print(string.format("onLocation: could not find object for code %s", v))
    end
end

-- called when a locations is scouted
function onScout(location_id, location_name, item_id, item_name, item_player)
    if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
        print(string.format("called onScout: %s, %s, %s, %s, %s", location_id, location_name, item_id, item_name,
            item_player))
    end
    -- not implemented yet :(
end

-- called when a bounce message is received 
function onBounced(value)
    if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
        print(string.format("called onBounce: %s", dump_table(value)))
    end

    local slots = value["slots"]
    -- Lua does not support `slots ~= {Archipelago.PlayerNumber}`, so check the first and second values in the table.
    if not slots or not (slots[1] == Archipelago.PlayerNumber and slots[2] == nil) then
        -- All Bounced messages to be processed by this tracker are expected to target the player's slot specifically.
        return
    end

    local data = value["data"]
    if not data then
        return
    end

    -- The key is specified in the AP client.
    onMap(data["tww_stage_name"])
end

-- called in response to an Archipelago:Get(key_list)
function onRetrieved(key, new_value, old_value)
    if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
        print(string.format("called onRetrieved: %s", dump_table(value)))
    end

    if key == visited_stages_key and ENTRANCE_RANDO_ENABLED then
        -- If the player has not connected the AP client and visited any stages yet, the value in the server's data
        -- storage may not exist.
        if new_value ~= nil then
            local load_assignments_from_ap = Tracker:FindObjectForCode("setting_load_exit_assignments_from_ap")
            if load_assignments_from_ap.Active then
                Tracker.BulkUpdate = true
                PAUSE_ENTRANCE_UPDATES = true
                -- The data is stored as a dictionary used as a set, so the keys are the visited stage names and the
                -- values are all `true`.
                for stage_name, _ in pairs(new_value) do
                    entranceRandoAssignEntranceFromVisitedStage(stage_name)
                end
                PAUSE_ENTRANCE_UPDATES = false
                update_entrances()

                Tracker.BulkUpdate = false
                forceLogicUpdate()
            end
        end
    end
end

-- add AP callbacks
-- un-/comment as needed
Archipelago:AddClearHandler("clear handler", onClearHandler)
Archipelago:AddBouncedHandler("bounced handler", onBounced)
Archipelago:AddRetrievedHandler("retrieved handler", onRetrieved)
if AUTOTRACKER_ENABLE_ITEM_TRACKING then
    Archipelago:AddItemHandler("item handler", onItem)
end
if AUTOTRACKER_ENABLE_LOCATION_TRACKING then
    Archipelago:AddLocationHandler("location handler", onLocation)
end
-- Archipelago:AddScoutHandler("scout handler", onScout)
