local panel = CreateFrame("Frame", "CombatClusterPanel", UIParent);
panel:SetWidth(140);
panel:SetHeight(224);
panel:SetFrameStrata("MEDIUM");
panel:Hide();
local chinese = GetLocale and string.sub(GetLocale(), 1, 2) == "zh";
local rows = {};
for i = 1, 8 do
    local amount = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
    local _, size = amount:GetFont();
    size = size or 16;
    local icon = panel:CreateTexture(nil, "OVERLAY");
    icon:SetWidth(size); icon:SetHeight(size);
    -- Anchor both regions to the frame, avoiding FontString-relative texture placement.
    icon:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -(i - 1) * 28);
    amount:SetPoint("TOPLEFT", panel, "TOPLEFT", size + 6, -(i - 1) * 28);
    amount:SetWidth(110); amount:SetHeight(size); amount:SetJustifyH("LEFT");
    icon:Hide();
    rows[i] = {amount = amount, icon = icon};
end

-- Stable source colors; skill icons identify sources when colors repeat.
local palette = {
    {1, 0.78, 0.32}, {0.4, 0.82, 1}, {1, 0.48, 0.35}, {0.55, 1, 0.5},
    {0.85, 0.6, 1}, {1, 0.58, 0.82}, {0.4, 1, 0.83}, {1, 0.95, 0.55}
};
local function color(name)
    local hash = 0;
    for i = 1, string.len(name) do hash = math.mod(hash * 31 + string.byte(name, i), 65521); end
    return palette[math.mod(hash, table.getn(palette)) + 1];
end
local function number(value)
    if (value >= 1000000) then return string.format("%.2fM", value / 1000000); end
    if (value >= 1000) then return string.format("%.1fK", value / 1000); end
    return string.format("%.0f", value);
end
local enabled = true;
local active = false;
local baseline, pending = {}, {};
local elapsed, window, age = 0, 0, 0;
local previousDamage;
local lastTime;
local warned = false;
local function message(text)
    local chat = getglobal("DEFAULT_CHAT_FRAME");
    if (chat) then chat:AddMessage("Combat Cluster: " .. text); end
end
local function stop()
    if (active and previousDamage ~= nil and SetCVar) then SetCVar("CombatDamage", previousDamage); end
    active = false;
    baseline, pending = {}, {};
    window, age = 0, 0;
    lastTime = nil;
    panel:Hide();
end
local function snapshot()
    local lines = AZS_GetMeter();
    if (type(lines) ~= "table") then return nil; end
    local totals = {};
    for i = 1, table.getn(lines) do
        local line = lines[i];
        if (type(line.name) == "string" and type(line.dmg) == "number" and line.dmg >= 0) then
            totals[line.name] = (totals[line.name] or 0) + line.dmg;
        end
    end
    return totals;
end
local iconLookup;
local function spellIcons()
    local icons = {};
    -- The browser client publishes localized names and texture paths together here.
    local feeds = {AZS_TIMERS or {}, AZS_PETS or {}, AZS_DEBUFFS or {}};
    for f = 1, table.getn(feeds) do
        for i = 1, table.getn(feeds[f]) do
            local entry = feeds[f][i];
            if (type(entry.name) == "string" and type(entry.icon) == "string" and entry.icon ~= "") then
                icons[entry.name] = entry.icon;
            end
        end
    end
    if (GetNumSpellTabs and GetSpellTabInfo and GetSpellName and GetSpellTexture) then
        for tab = 1, GetNumSpellTabs() do
            local _, _, offset, count = GetSpellTabInfo(tab);
            if (type(offset) == "number" and type(count) == "number") then
                for slot = offset + 1, math.min(offset + count, 1024) do
                    local name = GetSpellName(slot, "spell");
                    if (name and not icons[name]) then icons[name] = GetSpellTexture(slot, "spell"); end
                end
            end
        end
    end
    -- Survivors can populate the action bar without populating the WoW spellbook.
    if (GetActionTexture) then
        if (not iconLookup) then
            iconLookup = CreateFrame("GameTooltip", "CombatClusterIconLookup", UIParent, "GameTooltipTemplate");
            iconLookup:Hide();
        end
        if (iconLookup.SetOwner and iconLookup.ClearLines and iconLookup.SetAction) then
            iconLookup:SetOwner(UIParent, "ANCHOR_NONE");
            for slot = 1, 12 do
                local texture = GetActionTexture(slot);
                if (texture) then
                    iconLookup:ClearLines();
                    local ok = pcall(function() iconLookup:SetAction(slot); end);
                    local first = getglobal("CombatClusterIconLookupTextLeft1");
                    local name = ok and first and first:GetText();
                    if (type(name) == "string" and name ~= "" and not icons[name]) then icons[name] = texture; end
                end
            end
            iconLookup:Hide();
        end
    end
    return icons;
end
local function texturePath(value)
    if (type(value) ~= "string" or value == "" or string.find(string.lower(value), "questionmark", 1, true)) then return nil; end
    if (string.find(value, "\\", 1, true) or string.find(value, "/", 1, true)) then return value; end
    if (string.find(value, "^Spell_") or string.find(value, "^Ability_") or string.find(value, "^INV_") or string.find(value, "^Trade_")) then
        return "Interface\\Icons\\" .. value;
    end
    return nil;
end
local function sourceIcon(name, liveIcons)
    local canonical = (CombatClusterIconNames and CombatClusterIconNames[name])
        or (AZSSpellMeterName and AZSSpellMeterName[name]) or name;
    local path = texturePath(liveIcons[name]) or texturePath(liveIcons[canonical])
        or texturePath(CombatClusterIconFiles and CombatClusterIconFiles[canonical])
        or texturePath(AZSSpellMeterIcon and AZSSpellMeterIcon[canonical]);
    if (path) then return path; end
    -- Equipment procs can be named "item: spell"; the suffix identifies the actual spell.
    local _, _, item, spell = string.find(name, "^(.-):%s*(.+)$");
    if (not item) then _, _, item, spell = string.find(name, "^(.-)：%s*(.+)$"); end
    if (item and item ~= "" and spell ~= "") then
        path = sourceIcon(spell, liveIcons) or sourceIcon(item, liveIcons);
        if (path) then return path; end
    end
    if (GetItemInfo) then
        local _, _, _, _, _, _, _, _, ninth, tenth = GetItemInfo(name);
        return texturePath(tenth) or texturePath(ninth);
    end
    return nil;
end
local function display()
    local list = {};
    for name, value in pairs(pending) do table.insert(list, {name = name, value = value}); end
    pending = {};
    if (table.getn(list) == 0) then return; end
    table.sort(list, function(a, b)
        if (a.value == b.value) then return a.name < b.name; end
        return a.value > b.value;
    end);
    if (table.getn(list) > 7) then
        local other = 0;
        for i = 8, table.getn(list) do other = other + list[i].value; end
        list[8] = {name = chinese and "其他" or "Other", value = other, other = true};
        for i = table.getn(list), 9, -1 do list[i] = nil; end
    end
    local icons = spellIcons();
    for i = 1, 8 do
        local item = list[i];
        local row = rows[i];
        if (item) then
            local c = item.other and {0.78, 0.78, 0.78} or color(item.name);
            row.amount:SetText(number(item.value));
            row.icon:SetTexture(item.other and "Interface\\Icons\\INV_Misc_Book_09"
                or sourceIcon(item.name, icons) or "Interface\\Icons\\INV_Misc_QuestionMark");
            row.icon:Show();
            row.amount:SetTextColor(c[1], c[2], c[3]);
        else
            row.amount:SetText(""); row.icon:Hide();
        end
    end
    panel:ClearAllPoints();
    panel:SetPoint("RIGHT", UIParent, "RIGHT", -UIParent:GetWidth() * 0.2, 0);
    age = 0;
    panel:SetAlpha(1); panel:Show();
end
local driver = CreateFrame("Frame");
driver:RegisterEvent("PLAYER_LOGOUT");
driver:SetScript("OnEvent", stop);
driver:SetScript("OnUpdate", function()
    elapsed = elapsed + arg1;
    if (elapsed < 0.2) then return; end
    local dt = elapsed;
    elapsed = 0;
    if (not enabled) then return; end
    if (not AZS_GetPhase or not AZS_GetMeter or not AZS_GetRunTime) then
        if (not warned) then message("required AZS damage meter API unavailable"); warned = true; end
        stop(); return;
    end
    local phase = AZS_GetPhase();
    if (phase == nil or phase == "ready" or phase == "dead" or phase == "victory") then stop(); return; end
    if (phase ~= "playing") then panel:Hide(); return; end
    local totals = snapshot();
    local now = AZS_GetRunTime();
    if (not totals or type(now) ~= "number") then stop(); return; end
    if (active and lastTime and now < lastTime) then stop(); end
    lastTime = now;
    if (not active) then
        baseline = totals;
        previousDamage = GetCVar and GetCVar("CombatDamage");
        if (previousDamage ~= nil and SetCVar) then SetCVar("CombatDamage", "0"); end
        active = true;
        return;
    end
    for name, total in pairs(totals) do
        local delta = total - (baseline[name] or 0);
        if (delta > 0) then pending[name] = (pending[name] or 0) + delta; end
        baseline[name] = total;
    end
    window = window + dt;
    age = age + dt;
    if (window >= 0.75) then window = 0; display(); end
    if (age >= 2) then panel:Hide();
    elseif (age > 1) then panel:SetAlpha(2 - age); end
end);
if (SlashCmdList) then
    SLASH_COMBATCLUSTER1 = "/ccluster";
    SlashCmdList["COMBATCLUSTER"] = function(text)
        if (text == "off") then enabled = false; stop(); message("off; original damage text restored");
        elseif (text == "on") then enabled = true; message("on");
        elseif (text == "debug") then
            local icons = spellIcons();
            message("v1.4.0 tabs=" .. tostring(GetNumSpellTabs and GetNumSpellTabs()) .. " timers=" .. table.getn(AZS_TIMERS or {}));
            local lines = AZS_GetMeter and AZS_GetMeter() or {};
            for i = 1, math.min(table.getn(lines), 10) do
                local name = lines[i].name;
                message(tostring(name) .. " => " .. tostring(sourceIcon(name, icons) or "NO MATCH"));
            end
        else message("/ccluster on | off | debug"); end
    end;
end
