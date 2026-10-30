local frame = CreateFrame("Frame");
local elapsed = 0;
local active = false;
local previous;
local warned = false;

frame:SetScript("OnUpdate", function()
    elapsed = elapsed + arg1;
    if (elapsed < 0.25) then return; end
    elapsed = 0;

    if (not AZS_GetPhase or not AZS_IsStoringLevels or not AZS_SetStoringLevels) then
        if (not warned) then
            local chat = getglobal("DEFAULT_CHAT_FRAME");
            if (chat) then
                chat:AddMessage("Queued Level Ups: this client lacks the level storage API. Update the client to use this addon.");
            end
            warned = true;
        end
        return;
    end

    local phase = AZS_GetPhase();
    if (phase == "ready" or phase == "playing") then
        if (not active) then
            previous = AZS_IsStoringLevels();
            if (previous == nil) then return; end
            AZS_SetStoringLevels(true);
            active = true;
        end
    elseif (phase == nil or phase == "dead" or phase == "victory") then
        if (active) then
            AZS_SetStoringLevels(previous);
            active = false;
        end
    end
end);
