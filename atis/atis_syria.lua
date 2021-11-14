local atis_airports = {
    [1] = { AIRBASE.Syria.Incirlik, 129.75 }
}

local function StartATIS()
    env.info("[ATIS]: Starting ATIS for " .. tostring(#atis_airports) .. " airport(s).");
    for i = 1, #atis_airports do
        local ap = atis_airports[i];
        local atis = ATIS:New(ap[1], ap[2]);
        atis:SetSRS(SRS_Path, "female", "en-US");
        atis:SetAltimeterQNH(false);
        atis:ReportZuluTimeOnly();
        atis:SetQueueUpdateTime(40);
        atis:Start();
    end
end

if TTS_Enabled then
    StartATIS();
end
