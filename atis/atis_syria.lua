local atis_airports = {
    [1] = { AIRBASE.Syria.Incirlik, 129.75 }
}

local function StartATIS()
    local srsPath = os.getenv("SRS_PATH");
    if not srsPath then
        env.error("Could not find environmant variable SRS_PATH, ATIS will not start.");
        return;
    end

    for i = 1, #atis_airports do
        local ap = atis_airports[i];
        local atis = ATIS:New(ap[1], ap[2]);
        atis:SetSRS(srsPath, "female", "en-US");
        atis:SetAltimeterQNH(false);
        atis:ReportZuluTimeOnly();
        atis:SetQueueUpdateTime(40);
        atis:Start();
    end
end

StartATIS();
