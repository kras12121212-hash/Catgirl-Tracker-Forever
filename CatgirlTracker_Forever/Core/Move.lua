-- Speed and moving-flag reads. issecretvalue is the first use of each raw return.
-- A secret must not be compared, boolean-tested, or passed through `or`.

local ADDON_NAME, CCT = ...

CCT.Move = {}

function CCT.Move.Sample()
    if GetUnitSpeed then
        local speed = GetUnitSpeed("player")
        if issecretvalue(speed) then
            return { kind = "hidden" }
        end
        if type(speed) == "number" then
            return { kind = "speed", yards = speed, moving = speed > 0 }
        end
    end
    if IsPlayerMoving then
        local moving = IsPlayerMoving()
        if issecretvalue(moving) then
            return { kind = "hidden" }
        end
        if type(moving) == "boolean" then
            return { kind = "bool", moving = moving }
        end
    end
    return { kind = "hidden" }
end
