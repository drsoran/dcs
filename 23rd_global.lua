TTS_Enabled = false;
SRS_Path = nil;

-- #region Public

--- Airport with active ATIS by map.
local atis_airports = {
    [DCSMAP.Caucasus] = {
        [1] = { AIRBASE.Caucasus.Batumi, 143.0 }
    },

    [DCSMAP.PersianGulf] = {
    },

    [DCSMAP.Syria] = {
        [1] = { AIRBASE.Syria.Incirlik, 129.75 }
    },

    [DCSMAP.MarianaIslands] = {
        [1] = { AIRBASE.MarianaIslands.Andersen_AFB, 254.325 }
    },
};

--- Builds a menu with sub menu entries under 'F10 Other' that sets a DCS flag to true.
-- @param name - The display name of the menu under F10.
-- @params - A list of menu entries in the format "flag#:name". The flag# must match a DCS flag.
-- Example:
--
-- BuildFlagsMenu("Activate AI", "1:MiG29", "2:SU27", "103:Air Defense");
--
-- Will build the following menu structure under F10:
--
-- Activate AI
--   - MiG29        -> sets DCS flag 1 to true when selected
--   - SU27         -> sets DCS flag 2 to true when selected
--   - Air Defense  -> sets DCS flag 103 to true when selected
--
function BuildFlagsMenu(name, ...)
    local menu = MENU_MISSION:New(name);
    for i = 1, #arg do
        local split = UTILS.Split(arg[i], ":");
        if #split == 2 and tonumber(split[1]) then
            MENU_MISSION_COMMAND:New(split[2], menu, function () trigger.action.setUserFlag(split[1], true); end);
        else
            env.error("[23rd]: Wrong format in BuildMenu. Expected 'flag#:name'. " .. arg[i]);
        end
    end
end

--- Speaks the given @param message via SRS on the given @frequency
-- @param message - The message to speak in english.
-- @param frequency - The frequency of the SRS radio to transmit on.
-- @return modulation - The modulation to use, AM or FM. Defaults to AM.
-- @return after - Optional. The delay in seconds until the message is transmitted.
-- Example:
--
-- Speak("Dogde 1, FOX 2", 123.45, "AM", 3);
--
-- Will speak "Dogde 1, FOX 2" on SRS frequency 123.45 AM after 3 seconds.
--
-- Speak("Dogde 1, FOX 2", 123.45);
--
-- Will speak "Dogde 1, FOX 2" on SRS frequency 123.45 AM immediatly.
function Speak(message, frequency, modulation, after)
    if not TTS_Enabled then
        return;
    end

    env.info("[23rd]: Speak: " .. message);
    local srstext = SOUNDTEXT:New(message);
    local msrs = MSRS:New(SRS_Path, frequency, modulation);
    msrs:SetVoice("Microsoft David Desktop");
    msrs:SetCoalition(coalition.side.BLUE);
    msrs:PlaySoundText(srstext, after or 0);
end

--- Speaks the given @param message via SRS on the given @frequency
--- and additonally prints the message text in DCS.
-- @param message - The message to speak in english.
-- @param frequency - The frequency of the SRS radio to transmit on.
-- @return modulation - The modulation to use, AM or FM. Defaults to AM.
-- @return after - Optional. The delay in seconds until the message is transmitted.
-- @param sender - Optional. The sender of the message.
-- Example:
--
-- SpeakMsg("FOX 2", 123.45, "AM", 3, "Dodge-1");
--
-- Will speak "FOX 2" on SRS frequency 123.45 AM after 3 seconds and additonally
-- will display "Dodge-1: FOX 2" after 3 seconds in DCS.
function SpeakMsg(message, frequency, modulation, after, sender)
    local function sendMessage()
        local durationInSec = UTILS.Round(string.len(message) / 4, 0);
        local name = sender or (tostring(frequency) .. (modulation or "AM"));
        MESSAGE:New(name .. ": " .. message, durationInSec):ToCoalition(coalition.side.BLUE);
    end

    TIMER:New(sendMessage):Start((after or 0) + 4); -- 4 sec sample time for TTS.
    Speak(message, frequency, modulation, after);
end

-- #endregion

local function CheckTTS()
    SRS_Path = os.getenv("SRS_PATH");
    if not SRS_Path then
        env.error("[23rd]: Could not find environmant variable SRS_PATH, TTS disabled.");
        return;
    end

    package.path  = package.path..";"..lfs.currentdir().."/LuaSocket/?.lua"
    package.cpath = package.cpath..";"..lfs.currentdir().."/LuaSocket/?.dll"
    package.path  = package.path..";"..lfs.currentdir().."/Scripts/?.lua"
    local socket = require("socket");

    local data, err = socket.connect("127.0.0.1", STTS.SRS_PORT);
    if err then
        env.error("[23rd]: Could not connect to SRS server 127.0.0.1:" .. tostring(STTS.SRS_PORT) .. ". TTS disabled.");
        return;
    else
        env.info("[23rd]: Found SRS server at 127.0.0.1:" .. tostring(STTS.SRS_PORT));
        data:close();
    end

    TTS_Enabled = true;
    return TTS_Enabled;
end

local function StartATIS()
    if not TTS_Enabled then
        return;
    end

    local map = UTILS:GetDCSMap();
    local atis_stations = atis_airports[map];

    if not atis_stations then
        env.info("[23rd]: No ATIS stations registered for map " .. tostring(map) .. ".");
        return;
    end

    for i = 1, #atis_stations do
        local ap = atis_stations[i];
        env.info("[23rd]: Starting ATIS for " .. ap[1] .. ".");
        local atis = ATIS:New(ap[1], ap[2]);
        atis:SetSRS(SRS_Path, "female", "en-US");
        atis:SetAltimeterQNH(false);
        atis:ReportZuluTimeOnly();
        atis:SetQueueUpdateTime(40);
        atis:Start();
    end
end

function Init()
    if not BASE then
        env.error("[23rd]: MOOSE script not loaded. Script disabled.");
        return
    end

    if not lfs then
        env.error("[23rd]: Inproper setup in MissionScripting.lua. TTS disabled.");
    else
        CheckTTS();
        StartATIS();
    end
end

Init();
