local panel = CreateFrame("Frame", "CombatClusterPanel", UIParent);
panel:SetWidth(140); panel:SetHeight(224);
panel:SetFrameStrata("MEDIUM"); panel:Hide();
local rows = {};
for i = 1, 8 do
    local amount = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
    local font, size, flags = amount:GetFont();
    size = size or 16;
    local icon = panel:CreateTexture(nil, "OVERLAY");
    icon:SetWidth(size); icon:SetHeight(size);
    amount:SetWidth(110); amount:SetHeight(size); amount:SetJustifyH("LEFT");
    rows[i] = {amount = amount, icon = icon, font = font, size = size, flags = flags, life = 0};
    icon:Hide(); amount:Hide();
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
local enabled, active = true, false;
local previousDamage;
local groups = {};
local queue = {};
local nextRow = 1;
local function message(value)
    local chat = getglobal("DEFAULT_CHAT_FRAME");
    if (chat) then chat:AddMessage("Combat Cluster: " .. value); end
end
local function clear()
    groups = {}; queue = {}; nextRow = 1;
    for i = 1, 8 do rows[i].life = 0; rows[i].icon:Hide(); rows[i].amount:Hide(); end
    panel:Hide();
end
local function stop()
    if (active and previousDamage ~= nil and SetCVar) then SetCVar("CombatDamage", previousDamage); end
    active = false; clear();
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
local function show(group)
    local row = rows[nextRow];
    nextRow = math.mod(nextRow, 8) + 1;
    row.group = group; row.life = 3;
    local icons = spellIcons();
    local c = color(group.name);
    row.amount:SetText(number(group.damage));
    row.amount:SetTextColor(c[1], c[2], c[3]);
    if (row.font) then row.amount:SetFont(row.font, row.size * (group.crit and 1.5 or 1), row.flags); end
    row.icon:SetTexture(sourceIcon(group.name, icons) or "Interface\\Icons\\INV_Misc_QuestionMark");
    row.icon:Show(); row.amount:Show();
    panel:ClearAllPoints(); panel:SetPoint("RIGHT", UIParent, "RIGHT", -UIParent:GetWidth() * 0.2, 0);
    panel:Show();
end
local function parse(eventName, line)
    if (type(line) ~= "string") then return nil; end
    local name, amount, crit;
    if (eventName == "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE" or eventName == "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE") then
        local _, _, n, a, spell = string.find(line, "^(.+) suffers (%d+) .+ damage from your (.+)$");
        name, amount, crit = spell, a, string.find(line, "%(Critical%)") ~= nil;
    else
        local _, _, spell, victim, a = string.find(line, "^Your (.+) crits (.+) for (%d+)");
        if (spell) then name, amount, crit = spell, a, true;
        else
            _, _, spell, victim, a = string.find(line, "^Your (.+) hits (.+) for (%d+)");
            if (spell) then name, amount = spell, a;
            else
                _, _, spell, victim, a = string.find(line, "^Your (.+) causes (.+) (%d+)");
                if (spell) then name, amount = spell, a;
                else
                    _, _, victim, a = string.find(line, "^You crit (.+) for (%d+)");
                    if (a) then name, amount, crit = "Melee", a, true;
                    else
                        _, _, victim, a = string.find(line, "^You hit (.+) for (%d+)");
                        if (a) then name, amount = "Melee", a; end
                    end
                end
            end
        end
    end
    amount = tonumber(amount);
    if (name and amount and amount > 0) then return name, amount, crit; end
end
local driver = CreateFrame("Frame");
driver:RegisterEvent("PLAYER_LOGOUT");
for _, name in ipairs({"CHAT_MSG_SPELL_SELF_DAMAGE", "CHAT_MSG_COMBAT_SELF_HITS",
    "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE", "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE"}) do
    driver:RegisterEvent(name);
end
-- shortcut: same-spell hits arriving within 0.12s are treated as one burst; a true cast ID would replace this rule.
driver:SetScript("OnEvent", function()
    if (event == "PLAYER_LOGOUT") then stop(); return; end
    if (not enabled or not AZS_GetPhase or AZS_GetPhase() ~= "playing") then return; end
    local name, damage, crit = parse(event, arg1);
    if (not name) then return; end
    local now = GetTime();
    local group = groups[name];
    if (not group or now - group.last > 0.12) then
        group = {name = name, damage = 0, crit = false, last = now, ready = now + 0.12};
        groups[name] = group; table.insert(queue, group);
    end
    group.damage = group.damage + damage;
    group.crit = group.crit or crit;
    group.last = now;
    group.ready = now + 0.12;
end);
driver:SetScript("OnUpdate", function()
    if (not enabled) then return; end
    local phase = AZS_GetPhase and AZS_GetPhase();
    if (phase == nil or phase == "ready" or phase == "dead" or phase == "victory") then stop(); return; end
    if (phase ~= "playing") then return; end
    if (not active) then
        previousDamage = GetCVar and GetCVar("CombatDamage");
        if (previousDamage ~= nil and SetCVar) then SetCVar("CombatDamage", "0"); end
        active = true;
    end
    local now = GetTime();
    for i = 1, table.getn(queue) do
        local group = queue[i];
        if (now >= group.ready and rows[nextRow].life <= 0) then
            if (groups[group.name] == group) then groups[group.name] = nil; end
            show(group); table.remove(queue, i);
            break;
        end
    end
    local any = false;
    for i = 1, 8 do
        local row = rows[i];
        if (row.life > 0) then
            row.life = row.life - arg1;
            if (row.life <= 0) then row.icon:Hide(); row.amount:Hide();
            else
                any = true;
                local y = -(i - 1) * 28 + (3 - row.life) * 20;
                row.icon:ClearAllPoints(); row.icon:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y);
                row.amount:ClearAllPoints(); row.amount:SetPoint("TOPLEFT", panel, "TOPLEFT", row.size + 6, y);
                local alpha = math.min(1, row.life);
                row.icon:SetAlpha(alpha); row.amount:SetAlpha(alpha);
            end
        end
    end
    if (not any) then panel:Hide(); end
end);
if (SlashCmdList) then
    SLASH_COMBATCLUSTER1 = "/ccluster";
    SlashCmdList["COMBATCLUSTER"] = function(text)
        if (text == "off") then enabled = false; stop(); message("off");
        elseif (text == "on") then enabled = true; message("on");
        else message("/ccluster on | off"); end
    end;
end
