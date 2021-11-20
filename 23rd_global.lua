TTS_Enabled = false;
SRS_Path = nil;

-- #region Public

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

-- #endregion

package.path  = package.path..";"..lfs.currentdir().."/LuaSocket/?.lua"
package.cpath = package.cpath..";"..lfs.currentdir().."/LuaSocket/?.dll"
package.path  = package.path..";"..lfs.currentdir().."/Scripts/?.lua"
local socket = require("socket");

local function CheckTTS()
    SRS_Path = os.getenv("SRS_PATH");
    if not SRS_Path then
        env.error("[23rd]: Could not find environmant variable SRS_PATH, TTS disabled.");
        return;
    end

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
