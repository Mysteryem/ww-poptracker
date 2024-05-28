local Entrance = {}
Entrance.__index = Entrance

function Entrance.new(name, parent_exit, exit)
    local self = setmetatable({}, Entrance)
    -- The name of this entrance.
    self.name = name
    -- The exit that has been assigned to this entrance.
    self.exit = exit
    -- There are no entrances accessible from multiple different exits, so a single parent_exit is all that is needed.
    -- Set to `nil` when the entrance is "The Great Sea", indicating that the entrance's parent is always accessible.
    self.parent_exit = parent_exit or "The Great Sea"
    -- The location which holds this entrance's logic, or `nil` if the entrance is always accessible.
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