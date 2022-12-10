--- Watches for air units of a given coalition inside a given zone. The zone can be defined as
--- a DCS trigger zone.
-- @param name - The DCS name of the trigger zone. E.g. DefenseZone.
-- @param flag - The DCS flag number that indicates if an air unit is in the zone.
-- @param interval - The interval in seconds in which the zone should be scanned.
-- @param coalition - The coalition of the air units to scan for.
-- Example:
--
-- Watch("DefenseZone", 1, 10, coalition.Side.Blue);
--
-- Watches every 10s if at least one blue plane is inside the "DefenseZone" and
-- sets flag 1 to true, otherwise false.
--
function WatchZone(name, flag, interval, coalition)
    local zone = ZONE:FindByName(name);
    local userFlag = USERFLAG:New(flag);

    local function updateZone()
        zone:Scan({Object.Category.UNIT}, {Unit.Category.AIRPLANE});
        if zone:IsSomeInZoneOfCoalition(coalition) then
            userFlag:Set(1);
        else
            userFlag:Set(0);
        end
    end

    TIMER:New(updateZone):Start(0, interval, nil);
end
