local Entrance = {
    -- The name of this entrance.
    name = "",
    -- There are no entrances accessible from multiple different exits, so a single parent_exit is all that is needed.
    -- Set to `nil` when the entrance is "The Great Sea", indicating that the entrance's parent is always accessible.
    parent_exit = "",
    -- The exit that has been assigned to this entrance.
    exit = "",
    -- The location which holds this entrance's logic, or `nil` if the entrance is always accessible.
    entrance_logic = ""
}

Entrance.__index = Entrance

function Entrance.new(name, parent_exit, exit)
    local self = setmetatable({}, Entrance)
    self.name = name
    self.exit = exit
    self.parent_exit = parent_exit or "The Great Sea"
    self.entrance_logic = "@Entrance Logic/" .. name
    return self
end

function Entrance:canAccess()
    if not self.entrance_logic then
        return true
    end
    local location = Tracker:FindObjectForCode(self.entrance_logic)
    local accessibility = location.AccessibilityLevel
    return accessibility == AccessibilityLevel.Normal
end

return Entrance