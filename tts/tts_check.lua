TTS_Enabled = false;
SRS_Path = nil;

if not lfs then
    env.error("[TTS]: Inproper setup in MissionScripting.lua. TTS disabled.");
end

package.path  = package.path..";"..lfs.currentdir().."/LuaSocket/?.lua"
package.cpath = package.cpath..";"..lfs.currentdir().."/LuaSocket/?.dll"
package.path  = package.path..";"..lfs.currentdir().."/Scripts/?.lua"
local socket = require("socket");

function CheckTTS()
    SRS_Path = os.getenv("SRS_PATH");
    if not SRS_Path then
        env.error("[TTS]: Could not find environmant variable SRS_PATH, TTS disabled.");
        return;
    end

    local data, err = socket.connect("127.0.0.1", STTS.SRS_PORT);
    if err then
        env.error("[TTS]: Could not connect to SRS server 127.0.0.1:" .. tostring(STTS.SRS_PORT) .. ". TTS disabled.");
        return;
    else
        env.info("[TTS]: Found SRS server at 127.0.0.1:" .. tostring(STTS.SRS_PORT));
        data:close();
    end

    TTS_Enabled = true;
    return TTS_Enabled;
end

CheckTTS();
