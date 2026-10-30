local update;
local phase;
local storing = false;
local calls = 0;
local warnings = 0;
function CreateFrame()
    return {SetScript = function(self, name, callback) update = callback; end};
end
function getglobal() return {AddMessage = function() warnings = warnings + 1; end}; end
function AZS_GetPhase() return phase; end
function AZS_IsStoringLevels() return storing; end
function AZS_SetStoringLevels(value) storing = value; calls = calls + 1; end
local function tick(value)
    phase = value;
    arg1 = 0.25;
    update();
end

dofile("addons/QueuedLevelUps/QueuedLevelUps.lua");
tick(nil); assert(calls == 0);
storing = nil; tick("ready"); assert(calls == 0);
storing = false; tick("ready"); assert(storing and calls == 1);
tick("playing"); tick("choosing"); tick("paused"); assert(calls == 1);
-- Respect the player's stock toggle for the rest of the run.
storing = false; tick("playing"); assert(not storing and calls == 1);
tick("dead"); assert(not storing and calls == 2);
tick("playing"); assert(storing and calls == 3);
tick("victory"); assert(not storing and calls == 4);
storing = true; tick("ready"); tick(nil); assert(storing and calls == 6);
AZS_SetStoringLevels = nil;
tick("playing"); tick("playing"); assert(warnings == 1 and calls == 6);
print("QueuedLevelUps: all checks passed");
