KillTracker = {
    ClassName = "KillTracker",
    BlueFlag = nil,
    RedFlag = nil,
    MessageFlag = nil
}

function KillTracker:New(blueFlag, redFlag, messageFlag)
    local o = BASE:Inherit(self, EVENTHANDLER:New());
    if blueFlag then
        o.BlueFlag = USERFLAG:New(blueFlag);
    end
    if redFlag then
        o.RedFlag = USERFLAG:New(redFlag);
    end
    if messageFlag then
        o.MessageFlag = USERFLAG:New(messageFlag);
    end

    return o;
end

function KillTracker:OnEventKill(EventData)
    local function Inc(flag)
        if flag then
            flag:Set(flag:Get(flag) + 1);
        end
    end

    local function Get(flag)
        if flag then
            return flag:Get();
        else
            return "undefined";
        end
    end

    -- env.info("[KillTracker]: TgtObjectCategory " .. tostring(EventData.TgtObjectCategory));

    if EventData.TgtObjectCategory ~= Object.Category.UNIT then
        return;
    end

    if EventData.TgtCategory and EventData.TgtCoalition then

        local category = EventData.TgtCategory;
        -- env.info("[KillTracker]: TgtCategory " .. tostring(category));

        if category ~= Unit.Category.AIRPLANE and category ~= Unit.Category.HELICOPTER then
            return;
        end

        local c = EventData.TgtCoalition;

        if c == coalition.side.RED then
            Inc(self.BlueFlag);
        elseif c == coalition.side.BLUE then
            Inc(self.RedFlag);
        end

        env.info("[KillTracker]: RED: "..Get(self.RedFlag)..", BLUE: "..Get(self.BlueFlag));

        if self.MessageFlag and self.MessageFlag:Is(1) then
            MESSAGE:New("RED: "..Get(self.RedFlag)..", BLUE: "..Get(self.BlueFlag), 5, "Score", true):ToAll();
        end
    end
end

--- Tracks kills for each coalition and increases a cloaition flag by 1 for
--- every kill.
-- @param blueFlag - The flag of the blue coalition to increment if a red unit has been killed.
-- @param redFlag - The flag of the red coalition to increment if a blue unit has been killed.
-- @param messageFlag - Controls if actual score is displayed as a message. 1 - on, 0 - off.
-- Example:
--
-- TrackKills(1, 2, 3);
--
-- Flag 1: blue flag
-- Flag 2: red flag
-- Flag 3: message on/off flag
--
function TrackKills(blueFlag, redFlag, messageFlag)
    local tracker = KillTracker:New(blueFlag, redFlag, messageFlag);
    tracker:HandleEvent(EVENTS.Kill);

    world.addEventHandler(tracker);
end
